"""Phase 0 public-route router (the sanctioned exception to No-Site-Name).

Per SKILL.md R5, platforms that publish official no-auth public endpoints get a
deterministic route tried BEFORE the generic WAF grid. This is the *enforced,
in-engine* version of what used to be agent-driven curl snippets in SKILL.md —
so the agent can no longer silently skip it (which is exactly how Reddit/X were
wrongly declared "blocked": the grid 403'd on `.json` and nobody tried `.rss`).

This file is the ONLY engine/ module allowed to name platform hosts; it is
exempted in `bias_check.EXPLICIT_ALLOW_FILES`. Do NOT add per-site logic to any
other engine file — generic WAF handling stays site-agnostic.

Contract:
    route(url) -> Optional[dict]
      None              → url is not a recognised Phase-0 platform; caller runs
                          the generic grid as usual.
      {"platform","ok","route","content","final_url","attempts":[...]}
                        → recognised platform. `ok` says whether a public
                          route succeeded. Even on ok=False the caller should
                          fall through to the grid, but `attempts` is recorded
                          so failure is never silent.

Each attempt dict: {"route","platform","ok","status","bytes","note"}.
X longform can use the optional third-party FxTwitter service. X tweet results
retain their JSON format and report the selected source in metadata.
"""
from __future__ import annotations

import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
from typing import Optional
from urllib.parse import urlsplit


# --- low-level helpers -------------------------------------------------------
def _cffi_get(url: str, *, impersonate: str = "safari", timeout: int = 15):
    from curl_cffi import requests as r  # lazy: engine works even if missing
    return r.get(
        url,
        impersonate=impersonate,  # type: ignore[arg-type]
        timeout=timeout,
        headers={
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9,ko;q=0.8",
        },
        allow_redirects=True,
    )


def _host(url: str) -> str:
    h = (urlsplit(url).hostname or "").lower()
    return h[4:] if h.startswith("www.") else h  # strip the literal "www." prefix only


def _attempt(platform: str, route: str, ok: bool, status: int, body: str, note: str = "") -> dict:
    return {"platform": platform, "route": route, "ok": ok, "status": status,
            "bytes": len(body or ""), "note": note}


# --- platform detectors ------------------------------------------------------
def _detect(url: str) -> Optional[str]:
    h = _host(url)
    if not h:
        return None
    if "reddit.com" in h or h == "redd.it":
        return "reddit"
    if h in ("x.com", "twitter.com") or h.endswith(".x.com") or h.endswith(".twitter.com"):
        return "x"
    if "youtube.com" in h or h == "youtu.be":
        return "youtube"
    if h in ("threads.com", "threads.net") or h.endswith((".threads.com", ".threads.net")):
        return "threads"
    return None


# --- reddit ------------------------------------------------------------------
def _reddit(url: str, timeout: int) -> dict:
    attempts: list[dict] = []
    base = url.split("?", 1)[0].rstrip("/")
    # Build an .rss / .json target from the path (works for /r/<sub> and post URLs).
    rss_url = base + ("/.rss" if "/comments/" not in base else ".rss")
    json_url = base + ("/.json" if "/comments/" not in base else ".json")

    # Route 1: RSS (the route that actually survives — Reddit gates the JSON API).
    try:
        x = _cffi_get(rss_url, timeout=timeout)
        ok = x.status_code == 200 and ("<rss" in x.text or "<feed" in x.text)
        attempts.append(_attempt("reddit", "rss", ok, x.status_code, x.text,
                                 "feed" if ok else "no-feed-markers"))
        if ok:
            return {"platform": "reddit", "ok": True, "route": "rss",
                    "content": x.text, "final_url": rss_url, "attempts": attempts}
    except Exception as e:
        attempts.append(_attempt("reddit", "rss", False, 0, "", f"{type(e).__name__}"))

    # Route 2: JSON via curl_cffi (often 403 now, but try — cheap).
    try:
        x = _cffi_get(json_url, timeout=timeout)
        ok = x.status_code == 200 and x.text.lstrip().startswith(("{", "["))
        attempts.append(_attempt("reddit", "json", ok, x.status_code, x.text,
                                 "json" if ok else f"status={x.status_code}"))
        if ok:
            return {"platform": "reddit", "ok": True, "route": "json",
                    "content": x.text, "final_url": json_url, "attempts": attempts}
    except Exception as e:
        attempts.append(_attempt("reddit", "json", False, 0, "", f"{type(e).__name__}"))

    return {"platform": "reddit", "ok": False, "route": None, "content": "",
            "final_url": url, "attempts": attempts}


# --- x / twitter -------------------------------------------------------------
_TWEET_ID_RE = re.compile(r"/status(?:es)?/(\d+)")
_TCO_ONLY_RE = re.compile(r"^\s*https://t\.co/\S+\s*$")
_X_HANDLE_RE = re.compile(r"[A-Za-z0-9_]{1,15}")
_LONG_TEXT_CHARS = 270


def _x_truncation_signal(tweet: dict) -> bool:
    text = tweet.get("text")
    return isinstance(text, str) and (
        "note_tweet" in tweet or "article" in tweet
        or len(text) >= _LONG_TEXT_CHARS or bool(_TCO_ONLY_RE.fullmatch(text))
    )


def _fxtwitter_full_text(payload: object) -> str:
    if not isinstance(payload, dict) or not isinstance(payload.get("tweet"), dict):
        return ""
    tweet = payload["tweet"]
    article = tweet.get("article")
    if isinstance(article, dict):
        content = article.get("content")
        blocks = content.get("blocks") if isinstance(content, dict) else None
        if isinstance(blocks, list):
            paragraphs = [block["text"].strip() for block in blocks
                          if isinstance(block, dict) and isinstance(block.get("text"), str)
                          and block["text"].strip()]
            if paragraphs:
                title = article.get("title")
                if isinstance(title, str) and title.strip():
                    paragraphs.insert(0, title.strip())
                return "\n\n".join(paragraphs)
    text = tweet.get("text")
    return text if isinstance(text, str) else ""


def _x_fxtwitter(tid: str, tweet: dict, timeout: int, attempts: list[dict]) -> tuple[Optional[str], str]:
    """Expand only when longer; failures must preserve the official response."""
    try:
        user = tweet.get("user")
        handle = user.get("screen_name") if isinstance(user, dict) else None
        if not isinstance(handle, str) or not _X_HANDLE_RE.fullmatch(handle):
            handle = "i"
        response = _cffi_get(f"https://api.fxtwitter.com/{handle}/status/{tid}",
                             impersonate="chrome", timeout=min(timeout, 10))
        full = _fxtwitter_full_text(response.json()) if response.status_code == 200 else ""
        ok = bool(full.strip()) and len(full) > len(tweet["text"])
        reason = "fxtwitter_not_longer" if full.strip() else "fxtwitter_error"
        attempts.append(_attempt("x", "fxtwitter", ok, response.status_code, response.text,
                                 f"chars={len(full)}" if ok else reason))
        return (full, "") if ok else (None, reason)
    except Exception as error:
        attempts.append(_attempt("x", "fxtwitter", False, 0, "", type(error).__name__))
        return None, "fxtwitter_error"


def _x_expand(tweet: dict, result: dict, tid: str, timeout: int) -> dict:
    # Keep the known-good tweet-result even if the optional expansion is malformed.
    try:
        if not _x_truncation_signal(tweet):
            return result
        if os.environ.get("INSANE_SEARCH_FXTWITTER", "1").strip().lower() in {"0", "false", "off", "no"}:
            full, reason = None, "fxtwitter_disabled"
        else:
            full, reason = _x_fxtwitter(tid, tweet, timeout, result["attempts"])
        if full is not None:
            result.update(route="fxtwitter", content=json.dumps({**tweet, "text": full}, ensure_ascii=False),
                          source_kind="third_party", source_service="fxtwitter")
        else:
            result.update(truncated_possible=True, truncation_reason=reason)
    except Exception:
        result.update(truncated_possible=True, truncation_reason="fxtwitter_error")
    return result


def _x(url: str, timeout: int) -> dict:
    attempts: list[dict] = []
    m = _TWEET_ID_RE.search(url)

    if m:  # single tweet → tweet-result + oembed (both no-auth, reliable)
        tid = m.group(1)
        try:
            x = _cffi_get(f"https://cdn.syndication.twimg.com/tweet-result?id={tid}&token=a", timeout=timeout)
            d = x.json() if x.status_code == 200 else {}
            ok = isinstance(d, dict) and isinstance(d.get("text"), str) and bool(d["text"].strip())
            attempts.append(_attempt("x", "tweet-result", ok, x.status_code, x.text,
                                     "has-text" if ok else f"status={x.status_code}"))
            if ok:
                result = {"platform": "x", "ok": True, "route": "tweet-result",
                          "content": x.text, "final_url": url, "attempts": attempts,
                          "source_kind": "official", "source_service": "x", "content_format": "json"}
                return _x_expand(d, result, tid, timeout)
        except Exception as e:
            attempts.append(_attempt("x", "tweet-result", False, 0, "", f"{type(e).__name__}"))
        try:
            ourl = f"https://publish.twitter.com/oembed?url=https://twitter.com/i/status/{tid}&omit_script=1"
            x = _cffi_get(ourl, timeout=timeout)
            d = x.json() if x.status_code == 200 else {}
            ok = bool(d.get("html"))
            attempts.append(_attempt("x", "oembed", ok, x.status_code, x.text,
                                     "has-html" if ok else f"status={x.status_code}"))
            if ok:
                return {"platform": "x", "ok": True, "route": "oembed",
                        "content": x.text, "final_url": ourl, "attempts": attempts}
        except Exception as e:
            attempts.append(_attempt("x", "oembed", False, 0, "", f"{type(e).__name__}"))
    else:  # profile timeline → syndication (rate-limit-prone; retry once)
        handle = urlsplit(url).path.strip("/").split("/")[0]
        _reserved = {"i", "search", "home", "explore", "messages", "notifications", "settings", "hashtag"}
        if handle and handle.lower() not in _reserved:
            surl = f"https://syndication.twitter.com/srv/timeline-profile/screen-name/{handle}"
            for attempt_no in range(2):
                try:
                    x = _cffi_get(surl, timeout=timeout)
                    ok = x.status_code == 200 and "__NEXT_DATA__" in x.text
                    attempts.append(_attempt("x", f"syndication-timeline#{attempt_no+1}", ok,
                                             x.status_code, x.text,
                                             "timeline" if ok else f"status={x.status_code}"))
                    if ok:
                        return {"platform": "x", "ok": True, "route": "syndication-timeline",
                                "content": x.text, "final_url": surl, "attempts": attempts}
                except Exception as e:
                    attempts.append(_attempt("x", f"syndication-timeline#{attempt_no+1}", False, 0, "", f"{type(e).__name__}"))

    return {"platform": "x", "ok": False, "route": None, "content": "",
            "final_url": url, "attempts": attempts}


# --- youtube -----------------------------------------------------------------
def _ytdlp_argv() -> Optional[list[str]]:
    """Best yt-dlp invocation for this environment, or None if unavailable.

    Prefers the ``yt-dlp`` console script on PATH; falls back to
    ``<python> -m yt_dlp`` when the script dir is not on PATH but the module is
    importable — the common case for ``pip install --user`` and Windows / venv
    installs, where the Scripts/bin dir is frequently absent from PATH. Mirrors
    the ``which yt-dlp || python3 -m yt_dlp`` fallback already documented in
    references/media.md."""
    exe = shutil.which("yt-dlp")
    if exe:
        return [exe]
    if importlib.util.find_spec("yt_dlp") is not None:
        return [sys.executable, "-m", "yt_dlp"]
    return None


def _youtube(url: str, timeout: int) -> dict:
    attempts: list[dict] = []
    argv = _ytdlp_argv()
    if argv is None:
        attempts.append(_attempt("youtube", "yt-dlp", False, 0, "", "yt-dlp not installed"))
        return {"platform": "youtube", "ok": False, "route": None, "content": "",
                "final_url": url, "attempts": attempts}
    try:
        p = subprocess.run(
            argv + ["--dump-json", "--skip-download", url],
            capture_output=True, text=True, timeout=max(timeout, 60),
        )
        ok = p.returncode == 0 and p.stdout.strip().startswith("{")
        note = "json" if ok else (p.stderr or "").strip()[:80]
        attempts.append(_attempt("youtube", "yt-dlp", ok, 200 if ok else 0, p.stdout, note))
        if ok:
            return {"platform": "youtube", "ok": True, "route": "yt-dlp",
                    "content": p.stdout, "final_url": url, "attempts": attempts}
    except FileNotFoundError:
        attempts.append(_attempt("youtube", "yt-dlp", False, 0, "", "yt-dlp not installed"))
    except Exception as e:
        attempts.append(_attempt("youtube", "yt-dlp", False, 0, "", f"{type(e).__name__}"))
    return {"platform": "youtube", "ok": False, "route": None, "content": "",
            "final_url": url, "attempts": attempts}


# --- threads -----------------------------------------------------------------
_THREADS_POST_RE = re.compile(r"/post/([A-Za-z0-9_-]+)")


def _threads(url: str, timeout: int) -> dict:
    """Threads video post → signed CDN URLs from the page's inline JSON.

    yt-dlp has no Threads extractor, but an anonymous GET with a curl_cffi
    fingerprint passes the WAF and the HTML embeds several `video_versions`
    blocks (related posts included) — the block nearest to `"code":"<shortcode>"`
    is the requested post's. The signed URLs expire (`oe` param): download
    promptly, outside the engine (plain curl suffices for the CDN).
    """
    attempts: list[dict] = []
    m = _THREADS_POST_RE.search(url.split("?", 1)[0])
    if not m:  # profile/tag URL — no deterministic media route; run the grid
        attempts.append(_attempt("threads", "inline-json", False, 0, "", "no-post-shortcode"))
        return {"platform": "threads", "ok": False, "route": None, "content": "",
                "final_url": url, "attempts": attempts}
    code = m.group(1)
    try:
        x = _cffi_get(url, timeout=timeout)
        raw = x.text if x.status_code == 200 else ""
        code_pos = [c.start() for c in re.finditer(r'"code"\s*:\s*"%s"' % re.escape(code), raw)]
        blocks = list(re.finditer(r'"video_versions"\s*:\s*\[(.*?)\]', raw))
        if not code_pos or not blocks:
            note = (f"status={x.status_code}" if x.status_code != 200
                    else ("no-code-marker" if not code_pos else "no-video_versions"))
            attempts.append(_attempt("threads", "inline-json", False, x.status_code, raw, note))
            return {"platform": "threads", "ok": False, "route": None, "content": "",
                    "final_url": url, "attempts": attempts}
        best = min(blocks, key=lambda b: min(abs(b.start() - c) for c in code_pos))
        urls: list[str] = []
        for u in re.findall(r'"url"\s*:\s*"([^"]+)"', best.group(1)):
            u = u.replace("\\/", "/").encode().decode("unicode_escape")
            if u not in urls:
                urls.append(u)
        if not urls:
            attempts.append(_attempt("threads", "inline-json", False, x.status_code, raw, "empty-video_versions"))
            return {"platform": "threads", "ok": False, "route": None, "content": "",
                    "final_url": url, "attempts": attempts}
        content = json.dumps({"post_code": code, "video_urls": urls}, ensure_ascii=False)
        attempts.append(_attempt("threads", "inline-json", True, x.status_code, content,
                                 f"{len(urls)} video url(s)"))
        return {"platform": "threads", "ok": True, "route": "inline-json",
                "content": content, "final_url": url, "attempts": attempts}
    except Exception as e:
        attempts.append(_attempt("threads", "inline-json", False, 0, "", f"{type(e).__name__}"))
        return {"platform": "threads", "ok": False, "route": None, "content": "",
                "final_url": url, "attempts": attempts}


_ROUTERS = {"reddit": _reddit, "x": _x, "youtube": _youtube, "threads": _threads}


# --- public entrypoint -------------------------------------------------------
def route(url: str, *, timeout: int = 15) -> Optional[dict]:
    platform = _detect(url)
    if platform is None:
        return None
    return _ROUTERS[platform](url, timeout)

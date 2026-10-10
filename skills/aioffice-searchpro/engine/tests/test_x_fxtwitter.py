"""Offline longform regression tests, including the public fetch/search contracts."""
from __future__ import annotations

import io
import json
from contextlib import redirect_stdout
from dataclasses import dataclass

import pytest

from engine import __main__ as cli
from engine import phase0, x_search
from engine.fetch_chain import fetch

URL = "https://x.com/example/status/123"
FULL = "확장된 공개 게시물 본문입니다. " * 60


@dataclass
class Response:
    payload: object
    status_code: int = 200

    @property
    def text(self):
        return json.dumps(self.payload, ensure_ascii=False, default=str)

    def json(self):
        if isinstance(self.payload, Exception):
            raise self.payload
        return self.payload


@pytest.fixture(autouse=True)
def isolate(monkeypatch, tmp_path):
    monkeypatch.setenv("AIOFFICE_SEARCHPRO_LEARN", "0")
    monkeypatch.setenv("INSANE_OBSERVATIONS_DIR", str(tmp_path / "observations"))
    monkeypatch.delenv("INSANE_SEARCH_FXTWITTER", raising=False)


def tweet(text="A short post", **fields):
    return {"text": text, "id_str": "123", "user": {"name": "Example", "screen_name": "example"},
            "created_at": "2026-10-10T00:00:00Z", "favorite_count": 42, "conversation_count": 3,
            **fields}


def wire(monkeypatch, original, payload=None, status=200, error=None):
    calls = []

    def get(url, **kwargs):
        calls.append((url, kwargs))
        if "cdn.syndication.twimg.com/tweet-result" in url:
            return Response(original)
        assert url.startswith("https://api.fxtwitter.com/")
        if error:
            raise error
        return Response(payload, status)

    monkeypatch.setattr(phase0, "_cffi_get", get)
    return calls


@pytest.mark.parametrize("original", [
    tweet(note_tweet={}), tweet(article={}), tweet("x" * 270), tweet("https://t.co/fixture"),
])
def test_expansion_signals_preserve_json_and_official_metadata(monkeypatch, original):
    calls = wire(monkeypatch, original, {"tweet": {"text": FULL}})
    result = phase0.route(URL)
    assert result["route"] == "fxtwitter"
    assert json.loads(result["content"]) == {**original, "text": FULL}
    assert result["source_kind"] == "third_party"
    assert result["source_service"] == "fxtwitter"
    assert result["content_format"] == "json"
    assert result["final_url"] == URL
    assert len(calls) == 2 and calls[-1][1]["timeout"] <= 10


def test_short_post_avoids_third_party(monkeypatch):
    original = tweet("x" * 269)
    calls = wire(monkeypatch, original)
    result = phase0.route(URL)
    assert result["route"] == "tweet-result" and len(calls) == 1
    assert result["content"] == Response(original).text
    assert "truncated_possible" not in result


def test_article_extracts_title_and_nonempty_text_blocks(monkeypatch):
    original = tweet("https://t.co/fixture", article={})
    payload = {"tweet": {"text": "teaser", "article": {"title": "Article title", "content": {
        "blocks": [{"text": " "}, {"text": "First paragraph " * 10}, None,
                   {"text": 123}, {"text": "Second paragraph"}],
    }}}}
    wire(monkeypatch, original, payload)
    body = json.loads(phase0.route(URL)["content"])["text"]
    assert body.startswith("Article title\n\nFirst paragraph")
    assert body.endswith("\n\nSecond paragraph")
    assert "\n\n \n\n" not in body


@pytest.mark.parametrize("value", ["0", "false", "off", "no", " OFF "])
def test_disable_values_never_send_to_third_party(monkeypatch, value):
    monkeypatch.setenv("INSANE_SEARCH_FXTWITTER", value)
    original = tweet("x" * 280)
    calls = wire(monkeypatch, original)
    result = phase0.route(URL)
    assert len(calls) == 1 and result["content"] == Response(original).text
    assert result["truncated_possible"] and result["truncation_reason"] == "fxtwitter_disabled"


@pytest.mark.parametrize("payload,status,error,reason", [
    ({"tweet": {"text": "short"}}, 200, None, "fxtwitter_not_longer"),
    ({"tweet": {"text": "x" * 280}}, 200, None, "fxtwitter_not_longer"),
    ({}, 503, None, "fxtwitter_error"),
    ({}, 429, None, "fxtwitter_error"),
    ({}, 200, TimeoutError(), "fxtwitter_error"),
    (ValueError("invalid JSON"), 200, None, "fxtwitter_error"),
    (None, 200, None, "fxtwitter_error"),
    ([], 200, None, "fxtwitter_error"),
    ({"tweet": []}, 200, None, "fxtwitter_error"),
    ({"tweet": {"text": 42}}, 200, None, "fxtwitter_error"),
    ({"tweet": {"text": " " * 500}}, 200, None, "fxtwitter_error"),
    ({"tweet": {"text": "", "article": {"content": {"blocks": {}}}}}, 200, None, "fxtwitter_error"),
])
def test_unsuccessful_expansion_keeps_known_good_response(monkeypatch, payload, status, error, reason):
    original = tweet("x" * 280)
    wire(monkeypatch, original, payload, status, error)
    result = phase0.route(URL)
    assert result["ok"] and result["route"] == "tweet-result"
    assert result["content"] == Response(original).text
    assert result["truncated_possible"] and result["truncation_reason"] == reason
    assert len(result["attempts"]) == 2
    assert result["attempts"][0]["ok"] and not result["attempts"][1]["ok"]


@pytest.mark.parametrize("user", [None, [], "invalid", {"screen_name": "../bad?token=private"},
                                       {"screen_name": "a" * 16}])
def test_malformed_user_cannot_change_request_path_or_discard_original(monkeypatch, user):
    calls = wire(monkeypatch, tweet("x" * 280, user=user), {"tweet": {"text": FULL}})
    assert phase0.route(URL)["ok"]
    assert calls[-1][0] == "https://api.fxtwitter.com/i/status/123"


@pytest.mark.parametrize("disabled", [False, True])
def test_search_output_keeps_post_metadata_source_and_truncation(monkeypatch, disabled):
    if disabled:
        monkeypatch.setenv("INSANE_SEARCH_FXTWITTER", "off")
    wire(monkeypatch, tweet("x" * 280), {"tweet": {"text": FULL}})
    monkeypatch.setattr(x_search, "_discover_with_brave", lambda *args: [URL])
    monkeypatch.setattr(x_search, "_discover_with_yahoo", lambda *args: [URL])
    result = x_search.search_x("test", use_xai=False).to_dict()
    assert result["ok"] and result["rejected_urls"] == []
    post = result["posts"][0]
    assert post["text"] == ("x" * 280 if disabled else FULL)
    assert (post["author_handle"], post["created_at"], post["likes"], post["replies"]) == (
        "example", "2026-10-10T00:00:00Z", 42, 3)
    assert set(post["discovered_by"]) == {"brave", "yahoo"}
    assert post["source_service"] == ("x" if disabled else "fxtwitter")
    assert post["source_kind"] == ("official" if disabled else "third_party")
    assert post["truncated_possible"] is disabled
    assert post["truncation_reason"] == ("fxtwitter_disabled" if disabled else "")


def test_fetch_reports_not_longer_without_calling_it_a_service_failure(monkeypatch):
    wire(monkeypatch, tweet("x" * 280), {"tweet": {"text": "short"}})
    result = fetch(URL, enable_learning=False)
    assert result.ok and "truncated_possible" in result.summary
    assert result.extraction_meta["truncation_reason"] == "fxtwitter_not_longer"


def test_cli_single_fetch_keeps_json_body_metadata_provenance_and_masking(monkeypatch, tmp_path):
    calls = wire(monkeypatch, tweet("x" * 280), {"tweet": {"text": FULL}})
    output, metadata = tmp_path / "post.json", tmp_path / "metadata.json"
    stdout = io.StringIO()
    with redirect_stdout(stdout):
        code = cli.main([URL + "?token=REQUEST_SECRET", "--json-content", "--no-playwright",
                         "--output", str(output), "--metadata", str(metadata)])
    assert code == 0 and len(calls) == 2
    payload = json.loads(stdout.getvalue())
    sidecar = json.loads(metadata.read_text())
    assert json.loads(output.read_text())["text"] == FULL
    assert "third-party route" in payload["summary"]
    assert payload["extraction_meta"]["source_service"] == "fxtwitter"
    assert payload["extraction_meta"]["content_format"] == "json"
    assert FULL in payload.pop("untrusted_text")
    assert payload == sidecar and "content" not in sidecar
    assert "REQUEST_SECRET" not in stdout.getvalue() + metadata.read_text()

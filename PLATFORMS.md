# Supported platforms & reference

Full platform coverage, the reference files behind each route, dependencies, and example prompts.
Most sites need no explicit entry — the [Phase 0→3 adaptive scheduler](README.md#-how-it-works)
handles them automatically. This page lists the *special* endpoints and the reference map.

## What's in the index

Only special endpoints that the generic chain can't discover on its own. Everything else — Naver blogs, Coupang, LinkedIn, Medium, Korean news sites, Substack, most forums — is handled by the adaptive scheduler without explicit entries.

### Platform-specific APIs

| Platform | Method | Reference |
|----------|--------|-----------|
| X/Twitter | single tweet → `cdn.syndication tweet-result` + oEmbed · timeline → syndication · keyword → **WebSearch → tweet-result** | `twitter.md` |
| Reddit | `.rss` feed via curl_cffi (the unauth `.json` now 403s) | `json-api.md` |
| Bluesky | AT Protocol (`public.api.bsky.app/xrpc/...`) | `public-api.md` |
| Mastodon | Per-instance public API | `public-api.md` |
| Hacker News | Firebase API + **Algolia Search** (`hn.algolia.com/api/v1/search`) | `json-api.md` |
| Stack Overflow | SE API v2.3 | `public-api.md` |
| Lobste.rs / V2EX / dev.to | Public JSON APIs | `json-api.md` |

### Media (CLI tool required)

| Platform | Method | Reference |
|----------|--------|-----------|
| YouTube / Vimeo / Twitch / TikTok / SoundCloud + 1,853 others | `yt-dlp --dump-json` | `media.md` |

### Academic & registry

| Platform | Method | Reference |
|----------|--------|-----------|
| arXiv | Atom API | `public-api.md` |
| CrossRef | REST API | `public-api.md` |
| Wikipedia | REST API | `json-api.md` |
| OpenLibrary | JSON API | `public-api.md` |
| GitHub | `gh` CLI / REST API | `public-api.md` |
| npm / PyPI | Registry API | `json-api.md` |
| Wayback Machine | CDX API | `public-api.md` |

### Korea-specific

| Platform | Method | Reference |
|----------|--------|-----------|
| Naver Search | curl_cffi identity spoofing + `search.naver.com` (통합/블로그/뉴스) | `naver.md` |
| Naver Finance (stock prices) | `api.finance.naver.com/siseJson.naver` (unofficial, no auth) | `naver.md` |

**Everything else flows through Phase 1~3 automatically** — including Coupang (curl_cffi safari), LinkedIn (identity spoofing → JSON-LD full article body), fmkorea (identity spoofing), Medium (Jina), most Korean forums (Jina or curl), and any site with `/rss` or `/feed` endpoints.

## Reference files

The skill is organized as a set of reference files (`skills/aioffice-searchpro/references/`), each covering one class of techniques.

| File | Covers |
|------|--------|
| `fallback.md` | Phase 0→3 adaptive scheduler, escalation signals, response validation |
| `jina.md` | Jina Reader (no-key reader at `r.jina.ai`) |
| `json-api.md` | Public JSON APIs (Reddit, HN, dev.to, Wikipedia, npm, PyPI, etc.) |
| `public-api.md` | Bluesky, Mastodon, Stack Exchange, arXiv, CrossRef, OpenLibrary, GitHub, Wayback |
| `media.md` | yt-dlp usage for 1,858 media sites |
| `twitter.md` | X/Twitter tweet-result + oEmbed + syndication + WebSearch keyword search |
| `naver.md` | Naver Search (curl_cffi identity spoofing), blog mobile URLs, Finance JSON API |
| `rss.md` | Korean news RSS (9 outlets), Google News RSS, feedparser, SearXNG |
| `tls-impersonate.md` | curl_cffi multi-target + identity spoofing (cookie warming, referrer chain) + behavioral challenge detection |
| `playwright.md` | Playwright MCP full toolkit (snapshot, evaluate, network_requests) |
| `cache-archive.md` | Google AMP cache, archive.today, Wayback Machine |
| `metadata.md` | OGP, JSON-LD, Schema.org, Next.js RSC payload extraction |

## Dependencies

**Required:** Claude Code only.

**Installed in an isolated plugin venv on first use** (`setup/run-engine.sh` or `setup/run-engine.ps1`; system Python is not modified):

```bash
bash setup/run-engine.sh "https://example.com/" --selector h1 --no-playwright --json
```

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\setup\run-engine.ps1 "https://example.com/" --selector h1 --no-playwright --json
```

**Optional, improves coverage:**

```bash
bash setup/browser.sh   # local Chrome/Patchright + Playwright MCP
```

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\setup\browser.ps1   # local Chrome/Patchright + Playwright MCP
```

If a dependency is missing, the wrapper installs the locked runtime dependency set and then tries the route.

## What AIOFFICE-SearchPro is not

- **Not a scraper** — It's a method-selection layer. It uses public APIs and standard techniques.
- **Not API-key based** — Everything uses no-auth public endpoints or URL transformations.
- **Not a hand-maintained answer key** — The index is minimal (~15 groups). Everything else is discovered by the adaptive scheduler.
- **Not bias-forming** — There's no "access denied" list. If a site can be reached, the chain will find the way.

## Example prompts

There are no commands. Just talk normally — the skill triggers when a URL is blocked or when accessing platforms that need special handling.

```
"What's on the front page of Hacker News right now?"
→ Firebase API → top stories with scores and comments

"Find AI papers published this week on arXiv"
→ arXiv Atom API with date filter

"Scrape Coupang for laptop deals under $1000"
→ Phase 2: curl_cffi safari → JSON-LD ItemList

"Summarize this Medium article"
→ Phase 1: Jina Reader → clean markdown

"Check what people are saying about Claude Code on Reddit"
→ Reddit .rss feed (curl_cffi) → posts

"Search X for AIOFFICE-SearchPro"
→ Intent routing: keyword → WebSearch(site:x.com) → tweet-result → full tweets

"네이버에서 클로드코드 뉴스 찾아줘"
→ Naver Search (identity spoofing) → news tab → article URLs → Jina Reader

"Find LinkedIn articles about AI agents"
→ WebSearch(site:linkedin.com) → identity spoofing → JSON-LD articleBody
```

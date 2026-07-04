English | [한국어](README.ko.md) | [中文](README.zh.md) | [日本語](README.ja.md) | [Español](README.es.md)

<div align="center">

# insane-search

**Impossible is nothing. If it's public, insane-search gets in.**

A resilient public-page reader for Claude Code. No API keys, no proxy setup.

<p>
  <a href="https://docs.anthropic.com/en/docs/claude-code"><img src="https://img.shields.io/badge/platform-Claude_Code-D97757?logo=claude" alt="Claude Code"></a>
  <img src="https://img.shields.io/badge/API_key-not_required-3FB950" alt="No API key">
  <a href="https://github.com/aidenlim-dev/insane-search"><img src="https://img.shields.io/badge/install-direct_GitHub-6E56CF" alt="direct GitHub install"></a>
  <a href="https://github.com/aidenlim-dev/insane-search/stargazers"><img src="https://img.shields.io/github/stars/aidenlim-dev/insane-search?style=flat&color=F0B72F" alt="stars"></a>
</p>

<!-- Hero — cinematic key-art: a blocked site (403 / CAPTCHA / WAF) shatters as
     insane-search breaks through and returns real public content with its source. -->
<img src="assets/hero.png" width="860" alt="Cinematic split: on the left a blocked site shows 403 Forbidden, a CAPTCHA, and a WAF wall; it shatters down the middle as insane-search breaks through on the right, returning a real public post from @claudeai (Claude Code Plugins) with its source — no API key.">

</div>

---

## ⚡ Install

For this course / direct GitHub install:

```bash
/plugin marketplace add aidenlim-dev/insane-search
/plugin install insane-search@insane-search-marketplace
/reload-plugins
```

Verify the install from a terminal:

```bash
git clone https://github.com/aidenlim-dev/insane-search.git
cd insane-search
bash setup/doctor.sh
```

Optional full browser coverage:

```bash
bash setup/browser.sh
```

When you need the winning HTML for parsing, save it on the same call:

```bash
bash setup/run-engine.sh "https://example.com/" --json --output page.html --metadata page.fetch.json
```

For a short classroom handout, use [COURSE_INSTALL.ko.md](COURSE_INSTALL.ko.md).

Marketplace install from `gptaku-plugins`:

```bash
/plugin marketplace add https://github.com/fivetaku/gptaku_plugins.git
/plugin install insane-search@gptaku-plugins
/reload-plugins
```

No commands to learn after install. Ask Claude Code normally — insane-search kicks in when a fetch gets blocked.

## 💬 Try it

Just ask normally — insane-search kicks in when a fetch gets blocked:

> *"Find what people are saying about Claude Code on Reddit and summarize the top threads."*
> *"Search X for posts about insane-search."*
> *"Summarize this YouTube video."*

**Expected:** Claude reaches each site's public route — Reddit's feed, X via oEmbed, YouTube captions — with no login and no API key, and returns usable text, where the same request returns *"I can't access that"* without the plugin.

## 🌐 Works on

**X · Reddit · YouTube · Hacker News · Naver · Coupang · LinkedIn · Medium · Substack · arXiv · GitHub · Stack Overflow · Bluesky · Mastodon** — plus any site with a public page, feed, or `/rss`. Full platform list & methods → [PLATFORMS.md](PLATFORMS.md).

## ⚙️ Why it gets through

- **It escalates, never pre-judges** — public API readers → syndication gateways → TLS impersonation → a real headless browser, trying each route until one works.
- **It looks human** — builds a full browser identity (real TLS fingerprint, cookie warming, referer chain), not just a swapped User-Agent.
- **It finds hidden APIs** — watches the real browser's network traffic and reuses the site's own internal JSON.
- **Zero system-Python setup** — first use creates an isolated plugin venv for `curl_cffi`, `yt-dlp`, and parser dependencies. No API keys, no signup.

## 🆚 Default Claude Code vs `+ insane-search`

| When you hit… | Claude Code alone | `+ insane-search` |
| :--- | :--- | :--- |
| A `403` / WAF-blocked page | ✖ gives up | ✓ escalates until one route gets through |
| Platform content (X, Reddit, HN) | ✖ often blocked or empty | ✓ public API readers + syndication |
| An anti-bot / CAPTCHA challenge | ✖ stops | ✓ TLS impersonation, then a real headless browser |
| A media page (YouTube, 1,800+ sites) | ✖ no transcript | ✓ `yt-dlp` metadata + captions |
| Missing tools (`curl_cffi`, `yt-dlp`) | — | ✓ auto-installs on first use |
| API keys / signup | — | ✓ none |
| A **login wall or paywall** | ✖ | ✖ **stops here, and says so** (see Boundaries) |

The differentiating row is the one thing the default fetcher can't do: **it keeps trying public routes until one works.**

## ✨ What just happened

| Without it | With insane-search |
| :--- | :--- |
| Ordinary fetch hits `403` and Claude says it can't read the page | The plugin picks a public-access route and returns usable text |
| You manually try mirrors, archives, mobile URLs | Fallbacks escalate automatically, public-only |
| A blocked page is a dead end | Metadata and structured data still yield titles, prices, summaries |

## 🔁 How it works

<img src="assets/pipeline.png" width="860" alt="Phase 0→3 escalation pipeline: a blocked URL flows through special public endpoints → lightweight probes → TLS impersonation → a real headless browser until one returns clean public content; a login or paywall exits as 'authentication required'. Every response is scanned for OGP / JSON-LD.">

<details>
<summary><strong>Phase 0→3 adaptive scheduler — details</strong></summary>

Each phase runs only if the previous one fails or detects a blocking signal:

- **Phase 0** — special public endpoints (platform APIs, feeds) it can't discover generically
- **Phase 1** — lightweight probes: public API readers, syndication gateways, mobile / `.json` / `/rss` URL variants
- **Phase 2** — TLS impersonation (curl_cffi: safari → chrome → firefox) with a full browser identity
- **Phase 3** — a real headless browser, which also surfaces the public JSON APIs a site uses internally
- **Exit** — a login or paywall is detected: it reports *"authentication required"* rather than pretending

Every response is also scanned for OGP / JSON-LD, so even partial pages yield titles, summaries, and prices.
</details>

## 🔒 Boundaries

insane-search is a **reader for public content**, not a way around authentication.

- Reaches what's available through public pages, public APIs, feeds, archives, and a browser's public responses.
- **Stops at logins and paywalls** — it reports `authentication required` instead of trying to defeat them.
- Never logs in as you and never stores or transmits credentials.
- All routes use no-auth public endpoints and standard, documented techniques.

## License

MIT

---

<div align="center">

**Direct GitHub install:** [aidenlim-dev/insane-search](https://github.com/aidenlim-dev/insane-search)

</div>

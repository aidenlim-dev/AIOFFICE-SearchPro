English | [한국어](README.ko.md) | [中文](README.zh.md) | [日本語](README.ja.md) | [Español](README.es.md)

<div align="center">

# AIOFFICE-SearchPro

<sub>Forked from <a href="https://github.com/fivetaku/insane-search">fivetaku/insane-search</a> and maintained as an AIOFFICE distribution.</sub>

**Impossible is nothing. If it's public, AIOFFICE-SearchPro gets in.**

A resilient public-page reader for Claude Code. No API keys, no proxy setup.

<p>
  <a href="https://docs.anthropic.com/en/docs/claude-code"><img src="https://img.shields.io/badge/platform-Claude_Code-D97757?logo=claude" alt="Claude Code"></a>
  <img src="https://img.shields.io/badge/API_key-not_required-3FB950" alt="No API key">
  <a href="https://github.com/aidenlim-dev/AIOFFICE-SearchPro"><img src="https://img.shields.io/badge/install-direct_GitHub-6E56CF" alt="direct GitHub install"></a>
  <a href="https://github.com/aidenlim-dev/AIOFFICE-SearchPro/stargazers"><img src="https://img.shields.io/github/stars/aidenlim-dev/AIOFFICE-SearchPro?style=flat&color=F0B72F" alt="stars"></a>
</p>

<!-- Hero — cinematic key-art: a blocked site (403 / CAPTCHA / WAF) shatters as
     AIOFFICE-SearchPro breaks through and returns real public content with its source. -->
<img src="assets/hero.png" width="860" alt="Cinematic split: on the left a blocked site shows 403 Forbidden, a CAPTCHA, and a WAF wall; it shatters down the middle as AIOFFICE-SearchPro breaks through on the right, returning a real public post from @claudeai (Claude Code Plugins) with its source — no API key.">

</div>

---

## ⚡ Install

For this course / direct GitHub install:

```bash
/plugin marketplace add aidenlim-dev/AIOFFICE-SearchPro
/plugin install aioffice-searchpro@aioffice-searchpro-marketplace
/reload-plugins
```

**Asking an AI agent (including Claude Code itself) to install this?** The slash commands above are interactive-only and unavailable to agents. Have the agent run the non-interactive CLI in a terminal instead:

```bash
claude plugin marketplace add aidenlim-dev/AIOFFICE-SearchPro
claude plugin install aioffice-searchpro@aioffice-searchpro-marketplace
```

Then restart Claude Code or run `/reload-plugins` to load the plugin.

Verify the install from a terminal:

```bash
git clone https://github.com/aidenlim-dev/AIOFFICE-SearchPro.git
cd AIOFFICE-SearchPro
bash setup/doctor.sh
```

Windows PowerShell:

```powershell
git clone https://github.com/aidenlim-dev/AIOFFICE-SearchPro.git
cd AIOFFICE-SearchPro
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\doctor.ps1
```

Optional full browser coverage:

```bash
bash setup/browser.sh
```

Windows PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\browser.ps1
```

When you need the winning HTML for parsing, save it on the same call:

```bash
bash setup/run-engine.sh "https://example.com/" --json --output page.html --metadata page.fetch.json
```

Windows PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\run-engine.ps1 "https://example.com/" --json --output page.html --metadata page.fetch.json
```

For a short classroom handout, use [COURSE_INSTALL.ko.md](COURSE_INSTALL.ko.md).

No commands to learn after install. Ask Claude Code normally — AIOFFICE-SearchPro kicks in when a fetch gets blocked.

## 💬 Try it

Just ask normally — AIOFFICE-SearchPro kicks in when a fetch gets blocked:

> *"Find what people are saying about Claude Code on Reddit and summarize the top threads."*
> *"Search X for posts about AIOFFICE-SearchPro."*
> *"Summarize this YouTube video."*

**Expected:** Claude reaches each site's public route — Reddit's feed, X via oEmbed, YouTube captions — with no login and no API key, and returns usable text, where the same request returns *"I can't access that"* without the plugin.

## 🌐 Works on

**X · Reddit · YouTube · Hacker News · Naver · Coupang · LinkedIn · Medium · Substack · arXiv · GitHub · Stack Overflow · Bluesky · Mastodon** — plus any site with a public page, feed, or `/rss`. Full platform list & methods → [PLATFORMS.md](PLATFORMS.md).

## ⚙️ Why it gets through

- **It escalates, never pre-judges** — public API readers → syndication gateways → TLS impersonation → a real headless browser, trying each route until one works.
- **It looks human** — builds a full browser identity (real TLS fingerprint, cookie warming, referer chain), not just a swapped User-Agent.
- **It finds hidden APIs** — watches the real browser's network traffic and reuses the site's own internal JSON.
- **Zero system-Python setup** — first use creates an isolated plugin venv for `curl_cffi`, `yt-dlp`, and parser dependencies. No API keys, no signup.

## 🆚 Default Claude Code vs `+ AIOFFICE-SearchPro`

| When you hit… | Claude Code alone | `+ AIOFFICE-SearchPro` |
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

| Without it | With AIOFFICE-SearchPro |
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

AIOFFICE-SearchPro is a **reader for public content**, not a way around authentication.

- Reaches what's available through public pages, public APIs, feeds, archives, and a browser's public responses.
- **Stops at logins and paywalls** — it reports `authentication required` instead of trying to defeat them.
- Never logs in as you and never stores or transmits credentials.
- All routes use no-auth public endpoints and standard, documented techniques.

## License

MIT

---

<div align="center">

**Direct GitHub install:** [aidenlim-dev/AIOFFICE-SearchPro](https://github.com/aidenlim-dev/AIOFFICE-SearchPro)

</div>

English | [한국어](README.ko.md) | [中文](README.zh.md) | [日本語](README.ja.md) | [Español](README.es.md)

<div align="center">

# AIOFFICE-SearchPro

<sub>Original project: <a href="https://github.com/fivetaku/insane-search">fivetaku/insane-search</a>. This repository is a fork maintained as the AIOFFICE distribution.</sub>

**A public-page reader for Claude Code and Codex.** No API keys, no proxy setup.

<p>
  <a href="https://docs.anthropic.com/en/docs/claude-code"><img src="https://img.shields.io/badge/platform-Claude_Code-D97757?logo=claude" alt="Claude Code"></a>
  <img src="https://img.shields.io/badge/Codex-supported-10A37F" alt="Codex supported">
  <img src="https://img.shields.io/badge/API_key-not_required-3FB950" alt="No API key">
  <a href="https://github.com/aidenlim-dev/AIOFFICE-SearchPro/stargazers"><img src="https://img.shields.io/github/stars/aidenlim-dev/AIOFFICE-SearchPro?style=flat&color=F0B72F" alt="stars"></a>
</p>

<img src="assets/hero.png" width="860" alt="A blocked site showing 403 Forbidden, a CAPTCHA, and a WAF wall shatters as AIOFFICE-SearchPro breaks through, returning a real public post with its source and no API key.">

</div>

---

When an ordinary fetch hits `403`, a WAF challenge, or a bot wall, your agent normally answers *"I can't access that."* This plugin sits behind that moment: it walks a public-only escalation chain until one route returns real content, then hands back text that is ready to drop into a model's context.

It reads **public** pages. It stops at logins and paywalls and says so.

## Install

**Claude Code** (interactive):

```bash
/plugin marketplace add aidenlim-dev/AIOFFICE-SearchPro
/plugin install aioffice-searchpro@aioffice-searchpro-marketplace
/reload-plugins
```

**Claude Code** (for an agent, or any non-interactive shell - the slash commands above are interactive-only):

```bash
claude plugin marketplace add aidenlim-dev/AIOFFICE-SearchPro
claude plugin install aioffice-searchpro@aioffice-searchpro-marketplace
```

**Codex** - same repo, Codex-native manifest at `.codex-plugin/plugin.json`:

```bash
codex plugin marketplace add https://github.com/aidenlim-dev/AIOFFICE-SearchPro
codex plugin add aioffice-searchpro@aioffice-searchpro-marketplace
```

Restart the agent (or `/reload-plugins`) to load it. The runtime requires [uv](https://docs.astral.sh/uv/getting-started/installation/). First use syncs an isolated uv environment for `curl_cffi`, `yt-dlp`, and parsers, leaving your system Python alone.

### Update an existing installation

Existing users must update both the marketplace and the plugin to receive the latest version. Run these commands in a **separate terminal, not in the Claude Code conversation**. Entering `/plugin update ...` in the conversation opens the plugin manager instead of running the update.

```bash
claude plugin marketplace update aioffice-searchpro-marketplace
claude plugin update aioffice-searchpro@aioffice-searchpro-marketplace
claude plugin list
```

Confirm that the list reports `aioffice-searchpro` version `1.4.0` or newer, then restart Claude Code. An open session can also reload plugins with `/reload-plugins`.

To check an install, run doctor against the installed copy. No second clone needed:

```bash
bash ~/.claude/plugins/marketplaces/aioffice-searchpro-marketplace/setup/doctor.sh
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\plugins\marketplaces\aioffice-searchpro-marketplace\setup\doctor.ps1"
```

Anything listed under OPTIONAL in the doctor summary (Node.js, browser fallback) is not required to use the plugin. Install it only if you want the browser tier: `setup/browser.sh` (macOS/Linux, `--install-node`) or `setup/browser.ps1` (Windows, `-InstallNode`).

Teaching this to a class? See [COURSE_INSTALL.ko.md](COURSE_INSTALL.ko.md).

## Using it

Nothing to learn. Ask your agent normally, and the plugin engages when a fetch gets blocked:

> *"Summarize the top Reddit threads about Claude Code."*
> *"Pull the transcript of this YouTube video."*
> *"Read this Naver blog post."*
> *"Extract the products, prices, and links from this URL into a table."*

If automatic selection is uncertain, invoke the skill explicitly:

```text
/aioffice-searchpro:aioffice-searchpro Extract the product listings from this URL: https://example.com/products
```

To drive the engine directly:

```bash
bash setup/run-engine.sh "https://example.com/"
```

Fetching a page you intend to parse? Save the winning response on the same call, so a probabilistic WAF success is never thrown away and re-requested:

```bash
bash setup/run-engine.sh "https://example.com/" --json --output page.md --metadata page.fetch.json
```

Useful flags - full list via `--help`:

| Flag | Effect |
| :--- | :--- |
| `--output PATH` / `--metadata PATH` | Save content and result JSON from this same attempt |
| `--selector CSS` | Positive proof that the real page loaded, not a challenge shell |
| `--no-markdown` | Return raw HTML instead of converted markdown |
| `--maincontent` | Strip nav/footer/ads down to the article body |
| `--device mobile` | Pin the mobile route |
| `--trace` | Print every attempt and why it failed |

## How it gets through

Four tiers, each running only when the previous one fails or trips a blocking signal:

| Tier | What it does |
| :--- | :--- |
| **Phase 0** | Official public routes a generic crawler can't guess - Reddit `.rss`, X `tweet-result`/oEmbed, YouTube via `yt-dlp`, Threads inline `video_versions` |
| **Phase 1** | Cheap probes: public API readers, syndication gateways, mobile / `.json` / `/rss` URL variants |
| **Phase 2** | TLS impersonation via `curl_cffi`, ordered for fingerprint diversity, with a full browser identity (real TLS fingerprint, cookie warming, referer chain) |
| **Phase 3** | A real browser. Protocol-stealth drivers (nodriver, patchright) for gates that fingerprint automation itself, plus network capture that surfaces the site's own internal JSON APIs |

Nine WAF products are profiled (Cloudflare, Akamai, DataDome, PerimeterX, Kasada, Imperva, AWS WAF, F5, plus a generic challenge profile), and the detected profile decides which browser tier is even worth trying.

A `200` is treated as the *start* of validation, never as success: a four-layer check (marker, size, cookie, your `--selector`) has to agree before the engine calls it a win.

<details>
<summary><strong>Content handling - what you actually get back</strong></summary>

The consumer is usually a model's context window, so the engine cleans up before returning:

- **Markdown by default.** A raw-HTML success is converted to structure-preserving markdown (tables stay tables, code stays fenced). Opt out with `--no-markdown`.
- **PDF and thin-shell rescue.** PDF responses are extracted as text; SPA shells that ship no visible HTML fall back to JSON-LD `articleBody` or the rendered `innerText`. `result.extraction_source` tells you which path ran.
- **Article-body extraction** with `--maincontent` when boilerplate is in the way.
- **Failure diagnosis.** A failed fetch carries `block_class`: `bot_detection` (routes disagree, escalation may help) or `infra_or_auth` (every route uniformly 401/404, so stealth cannot help). Use it to decide whether a retry is worth anything.
- **Untrusted by construction.** Fetched page text is wrapped and labelled as untrusted public web content before it reaches a model, with prompt-injection risk scored.

Missing an optional library? Every path degrades to raw output instead of failing.
</details>

<details>
<summary><strong>Turning a blocked site into a reusable recipe</strong></summary>

HTML is often armored while the site's own JSON API is not. `scripts/endpoint_miner.py` mines endpoints statically; a patchright template captures XHR traffic during render. Save the result as `recipes/<domain>/recipe.yaml` and later fetches skip the grid and go straight to the API.

Set `INSANE_AUTO_FORGE=1` and the engine does this on its own when the chain fails: render, capture XHR, pick the data API by content overlap, reproduce it with curl, and write the recipe. See [references/scraper-forge.md](skills/aioffice-searchpro/references/scraper-forge.md).
</details>

## Where it works

**X · Reddit · YouTube · Threads · Hacker News · Naver · Coupang · LinkedIn · Medium · Substack · arXiv · GitHub · Stack Overflow · Bluesky · Mastodon** - plus any site with a public page, feed, or `/rss`.

Per-platform methods: [PLATFORMS.md](PLATFORMS.md).

## What it will not do

This is a reader for public content, not an authentication bypass.

- **Logins and paywalls stop it.** It returns `authentication required` instead of attempting to defeat them.
- It never logs in as you, and never stores or transmits credentials.
- Every route uses no-auth public endpoints and documented techniques.
- When it genuinely cannot get through, it says which routes it tried and which are left, rather than reporting a confident failure.

## How this fork differs

Forked from [fivetaku/insane-search](https://github.com/fivetaku/insane-search) and maintained as an AIOFFICE distribution. Upstream engine work is ported in; these changes are local:

- **Codex support** - native manifest, local install scripts, and tool-name mapping so both agents behave identically.
- **Anti-detour routing** - the skill is documented as the designated tool for bot-protected sites, so an agent stops reaching for a heavyweight browser first.
- **Profile-aware failure guidance** - escalation advice follows what the detected WAF profile actually needs, instead of always pointing at Playwright MCP.
- **One-shot capture** - `--output` / `--metadata` keep a successful body on first call.
- **OS-native wrappers** - `setup/run-engine.{sh,ps1}` use `uv sync --frozen` to manage an isolated environment on Windows and Unix.
- **Actionable dependency diagnostics** - a missing local Playwright install reports the exact fix instead of a bare "unavailable".

Version history and per-release porting notes: [CHANGELOG.md](CHANGELOG.md).

## License

MIT

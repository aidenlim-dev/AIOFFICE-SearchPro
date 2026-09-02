#!/usr/bin/env bash
# Course/student readiness check for aioffice-searchpro.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_ENGINE="$ROOT/setup/run-engine.sh"
fail=0

ok() { printf 'ok  %s\n' "$1"; }
warn() { printf 'warn %s\n' "$1"; }
bad() { printf 'bad %s\n' "$1"; fail=1; }

if command -v claude >/dev/null 2>&1; then
  ok "Claude Code found: $(claude --version 2>/dev/null | head -n 1)"
  if claude plugin validate "$ROOT" >/dev/null 2>&1; then
    ok "Claude plugin validator passes"
  else
    bad "Claude plugin validation failed: run 'claude plugin validate $ROOT'"
  fi
else
  bad "Claude Code CLI not found. Install Claude Code first."
fi

if [ -f "$ROOT/.claude-plugin/marketplace.json" ]; then
  if command -v claude >/dev/null 2>&1 && claude plugin validate "$ROOT" >/dev/null 2>&1; then
    ok "marketplace/plugin files are present"
  else
    warn "marketplace file is present, but validation could not be confirmed"
  fi
else
  bad ".claude-plugin/marketplace.json is missing"
fi

if [ -f "$ROOT/pyproject.toml" ] && [ -f "$ROOT/uv.lock" ]; then
  ok "uv project and dependency lockfile present"
else
  bad "pyproject.toml or uv.lock is missing"
fi

if command -v uv >/dev/null 2>&1; then
  ok "uv found: $(uv --version)"
else
  bad "uv not found. Install it from https://docs.astral.sh/uv/getting-started/installation/"
fi

if [ -f "$ROOT/skills/aioffice-searchpro/engine/templates/package-lock.json" ]; then
  ok "Node dependency lockfile present"
else
  warn "Node dependency lockfile missing; optional browser setup may drift"
fi

if "$RUN_ENGINE" "https://example.com/" --selector h1 --no-playwright --max-attempts 1 --json >/tmp/aioffice-searchpro-doctor.json 2>/tmp/aioffice-searchpro-doctor.err; then
  ok "engine smoke test passed"
else
  bad "engine smoke test failed"
  sed -n '1,20p' /tmp/aioffice-searchpro-doctor.err >&2
fi

has_node=0
if command -v node >/dev/null 2>&1; then
  has_node=1
  ok "Node.js found: $(node --version)"
else
  warn "Node.js not found; local real-Chrome Playwright fallback will be unavailable"
fi

has_browser_deps=0
if [ -d "$ROOT/skills/aioffice-searchpro/engine/templates/node_modules" ]; then
  has_browser_deps=1
  ok "local Playwright template dependencies installed"
else
  warn "optional browser fallback not fully installed: run 'bash setup/browser.sh'"
fi

has_mcp=0
if command -v claude >/dev/null 2>&1 && claude mcp list 2>/dev/null | grep -qi playwright; then
  has_mcp=1
  ok "Playwright MCP appears configured"
else
  warn "optional Playwright MCP not configured: run 'bash setup/browser.sh'"
fi

echo ""
echo "=== doctor summary ==="
if [ "$fail" -ne 0 ]; then
  echo "CORE: NOT READY - fix the 'bad' items above, then re-run doctor."
else
  echo "CORE: ready - blocked-page reading works now; no further setup is required."
fi
if [ "$has_node" -eq 1 ] && [ "$has_browser_deps" -eq 1 ] && [ "$has_mcp" -eq 1 ]; then
  echo "OPTIONAL browser fallback: fully installed."
else
  echo "OPTIONAL browser fallback: not fully installed. Only needed for heavy JS/WAF sites (Cloudflare/Akamai class); everything else already works."
  echo "  To enable later:"
  if [ "$has_node" -eq 0 ]; then
    echo "    1) Install Node.js 18+ (macOS: brew install node)"
    echo "    2) bash setup/browser.sh   (or let the script install Node: bash setup/browser.sh --install-node)"
  else
    echo "    bash setup/browser.sh"
  fi
  echo "  AI agents: relay this optional gap to the user and ask before installing Node.js or MCP servers - never install system software silently."
fi

exit "$fail"

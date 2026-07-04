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

if [ -f "$ROOT/requirements.lock" ]; then
  ok "Python dependency lockfile present"
else
  bad "requirements.lock is missing"
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

if command -v node >/dev/null 2>&1; then
  ok "Node.js found: $(node --version)"
else
  warn "Node.js not found; local real-Chrome Playwright fallback will be unavailable"
fi

if [ -d "$ROOT/skills/aioffice-searchpro/engine/templates/node_modules" ]; then
  ok "local Playwright template dependencies installed"
else
  warn "optional browser fallback not fully installed: run 'bash setup/browser.sh'"
fi

if command -v claude >/dev/null 2>&1 && claude mcp list 2>/dev/null | grep -qi playwright; then
  ok "Playwright MCP appears configured"
else
  warn "optional Playwright MCP not configured: run 'bash setup/browser.sh'"
fi

exit "$fail"

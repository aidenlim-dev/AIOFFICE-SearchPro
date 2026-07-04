#!/usr/bin/env bash
# Optional full-browser setup for stronger JS/WAF fallbacks.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES="$ROOT/skills/aioffice-searchpro/engine/templates"

ok() { printf 'ok  %s\n' "$1"; }
warn() { printf 'warn %s\n' "$1"; }
die() { printf 'bad %s\n' "$1" >&2; exit 1; }

command -v node >/dev/null 2>&1 || die "Node.js is required. Install Node 18+ first."
command -v npm >/dev/null 2>&1 || die "npm is required. Install Node/npm first."

ok "Node.js found: $(node --version)"
ok "npm found: $(npm --version)"

cd "$TEMPLATES"
npm install
npx patchright install chrome
ok "local real-Chrome Playwright dependencies installed"

if command -v claude >/dev/null 2>&1; then
  if claude mcp list 2>/dev/null | grep -qi '^playwright'; then
    ok "Playwright MCP is already configured"
  else
    claude mcp add playwright -s user -- npx -y @playwright/mcp@latest
    ok "Playwright MCP added at user scope"
  fi
else
  warn "Claude Code CLI not found; skipped Playwright MCP registration"
fi

cat <<'EOF'

Browser setup complete.
Restart Claude Code or run /reload-plugins so newly installed MCP/tools are visible.
EOF

#!/usr/bin/env bash
# Optional full-browser setup for stronger JS/WAF fallbacks.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES="$ROOT/skills/aioffice-searchpro/engine/templates"
NODE_DEPS="${AIOFFICE_SEARCHPRO_NODE_DEPS_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/aioffice-searchpro/node}"

ok() { printf 'ok  %s\n' "$1"; }
warn() { printf 'warn %s\n' "$1"; }
die() { printf 'bad %s\n' "$1" >&2; exit 1; }

# --install-node: install Node.js via Homebrew when missing. Requires explicit
# user consent: agents must ask before passing this flag.
INSTALL_NODE=0
for arg in "$@"; do
  [ "$arg" = "--install-node" ] && INSTALL_NODE=1
done

if ! command -v node >/dev/null 2>&1; then
  if [ "$INSTALL_NODE" -eq 1 ] && command -v brew >/dev/null 2>&1; then
    ok "Installing Node.js via Homebrew..."
    brew install node || die "brew install node failed. Install Node 18+ manually from https://nodejs.org/ and re-run."
  else
    die "Node.js is required. Install Node 18+ first (macOS: re-run with --install-node to install via Homebrew after asking the user)."
  fi
fi
command -v npm >/dev/null 2>&1 || die "npm is required. Install Node/npm first."

ok "Node.js found: $(node --version)"
ok "npm found: $(npm --version)"

mkdir -p "$NODE_DEPS"
cp "$TEMPLATES/package.json" "$TEMPLATES/package-lock.json" "$NODE_DEPS/"
cd "$NODE_DEPS"
PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 PATCHRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
  npm ci --no-audit --no-fund
node -e 'const fs=require("fs"),crypto=require("crypto");const data=fs.readFileSync(process.argv[1]);fs.writeFileSync(process.argv[2],crypto.createHash("sha256").update(data).digest("hex"))' \
  "$NODE_DEPS/package-lock.json" "$NODE_DEPS/.aioffice-searchpro-package-lock"
ok "shared real-Chrome Playwright dependencies installed: $NODE_DEPS"

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

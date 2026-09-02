#!/usr/bin/env bash
# Run the aioffice-searchpro engine through an isolated uv environment.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE_ROOT="$ROOT/skills/aioffice-searchpro"
VENV_DIR="${AIOFFICE_SEARCHPRO_VENV:-${XDG_CACHE_HOME:-$HOME/.cache}/aioffice-searchpro/venv}"

if ! command -v uv >/dev/null 2>&1; then
  echo "aioffice-searchpro: uv is required but was not found: https://docs.astral.sh/uv/getting-started/installation/" >&2
  exit 127
fi

LOG="${VENV_DIR}.install.log"
mkdir -p "$(dirname "$VENV_DIR")"
if ! UV_PROJECT_ENVIRONMENT="$VENV_DIR" \
    uv sync --project "$ROOT" --frozen --no-install-project >"$LOG" 2>&1; then
  cat "$LOG" >&2
  exit 1
fi

cd "$ENGINE_ROOT"
PYTHONPATH="$ENGINE_ROOT${PYTHONPATH:+:$PYTHONPATH}" exec "$VENV_DIR/bin/python" -m engine "$@"

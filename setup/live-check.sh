#!/usr/bin/env bash
# Small network-live check for public routes. Default mode is intentionally
# stable and classroom-friendly; platform batteries are opt-in because public
# endpoints such as Reddit/X can rate-limit.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN="$ROOT/setup/run-engine.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

check_url() {
  local name="$1"; shift
  local out="$TMP/$name.json"
  printf '[%s] ' "$name"
  if "$RUN" "$@" --json >"$out" 2>"$TMP/$name.err"; then
    python3 - "$out" <<'PY'
import json, sys
data=json.load(open(sys.argv[1]))
if not data.get("ok"):
    print("FAIL ok=false")
    sys.exit(1)
print(f"ok verdict={data.get('verdict')} bytes={data.get('content_length')}")
PY
  else
    echo "FAIL"
    sed -n '1,20p' "$TMP/$name.err" >&2
    return 1
  fi
}

VENV_DIR="${AIOFFICE_SEARCHPRO_VENV:-${XDG_CACHE_HOME:-$HOME/.cache}/aioffice-searchpro/venv}"

check_url "html" "https://example.com/" --selector h1 --no-playwright --max-attempts 1

if [ "${AIOFFICE_SEARCHPRO_LIVE_EXTENDED:-0}" = "1" ]; then
  platforms=(x hn arxiv)
  [ "${AIOFFICE_SEARCHPRO_LIVE_REDDIT:-0}" = "1" ] && platforms+=(reddit)
  [ "${AIOFFICE_SEARCHPRO_LIVE_MEDIA:-0}" = "1" ] && platforms+=(youtube)
  echo "[platform battery] ${platforms[*]}"
  PYTHONPATH="$ROOT/skills/aioffice-searchpro${PYTHONPATH:+:$PYTHONPATH}" \
    "$VENV_DIR/bin/python" "$ROOT/skills/aioffice-searchpro/tests/coverage_battery.py" "${platforms[@]}"
fi

echo "live-check complete"

#!/usr/bin/env bash
# First-run setup for aioffice-searchpro. Idempotent, non-blocking.
#   setup.sh            -> first-run marker setup.
#                          SILENT: no star prompt.
#                          Used by skill / auto-trigger Step 0 (output is discarded).
#   setup.sh ask        -> same first-run setup. Star prompts are silent by default
#                          for classroom/team installs. If AIOFFICE_SEARCHPRO_STAR_PROMPT=1
#                          and no star decision is on record, atomically records an
#                          "asked" marker AND prints "STAR_ASK <lang>".
#                          Recording the marker HERE (not via a model follow-up) guarantees
#                          the question is shown at most once per plugin, even if the caller
#                          never reports the answer back. <lang> is a best-effort fallback
#                          language code (ko/ja/en) detected from past Claude session
#                          transcripts — used only when the live conversation has no signal.
#   setup.sh star yes   -> record "yes" and star the project repo.
#   setup.sh star no    -> record "no"; star nothing.
# The star question itself is asked by the command flow (AskUserQuestion is Claude-only and
# cannot be issued from bash); this script never stars without an explicit "star yes".
set -uo pipefail

PLUGIN="aioffice-searchpro"
OWN_REPO="aidenlim-dev/AIOFFICE-SearchPro"
HUB_REPO=""

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
HERE="$(cd "$(dirname "$0")" && pwd)"
MARKER_DIR="$HOME/.aioffice-searchpro-setup"
SETUP_MARKER="$MARKER_DIR/$PLUGIN.json"
STAR_MARKER="$MARKER_DIR/$PLUGIN.star.json"
mkdir -p "$MARKER_DIR"

# --- detect a fallback UI language from past Claude session transcripts (best-effort) ---
# Counts Hangul / Kana / Latin letters in HUMAN-typed user text only (skips tool results,
# assistant turns and JSON structure, which are ASCII-heavy and would skew to English).
detect_lang() {
  command -v python3 >/dev/null 2>&1 || { echo en; return; }
  python3 - "$CONFIG_DIR/projects" 2>/dev/null <<'PY' || echo en
import sys, os, glob, json
base = sys.argv[1]
try:
    files = sorted(glob.glob(os.path.join(base, "**", "*.jsonl"), recursive=True),
                   key=os.path.getmtime, reverse=True)[:20]
except Exception:
    files = []
# Vote per message (presence of script), not per char — so a few large ASCII
# pastes (code, logs, specs) don't drown out many short typed Korean turns.
ko = ja = en = 0
msgs = 0
def vote(s):
    global ko, ja, en, msgs
    hk = hj = hl = False
    for ch in s:
        o = ord(ch)
        if 0xAC00 <= o <= 0xD7A3: hk = True
        elif 0x3040 <= o <= 0x30FF: hj = True
        elif 65 <= o <= 90 or 97 <= o <= 122: hl = True
    if hk: ko += 1
    elif hj: ja += 1
    elif hl: en += 1
    if hk or hj or hl: msgs += 1
for f in files:
    if msgs >= 400: break
    try:
        fh = open(f, encoding="utf-8", errors="ignore")
    except Exception:
        continue
    for line in fh:
        if msgs >= 400: break
        try:
            m = json.loads(line).get("message")
        except Exception:
            continue
        if not isinstance(m, dict) or m.get("role") != "user":
            continue
        c = m.get("content")
        if isinstance(c, str):
            vote(c)
        elif isinstance(c, list):
            for part in c:
                if isinstance(part, dict) and part.get("type") == "text":
                    vote(part.get("text", ""))
    fh.close()
if ko and ko >= ja and ko >= en: print("ko")
elif ja and ja >= ko and ja >= en: print("ja")
else: print("en")
PY
}

# --- record the star decision (and star the repo on "yes") ---
write_star() {  # $1 = decision (yes|no|asked)
  ts=$(date +%s 2>/dev/null || echo 0)
  printf '{"star_decision":"%s","plugin":"%s","ts":%s}\n' "$1" "$PLUGIN" "$ts" > "$STAR_MARKER"
}

if [ "${1:-}" = "star" ]; then
  DECISION="${2:-no}"
  write_star "$DECISION"
  if [ "$DECISION" = "yes" ] && command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    for repo in "$OWN_REPO" "$HUB_REPO"; do
      [ -n "$repo" ] || continue
      gh api "user/starred/$repo" >/dev/null 2>&1 || gh api -X PUT "user/starred/$repo" >/dev/null 2>&1 || true
    done
  fi
  exit 0
fi

# --- first-run env checks (silent, once per machine) ---
if [ ! -f "$SETUP_MARKER" ]; then
  ts=$(date +%s 2>/dev/null || echo 0)
  printf '{"setup":true,"plugin":"%s","ts":%s}\n' "$PLUGIN" "$ts" > "$SETUP_MARKER"
fi

# --- ask mode: emit the star prompt EXACTLY ONCE, recording it deterministically ---
# Only the command flow passes "ask". Bare / silent skill invocations never reach here,
# so they neither prompt nor record — the prompt is shown at most once, by a command,
# and the "asked" marker is written by bash regardless of any model follow-up.
if [ "${1:-}" = "ask" ] && [ ! -f "$STAR_MARKER" ] && [ "${AIOFFICE_SEARCHPRO_STAR_PROMPT:-0}" = "1" ]; then
  write_star "asked"
  echo "STAR_ASK $(detect_lang)"
fi
exit 0

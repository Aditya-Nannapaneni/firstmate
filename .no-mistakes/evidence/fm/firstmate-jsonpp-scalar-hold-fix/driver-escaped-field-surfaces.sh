#!/usr/bin/env bash
# Adversarial: every quoted-scalar field the shared show-scalar decoder reads
# carries escapes, and the operator-facing read surfaces must still resolve the
# captain call correctly. Drives the real fm-captain-hold.sh + bearings board.
# Usage: fm-ishira-escaped-fields.sh <code-root> <label> <out-dir>
set -u
ROOT=$1
LABEL=$2
OUT=$3
FAILURES=0

mkdir -p "$OUT"
HOME_DIR="$OUT/home"
rm -rf "$HOME_DIR"
mkdir -p "$HOME_DIR/data" "$HOME_DIR/state" "$HOME_DIR/config" "$HOME_DIR/projects"
cp "$ROOT/.tasks.toml" "$HOME_DIR/.tasks.toml"
printf '## In flight\n\n## Queued\n\n## Done\n' > "$HOME_DIR/data/backlog.md"
FAKEBIN="$HOME_DIR/fakebin"
mkdir -p "$FAKEBIN"
for tool in tmux treehouse no-mistakes gh gh-axi; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$FAKEBIN/$tool"
  chmod +x "$FAKEBIN/$tool"
done
TASKS_AXI_BIN=$(command -v tasks-axi)
AUDIT=ishira-opus-nlu-audit

tasks_in() { (cd "$HOME_DIR" && tasks-axi "$@"); }
run_captain() {
  PATH="$FAKEBIN:$PATH" REAL_TASKS_AXI="$TASKS_AXI_BIN" \
    FM_HOME="$HOME_DIR" FM_STATE_OVERRIDE="$HOME_DIR/state" \
    FM_DATA_OVERRIDE="$HOME_DIR/data" FM_CONFIG_OVERRIDE="$HOME_DIR/config" \
    FM_CAPTAIN_HOLD_NOW=2026-09-12T00:00:00Z \
    "$ROOT/bin/fm-captain-hold.sh" "$@"
}
run_bearings() {
  PATH="$FAKEBIN:$PATH" FM_HOME="$HOME_DIR" FM_BEARINGS_NOW=2026-09-12T12:00:00Z \
    "$ROOT/bin/fm-bearings-snapshot.sh" --json "$@"
}
check() {  # <what> <expected> <actual>
  if [ "$2" = "$3" ]; then
    printf 'PASS  %s\n' "$1"
  else
    printf 'FAIL  %s\n        expected: %s\n        actual:   %s\n' "$1" "$2" "$3"
    FAILURES=$((FAILURES + 1))
  fi
}

TITLE='Audit the "route" head \ and the Opus NLU review layer'
REASON='captain must pick "harden now" \ or defer the Opus NLU review layer'

printf '=== escaped quoted-scalar fields across the read surfaces: %s ===\n' "$LABEL"
printf 'code root: %s\n\n' "$ROOT"

mkdir -p "$HOME_DIR/data/$AUDIT"
tasks_in add "$AUDIT" "$TITLE" --kind scout --repo ishira --start >/dev/null || exit 90
printf 'done: consolidated NLU research synthesis complete\n' > "$HOME_DIR/state/$AUDIT.status"

run_captain hold "$AUDIT" --reason "$REASON" >/dev/null \
  || { printf 'FAIL  hold refused an escaped reason\n'; exit 1; }

printf -- '--- how tasks-axi shows the escaped scalars ---\n'
tasks_in show "$AUDIT" --full | grep -E '^  (title|hold_reason|hold_kind|body):'
printf -- '--- how the raw backlog persists them ---\n'
grep -F "$AUDIT" "$HOME_DIR/data/backlog.md"
printf '\n'

# `open --identity` decodes the escaped body through the shared decoder and emits
# the hold-set stamp plus the resolution-record count.
identity=$(run_captain open "$AUDIT" --identity 2>&1)
status=$?
check "open --identity resolves an escaped-body captain call (exit 0)" 0 "$status"
check "open --identity reports the hold stamp with no resolution record" \
  "2026-09-12T00:00:00Z#0" "$identity"

# The board surface reads hold_kind/title through the same decoder.
json=$(run_bearings 2>/dev/null) || { printf 'FAIL  bearings snapshot failed\n'; FAILURES=$((FAILURES+1)); json='{}'; }
# The board summary is the product's own "<title>: <reason>" line, elided to
# width, so assert the escaped fragments survive rather than the whole string.
board_title=$(printf '%s' "$json" | jq -r --arg id "$AUDIT" \
  '.decisions_open[] | select(.id == $id) | .summary' 2>/dev/null)
printf 'board summary: %s\n' "$board_title"
case "$board_title" in
  'Audit the "route" head \ and the Opus NLU review layer: captain must pick "harden now" \ '*)
    printf 'PASS  the board surfaces the escaped title and reason unescaped\n' ;;
  *) printf 'FAIL  the board corrupted the escaped title/reason: %s\n' "$board_title"
     FAILURES=$((FAILURES + 1)) ;;
esac
board_verb=$(printf '%s' "$json" | jq -r --arg id "$AUDIT" \
  '.decisions_open[] | select(.id == $id) | .verb' 2>/dev/null)
check "the board classifies it as a captain hold" "captain-hold" "$board_verb"

# `diverged` walks every open call reading hold_kind through the decoder.
div=$(run_captain diverged 2>&1)
check "diverged reads an escaped-scalar row without a decode error (exit 0)" 0 "$?"
case "$div" in
  *"JSON text must be"*) printf 'FAIL  diverged leaked a JSON::PP decode error: %s\n' "$div"; FAILURES=$((FAILURES+1)) ;;
  *) printf 'PASS  diverged emitted no decode error\n' ;;
esac

# The captain registers the decision; the escaped title and reason must survive.
printf 'Harden the "route" head now; the \\ escape path ships behind the audit gate.\n' \
  > "$HOME_DIR/decision.txt"
run_captain answer "$AUDIT" --decision-file "$HOME_DIR/decision.txt" >/dev/null \
  || { printf 'FAIL  the escaped-field captain call could not be answered\n'; FAILURES=$((FAILURES+1)); }

printf -- '\n--- the answered row, raw on disk ---\n'
sed -n '/## Done/,$p' "$HOME_DIR/data/backlog.md"

body=$(tasks_in show "$AUDIT" --full | sed -n 's/^  body: //p' | head -1)
case "$body" in
  *'Harden the \"route\" head now; the \\ escape path ships behind the audit gate.'*)
    printf 'PASS  the recorded decision kept its quotes and single backslash\n' ;;
  *) printf 'FAIL  the recorded decision was corrupted: %s\n' "$body"; FAILURES=$((FAILURES+1)) ;;
esac
# A literal two-character \n would mean the newline decode regressed.
if grep -qF '\n' "$HOME_DIR/data/backlog.md"; then
  printf 'FAIL  a literal backslash-n leaked into the persisted backlog\n'
  FAILURES=$((FAILURES + 1))
else
  printf 'PASS  no literal backslash-n leaked into the persisted backlog\n'
fi

printf '\n=== %s: %s failure(s) ===\n' "$LABEL" "$FAILURES"
[ "$FAILURES" -eq 0 ]

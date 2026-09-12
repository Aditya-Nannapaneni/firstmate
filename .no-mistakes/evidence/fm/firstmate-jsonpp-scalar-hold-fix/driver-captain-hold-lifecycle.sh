#!/usr/bin/env bash
# Drives the real Firstmate captain-hold lifecycle for the Project Ishira Opus
# NLU audit against a given code root, exactly the way an operator does:
#   hold -> complete gate -> fm-teardown.sh cleanup -> fm-captain-hold.sh answer
# Usage: fm-ishira-drive.sh <code-root> <label> <out-dir> [body-flavor]
#   body-flavor: plain (default) | escapes | sentinel
set -u

ROOT=$1
LABEL=$2
OUT=$3
FLAVOR=${4:-plain}

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
EVENT=ishira-event-time-alignment

step() { printf '\n### %s\n' "$*"; }
tasks_in() { (cd "$HOME_DIR" && tasks-axi "$@"); }
run_captain() {
  PATH="$FAKEBIN:$PATH" REAL_TASKS_AXI="$TASKS_AXI_BIN" \
    FM_HOME="$HOME_DIR" FM_STATE_OVERRIDE="$HOME_DIR/state" \
    FM_DATA_OVERRIDE="$HOME_DIR/data" FM_CONFIG_OVERRIDE="$HOME_DIR/config" \
    FM_CAPTAIN_HOLD_NOW=2026-09-12T00:00:00Z \
    "$ROOT/bin/fm-captain-hold.sh" "$@"
}
# FM_GATE_REFUSE_BYPASS=1 is the sanctioned test-harness escape hatch documented
# in bin/fm-gate-refuse-lib.sh: firstmate's own validation runs from a gate
# worktree, so both refusal signals would otherwise fire. The fleet driven here
# is the isolated fixture home above, never a real one.
run_teardown() {
  PATH="$FAKEBIN:$PATH" FM_ROOT_OVERRIDE="$ROOT" FM_HOME="$HOME_DIR" \
    FM_STATE_OVERRIDE="$HOME_DIR/state" FM_DATA_OVERRIDE="$HOME_DIR/data" \
    FM_CONFIG_OVERRIDE="$HOME_DIR/config" FM_GATE_REFUSE_BYPASS=1 \
    "$ROOT/bin/fm-teardown.sh" "$@"
}
write_meta() {
  local id=$1
  cat > "$HOME_DIR/state/$id.meta" <<EOF
window=firstmate:fm-$id
worktree=$HOME_DIR/projects/missing-$id
project=$HOME_DIR/projects/ishira
harness=codex
kind=scout
mode=scout
spawn_gen=fixture-$id
EOF
}

printf '=== Firstmate captain-hold lifecycle: %s (body flavor: %s) ===\n' "$LABEL" "$FLAVOR"
printf 'code root: %s\n' "$ROOT"
printf 'perl: %s / JSON::PP %s / tasks-axi %s\n' \
  "$(perl -e 'print $]')" \
  "$(perl -MJSON::PP -e 'print $JSON::PP::VERSION')" \
  "$(tasks-axi --version)"

step "The completed Opus NLU audit and the parallel event-time work are on the backlog"
mkdir -p "$HOME_DIR/data/$AUDIT" "$HOME_DIR/data/$EVENT"
tasks_in add "$AUDIT" "Audit Project Ishira Opus NLU review layer" \
  --kind scout --repo ishira --start >/dev/null || exit 90
tasks_in add "$EVENT" "Align Project Ishira event-time windows" \
  --kind scout --repo ishira --start >/dev/null || exit 90
write_meta "$AUDIT"
write_meta "$EVENT"
printf 'done: consolidated NLU research synthesis complete\n' > "$HOME_DIR/state/$AUDIT.status"
cat > "$HOME_DIR/data/$AUDIT/report.md" <<'EOF'
# Consolidated Project Ishira NLU research synthesis

The audit is complete. The captain must choose the review-layer hardening plan.
EOF

case "$FLAVOR" in
  escapes)
    cat > "$HOME_DIR/audit-body.txt" <<'EOF'
Audit finding: the "route" classifier drops a literal backslash \ mid-utterance.
Second line after the encoded newline: latency budget is 120ms.
EOF
    tasks_in update "$AUDIT" --body-file "$HOME_DIR/audit-body.txt" >/dev/null || exit 90
    ;;
  sentinel) : ;;  # leave the body empty so tasks-axi shows the "-" sentinel
  plain)
    printf 'Audit scope: Opus NLU review layer.\n' > "$HOME_DIR/audit-body.txt"
    tasks_in update "$AUDIT" --body-file "$HOME_DIR/audit-body.txt" >/dev/null || exit 90
    ;;
esac
printf 'body as tasks-axi shows it before the hold:\n'
tasks_in show "$AUDIT" --full | sed -n 's/^  body: /  body: /p'

step "Captain hold: the audit waits on the review-layer hardening decision"
run_captain hold "$AUDIT" --reason "captain must choose the review-layer hardening plan" \
  || { printf 'FAILED: hold\n'; exit 1; }
printf 'body as tasks-axi shows it after the hold:\n'
tasks_in show "$AUDIT" --full | sed -n 's/^  body: /  body: /p'

step "Completion gate: the audit registers itself as its own captain call"
run_captain complete "$AUDIT" "$AUDIT" || { printf 'FAILED: complete gate\n'; exit 2; }

step "Cleanup (fm-teardown.sh): release the worker, retain the captain call"
run_teardown "$AUDIT" > "$OUT/teardown.out" 2> "$OUT/teardown.err"
teardown_status=$?
if [ "$teardown_status" -ne 0 ]; then
  printf 'FAILED: cleanup exited %s\n' "$teardown_status"
  printf -- '--- teardown stdout ---\n'; cat "$OUT/teardown.out"
  printf -- '--- teardown stderr ---\n'; cat "$OUT/teardown.err"
  printf -- '--- the audit row after the failed cleanup ---\n'
  tasks_in show "$AUDIT" --full
  exit 3
fi
printf -- '--- teardown stdout ---\n'; cat "$OUT/teardown.out"
printf -- '--- the retained audit row ---\n'
tasks_in show "$AUDIT" --full

step "The captain registers the review-layer hardening decision"
cat > "$HOME_DIR/decision.txt" <<'EOF'
Harden the review layer: gate Opus NLU rollout on the "route" classifier audit.
EOF
run_captain answer "$AUDIT" --decision-file "$HOME_DIR/decision.txt" \
  || { printf 'FAILED: answer\n'; exit 4; }
printf -- '--- the answered audit row ---\n'
tasks_in show "$AUDIT" --full

step "The parallel event-time work is untouched"
tasks_in show "$EVENT" --full

printf '\n=== %s: every step of the lifecycle completed ===\n' "$LABEL"

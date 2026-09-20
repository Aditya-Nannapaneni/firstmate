#!/usr/bin/env bash
# Transient live-validation driver (not part of the suite; deleted after the run).
#
# The legacy-incarnation-stamp path, driven for real on both parsers: a landed
# legacy ship record that carries a recorded pr= plus an armed merge poll and a
# pending retirement receipt is torn down with `fm-teardown.sh --legacy-record`.
# That teardown stamps spawn_gen= at the END of the record - after the recorded
# pr= - and then reads the same record back to authenticate the pending receipt
# before removing the poll artifacts.
set -u

. "$(dirname "${BASH_SOURCE[0]}")/.drv-teardown-harness.sh"
. "$(dirname "${BASH_SOURCE[0]}")/.drv-lib.sh"
# shellcheck source=/dev/null
. "$ROOT/bin/fm-pr-lib.sh"

EVID=${EVID:?evidence directory required}
URL=https://github.com/example/repository/pull/17

legacy_case() {  # <name>
  local case_dir=$1
  case_dir=$(make_case "$case_dir")
  write_legacy_meta "$case_dir" no-mistakes ship
  seed_backlog_in_flight "$case_dir"
  wt_commit "$case_dir" "landed legacy work"
  add_fork_with_pushed_branch "$case_dir"
  {
    printf 'pr=%s\n' "$URL"
    printf 'pr_head=%s\n' 0123456789abcdef0123456789abcdef01234567
  } >> "$case_dir/state/task-x1.meta"
  bash -c '
    . "$1/bin/fm-pr-lib.sh"
    fm_pr_poll_prepare "$2" task-x1 github "$3" github.com example/repository 17 "$1/bin/fm-pr-poll.sh" \
      && fm_pr_poll_publish_prepared \
      && fm_pr_poll_snapshot_capture "$2" task-x1 "$1/bin/fm-pr-poll.sh" \
      && fm_pr_poll_retirement_publish "$2" task-x1 "$1/bin/fm-pr-poll.sh" merged
  ' _ "$ROOT" "$case_dir/state" "$URL" \
    || fail "$case_dir: could not arm the poll and its pending retirement receipt"
  printf '%s\n' "$case_dir"
}

teardown_with_root() {  # <root> <case-dir>
  local root=$1 case_dir=$2
  FM_ROOT_OVERRIDE="$root" \
  FM_STATE_OVERRIDE="$case_dir/state" \
  FM_DATA_OVERRIDE="$case_dir/data" \
  FM_CONFIG_OVERRIDE="$case_dir/config" \
  PATH="$case_dir/fakebin:${FM_TEARDOWN_TEST_PATH:-$PATH}" \
    "$root/bin/fm-teardown.sh" task-x1 --legacy-record
}

report() {  # <label> <root> <case-dir>
  local label=$1 root=$2 case_dir=$3 rc=0 out
  printf '\n--- fm-teardown.sh task-x1 --legacy-record, %s ---\n' "$label"
  out=$(teardown_with_root "$root" "$case_dir" 2>&1) || rc=$?
  printf '%s\n' "$out" | sed "s%$case_dir%<case>%g;s/^/    /"
  printf '    exit status: %s\n' "$rc"
  printf '    backlog row: %s\n' "$(backlog_row_state "$case_dir")"
  printf '    task record left behind: %s\n' \
    "$([ -e "$case_dir/state/task-x1.meta" ] && echo yes || echo no)"
  printf '    retirement receipt left behind: %s\n' \
    "$([ -e "$case_dir/state/task-x1.pr-poll-retirement" ] && echo yes || echo no)"
  printf '    worktree already returned: %s\n' \
    "$([ -d "$case_dir/wt" ] && echo no || echo yes)"
  if [ -e "$case_dir/state/task-x1.meta" ]; then
    drv_record "record the refusal left on disk" "$case_dir/state/task-x1.meta"
    cp "$case_dir/state/task-x1.meta" "$EVID/teardown-legacy-stamp-refused-record.meta"
  fi
}

base_case=$(legacy_case legacy-poll-receipt-base)
fixed_case=$(legacy_case legacy-poll-receipt-fixed)
printf '=== landed legacy ship record with a recorded PR and a pending poll receipt ===\n'
drv_record "record before teardown" "$fixed_case/state/task-x1.meta"
report 'BASE-COMMIT parser (a09090d)' "$DRV_BASE_ROOT" "$base_case"
report 'FIXED parser (7f19993)' "$DRV_TARGET_ROOT" "$fixed_case"
printf '\nDRIVER COMPLETE\n'

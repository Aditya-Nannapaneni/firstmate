#!/usr/bin/env bash
# Transient live-validation driver (not part of the suite; deleted after the run).
#
# One real watcher cycle per post-`pr=` record shape, on the base-commit parser
# and on the fixed one, so the captain-visible wake reason is the comparison:
#   - the shapes a legitimate writer produces must reach "merged",
#   - every other shape must still be refused, on BOTH parsers.
# Each shape gets its own home with a real armed merge poll and a merged PR.
set -u

. "$(dirname "${BASH_SOURCE[0]}")/.drv-security-harness.sh"
. "$(dirname "${BASH_SOURCE[0]}")/.drv-lib.sh"

EVID=${EVID:?evidence directory required}
URL=https://github.com/example/repository/pull/17
HEAD=0123456789abcdef0123456789abcdef01234567

# A home whose task recorded that PR, armed its merge poll, and then had <lines>
# appended to the END of its record - where every writer appends.
armed_home() {  # <name> <appended-lines>
  local name=$1 appended=$2 dir state
  dir=$(make_case "$name")
  state="$dir/home/state"
  fm_write_meta "$state/task-a.meta" \
    "window=fm-task-a" "endpoint_task_id=task-a" "worktree=$dir/wt" \
    "kind=ship" "mode=no-mistakes" "pr=$URL" "pr_head=$HEAD"
  seed_canonical_poll "$dir" task-a "$URL"
  fm_pr_poll_artifacts_valid "$state" task-a "$POLL" \
    || fail "$name: the armed poll was not authenticated before the append"
  printf '%s\n' "$appended" >> "$state/task-a.meta"
  printf '%s\n' "$dir"
}

one_cycle() {  # <root> <dir>
  local root=$1 dir=$2
  drv_watch "$root" "$dir/home" "$dir/fakebin" "$dir/watch.out" \
    FM_TEST_GH_LOG="$dir/gh.log" FM_TEST_GH_STATE=MERGED || true
  sed -e "s%$dir/home/state/%<state>/%g" "$dir/watch.out" | tr -d '\n'
}

run_shape() {  # <name> <expectation> <writer> <appended-lines>
  local name=$1 expect=$2 writer=$3 appended=$4 base_dir fixed_dir base fixed armed
  base_dir=$(armed_home "$name-base" "$appended")
  fixed_dir=$(armed_home "$name-fixed" "$appended")
  base=$(one_cycle "$DRV_BASE_ROOT" "$base_dir")
  fixed=$(one_cycle "$DRV_TARGET_ROOT" "$fixed_dir")
  armed=$(ls "$fixed_dir/home/state" | grep -c 'pr-poll$')
  printf '\n### %s\n' "$name"
  printf '    writer          : %s\n' "$writer"
  printf '    appended after pr=: %s\n' "$(printf '%s' "$appended" | tr '\n' '|')"
  printf '    expectation     : %s\n' "$expect"
  printf '    base a09090d    : %s\n' "$base"
  printf '    fixed 7f19993   : %s\n' "$fixed"
  printf '    poll left armed after the fixed cycle: %s\n' "$armed"
  case "$expect" in
    merged)
      case "$fixed" in
        *': merged') printf '    RESULT: PASS (fixed detects the merge)\n' ;;
        *) printf '    RESULT: FAIL (fixed did not detect the merge)\n' ;;
      esac
      ;;
    refused)
      case "$fixed" in
        *'rejected unauthenticated state checks'*)
          case "$base" in
            *'rejected unauthenticated state checks'*)
              printf '    RESULT: PASS (still refused, on both parsers)\n' ;;
            *) printf '    RESULT: FAIL (base did not refuse this shape)\n' ;;
          esac
          ;;
        *) printf '    RESULT: FAIL (fixed accepted a shape that must stay refused)\n' ;;
      esac
      ;;
  esac
}

printf '=== post-pr= record shapes, one real bin/fm-watch.sh cycle each ===\n'

run_shape legacy-incarnation-stamp merged \
  'bin/fm-teardown.sh --legacy-record (spawn_gen stamp)' \
  'spawn_gen=s1700000000.1234.5678'
run_shape decision-attestation merged \
  'bin/fm-captain-hold.sh complete (decision attestation pair)' \
  "$(printf 'decisions_reviewed=1\ndecision_keys=sample-held-call')"
run_shape relaunch-transaction merged \
  'bin/fm-spawn.sh --relaunch (control_relaunch_tx)' \
  'control_relaunch_tx=1361.20260920T115139Z.14154'
run_shape trace-carrier merged \
  'bin/fm-spawn.sh --relaunch (traceparent on a trace-enabled home)' \
  'traceparent=00-b4ef836375c302ce564f290e8bb7e4cc-318194d797e50bd5-01'
run_shape x-request-link merged \
  'bin/fm-x-lib.sh (pre-existing tolerated link fields)' \
  "$(printf 'x_request=request-fixture\nx_request_ts=1700000000\nx_platform=x')"

run_shape unknown-field refused \
  'no owner - an unrecognised writer rewrote the record' \
  'unrecognised_field=fixture'
run_shape promote-kind-mode-yolo refused \
  'bin/fm-promote.sh fields, which must stay refused after a recorded pr=' \
  "$(printf 'kind=ship\nmode=no-mistakes\nyolo=off')"
run_shape second-pr-identity refused \
  'a forged second PR identity appended after the tolerated relaunch key' \
  "$(printf 'control_relaunch_tx=tx\npr=https://github.com/attacker/repo/pull/99')"
run_shape malformed-pr-head refused \
  'a malformed pr_head after the recorded pr=' \
  'pr_head=not-a-commit-sha'
run_shape tolerated-key-then-unknown refused \
  'a tolerated key used as a prefix to smuggle an unknown one' \
  "$(printf 'control_relaunch_tx=tx\nspawn_gen=s1\nharness=attacker-controlled')"

printf '\nDRIVER COMPLETE\n'

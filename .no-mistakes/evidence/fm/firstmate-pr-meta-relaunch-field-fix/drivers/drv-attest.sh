#!/usr/bin/env bash
# Transient live-validation driver (not part of the suite; deleted after the run).
#
# The decision-attestation writer, driven for real: a ship task that recorded a
# PR and armed its merge poll answers a captain-held decision, and
# `fm-captain-hold.sh complete` appends decisions_reviewed=/decision_keys= to the
# END of that record - after the recorded pr=. The REAL bin/fm-watch.sh then
# cycles over the home on the base-commit parser and on the fixed one.
set -u

. "$(dirname "${BASH_SOURCE[0]}")/.drv-captain-harness.sh"
. "$(dirname "${BASH_SOURCE[0]}")/.drv-lib.sh"
# shellcheck source=/dev/null
. "$ROOT/bin/fm-pr-lib.sh"

EVID=${EVID:?evidence directory required}
URL=https://github.com/example/repository/pull/17
HEAD=0123456789abcdef0123456789abcdef01234567

attested_home() {  # <name> <id>
  local name=$1 id=$2 home
  home=$(make_home "$name")
  mkdir -p "$home/data/$id" "$home/wt"
  tasks_in "$home" add "$id" "Ship the sample change" --kind ship --repo sample --start >/dev/null \
    || fail "$name: could not create the backlog row"
  write_origin_meta "$home" "$id" ship
  {
    printf 'pr=%s\n' "$URL"
    printf 'pr_head=%s\n' "$HEAD"
  } >> "$home/state/$id.meta"
  cat > "$home/state/$id.status" <<'EOF'
working: change pushed and the PR is open
needs-decision [key=route]: merge now or wait for the second reviewer
EOF
  bash -c '
    . "$1/bin/fm-pr-lib.sh"
    fm_pr_poll_prepare "$2" "$4" github "$3" github.com example/repository 17 "$1/bin/fm-pr-poll.sh" \
      && fm_pr_poll_publish_prepared \
      && fm_pr_poll_artifacts_valid "$2" "$4" "$1/bin/fm-pr-poll.sh"
  ' _ "$ROOT" "$home/state" "$URL" "$id" \
    || fail "$name: could not arm an authenticated merge poll"
  run_captain "$home" hold sample-route-call \
    --title "Merge now or wait for the second reviewer" \
    --reason "captain must choose before the merge" --repo sample --origin "$id" >/dev/null \
    || fail "$name: could not register the captain-held decision"
  FM_STATE_OVERRIDE="$home/state" bash -c '
    . "$1"; fm_wake_status_mark_current "$2" "$3"
  ' _ "$ROOT/bin/fm-wake-lib.sh" "$home/state" "$home/state/$id.status" \
    || fail "$name: could not prime the announced decision baseline"
  run_captain "$home" complete "$id" sample-route-call > "$home/complete.out" 2>&1 \
    || fail "$name: fm-captain-hold.sh complete failed: $(cat "$home/complete.out")"
  drv_install_gh_stub "$home/fakebin" || fail "$name: could not install the gh stub"
  printf '%s\n' "$home"
}

base_home=$(attested_home attest-base task-b)
fixed_home=$(attested_home attest-fixed task-f)

printf '=== real fm-captain-hold.sh complete on a ship task with an armed merge poll ===\n'
printf '\n--- fm-captain-hold.sh complete (real) ---\n'
sed 's/^/    /' "$fixed_home/complete.out"
drv_record "task record after the real attestation appended to it" "$fixed_home/state/task-f.meta"

printf '\n--- one real bin/fm-watch.sh cycle, BASE-COMMIT parser (a09090d) ---\n'
drv_watch "$DRV_BASE_ROOT" "$base_home" "$base_home/fakebin" "$base_home/watch.out" \
  FM_TEST_GH_LOG="$base_home/gh.log" FM_TEST_GH_STATE=MERGED || true
sed "s%$base_home/state/%<state>/%g" "$base_home/watch.out" | sed 's/^/    /'
printf '    merge poll left armed: %s\n' "$(ls "$base_home/state" | grep -c 'pr-poll$')"

printf '\n--- one real bin/fm-watch.sh cycle, FIXED parser (7f19993) ---\n'
drv_watch "$DRV_TARGET_ROOT" "$fixed_home" "$fixed_home/fakebin" "$fixed_home/watch.out" \
  FM_TEST_GH_LOG="$fixed_home/gh.log" FM_TEST_GH_STATE=MERGED || true
sed "s%$fixed_home/state/%<state>/%g" "$fixed_home/watch.out" | sed 's/^/    /'
printf '    merge poll left armed: %s (0 = retired on detection)\n' \
  "$(ls "$fixed_home/state" | grep -c 'pr-poll$')"

cp "$fixed_home/state/task-f.meta" "$EVID/captain-hold-attested-record.meta"
printf '\nDRIVER COMPLETE\n'

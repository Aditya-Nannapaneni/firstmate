#!/usr/bin/env bash
# Transient live-validation driver (not part of the suite; deleted after the run).
#
# Drives the reported failure the way the captain hits it:
#   1. a ship task records a PR and arms its merge poll,
#   2. `fm-control <id> relaunch` really runs (stubbed session provider),
#   3. the REAL bin/fm-watch.sh then cycles over that home.
# Each (trace mode, parser) pair gets its own freshly relaunched home, so the
# base-commit transcript and the fixed transcript are both first reads of an
# untouched home. The watcher's own stdout is the captain-visible surface.
set -u

. "$(dirname "${BASH_SOURCE[0]}")/.drv-relaunch-harness.sh"
. "$(dirname "${BASH_SOURCE[0]}")/.drv-lib.sh"
# shellcheck source=/dev/null
. "$ROOT/bin/fm-pr-lib.sh"

EVID=${EVID:?evidence directory required}
URL=https://github.com/example/repo/pull/45
HEAD=0123456789abcdef0123456789abcdef01234567

# A ship task that recorded a PR, armed its merge poll, and was then really
# relaunched. Echoes the case directory.
relaunched_case() {  # <trace-mode> <id>
  local trace=$1 id=$2 dir meta rc out
  dir=$(new_case "live-$trace-$id" "$id")
  add_ship_task "$dir" "$id" claude
  meta="$dir/home/state/$id.meta"
  {
    printf 'pr=%s\n' "$URL"
    printf 'pr_head=%s\n' "$HEAD"
  } >> "$meta"
  if [ "$trace" = on ]; then
    printf '%s\n' "$$" > "$dir/home/state/.lock"
    printf '%s on\n' "$$" > "$dir/home/state/.trace-context-effective"
  fi
  bash -c '
    . "$1/bin/fm-pr-lib.sh"
    fm_pr_poll_prepare "$2" "$4" github "$3" github.com example/repo 45 "$1/bin/fm-pr-poll.sh" \
      && fm_pr_poll_publish_prepared
  ' _ "$ROOT" "$dir/home/state" "$URL" "$id" \
    || fail "could not arm the merge poll for $id"
  rc=0
  out=$(run_control "$dir" "$id" relaunch --note "keep the armed merge poll authenticated") || rc=$?
  [ "$rc" -eq 0 ] || fail "the relaunch itself failed for $id: $out"
  printf '%s\n' "$out" > "$dir/relaunch.out"
  drv_install_gh_stub "$dir/fakebin" || fail "could not install the gh stub"
  : > "$dir/gh.log"
  printf '%s\n' "$dir"
}

drive() {  # <trace-mode>
  local trace=$1 base_dir fixed_dir
  printf '\n================ trace context %s ================\n' "$trace"
  base_dir=$(relaunched_case "$trace" "b$trace")
  fixed_dir=$(relaunched_case "$trace" "f$trace")

  printf '\n--- fm-control relaunch (real, stubbed session provider) ---\n'
  sed 's/^/    /' "$fixed_dir/relaunch.out"
  drv_record "task record after the real relaunch rewrote it" "$fixed_dir/home/state/f$trace.meta"

  drv_watch_until_poll "$DRV_BASE_ROOT" "$base_dir/home" "$base_dir/fakebin" \
    "watcher on the BASE-COMMIT parser (a09090d)" 3 FM_FAKE_DIR="$base_dir/fake"
  printf '    poll still armed after the base cycles: %s\n' \
    "$(ls "$base_dir/home/state" | grep -c 'pr-poll$')"

  drv_watch_until_poll "$DRV_TARGET_ROOT" "$fixed_dir/home" "$fixed_dir/fakebin" \
    "watcher on the FIXED parser (7f19993)" 3 FM_FAKE_DIR="$fixed_dir/fake"
  printf '    merge poll sidecar remaining after the fixed cycles: %s (0 = retired on detection)\n' \
    "$(ls "$fixed_dir/home/state" | grep -c 'pr-poll$')"
  printf '\n--- durable merge outcome the fixed run left for the captain ---\n'
  { grep -o 'merged[^\t]*' "$fixed_dir/home/state/terminal-outcomes" 2>/dev/null \
    || printf '(none)\n'; } | sed 's/^/    /'
  { cat "$fixed_dir/home/state/terminal-outcomes" 2>/dev/null || true; } | sed 's/^/    /'

  cp "$base_dir/watch-watcher on the BASE-COMMIT parser (a09090d).log" \
    "$EVID/relaunch-trace-$trace-watcher-base-commit.log" 2>/dev/null || true
  cp "$fixed_dir/watch-watcher on the FIXED parser (7f19993).log" \
    "$EVID/relaunch-trace-$trace-watcher-fixed.log" 2>/dev/null || true
  cp "$fixed_dir/home/state/f$trace.meta" "$EVID/relaunch-trace-$trace-record.meta"
}

drive off
drive on
printf '\nDRIVER COMPLETE\n'

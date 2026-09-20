#!/usr/bin/env bash
# Transient live-validation helper (not part of the suite; deleted after the run).
#
# Shared pieces for the post-`pr=` record-contract drivers: the real gh stub the
# merge poll answers to, and a bounded run of the REAL bin/fm-watch.sh against a
# chosen bin/ root, so the same home can be driven through the base-commit parser
# and the fixed one and the two watcher transcripts compared.

DRV_BASE_PATH=${DRV_BASE_PATH:-/usr/bin:/bin:/usr/sbin:/sbin}
DRV_TARGET_ROOT=$ROOT
DRV_BASE_ROOT=${DRV_BASE_ROOT:-/tmp/fm-base-root}

# The same gh stub tests/fm-pr-check-security.test.sh drives its watcher cycles
# with, lifted verbatim so the poll sees the contract the real CLI answers with.
drv_install_gh_stub() {  # <fakebin>
  local fakebin=$1
  awk '/cat > "\$fakebin\/gh" <</ {f=1; next} f && /^SH$/ {exit} f {print}' \
    "$ROOT/tests/fm-pr-check-security.test.sh" > "$fakebin/gh"
  [ -s "$fakebin/gh" ] || return 1
  chmod +x "$fakebin/gh"
}

# One bounded cycle of the real watcher. Echoes its stdout (the wake reason the
# captain sees) and returns its exit code.
drv_watch() {  # <root> <home> <fakebin> <out> [extra env assignments...]
  local root=$1 home=$2 fakebin=$3 out=$4
  shift 4
  perl -e 'my $pid=fork; die unless defined $pid; if (!$pid) { exec @ARGV }
    local $SIG{ALRM}=sub { kill "TERM", $pid; waitpid $pid, 0; exit 124 };
    alarm 20; waitpid $pid, 0; alarm 0; exit($? >> 8)' \
    env FM_HOME="$home" FM_ROOT_OVERRIDE="$root" FM_CHECK_INTERVAL=0 FM_CHECK_TIMEOUT=1 \
      FM_POLL=0.02 FM_HEARTBEAT=999999 FM_SIGNAL_GRACE=0 \
      FM_TEST_GH_LOG="$home/../gh.log" FM_TEST_GH_STATE=MERGED \
      "$@" PATH="$fakebin:$DRV_BASE_PATH" "$root/bin/fm-watch.sh" \
      > "$out" 2> "$out.err"
}

# Acknowledge the row a wake queued, so the next cycle is not spent resurfacing
# the previous one (the same drain the suite's own watcher cases use).
drv_ack() {  # <state>
  local state=$1 err sequence generation
  err="$state/.drv-wake-drain.err"
  FM_STATE_OVERRIDE="$state" "$ROOT/bin/fm-wake-drain.sh" >/dev/null 2> "$err" || return 1
  sequence=$(sed -n 's/^WAKE_ACK_REQUIRED:.*--ack-through \([0-9][0-9]*\) --recovery-generation [A-Za-z0-9._-][A-Za-z0-9._-]*$/\1/p' "$err")
  generation=$(sed -n 's/^WAKE_ACK_REQUIRED:.*--ack-through [0-9][0-9]* --recovery-generation \([A-Za-z0-9._-][A-Za-z0-9._-]*\)$/\1/p' "$err")
  rm -f "$err"
  [ -n "$sequence" ] && [ -n "$generation" ] || return 1
  FM_STATE_OVERRIDE="$state" "$ROOT/bin/fm-wake-drain.sh" --ack-through "$sequence" \
    --recovery-generation "$generation"
}

# Cycle the real watcher until the merge poll reports, up to <cycles> times, and
# print every wake reason the captain would receive on the way.
drv_watch_until_poll() {  # <root> <home> <fakebin> <label> <cycles> [env...]
  local root=$1 home=$2 fakebin=$3 label=$4 cycles=$5
  shift 5
  local i out reason
  out="$home/../watch-$label.out"
  : > "$home/../watch-$label.log"
  for i in $(seq 1 "$cycles"); do
    drv_watch "$root" "$home" "$fakebin" "$out" "$@" || true
    reason=$(cat "$out")
    printf 'cycle %s: %s\n' "$i" "${reason:-(no wake)}" >> "$home/../watch-$label.log"
    case "$reason" in
      *merged*|*"rejected unauthenticated state checks"*) ;;
    esac
    drv_ack "$home/state" >/dev/null 2>&1 || true
    case "$reason" in
      *merged*) break ;;
    esac
  done
  drv_show "$label" "$home/../watch-$label.log"
}

drv_show() {  # <label> <file>
  printf '\n--- %s ---\n' "$1"
  sed 's/^/    /' "$2"
}

drv_record() {  # <label> <meta>
  printf '\n--- %s ---\n' "$1"
  grep -n '' "$2" | sed 's/^/    /'
}

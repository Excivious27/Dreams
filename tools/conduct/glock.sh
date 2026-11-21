#!/usr/bin/env bash
# glock.sh [-t secs] [-n nice] [-x] [--slot 0|1] -- <command...>
# Run a godot command under one of TWO lock slots (/tmp/godot.lock.0 / .1, whichever is free
# first), with a fresh XDG_DATA_HOME (own user:// save), PATH+=/home/claude/tools, nice.
#   -t secs   timeout (default 600)        -n nice  niceness (default 5; auditors 15)
#   -x        wrap in `xvfb-run -a` (screenshots); a trap kills that Xvfb on exit/timeout/signal
#   --slot N  use only that slot
# Compat: old agents still use the single /tmp/godot.lock. Slot 0 IS that lane: it takes
# /tmp/godot.lock.0 AND /tmp/godot.lock (both non-blocking), so old-style
# `flock /tmp/godot.lock ...` runs and slot 0 serialize; slot 1 (/tmp/godot.lock.1) is the
# second lane. At most 2 godot runs at once on the 2 CPUs. Never kill lock holders you did not start.
# Exit code: the command's (124 on timeout, 125 if no slot within GLOCK_WAIT secs, default 3600).
set -uo pipefail
T=600; NI=5; XV=0; SLOTS="0 1"
while [ $# -gt 0 ]; do
  case "$1" in
    -t) T="$2"; shift 2 ;;
    -n) NI="$2"; shift 2 ;;
    -x) XV=1; shift ;;
    --slot) SLOTS="$2"; shift 2 ;;
    --) shift; break ;;
    *) break ;;
  esac
done
[ $# -gt 0 ] || { echo "usage: glock.sh [-t s] [-n nice] [-x] -- cmd..."; exit 2; }
export PATH="$PATH:/home/claude/tools"
XDG=$(mktemp -d /tmp/glock_xdg.XXXXXX); export XDG_DATA_HOME="$XDG"
WAIT="${GLOCK_WAIT:-3600}"; T0=$(date +%s); SLOT=""
LB="${GLOCK_BASE:-/tmp/godot.lock}"  # test override: GLOCK_BASE=/tmp/x uses /tmp/x, /tmp/x.0, /tmp/x.1
exec 8>>"$LB"
while :; do
  for s in $SLOTS; do
    exec 9>>"$LB.$s"
    if flock -n 9; then
      if [ "$s" != 0 ] || flock -n 8; then SLOT=$s; break 2; fi
      flock -u 9
    fi
  done
  [ $(( $(date +%s) - T0 )) -ge "$WAIT" ] && { echo "glock: no free slot after ${WAIT}s"; rm -rf "$XDG"; exit 125; }
  sleep 2
done
echo "glock: slot $SLOT (waited $(( $(date +%s) - T0 ))s)" >&2
CPID=""
cleanup() {
  [ -n "$CPID" ] && kill -TERM -- "-$CPID" 2>/dev/null
  # Xvfb started by our xvfb-run: it is in our process group, but xvfb-run killed by timeout
  # leaves it behind; find it by the auth file under our XDG-less temp dir parent pid.
  for p in $(pgrep -f "Xvfb" 2>/dev/null); do
    if tr '\0' '\n' < /proc/$p/environ 2>/dev/null | grep -qx "GLOCK_TAG=$XDG"; then kill "$p" 2>/dev/null; fi
  done
  rm -rf "$XDG"
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP
export GLOCK_TAG="$XDG"
if [ "$XV" = 1 ]; then
  setsid nice -n "$NI" timeout -k 10 "$T" xvfb-run -a "$@" &
else
  setsid nice -n "$NI" timeout -k 10 "$T" "$@" &
fi
CPID=$!
wait "$CPID"; RC=$?
CPID=""
exit $RC

#!/usr/bin/env bash
# linux_boot_check.sh <binary> (S1 P4, 09-05): boot test for the exported Linux build
# the way the Deck runs it. Used by the Linux CI job (deploy.yml; wiring = P1 hook).
#  1) headless: exit code must be 0 (a crash/timeout fails) and no script/load errors;
#     wall time = first-launch time.
#  2) xvfb 1280x800 with SteamDeck=1 and the real opengl3 renderer, Movie Maker frames:
#     the last frame must be 1280x800 (fills the panel even without a window manager)
#     and not one flat colour (the title drew).
# Prints "LINUX BOOT: ok size=<MB> boot_ms=<n> deck_fullscreen=yes" (and to
# $GITHUB_STEP_SUMMARY when set), or "LINUX BOOT: FAIL ..." and exits 1.
set -u
BIN="${1:?usage: linux_boot_check.sh <binary>}"
D="$(mktemp -d)"
ERR='SCRIPT ERROR|Parse Error|Failed to load|^ERROR: '
# Known-benign engine lines on a CI box (no audio device, no vsync, leak report at exit).
BENIGN='ALSA|PulseAudio|audio driver|vsync|ObjectDB instances leaked|resources still in use|Movie Maker|XInput|xrandr|swrast|GLX|at: '
fail() { echo "LINUX BOOT: FAIL $*"; exit 1; }
t0=$(date +%s%3N)
XDG_DATA_HOME="$D/h" timeout 120 "$BIN" --headless --quit-after 300 > "$D/headless.log" 2>&1
rc=$?
boot_ms=$(( $(date +%s%3N) - t0 ))
tail -n 20 "$D/headless.log"
[ $rc -eq 0 ] || fail "headless exit code $rc (124 = timeout)"
if grep -E "$ERR" "$D/headless.log" | grep -vE "$BENIGN"; then fail "errors in the headless boot log"; fi
mkdir -p "$D/mov"
SteamDeck=1 XDG_DATA_HOME="$D/x" timeout 300 xvfb-run -a -s "-screen 0 1280x800x24" "$BIN" --rendering-driver opengl3 \
  --quit-after 600 --write-movie "$D/mov/boot.png" > "$D/xvfb.log" 2>&1
rc=$?
[ $rc -eq 0 ] || { tail -n 30 "$D/xvfb.log"; fail "xvfb opengl3 run exit code $rc"; }
if grep -E "SCRIPT ERROR|Parse Error|Failed to load" "$D/xvfb.log"; then fail "script errors in the xvfb run"; fi
last="$(ls "$D/mov"/*.png 2>/dev/null | sort | tail -n 1)"
[ -n "$last" ] || fail "no Movie Maker frames"
python3 - "$last" <<'PY' || fail "last frame check (see above)"
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
print("last frame", im.size)
if im.size != (1280, 800):
    sys.exit("frame is %sx%s, not 1280x800 (window did not fill the panel)" % im.size)
if len(set(im.resize((64, 40)).getdata())) < 8:
    sys.exit("frame is (almost) one flat colour: the title did not draw")
PY
size_mb=$(( $(stat -c %s "$BIN") / 1048576 ))
line="LINUX BOOT: ok size=${size_mb}MB boot_ms=${boot_ms} deck_fullscreen=yes"
echo "$line"
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && echo "### $line" >> "$GITHUB_STEP_SUMMARY"
rm -rf "$D"
exit 0

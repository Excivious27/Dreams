#!/usr/bin/env bash
# net_e2e.sh [url]: two headless Godot instances (host + guest) play together through a relay
# with scripts/net.gd (tools/net_e2e_test.gd). Default url: the live relay (NetNode.DEFAULT_URL).
# Checks: join by code, late-join world snapshot from the relay, guest on the host's clock,
# both puppets, the guest moves and the host sees it. Prints "NET E2E: ok, <s>s" or
# "NET E2E: FAIL ..." (exit 1). Logs in $NET_E2E_DIR (default a temp dir).
# Runs in CI's relay job when scripts/net.gd or server/ changed (conduct-ci.yml).
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
URL="${1:-}"
D="${NET_E2E_DIR:-$(mktemp -d)}"; mkdir -p "$D"; rm -f "$D/code" "$D/guest_done"
T0=$(date +%s)
XDG_DATA_HOME="$D/xh" timeout 200 "$GODOT" --headless --path . -s res://tools/net_e2e_test.gd -- host "$URL" "$D" > "$D/host.log" 2>&1 &
HP=$!
for i in $(seq 1 120); do [ -s "$D/code" ] && break; sleep 1; done
XDG_DATA_HOME="$D/xg" timeout 200 "$GODOT" --headless --path . -s res://tools/net_e2e_test.gd -- guest "$URL" "$D" > "$D/guest.log" 2>&1
GR=$?
wait $HP; HR=$?
grep -E "^  (ok|FAIL) |NET E2E|SCRIPT ERROR" "$D/host.log" "$D/guest.log" | sed "s#$D/##"
if [ $HR = 0 ] && [ $GR = 0 ] && grep -q "NET E2E host OK" "$D/host.log" && grep -q "NET E2E guest OK" "$D/guest.log" && ! grep -q "SCRIPT ERROR" "$D/host.log" "$D/guest.log"; then
  echo "NET E2E: ok, $(( $(date +%s) - T0 ))s"; exit 0
fi
echo "NET E2E: FAIL (host rc=$HR, guest rc=$GR; logs in $D)"; exit 1

#!/usr/bin/env bash
# Import the project and run the smoke test. Fails on any script error.
set -uo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."

echo "== import =="
"$GODOT" --headless --path . --import 2>&1 | tail -n 30

echo "== smoke test =="
out="$("$GODOT" --headless --path . -s res://tools/smoke_test.gd 2>&1)"
code=$?
echo "$out"

if [ $code -ne 0 ]; then
  echo "Smoke test exited with $code"; exit 1
fi
# Exit-time "still in use"/"leaked" notes come from coroutines cut off by quit(); not failures.
# (no grep -q here: with pipefail an early exit from -q masks the match)
nerr="$(echo "$out" | grep -vE "still in use at exit|instances leaked at exit|were leaked at exit|_free_rids|resource.cpp|renderer_canvas_cull" | grep -cE "SCRIPT ERROR|Parse Error|SMOKE FAIL|Failed to load|ERROR:" || true)"
if [ "${nerr:-0}" -gt 0 ]; then
  echo "$out" | grep -E "SCRIPT ERROR|Parse Error|SMOKE FAIL|Failed to load|ERROR:" | sort | uniq -c | sort -rn | head -n 20
  echo "Errors found in smoke test output ($nerr lines)"; exit 1
fi
if ! echo "$out" | grep -q "SMOKE DONE, failures: 0"; then
  echo "Smoke test did not finish"; exit 1
fi
echo "Smoke test passed"

echo "== interior reachability =="
rout="$("$GODOT" --headless --path . -s res://tools/interior_reach.gd 2>&1)"
echo "$rout" | grep -E "FAIL|interior_reach" || true
if ! echo "$rout" | grep -q "interior_reach: 0 failures"; then
  echo "Interior reachability failed"; exit 1
fi

echo "== building doors =="
dout="$("$GODOT" --headless --path . -s res://tools/door_check.gd 2>&1)"
echo "$dout" | grep -E "DOOR FAIL|door_check" || true
if ! echo "$dout" | grep -q "door_check: 0 failures"; then
  echo "Door check failed"; exit 1
fi

echo "== exits and spawns =="
xout="$("$GODOT" --headless --path . -s res://tools/exit_check.gd 2>&1)"
echo "$xout" | grep -E "FAIL|exit_check" || true
if ! echo "$xout" | grep -q "exit_check: 0 failures"; then
  echo "Exit check failed"; exit 1
fi

echo "== crops wired in =="
# Every interior's way back names its scene: ["scene", x, y].
python3 - <<'PY' || { echo "interior back check failed"; exit 1; }
import json, sys
d = json.load(open("data/interiors.json")); I = d.get("interiors", d)
bad = [k for k, v in I.items() if isinstance(v, dict) and "back" in v and not (isinstance(v["back"], list) and len(v["back"]) == 3 and isinstance(v["back"][0], str))]
print("interior_back:", len(bad), "bad", bad[:5])
sys.exit(1 if bad else 0)
PY
cout="$("$GODOT" --headless --path . -s res://tools/storage_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|storage_test" || true
if ! echo "$cout" | grep -q "storage_test: 0 failures"; then
  echo "storage_test failed"; exit 1
fi
cout="$("$GODOT" --headless --path . -s res://tools/crop_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|crop_test" || true
if ! echo "$cout" | grep -q "crop_test: 0 failures"; then
  echo "Crop test failed"; exit 1
fi

echo "== workshop: no dead ends =="
python3 tools/station_check.py || { echo "Station check failed"; exit 1; }

echo "== workshop: stations at run time =="
sout="$("$GODOT" --headless --path . -s res://tools/station_test.gd 2>&1)"
echo "$sout" | grep -E "FAIL|station_test" || true
if ! echo "$sout" | grep -q "station_test: 0 failures"; then
  echo "Station test failed"; exit 1
fi

echo "== allies: enemies fight back, pup commands =="
aout="$("$GODOT" --headless --path . -s res://tools/ally_test.gd 2>&1)"
echo "$aout" | grep -E "FAIL|ally_test" || true
if ! echo "$aout" | grep -q "ally_test: 0 failures"; then
  echo "Ally test failed"; exit 1
fi

echo "== gifts: the Marked and boss powers =="
gout="$("$GODOT" --headless --path . -s res://tools/gift_test.gd 2>&1)"
echo "$gout" | grep -E "FAIL|gift_test" || true
if ! echo "$gout" | grep -q "gift_test: 0 failures"; then
  echo "Gift test failed"; exit 1
fi

echo "== mine: keeper, shaft, tiers =="
mout="$("$GODOT" --headless --path . -s res://tools/mine_test.gd 2>&1)"
echo "$mout" | grep -E "FAIL|MINE DONE" || true
if ! echo "$mout" | grep -q "MINE DONE, failures: 0"; then
  echo "Mine test failed"; exit 1
fi

echo "== every script compiles =="
cout="$("$GODOT" --headless --path . -s res://tools/compile_all.gd 2>&1)"
echo "$cout" | grep -E "BAD|compile_all" || true
if ! echo "$cout" | grep -q "compile_all: 0 bad"; then
  echo "Compile check failed"; exit 1
fi

echo "== campaign: battles, projects, colonies, big mines =="
kout="$("$GODOT" --headless --path . -s res://tools/campaign_test.gd 2>&1)"
echo "$kout" | grep -E "FAIL|campaign_test" || true
if ! echo "$kout" | grep -q "campaign_test: 0 failures"; then
  echo "Campaign test failed"; exit 1
fi

echo "== settings, slots, quality, discovery, perks, birthdays =="
yout="$("$GODOT" --headless --path . -s res://tools/systems_test.gd 2>&1)"
echo "$yout" | grep -E "FAIL|systems_test" || true
if ! echo "$yout" | grep -q "systems_test: 0 failures"; then
  echo "Systems test failed"; exit 1
fi

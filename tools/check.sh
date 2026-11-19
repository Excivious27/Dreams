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

echo "== exits line up (top edge leads to the next map's bottom edge...) =="
xeout="$("$GODOT" --headless --path . -s res://tools/exit_edge_check.gd 2>&1)"
echo "$xeout" | grep -E "FAIL|exit_edge_check" || true
if ! echo "$xeout" | grep -q "exit_edge_check: 0 failures"; then
  echo "Exit edge check failed"; exit 1
fi

echo "== no invisible walls (rocket pad, moon) =="
iwout="$(MAPS=mountain,moon "$GODOT" --headless --path . -s res://tools/invisible_walls.gd 2>&1)"
echo "$iwout" | grep -E "invisible" || true
if ! echo "$iwout" | grep -q "invisible_walls: 0 failures"; then
  echo "Invisible wall check failed"; exit 1
fi

echo "== faint at 10pm, dawn light, region names =="
wout="$("$GODOT" --headless --path . -s res://tools/r13_world_test.gd 2>&1)"
echo "$wout" | grep -E "FAIL|r13_world_test|SCRIPT ERROR" || true
if ! echo "$wout" | grep -q "r13_world_test: 0 failures"; then
  echo "World/time test failed"; exit 1
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
cout="$("$GODOT" --headless --path . -s res://tools/rec_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|SCRIPT ERROR|rec_test" || true
if ! echo "$cout" | grep -q "rec_test: 0 failures"; then
  echo "rec_test failed"; exit 1
fi
cout="$("$GODOT" --headless --path . -s res://tools/coop_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|coop_test" || true
if ! echo "$cout" | grep -q "coop_test: 0 failures"; then
  echo "coop_test failed"; exit 1
fi
cout="$("$GODOT" --headless --path . -s res://tools/crop_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|crop_test" || true
if ! echo "$cout" | grep -q "crop_test: 0 failures"; then
  echo "Crop test failed"; exit 1
fi
cout="$("$GODOT" --headless --path . -s res://tools/anim_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|SCRIPT ERROR|anim_test" || true
if ! echo "$cout" | grep -q "anim_test: 0 failures"; then
  echo "Animation test failed"; exit 1
fi

cout="$("$GODOT" --headless --path . -s res://tools/commons_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|SCRIPT ERROR|commons_test" || true
if ! echo "$cout" | grep -q "commons_test: 0 failures"; then
  echo "Community farm test failed"; exit 1
fi

echo "== workshop: no dead ends =="
python3 tools/station_check.py || { echo "Station check failed"; exit 1; }
echo "== art prompts: at most 3 images each =="
python3 tools/prompt_size_check.py || { echo "Prompt size check failed"; exit 1; }
echo "== every sound the game asks for exists =="
python3 tools/sfx_audit.py || { echo "Sound audit failed"; exit 1; }

echo "== music: every map has a song; web streaming works offline =="
mmout="$("$GODOT" --headless --path . -s res://tools/music_map_test.gd 2>&1)"
echo "$mmout" | grep -E "FAIL|SCRIPT ERROR|music_map_test" | head -n 40 || true
if ! echo "$mmout" | grep -q "music_map_test: .* 0 failures"; then
  echo "Music map test failed"; exit 1
fi
msout="$("$GODOT" --headless --path . -s res://tools/music_stream_test.gd 2>&1)"
echo "$msout" | grep -E "FAIL|SCRIPT ERROR|music_stream_test" || true
if ! echo "$msout" | grep -q "music_stream_test: 0 failures"; then
  echo "Music stream test failed"; exit 1
fi

fsout="$("$GODOT" --headless --path . -s res://tools/footstep_test.gd 2>&1)"
echo "$fsout" | grep -E "FAIL|SCRIPT ERROR|footstep_test" || true
if ! echo "$fsout" | grep -q "footstep_test: 0 failures"; then
  echo "Footstep test failed"; exit 1
fi

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

echo "== region campaigns: boards, locks, convoy =="
mout2="$("$GODOT" --headless --path . -s res://tools/campaign_map_test.gd 2>&1)"
echo "$mout2" | grep -E "FAIL|SCRIPT ERROR|campaign_map_test" | head -n 40 || true
if ! echo "$mout2" | grep -q "campaign_map_test: 0 fails"; then
  echo "Campaign map test failed"; exit 1
fi
sout2="$("$GODOT" --headless --path . -s res://tools/campaign_story_test.gd 2>&1)"
echo "$sout2" | grep -E "FAIL|SCRIPT ERROR|campaign_story_test" || true
if ! echo "$sout2" | grep -q "campaign_story_test: 0 fails"; then
  echo "Campaign story test failed"; exit 1
fi

echo "== settings, slots, quality, discovery, perks, birthdays =="
yout="$("$GODOT" --headless --path . -s res://tools/systems_test.gd 2>&1)"
echo "$yout" | grep -E "FAIL|systems_test" || true
if ! echo "$yout" | grep -q "systems_test: 0 failures"; then
  echo "Systems test failed"; exit 1
fi

echo "== story: every chapter plays to the end =="
tout="$("$GODOT" --headless --path . -s res://tools/story_test.gd 2>&1)"
echo "$tout" | grep -E "FAIL|STORY DONE" || true
if ! echo "$tout" | grep -q "STORY DONE, failures: 0"; then
  echo "Story test failed"; exit 1
fi

echo "== mega regions: map tabs, unlocks, travel =="
megaout="$("$GODOT" --headless --path . -s res://tools/mega_region_test.gd 2>&1)"
echo "$megaout" | grep -E "FAIL|SCRIPT ERROR|mega_region_test" || true
if ! echo "$megaout" | grep -q "mega_region_test: 0 failures"; then
  echo "Mega region test failed"; exit 1
fi
echo "== mega regions: the new worlds walk end to end =="
mnout="$("$GODOT" --headless --path . -s res://tools/mega_regions_test.gd 2>&1)"
echo "$mnout" | grep -E "FAIL|SCRIPT ERROR|mega_regions_test" || true
if ! echo "$mnout" | grep -q "mega_regions_test: 0 failures"; then
  echo "Mega regions (new) test failed"; exit 1
fi

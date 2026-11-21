#!/usr/bin/env bash
# Import the project and run the smoke test. Fails on any script error.
set -uo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
# CHECK_SHARD=i/N runs every Nth step only (CI shards; see tools/conduct/check_shard.py).
if [ -n "${CHECK_SHARD:-}" ] && [ -z "${CHECK_SHARD_CHILD:-}" ]; then
  exec python3 tools/conduct/check_shard.py "$CHECK_SHARD"
fi

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

echo "== themed battlefields (points open and reachable, themes, grump/kin/pylon art) =="
bfout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/bf_themes_test.gd 2>&1)"
echo "$bfout" | grep -E "BF FAIL|bf_themes_test" || true
if ! echo "$bfout" | grep -q "bf_themes_test: [0-9]* fields, 0 failures"; then
  echo "Battlefield theme test failed"; exit 1
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

echo "== first week pacing, faint/clinic/sleep =="
fwout="$("$GODOT" --headless --path . -s res://tools/first_week_test.gd 2>&1)"
echo "$fwout" | grep -E "FAIL|first_week_test|SCRIPT ERROR" || true
if ! echo "$fwout" | grep -q "first_week_test: 0 failures"; then
  echo "First week test failed"; exit 1
fi

echo "== C8 core curves: levels, caps, swings, food, prices, sleep =="
ccout="$("$GODOT" --headless --path . -s res://tools/c8_curve_test.gd 2>&1)"
echo "$ccout" | grep -E "FAIL|c8_curve_test|pacing|swings by|SCRIPT ERROR" || true
if ! echo "$ccout" | grep -q "c8_curve_test: 0 failures"; then
  echo "C8 curve test failed"; exit 1
fi

echo "== C8 month curve: 30 days, both arcs (energy still binds, purse grows) =="
mcout="$("$GODOT" --headless --path . -s res://tools/month_curve_test.gd 2>&1)"
echo "$mcout" | grep -E "FAIL|month_curve_test|bar left|SCRIPT ERROR" || true
if ! echo "$mcout" | grep -q "month_curve_test: 0 failures"; then
  echo "Month curve test failed"; exit 1
fi

echo "== C11b P2 long ranch curve: three years of ranching, both arcs =="
lcout="$("$GODOT" --headless --path . -s res://tools/month_curve_test.gd -- long 2>&1)"
echo "$lcout" | grep -E "FAIL|month_curve_test|year 1|SCRIPT ERROR" || true
if ! echo "$lcout" | grep -q "month_curve_test long: 0 failures"; then
  echo "Long ranch curve test failed"; exit 1
fi

echo "== first hours on the maps: goal line, arrow, mailbox, tour (both arcs) =="
fhout="$("$GODOT" --headless --path . -s res://tools/first_hours_test.gd 2>&1)"
echo "$fhout" | grep -E "FAIL|first_hours_test|SCRIPT ERROR" || true
if ! echo "$fhout" | grep -q "first_hours_test: 0 failures"; then
  echo "First hours test failed"; exit 1
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
# Phone UI at 270x480: every menu tab, dialogue, toasts, chest, craft, prizes, campaign board, arcade, bowling;
# also every printed symbol has a glyph without system fonts (the web build has none).
dout="$("$GODOT" --headless --path . -s res://tools/desktop_layout_test.gd 2>&1)"
echo "$dout" | grep -E "FAIL|^DESKTOP LAYOUT" || true
if ! echo "$dout" | grep -q "DESKTOP LAYOUT: PASS"; then
  echo "desktop_layout_test failed"; exit 1
fi
cout="$("$GODOT" --headless --path . -s res://tools/phone_ui_test.gd 2>&1)"
echo "$cout" | grep -E "^ISSUE|^phone_ui_test:|^glyphs" || true
if ! echo "$cout" | grep -q "phone_ui_test: 0 issue"; then
  echo "phone_ui_test failed"; exit 1
fi
# Full-screen UIs with real touch events: arcade decks, picker, prizes, bowling, hack, chest/craft in the rec.
tout="$("$GODOT" --headless --path . -s res://tools/touch_ui_test.gd 2>&1)"
echo "$tout" | grep -E "FAIL|SCRIPT ERROR|touch_ui_test" || true
if ! echo "$tout" | grep -q "touch_ui_test: 0 failures"; then
  echo "touch_ui_test failed"; exit 1
fi
echo "== performance guards (batched cliffs, texture cache) =="
pout="$("$GODOT" --headless --path . -s res://tools/perf_test.gd 2>&1)"
echo "$pout" | grep -E "FAIL|SCRIPT ERROR|perf_test" || true
if ! echo "$pout" | grep -q "perf_test: 0 failures"; then
  echo "perf_test failed"; exit 1
fi

echo "== mine arrival: no black cover (c5_16) =="
maout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/mine_arrival_test.gd 2>&1)"
echo "$maout" | grep -E "FAIL|SCRIPT ERROR|mine_arrival_test" || true
if ! echo "$maout" | grep -q "mine_arrival_test: 0 failures"; then
  echo "mine_arrival_test failed"; exit 1
fi

echo "== dating and marriage: bouquet, dates, locket, wedding, spouse (C7 P1) =="
roout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/romance_test.gd 2>&1)"
echo "$roout" | grep -E "FAIL|SCRIPT ERROR|ROMANCE DONE" || true
if echo "$roout" | grep -q "SCRIPT ERROR" || ! echo "$roout" | grep -q "ROMANCE DONE, failures: 0"; then
  echo "romance_test failed"; exit 1
fi

echo "== night lighting: windows, festival fires, underground, mines (c5_10) =="
nlout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/night_light_test.gd 2>&1)"
echo "$nlout" | grep -E "FAIL|SCRIPT ERROR|night_light_test" || true
if ! echo "$nlout" | grep -q "night_light_test: 0 failures"; then
  echo "night_light_test failed"; exit 1
fi

echo "== gangster interior skins (c5_04) =="
isout="$("$GODOT" --headless --path . -s res://tools/interior_skin_test.gd 2>&1)"
echo "$isout" | grep -E "FAIL|SCRIPT ERROR|interior_skin_test" || true
if ! echo "$isout" | grep -q "interior_skin_test: 0 failures"; then
  echo "interior_skin_test failed"; exit 1
fi



echo "== Tom C6 phone playtest: pace, watering can, held name, pup menu, drag and drop, organise =="
tpout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/tom_playtest_c6_test.gd 2>&1)"
echo "$tpout" | grep -E "FAIL|SCRIPT ERROR|tom_playtest_c6_test|tier [0-9]" || true
if ! echo "$tpout" | grep -q "tom_playtest_c6_test: OK"; then
  echo "tom_playtest_c6_test failed"; exit 1
fi

cout="$("$GODOT" --headless --path . -s res://tools/storage_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|storage_test" || true
if ! echo "$cout" | grep -q "storage_test: 0 failures"; then
  echo "storage_test failed"; exit 1
fi

echo "== team animals + chores: lessons, team, muster, overnight chores, Animals/Chores pages (C11a P4) =="
taout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/team_animals_test.gd 2>&1)"
echo "$taout" | grep -E "FAIL|SCRIPT ERROR|team_animals_test" || true
if ! echo "$taout" | grep -q "team_animals_test: OK" || echo "$taout" | grep -q "SCRIPT ERROR"; then
  echo "team_animals_test failed"; exit 1
fi

echo "== C11b P5: chores rework (hay, spots, value cap, regions, levels), team ranks/words, RanchVoice =="
p5out="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/c11b_p5_test.gd 2>&1)"
echo "$p5out" | grep -E "FAIL|SCRIPT ERROR|c11b_p5_test" || true
if ! echo "$p5out" | grep -q "c11b_p5_test: [0-9]* checks, 0 failures" || echo "$p5out" | grep -q "SCRIPT ERROR"; then
  echo "c11b_p5_test failed"; exit 1
fi

echo "== decor catalogue: box, uniques, rolls, rotation, prices, migration (C10a) =="
dcout="$("$GODOT" --headless --path . -s res://tools/decor_test.gd 2>&1)"
echo "$dcout" | grep -E "FAIL|SCRIPT ERROR|decor_test" || true
if ! echo "$dcout" | grep -q "decor_test: [0-9]* checks, 0 failures"; then
  echo "decor_test failed"; exit 1
fi

echo "== decorate mode: place/move/store/undo, rooms, walls, floors (C10a P2) =="
dmout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/decor_mode_test.gd 2>&1)"
echo "$dmout" | grep -E "FAIL|decor_mode_test" || true
if ! echo "$dmout" | grep -q "decor_mode_test: OK"; then
  echo "decor_mode_test failed"; exit 1
fi

echo "== held-tool rules: right tool acts, wrong tool hints =="
trout="$("$GODOT" --headless --path . -s res://tools/tool_rules_test.gd 2>&1)"
echo "$trout" | grep -E "FAIL|SCRIPT ERROR|tool_rules_test" || true
if ! echo "$trout" | grep -q "tool_rules_test: 0 failures"; then
  echo "Tool rules test failed"; exit 1
fi
cout="$("$GODOT" --headless --path . -s res://tools/rec_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|SCRIPT ERROR|rec_test" || true
if ! echo "$cout" | grep -q "rec_test: 0 failures"; then
  echo "rec_test failed"; exit 1
fi
tout="$("$GODOT" --headless --path . -s res://tools/ticket_econ_test.gd 2>&1)"
echo "$tout" | grep -E "FAIL|SCRIPT ERROR|ticket_econ_test" || true
if ! echo "$tout" | grep -q "ticket_econ_test: 0 failures"; then
  echo "ticket_econ_test failed"; exit 1
fi
cout="$("$GODOT" --headless --path . -s res://tools/rec_links_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|SCRIPT ERROR|rec_links_test" || true
if ! echo "$cout" | grep -q "rec_links_test: 0 failures"; then
  echo "rec_links_test failed"; exit 1
fi
rrout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/rec_reno_test.gd 2>&1)"
echo "$rrout" | grep -E "FAIL|SCRIPT ERROR|rec_reno_test" || true
if ! echo "$rrout" | grep -q "rec_reno_test: 0 failures"; then
  echo "rec_reno_test failed"; exit 1
fi
raout="$("$GODOT" --headless --path . -s res://tools/rec_audio_test.gd 2>&1)"
echo "$raout" | grep -E "FAIL|SCRIPT ERROR|rec_audio_test" || true
if ! echo "$raout" | grep -q "rec_audio_test: 0 failures"; then
  echo "rec_audio_test failed"; exit 1
fi
bwout="$("$GODOT" --headless --path . -s res://tools/bowling_test.gd 2>&1)"
echo "$bwout" | grep -E "FAIL|SCRIPT ERROR|bowling_test" || true
if ! echo "$bwout" | grep -q "bowling_test: OK"; then
  echo "bowling_test failed"; exit 1
fi
cout="$("$GODOT" --headless --path . -s res://tools/cash_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|cash_test" || true
if ! echo "$cout" | grep -q "cash_test: scanned [0-9]* strings, 0 failures"; then
  echo "cash_test failed"; exit 1
fi
cout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/gang_play_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|gang_play_test" || true
if ! echo "$cout" | grep -q "gang_play_test: 0 failures"; then
  echo "gang_play_test failed"; exit 1
fi
for t in difficulty_test day_length_test; do
  cout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/$t.gd 2>&1)"
  echo "$cout" | grep -E "FAIL|$t:" || true
  if ! echo "$cout" | grep -q "$t: [0-9]* checks, 0 failures"; then
    echo "$t failed"; exit 1
  fi
done
cout="$("$GODOT" --headless --path . -s res://tools/coop_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|coop_test" || true
if ! echo "$cout" | grep -q "coop_test: 0 failures"; then
  echo "coop_test failed"; exit 1
fi
cout="$("$GODOT" --headless --path . -s res://tools/farm_week_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|farm_week_test" || true
if ! echo "$cout" | grep -q "farm_week_test: OK"; then
  echo "farm_week_test failed"; exit 1
fi

cout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/farm_look_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|farm_look_test" || true
if ! echo "$cout" | grep -q "farm_look_test: PASS"; then
  echo "farm_look_test failed"; exit 1
fi

cout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/pen_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|pen_test" || true
if ! echo "$cout" | grep -q "pen_test: PASS"; then
  echo "pen_test failed"; exit 1
fi

python3 tools/make_house_parts.py --check || { echo "house parts check failed"; exit 1; }

cout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/house_exterior_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|house exterior test" || true
if ! echo "$cout" | grep -q "house exterior test: PASS"; then
  echo "house_exterior_test failed"; exit 1
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

cout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/npc_anim_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|SCRIPT ERROR|npc_anim_test" || true
if ! echo "$cout" | grep -q "npc_anim_test: OK"; then
  echo "Villager animation test failed"; exit 1
fi

cout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/move_target_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|SCRIPT ERROR|move_target_test" || true
if ! echo "$cout" | grep -q "move_target_test: 0 failures"; then
  echo "Movement/targeting test failed"; exit 1
fi

cout="$("$GODOT" --headless --path . -s res://tools/commons_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|SCRIPT ERROR|commons_test" || true
if ! echo "$cout" | grep -q "commons_test: 0 failures"; then
  echo "Community farm test failed"; exit 1
fi

cout="$("$GODOT" --headless --path . -s res://tools/shop_econ_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|SCRIPT ERROR|shop_econ_test" || true
if ! echo "$cout" | grep -q "shop_econ_test: 0 failures"; then
  echo "Shop economy test failed"; exit 1
fi

cout="$("$GODOT" --headless --path . -s res://tools/ranch_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|SCRIPT ERROR|ranch_test" || true
if ! echo "$cout" | grep -q "ranch_test: [0-9]* checks, 0 failures"; then
  echo "Ranch test failed"; exit 1
fi

cout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/ranch_p2_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|SCRIPT ERROR|ranch_p2_test" || true
if ! echo "$cout" | grep -q "ranch_p2_test: 0 failures"; then
  echo "Ranch P2 test failed"; exit 1
fi

cout="$("$GODOT" --headless --path . -s res://tools/ranch_gift_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|SCRIPT ERROR|ranch_gift_test" || true
if ! echo "$cout" | grep -q "ranch_gift_test: [0-9]* checks, 0 failures"; then
  echo "Ranch gift test failed"; exit 1
fi

cout="$("$GODOT" --headless --path . -s res://tools/decor_sources_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|SCRIPT ERROR|decor_sources_test" || true
if ! echo "$cout" | grep -q "decor_sources_test: 0 failures"; then
  echo "Decor sources test failed"; exit 1
fi

cout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/cf_volunteer_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|SCRIPT ERROR|cf_volunteer_test" || true
if ! echo "$cout" | grep -q "cf_volunteer_test: 0 failures"; then
  echo "Community farm volunteer test failed"; exit 1
fi

cout="$("$GODOT" --headless --path . -s res://tools/gang_flavour_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|SCRIPT ERROR|gang_flavour_test" || true
if ! echo "$cout" | grep -q "gang_flavour_test: 0 failures"; then
  echo "Gangster flavour test (rec hall / lot garden) failed"; exit 1
fi

cout="$("$GODOT" --headless --path . -s res://tools/cf_layout_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|SCRIPT ERROR|cf_layout_test" || true
if ! echo "$cout" | grep -q "cf_layout_test: 0 failures"; then
  echo "Community farm layout test failed"; exit 1
fi

cout="$("$GODOT" --headless --path . -s res://tools/early_gating_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|SCRIPT ERROR|early_gating_test" || true
if ! echo "$cout" | grep -q "early_gating_test: PASS"; then
  echo "Early gating test failed"; exit 1
fi
cout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/town_first_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|SCRIPT ERROR|town_first_test" || true
if ! echo "$cout" | grep -q "town_first_test: 0 failures"; then
  echo "Town first-visit test failed"; exit 1
fi

echo "== workshop: no dead ends =="
python3 tools/station_check.py || { echo "Station check failed"; exit 1; }
echo "== art prompts: at most 3 images each =="
python3 tools/prompt_size_check.py || { echo "Prompt size check failed"; exit 1; }
echo "== every sound the game asks for exists =="
python3 tools/sfx_audit.py || { echo "Sound audit failed"; exit 1; }
echo "== music loop seams (join click + level jump) =="
python3 tools/music_loop_check.py || { echo "Music loop check failed"; exit 1; }
echo "== music: loop points are applied (data/music_loops.json) =="
mlout="$("$GODOT" --headless --path . -s res://tools/music_loops_test.gd 2>&1)"
echo "$mlout" | grep -E "FAIL|SCRIPT ERROR|music_loops_test" || true
if ! echo "$mlout" | grep -q "music_loops_test: .* 0 failures"; then
  echo "Music loops test failed"; exit 1
fi
echo "== text size floors (7 px) =="
python3 tools/text_floor_check.py || { echo "Text floor check failed"; exit 1; }
echo "== all ages: alcohol is a trade good, never drunk =="
python3 tools/drink_rule_test.py || { echo "Drink rule failed"; exit 1; }

echo "== C10a decor art: every catalogue piece and rotation exists =="
python3 tools/slice_c10a.py check || { echo "Decor art check failed"; exit 1; }

echo "== C10b decor art: outdoor pieces, seams, names =="
python3 tools/slice_c10b.py check || { echo "C10b outdoor decor art check failed"; exit 1; }

echo "== C11a ranch art: species strips, building looks, icons, stations =="
python3 tools/slice_c11a.py check || { echo "C11a ranch art check failed"; exit 1; }

echo "== C11b ranch art: exotic/fantastic/lab strips, team poses, habitats, icons, violet guard =="
python3 tools/slice_c11b.py check || { echo "C11b ranch art check failed"; exit 1; }
python3 tools/slice_c11b_chores.py check || { echo "C11b chore icons missing"; exit 1; }

echo "== economy: no money loops, crops and brews inside their bands =="
python3 tools/econ_check.py || { echo "Economy check failed"; exit 1; }

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
dmout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/danger_music_test.gd 2>&1)"
echo "$dmout" | grep -E "FAIL|SCRIPT ERROR|danger_music_test" || true
if ! echo "$dmout" | grep -q "danger_music_test: 0 failures"; then
  echo "Combat music test failed"; exit 1
fi
mxout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/mix_test.gd 2>&1)"
echo "$mxout" | grep -E "FAIL|SCRIPT ERROR|mix_test" || true
if ! echo "$mxout" | grep -q "mix_test: 0 failures"; then
  echo "Music mix test failed"; exit 1
fi

amout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/ambience_test.gd 2>&1)"
echo "$amout" | grep -E "FAIL|SCRIPT ERROR|ambience_test" || true
if ! echo "$amout" | grep -q "ambience_test: 0 failures"; then
  echo "Ambience/where-sound-plays test failed"; exit 1
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

echo "== arcs: path cards, arc building intros, locked-plan hints =="
arcout="$("$GODOT" --headless --path . -s res://tools/arc_intro_test.gd 2>&1)"
echo "$arcout" | grep -E "FAIL|SCRIPT ERROR|arc_intro_test" || true
if ! echo "$arcout" | grep -q "arc_intro_test: 0 failures"; then
  echo "Arc intro test failed"; exit 1
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
mout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/mine_test.gd 2>&1)"
echo "$mout" | grep -E "FAIL|MINE DONE" || true
if ! echo "$mout" | grep -q "MINE DONE, failures: 0"; then
  echo "Mine test failed"; exit 1
fi

echo "== keeper encounters keep real hp (floor-1 swarms topped up) =="
kmout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/keeper_min_hp_test.gd 2>&1)"
echo "$kmout" | grep -E "FAIL|SCRIPT ERROR|keeper_min_hp_test" || true
if echo "$kmout" | grep -q "SCRIPT ERROR" || ! echo "$kmout" | grep -q "keeper_min_hp_test: 0 failures"; then
  echo "Keeper min hp test failed"; exit 1
fi

echo "== mine keepers: tool damage, crates, keeper variety/pace, way-down arrow route =="
mkout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/mine_keeper_test.gd 2>&1)"
echo "$mkout" | grep -E "FAIL|MINE KEEPER DONE" || true
if ! echo "$mkout" | grep -q "MINE KEEPER DONE, failures: 0"; then
  echo "Mine keeper test failed"; exit 1
fi

echo "== early combat: clinic, pup lesson, telegraph, first boss =="
ecout="$("$GODOT" --headless --path . -s res://tools/early_combat_test.gd 2>&1)"
echo "$ecout" | grep -E "FAIL|early_combat_test" || true
if ! echo "$ecout" | grep -q "early_combat_test: PASS"; then
  echo "Early combat test failed"; exit 1
fi

echo "== every script compiles =="
cout="$("$GODOT" --headless --path . -s res://tools/compile_all.gd 2>&1)"
echo "$cout" | grep -E "BAD|compile_all" || true
if ! echo "$cout" | grep -q "compile_all: 0 bad"; then
  echo "Compile check failed"; exit 1
fi

echo "== campaign: battles, projects, colonies, big mines =="
kout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/campaign_test.gd 2>&1)"
echo "$kout" | grep -E "FAIL|campaign_test" || true
if ! echo "$kout" | grep -q "campaign_test: 0 failures"; then
  echo "Campaign test failed"; exit 1
fi

echo "== battle outcomes: drain, siege, boss, defend, convoy; team, helpers =="
bwout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/battle_win_test.gd 2>&1)"
echo "$bwout" | grep -E "FAIL|SCRIPT ERROR|battle_win_test" || true
if ! echo "$bwout" | grep -q "battle_win_test: 0 fails"; then
  echo "Battle outcome test failed"; exit 1
fi

echo "== region campaigns: boards, locks, convoy =="
mout2="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/campaign_map_test.gd 2>&1)"
echo "$mout2" | grep -E "FAIL|SCRIPT ERROR|campaign_map_test" | head -n 40 || true
if ! echo "$mout2" | grep -q "campaign_map_test: 0 fails"; then
  echo "Campaign map test failed"; exit 1
fi
sout2="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/campaign_story_test.gd 2>&1)"
echo "$sout2" | grep -E "FAIL|SCRIPT ERROR|campaign_story_test" || true
if ! echo "$sout2" | grep -q "campaign_story_test: 0 fails"; then
  echo "Campaign story test failed"; exit 1
fi
glout="$("$GODOT" --headless --path . -s res://tools/goal_line_test.gd 2>&1)"
echo "$glout" | grep -E "FAIL|SCRIPT ERROR|goal_line_test" || true
if ! echo "$glout" | grep -q "goal_line_test: 0 fails"; then
  echo "Goal line test failed"; exit 1
fi
qtout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/quest_tracker_test.gd 2>&1)"
echo "$qtout" | grep -E "FAIL|SCRIPT ERROR|quest_tracker_test" || true
if ! echo "$qtout" | grep -q "quest_tracker_test: 0 fails"; then
  echo "Quest tracker test failed"; exit 1
fi
sbout="$("$GODOT" --headless --path . -s res://tools/street_bat_test.gd 2>&1)"
echo "$sbout" | grep -E "FAIL|SCRIPT ERROR|street_bat_test" || true
if ! echo "$sbout" | grep -q "street_bat_test: 0 fails"; then
  echo "Street bat test failed"; exit 1
fi
c6cout="$("$GODOT" --headless --path . -s res://tools/c6_cue_test.gd 2>&1)"
echo "$c6cout" | grep -E "FAIL|SCRIPT ERROR|c6_cue_test" || true
if ! echo "$c6cout" | grep -q "c6_cue_test: 0 fails"; then
  echo "C6 gameplay cue test failed"; exit 1
fi
fdout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/farm_debris_test.gd 2>&1)"
echo "$fdout" | grep -E "FAIL|SCRIPT ERROR|farm_debris_test" || true
if ! echo "$fdout" | grep -q "farm_debris_test: 0 fails"; then
  echo "Farm debris test failed"; exit 1
fi
gout2="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/campaign_gate_test.gd 2>&1)"
echo "$gout2" | grep -E "FAIL|SCRIPT ERROR|campaign_gate_test" || true
if ! echo "$gout2" | grep -q "campaign_gate_test: 0 fails"; then
  echo "Campaign gate test failed"; exit 1
fi
gout3="$(ARC=gangsters "$GODOT" --headless --fixed-fps 60 --path . -s res://tools/campaign_gate_test.gd 2>&1)"
echo "$gout3" | grep -E "FAIL|SCRIPT ERROR|campaign_gate_test" || true
if ! echo "$gout3" | grep -q "campaign_gate_test: 0 fails"; then
  echo "Campaign gate test (gangsters) failed"; exit 1
fi
p5out="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/campaign_words_test.gd 2>&1)"
echo "$p5out" | grep -E "FAIL|SCRIPT ERROR|campaign_words_test" || true
if ! echo "$p5out" | grep -q "campaign_words_test: 0 fails"; then
  echo "Campaign gate words test failed"; exit 1
fi
c3out="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/campaign_c3_test.gd 2>&1)"
echo "$c3out" | grep -E "FAIL|SCRIPT ERROR|campaign_c3_test" || true
if ! echo "$c3out" | grep -q "campaign_c3_test: 0 fails"; then
  echo "Campaign C3 design test failed"; exit 1
fi
p5out="$("$GODOT" --headless --path . -s res://tools/meow_gate_test.gd 2>&1)"
echo "$p5out" | grep -E "FAIL|SCRIPT ERROR|meow_gate_test" || true
if ! echo "$p5out" | grep -q "meow_gate_test: 0 fails"; then
  echo "Meow Pow Wow gate test failed"; exit 1
fi
p5out="$("$GODOT" --headless --path . -s res://tools/skill_glow_test.gd 2>&1)"
echo "$p5out" | grep -E "FAIL|SCRIPT ERROR|skill_glow_test" || true
if ! echo "$p5out" | grep -q "skill_glow_test: 0 fails"; then
  echo "Skill points glow test failed"; exit 1
fi

msout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/move_speed_test.gd 2>&1)"
echo "$msout" | grep -E "FAIL|SCRIPT ERROR|move_speed_test" || true
if ! echo "$msout" | grep -q "move_speed_test: 0 fails"; then
  echo "Move speed ladder test failed"; exit 1
fi

echo "== settings, slots, quality, discovery, perks, birthdays =="
yout="$("$GODOT" --headless --path . -s res://tools/systems_test.gd 2>&1)"
echo "$yout" | grep -E "FAIL|systems_test" || true
if ! echo "$yout" | grep -q "systems_test: 0 failures"; then
  echo "Systems test failed"; exit 1
fi

echo "== saves: first run, slots, opening Skip, reopen at early milestones, old save -> Round 13 =="
svout="$("$GODOT" --headless --path . -s res://tools/save_test.gd 2>&1)"
echo "$svout" | grep -E "FAIL|SCRIPT ERROR|save_test" || true
if ! echo "$svout" | grep -q "save_test: [0-9]* checks, 0 failures"; then
  echo "Save test failed"; exit 1
fi

echo "== story: every chapter plays to the end =="
tout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/story_test.gd 2>&1)"
echo "$tout" | grep -E "FAIL|SCRIPT ERROR|STORY DONE" || true
if ! echo "$tout" | grep -q "STORY DONE, failures: 0" || echo "$tout" | grep -q "SCRIPT ERROR"; then
  echo "Story test failed"; exit 1
fi
echo "== penguin arc: new game to day 2 (crystal, mailbox marker, partner scene) =="
npout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/newgame_penguin_test.gd 2>&1)"
echo "$npout" | grep -E "FAIL|SCRIPT ERROR|newgame_penguin_test" || true
if ! echo "$npout" | grep -q "newgame_penguin_test: 0 failures" || echo "$npout" | grep -q "SCRIPT ERROR"; then
  echo "New-game penguin test failed"; exit 1
fi

echo "== gangster first hours: intro, day 2, meadow, Hideout, first crew =="
gsout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/gang_start_test.gd 2>&1)"
echo "$gsout" | grep -E "FAIL|SCRIPT ERROR|gang_start_test" || true
if ! echo "$gsout" | grep -q "gang_start_test: 0 failures" || echo "$gsout" | grep -q "SCRIPT ERROR"; then
  echo "Gang start test failed"; exit 1
fi

echo "== villager heart arcs (2-10 hearts, 6-heart quests, daily lines) =="
hout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/hearts_test.gd 2>&1)"
echo "$hout" | grep -E "FAIL|SCRIPT ERROR|HEARTS DONE" || true
if ! echo "$hout" | grep -q "HEARTS DONE, failures: 0" || echo "$hout" | grep -q "SCRIPT ERROR"; then
  echo "Hearts test failed"; exit 1
fi

echo "== C7 text: gift articles, plurals, quest wording =="
c7tout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/c7_text_test.gd 2>&1)"
echo "$c7tout" | grep -E "FAIL|SCRIPT ERROR|c7_text_test" || true
if ! echo "$c7tout" | grep -q "c7_text_test: 0 fails"; then
  echo "C7 text test failed"; exit 1
fi

echo "== mega regions: map tabs, unlocks, travel =="
megaout="$("$GODOT" --headless --path . -s res://tools/mega_region_test.gd 2>&1)"
echo "$megaout" | grep -E "FAIL|SCRIPT ERROR|mega_region_test" || true
if ! echo "$megaout" | grep -q "mega_region_test: 0 failures"; then
  echo "Mega region test failed"; exit 1
fi
echo "== mega UI: map pins, travel letters, mega quests, boss themes, caves (C4 P4) =="
muout="$("$GODOT" --headless --path . -s res://tools/mega_ui_test.gd 2>&1)"
echo "$muout" | grep -E "FAIL|SCRIPT ERROR|mega_ui_test" || true
if ! echo "$muout" | grep -q "mega_ui_test: PASS"; then
  echo "Mega UI test failed"; exit 1
fi
echo "== mega regions: the new worlds walk end to end =="
mnout="$("$GODOT" --headless --path . -s res://tools/mega_regions_test.gd 2>&1)"
echo "$mnout" | grep -E "FAIL|SCRIPT ERROR|mega_regions_test" || true
if ! echo "$mnout" | grep -q "mega_regions_test: 0 failures"; then
  echo "Mega regions (new) test failed"; exit 1
fi
echo "== hidden areas: a pocket and a secret way in every mega area (CONDUCT 4) =="
haout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/hidden_area_test.gd 2>&1)"
echo "$haout" | grep -E "FAIL|SCRIPT ERROR|hidden_area_test" || true
if ! echo "$haout" | grep -q "hidden_area_test: PASS"; then
  echo "Hidden area test failed"; exit 1
fi

echo "== crisp art shader on buildings/props (C2 P7) =="
caout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/crisp_art_test.gd 2>&1)"
echo "$caout" | grep -E "FAIL|SCRIPT ERROR|crisp_art_test" || true
if ! echo "$caout" | grep -q "crisp_art_test: OK"; then
  echo "Crisp art test failed"; exit 1
fi

echo "== fish critters only in deep water (C2 P4) =="
cwout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/critter_water_test.gd 2>&1)"
echo "$cwout" | grep -E "FAIL|SCRIPT ERROR|critter_water_test" || true
if ! echo "$cwout" | grep -q "critter_water_test: PASS"; then
  echo "Critter water test failed"; exit 1
fi

echo "== menu sweep: every menu button, both arcs (C2) =="
msout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/menu_sweep_test.gd 2>&1)"
echo "$msout" | grep -E "FAIL|SCRIPT ERROR|menu_sweep_test" || true
if ! echo "$msout" | grep -q "menu_sweep_test: .* 0 failures"; then
  echo "Menu sweep test failed"; exit 1
fi

echo "== hidden areas stay put day to day (C5) =="
hsout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/hidden_stable_test.gd 2>&1)"
echo "$hsout" | grep -E "FAIL|SCRIPT ERROR|hidden_stable_test" || true
if ! echo "$hsout" | grep -q "hidden_stable_test: OK"; then
  echo "Hidden stable test failed"; exit 1
fi

echo "== arcade: cabinets play, pay tickets; every jumper level can be finished =="
jout="$("$GODOT" --headless --path . -s res://tools/jumper_solve.gd 2>&1)"
echo "$jout" | grep -E "FAIL|jumper_solve" || true
if ! echo "$jout" | grep -q "jumper_solve: 0 failures"; then
  echo "Jumper level check failed"; exit 1
fi
jtout="$("$GODOT" --headless --path . -s res://tools/jumper_test.gd 2>&1)"
echo "$jtout" | grep -E "FAIL|SCRIPT ERROR|jumper_test" || true
if ! echo "$jtout" | grep -q "jumper_test: 0 failures"; then
  echo "Jumper feel/checkpoint test failed"; exit 1
fi
aout2="$("$GODOT" --headless --path . -s res://tools/arcade_test.gd 2>&1)"
echo "$aout2" | grep -E "FAIL|SCRIPT ERROR|arcade_test" || true
if ! echo "$aout2" | grep -q "arcade_test: 0 failures"; then
  echo "Arcade test failed"; exit 1
fi
swout="$("$GODOT" --headless --path . -s res://tools/stack_whack_test.gd 2>&1)"
echo "$swout" | grep -E "FAIL|SCRIPT ERROR|stack_whack_test" || true
if ! echo "$swout" | grep -q "stack_whack_test: 0 failures"; then
  echo "Crystal Stack / Whack-a-Grump test failed"; exit 1
fi
rgout="$("$GODOT" --headless --path . -s res://tools/rec_games_test.gd 2>&1)"
echo "$rgout" | grep -E "FAIL|SCRIPT ERROR|rec_games_test" || true
if ! echo "$rgout" | grep -q "rec_games_test: 0 failures"; then
  echo "Rec games test failed"; exit 1
fi
echo "== softlocks: every menu/screen leaves on B, dialogues always finish =="
slout="$("$GODOT" --headless --path . -s res://tools/softlock_test.gd 2>&1)"
echo "$slout" | grep -E "FAIL|SCRIPT ERROR|softlock_test" || true
if ! echo "$slout" | grep -q "softlock_test: 0 failures"; then
  echo "Softlock test failed"; exit 1
fi
echo "== story flow (C7): one beat at a time, quest-done backstop, beats wait for screens, skippable, canon lines =="
sfout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/story_flow_test.gd 2>&1)"
echo "$sfout" | grep -E "FAIL|SCRIPT ERROR|STORY FLOW DONE" || true
if ! echo "$sfout" | grep -q "STORY FLOW DONE, failures: 0"; then
  echo "Story flow test failed"; exit 1
fi
echo "== toasts: never over a boss card, a region card, the pup strip or the energy bar =="
tlout="$("$GODOT" --headless --path . -s res://tools/toast_layout_test.gd 2>&1)"
echo "$tlout" | grep -E "FAIL|SCRIPT ERROR|toast_layout_test" || true
if ! echo "$tlout" | grep -q "toast_layout_test: 0 failures"; then
  echo "Toast layout test failed"; exit 1
fi

echo "== seasons/weather looks: no drifts on paths, summer regions stay green, leaf particles, no storm flocks =="
slkout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/season_look_test.gd 2>&1)"
echo "$slkout" | grep -E "FAIL|SCRIPT ERROR|season_look_test" || true
if ! echo "$slkout" | grep -q "season_look_test: PASS"; then
  echo "Season look test failed"; exit 1
fi

echo "== UI/arcade/rec/story audio cues (CONDUCT 6 P6) =="
uaout="$("$GODOT" --headless --path . -s res://tools/ui_audio_test.gd 2>&1)"
echo "$uaout" | grep -E "FAIL|SCRIPT ERROR|ui_audio_test" || true
if ! echo "$uaout" | grep -q "ui_audio_test: 0 failures"; then
  echo "UI audio test failed"; exit 1
fi

echo "== C7 P5: colony stories and crew =="
c5out="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/c7_colony_crew_test.gd 2>&1)"
echo "$c5out" | grep -E "FAIL|c7_colony_crew_test" || true
if ! echo "$c5out" | grep -q "c7_colony_crew_test: PASS"; then
  echo "C7 colony/crew test failed"; exit 1
fi

echo "== C7 P3: endings and epilogue =="
epout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/epilogue_test.gd 2>&1)"
echo "$epout" | grep -E "FAIL|epilogue_test" || true
if ! echo "$epout" | grep -q "epilogue_test: 0 fails"; then
  echo "Epilogue test failed"; exit 1
fi

echo "== C7 P4: heart scene content =="
hcout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/hearts_content_test.gd 2>&1)"
echo "$hcout" | grep -E "FAIL|hearts_content_test" || true
if ! echo "$hcout" | grep -q "hearts_content_test: OK"; then
  echo "Heart content test failed"; exit 1
fi

echo "== C11a P5: ranch villagers, mail, festivals, pen sounds =="
rvout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/ranch_villagers_test.gd 2>&1)"
echo "$rvout" | grep -E "FAIL|SCRIPT ERROR|ranch_villagers_test" || true
if ! echo "$rvout" | grep -q "ranch_villagers_test: OK" || echo "$rvout" | grep -q "SCRIPT ERROR"; then
  echo "Ranch villagers test failed"; exit 1
fi

echo "== C11b P6: fair ribbon tables =="
asout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/animal_show_test.gd 2>&1)"
echo "$asout" | grep -E "FAIL|SCRIPT ERROR|animal_show_test" || true
if ! echo "$asout" | grep -q "animal_show_test: OK" || echo "$asout" | grep -q "SCRIPT ERROR"; then
  echo "animal_show_test failed"; exit 1
fi

echo "== C11b P6: battle line-up and team jobs =="
btout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/battle_team_test.gd 2>&1)"
echo "$btout" | grep -E "FAIL|SCRIPT ERROR|battle_team_test" || true
if ! echo "$btout" | grep -q "battle_team_test: OK" || echo "$btout" | grep -q "SCRIPT ERROR"; then
  echo "battle_team_test failed"; exit 1
fi

echo "== C11b P6: ranch building arc words and footprints =="
bwout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/builds_words_test.gd 2>&1)"
echo "$bwout" | grep -E "FAIL|SCRIPT ERROR|builds_words_test" || true
if ! echo "$bwout" | grep -q "builds_words_test: OK" || echo "$bwout" | grep -q "SCRIPT ERROR"; then
  echo "builds_words_test failed"; exit 1
fi

echo "== C11b P6: C11b creature voices and ranch sound =="
raout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/ranch_audio_c11b_test.gd 2>&1)"
echo "$raout" | grep -E "FAIL|SCRIPT ERROR|ranch_audio_c11b_test" || true
if ! echo "$raout" | grep -q "ranch_audio_c11b_test: OK" || echo "$raout" | grep -q "SCRIPT ERROR"; then
  echo "ranch_audio_c11b_test failed"; exit 1
fi

echo "== C8 P3: collections (museum, logs, Book tab) =="
clout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/collections_test.gd 2>&1)"
echo "$clout" | grep -E "FAIL|SCRIPT ERROR|collections_test" || true
if ! echo "$clout" | grep -q "collections_test: 0 failures"; then
  echo "Collections test failed"; exit 1
fi

echo "== C11a P3: Ranching tree, ranch tiers, processing, ranch log, animal counter =="
rp3out="$("$GODOT" --headless --path . -s res://tools/ranch_p3_test.gd 2>&1)"
echo "$rp3out" | grep -E "FAIL|SCRIPT ERROR|ranch_p3_test" || true
if ! echo "$rp3out" | grep -q "ranch_p3_test: OK"; then
  echo "Ranch P3 test failed"; exit 1
fi

echo "== C11a fix2: every ranch species buyable from its seller, both arcs, starter gift in the roster =="
rsout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/ranch_shop_test.gd 2>&1)"
echo "$rsout" | grep -E "FAIL|SCRIPT ERROR|ranch_shop_test" || true
if ! echo "$rsout" | grep -q "ranch_shop_test: [0-9]* checks, 0 failures" || echo "$rsout" | grep -q "SCRIPT ERROR"; then
  echo "ranch_shop_test failed"; exit 1
fi

echo "== C11a integration: one care path, ranching keys, incubator, farm hands, P6 art =="
ciout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/c11a_integ_test.gd 2>&1)"
echo "$ciout" | grep -E "FAIL|SCRIPT ERROR|c11a_integ_test" || true
if ! echo "$ciout" | grep -q "c11a_integ_test: [0-9]* checks, 0 failures"; then
  echo "C11a integration test failed"; exit 1
fi

echo "== C8 P4: fishing rules, mining curve, reward tables =="
p4out="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/c8_p4_test.gd 2>&1)"
echo "$p4out" | grep -E "FAIL|SCRIPT ERROR|c8_p4_test" || true
if echo "$p4out" | grep -q "SCRIPT ERROR" || ! echo "$p4out" | grep -q "c8_p4_test: PASS"; then
  echo "C8 P4 test failed"; exit 1
fi

echo "== C9 P1: controller bindings and field play =="
padout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/pad_test.gd 2>&1)"
echo "$padout" | grep -E "FAIL|SCRIPT ERROR|pad_test" || true
if ! echo "$padout" | grep -q "pad_test: 0 failures"; then
  echo "pad_test failed"; exit 1
fi

echo "== C9 P2: game menu with keys/pad =="
mpout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/menu_pad_test.gd 2>&1)"
echo "$mpout" | grep -E "FAIL|SCRIPT ERROR|menu_pad_test" || true
if ! echo "$mpout" | grep -q "menu_pad_test: 0 failures"; then
  echo "menu_pad_test failed"; exit 1
fi

echo "== C10a P3: decor catalogue =="
dcout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/decor_catalogue_test.gd 2>&1)"
echo "$dcout" | grep -E "FAIL|SCRIPT ERROR|decor_catalogue_test" || true
if ! echo "$dcout" | grep -q "decor_catalogue_test: 0 failures"; then
  echo "decor_catalogue_test failed"; exit 1
fi

echo "== C9 P3: full-screen screens with actions only =="
spout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/screens_pad_test.gd 2>&1)"
echo "$spout" | grep -E "FAIL|SCRIPT ERROR|screens_pad_test" || true
if ! echo "$spout" | grep -q "screens_pad_test: 0 failures"; then
  echo "screens_pad_test failed"; exit 1
fi

echo "== C9 P4: haptics =="
hpout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/haptics_test.gd 2>&1)"
echo "$hpout" | grep -E "FAIL|SCRIPT ERROR|HAPTICS" || true
if ! echo "$hpout" | grep -q "HAPTICS DONE, failures: 0"; then
  echo "haptics_test failed"; exit 1
fi

echo "== C9 P5: save codes and files =="
stout="$("$GODOT" --headless --path . -s res://tools/save_transfer_test.gd 2>&1)"
echo "$stout" | grep -E "FAIL|SCRIPT ERROR|SAVE TRANSFER DONE" || true
if ! echo "$stout" | grep -q "SAVE TRANSFER DONE 0"; then
  echo "save_transfer_test failed"; exit 1
fi

echo "== C9 P6: forest border buckets =="
bbout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/border_bucket_test.gd 2>&1)"
echo "$bbout" | grep -E "FAIL|SCRIPT ERROR|border_bucket_test" || true
if ! echo "$bbout" | grep -q "border_bucket_test: 0 failures"; then
  echo "border_bucket_test failed"; exit 1
fi

echo "== C9 P6: generated data in sync =="
dsout="$(bash tools/data_sync_check.sh 2>&1)"
echo "$dsout" | tail -3
if ! echo "$dsout" | grep -q "data_sync_check: 0 failures"; then
  echo "data_sync_check failed"; exit 1
fi

echo "== C10a P5: wardrobe =="
wrout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/wardrobe_test.gd 2>&1)"
echo "$wrout" | grep -E "FAIL|SCRIPT ERROR|wardrobe_test" || true
if ! echo "$wrout" | grep -q "wardrobe_test: OK (0 failures)"; then
  echo "wardrobe_test failed"; exit 1
fi

echo "== C10b P4: casino =="
csout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/casino_test.gd 2>&1)"
echo "$csout" | grep -E "FAIL|SCRIPT ERROR|casino_test" || true
if ! echo "$csout" | grep -q "casino_test: 0 failures"; then
  echo "casino_test failed"; exit 1
fi

echo "== relay: server/server.js protocol (tools/relay_test.js; a push of server/ to main deploys the live relay) =="
rtout="$(timeout 120 node tools/relay_test.js 2>&1)"
echo "$rtout" | grep -E "FAIL|RELAY TEST" || true
if ! echo "$rtout" | grep -q "RELAY TEST OK"; then
  echo "relay_test failed"; exit 1
fi

echo "== relay: Play together uses the live relay by default, custom server + Reset to default =="
nuout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/net_url_test.gd 2>&1)"
echo "$nuout" | grep -E "FAIL|SCRIPT ERROR|net_url_test" || true
if ! echo "$nuout" | grep -q "net_url_test: [0-9]* checks, 0 failures"; then
  echo "net_url_test failed"; exit 1
fi

echo "== net transport: NetNode over the in-memory relay twin (NetRelayRoom = server.js rules) =="
ntout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/net_transport_test.gd 2>&1)"
echo "$ntout" | grep -E "FAIL|SCRIPT ERROR|net_transport_test" || true
if ! echo "$ntout" | grep -q "net_transport_test: [0-9]* checks, 0 failures"; then
  echo "net_transport_test failed"; exit 1
fi

echo "== steam co-op: lobbies + networking messages over FakeSteam (no Steam client) =="
nsout="$("$GODOT" --headless --path . --fixed-fps 60 -s res://tools/net_steam_test.gd 2>&1)"
echo "$nsout" | grep -E "FAIL|SCRIPT ERROR|net_steam_test" || true
if ! echo "$nsout" | grep -q "net_steam_test: [0-9]* checks, 0 failures"; then
  echo "net_steam_test failed"; exit 1
fi

echo "== steam co-op: web build never parses Steam code (backend object, load by path) =="
python3 tools/net_web_safety_check.py || { echo "net_web_safety_check failed"; exit 1; }

echo "== steam input: game_actions VDF matches InputSetup (generator + KeyValues check) =="
python3 tools/steam_input_check.py || { echo "steam_input_check failed"; exit 1; }

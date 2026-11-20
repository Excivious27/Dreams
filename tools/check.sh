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

echo "== first week pacing, faint/clinic/sleep =="
fwout="$("$GODOT" --headless --path . -s res://tools/first_week_test.gd 2>&1)"
echo "$fwout" | grep -E "FAIL|first_week_test|SCRIPT ERROR" || true
if ! echo "$fwout" | grep -q "first_week_test: 0 failures"; then
  echo "First week test failed"; exit 1
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
cout="$("$GODOT" --headless --path . -s res://tools/storage_test.gd 2>&1)"
echo "$cout" | grep -E "FAIL|storage_test" || true
if ! echo "$cout" | grep -q "storage_test: 0 failures"; then
  echo "storage_test failed"; exit 1
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
cout="$("$GODOT" --headless --path . -s res://tools/cf_volunteer_test.gd 2>&1)"
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
tout="$("$GODOT" --headless --path . -s res://tools/story_test.gd 2>&1)"
echo "$tout" | grep -E "FAIL|STORY DONE" || true
if ! echo "$tout" | grep -q "STORY DONE, failures: 0"; then
  echo "Story test failed"; exit 1
fi
echo "== penguin arc: new game to day 2 (crystal, mailbox marker, partner scene) =="
npout="$("$GODOT" --headless --fixed-fps 60 --path . -s res://tools/newgame_penguin_test.gd 2>&1)"
echo "$npout" | grep -E "FAIL|SCRIPT ERROR|newgame_penguin_test" || true
if ! echo "$npout" | grep -q "newgame_penguin_test: 0 failures"; then
  echo "New-game penguin test failed"; exit 1
fi

echo "== gangster first hours: intro, day 2, meadow, Hideout, first crew =="
gsout="$("$GODOT" --headless --path . -s res://tools/gang_start_test.gd 2>&1)"
echo "$gsout" | grep -E "FAIL|SCRIPT ERROR|gang_start_test" || true
if ! echo "$gsout" | grep -q "gang_start_test: 0 failures"; then
  echo "Gang start test failed"; exit 1
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
echo "== toasts: never over a boss card, a region card, the pup strip or the energy bar =="
tlout="$("$GODOT" --headless --path . -s res://tools/toast_layout_test.gd 2>&1)"
echo "$tlout" | grep -E "FAIL|SCRIPT ERROR|toast_layout_test" || true
if ! echo "$tlout" | grep -q "toast_layout_test: 0 failures"; then
  echo "Toast layout test failed"; exit 1
fi

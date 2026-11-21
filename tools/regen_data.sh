#!/usr/bin/env bash
# Rerun every data generator in the one stable order (C9 P6, c9_17). Later
# generators read what earlier ones wrote (gen_gifts keeps gen_colonies' c_ gifts,
# gen_mega_regions reads gen_mega_new, gen_stations prices every item and recipe,
# gen_collections logs every recipe), so this order reaches a fixed point:
# running it twice changes nothing. gen_decor (C10a) runs early: it reads only the manifest and the
# committed items.json (rp_ prizes), and later generators. gen_ranch (C11a) writes ranch.json + the ranch product items before gen_stations prices them; later generators (gen_stations recipes/shop goods) read decor.json. tools/data_sync_check.sh fails CI on drift.
set -e
cd "$(dirname "$0")/.."
ORDER="gen_skill_trees gen_ranch gen_decor gen_wardrobe write_hearts gen_heart_perks gen_romance gen_side_stories gen_epilogue gen_projects gen_community_farm gen_rec gen_battles gen_colonies gen_gifts gen_mega_new gen_mega_regions gen_seasons gen_stations gen_collections gen_casino gen_team_animals gen_helpers gen_achievements gen_travel"
for g in $ORDER; do
  out="$(python3 -B tools/$g.py 2>&1)" || { echo "$out"; echo "regen_data: $g failed"; exit 1; }
done
# C14 P3: the beach marina (data/marina.json; its routes are TravelNet links).
python3 -B tools/gen_marina.py >/dev/null || { echo "regen_data: gen_marina failed"; exit 1; }
python3 -B tools/gen_props_c14.py >/dev/null || { echo "regen_data: gen_props_c14 failed"; exit 1; }  # C14 P6 dressing (reads regions.json: last)
python3 -B tools/gen_festivals.py >/dev/null || { echo "regen_data: gen_festivals failed"; exit 1; }  # C15 P6 festival year (data/festivals.json)
python3 -B tools/gen_calendar.py >/dev/null || { echo "regen_data: gen_calendar failed"; exit 1; }  # C15 P1 calendar rows (markets, small events)
python3 -B tools/store_facts.py >/dev/null || { echo "regen_data: store_facts failed"; exit 1; }
python3 -B tools/gen_progression.py >/dev/null || { echo "regen_data: gen_progression failed"; exit 1; }  # C16a P1 unlock timeline (docs/PROGRESSION.md -> data/progression.json)
python3 -B tools/gen_battle_rewards.py >/dev/null || { echo "regen_data: gen_battle_rewards failed"; exit 1; }  # C16b P4 reward ladder (reads battles.json + decor.json)
echo "regen_data: ok ($(echo $ORDER | wc -w) generators)"

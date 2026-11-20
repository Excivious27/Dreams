#!/usr/bin/env bash
# Rerun every data generator in the one stable order (C9 P6, c9_17). Later
# generators read what earlier ones wrote (gen_gifts keeps gen_colonies' c_ gifts,
# gen_mega_regions reads gen_mega_new, gen_stations prices every item and recipe,
# gen_collections logs every recipe), so this order reaches a fixed point:
# running it twice changes nothing. tools/data_sync_check.sh fails CI on drift.
set -e
cd "$(dirname "$0")/.."
ORDER="gen_skill_trees gen_heart_perks gen_romance gen_side_stories gen_epilogue gen_projects gen_community_farm gen_rec gen_battles gen_colonies gen_gifts gen_mega_new gen_mega_regions gen_stations gen_collections"
for g in $ORDER; do
  out="$(python3 -B tools/$g.py 2>&1)" || { echo "$out"; echo "regen_data: $g failed"; exit 1; }
done
echo "regen_data: ok ($(echo $ORDER | wc -w) generators)"

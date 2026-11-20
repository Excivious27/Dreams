# CONDUCT 8 fix packages: economy, progression, balance + collections build
Findings: /home/claude/wt/c8_reports/c8_NN.jsonl. Take every finding whose files/scope fall in your package from ALL files (filter by "files" and the scope numbers named); c8_09 (30-day bot curve) and c8_15..20 may still arrive: re-read the folder every ~20 minutes. Tom's rules: early game must make you work for it (C6 P7 slowdown stays; tune, don't undo), all ages, wine/ales are trade goods, difficulty never changes economy. Keep every number in its generator or table (no magic numbers in scattered code); every change gets a before/after line in your report. File ownership is strict; hooks in another package's file are one or two lines and reported.
Art: dreams-image up to 15 images per package (P3 up to 30: museum building, display cases, log icons, reward items). Audio: CC0 only if needed.

## P1 Core curves (game_state.gd owner)
OWNS: scripts/game_state.gd, scripts/sleep_report.gd, scripts/faint.gd, tools/first_week_test.gd, tools/sim.gd, tools/farm_week_test.gd.
DO: c8_05 (XP per action per skill, level curve, BONUS_CAPS — keep gen_skill_trees CAPS in sync via a note to P5), c8_06 (energy costs incl. the C6 P7 early factor, food restore vs price, pass-out, clinic fees, day-length interplay), c8_13 early-game feel (days 1-14: money in hand, first upgrade day; both arcs), c8_09 30-day curve findings (walls/floods), the GameState parts of c8_02 (toughen/hits_for tables) and c8_01 (crop quality/sell multipliers if they live here). Update first_week_test/farm_week_test bands only where the new pace is the intent (say so).

## P2 Crops, crafting, items, animals data
OWNS: tools/gen_stations.py (+ outputs), data/items.json, data/crops.json, scripts/crafting.gd, scripts/farm.gd (crop/animal economy), data/buildings.json, scripts/builds.gd, scripts/farm_animal.gd.
DO: c8_01 all (seed price, growth, regrowth, sell, per-season profit/day, outliers, greenhouse, fertiliser; both arcs), c8_04 all (recipe input vs output value, processing times, money loops, money-losing recipes, unlock order), c8_12 all (animal prices, produce, feed, happiness, artisan goods vs crops), item value fixes from c8_07 that live in items.json/gen_stations. Write a value-check script (tools/econ_check.py) that fails on loops/outliers and wire it into check.sh (< 60 s).

## P3 Collections (new system)
OWNS: new scripts/collections.gd, new tools/gen_collections.py (+ data/collections.json), scripts/game_menu.gd (new Collections tab; other packages' menu hooks are one line), new tools/collections_test.gd, museum building/interior via a new map or an interiors.json entry (one-line hooks in town.gd/interior.gd).
DO: c8_08 all (the build plan): museum donations (minerals, artifacts, fish, journal pages/secrets), shipping log (every item shipped), fish log, cooking + crafting logs, milestone rewards, the Collections tab UI (phone-sized, search/filter), save fields + migration, both arcs (gangster wording). Art for the museum and rewards.

## P4 Mining, fishing, rewards
OWNS: scripts/game_map.gd (fishing, rocks/ore drops, chests, interact rewards), scripts/mine.gd, scripts/mine_keepers.gd, scripts/secrets.gd, tools/gen_mega_new.py, tools/gen_battles.py (rewards only), tools/gen_colonies.py (rewards only), data/quests.json (rewards only), scripts/region.gd.
DO: c8_02 all except GameState tables (ore drops by floor tier, bars/smelting, gem prices, floor rewards; "work for it" curve), c8_03 all (fish list per place/season/time/weather, difficulty, prices, rods/bait/tackle), c8_11 all (rewards from quests, campaigns, mega regions, bosses, chests, secrets: value per hour vs farming).

## P5 Skills and speed
OWNS: tools/gen_skill_trees.py (+ data/skills.json), data/skills_base.json, scripts/char_sheet.gd, scripts/spells.gd, scripts/player.gd (move speed, mounts), scripts/skill_glow.gd.
DO: c8_05 skill-tree parts (node values, unlock pacing over 3 years, skills nobody can level; CAPS in sync with GameState.BONUS_CAPS: coordinate with P1 through your report), c8_10 all (a coherent speed ladder: gear, potions, foods, mounts, skills; caps and stacking; fill missing tiers).

## P6 Shops, prices, money sinks
OWNS: scripts/shops.gd, scripts/interior.gd (shop counters), scripts/commons.gd, tools/gen_rec.py (+ outputs), scripts/money.gd, scripts/mountain.gd (vendor), scripts/town.gd (shop hooks only), tools/cash_test.gd.
DO: c8_07 all (every shop's buy/sell vs item value, cash vs crystals parity, ticket economy check_economy, mega shop prices, sell box, inflation over 3 years), c8_14 all (late-game money sinks: houses, decor, upgrades, prestige goals; propose and build the cheap ones now as shop entries/upgrades, list bigger ones for C10/C16).

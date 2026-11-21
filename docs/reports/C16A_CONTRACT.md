# CONDUCT 16a contract

## 1. Shared files
- scripts/game_state.gd: three owners by section — P3 energy (ENERGY_* constants, energy_cost_f, spend_for, recovery, max energy), P6 skill effects (skill bonus getters), P1 gates (unlock/flag helpers). Edit only your section; add new functions rather than reshaping shared ones; keep signatures.
- generators: gen_stations.py P5 (P2 may change sell/buy prices only, noted in NOTES.md with exact keys); gen_mega_new.py / mega_regions_new.py / gen_travel.py P1 (gates only); gen_collections.py P4; gen_skill_trees.py, gen_helpers.py, gen_team_animals.py P6; gen_seasons.py prices P2.
- tools/check.sh: new blocks appended at the END with an `echo "== ... =="` header.
- tools/regen_data.sh: append-only.
- Always bash tools/regen_data.sh after a generator change; commit generated data with it.

## 2. New APIs
- `Progression.unlock_day(id) -> int` intended day (from docs/PROGRESSION.md table compiled into data/progression.json by P1's tools/gen_progression.py) used by tests and the sim (P2 reads it).
- `EnergyCheck` (tools/energy_check.py, P3) prints per persona per day: start, spent by category, end; fails outside bands in data/energy_bands.json.
- `BugNet` (P4): tool id "bug_net" (crafted or bought, tiered), Critters.catchable(scene, season, hour) and collection book "critters" category; museum wing "critters".
- Sim (P2): `godot -s res://tools/sim.gd -- --years 3 --style farmer|explorer|social --arc penguins|gangsters --out <csv>`; CI block runs one short smoke (e.g. 1 season).

## 3. Budgets
dreams-image today ~400 left: P4 120 (bug net, critters, rods/tackle, museum displays), P5 120 (gear tiers, stations), P6 60, P1 20, P2 0, P3 10. ACE none. Art ids c16a<pk>_*, own slicer, rm-then-write, set_import_lossy only on your new files.

## 4. Rules
Deterministic tests (game time, --fixed-fps 60 where the test supports it, seed). Saves: any new run block -> ask P1 in NOTES.md (P1 owns SAVE_VERSION bump + _migrate this round). All ages; no animal deaths; alcohol trade-only. Both arcs. Notes: /home/claude/wt/c16af_reports/NOTES.md.

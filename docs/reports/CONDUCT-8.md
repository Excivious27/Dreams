# CONDUCT 8 report: Economy, progression, balance + Collections (2026-11-20)

The fourth CONDUCT on the optimised process. 14 focus auditors and 6 checklist auditors (c8_01..20, 219 findings) fed 6 file-disjoint fix packages (docs/reports/C8-PACKAGES.md): five balance packages plus P3, the new Collections system (museum, shipping, fish, cooking, crafting and forage logs, milestones). Everything was merged once and checked on GitHub Actions (check.sh in 6 shards, 20 bots, the scripted playtest with screenshots): C8 passed on run c8c after one CI fix round and one merge fix.

**Whole game after CONDUCT 8: about 72% done, 28% remaining** (average of the 61 systems in docs/inventory.csv). Collections went in at 88%, shops/economy 80 -> 88%, skill trees 88 -> 92%, mines 90 -> 92%, and two new rows: fishing 88% and the move-speed ladder 85%. Systems Tom added for later CONDUCTs (hazards/lava C20, General Store C21, marina C14) still count at 0%.

## Audit (20 auditors, 219 findings: 0 blockers, 68 major, 113 minor, 38 polish)

| Area | Main findings |
|---|---|
| Crops (01) | Fertiliser lasted forever on regrowers, 15 seed tiers not matching their crop, useless crops (melon, lotus, slow herbs), tea/hops/moonberry outliers, uncapped yield and quality. |
| Mining (02) | Pick tiers with dead steps (copper = iron), gems on every stone, a floor-15 hardness sawtooth, early floors too costly in energy, mega ore ignoring the pick. |
| Fishing (03) | Valley waters short of common fish, windows not tied to value, bait spent where it did nothing, Legendary Koi unreachable. |
| Crafting (04) | Recipes that printed money or lost it, keg brews priced flat, station goods off their inputs. |
| Skills and levels (05) | Flat 400 XP per level forever with no cap, per-level effects unclamped, HP/energy stacking across nine trees, full trees that glowed forever. |
| Energy and early game (06, 13) | Energy stopped binding after week 2 (+3 max per level), food restore vs price, day 1-14 money pacing. |
| Shops and prices (07) | Bartering raised prices, community stand / market money loop, double-counted market sales, seed tiers in shops. |
| Collections build plan (08) | The 12-step plan: museum, logs, milestones, tab, save fields, both arcs. |
| 30-day bot curve (09) | Walls and floods in the month curve (energy and money). |
| Speed (10) | ~7x stacked move speed, tap-to-move overshoot, 11 movement nodes against a 25% cap, a speed card that disagreed. |
| Rewards (11) | Quest/campaign/chest/secret value per hour vs farming, caches without a budget. |
| Animals (12) | Produce vs feed, no animal shop, artisan goods vs crops. |
| Money sinks (14) | Nothing to spend on late; stand below sell price. |
| Checklist (15-20) | Smaller text, test and doc items. |

## Fix packages

| Package | Fixed |
|---|---|
| P1 Core curves | Level curve 40..400 to level 13, then x1.03 per level to MAX_LEVEL 100 (~year 3 for a steady farmer); LEVEL_EFFECT_CAP 20 on per-level effects; tree caps TREE_HP_CAP 200 / TREE_EN_CAP 120 / TEAM_XP_CAP 0.25; level energy +1.5 per level up to 30; smooth chop/mine effort (`hits_for/toughen/swing_damage`); shop price floors; full-bag eating. New c8_curve_test and month_curve_test (30 days, both arcs). |
| P2 Crops, crafting, animals | Fertiliser lasts one harvest; seed and produce tiers match their crops; outlier and useless crops retuned; HARVEST table with yield/quality capped at Farming 20; gen_stations ECON floors/caps over every recipe; keg brews priced by input; animal pacing table; new tools/econ_check.py in check.sh (fails on money loops/outliers). |
| P3 Collections (new) | gen_collections.py -> collections.json: 59 museum pieces in 4 wings (Valley Museum, gangster Curio Room), shipping log (216 per arc), fish log, cookbook, crafting log (293), forage log, 19 milestones with letters, the Curator's Loupe; Book tab CollectionScreen with pages; hooks in sell box, fishing, crafting, Sal's fence and the stand; save migration; Legendary Koi reachable. New collections_test. |
| P4 Mining, fishing, rewards | `Mining` (PICK_SWING per tier, smooth rock hp by floor, gem chance by stone), lighter floors 1-3, mega ore uses the pick; `Fishing.T` (pools, value-band windows, treasure by water, bait only where it helps, area tier ceiling); reward loot tiers, cache budgets, moon rocks respawn. New c8_p4_test. |
| P5 Skills and speed | `MoveSpeed` ladder: foot bonus capped at +60%, bursts, ride and vehicle caps, slows last; tap-to-move brakes (1.7 px overshoot, was up to 300); exactly 5 move-speed nodes per arc, the rest turned into cave/swim/ride speed and haste time (ids kept); Hero tab speed card matches. New move_speed_test. |
| P6 Shops and money sinks | Bartering never raises prices; stand at 1.35x above market 1.25x, donations to a pantry never resold; market sales counted once with stars; Gideon upgrade nights/rush fees; the Valley Fund late sink (5k..200k marks); hand-priced stalls through `Shops.stall`. New shop_econ_test. |

CI-only fixes after the merge (one round, run c8c green):
- coop_test: default `run.coll` for guests.
- tool_rules_test: mega rock HP now scales with the pick.
- move_speed_test: capped skill points.
Merge fix: conflict markers left in scripts/secrets.gd, and an econ loop that appeared after the shop silver price change.

## Timing (optimised process)

| Stage | Effort | Minutes |
|---|---|---|
| Auditors: 14 focus (medium) + 6 checklist (low, one agent), during the C7 wrap-up | medium / low | overlapped |
| Package plan | | ~20 |
| Fix agents (6, medium) | medium | ~60-75 |
| Merges (incl. secrets.gd and econ loop merge fix) | | ~25 |
| CI (6 shards + 20 bots + playtest), incl. one fix round | medium | ~80 |
| Package build (report, guide, progress, page) | low | ~10 |
| **Total from plan to verified merge** | | **~200** |

## Still open (next CONDUCTs)
- Speed buffs still overwrite each other (needs `GameState.add_buff` keeping the stronger one); Neon Jacket and a gear speed ladder.
- Fertiliser still kept by Hazel auto-harvest, crows and Bloom (`clear_crop` helper suggested).
- Duplicate crops glowcap2/3 and void_pepper2 in Old Moss's list; demand() takes the first match.
- Maple's rare seeds not gated by crop tier.
- Weak late crops (dreamflower, luminous starfruit) only warned by econ_check.
- Animal shop, buying/selling animals and herd growth (C11).
- Penguin arc has no crafted income line to match the gangster operation.
- Valley Fund projects don't yet change the town visibly (art next round).
- Still open from earlier: underwater colony caves, kid's board / Halo's race, Hale's portrait, Nova's hat, pixel font (C23), audio depth (C13).

## Questions for Tom (defaults are in place)
See Guide 32.

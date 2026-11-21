# Dreams: progression timeline (C16a)

How fast the game opens up, by game day, for three play styles and both arcs. Day numbers are
**game days** (28-day seasons, 112-day years: Spring 1 = day 1, Summer 1 = 29, Fall 1 = 57,
Winter 1 = 85, year 2 = day 113, year 3 = day 225), so every day-length option keeps the same
pacing per day. Gates are identical in every difficulty (Difficulty only touches combat).

The unlock table below is compiled into `data/progression.json` by `tools/gen_progression.py`
(run by `tools/regen_data.sh`); `Progression.unlock_day(id)` reads it, and
`tools/progression_test.gd` checks that the enforced rows match the game data and that a
"rusher" (every story step done, every skill maxed, a full purse) cannot open them a day early.

## Unlock table

`enforced` = the code/data that holds the gate (tested); `planned` = intended day, gate owned by
another package or still to change (listed under "Gates still to change").

| id | day | arc | status | what opens | gate |
|---|---|---|---|---|---|
| commons | 4 | both | planned | Commons / community farm letter | early_gating (C1) |
| rec_center | 7 | both | planned | Rec Center / Rec Hall opens | early_gating (C1) |
| coop | 10 | both | planned | first coop | Plans board |
| mega_gloamwood | 22 | both | enforced | Gloamwood (fairy ring) | story tier 1 + Spring 22 + Foraging 4 (mega_regions_new.py) |
| marina_t2 | 29 | both | planned | marina breakwater (T2) | gen_marina.py |
| mega_sunscorch | 43 | both | enforced | Sunscorch Expanse | tier 2 or Fishing 6, + Summer 15 |
| mega_ironline | 43 | gangsters | enforced | Ironline Frontier | tier 2 or Mining 7, + Summer 15 |
| greenhouse | 57 | both | planned | greenhouse | gen_stations.py (P5) |
| mega_frostpeak | 85 | both | enforced | Frostpeak Reach | tier 3 or Ranching 6, + Winter 1 |
| mega_windward | 113 | penguins | enforced | Windward Isles | tier 4 or Foraging 9, + year 2 |
| mega_giltcity | 113 | gangsters | enforced | Gilt City | tier 4 or 40 hearts in all, + year 2 |
| t4_hub_links | 113 | both | enforced | hub-to-hub keeper lines | both regions' hub jobs + tier 3 + year 2 (gen_travel.py) |
| t4_airship | 113 | both | enforced | airship dock / charter airstrip rides | build + tier 3 + year 2 |
| t5_hops | 113 | both | enforced | waystones / dispatch board instant hops | teleporter or uptown + year 2 |
| grand_marina | 113 | both | planned | marina T4 (grand marina) | gen_marina.py (+ year 2) |
| barn_t4 | 113 | both | planned | deluxe barn | gen_stations.py (P5) |
| comet_festival | 225 | both | planned | the comet festival | C15 Calendar (exists) |
| skill_masters | 225 | both | planned | master nodes per skill tree | gen_skill_trees.py (P6) |
| museum_last | 225 | both | planned | last museum milestone | gen_collections.py (P4) |

## Timeline by style (both arcs)

Day numbers are game days. "Sim" = what tools/sim.gd measured (docs/reports/sim/C16A-SIM.xlsx,
15-minute days); the rest is the intended pace from the gates.

| When | Farmer | Fighter / explorer | Social / creative |
|---|---|---|---|
| Spring days 1-7 | field, workbench, kitchen, furnace, keg; commons letter day 4; Rec Center day 7 | east meadow day 3; mine floors 1-10 (day-1 route about 35% of the bar); tier-1 drills | Rec Center day 7; first hearts; critters with the Twig Net (350) |
| Spring days 8-28 | coop (~day 10); anvil (Mining 2), sawmill (Building 2), mayo (Ranching 2); helpers from day 8 | mine floors 10-30; Gloamwood from day 22 with Foraging 4 | about 4 hearts; museum 5 and 10; glow bait at Fishing 6 |
| Summer (29-56) | barn, station tier 2 (skill 4); marina T2 | Sunscorch from day 43 (tier 2 or Fishing 6); Ironline from day 43 (tier 2 or Mining 7); mine 40 | about 8 hearts; Silk Net at Foraging 15; deep bait (10), magnet (12), wild (15) |
| Fall (57-84) | greenhouse (planned day 57); station tier 3 (skill 9); house tier 2 | mine 60; first mega region in the sim ~day 50-52 | Fishing Derby (marina T2); prism trout at Fishing 14 |
| Winter (85-112) | winter crops (16); "any" crops sleep outdoors; house tier 3 | Frostpeak from day 85 (tier 3 or Ranching 6); mine to 100 (101+ waits for year 2) | sailfish at Fishing 18; museum 20-30 |
| Year 2 (113-224) | station tier 4 (skill 16 + year 2), Creamery, Cellar Vats, Grand Barn / Enclosure / Aviary / Terrarium, Star Dome, iridium sprinkler; barn T4 permit 40,000 | Windward (penguins) / Gilt City (gang) from day 113 (tier 4 or Foraging 9 / 40 hearts); T4 hub links, airship, T5 hops; mine 101-149 | soul salmon (Fishing 22), frost pike (26); Star Net at Foraging 35; wedding; museum 40-50 |
| Year 3 (225-336) | final decor sets; farming lv ~86-90 in the sim | the Hollow Heart (floor 150); skill column X at 64 points | legendary koi (Fishing 30); season legend critters (Foraging 40); museum 65 and all |

Sim income per 112-day year (15-minute days): farmer 123k / 211k / 278k (penguins), 99k / 290k /
539k (gang); explorer ~190k each year; social 67k / 152k / 238k (penguins); hustler 236k / 523k /
628k. Max energy: day 1 120, day 28 181, year 1 278, year 2 365, year 3 395.

## Year gates held in code (C16a)

These are not rows of the unlock table (that table's `enforced` rows are checked against
mega_travel.json); each one is held by the code named and guarded by its own test.

| Gate | Opens | Held by | Test |
|---|---|---|---|
| Mine floors 101+ | year 2 | `Mine.deep_lock` (DEEP_FLOOR / DEEP_YEAR) | c16a_p5_test |
| The Hollow Heart | year 3 | `Mine.deep_lock` (HEART_YEAR) | c16a_p5_test |
| Top tier of every 4-tier station (Creamery, Cellar Vats, ...) | year 2 | gen_stations `unlock.year`, `Builds.gate` | c16a_p5_test, station_check |
| Grand Barn / Enclosure / Aviary / Terrarium, Star Dome | year 2 | gen_stations `unlock.year` | c16a_p5_test |
| Iridium sprinkler recipe | year 2 | recipe `year`, `Crafting.why_locked` | c16a_p5_test |
| Station tier skill gates 1 / 4 / 9 / 16 | by skill | gen_stations SK | station_check |
| Recipe tier levels 1 / 3 / 8 / 14 / 20 | by skill | `Crafting.RECIPE_LV` | c16a_p5_test |
| Late permits (barn T4 40,000, house T3 6,000, launchpad T4 30,000, T4 stations 20,000) | money | gen_stations `C16A_PERMITS` | econ_check |
| Soul salmon, frost pike / legendary koi | year 2 / year 3 | `Collections.LEGENDS` year + level | c16a_p4_fish_test, c15_p4_seasons_test |
| Season legend critters | Star Net + Foraging 40 | `Critters.catchable` | critter_net_test |
| Skill columns I-X at 0/2/5/9/14/20/28/38/50/64 points | by points | `GameState.TIER_NEED` / `col_need` | c16a_p6_test |
| Team animal ranks at 1/5/12/22/35 lessons; team +1 at Leadership 25, +1 at tier 3 | by use | gen_team_animals, `TeamAnimals.team_max` | team_animals_test, c16a_p6_test |
| Helper levels at 40/130/300/600 chores | by use | gen_helpers LEVELS | c16a_p6_test |
| Crew loyalty steps 3/7/14 days, 0/4/6 hearts | by days | `Crew.loyalty_wait` | c16a_p6_test |

## Goals at every stage (quick / moderate / long)

- Days 1-14 (quick): T1 hops, Marina T1, the meadow, first coop, Rec Center, commons;
  colonies ferry after c_colony_coral (penguins); gang taxi farm<->town after the gang quest and
  a payphone-and-rank build.
- Spring 15 - Summer 28 (moderate): Gloamwood (day 22, Foraging 4, hook 12 flower + 8 wild herb
  + 6 mushroom); T2 carts/ferries; T3 masts/pads (tier 2 + ~2600 build); Sunscorch / Ironline
  (day 43); Marina T2-T3.
- Fall - Winter year 1 (long): Frostpeak (day 85, hook 12 wool + 20 coal + 6 beam); every open
  region's hub job; mine floors to 100 (101+ wait for year 2, the Hollow Heart for year 3).
- Year 2: Windward and Gilt City; T4 hub links (300 fare until 20 rides) and the airship /
  airstrip (400 fare until 20 rides); T5 instant hops; grand marina.
- Year 3: Hollow Heart (floor 150), comet festival, master skill nodes, last museum milestone, the C20 lava region slot.

## Real play time per year by day length

| day length | real minutes per day | hours per year | year 2 starts after | year 3 starts after |
|---|---|---|---|---|
| 15 (classic) | 15 | 28 | 28 h | 56 h |
| 20 | 20 | 37 | 37 h | 75 h |
| 30 | 30 | 56 | 56 h | 112 h |
| 40 | 40 | 75 | 75 h | 149 h |

Judge year-2/3 gates at the 20-minute day (about 37 hours a year) as the median. Shorter days
reach the next year sooner; the save can switch length at any time in Options.

## Mega regions and travel (C16a P1 retime)

| region | old gate | new gate | hook (old -> new) | hook reward |
|---|---|---|---|---|
| Gloamwood | tier 1 (~day 3) | tier 1 + day 22 + Foraging 4 | 6 flower, 3 wild herb -> 12 flower, 8 wild herb, 6 mushroom | 60 -> 150 |
| Sunscorch | tier 2 | (tier 2 or Fishing 6) + day 43 | 4 bread, 3 rope -> 8 bread, 6 rope, 1 sail | 90 -> 300 |
| Ironline | tier 2 | (tier 2 or Mining 7) + day 43 | 10 coal, 3 iron bar -> 30 coal, 10 iron bar, 4 gear | 120 -> 400 |
| Frostpeak | tier 3 | (tier 3 or Ranching 6) + day 85 | 4 wool, 6 coal -> 12 wool, 20 coal, 6 beam | 150 -> 500 |
| Windward | tier 3 | (tier 4 or Foraging 9) + year 2 | 4 cloth, 1 refined crystal -> 12 cloth, 2 sail, 3 refined crystal | 200 -> 700 |
| Gilt City | tier 3 | (tier 4 or 40 hearts) + year 2 | 12 rolled bills, 1 gold bar -> 40 bills, 4 gold bar, 1 pearl necklace | 250 -> 900 |

## Gates still to change (owned elsewhere or waiting on Tom)

- Greenhouse t1 day 57 and permit 1000 -> 3000; house t3 building 7 / progress 2; coop t3
  ranching 6 / progress 2; barn t3 progress 3, barn t4 progress 3 (gen_stations.py). The Grand
  ranch tiers already wait for year 2.
- Hearts twice as big (HEART_POINTS 25 -> 50) so 10 hearts take ~7 weeks (romance, needs a save
  migration; deferred).
- progress_tier calendar floors (tier 2 day 10, tier 3 day 29, tier 4 day 57) and boss-only tier
  steps for both arcs (touches every story/campaign test; deferred to C16b with the no-battle road).
- Campaign provision costs and calendar floors per campaign tier (gen_battles.py, C16b).
- Day-length meaning (Tom): "more game per day" vs "same progress per day" for the real-time
  systems (mine keepers, fishing, racket).
- Late-game energy (Tom): the bar barely limits a full day from year 1 on (default: tougher deep
  rocks in C22). Max energy with every source is 560 (default: keep).
- Sim tuning: explorer income flat across years; gang farmer 1.9x the penguin farmer in year 3;
  farmer's first mega region day 50 (band wants 56+).

## How tests guard the timeline

- `tools/progression_test.gd` (check.sh): enforced unlock-table rows match mega_travel.json; a
  rusher (every story step, every skill maxed, full purse) can't open a region a day early and can
  on the day, in both arcs; non-combat roads never beat the calendar; T4/T5 links shut on day 112,
  open on day 113; Windward / Gilt shut at day 30 and tier 3.
- `tools/sim.gd` smoke + `tools/sim_bands.py` (check.sh, 28 days farmer/penguins and
  explorer/gangsters): day-28 purse 1k-20k, farming level 10-35, season-1 income bands, chapter
  <= 2 and no skill 100 by day 28; warns if days 1-3 use over 40% of the bar.
- `tools/energy_check.py` + `data/energy_bands.json` and `tools/energy_route_probe.gd` (check.sh):
  per-persona energy per day; Tom's day-1 gang route must stay near 35% of the bar; full days at
  years 1-3 keep farmer >= 15% and miner >= 35%.
- `tools/c16a_energy_test.gd`, `c16a_p4_fish_test.gd`, `critter_net_test.gd`, `c16a_p5_test.gd`,
  `c16a_p6_test.gd`: the gates in the table above.
- Older guards still run: early_gating_test (days 2-13), first_week_test, month_curve_test,
  c8_curve_test, econ_check, station_check.
- Full 3-year runs: `godot --headless --path . -s res://tools/sim.gd -- --years 3 --style farmer
  --arc penguins --day-len 15 --out /tmp/sim/farmer_penguins.csv`, then
  `python3 tools/sim_report.py /tmp/sim` rebuilds docs/reports/sim/C16A-SIM.xlsx.

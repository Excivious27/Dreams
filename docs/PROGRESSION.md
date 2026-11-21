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

## Three play styles

FARMER. Year 1 Spring: the field, coop (day ~10), Rec Center (day 7), commons (day 4). Summer:
barn, greenhouse plans. Fall: greenhouse (day 57+), house tier 2. Winter: house tier 3, winter
crops. Year 2: deluxe barn, grand marina, legendary fish. Year 3: final decor sets, museum.

FIGHTER / EXPLORER. Year 1 Spring: east meadow (day 3), mine floors 1-20, the drill and tier-1
campaigns; Gloamwood from Spring 22 with Foraging 4. Summer: the commander / Docks boss, mine 40,
Sunscorch / Ironline from Summer 15. Fall: knight / neon, mine 60. Winter: Frostpeak from
Winter 1, mine 80 (floors 1-100 are year 1). Year 2: Windward / Gilt City, teleporter / uptown,
T4 hub links, mine floors 101-149 (Mine.deep_lock). Year 3: the Hollow Heart (floor 150), comet
festival, master nodes.

SOCIAL / CREATIVE. Year 1: Rec Center day 7, festivals, about 4 hearts in Spring and 8 in
Summer (bouquet), decor sets. Year 2: wedding, casino tiers (gang arc), museum half. Year 3:
museum complete, final decor sets. Non-combat roads into the mega regions: Fishing 6
(Sunscorch), Mining 7 (Ironline), Ranching 6 (Frostpeak), Foraging 9 (Windward), 40 hearts in
all (Gilt City); each still waits for the same calendar day.

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
  ranching 6 / progress 2; barn t3 progress 3, barn t4 progress 3 + year 2 (gen_stations.py, P5).
- Hearts twice as big (HEART_POINTS 25 -> 50) so 10 hearts take ~7 weeks (romance, needs a save
  migration; deferred).
- progress_tier calendar floors (tier 2 day 10, tier 3 day 29, tier 4 day 57) and boss-only tier
  steps for both arcs (touches every story/campaign test; deferred to C16b with the no-battle road).
- Campaign provision costs and calendar floors per campaign tier (gen_battles.py, C16b).
- Day-length meaning (Tom): "more game per day" vs "same progress per day" for the real-time
  systems (mine keepers, fishing, racket).

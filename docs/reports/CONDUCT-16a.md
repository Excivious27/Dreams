# CONDUCT 16a report: progression, balance, energy, skill ecosystems, museum (2026-11-21)

A pacing pass so the game lasts three years in every style of play. Your energy case is fixed (the day-1 gang mine route used 68% of the bar, now 35%). The mega regions now open by the calendar and by skill, not all in week 1. Year 2 and 3 gates hold back the deep mine, the top station tiers, the Grand ranch buildings, the iridium sprinkler and some legend fish. A 3-year simulator measures income for each style. New this round: a bug net and critter log, a longer museum ladder, a fishing ladder (stars, sizes, baits, legends), skill columns that open slowly, and ranks for partners, team animals, helpers and crew. 18 focus auditors (269 findings) fed 6 fix packages (scopes in /home/claude/wt/C16A_SCOPES.txt, contract in C16A_CONTRACT.md), then one hook integration pass. **Final full CI c16ai: PASS (first run: 4 of 6 shards, 20 bots, playtest and relay green; shards 1-2 caught a training-hall test that predated the loyalty rule, a skill-reset button word outside PadInput, and a faint-energy test that predated the new rule; fixed, shard 1-2 rerun green).**

**Whole game after C16a: about 82% done, 18% remaining** (average of the 127 systems in docs/inventory.csv). New rows: energy model 85%, 3-year simulator 75%, bug net and critter log 82%, museum ladder 80%, fishing ladder 78%, skill pacing 85%, recruit progression 75%. Moved: long-run progression and balance 50% -> 75%.

## Audit (18 focus auditors, 269 findings: 0 blockers, 123 major, 118 minor, 28 polish, plus 18 verified-clean notes)

| Area | Main findings |
|---|---|
| Progression (01, 15, 18) | All four mega regions opened on day 7-10 for every style. No year gates at all. Hook quests were tiny. T4/T5 travel was cheap and early. |
| Economy and sim (02, 16, 17) | No 3-year simulator. Racket and story money skipped the ledger. Weak crops, money stops being a gate in year 2. |
| Energy (03, 04) | Your route: 68% of the bar on day 1. Tree perks stacked below the floor. Growth items had no cap. Free meals refilled the whole bar. |
| Fishing (05) | Legend koi on two rule sets. No stars from the catch, no sizes, no special baits. Legends from Fishing 6-9. |
| Farm, ranch, mine, gear, crafting (06, 07, 09, 10) | Pickaxe tier counted twice. Gun and sword ladders uneven. Every station open on day 1. "Any" crops grew outdoors in winter. Helpers watered every crop. |
| Foraging and critters (08) | Forage re-rolled on every map entry. No bug net. |
| Skill trees (11, 12) | Every capstone column open by about level 19. XP pace differed about 10x between trees. Farming perks stacked to 5.7x. |
| Recruits (13) | Exotic team animals could not train. Team stuck at 2. Partner powers gave XP for nothing. Crew loyal in a week. |
| Museum (14) | Hints named script files. Few milestones. A legend sold before donating could never come back. |

## Fix packages

| Package | Fixed | Images |
|---|---|---|
| P1 Gates, travel, year 2-3, difficulty | Mega regions gated by calendar day and skill, each with a non-combat road. Hook quests 2-4x bigger with bigger rewards. `year` key in GameState._cond_ok, TravelNet and Builds.gate. T4 links, airship and T5 hops wait for year 2. Fares up. docs/PROGRESSION.md, tools/gen_progression.py -> data/progression.json, `Progression.unlock_day`, progression_test (110 checks). Difficulty foe_count. Hours-per-year words under the day-length button. | 0 |
| P2 Economy + 3-year simulator | tools/sim.gd rewritten (4 styles, both arcs, any day length, real game rules) + tools/sim_report.py -> docs/reports/sim/C16A-SIM.xlsx; sim smoke + tools/sim_bands.py in check.sh. Racket, wash, story and luck money go through add_money. Starfruit and dreamflower fixed. Late permits raised (C16A_PERMITS). economy.py retired. | 0 |
| P3 Energy | Your case fixed (table below). Pickaxe, sword and dodge cheaper. Tree perks now sit inside a 35% floor. Caps on eaten growth, food and rest recovery (scaled by day length). Stamina buff on coffee, tea, fish stew and salad. Miner's bench on floor 1 and every 5th floor. tools/energy_check.py + data/energy_bands.json, energy_route_probe.gd, end-of-day energy in the bots. | 1 |
| P4 Fishing, bug net, museum | Bug net and critter log (`BugNet`, `Critters`). Reel stars, fish sizes, 4 special baits, legends by level and year, fish log rungs, derby prizes by year. Museum ladder and hints, legend safety net. ForageRoll (a spot's find never re-rolls). Tests: critter_net_test, c16a_p4_fish_test. | 2 |
| P5 Farm, ranch, mine, gear, crafting | Pick swing fix and early rock relief. One weapon damage per tier, armour defence per metal, better guns. Station tier-1 gates and skill gates [1,4,9,16]; top station tiers year 2. Recipe levels `Crafting.RECIPE_LV`. `Mine.deep_lock`. "Any" crops sleep in winter. Helper watering caps. Dish buffs. Decor set arc twins. Show tables take exotic goods. Test: c16a_p5_test. | 0 |
| P6 Skill trees + recruits | Column ladder `GameState.TIER_NEED` / `col_need`. Per-tree XP pace `SKILL_XP_MUL`. Lower bonus caps. Respec fee after the first free one. Gang arc Sorcery shows as Tech. Partner ranks, team ranks and team size, 10 exotic team species, slower helpers and crew, fish and mine chores, pup XP caps. Test: c16a_p6_test. | 1 |
| Hook integration | Energy filler re-spread under P3's cap. Duplicate kill_energy key fixed. Mega hook quests wait for the same gate as travel (sim now opens the first mega region on day ~50). Starter Spark for old saves. Bug net energy row. Fishing bonus caps. Gang helpers forage meadow, woods and lake. | 0 |

## Your energy case (gang arc, level 1, wood tools, day 1)

Measured by tools/energy_route_probe.gd: meadow fight + mine floor 1 + half of floor 2 + the mine fights.

| | Before | After |
|---|---|---|
| Route energy | 82 of 120 (68%) | 42 of 120 (35%) |
| Floor 1 rocks to the keeper (mean / max) | 15.7 / 32 | 10.8 / 18 |
| Floor 2 (mean / max) | 14.7 / 31 | 10.2 / 18 |
| Pickaxe per rock | 2.42 | 1.58 |
| Keeper wait on floors 1-3 | up to 320 s | at most 110 s |

Swings per rock are unchanged (mining stays slow early by hits). Max energy curve: day 1 120, day 28 181, year 1 278, year 3 395.

## Key tuning numbers

| What | Old | New |
|---|---|---|
| Pickaxe / sword / dodge energy | 0.6 / 0.15 / 0.8 | 0.45 / 0.12 / 0.5 |
| Lowest energy cost (all perks) | 13% of base | 35% |
| Skill tree max energy | 120 | 60 |
| First mega region opens (sim) | day 7-10 | day ~50 |
| Skill column X opens at | ~19 points | 64 points |
| Station skill gates (tiers 1-4) | 1/3/5/7 | 1/4/9/16 |
| Recipe tier levels | 1/3/5/7/9 | 1/3/8/14/20 |
| Farming perks, full tree | 5.7x per plot | <= 3x |
| Legendary koi | Fishing 8, year 1 | Fishing 30, year 3 |
| Helper levels | 12/30/60/100 | 40/130/300/600 |
| Team animal ranks | 3 (1/4/7) | 5 (1/5/12/22/35) |
| Barn T4 permit | 15,000 | 40,000 |

## 3-year sim (docs/reports/sim/C16A-SIM.xlsx, 15-minute days)

Income per 112-day year:

| Style | Arc | Year 1 | Year 2 | Year 3 |
|---|---|---|---|---|
| Farmer | penguins | 123k | 211k | 278k |
| Farmer | gangsters | 99k | 290k | 539k |
| Explorer | penguins | 193k | 180k | 189k |
| Explorer | gangsters | 189k | 180k | 188k |
| Social | penguins | 67k | 152k | 238k |
| Social | gangsters | 64k | 247k | 387k |
| Hustler | gangsters | 236k | 523k | 628k |

- Mega regions now open around day 50 (farmer day 50, explorer day 52), not day 7-10.
- The explorer is flat across years (mine floor 74 by day 28, then little growth). The gang farmer earns 1.9x the penguin farmer in year 3. Both are open tuning items.
- The workbook was made on P2's branch before the other packages merged; the mega-region days come from the integration re-run.

## Bug net and critter log

- Nets: Twig Net (350 at Maple's), Silk Net (Foraging 15, ~1,500), Star Net (Foraging 35, ~4,950). Gang arc: Wire, Mesh and Neon Net.
- 13 critters on the seasonal wildlife, plus 4 season legends (Petal Emperor, Sunwing, Ember Moth, Snow Sylph) that need the Star Net, Foraging 40 and their own weather and hour.
- Catch and release: each catch is logged, nothing goes in the bag. A swing costs 0.25 energy.
- Critter log in the Book. Milestones: 5 (300 + a firefly jar), 10 (1,200), all (3,000). The museum's Live Exhibit wing counts logged critters.

## Museum milestones

5, 10 (500 + 10 bait), 15 (500), 20, 30, 40 (starfruit seed), 50 (2,500), 65 (4,000), all. Curator's Loupe luck 2 -> 4. 76 entries (penguins) / 75 (gang) with the Live Exhibit. A legend given or sold before donating can bite again at a quarter of its chance.

## Fishing ladder

- **Stars:** reel fast after the bite. Silver within half the window, gold within the first 22%. No stars on boots or legends.
- **Sizes:** each fish has a size in cm. The fish log keeps your biggest.
- **Baits at Finn's:** glow (Fishing 6), deep (10), magnet (12), wild (15). The best one in your bag goes on each cast.
- **Legends:** prism trout Fishing 14, sailfish 18, soul salmon 22 (year 2), frost pike 26 (year 2), legendary koi 30 (year 3).
- **Fish log rungs:** 5, 10, 15, 25, 30, all, with bait, money and a fish trophy.
- **Derby:** legends don't count, your fish is kept, prizes grow 25% a year (up to 2x).

## Skill tree pacing

Points spent to open each column: I 0, II 2, III 5, IV 9, V 14, VI 20, VII 28, VIII 38, IX 50, X 64. XP pace by tree: mining 0.6x, farming 0.75x, fishing 0.9x, foraging/combat/strategy 1x, hustle/harmony 1.2x, bartering/magic 1.8x, building 2x, ranching/pup 2.5x, leadership 3x. The first respec of each tree is free.

## Recruits and team ranks

- **Partners:** rank 1-5 (hearts / 2). Mend, Power Pose, stun and scout grow with rank. Powers give XP only when they do something (25 a day).
- **Team animals:** 5 ranks (lessons 1, 5, 12, 22, 35). Team of 2, +1 at Leadership 25, +1 at story tier 3. 10 exotic species can now train.
- **Helpers:** levels at 40, 130, 300, 600 chores. New fish and mine chores.
- **Crew:** loyalty steps 3, 7 and 14 days apart (with 0, 4, 6 hearts). Drill gives at most +1.
- **Pup:** bite XP only on a hit (40 a day); petting, fetch and digging give more.

## Year 2-3 gates

| Year | Opens |
|---|---|
| Year 2 (day 113) | Mine floors 101+, top tier of every 4-tier station (Creamery, Cellar Vats and the rest), Grand Barn, Grand Enclosure, Grand Aviary, Grand Terrarium, Star Dome, iridium sprinkler, Windward Isles / Gilt City, T4 hub links, airship and airstrip, T5 hops, soul salmon and frost pike |
| Year 3 (day 225) | The Hollow Heart (floor 150), legendary koi |

## Images and audio

**Images: 4** from dreams-image (P1 0, P2 0, P3 1, P4 2, P5 0, P6 1): the stamina buff icon, a critter and net sheet (20 icons), a bait sheet (4 icons) and two chore icons. All sliced and placed. **ACE: 0.** Art prompts: none needed.

## Timing

| Stage | Role | Effort | Minutes |
|---|---|---|---|
| Auditors (18 focus, read/play-only), 08:00-08:30 PT | auditor | medium | ~30 |
| Packages + contract (269 findings into 6 packages), 08:30-08:45 | conductor | medium | ~15 |
| Fix agents P1-P6 in parallel, 08:45-09:20 (server restart mid-run, resumed) | fixer | medium | ~35 |
| Merges, 09:20-09:25 | integrator | medium | ~5 |
| Hook agent, 09:25-09:40 | integrator | medium | ~15 |
| Final full CI c16ai, started ~09:45 | CI | | PASS (shards 1-2 rerun) |
| **Total** | | | **~1.75 h wall clock (08:00-09:45) + final CI** |
| Agents per effort | | | 18 medium auditors; 6 medium fixers; 1 hook integrator |
| Images used | | | 4 |
| ACE credits used | | | 0 |

## Still open

- **Gates:** progress_tier calendar floors and boss-only tier steps, gang non-combat tier roads and campaign provisions (C16b). Greenhouse day 57 and permit 3,000. Hearts twice as slow (needs a save migration). The farmer's first mega region is day 50 (the band wanted 56+).
- **Energy:** late game the bar barely limits a full day (your call 2). Hustle vs Harmony energy still a little uneven. The sim's explorer uses 73% of the bar on days 1-3 (a warning; the real route probe is 35%).
- **Economy:** explorer income flat across years, gang farmer 1.9x the penguin farmer in year 3, hustler racket ceiling. Coffee and tea prices. Bot telemetry and a progression CI job.
- **Fishing:** a reel fight mini-game (needs bot updates), tackle slots, charters, fishing helpers, pond tiers, a timed derby with size scoring.
- **Museum and forage:** a second hall (seasonal, lore and gang wings, Theo), a guard before selling undonated legends, forage gear and legendary forage, journal milestones.
- **Farm, ranch, crafting:** area hoe and can, fertilizer tiers, gang ranch creatures (your call 1), masterwork recipes, home renovations, tailoring, gang dishes.
- **Skills and recruits:** capstones and mastery, ally battle ranks (C16b), per-partner quests, helper hut, crew level cap 5, pup gear.
- **Day length:** whether longer days mean "more game per day" (now) or "same progress per day".

## Tom's calls

1. **Gang-arc ranching.** (a) stronger lab "advanced splice" strains, or (b) 8 gang "street creatures" tied to gang regions. Default: street creatures, in C21/C22 if time.
2. **Late-game energy.** The bar barely limits a full day from year 1 on. Options: tougher deep rocks, higher late costs, or a smaller late bar. Default: tougher deep rocks in C22.
3. **Max energy.** With every source collected it reaches 560. Default: keep. A cap near 400 would cut friend and house rewards.

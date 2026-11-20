# CONDUCT 4 report: Mega regions, difficulty modes and day length (2026-11-19)

Run on the personal account with the standing process. First, 20 read/play-only auditors (docs/reports/C4-SCOPES.txt). The 20-bot playtest from the CONDUCT 3 wrap-up served as this round's baseline: 20 runs, 0 fails. Then 6 file-disjoint fix packages, one merge, one full check.sh, the bots and the playtest. The packages are in docs/reports/C4-PACKAGES.md, and every finding is in the c4_NN reports.

**Whole game after CONDUCT 4: about 64% done, 36% remaining.** Mega regions are now at 88%, and difficulty and day length are done (90%). The total dipped from 66% only because two more systems Tom added today count at 0% until their CONDUCTs run: hazards, jumping and the lava region (C20), and The General Store (C21). The systems already built average about 83%.

## Audit (20 auditors)

| Area | Main findings |
|---|---|
| Unlocks and travel (01) | The gangster arc couldn't reach Space at all. Gates named the wrong chapter. Windward and Gilt opened only before the finale. Gloamwood opened in week one. The Hollow Heart couldn't be found. |
| Map UI (02) | The region map sat below the fold, dragging on it didn't scroll, the title banner covered pins, and painted maps had solid blobs over their landmarks. |
| Gloamwood, Sunscorch, Frostpeak, Windward, Gilt and Ironline (03-07) | **Looks:** fireflies drawn as a fixed grid; straight concrete-slab paths; green trees in themed biomes; caves that looked like open fields; a window opening still too wide on Windward's exits. **Content:** bosses that reused other art; a shop selling an item that doesn't exist; a fish worth 0. |
| Original mega regions (08) | The gangster arc got penguin story on the moon. All four colonies shared one map. The station and jungle were thin. Names didn't match between the map and the HUD. |
| Enemies (09) | Every mega foe paid 3. Region bosses were tougher than the arc finales. Packs were lopsided, and ordinary foes set off the elite music. |
| Economy (10) | Ore rocks came back on every re-entry (about 3,800 a day). Most new materials could only be sold. Boss prizes were weaker than things you could buy. |
| Quests (11) | The quest compass never pointed at mega quests. There were no progress counts. Wording was wrong ("12 thug cash"). |
| Audio (12) | Every boss played the generic boss song. Birds sang in caves. Vehicle travel was silent. |
| Performance (13) | Colonies were the slowest maps, some areas had 700-900 nodes, and some arrivals landed you right on an exit. |
| Exploration (14) | About 30 areas shared one path layout, there were no hidden areas at all, and chests sat in plain view. |
| Difficulty design (15) | The old global "easy" switch also weakened your allies' damage, was shared by every save slot, and waived non-combat fees. |
| Day length design (16) | A day is 14 real minutes now. Combat buffs and mana must stay in real time when days get longer. |
| C3 regression (17, 18) | Crystal Kin couldn't be used. Reopening a fight brought the captain back at full health. Summer tall grass walled off 25% of the farm. The gangster arc still said "sword" in places. |
| Bugs (19) | The "stuck Plans board" was B being ignored for 12 frames after a menu opened. Bots never visited the newer areas. A few foes were placed inside walls. |
| Docs (20) | The inventory lagged behind Tom's decisions. About 34 money adds bypassed `add_money`. |

## Fix packages

| Package | Fixed |
|---|---|
| P1 Difficulty + day length | **Difficulty:** Very easy / Easy / Default / Hard, for combat and battles only, per save slot, set on the new-game screen and in Settings. Foe HP is a separate multiplier, so ally damage is untouched. Boss HP, foe damage to you and to allies, status effects, wind-up time, battle tickets, enemy caps, waves, convoy, hold, capture, supply, morale and mine keeper packs all scale. Clinic fees change only for combat faints. The old Easy setting migrates. Co-op guests follow the host. **Day length:** 15/20/30/40 real minutes per day, per slot; mana and combat buffs stay in real time; co-op guests follow the host. **Also:** every money payout now counts toward "earned in all", and mega ores need the right pickaxe tier. |
| P2 Mega region data | **Balance:** bosses at about 0.55x HP, tiered trash and real rewards (bosses 300-1000). Unlocks per arc, with the next step named, and bosses wait for the hub job. **Gangster arc:** its own Gloamwood, Sunscorch and Frostpeak bosses, and thug reskins on gangster campaigns. Finargle Drones. **Economy:** Hot Cocoa, Ember Koi, Sparkling Wine, fixed prices, boss charms +1, an ore respawn wait and a generator id check. **Quests:** Rahim's sunstone job, Rolled Bills. **Looks:** per-look scatter and border trees, cave areas, Vault and Garden props, the fountain, the Thornmother moved by her pool, and per-area songs with fallbacks. Colonies no longer share one map. exit_edge_check covers every mega area. |
| P3 Region runtime + exploration | **Exploration:** every mega area has a hidden pocket (vine curtain or cracked wall) and a secret way (worn steps or a crack). Pups sniff near them and they sparkle at dawn and dusk. The Sunscorch inner sanctum opens after the Colossus. Journal pages cover 27 more areas, and chests are tucked away. **World:** ore rocks respawn by day; foes, doors and villagers are kept out of walls; fireflies drift; void exits open only the path lanes; soft ice and water patches; spawns sit away from exits; critters are capped. **Gangster arc:** a cargo rocket takes you to Space, with your own moon lines. **Also:** the HUD uses mega area names, and the Hollow Heart has hints. |
| P4 Mega UI, travel, quests, audio | **Map tab:** a scrolling tab strip, the map on top, drag scroll, pin cards (where it is, what holds it, how to get there, "Next here"), ring pins on painted maps, and the hub's every way in. **Quests:** the tracker points at mega quests, shows item progress and has a "Follow the story" row. **Travel:** travel points appear with their letter, gate words name the next step, and rides have sound both ways. **Audio:** 7 mega boss themes, plus storm, station and thicket songs (10 ACE tracks); caves and dry areas fall quiet; day and night ambience beds. |
| P5 Art | Thornmother, Sun Colossus, three gangster bosses, desert foes (dune crab, sand hound, sun moth, glass golem), casino guard, rail bot, boss cards, hidden-area kit, station kit, alien trees, knitwear and boutique stalls, cloud-stone cliffs, glass decals, firefly glows, Gloam NPC walks, community-farm beds and saplings. |
| P6 Battles, farm, bugs | **Battles:** Crystal Kin at spawners, captain HP kept on resume, the team spawns in a ring with readable tags, "CAPTAIN" printed once, and the team pushes on its own in early fights. **Farm:** walk-through tall grass, hay half the time, a 3-cell scythe sweep. **Menus and bots:** B always backs out, bots and reach_all visit mega areas, and Plans Back returns to its category. **Pauses:** `Hud.pause(owner)` with owner logging. **Gangster arc:** weapon words fixed and a Crowbar at vendors. **Also:** the gold revolver has its own sound. |

Tom's 20:03 decision is in: wines are trade goods (crafted, sold, gifted, never drunk), Maison Dorée sells Sparkling Wine, and real gambling is allowed for the casino.

## Tests added
difficulty_test, day_length_test, hidden_area_test, mega_ui_test; save_test, coop_test, phone_ui_test, battle_win_test, farm_debris_test and softlock_test were extended.

## Still open
- Some full redraws still run 64-89 ms (coral, hollow_heart, thicket, vaults), though every map's p95 frame is under 32 ms.
- Scatter is not baked into the ground, and colony water is not merged.
- Convoy progress on resume.
- c_colony_ember still needs its own battlefield.
- Regrowth by rarity on maps other than the farm.
- Three songs: Moonpool, Canyon, Temple (they fall back to older tracks for now).
- Small plateau cliff sides.
- Pockets are not yet tied to path dead ends.
- Cities pin positions on the map.

## Timing (from commit times; paused 20:14 for the CI optimisation)

| Stage | Start | End | Minutes |
|---|---|---|---|
| Auditors (20) | 18:30 | 19:10 | 40 |
| Package draft | 19:10 | 19:20 | 10 |
| Fix agents (6) | 19:20 | 20:03 | 43 |
| Merge + local tests (godot lock contention) | 20:03 | 20:14 | 11 (+ local check.sh waits) |
| CI verify (6 shards + 20 bots on GitHub) | 20:43 | see Baton | — |
| **Total to merge** | | | **~105** |

## Questions for Tom (defaults in place)
1. Should the three gangster bosses in Gloamwood, Sunscorch and Frostpeak get their own songs? (Default: they share their region's theme.)
2. Is the stand-in train departure sound OK? (Default: keep it.)
3. Gangster vendors sell a Crowbar, not cheap Street Bat upgrades. (Default: keep.)
4. Do hidden pockets ringed with crates in cities, or hedges in Gilt, read as hidden enough? (Taste check while playing.)
5. Difficulty: Hard gives no extra loot, Hard keeps the normal clinic fee, and Very easy bosses hit softer. (Defaults.)
6. Day length defaults to 15 minutes (today's pace).

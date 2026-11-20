# Dreams: Status

**Play:** https://excivious27.github.io/Dreams/

## 2026-11-19 — CONDUCT 5 fix P1: farm and home look

- Farmhouse upgrades show their own art (house / house_2 / house_3, day + night pictures swapped at dusk), with the solid rect, door, mailbox and exit spawn following the tier (`farm.HOUSE_TIERS`, `house_look(tier)`); the Manor stands where the old greenhouse plot was.
- Greenhouse plot moved to south-east open ground (`GameState.GREENHOUSE_PLOT` 19,20 9x6) with the greenhouse in front (22,19), beehive (29,19), scarecrow (21,15); old saves: plot crops move once (flag gh_plot_c5), soil/placed things under buildings move (`_migrate_layout`). Stone kerb round the bed.
- Coop/barn drawn at house scale; bigger coop pen; wooden (gangster: chain-link) pen fences with an open gate; no decor tufts in pens.
- Animals: per-kind true-to-life heights (`FarmAnimal.TARGET_H`, babies 60%), goat drawn from goat2, width-sized shadows, two-row huddle at night/rain/winter.
- Crops killed by the season's turn stay as withered plants until pulled (any tool or hand). Planting plays "hold"; tilling turns the soil at 0.25 s with a dirt puff; watering splashes.
- Debris never on a path or its soft edge. Test: tools/farm_look_test.gd (check.sh).

## 2026-11-19 — CONDUCT 4 fix P1: difficulty modes, day length, money routing
- **Difficulty (Tom):** Very easy / Easy / Default / Hard per save slot (run.opts.difficulty, default Default), chosen on the new-game page (Difficulty button + one-line description) and in Options; COMBAT AND BATTLE CAMPAIGNS ONLY. `Difficulty` (scripts/difficulty.gd) holds the c4_15 table: foe HP (own `Enemy.diff_hp`, after hp_scale, no floor), boss HP (once, inside `Battle.boss_hp`), foe hits on you (`GameState.enemy_damage`, Very easy floor 3), on allies (`Enemy.ally_damage`), status length/power, wind-up time, battle tickets/cap/waves/convoy/hold/enemy capture/supply/morale loss (`Campaign.battle_data` -> `foe_capture`/`supply_mul`), mine keeper pack size, clinic fee only after a combat faint (`Faint.fee(clinic, floor, reason)`). Old global Easy switch migrates to Easy per slot and is gone. Hero tab shows the mode; campaign danger words light/fair/tough/fierce; co-op guests play at the host's mode (run.opts in Net.WORLD_KEYS). Hard gives no extra loot.
- **Day length (Tom):** 15/20/30/40 real minutes for the 6am-2am day per slot (run.day_len, default 15; new-game page + Options; locked for a co-op guest, host's value via WORLD_KEYS). `GameState.minutes_per_second()` / `day_len()`; real-time timers use `GameState.real_min(sec)` (gift gale/iron buffs, haste, warden) and mana regen runs on real seconds (`GameState.mana_regen_secs()`, 14 s). Save slot info shows mode and day length.
- **Money:** every earning in campaign/campaign_gate/battle/kill pay/mine/mail/ops/town/community farm/craft/farm/region goes through `GameState.add_money(n, source)` (bank withdrawals stay direct: not earnings). Mega ores have ORE_TIER/ORE_SKILL (tin 2, sunstone/sapphire/frost/star dust 3, storm glass/platinum 4).
- Tests: tools/difficulty_test.gd, tools/day_length_test.gd (check.sh, --fixed-fps 60); save_test (per-slot opts, legacy Easy), coop_test (guest follows host), phone_ui_test (new-game page, slots), early_fight_audit DIFF=0..3.
## 2026-11-19 — CONDUCT 4 fix P5: art for C4 (image tool)
- **11 renders** in art/incoming/c4/, sliced by `tools/slice_c4_p5.py` (look at each step's output; contact sheets checked, bosses checked in game with `tools/c4_p5_enemy_shot.gd`).
- **Enemies (face right, 2x detail):** thornmother, sun_colossus (walk 4, idle, attack 3, hurt); gang_boss_gloam (garden-syndicate boss), gang_boss_desert (smuggler king), gang_boss_frost (ice-hauler boss); dune_crab, sand_hound, sun_moth, glass_golem, casino_guard, rail_bot. enemies.json: the 7 kinds that already existed now use their own art (no borrowed art/tint; `gen_mega_new.py` does the same whenever `enemies/<kind>` exists). casino_guard and the gang bosses are art only (P2 wires kinds).
- **Boss cards:** ui/card_thornmother, card_sun_colossus, card_gang_boss_gloam/_desert/_frost (shared gold frame, boss on the left).
- **Props/kits:** props/hidden_crack_wall, hidden_vine_curtain, hidden_stairs, hidden_cave_mouth_cave/gloam/desert/frost/city; props/stall_knit, props/boutique_gold; nature/alien_tree_a..c; kits/station/station_wall, _window, _door, _pipes, _console, _corner; decals/glass_a..c; cliffs/cloudstone_strip, _side_l, _side_r (same size as grass_*); fx/firefly_0..3 (24 px glow pulse, procedural); props/cf_bed_halfdug_a/_b, cf_sapling_staked_a..c, cf_saplings_staked.
- **Gloam villagers:** mg_liesl, mg_fenn, mg_bramble get real 4-frame walk_up (back) and walk (side) strips and a back idle_up.
## 2026-11-19 — CONDUCT 4 fix P2: mega region data
- **Balance:** mega trash raw hp by tier (t2 ~8-10 ... t4 ~14-24; none >= 36, so no false elite music), region bosses x0.55 (Thornmother 85, Colossus 105, Coalbrook 115, Wyrm 125, Roc/Aurum 140 raw), rewards: trash 0.3 x scaled hp, bosses 350/550/850 by tier; drop chances normalised to ~3.4 crystals per raw hp. No tier-0/1 base kinds in late areas (rime_wisp, tunnel_bat, mill_runner, gilt_runner); rime_wyrm/frost_spider chill; Finargles are "Finargle Drone" (also the Sky Isles); stronger tints on near-white kinds.
- **Unlocks:** unlock tier = first area tier - 1 (Gloamwood t1 with t2 areas, Windward/Gilt t3 = after the sky stair / after neon, their areas t4 with t5 boss areas); every region boss waits for the hub job (Moonpool's Thornmother after Liesl's nets); locked travel points name the real story step per arc (mega_travel.json unlock.hint).
- **Gangster bosses:** Rosa Thorne (Moonpool), Dune King Vasco (Sunken Temple), Big Ike Frost (Summit) with their own lines (region.gd reads title/win/after _gangsters).
- **Economy:** hot_cocoa at Ingrid's, ember_koi and Sparkling Grape Cordial items (Fine Wine gone), Storm Fluff 480, Frost Sorbet 480/580, boss charms best-for-tier +1, Gilt Chip text, keepers' hidden friendship dropped, mrock `every` 3-7 days by ore tier; gen_mega_new.py refuses unknown ids (shops, loot, fish, forage, drops, quests, recipes).
- **Words/quests:** Rolled Bills, Ironline "the town square", Rahim's sunstone job (mega_sunscorch_rahim), Gull points at the Sunrise Shelf pool, no "Colossus walks at noon".
- **Looks/audio data:** per-look scatter themes + border stands (gloam mushroom/crystal, snow pines, desert dry), cave areas flagged "cave" (no critters, cave scatter), Vaults/Gardens props instead of the crystal shrine, Casino fountain uses fountain2, Thornmother by the pool; new area songs named with `music_fallback`.
- **Battles/colonies:** gangster campaigns field thugs instead of soldier/archer/knight/grump; Kelp Hollow and Emberclaw are the mirrored colony plan, more forage. exit_edge_check now walks every mega area.
## 2026-11-19 — CONDUCT 4 fix P4: mega map, travel, quests, audio
- **Map tab:** one sideways tab strip, the region map right under it, Campaign button below (hidden when locked on region tabs); map passes drags; painted maps get pin plates instead of solid blobs and a translucent "?"; the title ribbon dodges pins; hub label lists every way in.
- **Pin cards (Tom):** tap a pin -> card under the map (name, visited, danger stars, what holds it, how to get there, "Next here:" quests handed in there); it scrolls into view.
- **Travel (Tom):** vehicles/booths/rings appear only once the keeper's letter has come (`MegaTravel.shows`); locked gates name the real story step per arc (`MegaTravel.gate_words`, no "chapter N"); a region's map tab opens the moment its hook is done; ride sounds both ways (`MegaTravel.travel_sfx`: train_depart, sled_bells, airship_whoosh new CC0 mixes; horse, car_start/car_door, sparkle).
- **Quests:** Quests tab has one "Follow the story" row + plain story lines; tracker points at gate_* keepers (travel point / exit toward it) and mg_* villagers (their area, or the way to the hub); item-list quest progress ("Wildflower 0/6"); `GoalLine.adj` reads mega exits from regions.json.
- **Banner:** area-level title (Ironline Frontier, not Lieutenant Cities), moved below the goal line.
- **Audio:** 10 ACE songs: boss_thornmother/colossus/wyrm/roc/coalbrook/aurum/light_eater (GameMap.MEGA_BOSS by kind stem, MEGA_REGION_BOSS by region fallback, in BOSS_TRACKS), mega_wind_storm, mega_station (AREA_MUSIC station), mega_gloam_thicket. Ambience: `Ambience.is_cave/is_quiet` (regions.json "cave"/"quiet", defaults MEGA_CAVES + dry Sunscorch): no birds/crickets/frogs in caves, drips on; "amb_day"/"amb_night" beds; crowd/town beds thin at night. Removed region.gd's second boss play.
- Test: tools/mega_ui_test.gd (in check.sh); mega_region_test / quest_tracker_test updated for the strip and story row.
## 2026-11-19 — CONDUCT 4 fix P6: battles, farm, bugs, pauses
- CONDUCT 4 fix P6 (battles/farm/bugs/pauses): Crystal Kin buildable at spawners (`Battle.spawner_kinds()`: data kinds by arc + flag, cost from data); resumed fights bring the captain back as hurt as left (fight state `boss_hp`); team spawns on a ring with alternating name-tag rows; goal line says "CAPTAIN Bramblesnout" once; tier-1 fights: the team pushes to the captain / nearest point until you give a RALLY order (`map.team_push`). Farm tall grass is walk-through (sways + rustles), weeds stay solid; meadow clumps give hay half the time; scythe cuts a 3-cell swath (`farm.scythe_sweep`); grass regrow days consistent. Dialogue: B leaves a menu even while it settles; bots retry B and visit the mega areas (reach_all too). Pauses: `Hud.pause(tree, owner)`, the orphan-pause warning names the owner, GameMenu/ArcadeGame close only restore a pause something still needs, BattleBrief counts in keep_paused, `GameMenu.last_press` set by every menu button and cleared on close. Plans board Back returns to its category. Gangster weapon words (meadow toast, USE icon, Gideon), vendors sell a Crowbar in the gang arc; gold revolver `shot_heavy`; rounds fired persist (run.mag_used). Community farm build wording follows the nights done; greenhouse frame from night 1; Rec Cup uses DAYS_PER_SEASON.
## 2026-11-19 — CONDUCT 4 fix P3: region runtime + exploration
- **Hidden areas (Tom's exploration rule):** `HiddenArea` (scripts/hidden_area.gd) gives every mega area a pocket (a nook dug into a wall mass behind a vine curtain you part with A, or a cracked wall you break with the pickaxe; chest at tier+1 and, in the 27 newer areas, a journal page) and a secret way (two hidden ends: worn steps up onto a hill when the area has one, else a crack across to a far quiet corner). The pup sniffs when you're close and a sparkle shows at dawn/dusk (also over undug caches). Sunscorch: a sealed sun door beside the Colossus opens after the boss (inner sanctum chest + page). Pockets never wall in an arrival or cut anything off (flood check); art names from P5 (props/hidden_*), drawn shapes until then.
- **Secrets:** `chests_total()` (the toast no longer says 25/19), `POCKET_PAGES` lore for 27 areas (pages_total 34 penguin / 39 gangster), chests prefer tucked-away spots.
- **World runtime:** ore rocks respawn by day flags (`every` or 3-7 days by ore tier); foes, villagers and unreachable locked doors are moved/cleared onto reachable cells (uptown 26,11; iron_mill 12,10; colony foes); void-border exits open only the path lanes; default_spawn 3 cells inside exits; mega critters capped at 5, none on "cave" areas; cave_ice/cave_water/grass_dry feature blobs drawn soft; fireflies are drifting glows, no tiled orb grid.
- **Gangster Space:** the smugglers' camp on the mountain flies a cargo rocket to the moon (sets the launchpad beacon); moon lines/foes/spire words per arc; Star Crystal notes read as narration in that arc; moon foes spawn >= 64 px from you.
- **Names/hints:** PlaceNames uses mega area names first (Star Station, Cloud Isles...); Hollow Heart hints (lift row "Floor 150 · ???", Granite's chalk at 50/100, a letter at floor 100).
- Tests: tools/hidden_area_test.gd (in check.sh, ~10 s: 45 areas both arcs, 46 pockets, 45 ways, access checks), mega_regions_test (skips sealed nooks), mega_region_test, door_check, r13_world_test, invisible_walls on mega maps.

## 2026-11-19 — CONDUCT 3 fix P1: campaign design, data and words
- **Grumps (Tom):** penguin campaigns fight Grump variants (once Crystopia crystals the Dark Crystal turned): grump_crystal (tough, shard volley), grump_storm (violet zaps), grump_frost (slows), grump_coral (mends itself), grump_ember (burns, flares up), grump_moss (ambush, roots), grump_brute (big), grump_wisp (fast flyer), plus a named grump captain per penguin campaign (gcap_<region>, e.g. Captain Bramblesnout, Frostjaw, Stormcrest) on boss/gate nodes. Written by gen_battles.py into enemies.json; until P4's `enemies/grump_<v>` sheets exist Enemy draws the grump with `fallback_tint`. No soldiers/archers/knights/thugs in penguin lists.
- **Leaders (Tom):** each campaign has its own leader list (gen_battles LEAD; `Campaign.who` picks the first you've met): partner (Pip-Pip/Nova) early, Big Jim highlands/sky, Coldy station/ice, merkitty elders on the islands, Catkins only on ruins/jungle. Battles and briefs use it.
- **Crystal Kin (Tom):** crystal babies are foes in early penguin boards; after a won battle with them the board offers their nest: a gift (2 Refined Crystal) or Meow Pow Wow (once taught) turns them into Crystal Kin (flag crystal_kin; helper kind data in battles.json "_helper_kinds" for HelperUnit).
- **Easy early, slow build:** gangsters start with The Highway Job (docks after countryside), uptown after underground (both t4); penguin Cloud Stair t3 after Wastes + Highlands; no escort openers on t1-2 boards; escorts easier (cap -2, slower waves, convoy 80+25/tier, tickets scaled); siege tickets 150+40 per fortified point over 3; +1 enemy cap per tier after t2; tier-1 boss at the countryside gate; bigger muster supply, supply never below 10 after a fight; retreat keeps supply/3, morale -15.
- **Per arc:** Wastes and the four islands are penguin-only; shared campaigns have gangster intro/won lines (`Campaign.text`), truck escorts, gangster point names, "crew" not "army"; penguin win/loss lines (crystals turned back, captains freed, Meow Pow Wow only once taught).
- **Words:** gate words follow the whole chain (`first_in_chain`, "N more"), no false geography, the board opens on the campaign to do; goal line always <= 112 chars.
- **Economy:** kill pay per campaign node (`Campaign.kill_pool`, 80) and drill; cache share ~0.8x the goods; no stray gate item; arc items scale by tier and show on the gate; gangster rewards swap refined crystal for data chips.
- **Board / brief / saves / projects:** island and highland backdrops, list sorted by state, "march, then attack", briefing auto once, varied board shapes; briefs have "Not now" (B, no cost); launch/muster blocked while visiting; cs() fills old saves; ferry gates on the island campaign; Sky Lens +20 island muster supply; honest Prism/Aurora texts; overnight project lines in the morning report.
- Test: tools/campaign_c3_test.gd (in check.sh); campaign map/story/words tests updated.
## 2026-11-19 — CONDUCT 3 fix P4: themed battlefields and battle art
- 11 new battlefields, one per campaign region (tools/bf_themes.py, built through gen_battles.battle()): bf_highland_pass, bf_quarry_cut, bf_river_ford, bf_ruin_court, bf_cloud_stair, bf_station_deck, bf_jungle_grove, bf_reef_shallows, bf_kelp_beds, bf_uptown_plaza, bf_sewer_works. Each has its own ground/seam, border (snow pines, cliffs, cloud trees, hedges, palms, sea, dark void), scatter theme, landmarks and one of 4 layout families (river split, ring, diagonal ridge, open plain); lanes run camp -> hub -> each point. `bf_themes.campaign_field(region)` names the field for each campaign (P1 maps campaigns to it).
- Original 8 fields: north points 4 rows lower (row >= 24, clear of the HUD), Frostfield on snow, Dockside on dock concrete with a north sea edge and piers, Vale dense with crystals, themed borders/scatter (dead trees on ash/rail, city blocks on neon).
- Scatter filtered by theme (`WorldGen.theme`, regions gen.theme): no green tree clumps, logs or berry bushes on pavement, decks, sewers, ash or snow; themed border stands (`border_trees`, hook in GameMap._build_border); themed band undergrowth (dress_band).
- Art (dreams-image, 10 images): 8 grump variants enemies/grump_{crystal,storm,frost,coral,ember,moss,brute,wisp} (idle/walk/attack/hurt), helpers/crystal_kin_crystal_{idle,walk,act,hurt}_N + helpers/crystal_kin, props/crystal_pylon (+_0.._3: glow, zap), props/bf_cairn, bf_ruin_pillar, bf_ruin_wall, bf_weir_gate, bf_sky_pillar, bf_sewer_mouth. Slicer tools/slice_c3_p4.py.
- Test: tools/bf_themes_test.gd (in check.sh): every bf_ field loads, points dry/open/reachable and below the HUD, tree-less themes grow no trees, new art present. exit_edge_check covers the new fields.

## 2026-11-19 — CONDUCT 3 fix P6: quest tracker, Street Bat, farm debris, saves, HUD
- **Quest tracker (Tom, Guide 26 #18):** Menu > Quests is a checkbox list (story steps, townsfolk jobs with their count or "ready"); the ticked quest drives the goal line and a small themed compass by the clock (ice-blue rim for penguins, brass/neon for gangsters) with cells-to-go or the job's count, and a bobbing chevron over the target when it's on screen. It replaced the screen-edge arrow. In the mines it always points to the way down (the shut shaft site before it opens, then the open shaft or the awake keeper). `QuestTracker` (scripts/quest_tracker.gd), `GoalLine.exit_toward`. Test tools/quest_tracker_test.gd.
- **Street Bat (Tom, Guide 26 #1):** the gangster arc starts with a Street Bat instead of a sword: same starter weapon underneath (id "sword": tiers, bench, damage), named and drawn as a bat at all 8 tiers (items/bat_<tier>, new art, tools/slice_c3_p6.py). Gun shots sound by the gun in hand (scattergun/shotgun, tommy gun/rifle, revolvers), and a reload sound after each load (`Player.MAG`). Test tools/street_bat_test.gd.
- **Farm debris (Tom, Guide 26 #23):** cleared debris grows back on a rarity ladder (farm.REGROW: grass 4 days, weeds 7, logs/stumps 21, rocks 28, trees 56; stone/wood never by the house or beside soil and placed things); weed spots and new tall-grass meadows change each season (lush summer, gold fall, thin frosted winter; new art nature/tgrass_<season>, weed_<season>); tall grass always gives hay to the scythe plus fiber. Test tools/farm_debris_test.gd.
- **Saves (c3_15 F1/F2/F4):** a save on a battlefield with no fight or drill under way reopens where the fight was launched from (or the farm) and drops the stale fight record (`GameState.battle_resume_fix`). save_test covers it.
- **HUD:** toasts wait while a battle choice menu is open; long choice lists pin the way-out row below the scroll; tool tips only where they fit (none on battlefields, hoe/can/seed tips on the farm only); `GameState.add_money(n, source)` counts payouts in earned_total (run.earned_by per source); the ownerless-pause watcher now counts every full-screen UI as an owner and names the scene/layers/last menu press when it fires.
## 2026-11-19 — CONDUCT 3 fix P5: rec, arcade, community farm, town (Guide 26 answers)
- Gangster cabinet names: Whack-a-Snitch and Neon Range (Tickets.game_name; game titles, how-to, quests via `text_gangsters` + a small hook in quests.gd).
- Rec keeps growing for months (Tom #3): `RecReno` (scripts/rec_reno.gd; gen_rec RENOVATIONS) announces five renovations after the opening (arcade wing day +18: Whack/Neon Range; Skee-Ball Alley +42; jukebox lounge +66; prize gallery +92: top prize shelf; trophy hall +120). Each has a start letter, 3-5 days taped off ("A: under renovation"), an open letter; then a seasonal Rec Cup (score to beat, ticket pot, once a season). Desk board lists work and the cup.
- Gangster Rec Hall open 9am-2am (`hours_gang`, `RecCenter.day_hour`). Prize Candy is a loved gift for anyone who likes candy (item `loved_by`, GameState.gift_value hook).
- Community farm builds take 2-4 nights each (shed 2, beds 2, well 3, orchard 2, greenhouse 4): nightly progress lines in the sleep report, journal/board "night 2 of 4", Hazel's words, and half-built pieces on the map (new art cf_build_frame/well/greenhouse/sawhorse, tools/slice_r13_c3_p5.py).
- Good friends (4+ hearts) let you into their home until midnight, with a wave-in toast (TownHours.late_friend).
- Tickets drawn as a ticket stub (`Tickets.draw_ticket/draw_amount`), no more ♦ next to crystals' ◆. Bowling versus sheet shows the opponent's full name (fitted). Lambda-capture-freed errors fixed (weakrefs in RecAudio.lane_sound, CfVolunteers._back). cf_volunteer_test is deterministic (game-time waits, seed, --fixed-fps 60).
- Whack-a-Snitch critters: original fedora snitch rats (plain, gold, hard hat, dizzy) for the gangster arc (art/gen/arcade/whack_snitch*, `ArcadeWhack.sprite_for`). Screenshots checked: whack play, prize counter stubs, versus sheet (full "MAYOR ALDER" on a plate), half-built shed/well/greenhouse on the farm.
- Tests: new tools/rec_reno_test.gd; extended gang_flavour_test, town_first_test, commons_test.
## 2026-11-19 — CONDUCT 3 fix P2: battle runtime, helpers, battle audio
- Your mustered team takes the field: up to 4 of CampaignGate.team (not the partner already with you) fight as named HelperUnits drawn with their own sprites (strikers, a healer, a warden); they walk with you unless sent to a point and fall back to camp instead of dying.
- Commanders: HP floored by campaign tier (`Battle.boss_hp`, T1 60-96, capped for T1-2), T1 captains hit softer, boss tier follows the field's enemy tier (tier_bonus too), the commander leads a push after 20 s; boss theme + horn + DangerMusic.boss_started on spawn, wind-down to the fight's song on the kill.
- Helpers: spawn on the nearest free dry cell (`HelperUnit.free_spot`), walk out of blocked cells, catch up at up to 100 px/s when left behind, poof back beside you past 400 px, keep 8 px apart, healer/warden act only when they really heal/shield (healer mends the pup too), Shade veil on game time, extra kinds from battles.json `_helper_kinds`; "Healer Crystal" rename; dying foes are never targeted.
- Waves: first wave ~2 s after the briefing closes (clocks wait while it is up), half-taken enemy points settle back and spawn again, gates spawn at the ring's far side (no camping them shut), every 4th wave a squad of 3 at the target, faster when they hold <= 2 points, you count as 2 defenders, decoys/minions never count as kills, a lost point drops its level/walls. Turret/Crystal Pylon (`scripts/battle_turret.gd`) stands with the allies (holds rings, can be broken; penguin pylon art).
- Drill: risk-free (KO/tired/late -> trainer pulls you out, half health, no fee/faint), step card above the touch deck and hidden while the trainer talks, short spoken lines, 7 px text, leaves on the win, follow step waits for a helper (first drill helper at once), XP paid in one go.
- HUD/audio: RALLY button 21 px, rally toasts replace each other, "No helpers yet" picker, pips 7 px clear of the ticket bars, open rings with a dark under-stroke; battle song from frame 1, jingles once (Campaign.finish owns the win; KO leaves it to the faint), music ducks at the end, sfx for helpers, point menu, spawners, turrets; `DangerMusic.boss_ended` (2 s wind-down, then the j_victory sting) everywhere.
- Follow-up: convoy sounds (sets off, foes on it, hits, destroyed, arrival horn); gangster battles get their own ACE songs `battle_gang` (gritty 70s crime funk) and `battle_siege_gang` (noir half-time siege), picked in `GameMap.area_track` when a `<track>_gang` exists; penguin Crystal Pylon uses P4's props/crystal_pylon_0..3 (glow, zap beam facing the target); tools/battle_shot.gd (a field's first seconds, phone or 1280x720).
- Saves/co-op: a campaign fight closed mid-way and reopened resumes its tickets, supply, point owners/spawners and commander (`Battle._keep` writes run campaign fight.state each second, `_resume` reads it; the convoy restarts from its start); a co-op guest sent home is never charged a retreat.
- Tests: new tools/battle_win_test.gd (check.sh: drain, siege, boss, defend, convoy lost/arrived, team, free spawn, veil), danger_music_test boss wind-down cases, campaign_gate_test both arcs pass. Balance table: tools/battle_audit.gd.

## 2026-11-19 — CONDUCT 2 fix P7: art quality (Big Grump card, mine rocks, fuzz audit)
- CONDUCT 3 fix P3 (map drawing speed, partial): arrival cover holds black until the on-screen ground chunks are baked (2 per frame, player chunk first; `GameMap._fade_in_when_baked`, max 45 frames) - longest load frame after the first: farm 644->375 ms, bf_orchard_line 166->87 ms (c3_16 measure), cover lifts at frame 2-4; rain_call no longer re-bakes non-farm maps; PlaceNames.for_id names mega areas from MegaRegion; perf_probe: median-of-5 chunk bake, median-of-3 redraw, longest load frame + cover frame, battle frozen for BREAKDOWN. Clipped chunk bakes (`GameMap.bake_clip`): a frame that bakes one chunk redraws the painter clipped to it (Art.clip; draw helpers skip outside, grass/ground-detail loops walk nearby cells only); CliffPainter/draw_rounded_cells/draw_border/soft shade replay recorded drawing (TriBatch.begin_rec/replay, CliffPainter.memo, GameMap._geom_memo). Chunk draws 4-66 (were 4-209), pixel-identical on 10 maps (tools/bake_clip_check.gd); full redraw bf_orchard 175->105, bf_neon 80->29, town 82->39 ms. Region exit corridors keep to path lanes for seamless paths (Windward notches).
- Big Grump boss card (ui/card_big_grump) showed a bald man in a fur coat; now the purple storm-cloud Grump in the gold boss frame, matching its sprite and portrait (image-tool edit, tools/slice_r13_c2_p7.py card_big_grump).
- Mine stones/ore (55 props: mine_*_rock/bigrock/ore, node_*) crispened by tools/crispen.py: hard alpha (no magenta-tinted soft fringe), clean dark 1px outline, small palette, light unsharp. Same canvas sizes.
- Code-side blur: phones draw the 270x480 canvas at 3-4x, so LINEAR smeared every 2x-detail texel (buildings are drawn at scale 1.0 = 1 texel per game pixel, worst hit). New `CrispArt` + shaders/sharp_pixel.gdshader (sharp-bilinear: solid texels, 1-pixel blended seams; plain bilinear at 1:1/minified) on every buildings/props/nature sprite from GameMap.prop().
- tools/fuzz_audit.py scores all art/gen images (soft rim, detail under 2x shrink, mushy steps, colour counts) -> docs/FUZZY-ART.md, the ranked to-do (buildings first) for CONDUCT 5.
- Test: tools/crisp_art_test.gd (card, shader on town buildings, mine rocks hard-alpha).
## 2026-11-19 — CONDUCT 2 fix P4: world and map fixes
- **Fish on land (Tom):** `fish_jump` critters (lake, riverlands) spawned on any open cell, so a jumping fish sat on the grass. Fish now spawn on deep-water cells only and swim only there (`WorldGen.WATER_CRITTERS`, `_deep_water`); ground critters never walk into water; jungle jellies float (flyers). Test: tools/critter_water_test.gd (every outdoor map, both arcs, at spawn and after 6 s).
- **Lighthouse wall (Tom):** the lake lighthouse blocked a 9x10 box up its tower; now only the rock island and the tower foot are solid, and the derelict tower fades when you walk behind it.
- **Mushrooms (Tom):** fall ground decor drew `mushrooms_fall`, the same picture as the pickable mushrooms. Decor now uses fall tufts, acorns and pinecones; the forage looks (`WorldGen.FORAGE_LOOKS`: mushrooms_fall, wildflowers2) mean "pick me" everywhere (wild herbs no longer look like decor clover; forest forage flowers use wildflowers2).
- **Farmhouse (Tom):** drawn at 2/3 of its art (128x116 px, was 96x87): door the hero's width, about 4.5 heroes tall. Solid rect Rect2i(9,6,8,5); mailbox moved to the front yard (16,11).
- **Hubs:** prop corners the art leaves see-through are listed as `"open"` by `gen_mega_new.open_cells` (alpha sampling) and unblocked by region.gd (Gilt plaza tables, Iron Junction plaza, Frosthold stilt hut, Breezehaven cloud tree, Mirage Post camp...). Fairy ring entry moved to open ground (forest 24,38). Gilt City entry is "the black limousine".
- **Community farm:** volunteers never path or wander across beds (`GameMap.keep_off`); no market on the 14th (festival), texts say 7th, 21st and 28th.

## 2026-11-19 — CONDUCT 2 (fix P3): combat music
- **Big Grump fight music:** the boss song is now held by `DangerMusic` from the intro card (`boss_started`) for as long as the boss is fighting or within reach, then a 7 s grace; the old 3-second area-song poll and `_boss_playing` check are gone, and anything that swaps the song mid-fight is taken back.
- **Combat music everywhere:** `DangerMusic` (scripts/danger_music.gd) reads every enemy's aggro/chase state and plays skirmish, danger, elite or boss music (per-arc variants, per-boss themes, songs started by boss cards or story beats kept), climbs at once, drops a tier only after 4 s, fades back to the area song 5 s after the last threat, so fleeing with foes on your heels keeps the music up and a foe at the edge of range doesn't flap it. Battlefields keep their own battle moods; endings/lullaby are never interrupted; streamed web songs carry the old song until they arrive (combat songs added to the prefetch lists).
- **New ACE songs (4):** combat_light (Skirmish), combat_light_gang (Street Scrap), combat_elite (Elite Foe), combat_elite_gang (Heavy Hitter); streamed on the web.
- `Music.play(track, fade)`: quicker cut-in (0.6 s) for fights, slower fade-out (2.2 s) after.
- Test: tools/danger_music_test.gd (both arcs, engage/flee/escape, edge-of-range flapping, pack, low health, elite + tier hold, boss, the meadow's staged boss fight, web streaming from a local server).
## 2026-11-19 — CONDUCT 2 fix P5: gate wording, skill points, Meow Pow Wow, penguin name
- **Region gates speak in-world:** walking into a region its campaign still holds no longer says "held against you". `Campaign.gate_words(cid)` gives a sense line unique to the region and arc (gen_battles.py `SENSE` → battles.json `sense`) plus the one true next step, naming who leads you: meadow not cleared / find Catkins or reach Hideout town (Sal) / drill with Catkins or Sal / an earlier region first / further in the story / recruit and bring provisions / ready to muster / under way. Same checks as `why_locked`. Goal line says "guarded". Test tools/campaign_words_test.gd (every campaign, both arcs, every stage).
- **Skill points:** the menu's Skills tab shimmers gold with a count badge whenever any tree has points; tree tabs with points shimmer and show "+N"; the open tree has a big "N Farming points to spend! Tap a node, then Learn." banner (scripts/skill_glow.gd, preloaded by GameMenu). Test tools/skill_glow_test.gd (shots with a dir).
- **Meow Pow Wow is earned:** Nova joins on day 2 but her button now explains she can't let it out yet and points at the purring in the crystal meadow; the party tab shows "Meow Pow Wow (not yet)"; Catkins teaches it (beat p2_catkins, from Tom's book: heart at the chest, rainbow hearts and paws) and now also explains what it does and that a penguin partner can use it too. Old saves that used it early hear "it's gone quiet" and get it back from the same beat. Test tools/meow_gate_test.gd.
- **"The Two Too Powerful Penguins"** in hero cards (playable.json), the partner scene line and the Fennimore line.
- Meadow letter no longer toasts "New quest" for a quest that was already open.
## 2026-11-19 — CONDUCT 2 (fix P8): desktop / full-screen play
- On a computer (desktop browser or native run) with a landscape window the view widens instead of showing a thin portrait strip: height stays 480, width follows the window (up to 960, e.g. 853x480 at 16:9), so the camera shows more of the map. Phones and portrait windows are exactly as before (270x480).
- HUD spreads to the screen: hearts/toolbar/goal top-left, clock box, place name, heat and the energy bar at the right edge, boss bar centred, edge arrow uses the whole view. Menus, dialogue and every full-screen panel (chest, craft, arcade, bowling, prizes, campaign board, epilogue, hack) stay a 270-px column in the middle; dim side curtains cover the world while one is open. Title screen: landscape key art, centred column.
- Fullscreen: F11 / Alt+Enter, Menu > Options > Fullscreen (remembered; the web build asks the browser on the first click when it is on). On-screen touch controls: hidden on computers by default; Options > On-screen controls auto/always/never. Native desktop runs open in a 1280x720 window.
- Test: tools/desktop_layout_test.gd (1920x1080, 1366x768, 2560x1440, ultrawide, portrait, phone 1080x1920 and 270x480; screenshots under xvfb).
## 2026-11-19 — CONDUCT 2 (fix P2): movement, facing, targeting, swimming pup
- **Facing on stop (Tom):** stopping keeps the way you walked for every hero (12B heroes' side rests too), keys and touch stick. A single-axis input in the last 0.14 s of a diagonal (one key let go first, the stick's thumb roll on lift) doesn't turn you (`Player.FACE_GRACE`, `facing_for`); deceleration never re-reads facing from the sliding velocity; up/down -> sideways needs a clear lead (no flicker on a drifting thumb). Exact diagonals still face up/down.
- **Targeting (Tom):** `Player.target_cell()` is Stardew-style: the front cell when it holds something to use; else the diagonal you walked toward, the front cell on the side your feet lean to, then the side cell you walked toward (`target_candidates`, `cell_has_target`); USE turns to a side target so swing and hit agree; the cursor square uses the same cell; work rows stay strictly on their line.
- **Attacks:** aim assist takes foes in front or along the way you walked (`_foe_ahead`, `move8`) and the hit box/arc/shot go straight at the foe it snapped to (`hit_dir`).
- **Pup swims (Tom):** in water the pup (and a walking partner) swims: water band over the legs, body lower with a bob, slow paddle, splash in and out, never sits/digs on the water (`Paddle`, scripts/paddle.gd). Both arcs.
- Removed the dead `Hud.stick_ok` (TouchControls never started a stick while paused; HackGame has its own arrows and keys).
- Test: tools/move_target_test.gd (in check.sh): rests in 8 directions x 3 release orders x 6 heroes, stick + thumb roll, rock/tree/crop/villager from 8 directions, sword after diagonal approaches, swimming pup in both arcs.
## 2026-11-19 — CONDUCT 2 fix P6: arcade and bowling
- **Bowling feel merged (c2_01)** with main's newer work: RecAudio's rolling/pin/pit/return sounds, ScreenCover, TapInput (no double taps; drag ignores the emulated mouse copy), payout caps.
- **One villager system:** a bowler's lane ("Challenge X") and talking to a bowler both start a real versus game (`RecCenter.bowl_with` -> `Bowling.play(map, lane, id)`): they bowl each frame on their own rack. Strength comes from ONE table, gen_rec `BOWL_AVG` (Tobin 95, Juniper 115, Theo/Ivy 135, Finn 150, Gideon 175, Maple 195), turned into a release skill by `Bowling.SKILL_AVG` (measured with `tools/bowl_audit.gd -- skills`). The win bonus goes through `Tickets.payout("bowling", ...)` with the game's tickets (cap 60); friendship once a day per villager; the villager's line after the game names both scores.
- Fallen and tilted pins draw through TriBatch (one draw call per run of them instead of ~25 each). rec_shot's versus card is captured steady.
- **Block Jumper:** checkpoint runways measured from the flag at the speed reached at the end of the runway (a calm 1.2 s plus a block's margin); the d-pad buttons that do nothing while running (◀ ▶ ▲) dim. Plans re-solved.
- Arcade cabinets freed without close() (a scene change) hand the screen back (Hud.modal_rect).
## 2026-11-19 — CONDUCT 2 fix P1: mines and mine combat (Tom's phone playtest)
- **Tools are not weapons:** a pickaxe/axe/hoe/scythe swung at a foe deals `GameState.TOOL_FIGHT` (30%, min 1) of the sword damage it used to borrow from your best blade (`GameState.tool_fight_damage`); a one-time tip says to hold the sword.
- **Crates/barrels break reliably:** every blow goes through `Mine.hit_crate` (counted, knock sound + wobble + chips + small shake each hit, break sound + loot on the last); sword/fist swings (holding USE) now smash crates and open chests they sweep (`Mine.attack_at` override); USE beside an off-centre barrel finds it; rod/can give a hint; a sword swing at rock hints "hold the pickaxe" (throttled).
- **Keeper variety:** `MineKeepers` (scripts/mine_keepers.gd): per floor/day pace (quick 4-16 s / normal / long / marathon up to ~320 s, threshold x0.3-2.5; floor 1 never quick; never the same pace 3 floors running) and 35 encounters (one big keeper, elder brute, packs, swarms, dens, twin keepers, themed by cave: slime court, serpent, shard brood, frost pack, ash hounds, hall of mirrors...; gangster-only rival dig/wrecking crews, penguin-only grump gang/shard flock), never the same encounter twice running. Packs: the shaft opens when every keeper falls (`Mine.keepers_left()`).
- **Way-down arrow:** `Mine.pointer_target` = the nearest keeper or the real shaft cell; `pointer_aim` follows the walking route (Dial flow field over open floor, rocks cost 5) so the HUD arrow never points through walls; `pointer_dist` = route length (small hook in hud.gd `_draw_pointer`).
- Test: tools/mine_keeper_test.gd (tool damage, crates with pickaxe/sword/off-centre/can, variety in both arcs, pace spread, live packs on 3 floors, arrow route reaches the shaft on all 26 layout styles); tools/mine_test.gd updated for packs.
## 2026-11-19 — CONDUCT 2 (c2_13): gangster flavour of the Rec Hall, arcade and Westside Lot Garden
- Rec Hall: every adult visitor now has gangster-arc lines there (Gideon, Maple, Finn, Lumi, Theo, Ivy, Juniper, Posy, Benno, Hazel, Rook + Alder/Sal); front desk greets with the hall's rule; Tobin's bowling bet no longer has Dad "putting up stakes"; the quest text says "the rec" (fits both arcs).
- Prizes: Penguin Plush and Top Hat are penguin-arc only; the gangster counter (and claw machine) has Fuzzy Dice and a Pinstripe Fedora instead (`Tickets.arc_ok`, lock_text "Not on this counter."). Item texts no longer name the Rec Center/commons or say "high roller"; Commons Stew is Community Stew.
- Arcade: Crystal Stack is Neon Stack in the gangster arc (`Tickets.game_name`, prizes.json game_names_gang; cabinet hints, hub list, milestones, NEON CRUSH!).
- Lot Garden: gangster-arc volunteer work lines, market-stand and shed lines, "your own lot garden".
- Test: tools/gang_flavour_test.gd (in check.sh): names, swaps, claw pool, hints, every hall visitor's lines, all-ages word check over every gangster text in rec/commons/quest lines.
## 2026-11-19 — CONDUCT 2 (c2_17): test hardening (deterministic under load)
- **No wall-clock waits in check.sh tests:** gang_play_test (swing pace, pup bite, pup dig), mine_test (keeper wake, shaft descent), campaign_test (colony reload), town_first_test (tour guide walk-up) now wait in game time (summed frame deltas), and check.sh runs them and newgame_penguin_test with `--fixed-fps 60`, so every wait is the same frame count however loaded the box is (verified with `--frame-delay`).
- **Fixed seeds:** each of these tests calls `seed()` for the game's own randf/randi rolls, and mines build from `force_seed` (new static in scripts/mine.gd; 0 = the clock as before). gang_play_test gives every mine load its own fixed layout, so "waits by the lift on the new layout" still sees a new layout.
- **campaign_test "the way down is a real walk":** was a straight-line distance > 15 on one clock-seeded floor, which failed on mazes/spirals whose ladder is a long walk round (seed sweep: 2 of 60 floors, walking distance 86-169 steps). Now it measures the walking path (rock minable, no lava/chasm/pool) >= 30 steps on five fixed floors, including those two (100 sampled floors: shortest walk 46).
- **mine_test variety:** the five floor-1 entries use fixed seeds (style rotation is the game's own); two extra clock-seeded entries check the live game still rolls a new seed every entry.
## 2026-11-19 — CONDUCT 2 (c2_09): community farm stages and quest line
- **Overnight builds:** the shed, raised beds, well, orchard and greenhouse now go up overnight, Stardew-style. Filling the bundle gets Hazel's "tonight" line, the materials stack on the spot (new build-site props: lumber on sawhorses, cut stone, a barrow of saplings, a crate of glass panes), the journal says "building tonight", the sleep report says it's up, and the next visit plays the reveal with Hazel's line. A stage can't land the same day its bundle fills, so the line paces over more days. Clearing the lot, the seeds and the market still finish on the spot.
- **One volunteer speaks in each reveal** (Sal, Gideon, Finn, Wren, Benno, Rook, Juniper), in both arcs.
- **Your seeds grow:** the beds now plant the kinds you donated (two rows in three, while they suit the season) instead of ignoring them.
- **After the market opens:** the board carries one ask per season (crops in spring to fall, any fish / mushrooms / forage in winter), paying 250 crystals ($250), 5 seed packets, friendship and goodwill. Morning report flags market days and the new season's ask. Hazel's lines at the finished farm now differ by arc.
- **Fixes:** a softlock if the app closed during Hazel's "lot cleared" scene (the save had every pile gone but stage 0, with nothing left to finish it: the next visit now finishes it, and the board offers it too); the compost never dropped fertilizer before the seeds stage although the shed promised it; the morning line said "0 beds harvested" and repeated the share-crate note every night (now only when something new came in); the opening speech said "a year ago" even in the first season.
- **Saves:** old cfarm blocks gain `pending` and `asks`. Test: commons_test walks every build stage through the night (site, journal, report, reveal) in both arcs and checks compost, donated seeds, asks and the recovery.

## 2026-11-19 — CONDUCT 2 (c2_05): ticket economy and prize counter
- **Money loops closed.** Before: prizes resold for half their ticket cost, and good arcade play paid 3-9 tickets per crystal (Crystal Stack keen runs ~90 tickets for a 10-crystal game, endless Block Jumper 1000 m ~83, Duck Pond 800 ~53), so tickets -> prize -> sell made crystals; the counter also sold plain Candy (worth 10) for 15 tickets and Growth Elixirs (worth 300) for 400 tickets, repeatably; the claw machine's pool (pearls, amethyst, golden gifts) averaged more than a 20-crystal go was worth for a steady hand.
- **Now (all numbers in tools/gen_rec.py, checked every run by `check_economy()`, which refuses to write a loop):** per-play payouts go through `Tickets.payout(game, n)` (full up to a soft mark, half rate above, hard cap: arcade 24/34, bowling 40/60, claw 14/20, skee 15) and `Tickets.add` holds game sources to their cap; prizes resell for 1/8 of their ticket cost; worst case (every sell bonus stacked, x2.15) a capped play resells for under its fee. Counter Candy is now Prize Candy (rp_candy); the elixir is Sprout Fizz (rp_sprout_fizz, same farm-growth effect, 300 tickets, one a week via the new "weekly" need). Claw pool moved to gen_rec CLAW_POOL (plushes and treats with a few small treasures; average prize 9.4, best-case go worth 18.4 < 20); ArcadeClaw reads it via `Tickets.claw_pool`.
- **Bowling pays a bit better** (5 + score/8 + 2/strike + 1/spare: a 120 game ~29 tickets) since it is the headline game and the dearest.
- **Pacing:** `python3 tools/gen_rec.py --sim` simulates three players for 12 weeks. Regular (2 visits/wk, ~115 crystals a visit) gets the first keepsake in week 1 and the Home Arcade Cabinet ~week 11; keen (4 visits) has everything but the skill-locked Golden Pin by week 4; casual (1 visit, 45 crystals) has three keepsakes by week 12. Grand shelf raised to fit (Star Cape 600, Jukebox 900/earn 800, Gold Trophy 900, Arcade Cabinet 1200/earn 1500/25 plays, Golden Pin 1500).
- **Milestones:** prizes can need an ArcadeHub milestone (`"ms"`); the Arcade Medal now needs "Play every cabinet once" (all_games), matching its text (it used to need any 4 games).
- **Prize screen clarity:** lock lines show progress ("Score 150 in Bowling (best 132)", "Play 3 arcade games (1/3)", "Win 800 tickets in all (412 so far)"), affordable-but-short rows say "N more tickets", owned keepsakes sink to the bottom marked OWNED / "Yours! It's in your house.", shelf tabs get a green dot when something there is buyable now, header shows tickets won in all; "Sold out this week (more in N days)" for weekly prizes.
- Tests: new `tools/ticket_econ_test.gd` (in check.sh): fees match the games, payout curve and caps, resale bound, claw pool/EV, progress locks, milestone and weekly prizes, every shelf fits. rec_test medal check updated. Shots: `tools/prize_shot.gd`.
## 2026-11-19 — CONDUCT 2 (c2_03): Crystal Stack + Whack-a-Grump polish
- **No more lost coins on a stray B:** B during a round pauses both games (`ArcadePause` card: A keep playing / B end the round); switching apps or a phone call pauses too. The round clock stands still while paused. The B caption under the button says pause / end / leave as it changes.
- **Crystal Stack:** gentler speed curve (0.8 s a row at level 1, ~0.4 s at 5, ~0.17 s at 10, never under 0.07 s; it used to fall linearly to 0.05 s by level 11). Holding ▼ no longer rushes the next piece (press it again). Topping out now plays a "STACKED OUT!" beat where the well turns to grey stone from the bottom up before the results; results list Crystal Crushes. Danger rim pulses red when the stack nears the top; a locked piece flashes; the ghost is easier to see; a level progress bar sits under LEVEL; banners sit across the well instead of over its floor and the side panel; CRUSH shows its +800.
- **Whack-a-Grump:** READY / GO! lead-in before the clock starts; last five seconds tick with a big countdown and a flashing bar, seconds left on the bar. A bopped critter stays up dizzy for a beat and a second tap on it is no longer a combo-breaking miss. Taps hit by the box around each hole (head included), not a small circle. Gold grumps stay up at least 0.5 s. Combo shows its multiplier; "COMBO x2!" banner; "combo lost" when a 10+ streak breaks. Results add "Got away".
- **Whack scoring rebalanced:** a scripted sharp player made ~2,250 points (186 tickets a coin) because x3 combos ran all round. Now grump 5 / gold 15 / helmet 10 / bunny -10, double points from 10 in a row (no x3): sharp ~730 (60 tickets), casual ~360 (29 tickets).
- Test: `tools/stack_whack_test.gd` (in check.sh); shots: `tools/stack_whack_shot.gd`.
## 2026-11-19 — CONDUCT 2 (c2_06): Rec Center hub, villager visits
- **Audit** (`tools/rec_sched_audit.gd` prints who is at the rec every half-hour of each weekday, both arcs; rec_shot league-night shots): on league night all four lanes were "taken" by villagers, so the player couldn't bowl at all; the four lane bowlers' stand cells sat on the lane A-cells, which interiors refused, so they stood at random spots while the lanes still read as taken (and one, Ivy, didn't appear); lobby watchers behind the lanes counted as bowlers; Posy's rest-day visit fell in her bakery hours and never happened; the rec never closed (open 24 hours, villagers listed "in" while still at work); nothing told the player who comes when (the game has no weekday names) and the desk said "every third day of the week"; Gideon said "Grab a lane before Gideon does".
- **Lanes:** villagers bowl on lanes 1-3 (on the approach, a partner behind), lane 4 is the house lane and always stays free; watchers never count as bowlers; only villagers really there (not at work) take a stand.
- **Playing alongside villagers:** talk to a bowler (or pick their lane) to bowl a game together: normal fee and tickets, then they bowl their game (their average from gen_rec BOWL_AVG, plus or minus 25, steady for the day) and you compare cards with a line from them; friendship +8 for a win / +5 otherwise once a day each, +10 tickets for beating them.
- **Hours:** open 9am to midnight, closed 9am-6pm on festival days (door sign, desk, every machine and the lanes); nobody visits outside hours.
- **Front desk "What's on today?":** the day word (league night: the 3rd, 10th, 17th, 24th; rest day: the 6th and 7th of each week; or a working day), hours, and who comes in on each floor with their times (only hours they're really free). "What's here?" explains when folks drop in, the house lane and bowling together.
- **Chatter:** villagers at the rec talk about what they're doing: league-night lines (own lines for Gideon, Maple, Finn, Ivy, Benno), rainy-day lines, cabinet lines naming the cabinet in front of them, lane and lobby lines, then their own lines. The cabinet/lane menus' way out reads "Not now" (softlock rule).
- Test: `tools/rec_test.gd` `_c2_06_checks` (hours, every visit slot really happens across a clear and a wet week, no floor over its stands, house lane always free, league-night bowlers at their stand cells, chatter filled, desk board, taken-lane and bowler menus, bowling-together rewards once a day). Shots: rec_shot adds the desk board (`<arc>_desk_today0-2`).
## 2026-11-19 — CONDUCT 2 (c2_07): Rec Center visuals
- Audited both floors and the town lot, both arcs, afternoon and night (`tools/rec_vis_shot.gd`). Ground floor read empty and flat: neon signs were faint, flickered to near-invisible and sat over the window; the arcade carpet was procedural confetti; nothing changed after dark inside; the lot had no lit windows at night; the sign carried 3 px text no phone can read.
- **New art (3 renders, `tools/slice_c2_07.py`):** air hockey table, two pinball machines, capsule machine, photo booth, stool and cafe table (props/rec_*), four framed game posters (furniture/rec_poster_*, wall_props on both floors), four neon pictogram signs (props/rec_neon_*), seamless arcade carpet in daylight and blacklight versions (tiles/rec_carpet, rec_carpet_gang).
- **Ground floor:** carpet under the cabinets and pinballs with a brass (Hall: violet) trim; posters beside the window; joystick and star neon in the gaps between cabinets (steady hum, the odd flicker); new pieces placed off every stand and usable cell.
- **Light:** `RecGlow` (scripts/rec_glow.gd) throws coloured pools and halos from cabinets, claw, jukebox, vending, pinballs, booth, counters, neon and the lane pin decks (blacklight down the lanes in the Rec Hall); faint by day, full after dark, while `GameMap.sky_tint` dims the rec rooms to a cool tint (`RecGlow.tint`) instead of the lamplit house tint. Town lot: lit windows, doors and sign after dark (NightGlow).
- Test: `tools/rec_test.gd` checks decor art, decor off stands/things, the light layer, day/night tint and neon off the window.
## 2026-11-19 — CONDUCT 2 (c2_14): rec/arcade integration
- **Arcade feeds quests:** six new villager quests (Pip: Block Jumper level 3; Theo: Crystal Stack 3,000; Wren jr: Duck Pond 300; Sal: Whack-a-Grump 400; Maple: league night 150 after Tobin's bet; Alder: try every cabinet), offered after your first visit. New condition keys `arcade_ms` / `rec_best` / `tickets_won` (`Tickets.cond_ok`, read by `GameState._cond_ok`) and a `tickets` quest reward (named in the quest toast). Gangster wording for Sal and Alder.
- **Hearts:** Tobin ♥2 and Pip ♥8 weekly gifts now add arcade tickets (5 / 10; `#tickets` in gen_heart_perks.py, only once the rec is open).
- **Mail:** Maple's league-night letter three days after you first visit; the front desk writes when a prize you earned (score, plays, tickets, milestone) comes out at the counter, once per prize.
- **Festivals:** joining a festival event gives +15 tickets once the rec is open (`RecCenter.festival_bonus`).
- **Board:** the town community board pins what's on (league night / rec open / opening soon, community farm market day).
- **High score board:** two pages; Block Jumper shown in levels cleared; arcade milestones x/21 with the next one named. Prizes can now be locked on milestones (`need.ms`).
- **Saves:** `_migrate` creates run.arcade_hub too. Test: tools/rec_links_test.gd (in check.sh).
## 2026-11-19 — CONDUCT 2 (c2_08): Rec Center audio
- **Bowling floor has its own song:** "Ten Pin Strut" (ACE, `bowling_alley`, retro surf-lounge shuffle) upstairs in both arcs; the arcade floor keeps the house song (neon in the gangster arc).
- **Jukebox:** 11 records (new ACE 50s boogie record "Nickel Record" `jukebox_oldie`, plus the bowling song and the cabinet hall loop); the toast names the record ("drops a record: \"Nickel Record\""), and a real needle-drop sound plays instead of a UI tap.
- **Bowling lane sound** (`RecAudio`, scripts/rec_audio.gd): a 4 s real rolling-ball rumble that follows the ball (louder/brighter when fast, pitch drops in the slow-motion finish, fades at the pins), a hollow gutter rumble, pins sized to how many fall (tap / crash / one big strike crash), the pit drop and the ball return clunk before the next ball. Before: one 1 s roll and the same small clatter on first contact for a 1-pin tap and a strike alike.
- **Villager lanes** roll and crash from where the lane is (positional, quieter across the room, strike crash on their strikes) instead of a full-volume clatter anywhere in the room.
- **Ambience:** the downstairs arcade had only the bowling bed at -24 dB (about -52 LUFS: inaudible). Now a new `arcade_floor` bed (cabinets in attract mode, coins, low murmur, built from CC0 retro packs) with the lanes muffled through the ceiling; upstairs the lane bed is up front and the arcade a murmur. Spots: strikes through the ceiling and far cabinet wins downstairs, other lanes' strikes upstairs.
- Sounds built by `python3 tools/make_rec_audio.py` (CC0 packs; credits/sources/CC0_USED updated), then sfx_soften. `tools/sfx_audit.py` now also checks RecAudio's beds/spots/records. Test: tools/rec_audio_test.gd (in check.sh).
## 2026-11-19 — CONDUCT 2 (c2_04): claw, Duck Pond, Skee-Ball, snack bar
- **Skee-Ball is a real game now** (`ArcadeSkee`, game id `skee_ball`, ◆10): nine balls up a painted maple lane (new art `arcade/stage_skee`, `skee_ball_ball`). ◀ ▶ or a tap picks the line, hold ROLL and let go on the power meter (painted with what each power scores on your line). Board 10, outer ring 20, inner ring 30, cup collar 40, cup 50, corner cups 100 (need a line by the bumper and a strong roll); soft rolls die on the ramp (0), rockets hit the net (10). Tickets score/20 + 1 per corner cup + 3 at 300+. Milestones skee_300, skee_cup. Before: a ◆5 dialogue with three random rolls and no skill at all.
- **Claw Machine odds:** centring now decides the grip (`ArcadeClaw.grip_for` / `slip_rate`); luck (gear + the new Lucky Popcorn buff) helps; a dry run of 3+ losses firms the grip (the old pity win, kept fair; "The machine hums warmly"); wins per day still loosen it. Surveyed (tools/rec_odds.gd, 100 rounds): dead-centre 36% (was 24%), 4 px off 31% (20%), sloppy 15% (8%). Win card names the prize ("Candy · Tucked inside the bear plush.") instead of "Candy (bear plush)"; nicer prize chute.
- **Duck Pond payout** score/25 (was /15: 20-66 tickets for a 10-crystal game, double every other cabinet); now ~12 casual / 25 fair / 40 expert.
- **Snack bar:** four snacks with what they do on the menu (gen_rec `building.snacks`), stays open for another round: Lucky Popcorn ◆10 (luck +1, 90 min), Hot Pretzel ◆20 (45 energy), Cotton Candy ◆15, Fizzy Pop ◆12. New icons (snack_popcorn/pretzel/cotton_candy; cotton candy used a crop icon before). Values stay under prices.
- Rec props for claw/skee open the arcade games directly (old dialogue fallbacks removed). Art: `tools/slice_r13_c2_04.py`. Test `tools/rec_games_test.gd` (check.sh); shots `tools/rec_games_shot.gd`, `tools/rec_snack_shot.gd`; odds survey `tools/rec_odds.gd` (ONLY=skee).

## 2026-11-19 — CONDUCT 2 (c2_12): full-screen UI touch input
- **One tap = one action:** on a phone Godot hands a Control the touch AND an emulated mouse copy, so drawn screens reading both fired twice: a prize tapped once was picked and bought (BUY bought two), bowling's quit X asked and left in one tap, spin moved two steps, a hack arrow counted twice, the endings slideshow skipped slides. New `TapInput` (scripts/tap_input.gd) drops the copy; PrizeScreen, Bowling, HackGame, Epilogue and CampaignScreen use it.
- **Cabinets:** the USE finger that opens a cabinet (or a thumb on the stick) now lifts cleanly: before, the arcade swallowed its release, so A stayed held (the first INSERT COIN tap did nothing), the stick kept steering and the pad showed buttons stuck down after closing. TouchControls lets go of everything when a full-screen panel opens. Closing a cabinet launched from the picker no longer clears the picker's modal/deck rects.
- **Hack terminal** has an on-screen UNPLUG button (B was unreachable on a phone under the panel; the "joystick" hint was wrong). Dead touch buttons are no longer drawn under full-screen panels (CHECK/MENU peeked out under chest/craft). Craft category chips are finger-sized (20 px).
- Tests: new `tools/touch_ui_test.gd` (check.sh) plays every cabinet, the picker, prizes, bowling, hack, chest and craft in the Rec Center with real touch events (two fingers, slides, edge taps; nothing held or moved afterwards). `tools/phone_ui_test.gd` now also audits every cabinet (title/play), jumper select, bowling aim/power, every prize shelf, the hack terminal and chest/craft inside the rec, plus tap targets of drawn screens.
## 2026-11-19 — CONDUCT 2 (c2_15): first-hours regression, both arcs
- Re-ran newgame_penguin, gang_start, goal_line, town_first, farm_week and first_week tests (all pass) and played new games to day 3 with screenshots.
- **HUD arrow pointed 7 cells off** whenever the goal was on another map: `GoalLine.target` used exit rects as world cells without the map's border pad (town arrow aimed at the wall left of the farm road; farm arrow above the meadow gate). Now `cell_pos`.
- **Day 3 told you the meadow quest before the letter that gives it:** the goal line and arrow now say "A letter waits in your mailbox, by the house. Read it." until the meadow letter is read (`GoalLine.letter_first`), then the meadow.
- **Morning "Next:" line was a day behind** on days a main quest opens by date (day 3 said "Water your crop" while the HUD said meadow): `SleepReport._open_due` opens due main quests first.
- Removed the unused duplicate mailbox marker class `MailFlag` (the farm's `_mail_mark` is the one drawn). `newgame_flow_c1.gd` now plays the whole gangster opening before farming.
- **Test:** `tools/first_hours_test.gd` (in check.sh) plays both arcs on the real maps to day 3: goal line, arrow targets, mailbox marker per day, tool tips, town tour completing meet_town, Next: matching the goal line.
## 2026-11-19 — CONDUCT 2 (c2_10): community farm volunteers
- **No more stacking:** every volunteer gets their own cell of a shared spot (`CfVolunteers.stand_cell`, hooked in `Npc._apply_routine`); bench sitters sit on the bench, picnickers at the table (picnic spot moved off the campfire). Market day had 3 cells with 2-3 people on top of each other.
- **Market day really happens:** the 7th-day chapel morning used to pull everyone off the market until noon (`Npc.place_now` now lets `Commons.market_slot` win). The market-day crowd is bigger and spread over two new spots (third stall, plaza).
- **Visible work:** bed volunteers walk to a bed, crouch (work/work_2) and tend, water dry cells (splash) and pick what's ripe; haulers carry loads to the compost/cart/timber pile; Benno carries water from the well to the beds; market keepers restock from the crates; on stage 0 they drag at the junk.
- **Shifts:** a volunteer whose shift starts while you're there walks in along the road; one whose shift ends walks back out before vanishing.
- **Rain days:** grown-ups shelter under the shed eaves / in the greenhouse and chat (no umbrellas under a roof), kids stay home, Finn/Rook/Sal and the day's umbrella walkers keep working; at-work lines talk about the rain.
- **Chatter:** gangster-arc at-work lines of their own, per-volunteer lines, winter and market-day lines, short floating call-outs as you pass (greeting first). Fixed the villager chat bubble everywhere: it drew the whole 12-icon emote sheet; now one icon at a time.
- **Lend a hand:** talk to a working volunteer (stage 1+) and they may ask for help once a day: pull 4 weeds round the beds, carry 3 crates to the shed/compost/stall (one at a time, crate over your head), or water their dry beds before the well. Reward: +10 friendship, goodwill, xp and a cut of the stand's produce. A lightbulb now and then marks someone with a job.
- Test: tools/cf_volunteer_test.gd (in check.sh). Shots: tools/cf_volunteer_shot.gd.
## 2026-11-19 — CONDUCT 2 (c2_02): Block Jumper levels, checkpoints, touch (partial)
- **Difficulty curve:** levels now get longer in time as well as faster (L1 ~26 s ... L8 ~45 s; lengths 2400 to 6600), tighter gaps/shorter runways with difficulty, and a new "combo" chunk on levels 5-8 + late Endless (gap whose landing pad runs straight into spikes or a low ceiling).
- **Checkpoints:** one about every 8 s of running, each at the start of a calm runway (1.2 s of flat ground), so a respawn never lands you on an obstacle. Respawn uses `JumperLevels.respawn_state`: the run's clock is a function of x, so moving platforms are in the same phase as a clean run (before, the clock restarted at 0 and a mover could be unreachable after a respawn).
- **Moving platforms** are timed to the run (sliding ones swing toward you as you reach the edge).
- **Solver:** plans are proven from the start and from every checkpoint (keys `n` and `n@i`, 36 segments); a wider beam retry when the narrow one prunes the only way through; `--levels`, `--seeds`.
- **Touch:** the whole play area is a second JUMP button while running (hold for higher).
- **Looks:** low ceilings are a hanging slab of the level's rock instead of a flat grey pillar; CHECKPOINT text floats ahead of the player.
- **Tools/tests:** tools/jumper_test.gd (coyote, buffer, hold height, curve, calm checkpoints, respawn clock, play-area jump; wired in check.sh), tools/jumper_audit.gd (take-off window per jump), jumper_dump.gd / jumper_probe.gd (debug).
## 2026-11-19 — CONDUCT 2 (c2_16): UI softlocks and overlapping toasts
- **Frozen game with nothing on screen (bot20 "screen won't close on B/MENU"):** a full-screen UI opened while something else had the game paused (a dialogue, or the menu) restored that pause when it closed, even after its opener was gone, so the game stayed paused with no box and no button. Two fixes: MENU/B no longer close the game menu underneath a screen opened from it (that unpaused the game under the screen, then the screen re-froze it), and the Hud now lets go of a pause that has no dialogue, menu or full-screen UI behind it after 20 frames (`Hud._pause_watch`, warns once).
- **Toasts over the boss intro card** (e.g. the first sword/weapon tip landing with Big Grump's card): a boss card now holds the toasts (hidden, their fade paused) and they show in full once it slides away (group `toast_hold`). The region name card (MegaBanner) puts toasts under itself (group `toast_under`), so "New map tab" lines no longer cover it.
- **Toasts over the pup buttons and the energy bar** (battles put the stack under the battle bar, down into the strip): a stack that reaches the pup command strip steps in beside it, and one that reaches the energy bar narrows on that side (left-handed mirrored).
- Key-binding labels no longer spam "Not supported by this display server" in headless runs.
- Tests: `tools/toast_layout_test.gd` (in check.sh; pass a dir under xvfb for shots), `tools/softlock_test.gd` cases 9-10 (chest over a dialogue; MENU over a chest opened from the menu), new `tools/menu_sweep_test.gd` (presses every button on every menu tab, then leaves with B; 145 buttons, 0 stuck; slow, not in check.sh). Bot failure lines now say the menu state, open layers and the last action.
## 2026-11-19 — CONDUCT 2 (c2_11): community farm map and art
- **Organic woodland edge:** the commons no longer sits in a ruler-straight box of trees. `_edge_wood()` grows woodland bays and points 1-6 cells in from the border band (noise along the edge, Sun Haven style: open middle, soft edges), trees spaced so you can see into the wood, undergrowth on the fringe, forest-floor ground under it; never on paths, beds, yards, exits, gathering spots, debris or the orchard. Replaces the old tree clumps (two planted-looking rows in the north-west).
- **Stage 0 reads as a mess to clear:** new debris art (bramble thicket, weed clump, fallen branches, mossy stones, rotting stump; gangster lot: weeds through cracked slab, brick/concrete rubble, scrap pile, tyre stack) replaces the flowering berry bush and plain field rock that looked like decoration; drawn a bit larger. The gone-wild ground is patchy instead of one flat brown blot.
- **Lot garden ground:** the old lot is slab paving (it was road asphalt with lane lines), and from stage 1 the plaza is relaid in reclaimed herringbone brick.
- **Paths:** the market lane now joins the south path (it floated 3 cells short); the apple bucket no longer sits on it.
- **Sizes:** the repaired tool shed is no smaller than its ruin (0.66), the roofed well a little bigger.
- **Fruit trees in leaf:** new `ftree_<apple|orange|plum>_green`; apple trees in spring (were bare winter twigs) and any fruit tree after it's shaken in season (an orange tree turned autumn-orange mid-summer) now show green leaves (WorldGen.fruit_tree, GameMap shake). Applies to every orchard, not only the commons.
- **Tools:** `tools/cf_shot.gd` (stage-by-stage overview + close shots, ARC/SEASON env), `tools/cf_layout_test.gd` (in check.sh: paths connected and walkable, every station reachable, woodland edge organic and on all sides, debris art, orchard in leaf; every stage, both arcs), art `tools/slice_r13_c2_11.py` (3 renders).

## 2026-11-19 — CONDUCT 2 (c2_01): bowling feel
- **Phone controls:** drag the ball along the foul line (or ◀ ▶), spin buttons set the hook, a tap on the lane is GO. The aim is a steady sweep (no more fast sine whip) of the ball's *real* predicted path, hook included; tap to lock. The power bar has a gold sweet band: stop in it for a clean release, outside it the ball wanders (and a slow ball hooks more than the preview). Buttons read GO / LOCK / ROLL.
- **Pin physics:** fallen pins lie down as 15-inch sticks that sweep the deck and take out neighbours (messenger pins), kickbacks throw pins back across, pins tumble with a little scatter, a brushed pin rocks and a hard rock can still tip over late. Pocket hits (2.75 in right of the head pin) strike ~85% of the time, a board off ~40-60%, wide hits rarely: a bell, not a coin toss (`tools/bowl_audit.gd` maps it).
- **Frame flow:** result pop, then the pinsetter bar rakes the deck, a fresh rack lowers in, the camera glides back. Split leaves are named ("7-10 split!"), Double/Turkey/Hambone streaks, confetti on strikes and spares, "9 pins: so close". Frame/ball/pins-up and the running score sit in the control bar.
- **Villager opponents:** a villager bowling on a lane can be challenged (lane dialogue). They bowl each frame on their own rack after yours, shown on a portrait card; a second row on the score sheet; lead/trail shown live. Nine bowlers with skills from Tobin (~95) to Maple (~200); beating them pays a ticket bonus (6-20), any game is +5 friendship (+8 on a win), flag `bowl_beat_<id>`.
- **Results:** win/lose/tie card with both scores, ticket breakdown, new personal best, and which high-score prize it just unlocked at the counter.
- Test: `tools/bowling_test.gd` (in check.sh): preview matches the roll, strike window shape, villager skill order, splits, a full versus game played by the screen's own bot through every phase, ticket bonus. Shots: tools/rec_shot.gd adds sweep and versus card/result.
## 2026-11-19 — CONDUCT 1: inventory (docs)
- `docs/INVENTORY.md` + `docs/inventory.csv`: 37 systems with status (27 done, 5 rough, 5 missing; average 73%), game size counts, art/audio outstanding (both zero, verified), test coverage (26 of 32 tests in check.sh; char_sheet/creator/hearts tests pass outside it), open work Claude can do alone, and a draft "What Claude needs from Tom" list.
- `tools/missing_art.py` honours an item's own `icon` alias (as the Hud does): the 20 Rec Center prizes it listed were false positives; MISSING-ART.md is now all zero.
## 2026-11-19 — CONDUCT 1 (c1_10): farming first week, clarity pass
- **Growth text on every tap:** USE or CHECK on a growing crop always shows days left and its water state ("Turnip: 2 more days. Thirsty: water it with the can or it won't grow tonight." / "Watered today." / "The rain is watering it today."). Before, a dry crop tapped with anything but the can said only "Hold the watering can." (or nothing), and a snack in hand got eaten instead.
- **Hoe on tilled soil** says once "Already tilled. Pick seeds on the toolbar and USE here to plant." (it used to nag "Hold the watering can." on every row pass). The can on empty soil in the rain says the rain has it wet. Growth tonics still work facing the field.
- **Morning report:** counts crops that went without water ("didn't grow"), ripe crops (after the first harvest; the Next: line covers the first), and says when rain or snow waters the field so the can can stay home.
- **Quality stars explained:** silver/gold harvest toasts say they sell for a quarter / half again more.
- **Tutorial texts:** the gangster intro and the Star Crystal now say to hold the hoe and the can, and that a crop only grows on nights it was watered. Maple's letter no longer clashes with her first-timer's bundle; M.'s first letter now carries 3 potato seeds, so both arcs start with a second crop.
- Sell toast reads "Put Turnip x3 in the sell box".
- **Test:** `tools/farm_week_test.gd` (in check.sh) plays the first week in both arcs through the farm's own USE path: till, plant, water, thirsty text, rain day 1 (gangsters), morning dry/ripe counts, harvest with the hoe, first-harvest quest, sell box, overnight pay.
## 2026-11-19 — CONDUCT 1 (06): early-game gating
- Audited day 1-14 in both arcs (scripted sleeps, tools/early_gating_test.gd): Rec Center/Hall + arcade open day 7 after the town intro, community farm letter day 4, campaigns locked until chapter 2 + drill (invite beats already in place), mega keepers locked with a line + "Opens at story chapter N", no map tabs. Day 1 Plans: 13/34 (penguins), 15/36 (gangsters) tiers open, all material-gated.
- **Rec lead-in:** from day 3 until the opening, villagers talk about the works at the old hotel (rec.json chat_soon / chat_soon_gang from tools/gen_rec.py); the door banner still counts down.
- **Hazel's commons letter** was signed "hazel" (raw id); now her name.
- **Plans board:** story-gated tiers said a bare "story first"; they now name the step (e.g. "story chapter 4 first (the Merkitties)", "after the east meadow story").
- Test: tools/early_gating_test.gd (in check.sh).
## 2026-11-19 — CONDUCT 1 (c1_12): pup intro, first fights, clinic
- **Audit** (`tools/early_fight_audit.gd`, scripted "naive" and "careful" fighters vs every early foe, both arcs): meadow foes and mine floors 1-4 are gentle (0 health lost), but the meadow's first boss took 96/100 from a player who never dodges (penguins) and knocked out the gangster player (it hit for 36 once enraged). The floor-1 keeper takes ~half from a naive fighter, ~12 from a careful one: kept.
- **First boss** (Big Grump / The President's Man) now hits for 12, 24 once enraged: naive fighter keeps ~half, careful loses ~25-35.
- **Telegraphs:** a foe winding up a plain hit shows a new claw-mark icon over its head (`ui/tele_strike`, image tool, `tools/slice_r13_c1_12.py`) and a stronger red tint; lunge/stomp/shot keep their own icons.
- **Pup intro:** the first fight (meadow, or the mine if first) explains the red flash, what the pup does, its order buttons (ATK/HEEL/STAY/CALL) and how to heal/revive it (`PupIntro`). A one-time "Health low! ... MENU > Items > Eat" tip at a third of your health.
- **Sword feel:** the third swing of a combo (+1 damage) lands with the slash crescent.
- **Clinic:** the first knockout of a run is free (the note says so and how to avoid the next); after that the flat part of the bill is capped at a tenth of your purse (50 crystals: 13, was 28).
- **PupMine:** the pup's dig clock pauses while it fights (it used to stop mid-fight to dig).
- Test: `tools/early_combat_test.gd` (in check.sh).

## 2026-11-19 — CONDUCT 1 (c1_15): Rec Center + arcade regression after the merge
- **Jukebox works now:** the record you pick used to be replaced by the house song within 3 seconds (the area-song refresh). `RecCenter.music_for` (hooked in `GameMap.area_track`) keeps today's record on both floors and through an arcade game; it resets the next day. The first press no longer "changes" to the song already playing.
- **Visitors no longer block cabinets:** a villager standing at a cabinet offers "Can I have a go?" when you talk to them, steps aside to a watching spot and opens the game (`RecCenter.visitor_talk`). Cabinet stands are ordered two players, then watchers in the gaps, so fewer cabinets are taken.
- **No ticket-to-crystal loop:** prize-counter items sold for 1.3-1.5x their ticket cost (a Teddy for 80 tickets sold for 120). Prize items now sell for half their ticket cost (gen_rec `balance_values`); candy costs 15 tickets, Growth Elixir 400.
- **Claw grip loosens per day,** not per visit: walking out and back in no longer resets it (`ArcadeClaw.wins_today`).
- Cabinet prices read "10 crystals" / "$10" in the gangster arc (`ArcadeHub.price`). The high-score board lists the claw and skee-ball too.
- Tests: rec_test checks cabinet ids vs ArcadeHub games, props and A-cells, every game has a machine, prize resale, stands on open floor, step-aside cells, the jukebox vs area_track, money words, in both arcs.
## 2026-11-19 — CONDUCT 1: cash words in the gangster arc (Round 13 systems)
- **Arcade:** the picker, Block Jumper and every cabinet read "40 cash" / "INSERT 40 CASH" / "You have 40"; now "$40", "INSERT $10", "You have $75", "Not enough cash ($10)". Arcade and mega-map text is drawn by hand (no Translation), so their text helpers now pass through `Money.t`, as does the HUD held-item/hint line. `ArcadeHub.money_word()` defers to `Money.word()`; new `Money.amount(n)` ("40 crystals" / "$40") and `Money.num(n)` ("40" / "$40"). Penguin arc text is unchanged.
- **Mega regions:** Rahim (Sunscorch) "pay you in shade. And crystals." now says cash.
- **Test:** `tools/cash_test.gd` also scans rec, prizes, community farm, battles/campaigns, colonies, mega regions, hub travel, regions, interiors, epilogue data, and checks the arcade picker, Block Jumper, rec center/stand lines, commons stage rewards, campaign muster lines, mega hook rewards, shops and mail in cash, plus the penguin arc unchanged (54,770 strings, 0 failures).

## 2026-11-19 — CONDUCT 1: softlock and stuck hunt
- **B leaves every menu:** the game menu now closes on B (it only closed on MENU), the dresser cancels on B, and choice menus also back out on "Stay", "Not yet", "Later", "Just chat", "No" and the like (story questions with a stored answer still only accept "Never mind"/"Back"/"Leave", so B never answers for you). Battle rally and supply-point menus and the crew job picker gained a "Leave"/"Back" option (the long supply list had none).
- **Dialogues always finish:** an empty `say([])` used to emit `finished` before the caller was waiting, leaving it (and a frozen player) hanging forever; an empty choice list left a box with no button. Both fixed.
- **No menu over cutscenes:** the menu won't open while a story beat is playing (between its lines the game runs); a beat that broke off never locks it.
- **Bots:** the play bots now take the way out of choice loops (they used to browse the farm Plans board forever), close any full-screen screen with B and fail if one won't close, list menus B can't leave, and only warn "boxed in" after testing all four directions. The reported stuck spots (house 7,2 and 8,9, farm 13,13, beach 33,4, town 40,2 and 28,0, meadow, marsh) all walk out: `tools/stuck_probe.gd` checks any spot. Test: `tools/softlock_test.gd` (in check.sh).
## 2026-11-19 — CONDUCT 1: first week, energy, fainting and sleep (both arcs)
- **Passing out no longer hides the night:** collapsing at 2am (or after 10pm) used to skip the morning summary, so you never saw what the sell box paid, what grew, crows, finished builds, the crew's night or the weather; the morning story beats and mailbox nudges were skipped too. The report is now kept (`SleepReport`, flags.wake_report) and shown when you come round, at home or in the clinic, then the morning beats run.
- **The short bar is explained:** the morning after a collapse says you wake on three quarters of your energy and how to avoid it.
- **First week is forgiving:** days 1-7 the clinic doesn't bill and nothing "goes missing" on the way home (the clinic note says why). From day 8 the old fees apply (`Faint.fee`: clinic 8% + 20 + 4/floor, cap 750; at home 5%, cap 300).
- **Bedtime warnings:** a toast at midnight and at 1:30am (once each a night) before the 2am collapse.
- **Pacing check:** `tools/first_week_test.gd` plays a modest phone player through days 1-7 in both arcs (real energy costs, prices, saturation and the early quests). Result: day 1 uses about a quarter to a third of the bar, never Exhausted; purse 50/60 → ~300 on day 4 → ~730 on day 5 (turnips, Maple, Alder, Hazel) → ~1170 by day 8. The Bigger Backpack (600) lands on day 5, copper tools (300 + 3 bars) the week after. No data change needed; the test holds these bands (in check.sh), plus the faint/clinic/sleep rules.
## 2026-11-19 — CONDUCT 1 (c1_13): saves for a new player, opening Skip
- **Skip the opening:** the farm's opening scene (both arcs) now has a **Skip ▸▸** button top-right (MENU does the same). It jumps past the narration to the opening's choice, so the answer still counts, and the how-to-play line still shows. The quests arrive as before. The button goes away when the scene ends, and also if you leave mid-scene.
- **Save audit:** checked first run with no save (every setting at its default, the title shows only New game), a new game in all three slots (penguins, gangsters, a custom hero), save and reopen at every early milestone (opening done, first planting, closing mid-way to town, standing in town, inside the store, first night's sleep, a story scene cut off), slot isolation, settings shared across slots, a save file cut off mid-write (falls back to the backup and keeps the bad copy), and an old pre-Round-13 save moving into the arcade tickets, community farm, mega regions and campaign gate. All of these held. No save bugs found beyond the missing Skip.
- **Test:** `tools/save_test.gd` (in check.sh; pass a dir under xvfb for a picture of the opening with its Skip button).
## 2026-11-19 — CONDUCT 1 (c1_17): the Marked re-cut, power poses
- **The ten Marked were mis-cut.** Their sheets were sliced by "cell N of 16", but flame trails, rings and wind streaks join figures, so cells merged and names slid: Ember's power strip showed half-figures cut at the seams (choppy), Rio's attack showed his back and his sit/sleep were ring pulses, Dahlia/Juno/Bruno "views" were watering-can, toolbox and forge poses, Dahlia/Juno/Atlas walked away with side steps mixed in, and several "attack" strips were running frames. `tools/reslice_marked.py` re-cuts all ten on each band's own grid (17 cells where a row squeezes one in), one scale per character, frames centred on the torso with feet on the line; every animation's cells were picked by eye (`--cells DIR` draws the indexed sheets). Fake back-view attacks are dropped (they fall back to attack_down), side strips all face right like the walk.
- **Power poses play:** a Marked enemy now strikes its power pose when it uses a Gift move (`Enemy.play_power`), and a Marked partner does when you tap the partner button (`Companion.play_power`).
- **Test:** `tools/anim_test.gd` section 7 checks every Marked frame holds one centred figure, a 6-frame one-shot power strip, no fake attack_up, and the Gift power pose.
## 2026-11-19 — CONDUCT 1 (16): community farm + round-13 world fixes, regression pass
- All round-13 world checks pass (commons_test, r13_world_test, exit_edge_check, door_check, invisible walls on mountain/moon).
- **Farm terrace invisible wall:** the north track's soft edge painted over the terrace's west rock wall (x38), so the raised north-east grass looked walkable from the path but wasn't. The track now runs one column west (x36) and the wall shows.
- **Day-1 visit to the commons:** walking west before Hazel's letter used to find an empty lot (she only volunteers once the place is known). The first visit now makes it known, so she's there on her morning schedule to greet you, and no "come and help" letter arrives after you've already met her.
- **HUD place names:** the community farm reads "Dreamhollow Commons" / "Westside Lot Garden" (was "Community Farm" in both arcs); the rec rooms read the rec center's name (were "Rec" / "Rec Up" after the stairs or a reload). `PlaceNames.for_id(id)` added for tests.
- `tools/invisible_walls.gd` now also lists community_farm and no longer crashes on freed props (gangster outskirts). Tests extended: commons_test (day-1 visit), r13_world_test (labels, both arcs).
## 2026-11-19 — CONDUCT 1 (03): goal line and quest pointers, days 1-5
- **Goal line fits and says how:** long quest texts were cut to "…" by the HUD's two lines (the resonator step lost its whole how-to). `GoalLine` (scripts/goal_line.gd) now gives the one step that's next: resonator "needs 4 more stone" → "Build it: Plans board by your house" → "Find 2 more shards" → "Refine: hold 3 shards, USE on the Resonator"; the meadow says "the farm's east gate", and inside it counts the foes left before the boss.
- **Gangster order fixed:** after the meadow the goal said "Get through the gate to Hideout town" while the story said to see Sal first; it now suggests Sal (arrow on him), then the outskirts gate. Skipping Sal is fine: in Hideout the goal is the first recruit, and the Docks campaign only shows after it.
- **Campaign pointer:** "First: ..." came last and was always cut off; it now reads "Docks is held. First: training with Sal on the campaign map (Menu > Map). Then win "Dockside Push"."
- **Ripe first crop** comes before any other goal (it used to hide under the day-3 meadow quest). The rainy gangster first night says "The rain waters it today" instead of "Watered".
- **Goal arrow:** the HUD's green edge arrow (mine-only before) now points at the goal on outdoor maps: the exit toward the goal's area, then the person or thing (Sal, Catkins, the Plans board, the outskirts gate, the Resonator). Hidden in dialogue and battles.
- **Quest log** starts with "▸ Now:" (the same text as the HUD) and lists open story steps before finished ones.
- **Test:** `tools/goal_line_test.gd` (in check.sh) walks days 1-5 in both arcs and checks every goal, its length and its arrow.
## 2026-11-19 — CONDUCT 1: mega regions and campaigns regression (c1_18)
- **Fairy ring was invisible:** the forest travel point to Gloamwood (opens at chapter 2) looked for `props/fairy_ring`, but the art is `nature/fairy_ring`, so players saw the keeper standing in tall grass with nothing to step into. The entry now names its group (tools/mega_regions_new.py), and tall grass/weeds right round any travel point are cleared so the ring reads.
- **Vehicles are solid:** the limo, caravan, sled station, balloon tower and ticket booth blocked only their middle cell; now their base row blocks (never an exit or another thing), so you no longer walk through the gold limo on the farm road.
- **Campaign list:** the "aren't open yet" line showed a missing-glyph box (lock emoji); the locked Training row's long text squeezed its whistle icon away (now "locked · after chapter 2").
- **Battles:** the off-screen arrow's point name was cut to 40 px ("Scarecrow Po"); 90 px now, kept on screen.
- **Valley map:** gate badges near the right edge (Cities) put their name off the painted map; it now goes left of the dot.
- Tests: `tools/campaign_gate_test.gd` takes `ARC=gangsters` (Sal, Hideout town) and check.sh runs both arcs; `tools/mega_regions_test.gd` fails when a travel point's art is missing or not drawn.

## 2026-11-19 — CONDUCT 1 (c1_01): penguin arc, new game to day 2
- **Audit:** played a new penguin run headlessly from the first line to day 3 (`tools/newgame_flow_c1.gd`, screenshots + every line and goal logged).
- **The Star Crystal is drawn:** in the field it was a pale vector diamond; it is now its own sprite (the face from its portrait, `characters/light_crystal`), bobbing over a fixed shadow, and it plays its speaking strip while its lines type out (story beats too).
- **Day 2 has its scene:** Pip-Pip and Nova now come on day 2 (the morning after the crystal lands) instead of crowding day 3 with the howl, the meadow letter and the storm. `companions.json` `partner_scene.<arc>.when.day` now really sets the day (gangsters stay on day 3). The visitors walk up and stand in view while they ask; the one who stays becomes your follower on the spot (before, the new partner was invisible until you changed maps), the other walks off. "At dawn" is gone (the scene can play at any hour). The partner button is explained by where it is ("round button, left of CHECK"), not as a heart the screen doesn't show.
- **Mailbox:** a letter bobs over the mailbox while something waits in it (`Mail.waiting()`: the opening story letters or unread mail). The morning toast only mentions mail when there is some (it used to fire on day 2 even after Maple's letter was read on day 1). Maple's letter now says the seeds are in the envelope, not at her store.
- **Wording:** the crystal's last intro line names the hoe's slot and the full till / plant / water order, and points at the goal line under the toolbar. Talking to the crystal before the first harvest gives the exact next crop step and ideas for the wait (clear the field, forage to sell, meet the town, fish with the rod in hand).
- **Test:** `tools/newgame_penguin_test.gd` (in check.sh).
## 2026-11-19 — CONDUCT 1 (c1_02): gangster arc, the first hours
- **Day 2 letter:** M.'s night-one letter was read in the intro, then delivered again on day 2. Now day 2 brings a second envelope with 3 strawberry seeds (the penguin side gets 3 from Maple) that points at Maple and Sal; on day 1 the box reads ordinary mail. One tap on the box also reads letters waiting in the mail list (both arcs).
- **Sal:** the arrival called him a woman (his portrait is a bearded man); his town tour line now introduces him. No "Heat 0/5" line in the morning report before heat has ever been explained.
- **Meadow boss:** the boss-down text ("stays down, sixty crystals, a note") contradicted the coat scene right after it ("stumbles off, leaves his coat"); now one story. Its hint points at Sal and the outskirts gate.
- **Hideout order:** on arrival a new player got Sal's drill invite, a campaign-map tab and the docks quest before Deuce and Mama Rosa were even introduced. Now: arrival scene -> goal "recruit your first crew: Deuce, Mama Rosa" (quest opens on reaching the Hideout, no longer only after Sal) -> first recruit explains crew perks/loyalty/MENU > Party -> Sal's drill invite -> docks.
- **No Marked ambush** (Atlas "Tiny" in the outskirts) before the Hideout's arrival scene.
- **Gangster wording** for the first two quests (meet_town, first_harvest); Rolled Bills say what they're for.
- Test: `tools/gang_start_test.gd` (in check.sh) plays new game -> day 3 -> meadow -> Sal -> Hideout -> Deuce with checks; screenshots with a dir under xvfb.
## 2026-11-19 — CONDUCT 1 (c1_11): first visits to town

- **Door hours** (`TownHours`, scripts/town_hours.gd): shops lock their front door outside hours with a sign giving the hours (7am to 9pm; library 8 to 8, bank 8 to 5 like Ivy, school till 6); homes stop answering after 10pm unless you have 4+ hearts with someone living there; the inn, chapel and Rec Center keep their own rules; crew shops follow their "closed" fronts. Counters (`Interior._counter`, region keepers too) read the same table.
- **First meetings** (`Intros`, scripts/intros.gd): every town villager introduces themselves on the first talk (who, what, where and when to find them), in both arcs, indoors or out. A story beat on that first talk counts as the meeting.
- **Town tour**: Mayor Alder / Sal now walks up the avenue to you for the welcome, then walks back off to their day (`Npc.step_in/walk_off`).
- **Sal** is a man everywhere now (the gangster arrival text and a hint said "woman"); the arrival text says where he spends the day.
- **Rain**: on a plain rainy day (the gangster arc's day 1 is always rain) a different few grown-ups go out under umbrellas, so the town isn't empty (`Npc.rain_walker`); no umbrellas indoors.
- **Mail, days 1-5**: a welcome letter with the town's hours on day 2 (Alder / Maple) and two loaves from Posy on day 5; the story letters live in `Mail.story_due()` and all waiting letters are read in one visit; a sealed letter bobs over the farm mailbox while anything waits (`MailFlag`); the morning "check the mailbox" toast only shows when there is a story letter. The gangster arc's second M. letter comes on day 2 (the first one was read in the opening). Mail gifts toast the real count.
- **Community board**: no job pays less than 12 + 4 per item (day-1 "3 stone for 6" is gone); crop orders only ask for crops whose seeds the town sells today or you already grow (`Shops.growable_now`); strangers on the board show their job ("Posy (baker)"); an empty board says so.
- Hazel's warehouse lock text no longer promises it opens.
- Test: tools/town_first_test.gd (both arcs; in check.sh).

## 2026-11-19 — CONDUCT 1 (c1_14): the arc choice and each arc's early systems explain themselves
- **Path cards:** "Choose your path" now shows three heroes of each path, a tone line and three lines of how it plays (penguins: Star Crystal, Meow Pow Wow, overnight gifts; gangsters: lie low, crew/fronts/bills/heat, take the districts back), plus a note that each save slot keeps its own path. Data: `feel`/`pitch`/`faces` in data/arcs.json.
- **First use of an arc building** (press, laundromat, training center, soda cart, pool, burrow, shrine, litter tray, campfire) plays one short intro from whoever it belongs to (`ArcIntro`, scripts/arc_intro.gd). A crew member you haven't recruited yet leaves a note instead of speaking.
- **Locked plans say what opens them:** pool, burrow and shrine said "story first"; now "meet the merkitties at the lake shore", "turn back the crystal babies on the mountain", "learn the Meow Pow Wow from Catkins" (`unlock.hint`, gen_stations.py). The Operation and Sanctuary plan lists open with a line on what they're for. The press plan says how bills are used.
- **Racket:** the laundromat says where bills come from when you have none (or that the wash is full); Sal's heat speech points at the real HUD pips (it said "a flame by your hearts"); the morning report no longer says "Heat 0/5" before heat has ever come up; Rolled Bills (thug cash) read as real money, and Sal's quest says thugs carry them.
- **Sanctuary:** the morning report names only the place that holds gifts (it always said "check the pool and the burrow", even with one built).
- **Test:** tools/arc_intro_test.gd (in check.sh).
## 2026-11-19 — CONDUCT 1 (07): phone UI at 270x480
- **Symbols on the web build:** the default font (Open Sans) has no ◆ ♥ ★ ✓ ▶ ⚔ ☂ arrows etc., and the web build has no system fonts to borrow them from, so they printed as empty boxes on the phone (shop prices, hearts, quality stars, weather, campaign list). `fonts/symbols.ttf` (111 glyphs, 17 KB, cut from DejaVu Sans by `tools/make_symbol_font.py`, licence in fonts/LICENSE-symbols.txt) is now a fallback of the default font (`SymbolFont` autoload). 🔒 ⏱ ⌛ 〰 had no glyph anywhere: now ⊘ ◷ ◷ ∿.
- **Campaign list ran off the right edge** (penguin arc: the training lock line didn't wrap); the scroll bar no longer covers the rows.
- **Finger-sized buttons:** menu rows, Close, skill tabs, hero rows, chest buttons, craft − / + / Max / MAKE (MAKE is gold when it can run), bowling ✕.
- **Toolbar counts** are outlined and sit inside their slot (white on the light slot art was hard to read).
- **Prize counter:** descriptions were cut mid-word; rows now end at a word with "…" and the picked prize shows its full text.
- Test: `tools/phone_ui_test.gd` (in check.sh; `UiAudit` in tools/ui_audit.gd) opens every screen in both arcs with system fonts off and fails on off-screen/spilled controls, buttons under 20 px, cut text, tiny fonts or missing glyphs; with a dir under xvfb it saves screenshots.

## 2026-11-19 — CONDUCT 1: performance (phone/web)
- **Measured** every outdoor map with the new `tools/perf_probe.gd` (load ms, frame ms while walking, nodes, draw calls, texture MB, and the draw calls of one baked-ground chunk). Normal frames were already lean (~80-120 draw calls). The stutter was the baked ground: each 256 px chunk re-issues the whole map's drawing, and the cliff outlines and rounded forest floor drew one polygon or line per 6 px segment / cell, each its own draw call. One chunk cost 7071 draw calls on the Shattered Vale battlefield, 4730 on Neon Block, 3030 in town, 2789 on the mountain, 2249 on the farm, and a few chunks get baked every time you walk across a chunk edge.
- **Fix:** `TriBatch` (scripts/tri_batch.gd) collects those pieces and sends each pass as one triangle array; inner forest-floor cells are plain rects. Per chunk now: Shattered Vale 184, Neon Block 209, town 164, mountain 138, forest 91, farm 54 (25-55x fewer). Before/after screenshots of cliffs, border woods and side walls match (only the hero's walk frame differs; side-wall rim lines within 19/255).
- **Texture memory:** the cache used to keep every texture until 1500 were loaded, then dropped all of them at once (a reload hitch, and ~125 MB of textures on a long trip). `Art.trim_cache` now drops only textures the last scene didn't use, once the cache passes ~64 MB; what you just used (hero, HUD, the place you came from) stays.
- **Export size:** the web pack is 118 MB (CI). Music already streams; art/gen/kits is excluded; art is lossy WebP except tiles. No single large offender left (biggest files are 0.4 MB title/map art); the unused `buildings/*_night` copies are 0.26 MB.
- Test: `tools/perf_test.gd` (in check.sh). Probes: tools/perf_probe.gd, tools/startup_probe.gd.
## 2026-11-19 — CONDUCT 1 (04): held-tool rules everywhere
- **Wrong tool = a short hint, never a silent or wrong action.** New `ToolHint` (scripts/tool_hint.gd) gives one voice for it: "Hold the Axe to chop it: tap it on your toolbar." (or "put it on your toolbar (MENU > Items)", "You need a Fishing Rod to fish.", "Your Axe is at the smithy for its upgrade."), with a soft nope sound once per burst.
- **Fixed:** trees/logs/stumps/rocks/mine rocks/mountain and region ore said nothing when you didn't own the tool (you just punched); the moon's crystal rocks broke with ANY tool if you owned a pickaxe; water in the forest, lake, beach, crystal meadow, regions and the farm said nothing without a rod; the can and the rod pulled weeds (a watering row weeded the field); the can and rod smashed mine crates; seeds in hand punched the air (now "Seeds go in tilled soil..."); the rod cast at grass (now "Face water and tap USE to cast."); a dry crop with the axe/pickaxe/sword did nothing (now "Hold the Watering Can..."); empty tilled soil with a tool now says to pick seeds; berryless bushes, the forest's old wood (axe) and standing stones (pickaxe) say why. The hoe stays quiet on tilled soil so work rows don't spam.
- **Toolbar tutorial:** the first time each tool (and seeds) is in hand, one line says what it does and how (hold USE and walk for rows). Intro lines now say "tap the hoe on your toolbar" instead of "Till with USE".
- **Test:** `tools/tool_rules_test.gd` (in check.sh): every tool against trees/logs/stumps/rocks/weeds/water/bush/grove/soil on the farm in both arcs, region mrock + water, mine rock + crate, community-farm debris, the hint lines and the first-pick tips.

## 2026-11-19 — Round 13: audio fixes (music on the web, softer effects, grass steps)
- **Why most areas had no music on the web:** the game fetched streamed songs with a relative address ("music/neon.ogg"), and Godot's HTTPRequest refuses those ("Invalid URL scheme"). So 57 of 61 songs, including both arc themes, never loaded; only title, farm, house and music box played. `Music` now builds the full address from the page (`new URL('music/', document.baseURI)`).
- **Music never goes silent:** while a song downloads, the song already playing carries on, or a packed stand-in starts (farm outdoors, house indoors), and the real song crossfades in when it arrives. Failed downloads retry (2, 5, 12, 30, 60 s). Broken cached copies are thrown away and fetched again. Songs you hear often (night, rain, town, meadow and the arc's own areas) are fetched quietly in the background, one at a time.
- **Tests:** `tools/music_map_test.gd` loads every map, region, battle, colony and interior in both arcs, by day and by night, and checks that each one's song exists (371 checks). `tools/music_stream_test.gd` runs the web streaming path offline against a local server: stand-in, takeover, cache, retries, no server. Both run in check.sh.
- **Softer effects:** `tools/sfx_soften.py` levelled and filtered 338 effect files. Every CC0 effect had been normalised to its peak, so long crackles (stun, EMP, spells) played about 20 dB louder than a twig snap. The loudest files are now 6 to 13 dB quieter. Loudness spread (p10 to p90) went from -22..-8 dB to -23..-14 dB. Bright metal and electric sounds get a gentle low-pass and a high shelf, and peaks stay at or under -1.5 dBFS. Everything is logged in audio/sfx/SOFTEN_LOG.json. The last two synthetic beeps (heartbeat, whimper) are now CC0 recordings.
- **Grass steps:** one grass take was a Kenney boot step, the "clomp". It is replaced by a soft Fantozzi grass step, and dirt lost its two boot steps too. Town and uptown used to be all "stone" and highlands all "gravel": `Footsteps` (scripts/footsteps.gd) now picks the step from the map's real ground (lawn and meadow are grass, roads and the plaza are stone, docks are concrete and wood, tilled soil is dirt). In town, 74% of cells are now grass, where before it was 0%. Grass and leaf steps are low-passed and 4 dB quieter, with a smaller pitch and volume spread. Checked by `tools/footstep_test.gd` (in check.sh).
## 2026-11-19 — Round 13: mega regions, the new worlds
- **Five new mega regions** fill the five planned slots (each a hub town + 3-4 areas, its own tab and painted map):
  - **Gloamwood** (both arcs, chapter 2): fairy ring in the forest → Lanternfall (mushroom-cap houses, lantern posts, moth shrine), Violet Glade, Crystal Thicket, the Moonpool. Boss: the Thornmother.
  - **Sunscorch Expanse** (both, chapter 3): sand-sail caravan on the beach → Mirage Post (oasis, bazaar tent, adobe houses, sun obelisk), Dune Sea, Glass Canyon, Sunken Temple. Boss: the Sun Colossus.
  - **Frostpeak Reach** (both, chapter 4): sled station on the mountain → Hearthhold (log lodges, village hearth, bell tower, hot spring), Glacier Fields, Rime Caverns, Frozen Falls, the Summit. Boss: the Rime Wyrm.
  - **Windward Isles** (penguins, chapter 5): Captain Zephyr's balloon in the meadow → Breezehaven (propeller cottages, wind shrine, mooring tower), Sunrise Shelf, Storm Shelf, Starfall Garden. Boss: the Storm Roc.
  - **Gilt City** (gangsters, chapter 5): the gold limousine at the farm → Grand Plaza (Madame Aurum's statue), Casino Row, Gilded Gardens, the Vaults. Boss: Madame Aurum.
  - **Ironline rail frontier** (gangsters, chapter 3) joins the Cities tab: night-train booth in town → Junction City, Freight Yards, Mill District, Coalbrook Tunnels. Boss: Baron Coalbrook.
- **Getting there:** each travel point has a keeper who writes to you when the story is far enough along and asks for a short hook quest (supplies for the trip). Done, the way stays open; every hub's vehicle takes you home or on to any other hub you've opened.
- **Reasons to go back:** regional ores, loot spots, forage tables and fishing (Glacier Pike, Sun Trout, Skyfin, Ghostfish), a shop per hub (regional dish, ring or charm), a hub job per region, a unique charm or ring from each boss (+1 heart), and six kitchen recipes that need regional ingredients (Gloam Pudding, Sun Loaf, Stoker's Stew, Frost Sorbet, Cloud Souffle, Gilded Flan).
- **Foes:** 18 native kinds (recoloured kin of existing foes) plus 6 bosses; the Storm Roc and Rime Wyrm, Madame Aurum and Baron Coalbrook have their own new sprites.
- **Art (image tool, 17 renders):** 26 landmark/hub props, 20 villagers with walk cycles, 2 boss sheets, 5 painted region maps (tools/slice_r13_a6.py).
- **Music:** five new ACE themes (mega_gloam, mega_desert, mega_frost, mega_wind, mega_gilt); every area also gets its own ambience beds (regions.json "amb").
- Generators: tools/mega_regions_new.py + tools/gen_mega_new.py. Test: tools/mega_regions_test.gd (in check.sh): every area in each arc that can reach it, spawns, exits, things, villagers, bosses, exit landings, home travel points, hook quests, the way home.

## 2026-11-19 — Round 13: mega regions (framework + conversions)
- **Mega regions:** ten big separate worlds, data in data/mega_regions.json (written by `tools/gen_mega_regions.py`). Five are the existing clusters, converted: **Space** (moon, star station, green planet), **Merkitty Colonies** (the four islands, penguins), **Lieutenant Cities** (docks, Neon, Uptown, the Pit, gangsters), **The Hollow Heart** and the **Sky Isles** (penguins). Five are planned for the next round: Sunken City, Frozen North, Desert Bazaar (both arcs), Clockwork Isles (penguins), Chrome Megacity (gangsters).
- **Map tabs:** Menu > Map has a tab row: Valley plus one tab per unlocked region. Locked regions get no tab (a fresh run shows no tab row at all). Each region tab draws its own themed map (stars and planets, sea lanes and islands, city blocks, crystal cave, cloud banks) with its areas, the routes between them, the way back to the Valley, campaign padlocks and your spot. The Valley map shows a small gate badge where each open region is entered and no longer pins mega-region areas.
- **Crossing over:** going into a region shows its name banner, the area name and a travel line (rocket, ferry, night bus, deep lift, great tree stair); coming home shows a welcome-home banner. The hideout's docks exit is now the "city bus".
- **Unlocks:** each region opens once its condition holds (launching from the pad, reaching the beach after chapter 1, reaching the hideout with the docks campaign open, the Hollow Heart lift, the sky stair quest) or when you arrive in one of its areas. Old saves are migrated quietly from what they've already seen.
- Test: tools/mega_region_test.gd (in check.sh): tabs hidden until unlocked, unlocking shows them, rocket/ferry/bus travel, banners, save round trip, migration.
## 2026-11-19 — Round 13: animation and visual fixes
- **Heroes rest facing the way they walked.** The 12B sheets (Pip-Pip, Nova, Coldy, Big Jim, Merry, Coco, Mer) drew "idle" as a side view, so every rest turned right; `CharacterLibrary` now makes their front pose `idle` (side kept as `idle_side`), and left rests mirror `view_right` instead of an unflipped copy. Companions rest facing their last walk too.
- **Penguin walk fixed.** `tools/reslice_hero12.py` re-cuts the 12B movement strips with one scale per sheet, torso-centred frames and no neighbour slivers: the old penguin walk turned to face you mid-stride (now redrawn, below); both penguins get views in their own design (Nova's were the old green-hat look).
- **Feet stay planted on every animation swap** (offset refit on `animation_changed` for heroes, pets, partners, critters, farm animals).
- **Animals:** `tools/reslice_wildlife.py` re-cuts the ground and medium wildlife (the deer's walk was half a deer plus a scrap) and the town cats (their idle blinked between grey/orange/black cats: the "flashing cat"). `tools/align_strips.py` centres every animal frame on its body and drops neighbour scraps (horses, foals, donkeys, pup...). Critters' legs keep pace with their speed, idle holds a pose instead of twitching, no flip-flicker. Hatchlings use the hen's chick strip.
- **Redrawn with the image tool** (5 sheets, `art/incoming/r13/a8_*`, sliced by `tools/slice_r13_a8.py`): the deer (6-frame walk, 4-frame graze), a real calf (idle, walk, eat), fox/squirrel/turtle walks with whole tails, and both penguins' walks (6 side, 4 toward, 4 away; the king had no toward/away walk before).
- **Rain puddles:** the old puddle_0..5 showed a different rock-ringed pond every frame; every wet day now uses the redrawn 3-frame puddles, flat on the ground layer, smaller in rain, never spilling onto buildings, each on its own frame and pace.
- **Props:** `tools/steady_props.py` stops warp pads, teleporter, holo table, hot spring, enchanting table, coffee pot and cauldron from swelling and shrinking each frame; `tools/unbox_props.py` fades the square backings of sunflowers and bulbs and clears neon-sign edge bars; mine lava glow is soft blobs, not bars.
- **Walk speed -10%** (52/96 from 58/108); footsteps match.
- Tests: `tools/anim_test.gd` (in check.sh). Dev shots: `tools/anim_shot.gd` (hero walk/rest close-ups), `tools/seq_shot.gd` (timed sequence of a spot, FOCUS=<animal>, WEATHER=rain).
## 2026-11-19 — Round 13: the community farm
- **New area west of town** (`scenes/community_farm.tscn`, town's west road ◀): Dreamhollow Commons (penguins) / the Westside Lot Garden, a reclaimed vacant lot behind a brick wall (gangsters). 52x40 with a tree border, four raised beds, plaza and well, tool shed and compost, greenhouse with cold frames, market stand and donation box, picnic corner, orchard row. On the world map as "Commons" / "Lot Garden".
- **Eight-stage quest line** run by Hazel (`Commons`, data from `tools/gen_community_farm.py`): clear the lot by hand (14 piles, tools matter), fix the shed, raised beds, donate seeds (3+ kinds), repair the well, plant the orchard, build the greenhouse, host the harvest market. Hazel's letter arrives on day 3; the journal entry follows each stage; the board by the gate takes contributions. Every stage reloads the map with the change shown, then a reveal with the rewards (crystals, friendship with that stage's volunteers, Commons Stew and Harvest Cobbler kitchen recipes, Harvest Baskets, the Green Thumb Charm).
- **Volunteers:** 19 schedule slots (Hazel, Sal, Gideon, Alder, Lumi, Finn, Mabel, Wren, Benno, Rook, Juniper, Posy, Bram, Maple and the kids) unlock stage by stage. They're at the farm instead of in town at those hours, work in their life poses (work, carry, eat, talk...), walk to ripe crops and harvest them. Rain and winter send most home (greenhouse, shed and market keep going). Market day (7th/14th/21st/28th once open) brings a crowd.
- **Economy:** beds grow overnight (faster watered: you, rain, or the well), get replanted per season; harvests stock the stand (buy at 80%), every third goes to your share crate; neighbours take produce nightly; donations build goodwill (4 reward tiers); market day buys your produce at +25%; the compost turns fibre/veg into fertilizer and drops some in your crate. Winter: open beds rest, cold frames grow. The well gives +15 energy a day.
- **Chatter:** villagers gossip about the farm's progress in town (per-stage lines, own lines for volunteers), and say work lines at the farm.
- **Art:** 11 new pieces from 2 renders (raised bed frame, cold frame, derelict shed, boarded well, compost bin, planting hole, staked sapling, picnic table, garden mural wall, produce crates, donation box), `tools/slice_r13_a3.py`.
- **Test:** `tools/commons_test.gd` (in check.sh) walks every stage in both arcs and checks map changes, schedule, growth/harvest, winter, stand, save/load and the town hooks; with a display it saves before/after screenshots.
## 2026-11-19 — Round 13: world, maps and time (Tom's playtest)
- **Exits line up:** the lake's top-edge road now comes up into the bottom-left of the forest (new road mouth at the forest's south edge, path spur and signpost), facing up; the forest's old west-edge lake exit is gone. New `tools/exit_edge_check.gd` (in check.sh) checks every edge exit of every map: leave by one edge, arrive near the opposite edge of the next map, facing inward, with the way back on that edge and a matching label arrow.
- **Every building answers:** `BuildingAccess` (scripts/building_access.gd) gives each building with no way in a short reason on its door ("Private home: ...", "Locked: ...", "Closed: ...") and points every wall cell of it at its door or reason, so USE anywhere along the front works. Region building props and animated region buildings are covered too. door_check.gd now walks every map and fails on any silent front wall (104 buildings checked).
- **Buildings at town size:** region buildings carry a `scale` in regions.json (town size, about 1.0) and the streets of the Docks, Hideout, Neon District and Uptown are re-laid out around them; also the Wastes, Highway, Sky Islands, Orchard Hills, Highlands, Ruins, Quarry, Marsh and Riverlands huts/towers, the forest woodcutter's hut and the beach hut.
- **Region name on screen:** a small label left of the clock box names where you are (`PlaceNames`: regions, battlefields, colonies, mine floor, and inside buildings the name on the door you came through).
- **Moon (the rocket region):** the landing pad no longer walls off its own steps; the rocket house and teleporter footprints match their art. `tools/invisible_walls.gd` (in check.sh for mountain + moon) finds blocked cells with nothing solid drawn on them and walk-on pads that block.
- **Lighthouse:** dark and derelict (new art: boarded windows, cracked lamp, no beam; `tools/slice_r13_a9.py`) until Marlowe's lens quest lights it, then the turning lamp (swaps live with a sound).
- **Fainting:** collapse before 10pm and you come round at 10pm the same day (clinic, or your bed when just tired), patched up with enough energy to get home; the night after still costs the quarter bar. After 10pm or at 2am it's next morning as before (`Faint`).
- **Mornings:** no more night-dark dawns: before sunrise it's a soft rose dawn (at most 0.42 dark), then an orange-gold light that fades to plain day 2.5 hours after sunrise, following the season's sunrise (`GameState.morning_glow`, `GameMap.sky_tint`); sunrise sky strip on the backdrop.
- Tests: tools/r13_world_test.gd (faint timing, dawn/glow in all seasons, place names), exit_edge_check, invisible_walls, extended door_check, all in check.sh. area_shot.gd takes `scene:x:y:minutes:flag`.
## 2026-11-19 — Round 13: arcade mini-games (Recreation Center)
- **Five playable cabinets**, full-screen, paused, with their own touch deck (◀▲▼▶, A, B) that presses the input actions:
  - **Block Jumper** (flagship): auto-runner; A jumps (hold for higher), ▼ ducks under low ceilings / drops fast. 8 levels that unlock in order (Meadow Dash … Star Gauntlet), faster and busier each time (gaps, spikes, blocks, steps, low ceilings, cloud platforms, moving platforms, spike pits), plus Endless (speed keeps rising). Checkpoints, coins, 3 lives, level select with locks and best distance per level; clearing level 4 unlocks a double jump.
  - **Crystal Stack** (falling gems, 7-bag, ghost piece, faster every 8 rows), **Whack-a-Grump** (40 s, gold/helmet grumps, don't bop bunnies, combos), **Claw Machine** (12 s to aim; a centred grab wins a real item; the grip loosens after each win), **Duck Pond** (cork popper, 3 lanes, golden ducks, frogs cost points).
- **Money and tickets:** each play costs crystals (cash in the gangster arc): 10, or 20 for the claw. Tickets are paid by performance through `Tickets` (scripts/tickets.gd) and each game keeps a high score.
- **Hub:** `ArcadeHub.open(map, id)` (or `open(id)`) with ids jumper/stack/whack/claw/gallery, or "" for the cabinet picker. The Rec Center's cabinet row is now Block Jumper, Crystal Stack, Whack-a-Grump and Duck Pond (`CABINETS` in tools/gen_rec.py; two new cabinet props), and its claw machine opens the real Claw Machine game (plush prizes are the prize counter's teddy/penguin/cat plushes, candy and a few trinkets). `ArcadeHub.milestone(id)` (jumper_1..8, jumper_coins, jumper_endless_300/1000, stack_3000/15000/stack_tetra, whack_150/400, claw_win/claw_5, gallery_300/800, all_games) for prize locks.
- **Art (10 image-tool renders, art/incoming/r13_arcade):** 5 cabinets (picker icons and title cards, ready as world props), 9 painted parallax backdrops, 8 ground tile sets, the cube hero, coins, spikes, flags, goal, platforms, grumps/bunny/mallet/hole, 6 plush prizes and the claw, toy ducks/frog/cork popper, and lawn/booth/claw-box stages. Sliced by `tools/slice_r13_arcade.py` into art/gen/arcade/.
- **Music:** two ACE songs: `arcade_jumper` (chiptune) and `arcade_hall` (the other cabinets). The cabinet puts back the area song when you leave.
- **Tests:** `tools/arcade_test.gd` (each game starts, plays scripted frames, ends, pays; level 1 played to the goal; unlock order; picker; no-money; milestones). `tools/jumper_solve.gd` replays a stored winning input plan for every level (data/jumper_plans.json; `-- --solve` searches the real physics again after level changes). Both in check.sh. Screenshots: `tools/arcade_shot.gd`.
## 2026-11-19 — Round 13: the Rec Center (Rec Hall in the gangster arc)
- **A new building in town**, south-east of the library, with a lane to the avenue and a sign. It opens on the first morning from day 7, once you've met the town. A letter (Alder / Sal), a journal step and a hint announce it; your first game is free and your first visit gives 20 tickets. Before that the door shows the opening banner. New art: a timber Rec Center and a brick-and-neon Rec Hall.
- **Two floors.** Ground floor: lobby, prize counter, front desk, high-score board, jukebox (changes the song), vending machine, claw machine (plushies, with a pity win after 12 tries), skee-ball, and six arcade cabinets (`ArcadeHub.open(map, game_id)`; agent a2's games plug in there). Upstairs: four bowling lanes with ball returns, score consoles, a snack bar, shoe rental and a trophy case.
- **Bowling you can play** (`Bowling`, full screen): line up, spin, aim and power, then a perspective lane with simple pin physics and slow motion at the pins. Ten frames with real scoring (strikes, spares, the 10th frame), an overhead score sheet and a pin chart. A game costs ◆25 and pays tickets for score, strikes and spares. Touch buttons, or the stick and USE.
- **Tickets** (`Tickets`, run["arcade"], old saves migrated) and the **prize counter** (`PrizeScreen`): 22 prizes on 4 shelves. Some prizes open at milestones (a 100/160/200/220/270 game, arcade plays, tickets won). Decor prizes (trophies on a shelf, music box, painting, jukebox, home arcade cabinet) show up in your house.
- **A hub for villagers:** 17 of them have visit slots (evenings, rest days, rainy days, league night every third day of the week). They stand at lanes and cabinets, bowl on their lanes (with a cheer on a strike), and talk about the place and your best score. Two side quests: Tobin bets you can't bowl 120; Mabel wants the Teddy Bear.
- **Audio:** a new ACE song "Lane Two Is Lucky" (`rec_center`; the gangster Rec Hall keeps `neon`); CC0 sounds for the ball roll and pin crashes; a bowling-alley ambience bed (`rec_alley`).
- Data: `python3 tools/gen_rec.py`. Art: `python3 tools/slice_r13_a1.py`. Test: tools/rec_test.gd (in check.sh). Screenshots: tools/rec_shot.gd.
## 2026-11-19 — Round 13: battle campaigns overhaul
- **No campaigns on day one.** The campaign map, board and war-table battles open through a lead-in (`CampaignGate`, scripts/campaign_gate.gd): chapter 2 of the story (Catkins teaches you / you reach Hideout town), then a guided training drill with a veteran (Catkins or Sal invite you in story beats, data/campaign_story.json), then per campaign a team (partners, crew, Marked friends, villagers at ♥2) and tiered provisions (wood/stone → copper → iron → gold → refined crystal, plus ◆). Mustering pays the provisions and turns them into starting supply. Messages say exactly what's missing ("Recruit 2 more allies and bring 20 Wood, 10 Stone."), and the goal line adds it after the campaign pointer.
- **Training drill** (`BattleDrill`): six short steps on the orchard field with live checks and a step card: take a point, build a helper, RALLY follow, the point menu, RALLY to a point, capture and win. Foes only come in the last step. Pays once and trains you.
- **Briefing cards:** every campaign battle and the drill open with a card (`BattleBrief`: kind badge, objective, how to win/lose, your army, controls). It pauses the game, stays up a moment the first time, and each kind can be hidden after that. Every campaign board opens with its own briefing (war-table panel, how it works, length, a ticked list of what it asks); "?" shows it again.
- **Battles are less clunky:** an objective banner is always on screen (TAKE ALL 4 POINTS (2/4), SIEGE, HOLD, CONVOY, CAPTAIN), a RALLY button with painted icons and a helper count, a pulsing RALLY marker on the target point (or round you when they follow), a rally menu that marks the current choice and each point's owner, and toasts moved below the bar.
- **Shorter, measured campaigns** (tools/gen_battles.py): 4 territories at tier 1 (no sieges/defends before the gate), 5 at tiers 2-3, 6 at tier 4, 7 at tier 5; enemy tickets, hold timers and foe caps scale with tier; each board records its fewest battles to the gate.
- **Art:** 5 image-tool renders (art/incoming/r13_a4/, `tools/slice_r13_a4.py`): Catkins' and Sal's training panels, the war table, 6 battle-kind badges (also the board tokens) and 6 HUD icons (rally guard/follow/send, objective, whistle, supply). Audio reuses existing cues (sfx_audit: 0 missing).
- Tests: tools/campaign_gate_test.gd (new, in check.sh), campaign_map_test and campaign_story_test updated for the lead-in.
## 2026-11-19 — Round 13: gangster arc cash, underworld look, gang mining/swings, pup in the mines
- **Cash, not crystals (gangster arc):** `Money` (scripts/money.gd) is the one arc-aware money name/symbol (`sym/fmt/word/t`). `MoneyHook` (autoload) installs `Money.t` as a Translation, so every Label/Button shows `$` and "cash" in the gangster arc (shops, rewards, toasts, mail, quests, sell box, bank, crafting fees, story choices); Dialogue, the HUD goal line and the campaign board's drawn text convert too. HUD shows a cash icon (art/gen/ui/cash); mine cash loot flies in as a bundle (ui/cash_bundle). Coin clinks become bill sounds (`cash_pickup`), the morning sell-box payout rings the register (`cash_register`) — CC0 Money/purchase packs. Penguin arc unchanged. Test: tools/cash_test.gd scans every gangster-arc data/script string for crystal money.
- **Underworld redesign (29 renders, art/incoming/r13/):** the six thugs + lookout, all eight lieutenants (sprites, portraits, boss cards), the twelve crew (sprites, portraits, badges, signs), the ten Marked and all eight gang heroes were redrawn darker and cyberpunk (night-city coats, neon trims, implants, hard faces, ages ~15–30; Vance, Mags, Pike, Mama Rosa, Doc, Marlene now young). Same sheet layouts, cut by the original slicers via `slice_world5.py` steps `r13_heroes`, `r13_dark`, `r13_marked`, `r13_cash`.
- **Gang mining and tools:** the six gang heroes that had no tool poses now have hand-picked hoe/axe/pickaxe/water poses (`GANG_TOOL_ROWS` in slice_world5.py). Every work swing takes the same time for every hero (`Player.TOOL_TIME`), so the gang side no longer mines faster; a hero with no pose for a tool swings its attack frames with the tool drawn over (`HeldSwing`).
- **Sword on gangster:** gang attack frames are empty-handed, so a held sword/club is drawn sweeping over the swing; guns are held out when fired.
- **Pup in the mines:** the pup follows you down (`PupMine`), stands on open floor of each new layout, keeps stay/guard (waits by the lift), fights, and between fights runs off to dig finds from the floor's ore pool and carries them back. Test: tools/gang_play_test.gd.

## 2026-11-18 — Round 12: art complete (image tool)
- **Every outstanding art prompt is drawn:** 179 renders from the dreams-image server, plus 12 redraws (wrong-person rows, missing frames, matching enemies), which fills Prompts 17-30. Nothing is left in docs/MISSING-ART.md.
- **Sliced and live in the game** (`tools/slice_world5.py` + `tools/slice_comp.py`, which find pieces as magenta-separated blobs):
  - 21 + 32 + 14 item icons;
  - portraits: Marlowe, Orla, Ivy, Tam, Benno and Sel (12 moods), winter faces for 9 villagers, 12 minor characters, Big Grump and the Commander, 8 hero outfits, the President (and his tall card), Biscuit, Grandfather Auk, the Hollow Heart trio and Pip the ferry-cat;
  - villager life poses for 17 villagers (LIFE_SKIP is now empty), 10 seasonal walkers, and Mabel's own walker;
  - thug walk/attack/hurt/KO sets for 6 thugs plus the Lookout (now his own sprite);
  - attack frames for 9 foes, a Big Grump boss sheet, three colony bosses (with defeat frames);
  - dog fight, play, fetch, beg and dig strips for 8 pets; new pup strips; pet gear overlays;
  - 50 buildings redrawn in place on the same footprint (town, lake, farm, neon district, docks, roadside), with `_night` versions saved for later;
  - 8 orchard trees in 6 stages, 10 ores, crystal trees, the pylon, sprinkler sprays, silo, incubator, ferry, fountain, storm puddles, glow sprites;
  - boss banners, party cards, hero cards, gate scenes, 12 story panels, 4 ending panels, the app icon, partner-ability icons, unlock-node icons and all 8 skill-icon sheets.
- **Kits for later rounds:**
  - blob edge sets (river, pond, shore, snow, bog, cave, paths, tilled soil, colony shores; `tiles/<set>_<role>_<n>`) and 60 new seamless textures, ready for the map round;
  - generic pieces (cliff kits, interiors, river and marsh dressing, UI kits) in art/gen/kits/, which is left out of the web export until a map uses them.

## 2026-11-18 — Audio project (ACE Music + CC0)
- **Music:** 61 real tracks from ACE Music replace every placeholder. Every area, room, colony and battle mood has one. Bosses get music by kind, with the arc themes reused for the boss and ending songs. Also: chase and danger music, both endings with the credits after, a music-box title and a sung merkitty lullaby.
- **Jingles and effects:**
  - 45 jingles and instrument sounds from ACE;
  - 306 CC0 effect files (with takes) from 96 OpenGameArt packs;
  - 40 CC0 ambience beds and spots;
  - 2 ACE drones (crystal cave, space).
- **Wiring:** spells, guns, enemy deaths, crafting stations, footsteps (10 ground types), menus, shops, battles, campaigns, secrets, journal pages and new regions all have their own sounds. Talk blips are pitched per speaker.
- **Web:** music streams on demand and is cached; the first download only carries 4 songs.
- **Checks:** `tools/sfx_audit.py` added to check.sh. Credits: docs/AUDIO-CREDITS.md. Plan: docs/AUDIO-PLAN.md.

## 2026-11-18 — Round 11 (Tom's playtest list)
- Region campaigns: every major region (and the story regions: Wastes, Sky; Docks, Neon, Uptown, Pit) opens by winning a campaign on a 5-7 territory board (skirmish, siege, escort, defend, captain, gate, caches, camps; morale and supply carry over). Board from Menu > Map > Campaign map, the town project board and the war table; walking into a held region offers it. The goal line names the campaign the story needs next. 4 new battlefields (orchard, bog, ash wastes, neon block).
- Cliffs and edges: plateaus, terraces, ledges and cliff border bands are drawn by `CliffPainter`: curved corners and smooth slopes instead of grid steps, painted faces on the front, rock side walls on east/west sides, rims in the ground's own colour (no pale cap ring), snow pieces in winter, stairs sized to the face. Quarry/colonies use grass faces with wooden stairs. Border woods: rounded two-layer forest floor and deeper shade toward the edge; cliff bands get a face inside the band, shade and boulders/shrubs. Mountain trail no longer buries its stairs; farm terrace yard is a soft ruin patch.
- Pup menu only on CHECK/tap with no foe near; pup heels behind. Facing: vertical wins ties (player, pup, villagers, partners); characters without toward/away walks use a bobbing front/back view. Work-walking with hoe/can. Energy revamp (120 bar, fractional costs by skill/tool, sword/dodge/swim cost a little, Exhausted <15%, pass out at 0 → home, or the clinic with a bill in the mines/when hurt). Exit zones: walk anywhere into a road mouth to leave. Ladder: walk in or USE from any neighbouring cell.
- Mines: 26 layout styles + dressings, re-rolled every entry/descent (never the last 5); keeper needs real progress and time on floors 1-3 and fights harder; golem head fixed (fix_keeper_art.py, run by slice_art.py); shaft marker, "Climb down" button. Meadow mine entrance dressed (big timbered portal, rocks, lanterns, rails, ore cart).
- Farm river with stone + wooden bridges and river fish; tiered hills on the farm terrace/knoll, forest, meadow, highlands, orchard_hills, quarry and colonies; beach side bands are palm groves (invisible walls fixed); border bands get undergrowth (WorldGen.dress_band).
- Hero tab (character, stats, gear, set bonuses now live, milestones incl. lifetime crystals). Weapons with their own art keep it on the toolbar. Art Prompts 30 (buildings at 2x detail, 11 prompts / 30 images).

## 2026-11-18 — CONDUCT loop 10 of 10 (final)
- 20-agent audit (/tmp/audit_c10) incl. a progress inventory; bots clean before/after; check (now with story_test + coop_test) + playtest pass. Perf + edge patches; co-op day stamps, other-story buildings, relay host grace (server/server.js, needs redeploy); unwon battles 160 paid kills per run; skill "aka" names keep ranks; tidy build sites; mine pools/keeper/finds; plateau edges; Star Crystal next-step lines; 576 re-cut art files. Prompts 29 (5 prompts / 12 images, 4 optional). Guide 22 = all-in-one guide replacing 12–21; final combined page (guide + progress sheet + every prompt file) and Dreams-Progress-after-10-loops.xlsx.

## 2026-11-18 — CONDUCT loop 10 of 10 (audit fixes, round G)
- Skill renames keep ranks: gen_skill_trees.py writes `"aka"` (earlier names of a node whose effect and ranks didn't change; set `SKILLS_PREV=<old skills.json>` to seed it). `GameState._migrate` keeps those ranks silently and only refunds real effect changes (systems_test checks it). The skill-icon slicer also matches aka names.
- max_energy: the level part is capped at +120 (100 + 3 x min(levels, 40)); late saves get a smaller bar.
- Art: w70/w72/w83 icon rows cut by sprite count (`ICON_SPLIT`, "!name" = no sprite on the sheet, `ICON_STANDIN`); side-sliver rule in art_audit/_drop_edge_bits; sentinel/ash_hound die frames; observatory, wdeco/jdeco slivers. Orla/Benno/Tam/Ivy life rows skipped (`LIFE_SKIP`), they use only their walker-design work pose. Hound pet skips its other-dog fight strips.
- make_ambience.py: `SFX_GAIN` per sound and a new "tell" (enemy move wind-up). check.sh runs story_test.

## 2026-11-18 — CONDUCT loop 9 of 10
- 20-agent audit (/tmp/audit_c9), bots clean before/after, check (now with tools/coop_test.gd) + playtest pass. Perf patch 3 (walking spikes on hollow_heart/highlands/ruins). Co-op clock shift covers jobs/upgrades/haste/drone, save_view restores guest clock, Net.visiting(); enemy _walk_clear feet box, shooter ring; unwon battles cap 80 paid kills; Hot Loads→Fresh Rounds (NODE_RENAMES); reset keeps gift spells; colony plateaus over patches; forest seasons; ♥8 waits for ♥6; creator outfit picker + hair luma tint; 1075 re-cut art (901 icons, w77 rows, benches, pets, hounds/golems). Prompts 28 (2 prompts / 3 images), Guide 21. Tom asked: re-export w72/w73 (cut off).

## 2026-11-18 — CONDUCT loop 8 of 10
- 20-agent audit (/tmp/audit_c8), bots clean before/after, check + playtest pass. Perf patch 2 (bake spikes, redraw cost, soil). Kill pay cap uses e.bossy/named kinds; capped kills drop only quest items; rest_energy() half bar; bait 0.8; blooms 4/day; gun_damage cap + SKILL_VER 8; co-op timer shift, placed sync; farm debris stable; mine barrels/lamps; region invisible walls; story quest timing; heart quests gated at ♥6; Catkins art; 623 re-cut art files (tools/edge_slivers.py new; fix_overlays softens cloud shadow). build_prompt_files keeps every rule. Prompts 27 (1 prompt / 2 images), Guide 20.

## 2026-11-18 — CONDUCT loop 7 of 10
- 20-agent audit (/tmp/audit_c7), bots clean before/after (one bot.gd guard), check + playtest pass. Perf patch (soil draw calls, bake spikes, water shader, spell redraws, co-op sync hash, hidpi off); sell box new-game crash; shared daily energy allowance; kill crystals 12/day/map (bosses/battles/colonies exempt); SKILL_VER 7, pet_dmg cap; bounded flow_dir(max_r); greenhouse plot clear; mine lamps/reachability/size; story/quest fixes; one-face portraits (Dialogue.one_face + slicer _one_face); quest_done_text toasts; 173 re-cut art files. story_test.gd now passes (not in check.sh). Prompts 26 (1 prompt / 2 images), Guide 19.

## 2026-11-18 — CONDUCT loop 6 of 10
- 20-agent audit (/tmp/audit_c6), bots 0/0 before and after, playtest 0 fails. Fix agents A–E by file ownership, G deferred, H slicer (412 art files promoted via a /tmp copy). Map ground baked to chunk textures (BAKE_*, painter twin); food energy one bar a day; Big Coop/Barn/Silo; mine ore ~1/6; Not Today clears statuses; enemy flow-field pathing; SKILL_VER 6 refunds; menu/chest drag scroll; shops absent flag; quest/blocked/collapse sounds. Prompts 25 (2 prompts / 4 images), Guide 18.

## 2026-11-18 — CONDUCT loop 5 of 10
- 20-agent audit (/tmp/audit_c5), 20 bots × 3 days twice (one GameMenu.toggle crash fixed, then 0 errors / 0 fails), playtest 0 fails. Fixes applied by file owner (A bag/saves, B combat/skills/economy, C world/water/mines, D story/text, E UI/interiors/map, F deferred). Prompts 24 (2 prompts / 5 images), Guide 17.

## 2026-11-18 — CONDUCT loop 5 of 10 (audit fixes, round F)
- Economy: raw catch/crops/forage give heal×2 energy (cooked food and potions keep ×8); pond keeps 6 common fish; fishing reach 1+level, 4 xp a catch; trees give 4 wood; 1 berry a bush; ore rocks softer, mining xp up, full cave forage only on your deepest floor; better hoe/can save 15% a tier; bartering xp capped per night; 10 starter turnip seeds; quality bonus uses the saturated price; buy floor = sell price ×1.15 (demand and fence included); fence perk keeps saturation off only for loot.
- Skills: Iron Gut is an unlock (`status_guard`; old combat_2_8 moves to it via NODE_RENAMES/NODE_RENAME_NAME); `GameState.SKILL_CAPS` per-tree caps (Combat hp 140 / energy 60), read by gen_skill_trees.py; Buying row gives buy_discount, Sap & Bees gives regrowth; new unlocks Wide Spout, Tremor, Domino Fall, Tidecall, Lucky Day, Quick Build (effect keys wide_water, timber, tremor, tidecall, jackpot, quick_build). Every level-up gets a note (`GameState._xp_loud` while GameMap.xp toasts).
- Fixes: summoned minions pay nothing; crystal baby broken by a blade comes back (babies_calm waits for ♥); lieutenant beats fire once; departed villagers (`GameState.npc_present`) send no mail/birthdays/board jobs; ready quests turn in first; tool rewards go to the tool list; app background / Save & back to title keep your spot (`GameMap.save_here`); Haste icon reads haste_abs; HackGame stick; meadow boss spawns near you; builds keep locked bag items; sanctuary builds wait for their story flag; cloth-free gangster stations; crew press prints crude bills; moon spire always placed; sky knight win_reverted text; chest_open sound; Seed → Seeds names; mine_test in check.sh.

## 2026-11-18 — CONDUCT loop 4 of 10
- 20-agent audit (/tmp/audit_c4), 20 bots × 3 days: 0 errors, 0 fails; playtest 0 fails. Built: slot bag (scripts/slots.gd, lock/trash/half, tools row, toolbar swap), chest slot grids, room side walls/front lip, fuller homes, beach/lake/docks one water body. Fixes: `_add_under` ranks (ground patch < water < under layer) so water shows over patches, lake dock cells kept in the mask + outlet stream to the border, region rect water reaches the edge and merges with a water border (`_rect_water`), WaterMask keeps 1-wide cells, locked items refuse the sell box, vehicles never trashed/stacked, mana lend cost, burn ticks skip blink/gift, sleep wears shields, decoys without abilities, grudge ring gap, KO mid-battle (`_end(false, false)`), gun cd (gen_stations), resting orchard trees, pen bounds, snow waters, helper damage, warden buff, bot line of sight, barrage stun on bosses, Lull by base_hp, 23 all-ages lines (Keen Edge, Starborn), USE/CHECK from the uncut btn row (`BTN_ROW`), clock 9-slice from panel_parchment2, tuft deco instead of opaque deco tiles, wrapped choice sizing, NPC beats pup tap (`_npc_near`), lieutenant portraits, *_plus helmet sprites, playtest fixes.
- Prompts 23 (5 prompts / 11 images), Guide 16.

## 2026-11-18 — CONDUCT loop 3 of 10
- 20-agent audit (/tmp/audit_c3), 20 bots × 3 days: 0 errors, 0 fails. Fixes: hut exits restored + interior_back check in check.sh, Orla [11,5], under layer sorts above water (offset y), Sal fence cooldown after the sale, lunge waits for stun / none during openings, tools hit foes in front, keepers at floor tier, freed Fennimore leaves (clear_kind), Trickster, wine quests penguin-only, 81 armour recipes (gen_stations: Crystal t4, Moon t5, tempers, Neon Jacket), lens/ink values, seed_back 0.5 + smelt_discount caps, Builds count/take chest materials (Storage.total/take_from_chests), stick inert while paused (dialogue excepted), merkitties at the pool (GEN_ONLY), _set_pic accepts group/name (catship panels), gutter-free interior floors (_floor_cell), barrels3→barrel.
- Prompts 22 (1 prompt / 2 images), Guide 15.

## 2026-11-18 — CONDUCT loop 2 of 10
- 20-agent audit (/tmp/audit_c2, each re-checking loop 1), 20 bots × 3 days: 0 errors, 0 fails. Fixes: Orla beside her counter, Granite off his door, hut exits, spawn checks one row up, Pike/Ostrova count again, farm pond on shared fishing, value-sorted pools, (tier+1)/2 tool power + moon mine_power, deep-floor enemy cap, keeper ramp to floor 10, HUD edge pointer (Mine.pointer_target), xp_gain filler + caps (energy/hp/mana/supply/helper/pet), gift power cooldown, enemy taps beat pup, sword auto-select in first fight, glancing-blow tips, wet+open window, no shields during openings, story text (Doc, crates, arcade, Flame), _play_lines guards, quick stack spares toolbar, rooms fit above indoor HUD, GameMap.under_layer()/to_under() for ground props (z -1 was hidden), rounder WaterMask, w198 icons re-sliced, frozen skill icon order (docs/src/skill-icon-order.json), Sal recruit indoors, unique node names, salvage/fuel cell/buy floor.
- Prompts 21 (4 prompts / 10 images), Guide 14.

## 2026-11-18 — CONDUCT loop 1 of 10
- 20-agent audit (/tmp/audit_c1), 20 bots: 0 errors, 0 fails. Fixes: animal goods quality, bag overflow only into a built chest with room, quality clamp, Sal two-tap fence (quest items safe), Big Jim ore gate, pup menu, fishing pauses in menus + weighted rare fish, chop/yield caps (chop_bonus = chance), ripe sprite, greenhouse border, season warning, fertiliser on ripe, grown-crop counting, gentler early HP (NATIVE_HP 1.5/2.2…), meadow counts, first gangster boss damage, floor-1 keeper tier, burn ticks, helpers follow in fights + strikers/bots draw aggro, battle commanders don't count as story lieutenants, capped bartering buy floor, wash/job caps, one crew per job, sprinkler value, glass at Granite, stable unlock ids + migration refunds, unlocks in all 13 trees, hp/energy nodes from every tree, icons matched by node name, mine redraw only when needed, grotto glints, perf (update check, farm animals, skill_name), saves keep key order and skip mid-door, toolbar pad, colony seeds stable/ferry/beacons/house, Marlene ashore, Sal recruit, knight mercy, all-ages text, sfx throttle, chest sounds, default_spawn offset, exit_check covers colonies/battlefields/Hollow Heart.
- Prompts 20 (8 prompts / 20 images), Guide 13.

## 2026-11-18 (CONDUCT round) — audit, bots, edges audit, skill unlocks, bag and chests, mines
- Two 20-agent audits (general + edges/transitions; reports in /tmp/audit, not in the repo); bots clean apart from navigation stalls.
- Edges: `WaterMask` shader draws whole water bodies and ground patches with curved, foamy, banked edges; dirt/sand paths and region patches blend (`soft_ground`); seamless textures wrap (`tools/make_seamless.py`).
- Farm soil layer was hidden by y-sort (crops invisible): fixed; rounded beds; dark (not blue) wet soil.
- Interiors: props fitted to footprint, small rooms centred, `tools/furnish.py` (282 props), walk-out doors; building front walls enter (`tools/door_check.gd` in check.sh).
- Skill trees: real unlock nodes (blueprints gate stations, spells from other trees, move speed, chop/mine power, damage); unlock nodes framed violet with what-they-give icons.
- Sun Haven bag and chests: 30-kind bag (+12 per backpack, 3 upgrades), overflow to the farm chest, Sort, quick stack to nearby chests, `ChestScreen`, placeable chests (`Storage`, tools/storage_test.gd).
- Mines: ~1.7× bigger floors, ~half the ore, fewer enemies scaled to area, gentle floors 1–4.
- Art in: 16-1..16-7 (lieutenants, HQ/Ward stages, Marisol & Bo, the Marked, gift fx, cyber stations), 17-1 (Catkins, finargles, crystal babies, merkitties, catship, story panels), 17-3 (skill icons for five trees).
- Many audit fixes: battles (supply, cooldowns, safe spawns, loss XP), enemy telegraphs, fishing bait, animals, story beat order, epilogue flags, economy/shop stock, gift cap, two-window save guard, story beat survives scene change.
- Prompts 19 (edges, interiors, last stand-ins; 15 prompts / 43 images, 2–3 per prompt), Prompts 17/18 rebuilt to 3-per-prompt; Guide 12.

## 2026-11-18 — remaining work: battles, story branches, farm life, colonies
- Battles: helpers and enemies path with flow fields (`GameMap.flow_dir`); rally cycles guard posts → follow me → each point; supply buys Upgrade/Fortify/Mend/Barrage with upkeep per unit; the enemy commander masses on one point and warns you; wolves and ash hounds hunt in packs.
- Story: Marlene's beat branches on the intro letter; Sasha's loyalty opens the tower doors quietly; Fennimore can be freed in the Meow Pow Wow; endings list more of your choices. Penguin arc: the great tree waits for the mountain campfire.
- Farm: feed animals hay (scythe weeds, Maple sells it) for goods; petting streaks raise quality; crows eat unguarded crops on big farms (scarecrows, rain stop them); animals shelter at night/rain/winter; shop counters keep hours.
- Mines get themed ores and stone caves for the fire depths; colonies get their own music, ground, critters, weather and season look (`GameState.look_season`).
- Villagers react to gifts with their own lines (data/gift_lines.json); bigger menu/title text; parchment dialogue choices; hero picker scrolls to Next.
- Saves warn when Dreams is open in two windows. Skill trees never waste ranks past a bonus cap.
- Not done: chunked map drawing / water shader, alpha-mask footprints, pup gear overlays (need art), telegraphed brute charge.

## 2026-11-17 (night, round 3) — 20-agent audit, 20-bot playtest, fixes

- Audit reports: /home/claude/audit2 (not in the repo). 20 bots × 3 days: 0 script errors after fixes (only bot navigation stalls at map edges).
- Seasonal sunset/sunrise and real darkness, lamp glow, indoor lamplight, Night darkness option.
- Ambience layer (birds, crickets, frogs, owls, wind, rain, thunder, waves, town, city, hearth, cave), Nature volume; 36 new sfx incl. footsteps; 15 new placeholder area songs + night/festival/winter.
- Hero art re-keyed (Big Jim etc. had see-through holes); hero picker shows names and highlights.
- Combat: home-tier HP scaling, no stun-lock, ranged spacing, area tiers + elites, crit/defence caps, boss guards, food cooldown in fights.
- Economy: forage mushroom ◆10 (Shiitake crop), a third of the forage, slower regrowth, chance-based resource nodes, tighter selling, crates per day.
- Farming: season-end crop death, greenhouse plot, out-of-season planting refused, morning-wet sprinkler soil.
- Collisions: animated props aligned, structures block swimmers, no bog wading, multi-frame strips show one frame, canopy/roof fade.
- Colony art (w326–w329) wired; Hollow Heart rebuilt; Secrets (chests, caches, journal) in every region; boss markers.
- Pup re-sliced and fixed; partners stop flickering. Mines: reachable findables, mining perks, smoother curve.
- Saves: localStorage mirror, save on hide/update, SW cache bypass in CI, phone copy/share/paste, per-slot restore.
- Villagers: everyday talk for all, perk texts fixed, add_friend everywhere, moonwort quest; town greeter accurate.
- Stories: bell and Auk effects real, W/K clue, twins all-ages, evicted shopkeepers gone, President tougher, no grumps for gangsters.
- Battles: turrets expire, boss rout, more strategist XP; skills: 32 empty nodes given effects, Learn above grid.
- Prompts 16/17 rebuilt (received marked), Prompts 18 written; Guide 11.

## 2026-11-17 (later still, 2) — The chrome (cyberpunk), crew redrawn
- gen_stations: `terminal` (book hack), `clinic` (book implant), `robotics` (book robot), gangster arc only, cells [13,24] [15,24] [12,27]. 18 new items. Effects in `GameMap.use_consumable`: scrub (heat), emp (stun + forces Gift open), bot (`scripts/bot.gd`, a timed turret), drone (reusable scout; reads Gift tips; blocks the day's collectors).
- Prompts 15 batch 6 in: twelve crew redrawn (old sheets kept as `*_v1_cheerful.png`); from w303 only Marisol, Bo and custom cards used. Batch 9 (cyber stations, icons, fx) added.
- Open: cyber stations and bots have no art yet; implants do not show on the paper doll.

## 2026-11-17 (later still) — Gifts: ten Marked, boss powers, the Dark Crystal reveal; Nia and Ollie redrawn
- `Gift` (scripts/gift.gd, data/gifts.json from `tools/gen_gifts.py`): a loop of telegraphed moves (ring, spiral, lines, zones, dash, pull, gust, veil, clones, roll) plus one rule for taking damage (window, wet, back, cycle, real, offbeat, range). Attached to any enemy whose data has `gift`.
- `Marked` (scripts/marked.gd): ten gangsters aged 15 to 30, one per district, spawn on entering; yield at 0 hp; recruit (Companion `mk_<id>`, ability `gift:<id>`, cast with hold-B for mana) or send home. Flags `marked_<id>` = crew/free.
- Eleven bosses carry a gift (penguin arc included). Story: President admits the Gifts are splinters of the Dark Crystal; both gangster endings and p5_win refer to it.
- `tools/gift_test.gd` in check.sh. `tools/gift_shot.gd` for screenshots.
- Art: Prompts 15 batch 5: Nia and Ollie gritty sheets in (compact 7-row sheets handled). Marisol and Bo only arrived four-to-an-image, too small to cut; still wanted one per image. Prompts 15 gains batch 7 (the Marked) and batch 8 (Gift effects); Marked use stand-in sprites until then.
- Open: no dedicated Gifts journal page (tips go to the hint log); gift balance is untested by human hands.

## 2026-11-17 (late) — the workshop: tiered stations, vehicles, rocket, the operation; Prompts 14 art in

- **Design:** every station is a building in `data/buildings.json` with `"station": {skill, verb, book}` and four tiers. `scripts/crafting.gd` runs all of them.
  - A tier gives slots (= tier), speed (15% per tier), recipe cap (tier + 1) and a masterwork chance (0/5/10/20%).
  - A tier's gate is `unlock`: `progress` (story), `skill`, `friend`, `quest`. Materials or the ready-made `price` pay for it (`Builds.start(id, buy)`).
  - Nothing is pre-built. The house kitchen works at the tier of the Cooking Pot you own.
- **Stations (both arcs):** workbench, sawmill, furnace, anvil, loom, tannery, kitchen, keg, press, kiln, jeweler, cauldron (magic potions), resonator, garage (vehicles), launchpad (rocket), mill.
- **Gangster arc only (`"arc": "gangsters"`):** print_shop, armory, soda, laundromat, training. `scripts/racket.gd` holds heat, passing bills, forged permits, the wash and sparring.
- **Penguin arc only (`"arc": "penguins"`):** shaper, litter, campfire (stations); pool, burrow, shrine (buildings). `scripts/sanctuary.gd` holds overnight gifts (`run["gifts"]`), the shrine's Meow Pow Wow ranks and daily practice. Litter boxes read `radius` and `stun` from the item.
- **Guns (gangster arc):** weapons with `range` fire from `player._fire()`: one `rounds` a shot, first enemy down the line (`spread` hits everyone close), tracer and dust puff only. No rounds: half-damage club.
- **Hero picker:** a hero with no `card_hero_<id>` art gets a parchment card with its sprite (`title.gd _sprite_card`). The gangster picker dims the backdrop (`_mood`); the gangster arc's day/night tint is cooler and darker (`game_map.gd`).
- **Gritty gangster redesign** is an art job: Prompts 15 batches 4–6 (w295–w302 hero sheets, w303 cards, w213–w218 crew redrawn).
- **Allies and enemies:** `GameMap.allies()` lists who enemies may turn on (the pup; later anything in group `allies` with `take_damage()`). `Enemy.provoke(by)` gives 4 s of aggro; enemies also pick an ally that is much closer than the player. The pup's random bite-back is gone. `tools/ally_test.gd` is in `check.sh`.
- **Pup command strip:** five buttons down the left edge of the touch controls (`TouchControls.PUP_CMDS`): Heel, Attack, Stay, Guard, Recall.
- **Prompts 15 art:** batch 1 (w284–w288) and batch 3 (w292–w294) are sliced in, plus the street icons (w290). Stations use `props/st_<id>_<tier>`; vehicles `props/veh_<id>_{down,up,side}`; Granite and Sel portraits; fx `rocket_flame`, `veh_dust`, `veh_wake`, `masterwork`, `stink_*`, `heart_burst`, `merkitty_*`, `baby_*`. Batch 2 second take is in: gangster stations (w289) and all 28 street icons (w290); the first take is kept as `*_v1_rejected.png`. The UI sheet (heat meter, badges) only exists small inside the all-in-one image and is not used yet. Batch 4 is in: Dad, Pax, June and Rafe redrawn (`characters/man_gang`, `son_gang`, `june_gang`, `rafe_gang` + portraits) via `_grit()`; movement, attack, swim, ride and faces are cut, tool swings reuse their attack frames. Batches 5–6 still to come.
- **Station yard** re-gridded on a 3-cell spacing west of the house path.
- **Data is generated:** `python3 tools/gen_stations.py` rebuilds the station entries, recipe books and goods. Edit that file, not the JSON, for station changes.
- **Jobs:** `run["jobs"][station]` is a list (old single-job saves migrate). Batches of 1 / 5 / max. Keg jobs take days; everything else is ready by morning.
- **Town benches:** `Crafting.run(m, station, title, "town")`; tier from the keeper's hearts, fee per piece. `"smith"` and `"alchemy"` are aliases.
- **Vehicles:** items of type `vehicle`; `player.ride()` / `unride()`; the balloon uses `run["visited"]`.
- **Farm upgrades** (house, coop, barn, shed tier 2+) now cost planks, bricks, nails, beams and tile.
- **Tests in `check.sh`:** `tools/station_check.py` (no dead ends, both arcs) and `tools/station_test.gd` (build, buy, gates, jobs, masterwork, keg, vehicles, potions, heat, wash, training).
- **Prompts 14 art integrated** (w274–w283): 71 icons and six growth stages for 117 crops. Crops in beds are sized by their ripe sprite.
- **Prompts 15** written: station tiers, goods icons, vehicles, rocket, Granite/Sel portraits, gangster stations and UI, penguin sanctuary stations, icons and extras (11 images). Layout in `tools/prompts15_layout.json`.
- Open: wearable art for gangster suits; pack size.

## 2026-11-17 (evening) — 134 growable crops, wired into everything

- **Crops:** all 120 catalogue seeds now grow, for 134 crops in total. Every crop and every piece of produce has a family: veg, herb, berry, fruit, tree, grain, mushroom, flower or magic (`crops.json` / `items.json` "family").
  - Tiers set days and price. Profit per day climbs about 2.5 → 4 → 9 → 18 → 45 from tier 1 to tier 5.
  - Bushes, vines and orchard trees regrow.
  - Strain variants (Cave/Deep Glowcap, Deep Void Pepper, Dawn/Dusk World Bloom) share their parent's art via "art".
- **Orchard trees** rest out of season instead of dying, including in winter.
- **Where seeds come from:**
  - Maple: the season's vegetables, with 4 extras that rotate every 3 days.
  - Tam: orchard trees and berry canes.
  - Old Moss: mushrooms and herbs.
  - Sel: wonder crops, gated by progress.
  - Catkins: crystal crops.
  - Pulling weeds can drop a Wild Seed Packet, which opens into a random in-season seed.
- **Using the produce:**
  - Recipes can ask for a family (`"#veg": 3`) and take the cheapest first. There are 12 new kitchen dishes plus oat flour.
  - The keg brews by family and tier (`GameState.keg_brew`): wines, pickles, herbal tea, ale, broth, mead, wonder elixir.
  - Villagers like whole families (`"#berry"`) as well as specific dishes.
  - The plaza board posts one in-season crop order a day.
  - The Harvest Fair takes any produce and weighs your field log.
  - Four new crop quests: Posy's blueberries, Theo's coffee, Tam's pears, Wren's saffron.
- **Field log:** in the journal (Quests → Field log). It lists every crop by family, with counts, names for what grows this season, and ??? for the rest.
- **Art until Prompts 14 lands:** crops with no art are drawn as a plant (a tree, or a leafy stem) and show the produce icon when ripe.
- **Tests:** `tools/crop_test.gd` is in `check.sh`. It checks every crop has a seed that's sold somewhere, produce, a family and a keg brew, and ripens in season. It also checks that recipes resolve and that family gifts, dormancy, seed packets and the board work.
- **Art Prompts 14:** 2 produce-icon sheets and 8 crop growth sheets. The slicing layout is in `tools/prompts14_layout.json`.

## 2026-11-17 (night) — full audit, 20-bot playtest, fixes 1–10

- Findings and status are in `docs/AUDIT-2026-11-17.md`.
- New harnesses, both in `tools/check.sh`:
  - `tools/interior_reach.gd`: every interior thing can be reached.
  - `tools/exit_check.gd`: every exit and scripted jump lands on open ground, near the way back.
- 20 bots: 0 fails. Playtest 43/43; story, mine, hearts, creator and net tests pass.
- Main changes:
  - Atomic saves with a backup.
  - Host-only shared world in multiplayer.
  - Story follow-ups queue, and boss spawns survive reloads.
  - Rain counts as watering; fertilizer works.
  - Arc-specific heart and event lines.
  - Villager spots are resolved against the live map.
  - Seasonal sheets and portraits are used.
  - Water is culled to the screen.
  - Catkins shop.
  - Chill and Dazed statuses now apply.
- Open: pack size (~205 MB), Granite/Sel portraits, 120 crop-less filler seeds.

## World art batches 1–3 integrated (W1–W10, W22, W23, W9)
- Real **grass↔dirt/sand/stone transitions** (autotiler) on every path; six grass variants.
- **Forest**: forest floor, winding forest path, the great lantern tree (story door), hollow tree, willow, woodcutter's hut, giant log, shrine, berry thicket, deer/fox/rabbit/owl.
- **Lake**: proper water edges, animated water mill, lighthouse beam, reeds, lily pads, ducks, heron, beaver dam, fishing hut.
- **Beach**: sand set, sea, foam line, pier, the wrecked galleon (lootable), beach hut, palms, umbrellas, bonfire, buoys, tide pool, dunes, seagulls and crabs.
- **Mountain**: cliff faces on terraces, cliff stairs, lookout tower, rockslide, cave mouth, animated hot spring, goats and crows; mine entrance in the meadow.
- **Farm**: silo, hay field, wheat, animated cows/sheep/chickens, pig, bales, tractor, cart.
- **Town**: cobbled roads, flagstone square, inn, bakery, clinic, library, chapel, clock tower, bandstand, statue, benches, flower beds, market stalls, pigeons and cats.
- **House**: interiors kit (floral wallpaper, wood floor, carpet, animated fireplace, kitchen, wardrobe, radio, paintings, day/night windows).
- **Crystal meadow**: glowing grass, standing stones, crystal trees and arches, glow pond, the fallen-star crater (animated), moon rabbits and crystal fish.
- **Deep mine**: earth / stone / ice / lava floors and walls by depth, ore nodes, crystal clusters, glowing mushrooms, stalactites, beams, carts, a dead miner with loot.
- **Wildlife** everywhere from the W23 sheet; **painted sky strips** (day/sunset/night/mountains/sea/forest) as parallax backdrops.
- Batches 4-7 (now integrated, see below) (hideout, docks, neon, uptown, wastes, sky islands, moon colony, station, jungle, underground, countryside, animals, weather, travel, world map) are saved in `art/incoming/` and are next.

## The world (opened up)
- **Nine outdoor areas**, all 2 to 4 times bigger than before and connected by
  walk-off exits: **Farm** (32×44, with barn, greenhouse, coop, animals, well, all
  crafting stations) → **Town** south (28×40, four cottages, square, arch, lamps,
  nine villagers) → **Beach** south of town (sand, sea, pier, wreck, shells, surf
  fishing) and **Mountain pass** east of town (terraces, ore rocks, hot spring, golems;
  rocket pad in the penguin arc, smugglers' camp in the gangster arc) → **Moon**
  (penguin arc, from the pad once the meadow is cleared). Farm → **Forest** north
  (winding path, clearing, hidden pond, shrine with offerings, daily forage, wisps at
  night) → **Lake** west (big water, dock, Finn's bait shop, best fishing) ↔ farm.
  Farm → **Meadow** east (36×28) → **Crystal Meadow** (penguins: standing stones,
  crystal blooms, altar that spends Refined Crystals for max hearts, Grumps pressing
  in) or **Outskirts** (gangsters: shack, black market, fence to the city). The mine
  is still off the meadow. The gates east of those are the story doors (Guide #2).
- **Dense detail everywhere**: `WorldGen` scatters tufts, flowers, mushrooms, rocks,
  logs, stumps, berry bushes and tree lines per map (seeded), plus wildlife (birds
  that flush when you approach, butterflies, rabbits), and a **parallax backdrop**
  behind every map (hills, mountains, sea, city, moon) that follows the time of day.
- **World map tab** shows all areas, greyed until visited, with your position.
- Rocks/logs/stumps/bushes/forage work on every map (shared interactions).

## What's in the game now (art batch 2: 29 sheets integrated)
- **Tool-use animations** for all four family members and the dog: hoe, water, axe,
  pickaxe, cast, reel, hold-up, eat, in three directions. Farming, chopping, mining and
  fishing all play them.
- **Dialogue portraits** with moods (6 expressions for the family + dog; villagers,
  crew, rivals, the President, the Light and Dark Crystals).
- **Nine villagers** with real sprites (Barnaby, Greta, Wren, Alder, Finn, Lumi, Theo,
  Hazel, Nico-as-Sal), walking around town with lines per arc.
- **Grumps army**: soldier, archer, corrupted crystal knight, gloom wisp, commander;
  **gangster roster**: cyber, brute, flame, speedster, gambler, enforcer; the
  **President** and the **Dark Crystal** as boss-class enemies (sprites ready, boss
  fights wired for the meadow; later fights wait on Guide #2 B).
- **Gangster-arc heroes**: Dad and Pax get their jacket/hoodie variants and a punch.
- **House interior** with wood floor, rug, wallpaper, window, bed, table, chairs,
  bookshelf, fireplace, kitchen, plant, lamp, pet bed, clock, chest.
- **Crafting stations on the farm**: workbench (recipes), furnace (ore → bars), storage
  chest, keg (brews), beehive (honey), crystal resonator (3 shards → refined crystal),
  sprinkler item.
- **Fishing**: bobber and bite animation, splash, 12 fish from your sheet, better fish
  with fishing level.
- **Mine**: your floor and wall tiles, ore props (copper, iron, gold, crystal, dark),
  ladders, support beams, mushrooms and moss; knights and wisps on deeper floors.
- **Seasons**: spring/summer/fall/winter grass, trees and bushes swap per season (28
  days each); season icon in the clock. **Weather**: rain, snow, petals, leaves,
  fireflies, rolled per day; rain waters crops.
- **Combat effects**: slash, hit spark, poof, sparkle on pickup, level-up burst,
  Meow Pow Wow paw ring on the resonator.
- **UI**: your hotbar frame and slots, season icons, skill icons, pink friendship
  hearts, portraits in the Social tab.
- **Hideout and moon tilesets** are sliced and ready (`art/gen/tiles`, `art/gen/props`);
  no maps use them yet (waiting on story answers).
- **Tom's art is in**: title key art, UI kit (hearts, energy bolt, crystal, buttons),
  ground/water/dock/stone tiles, farmhouse + mailbox + sell box + fences, town
  buildings, barn, windmill, scarecrow, lamps, stall, trees/bushes/rocks, crops with
  growth stages, item icons, enemies (Grump, slime, bat, golem, corrupted shard),
  penguin hero, walk-toward/away frames for the family, dog sit/dig and toward/away.
  Pipeline: `tools/slice_art.py` keys the magenta, slices sheets, scales to 2x
  detail → `art/gen/` (+ `manifest.json`). Re-run after new uploads.
- **Stardew-shaped controls and menus**: 12-slot toolbar (tap, number keys, mouse
  wheel), inventory with backpack grid, skills with XP bars, Social tab with hearts,
  Map tab, Quests, Options. Tap-to-move anywhere in the world (tap a thing to walk
  up and use it; tap an enemy to attack it). Mouse click does the same on desktop,
  where the on-screen pad hides itself. Sword swing arc, enemy hurt flash.
- **Title → New game → choose a path** (Too Two Powerful Penguins / Gangster's Paradise)
  → choose a character → name yourself, your town, your pet → the story begins.
- **Story opening per arc**, with a choice that is remembered and referenced later
  (the Light Crystal's question / what you do with the letter).
- **Your farm**: house (walk in), bed (sleep → next day, crops grow, sell box pays),
  journal, mailbox with story letters on day 1 and day 3, tilled plot, sell box, pond
  with fishing, berry bushes, trees for wood, gates to town and the meadow.
- **Farming**: A on the plot tills; hold seeds (MENU → Items) and A to plant; A again
  to water; harvest when grown. 4 crops with different growth times and prices.
- **Economy**: crystals; everything has a trade value; sell box pays overnight;
  bartering skill improves prices. Shops: general store (seeds, pie), blacksmith
  (iron sword), potions (healing, energy tea).
- **Town**: 5 townspeople (Maple, Gideon, Wren, Mayor Alder, Sal) with lines that
  change by arc, friendship level, and story progress. Talking daily and gifts
  raise friendship. Town hall. Fountain.
- **Combat**: east meadow with Grumps (penguin arc) / the President's muscle
  (gangster arc). Swing with A, run with B. Beat 5 → the boss appears. Beating the
  boss pays off differently per arc (+2 hearts and the first spark of the Meow Pow
  Wow / 60 crystals and Sal joins your crew).
- **Mine**: break rocks for stone, copper, iron, crystal shards; slimes and bats;
  ladders to deeper, harder, richer floors.
- **Day/night**: clock, energy, evening tint, pass out at 2am. HP hearts, energy bar.
- **Skills**: combat, farming, mining, bartering, building, foraging, fishing with
  XP and levels (MENU → Skills).
- **Pet**: follows you, occasionally digs something up.
- **Living world**: cloud shadows, birds, animated water, rain on the gangster
  arc's first day, dust when running, movement eases in/out.
- **Music and SFX**: placeholder chiptune loops per area (title, farm, town, meadow,
  mine, boss, house, rain) and sound effects, generated by `tools/make_audio.py`.
  **Real tracks so far:** `title` ("Dreams", made by Tom in ACE Music; original MP3 in
  `audio/incoming/`); `arc_gangsters` (Tom's "Gangster Arc", plays from the moment the
  gangster path is chosen on the new-game screens, back to `title` on Back); `arc_penguins`
  (same, for the penguin path; the upload was named "Gangster_Arc_1"). `make_audio.py` skips anything in `REAL_TRACKS`, so regenerating
  placeholders won't overwrite it.
  Real tracks drop in with the same file names.
- **Controls**: D-pad (slide thumb for 8 directions), **A** = interact/attack,
  **B** = hold to run or tap to toggle run, **MENU** = items/quests/skills/options.
  Keyboard: arrows/WASD, Z/Space/Enter, X/Shift, Esc/M.
- Saves to `user://` automatically on sleep, scene change, and from the MENU.

## Testing
- `tools/check.sh`: import + smoke test of every scene (runs before every push and in CI)
- `tools/playtest.gd`: scripted playthrough (intro, farming, touch controls, house,
  sleep, town, shop, combat, boss, mine, both arcs) with screenshots; 30+ checks

## Next
- Tom answers Guide #1 → real town layout, NPC roster, crops, the penguins' look,
  the Meow Pow Wow ability list, the gangster regions, music direction
- Slice and wire in art from `art/incoming/` as it arrives

## Known gaps
- Beach shoreline and lake edges use the 9-piece pond set; W3/W5 prompts give proper edges
- Villagers still only stand/walk-toward in town
- Villagers only have front pose + walk-toward (ART-PROMPTS-03 #1); they face front when walking sideways
- Big Jim and the female penguin still placeholders; shop interiors still flat
- Water edges: only the 9-piece pond set; rivers/beaches need #11
- Hideout town, districts and moon maps not built (story first)
- Woman's last attack frame is missing part of the pink magic crescent
- Typing names on the web build uses the browser's keyboard; report any trouble
- Multiplayer not started (see Guide #1, G)


## World art batches 4-7 integrated (regions pass)

- `tools/slice_world.py` now slices w11 wastes, w12 sky islands, w13 moon colony, w14 station, w15 jungle, w16 hideout, w17 docks, w18 neon, w19 uptown, w20 underground, w21 countryside, w24 animals, w25 weather, w26 travel, w27 world map.
- New data-driven region system: `scripts/region.gd` + `data/regions.json`. Each region declares size, ground/path tiles, layers, water, props (static or animated), generated scatter/critters, enemies, exits, intro, and things (`note`, `shop`, `loot`, `heal`, `boss`, `door`, `mrock`). Scenes are one-liners (`scenes/<id>.tscn` with `region_id`).
- New areas: **Penguins**: Grump Wastes (meadow gate, Commander boss) → sky islands (great tree stair in the forest, Crystal Knight) → station (moon teleporter, needs 3 Refined Crystals) → alien jungle. Moon has a colony now (dome, dish, rover, alien stall shop, moon cow, spire). **Gangsters**: Outskirts gate → Hideout town (diner shop, motel) → Docks (fish market, dock boss) → Neon (noodles, ramen, Flame boss, manhole → Underground fight pit) → Uptown (President's tower, Enforcer boss). Hideout → Countryside highway (checkpoint, stone head).
- Weather: painted overlay strips (`fx/ov_*`) replace particles for rain/snow/petals/leaves/fireflies/fog/dust/sandstorm/ash/meteors/storm/blizzard; regions can force one (`"weather"`).
- Map tab shows the painted world map (`ui/world_map`) with pins for visited areas.
- Farm animals: `scripts/farm_animal.gd` uses the full idle/walk/eat sets (cows, sheep, goat, chickens, rooster, duck, pig); they wander in pens and can be petted once a day (A).
- Not yet wired: w26 travel pieces beyond pins (signposts/gates/warp pad/balloon/ferry/drawbridge), aurora, baby animals, w21 river_road. Next: ART-PROMPTS-03.

## Open-world pass (after Tom's "constricted / buggy" feedback)

- **Map size & borders**: `GameMap.pad` + `border` give every outdoor map an organic edge (tree mass, cliff band, water) instead of a fence; `extend(dx, dy)` opens scripted maps to the right/bottom and moves their exits. Regions in `data/regions.json` have `pad`/`border` and were enlarged. `tools/overview.gd` renders whole-map overviews for layout review (`-- /out farm town ...`).
- **Farm rebuilt** (72×60 + pad): house, mailbox, shipping bin, plans board, pond, NE terrace with a ledge and stairs; field overrun with weeds/rocks/logs/stumps/trees (seeded; cleared cells persist in `run["cleared"]`). Any open grass tills. Buildings/stations are built from the plans board (`FARM.BUILDS`, saved in `run["builds"]`); animals appear only after coop/barn. House starts with bed + dresser.
- **Controls**: Stardew keys (WASD/arrows, C/left-click tool, X/right-click check, Shift run, E/Esc menu, I/M/F tabs, Tab/wheel cycle, 1-0 slots). Mobile: floating joystick (push far = run), tap-to-move/interact, USE + CHECK + MENU buttons.
- **Combat**: instant swing with cooldown, wider hitbox, aim assist, buffered presses, hit-stop, screen shake, damage numbers, white hit flash (shader), real knockback that slides along walls, stagger, enemies wind up before striking (no more touch damage), separation.
- **Collision**: `prop()` now blocks its footprint by default (`solid` param).
- **Interiors**: `scenes/interior.tscn` + `data/interiors.json`; every town building (store, smith, potions, hall, inn, bakery, clinic, library, chapel, two cottages) has a walk-in interior with fittings, an NPC and a counter. Shop logic moved to `scripts/shops.gd`.
- **Cinematics**: trees sway when chopped and fall over; rocks crumble; items pop out and fly to the player (`wobble`, `fell_tree`, `break_rock`, `pop_items`).
- **Art fixes**: dark-magenta backdrop shade is now keyed everywhere (purple blobs under trees gone); wildlife/animal rows sliced by connected components (ghost frames gone); weather overlays soft-keyed.
- **Mountain** redone: three terraces, two long ledges with stairs, sparse rocks.
- Known gaps: cliff art is a placeholder strip until ART-PROMPTS-04 batch 1; NPC schedules; beach/lake/forest layouts still the older hand layouts (opened with extend + borders, not redesigned).

## ART-PROMPTS-04 batches 1-6 integrated
- W28/29 cliff sets: `GameMap.draw_plateau()` (raised blocks with real faces + stairs) used by the farm terrace, mountain ledges and cliff borders. W30 water: new animated fill, bridges/docks/lilies/reeds sliced (47-piece shore sets saved raw, not mapped). W31: path/ground decals in `draw_ground` and `WorldGen.draw_ground_detail`.
- W32-35 cinematics: painted tree fall (`_fell_tree_fx`), trunk break, rock/ore shatter, dust/chips, item pop icons, bobber cast/idle/bite, fish jump, reel splash, alert, sprout pop, scarecrow flap, crow land/takeoff, sprinkler spray. Swim/player-action rows kept as `fx/ref_*` (generic hero, not our characters).
- W36 emotes (`GameMap.emote`), W39 portraits for all townsfolk (+ new NPCs Bram/Posy/Juniper), W40-43 interiors (new fittings in `data/interiors.json`, wall kits with mid variants + window pieces).
- W44-46 UI: touch joystick/buttons art, icons, skill icons; W47 overlays (`ov2_*`), aurora2, cloud shadows on clear days.
- W48 big/mid trees in borders (seasonal), W49 landmarks placed per map, W50 farm buildings for the plans board (+ fish pond, shed, stable, mill), W51 pet dog strips, babies, horses (mount system not built yet).
- Slicer: `load_hue`, `row_sprites` (component rows with equal-cell fallback), `_boxed` helpers; beige panels keyed for W51.

## 2026-11-16 (later) — Prompts-07 batches 3–4, tool tiers, async fix
- Saved w100–w107 (tool anim layers, 8 tiers × 16 frames each), w108/w110/w111 (hair sets A–C), w112/w113 (hats A–B), w109 (horse/donkey/llama + rider + saddle), composites `w100-107_composite_small.png`, `w108-115_composite_small.png` (swim sheet only in composite).
- `tools/slice_world.py`: `_rows16` generic 8-row slicer → `art/gen/toolanim/<tool>_<tier>` (16f), `hair/<style>`, `hats/<hat>`, `mounts/<name>` (17f), plus per-tier tool icons in `items/` (`axe_copper`, `sword_moon`, …) and hat icons.
- Tool tiers: `GameState.TOOL_TIERS` wood→copper→iron→steel→silver→gold→crystal→moon, `run["tool_tier"]`, `tool_tier/tool_power/upgrade_tool`. Gideon's counter has "Upgrade a tool" (bars + crystals). Axe/pickaxe hit harder per tier, sword adds damage, toolbar/inventory icon and name follow the tier. `moon_shard` item (moon crystal rocks, 35%).
- Fixed Godot "called async function without await" in `try_interact`: `interact()` is sync again — `tell(lines)` fires dialogue, `later(callable)` starts coroutines (shops, crafting, alien stall, teleporter line).
- Playtest: run/joystick/tap tests made robust (max speed over window, fresh runway, re-tap after dialogue fade); tool-upgrade test added. 0 failures.
- Not yet: hair/hats/mounts/tool-anim layers drawn on the body (creator + paper-doll still pending; sheets are sliced and in the manifest). Swim needs a full-size sheet.
- Added `docs/guides/GUIDE-03.md` and `docs/ART-PROMPTS-08.md` (+ `art-prompts-08.html`): full-body costume sheets (w120–123), base actions/swim/riding (w124–126), creator UI + portraits (w127–129).

## 2026-11-16 (evening) — play-feedback pass 1
- Controls: Stardew PC defaults exactly (WASD/arrows, C tool, X action, Shift run, E/Esc menu, F journal, M map, Y emote, Tab toolbar, 1-0-=), rebindable in Options → Key bindings (saved under "keys"). Real mouse: left click = tool toward cursor, right click = check; emulated events are ignored on both sides (`emulate_touch_from_mouse` off) so desktop and phone never double-fire.
- Performance: maps no longer redraw every frame. Water, sea, waterfall and lava draw on `GameMap.AnimLayer` (`_anim_layer.jobs`); everything else draws once.
- Collisions: trees/rocks/bushes/crystals block only their base cell (`prop()` for "nature"/"props"); buildings keep their body. `tools/reach_test.gd` flood-fills every map from spawn and asserts exits/doors reachable.
- Paths: `draw_ground` widens 1-wide strips to 2 (`widen_path`), paints plain fill (cobble_a / sand_fill / dirt fill 7-11) under blob edges, decals only inside. Tall-grass and flower patches thinned; crystal-meadow glow turf is a noise blob.
- Sizes: `CharacterLibrary.make_sprite` normalises everyone to villager height (hero 26 px, villagers 24, penguin 14, dog 15). Pet is Tom's original pup again (W64 pup's 2-frame run "flew").
- Vitals: health on a 100 scale (hearts = 20 HP, partial fill), enemy dmg ×12, defense ×3, energy costs per task × tool tier (`GameState.ENERGY_COST`, `spend_for`), mana + `Spells` (Spark, Glow, Haste, Rain Call, Growth, Crystal Shield, Warp Home) from the Magic tree. 2am → carried home, 5% crystals; health 0 → clinic, 10%; energy 0 → carried home.
- Skills: Sun Haven-style trees in `data/skills.json` (8 skills × ~12 ranked nodes, tiers gated by points spent, branches via `requires`); `GameState.node_rank/bonus/buy_node`; menu Skills tab shows the tree with buy buttons and reset. Old level-gated perks are `data/skills_old.json`.
- Signposts show "→ town" when you walk up and can be read; no painted labels. Mountain cave is a second mine entrance (returns you where you came from).
- Still to do from Tom's list: town ×10 with big houses, NPC routines/friendship perks/quest lists, lake building purposes, more regions, bigger beach, creator fixes, squirrel anim.
- Town rebuilt (scripts/town.gd): 84×96, cobbled avenues, flagstone plaza + fountain, river with two bridges, districts; buildings at full 2x art scale via `GameMap.building()` (footprint blocked, door cell set). New interiors: mansion, school, cottage_c, hazel_house, stable, lodge (Rook's shop), bank (stub). Spawn points from farm/beach/mountain updated.
- Villagers: `Npc` routines (npcs.json "routine": [[hour, place]…], places = town SPOTS or indoor words), rain/chapel-day rules, interiors show the villager only when the routine puts them there. Friendship: 25 pts/heart, gifts by likes/dislikes (`GameState.gift_value`), heart perks in npcs.json "perks" with hooks: Maple discounts, Gideon upgrade discounts, Wren potion power, Theo XP, Hazel waters/harvests, Posy bread, Juniper clinic fee, Alder sell bonus. New gift/economy items (pelt, meat, flour, egg, milk, cheese, wine, candy, book…).
- Quest conditions now accept season / friend / arc.

## 2026-11-16 (night) — Prompts-08 batches 1–2 in, paper doll live
- Sliced: w120–w123 costume bodies (armor ×8, outfits ×8, walk + action rows), w124 base actions, w125 swim, w126 riding, w127 creator UI pieces (`ui_creator/*`), w128/w129 hero portraits + hair/hat/face/eye overlays (`portraits/hero_*`, `portraits/hair|hats|face|eyes`), w130 eight new villager sprites (`characters/npc_marlowe|orla|benno|ivy|tam|old_moss|granite|sel`), w131 their portraits. w56 body bases sliced (`body/<skin>_<build>`, `body/act_*`, `faces/`) with per-frame anchors; hair/hats re-cut.
- `PaperDoll` (scripts/paper_doll.gd): body sheet = equipped costume (`items.json "costume"`) else bare base; action row mapping (`ACT`); hair + hat layers pinned to head anchors; `Player` builds the doll when `run["look"]` has a body (`refresh_doll()` after equipping). `Creator` (scripts/creator.gd) on the title screen and at the dresser (house). Outfit items + workbench recipes added.
- Six new regions (data/regions.json): orchard_hills, highlands, ruins, quarry, marsh, riverlands with exits from forest/mountain/meadow/lake/beach; region.gd: noise water bodies (`water_blobs`), fishing (`fish_at` now in GameMap), forage spots, villagers (`npcs`), `_talk_npc` with gifts/quests. Beach 64×36 with a wandering tide line, cove, two piers, exits to marsh/quarry.
- Weather: `GameState.weather_for(day)` seeded roll with seasonal odds (`WEATHER_ODDS`), fronts linger, forecast toast at waking, HUD icon; effects: wet days water crops + villagers stay in + fish bite sooner, heat raises energy cost, snow slows.
- Vitals: hp/energy/mana numbers on the HUD; tonics (`grow`) and quest rewards (`max_hp` etc.) raise maxima permanently; energy costs retuned (fractional).
- Trees fall + regrow (6 days / 2 with Old Growth); town scenery can't be harvested (`resources_here`).
- Still open: swim/ride gameplay (sheets sliced, no mechanics yet), creator UI art not applied (pieces sliced), portraits in dialogue for the hero, Batches 3–5 art.
- Prompts-08 batches 3–5 sliced: region sheets w132–w137 → `tiles/rg_<region>_N` (ground fills), `rdeco_<region>_N`, `redge_<region>_N` (edge tiles, not yet role-mapped), `props/r_<region>_NN` (connected components, row-major; largest 3 placed as landmarks, small ones scattered via `region_props`); w138–w142 → `props/plaza_NN`, `props/dock_NN`, `props/stable_NN`, `fx/wx_NN`, `ui/hud2_NN` (numbered, to be hand-mapped); w143 → named item icons (`ITEMS_C`; telescope/lantern unmapped); w144/w145 → `enemies/<bog_hag|mud_slime|quarry_golem|rock_crab|hill_wolf|ice_wisp|ruin_guardian|river_serpent|marsh_witch|golem_king|ruin_warden>` with stats/drops in enemies.json and spawns + boss things in regions.json. Region ground sets drawn as noise drifts over grass (`ground_set`/`deco_set`).
- To do: map numbered plaza/dock/stable/weather/HUD pieces to names and use them (town plaza stalls/benches/lamps, bridges on the town river, stable interior, weather overlays, new HUD bars); role-map region edge tiles into blob sets; swim/ride mechanics; creator UI skin.

## 2026-11-16 (late) — Prompts-09 batches 1–5 in; swim + ride
- Costumes: `_life` (sit/sleep/faint/carry/pet/wave/dance/eat/drink), `_water` (swim side/down/up, float, dive, climb), `_ride` (horse) rows for all 16 costumes; PaperDoll maps them (`LIFE`, `WATER`, `RIDE`), layers follow facing.
- Swimming: water cells are walkable for the player (`rect_blocked_player`/`can_swim_cell`): shallows (land within 3 cells) always, deep water with the fishing tree's Swimmer node; 0.55× speed, 1 energy / 2 s, no tools; splash on entry/exit.
- Riding: Benno's stable (interior "stable") sells Clover (◆2000, ◆1000 at 2 hearts); Ride → `player.mount()`; 1.5×/1.8× speed; A with nothing in front dismounts; `run["flags"]["mounted"]` persists.
- Villagers: life poses for all 24 (`characters/npc_<id>/work|sit|talk|…`), seasonal outfit walk sets (`characters/npc_<id>_<season>`), seasonal portraits (`portraits/npc_<id>_<outfit>`). Not yet switched on by season/routine.
- Region edge sets w162–167 → blob sets `bog`, `terrace`, `track`, `snowpatch`, `ruinfloor`, `river` (47 roles + 42 fills + 36 decals each); `draw_water` accepts shore "bog"/"river"; regions.json `feature_blobs` draws terrace/snow/track/ruin floor as noise blobs.
- Interiors w168–w173 → `furniture/int_*_NN` (numbered) + named shop counters; festivals → `props/fest_ss_NN`, `fest_fw_NN`; animals → `animals/goat|goat_kid|sheep|lamb|llama|llama_cria|donkey|foal`; pets → `animals/dog_*|cat_*` (choosable in the creator, `look["pet"]`); stations → `stations/<name>_<tier>` 4-frame; crops → `crops/<crop>_<stage>` with 12 new crops + seeds in data (farm draws per-stage sprites).
- Not yet: interiors for the new buildings assembled from the kits; festival events; station animations on the farm; seasonal villager outfits switching; title/menu/boss-card art (batch 6).

## 2026-11-16 (night) — Prompts-09 batch 6 in; everything from 07–09 wired
- Title: `ui/title_keyart` background + `wordmark_glow`; wooden button skin (`Hud.skin_buttons`, 9-slice `btn2_wood`) on title, creator, pause menu; menu tabs use `tab_*` icons.
- HUD: `heart2_*` hearts, painted energy tube (`ebar_empty/green/amber/red`), horizontal mana bar (`bar_h_*`), `season2_*` and `wx_*` icons in the clock box.
- Dialogue portraits: hero → `portraits/hero_<costume>` by equipped costume, else `hero_<body>`. Boss intro cards (`ui/card_<boss>`) slide in on every boss spawn (`GameMap.boss_card`).
- Plaza rebuilt from the plaza sheet: coloured stalls (closed after 6 pm), `fountain2` (animated, was never drawn before), tall lamps, three bench styles, planters, bunting, hedge rows/arch, flower beds, founder/horse/crystal statues, `gate2`; river bridges are single wide `bridge3_ew_a` / `foot3_ew_a` sprites.
- Dock + stable sheets named (`bridge3_*`, `foot3_*`, `board3_*`, `rowboat2_*`, `buoy2_*`, `boathouse`, `stall_*`, `trough2`, `saddle_*`, `paddock_*`) and horse coats → `animals/horse_<bay|grey|black|palomino>` idle/walk/run/eat, `donkey_b`, `llama_b`, `foal_b`.
- Horse: Benno sells a coat of your choice; after dismount the horse is drawn where you left it (`flags.horse_at`), A to remount.
- Interiors assembled from the five kits (floor/wall tiles `fl_parquet/marble/plank/dirt/cobble/flour/round_stone/hut_plank/moss_plank/grey_plank/quarry/camp`, walls `wl_panel/marble/chalk/timber/log/mill/curve/hut/reed/fish/quarry/tent`): mansion (six mayor portraits, fireplace anim), bank (Ivy: deposit/withdraw, 1%/day interest, 2% at 6 hearts; `run["bank"]`), school (four kids, chalkboard, frog jar), stable (stalls, animated trough), lodge, water mill (animated millstones, Orla's counter), lighthouse (lamp mechanism anim, Marlowe), quarry office (Granite, coffee pot anim), Sel's camp (crystal cage anim, rune rubbings), Tam's hut, Old Moss's hut (bubbling pot), river hut. Region `idoor` things open them.
- New shop counters: orla, marlowe, tam, old_moss, granite, sel (Shops.stock).
- Farm stations: workbench/furnace draw `stations/bench_<tier>` / `forge_<tier>` animations by unlocked tier; keg → cider press, beehive → honey extractor.
- Villagers: seasonal walk sets switch by season (`npc_<id>_<season>`, `_festival` on festival days); life poses when standing still (work at shop fronts, fish by the river, sit/talk/wave on the plaza, umbrella in rain, shiver in snow).
- Festivals (day 14 of each season, town plaza, decor from `fest_ss_*`/`fest_fw_*`): Egg Festival (hunt 12 eggs, ◆200), Lantern Festival (max mana +5), Harvest Fair (enter your best crop, ribbons ◆50/150/300), Star Festival (gift + everyone +10 friendship). Morning toast and plaza toast on the day.
- Weather on the ground (wx sheet): puddles (animated) on wet days, storm puddles, snowdrifts in winter, winter grass tufts; sky: rainbow the morning after rain, god rays sunny mornings, wind streaks, lightning flashes in storms.
- `GameMap.anim_prop()` shared (was duplicated in town/lake).
- Playtest + reach test pass; overview of town checked.
- Still open: lake docks from `board3_*`/`boathouse` (lake still uses old dock cells), stable_* paddock pieces on the farm stable, menu_ pieces with baked text not used (badges/crests used), audio pass.

## 2026-11-17 — Tom's play-test round (controls, water offset, villagers, story, systems, pup)
- Root cause fixed: the animated water layer was positioned before `pad` was set, so every river/pond/lake/sea was drawn 7 cells off its collision (trees "in" ponds, walking into the sea, blocked docks, floating bridges). `_anim_layer.position = offset()` now set after `build()`.
- Mouse: left click on a door/person/thing walks over and uses it, otherwise swings the tool toward the cursor and keeps swinging while held; aim any of the 8 neighbouring tiles with a green/red highlight; dialogue advances on click; menu buttons fire on press.
- Title: portrait crop of the key art + glowing wordmark (proper portrait art requested in Prompts 10).
- World: cliff borders drawn as rock plateaus (were floor-looking invisible walls); coherent ground patches per region (blob sets) instead of per-cell tile lottery; magenta residue scrubbed from all tiles, blob fills de-guttered; soft-rim paths; mountain ledges have rock faces + dirt ramps and one continuous switchback path; town buildings scaled up with a lane to every door and props that fit each owner; river uses the river set; beach/lake/marsh/riverlands doors reachable; wildlife at true scale; cloud shadows/aurora feathered; overgrown farm start; seasonal dead tree.
- Interaction: ground forage you can pick (respawns daily), fruit trees to shake by season, meadow mine door reachable, eat anywhere with +N readouts, penguin creator (feathers/scarf/hat/pet), shorter i-frames and knockback.
- Villagers: BFS pathing between spots, staggered schedules, activity poses, pair chats with bubbles, home/work interiors with dynamic occupancy, region folk no longer appear in town.
- Story: side quests spoken in each villager's voice with face-to-face turn-in (`data/quest_lines.json`, `Quests.talk`); scripted villager scenes with relationships (`data/events.json`, `Events.tick`) that leave journal hints; community board with 3 daily jobs (`GameState.board_today`); morning "Next:" guidance.
- Systems: gathering tiers (ore/tree need tool tier + skill, with a message), economy (season demand, saturation, tiered buy prices), crop seasons/regrow/growth rates, forage respawn by rarity, enemy density by progress tier, Sorcery tree rebuilt (25 nodes, Light/Dream/Crystal paths, 13 spells).
- Pup: `scripts/pet.gd`, own tree (17 nodes), commands heel/attack/guard/stay/recall (Pup tab), bites, takes hits, limps home at 0 hp, packs/collars/boots/treats (workbench + smithy recipes), dig/fetch/tracker/rescue/aura, training quests from Benno and Rook.
- Tools: `tools/ui_test.gd` (menu/dialogue/door clicks), `tools/walls.gd` (invisible-wall audit), overview `OV_BLOCKED=1` / `OV_FOCUS=x,y`.
- Art requested: `docs/ART-PROMPTS-10.md` (portrait key art, clean path sets, penguin poses + wearables, pup gear/fight poses, fruit trees, two-row cliff faces, region walls, Sorcery/Pup/buff/bubble icons, boss cards).

## 2026-11-17 (late) — crafting, buildings, companions, Prompts 10, multiplayer
- Prompts 10 batches 1–6 all sliced (`tools/slice_world.py` w184–w200) and wired: portrait title key art, clean cobble path set (dirt/sand keep soft-rim paths; the dirt sheet's roles were fused), penguin poses + wearables, pup gear/fight poses, fruit trees by season, two-row cliff faces + ramps, region walls, Sorcery/Pup/buff/bubble icons, boss cards + portraits.
- Timed crafting at stations (game-minute jobs per tier), tool upgrades take hours at Gideon's; tiered buildings with Town Hall permits and overnight construction (`data/buildings.json`, `scripts/builds.gd`).
- Companions (`scripts/companion.gd`, `data/companions.json`): one active partner + pup, partner-choice scene day 3 (penguin arc always offers the other penguin), hold-B abilities, Mer the mercat on mine floor 5 (swim/dive only with her), Party tab, bitter companions leave after day 20.
- Multiplayer (web, up to 8): `server/server.js` Node WebSocket relay (room codes), `scripts/net.gd` autoload `NetSvc` + static facade `Net` (`scripts/net_api.gd`), host-authoritative world sync (`WORLD_KEYS`, 10 Hz state), remote players drawn as `scripts/puppet.gd`, guest actions (farm tile, flags, sellbox, build, sleep) relayed to host. Title → "Play together" (host / join code). `tools/net_test.gd` two-process test passes: connect, puppets both ways, world sync, guest farm action reaches host. Relay URL is set in `net.gd` (`RELAY_URL`); deploy `server/` to any ~$4 VPS (`PORT=8787 node server.js`).
- Fixes: hero drawn in base body after appearance step (default outfit), buildings enterable by clicking anywhere on them, `GameState.look_d()` guards a null look.
- Still open: relay not yet deployed (localhost only); gangster-shop decisions and bell ending are data-only (companions.json "decisions"); audit pass next.

## 2026-11-16 (late night) — audit round: tiers, mine, combat, creator
- Audit: art refs vs manifest (only `fx("dust")` wrong → `dust_puff`), data cross-refs clean, all 25 NPCs have real home/work interiors; routines got mid-day home stints; region prop footprints clamped to the art (invisible walls); walls tool counts animated props.
- Unified tiers `data/tiers.json` + `GameState.tier/tier_scale/enemy_tier/player_tier/mine_tier`; enemies.json gained `tier/abilities/status`; `Enemy.setup(kind, tier_override)`; abilities lunge/enrage/ranged (`Enemy.Shot`)/shield/summon/stomp/blink/regen; armour, kb_resist, anti-kite knockback decay + counter-lunge; player statuses (`GameState.status_*`, HUD icons); spells pierce half armour (`hit(..., true)`); xp/loot scale by tier.
- Mine: hidden shaft, `mine_tried` progress, keeper (`_summon_guardian`, `is_guardian`), `_open_way`, lift (`mine_deepest`), tier ore/enemy pools. `tools/mine_test.gd`.
- Title: `custom` playable ("Build your own") in playable.json/arcs.json; precreated heroes skip the look step and never use the doll; `sprite_for_playable(id, arc)`; `_next_btn`. `tools/creator_test.gd`.
- Docs: `docs/guides/GUIDE-04.md`, `docs/ART-PROMPTS-11.md` + `art-prompts-11.html` (6 images per batch; new heroes ×6 + gang versions, 12 recruitable gangsters, portraits/roster/shops/status icons, deep-mine tiers + keepers, ability fx + deep enemies).
- Open: gangster chapters 2–5 + decisions, new heroes/gangsters once art lands, relay deploy, audio, Steam export.

## 2026-11-16 (night) — Writing round 1
- Main story data-driven: `data/story.json` + `scripts/story.gd` (triggers: scene/area, talk, quest_done, sleep; choices with branches/gates/effects_by_choice; effects incl. spawn story bosses, endings). Hooks: `GameMap._process` (Story.tick), town/interior/region/lake talk flows, Light Crystal, moon spire, uptown tower doors (`story` field on a region note), `House` morning. `GameState._cond_ok` gained flags/not_flags/decision/kills/companion/known/mine_floor/crystals/hearts_total/chapter/crops.
- Both arcs have five chapters with real finales (Dark Crystal on the moon: revert/shatter; the President in the tower: free/take) and epilogues; decisions: tell_town, locket, knight_mercy, bell, letter, sell_letter, shop_1..3, ending. Bitter companions (`bitter_left`) stand with the Dark Crystal; bell_rung halves it; Knight's Shard +1 damage.
- Crew: `data/crew.json` + `scripts/crew.gd` — 12 recruits, placed by `Crew.place` (before: districts; after: hideout), loyalty scenes every 3 days at the hideout (`Crew.talk`), perks via `Crew.perk_level` (sell bonus, sword, defence, status half, run speed, hideout heal, Halo rides). Placeholder thug sprites until Prompts 11 Batch 3.
- Hearts: `data/hearts.json` (written by `tools/write_hearts.py`) + `scripts/hearts.gd` — 25 villagers × ♥2/4/6/8/10 scenes, ♥6 personal quest promotion, daily lines after milestones, ♥10 "fall" lines (journal hints).
- Placeholder "(Tom: …)" notes stripped from all player-facing text.
- Harnesses: `tools/story_test.gd` (50 beats both arcs), `tools/hearts_test.gd` (125 milestones). Both green.

## 2026-11-16 — Prompts 11 batches 1–2: six new heroes
- `tools/slice_world.py` w201–w206 (`_hero_sheet`: 16-col grid by components, HERO_ROWS map, portraits + 8 expressions) and w207–w212 (`_gang_sheet`: per-sheet GANG_ROWS maps, stray-cell filter). Characters `june/rafe/nia/ollie/marisol/bo` (+`_gang`) in `CharacterLibrary.GEN_ONLY` (HERO2_ANIMS) with new aliases (walk_down/up, run_down/up, idle_down/up, attack_down/up, hurt).
- playable.json + arcs.json: the six are selectable in both arcs; gang versions used automatically in Gangster Paradise; gang portraits fall back to the farm portraits.

## 2026-11-16 — Prompts 11 fully integrated (batches 1–6)
- Batch 3: `_crew_sheet` (w213–w218): 12 gangsters → `characters/<id>` (idle/walk 3 dirs, attack 3 dirs, hurt, down, join, special, loiter, bubble, sit, sleep, cheer, laugh, views), `portraits/<id>` (neutral/happy/sly/angry/worried), `ui/crew_badge_*`, `ui/crew_sign_*`; crew.json sprites point at them.
- Batch 4: w219 hero portraits (6 expressions + gang neutral), w220 gangster portraits (6 rows), w221 roster UI (`crew_panel/slot/card`, `rank_1..5`, `loyalty_0..4`, badges, `crew_joined/left`), w222 gang shops (`buildings/gang_shop_<id>[_closed]`, `ui/gang_sign_<id>`; town swaps bakery/cottage/clinic on shop_1/2/3), w223 status/tier/telegraph/keeper icons (tiers.json icons → `status_*`; Enemy draws `tier_pip_N`, `tele_*`, `keeper_crest_N`, `guardian_crown`), w224 hero select cards (`card_hero_<pid>[_gang]`, title shows a 4-column card grid), creator random/tabs/swatches sliced (not yet used by Creator).
- Batch 5: `_mine_set` (w225–w228): per tier `tiles/mine_<t>_fill_N`, `wall_N` (2 tall), `walltop_N`, `wallend_N`; `props/mine_<t>_rock_N / ore_a_N / ore_b_N / lamp_N / stalag_N / cart / skeleton / crystal / decal_N / bigrock_N`; `props/heart_crystal` strip. Mine `_tier_set()` draws them for tiers 2–5 (deep/crystal/dark/heart) with shaft hint crack, open shaft by tier, lift prop. w229 lift/shaft/winch/rope bridge/map markers; w230 `card_keeper_0..5` + `portrait_keeper_N` (mine uses them for the keeper intro).
- Batch 6: w231 ability fx (`lunge_tele/trail`, `shot_<poison|fire|ice|dark>[_hit]`, `shield_up/hold/pop`, `summon`, `stomp`, `blink`, `enrage`, `regen`, `keeper_wake`), w232–w235 eleven new enemies (drip_crawler, lantern_moth, rust_knight, shard_spider, prism_wisp, geode_golem, ash_hound, void_eel, obsidian_sentinel, mirror, light_eater + dark_crystal_shard art) in enemies.json with tiers/abilities/status/drops and in the mine pools; w236 overlays: `aura_shield/aura_enraged` (Enemy child sprite), `st_<status>` (Player overlay), `armor_*`, `tier_aura_0`, `guardian_crown`.
- Known rough edges: a few special-move strips carry effect fragments; gangster portrait grid drifts a few px on some cells; `tier_aura_1..5` and `shot_poison_hit` didn't separate; Creator doesn't use the new tab/swatch art yet.

## 2026-11-16 — Penguin-arc heroes: Merry, Coco, Mer, Coldy, Big Jim + the two Too Powerful Penguins
- `tools/slice_world.py` w237–w241 (`_peng_hero_sheet`, per-sheet row maps) and w242/w243 (penguin wizard = penguin_f, penguin king = penguin_m). Characters in `GEN_ONLY` (HERO3_ANIMS); portraits with expressions where the sheets had them (Coldy: neutral only).
- playable.json/arcs.json: all seven selectable in the penguin arc; penguin_m/penguin_f now use the designed penguins (no feather/scarf picker; straight to names). companions.json: Mer, Big Jim, both penguins use the new sprites.
- Missing until Prompts 12: tool/fishing/swim/ride/power-up rows for the five, select cards and full expression sets, gang versions not needed (penguin arc only).

## 2026-11-17 — Penguin arc rewritten to Tom and his daughter's book + Prompts 12 batches
- Book saved to `reference/PENGUIN-STORY-by-Tom-and-daughter.txt`; design map `docs/PENGUIN-ARC.md`; `docs/STORY.md` Arc A rewritten. "Light Crystal" → "Star Crystal" everywhere (ids unchanged).
- `data/story.json` penguins: 30 beats / 5 chapters — Catkins + Meow Pow Wow lesson, catship + litter catapults (Litter Box consumable: `stink` stuns Grumps), Big Jim campfire, crystal babies (`crystal_baby` enemy, revert → Coldy joins + `sacred_key`), finargles (`finargle`, `finargle_elder`: blink + daze shot), crystal prison + Fennimore question (`fennimore_doubt/sure`), escape `scene_to` lake, merkitties → `mermaid_gift` (Companion `has_ability("tail")` true for everyone with the flag) + Mer joins, Fennimore beside the Dark Crystal at the finale (turnable if she doubted). Catkins NPC at the crystal meadow cave (`crystal_meadow.gd`, `data/npcs.json`, portrait placeholder = merry).
- Prompts 12A b1–2 (w244–w246, w251a, w253a, w255a): Merry/Coco/Mer full sheets (`_free_rows` per-sheet blob maps), 6 portraits each, select cards (`card_hero_<id>` → shown on the select screen), party icons, ability icons, partner ability cast + `fx/ability_<id>` (played by `Companion.use_ability`), gate panels `ui/gate_<id>`, water extras (dive/surface/swim_fast/tread/sit_rock/legs), Merry phase/float/hat_trick.
- Prompts 12B b1 (w247–w250, `_grid12` pitch-split rows): Coldy/Big Jim/Pip-Pip/Nova full sheets + 5 portraits each. 12B batch 2 came back as repeats of batch 1 (saved as `*_alt.png`, not sliced) — the 12B cards/portraits/abilities prompt needs a re-run (in Prompts 13).
- Prompts 12C b3 (w256–w261): clean gang `special` strips + `fx/special_<gang>`; 12 gang portraits × 5 expressions (neutral/happy/sly/angry/worried); `fx/tier_aura_0..5` (centre blanked, drawn behind enemies scaled above their native tier: `Enemy._boosted`), `fx/impact_*`, `fx/status_bleed/bless/shield`; party tab art (`ui/party_panel`, `party_card_<sprite>[_sel]` shown in the Party tab, ring/B/bitter/paw); creator panel pieces saved to `ui_creator2/` (not wired: the old panel geometry stays).
- `CharacterLibrary.HERO12_ANIMS` for the seven; `Player.play_tool` falls back to `<tool>_down`. Harnesses green (smoke, story 59 beats, creator, mine, hearts); ui_test has the same 5 pre-existing failures as before this work.
- Known rough edges: a few 12A strips are one cell off (Mer `sit`/`cast`, Merry `phase` carries wall fragments, Coldy `sleep` is a standing frame); 12B lacks sleep_bed accuracy on the king; Fennimore/finargles/crystal babies/Catkins use placeholder art until Prompts 13.

## 2026-11-17 — Round 2 balance, pass 1 (economy sheet + 100-day bot)
- `tools/sim.gd`: headless farming bot on the GameState API (`godot --headless -s res://tools/sim.gd -- 112 penguins best /tmp/sim.csv`); strategies best/cheap. `tools/economy.py` builds `docs/economy.xlsx` (crops profit/day with formulas, energy→field size, money sinks, sim curves + charts).
- Tuning: Maple's store stocks the season's seeds (next season's from day 22; Networker adds the rare ones) — fall/winter were dead before; saturation is now full price for the first 20 of a thing, then −10%/10, floor 40%; planting costs 1 energy (it was free), hoe 3, water 2 (field settles at ~50–60 tiles); start ◆50/◆60; crop values: turnip 12, carrot 16, potato 18, strawberry 20, corn 22, tomato 26, rice 18, wheat 14, cranberry 16, sugar beet 48, snow pea 24.
- Optimal farming-only curve: day 28 ≈ ◆4.9k, 56 ≈ ◆13k, 84 ≈ ◆24k, 112 ≈ ◆41k against ~◆9.6k of permits + weapons (materials extra). Next passes: mining/combat income in the bot, tool upgrade costs, skill-node prices.
- Pass 2: the bot mines with leftover energy (`sim.gd` 5th arg `1`; mine tier = day/28 as a stand-in for the story gates). Mine rocks now respect the pickaxe tier (1 + tier/2 per hit, like surface rocks) and ore rocks give a second lump 30% + 10%/pickaxe tier + mining tree; tool ladder crystals eased above steel (silver 3500, gold 7000, crystal 14000, moon 30000). Farm+mine curve: day 28 ≈ ◆9.5k, 56 ≈ ◆25k, 84 ≈ ◆47k, 112 ≈ ◆74k — covers permits + copper/iron/steel on every tool (~◆35k) with the silver ladder as the long goal. `docs/economy.xlsx` has the three curves.
- Pass 3 (combat): swords hit harder (wood 2, iron 4, steel 6, crystal 9, + sword tool tier) so regular enemies die in ~3–12 hits at their tier instead of 10–50; sword prices up (iron 200, steel 800, crystal 2400 base); stingy drop tables got ore/material drops (rock crab, quarry golem, drip crawler, crystal baby, ash hound, bog hag, rust knight, shard spider), wisp/shard trimmed; golem king 120 hp, ruin warden 150. `economy.xlsx` gained a Combat sheet (hits to kill, drop EV per hp).

## 2026-11-17 — Round 3 art consistency, pass 1
- `tools/art_audit.py`: per-frame bounding boxes for every character strip; flags size/feet outliers, single-frame motion strips, idle/walk scale mismatches; `--fix` drops empty/fragment frames (manifest updated) and normalises the feet line. Run it after any slicing. 68 → 27 issues.
- Slicers: `_hero_row_cells` splits a blob that spans two grid columns into per-column slices (it used to hand the whole blob to both columns: Marisol's swim, Nia's ride, Ladder/Sasha/Val/Mama Rosa/The Kid walk+attack were double sprites); `_split_wide` for the gang sheets. Re-sliced w201–w218.
- Creator skinned with the 12C panel (`ui_creator2`: panel behind the container, preview frame, arrow/dice/done/x picture buttons; `tools/creator_shot.gd` screenshots both creators). Party tab: the 12C partner card is the button, name + ability beside it.
- ui_test: fixed a stale-button crash; 2 remaining failures (dialogue mouse clicks, door click) don't reproduce in a standalone script — harness state, to revisit in Round 7.

## 2026-11-17 — Round 4 feel, pass 1
- Sword hits: hitstop (0.035 s, 0.08 on a kill or crit) + camera nudge (1.2 / 2 / 3 px); crit chime. Enemy deaths: poof + thud, bosses (≥60 hp) a long boss_down and a 5 px shake. New placeholder SFX: thud, boss_down, crit, stun (Coldy's stomp), stink (litter box). `make_audio.py` music is non-deterministic: `git checkout audio/music` after regenerating unless the music changed on purpose.

## 2026-11-17 — Round 5 audio, pass 1
- Music crossfades (0.9 s) between areas on a spare player; SFX get ±7% pitch drift. Five new placeholder tracks: lake (lake, riverlands), mountain (mountain, highlands), beach, sky (sky, station), cattopia (crystal meadow in the penguin arc, jungle). Real tracks drop in under the same names.

## 2026-11-17 — Round 6 multiplayer hardening, pass 1
- net_test (host + guest + local relay) green. Client: after an unexpected drop it rejoins the same room up to 3 times (2/4/6 s backoff); a deliberate leave never reconnects. Relay: ping/pong heartbeat drops dead sockets after 30 s, 64 KB frame cap, ~120 msgs/s per socket flood guard.

## 2026-11-17 — Round 7 QA pass
- Full harness run green: smoke, playtest (43 checks, screenshots reviewed), creator, mine, story (59 beats), hearts, reach, walls, net (host+guest). ui_test: 2 harness-only failures remain. Guide 07 written.

## 2026-11-17 — Round 3 pass 2 + Round 4 pass 2
- Art: portrait/fragment frames dropped from bo celebrate, marisol axe_down, nia reel/pickaxe_up, ollie hoe_up, old_moss walk_up, merry wave (persisted as `KNOWN_DROPS` in art_audit so re-slices keep them). 27 → 20 audit lines, all cosmetic.
- Feel: tool swings play at 1.35× and can be walked out of after 0.3 s (fishing excepted); the work still happens on the press. Playtest 43/43.

## 2026-11-17 — 20-agent audit round + design round (Guide 09, Art Prompts 16)
- Audit: 20 reports (merged list in `docs/AUDIT-2026-11-17b.md`). Done: save recovery (TMP/BAK, corrupt save moved aside), 90 s autosave, story_pending replay, new-game confirm + Restore, toast cap/log, next-step line, dialogue B-back and confirm guard, percentage armour, wall-aware attacks and guns, dodge roll, crew/skill perks wired, racket pass cap/wash cap/collector rework, sprinklers and scarecrows placeable, web pack 216 → 82 MB (lossy WebP for art/gen).
- Mines: cellular-automata caverns, 40–80 wide, organic walls, ladder at the farthest point (`scripts/mine.gd`).
- Elevation: `GameMap.add_plateau(cells, ramps)`; regions read `plateaus` from data.
- Conquest: `Battle` + `HelperUnit`; `tools/gen_battles.py` → bf_frostfield, bf_shattered_vale, bf_rail_yards, bf_dockside.
- Colonies: `Colony`; `tools/gen_colonies.py` → colony_coral/kelp/ice/ember, ferry from the beach pier, cboss_* gift bosses, abilities coral_ward/tideswim/frost_step/starfire.
- Town projects: `Project`; `tools/gen_projects.py` → crystal_ward and hq (6 stages each), crew jobs.
- Lieutenants: eight `lt_*` gift bosses in gifts.json `lieutenants`.
- Talk: `Talk` + data/talk.json (season/weather/arc/festival/heat).
- check.sh adds compile_all.gd and campaign_test.gd. 20-bot run: all finish, 0 errors.
- Open: crafting screen, quality crops, save slots, settings, heists/turf, endings/epilogues, heart perks, relay host. Art: Prompts 16.

## 2026-11-17 — "Complete remaining work" round
- Settings (`Settings`, scripts/settings.gd): music/sound volume on Music/SFX buses, button size, left-handed mirror, easy mode (60% damage, no faint fee). Options tab.
- USE button shows an action word (`GameMap.action_word`, `TouchControls.context_word`).
- Save slots: `GameState.slot()/save_key()/use_slot()`, slot 1 = old "run" key; `export_code()/import_code()` (gzip+base64 "DRM1:"). Title → Save slots.
- Quality crops: run.quality[id] = {g, s}; harvest rolls (farming level, fertiliser); sell box pays +50%/+25%; stars on inventory slots.
- Crafting screen: `CraftScreen` replaces the dialogue list; recipe discovery (`Crafting.discovered`, run.seen, run.known_recipes).
- Heart perks: `tools/gen_heart_perks.py` → data/heart_perks.json + npcs.json perk texts + birthdays; `Perks` (scripts/perks.gd). Birthdays triple gifts. Social page shows birthday, learned loves, next perk.
- Endings: `Epilogue` slideshow from data/epilogue.json (`tools/gen_epilogue.py`), once after epilogue_done, replay in Options. Lieutenants: spare or recruit (Mags, Brock). Nova catches up at the campfire (story effect `know`). Deuce's card game is a friendly hand.
- Gangster ops (`Ops`, scripts/ops.gd): turf per district (clear the block, ◆40/morning, no raids), three heists (cannery/arcade/vault), crew loyalty favours gate loyalty 3.
- Battles: RALLY button (`Hud.extra_rects` lets on-screen buttons take taps).
- Hacking Terminal: daily memory hack (`HackGame`).
- Web: PWA on (installable, portrait, icons in web/), styled loading screen.
- Tests: tools/systems_test.gd in check.sh. Screens: tools/ui_shot.gd.

## 2026-11-17 — Skills rebuilt, President rewritten, Guide 10 + Art Prompts 17
- Skills: `tools/gen_skill_trees.py` (reads data/skills_base.json) → 13 skills × 4 branches × 10 tiers = 520 nodes; column c opens at 2c points; `GameState.BONUS_CAPS`; arc trees Harmony/Hustle (`skill_in_arc`, `arc_skill`, `add_arc_xp`), Leadership (teamwork XP; `has_team`), Strategist (battle campaign XP). Menu Skills tab is a Sun Haven grid (`_skills_tab`, `_node_cell`).
- The President is M. (story.json g5_president / g5_win).
- PWA update flow: head_include script checks the service worker, saves via `window.dreamsUpdateReady`, yellow update bar.
- tools/missing_art.py → docs/MISSING-ART.md. tools/gen_prompts17.py → docs/ART-PROMPTS-17.md. Guide 10.

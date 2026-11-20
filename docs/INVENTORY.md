# Dreams: inventory (regenerated 2026-11-20 by tools/inventory_md.py)

Every system in the game with its state, what is still outstanding, test coverage, and what Claude needs from Tom. `docs/inventory.csv` is the source (edit it, then run `python3 tools/inventory_md.py`). Percentages are estimates against Tom's bar ("100% = Stardew-grade commercial release").

**Summary:** 58 systems: 40 done, 9 rough, 9 missing. Average 71%.

**Live counts:** 19,394 sliced art pieces in 653 groups; 105 music tracks, 467 sfx files, 61 ambience beds; 101 headless tests, 95 in check.sh.

## Systems

Status: **done** = built, tested, only polish left; **rough** = playable but content or features are still missing; **missing** = not started.

| Area | System / feature | Status | Percent | Tests | Notes |
|---|---|---|---|---|---|
| Art | 19,394 sliced pieces in 653 groups; Prompts 17-30 drawn | rough | 88 | crisp_art_test, art_audit | C2: CrispArt shader; fuzzy-art ranking docs/FUZZY-ART.md (buildings to redraw C5); Tom: gangster heroes need unique One-Piece-level designs |
| Audio | 105 music tracks (ACE), 467 sfx files, 61 ambience beds | done | 97 | music_map_test, danger_music_test, sfx_audit | C6: seamless loops (numpy crossfade + loop points), 30 re-renders + new tracks, all sfx re-softened from source, real CC0 ambience/animal/war-horn sounds, music engine ducking/resume/prefetch, footsteps by ground |
| Combat | Battles, campaigns, drills, briefings, convoy, helpers | done | 92 | campaign_c3_test, battle_win_test, bf_themes_test, campaign_gate/words/map/story tests | C3: Grump variants + captains, per-campaign leaders, Crystal Kin, team on the field, 19 themed fields, easy early wins, resume, boss music |
| Combat | Weapons, guns (no blood), spells, bosses, Gifts and the ten Marked | done | 85 | gift_test, ally_test | Kills-past-cap XP undecided |
| Core | Engine, portrait 270x480, touch D-pad + A/B/MENU, input actions | done | 95 | smoke_test, desktop_layout_test, touch_ui_test | C2: desktop/landscape fills the screen (DisplayMode), F11/fullscreen, touch controls auto-hide on computers; phones unchanged |
| Core | Title, character creator, outfits, hair colours | done | 90 | creator_test (not in check.sh) | 19 playable characters (data/playable.json) |
| Core | Saves, 3 slots, migrations, settings page | done | 90 | systems_test, storage_test | No save export/import yet (audit 17b deferred) |
| Core | Web build + PWA, deploy on push | done | 90 | CI runs check.sh | Pack size/memory and loading bar still open (audit 17b F12, W15/W16) |
| Core | Desktop / full-screen play | done | 90 | desktop_layout_test | C2 P8 |
| Core | Steam build (export, achievements, Steam networking) | missing | 0 | none | Planned last ('QA/Steam' depth round); needs Tom's Steamworks account |
| Farm | Stardew start: empty house, overgrown field, debris | done | 96 | crop_test, playtest.gd | C3: debris regrows by rarity, seasonal weeds/tall grass, hay+fiber (decided; Tom may still change) |
| Farm | Farming: 134 crops, seasons, watering, soil layer, star quality | done | 90 | crop_test | Quality stars via farming skill |
| Farm | Buildings: crafted/purchased by tier (43 defs) | done | 90 | station_test, station_check.py | No free stations (Tom rule) |
| Farm | Farm river, chests, bag upgrades | done | 90 | storage_test | Sun Haven style bag + chests |
| Farm | Animals, coop/barn, hay, streaks, crows | rough | 45 | systems_test | Tom C11: massive tiered ranching (exotics, fantastic/GM creatures, Ranching skill tree, trainable team animals) not built yet |
| Look | Soft edges and cliffs: WaterMask shores/paths, CliffPainter plateaus/bands, stairs | done | 88 | bake_clip_check, perf_test | Round 11 + C3 P3 clipped bakes |
| Look | Lighting: day/night tint, lamps/NightGlow, dawn glow, region fixed darkness | done | 85 | r13_world_test, perf_test | C5 home-world look round; caves light 0.5 |
| Look | Weather visuals: rain, snow, fog, wind, petals, leaves, fireflies, storms | done | 85 | r13_world_test | Overlay strips (fix_overlays.py); HUD weather icon beside the date (C5) |
| Look | Seasonal looks: trees/bushes/tiles per season, winter snow, region look_season | done | 85 | r13_world_test | Region season pins (desert/sky summer, frost winter) |
| Look | Interiors: furnish.py dressing, props fitted to footprint, rec rooms glow | done | 85 | interior_reach, rec_test | C2 rec visuals |
| Look | NPC and animal animation: walk/idle strips, aligned wildlife, tool poses | rough | 78 | anim_test, gang_play_test | C5 c5_15: 12B heroes still lack side/up tool strips |
| Multiplayer | Co-op up to 8 through relay (host-authoritative) | rough | 55 | coop_test, net_test (needs relay, not in check.sh) | Relay not deployed; audit 17b net findings F1-F11 partly fixed |
| People | 26 villagers: schedules, gifts, hearts, birthdays, 96+ heart perks | done | 90 | hearts_test, hearts_content_test | 10-heart endings and best-friend ceremony are story defaults not built |
| People | Dating/marriage | done | 85 | romance_test | C7: bouquet at 8 hearts, 3 dates per candidate, locket at 10, wedding (penguin chapel / gangster plaza), spouse moves in and helps overnight; 10 candidates, G-rated; writing deepened in C12 |
| People | Pet/pup: perks, hunter perk, mines | rough | 78 | systems_test, move_target_test | C2: pup swims (Paddle) instead of walking on water |
| QA | Headless tests, bots, playtest | done | 85 | 101 *_test.gd; 95 run in check.sh | char_sheet/creator/hearts/ui/reach/net tests run outside check.sh |
| Story | Endings + epilogue slideshow | done | 90 | story_test, epilogue_test | Third ending (Clean Break) pending Tom |
| Story | Penguin arc: 5 chapters, sanctuary, colonies | done | 85 | story_test, meow_gate_test | C7: canon (Crystopia crystals, 21-year bell timeline, Catkins guardian line, Nova dream, Fennimore beats, elders at the finale), beat flow fixes, story_flow_test |
| Story | Gangster arc: 5 chapters, Racket, heat, turf, heists, crew | done | 85 | story_test, gang_play_test, cash_test | C7: origin + redemption path, Winter Kade, Inspector Hale, Clean Break ending, loyalty in the finale (data/story_gang.json) |
| Story | Side stories (crystal babies, Big Jim's brother, Coldy's key, Wastes Commander, Rosa, The Kid, Specs) | done | 75 | none | C7 P4: 7 chains x 3 scenes (data/side_stories.json via tools/gen_side_stories.py, SideStory). Still to hook: baby helpers, highland cave, hall vault, Tomas as villager |
| Story | Festivals: Egg, Lantern, Harvest, Star (scenes in town) | rough | 75 | none dedicated | C7 P4: lantern float (wish + steer past snags), crop contest (pick entry, rival entries), star-wish (wish + send a star). Full action mini-games still to come |
| Systems | Community farm (Commons), 8 stages, volunteers | done | 95 | commons_test, cf_volunteer_test, cf_layout_test | C2: overnight builds, seasonal asks, working volunteers, lend-a-hand, woodland edge / gangster city-block edge; C3: builds take 2-4 nights with half-built pieces |
| Systems | Rec Center: bowling, 5 arcade cabinets, tickets, prizes | done | 94 | rec_test, bowling_test, ticket_econ_test, rec_links_test, rec_audio_test | C2: hours, house lane, villager versus bowling, real phone controls and pin physics, economy without loops, quests/mail/perks links, new decor + RecGlow, bowling song + jukebox; C3: renovations to ~day 125 + seasonal Rec Cup, gang 2am, ticket stub |
| Systems | Arcade: Block Jumper, Neon/Crystal Stack, Whack-a-Grump, Claw, Duck Pond, Skee-Ball | done | 92 | arcade_test, jumper_test, stack_whack_test, rec_games_test, touch_ui_test | C2: pause card, curves, scoring, real Skee-Ball, checkpoints/respawn, tap-to-jump |
| Systems | Workshop stations, CraftScreen, recipe books, cyber stations | done | 90 | station_test | Generated by gen_stations.py |
| Systems | Quest tracker: pick tracked quest, themed corner compass (mines point down) | done | 90 | quest_tracker_test | C3 P6 |
| Systems | Difficulty modes Very easy/Easy/Default/Hard (combat + battle campaigns only, per slot) | done | 90 | difficulty_test (not in check.sh) | C4 P1 |
| Systems | Day length 15/20/30/40 min (new-game menu + Settings, per slot) | done | 90 | day_length_test (not in check.sh) | C4 P1 |
| Systems | Skill trees: 13 trees, unlock nodes, caps, renames | done | 88 | skill_glow_test | C2: unspent points shimmer on tabs + banner |
| Systems | Hero tab, gear sets, energy revamp | done | 85 | char_sheet_test (not in check.sh) |  |
| Systems | Collections: museum, shipping log, fish log, cookbook/crafting/forage logs, milestones (badges) | done | 85 | collections_test, gang_flavour_test, save_test, coop_test | C8 P3: Valley Museum / Curio Room (library east wing, 59 pieces in 4 wings, donation tray, Theo letters), Book menu tab, milestone letters + farmhouse decor + Curator's Loupe; open: wildlife log or bug catching (Tom), museum cases not synced to co-op guests |
| Systems | Shops, economy, money (gangster cash), kill-crystal cap | done | 80 | cash_test | Balance sheet docs/economy.xlsx |
| Systems | Long-run progression and balance (3-year pacing, year 2-3 unlocks) | rough | 50 | first_week_test | Tom: CONDUCT 16 |
| Systems | Seasonal content (festivals, holidays, seasonal items/quests per season, year-2+ events) | rough | 45 | none | Tom: CONDUCT 15 |
| Systems | Earned fast travel network (mine carts, ferries, trains, planes, clouds, cars/subway, currents) | missing | 10 |  | Tom 17:39; mega hub vehicles exist; built in C14, paced C16 |
| Systems | Decor and cosmetics ecosystem (furniture, wallpaper, floors, exteriors, outdoor decor, apparel, footwear; rarity to one-of-a-kind) | missing | 5 | none | Tom: CONDUCT 10 |
| Systems | Helper automation (assign recruits/helpers/animals to farm, combat, forage, chests; levels, energy) | missing | 5 |  | Tom 17:12; base = battle team helpers (C3); full in C11 |
| Systems | Haptics (phone vibration) | missing | 0 | none | Audit 17b W7; Claude can build |
| Systems | Trading cards (packs, binder, regional sets, trading with NPCs/players, card game) | missing | 0 |  | Tom 17:21; CONDUCT 19 |
| Systems | Casino side arc (gangster; tiered build-up against NPC pushback, staff) | missing | 0 |  | Tom 17:12; CONDUCT 10. Tom 20:03: real betting allowed, all-ages tone (no drinking: wines are trade goods) |
| Systems | The General Store side arc | missing | 0 |  | CONDUCT 21 |
| World | Valley maps: farm, town, beach, mountain, forest, lake, meadow, crystal meadow, outskirts, community farm | done | 90 | reach_test (not in check.sh), exit_check, exit_edge_check, door_check, invisible_walls | Sun Haven openness via WorldGen |
| World | Mines: 26 layouts, chunks, pup in mines, Hollow Heart | done | 90 | mine_test, mine_keeper_test | C2: 35 varied guardian encounters, varied wake pace, route-following arrow, reliable crates/barrels, tools 30% of sword in fights |
| World | Day/night, seasons, weather, dawn glow, faint at 10pm | done | 90 | r13_world_test, day_length_test (not in check.sh) | Day length 15/20/30/40 min built (C4 P1); C5: desert/sky looks always summer, caves fixed darkness (light 0.5) |
| World | Mega regions: 10 worlds, own map tabs, travel hooks | done | 88 | mega_region_test, mega_regions_test | Five built round 13; new and least played; C4: balance/rewards/unlocks per arc, pin cards, mega quest tracker, boss themes, hidden pockets + secret ways, gangster Space, new boss/foe art |
| World | 67 regions (regions.json) incl. campaign-gated story regions | done | 85 | r13_world_test, campaign_gate_test | Story regions held until campaign won (Tom may want free) |
| World | Hidden pockets and secret ways (one each per mega area), journal pages | rough | 65 | hidden_area_test, hidden_stable_test | C4 P3; C5: spots stay put day to day (run.hidden_at); home-world + more in C14 |
| World | Hazards, jumping/flight, lava mega region, mine hazards | missing | 0 |  | CONDUCT 20 |

## Outstanding

- Art: Missing art (icons, enemies, portraits, stations, named, broken) = 0 (checked by tools/missing_art.py, 2026-11-19)
- Audio: Missing sounds = 0 (checked by tools/sfx_audit.py, 2026-11-19)

## What Claude needs from Tom

1. **Co-op relay host account** (blocks: online co-op on the live site). Sign up for Render (second Starter service) or Fly.io; Claude gives tap-by-tap steps and deploys server/. Until then co-op only works in tests.
2. **Story answers, or say 'write the defaults'** (blocks: side stories, third ending, colony/Marked scenes). Guide 11 Part 3: 31 questions. Not built yet: finargle queen scene, four merkitty verses, one story per colony, Clean Break ending + Inspector Hale, one scene per Marked, 10-heart villager endings, side stories 20-26, festival mini-games.
3. **Dating/marriage or friendship only** (blocks: done). C7: bouquet at 8 hearts, 3 dates per candidate, locket at 10, wedding (penguin chapel / gangster plaza), spouse moves in and helps overnight; 10 candidates, G-rated; writing deepened in C12
4. **Your daughter's ideas** (blocks: nothing (optional)). Guide 11 Q29: a creature, place, joke or character she wants.
5. **Tone check, both arcs** (blocks: nothing (defaults running)). Guide 11 Q30-31; default keep sad scenes gentle and the gangster arc as is.
6. **Gameplay calls** (blocks: nothing (defaults running)). Muscle skill row names; pup Hunter perk; full XP past the kill cap?; story regions held until their campaign is won (on now).
7. **Steam** (blocks: Steam release). A Steamworks developer account (about $100 per game) when you want the Steam build; Claude does the export work.
8. **OpenAI organisation verification** (blocks: nothing now). Was still in review (HANDOFF); the image tool works meanwhile. 300 images/day through Nov 25, then 60.
9. **Playtest notes from your phone** (blocks: polish). One good and one confusing thing per session (Guide 24 Part 5), plus the Guide 24 checklist: new game, shop/bag, rooms, mines, fights, phone smoothness, co-op.
10. **Song swaps** (blocks: nothing). Say 'swap <name>' for any track you don't like.

## Tests outside check.sh

char_sheet_test, creator_test, day_length_test, difficulty_test, net_test, reach_test

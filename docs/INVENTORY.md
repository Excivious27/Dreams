# Dreams: inventory (regenerated 2026-11-20 by tools/inventory_md.py)

Every system in the game with its state, what is still outstanding, test coverage, and what Claude needs from Tom. `docs/inventory.csv` is the source (edit it, then run `python3 tools/inventory_md.py`). Percentages are estimates against Tom's bar ("100% = Stardew-grade commercial release").

**Summary:** 74 systems: 54 done, 14 rough, 5 missing. Average 78%.

**Live counts:** 20,824 sliced art pieces in 674 groups; 105 music tracks, 475 sfx files, 61 ambience beds; 125 headless tests, 119 in check.sh.

## Systems

Status: **done** = built, tested, only polish left; **rough** = playable but content or features are still missing; **missing** = not started.

| Area | System / feature | Status | Percent | Tests | Notes |
|---|---|---|---|---|---|
| Art | 20,824 sliced pieces in 674 groups; Prompts 17-30 drawn | rough | 88 | crisp_art_test, art_audit | C2: CrispArt shader; fuzzy-art ranking docs/FUZZY-ART.md (buildings to redraw C5); Tom: gangster heroes need unique One-Piece-level designs |
| Audio | 105 music tracks (ACE), 475 sfx files, 61 ambience beds | done | 97 | music_map_test, danger_music_test, sfx_audit | C6: seamless loops (numpy crossfade + loop points), 30 re-renders + new tracks, all sfx re-softened from source, real CC0 ambience/animal/war-horn sounds, music engine ducking/resume/prefetch, footsteps by ground |
| Combat | Battles, campaigns, drills, briefings, convoy, helpers | done | 92 | campaign_c3_test, battle_win_test, bf_themes_test, campaign_gate/words/map/story tests | C3: Grump variants + captains, per-campaign leaders, Crystal Kin, team on the field, 19 themed fields, easy early wins, resume, boss music |
| Combat | Weapons, guns (no blood), spells, bosses, Gifts and the ten Marked | done | 85 | gift_test, ally_test | Kills-past-cap XP undecided |
| Core | Engine, portrait 270x480, touch D-pad + A/B/MENU, input actions | done | 95 | smoke_test, desktop_layout_test, touch_ui_test | C2: desktop/landscape fills the screen (DisplayMode), F11/fullscreen, touch controls auto-hide on computers; phones unchanged |
| Core | Saves, 3 slots, migrations, save codes/files (export/import) | done | 95 | systems_test, storage_test, save_test, save_transfer_test | C9 P5: DRM2 codes with version + check, save/load files, confirm before overwrite, Restore kept, honest write errors, back up all farms |
| Core | Controllers: pad bindings, remap API, device prompts, PadFocus/PadCursor, analog walk | done | 92 | pad_test, menu_pad_test, screens_pad_test | C9 P1-P3: every action on a pad, hot-plug, remap page, device prompts, analog walk; menus, chest, craft, campaign board, prizes, map pins, arcade and bowling all playable by pad/keys |
| Core | Web build + PWA, deploy on push | done | 92 | CI runs check.sh; deploy gate (smoke, web_head, music_stream --check) | C9 P4: deploys fixed (no cancels, skip unchanged builds), offline launch, maskable icons, Android back, phone fullscreen, music streamed. Pack still ~105 MB (target 80) |
| Core | Title, character creator, outfits, hair colours | done | 90 | creator_test (not in check.sh) | 19 playable characters (data/playable.json) |
| Core | Desktop / full-screen play | done | 90 | desktop_layout_test | C2 P8 |
| Core | Haptics (vibration on phones and pads) | done | 88 | haptics_test | Web Vibration API on Android; iPhone browsers cannot vibrate (Options says so). Hooks beyond Music.sfx names (tool fx, story shakes, arcade) can be added with one Haptics.buzz line. |
| Core | Accessibility and Options: text size/speed, message time, reduced motion, colour-blind cues, timing help, grouped Options | done | 88 | menu_pad_test, phone_ui_test, toast_layout_test | C9 P2: Options grouped (Sound / Display and controls / This farm), Larger text, instant text, rarity dots, framed ally bars, fish timing x1.5, Save and quit on computers |
| Core | Steam Deck / Linux native build | partial | 60 | haptics_test, deploy linux job | Linux preset + CI export, fullscreen, touch auto, cursor hide, focus pause. Open: UI scale for 1280x800, physics interpolation, Steam art (docs/STEAM-DECK.md). |
| Core | Steam build (export, achievements, Steam networking) | missing | 0 | none | Planned last ('QA/Steam' depth round); needs Tom's Steamworks account |
| Farm | Stardew start: empty house, overgrown field, debris | done | 96 | crop_test, playtest.gd | C3: debris regrows by rarity, seasonal weeds/tall grass, hay+fiber (decided; Tom may still change) |
| Farm | Farming: 134 crops, seasons, watering, soil layer, star quality | done | 90 | crop_test | Quality stars via farming skill |
| Farm | Buildings: crafted/purchased by tier (43 defs) | done | 90 | station_test, station_check.py | No free stations (Tom rule) |
| Farm | Farm river, chests, bag upgrades | done | 90 | storage_test | Sun Haven style bag + chests |
| Farm | Ranching skill tree (14th tree, both arcs: Produce, Quality and Care, Breeding, Friends and Helpers) | done | 85 | ranch_p3_test | C11a P3: gen_skill_trees.py, keys animal_yield/animal_quality/animal_friend/big_goods/grow_speed/breed_chance/ranch_value/hand_work, blueprints for hutch/sty, Farm Hands. Open: rare_breed node, old hp/energy filler over the arc caps |
| Farm | Ranch stations and goods: Mayo Machine, Honey Extractor, loom yarn, cream/yogurt/truffle oil, Down Pillow, Flower Mead, Ranch log | done | 85 | ranch_p3_test, collections_test, econ_check | C11a P3/P1: new stations 2 tiers each, starred inputs keep their star, Ranch log + milestones, econ_check 0 failures. Open: creamery/wool carder/egg sorter art drawn but not yet stations |
| Farm | Ranching core: 9 classic species both arcs (chicken, duck, cow, sheep, goat, llama, pig, rabbit, bees), roster, care, goods quality, breeding, incubator, rehome | rough | 80 | ranch_test, save_test, c11a_integ_test | C11a P1: gen_ranch.py -> data/ranch.json, Ranch (scripts/ranch.gd) care/friendship 0-1000/overnight goods/breeding without gender checks/variants/rehome (never sold for meat), old farms migrated (SAVE_VERSION 12). Open: exotics and fantastic creatures (C11b), rare_breed skill node |
| Farm | Ranch buildings and pens: coop and barn 1-3, hutch and sty 1-2, apiary 1-3, silo 1-3, fences, gates, grazing, night shelter | rough | 75 | pen_test, coop_test, farm_look_test | C11a P2/P3: RanchFarm (scripts/ranch_farm.gd), roster spawn, one silo feeder rule, dry-day grazing, incubator by the coop, animals go in at night/storms. Open: walk-in coop/barn interiors, brushing, bigger barn pen, pen grass that regrows |
| Farm | Team animals: lessons with treats, team of 2, follower in the field (charge/guard/fetch), battle team, Animals page | rough | 60 | team_animals_test, campaign_gate_test | C11a P4: TeamAnimals + TeamBeast + gen_team_animals.py, poses for 8 species (P6). Open (C11b): teacher letter, CHECK menu on pen animals, saddlebags, full ally review |
| Gangster | Casino side arc: The Gilded Ace on Casino Row (5 tables, real cash bets, every bet returns under 99%, limits, odds board, keepsakes) | rough | 75 | casino_test | C10b P4: slots 94.6%, roulette 97.3%, Big/Small 97.2%, blackjack 6:5 97.4%, video poker 97.3%; $500 daily loss limit on, hands cap, Take a break, reality check, heat ties. Open: The Straight Game story chain + High Roller room, casino song and ambience, house cut once yours |
| Look | Ranch art: 23 animal kinds + team poses for 8 species, 12 building tiers with snow/night/window glow, 24 interior pieces, 6 floors, 24 product icons, 8 stations | done | 90 | slice_c11a check, missing_art | C11a P6: 25 renders, tools/slice_c11a.py, art/gen/animals/_ranch_art.json. Open: duck swim strip, apiary tier 3, gangster city-ranch skin (Tom), team lamb face, one llama sliver |
| Look | Soft edges and cliffs: WaterMask shores/paths, CliffPainter plateaus/bands, stairs | done | 88 | bake_clip_check, perf_test | Round 11 + C3 P3 clipped bakes |
| Look | Lighting: day/night tint, lamps/NightGlow, dawn glow, region fixed darkness | done | 85 | r13_world_test, perf_test | C5 home-world look round; caves light 0.5 |
| Look | Weather visuals: rain, snow, fog, wind, petals, leaves, fireflies, storms | done | 85 | r13_world_test | Overlay strips (fix_overlays.py); HUD weather icon beside the date (C5) |
| Look | Seasonal looks: trees/bushes/tiles per season, winter snow, region look_season | done | 85 | r13_world_test | Region season pins (desert/sky summer, frost winter) |
| Look | Interiors: furnish.py dressing, props fitted to footprint, rec rooms glow | done | 85 | interior_reach, rec_test | C2 rec visuals |
| Look | NPC and animal animation: walk/idle strips, aligned wildlife, tool poses | rough | 78 | anim_test, gang_play_test | C5 c5_15: 12B heroes still lack side/up tool strips |
| Multiplayer | Co-op up to 8 through relay (host-authoritative) | rough | 68 | coop_test, net_test (needs relay, not in check.sh) | C9 P6: guest sees host world keys (romance/dates, spouse, cfarm, mega, tickets), relay overwrite guard, world sync as deltas; coop_test covers C3-C8. Relay host still not deployed (Tom) |
| People | 26 villagers: schedules, gifts, hearts, birthdays, 96+ heart perks | done | 90 | hearts_test, hearts_content_test | 10-heart endings and best-friend ceremony are story defaults not built |
| People | Dating/marriage | done | 85 | romance_test | C7: bouquet at 8 hearts, 3 dates per candidate, locket at 10, wedding (penguin chapel / gangster plaza), spouse moves in and helps overnight; 10 candidates, G-rated; writing deepened in C12 |
| People | Pet/pup: perks, hunter perk, mines | rough | 78 | systems_test, move_target_test | C2: pup swims (Paddle) instead of walking on water |
| QA | Headless tests, bots, playtest | done | 85 | 125 *_test.gd; 119 run in check.sh | char_sheet/creator/hearts/ui/reach/net tests run outside check.sh |
| Story | Endings + epilogue slideshow | done | 90 | story_test, epilogue_test | Third ending (Clean Break) pending Tom |
| Story | Penguin arc: 5 chapters, sanctuary, colonies | done | 85 | story_test, meow_gate_test | C7: canon (Crystopia crystals, 21-year bell timeline, Catkins guardian line, Nova dream, Fennimore beats, elders at the finale), beat flow fixes, story_flow_test |
| Story | Gangster arc: 5 chapters, Racket, heat, turf, heists, crew | done | 85 | story_test, gang_play_test, cash_test | C7: origin + redemption path, Winter Kade, Inspector Hale, Clean Break ending, loyalty in the finale (data/story_gang.json) |
| Story | Ranch villagers and events: animal sellers, ranch letters, Bramble the lamb, Animal Show and Best Egg, Benno/Hazel market stalls, spouse feeds animals | rough | 75 | ranch_villagers_test, romance_test, ambience_test | C11a P5: favour sources by tier, CC0 oink/buzz/thump, pen sounds from real animals. Open: barn/coop room-tone beds, community-farm petting pen, crew ranch ties, exotic quest rewards |
| Story | Side stories (crystal babies, Big Jim's brother, Coldy's key, Wastes Commander, Rosa, The Kid, Specs) | done | 75 | none | C7 P4: 7 chains x 3 scenes (data/side_stories.json via tools/gen_side_stories.py, SideStory). Still to hook: baby helpers, highland cave, hall vault, Tomas as villager |
| Story | Festivals: Egg, Lantern, Harvest, Star (scenes in town) | rough | 75 | none dedicated | C7 P4: lantern float (wish + steer past snags), crop contest (pick entry, rival entries), star-wish (wish + send a star). Full action mini-games still to come |
| Systems | Community farm (Commons), 8 stages, volunteers | done | 95 | commons_test, cf_volunteer_test, cf_layout_test | C2: overnight builds, seasonal asks, working volunteers, lend-a-hand, woodland edge / gangster city-block edge; C3: builds take 2-4 nights with half-built pieces |
| Systems | Rec Center: bowling, 5 arcade cabinets, tickets, prizes | done | 94 | rec_test, bowling_test, ticket_econ_test, rec_links_test, rec_audio_test | C2: hours, house lane, villager versus bowling, real phone controls and pin physics, economy without loops, quests/mail/perks links, new decor + RecGlow, bowling song + jukebox; C3: renovations to ~day 125 + seasonal Rec Cup, gang 2am, ticket stub |
| Systems | Skill trees: 13 trees, unlock nodes, caps, renames | done | 92 | skill_glow_test, c8_curve_test, move_speed_test | C2: unspent points shimmer on tabs + banner; C8: level curve to MAX_LEVEL 100, LEVEL_EFFECT_CAP 20, tree HP/EN caps, 5 move-speed nodes per arc |
| Systems | Arcade: Block Jumper, Neon/Crystal Stack, Whack-a-Grump, Claw, Duck Pond, Skee-Ball | done | 92 | arcade_test, jumper_test, stack_whack_test, rec_games_test, touch_ui_test | C2: pause card, curves, scoring, real Skee-Ball, checkpoints/respawn, tap-to-jump |
| Systems | Workshop stations, CraftScreen, recipe books, cyber stations | done | 90 | station_test | Generated by gen_stations.py |
| Systems | Quest tracker: pick tracked quest, themed corner compass (mines point down) | done | 90 | quest_tracker_test | C3 P6 |
| Systems | Difficulty modes Very easy/Easy/Default/Hard (combat + battle campaigns only, per slot) | done | 90 | difficulty_test (not in check.sh) | C4 P1 |
| Systems | Day length 15/20/30/40 min (new-game menu + Settings, per slot) | done | 90 | day_length_test (not in check.sh) | C4 P1 |
| Systems | Fishing: pools per water/season/time, rods/bait, treasure, Legendary Koi | done | 88 | c8_p4_test, collections_test | C8 P4: Fishing.T table, value-band windows, bait only where it helps, tier ceiling per area |
| Systems | Shops, economy, money (gangster cash), kill-crystal cap | done | 88 | cash_test, shop_econ_test, econ_check.py | Balance sheet docs/economy.xlsx; C8: econ_check (no loops/outliers) in check.sh, ECON floors/caps per recipe, stand/market fixed, Valley Fund sink |
| Systems | Collections: museum, shipping log, fish log, cookbook/crafting/forage logs, milestones (badges) | done | 88 | collections_test, gang_flavour_test, save_test, coop_test | C8 P3: Valley Museum / Curio Room (library east wing, 59 pieces in 4 wings, donation tray, Theo letters), Book menu tab, milestone letters + farmhouse decor + Curator's Loupe; open: wildlife log or bug catching (Tom), museum cases not synced to co-op guests |
| Systems | Move speed ladder: gear, buffs, skills, bursts, mounts, vehicles (MoveSpeed caps) | done | 85 | move_speed_test | C8 P5: foot cap +60%, ride/vehicle caps, tap-to-move braking; buff stacking still open |
| Systems | Hero tab, gear sets, energy revamp | done | 85 | char_sheet_test (not in check.sh) |  |
| Systems | Farmhouse exteriors: 61 styles (roofs, painted and brick/stone/log walls, windows, stonework, doors, shutters, porches, mailboxes, pen fences) | done | 85 | house_exterior_test, farm_look_test, door_check | C10b P3: Plans board > Restyle the farmhouse, live preview, buy once and switch free, night and winter refit, winter-night bug fixed. Open: gangster city look default (Tom), showpiece whole-house redraws |
| Systems | Decor catalogue (data/decor.json from gen_decor.py, 1034 entries, rarity common..mythic + unique, sets, Book catalogue screen with filters/order/set rewards) | done | 85 | decor_test, decor_catalogue_test | C10a P1/P3. phone_ui_test does not audit the catalogue screens yet; CharSheet keeps its own rarity rank dict. |
| Systems | Decor sources and shops: Tess the carpenter's workshop, crew counters, shelves with real rotation, crafted decor, loot, rewards, re-orders | done | 85 | decor_sources_test, decor_test, econ_check | C10b P1: Tess (new villager, Delve art reused, letter day 3, heart perks), Marlene/Deuce/Specs/Halo counters, rotation bug fixed (shelves really change), 10% re-order fee, price ladder, sink sim. Open: Lumi commissions, villager decor requests |
| Systems | Wardrobe and apparel on every hero (cosmetic slots, no stats, hats/face pins on all 16 drawn heroes, capes, sets, dresser, co-op look sync) | done | 82 | wardrobe_test, phone_ui_test, coop_test | C10b P5: one catalogue with decor ids (old saves migrated), drawn heroes show hats and face pieces, capes on every hero, wear sets claimable. Open: apparel sit/ride redraws, knit scarves icon-only |
| Systems | Yard and farm decorating: 169 outdoor pieces (paths, lamps, planters, fences, statues, fountains, seasonal, gangster yard), decorate mode outdoors | done | 80 | decor_mode_test, farm_debris_test, coop_test | C10b P1/P2/P6: Decorate yard button + Plans board, blocked cells (soil, buildings, exits, river), drag-to-paint paths, winter twins, co-op deltas; pieces on a new building site go back to the box. Open: keyed-by-cell storage, villager decor requests |
| Systems | Decorate mode indoors (grid ghost, rotate, move, store, undo, per-room wallpaper/flooring, glow pieces, co-op guest rules) | done | 80 | decor_mode_test | C10a P2. House and owned interiors only; exteriors/farm are C10b. Placed decor not yet in a texture atlas (draw calls). |
| Systems | Long-run progression and balance (3-year pacing, year 2-3 unlocks) | rough | 50 | first_week_test | Tom: CONDUCT 16 |
| Systems | Seasonal content (festivals, holidays, seasonal items/quests per season, year-2+ events) | rough | 45 | none | Tom: CONDUCT 15 |
| Systems | Helper automation: overnight chores (water, harvest, feed, pet, forage to chests) for pup, team animals, crew, partners and Farm Hands; energy, levels | rough | 45 | team_animals_test | C11a P4: Chores (scripts/helpers.gd) + gen_helpers.py, Chores page, opens day 8, morning report lines. Full automation (combat, more chores) in C11b |
| Systems | Earned fast travel network (mine carts, ferries, trains, planes, clouds, cars/subway, currents) | missing | 10 |  | Tom 17:39; mega hub vehicles exist; built in C14, paced C16 |
| Systems | Trading cards (packs, binder, regional sets, trading with NPCs/players, card game) | missing | 0 |  | Tom 17:21; CONDUCT 19 |
| Systems | The General Store side arc | missing | 0 |  | CONDUCT 21 |
| World | Mines: 26 layouts, chunks, pup in mines, Hollow Heart | done | 92 | mine_test, mine_keeper_test, c8_p4_test | C2: 35 varied guardian encounters, varied wake pace, route-following arrow, reliable crates/barrels, tools 30% of sword in fights; C8 P4: Mining curve (PICK_SWING, smooth rock hp, gem chance), early floors lighter |
| World | Valley maps: farm, town, beach, mountain, forest, lake, meadow, crystal meadow, outskirts, community farm | done | 90 | reach_test (not in check.sh), exit_check, exit_edge_check, door_check, invisible_walls | Sun Haven openness via WorldGen |
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

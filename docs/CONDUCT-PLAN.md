# CONDUCT ×9 plan (3 waves of 3, 5 h apart)

Every CONDUCT has the same steps:
1. A 20-agent audit, scoped to that run's focus.
2. A 20-bot playtest (`tools/bots.sh 3 DIR`, plus focused bot scripts).
3. Every fix Claude can do alone.
4. Art prompt files for anything still needed (made with the image tool, then wired in).
5. A full guide of what Claude needs from Tom.

The 20 audit agents in each run:
- 14 on the run's focus;
- 4 regression agents on the previous runs' areas;
- 1 performance agent on the phone and web build;
- 1 progress-inventory agent.

## Wave 1 — new systems and first hours (right after the Round 13 merge)
1. **C1 · New-player first 3 hours, both arcs.**
   - Intro, tutorials and goal line.
   - Gating of campaigns and the rec centre.
   - Money, cash and crystal wording.
   - Pacing, softlocks, clarity on a phone screen.
   - Bots: fresh saves in both arcs, days 1–5.
2. **C2 · Recreation centre, arcade and community farm.**
   - Mini-game feel and difficulty curves.
   - Ticket economy, prize tiers, NPC hub schedules and dialogue.
   - Community farm quest line and saves.
   - Touch input on every full-screen UI.
3. **C3 · Battle campaigns and the battlefront.**
   - Tutorials and briefings, gating thresholds, length per tier.
   - Balance by simulation.
   - HUD readability, ally AI, rewards, and the story-region timing tests.

## Wave 2 — the world (5 h after wave 1)
4. **C4 · Mega regions.**
   - The 10 regions, unlocks, map tabs and travel.
   - Area reachability, enemy tiers, bosses, forage, music, hub NPCs.
   - Use the Round 12 edge and texture kits so every region looks distinct.
5. **C5 · Home world look and feel.**
   - Buildings: proportions, doors and messages, night windows.
   - Lighting (sunrise, night), weather, edges and seams.
   - Animals, penguin and NPC animation, pulsing or square-edged props.
   - Screenshot sweep of every map.
6. **C6 · Audio and music, end to end.**
   - Music on every map in both arcs, including the web streaming path.
   - SFX harshness, footsteps by ground type, ambience by place and time.
   - Missing cues on the new systems.

## Wave 3 — depth and polish (5 h after wave 2)
7. **C7 · Story, quests and writing.**
   - Both arcs' chapters, heart scenes, mail and board.
   - Text tone and typos; quest pointers; endings and epilogue pictures.
   - Story and dialogue tests.
8. **C8 · Economy, progression and balance.**
   - Crops, mining, fishing, crafting, skills and caps.
   - Prices, cash, tickets, energy.
   - The 30-day curve via bots, both arcs.
9. **C9 · Release readiness.**
   - Performance on phone and web: size, load time, memory.
   - Saves and migrations, co-op, settings and accessibility.
   - A crash and edge-case sweep, plus a final screenshot review of everything.
   - Finish with the fully updated artifact (full package).

## Timing
No waits (Tom 2026-11-19 16:17): run every CONDUCT back to back.

## CONDUCT 1 agent scopes (as run 2026-11-19)
01 penguin new game → end of day 2 · 02 gangster new game → end of day 2 · 03 goal line + quest pointers days 1-5 · 04 held-tool rules on every interaction · 05 gangster money words in Round 13 systems · 06 early-game gating · 07 phone UI at 270x480 · 08 softlocks and stuck spots · 09 energy, faint, pacing, money curve · 10 farming first week · 11 town first visits · 12 pup intro, early combat, first mine floors · 13 saves, slots, migration · 14 arc choice + arc systems intros · 15 regression rec/bowling/arcade · 16 regression community farm + world fixes · 17 regression animation/audio · 18 regression mega regions + campaigns · 19 performance phone/web · 20 progress inventory (docs only).


## CONDUCT 10 — Decor and cosmetics ecosystem (Tom, 2026-11-19 13:46)

Runs after CONDUCT 9 (then the final package and artifact). Goal: make the game appealing on another level with an extraordinarily large, progressive collection.
- Categories: furniture, wall art, decor, wallpaper, flooring, house exterior styles (siding, roofs, doors, windows, fences), outdoor and farm decor (paths, lamps, planters, statues, fountains), apparel (hats, tops, bottoms, outfits, accessories) and footwear; both arcs get their own flavour (penguin whimsy; gangster underworld/cyberpunk, all-ages).
- Sources: shops (tiered by progress), crafting stations, quests and heart perks, festivals, the rec prize counter, mines/regions/mega regions loot and secrets, bosses, collections, rare world finds.
- Rarity: common, uncommon, rare, epic, legendary, mythic, and unique one-of-a-kind items (only one in the game); drop/price curves to match.
- The auditors' job: identify every place in the game the need can be filled and how it should plug into existing systems (house/interior placement, farm placement, wardrobe/character sheet, shops, quests, loot tables, saves), then the fix agents build it with art from the image tool, a catalog/collection screen, tests, and save migration.


## CONDUCT 11 — Ranching and livestock ecosystem (Tom, 2026-11-19 14:05)

Runs after CONDUCT 10 (then the final package and artifact). Goal: a massively sophisticated, progressively tiered ranching system, seamlessly part of the game.
- Classic: chickens and coops, cows and barns, goats, sheep, pigs, ducks, rabbits, bees; buildings upgrade by tier (coop → big coop → deluxe), feeders, incubators, auto-water, pastures and fencing.
- Exotics bought, imported or earned through quests: ostriches (ostrich eggs), Komodo dragons, and fantastic creatures from mega regions and story places (moon/space creatures, Merkitty Islands creatures, etc.); gangster arc: genetically modified creatures from the cyber/robotics side (all-ages).
- Products and processing (eggs, milk, wool, feathers, scales, exotic goods) feeding cooking, crafting, shops, quests and festivals; animal care, mood, friendship, breeding, rare variants/colours, shows/competitions.
- A full Ranching skill tree (gen_skill_trees.py) with abilities like the others; heart perks, quests, mail, villagers (Hazel, Tam, Benno...) tied in; saves migrated.
- Some raised animals can occasionally be trained to join your team as companions, like Pup (Tom 14:06): training path, fighting/helping abilities, a team slot, unified with the companion/party system.
- Art via the image tool for every creature (walk/idle/produce animations) and building; audio for each creature.


## CONDUCT 12 — Writing, story and dialogue (Tom, 2026-11-19 14:13)

A very thorough pass, after CONDUCT 11 (so it covers the decor and ranching content too), then the final package and artifact. C7's story work comes first; C12 makes all writing rich, robust, well-worded and seamless across the whole game, both arcs, start to finish.
- Every line of text: main story beats, side quests, villager dialogue (first meetings, daily, hearts, gifts, birthdays, festivals, weather, rec/commons/ranch chatter), mail, item and quest descriptions, tutorials and hints, locked-area messages, boss intros, endings.
- Cohesion: each NPC's voice is consistent; what villagers say matches the player's real progress, quests, relationships and story state (no contradictions or references to things not yet seen); storylines reference each other; both arcs feel complete and distinct (penguins from Tom's book *The Two Too Powerful Penguins*; gangster arc serious, cool, all-ages).
- Auditors read and play all writing by area/NPC/arc and cross-check continuity with a script (who mentions what, when); fix agents rewrite and fill gaps, add progression-aware variants, and add tests that check dialogue conditions match game state.


## CONDUCT 13 — Audio depth (Tom, 2026-11-19 14:27)

After CONDUCT 12. Builds on C6 (audio and music).
- Every area gets alternate soundtracks (several songs per area, rotated by time of day, weather, story state, day of week) and every season gets many alternates (spring/summer/fall/winter sets per area, both arcs), made with ACE Music.
- Full audit of every sound effect and song pairing: per quest, story beat, area, interior, event, festival, boss, minigame, UI screen; each one plays the right thing, at the right loudness, at the right moment, with no silence, clashes, repeats or wrong-arc sounds; web streaming checked.
- Tests that map every place/state to its music and every action to its sound (extending music_map_test and sfx_audit).

## CONDUCT 14 — Aesthetic quality of the world (Tom, 2026-11-19 14:27)

After CONDUCT 13, then the final package and artifact. Builds on C5 (home-world look and feel) and C4 (mega regions).
- Strictly the look and feel of the design: graphics quality (no fuzzy or mismatched art), smooth-looking edges and transitions between ground types, water and cliffs, region map layouts, natural boundaries (no boxy walls), explorability (hidden paths, vistas, secrets, reasons to wander), interesting geography (rivers, hills, caves, ruins, landmarks), lighting and colour harmony, density of detail vs Stardew/Sun Haven.
- Auditors screenshot every map in every season/time and rank problems; fix agents redraw art (image tool), reshape maps and edges, and add landmarks and secrets.


## CONDUCT 15 — Seasons (Tom, 2026-11-19 14:32)

After CONDUCT 14. Each season uniquely built out, both arcs: its own festivals, holidays and events (calendar on the board), seasonal-only items, crops, forage, fish, creatures, shop stock, decor and recipes; unique seasonal quests and story/villager events; seasonal map dressing, weather, music hooks; year-to-year variety (some events only in year 2+). Tests that each season's calendar, availability and events fire correctly.

## CONDUCT 16 — Progression and balance across the whole game (Tom, 2026-11-19 14:32)

After CONDUCT 15, then the final package and artifact. A sophisticated evaluation of pacing across every way to play (farming, ranching, mining, combat, campaigns, crafting, fishing, foraging, arcade/rec, commons, relationships, story, mega regions, decor/cosmetics, money in both arcs) so everything ties together and nothing progresses too fast.
- Unlocks of areas, regions, events, systems and big rewards take real time and effort; a deliberate spread of quick, moderate and long goals; some of the most interesting and rewarding elements only open in year 2 or 3.
- Simulate several player styles over 3 in-game years (scripted bots + spreadsheets): income, XP, unlock days, item/region access; tune gates, prices, drop rates and requirements; document the intended unlock timeline (docs/PROGRESSION.md) and add tests that guard it.


## CONDUCT 17 — Multiplayer (Tom, 2026-11-19 15:13)

After CONDUCT 16, then the final package and artifact. A full review of the whole game engine so co-op is enjoyable, smooth and seamless: every system checked for host/guest sync, saves, joining mid-session, shared vs personal progress, latency on phones.
- Some activities become real two-player (or more) experiences: challenge each other at bowling, Skee-Ball and arcade games (versus and co-op modes, shared high scores), plus co-op farming, mining, fights, campaigns and festivals where it fits. Not everything has to be multiplayer.
- When this is done, Tom sets up a ~$4/month server for the relay (server/ in the repo); Claude then writes the exact step-by-step setup in the guide and turns online co-op on, and Tom starts testing with friends.


## Game controller support (Tom, 2026-11-19 15:49-15:50)

Fully working game controller support (Xbox-layout mapping; also PlayStation, Switch Pro and generic pads through Godot's joypad mapping), single player and multiplayer, on a computer AND on a phone (a Bluetooth controller paired to Android or iPhone; the web build reads it through the browser Gamepad API).
- CONDUCT 9 (release readiness) builds it: every action mapped (move on left stick + d-pad, A use/confirm, B back/cancel, X/Y tool and item shortcuts, LB/RB toolbar, LT/RT secondary actions, Start menu, View/Back map), analog movement with deadzone, menu/grid/cursor navigation with focus highlights in every screen (inventory, chests, crafting, shops, skill trees, campaign board, arcade games, bowling aim/power, prize counter, dialogue choices), on-screen button prompts that switch between touch/keyboard/controller, rumble where supported, hot-plugging, remapping in Options; touch controls hide while a controller is in use (also on phones) and come back on a tap.
- Phone specifics: test the Gamepad API path in mobile Chrome/Safari (first button press activates it), portrait and landscape with a controller, and that the phone screen layout still works.
- CONDUCT 17 (multiplayer) checks controllers per player in co-op and versus (each player's own pad), plus local couch play if it fits.
- Tests: a headless controller test that drives every screen with simulated joypad events.

- Steam Deck (Tom 15:52): when the game is ready to publish, it must be Steam Deck compatible (aim for "Verified"): Linux build (or Proton-clean Windows build), 1280x800 landscape layout (DisplayMode wide view), all text readable at that size (min ~9 px font at 800 tall), full controller play with Steam Deck button prompts and no keyboard/mouse needed (on-screen keyboard for text entry via Steam), default controller config, suspend/resume safe, good performance at 30-60 fps on the Deck. Built in CONDUCT 9 with the controller work; checked again with the Steam build.


## CONDUCT 18 — Cutscenes (Tom, 2026-11-19 15:54)

After CONDUCT 17, then the final package and artifact. Sole purpose: cutscenes throughout the whole game, built from art imagery (image-tool story panels and staged in-engine scenes with NPCs moving and talking), with extremely well-crafted creative text.
- **Intro cutscene before the player even starts (penguin arc):** the backstory of Crystopia (spelled C-R-Y-S-T-O-P-I-A): the Dark Crystal, the corruption, what happened to Crystopia, leading into the Star Crystal landing on your farm; matching the game's genre and tone and Tom's book *The Two Too Powerful Penguins*. The gangster arc gets its own matching intro (why you are hiding out under a fake name, M., the President).
- **Placed strategically:** chapter openings and endings, key quests, boss arrivals and defeats, big achievements and openings (the Rec Center/arcade opening, the community farm's market opening, first campaign win, new mega region, house upgrades, festivals), heart events; plus quirky and funny ones tied to side quests and villagers.
- **Random-event cutscenes (Tom 15:56):** randomized scenes for events in the middle of the night (Stardew-style night events: a strange light over the farm, a visitor at the door, a crystal shard falling, critters raiding a field, a gangster-arc tail or a mysterious package...) and scenes triggered by specific side events, weather, relationships or discoveries; weighted by progress, season and arc, never repeating too often.
- Skippable (Dialogue.begin_skippable), replayable from a gallery once seen, consistent with progress and saves (play once, flags), music and sound cues per scene, phone and desktop layouts, both arcs.
- Auditors map every place a cutscene belongs and write the scripts; fix agents make the art (image tool), build the scenes and add tests.

## Added 2026-11-19 17:12 (Tom's Guide 11 answers)
- Helper automation (any recruit/helper/pup/tamed animal): assign to farming, combat, foraging, hauling; energy, work amounts, tiered levelling per skill, deposit into assigned placed chests; intuitive UI. Base built in CONDUCT 3/7 (crew/helpers), finished in CONDUCT 11 with trainable ranch animals.
- Casino side arc (gangster arc): bring a casino to town against NPC pushback, tiered expansion, hiring staff, tied to the tier system; all-ages tone with real betting allowed (Tom 20:03; supersedes chips/tickets), no drinking (wines are trade goods). Built in CONDUCT 10 (with decor/build tiers), balanced in C16.
- Exploration everywhere (hidden areas, secret passages, ways up/down) and underwater caverns on the merkitty islands: C14 (aesthetics/exploration) with island content in C7/C12.
- Story spine: Tom's book is canon for the penguin arc; Grumps = converted Crystopia crystals (+ some other creatures); Catkins' monastic guardian line; Nova's universe-of-happiness dream; gangster origin (fighting gangs, corrupted, redeemable). C7/C12 rebuild with no plot holes; C18 intro cutscene shows the Star Crystal visiting the hero.

## CONDUCT 19: Trading cards (added 2026-11-19 17:21)
An extremely sophisticated collectible card system, unified with the game's tiers:
- Cards for creatures, villagers, places, Grumps/crystals, gangster crew, bosses, items; per-region sets that unlock as regions open; rarity tiers common to one-of-a-kind (foil/alt-art/numbered); art from the image tool in a consistent card frame per arc.
- Booster packs bought in shops (prices/odds tuned in a generator with an economy check like gen_rec), plus packs earned from quests, campaigns, festivals, arcade prizes; region/seasonal packs.
- Binder/collection UI on the phone (sets, completion %, rewards for finishing sets), card shop / card counter NPC, a duplicate/dust or trade-in system.
- Trading: with villagers (each has wants/haves, heart-gated rare trades), traveling traders by region, and with other players over the co-op net layer (trade window, both confirm; works with C17 multiplayer).
- Optional card mini-game (simple, all-ages) used for friendly matches and a league ladder; ties to tiers so big sets/cards take into year 2-3 (C16 rules).
- Tests: economy check, pack odds sim, trade test (solo + net), binder UI phone audit.
Order: C3..C18, then C19, then the final package and artifact.

## Fast travel (added 2026-11-19 17:39) -> built in CONDUCT 14, paced in CONDUCT 16
Earned, organic, tiered travel network instead of teleport menus:
- Each link is a real vehicle/place you repair, build or win: mine-cart lines between mines and the valley, a rail line (Ironline ties in), ferries/boats along rivers and to the islands, a prop plane / airship from the mountain pad, cloud rides in the Sky Islands (penguin arc), getaway cars/taxis/subway for the gangster arc, merkitty current-rides underwater.
- Tiers: walk -> local shortcuts (secret passages, ladders, zip lines) -> regional lines (carts, ferries, buses) -> world lines (train, plane, clouds, airship) -> late-game instant hops at a few hubs. Each tier unlocks through quests, projects (materials + money), campaign wins or a skill node; tickets/fuel cost early, free later.
- Stations appear on the map as you build them; a ride plays a short travel scene (riding the cart, the plane over the map) and can be skipped once seen.
- Unified with exploration (C14), story gates (Campaign.blocks still applies) and progression (C16: no early shortcut that skips content). Works in co-op (host's network).

## Added 2026-11-19 18:24 -> CONDUCT 4 extra package
- Difficulty: Very easy / Easy / Default / Hard, combat and battle campaigns only (enemy HP/damage, boss HP, wave pace, ticket counts, faint penalty in fights); chosen in the new-game menu, changeable in Settings; per save slot.
- Day length: 15 / 20 / 30 / 40 real minutes per in-game day, chosen in the new-game menu (and Settings); scales the game clock only.

## Assignments confirmed 2026-11-19 18:43 (Tom)
- Dating and marriage (G-rated, Stardew-like: bouquet at 8 hearts, dates, proposal at 10, wedding, spouse moves in, spouse helps on the farm, both arcs, same- and opposite-sex options): BUILT in CONDUCT 7 (story/quests), writing deepened in CONDUCT 12.
- Quest tracker menu + corner pointer: built in CONDUCT 3 (P6, QuestTracker); polished/checked in CONDUCT 9.
- Collections (museum, shipping log, fish log, bug/forage/recipe/card logs, rewards for completion): BUILT in CONDUCT 8 (economy/progression).
- Phone vibration (haptics, setting) and save export/import (copy/paste code + file): BUILT in CONDUCT 9 (release readiness).
- CONDUCT 22 (after C21): POLISH pass tying the new systems together (economy, menus, saves, settings, HUD), then a cleanup/refactor of the two biggest code files (scripts/game_map.gd and scripts/game_state.gd) into smaller modules with no behaviour change (full tests + bots before/after).
- CONDUCT 23: ART DIRECTION pass: one consistent art direction across the whole game (palette, outline, scale, lighting, UI style), redraws where needed via the image tool.
- Then the final package and artifact.

## CONDUCT 20: Hazards, jumping and flight, lava mega region (added 2026-11-19 18:48)
Traversal and hazards, themed to Dreams, all ages, fair and readable on a phone:
- JUMP (Sun Haven-like): a jump button/gesture (A double-tap or a dedicated touch button; controller button in C9). Hop small gaps, ledges, logs and low walls; jump arcs drawn with shadow so depth reads in top-down. Tiered by progress: tier 0 short hop -> longer jump (boots/skill) -> double jump -> a brief GLIDE/FLIGHT (penguin arc: crystal wings / Nova's cape glide / cloud puff; gangster arc: grapnel swing / jet pack / rocket boots) unlocked through story, skills and gear; stamina/energy cost; never lets you skip story gates (Campaign.blocks and region gates still apply; jump-blocking walls where needed).
- HAZARDS placed with care in hazardous regions only (not the cozy farm/town): timed floor spikes (crystal spikes / steam vents), gaps and pits you jump (fall = respawn at the edge with a small HP loss, never death), rolling boulders/barrels down slopes with a clear warning lane, pouring lava falls and lava flows, crumbling platforms, swinging logs, geysers, icy slides, wind gusts on sky islands, conveyor/gear traps in clockwork areas; every hazard has a tell (shake, glow, sound) and a safe rhythm; difficulty modes (C4) soften damage; secrets reward mastery (hidden caches beyond hard jumps).
- LAVA MEGA REGION (new): a volcanic world (e.g. "Emberdeep / Cinder Crown") with its own map tab: lava rivers, obsidian bridges, ash forests, magma caves, a forge town, fire-themed creatures and Grump variants (ember grumps) / gangster magma-works; lava falls that pour on a cycle, rolling magma boulders, eruption events; story hook in both arcs, a campaign gate, side quests, unique forage/ores/recipes, music (ACE) and ambience; reached by an earned travel link (C14 fast travel).
- Embellish existing hazardous regions with themed sets: mines (rolling rocks, pits), Frostpeak (ice slides, falling icicles), Sunscorch (quicksand, sun-baked spikes), Windward (gusts, gaps between floating isles), Gloamwood (snapping roots), Ironline (rail carts), colonies' underwater caves (currents) — plus jump puzzles as exploration secrets (C14 synergy).
- Tech: Hazard nodes (spikes, boulder, lava, crumble, gust) with a shared tick on game time; jump state on Player (height, shadow, landing, coyote time, fall respawn); map cells marked gap/pit/lava; enemies and helpers path around hazards; tests: hazard_test (timings, damage, respawn), jump_test (reach per tier, gates hold), bots run hazardous maps; art via image tool (jump/glide strips for all heroes, hazards, lava region tiles/props); audio via ACE/CC0.
- MINES (Tom 18:49): hazards roll randomly into mine floors, tier-based: shallow floors rare and gentle (rolling pebbles, small pits), deeper floors more and harder (spike floors, crumbling ledges, gap jumps, rolling boulders, steam vents, lava seams in the deepest/volcanic floors); MineLayouts dressings pick a hazard set per floor (never the same set twice in a row), always with a safe route and readable tells; tested by mine_layout_stats + hazard_test.
Order: C3..C19, C20 hazards/traversal/lava, C21 The General Store side arc, C22 polish + code cleanup, C23 art direction, then the final package.

## CONDUCT 21: The General Store side arc (added 2026-11-19 18:55)
A major side arc built on Tom's real store, The General Store (Spokane, est. 1946, a full city block), fun and non-serious, both arcs, tiered like the rest of the game.
- THE STORE: a massive building in town (or its own district) that looks huge outside and IS huge inside, matching the real store's layout and departments: Toys (voted #1 toy store), Trading Cards (upstairs; card counter, card shows, play nights), Sports, Disc golf (biggest selection; a disc golf course side game in a park), Grills and outdoor cooking, Drinkware/hydration and coolers, Workwear/apparel and boots, Automotive, Hardware (a hardware store inside the store), Power equipment with a repair bench ("on the workbench in 2 days"), Airsoft (all-ages target range), Model kits and building bricks, Emergency-preparedness, seasonal aisles; plus the smaller Outpost and lakeside branch stores as later expansions. Multi-floor interior with escalator/stairs, departments as rooms, staff NPCs (invented names only; never Tom's family or real staff names).
- LOGO and ART: the store's own logo (from generalstorespokane.com, Tom's own brand) converted to pixel art with the image tool for the sign, bags, uniforms, receipts and UI; storefront and interior art in the game's style. Third-party brands are never shown: in-game equivalents with invented names.
- QUESTS (fun, light, tied to NPC routines): restock rushes, toy-demo days, a squishy-toy craze, card-pack openings and trade nights tied to C19's trading cards, a grill-off cook contest, disc golf league, tool repair jobs, winter-storm prep, back-to-school, holiday toy book catalog, the store's 80th-anniversary festival; villagers shop there on their schedules and ask for specific items; seasonal sales (C15).
- UPGRADES (tiered): help the store grow: reopen the upstairs card department and expand it into a full card hall, add departments, build the parking lot/garden center, open the Outpost and lakeside branches, a delivery van route (ties to fast travel C14), an employee crew you hire and level (ties to helper automation C11); each tier unlocks stock, perks and cosmetics (C10 decor).
- ECONOMY: a store-credit/loyalty card, wholesale buying for your farm goods (the store buys your crops/crafts for its shelves), gift cards as gifts; numbers in a generator with an economy check; both arcs (gangster arc: a family store under pressure from the gangs, protection-racket plot you resolve the right way; penguin arc: the cozy heart of town).
- Tests: store_test (departments reachable, quests, upgrades, economy), phone UI audit of every store screen, bots walk the store. Art via image tool; music: an upbeat in-store song (ACE).

## Split build-from-scratch runs (Tom 20:18, OPTIMIZE CONDUCT)
Each half is a full CONDUCT (20 auditors, 5-6 fix packages, CI check + 20 bots, full package):
- C10a decor/cosmetics: the item catalogue, rarity tiers, shops/rewards/drops, placing furniture/wallpaper/flooring indoors, apparel and footwear (wardrobe), data generator + tests.
- C10b decor/cosmetics: house exteriors and outdoor/farm decor placement, the casino side arc (gangster; real gambling allowed), decor in quests/festivals/collections, art for the whole catalogue, balance.
- C11a ranching: classic animals (coops, barns, care, products, breeding, babies), pens/fences, animal skill tree, hay/feed economy, trainable team animals (with C3 helpers), helper automation base.
- C11b ranching: exotics and fantastic creatures (ostrich, Komodo, space and Merkitty Islands creatures; gangster genetically modified ones), quest-earned animals, ranch buildings tiers, helper automation full (assign to farm/combat/forage/chests, levels, energy), balance + art.
- C18a cutscenes: cutscene engine (art panels, staged NPC scenes, skip), the Crystopia intro (Star Crystal visits the hero), main-story beats both arcs.
- C18b cutscenes: random night events, side-event and quirky side-quest scenes, big openings (rec, casino, General Store), polish + art.
Queue: C5, C6, C7, C8, C9, C10a, C10b, C11a, C11b, C12, C13, C14, C15, C16, C17, C18a, C18b, C19, C20, C21, C22, C23, then the final package.

## CONDUCT timing (Tom 20:18)
Every report carries a timing table (audit, sort, fix, merge+CI, package, total, gap since the last CONDUCT ended); the progress sheet has a Timing tab. Target about 1.5-2 h between finished CONDUCTs (Tom 20:22: ideally ~1.5 h all in).

## Added 2026-11-19 22:27-22:37 (Tom)
- C6 extra package P7 (Tom's phone playtest): early mining/harvesting much slower (work for it, faster with tool tiers/skills); watering can holds water and must be refilled at water (capacity grows with tiers); "planted seeds" toast no longer sticks at the top; the pup's Pack option only shows once you own a pack; inventory drag and drop; sorting options matching Stardew exactly (sort by type/name/value, auto-stack to chests, organise, trash slot, shift-move between bag and chest). Deeper pacing check in C8.
- C11b: complete review of team, allies, crew, companions and pup: every command, menu, follow/guard/fight, pack, digging, sniffing, swimming, battle team, helpers; seamless, intuitive, works as intended.
- C14: the town expanded and embellished; the beach region much larger with an expansive tier-based marina (dock upgrades, boats, marina NPCs who work, sell and trade, quests, boat passage to other regions as earned travel, fishing charters), tied into the unified engine (shops, quests, travel tiers, fishing, festivals).


## CONDUCT S1: Steam prep, no account needed (Tom, 2026-11-20 15:58) - runs NEXT after CONDUCT 11 (C11b) finishes

Tom's spec, verbatim:

NEW CONDUCT: S1, STEAM PREP (NO ACCOUNT NEEDED) (Tom, 2026-11-20 15:58). Add it to docs/CONDUCT-PLAN.md and run it NEXT, right after the CONDUCT in progress finishes (don't interrupt current work). Same CONDUCT process and package as always. Do it all yourself; never ask me to do anything on a computer or website. My Steamworks account comes later; everything needing it gets staged and listed, not skipped.

GOAL: Dreams is Steam-ready as far as possible without the account. Steam builds, Steam Deck Verified readiness, GodotSteam working in code with Valve's test app (480, Spacewar), achievements/cloud/rich presence wired behind a backend switch, an upload pipeline staged, and store materials drafted. The web build must keep working exactly as now.

1. STEAM BUILDS: add Windows x64 and Linux x64 export presets. A CI job builds both on every post-merge run and records sizes, the first-launch time and a headless boot test, then uploads them as CI artifacts (not committed). Web stays the default deploy. Never ship steam_appid.txt (dev/test only).

2. GODOTSTEAM: add the GodotSteam GDExtension for Godot 4.4+ (MIT) for desktop only. It's hosted on Codeberg; if the sandbox can't download it, fetch it in a CI job and commit the addon from there. Wrap it in a SteamService autoload: if Steam isn't present (web, CI, no client), every call is a safe no-op and the game runs unchanged. Test app 480 is for dev only. Add tests proving the game boots and plays with Steam absent, and that the web export excludes the addon.

3. BACKENDS BEHIND ONE SWITCH (local now, Steam later):
- Achievements: design about 40-60 across both arcs and every system (first harvest, hearts, campaigns, arcade, community farm, collections, secrets). Write data/achievements.json (id, name, description, hidden flag, icon prompt, stat if progress-based). Unlock locally now (title-screen list); the same calls go to Steam when the backend is on. Make the icons through the art lane within the image budget.
- Cloud saves: saves stay small and in user://. Document each OS's exact save path and the Steam Auto-Cloud settings to enter later (docs/STEAM.md).
- Rich presence: short strings per activity (farming, in the mines, at the arcade, in co-op).
- Co-op: plan the Steam transport (GodotSteam lobbies + Steam networking) behind the existing NetTransport. Build it to work with 480 where possible; the relay stays the web/phone transport.

4. STEAM DECK VERIFIED READINESS (builds on C9): at 1280x800 every screen is readable (minimum text size check by script on screenshots), full controller play with no mouse or keyboard needed, Deck/Xbox button glyphs when a pad is used (keyboard prompts hidden), Steam's on-screen keyboard for text fields (ShowFloatingGamepadTextInput / ShowGamepadTextInput via GodotSteam, with the existing input as fallback), a draft default controller configuration file, Linux build runs, performance target at 1280x800. Write a checklist against Valve's Deck criteria in docs/STEAM.md with pass/fail per item.

5. UPLOAD PIPELINE (staged, disabled): steam/ folder with app_build/depot .vdf templates (Windows and Linux depots, content roots, exclusions) and a disabled CI job for steamcmd uploads to a beta branch. It turns on when the App ID and a dedicated limited "builder" Steam account exist. Document exactly what's needed from Tom's Steamworks session (App ID, depot IDs, builder account added to the app with build permissions only, how its login is stored as GitHub secrets without Tom pasting into chat).

6. STORE MATERIALS (drafts in docs/steam-store/, working title "Dreams (working title)"):
- Short description (Steam's limit), long description, feature bullets, tags and genre research versus comparable cozy farming games, a price-point comparison, and system requirements from measured numbers.
- Content descriptor and IARC questionnaire draft answers based on the real game (gun sounds, gangster arc, combat), and the AI disclosure draft: pre-generated art (dreams-image/OpenAI), music (ACE Music), Claude-written code and text, no live AI in the game.
- Capsule art plan and drafts at the required sizes: header 920x430, small 462x174, main 1232x706, vertical 748x896, library capsule 600x900, library header 920x430, library hero 3840x1240 (no text), library logo (transparent PNG, title only), app icon 184x184. Follow Valve's graphical asset rules (title only, no review quotes or other text). Use the art lane and image budget; consistent style, logo readable at small size.
- 5+ screenshots at 1920x1080 picked from scripted shots, and a 30-60 s trailer shot list and script.

7. NAME CHECK: "Dreams" is also a well-known PlayStation game (Media Molecule/Sony). Research name conflicts (Steam store search, trademark-style web search) and propose 5-8 alternative titles that fit the book and both arcs, each with a quick conflict check. I decide; keep the working title until then.

8. STEAMWORKS HANDOFF: docs/STEAM.md ends with "When Tom's Steamworks account is ready": an ordered list of every setting to enter (app name, Auto-Cloud paths, achievements upload from data/achievements.json, rich presence tokens, controller config, depots, builder account, store page fields from the drafts, pricing, release-date gating: the fee-to-release wait and two weeks visible as "coming soon"). It becomes a Chrome brief I can run in one session.

PACKAGE: the usual package, plus docs/STEAM.md as an artifact page and a Steam readiness % (done / staged-waiting-on-account / not started) in the progress sheet. Update HANDOFF (Baton + a Steam row), PROJECT-MEMORY and CLAUDE.md (one line per new tool), push, then continue the queue.

## Multiplayer relay is live (Tom, 2026-11-20 15:54)

Live relay: wss://dreams-64-23-239-63.sslip.io (health https://dreams-64-23-239-63.sslip.io answers "dreams relay ok"). Auto-deploys server/ from main every 10 min, so server/ changes must pass tools/relay_test.js first. CONDUCT 17 tests against this live relay (phone-like latency, a host whose screen locks, reconnect) using real numbers from the live CI check. Steam alignment: keep the NetTransport abstraction; the relay stays the web/phone transport; a Steam transport (GodotSteam lobbies + Steam networking) is added in the Steam CONDUCT after Tom's Steamworks setup (S1 plans it and builds it against test app 480 where possible).

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
- Casino side arc (gangster arc): bring a casino to town against NPC pushback, tiered expansion, hiring staff, tied to the tier system; all-ages (chips/tickets). Built in CONDUCT 10 (with decor/build tiers), balanced in C16.
- Exploration everywhere (hidden areas, secret passages, ways up/down) and underwater caverns on the merkitty islands: C14 (aesthetics/exploration) with island content in C7/C12.
- Story spine: Tom's book is canon for the penguin arc; Grumps = converted Crystopia crystals (+ some other creatures); Catkins' monastic guardian line; Nova's universe-of-happiness dream; gangster origin (fighting gangs, corrupted, redeemable). C7/C12 rebuild with no plot holes; C18 intro cutscene shows the Star Crystal visiting the hero.

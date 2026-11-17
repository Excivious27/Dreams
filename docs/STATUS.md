# Dreams: Status

**Play:** https://excivious27.github.io/Dreams/

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

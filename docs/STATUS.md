# Dreams: Status

**Play:** https://excivious27.github.io/Dreams/

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

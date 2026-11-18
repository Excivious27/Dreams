# Dreams — Art Prompts 19: clean edges everywhere, interiors, and the last stand-ins

WHAT THIS COVERS, most important first: (1) water edges: rivers, ponds, lakes, the beach, bog and cave water, (2) ground-to-ground edges: grass to sand, dirt, snow, dead grass and mud, (3) cliffs and stairs that fit every material, (4) paths and paving, (5) the farm (tilled soil, pond bank, fences), (6) house and shop interiors (floors, walls, trim, rugs), (7) colony and special places (moon, crystal meadow, battles), (8) the last stand-ins: gangster walk cycles, enemy attacks, partner ability effects, ore nodes, icons.

RULES THAT APPLY TO EVERY IMAGE: 1536×1024, 16-bit pixel art, clean 1px dark outlines on objects (never on ground textures), warm saturated Stardew Valley / Sun Haven palette, flat #FF00FF magenta background unless the batch says otherwise, NO GRID LINES, NO TEXT OR LABELS OR NUMBERS anywhere, no watermark, NO LETTERBOXING. At least 16 px of clear magenta between separate pieces. All ages: no blood, nothing gory. Ground is seen from straight above with soft light from the top-left.

SEAMLESS RULE: a seamless square must tile with no visible edge when copied side by side in every direction: no border, no vignette, no lighter or darker rim, no shadow on one side, no single big feature that repeats obviously (small details only, spread evenly). Squares are 256×256, 5 per row, x = 24 + N×304, y = 24 + M×304.

BLOB RULE (for every "16-piece edge set"): the set shows how material A (the inside) meets material B (the outside) on a 64×64 cell grid, cells at x = 24 + N×88, y = 24 + M×88. Row 0, in this order: OUTER CORNER top-left, TOP EDGE, OUTER CORNER top-right, INNER CORNER top-left, INNER CORNER top-right, FULL A (seamless), FULL B (seamless), then a second TOP EDGE variation. Row 1: LEFT EDGE, (empty), RIGHT EDGE, INNER CORNER bottom-left, INNER CORNER bottom-right, then two more FULL A variations. Row 2: OUTER CORNER bottom-left, BOTTOM EDGE, OUTER CORNER bottom-right, then a second LEFT, RIGHT and BOTTOM EDGE variation. Edges are wobbly and natural (never a straight ruler line), and every piece lines up with its neighbours with no seam. Where it says "overlay", material B is left as magenta (only the edge and A are painted) so the set can be drawn on top of any ground.

---

## BATCH 1 — Rivers and streams (3 images)

The town river and forest streams still show straight blocky banks. These let the game draw a soft, wobbly bank with reeds and stones all the way along.

> IMAGE "w380_river_bank_overlay.png": RIVER BANK, a 16-piece edge set by the BLOB RULE as an OVERLAY: A is clear river water (blue-green, small ripples, slightly darker at the deep middle), B is magenta. The bank between them is a strip of wet dark earth with small pebbles and a thin light foam line at the waterline, about 12 px wide. Below the set, at y = 300, a second full set for WINTER (the water edge is a rim of thin ice, the bank has snow on it).

> IMAGE "w381_river_flow_seamless.png": RIVER WATER that flows, by the SEAMLESS RULE: row 0: river water ×4 frames of animation (ripples move DOWN the square, so it loops), shallow river water ×1; row 1: deep river water ×4 frames, river water at night ×1 (darker, moon-blue glints). Each frame tiles with itself and the four frames loop smoothly.

> IMAGE "w382_river_dressing.png": THINGS THAT LINE A RIVER, each isolated on magenta in 64×64 cells (x = 24 + N×88, y = 24 + M×88): reeds ×4 (tall green, gently leaning), cattails ×3, water lilies with a flower ×3 and without ×3, mossy river stones ×6 (half under water, a ripple ring around each), a fallen log across shallow water ×2, a little wooden footbridge plank end ×2, a foam swirl ×4 frames, small fish shadow ×2, a dragonfly ×4 frames. Then BRIDGE ENDS 128×64 ×4 (where a stone or wooden bridge meets the bank on each side: left, right, top, bottom).

---

## BATCH 2 — Ponds and lakes (2 images)

> IMAGE "w383_pond_shore_overlay.png": POND AND LAKE SHORE, two 16-piece edge sets by the BLOB RULE as OVERLAYS. Set 1 at the top: A is calm pond water (slightly greener than the river, tiny lily pads drawn only in the FULL pieces), the shore is a soft band of short grass ending in dark mud and a few pebbles. Set 2 starting at y = 300: A is LAKE water (deeper blue), the shore is a pale pebble beach about 16 px wide.

> IMAGE "w384_pond_extras.png": POND EXTRAS: a WINTER frozen pond 16-piece set by the BLOB RULE (pale blue ice with white cracks and snow drifted along the shore) in the top half; then, isolated in 64×64 cells, a duck ×2, ripple rings ×4 frames, a little wooden dock end 64×96 ×2, a fishing spot sparkle ×4 frames, reeds in snow ×3.

---

## BATCH 3 — The beach, done seamless (3 images)

The beach got much better; what's left is the sand-to-sea line and the grass-to-sand line, which still show tile edges.

> IMAGE "w385_sand_sea_overlay.png": SAND MEETS SEA, a 16-piece edge set by the BLOB RULE as an OVERLAY: A is shallow turquoise sea water with light sun glints, the edge is wet dark sand with a white lacy foam line. Draw the whole set TWICE: the top set as foam frame 1, the second set (starting at y = 300) as foam frame 2 where the foam line has moved slightly, so the two frames make the waves lap. Then a third row of SEAMLESS 128×128 squares: dry sand, wet sand, sand with shells, sand with seaweed.

> IMAGE "w386_grass_sand_blob.png": GRASS MEETS SAND, a 16-piece edge set by the BLOB RULE: A is beach sand, B is summer grass, the edge is grass thinning into sand with little tufts and a few shells. Then (at y = 300) the same set for GRASS MEETS WET SAND (darker sand, a few puddles).

> IMAGE "w387_beach_rocks.png": BEACH ROCKS AND POOLS, isolated on magenta: a CLIFF FOOT where a low rock cliff meets the sea, 6 pieces 96×96 (left end, middle ×3, right end, corner) with foam at the bottom; TIDEPOOL rims ×4 (a ring of rocks around a small blue pool with a starfish, 96×80); rocks half in the water ×6 (64×64) with a foam ring; a washed-up driftwood log ×2; a sandcastle ×2.

---

## BATCH 4 — Grass to dirt, dead grass and mud (3 images)

> IMAGE "w388_grass_dirt_blob.png": GRASS MEETS DIRT, a 16-piece edge set by the BLOB RULE: A is packed brown dirt, B is summer grass, the edge is ragged grass blades over the dirt with a few pebbles. Below it (y = 300) the same set in AUTUMN colours.

> IMAGE "w389_grass_deadgrass_blob.png": GRASS MEETS DRY GRASS, a 16-piece edge set by the BLOB RULE: A is dry yellow-brown grass, B is green grass, the edge is a soft mix of both. Below it (y = 300): GRASS MEETS MUD, A is dark wet mud with puddles, B is grass.

> IMAGE "w390_edge_fringe_decals.png": EDGE DECALS that hide any seam, isolated on magenta in 48×48 cells (x = 24 + N×72, y = 24 + M×72), 48 pieces: grass tufts ×8, clover patches ×4, small flowers (white, yellow, purple, pink) ×8, pebble clusters ×6, fallen leaves ×6 (3 autumn, 3 summer), twigs ×4, mushrooms tiny ×4, sand ripples ×4, snow tufts ×4.

---

## BATCH 5 — Snow, ice and winter ground (3 images)

> IMAGE "w391_grass_snow_blob.png": GRASS MEETS SNOW, a 16-piece edge set by the BLOB RULE: A is soft white snow with faint blue shadows, B is winter grass (dull green-brown), the edge is snow thinning into patches. Below it (y = 300): SNOW MEETS OPEN WATER as an OVERLAY (A is dark cold water, the edge is a snowy bank with a rim of thin ice).

> IMAGE "w392_winter_seamless.png": WINTER SEAMLESS squares by the SEAMLESS RULE: snow (smooth), snow (trodden, footprints), packed snow, ice, frozen dirt, frosty grass, snow on paving, slush. Then a SNOW PLATEAU TOP edge row: 64×64 pieces of a raised snowy shelf seen from above (left end, middle ×2, right end, corner ×2).

> IMAGE "w393_snow_sea_shelf.png": SNOW MEETS SEA (the frozen coast), a 16-piece edge set by the BLOB RULE as an OVERLAY: A is icy blue sea with floating ice chunks, the edge is a snow shelf with an icy blue cliff face 8 px tall. Then isolated: ice floes ×4 (64×48), a seal-shaped rock ×2, icicle fringe strips 96×24 ×3.

---

## BATCH 6 — Bog and marsh (2 images)

> IMAGE "w394_bog_water_overlay.png": BOG WATER, a 16-piece edge set by the BLOB RULE as an OVERLAY: A is murky brown-green bog water with a few bubbles and duckweed specks, the edge is soft black mud with reeds poking out. Below it (y = 300): GRASS MEETS BOG MUD (A is squelchy dark mud with footprints, B is marsh grass).

> IMAGE "w395_marsh_kit.png": MARSH KIT, isolated on magenta: tall marsh grass clumps ×6 (64×80), a rotten stump in water ×2, lily pads with frogs ×3, bubbles ×4 frames, mist puffs ×4 (soft white, semi-transparent looking), a wooden boardwalk: straight ×2, end ×2, corner ×2, crossing ×1 (each 64×64, planks running both ways).

---

## BATCH 7 — Caves and mines (3 images)

The mines are much better now; the last thing is water, lava and chasm edges inside caves, and walls that curve.

> IMAGE "w396_cave_water_edges.png": CAVE WATER, a 16-piece edge set by the BLOB RULE as an OVERLAY: A is dark underground water with faint teal glints, the edge is wet black stone. Below it (y = 300): CAVE LAVA as an OVERLAY (A is glowing orange lava with dark crust, the edge is cooled black rock with a red glow).

> IMAGE "w397_cave_chasm_ice.png": CAVE CHASM, a 16-piece edge set by the BLOB RULE as an OVERLAY: A is a black bottomless drop, the edge is a crumbling stone lip with a little rubble. Below it (y = 300): CAVE ICE (A is slick frozen floor with cracks, B is cave stone).

> IMAGE "w398_cave_walls.png": CAVE WALL tops seen from above (where the open floor meets solid rock), in FIVE kinds, one per row, each row: outer corner ×4, straight edge ×4 (N, S, E, W), inner corner ×4, filled rock ×2, in 64×64 cells. Row 0 earthy brown rock, row 1 grey stone, row 2 blue crystal rock, row 3 dark purple void rock, row 4 icy rock. The south-facing edge shows a short rock face (about 20 px) so walls look like they have height.

---

## BATCH 8 — Cliffs and stairs for every material (3 images)

> IMAGE "w399_cliffkit_grass.png": GRASS CLIFF KIT, 64×64 cells: the top of a grassy cliff seen from above with the rock face below it. Row 0: top edge ×3, top outer corners ×2, top inner corners ×2, end caps ×2. Row 1: rock face (the vertical side) ×3, face corners ×2, face meeting ground ×3. Row 2: STAIRS cut into the cliff: stone steps ×2 widths (1 cell, 2 cells), wooden steps ×2 widths, each with the cliff on both sides. Row 3: the same top edges in SNOW.

> IMAGE "w400_cliffkit_sand_stone.png": SAND CLIFF KIT (row 0–1, a pale sandstone cliff with the same pieces as the grass kit) and DARK STONE CLIFF KIT (rows 2–3, grey mountain rock). Row 4: stairs for each (stone ×2 widths).

> IMAGE "w401_cliff_crystal_iron.png": CRYSTAL CLIFF KIT (rows 0–1: blue crystal rock with glowing seams) and IRON CLIFF KIT (rows 2–3: rusty iron-grey rock for the gangster arc). Row 4: stairs for each and a ladder 32×96 for each.

---

## BATCH 9 — Paths and paving (3 images)

> IMAGE "w402_path_dirt_dualgrid.png": DIRT PATH, a 16-piece edge set by the BLOB RULE as an OVERLAY (A is a worn dirt footpath with small stones, the edge is grass blades leaning over it). Then a second set (y = 300) for a GRAVEL path. Path ends: 4 pieces where a path fades out into grass, one per direction.

> IMAGE "w403_paving_seamless.png": PAVING by the SEAMLESS RULE: cobblestone (grey), cobblestone (warm), brick (herringbone), flagstone, plaza tiles, wooden boardwalk, cracked old stone, city pavement (gangster arc), asphalt road (gangster arc), mossy cobble. Then a row of 64×64 pieces: a PLAZA RING (a round border of stone, 4 quarter pieces), and 4 PATH MOUTHS (where a dirt path joins cobble).

> IMAGE "w404_paving_edges.png": GRASS OVER PAVING, a 16-piece edge set by the BLOB RULE as an OVERLAY (A is cobblestone, the edge is grass and moss creeping over the stones). Then (y = 300) CURB AND ROAD as an OVERLAY (A is asphalt, the edge is a light concrete kerb, gangster arc). Then door APRONS ×4 (a half-round of cobble in front of a door, 96×48).

---

## BATCH 10 — The farm (3 images)

> IMAGE "w405_tilled_soil_blob.png": TILLED SOIL, a 16-piece edge set by the BLOB RULE as an OVERLAY: A is dark brown tilled soil with neat furrows, the edge is a soft raised lip of loose earth. Draw it TWICE: dry (top), wet (y = 300, darker and shinier, NOT blue). Then decals 32×32: a seed hole ×2, a watered sparkle ×2, a weed sprout ×2, a fertiliser speckle ×2.

> IMAGE "w406_farm_pond_fence.png": FARM POND BANK, a 16-piece edge set by the BLOB RULE as an OVERLAY (A is the farm pond's water, the bank is grass with a few stones and one cattail). Then a PEN FENCE KIT of wooden fence pieces (64×64): horizontal ×2, vertical ×2, corners ×4, gate closed, gate open, end posts ×2.

> IMAGE "w407_yard_kit.png": FARM YARD bits, isolated on magenta: a hay pile ×3, a water trough ×2, a feed bucket, a chopping block with an axe, a wheelbarrow, a stack of firewood ×2, a scarecrow (new design), a greenhouse plot border (4 corners, 4 edges in 64×64), a little stone well (smaller than the main well), flower boxes ×4.

---

## BATCH 11 — Interiors: floors, walls and trim (3 images)

House and shop insides look bare and blocky. These give every room a proper floor, walls with height, skirting, windows and doorways.

> IMAGE "w408_interior_floors.png": FLOORS by the SEAMLESS RULE, 15 squares: oak planks, dark planks, light planks, worn planks, stone tiles, checker tiles (black and cream), terracotta, herringbone parquet, cottage flagstone, clinic tiles (white and pale blue), bakery tiles (warm cream), smithy stone (sooty), shop boards (polished), straw-strewn barn floor, rich carpet (deep red).

> IMAGE "w409_interior_walls.png": WALLS AND TRIM, 64×64 cells, each row one wall style: row 0 wallpaper (cream with small flowers), row 1 wood panelling, row 2 plaster with beams (cottage), row 3 stone (smithy), row 4 painted brick (shop), row 5 tiled (clinic). For each style: wall face ×3 (seen from the front, about 48 px tall above a skirting board), wall with a WINDOW, wall with a SHELF, wall with a PICTURE, left side wall, right side wall, corner ×2, a DOORWAY (open, with a threshold step and a mat on the floor).

> IMAGE "w410_rugs_and_props.png": RUGS AND ROOM PROPS, isolated on magenta: rugs seen from above, round ×3 (64, 96, 128 px) and long ×3 (128×64), patterned in warm colours; a fireplace 96×96 ×4 frames of fire; a bed (single, double); a table with two chairs; a bookcase ×2; a cupboard; a potted plant ×4; a wall clock; a counter with a till (shop); a hanging lamp ×2 frames; a coat stand; a bathtub. All sized to fit a room of 16 px floor cells at the game's scale (a bed is about 32×48).

---

## BATCH 12 — Colonies, moon and special places (3 images)

> IMAGE "w411_colony_shores.png": COLONY SHORES, four 16-piece edge sets by the BLOB RULE as OVERLAYS, two per half of the image: CORAL (pink coral sand into clear tropical water), KELP (dark sand into green kelp water), ICE (snow into icy water), EMBER (ash into glowing lava).

> IMAGE "w412_special_seamless.png": SPECIAL GROUND by the SEAMLESS RULE: moon dust, moon crater field, cloud top (for the sky stair), crystal meadow glow grass, pale stone, ash, frost ground, coral sand, pier concrete, deep lake. Then MOON RIM pieces 64×64: the edge where the moon's ground ends in black space with stars (top, bottom, left, right, 4 outer corners, 4 inner corners).

> IMAGE "w413_battle_ground.png": BATTLEFIELD GROUND by the SEAMLESS RULE: rail ballast (grey gravel), dock concrete, packed snow (trampled), dark scorched earth, muddy field; then a RAIL TRACK kit 64×64: straight ×2 (both ways), curve ×4, crossing, buffer stop ×2.

---

## BATCH 13 — Gangster arc walk cycles (3 images)

The crew fighters and thugs still slide around in one pose. Each needs its walk.

> IMAGE "w414_thug_walks_a.png": THREE THUGS on the GRID RULE (attach the existing thug sheets), each two rows: row A IDLE down ×2, up ×2, side ×2, WALK down ×4, up ×4, side ×2; row B WALK side ×2 more, ATTACK side ×4, HURT ×2, KNOCKED OUT ×2 (sitting dazed with stars, no injury). (1) THE CYBER THUG (chrome arm, visor), (2) THE BRUTE (huge, rolled sleeves), (3) THE FLAME THUG (orange jacket, a flame-thrower-shaped glove that throws harmless sparks).

> IMAGE "w415_thug_walks_b.png": THREE MORE on the same layout: (4) THE SPEEDSTER (track suit, roller skates), (5) THE GAMBLER (waistcoat, deck of cards he throws), (6) THE ENFORCER (long coat, a stun baton). All ages: ranged attacks are cards, sparks and stun bolts, never blood.

> IMAGE "w416_president.png": THE PRESIDENT, the gangster arc's final boss, on the GRID RULE but with 96×128 cells: a tall, sharp-suited figure with a gold tie, slicked silver hair and a cane that fires bright energy bolts. Row 0: IDLE ×4, WALK ×4 (side), Row 1: ATTACK cane bolt ×4, SUMMON (raises cane, briefcase drones appear) ×4, Row 2: HURT ×2, DEFEATED ×4 (sits down on the floor, tie loosened, looking finally tired and honest; no injury). Then a 96×96 portrait in three moods (smug, angry, defeated).

---

## BATCH 14 — Enemy attacks and partner abilities (3 images)

> IMAGE "w417_enemy_attacks.png": ATTACK FRAMES for seven basic enemies, each one row of 64×64 cells: WIND-UP ×2, ATTACK ×3, RECOVER ×1. Row 0 SLIME (squash and leap), row 1 BAT (dive), row 2 HILL WOLF (lunge bite, no blood), row 3 ROCK CRAB (claw snap), row 4 WISP (flare of light), row 5 MUD SLIME (spit a mud ball, plus the ball ×2), row 6 GRUMP (stomp, with a dust ring).

> IMAGE "w418_ability_fx_a.png": PARTNER ABILITY EFFECTS, each one row of 96×96 frames ×6, on magenta, bright and readable: (1) a paw-print burst, (2) a healing leaf swirl, (3) a fish splash wave, (4) a crystal shield bubble, (5) a sleepy cloud with stars, (6) a whirlwind, (7) a seed-sprout ring, (8) a lantern flash, (9) a snowflake burst.

> IMAGE "w419_ability_fx_b.png": NINE MORE on the same layout: (10) a bubble stream, (11) a thunder clap, (12) a flower petal storm, (13) a music-note ring, (14) a rock pillar rising, (15) a heart pulse, (16) a speed-line dash, (17) a star shower, (18) a glowing net.

---

## BATCH 15 — Ore nodes, icons and the last props (3 images)

> IMAGE "w420_ore_nodes.png": ORE NODES (rocks with ore showing), 48×48 each, isolated on magenta, three variations each, one ore per row: coal, copper, iron, silver, gold, crystal shard, amethyst, emerald, fossil (a stone with a shell print), dark crystal. Same chunky style as the mine rocks: grey rock with the ore poking out in clear colour.

> IMAGE "w421_item_icons_19.png": 24 ITEM ICONS, 48×48 each, rows of 12 (x = 24 + N×120, y = 24 + M×120), same soft top-left light as the other item icons, no frames, no text. In order: 1 Crystal Bloom, 2 Strawberry Wine (a bottle), 3 Corn Ale (a mug), 4 Berry Juice, 5 Iridium Sprinkler (purple-silver), 6 Old Collar, 7 Brass Locket, 8 Knight's Shard, 9 Manifest (a rolled ship's paper), 10 Finargle Fuzz (a puff of soft fluff), 11 Sacred Key, 12 Merkitty Necklace (shells on string), 13 Sand (a little pile), 14 Colony Light (a glowing lantern), 15 Tide Pearl, 16 Ember Glass, 17 Bigger Backpack, 18 Traveller's Pack (with a bedroll), 19 Bottomless Pack (glowing stars on it), 20 Storage Chest (small), 21 Station Blueprint (a rolled blue plan), 22 Spell Scroll, 23 Speed Boots, 24 Lumberjack's Axe charm.

> IMAGE "w422_last_props.png": THE LAST PROPS, isolated on magenta: a town FOUNTAIN 128×128 ×4 frames of water; a HORSE (side, front, back ×2 frames each, 64×64) and a horse WITH SADDLE; a DIRT PUFF effect ×6 frames 32×32; a GLOWING MOTH ×4 frames 24×24; a BOSS HEALTH BAR FRAME 200×24 (ornate, empty inside) and its fill strip; a gritty CITY SKYLINE strip 512×128 (gangster arc, dark purple with lit windows); a SPACE SKY strip 512×128 (stars and a far planet); BOT props (a small helper robot ×4 frames, a drone ×4 frames, a charging pad).

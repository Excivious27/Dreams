# Art prompts: THE WORLD (regions, backgrounds, tiles)

This sheet exists to make the world big. Every prompt here produces ground tiles,
edges, props and backdrops for one region, so each region can be a sprawling map
with its own look rather than a patch of the same grass. Do these before going
back to ART-PROMPTS-03.

**How to use.** Paste the Style block first, every prompt. One sheet per prompt.
Upload to `art/incoming/` with any name. If ChatGPT puts text on the sheet, say
"redo with no text, no labels". If a result looks painted or blurry: "redo with
crisp hard pixel edges, no anti-aliasing, no glow".

**What I need from every region** (the prompts below ask for it each time):
1. A **ground 9-slice** (3x3: corners, edges, middle) so I can draw any shape.
2. A **second ground** for paths/variation, also 9-slice.
3. **Edges to neighbours**: how this ground meets grass/water/cliff.
4. **Decoration tiles** (6 to 12 small things that sit on the ground).
5. **Props** in 3 sizes: small (1 tile), medium (2x2), large (3x4+).
6. **One landmark** per region: the thing you remember it by.
7. A **parallax backdrop strip** (wide, painted, seamless left-right) for the sky
   or distance behind the map.

## Style block (paste first, every time)

```
STYLE (must follow exactly): 2D pixel art for a cozy top-down farming RPG in the
style of 16-bit console games. 3/4 top-down view. Crisp hard pixel edges, no
anti-aliasing, no blur, no glow, no gradients, 1-pixel dark outlines. Warm
saturated palette matching a game whose characters are about 26 pixels tall and
whose tiles are 16x16. Flat solid magenta background #FF00FF. Separate cells with
thin dark-magenta #CC00CC gaps, never white or pink lines. No text, no labels, no
titles anywhere on the sheet. Original designs only: no characters, logos or art
from any existing game, show or brand.
```

For the **gangster arc** regions (section D), add after the Style block:
```
ARC STYLE: same pixel rules, grittier palette: muted browns, rust, concrete greys
and neon accents (hot pink, electric cyan). Urban-fantasy crime world, tough but
not gory.
```

---

## A. The valley (starting region, shared by both arcs)

### W1. Grass variations and ground transitions (do this first)
```
Make a 16x16 ground tileset, dark-magenta gaps: (1) short grass 9-slice, (2) tall
grass 9-slice, (3) flower meadow 9-slice, (4) dry grass 9-slice, (5) mud 9-slice,
(6) gravel 9-slice, (7) the TRANSITION edges for grass meeting dirt: top, bottom,
left, right, 4 outer corners, 4 inner corners, (8) the same 12 transition pieces
for grass meeting sand, (9) the same 12 for grass meeting stone. 12 scatter
decorations: 3 tufts, 3 flowers, pebbles, twigs, a puddle, a molehill, a
mushroom ring, a fallen log end.
```

### W2. Forest (north-west of the farm)
```
Make a FOREST region sheet: forest floor 9-slice (dark earth with roots and
leaves), a forest path 9-slice, edges where forest floor meets grass (12 pieces),
10 decorations (ferns, mushrooms, roots, moss, pine cones, fallen branches, a
toadstool ring, wildflowers, a bird nest, acorns), large oak 3 tiles wide 5 tall,
large pine 3x6, a giant hollow tree 4x6 with a door-sized hole, a willow 3x5, a
berry thicket 2x2, a fallen giant log 4x2 you can walk along, a stump with an axe,
a woodcutter's hut 4x4, a forest shrine (small stone altar with a crystal) 2x3,
a hidden pond 4x3 with lily pads, a deer 2x2, a fox 1x1, a rabbit 1x1, an owl on
a branch. LANDMARK: an enormous ancient tree 8 tiles wide 12 tall with lanterns
hanging from its branches and a staircase spiralling up its trunk.
```

### W3. River and lake (west edge of the valley)
```
Make a RIVER and LAKE sheet with 4-frame animation strips for every water piece:
river flowing down (straight, 2 variants), river bends (4), river meeting lake,
lake deep water 9-slice (animated), lake meets grass (12 edge pieces), lake meets
sand (12), a waterfall 2 tiles wide 3 tall, rapids, a stone ford (walkable
stepping stones), a wooden bridge 3 tiles wide, a stone bridge 3 wide, a dock
9-slice, a rowboat, a fishing hut on stilts 4x4, reeds, cattails, lily pads (3),
ducks (2 frames), a heron, a beaver dam 3x2, a water mill 4x5 with a turning wheel
(4 frames). LANDMARK: a lakeside lighthouse 3 wide 7 tall with a rotating beam.
```

### W4. Cliffs, hills and caves (the valley walls)
```
Make a CLIFF and HILL sheet: grassy cliff edges (top, bottom, left, right, 4 outer
corners, 4 inner corners) with brown rock faces 2 tiles tall, a 3-tile-tall
variant, cliff stairs (up/down), a dirt ramp, a rope ladder, a cave mouth 3x3
(dark), a mine entrance with a wooden frame 3x3, boulders in 3 sizes, a rockslide
pile 3x2, a mountain goat, a hawk shadow (4 frames), a lookout tower 3x6, a rope
bridge 5 tiles across a gap, a hot spring 3x3 with steam (4 frames). LANDMARK: a
mountain peak backdrop with a crystal glowing in a cleft, 12 tiles wide 8 tall.
```

### W5. Beach and sea (south-west)
```
Make a BEACH sheet: sand 9-slice, wet sand 9-slice, sand meets sea (12 animated
edge pieces, 4 frames), sea deep 9-slice (4 frames), foam line (4 frames), a tide
pool 3x3 (4 frames), 12 decorations (shells x3, starfish, seaweed, driftwood,
crab, bucket and spade, a sandcastle, footprints, a bottle, a coconut), a palm
tree 2x5, a beach hut 4x4, a pier 9-slice with posts, a beached rowboat, a
shipwreck 6x4, a buoy (2 frames), a lifeguard chair, a beach umbrella (3
colours), a bonfire (4 frames), a seagull (2 frames). LANDMARK: a wrecked
galleon half-buried in sand, 10 tiles wide 6 tall.
```

### W6. Farmland expansion (fields beyond the fence)
```
Make a FARMLAND sheet: ploughed field rows 9-slice (tall, wide furrows), wheat
field 9-slice in 3 growth stages, an orchard grid tile, a vineyard trellis
(horizontal, 3 pieces), a hay field 9-slice, a stone wall 9-slice with gate, a
hedge 9-slice with gap, farm track 9-slice, irrigation ditch (straight, corner,
end, 4 frames), a silo 3x6, a big red barn 6x6, a stable 5x4, a chicken coop
3x3, a pig pen fence, a trough, a windmill 4x7 (4 frames turning), a tractor
(old, rusty), hay bales (round, square), a farm cart, a scarecrow (2 variants),
cows (2 frames), sheep (2 frames), chickens (2 frames), a pig, a horse. LANDMARK:
a great wooden grain elevator 6 tiles wide 10 tall.
```

### W7. Town expansion (more of the village)
```
Make a TOWN EXPANSION sheet: cobblestone 9-slice (2 variants), brick road
9-slice, town square flagstones 9-slice, a low stone wall, iron fence (straight,
corner, gate), a hedge, flower beds (4 colours), street lamps (lit, unlit),
benches (2), a bandstand 5x5, a clock tower 4x9, an inn 7x6 with a hanging sign,
a bakery 5x5 with a chimney (smoke 4 frames), a clinic 5x5, a library 6x6, a
chapel 5x7, a school 6x5, a train station platform 8x4 with a small steam train
(8 tiles long), market stalls (4 colours), a cart, crates, barrels, a well, a
notice board, a mailbox, a fountain 3x3 (4 frames), a statue on a plinth 2x3,
a dog house, a bicycle, pigeons (2 frames). LANDMARK: a tall stone bell tower
with a glowing crystal at its top, 5 wide 12 tall.
```

### W8. Mines, deep
```
Make a DEEP MINE sheet: (1) rock floor 9-slice in 4 colour variants: brown earth,
grey stone, blue ice, red volcanic, (2) cave walls for each variant (top,
bottom, left, right, 4 outer corners, 4 inner corners, faces 2 tiles tall),
(3) lava floor 9-slice (4 frames), underground water 9-slice (4 frames), an ice
floor with cracks, (4) ore nodes: copper, iron, gold, silver, coal, crystal
(blue), dark crystal (purple), ruby, emerald, (5) breakable rocks in 3 sizes per
variant, (6) ladders, a mine cart on rails, rail pieces (straight, corner, end,
crossing), support beams, a wooden elevator cage 3x4, lanterns, a minecart full
of ore, a skeleton of a miner, a pickaxe stuck in a rock, (7) crystal clusters
in 4 colours, glowing mushrooms in 3 colours, stalagmites, stalactites hanging
from the top wall, bones, a treasure chest, a mine shaft hole 2x2 (dark), an
underground lake edge (12 pieces, 4 frames). LANDMARK: a huge glowing crystal
geode chamber, 10 wide 8 tall.
```

### W9. Sky, parallax backdrops and day/night (painted, not tiles)
```
Paint six seamless horizontal backdrop strips, each 1920x480, that tile left-to-
right, soft storybook style, no text: (1) daytime sky with cumulus clouds over
rolling green hills, (2) the same at sunset, orange and pink, (3) the same at
night with stars and a spiral galaxy, (4) a mountain range with snow caps, (5) a
sea horizon with distant islands, (6) a forest canopy from above. Keep the bottom
20% of each strip a flat colour so it can sit behind a map.
```

---

## B. Penguin arc regions

### W10. The crystal meadow (where the Light Crystal's power spreads)
```
Make a CRYSTAL MEADOW sheet: grass that glows faintly blue at the tips 9-slice,
a path of pale stone 9-slice, edges where glowing grass meets normal grass (12),
12 decorations (glowing flowers x4, crystal sprouts x3, floating motes (4
frames), a paw-print stone, a tiny shrine, fireflies), crystal formations in 4
sizes (blue), a crystal tree 3x5 whose leaves are glass, a glowing pond 4x3 (4
frames), stone arches with crystal keystones, a ring of standing stones 5x5, a
crystal bridge, a flying crystal fish (4 frames), a moon-rabbit (2 frames).
LANDMARK: a fallen star crater 8x8 with a cracked crystal in the middle and
light rising from it (4 frames).
```

### W11. The Grump wastes (where joy has been drained)
```
Make a GRUMP WASTES sheet: grey dead grass 9-slice, cracked grey earth 9-slice,
purple-tinged soil 9-slice, edges where dead grass meets living grass (12), 10
decorations (wilted flowers x3, grey tufts, dark crystal shards x3, a dead bird,
a broken sign, a fog wisp (4 frames)), dead trees in 3 sizes, a dead giant tree
4x6, dark crystal spikes in 4 sizes (purple glow), a corrupted well, a ruined
cottage 4x4 with a hole in the roof, a toppled statue, storm cloud shadows (4
frames), a sulking Grump campfire (4 frames, grey flame). LANDMARK: the Dark
Crystal's spire: a jagged purple-black tower 6 wide 14 tall with cracks of
magenta light (4 frames pulsing).
```

### W12. The sky islands (reached by the rocket or a crystal lift)
```
Make a SKY ISLANDS sheet: cloud-top ground 9-slice (white and pale blue), island
edges that drop into sky (12 pieces, with a cloud lip), a floating stone path
tile, a wind current tile (4 frames, pushes the player), 10 decorations (sky
flowers x3, feather, a tiny cloud sheep, a puff of mist (4 frames), a wind
chime, a kite stuck on a rock, star-grass), cloud trees 3x4 (round white
canopies), an ancient temple entrance 5x5 with crystal columns, a broken
staircase into the sky, a rope-and-plank bridge between islands 6 tiles long, a
sky whale silhouette (4 frames, passes far below), an eagle (2 frames). LANDMARK:
a crystal observatory on the highest island, 6 wide 9 tall, with a telescope
pointed at the galaxy.
```

### W13. The moon colony (expands the rocket-house set already in the game)
```
Make a MOON COLONY sheet, matching the lavender moon dust already in use: a metal
walkway 9-slice, a glass dome floor 9-slice showing stars (4 frames twinkle),
dome walls (12 edge pieces, transparent blue), an airlock door (3 frames), a
greenhouse dome 5x5 with plants inside, a radio dish 3x4, a solar panel field
tile, a rover, a crashed probe, moon rocks in 3 sizes, star-flowers in 3
colours, a glowing pool 3x3 (4 frames), a moon cow (2 frames), a tiny alien
market stall, an alien vending machine (2 frames), a crystal mine entrance on
the moon 3x3. LANDMARK: a giant crystal spire growing out of a crater, 8 wide 14
tall, that is the "missing piece" the penguins seek.
```

---

## C. Space and the galaxy

### W14. Space station interior
```
Make a SPACE STATION sheet: metal floor 9-slice (2 variants), hazard-stripe
floor, grating floor, metal walls (12 edge pieces, 2 tiles tall) with pipes, a
sliding door (3 frames), a console (2 frames), a hologram table (4 frames), a
cryo pod (2 frames: closed, open), a viewport window showing stars (4 frames),
a cargo crate (3 colours), a robot arm, a vending machine, a bunk bed, a
hydroponics rack with plants, a reactor core 3x4 (4 frames pulsing), an escape
pod, a teleporter pad (4 frames), a floating service drone (4 frames).
LANDMARK: the bridge: a wide window 10 tiles across looking onto a planet.
```

### W15. Alien jungle planet
```
Make an ALIEN JUNGLE sheet: teal moss ground 9-slice, violet soil 9-slice,
bioluminescent path 9-slice (4 frames), edges to water (12, 4 frames, pink
water), 12 decorations (glowing fungi x4, spiral ferns x3, eye-flowers that
blink (2 frames), a pod that pulses, tendrils, a glow-fruit), giant mushroom
trees 3x5 and 4x7, a carnivorous plant 2x3 (2 frames), vines hanging from the
top edge, a crashed ship 6x4, a ruined alien statue 3x5, floating jellyfish (4
frames), a six-legged deer (2 frames). LANDMARK: a colossal glowing flower 8x8
that opens and closes (4 frames).
```

---

## D. Gangster arc regions (add the ARC STYLE line)

### W16. The hideout town (expands the shack set)
```
Make a HIDEOUT TOWN sheet: cracked asphalt 9-slice, broken sidewalk 9-slice
with curb edges (12), weedy lot 9-slice, gravel 9-slice, rail tracks (straight,
corner, crossing), chain-link fence (straight, corner, gate, broken), a wooden
fence (broken), a trailer home 5x3, a gas station 6x5 with a canopy, a diner
5x4 with a neon sign (2 frames), a motel 8x4 with a vacancy sign (2 frames), a
water tower 3x7, a billboard 4x4 (blank), a bus stop, a payphone, a dumpster,
oil drums, tyres, a rusted car, a pickup truck, a dog on a chain (2 frames),
crows (2 frames), a fire barrel (4 frames), power poles with wires (straight,
corner), a storm drain, graffiti decals (6, no readable words). LANDMARK: an
abandoned drive-in cinema screen 10 wide 8 tall with a torn screen.
```

### W17. The docks district
```
Make a DOCKS sheet: concrete pier 9-slice, wooden dock 9-slice, dock edge to
water (12 pieces, 4 frames, dark oily water), harbour water 9-slice (4 frames),
a warehouse 8x6 with a roll-up door (3 frames), a smaller warehouse 5x5, a crane
4x8, shipping containers in 4 colours (2x1 and 2x2), a cargo ship hull edge
(12 tiles long, 4 tall), a tugboat, a fishing trawler, a fish market stall,
bollards, ropes, a lighthouse 3x7, oil drums, a forklift, crates on pallets, a
guard booth, floodlights (lit/unlit), a gull (2 frames), rats (2 frames).
LANDMARK: a rusting giant crane with a car dangling from its hook.
```

### W18. The neon district
```
Make a NEON DISTRICT sheet: wet asphalt 9-slice reflecting pink and cyan (4
frames shimmer), a tiled sidewalk 9-slice, a crosswalk, a storm drain, a bar
6x5 with a flickering neon sign (2 frames), an arcade 6x5 (lights 4 frames), a
noodle stand 3x3 with steam (4 frames), a hotel 8x8 with a lit sign, a ramen
shop 5x4, a karaoke bar 5x5, vending machines (3, 2 frames), a scooter, a
taxi, a payphone, neon signs as separate decals (8, abstract shapes, no words),
hanging lanterns (3 colours), a rooftop with an AC unit and a water tank (for
rooftop scenes), a fire escape, a dumpster alley, a puddle (4 frames), a cat on
a wall. LANDMARK: a giant neon dragon sign across a building 10 wide 6 tall
(4 frames, lights chasing).
```

### W19. Uptown and the President's tower
```
Make an UPTOWN sheet: marble floor 9-slice, polished stone road 9-slice, a
manicured lawn 9-slice, hedge maze pieces (straight, corner, T, end), a gold
iron fence (straight, corner, gate), a fountain with gold statues 4x4 (4
frames), a luxury car (2 colours), a limousine, a guard booth, a security
camera (2 frames), a bank 7x6 with columns, a mansion 10x8, a penthouse rooftop
with a helipad 8x8, a helicopter (4 frames rotor), topiary (3 shapes), a
statue of a man with a cane 2x4, a red carpet (straight, end), spotlights.
LANDMARK: the President's tower, 8 wide 20 tall, black glass and gold, a dark
crystal glowing in the penthouse window (4 frames).
```

### W20. The underground (sewers and the fight club)
```
Make an UNDERGROUND sheet: sewer brick floor 9-slice, sewer water channel (4
frames, green), brick walls (12 pieces, 2 tall, dripping), a grate floor, a
ladder up, a manhole (open/closed), pipes (straight, corner, valve), a boxing
ring 6x6, bleachers 4x2, a cage, a weight bench, a punching bag, a betting
booth, crates of bottles, a card table, a jukebox (2 frames), a bare bulb (2
frames), rats (2 frames), a cockroach, graffiti decals. LANDMARK: an arena pit
10x10 with floodlights and a crowd silhouette around its edge (4 frames,
cheering).
```

### W21. The countryside between districts (overworld travel)
```
Make a COUNTRYSIDE ROAD sheet in the gritty palette: a two-lane highway 9-slice
with a dashed centre line, road edges to dirt (12), a dirt shoulder, a bridge
over a river 7 tiles long, a tunnel mouth 4x4, a roadside motel sign, a
billboard, a rest stop with picnic tables, a broken-down bus, a hitchhiker, a
cornfield 9-slice at night, a farm silo, a radio tower 3x9 (blinking light, 2
frames), a wind farm turbine 3x8 (4 frames), a border checkpoint with a barrier
(2 frames up/down), a roadblock of cars. LANDMARK: a mountain pass with a
giant stone head carved into the cliff.
```

---

## E. Interiors for every building above

### W22. Generic interiors kit (do this once; it covers many buildings)
```
Make an INTERIORS kit: floors 9-slice in wood, stone, tile (black/white), carpet
(red, blue, green), concrete, metal grating; walls as 3-piece sets (left end,
middle, right end, 2 tiles tall) in plaster, brick, wallpaper floral, wallpaper
striped, concrete, wood panel; doors (wood, metal, glass, 2 frames open), windows
(day, night, boarded, 4 frames rain), stairs up, stairs down, a rug (round,
rectangular, 3 colours), a counter (straight, corner, end), shelves (3 fills),
tables (round, square, long), chairs (4 directions), stools, a bed (single,
double), a wardrobe, a dresser, a bookshelf (2 fills), a fireplace (4 frames), a
stove, a sink, a fridge, a toilet, a bathtub, a mirror, a lamp (floor, table),
plants (3), a clock, a painting (4), a TV (2 frames), a radio, a safe, a crate,
a barrel, a trash can.
```

---

## F. Creatures and ambient life (makes the world feel alive)

### W23. Wildlife
```
Make a WILDLIFE sheet, each animal 2x2 or smaller with 4 frames idle and 4
frames walk right: rabbit, squirrel, deer, fox, hedgehog, frog, turtle, duck,
heron, crow, sparrow (flying, 4 frames), butterfly (4 frames, 3 colours), bee (4
frames), firefly (4 frames), fish jumping (4 frames), crab, seagull (flying),
bat (flying), mountain goat, owl, a cat (3 colours), a stray dog, a rat, a
pigeon, a dragonfly.
```

### W24. Farm animals (full sets)
```
Make a FARM ANIMALS sheet: chicken, rooster, cow (brown, black-and-white),
sheep (woolly, shorn), pig, goat, horse, duck, each with 4 frames idle, 4 frames
walk right, 2 frames eating, plus baby versions (chick, calf, lamb, piglet,
foal). Also an egg, a milk pail, a wool pile, a feed bag, a saddle.
```

### W25. Weather and time-of-day overlays (tileable)
```
Make seamless 64x64 tileable overlays on magenta, 4 frames each: light rain,
heavy rain, snow, blizzard, drifting petals, falling leaves, fireflies, fog
wisps, dust motes, sandstorm, ash fall (for the volcanic mine), meteor shower
(for space), aurora ribbon (wide strip 256x64, 4 frames).
```

---

## G. Transition and travel

### W26. Signposts, gates and map markers
```
Make a sheet of TRAVEL pieces: wooden signposts with 1, 2, 3 blank arrows, a
stone milestone, a town gate (wooden, 5 wide 4 tall), a stone archway, a
wrought-iron gate, a toll booth with a barrier (2 frames), a bus (side view, 6
tiles), a train car (side view, 6 tiles) and an engine, a ferry boat (6x3), a
hot-air balloon (3x5, 4 frames), a crystal warp pad (4 frames), a cave door
sealed with crystal (closed, cracked, open), a drawbridge (closed, open). And 12
map-pin icons 16x16: farm, town, forest, lake, beach, mine, mountain, meadow,
wastes, moon, docks, tower.
```

### W27. World map (painted, portrait)
```
Paint a hand-drawn parchment WORLD MAP, 1080x1920 portrait, ink outlines, soft
colour, no text: centre-left a farm with a pond; south a village with a fountain
and clock tower; east a wildflower meadow becoming a glowing crystal meadow
further east; north-east a mountain with a mine entrance; north-west a dense
forest with a giant tree; west a river running to a lake with a water mill and
south-west to a beach with a wrecked galleon; far east grey wastes under a dark
spire; far south a city skyline with docks, neon lights and one tall black tower;
in the sky a moon with a crystal spire and a faint spiral galaxy. Leave room for
labels I will add.
```

---

**Order:** W1 → W2 → W3 → W4 → W7 → W6 → W5 → W8 → W9 → W23 → W22 → W10 →
W11 → W16 → W17 → W18 → W19 → W12 → W13 → W14 → W15 → W20 → W21 → W24 → W25 →
W26 → W27.

W1 through W9 give me enough to make the valley huge. Everything after that
adds a whole new region each.

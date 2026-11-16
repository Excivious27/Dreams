# Art prompts, batch 2

Everything from batch 1 is in the game. This batch fills the gaps that are now
visible: the five townspeople still show as coloured blobs, interiors are drawn
with flat shapes, there is only one ground tileset, and the mine and the story
characters (Big Jim, the Light Crystal, the Dark Crystal, the President) have no art.

**Paste the Style block first, every time.** Upload results to `art/incoming/`
with any file name. One sheet per prompt, flat magenta `#FF00FF` background, a
grid with visible gaps. If a result comes back blurry, glowing, or painted, reply:
*"Redo with crisp hard pixel edges, no anti-aliasing, no glow, no gradients."*

Batch 1 taught me two things worth passing on to ChatGPT: (1) it likes to draw
light pink grid lines, so ask for **dark magenta gaps `#CC00CC`** instead; (2) it
ignores exact pixel sizes, so ask for **relative** sizes ("as tall as the
character", "one tile wide") and I'll scale.

## Style block

```
STYLE (must follow exactly): 2D pixel art for a cozy top-down farming RPG in the
style of 16-bit console games. 3/4 top-down view. Crisp hard pixel edges, no
anti-aliasing, no blur, no glow, no gradients, 1-pixel dark outlines. Warm
saturated palette matching a game whose characters are about 26 pixels tall and
whose tiles are 16x16. Flat solid magenta background #FF00FF. Separate cells with
thin dark-magenta #CC00CC gaps, never white or pink lines. Original designs only:
no characters, logos or art from any existing game, show or brand.
```

---

## A. Townspeople (one prompt each; run all five)

These are the people you meet in town. Each needs the same animation set as the
family so they can walk around. Replace the description line per person.

```
Design an original villager character and give me a reference sheet on magenta,
dark-magenta gaps. Row 1: standing poses front, right, back, left (character
about as tall as a chibi adult: 3 heads tall). Row 2: 4 frames idle facing the
camera (breathing, blink). Row 3: 4 frames walking RIGHT. Row 4: 4 frames walking
TOWARD the camera. Row 5: 4 frames walking AWAY. Row 6: a close-up PORTRAIT of
the face and shoulders, 3 expressions: neutral, happy, annoyed (these are for the
dialogue box). Character: [DESCRIPTION]
```

Descriptions (change any you like; these are only what the game currently implies):
1. **Maple**, general store owner: warm, round, 40s, flour on an orange apron, hair in a bun with a pencil in it, striped sleeves rolled up.
2. **Gideon**, blacksmith: broad, quiet, 50s, grey-streaked beard, leather apron with burn marks, one glove, arms crossed.
3. **Wren**, potion maker: wiry, 30s, purple hooded cloak over a patched green dress, round tinted glasses, a crystal pendant, a little smirk.
4. **Mayor Alder**, mayor: tall, thin, 60s, green waistcoat with a gold chain, neat white moustache, holds a rolled-up document.
5. **Sal**, drifter: 30s, stubble, long brown coat with the collar up, a knit cap, hands in pockets, a bad knee so one leg a bit stiff.

## B. Story characters

6. **Big Jim** (playable, penguin arc)
```
Design an original hero character called Big Jim for a cozy pixel RPG: a huge,
gentle, bearded man in a plaid shirt and overalls with a tiny pet mouse on his
shoulder. Same reference sheet layout as the villagers: 4 standing poses, 4 idle,
4 walk right, 4 walk toward, 4 walk away, plus 4 frames of an overhead hammer
swing ATTACK facing right, and 3 portrait expressions.
```
7. **Female Too Powerful Penguin** (playable)
```
Design the second Too Powerful Penguin, a female hero penguin: same species and
size as this description "a small round penguin wearing a star-patterned navy
wizard hood and a purple scarf with a glowing cyan diamond gem on the chest", but
with a rose-pink hood and scarf, a crescent-moon gem, and a feather tuft. Same
sheet layout as the first penguin: standing poses front/right/left/back, 4 idle,
4 walk right, 4 run right, 4 attack right (a magic swipe), 4 power-up frames.
```
8. **The Light Crystal** (character, not an item)
```
Design the Light Crystal, a floating cosmic character: a pale blue six-sided
crystal about twice as tall as it is wide, with a soft inner star-glow and two
simple glowing eyes (no mouth). Sheet: 4 frames floating idle (gentle bob), 4
frames speaking (eyes narrow/brighten, small sparkles), 4 frames "casting"
(brighter, rings of light), 2 frames dimmed/sad, and 3 portrait expressions.
```
9. **The Dark Crystal** (the villain)
```
Design the Dark Crystal, a corrupted twin of a glowing blue crystal: jagged
black-purple with cracks of magenta light and one slit eye. Sheet: 4 frames
floating idle, 4 frames angry pulse, 4 frames summoning (shards orbit it), a
large boss-size version (3x bigger) idle 4 frames, and 3 portraits.
```
10. **The President** (gangster arc villain)
```
Design the President, the boss of the biggest gangster nation: a sharp older man
in a white suit with a red tie and a gold crystal lapel pin, slicked silver hair,
a cane. Sheet: standing poses front/right/back/left, 4 idle, 4 walk right, 3
portrait expressions (calm, smiling, furious). Also one "lieutenant": a bulky
enforcer in a dark coat with a chrome cybernetic arm, same layout.
```

## C. Enemies, batch 2

11. **Gangster-arc enemies** (replace Grumps in that arc)
```
Design original street-gang enemies for a cozy-but-dangerous pixel RPG, on
magenta with dark-magenta gaps, each with 4 idle, 4 walk right, 2 hurt frames:
(1) a thug with a baseball bat, (2) a knife guy in a hoodie, (3) a cyber thug with
a glowing arm, (4) a brute twice as big as the others, (5) a drone: small flying
camera-eye with propellers.
```
12. **More Grumps** (penguin arc)
```
Design variants of this enemy "a small grey storm-cloud creature with angry
eyebrows and stubby legs": (1) a Rain Grump that drips, (2) a Thunder Grump with a
lightning tuft, (3) a Fog Grump, half transparent, (4) the Grump Mother: three
times bigger, with a crown of small clouds. Each 4 idle, 4 walk right, 2 hurt.
```
13. **Mine and space enemies**
```
Design original enemies with 4 idle, 4 walk right, 2 hurt each: (1) a cave
spider, (2) a glowing mushroom walker, (3) a crystal beetle, (4) an ice slime,
(5) a lava slime, (6) a little alien in a bubble helmet, (7) a hovering asteroid
with a face, (8) a star-jelly.
```

## D. Interiors

14. **Interior tileset**
```
Make a 16x16 pixel tileset sheet for INTERIORS, grid with dark-magenta gaps: wood
plank floor (9-slice), stone floor (9-slice), carpet red (9-slice), carpet blue
(9-slice), plaster wall top edge with wooden base (3 tiles wide), stone wall,
wallpaper floral, a door frame, a window with curtains (2 tiles), a dark
"outside" void tile, and stairs down.
```
15. **Home furniture**
```
Make a furniture sheet on magenta, dark-magenta gaps, each object drawn from the
3/4 top-down view used by the floor tiles: single bed, double bed, wardrobe,
bookshelf, fireplace with fire (2 frames), round rug, square table, two chairs,
kitchen counter, stove, sink, fridge, potted plant, lamp, chest closed and open,
a wall clock, a framed painting, a TV, a crystal display stand, a dog bed.
```
16. **Shop interiors** (one prompt each)
```
Make interior props for a GENERAL STORE: a long wooden counter with a cash box,
shelves full of jars and sacks (3 variants), a seed display rack, a produce
crate, a hanging scale, a bell, a chalkboard sign.
```
```
Make interior props for a BLACKSMITH: anvil, forge with glowing coals (2
frames), quenching barrel, weapon rack with swords, tool wall, bellows, a
workbench with hammer, coal pile.
```
```
Make interior props for a POTION SHOP: bubbling cauldron (2 frames), shelves of
colored bottles (3 variants), hanging dried herbs, a crystal ball on a stand, a
spell book on a lectern, a distillery with glass tubes, a cat sleeping.
```
```
Make interior props for a TOWN HALL: long desk, notice board with papers, flag
stand, bench, a filing cabinet, a bust on a pedestal, a map on the wall.
```

## E. Ground, water, and world tiles

17. **Seasons** (one prompt each: summer, autumn, winter)
```
Make a 16x16 pixel tileset sheet for [SEASON]: grass base (9-slice) in the
season's colour, 6 decoration tiles (tufts, flowers or fallen leaves or snow
lumps), a path (9-slice), and tilled soil wet and dry. Match this spring palette:
bright green grass, warm orange dirt.
```
18. **Water, full set**
```
Make 16x16 pixel water tiles, 4 animation frames each as a horizontal strip,
dark-magenta gaps: deep water, shallow water, and ALL shoreline pieces where
water meets grass: top edge, bottom edge, left edge, right edge, 4 outer corners,
4 inner corners. Then the same shoreline set where water meets sand. Then a
waterfall 2 tiles tall (4 frames) and a river rapids tile (4 frames).
```
19. **Cliffs, bridges, fences**
```
Make a 16x16 pixel tileset on magenta: grassy cliff edges (top, bottom, left,
right, 4 corners) with brown earth faces 2 tiles tall, cliff stairs, a wooden
bridge horizontal (3 tiles) and vertical (3 tiles), a stone wall (9-slice), a
stone fence with gate, a hedge (9-slice), a wooden gate open and closed.
```
20. **Cave / mine tileset**
```
Make a 16x16 pixel tileset for a MINE: dark stone floor (9-slice), cave wall
edges (top, bottom, left, right, 4 corners) with wall faces 2 tiles tall, a
ladder down, a ladder up, a mine-cart rail straight and curved, a wooden support
beam, glowing crystal clusters in blue, purple and green, a lava floor (4
frames), an ice floor, a dark pit tile, stalagmites, a mine cart.
```
21. **Beach and desert**
```
Make a 16x16 pixel tileset: sand (9-slice), wet sand, 6 beach decorations
(shells, starfish, seaweed, driftwood, a crab, a bucket), a dock (9-slice),
palm tree 32x64, a tide pool (4 frames), desert sand (9-slice), cracked earth,
cactus 2 sizes, a tumbleweed (4 frames), an oasis edge.
```
22. **Space region** (for the penguin arc later)
```
Make a 16x16 pixel tileset for a SPACE STATION and a tiny alien planet: metal
floor (9-slice), metal floor with hazard stripes, glass floor showing stars (4
frames twinkle), a sliding door (3 frames), a console (2 frames), a cryo pod,
purple alien grass (9-slice), crystal rocks, a glowing mushroom, a star field
background strip, a small rocket ship 48x64, a launch pad.
```

## F. Buildings and big props

23. **Farm buildings**
```
Make farm buildings on magenta, dark-magenta gaps, each with its door centered
at the bottom: a silo, a chicken coop, a cow barn (bigger than the red barn), a
greenhouse, a stable, a shed, a water tower, a mill, a mailbox with flag up,
a well, a scarecrow with a crow on it. Also give me the farmhouse in 3 upgrade
stages: small cabin, the current cottage, a two-storey house.
```
24. **Town, batch 2**
```
Make more town buildings: an inn/tavern with a hanging mug sign, a clinic with a
red cross, a library, a bakery with a bread sign, a fish shop by a dock, a
chapel, a train station platform, a ruined tower, a wishing fountain (4 frames
splash), market stalls in 3 colours, street lamp lit and unlit, a bench, a
notice board, crates, barrels, a cart, a dog house, flower boxes.
```
25. **Gangster district**
```
Make buildings for a rough city district in the same cozy pixel style: a
neon-sign bar (2 frames flicker), a pawn shop, a boxing gym, a warehouse with a
roll-up door, a back-alley with dumpsters, a chain-link fence (9-slice), an
armoured car, a sewer entrance, a cracked asphalt tileset (9-slice), a crosswalk,
graffiti decals (4), a street light, a fire escape.
```

## G. Items and icons, batch 2

26. **More crops**: `Make crop growth rows (5 stages + the harvested item) for: carrot, tomato, potato, wheat, melon, grapes on a trellis, hot pepper, sunflower, cotton, a glowing "moon melon", a "star fruit" tree sapling in 3 stages.`
27. **Fish**: `Make 16 fish icons on magenta: minnow, trout, carp, bass, catfish, eel, pufferfish, crab, octopus, a glowing "dream trout", a crystal fish, an old boot, seaweed, a treasure chest, a message in a bottle, a tin can.`
28. **Minerals and gems**: `Make 16 icons: stone, copper ore, iron ore, gold ore, coal, quartz, amethyst, emerald, ruby, diamond, a blue light-crystal shard, a purple dark-crystal shard, geode, obsidian, salt, clay.`
29. **Tools in 4 tiers**: `Make icons for hoe, watering can, axe, pickaxe, fishing rod, sword, each in 4 tiers: wood, copper, iron, crystal (blue glow). Plus a slingshot, a bow, a shield, a lantern, a backpack, a compass.`
30. **Food**: `Make 20 food icons: bread, berry pie, pumpkin soup, salad, fried fish, roast corn, jam jar, energy tea, coffee, cookie, cake, sandwich, pancakes, stew, sushi, ice cream, honey, cheese, milk bottle, egg.`
31. **Materials and crafting**: `Make 16 icons: wood, hardwood, fibre, stone, clay, coal, iron bar, copper bar, gold bar, rope, cloth, glass, nails, a gear, a battery, a circuit board.`
32. **Gifts and quest items**: `Make 16 icons: wrapped gift, bouquet, pearl necklace, a music box, a letter with a wax seal, a torn photograph, a key, a map, a journal, a badge, a cassette tape, a pocket watch, a locket, a rubber duck, a snow globe, a trophy.`

## H. UI, batch 2

33. **Dialogue portraits frame and icons**
```
Make a pixel UI sheet: a portrait frame 48x48 (wooden, with a small nameplate),
skill icons 16x16 for combat (sword), farming (sprout), mining (pickaxe),
bartering (coin/crystal), building (hammer), foraging (mushroom), fishing (fish),
a map pin, a quest scroll icon, a bell notification, a clock face, a calendar
page, a sun, a moon, a rain cloud, a snowflake, a settings cog, a speaker on/off,
a checkbox on/off, a slider knob, tab shapes (active, inactive).
```
34. **World map**
```
Paint a hand-drawn parchment WORLD MAP (not pixel art, painted) of a valley: a
small farm with a pond in the centre-left, a village with a fountain to the
south, a wildflower meadow to the east, a mountain with a mine entrance in the
north-east, a river running to a beach in the south-west, a forest in the
north-west, and a faint far-off crystal in the sky. Soft colours, ink outlines,
no text and no labels. Portrait orientation, 1080x1920.
```
35. **Toolbar and inventory frames**
```
Make a pixel UI sheet on magenta: an inventory slot 20x20 (empty, selected with
a gold outline, locked), a toolbar background strip 9-slice, a tab button
(active and inactive), a scroll bar track and knob, a small "x" close button,
an arrow button left and right, a heart meter in 5 steps for friendship,
an energy bar frame (vertical) with a lightning icon on top.
```

## I. Effects and weather

36. **Particles**
```
Make a pixel effects sheet on magenta, each as a strip of 4 to 6 frames: a hit
spark, a sword slash arc, dust puff, water splash, sparkle, smoke puff from a
chimney, a level-up burst of stars, a heart floating up, a "Zzz" sleep, rain drop
splash, a leaf falling, a crystal glint, a magic circle (6 frames), a puff of
grey Grump smoke when one is defeated.
```
37. **Weather overlays**
```
Make seamless tileable 64x64 pixel overlays on magenta, 4 frames each: rain
streaks, heavy rain, falling snow, drifting petals, fireflies, fog wisps.
```

## J. Key art and screens

38. **Arc title cards** (painted, not pixel)
```
Paint a title card, 1080x1920, storybook style, no text: TWO small cloaked
penguins and a fluffy black-and-tan puppy standing in a wheat field at night
looking up at a glowing blue crystal that is descending from a spiral galaxy.
```
```
Paint a title card, 1080x1920, moody noir storybook style, no text: a hooded
figure walking up a muddy road in the rain toward a crooked farmhouse, a black-
and-tan puppy at his heels, a city skyline glowing far behind him.
```
39. **Loading / sleep screens**: `Paint four small square illustrations, 512x512, storybook style, no text: a cozy bedroom at night with a puppy asleep at the foot of the bed; a sunrise over a vegetable field; a mine lantern in the dark with blue crystals; a village square at dusk with lanterns.`

---

**Order I'd suggest:** A (townspeople) → 14/15 (interiors) → 18 (water set) →
17 (seasons) → 20 (mine) → B (story characters) → the rest as you feel like it.

# Art prompts for ChatGPT

Paste the **Style block** at the top of every prompt so everything matches the
character pack. Then paste one request block. Save results to `art/incoming/` in the
repo (Add file → Upload files); I slice, clean and wire them in.

Tips that make a big difference:
- Ask for **one sheet per prompt**. Big mixed sheets come out inconsistent.
- Ask for a **flat solid magenta background** (`#FF00FF`), not transparent and not
  white. It's the easiest to remove cleanly.
- If the result has a glow, blur, or "painted" look, reply: *"Redo with crisp hard
  pixel edges, no anti-aliasing, no glow, no gradients."*
- Ask for a **grid with visible 1px gaps** between cells so I can slice reliably.

## Style block (paste first, every time)

```
STYLE (must follow exactly): 2D pixel art for a cozy top-down farming RPG in the
style of 16-bit console games. 3/4 top-down view (we see the front of things and a
little of the top). Crisp hard pixel edges, no anti-aliasing, no blur, no glow, no
gradients, no outlines thicker than 1 pixel. Base tile size 16x16 pixels. Characters
are about 26 pixels tall. Warm saturated palette, soft shadows directly below objects.
Flat solid magenta background #FF00FF. Render at exactly 1 pixel per pixel (no
upscaling, no "pixel-look" filter on a high-res image). Original designs only: no
characters, logos or art from any existing game, show or brand.
```

## 1. Ground tileset (do this first)

```
Make one 16x16 pixel tileset sheet, laid out in a grid with 1px magenta gaps.
Include, each as a full 9-slice set (center, 4 edges, 4 corners) so they tile
seamlessly: (1) spring grass, (2) dirt path, (3) tilled soil (dry), (4) tilled soil
(watered, darker), (5) shallow water with a sandy shore, (6) stone floor for a town
square, (7) wooden dock planks. Also 6 grass decoration tiles: tufts, 3 kinds of
small flowers, a pebble, a mushroom. All tiles must tile seamlessly with their
neighbours.
```

## 2. Water animation

```
Make a horizontal strip of 4 frames of a 16x16 pixel water tile that loops as a
gentle animation (subtle highlight ripples moving). Same blue as the water in the
tileset. 1px magenta gaps between frames. Then a second strip of 4 frames for the
shoreline edge (water meeting sand) that animates the same way.
```

## 3. Trees, bushes, rocks

```
Make a sprite sheet of nature objects on magenta, 1px gaps: (1) a round leafy oak
tree 32x48 pixels, (2) the same tree in autumn colours, (3) a pine tree 32x48, (4) a
small bush 16x16, (5) a berry bush 16x16 with red berries, (6) a tree stump 16x16,
(7) three rocks: small 16x16, medium 32x32, large copper-flecked 32x32, (8) a fallen
log 32x16, (9) a wild-flower patch 16x16. Each object has a soft shadow at its base.
```

## 4. The farmhouse

```
Make a cozy farmhouse exterior for the player's starting plot: 96x80 pixels. Wooden
walls, a warm red-brown shingled roof, a front door in the middle of the bottom
edge, two windows, a small chimney with no smoke (I animate smoke separately), a
mailbox beside the door as a separate 16x16 sprite. Also give me: a wooden sell box
(chest with an open slot on top) 24x24, a wooden fence post 16x16 and fence sections
horizontal 16x16 and vertical 16x16, and a wooden sign 16x16.
```

## 5. Town buildings

```
Make a sheet of town buildings for a small mystical village, each 96x96 or
128x96 pixels, on magenta with 1px gaps: (1) a general store with a striped awning
and a hanging sign, (2) a blacksmith with an anvil and a glowing forge window, (3) a
potion shop: crooked, purple roof, a crystal in the window, (4) a town hall with a
clock, (5) two small cottages with different roof colours, (6) a well 32x32 and (7)
a fountain 48x48. Doors are centered on the bottom edge of each building.
```

## 6. Crops (growth stages)

```
Make a crop sheet on magenta, 1px gaps. For each crop, a horizontal row of 16x16
cells showing 5 growth stages from seedling to fully grown, then a 6th cell of the
harvested item alone: (1) turnip, (2) strawberry, (3) corn (the full plant can be
16x32, two cells tall), (4) blueberry bush, (5) pumpkin, (6) a glowing blue
"dream flower" (fantasy crop) that gives off tiny sparkles.
```

## 7. Items and icons

```
Make a 16x16 icon sheet on magenta, 1px gaps, with a 1px dark outline on each icon
so they read on any background: hoe, watering can, axe, pickaxe, fishing rod,
sword, wooden sword, bow, three potions (red, blue, green), a crystal (the game's
currency: a pale blue 6-sided crystal), a dark corrupted crystal, copper ore, iron
ore, gold ore, wood log, stone, fibre, seeds packet, a fish, a loaf of bread, an
apple, a wrapped gift, a letter, a key, a map.
```

## 8. Pet animations (extra for the puppy)

```
Make a horizontal animation strip for a small black-and-tan fluffy puppy with a
green collar, 24x24 pixel cells on magenta, 1px gaps: 4 frames walking TOWARD the
camera (front view), 4 frames walking AWAY (back view), 4 frames sitting/wagging,
4 frames digging. Match this description exactly: black body, tan muzzle, chest and
paws, floppy ears, green collar.
```

## 9. Walking toward/away for the family characters (fills a known gap)

Run this once per character, swapping in the description line.

```
Make a horizontal animation strip, 32x40 pixel cells on magenta, 1px gaps, for
this character: [DESCRIPTION]. Row 1: 4 frames walking TOWARD the camera (front
view, legs alternating). Row 2: 4 frames walking AWAY from the camera (back view).
Row 3: 4 frames running toward. Row 4: 4 frames running away. Keep the feet on the
same baseline in every frame.
```
Descriptions:
- Dad: `a man in a grey beanie, beige sweater and brown pants`
- Mom: `a woman with long wavy brown hair, a pink floral kimono and denim shorts`
- Pax: `a blond boy in a grey patterned tee and navy joggers, holding drumsticks`
- Kairi: `a girl with a blonde ponytail, purple glasses, a black cat sweater and pink pants`

## 10. The penguins (new characters, needs Tom's answers first)

Once you answer Guide #1 question 10, I'll write exact prompts. Draft:

```
Design an original character: a [SIZE] penguin hero who has been granted cosmic
power. [COLOURS / DISTINCT FEATURE]. Give me a reference sheet on magenta with 1px
gaps: front, back, left and right standing poses (26 pixels tall), then animation
strips: 4 frames idle (facing camera), 4 frames walk (facing right), 4 frames run
(facing right), 4 frames attack (facing right), 4 frames of a "power-up" pose with a
small burst of light.
```

## 11. Enemies

```
Design original enemies for a cozy-but-dangerous RPG, on magenta, 1px gaps, each
with 4 idle frames, 4 walk frames (facing right) and 2 hurt frames: (1) a "Grump":
a small grey storm-cloud creature with angry eyebrows and stubby legs, 16x16, (2) a
cave slime 16x16, (3) a cave bat 16x16, (4) a rock golem 32x32, (5) a corrupted
crystal shard that floats, 16x24, with a faint purple core.
```

## 12. UI

```
Make a pixel-art UI kit on magenta, 1px gaps: a 9-slice wooden panel 48x48 (so it
can stretch), a 9-slice parchment panel 48x48, a round button 32x32 in normal and
pressed states, a heart (full, half, empty) 8x8, an energy bolt (full, empty) 8x8,
a small crystal icon 8x8 for the money counter, a speech-bubble tail 8x8, and
arrow icons up/down/left/right 8x8.
```

## 13. Title screen key art (not pixel art)

```
Create a painted title illustration, 1080x1920 pixels (portrait, phone wallpaper
shape), soft storybook style: a small farm at dusk at the edge of a glowing forest,
a floating pale-blue crystal shedding light over the field, a puppy sitting on the
path, distant mountains, a starry sky with a faint far-off galaxy. No text, no
characters' faces, original scene only.
```

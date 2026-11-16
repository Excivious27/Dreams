# Art prompts for ChatGPT: set 2 (critical gaps)

These pick up where `ART-PROMPTS.md` left off, starting at #14. The same rules apply:
paste the **Style block** from `ART-PROMPTS.md` first, ask for one sheet per prompt,
use a magenta `#FF00FF` background with 1px gaps, and save results to `art/incoming/`.

The prompts are in priority order. The first group blocks core gameplay (you can't farm,
fish, mine or talk to anyone without it). Later groups unlock new regions and the
second arc.

---

## GROUP A: core gameplay (do these first)

## 14. Player tool-use animations

Run this once per playable family character, swapping in the description from #9.
Without these the player can't visibly farm, chop, mine or fish.

```
Make an animation sheet, 32x40 pixel cells on magenta, 1px gaps, for this character:
[DESCRIPTION]. Each row is one action, shown facing DOWN (toward camera), then the same
action facing RIGHT, then facing UP (away). 4 frames per direction:
Row 1: swinging a hoe down into the ground.
Row 2: tipping a watering can (small water droplets in frames 3-4).
Row 3: swinging an axe overhead.
Row 4: swinging a pickaxe overhead.
Row 5: casting a fishing rod (wind up, cast, line out, waiting).
Row 6: reeling in / pulling a fish up.
Row 7: holding an item up over the head with both hands (item-get pose, hands empty).
Row 8: eating/drinking (hand to mouth).
Keep feet on the same baseline in every frame. Tools are simple and match a 16x16
item icon style.
```

## 15. Dialogue portraits

Stardew-style talking portraits are what make friendships feel real. Run this once per
character (family members first, then each townsperson from #16).

```
Make a set of 6 character portraits, each 64x64 pixels, on magenta with 1px gaps, for:
[DESCRIPTION]. Head and shoulders, facing slightly toward the viewer, inside no frame.
Expressions in this order: neutral, happy (big smile), sad, angry, surprised, embarrassed
(blushing). The face, hair, clothing and colours must be identical across all 6; only
the expression changes. Same crisp pixel style as the sprites, slightly more detail is
allowed at this size.
```

## 16. Starting-town villagers (friendship NPCs)

Original townsfolk for the starting village. Adjust names and roles to match your story
once you've decided them.

```
Design 8 original villager characters for a cozy mystical farming village. For each,
give a front-facing standing sprite 32x40 pixels (character about 26 pixels tall) on
magenta with 1px gaps, plus a 4-frame walk toward the camera underneath it:
(1) the general store owner: a cheerful round older man with an apron and spectacles,
(2) the blacksmith: a tall muscular woman with a soot-smudged leather apron and a
braid, (3) the potion maker: a thin elderly person in a star-patterned violet robe with
a crystal pendant, (4) the mayor: a portly man in a green waistcoat with a pocket watch,
(5) a fisherman: a bearded man in a yellow raincoat and boots, (6) a young artist: a
woman with short teal hair and a paint-stained smock, (7) a quiet scholar: a young man
with a scarf and a stack of books, (8) a kind farmer neighbour: a woman in overalls and
a straw hat. Each villager has one distinct silhouette and colour so they read
instantly at small size.
```

## 17. House interior tileset + furniture

```
Make an interior tileset, 16x16 base tiles, on magenta with 1px gaps, for a cozy
farmhouse in 3/4 top-down view: (1) wooden plank floor 9-slice, (2) rug 9-slice,
(3) back wall with wallpaper and a wooden baseboard (left end, middle, right end),
(4) a window on the back wall 16x32, (5) an interior door 16x32. Furniture as separate
sprites: single bed 32x32, double bed 32x48, wooden table 32x32, two chairs (facing
down and up), a bookshelf 32x32, a fireplace 32x48, a kitchen counter with a stove
48x32, a TV-free dresser 32x32, a potted plant 16x32, a floor lamp 16x32, a pet bed
for a puppy 16x16, a wall clock 16x16, and a storage chest 16x16 shown closed and open.
```

## 18. Crafting stations and farm machines

```
Make a sheet of farm crafting objects, each on magenta with 1px gaps, 3/4 top-down:
(1) a workbench 32x32, (2) a stone furnace 16x32 shown unlit and lit with orange glow
in the opening (2 frames), (3) a wooden chest 16x16 closed and open, (4) a sprinkler
16x16 (copper) with 3 frames of water spray, (5) a scarecrow 16x32, (6) a beehive
16x32, (7) a keg 16x32, (8) a preserves jar 16x16, (9) a "crystal resonator": a
mystical machine 16x32 of wood and brass holding a small pale-blue crystal, with 4
frames of the crystal pulsing softly (this is a fantasy item that refines crystals).
```

## 19. Fishing set

```
Make a fishing sheet on magenta, 1px gaps: (1) a red-and-white bobber 8x8 with 4 frames
of bobbing and a 2-frame "bite" splash, (2) a water splash effect 16x16 with 4 frames,
(3) 12 fish icons 16x16 with a 1px dark outline: sunfish, trout, carp, catfish, salmon,
bass, eel, pufferfish, a golden fish, a glowing blue "starfin" fantasy fish with tiny
sparkles, a silver "moon carp" fantasy fish, and a piece of junk (an old boot).
```

## 20. Mine tileset

The starting town has mines, and each region gets its own later. This is the base one.

```
Make a cave/mine tileset, 16x16 base tiles, on magenta with 1px gaps, 3/4 top-down:
(1) dirt cave floor 9-slice, (2) rocky cave walls as a full autotile set (top edge,
side edges, inner and outer corners), (3) a ladder down 16x16 and a ladder up 16x32,
(4) a mine-cart track (straight, corner) 16x16, (5) a wooden support beam 16x32,
(6) breakable rocks 16x16 in 3 variants, (7) ore nodes 16x16: copper, iron, gold, and a
pale-blue crystal node that glows faintly, (8) a dark corrupted crystal node with a
purple glow, (9) a cave mushroom cluster and a glowing moss patch for decoration.
```

## 21. Seasons: summer, fall, winter versions

Run this after #1 and #3 are done and you're happy with them.

```
Recolour the ground tileset and nature objects for three more seasons, keeping the
exact same shapes, layout and grid as the spring versions: SUMMER (deeper greens,
sunflowers in the flower tiles), FALL (golden-orange grass, red and orange leaves,
fallen leaves on the path), WINTER (snow-covered grass and paths, bare trees with
snow on branches, frozen water with an ice-crack pattern, snowy rocks). One sheet per
season.
```

## 22. Combat and magic effects

```
Make a sheet of combat visual effects on magenta, 1px gaps, each as a horizontal
4-6 frame animation: (1) a sword slash arc 32x32 (facing right), (2) a hit spark 16x16,
(3) an enemy defeat poof of smoke 24x24, (4) a pickup sparkle 16x16, (5) a healing
swirl of green leaves 24x24, (6) a level-up burst of rising stars 32x32, (7) a magic
projectile: a pale-blue crystal bolt 16x16 with a short trail, (8) a "power awakening"
burst: a ring of pale-blue light with tiny paw-print shaped sparkles expanding outward
32x32 (this is the hero power effect, the Meow Pow Wow).
```

## 23. Core gameplay UI (beyond #12)

```
Make a pixel-art UI sheet in the same wooden/parchment style as the existing UI kit, on
magenta, 1px gaps: (1) an inventory slot 20x20 in normal, hovered and selected states,
(2) a 12-slot hotbar frame 9-slice, (3) a dialogue box 9-slice with a name tab on the
top-left, (4) a friendship heart row icon 8x8 (empty, half, full) in pink, (5) skill
icons 16x16 with a 1px dark outline: combat (crossed swords), farming (sprout),
mining (pickaxe), foraging (leaf), fishing (fish), bartering (two hands shaking),
building (hammer), (6) a day/time clock frame 48x32 with a sun and a moon icon,
(7) season icons 8x8: spring blossom, summer sun, fall leaf, winter snowflake,
(8) a quest scroll icon 16x16 and an exclamation-mark bubble 8x16.
```

## 24. Weather and day/night

```
Make weather effect sprites on magenta, 1px gaps: (1) a raindrop streak 2x6 pixels in
3 variations, (2) a rain splash on the ground 8x8, 3 frames, (3) a snowflake 3x3 in
3 variations, (4) a drifting leaf 6x6 in 4 rotation frames (green, orange), (5) a
firefly 4x4 with 4 frames of glow pulsing (for summer nights), (6) a lit window glow
overlay 16x16 in warm yellow, (7) a street lantern 16x32 shown unlit and lit.
```

---

## GROUP B: Too Two Powerful Penguins arc

## 25. The Light Crystal and the Dark Crystal

```
Design two original magical crystal beings, on magenta with 1px gaps.
(1) THE LIGHT CRYSTAL: a floating pale-blue and white crystal, about 24x32 pixels, with
a gentle face formed by light inside it, a soft halo, kind expression. Give 4 frames of
floating idle (bobbing gently), 4 frames of "speaking" (the inner light pulses), and a
64x64 dialogue portrait in neutral, happy and worried expressions.
(2) THE DARK CRYSTAL: a large jagged crystal 48x64 pixels, deep purple and black with
cracks of sickly magenta light, a menacing face formed in the cracks, smaller dark
shards orbiting it. Give 4 frames of idle (shards orbiting), 4 frames of a charge-up
attack, 2 hurt frames, and a 64x64 portrait in menacing and furious expressions.
```

## 26. Grumps Army

The basic Grump enemy is already in #11. This adds the rest of the army.

```
Design the rest of an evil army called the Grumps, all original, on magenta, 1px gaps,
each with 4 idle, 4 walk (facing right), 4 attack and 2 hurt frames:
(1) a Grump Soldier 24x24: a grumpy grey cloud creature wearing a small iron helmet and
holding a spear, (2) a Grump Archer 24x24 with a tiny crossbow, (3) a Corrupted Crystal
Knight 32x40: a humanoid made of dark purple crystal plates, (4) a Gloom Wisp 16x16:
a floating ball of dark smoke with glowing eyes that drains colour from the ground
around it, (5) a Grump Commander mini-boss 48x48: a huge thundercloud creature with a
crown of dark crystals and lightning arms.
```

## 27. Space region tileset (first off-world area)

```
Make a tileset for an alien moon region, 16x16 base tiles, on magenta with 1px gaps,
3/4 top-down: (1) pale lavender moon-dust ground 9-slice, (2) crater edges autotile,
(3) glowing cyan alien grass tufts, (4) crystal formations 16x32 and 32x32 in pale blue
and pink, (5) a small landing pad 48x48, (6) a cozy rocket-ship house exterior 64x80
with a round door and porthole windows, (7) alien plants: a bulb plant with a glowing
tip 16x32, a spiral fern 16x16, (8) a sci-fi teleporter pad 32x32 with 4 frames of a
light beam. Keep it cozy and magical, not scary.
```

---

## GROUP C: Gangster's Paradise arc

This arc needs its own grittier look. Add this line **after** the Style block for every
prompt in this group:

```
ARC STYLE: same pixel rules, but a grittier palette: muted browns, rust, concrete greys
and neon accents (hot pink, electric cyan). Urban-fantasy crime world, tough but not
gory. All characters are original and must not resemble characters from any existing
anime, manga or game.
```

## 28. Gangster's Paradise heroes (Dad and Paxten variants)

```
Make arc variants of these two characters, 32x40 cells on magenta, 1px gaps:
(A) [Dad DESCRIPTION] now wearing a worn dark leather jacket over the sweater, a scar
across one eyebrow, and fingerless gloves, (B) [Pax DESCRIPTION] older, as a teenager
in a dark hoodie with the hood down, a bandaged forearm and a determined look. For each:
front, back, left and right standing poses, 4 frames walk toward, 4 frames walk right,
4 frames punch combo facing right, 2 hurt frames, and 64x64 portraits in neutral,
angry, determined and sad.
```

## 29. Hideout town tileset (the arc's starting community)

```
Make a tileset for a run-down hideout town where a man on the run hides out, 16x16
base tiles, 3/4 top-down, on magenta with 1px gaps: (1) cracked asphalt 9-slice,
(2) broken sidewalk with a curb, (3) weedy dirt lot 9-slice, (4) a chain-link fence
(horizontal, vertical, gate), (5) a rusty dumpster 32x24, (6) a flickering neon sign
32x16 with 2 frames, (7) a fire barrel 16x24 with 4 frames of flames, (8) stacked
crates and pallets, (9) a run-down farmhouse/shack 96x80 with boarded windows that
can later be upgraded, (10) a black-market stall 48x48 with a tarp roof.
```

## 30. Rival gangsters (region bosses and crew)

```
Design 6 original gangster characters with distinct powers, each with a 32x40 standing
sprite, 4 frames idle, 4 frames attack facing right, 2 hurt frames and a 64x64 portrait
(neutral and furious), on magenta, 1px gaps:
(1) a cyber-gangster with a glowing cyan mechanical arm and a visor, (2) a brute: a
huge muscle-bound bruiser in a tank top with chains, (3) a fire-wielder in a long red
coat with flames around his fists, (4) a speedster in a tracksuit leaving afterimages,
(5) a slick gambler woman in a white suit who throws enchanted playing cards,
(6) a hulking enforcer with cybernetic legs and a riot shield.
Each must have one bold distinct silhouette and colour accent.
```

## 31. Recruitable gang members

```
Design 6 original recruitable crew members for the hero's own gang, 32x40 cells on
magenta, 1px gaps, each with a front standing pose, a 4-frame walk toward, and a 64x64
portrait (neutral and happy): (1) a street-smart mechanic girl with goggles and a
wrench, (2) a gentle giant cook with an apron, (3) a nervous hacker kid with a laptop
backpack, (4) a retired boxer with grey hair, (5) a tattooed lookout with a bandana,
(6) a smooth-talking negotiator in a vest and flat cap.
```

## 32. The President (final boss of the arc)

```
Design an original final boss: the President of the biggest gangster nation. A tall
imposing man in an immaculate black suit with a crimson tie and gold cufflinks, a
cybernetic glowing-red eye, slicked silver hair, and a cane topped with a dark crystal
(hinting at a link to a dark crystal power). On magenta, 1px gaps: a 48x64 standing
sprite, 4 frames idle, 4 frames cane-strike attack, 4 frames of a dark-power charge-up
with purple-red energy, 2 hurt frames, and 64x64 portraits in calm, smug and enraged.
```

---

## Not included yet (and why)

- **Penguin heroes and Big Jim:** waiting on your answers for Guide #1 question 10.
  Big Jim has no description yet.
- **Farm animals, coop and barn:** the brief doesn't say yet whether animals are in the
  game.
- **Shop interiors** (store, blacksmith, potion shop): do these after #17 so they reuse
  its floor and wall tiles.
- **Other-region tilesets** beyond the first space moon and hideout town: the region
  list isn't defined yet.
- **Choice and morality UI** (good/bad path indicators): needs the decision system
  designed first.
- **Logos and title text:** usually best made by hand once the game's name and font are
  final.

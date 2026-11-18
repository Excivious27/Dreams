# Guide #18: CONDUCT loop 6 of 10

Play: https://excivious27.github.io/Dreams/

This loop:
- a 20-agent audit;
- 20 bots, run before and after the fixes: 0 errors, 0 fails;
- the scripted playtest: 0 fails;
- about 200 fixes;
- 412 art files re-cut from your sheets;
- Prompts 25 (new, small) and this guide.

Guides 12–17 still apply to anything not repeated here.

---

# PART 1 — What changed, and what to test

## Smoother on phones
- Each map's ground is now baked into big picture tiles, so the phone draws 8–45 times fewer pieces each frame.
- Path patches no longer run the water shader every frame.

## Rooms look right
- The furniture sheets are cut properly now. That fixes:
  - chairs, stools, pews and stained glass;
  - shelves, crates and flour sacks;
  - rugs and floors.
- Captions and ruled lines are gone.
- Items no longer show the wrong picture. Before, a cider press could show as an apple tub, and frog jars as a cauldron.
- **Lieutenants:** their boss cards are clean framed cards.
- **Pets:** the golden, collie and husky dogs have whole frames with no holes.
- **Fish:** all 15 fish icons are clean.
- **Farmhouse:** now has a lamp, bookshelf, table and plants.

## Farm
- **Big Coop, Big Barn and Silo now work.** Scythed hay goes into the silo, and the Big Barn feeds animals from it.
- The Workshop crafts 25% faster, and the Stable makes riding 10% faster.
- Tapping an animal while holding an egg no longer eats the egg.

## Economy
- **Food energy:** eating gives at most one full bar of energy a day. Past that you see "Too full for more energy today."
- **Fishing:**
  - Every water has minnows and sunfish.
  - Valuable fish need skill, night or bait.
  - The lake can give Finn's pearl.
- **Bushes** refill every 3 days.

## Mines
- Ore is back to about 1 rock in 6.
- Coal looks like coal, and stalagmites are no longer mine carts.
- The keeper wakes with an alert and boss music.
- Skeletons give bone, and Theo's book while his quest is open.

## Combat and skills
- **Not Today** clears poison and burn, so they can't finish you off.
- Enemies walk around walls instead of getting stuck.
- **Tremor** leaves the neighbouring rocks on one hit, as its text says.
- **Bartering:** the Buying row gives the shop discount. If an old save had points in a node whose effect changed, those points are refunded.
- Vance's fight opens properly.

## Story
- Memorizing the letter without Marlene now has its own tower route.
- The lieutenant count reads "N of 7" in the gangster arc.
- The Sasha line in the ending matches what happened.
- Penguin beats no longer fire after the ending.
- Glowcap quests open at Foraging 3.
- More lines were softened for all ages.

## Phone screen and sound
- **Mana bar:** it's blue and only appears once you can cast.
- **Boss card:** the boss's name fits.
- **USE button:** shows a zzz for Sleep and a speech bubble for Talk.
- **Shop:** when Maple is out, a note sits on the till, and she doesn't greet you.
- **Sounds:**
  - The door creak plays only at doors.
  - Kills make fewer sounds at once.
  - New sounds for completing a quest, blocking, enemy shots and collapsing.
  - No birds underground.
- **Menus:** drags that start on a button now scroll the menu and chest grids.

## What to test (10 minutes)
1. Walk into the chapel, inn, store and bakery. Do the furniture and floors look clean?
2. Walk around town and the farm. Does it feel smoother on your phone?
3. Eat until you see "Too full."
4. Build the Silo, scythe some grass, and check the Big Barn feeds your animals.
5. Scroll the chest grid and the menu tabs with your finger.

---

# PART 2 — New decisions

1. **Food energy cap** (one full bar a day from food). *Default: keep.*
2. **Greenhouse plot size:** to fix the overlap, either shrink the plot by one row or move the Plans board. *Default: move the Plans board.*
3. Still open from Guide 17: caps on pup bite, gun and helper damage, and team healing. *Default: leave as is until you play.*

---

# PART 3 — Art, in order

1. **Prompts 19** (edges, interiors, last stand-ins): 15 prompts, 43 images. Still the most important.
2. **Prompts 23** (5 prompts, 11 images) and **Prompts 24** (2 prompts, 5 images).
3. **Prompts 25** (new): 2 prompts, 4 images:
   - the hero's face in the Neon Jacket and Ceremony Coat;
   - a proper Big Grump boss sheet;
   - ability button icons for 19 partners;
   - icons for the 15 special skill unlocks.
4. **Prompts 20–22**, then **17–18**.

No new sheets have arrived since Prompts 16, so everything in Prompts 17–25 is still waiting.

---

# PART 4 — Still open

Story answers (Guide 11, Part 3), music approvals (Guide 11, Part 5) and playtest notes.

---

# PART 5 — What's left on my side

| Work | Hours | Needs you? |
|---|---|---|
| Wire Prompts 17–25 art as it arrives | 25–32 | The art |
| Fix the 16 old slicer steps that no longer run | 2–3 | No |
| Story rework with your answers | 8–14 | Yes |
| CONDUCT loops 7–10 | ongoing | No |

# Guide #16: CONDUCT loop 4 of 10

Play: https://excivious27.github.io/Dreams/

This loop had five parts:
- a 20-agent audit;
- 20 bots, with 0 errors and 0 fails;
- the scripted playtest, with 0 fails;
- fixes;
- Prompts 23 (new) and this guide.

Guides 12–15 still apply to anything not repeated here.

---

# PART 1 — What changed, and what to test

## New
- **Sun Haven bag:** your bag is now real slots.
  - Tap an item to pick it up. Tap a slot to put it down or swap.
  - Long-press for **Half**, **Lock** and **Trash**. Trash takes two taps.
  - Locked items stay put when you sort. They can't be trashed, stacked into chests or sold in the sell box.
  - Your tools have their own row. Assigning one to the toolbar swaps it, so a tool is never lost.
- **Chests:** two slot grids, using the same long-press. The chest's Sort only sorts the chest.
- **Rooms:**
  - Side walls, a front lip and shadows.
  - Homes have a fuller living area.
  - Rugs lie flat.
- **Water as one body:** each of these is one smooth shore now:
  - the beach sea, piers and edge water;
  - the lake, its outlet stream and the edge water;
  - the docks sea and the edge water.

## Fixed
- **Hidden water:** the river in Riverlands and the bog ponds in the Marsh were covered by the ground patches. They show again.
- **Lake:**
  - The water reaches under the docks.
  - The outlet stream now runs all the way to the edge.
- **Docks:**
  - You can no longer walk on the sea at the map edge.
  - Bollards stand on the quay, not in the water.
- **Phone screen:**
  - The USE and CHECK buttons drew half of the wrong button. They show the gold and green buttons now.
  - The clock box no longer has dark lines through it.
  - The grass on the farm, meadow and town no longer has a light/dark checkerboard.
  - A choice with long answers shows every answer in full.
  - The letter choice asks its question.
  - When the pup is at your feet, tapping a villager talks to them instead of opening the pup menu.
- **Combat:**
  - Low mana no longer makes Gift powers free.
  - Burning foes no longer teleport or pop boss openings every second.
  - Lulled shields wear off.
  - Clone decoys can't shoot.
  - The first boss's ring has a gap.
  - Getting knocked out mid-battle no longer races the defeat screen.
- **Balance:**
  - Guns:
    - the Tommy Gun fires slower and hits a bit softer;
    - the Six-Shooter and Gold Revolver have a real reload gap.
  - Helpers take more damage.
  - The Warden's defense buff no longer replaces a stronger one.
  - Turrets can't shoot through walls.
- **Farm:**
  - Orchard trees rest in their off-season.
  - Snow waters crops.
  - Sheep and calves stay out of the stable.
  - Farm weeds don't regrow in 4 days with Old Growth.
- **All ages:** 23 lines were softened. They covered Doc's backstory, Old Moss's lines, Halo, Mama Rosa, the coffee and wine quests, "Killing Edge" (now Keen Edge) and "Star Blood" (now Starborn).
- **Lieutenants** now speak with their painted portraits.
- **Tempered helmets** look like their base helmet when worn.

## What to test (10 minutes)
1. Open the bag:
   - long-press an item and Lock it;
   - try to sell it in the sell box: it should refuse;
   - Trash something you don't need.
2. Open the farm chest: move items both ways, split a stack with Half.
3. Walk to the Riverlands river and the Marsh ponds: the water should show.
4. Go to the lake: the docks should sit on water, and the stream should reach the bottom edge.
5. Check the USE/CHECK buttons and the clock box on your phone.

---

# PART 2 — New decisions

1. **Gun rebalance:** Tommy Gun damage 3 every 0.18 s; revolvers about one shot per 0.6–0.75 s. *Default: keep.*
2. **Skill names:** Keen Edge and Starborn, for all ages. *Default: keep.*
3. **Locked items can't be sold.** *Default: keep.*

---

# PART 3 — Art, in order

1. **Prompts 19** (edges, interiors, last stand-ins): 15 prompts, 43 images. Still the most important.
2. **Prompts 23** (new): 5 prompts, 11 images:
   - boss banners for seven bosses;
   - effects for five boss Gifts;
   - party cards for the 15 partners without one;
   - six new outfits, walking and in action;
   - headgear that draws nothing on the head;
   - 12 speaker portraits;
   - small leftovers (seed packets, an emote, tabs);
   - Mabel's walking sheet.
3. **Prompts 20** (8 prompts), **Prompts 21** (4) and **Prompts 22** (1).
4. **Prompts 17** (12 prompts) and **Prompts 18** (6 prompts).

---

# PART 4 — Still open

Story answers (Guide 11, Part 3), music approvals (Guide 11, Part 5) and playtest notes.

---

# PART 5 — What's left on my side

| Work | Hours | Needs you? |
|---|---|---|
| Wire Prompts 17–23 art as it arrives | 22–28 | The art |
| Lieutenant boss-card crop (slicer fix, no new art) | 1 | No |
| Town river you can fish; crystal pond you can't walk on | 1–2 | No |
| Economy pass (farm-pond fish value, bread energy, mining speed) | 2–3 | No |
| Story rework with your answers | 8–14 | Yes |
| CONDUCT loops 5–10 | ongoing | No |

# Guide #15: CONDUCT loop 3 of 10

Play: https://excivious27.github.io/Dreams/

This loop: a 20-agent audit, 20 bots (0 errors, 0 fails), fixes, Prompts 22 (small), and this guide. Guides 12–14 still hold for anything not repeated here.

---

# PART 1 — What changed, and what to test

## Fixed
- **Trapped in huts (my mistake in loop 2):** leaving Old Moss's hut or the river hut broke after my fix. It works again, and a new check makes sure no doorway can lose its destination.
- **Orla:** moved again, this time to a cell that's actually free.
- **Ground pieces:** piers, the hot spring, pond and warp pad now draw above the water layers as well as the ground.
- **Sal:** her "ask twice" sale works now. Before, her cooldown blocked the second tap.
- **Combat:**
  - A boss in its opening no longer lunges out of the stun after a few quick hits.
  - Holding a farm tool (the pickaxe in the mine, say) still lets you hit a foe right in front of you.
  - Mine keepers match the floor's tier, so there's no jump at floor 11.
- **Story:**
  - In the "turn him back" ending, Fennimore walks away instead of being knocked out after the text frees her.
- **All ages:**
  - The "Gambler" thug is now the Trickster.
  - The two wine side quests only appear in the penguin arc.
- **Armour:** 81 pieces that existed but couldn't be made now have recipes:
  - the Crystal set at the anvil, tier 4;
  - the Moon set at tier 5;
  - a "+1" temper for every set (leather at the tannery);
  - the Neon Jacket at the armory.
- **Economy:**
  - Lenses and printing ink can't be crafted for profit.
  - The "seed back" and smelting discounts are capped.
- **Building from chests:** the Plans board now counts and uses materials in your chests, not just your bag.
- **Touch:** the joystick no longer closes the craft or chest screen, or presses Leave in a menu, while a screen is open. It still works for dialogue choices.
- **Art wired:**
  - Merkitties swim (and sing at night) in the Merkitty Pool.
  - The catship chase shows the catship, the Grump ship and its crash as story panels.
  - The mercat speaks with a portrait.
- **Rooms:**
  - Floors no longer have dark stripes across every row.
  - The "barrels" that were actually a life ring are real barrels now.

## What to test (10 minutes)
1. Enter and leave Old Moss's hut (marsh) and the river hut.
2. Walk into the inn and the smithy: the floors should be clean planks and stone.
3. Penguin arc with the pool built: look for merkitties.
4. Plans board with materials only in a chest: you can build.

---

# PART 2 — New decisions

1. **Armour recipes:** Crystal at anvil tier 4, Moon at tier 5, +1 tempering for every set. *Default: keep.*
2. **Building from chest materials:** *Default: keep.*
3. **Full slot inventory** (from Guide 14). *Default: yes; I'll start it next loop.*

---

# PART 3 — Art, in order

1. **Prompts 19** (edges, interiors, last stand-ins): 15 prompts, 43 images. Most important.
2. **Prompts 20** (8 prompts) and **Prompts 21** (4 prompts).
3. **Prompts 22** (new): 1 prompt, 2 images: clean tables (some came back with captions painted on) and real barrels.
4. **Prompts 17** (12 prompts) and **Prompts 18** (6 prompts).

---

# PART 4 — Still open

Story answers (Guide 11, Part 3), music approvals (Guide 11, Part 5) and playtest notes.

---

# PART 5 — What's left on my side

| Work | Hours | Needs you? |
|---|---|---|
| Wire Prompts 17–22 art as it arrives | 20–26 | The art |
| Slot-based inventory (drag, split, lock, trash) | 4–6 | Decision 3 |
| Room side and front walls in code | 2–3 | No |
| Beach sea as one water body | 2 | No |
| Story rework with your answers | 8–14 | Yes |
| CONDUCT loops 4–10 | ongoing | No |

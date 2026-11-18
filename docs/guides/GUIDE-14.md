# Guide #14: CONDUCT loop 2 of 10

Play: https://excivious27.github.io/Dreams/

This loop: a fresh 20-agent audit (each agent also re-checked loop 1's fixes), 20 bots (0 errors, 0 fails), fixes, Prompts 21 and this guide. Anything not listed here stands as in Guides 12–13.

---

# PART 1 — What changed, and what to test

## Fixed
- **Shops you couldn't open:**
  - Orla stood on her own counter, so her flour shop never opened. She stands beside it now.
  - Granite stood on his office door. He's moved, so you can get to his shop (and the glass).
- **Walking out of huts:** leaving Old Moss's hut or the river hut no longer drops you inside a wall.
- **Enemies inside walls:** spawn checks were looking one row too low, which put about 18 enemies in walls or water. Fixed.
- **Lieutenants:** Pike and Ostrova (who only appear in battles) count toward "8 of 8" again. My loop-1 change had broken that.
- **Fishing:**
  - The farm pond now uses the same fishing as everywhere else; it was the best fishing spot by accident.
  - Every fish list runs cheapest to priciest, so rare fish stay rare everywhere.
- **Tools:** the copper axe and copper pickaxe now actually hit harder.
- **Mines:**
  - Deep floors were getting more enemies, not fewer. There's now a hard cap (about 7 on early floors, 15 at the bottom).
  - The floor keeper now gets tougher gradually through floor 10 instead of jumping at floor 6.
  - An **arrow at the screen edge** points to the awake keeper (red) or the open shaft (green).
- **Skill trees:**
  - Capped filler no longer turns into hundreds of max energy. It's now "levels faster in this skill" (up to +50%), with real caps on health, energy, mana and battle supply.
  - Node names don't repeat.
  - The skill headers show their painted icons.
- **Combat:**
  - Gift powers have an 8-second cooldown.
  - Tapping an enemy hits it even when the pup is right there.
  - In the first meadow fight the sword comes out for you.
  - A boss that only takes glancing blows tells you how to hit it properly.
  - Vance's opening works.
  - Bosses can't raise a shield during their opening.
- **Interiors:**
  - Rooms now sit above the indoor HUD, so the door and the bottom rows aren't hidden.
  - Ground pieces (the moon warp pad, the hot spring, decals) were being drawn under the ground. They show now.
- **Water edges:** shorelines are rounder; they no longer follow the square grid.
- **Icons:** the 13 spell icons, the sorcery and pup node icons and the skill badges from your earlier sheet were sliced wrong. They're in now, so the Cast list shows real spell icons.
- **Story:**
  - Big Jim no longer talks in the baby-crystal scene before he has joined you.
  - Sal also joins if you find her at the inn.
  - The scene changing in the middle of a story choice can't crash the game.
- **All ages (gangster arc):**
  - The card parlour is an arcade.
  - Doc's story about the President's daughter no longer involves her dying.
  - Specs's and Sasha's "crate" lines no longer hint at people being shipped.
- **Economy:**
  - The salvage crew job brings one piece of scrap a night, not a pile.
  - Fuel cells can't be crafted for profit.
  - Shop items can't be bought and resold at a profit using crop or fish bonuses.
- **Inventory:** "Stack to chests" leaves your toolbar items alone, like Sun Haven's action bar.

## What to test (15 minutes)
1. Water mill: buy flour from Orla. Quarry: enter Granite's office.
2. Mine floor 3+: wake the keeper and follow the red arrow.
3. Open Magic → the Cast list: the spell icons should be real pictures.
4. Walk into any shop: is the whole room visible above the HUD?
5. Go to the lake and look at the shoreline.

---

# PART 2 — New decisions

1. **Mine enemy cap:** about 7 on early floors, rising to about 15 at the bottom. *Default: keep.*
2. **Gift power cooldown:** 8 seconds. *Default: keep.*
3. **Quick stack skips the toolbar** (Sun Haven style). *Default: keep.*
4. **Full slot inventory** (drag to rearrange, split stacks, lock slots, trash can) like Sun Haven. Today the bag holds 30 kinds and sorts, but you can't drag items between slots. *Default: yes, I'll build it in a coming loop.*

---

# PART 3 — Art, in order

1. **Prompts 19** (edges, interiors, last stand-ins): 15 prompts, 43 images. Most important.
2. **Prompts 20** (loop 1): 8 prompts, 20 images.
3. **Prompts 21** (new): 4 prompts, 10 images:
   - wall tops and night windows for rooms, and props that belong to each shop;
   - the fishing hut and beaver dam without painted water, plus pier pilings;
   - Biscuit as an old dog, plus two story panels;
   - an arcade ticket booth for the underground;
   - withered plants;
   - wind-up warning icons.
4. **Prompts 17** (12 prompts) and **Prompts 18** (6 prompts; the spell icons were dropped from it because they're already in).

---

# PART 4 — Still open

Story answers (Guide 11, Part 3), music approvals (Guide 11, Part 5) and playtest notes.

---

# PART 5 — What's left on my side

| Work | Hours | Needs you? |
|---|---|---|
| Wire Prompts 17–21 art as it arrives | 20–26 | The art |
| Slot-based inventory (drag, split, lock, trash) | 4–6 | Decision 4 |
| Room walls and floor cleanup in code | 3–4 | No |
| Story rework with your answers | 8–14 | Yes |
| Real music | 6 | Approve prompts |
| CONDUCT loops 3–10 | ongoing | No |

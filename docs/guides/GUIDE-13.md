# Guide #13: CONDUCT loop 1 of 10

Play: https://excivious27.github.io/Dreams/

This loop: a fresh 20-agent audit, 20 bots (20 of 20 finished, 0 errors, 0 fails), fixes for everything I could do myself, Prompts 20 for the new art, and this guide. Guide 12 still holds for anything not repeated here. Each question has a **default**.

---

# PART 1 — What changed, and what to test

## Fixed
- **Lost items:**
  - Silver and gold eggs, milk and wool were being thrown away. They now arrive with their stars.
  - A full bag no longer sends items into a farm chest you haven't built. They stay in your bag.
  - Stars on a crop can no longer move onto a later plain crop.
- **Partners:**
  - Sal now asks before selling your loot: tap once to hear the price, again within 5 seconds to sell. She never sells quest items.
  - Big Jim can't break ore your pickaxe isn't ready for.
  - Tapping the pup puts **Pet** first. Food only shows when it's hurt, cheapest meal that heals it first.
- **Fishing:**
  - The fish waits while a menu is open.
  - Rare fish are rare again; before, almost half your catches were the two most valuable fish.
- **Woodcutting:** trees take a few swings again, and the yield bonuses can't add 11 logs a tree. Woodcutter skills are now a chance for a double-deep swing.
- **Farming:**
  - Crops no longer show "ready" a day early.
  - The greenhouse plot has a stone border, so you can see where off-season crops grow.
  - The last-days warning is right.
  - Fertiliser no longer wastes itself on a ripe crop.
  - Fruit trees tell you when they'll sleep.
  - "Bring N crops" quests count fruit, herbs and flowers too.
- **Early fights:**
  - Starting areas need fewer swings.
  - The first meadow fight is 3 enemies, not 4, refilling to 2.
  - The gangster first boss hits like the penguin one.
  - The floor-1 mine keeper meets you at the floor's level.
  - The meadow boss counts meadow kills only.
- **Battles:**
  - "Follow me" keeps helpers with you during fights.
  - Strikers and turrets draw enemies onto themselves, not you.
  - Beating a lieutenant in a battle no longer skips their story fight.
- **Bosses:** burn damage no longer sets off a boss's counter-moves every second, and it now does real damage.
- **Economy:**
  - Prices no longer climb as Bartering rises.
  - Laundering always costs something.
  - Only one crew member per job.
  - Sprinklers no longer print money.
  - Granite sells glass, so the greenhouse and fuel cells don't need a deep Mining skill.
- **Skill trees:**
  - All 13 trees have unlocks now, including Hustle (Terminal/Clinic/Robotics blueprints, gun damage), Harmony (Radiance, Bloom), Leadership and Strategist.
  - Blueprints are near the start of each tree.
  - Node IDs no longer change, and points from any node that disappeared are refunded.
  - Health and energy nodes count from every tree.
  - No more nodes that do nothing because a cap was hit.
  - Skill icons are matched to the right node.
- **Mines:** breaking a rock no longer redraws the whole floor (less stutter on phones). The six grotto crystals now glint under the water.
- **Story:**
  - In the gangster arc, Sal always joins after the meadow (it used to depend on luck).
  - Marlene stands on the dock, not in the sea.
  - The knight mercy only works on the sky boss.
  - Sasha only speaks at the tower if she's in your crew.
  - Some text was softened for all ages (the bookie is now a sparring-ring announcer; crew like root beer, not wine).
- **Colonies:**
  - The ferry home no longer drops you inside the wreck.
  - Lit beacons light up at once.
  - A village house no longer blocks the plateau ramp.
  - Island shapes can never reshuffle.
- **Saves:** your Sort order survives a reload, hiding the tab mid-door can't save a bad position, and older saves get a full toolbar.
- **Sound:** a burst of pickups no longer cuts off other sounds. The chest screen has sounds.
- **Phones:** two things that ran every frame are fixed (an update check, and farm animals scanning the whole farm).

## What to test (15 minutes)
1. Pet the pup at full health: no food should be offered.
2. Fish for a while: are rare fish rare again?
3. Chop a tree: about 3–4 swings with the starting axe.
4. Gangster arc: clear the meadow, then talk to Sal.
5. Open Skills → Hustle or Harmony and look for the violet unlock nodes.

---

# PART 2 — New decisions

1. **Woodcutting:** trees take 4 swings with the starting axe (5 on the farm). *Default: keep.*
2. **Sal's fence:** two taps to sell. *Default: keep.*
3. **Glass at Granite's:** *Default: keep.*
4. **One crew member per job** (gangster HQ). *Default: keep.*

---

# PART 3 — Art, in order

1. **Prompts 19** (edges, interiors, last stand-ins): 15 prompts, 43 images. Most important.
2. **Prompts 20** (new): 8 prompts, 20 images:
   - farm fixes;
   - the ferry and Pip;
   - the lookout, crystal pylon and crystal trees;
   - small screen pieces;
   - story panels and Grandfather Auk's ghost;
   - Coldy and Big Jim cards;
   - the villagers' own walking sheets and winter portraits.
3. **Prompts 17** (12 prompts) and **Prompts 18** (6 prompts) as before.

Every prompt asks for at most 3 images, each labeled and separated.

---

# PART 4 — Still open

Story answers (Guide 11, Part 3), music approvals (Guide 11, Part 5) and playtest notes, as in Guide 12.

---

# PART 5 — What's left on my side

| Work | Hours | Needs you? |
|---|---|---|
| Wire Prompts 17–20 art as it arrives | 18–24 | The art |
| Story rework with your answers | 8–14 | Yes |
| Side stories | 10–16 | Optional |
| Real music | 6 | Approve prompts |
| Balance from your playtests | 6 | Your notes |
| CONDUCT loops 2–10 | ongoing | No |

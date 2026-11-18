# Guide #12: everything I need from you (CONDUCT round)

Play: https://excivious27.github.io/Dreams/

This round: a 20-agent audit, a 20-bot playtest, then a second 20-agent audit just for edges and transitions (water, beach, paths, cliffs, interiors). Everything I could do myself is done. This guide lists what only you can give me. Each question has a **default**; if you skip it, I build the default.

Reply any way you like: "12-3: yes", or "defaults for Part 2". Quote the number.

**Contents**
- Part 1: What changed, and what to test
- Part 2: New decisions (short)
- Part 3: Art, in order (Prompts 17, 18, 19)
- Part 4: Still open from Guide 11 (story, music, accounts)
- Part 5: What's left on my side

---

# PART 1 — What changed this round

## Your list
- **Edges and water:** water is now drawn as one shape with curved shores, foam and a darker bank, not a grid of squares. Dirt and sand paths and region patches (bog, snow, ruins, tracks) blend softly into the grass. The ground textures tile with no seams. The beach's waterline uses the same system. Prompts 19 is the art to finish this: proper bank, shore and edge pieces.
- **Blacksmith door:** walking into the front wall of any building now takes you in. Every outdoor door is now checked by an automatic test.
- **Interiors:** furniture now fits its spot instead of being huge, small rooms sit in the middle of the screen (no black void, no room pinned in a corner), and 282 pictures, plants and pieces of furniture were added to bare homes. You can walk out by holding down on the door. Proper floors, walls and rugs are in Prompts 19, batch 11.
- **Skill trees:** every tree now has real unlocks, framed in violet:
  - **Blueprints** to build new stations: Keg and Press (Farming), Kiln (Mining), Loom (Foraging), Fish Pond (Fishing), Tannery (Combat), Jeweler (Bartering), Garage and Cauldron (Building). You can't build these until you learn them.
  - **Spells from other trees:** Rain Call and Growth (Farming), Haste (Foraging), Lull (Fishing), Crystal Shield (Combat), Warp Home (Bartering).
  - **Faster walking:** a 5% node in six trees, up to +25% in total.
  - **Chop and mine faster:** extra hits per swing. **More damage:** +2 and +3 combat nodes.
  - Filler nodes that did nothing because a bonus was already maxed now give something else. All 520 node icons are in.
- **Inventory and chests (Sun Haven style):**
  - The bag holds 30 kinds of item. Each stack holds up to 999.
  - Backpack upgrades at Maple's add 12 slots each, up to 66.
  - When the bag is full, new items go to your farm chest instead of being lost.
  - **Sort** button.
  - **Stack to chests:** puts items into nearby chests that already hold the same thing.
  - Chests open a two-grid screen (chest on top, bag below). Tap to move all, 10 or 1; there's also Deposit all, Take all and Quick stack.
  - The farm chest holds 36 stacks and the shed 72. Placeable chests from Maple's hold 24 each. Gold and silver crops keep their stars in chests.
- **Mines:**
  - Floors are about 1.7× bigger, with about half as much ore.
  - Fewer enemies, scaled to cave size.
  - Floors 1–2 have only slimes and bats, and enemies on floors 1–4 are weaker.
- **Art you sent (16-1 to 16-7, 17-1, 17-3):** all wired in:
  - the lieutenants, Marisol and Bo, the Marked, Gift effects;
  - cyber stations, icons and effects;
  - HQ and Ward build stages;
  - 14 portraits;
  - Catkins, the finargles, the crystal babies, the merkitties and the catship;
  - four story panels (they appear inside dialogue);
  - skill icons.

## Also fixed
- **Crops** were invisible after tilling on some phones: the soil layer was hidden behind the map. Fixed. Beds now have rounded edges, and wet soil is darker instead of blue.
- **Battles:**
  - Supply builds more slowly.
  - Mend and barrage have cooldowns.
  - Enemies no longer spawn next to you or on a point you're taking.
  - A loss still gives some XP. Win and lose sounds.
- **Enemies:**
  - Shooters show a short aim flash before they fire, and only shoot at you.
  - Burns no longer stun-lock.
  - Early gangster fights are softer.
- **Fishing:** bait now does something (faster bites and a longer reach). Rare fish are random, not always the same one.
- **Animals:** feeding and petting is one tap, and goods are never lost.
- **Two copies open:** the game warns you instead of letting saves fight each other.
- **Story:**
  - Several beats that could fire twice or out of order are fixed.
  - The bell only halves the boss if the town helped.
  - The epilogue covers more of your choices.
- **Economy:** shop stock fixed (Tam, Marlowe, Moss), a weekly gift cap of two per villager, and the Iridium Sprinkler recipe.

## What to test (20 minutes)
1. Open Skills: buy a blueprint node, then build that station from the plans board.
2. Fill your bag in the mine and watch the overflow go to the farm chest. Open the chest, press Sort, try Move: 10.
3. Mine floors 1–3: is it big enough, and are enemies and ore about right?
4. Walk into the blacksmith and a couple of homes. Do the rooms look better?
5. Look at the town river and the beach: are the edges better? (Prompts 19 finishes them.)
6. Till, plant and water: can you see the crops clearly?

---

# PART 2 — New decisions

1. **Bag size:** 30 kinds of item, with three backpack upgrades to 66. *Default: keep.*
2. **Backpack prices** (◆ at Maple's, before haggling): about 600 / 2,400 / 7,500. *Default: keep.*
3. **Blueprints locked behind skills:** should stations you had already built stay usable? *Default: yes; only stations you haven't built yet need the node.*
4. **Mine size:** about 1.7× bigger now. Want even bigger (2–3×) with a minimap? *Default: keep it, and add a minimap if you'd like.*
5. **Mine ore:** about one rock in six carries ore. *Default: keep. Tell me if it's now too stingy.*
6. **Gift cap:** two gifts a week per villager (birthdays don't count). *Default: keep.*

---

# PART 3 — Art, in the order to make it

Every prompt now asks for **2 or 3 images**, each labeled and separated, so ChatGPT copes. Paste one prompt per chat and save each image under its file name.

**1. Prompts 19 (new, most important): 15 prompts, 43 images.** Edges first, in this order:
- 19-1 rivers;
- 19-3 beach;
- 19-2 ponds;
- 19-4 grass to dirt and mud;
- 19-10 the farm;
- 19-11 interiors;
- 19-9 paths;
- 19-8 cliffs;
- then the rest.

19-13 (gangster walk cycles) and 19-14/15 (enemy attacks, partner effects, ore, icons) replace the last stand-ins.

**2. Prompts 17: 12 prompts left, 22 images.** Merkitties and the catship are in: the pool's singing merkitties, the gift ring, the catship and Grump ships, the litter catapult, and their icons. Still owed: Prompts 13's penguin creatures and places, the last item icons, screens, ending paintings, the app icon, and skill icons for the trees not yet done.

**3. Prompts 18: 6 prompts, 15 images.** The pup and its gear, the moving colony bosses, spell and UI icons, night lights, the Hollow Heart.

Prompts 16 is complete. Thank you.

---

# PART 4 — Still open from Guide 11

- **Story (Guide 11, Part 3):** the penguin and gangster spines, the colonies, the lieutenants, the Marked, side stories, tone checks. This is the biggest thing only you can give. Even one line per question helps.
- **Music (Guide 11, Part 5):** 28 tracks are ready to send to ACE Music one at a time once you approve each. Say "send track 1" to start.
- **Accounts (Guide 11, Part 6):** a multiplayer relay host is optional. *Default: skip for now.*
- **Playtesting:** every few days, one thing that felt good, one thing that felt confusing or ugly (a screenshot is perfect), and anything your daughter said.

---

# PART 5 — What's left on my side

| Work | Hours | Needs you? |
|---|---|---|
| Wire Prompts 17–19 art as it arrives (edge kits, interiors, walk cycles) | 16–22 | The art |
| Story rework with your answers | 8–14 | Yes |
| Side stories | 10–16 | Optional |
| Real music | 6 | Approve prompts |
| Balance from your playtests (mines, battles, economy) | 6 | Your notes |
| Ten more CONDUCT rounds (you asked for these) | ongoing | No |

**About 50–65 hours of work remain. The game is about 55% done.**

# Guide #17: CONDUCT loop 5 of 10

Play: https://excivious27.github.io/Dreams/

**This loop:**
- 20-agent audit.
- 20 bots, run twice: 0 errors, 0 fails. Before the fixes, one bot hit a crash in the menu; it's fixed.
- Scripted playtest: 0 fails.
- About 200 fixes.
- Prompts 24 (new, small) and this guide.

Guides 12–16 still apply to anything not repeated here.

---

# PART 1 — What changed, and what to test

## Bag, chests, saves
- Scrolling the Items tab no longer picks up or moves items by accident.
- Locks survive a trip through a chest.
- Keys and quest items stay out of chests.
- Moving into a full bag or chest tells you it's full.
- Building from chest materials can't duplicate gold or silver stars.
- Bundles and colony hand-ins skip locked items and use your cheapest fish first.
- Closing the app, or "Save & back to title", resumes where you stood.
- Board jobs no longer leak between save slots.

## Skills
- **Iron Gut** is a real unlock now: immune to poison and burn.
- **New unlocks:**
  - Wide Spout: the watering can covers more.
  - Tremor: the pickaxe hits nearby rocks too.
  - Domino Fall: a felled tree topples the next.
  - Tidecall.
  - Lucky Day.
  - Quick Build.
  - Not Today: survive one knockout a day.
  - Twin Cast: a spell sometimes costs no mana.
- **Old saves:** points in a replaced node are refunded. Killing Edge ranks become Keen Edge.
- **Balance:**
  - Per-tree caps, so filler ranks always give something.
  - Tempered gloves, capes and belts add stats.
  - Crystal recipes are no longer listed twice.

## Combat
- The scattergun hits each foe once per blast.
- Gravity pulls can't drop foes inside walls.
- Stun powers barely hold bosses.
- Summoned minions pay nothing.
- Battle and quest weapon prizes go to your tools, so you can use them.

## Economy
- **Energy:** raw fish, crops and forage now give a little energy (2 per heart). Cooked food and potions are unchanged.
- **Prices and food:**
  - Shop bread and meat give less energy and cost more.
  - The buy price can never drop below the sell price.
- **Fishing:** the farm pond has six common fish, and fishing XP is lower.
- **Starting out:** trees give 4 wood, and you start with 10 turnip seeds.
- **Names:** every seed is "… Seeds".

## World
- **Town:** café tables and racks are out of the river.
- **Lake:** the east dock reaches the shore.
- **Crystal meadow:** the glow turf has soft edges.
- **Buildings:** the fishing hut, lighthouse and bridges lost their painted blue boxes.
- **Mines:**
  - Floors draw in chunks, so big floors are much lighter.
  - Floor 3 no longer jumps in enemies.
  - The deep-floor enemy count is capped.

## Story
- Every villager offers their own ♥6 quest.
- Wren, Lumi and Rook have gangster-arc lines.
- Keeping the letter has its own beat.
- The penguin arc has a quest pointing to the finale.
- Villagers the story sends away stop sending mail, gifts and board jobs.
- A Fennimore you defeat isn't "freed" in the ending.
- 25 more lines softened for all ages: no deaths on screen, no wine jokes, no gambling words.

## Phone screen and rooms
- USE/CHECK are clean circles.
- Indoors, the energy bar sits inside the HUD instead of over the room.
- Hints say "USE: …" instead of "A: …".
- At the bed the button shows a hand with "Sleep".
- Toasts have a dark backing.
- **Rooms:**
  - The hall and inn fit the screen.
  - The chapel has real pews.
  - Shopkeepers stay at their counters.
  - The store's captioned crates are gone.
  - Each kind of room gets its own furniture.
- **Feel:**
  - A little hitstop on swings.
  - Level-ups and builds chime.
  - Screen shake has an on/off setting in Options.
- Talking beats the pup for the crew and Catkins too.

## What to test (10 minutes)
1. Walk into the inn, the hall and the chapel. Do they fit, and do they look furnished?
2. Scroll the Items tab with your finger. Nothing should move.
3. Eat a raw fish when you're low on energy.
4. Go down three mine floors. Does it feel fair, and is it smooth?
5. Check the new unlocks in the skill trees (Foraging, Mining, Farming).

---

# PART 2 — New decisions

1. **Raw food gives a little energy** (2 per heart; cooked food unchanged). *Default: keep.*
2. **Balance calls I didn't make:**
   - caps on pup bite, energy per kill, gun and helper damage, and team healing;
   - berry bushes refilling every 3 days instead of daily.

   *Default: leave as is until you play.*
3. **Total health/energy cap across all trees:** it would cut late saves by up to about 400 max health. *Default: no.*

---

# PART 3 — Art, in order

1. **Prompts 19** (edges, interiors, last stand-ins): 15 prompts, 43 images. Still the most important.
2. **Prompts 23**: 5 prompts, 11 images: boss banners, gift effects, party cards, outfits, headgear and portraits.
3. **Prompts 24** (new): 2 prompts, 5 images:
   - faces for Big Grump and the Grump Commander;
   - the hero's face in the six new outfits;
   - missing pet poses (fetch, beg, play, dig);
   - attack frames for the golem and the shard.
4. **Prompts 20** (8 prompts), **21** (4) and **22** (1).
5. **Prompts 17** (12 prompts) and **18** (6 prompts).

---

# PART 4 — Still open

Story answers (Guide 11, Part 3), music approvals (Guide 11, Part 5) and playtest notes.

---

# PART 5 — What's left on my side

| Work | Hours | Needs you? |
|---|---|---|
| Wire Prompts 17–24 art as it arrives | 24–30 | The art |
| Re-slice furniture sheets cut as whole rows (chairs, stools, pews, shelves) | 2 | No |
| Map drawing in chunks (fewer draw calls on phones) | 3–4 | No |
| Big Coop / Big Barn / Silo effects | 2 | No |
| Story rework with your answers | 8–14 | Yes |
| CONDUCT loops 6–10 | ongoing | No |

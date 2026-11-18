# Guide #19: CONDUCT loop 7 of 10

Play: https://excivious27.github.io/Dreams/

This loop had five parts:
- a 20-agent audit;
- 20 bots, run before and after the fixes, with 0 game errors (one bot-tool slip is fixed);
- check.sh and the scripted playtest, all passing;
- about 150 fixes, plus 173 re-cut art files;
- Prompts 26 (new, small) and this guide.

Guides 12–18 still apply to anything not repeated here.

---

# PART 1 — What changed, and what to test

## Fixed a crash
- A new game with items in the sell box before your first sale to Sal could crash overnight. Fixed.

## Smoother still
- A farm with lots of tilled soil costs far less to draw.
- Walking into new areas hitches less.
- The water shader costs about half as much.
- Bloom, Rain and Growth spells no longer redraw the whole map.
- In co-op, the guest's screen only redraws when the farm actually changes.
- High-DPI rendering is off on the web build: it's faster, but the art may look slightly softer (Decision 1).

## Energy and money
- **Energy:** food, rest spots, Mama Rosa and energy from kills all share the same one-bar daily allowance. Food you eat past the cap stays in your bag.
- **Kills:** crystals from kills are capped at 12 kills a day per map.
  - Each mine floor counts separately.
  - Bosses, battlefields and colony foes always pay.
- **Fishing:** the rare-fish perk can no longer pull 170-crystal fish all day.
- **Gangster arc:** the Cherry Fizz recipe is no longer an energy battery.
- **Pup:** its bite has a cap.
- **Old saves:** points in the changed pup and combat nodes are refunded.

## Fights
- Enemies only plan paths nearby, so big maps no longer stutter.
- Shooters walk to where they can see you.
- Chasers wait instead of running into walls.

## Farm
- The coop and silo respond on every tile.
- A co-op guest's scythed hay is kept.
- The scarecrow and the Plans board moved out of the greenhouse plot, so planted glass is safe.

## Mines
- Lamps show.
- No rocks stuck inside lava or chasms.
- Bigger stones.
- Crystal caves have more contrast.
- Floors keep growing past floor 40.
- Every 5th floor now has an old miner's dropped pack instead of a skeleton (all ages).

## Story and quests
- **Gangster arc:**
  - The tower-door letter scene plays once.
  - Marlene won't buy a letter you've already used.
  - "The Chair" ending matches its slides.
- **Penguin arc:** after the Commander, the next step points you to the mountain babies.
- **Quests:**
  - Sal's coffee quest can be finished.
  - Board jobs expire.
  - Lumi's, Posy's and Benno's quests point to the right season and station.
- Catkins can be befriended and given gifts.

## Screen, rooms, sound
- **Portraits** show one face each (some had two), and the Dark Broad hero portraits are whole.
- **Rooms:**
  - Pictures don't hang over windows.
  - Stained glass dims at night.
  - The farmhouse rug is a real rug.
- **Quest toasts** say what you earned.
- **Sounds:**
  - The gangster opening really rains.
  - Rocks crunch when they break.
  - A pick that's too weak clinks.
  - Bosses sound an alert.
  - The Hollow Heart has no rain and no winter wind.
- **Re-cut art:**
  - the bakery oven, taps and kettle;
  - farm buildings (greenhouse, windmill, coop, barn, silo, sprinklers, fish pond);
  - the 17 big border trees and villager walking strips;
  - the lookout tower and hot spring.

## What to test (10 minutes)
1. Start a new game, put a turnip in the sell box and sleep. You should wake up fine.
2. Walk through town and a battlefield. Is it smoother?
3. Look at the bakery and the farm buildings. Is each one shown once, with no copies or labels?
4. Fish at the lake for a while. Does it still feel worth doing?
5. Check the art doesn't look too soft on your phone (Decision 1).

---

# PART 2 — New decisions

1. **High-DPI off on web:** faster, possibly a bit softer. *Default: keep unless it looks blurry to you.*
2. **Kill crystals capped at 12 a day per map** (bosses, battles and colonies exempt). *Default: keep.*

---

# PART 3 — Art, in order

1. **Prompts 19:** 15 prompts, 43 images. Still the most important.
2. **Prompts 23–25:** 9 prompts, 20 images:
   - boss banners;
   - party cards;
   - outfits;
   - faces;
   - pet poses;
   - partner and unlock icons.
3. **Prompts 26 (new):** 1 prompt, 2 images:
   - seamless glowing ground (teal moss and violet soil) for the Hollow Heart, Jungle and Kelp colony;
   - storm puddles.
4. **Prompts 20–22**, then **17–18**.

---

# PART 4 — Still open

- **From you:** story answers (Guide 11, Part 3), music approvals (Guide 11, Part 5) and playtest notes.
- **On my side:** the enemy art from sheets w231–w243 still needs a careful re-cut.

---

# PART 5 — What's left on my side

| Work | Hours | Needs you? |
|---|---|---|
| Wire Prompts 17–26 art as it arrives | 26–33 | The art |
| Re-cut enemy sheets w231–w243 | 1–2 | No |
| Story rework with your answers | 8–14 | Yes |
| CONDUCT loops 8–10, then the combined guide, prompts and progress sheet | ongoing | No |

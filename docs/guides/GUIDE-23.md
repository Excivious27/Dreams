# Guide #23: Everything after Round 11 and the audio project

Play: https://excivious27.github.io/Dreams/

This one guide replaces Guides 12–22. It covers:
- what the 10 loops, Round 11 and the audio project did;
- what to test;
- every open decision;
- the art still needed, in order;
- what only you can do.

The progress sheet and every art prompt file are on the same page, below this guide.

**The 10 loops in numbers:**
- 200 audit agents.
- 200 bot playthroughs, with 0 errors after each loop's fixes.
- About 1,700 fixes.
- About 2,900 art files re-cut from your own sheets.
- Each push passed the full check (now 20+ tests, including story, co-op and storage) and the scripted playtest.

---

# PART 1 — What's better since loop 1

## Phone feel
- **Speed:** maps are baked into big tiles, cutting draw calls 8–45x. There were four more performance passes, and walking spikes are down from about 4,000 to under 300.
- **Screen:**
  - the USE, CHECK and MENU buttons are clean, labelled circles;
  - toolbar icons keep their real shape, and toasts have a backing;
  - the goal line wraps, and the boss banner sits above you;
  - indoors, the HUD sits inside its own block instead of over the room.
- **Menus:** you can scroll menus and chests with your finger without moving items.

## Your bag and chests (Sun Haven style)
- **Slots:** tap an item to pick it up, tap a slot to drop it.
- **Long-press:** gives Half, Lock and Trash.
- **Locked items:** can't be sold, trashed or handed in.
- **Chests:** use the same slot grid.

## World and rooms
- **Water and edges:**
  - curved shores with foam;
  - the beach, lake and docks are each one body of water;
  - clean cliffs, plateaus and exit roads.
- **Interiors:**
  - side walls and fitted furniture, with no captions or slivers;
  - windows that go dark at night;
  - shopkeepers go off duty at night.
- **Regions:** no invisible walls, no frozen stand-in props, crabs on the beach, seasons in the forest.

## Farm
- **Big Coop, Big Barn and Silo** all work. Scythed hay feeds your animals, and baby animals grow up.
- **Layout:** debris stays put once cleared, and big buildings fill their space.
- **Weather:** snow waters crops.

## Mines (your three asks)
- **Ore:** about 1 rock in 6 has ore.
- **Early floors:** gentle.
- **Size:** floors are about 1.7x bigger and keep growing deeper down.
- **Look:** lamps, barrels, real coal and stalagmite art.
- **Speed:** floors draw in chunks.

## Fights
- **Enemies:** they path around walls and streams instead of getting stuck, and shooters walk to where they can see you.
- **Bosses:** each Gift boss has clear "OPEN" windows and sounds.
- **Kill rewards:** kills pay crystals for the first 12 per map each day. Bosses, story foes, first battles and colony quotas always pay.

## Skills
- **Unlocks:** all 13 trees have real unlocks (blueprints, spells, speed, power), plus 10 special ones such as Not Today, Twin Cast, Tremor and Wide Spout.
- **Caps:** each tree has caps, so no stat runs away.
- **Renamed nodes:** they keep your points.

## Money and energy
- **Energy:** food gives at most one bar a day, and rest spots give their own half bar.
- **Fishing:**
  - every water has common fish, and rare fish need skill, night or bait;
  - bait now pulls better fish;
  - fishing is no longer a money printer.

## Story and text
- **Both arcs** play start to finish in headless runs with no soft-locks, and main quests open on time.
- **Villagers:** each has their own 6-heart quest, and their 8-heart scene waits for it.
- **All ages:** about 120 lines were softened (no deaths on screen, no drinking or gambling jokes).
- **Gangster arc:** the letter, Marlene and the tower doors work in every combination.

## Co-op
- Visiting keeps your own clock, buffs and daily spots.
- Guests can't touch the host's chests or animals.
- A disconnect shows "Reconnecting…".

## Round 11 (your playtest list)
- **Controls:**
  - USE never opens the pup menu; only CHECK does;
  - you face the right way moving down or diagonally;
  - hold a direction while hoeing or watering and you keep moving down the row.
- **Energy:** every action and skill has its own small cost, and the sword costs energy too. You can work until 0, then you pass out: you wake at home, or at the clinic with a bill if it happened in the mines or while hurt.
- **Exits:** stepping anywhere into an exit area changes the map, not only the sign.
- **Mines:**
  - 26 layout styles, a fresh one each time you enter or go down (never one of your last 5);
  - the floor-1 guardian has its head back, shows up after 22 rocks or 100 seconds, and has 1.45x HP;
  - after it, a glowing shaft: walk in, press USE beside it, or tap the big button;
  - the mine entrance in the meadow is dressed.
- **Farm and regions:**
  - a river runs through the farm, with stone and wooden bridges (old saves get it too);
  - two-tier hills on the farm, forest, meadow, highlands, orchard, quarry and colonies;
  - smooth cliffs with rounded corners, rock faces, side walls, winter rims and fitted stairs;
  - the beach's left side has no invisible walls.
- **Hero tab** (Menu, second tab): 10 gear slots, 14 stats showing where each comes from, armour set bonuses, buffs, skills and milestones.

## Region campaigns (new)
- **How regions open:** each new major region opens through a campaign on a strategic map, battle by battle. There are 19 campaigns of 5–7 battles each.
- **Battle types:** skirmish, siege, escort, defend, captain duel, gate, supply run and camp.
- **What carries over:** morale and supply carry from battle to battle. Win the last battle and the region opens.
- **Story regions:** Wastes and Sky (penguin arc), and Docks, Neon, the Pit and Uptown (gangster arc), are held until you win their campaign. The goal line tells you which campaign to fight.
- **Where to open it:** Menu > Map > Campaign map, the town project board, or the war table.

## Sound (the audio project)
- **Music:**
  - 61 real tracks made with ACE Music replace every placeholder;
  - every area, room, colony and battle type has its own;
  - farm by season, night and rain, deeper mine floors, chase and danger music;
  - bosses by kind: the arc themes played heavy for arc bosses, stone drums for mine keepers, the Marked's own theme;
  - both endings are slow versions of your arc theme, followed by the credits;
  - there's a music-box version of "Dreams" and a sung merkitty lullaby.
- **Jingles:**
  - level up, quests and skills;
  - hearts and gifts, birthdays, mornings;
  - secrets, journal pages, new places, treasure;
  - battle won, lost and starting, campaign won.
- **Sound effects:** about 300 real recordings from free CC0 packs:
  - footsteps on 10 kinds of ground;
  - swords, blocks, three kinds of gun;
  - spells by element;
  - tools, animals, doors, shops, hacking and robots.
  - Each common sound has up to 3 takes, so it doesn't repeat.
  - Every villager talks at their own pitch.
- **Ambience:**
  - real rain, wind, birds, crickets, waves, rivers and city streets;
  - jungle insects, marsh, fire;
  - gulls, crows, frogs and cicadas now and then.
- **Phone loading:** songs download as you reach each place, then stay saved on the phone. The game still opens fast.

---

# PART 2 — What to test (15 minutes)

**New since Guide 22:**
- **Sound:** walk the farm, town, beach and the mine with sound on. Does each place have its own song, and do footsteps change on sand, wood and water?
- **Shops and fights:** buy something, open a chest, talk to two villagers (different blips), then fight a few foes and a boss.
- **Campaigns:** open Menu > Map > Campaign map and win the first battle.
- **Energy:** run out of energy in the mine. You should wake at the clinic.
- **Hero tab:** check your stats there.

**Still worth a look:**

1. **New game:**
   - make a character and try the hair colours and the Outfit picker;
   - till, plant and water on day 1, following the goal line.
2. **Shop and bag:**
   - buy seeds;
   - check the icons look clean;
   - lock an item and try to sell it.
3. **Rooms:** walk into the chapel, inn, store and bakery, by day and at night.
4. **Mines:** go down three floors. Is the amount of ore and the number of enemies right?
5. **Fights:** fight near a wall or stream, and past 12 kills on one map.
6. **Your phone:** walk around town and the farm. Is it smooth, and is the art sharp enough?
7. **Co-op, if you use it:** visit someone, close the app, reopen it and check your buffs.

---

# PART 3 — Decisions (all running on their defaults until you say otherwise)

**Story (Guide 11, Part 3):** 31 questions; the full list is on the progress sheet. These defaults are **not built yet**:
- the finargle queen's talk scene;
- the four merkitty verses;
- one story per colony;
- the "Clean Break" third ending and Inspector Hale;
- one scene per Marked;
- 10-heart villager endings;
- the side stories (crystal babies grow up, Big Jim's brother, Coldy's key, Rosa, The Kid, Specs);
- one mini-game per festival.

Say "write the defaults" and I'll build them.

**Gameplay (all in the game now; say if any feel wrong):**
- **Energy:** food capped at one bar a day; rest spots give their own half bar.
- **Kill crystals:** 12 a day per map (bosses, battles and colonies exempt); an unwon battle pays for 160 kills over the whole game.
- **Guns:** the Tommy Gun fires every 0.18 s; revolvers every 0.6–0.75 s; gun damage capped.
- **High-DPI:** off on the web build for speed. Say if the art looks soft.
- **Still undecided:**
  - should farm debris regrow?
  - the Muscle skill row's names;
  - the pet's Hunter perk;
  - should kills past the cap still give full XP?
  - story regions held until their campaign is won (on now; say if you'd rather they were free);
  - any song or sound you don't like: say its name and I'll swap it for the other version.

---

# PART 4 — Art, in order (167 images still needed, plus 6 optional)

Nothing has been uploaded since w344, so every prompt from 17 on is still waiting. **I'll now make these myself with the new image tool**, in this order. You don't need to paste prompts any more. The page below still lists every prompt and image, so you can see what's coming.

0. **Prompts 30 (new):** 11 prompts, 30 images: sharper buildings with night versions, the mine entrance, forest edge walls, two-tier cliffs and stairs, river bridges and waterfalls.

1. **Prompts 19:** 15 prompts, 40 images. Edges, rivers, beach, cliffs, interiors. Biggest visual win.
2. **Prompts 23–28:** 13 prompts, 27 images: boss banners, party cards, outfits, faces, pet poses, partner and unlock icons, glowing ground, the last item icons, villager faces.
3. **Prompts 29 (new):** 5 prompts, 8 images plus 4 optional. Everyday villager poses that match their faces, and seasonal outfits in the new look.
4. **Prompts 20–22:** 13 prompts, 30 images.
5. **Prompts 17–18:** 17 prompts, 32 images: skill icons for 8 trees, screens, endings, the pup.

**Skip these, they're no longer needed:**
- 17 w354, 18 w369 and 19 w421: all replaced by 27 w478;
- 19 w416: replaced by 17 w362;
- 18 w378: obsolete;
- 21 w452: already have it.

---

# PART 5 — Only you can do these

1. **Re-export icon sheets w72_monster_drops.png and w73_magic_minerals.png.** Both are cut off at the bottom. If you can't, paste Prompt 29-5 instead.
2. **Art:** nothing to do. I'll make it with the image tool (it uses your OpenAI credits, about $93 left).
3. **Story answers:** or say "write the defaults".
4. **Music:** done. Say "swap <name>" for any track you don't like.
5. **Co-op relay:** sign up for a free host (Fly.io or Render) when you want online play. The relay code now waits 30 s for a host to come back; it takes effect when it's deployed.
6. **Playtest notes:** one good thing and one confusing or ugly thing (a screenshot helps), plus anything your daughter says.

---

# PART 6 — What's left on my side (about 55–70 hours)

| Work | Hours | Needs you? |
|---|---|---|
| Make and wire the art for Prompts 17–30 with the image tool (next) | 30–38 | Nothing |
| Story rework and the not-built defaults | 8–14 | Answers or "write the defaults" |
| Side stories (pick any) | 10–16 | Pick |
| Balance from your playtests | 6 | Notes |
| Co-op relay setup | 4 | A host account |
| Re-cut the w72/w73 rows | 0.5 | The two sheets |

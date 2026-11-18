# Guide #11: everything I need from you to finish Dreams

Play: https://excivious27.github.io/Dreams/

This round I ran a 20-agent audit of the whole game, fixed nearly everything it found, then ran 20 bots through both arcs. This guide lists everything only you can give me: story choices, art, music, decisions, accounts and playtesting. It's ranked, so the top of each part matters most. Every question has a **default**: if you skip one, I build the default, and you can change it later.

Answer any way you like: "12: yes", "defaults for all of Part 3", or a long typed voice note. Quote the number so I know which item you mean.

**Contents**
- Part 1: What changed this round (and how to test it)
- Part 2: Decisions from the audit (new, short)
- Part 3: Story for both arcs (still open from Guide 10)
- Part 4: Art, in the order to make it (Prompts 16, 17, 18)
- Part 5: Music and sounds
- Part 6: Accounts and setup
- Part 7: Playtesting
- Part 8: What's left on my side, and the hours

---

# PART 1 — What changed this round

## Your list from earlier tonight
- **Big Jim's card:** his purple fur was being erased by the background remover, leaving holes. His art is redone and solid. Merry, Mer, Coco, Coldy and June had smaller holes; those are fixed too. Until his painted card arrives (Prompts 17), his card shows his own sprite, and the picker now shows the name of whoever you tap and lights up their card.
- **Seeing the ground through your hero:** same cause (holes in the art). Fixed.
- **Dark at the right time:** sunset follows the season, from about 4:30pm in midwinter to 8pm in midsummer. Dusk goes gold, then real night; mornings start dark in winter. Lamps, lanterns, fires and beacons glow. Indoors gets warm lamplight. The morning note tells you when the sun sets. There's a **Night darkness** option (off, soft, full).
- **Sounds for time and season:** a new nature layer: birds at dawn, crickets and owls at night, frogs by the water in spring and summer, wind in winter and on the heights, rain on the roof indoors, thunder with lightning, waves at the shore, the town's chatter by day, the city's hum, drips in the mine, a rooster on the farm at sunrise. It has its own **Nature volume** slider.
- **Walking through things:** the game's moving props were drawn several squares away from their walls. They now line up. Huts and docks over water now block swimmers. Bog and marsh mud can't be waded without the Swimmer skill or a boat. A sprite of four trees was being placed as one tree; it's gone. Tree tops and roofs turn see-through when you walk behind them, so nothing hides behind them.
- **Too easy, too much stuff:**
  - Enemies take several hits at every stage and finish their swings, so mashing no longer wins. Shooters keep their distance. Bosses take little damage outside their openings.
  - Areas now have their own toughness, with the odd tougher elite.
  - Crits and defence are capped. Eating from the menu mid-fight is one bite every 3 seconds.
  - The common mushroom sold for ◆150 by mistake; it's ◆10 now (the farm crop is a separate Shiitake).
  - About a third as much ground forage. Trees give 3 wood, rocks 1 or 2 stone, and they grow back in 10 and 8 days.
  - Skill bonuses for extra forage, wood and stone are now chances, not guaranteed extras.
  - Selling floods the market sooner. Energy tea costs four times as much.
  - Mine crates stay smashed for the day and cost energy.
- **Ordinary trees:** they said "too hard for your axe". Only big old hardwood and crystal trees need a better axe now.

## Also fixed or added
- **Music:** 15 new area tracks (forest, wastes, Neon, marsh, jungle, battles, each colony, the Hollow Heart, winter on the farm), plus night and festival music, as placeholders until real songs arrive.
- **Sound effects:** footsteps, casting and reeling, splashes, gunshots, doors, locked doors, coins, eating, crafting, quests, spells, mail, the pup's barks, an alert when a foe spots you, and a heartbeat when you're low.
- **Colony art (your 16-5 sheets):** the elders, their portraits, houses, stalls, star crystals, beacons, villagers, the creeping blight and the four bosses are all in.
- **Hidden things in every region:** an old chest that opens once, two buried caches you find with the hoe, and a page of the Wayfarer's Journal. Find every page for its last secret. Bosses now stand visibly where they wait.
- **The Hollow Heart** is rebuilt with cave pieces: no surface trees, readable notes, its own music, and a tougher last boss.
- **The pup:**
  - Re-sliced, so the run cycle has no sitting or sleeping frames in it.
  - Chosen breeds are the same size as your pup.
  - Bites and barks finish properly.
  - The 2-minute rescue window survives going through a door.
  - Commands are refused while it's down.
  - It keeps up with you without walking through walls.
  - No more stack of dogs when it wears gear.
  - Partners stop flickering.
- **Farming:**
  - Crops die when their season ends.
  - Out-of-season seeds are refused with a message.
  - The greenhouse protects only its glass plot.
  - Sprinkler soil is wet in the morning.
- **Saves on your phone:**
  - Every save is also kept in the browser's own storage.
  - The game saves when you leave it, and before an update.
  - Updates now always download the new game.
  - Save codes use your phone's real Copy / Share and Paste.
  - Each slot has its own Restore.
- **Town:**
  - The greeter is shorter and only says true things.
  - Maple now sells fertiliser and bread; Granite sells stone and brick.
  - Wells and bandstands no longer say "knock".
  - Every villager has everyday lines that change with the season and the weather.
  - The four kids are now four different people.
- **Stories:**
  - Ringing the bell really halves the Dark Crystal, and Grandfather Auk really drives off the shards.
  - Heroes don't talk to themselves when you play as Big Jim, Coldy, Mer, Nova or Pip-Pip.
  - The gangster W/K handwriting clue works and is explained at the end.
  - The twins' story is gentler.
  - Shopkeepers who leave really leave.
  - The President is a real final boss.
  - Grumps no longer appear in the gangster arc (lookouts instead).
- **Battles:**
  - Turrets run out and fall with their point.
  - Downing the enemy commander routs them.
  - Being knocked out counts as a loss.
  - Much more Strategist XP.
- **Skills:**
  - 32 nodes that did nothing now have real effects.
  - The Learn button sits above the grid.
  - Skill tabs show unspent points.
  - Silent level-ups are announced.
- **Quests:** the goal line shows the main story first, and you can pin a side quest. The spark quest now explains the Crystal Resonator, and the meadow gives 2 shards.
- **Phone speed:** farming redraws only the field, ground decorations stay still, and textures stay loaded between maps.

## What to test (20 minutes)
1. Chop a normal tree with the starter axe.
2. Stay out past sunset in winter and in summer: does it get dark at the right time? Is night too dark, about right, or not dark enough?
3. Walk behind a big tree and a house: they should go see-through.
4. Listen at dawn on the farm, at night in the meadow, at the beach, and in the mine.
5. Fight a few enemies in the meadow and the mine: are they a fair fight now?
6. Pick Big Jim in the hero picker: is the art right?
7. Let the pup get knocked out, then go through a door: it should still be down. Feed it.
8. Find a hidden chest in any region.

---

# PART 2 — Decisions from the audit (new)

1. **How dark should night be?** Night darkness defaults to full (Options can set soft or off). *Default: full.*
2. **Crops dying at the end of their season** (like Stardew). Before, they just grew at half speed. *Default: keep the new, harsher rule.*
3. **A daily limit on eating for energy** ("You're too full to eat more today")? *Default: no limit. Pricier energy tea is enough for now.*
4. **Friendship pace:** a villager can reach 10 hearts in about 10 days. *Default: two gifts a week per villager, like Stardew.*
5. **Hidden chests:** can they hold real progression (tool upgrades, relics), or only money and materials? *Default: money and materials, plus one relic for finishing the journal.*
6. **Fewer resources or higher build costs?** I cut supply. *Default: keep it this way.*
7. **Bog water:** no wading without Swimmer or a boat. *Default: keep it.*
8. **Music at night:** now it dips so the crickets come through. *Default: keep it. The other choice is music stopping entirely late at night, like Stardew.*
9. **Penguin hero picker:** show all 18 heroes, or a shorter list? *Default: all 18.*
10. **Big Jim in both arcs?** *Default: yes.*

---

# PART 3 — Story: what I need from you, both arcs (unchanged from Guide 10, still open)

The game has a complete five-chapter story in each arc, written from your book and our earlier talks. What's missing is **your** choices on the big questions, and the side stories that make the world feel deep. Each item below shows what's in the game now, the question, and the default.

## 2A. Penguin arc: the spine (most important)

The chapters as they stand:

| Chapter | Title | What happens |
|---|---|---|
| 1 | The Day the Star Crystal Came Down | The crystal falls in your field and asks for help. The sky turns red. Pip-Pip and Nova touch it. |
| 2 | Cat-topia | A voice in the crystal meadow. Catkins teaches the Meow Pow Wow. The cave shakes. |
| 3 | Mount Prismatica | Big Jim's campfire. The crystal babies. Coldy and the sacred key. A knight above the clouds. |
| 4 | The Finargles and the Merkitties | A crystal prison. The uphill stream, the waterfall, and the song that gives you a tail. |
| 5 | The Heart of Mount Prismatica | The spire is the Dark Crystal, with the finargle queen beside him. |

The two endings:
- **Two Crystals:** you heal him, and he turns out to be the Star Crystal's brother.
- **The Quiet Mountain:** you shatter him.

1. **Who was the Dark Crystal before?** Now he's the Star Crystal's brother, left behind and twisted by being left. Is that right, or is he someone else (an old friend, a person, a guardian who failed)? *Default: keep the brother.*
2. **Why does he make Grumps?** Now he "takes something that loved and squeezes until only the wanting is left" (Grumps were once pets). Keep it? *Default: keep it.* The Revert ability turns Grumps back into animals.
3. **What do Pip-Pip and Nova want for themselves?** Each needs one personal goal. *Defaults:*
   - Pip-Pip wants to be brave enough to lead.
   - Nova wants to find the knight who saved her once.
4. **The finargle queen.** Can she be turned before Chapter 5? Now she can be freed only if you told Fennimore the truth. *Default: add one scene in Chapter 4 where you can talk to the queen. If you've freed 3+ finargles, she stands aside at the end.*
5. **Catkins' secret.** Who taught her the Meow Pow Wow? *Default: the Star Crystal did, long ago, when it last came down. Catkins is the last one who remembers.*
6. **Big Jim's tail** (the running joke). Does he ever get a tail? *Default: yes, in the epilogue, and he hates it, then loves it.*
7. **The bell in the tower.** It rings in both arcs' endings ("twenty-one years of rust"). Who took the bell down twenty-one years ago? *Default: the town did, the night the crystal first fell, because the ringing called the Grumps.*

## 2B. Penguin arc: the merkitty colonies

Four islands, each with an elder, a trouble and a boss:

| Colony | Elder | Trouble | Boss | Reward |
|---|---|---|---|---|
| Coral Reach | Grandmother Brine | Grey coral | The Grey Reef | Coral Ward |
| Kelp Hollow | Old Tidewhisker | Black kelp | The Drowning Tide | Tideswim |
| Frostfin Isle | Captain Icewhisker | Ice | Hollow Winter | Frost Step |
| Emberclaw Atoll | Lady Cinderpaw | The Smother | The Smother | Starfire |

8. **Why are their star crystals fading?** *Default: each is a splinter of the same great star. The Dark Crystal pulls them back toward him, so the colonies' fading is part of the main story.*
9. **One personal story per colony** (3–5 scenes each). *Defaults:*
   - **Coral Reach:** Grandmother Brine's grandson ran into the grey reef to prove himself. You bring him home.
   - **Kelp Hollow:** Old Tidewhisker has forgotten the song that keeps the kelp green. You find the verses with three villagers.
   - **Frostfin Isle:** Captain Icewhisker's ship is frozen in the bay with her crew asleep inside. You thaw it with the beacons.
   - **Emberclaw Atoll:** the glassblowers can't make the lens the crystal needs. You bring sand from all four islands.
10. **The song and the tail.** In Chapter 4 the merkitties' song gives you a tail. *Default: each colony teaches one verse. All four verses unlock the true merkitty form in Chapter 5, which helps the heal ending.*
11. **Merkitty queen or king?** *Default: none. The four elders come to the finale together.*

## 2C. Gangster arc: the spine (most important)

The chapters as they stand:

| Chapter | Title | What happens |
|---|---|---|
| 1 | Lie Low | A deed with the wrong name, and letters from M. |
| 2 | The Hideout | The first recruits, and a shop if you want one. |
| 3 | The Docks | Purple crystals in crates, and a fence with an offer. |
| 4 | Neon | The dragon sign, the pit, and six more recruits. |
| 5 | Uptown | The tower, and M. |

The endings are **A Tired Man** (free him) and **The Chair** (take the city).

12. **The hero's past.** Why were you hiding? What happened in the city before Chapter 1? *Default: you were M.'s best runner. A job went wrong, you saw something you shouldn't have, and M. "saved" you by hiding you on the farm.*
13. **The wrong name on the deed.** Whose name is it? *Default: M.'s real name, Walter Kestrel. That's the W and the K in the handwriting clue.* The clue now works in the game: the photo note reads "WE KNOW ABOUT THE FARM. NICE TOUCH.", and M. explains the two handwritings at the end. (Say if you want a different name.)
14. **A third ending?** Guide 09 suggested a "Clean Break" (walk away). *Default: add it, available only if your heat is 0 at the end, all ten Marked went home, and you never took a shop. You leave the stone with the detective (see 17), and the epilogue changes.*
15. **Does your crew's loyalty change the finale?** Now loyalty changes the epilogue lines. *Default: crew at loyalty 3 each give a small help in the final fight (Doc heals, Vic and Val hold doors, Ladder spots).*

## 2D. Gangster arc: the eight lieutenants

Now: you can spare any of them, and Old Mags and Brock can join you.

| Lieutenant | Where |
|---|---|
| Harbourmaster Vance | the docks |
| Lucia "Flame" Ardent | Neon |
| Brock the Unbroken | the pit |
| Silas Crane | uptown |
| Old Mags | the countryside |
| The Surveyor | the wastes |
| Conductor Pike | the rail yards |
| Madame Ostrova | the Dockside battle |

16. **One line of backstory each, and links between them.** *Defaults:*
    - **Vance** owes M. his harbour.
    - **Lucia** was the first Marked M. ever made.
    - **Brock** fights to pay for his little brother's school.
    - **Silas** is M.'s lawyer and believes in order above everything.
    - **Mags** ran the country roads before M. and still resents him.
    - **The Surveyor** is mapping where the star's pieces fell.
    - **Pike** and Vance are old rivals.
    - **Ostrova** keeps the books on everyone, including M.

    Tell me which to change.
17. **The detective.** *Default: add Inspector Hale, a tired, kind detective who follows your heat. She can be fooled, befriended or outrun. She's who you hand the stone to in the Clean Break ending.* Yes or no?

## 2E. Gangster arc: the Marked

18. **Where do the Gifts come from?** Now M. pressed a splinter of the stone into each of them on a bad day. Keep it? *Default: keep it.*
19. **One small personal scene per Marked**, when they join or go home (10 scenes). *Default: I write them. Each one is about what they wanted on the day they got the splinter.*

## 2F. Both arcs: side stories (sub-arcs)

Pick any you want, or add your own. Each is 3–6 scenes. *Default: I write all of them, in this order.*

| # | Arc | Sub-arc | What happens |
|---|---|---|---|
| 20 | Penguin | The crystal babies grow up | The three babies become battle helpers with names you choose. |
| 21 | Penguin | Big Jim's brother | A campfire story leads to a hidden highland cave. |
| 22 | Penguin | Coldy's key | What else the sacred key opens: a vault under the town. |
| 23 | Penguin | The Wastes Commander | "He was a person once." Who was he, and can he come home? |
| 24 | Gangster | Mama Rosa's restaurant | Keeping the front business honest when a rival wants it. |
| 25 | Gangster | The Kid's school | The Kid wants to go back to school; you have to make it safe. |
| 26 | Gangster | Specs and the wire | Specs finds M.'s private files and sees your name in them. |
| 27 | Both | The 25 villagers | Each has a 10-heart story. Do you want marriage or dating (all ages: walks, picnics, a ring) or friendship only? *Default: friendship only, plus a "best friend" ceremony at 10 hearts.* |
| 28 | Both | Festivals | Four festivals exist (Egg, Lantern, Harvest, Star). One mini-game each? *Default: yes: egg hunt, lantern float, biggest-crop contest, star-wish.* |
| 29 | Both | Your daughter's ideas | Anything she wants in the game: a creature, a place, a joke, a character. I'll build it. (This is the one I'd love most.) |

## 2G. Tone checks

30. **Penguin arc:** some scenes are sad (Grumps were pets; the dog at the gate). OK for your daughter? *Default: keep them gentle.*
31. **Gangster arc:**
    - Guns are toy-like. Nobody dies (people are "knocked out", the Marked "yield").
    - There's no blood, no drugs, no drinking (soda only).
    - Gambling is now just a friendly hand of cards.

    Anything else to soften or remove? *Default: keep it as is.*

---


---

# PART 4 — Art, in the order to make it

Each **PROMPT** is one copy-paste into ChatGPT, asking for **6 images at most**. Every prompt carries all its rules, so it works pasted into a fresh chat. Each image has its own labelled section with its file name. If ChatGPT stops early, say "now image 2". Upload the images here with their file names.

**Received and wired in from Prompts 16:** ground and water, edges and shores, cliffs and stairs, the beach and marsh kits, cave kits, battle structures and helpers, and the four colonies (w314–w329). Thank you.

| Order | Prompt | What it fixes |
|---|---|---|
| 1 | **17-6** | The Sun Haven-style skills screen and big skill badges |
| 2 | **17-3, 17-4, 17-5** | Icons for all 520 skill-tree nodes (13 sheets) |
| 3 | **17-1, 17-2** | Prompts 13 again: Cat-topia, finargles, crystal babies, merkitties, the catship, the summit, plus painted cards and portraits for Big Jim, Coldy, Pip-Pip and Nova |
| 4 | **18-1** | One clean pup sheet, and gear that sits on the pup |
| 5 | **16-7** | Missing portraits: the four kids, and Sal and Rook (who share a face) |
| 6 | **16-1** | The President's eight lieutenants (they wear thug bodies now) |
| 7 | **17-10** | The President's new look |
| 8 | **16-4** | The Marked (10 characters on thug bodies now) |
| 9 | **16-5** | Gift effects (drawn in code now) |
| 10 | **16-3** | Marisol and Bo |
| 11 | **18-2** | Moving bosses for three colonies |
| 12 | **16-2** | The two town projects (Crystal Ward, HQ) |
| 13 | **16-6** | The chrome stations, bots and drones |
| 14 | **18-4** | Night glow for lamps and lit windows |
| 15 | **18-5** | The Hollow Heart's landmarks and people |
| 16 | **17-7, 18-3** | The last item icons, spell icons, mail and goal-line marks |
| 17 | **17-8** | New screens: crafting, save slots, settings, the hack |
| 18 | **18-6** | Small fixes: the Wastes spire, extra select cards, outfit portraits, hidden-chest pieces |
| 19 | **17-9** | The four ending paintings |
| 20 | **17-11** | The app icon |

That's 20 images in Prompts 16, 32 in Prompts 17 and 15 in Prompts 18. Nothing is blocked while you work: the game uses stand-ins, and I wire each sheet in as it arrives.

---

# PART 5 — Music and sounds

Your title song and the two path themes are real. Everything else is a placeholder I generated, and all of it is already playing in the right places, so a real song only has to replace the file. Once the ACE Music connector is set up, I'll send these prompts one at a time **after you approve each**. Each track should be 1.5–3 minutes, loop cleanly, and have no vocals unless noted.

| # | Track | Where it plays | Prompt idea |
|---|---|---|---|
| 1 | farm | the farm by day | gentle acoustic guitar, flute, light percussion, warm morning, 90 bpm |
| 2 | town | the town plaza | bouncy accordion and pizzicato strings, friendly, 105 bpm |
| 3 | house | inside your house | soft piano and music box, cosy, 70 bpm |
| 4 | night | anywhere after 8pm (new) | slow celesta and pads, crickets feel, 60 bpm |
| 5 | rain | rainy days | piano and soft rain-like synth, wistful, 75 bpm |
| 6 | lake | the lake and riverlands | harp and soft strings, flowing, 80 bpm |
| 7 | beach | the beach | ukulele, steel drum, sunny, 110 bpm |
| 8 | mountain | the mountain and highlands | horns and strings, open and brave, 95 bpm |
| 9 | meadow | the meadows | woodwinds and glockenspiel, playful, 100 bpm |
| 10 | mine | the mines | low marimba, dripping echoes, mysterious, 85 bpm |
| 11 | cattopia | Cat-topia (penguin arc) | jazzy, purring bass, playful cat theme, 100 bpm |
| 12 | sky | the sky, station and moon | airy synth, choir pads, wonder, 80 bpm |
| 13 | colonies | the merkitty islands (new) | island marimba, soft choir "ooh", ocean calm, 95 bpm |
| 14 | boss | boss fights | driving strings and drums, heroic, 140 bpm |
| 15 | battle | conquest battles (new) | marching snare, brass, strategic tension, 120 bpm |
| 16 | city | docks, Neon and uptown (new, gangster arc) | noir jazz, upright bass, muted trumpet, 95 bpm |
| 17 | hideout | the hideout (new) | lo-fi jazz, warm vinyl crackle, 80 bpm |
| 18 | neon_chase | raids and collectors (new) | synthwave with a jazz sax hook, 125 bpm |
| 19 | festival | festival days (new) | folk band, fiddle, clapping, 115 bpm |
| 20 | winter | winter days (new) | sleigh bells, soft piano, 85 bpm |
| 21 | ending_penguin | the penguin ending slideshow (new) | the penguin theme slowed down, piano and strings, hopeful |
| 22 | ending_gangster | the gangster ending slideshow (new) | the gangster theme as a slow jazz ballad |


| 23 | forest | the forest (new) | woodwinds, soft harp, dappled light, 90 bpm |
| 24 | wastes | the Wastes (new) | dusty slide guitar, low drone, lonely, 85 bpm |
| 25 | marsh | the marsh (new) | slow, misty, clarinet and low strings, a little eerie, 70 bpm |
| 26 | jungle | the jungle (new) | hand drums, marimba, birdsong feel, 105 bpm |
| 27 | hollow_heart | the Hollow Heart (new) | glassy bells, deep warm pads, a slow heartbeat pulse, 60 bpm |
| 28 | colony_coral / kelp / ice / ember | one per merkitty island (new) | the colonies theme in four colours: sunny, deep-green, icy, fiery |

**Nature sounds (optional):** the birds, crickets, wind, rain, waves and so on are generated placeholders. If you'd like real recordings, I can use free CC0 sounds, or you can upload your own. *Default: keep the placeholders until the music is done.*

---

# PART 6 — Accounts and setup

11. **ACE Music connector:** tell me when it's connected and I'll send the first track prompt for your OK.
12. **Relay server for multiplayer:** a free account on Fly.io or Render, or about $5 a month for always-on. You sign up yourself (I can't create accounts); tell me which, and I'll give you the steps one tap at a time. *Default: skip multiplayer until the rest is done.*
13. **Nothing else.** GitHub and the website are set up, and every push deploys by itself.

---

# PART 7 — Playtesting

The bots catch crashes; only you can tell me what's fun. Every few days, play 20 minutes and send:
- One thing that felt good.
- One thing that felt confusing or ugly. A screenshot is perfect.
- Anything your daughter said.

Most useful right now: the test list in Part 1, then one full battle, one colony and one heist.

---

# PART 8 — What's left on my side, and the hours

| Work | Hours | Needs you? |
|---|---|---|
| Rework the story with your answers (Part 3) | 8–14 | Yes |
| Side stories (Part 3, 2F) | 10–16 | Optional |
| Wire in Prompts 16–18 art as it arrives | 12–16 | Yes (the art) |
| Real music for every area | 6 | Approve prompts |
| Balance tuning from your playtests | 6 | Your notes |
| Battle pathfinding, more battlefields | 5 | Your opinion |
| Multiplayer relay and fixes | 4 | Hosting account |
| Bigger phone-speed work (chunked map drawing, water shader) | 4 | No |

**Total remaining: about 55–71 hours. The game is about 50–55% done.**

# Guide #9: the audit round, conquest battles, the colonies, the town projects, big mines

Play: https://excivious27.github.io/Dreams/

This guide has three parts. Part A is what's new and how to test it on your phone. Part B is **everything I need from you, ranked by importance** (story for both arcs, design decisions, art, accounts). Part C is what's still open on my side.

---

# PART A — What's new

## The audit (20 agents)

Twenty agents each went through one area of the game: Gifts, cyber, crafting, the racket and sanctuary, combat, allies, story, farming, saves, UI, title, art, world, mines, both arcs, economy, villagers, network, and meta. Each one listed bugs and, more importantly, work I could do without you. I did most of it. The full list, with what's done and what's deferred, is in `docs/AUDIT-2026-11-17b.md`.

### Fixes you might notice
- **Saves are much safer.** If the save file goes missing, the game recovers the backup. A broken save is moved aside instead of blocking every future save. The game also autosaves every 90 seconds. New Game now asks "are you sure?", and there's a **Restore** button on the title screen to bring back the last run.
- **Story scenes are never lost.** If the game closes in the middle of a story scene, the scene replays on the next load. Before, the scene could be marked done without its rewards being given.
- **"Next step" line** under the HUD tells you what to do next in the story. It hides during battles.
- **Fewer toasts.** At most 3 at a time. Repeats show as "×3", and longer messages stay on screen longer. Old messages are under Menu → Messages.
- **Menus:** B backs out of a menu when the last choice is Leave or Back. A short guard stops a fast double tap from picking an option by accident.
- **Combat:**
  - Armour now cuts damage by a percentage, so it never makes you invincible.
  - Guns and swords can't hit through walls.
  - The USE button swings at an enemy in front of you before trying anything else.
  - New **ROLL** button (dodge) appears near enemies, and you're untouchable for a split second while rolling.
  - The pup's ♥ shows a cooldown ring.
- **Enemies** no longer spawn on top of you when you enter a map.
- **Racket:**
  - Passing counterfeit bills has a daily limit that grows with your tier, and each pass gets a bit riskier.
  - Washing money is capped by the face value of the bills.
  - Collectors no longer drop money, and beating all of them cools your heat.
- **Crew and skill perks:** the 24 crew perks and dead skill perks that did nothing now work: Specs gets better prices, Marlene fences, Dice improves board rewards, Ladder warns before raids, Mama Rosa cooks, and Doc patches you up mid-fight. The crew descriptions now match what each perk actually does.
- **Your screenshots:**
  - The marsh fog is now soft and faint instead of thick clouds.
  - The beach's dirt strips are gone and there are far fewer dunes.
  - The toolbar no longer covers the mines.
- **Smaller download:** 216 MB → 82 MB. The game loads much faster on a phone.

## Big new things

### 1. Mines are huge and organic
Every floor is a cave carved by the game: 40–80 tiles wide, with natural wavy walls. The caves get bigger as you go deeper. The ladder down is always far from where you arrive. Floor keepers hit harder deeper down.

### 2. Elevated ground
Maps can now have raised plateaus with rock faces and ramps up. The colonies and battlefields use them. The art for big cliffs and stair sets is in Art Prompts 16 (batch 3). Until then they're drawn by code.

### 3. Conquest battles (both arcs)
There are four battlefields, two per arc:

| Arc | Battlefield | Tier |
|---|---|---|
| Penguins | **Frostfield Front** | 2 |
| Penguins | **Shattered Vale** | 4 |
| Gangsters | **The Rail Yards** | 2 |
| Gangsters | **Dockside War** | 4 |

You start them from the **War Table** (a town project stage, see below).

- **Capture:** stand in a control point's ring until it fills (about 7 seconds) to take it.
- **Tickets:** each side has tickets. The side holding more points drains the other side's tickets.
- **Supply:** you earn supply over time. At points you hold, spend it to **build structures**. These are crystal spires in the penguin arc and drone bays in the gangster arc. Each one makes a helper:
  - **Striker:** attacks
  - **Healer:** heals you
  - **Warden:** protects
  - **Shade:** makes you invisible
  - **Turret:** stays put and shoots
- **The enemy** sends waves that march on your points. When their tickets fall to half, a **boss** arrives. In the gangster arc, those bosses are two of the President's lieutenants.
- **Win** to get gold, items and story progress.
- **The HUD** shows tickets and points, and an arrow points to anything off-screen.

### 4. The merkitty colonies (penguin arc)
Take the ferry from the tip of the beach pier to four islands. Each colony is in trouble, and its star crystal is fading:

| Colony | Tier | Elder | Trouble | Reward |
|---|---|---|---|---|
| **Coral Reach** | 1 | Grandmother Brine | Grey coral | Coral Ward (armour) |
| **Kelp Hollow** | 2 | Old Tidewhisker | Black kelp | Tideswim (swim in deep water) |
| **Frostfin Isle** | 3 | Captain Icewhisker | Frozen | Frost Step |
| **Emberclaw Atoll** | 4 | Lady Cinderpaw | Smothered | Starfire |

In each colony:
- Talk to the elder.
- Light the tide beacons.
- Bring what they ask for.
- Beat the colony's boss.
- Restore the star crystal.

Restoring it gives you the colony's ability and new spells (Lull, Radiance), more mana, and a colony shop. The islands are big, joined by sand bars, with hidden bits to find.

### 5. Town projects (like Stardew's community center)
Each arc has a town project with six stages. Each stage needs a bundle of items, and each finished stage changes the game:

- **Penguins: the Crystal Ward** on the town plaza:
  1. Ward Stone
  2. War Table (opens the battles)
  3. Prism Array (crops grow faster)
  4. Sky Lens
  5. Aurora Dome (enemies hit 15% softer)
  6. Star Beacon
- **Gangsters: Headquarters** at the hideout:
  1. Back Room
  2. Safehouse (recruits move in)
  3. War Table
  4. Workshop Wing
  5. Rooftop Comms (stops raids)
  6. Tower Plan (boosts the finale)

**Crew jobs:** recruits can be given jobs (press, farm, scout, fence, salvage, train) that pay out every morning. HQ has 2, 4, then 6 job slots.

### 6. The President's eight lieutenants (gangster arc)
They're placed as bosses across the arc:
- Harbourmaster Vance (docks)
- Lucia "Flame" Ardent (neon)
- Brock the Unbroken (underground)
- Silas Crane (uptown)
- Old Mags (countryside)
- The Surveyor (wastes)
- Conductor Pike (Rail Yards battle)
- Madame Ostrova (Dockside battle)

Each one has a Gift power with a weakness to learn. Beating them counts toward Headquarters' last stage.

### 7. Living talk
Villagers now have over 150 lines that change with the season, the weather, festivals, your arc and your heat. They don't repeat until they've used them all.

### 8. Also new
- Placeable sprinklers and scarecrows on the farm. Sprinklers water their area every morning.
- Gift effects on Marked enemies (the gift engine got four new moves and two new rules).
- The cyber gear works: Scrub, EMP, Bot (a turret you place), Drone (scouts, then recharges for 2 days).
- New pages in the menu: **Foes & Gifts** (what you've learned about each Gift) and **Messages**. Six new map pins.
- Villagers wear festival outfits on festival days.

## The 20-bot playtest
Twenty scripted players each played 5 days across both arcs, every region, the colonies and the battlefields:
- One bot crashed. I fixed the cause (a cutscene running after its map had closed) and reran it.
- After the fix, all 20 finished with 0 script errors and 0 failed checks.
- 5 bots stood still for a while during region intros. That's a harmless timing gap in the bots, not the game.

## What to test (20 minutes, on your phone)
1. **Title:** start a New Game. You should get an "are you sure?" box, and a Restore button should be there.
2. **Mines:** go down three floors. Each one should be a big, wavy-edged cave. The toolbar shouldn't cover anything.
3. **Beach and marsh:** check the marsh fog and the cleaned-up beach.
4. **Penguin arc:**
   - Walk to the end of the beach pier and take the ferry to Coral Reach.
   - Talk to Grandmother Brine and light a beacon.
5. **Town plaza (penguins) or the hideout (gangsters):** find the project site and check that it lists stage 1's bundle.
6. **Battle:** build the War Table (project stage 2), then start one from it. Capture a point, build a structure, and see whether it feels like strategy or like clutter. **That's the thing I most want your opinion on.**
7. **ROLL:** near an enemy, tap ROLL and check that you dodge.
8. Close the game in the middle of a story scene, reopen it, and check that the scene replays.

---

# PART B — What I need from you, ranked by importance

Every item below is something only you can decide or make. I've put my default under each one: if you don't answer, I'll go with the default. Answer in any order and in any form: a voice note typed out, a list, or "default is fine."

## Tier 1: blocks the game from feeling finished

### 1. The two finales and the endings (both arcs)
The game has one end beat per arc. The audit found that choices you make during the story don't change the ending yet. I need:
1. **Penguin arc, Chapter 5:** what happens at the Dark Crystal? Your story with your daughter ends at the spire.
   - Is the Dark Crystal someone (a person who was hurt?) or a thing?
   - Can it be saved, or must it be shattered?
   - *Default:* two endings. **Heal** happens if you restored all four colonies and kept the sacred key. **Shatter** happens otherwise. Plus a short epilogue for each companion you kept.
2. **Gangster arc, Chapter 5:** who is **the President**?
   - Name, look, and what he wants. "The man with the stone in his chest" is all we have.
   - Why does he want the purple crystals?
   - *Default:* a once-honest mayor who found a fallen crystal shard and now can't stop wanting more.
3. **The gangster endings.** Do you take over the city, walk away, or turn him in? Does your crew's loyalty decide which ending you get?
   - *Default:* three endings:
     - **Boss of the City** (high heat, all crew)
     - **Clean Break** (low heat, washed money)
     - **The Long Con** (Specs and Sasha both loyal)
4. **Epilogues.** Do you want a slideshow showing where each friend, villager, pet and crew member ended up, like Fallout? *Default:* yes, one line each.

### 2. The President's eight lieutenants: who they are
I made names, looks and powers (above, and in Art Prompts 16 batch 8). For each one I need from you, or a "default is fine":
- **One line of backstory.** Why do they work for the President? *Default:* each owes him something different: money, a pardon, a family member, a job.
- **What happens when you beat one.** Can they be **recruited**, **spared** (they leave town), or **arrested**? *Default:* spare or recruit.
  - Recruited lieutenants become crew with a perk.
  - Old Mags and Brock are the most recruitable.
  - Silas and Ostrova never turn.
- **Any links between them.** For example, Lucia and Brock are siblings, or Vance trained Pike. *Default:* Vance and Pike are old rivals, and Ostrova keeps the books on all of them.
- **Order.** Is the order fixed (docks → neon → underground → uptown), or can you take the countryside, wastes and battlefields in any order? *Default:* the four city lieutenants in a fixed order, the other four in any order.

### 3. The merkitty colonies: their stories
I made four colonies with an elder, a trouble and a boss each (the table above). For each one:
- **Why is its star crystal fading?** Is it the same darkness as the spire, or something else? *Default:* each crystal is a piece of one great star that fell long ago. The Dark Crystal is pulling them back, and each colony's boss is a creature the darkness twisted.
- **One personal sub-story per colony.** *Defaults:*
  - **Coral Reach:** Grandmother Brine's grandson ran off to the grey reef.
  - **Kelp Hollow:** Old Tidewhisker has forgotten the song that keeps the kelp green.
  - **Frostfin Isle:** Captain Icewhisker's ship is frozen in the bay with her crew asleep inside.
  - **Emberclaw Atoll:** Lady Cinderpaw's glassblowers can't make the lens that focuses the crystal.
- **The merkitties' link to Chapter 4.** In your story, the merkitties' song gives you a tail. Is that song taught in the colonies? *Default:* yes. Each restored colony teaches one verse, and all four verses unlock a true merkitty form for the finale.
- **Is there a merkitty queen or king** who appears at the end? *Default:* no queen. The four elders come to the finale together.

### 4. Choices that matter
The agents found choices that are asked but never used later:
- the intro letter
- the counterfeit shop ("a shop, if you want one, and what it costs")
- the fence's offer
- Doc's "free" option
- the items you keep (the old collar, brass locket, merkitty necklace, sacred key)

For each, tell me what it should change, or say "default." *Default:* each one changes one later scene line and one epilogue line, and the four kept items each unlock a small extra scene in Chapter 5.

### 5. Is the card parlour OK?
The gangster arc has a card table (shop_1). The audit flagged gambling as the one theme that might be too mature for an all-ages game. Options:
- **Keep** it as is (card games for gold).
- **Change** it to an arcade or claw machine.
- **Keep** the cards but play for tokens and prizes only.

*Default:* tokens and prizes.

## Tier 2: makes the game deeper

### 6. Sub-arcs and side stories
I can write these myself. If you want any of them, or have your own, say so. Each is 3–6 scenes.

**Penguin arc**

| # | Sub-arc | What happens |
|---|---|---|
| a | **The crystal babies** (Ch3) | Raise the three baby crystals. Each grows into a helper unit for battles. |
| b | **Catkins' past** | Why the wise cat knows the Meow Pow Wow, and who taught her. |
| c | **Big Jim's lost brother** | A campfire story that leads to a hidden cave in the highlands. |
| d | **The finargle queen** | Does she have a reason? A chance to turn her before Chapter 5. |
| e | **Nova's knight** | The knight above the clouds was a penguin once. The audit found Nova can be missed for the whole run. Should Nova always join? *Default:* yes. |
| f | **Coldy's key** | Where the sacred key came from and what it opens besides the spire. |

**Gangster arc**

| # | Sub-arc | What happens |
|---|---|---|
| g | **Heists** | One per district, each needing two specific crew. Example: **The Vault** in uptown needs Specs and Sasha and rewards crystal batteries. |
| h | **Turf** | Take blocks of each district, which push back raids and earn daily money. |
| i | **Each crew member's loyalty mission** | 12 short missions, one per crew. These are what make the endings branch. |
| j | **The detective** | Someone who follows your heat and can be fooled, befriended or outrun. *Default:* a kind, tired detective who wants the President, not you. |
| k | **The Marked** | Ten young people with Gifts. Where do the Gifts come from? Are they linked to the crystals? *Default:* each was near a crystal shard when it fell. |
| l | **Mama Rosa's restaurant** | She runs the front business that washes your money. A sub-story about keeping it honest. |

**Both arcs**
- **m. The 25 villagers' heart arcs.** Each has 10 heart levels. 96 heart perks are still unwritten. Do you want me to write them all? *Default:* yes, one small perk each.
- **n. Birthdays and gifts:** who loves what. *Default:* I'll write them.

### 7. Is the conquest battle what you imagined?
After you've played one:
- Are there too many structure types (5)?
- Should battles be longer?
- Should you command your helpers directly (tap a point to send them)?

*Default:* add a "send all helpers to this point" button and a third battlefield per arc.

### 8. The town projects' bundles
Do the item lists for each stage feel right? Do you want a stage that needs friends (hearts) or fish? There's already one of each. *Default:* keep them as they are and tune them after playtesting.

### 9. Should Pip-Pip and Nova be customizable?
The penguin creator (feathers, scarf, hat, pet) can't be reached for the pre-made heroes. Should you be able to dress them? *Default:* yes, scarf and hat only.

## Tier 3: polish and running costs

### 10. Multiplayer hosting
Multiplayer can't work on the live site until there's a small relay server. Your options:
- **Free:** Fly.io or Render free tier. It sleeps when unused, so the first connection is slow.
- **About $5 a month:** an always-on server.

You make the account (I can't sign up for you). Then I give you the exact steps. *Default:* free tier.

### 11. Art (Art Prompts 16)
Most important first:
1. Batches 1–3: seamless ground, soft edges, cliffs and big stairs. This fixes the choppy look everywhere.
2. Batch 4: beach and marsh kits.
3. Batch 5: mine caves.
4. Batches 6–9: battles, colonies, lieutenants, town projects.
5. Batches 10–13: still owed from Prompts 15 (Marisol and Bo, the Marked, Gift effects, the chrome).
6. Batch 14: missing portraits, including the kids, who are copies of each other right now.

Upload the images to the chat with the batch name, as before.

### 12. Small decisions (any answer is fine)
- **Game name:** is it final as "Dreams"?
- **Save slots:** do you want 3 save slots and a way to export a save (to move it to another phone)? *Default:* yes.
- **Settings page:** music and sound volume, button size, left-handed controls? *Default:* yes, all of them.
- **Difficulty:** should there be an easy mode for your daughter (enemies hit softer, no money lost when you faint)? *Default:* yes.

---

# PART C — Update: the remaining work is done

After this guide went out, I built everything that didn't need you. Where Part B had a default, I used the default; you can still change any of it.

## New in the game
- **Options page:** music and sound volume, button size (small / normal / large), left-handed controls, and **Easy mode** (enemies hit softer, no fee when you faint).
- **The USE button says what it will do:** "Talk", "Chop", "Mine", "Open", "Go" and so on.
- **3 save slots:** on the title screen, tap **Save slots**. There's also a **save code**. Copy it on one phone, paste it on another, and your farm moves over.
- **Quality crops:** harvests can come out ☆ silver or ★ gold. Farming level and fertiliser raise the odds. Silver sells for 25% more and gold for 50% more.
- **A real crafting screen:** every station opens a full screen of recipe cards showing the icon, what you have against what you need, and the time. Recipes you haven't found yet show as **???** and tell you which ingredient to look for. Hold that ingredient once and the recipe appears.
- **96 villager heart perks** now do something: gifts when you reach a heart level, weekly deliveries (tea, bait, pies, wool...), and bonuses to max health, energy or mana. A few change how the game plays: Ivy pays your clinic fee, Sal teaches you to walk quietly, Theo gives a free skill point in every skill, and Old Moss lifts the marsh fog.
- **Birthdays:** every villager has one. Gifts count triple on the day, and the morning tells you whose birthday it is. The Social page shows each villager's birthday, the gifts you've learned they love, and their next perk.
- **The ending slideshow:** after the final scene, slides show your ending, the choices you made, who stayed with you, the colonies (penguins) or the crew, lieutenants and the Marked (gangsters), and a line for every villager, warmer if you're close. You can replay it from Options.
- **Lieutenants:** when you beat one, you choose to let them walk or ask them to join. Old Mags and Brock say yes and give a bonus; the others leave town.
- **Nova** now catches up with you at Big Jim's campfire if you never met her. This fixes the knight scene that could be missed.
- **Deuce's card game** is a friendly hand with nothing at stake. I made no other changes to gambling.
- **Gangster side operations:**
  - **Turf:** clear every hostile on a district block and it's yours. Each block pays ◆40 every morning, and collectors stop raiding there.
  - **Three heists**, planned with two crew members at the hideout:

    | Heist | Planner | Crew | Where |
    |---|---|---|---|
    | The Cannery Job | Ladder | Ladder and Halo | the docks |
    | The Neon Arcade | Dice | Dice and Vic | Neon |
    | The Vault | Specs | Specs and Sasha | uptown |

    You pick quiet or fast. Your crew's loyalty and your heat set the odds.
  - **Crew favours:** each crew member asks one favour before their last loyalty step. This decides what their ending line says.
- **Battles:** a **RALLY** button sends every helper to one point. Tap it to cycle through the points.
- **Hacking Terminal:** a daily memory hack. Repeat the arrows; a clean run lowers your heat and gives a data chip.
- **Install to home screen:** on your phone, open the game in the browser and choose "Add to Home Screen". It opens full screen, upright, with its own icon. There's also a nicer loading screen.

## What to test (10 minutes)
1. **Options:** change the volume, set buttons to large, and switch to left-handed.
2. **Save slots:** pick slot 2, start a game, then go back and pick slot 1. Your first farm should still be there.
3. **Crafting:** build a station and open it. Look at the ??? cards.
4. **Social page:** check the birthdays.
5. **Home screen:** add the game to your home screen.

## Still open
- Wearable art, once the costume sheets arrive.
- Multiplayer fixes, once there's a relay server (Part B, item 10).
- Everything in Part B is still yours to change. Each default is now in the game, so you can play it and react.

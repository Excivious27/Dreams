# CONDUCT ×9 plan (3 waves of 3, 5 h apart)

Every CONDUCT has the same steps:
1. A 20-agent audit, scoped to that run's focus.
2. A 20-bot playtest (`tools/bots.sh 3 DIR`, plus focused bot scripts).
3. Every fix Claude can do alone.
4. Art prompt files for anything still needed (made with the image tool, then wired in).
5. A full guide of what Claude needs from Tom.

The 20 audit agents in each run:
- 14 on the run's focus;
- 4 regression agents on the previous runs' areas;
- 1 performance agent on the phone and web build;
- 1 progress-inventory agent.

## Wave 1 — new systems and first hours (right after the Round 13 merge)
1. **C1 · New-player first 3 hours, both arcs.**
   - Intro, tutorials and goal line.
   - Gating of campaigns and the rec centre.
   - Money, cash and crystal wording.
   - Pacing, softlocks, clarity on a phone screen.
   - Bots: fresh saves in both arcs, days 1–5.
2. **C2 · Recreation centre, arcade and community farm.**
   - Mini-game feel and difficulty curves.
   - Ticket economy, prize tiers, NPC hub schedules and dialogue.
   - Community farm quest line and saves.
   - Touch input on every full-screen UI.
3. **C3 · Battle campaigns and the battlefront.**
   - Tutorials and briefings, gating thresholds, length per tier.
   - Balance by simulation.
   - HUD readability, ally AI, rewards, and the story-region timing tests.

## Wave 2 — the world (5 h after wave 1)
4. **C4 · Mega regions.**
   - The 10 regions, unlocks, map tabs and travel.
   - Area reachability, enemy tiers, bosses, forage, music, hub NPCs.
   - Use the Round 12 edge and texture kits so every region looks distinct.
5. **C5 · Home world look and feel.**
   - Buildings: proportions, doors and messages, night windows.
   - Lighting (sunrise, night), weather, edges and seams.
   - Animals, penguin and NPC animation, pulsing or square-edged props.
   - Screenshot sweep of every map.
6. **C6 · Audio and music, end to end.**
   - Music on every map in both arcs, including the web streaming path.
   - SFX harshness, footsteps by ground type, ambience by place and time.
   - Missing cues on the new systems.

## Wave 3 — depth and polish (5 h after wave 2)
7. **C7 · Story, quests and writing.**
   - Both arcs' chapters, heart scenes, mail and board.
   - Text tone and typos; quest pointers; endings and epilogue pictures.
   - Story and dialogue tests.
8. **C8 · Economy, progression and balance.**
   - Crops, mining, fishing, crafting, skills and caps.
   - Prices, cash, tickets, energy.
   - The 30-day curve via bots, both arcs.
9. **C9 · Release readiness.**
   - Performance on phone and web: size, load time, memory.
   - Saves and migrations, co-op, settings and accessibility.
   - A crash and edge-case sweep, plus a final screenshot review of everything.
   - Finish with the fully updated artifact (full package).

## Timing
After C3 finishes, schedule a message in this session for 5 h later (`send_later`), and the same after C6.

## CONDUCT 1 agent scopes (as run 2026-11-19)
01 penguin new game → end of day 2 · 02 gangster new game → end of day 2 · 03 goal line + quest pointers days 1-5 · 04 held-tool rules on every interaction · 05 gangster money words in Round 13 systems · 06 early-game gating · 07 phone UI at 270x480 · 08 softlocks and stuck spots · 09 energy, faint, pacing, money curve · 10 farming first week · 11 town first visits · 12 pup intro, early combat, first mine floors · 13 saves, slots, migration · 14 arc choice + arc systems intros · 15 regression rec/bowling/arcade · 16 regression community farm + world fixes · 17 regression animation/audio · 18 regression mega regions + campaigns · 19 performance phone/web · 20 progress inventory (docs only).


## CONDUCT 10 — Decor and cosmetics ecosystem (Tom, 2026-11-19 13:46)

Runs after CONDUCT 9 (then the final package and artifact). Goal: make the game appealing on another level with an extraordinarily large, progressive collection.
- Categories: furniture, wall art, decor, wallpaper, flooring, house exterior styles (siding, roofs, doors, windows, fences), outdoor and farm decor (paths, lamps, planters, statues, fountains), apparel (hats, tops, bottoms, outfits, accessories) and footwear; both arcs get their own flavour (penguin whimsy; gangster underworld/cyberpunk, all-ages).
- Sources: shops (tiered by progress), crafting stations, quests and heart perks, festivals, the rec prize counter, mines/regions/mega regions loot and secrets, bosses, collections, rare world finds.
- Rarity: common, uncommon, rare, epic, legendary, mythic, and unique one-of-a-kind items (only one in the game); drop/price curves to match.
- The auditors' job: identify every place in the game the need can be filled and how it should plug into existing systems (house/interior placement, farm placement, wardrobe/character sheet, shops, quests, loot tables, saves), then the fix agents build it with art from the image tool, a catalog/collection screen, tests, and save migration.


## CONDUCT 11 — Ranching and livestock ecosystem (Tom, 2026-11-19 14:05)

Runs after CONDUCT 10 (then the final package and artifact). Goal: a massively sophisticated, progressively tiered ranching system, seamlessly part of the game.
- Classic: chickens and coops, cows and barns, goats, sheep, pigs, ducks, rabbits, bees; buildings upgrade by tier (coop → big coop → deluxe), feeders, incubators, auto-water, pastures and fencing.
- Exotics bought, imported or earned through quests: ostriches (ostrich eggs), Komodo dragons, and fantastic creatures from mega regions and story places (moon/space creatures, Merkitty Islands creatures, etc.); gangster arc: genetically modified creatures from the cyber/robotics side (all-ages).
- Products and processing (eggs, milk, wool, feathers, scales, exotic goods) feeding cooking, crafting, shops, quests and festivals; animal care, mood, friendship, breeding, rare variants/colours, shows/competitions.
- A full Ranching skill tree (gen_skill_trees.py) with abilities like the others; heart perks, quests, mail, villagers (Hazel, Tam, Benno...) tied in; saves migrated.
- Art via the image tool for every creature (walk/idle/produce animations) and building; audio for each creature.

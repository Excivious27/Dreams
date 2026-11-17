# Guide #5: Round 1 done, Prompts 11 in, what to test, what comes next

**Play:** https://excivious27.github.io/Dreams/

**Where the game is now (16 Nov, late).** Since Guide #4: the writing pass
(Round 1) is in — both arcs have five chapters with real finales and
epilogues, six decisions that pay off, twelve recruitable gangsters with
loyalty stories and perks, and all 25 villagers have five heart scenes, a
personal quest and daily lines that change. All six Prompts-11 batches are
integrated (new heroes, gang versions, gangsters, select cards, gang shops,
status/telegraph icons, roster UI, tiered mine floors, keepers, deep enemies,
ability effects, overlays). Your seven penguin-arc characters (Merry, Coco,
Mer, Coldy, Big Jim, the two Too Powerful Penguins) are selectable. Harnesses:
smoke, playtest, creator, story (50 beats), hearts (125 scenes), mine, net —
all green.

## What to test first (in this order)

1. **Select screen.** Penguin arc: cards for 12 heroes + text buttons for the
   new seven + Build your own. Gangster arc: the gang cards. Pick Mer, walk the
   farm, swing the hoe (she hovers; tools come with Prompts 12).
2. **Penguin story.** Day 2+: after the first harvest the howl in the east;
   after the Big Grump, the collar scene (tell the town / keep quiet). Then the
   spark → Wastes → Commander → locket → Finn at the lake.
3. **Gangster story.** Meadow → Sal → hideout: Deuce (pay ◆150 or play him)
   and Mama Rosa (ten crops). Then Deuce's shop offer. Docks → Specs/Ladder/
   Halo/Marlene; Neon → the twins, Dice, the Kid, Doc, Sasha. Party tab shows
   the crew. Halo drives you between districts from the hideout.
4. **Hearts.** Gift Gideon twice (copper bar) and talk to him: the ♥2 scene.
   Keep going to ♥6 for his ruby quest.
5. **Mine.** Floor 1 → dig ~10 rocks → keeper (painted card) → shaft → floor 2.
   Floors 9+ change tile sets every four floors; new enemies spit, blink,
   shield, stomp. Watch the icons over enemies and under your hearts.
6. **Combat feel.** Juggle a forest wolf three times — it charges back.

Tell me what feels wrong, in a list, like last time.

## What comes next (Round 2: balance), in order

1. Economy model as a spreadsheet: income per in-game day by activity
   (crops by season, fishing, mining by tier, foraging, board jobs, crew
   perks), costs (seeds, permits, upgrades), and the gates (tool tiers, combat
   skill, chapter) laid against a target 30–40 h first playthrough.
2. A **100-day bot** (`tools/sim.gd`) that farms, mines, fights and sleeps
   on simple rules and prints money, skills, deaths, hearts per day — so each
   tuning change is measured, not guessed.
3. Tune: crop values and growth, sell saturation, enemy hp/damage per tier
   against sword tiers, status durations, keeper thresholds, crew perk sizes.
4. Then Round 3 (art consistency) as Prompts 12–13 land, Round 4 (feel),
   Round 5 (audio), Round 6 (multiplayer hardening), Round 7 (QA + Steam).

Estimate from here to the commercial bar you chose: ~85 h of mine
(Round 1 took ~12; the plan was ~100 total).

## What I need from you

**A. Art — Prompts 12** (sent): Batch 1 (full sheets for six heroes) and
Batch 2 (wizard penguin, portraits, cards, partner abilities) unblock the
most; Batch 3 is fix-ups and can wait.

**B. One decision (unanswered from Guide #4):** multiplayer relay host —
free tier that sleeps (default if you say nothing) or a ~$4 VPS you rent and
paste me the IP.

**C. Play-test the six things above** and send the list.

## Still parked
- Rough edges from Prompts 11 (in STATUS.md): a few gangster special-move
  frames carry effect fragments; gangster portrait cells drift a few px; tier
  auras 1–5 and the poison impact didn't separate — all re-asked in Prompts
  12 Batch 3.
- The creator doesn't use the new tab/swatch art yet; the seven new heroes
  have no select cards until Prompts 12 Batch 2.
- Audio placeholders; relay on my machine only.

# Guide #6: the book is in the game, Prompts 12 in, farming fixes, what to test, what comes next

**Play:** https://excivious27.github.io/Dreams/

**Where the game is now (17 Nov, small hours).** The penguin arc is now your
and your daughter's story: the Star Crystal (she), Cat-topia and Catkins, the
Meow Pow Wow lesson, the catship and the litter catapults, Big Jim's campfire,
the crystal babies and Coldy's sacred key, the finargles and Fennimore's
question in the crystal prison, the uphill stream and the waterfall, the
merkitties' gift (a tail in any water), and the heart of Mount Prismatica
with Fennimore beside the Dark Crystal. 30 beats, 5 chapters, 5 decisions.
Prompts 12A (all), 12B batch 1 and 12C batch 3 are sliced and wired. Farming
got two fixes from your test. Harnesses: smoke, story (59 beats), creator,
mine, hearts, playtest — green.

## What to test first (in this order)

1. **Farming (your bug).** Hoe a square, hold the seeds (MENU → pick seeds):
   you now get the same green/red target square as the hoe and can. A plants
   into the tilled square in front of you (or under the mouse). Water it: the
   soil goes dark-blue now. Watering an already-watered square says
   "Already watered. N more days." If planting still misses, tell me which
   control you used (touch A, mouse click, keyboard).
2. **Penguin story, chapter 1–2.** New game, penguin arc, pick Nova. Day 2 after
   the first harvest: the howl. Clear the meadow → the collar → the Star
   Crystal sends you past the big meadow to the crystal meadow: Catkins is at
   the cave mouth (his portrait is Merry's for now). Talk to him: the Meow Pow
   Wow lesson. Three shards in the resonator → the catship cutscene → you get
   5 Litter Boxes (hold one and press A near Grumps: they stop and hold their
   noses).
3. **Chapter 3.** Climb the mountain. Sleep once there (campfire with Big Jim).
   Walk the pass: four crystal babies (shard-art placeholders) stamp at you.
   Beat three down; the leader must be *turned back* — hold B with a partner
   who knows the Meow Pow Wow when she is low. Coldy joins with the sacred
   key.
4. **Chapter 4.** Above the clouds: finargles (wisp art for now) blink around
   and daze you with purple eye-light. After the Knight you are taken: the
   crystal prison scene, Fennimore's question (tell her the truth or not),
   then you wake at the lake and Mer gives you the tail — you can now swim
   anywhere. Try diving in the lake and the pond.
5. **Finale.** Moon → the spire. Fennimore rises beside the Dark Crystal. If
   you told her the truth she hesitates (toast). Revert ending: both crystals,
   Fennimore turned back.
6. **New art.** Select screen: Merry, Coco and Mer have cards now. Pick Mer:
   hoe, axe, pickaxe, water, fish, swim, ride. Pick Coldy / Big Jim / Pip-Pip /
   Nova: full tool rows. Menu → Party: partner cards with portraits (selected
   = gold). Gangster arc: the twelve gangsters' specials are clean strips
   now; gangster portraits have five expressions. Scaled-up enemies (any
   enemy above its native tier, e.g. deep mine floors) carry a tier aura
   behind them.

## Things I left out or marked placeholder

- Catkins, finargles, Fennimore, crystal babies, merkitties, the catship, the
  prison, the summit — all use stand-in art until Prompts 13 (new file).
- 12B batch 2 came back as repeats of batch 1 (saved, not used). The redo is
  the last two images of Prompts 13 batch 2.
- The creator-panel art from 12C is sliced to `ui_creator2/` but not wired —
  the old panel's geometry is baked into the creator; swapping needs a
  layout pass.
- The 12C party panel is sliced (`ui/party_panel`); only the partner cards
  are shown so far.
- A few strips are one cell off (Mer's sit/cast, Merry's wall-phase).

## What comes next (in my order)

1. Prompts 13 batches → slice → the story's creatures get their real faces.
2. Round 2 balance: the economy sheet + the 100-day bot (`tools/sim.gd`),
   then tuning.
3. Creator/party panel re-layout with the 12C art.
4. Relay decision (free sleeping tier vs ~$4 VPS) — still yours.

## Files

- `docs/PENGUIN-ARC.md` — how the book maps to the game.
- `docs/STORY.md` — the story bible, Arc A rewritten.
- `docs/ART-PROMPTS-13.md` — two batches of six.
- `reference/PENGUIN-STORY-by-Tom-and-daughter.txt` — the book, kept as is.

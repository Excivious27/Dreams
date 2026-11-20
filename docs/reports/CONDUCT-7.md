# CONDUCT 7 report: Story, quests, writing + dating and marriage (2026-11-20)

The third CONDUCT on the optimised process. 14 focus auditors (8 sent back for a deeper pass) and 6 checklist auditors (c7_01..20, 235 findings) fed 6 file-disjoint fix packages (docs/reports/C7-PACKAGES.md): five writing packages plus P1, the new dating and marriage system. Everything was merged once and checked on GitHub Actions (check.sh in 6 shards, 20 bots, the scripted playtest with screenshots), with one CI fix round.

**Whole game after CONDUCT 7: about 70% done, 30% remaining** (average of the 58 systems in docs/inventory.csv). Dating and marriage went in at 85%, both story arcs to 85%, endings to 90%. Systems Tom added for later CONDUCTs (hazards/lava C20, General Store C21, marina C14) still count at 0%.

## Audit (20 auditors, 235 findings: 0 blockers, 80 major, 101 minor, 54 polish)

| Area | Main findings |
|---|---|
| Penguin main story canon (17) | No Star Crystal visit at the start, the cracked bell never explained, Grumps not tied to Crystopia, Nova's dream and the summit heart unclear, the sacred key never used, timeline holes. |
| Gangster story (18) | No origin (why you came), no corruption or road back, lieutenants' Dark Crystal powers never revealed, Inspector Hale thin, menus whose B choice made a permanent decision. |
| Lore: Catkins, Fennimore, elders (25) | Catkins had no guardian line or heart arc, the four elders never came to the finale, the Finargle queen's story stopped short, a boss bar named "The Finargle Elder". |
| Colonies and islands (23) | Four colonies told the same story, no side quests, identical secrets, foes that weren't Grumps, colonies went quiet once done, the ferry cat shared Pip's name. |
| Hearts and villagers (10) | Every heart scene was two lines, no arc for Catkins, "after" lines repeated forever, gifts swallowed by heart scenes, no sign a scene was waiting. |
| Mail and board (12) | Plurals ("2 Egg"), out-of-season favour asks, silent mid-day letters, the mail cap dropped unread gifts, stock lines repeated. |
| Text, gangster and general (13+) | Typos, crystals named in the cash arc, wrong speakers, lines that lowercased names. |
| Quests and tracker (6) | The compass pointed nowhere mid-story, givers indoors or at the Rec couldn't be found, giverless quests couldn't be tracked, gangster steps never said where. |
| Story flow (5) | Two beats at once, beats that never fired, menu open during the opening, missing story panels. |
| Endings and epilogue (8) | Ending panels unused, slides running off screen, no credits, toasts over slides, choices not reflected. |
| Tests and docs (7+) | hearts_test penguin-only and outside check.sh, endings never played both ways, non-first choices untested, stale docs. |
| Dating and marriage (c7_04) | The build plan: bouquet, dates, proposal, wedding, spouse at home, both arcs. |

## Fix packages

| Package | Fixed |
|---|---|
| P1 Dating and marriage | New `Romance`, `Dates`, `Wedding`, `SpouseFarm` with tools/gen_romance.py: 10 candidates in both arcs, no gender checks, one partner, no divorce. Bouquet at 8 hearts (200), 3 dates each, the locket at 10 hearts (5000), proposal, wedding day with guests and a wedding song (penguin meadow; gangster plaza bandstand), the spouse moves in (own corner, bed), morning/evening/rain lines, chores (water, feed, gifts) on home days, keeps a job on work days, anniversary, refusals with a cooldown. Social tab rows, Hero tab row, save migration. G-rated. New romance_test (102 checks). |
| P2 Penguin story | Canon: the Star Crystal fled over the island 21 years ago (the bell cracked), Grumps are converted Crystopia crystals, Crystopia and Celestica named, the sacred key opens the spire. Catkins' guardian line and the four elders at the finale, Fennimore's story finished. Beat flow: one beat at a time, quest-done backstop, beats wait for menus, every scene skippable, story_busy fixed, hero-aware lines, missing panels added. New story_flow_test (43 checks). |
| P3 Gangster story + endings | data/story_gang.json overrides story.json: the origin (you came to end the gangs; M. buried you), dark choices with a self-noticing line, Sal's conscience and buy-backs as a road back, Hale and the President's reveal. Endings: new gangster panels, slides paged by measured height, the ending painting on THE END, a Credits slide with the credits song, toasts held. New epilogue_test. |
| P4 Villagers | All 125 heart scenes staged and longer, a full Catkins arc (penguins only), 7 side-story chains (SideStory), light festival mini-games, a "scene waiting" row and heart emote. Letters: ItemWords plurals, in-season favours only, mid-day letters toast, unread mail never dropped, per-villager notes. New hearts_content_test. |
| P5 Colonies, crew, recruits | One story per colony with elders, 8 island side quests on talkable kits, own lore and loot, Grump-family foes, life after completion, the ferry cat is Skipper Barnacle. Crew waiting lines, Marlene leaves for good after the sale, drilled crew in the roster, crew can be gifted, Big Jim can be asked again at the hideout. New c7_colony_crew_test. |
| P6 Quests, pointers, tests | The compass has a place for every late main step, one two-way route graph, givers found indoors/at the Rec/at home, giverless quests trackable, colony progress, gangster steps say where, quest text fixes. story_test plays every choice option and both endings; hearts_test in check.sh for both arcs. Text fixes across unowned scripts. |

CI-only fixes after the merge (one round):
- Tests updated for new writing: gift letters give 2, the partner-scene wording, a music-stream test race.
- Wedding songs re-imported as seamless loops (the vows scene has no fixed length).
- romance_test seeded and given crops that survive the night.
- Mine keeper packs topped up to a minimum total HP (new keeper_min_hp_test).
- Catkins' heart 6 got its quest (recast the monastery bell); other-arc heart arcs filtered (`Hearts.in_arc`).
- Bots frozen in town: the tour guide now starts closer and walks at most 2.5 s.

## Timing (optimised process)

| Stage | Effort | Start | End | Minutes |
|---|---|---|---|---|
| Auditors: 14 focus (medium; 8 sent back for a deeper pass) + 6 checklist (low, one agent), during the C6 wrap-up | medium / low | before 00:00 | | overlapped |
| Package plan | | 00:00 | 00:20 | 20 |
| Fix agents (6, medium) | medium | 00:55 | 01:50 | 55 |
| Merges | | 01:50 | 02:15 | 25 |
| CI (6 shards + 20 bots + playtest), incl. one fix round by 1 CI-fix agent (medium) | medium | 02:15 | 03:35 | 80 |
| **Total from plan to verified merge** | | | | **~200** |

## Still open (next CONDUCTs)
- Underwater/glow caves under the colonies (data stubs in gen_colonies.py `DEEP`); Kelp and Ember maps don't yet match their descriptions.
- Kid's board and Halo's race are still narrated, not playable (question below).
- Heart scenes can chain back to back on one day; "after" lines don't rotate yet.
- story_test still fabricates some conditions (full rewrite planned for C12).
- Wren jr's Gerald quest; rec visitors don't run heart scenes.
- Inspector Hale has no portrait or walker.
- Still open from earlier: Nova's hat, Sal's gangster portrait, seasonal portraits, pixel font (C23); audio depth (C13).

## Questions for Tom (defaults are in place)
See Guide 31.

# CONDUCT 3 report: Battle campaigns (2026-11-19)

Run on the personal account with the standing process. 20 read/play-only auditors and a 20-bot playtest went first. Their findings went into 6 file-disjoint fix packages, together with Tom's decisions from 16:40 (Grump variants, Catkins later, crystal babies won over, a themed battlefield per region), his Guide 26 answers (16:54) and his story answers (17:12). After the fixes: one merge, one full check.sh, 20 bots and the playtest. Findings: docs/reports/C3-PACKAGES.md.

**Whole game after CONDUCT 3: about 66% done, 34% remaining.** Battles and campaigns rose from 82% to 92%. The rec, community farm and farm start went up too. The total fell because four new systems Tom asked for today now count at 0-10%: trading cards (C19), earned fast travel (C14/C16), the casino arc (C10) and helper automation (C11). Without them the game is about 71%.

## Audit (20 auditors + 20 bots)

| Area | Main findings |
|---|---|
| Gating, timing (01, 09) | Gangster story opened on a tier-2 escort. Penguin story jumped from tier 1 to tier 4. "After" lines claimed false geography. The goal line was cut before "Menu > Map". |
| Drill, briefings (02) | "Can't lose" drill could be lost; no back-out; card over the next ring |
| Battle HUD (03) | Toasts over the point menu; "Leave" clipped; 18 px RALLY button; farm tips in battles |
| Ally AI (04) | Helpers spawned inside walls and never moved; couldn't keep up when running; stacked on one pixel |
| Enemy waves (05) | 6-point sieges nearly unwinnable; enemy points stopped spawning; gates could be camped; no wave variety |
| Balance sim (06) | Tier-1 bosses at 120-240 HP; escorts the hardest node at every tier; only one ally actually fought |
| Campaign board (07) | Island campaigns drew the farm town; card text contradicted its button; dead button; unsorted list |
| Rewards (08) | Kill pay shared per field; retreat beat losing; cache "take" 4-5x "share" |
| Writing (10, 11) | Penguin campaigns had soldiers and war talk; Catkins led every campaign; the gangster arc listed penguin-only island campaigns, with penguin text |
| Battlefields (12) | 8 fields served 19 campaigns. All fields shared one layout and one flowering-tree border, even the ash wastes and the city. |
| Audio (13) | No boss music in battles; every gun sounded the same; silent helpers and point actions |
| Projects (14) | Sky Lens, Prism Array and Aurora Dome promised things that didn't happen |
| Saves (15) | Save & title mid-fight left you in a free battle with full rewards (exploit). Closing the app while losing restarted the fight fresh. |
| Performance (16) | Every baked chunk replayed the whole map's draw list |
| Regression of C2 (17, 18) | All C2 fixes hold. Boss song lingered 6-9 s after a win. One flaky community-farm test. |
| Bugs (19) | 0 script errors, 0 softlocks in campaign flows; supply ran dry after losses |
| Docs (20) | Inventory rows out of step; win conditions never played end to end |
| 20 bots | 20/20 clean, 0 fails; 5 "paused with nothing on screen" warnings (self-recovered) |

## Fix packages

| Package | Fixed |
|---|---|
| P1 Campaigns | Penguin campaigns fight 8 Grump variants and 14 named captains. Each campaign has its own leader (partner early, Big Jim, Coldy, the elders, Catkins only late), and penguin lines free the crystals. Crystal-baby nests can be won over: they become Crystal Kin. Early wins are easy (Highway Job first, no tier jump, no escort openers, gentler escorts and sieges, supply never under 10). Penguin-only campaigns, per-arc text, true gate words, goal line kept within the 112-character limit, kill pay per node, board fixes, project rewards made real. |
| P2 Battles | The mustered team fights beside you (up to 4 named helpers). Boss HP set by campaign tier. Helpers no longer get stuck, keep up and spread out. Waves vary and squads attack. Turrets and pylons are real allies. The drill is risk-free. Reopened fights resume. Boss music, horn, a victory sting, convoy and helper sounds, and 2 new ACE gangster battle songs. |
| P3 Map drawing speed | Chunks bake clipped with a geometry memo (12-66 draws per chunk, down from 79-209). Battlefield redraws are up to 3x faster. Arrival stays dark until the ground is drawn. Windward path notches fixed. |
| P4 Battlefields | 11 new region battlefields with 4 layout families, themed borders and scatter, landmarks and named points. Snowy Frostfield, sea-edged Dockside, crystal Vale. New art: 8 Grumps, Crystal Kin, crystal pylon, landmarks. |
| P5 Rec, arcade, community farm | Gangster names (Whack-a-Snitch with new snitch art, Neon Range). Five rec renovations to about day 125, then a seasonal Rec Cup. Gangster rec open to 2am. Prize Candy is a loved gift. Community farm builds take 2-4 nights with half-built pieces. Friends at 4+ hearts let you in late. Ticket-stub icon. |
| P6 Player, HUD, saves, farm | Quest tracker (pick the tracked quest; themed corner compass; points down in mines). Gangster Street Bat. Gun sound per gun plus reloads. Farm debris regrows by rarity, with seasonal weeds and tall grass for fiber and hay. Save exploit closed. Toasts wait during battle menus. "Leave" pinned. Farm tips only on the farm. |

## Tests added
campaign_c3_test, battle_win_test, bf_themes_test, rec_reno_test, quest_tracker_test, street_bat_test, farm_debris_test; tools/battle_audit.gd, tools/battle_shot.gd, tools/bake_clip_check.gd.

## Still open (next CONDUCTs)
- Farm, town and community-farm drawing are not clipped yet. Farm full redraw is about 150 ms.
- Escort convoys restart from the start point when a fight is resumed.
- Regrowth ladder for maps other than the farm.
- Desktop toasts sit at the left edge in battles.
- Player-frozen watchdog (bot 34, town 40,2).
- Campaign, kill and mine payouts still bypass `GameState.add_money`.
- The ownerless pause now names its source. Read it in the next bot run.
- Community-farm city-edge side pavement.

## Questions for Tom (defaults are in place)
1. Should Nova or Pip-Pip lead the early penguin campaigns, as now, or someone else?
2. Is two Refined Crystals the right gift for a crystal-baby nest?
3. Are "Whack-a-Snitch" and "Neon Range" good gangster names?
4. Rec renovations finish about day 125, then a Rec Cup each season. Is that pace right?
5. Is about 400 tall-grass clumps on the summer farm right, or too many? Rocks regrow in 28 days. Is that too fast?

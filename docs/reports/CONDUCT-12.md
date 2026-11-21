# CONDUCT 12 report: writing, story and dialogue (2026-11-21)

A thorough writing pass over both arcs: main story scenes that know which hero you play, choices that come back later, villagers who talk about the weather, the time of day and festival days, a side-story list in the journal, letters from people in town that match what has happened, gift refusal messages, and new checkers that stop a line from naming someone before you have met them. 18 focus auditors (379 findings) fed 7 fix packages (docs/reports/C12-PACKAGES.md, scopes in docs/reports/C12-SCOPES.txt), then one integration pass. **Final full CI c12i: PASS** (6 shards, 20 bots, playtest, live relay 121 ms; shard 3 first failed on stale Steam store facts, fixed and rerun green; the playtest failed once at the house door and passed on rerun, logged as a flake for C22).

**Whole game after C12: about 81% done, 19% remaining** (average of the 96 systems in docs/inventory.csv). Three new rows: talk conditions 85%, writing checks 85%, mail and letters 85%. Up this round: penguin arc 85 to 90%, gangster arc 85 to 90%, side stories 75 to 82%, festivals 75 to 80%, villagers 90 to 92%, dating 85 to 88%, endings 90 to 92%.

## Audit (18 focus auditors, 379 findings: 1 blocker, 109 major, 179 minor, 90 polish, plus 18 verified-clean notes)

| Area | Main findings |
|---|---|
| Penguin story (01-02) | The tell-the-town choice and the crystal answer were never answered; scenes spoke as if you were human when you played Nova, Pip-Pip, Big Jim, Coldy or Mer; two bell causes; the kept locket did nothing. |
| Gangster story (03-04) | Crew finale lines ignored loyalty; Clean Break skipped the crew payoffs; caught lines always blamed a town shopkeeper; ◆ showing in the cash arc. |
| Villagers (05-06) | Talk lines ignored weather, time and festivals; indoor lines out of place; Rook and Bram talked about hunting and meat (the one blocker, against the animal rule). |
| Hearts and gifts (07-08) | Juniper's romance clashed with her Gideon story; Mabel's father had two stories; Tess had no heart arc; empty gift lines; no message when a gift was refused. |
| Mail, side stories, quests (09-10) | Letters ignored who had left town; Tam wrote from the highlands while standing in town; side-story hints didn't say who to see next; no side-story list. |
| Festivals (11) | Hosts who had left town still ran stalls; fireworks in daylight; 11 eggs in a "12 egg" hunt. |
| Items, UI, ranch and decor text (12-14) | 936 items with no description; one decor line repeated hundreds of times; keyboard words shown to pad players. |
| Continuity, cross-refs, conditions, style (15-18) | Lines naming Big Jim, Coldy or the merkitties before you meet them; no test that conditions match game state; spelling and casing drift. |

## Fix packages

| Package | Fixed |
|---|---|
| P1 Penguin main story | Hero-aware scenes for all 5 story heroes; tell_town and crystal_answer answered in talk and scenes; the kept locket goes home to Tomas; four elders; one bell cause (the clapper split); Pip-Pip meets Grandad; Biscuit goes to Posy; %bitter, the friend who turned grey, comes back in both endings. New story keys: if_flag/unless_flag lists, if_item, if_known, if_partner, hint_hero. c12_story_cond_test (39 checks). |
| P2 Gangster main story | `if_loyalty` lines in the finale (Kid, Val, Specs, Dice, Halo); Clean Break carries the crew payoffs; epilogue flag_alt, crew_take and crew_if; caught lines by place; raids stop once the city is taken; Money.t on choice buttons. c12_gang_story_test. |
| P3 Villagers and festivals | Talk keys are conditions joined with "&" (season, weather, arc, heat, festival, morning to night, quest and flag parts); `FestivalWords` hosts; everyone on the plaza 9 to 6 on festival days; indoor lines only at work; Rook is a tracker; region folk lines; 12 eggs in the egg hunt. talk_conditions_test. |
| P4 Hearts, romance, gifts | Juniper no longer a romance candidate (engaged to Gideon); Mabel's father has one story; Tess heart arc, Catkins gift lines (27 arcs); `Hearts.scene_lines` and if_partner variants; gift order and tastes fixed; gift lines never empty; crew tastes and voices; ItemWords for every article and plural. c12_hearts_gifts_test. |
| P5 Mail, side stories, quests | Favour letters with Money.amount and ItemWords; letters skip people who left; `Mail.tam_away`; heat letter once per spike; signed letters; side-story hints name the next giver; `SideStory.open_lines` and a "Side stories" list in the Quests tab. c12_mail_quests_test. |
| P6 Items, ranch, decor, UI text | Every item has a description (936 filled); 518 distinct decor lines instead of 81; sets end in "Set"; catalogue "From:" per arc; Drink vs Eat; achievement texts; pad and keyboard words in hints, menus and battle drill; campaign gate words. c12_items_ui_text_test. |
| P7 Continuity, conditions, style | tools/continuity_check.py (spoilers and arc leaks, allow list), tools/cond_schema_test.py (268 conditions), tools/dialogue_state_test.gd (lines never shown before their flag), tools/text_style_check.py (baseline only goes down); style fixes in unowned files. |
| Integration (23:45-00:20) | P5/P6 merge conflicts; `Story.partner_guard` (a shop deal never sends your partner away); `GameState.gift_block` toasts; heart keepsakes; penguin after-ending letters; told_town / kept_quiet talk; Sal lines after the ending; festival-eve letters; compass follows side stories; Tess ♥6 quest; Bram's Big Jim line waits for the campfire. Fixed the coordinator's CI fails (hearts gating, story_test locket, prompt words, Dialogue null-tree guard). |

## Timing

| Stage | Role | Effort | Minutes |
|---|---|---|---|
| Auditors (18 focus, read/play-only), 21:55-22:40 PT | auditor | medium | ~45 |
| Package plan (hand-built, 379 findings into 7 packages) | conductor | medium | in the 22:40 hand-off |
| Fix agents P1-P7 in parallel, 22:40-23:50 (disk full at 23:20, paused ~15 min) | fixer | medium | ~70 |
| Integration (merge, hooks, regen, checks), 23:45-00:20 | integrator | medium | ~35 |
| Final full CI c12i, 00:22-01:05 | CI | ~43 min | PASS (shard 3 rerun after facts fix; playtest rerun) |
| Package build (report, guide, progress, page) | packager | low | ~10 |
| **Total** | | | **~150 wall clock (21:55-00:25) + final CI** |
| Agents per effort | | | 18 medium auditors; 7 medium fixers; 1 integrator |
| CI first-run result | | | roll CI on P1+P2+P4+P7: FAIL (hearts_test gates, story_test locket, prompt words, mega_region null tree), all fixed in integration; c12i PASS |
| CI minutes | | | 2 package subset runs + 1 roll run + final full run (pre-merge runs blocked by the full disk) |
| Images used | | | 0 |
| ACE credits used | | | 0 |

## Still open
- Tam away and back in talk, the Animal Show and romance (mail side done); Tess birthday lines.
- Rehome destination per home; eat and pet words per creature group; team lesson descriptions; chore words; the rest of the raw home ids in ranch mail and births.
- Duplicate prize names (gen_rec, gift_pie); " II", "(side)", "(indoor)" name suffixes; rp_trophy_bronze and backpack lines.
- Hints in farm.gd, town.gd stall hours, first-crop steps, campaign_gate muster list.
- Region folk weather and winter lines (optional).
- Real hooks for side-story endings: the highland cave (ss_jim_cave), the hall vault (ss_vault_open), Tomas as a villager, crystal-baby battle helpers. Big Jim has no side-story talk hook.
- Style items in other files: the "Skee-Ball" and "Tommy Gun" renames, item name "Fertilizer", lower-case grumps in a few data files, 'the Outskirts' casing, long story lines, the stale gangster copy inside story.json.
- 8 known continuity hits stay on the allow list (tools/continuity_allow.txt) until their lines are gated.
- Remote CI branches to delete if still there: ci/c12p3-80b19a56, ci/c12p5-0e82ced8.
- docs/steam-store/facts.json is rewritten by a check (left uncommitted); after a merge that adds a class_name, run `godot --headless --path . --import` first.

## Tom's calls (defaults kept until he answers)
1. **Juniper.** She is no longer a romance candidate: she is engaged to Gideon, which is the stronger story. 9 candidates per arc remain. An old save already with her keeps her lines. Say "Juniper back" if you want her as a candidate again.
2. **The kid "Pip".** The town kid is called Pip, which is close to Pip-Pip the penguin. Rename him? Default: keep "Pip".

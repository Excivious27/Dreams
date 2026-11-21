# CONDUCT 11b report: Ranching, part 2 (2026-11-20)

Ranching got its second half: 32 new creatures (8 exotics in both arcs, 16 fantastic creatures in the penguin arc, 8 lab strains in the gangster arc), new homes, creatures you earn from quests, colonies and bosses, the Gene Splicer, animal shows with ribbons and medals, real helper chores with caps, deeper team animals and breeding, a voice for every creature, and a fixed battle training drill (P7, from Tom's 17:00 playtest). 14 focus auditors (c11b_01..14, 183 findings) and an art lane (31 renders) fed 7 fix packages (docs/reports/C11B-PACKAGES.md, scopes in docs/reports/C11B-SCOPES.txt), then one integration pass. **Final full CI c11bi4b: PASS (6 shards, 20/20 bots, playtest, live relay, net e2e).**

**Whole game after CONDUCT 11b: about 79% done, 21% remaining** (average of the 83 systems in docs/inventory.csv). Nine new rows: exotic/fantastic/lab creatures (78%), earned creatures and gifts (72%), ranch homes v2 (70%), Gene Splicer (75%), animal shows (80%), breeding depth (75%), creature voices (85%), C11b ranch art (90%), battle training and line-up (85%). Helper automation rose from 45% to 72%, team animals from 60% to 75%, the ranching core from 80% to 86%. Systems for later CONDUCTs (C14, C20, C21) still count at 0%.

## Audit (14 focus auditors, 183 findings: 1 blocker, 89 major, 79 minor, 14 polish)

| Area | Main findings |
|---|---|
| Exotics, fantastic, lab strains (01-03) | Only planned stubs: no species rows, goods, sellers or unlock path; themed feeds treated as bees; no habitat or climate needs; lab strains untrainable. |
| Earned animals (04) | Heart perks, side stories and quests gave no animals; no one gift path; Tam's lamb lost on a full barn. |
| Homes v2 (05) | Blocker: the hutch and sty pens sat inside the farmhouse; no Enclosure, Aviary, Terrarium or Grand Barn; flat Plans board list. |
| Helpers (06) | Feed chore skipped the silo; no caps (idle money); levels didn't help; no forage regions; no helper spot limit. |
| Team, pup, partners (07-09) | Pup commands toasted twice and Fetch was cosmetic; partner cooldowns on the wall clock; a ♥ tap fired later unasked; team animal damage and HP counted twice; no CHECK menu. |
| Shows, breeding (10-11) | Show lines read badly; judging used price; no ribbons or 4th place; rare looks unnamed; no lineage. |
| Economy (12) | Pigs paid 4-7x more than anything; sheep and llamas lost money to their own hay; buildings cheaper than one animal. |
| Art, audio (13-14) | No art for any new creature; the colour key would punch holes in violet glows; voices for big creatures could pick scary sounds. |

## Fix packages

| Package | Fixed |
|---|---|
| Art lane (14:10-15:25) | 31 renders, new tools/slice_c11b.py (check wired into check.sh): 32 creatures with babies, variants and shorn looks, 12 team kinds, 16 building looks with snow and night, 46 item icons, 32 UI icons, 8 stations, interior pieces and floors. Table art/gen/animals/_ranch_art_c11b.json. |
| P1 Data and economy | All 32 creatures are real species in gen_ranch.py (C11B), 38 new items and 29 recipes; homes carry footprints with pens in front; new homes and the Grand Barn; one TIER_LADDER and econ_check paybacks (29-56 days); pig, sheep, llama, duck, goat, rabbit retuned; buildings x4-6 money; slower friendship; lore and voice guards; ♥ tap dropped when busy (ability_tap_test). |
| P2 Ranch depth | Themed feeds, habitat and climate comfort, one egg lookup, rare look names, lineage, the hen's line, "expecting" hints, rare goods, rare recolours (slice_ranch_variants.py), coloured night glow, show prizes (ribbons, trophy), 3-year income test (month_curve long), pup "away" words, team animal damage/HP fixed. |
| P3 Gifts and sources | New `RanchGift`: one gift path, waits with a letter when there's no room; colony creatures, Storm Roc, Frost Wyrmling, Deep Glowworm, hub job animals, the Moon cow; pup Fetch really fetches; partner cooldowns on game time with a ring; chest names; co-op shows your partner and pup. |
| P4 Farm and homes | Pens out of the farmhouse (blocker), every pen kept clear, one incubator for every egg, variant art on the farm, heart perk and side story animals, Ranch page on the Plans board, one bed reset for harvests, guard circles vs crows, Rare Bloodlines node, Specs' perk fixed. |
| P5 Helpers and team | Chores with real caps: helper spots by tier, a night haul cap, energy from bond and level, a second chore, feed from trough/silo/chest, forage regions, guard chore, chore icons and cues; CHECK menu on pen animals, Teach notes, Guard shove, Fetch carries back, followers keep up; new `RanchVoice` for every creature. |
| P6 Shows, battle, voices | `AnimalShow`: clear lines, fair judging, 4th place, rivals by year, goods table, Stock Show words, summer Fleece & Feather, ribbon milestones; battle line-up (pick 4), team animals muster first, jobs by member; gangster coop/barn/hutch/sty/hive names and looks; 19 CC0 creature takes, cues and beds; 2 ACE alt takes (0 credits). |
| P7 Battle training (Tom's playtest) | A "Leave training" button at every step (and a pause-menu row); helpers follow by default; the button is now HELPERS with plain orders (Follow me, Hold here, Go to X); "Build helper" comes first on the banner; 8 steps, one order each. New battle_drill_flow_test. |
| Integration (19:40-21:15) | Voice order settled in RanchVoice; Gene Splicer station (gangster) splicing 8 lab strains through RanchGift; Chores.migrate, guard_cells, reap_tile hooked; Install row on the Plans board; gift names kept out of name pools; station_check fixed (one-arc goods); playtest flake fixed (CI runs it with --fixed-fps 60, waits on game time). Then the bot20 Decor catalogue softlock fixed (21:15-21:45). |

## Timing (optimised process)

| Stage | Role | Effort | Minutes |
|---|---|---|---|
| Auditors (14 focus, read/play-only), ~13:40-14:30 PT | auditor | medium | ~50 |
| Art lane (31 renders + slicer), 14:10-15:25 | art | medium | ~75 (parallel) |
| Package plan (cluster.py, 184 findings into 6 packages) | conductor | medium | in the 14:30-16:30 window |
| Fix agents P1-P6 in parallel, 16:30-19:00 (two server restarts paused them) | fixer | medium | ~150 |
| P7 battle training (Tom's 17:00 playtest), 17:05-19:35 | fixer | medium | ~150 (parallel) |
| Integration (merge, hooks, regen, CI), 19:40-21:15 | integrator | medium | ~95 |
| bot20 Decor catalogue softlock fix, 21:15-21:45 | integrator | medium | ~30 |
| Package build (report, guide, progress, page) | packager | low | ~10 |
| **Total** | | | **~485 wall clock (13:40-21:45)** |
| Gap since last CONDUCT | | | 0 (C11b auditors started while C11a's final CI ran) |
| Agents per effort | | | 14 medium auditors; 1 art lane; 7 medium fixers; 1 integrator |
| CI first-run result | | | c11bi FAIL (station_check: C11b goods never makeable in shared stations; fixed); c11bi2 and c11bi3 FAIL (bot20 Decor catalogue softlock, twice each); c11bi4b PASS |
| CI minutes | | | ~10 package subset runs + 4 full runs x ~14 min |
| Images used | | | ~41 (31 art lane + ~10 in packages) |
| ACE credits used | | | 0 (reused second takes) |

## Still open (next CONDUCTs)
- No giver yet for 7 creatures: crystal hen, star sheep, moon hare (the alien counter needs a stock row), star jelly, glow gecko, aurora fox and the Sun Drake / Komodo. Their art and data are ready.
- Team rows for the exotic and fantastic team kinds (ostrich, emu, Komodo, coral seahorse, frost otter, frost wyrmling, storm roc, chrome runner, drone hog, volt gecko): the art is drawn, no lessons yet. Lab-only lessons, saddlebags, co-op guard rules.
- Ranch Hand Hut is not buildable yet (art drawn), so helper spots come from progress tiers only.
- Add-on items (hay hopper, coop heater, water trough, incubator, tide pool kit, moon lamp, perch, terrarium kit) don't exist yet, so the Plans board Install row never shows.
- Festival egg and a youngster at the show; naming moment on first pet; gift arriving next morning.
- Breeding: pick a pair, a due baby lost when the home is full, unique variants by breeding, Breeds log + Benno letter, a rare jingle.
- Care is still a bit free (mood_comfort 20 -> 10 and higher mood needs for pig, cow, llama): needs a balance check.
- Shows: winter table (Tom), a show host, RecCenter festival bonus, villager reactions.
- Helpers: week log and chest totals, daytime chores (cues are ready), crop + helper share bands in the long income test.
- Art: attack/hurt strips for the classic team kinds, patched calf / spotted piglet / brown kid babies, golden egg / black wool / silver fur icons, add-on icons, gangster building night and snow looks.
- Audio: outdoor enclosure beds, space/crystal beds, kit chimes, a gangster lab pen sound.
- Partner/pup off screen (c11b_08-16) not reproduced; the remote branch wip/c11bp4-nofarm can be deleted.
- Komodo: both arcs as now? terrarium vs enclosure (auditor question).
- From C11a, still open: walk-in coop/barn interiors, brushing, regrowing pen grass, farm load 20-60% slower than C9.

## Tom's open calls (defaults kept)
1. Lab strains: made at the new Gene Splicer (built, default) or as pods at the Robotics Bench?
2. Winter Star Festival: add a ranch table? Default: no (spring Best Egg, summer Fleece & Feather, fall Animal Show and Goods table).
3. Pasture: east of the north track below the cliff (default, where the hutch and sty now stand) or up on the terrace by the stairs?
4. Lab strains: all 8 kept (chrome hen, glow sheep, circuit goat, turbo bunny, circuit cow, drone hog, volt gecko, chrome runner). Trim to 3-4?

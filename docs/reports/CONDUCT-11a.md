# CONDUCT 11a report: Ranching, part 1 (2026-11-20)

Ranching is real now: 9 classic animals in both arcs, homes with tiers, feeding, grazing and the silo, petting and friendship, goods with stars, breeding and the incubator, rehoming (animals are never sold for meat), the 14th skill tree (Ranching), new stations and goods, team animals with lessons, overnight chores, and ranch villagers, letters and shows. 20 read/play-only auditors (c11a_01..20, 280 findings) fed 6 file-disjoint fix packages (docs/reports/C11A-PACKAGES.md, scopes in docs/reports/C11A-SCOPES.txt), then one integration pass. Two integration CI runs passed (6 shards + playtest). **Final full CI (shards, 20 bots, playtest): PASS on c11afix3b (run 44852983412; live relay ok, 34 ms; NET E2E ok).**

**Whole game after CONDUCT 11a: about 78% done, 22% remaining** (average of the 74 systems in docs/inventory.csv). The old animals row (45%) became the ranching core at 80%, with new rows for buildings and pens (75%), the Ranching tree (85%), ranch stations and goods (85%), team animals (60%), ranch villagers and events (75%) and ranch art (90%). Helper automation rose from 5% to 45%. Systems for later CONDUCTs (C14, C20, C21) still count at 0%.

## Audit (20 auditors, 280 findings: 0 blocker, 78 major, 142 minor, 60 polish)

| Area | Main findings |
|---|---|
| Build plan, buildings, care (01-03) | No species data: animal facts were spread over 7 files as name tests; a fixed herd with no roster; two silo copies; feeding did nothing; no grazing; one missed day reset a streak. |
| Goods, breeding, pens, feed (04-06, 08) | Old gold/silver rules in two places; no truffles or rabbit fur; the incubator had a lifetime cap; guests changed the host's animals; fences went inside other pens; hay could not be scythed for a quest. |
| Ranching tree (07) | No Ranching tree; animal skills sat in Farming and doubled up; caps not mirrored. |
| Team animals and helpers (09, 10) | Raised animals could not join the team; no way to give helpers farm chores. |
| Villagers, art, audio (11-13) | Nobody really sold animals; no ranch letters or shows; baby strips that showed adults; two art styles in one pen; no pig, rabbit or bee art; missing voices (pig, bees, rabbit). |
| Tests, regressions, perf, docs (14-20) | Test plan; one freed-sprite error in C10b tests; the farm loads 20-60% slower than in C9 (open); C10b inventory rows out of date. |

## Fix packages

| Package | Fixed |
|---|---|
| P1 Ranch core | New tools/gen_ranch.py -> data/ranch.json (9 species, both arcs; 5 homes with tiers; products, rules, names, planned exotics) with self-checks. `Ranch` (scripts/ranch.gd): feeding by hand, trough, silo or grazing; petting, mood, friendship 0-1000; goods overnight with stars from friendship and mood; pigs dig truffles; breeding with no gender checks, litters and rare looks; incubator; growing up; naming; rehome to Tam's high pasture. Old farms migrated (SAVE_VERSION 12). One "Ranch" block in the morning report; the daily pet nag is gone. Honey brews Flower Mead. New ranch_test (74 checks). |
| P2 Farm, buildings, pens | New `RanchFarm` (scripts/ranch_farm.gd). Animals spawn from the roster into their pens; one silo feeder rule (milkers first); dry-day grazing; a care day needs a pet and a meal; the incubator by the coop (hen eggs 3 days, duck 4); guests see the host's animals but change nothing; fences fixed; crops under a new pen go to the bag; scythed hay for quests; Benno's horse gets a name; animal tap hints ("A: Clover (hungry)"). New pen_test. |
| P3 Generators | Ranching skill tree (14th, both arcs, 4 branches; Rancher node moved from Farming, ranks refunded). Every ranch building tier priced in gen_stations (coop and barn 1-3, hutch and sty 1-2, beehive/bee house/apiary, silo 240/480/720). Mayo Machine and Honey Extractor; new recipes (mayonnaise, honey, beeswax candle, cream, honey yogurt, truffle oil); loom yarn is now 1 wool + 1 fiber -> 2 yarn; stars kept through single-input recipes. Animal counters in shops, hay by the handful, Ranch log and milestones. New ranch_p3_test. |
| P4 Team animals and chores | `TeamAnimals` + `TeamBeast`: grown animals at 2 hearts learn lessons (a treat, 8 energy, one a day); up to 2 join the team; they follow you outdoors, charge, guard or fetch, and fight in battle campaigns. `Chores` (scripts/helpers.gd): pup, team animals, crew and partners water, harvest, feed, pet or forage overnight into a chest, from day 8. Animals and Chores pages in the Party tab, pad-ready. New team_animals_test. |
| P5 Villagers, mail, shows, audio | Favour letters only ask for goods you can make; ranch welcome and first-goods letters (both arcs); Tam's lamb Bramble (a keepsake, never rehomed) and his highland letters; the spouse feeds every animal; Harvest Fair crop contest fixes; Animal Show (Harvest Fair) and Best Egg (Egg Festival); Benno's feed stall and Hazel's farm stall; pen sounds from real animals; CC0 oink, buzz, thump. New ranch_villagers_test. |
| P6 Art | 25 renders, tools/slice_c11a.py: 23 animal kinds with idle/walk/eat/sleep/sad/happy/produce (new chickens, ducks, cows, pigs, rabbits, bees, rare looks, babies), team poses for 8 species, building tiers with snow, night and window glow, 24 interior pieces and 6 floors, 24 product icons, 8 stations, 253 missing skill-node icons drawn. MISSING-ART at zero. |
| Integration | One care path (the farm tap writes the roster and collects overnight goods); overnight treats dry days as pasture (no false "went hungry"); one incubator path (fixed eggs hatching the first night); Ranching keys renamed to one set and read everywhere; Down Pillow uses feathers; art heights, snow/night building looks, team poses wired; Farm Hand workers; the crew farm job waters for the morning; animal voices; Bramble can't be rehomed. New c11a_integ_test. |

## Timing (optimised process)

| Stage | Role | Effort | Minutes |
|---|---|---|---|
| Auditors (20 read/play-only; 01-14 medium, 15-20 low), started ~11:40 PT | auditor | medium / low | ~40 |
| Package plan (sort) | conductor | medium | ~10 |
| Fix agents (6 in parallel from ~12:30; two server restarts paused them) | fixer | medium | ~90 |
| Integration (merge, hooks, regen, 2 subset CI runs), 14:00-14:47 | integrator | medium | ~47 |
| Final CI (6 shards + 20 bots + playtest), 14:50-19:20 | CI | | c11a FAIL (bot20 battle card), c11a2 FAIL (bot.gd freed map), c11a3 FAIL (commons reveal timing); c11afix3b PASS |
| Package build (report, guide, progress, page) | packager | low | ~10 |
| **Total** | | | **~200 + final CI** |
| Gap since last CONDUCT | | | 0 (C11a auditors started during C10b's CI) |
| Agents per effort | | | 14 medium + 6 low auditors; 6 medium fixers; 1 integrator |
| CI first-run result | | | Integration run 1 PASS (6 shards + playtest); run 2 with P5 PASS (one-off mega_region_test script errors, test still 0 failures); final full runs: 3 fails fixed (BattleBrief early B/MENU, CampaignScreen freed pause, commons reveal flags + test wait on game state), then PASS |
| CI minutes | | | ~10 + ~10 (integration) + ~10 (P5 pre-merge) + ~6 final runs x ~14 min |
| Images used | | | ~27 (25 P6 + 2 P3 skill icons); the C11b art lane is counted separately |
| ACE credits used | | | 0 |

## Still open (next CONDUCTs)
- Animal counters: only Tam's shop shows "Animals for your ranch" today (sheep, goats, llamas). Chickens, ducks, cows and pigs are listed with Hazel and rabbits and bees with Posy, but neither has a shop the counter can open (Hazel only has a market stall, Posy's bakery isn't a shop id), so until a counter is wired a new coop or barn still shows its classic starter herd. Fix first in C11b.
- Exotic and fantastic creatures (ostrich, chrome hen, moon hare and more), quest-earned animals and exotic quest rewards (C11b).
- Walk-in coop and barn interiors (the art is drawn), brushing, pen grass that gets eaten and regrows, and a bigger Big Barn pen (the barn sits on the north track: layout pass).
- Pen pathing around troughs (animals walk straight lines in open pens).
- Team animals: a teacher letter to open lessons and chores, a CHECK menu on pen animals (Pet / Train / Come along), skipping the pen while an animal follows, carry-lesson saddlebags, co-op guard rules; full team/ally review in C11b.
- A Ranching node that grants rare_breed (the game reads it, nothing grants it yet).
- Old hp/energy filler over the arc caps in the skill trees (from before; needs a rework of every tree).
- Barn and coop room-tone sounds, hay footsteps, ranch music and product cues.
- Art: duck swim strip, apiary tier 3 (falls back to tier 2), team lamb face colour, one llama frame sliver; old props/*_open pictures still unused.
- Creamery, wool carder, egg sorter, truffle press, cheese rack and deluxe incubator are drawn but not yet stations.
- Tam leaving his hut and boarding Dolly's, the community-farm petting pen, crew ranch ties, quest tracker routing to the Plans board.
- Farm load is 20-60% slower than in C9 and walking p95 is up (c11a_19); perf_probe can't seed yard decor yet.
- One-off mega_region_test script errors in CI run 2 (dialogue after a node left the tree): watch in the final CI; suggested guard after each await in region/town talk flows.

## Tom's open calls (defaults kept)
1. Trainable animals: goat (charge/guard/fetch), llama (guard/carry/charge), donkey (carry/fetch/charge), sheep (fetch/guard), hen and duck (fetch); cows and pigs stay home. Team holds at most 2 animals. Keep?
2. Chores open on day 8 for everyone with no story beat. Keep, or wait for a teacher letter?
3. Gangster arc: a "city ranch" skin for the coop, barn and other buildings (1 render + 2 edits)? Default: both arcs share one look, gangster pens use chain-link.

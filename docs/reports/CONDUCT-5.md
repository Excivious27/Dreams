# CONDUCT 5 report: Home-world look and feel (2026-11-19)

The first CONDUCT run on the optimised process. It used 20 read/play-only auditors (docs/reports/c5_audit/c5_01..20.md) and 6 file-disjoint fix packages (docs/reports/C5-PACKAGES.md). Fix agents were resumed when they stopped early. Everything was merged once and checked once on GitHub Actions, with the full check.sh in 6 shards, 20 bots and the scripted playtest with screenshots. C6's 14 focus auditors started at the merge.

**Whole game after CONDUCT 5: about 66% done, 34% remaining.** The home world's look is now at 85%, villagers and animals at 82%, and the gangster crew art at 85%.

## Audit (20 auditors)

| Area | Main findings |
|---|---|
| Farm (01) | House upgrades never showed their art, and the greenhouse plot sat under the bigger house. There were no fences, coops looked like toys, and the farmhouse was dark at night. |
| Town (02) | Windows never lit at night, crew shops looked like sheds, and a crystal statue covered Mama Rosa's. |
| Outdoor maps (03) | The outskirts fire barrel was four barrels in a row. The glow turf was flat lime, the mountain stream was a straight tube, and piers were flat planks. |
| Interiors (04) | Gangster interiors had no gang look, and the house never grew with its tier. Rooms had no night lighting, and some layouts were copied. |
| Fuzzy art (05) | Ward/HQ blobs and soft rims. Characters, animals and baked ground were not crisp. |
| Gangster heroes (06) | All 12 crew shared one black-jacket silhouette, and their walk_down strips were broken. Thug "half height" turned out to be a measuring error: in-game they are already the hero's size. |
| Penguin characters (07) | Slivers in action strips, tool poses only facing down, and 2-frame walks. |
| Villagers (08) | 16 villagers walked in an old design and switched to another person for poses. Some cells were cut off, kids were adult height, and legs churned while drifting. |
| Animals (09) | The goat was twice the cow's size, magenta stayed under the feet, and ducks walked in a flying pose. |
| Lighting (10) | Festival lanterns didn't glow, caves ran on the sky clock, and mine lamps didn't glow. |
| Weather (11) | Leaves and petals fell in a grid, the weather layer wasn't darkened at night, and storms looked sunny. |
| Edges (12) | Debris on paths, visible joins in floors, dead-end paths, and props on paths. |
| UI (13) | The weather icon hid under the money, and text was 5-6 px. |
| Seasons (14) | Crops didn't wither, snowdrifts lay on paths, and winter roofs and fountains were missing. |
| Effects (15) | Gangster mega bosses had the wrong art, 4 boss cards were missing, scythes swung like axes, and planting played the hoe. |
| Performance (16) | Every mine entry showed a black screen for about 1.4 s. |
| Regressions (17-18) | Hidden pockets moved day to day, and ales, mead and cider were still edible. |
| Bugs (19) | Bots couldn't see ownerless pauses or test difficulty and day length. |
| Docs (20) | Inventory, missing art and the plan wording were stale. |

## Fix packages

| Package | Fixed |
|---|---|
| P1 Farm and home | House tier art, door, mailbox and spawn by tier. The greenhouse moved south-east and old saves migrate. Pens have fences and gates (chain-link for gangsters), and the greenhouse bed has a stone border. The night house art is used. Animal heights are true to life, with shadows, and the goat uses goat2. Withered crops stay on the bed. Debris stays off paths. Tilling throws a dirt puff and watering splashes. The house interior grows by tier (pantry, cellar and keg, study, bath). Dry patches, pen tufts and bridge water boxes are fixed. |
| P2 World runtime | Town windows glow at night (21 masks, home and shop hours). Festival, campfire and neon glows are back. Caves have one steady dimness and glowing lamps. The mine black screen is gone (0.03 s). Crisp art covers characters, animals and baked ground. Tall animated props fade when you're behind them. There are gangster skins for 14 interiors and the crew shops, and the crew shops are full size with dressed lots. Lumi & Theo have their own cottage. The lighthouse lamp stays dark until it's lit, and day windows look like daylight. Co-op and town bakes are faster. |
| P3 Nature, weather, seasons | One animated fire barrel. Soft glow turf. A wandering stream with an oval pool. Leaves and petals fall as particles (with a new petal sprite), the weather darkens at night, storms and blizzards get a wash, and there are no birds in bad weather. Drifts stay off paths and warm regions get no winter. Cherry and apple trees blossom. There is winter art (snowy roofs for 3 house tiers and the cabin, frozen fountains, winter planters, snowy logs). Raccoons, beavers, badgers and otters walk side-on, and the duck waddles. Two floors repeat seamlessly, dead ends get landmarks, paths are clear, and piers have posts. |
| P4 Heroes, crew, foes | All 12 crew and 7 thugs are redrawn ("one shape, one colour pair, one prop"). The walks are fixed. Pip-Pip and Nova have right/up tool poses, and Coldy and Big Jim mine. Big Jim, Coldy, Mer, Coco and Merry have 4-frame walks. Portraits get cyan circuit marks instead of red slashes. Gangster fishing and watering poses are fixed. The scythe and sword sweep. Thugs keep their real height (a test guards it). |
| P5 Villagers, animals, fuzzy art | All 16 villagers have new-design base walkers, and 8 portrait sets are new. Broken cells are redrawn or resliced (benno/marlowe off-by-one). Legs keep pace, idles face the walk direction, and kids are 18 px. The woolly sheep is redrawn and magenta is gone from under the feet. Ward/HQ blobs are trimmed and crispened. Plaza grid lines are cleaned. Magic crops, holo table, teleporter, bulbs, coral boss and oil drums are redrawn. |
| P6 UI, data, bots, docs | The 3 gangster mega bosses use their own art, and 7 boss cards are added. Every alcoholic drink is a trade good. Hidden spots are stable. The HUD clock box is fixed (12.3k money, weather by the date). Text is at least 7 px, with a Text size option. The dialogue camera nudges up. The campaign board uses the wooden panel. "Maple's Mercantile". The gangster rocket waits for Neon. Bots test difficulty and day length, count ownerless pauses, fighters fight, and penguin bots stay in their arc. The inventory is regenerated and the docs are fixed. |

Main-chat merge fixes:
- Winter art is wired on the farm and in town.
- clear_paths now frees a removed prop's whole footprint. It had left an invisible wall on the gangster mountain.
- The gangster store intro now says Maple's Mercantile.

## Timing (optimised process)

| Stage | Start | End | Minutes |
|---|---|---|---|
| Auditors (20, during the C4 wrap-up) | 19:40 | 20:40 | overlapped |
| Package plan | 20:47 | 20:55 | 8 |
| Fix agents (6, resumed when they stopped early) | 20:55 | 22:08 | 73 |
| Merges as packages finished + merge fixes | 21:33 | 22:09 | overlapped |
| CI (6 shards + 20 bots + playtest) | 22:10 | 22:22 | 12 |
| **Total from plan to verified merge** | | | **~95** |

## Still open (next CONDUCTs)
- Nova's hat: redraw her walks in one hat colour (2 renders).
- A gangster-arc Sal portrait. Catkins scale. The fishing line and bobber. Unused effects to wire. pop_items easing.
- Merkitty walks and the crystal baby redraw.
- Seasonal portraits for the 8 redrawn villagers. bram_festival idle. Crystal ball, cauldrons, dark crystal attack.
- Moss texture joins. The quarry watchtower and ruins cottage on paths. Cliff thickness (C14).
- Pixel font (C23). Time format wording.
- The item-job compass needs a "where" scene in the quest data.

## Questions for Tom (defaults are in place)
See Guide 29.

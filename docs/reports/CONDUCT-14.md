# CONDUCT 14 report: world aesthetics, town, beach + marina, earned fast travel, exploration (2026-11-21)

A look-and-world pass over both arcs. The beach is twice as big, with a marina you build up in four tiers, boat routes, fishing charters and marina people. The town grew south with Harbour Row and gained a real plaza, warm cobbles, a winding river and the Mayor's garden maze. Fast travel is now earned: a network of stations and rides in five tiers per arc (TravelNet), with short ride scenes and fares that turn free. Classic regions have secrets, the home valley has rivers and orchard rows, the gang cities have real city blocks, lamps glow in their own colours, and many old sprites were redrawn or cleaned. 18 focus auditors (401 findings) fed 6 fix packages (scopes in /home/claude/wt/C14_SCOPES.txt, APIs and ownership fixed up front in C14_CONTRACT.md), then one hook integration pass. **Final full CI c14i: PASS** (4 of 6 shards, 20 bots, the playtest and the live relay green on the first run; shards 3 and 6 caught one house-style word and two footstep expectations for the now-paved Uptown and gravel quarry; fixed, rerun green).

**Whole game after C14: about 82% done, 18% remaining** (average of the 106 systems in docs/inventory.csv). New or moved rows: fast travel 10% -> 72%, marina 68% (new), town expansion 75% (new), prop dressing 70% (new), secrets 65% -> 74%, lighting 85% -> 87%.

## Audit (18 focus auditors, 401 findings: 2 blockers, 139 major, 192 minor, 68 polish, plus 18 verified-clean notes)

| Area | Main findings |
|---|---|
| Blockers | The marina did not exist (the beach was a 64x36 strip with two plain piers). There was no earned fast travel, only the mega hub gates. |
| Home valley (79) | Riverlands had no river, Orchard Hills no orchard. The Highway showed night corn at noon and no winter. Highlands had snow fields in spring. Straight boxy ledges, name captions baked into sprites, lily pads on winter water, flowers on arrival cells. |
| Town and interiors (40) | Town shots were blank (stale class cache). Flat flagstone "wallpaper", a staircase rim, an empty dark plaza, a ruler-straight river, grey avenues, empty evening festivals, stacked props, no winter roofs, no room to grow. The gang town looked like the penguin town. |
| Beach and marina (27) | No marina, tiers, boats, marina people, charters or boat passage. The gang arc had a penguin ferry. Pier sprites drawn in a loop, a fixed summer look all year. |
| Fast travel, secrets, landmarks (64) | No stations, network, ride scenes or map layer. The balloon flew anywhere. Classic regions had no pocket or secret way. Ways drawn at 55% alpha. |
| Gang cities, mega regions, moon/sky/colonies (93) | Gang cities had no city borders or blocks, Uptown was lawn, Neon was dry. Grass lips on stone and city borders, square dune crops, green waterfalls in winter, no Ironline track. |
| Art, props, lighting, mines, perf (98) | Mines lit like noon, sun effects at night, all lamps the same colour, hearths never glowing. Icon badges and pinholes, magenta shadows, villagers with no real walk, a gutted Dark Crystal. Empty hub towns and colonies. 44 seams in seamless ground. |

## Fix packages

| Package | Fixed | Images |
|---|---|---|
| P1 Home valley | Riverlands river with a bridge deck, Orchard Hills orchard rows (~20 harvestable trees), Highway corn by season and a snowy winter, Highlands spring without snow fields, wandering mountain ledges, the meadow creek carries the farm river on, a reedy backwater at the lake, winter mill and Finn's hut, seasonal wild patches on the Commons, no winter hedges or lilies, stone-only cliff tops off green ground, clear arrival cells, name plates cut off 15 sprites. Test: c14p1_home_test. | 2 |
| P2 Town | Plaza with 4 flagstone variants, a compass mosaic, a smooth kerb ring, an 8-lamp ring and dressing (shade trees, benches, flower kiosk, cafe table, fountain, signposts). Warm cobble avenues, a meandering river with reeds. Harbour Row (town grew to 124 rows): fish market, chandlery, ferry and coach office, quay lane (gang twins: warehouse market, neon chandlery, taxi rank). Mayor's garden: hedge maze with a keepsake at its heart, glass conservatory, rose arbour. Snow roofs on 19 buildings. No stacked props, lamps off lanes. Lantern/Star festivals run in the evening (`Npc.festival_hours/in_festival`). Gang arc: payphone, manhole, neon signs. Test: town_props_test. | 26 |
| P3 Beach + marina | Beach 100x46 with wreck, family beach, cove and sandbar, marina, lighthouse point. `Marina` (scripts/marina.gd, data/marina.json from gen_marina.py): tiers T1-T4 on Hollis's board, each tier dressed on the beach; routes to the marsh, Riverlands and quarry (free at T4); Roz's charters The Shoals and Blue Deep (own fish, Blue Deep at night only); Ines buys the catch of the day at +25%; dock jobs; the Wreck's Log; Lantern Boats. Gang arc: the Tidewater Launch (speedboat), a boardwalk, concrete piers, containers and a crane, the beach_gang song. Seasonal beach, sea fish pool. Test: marina_test. | 2 |
| P4 Fast travel + exploration | `TravelNet` (scripts/travel_net.gd, data/travel.json from gen_travel.py): 62 stations, 74 links, tiers 1-5 in both arcs. `TravelScene` ride overlay (first ride plays in full, then skippable). Keeper rides cost 150 and turn free after 5 paid rides. The balloon flies only between built masts (gang: charter pads). Map-tab station layer. Save version 13 (run.travel, run.marina). 9 classic regions get a pocket, a way and a lore page; ways drawn solid; page props. Quarry gravel ground. Tests: travel_net_test, c14_secrets_test. | 11 |
| P5 Gang cities + mega regions | City borders (brick walls, containers, hedges, billboards), Neon east and south blocks, Uptown paved with hedged beds, Neon wet asphalt, gang skins for the quarry, ruins and marsh (`Region._gang_skin`), Neon night glow masks (karaoke, hotel, ramen shop, President tower). Stone border bands for city and cave areas (`band_style`). Clean desert and winter scatter, Glass Canyon head, frozen waterfall, snowy hot spring, Ironline track, cave and sky pool shores, softer hub plazas, colony jetties. Ride lines only when you really arrived by the ride. Test: c14_p5_test. | 12 |
| P6 Art, props, lighting | `PropDress` dressing (data/props_c14.json from gen_props_c14.py) for hub towns, colonies, sky maps, ruins and rail yards. Steady mine shade, overcast washes for rain/fog/snow, sun effects by day only, coloured lamps, hearth/forge/candle glow, night and winter critters, mine dressing per depth theme. `c14_art_clean.py`: icon badges and pinholes (638 icons), magenta shadows (87 strips), fringe (45 props), holes. make_seamless Poisson fix (44 -> 4 seams). Redrawn: dunes, icons, cobbles, brick, flagstone, ballast, 20 mega villager walks, Dark Crystal, colony elders and kits, hero swim strips. Tests: prop_dress_test, c14_p6_art_test. | 27 |
| Hook integration | Marina routes load as TravelNet links (locked until the tier, free at T4); landing stations at the marsh, Riverlands, quarry and docks; one desk per station (no duplicates); real jetty and pier-tip cells; town ferry office (penguins) and Harbour Row taxi rank (gang); festival hours in romance and the rec center; charter maps get sea fish and sea sound; "Skipper Barnacle's ferry" text; a hidden pocket that walled in a Gilt shop fixed. 23 targeted tests, 0 failures. | 0 |

**Images: 80** from dreams-image (P1 2, P2 26, P3 2, P4 11, P5 12, P6 27). **ACE: 0** (no songs this round). Every prompt is in docs/reports/ART-PROMPTS-CONDUCT-14.md.

## Timing

| Stage | Role | Effort | Minutes |
|---|---|---|---|
| Auditors (18 focus, read/play-only), 01:30-01:50 PT, in parallel with C13's end | auditor | medium | ~20 |
| Packages + contract (401 findings into 6 packages), 01:55-02:05 | conductor | medium | ~10 |
| Fix agents P1-P6 in parallel, 02:05-03:00 | fixer | medium | ~55 |
| Merges, 03:00-03:15 | integrator | medium | ~15 |
| Hook agent, 03:15-03:30 | integrator | medium | ~15 |
| Final full CI c14i, started ~03:32 | CI | | PASS (after shard 3/6 rerun) |
| **Total** | | | **~2 h wall clock (01:30-03:32) + final CI** |
| Agents per effort | | | 18 medium auditors; 6 medium fixers; 1 hook integrator |
| Images used | | | 80 |
| ACE credits used | | | 0 (64 left until Dec 1) |

## Still open

- **Marina:** Cora, Dabney, Dutch and Saffi have posts but no sprites or walkers; new sea fish items; overnight tier builds (now instant); a race mini-game for the Derby/Regatta; charter quests; marina songs and a ferry horn. Landing stations are arrival-only (no return desk). Prompts for the rest are in docs/ART-QUEUE.md.
- **Travel:** co-op guests read their own unlocks (no host sync); T1 links from secret ways; quest compass preferring rides; arrival banners; space rides; cart_rattle and ferry_horn sounds and a travel sting; gang balloon name. Pacing in C16.
- **Town:** riverside promenade and SE artisan corner; Harbour Row shops, rooms, NPCs and Friday market; grand fountain redraw; building scales; east cliff wobble and see-through roofs; town litter from a grass decal pass; 7 gang shop fronts need snow twins; all interior findings (gang palettes, Rook's Lodge props, night dim, partitions, floors).
- **Home valley:** valley secrets (needs Secrets totals), boxy exit notches and rock stubs, cloud border band, iced ponds, snowdrift halos, the mountain west-edge stub.
- **Mega/gang:** the Pit look, floating signs, city secret mouths, more Neon night twins, Docks lighthouse at night, curbs and kerbed paths, meandering mega lanes, sparse outer areas, Windward islands, Star Station hull, cloud bank gradient, Gloamwood night glow, merkitty underwater caverns (not started).
- **Art/props:** town, beach and home maps not yet dressed by PropDress; 4 patterned floors still flag SEAM; jdeco_9, wdeco_2, skydeco_7 need re-renders; merkitty non-sing strips; remaining mine items (cracked-wall pockets, kits, themes); beach bonfire and campfire never glow; 504 character-strip issues in art_audit (not touched).
- **Tooling:** `set_import_lossy.py` rewrites ~120 unrelated .import files: revert those after a run. Marina.passage/ride fallbacks are dead code.

## Tom's call

1. **How far should the gang-arc town go?** It now has a payphone, a manhole, neon OPEN signs and the Harbour Row docks twins. Still the same: the pastel bunting, no posters of the President, no parked sedan. Default: go further in C23b (posters, a parked sedan, darker bunting).

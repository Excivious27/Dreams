# CONDUCT 15 report: seasons (2026-11-21)

A seasons pass over both arcs. Each season now has its own festivals, holidays and small events on a real calendar, its own forage, crops, recipes, shop stock, fish and critters, villager talk, routines, outfits and letters, its own look and weather, and some things only arrive in year 2 or 3. Before this round there were four day-14 festivals and very little else that changed with the season. 18 focus auditors (350 findings) fed 6 fix packages (scopes in /home/claude/wt/C15_SCOPES.txt, Calendar API, festival row format and ownership fixed up front in C15_CONTRACT.md), then one hook integration pass and a first-week weather fix. **Final full CI c15i: PENDING.**

**Whole game after C15: about 82% done, 18% remaining** (average of the 120 systems in docs/inventory.csv). New rows: calendar 86%, festival year 78%, seasonal goods 85%, seasonal fish and critters 84%, villager seasons 80%, seasonal look 80%, weather by save 85%. Moved: seasonal content 45% -> 85%, festivals 80% -> 84%.

## Audit (18 focus auditors, 350 findings: 2 blockers, 132 major, 172 minor, 44 polish, plus 18 verified-clean notes)

| Area | Main findings |
|---|---|
| Blockers | No calendar anywhere (board, menu or HUD). No data model for festivals: four hard-coded day-14 festivals, nothing else. |
| Seasons (02-05) | Forage, shop stock and recipes were the same all year; winter had almost no crops; spring flowers drawn in every season. |
| Festivals (06-07) | The egg hunt was lost if you left the plaza; mini-games were menus; nothing changed in year 2; gang arc had the penguin fair; no festival in most weeks. |
| Economy (08) | No seasonal-only goods, off-season premium with no downside, seed "!" off by one, carrot seeds all year. |
| Fish and critters (09) | Fish ignored the season; critters the same all year; bats and owls by day. |
| Villagers (10-11) | One line per season, the same outfit all year, kids at school in summer, eve letters always said "nine till six". |
| Look (12-13) | Plaza props and city blocks never changed; no interior wreaths or harvest tables; meadow flowers in snow. |
| Weather (14) | Same weather on every save, no special days, no snow depth, no heat waves, rain in the greenhouse. |
| Gang arc, mega regions, tests (15-18) | No city seasons, crew birthdays or festival truce; region props never took winter twins; no calendar or season tests; festival songs missing for the gang arc. |

Lesson: the auditor files came out shifted by one (c15_NN.jsonl held scope NN-1), so some findings landed in the wrong package; P5 caught it and re-routed. Next time keep scope id = file id.

## Fix packages

| Package | Fixed | Images |
|---|---|---|
| P1 Calendar, weather, years | `Calendar` (scripts/calendar.gd): one source for festivals, holidays, small events, markets, birthdays and special weather, with arc, year and needs filters. Calendar screen (7x4 grid, tap a day, past seasons and a year ahead) from the town board, Menu > Quests and the HUD date; HUD event pip and "Y2". Small events and markets (tools/gen_calendar.py). Per-save weather, city weather odds, special weather days, snow depth and first snow, heat waves, snow slows walking, no rain under glass, year in the sleep report. Tests: calendar_test, calendar_screen_test, weather_c15_test. | 3 |
| P2 Seasonal goods | `SeasonGoods` (tools/gen_seasons.py -> data/season_goods.json): 19 new seasonal forage items, 10 winter crops (winter now has 16), 19 seasonal recipes, seasonal shop stock and year-2 extras, 3 off-season greenhouse seeds, seasonal decor shelf, festival stall treats, seed "!" fix, off-season premium x1.1. Test: season_goods_test. | 8 |
| P3 Villagers, mail, events | 330+ new seasonal lines (3+ per season each, gang-arc lines), festival, birthday, eve and weather talk; `Npc.season_place` / `season_activity` (no school on weekends, summer and snow days; winter ice fishing; summer beach); winter coats for everyone, spring and festival outfits; seasonal letters, real eve hours, thank-you and new-year letters; 8 seasonal events and 4 seasonal side stories; spouse season lines. Test: villager_seasons_test. | 5 |
| P4 Gang arc, fish, critters | 16 seasonal fish by water, weather and time, a legend fish per season (Frost King Pike from year 2); critters per season that leave at dusk or in winter; Roz stays in port in storms. City winter look (23 snow twins, winter ground), seasonal Neon weather, stall menus and Hideout dressing; festival truce; racket by season; `CrewSeason` lines and crew birthdays; crew at festivals. Test: c15_p4_seasons_test. | 24 |
| P5 Look, FX, music hooks | `SeasonLook` prop twins (21 plaza and park pieces for spring, fall and winter), `InteriorSeason` wreaths, garlands, harvest tables and frosted windows; meadow flowers by season; no petals over industrial maps; summer leaves and winter flurries; heavier rain and splashes; `MusicResolve.festival_track` (the gang arc never hears a penguin fair tune); fall leaf ambience. Test: c15_p5_test. | 7 |
| P6 Festivals | tools/gen_festivals.py -> data/festivals.json: 25 festivals and holidays a year per arc. `FestivalExtra` (scripts/festival_extra.gd) plays the new ones; egg hunt survives leaving, kid rivals, golden egg; lantern water tells; contest ranks every entry; activities only in festival hours; bonfire moved off the stage; gang dressing. Tests: festival_calendar_test, festival_events_test. | 3 |
| Hook integration | New festival ids start on their days; beach, farm and city festivals no longer empty the town; gilt_gala moved to winter 23; crew birthdays on the calendar; crew placed at plaza festivals; plaza events wait during festival hours; shared chatter for the new festivals; festival music fallbacks; calendar icons per festival. Test: c15_integ_test. | 0 |
| First-week fix | The per-save weather had re-rolled week 1 (day 4 rain became clear, gang heroes ended Exhausted). Week 1 now keeps the old fixed weather; per-save weather starts on day 8. first_week_test passes. | 0 |

**Images: 50** from dreams-image (P1 3, P2 8, P3 5, P4 24, P5 7, P6 3). **ACE: 0** (no credits until Dec 1); new festival songs are queued in docs/ART-QUEUE.md and play existing songs meanwhile. Every prompt is in docs/reports/ART-PROMPTS-CONDUCT-15.md.

## What changed (both arcs)

- **Calendar:** tap the date on the HUD, pick "Calendar" on the town board or open Menu > Quests. Every festival, holiday, market, small event and met birthday, with times and places.
- **25 festivals and holidays a year**, some from year 2 or every 3rd year. New: Blossom Dance (spring 24, evening, park), Founders' Day (summer 7, year 2+), Tide Feast (summer 24, beach), Regatta / Harbour Lights (summer 18, marina T3), Moon Jellies (summer 27 night, year 2+), Fishing Derby (fall 9, marina T2), Hollow Night (fall 27, lantern maze), Winter Market (winter 10), Gift Swap Feast (winter 28), a comet night every 3rd year, and a holiday on day 1 of each season. Gang arc: Block Party, Neon Night, Harvest Hustle, Snowlight Street Party, Mask Night, Year's End Swap, plus Spring Cleanup, Neon Street Fair, Rooftop Cinema, Payday Feast, Gilt Gala and Countdown on the Roof.
- **Seasonal goods:** 19 new forage finds, 10 winter crops, 19 seasonal recipes, shop shelves that change by season (and more in year 2), greenhouse off-season seeds, seasonal decor, festival treats.
- **Fish and critters:** 16 seasonal fish and a legend fish per season; robins and ladybugs in spring, dragonflies in summer, crows and hedgehogs in fall, blue jays and deer in winter.
- **Villagers:** seasonal talk, routines, outfits, letters, events and side stories; spouse lines; the crew has seasonal lines and birthdays.
- **Look:** seasonal plaza planters, kiosks and benches, snowy city blocks, wreaths and harvest tables indoors, frosted windows.
- **Weather:** each save has its own weather from day 8; special days (spring shower, meteor shower, harvest moon, first snow, aurora night), snow that builds up, heat waves that dry unwatered crops.
- **Music and ambience:** festival songs per arc through one resolver, a fall leaf bed in the wild.

## Timing

| Stage | Role | Effort | Minutes |
|---|---|---|---|
| Auditors (18 focus, read/play-only), 05:15-05:35 PT | auditor | medium | ~20 |
| Packages + contract (350 findings into 6 packages), 05:35-05:50 | conductor | medium | ~15 |
| Fix agents P1-P6 in parallel, 05:50-06:35 (P2 06:35-07:05) | fixer | medium | ~45 (P2 ~75) |
| Merges, 07:05-07:10 | integrator | medium | ~5 |
| Hook agent, 07:10-07:28 | integrator | medium | ~18 |
| First-week weather fix, 07:30 | integrator | medium | ~5 |
| Final full CI c15i, started ~07:28 | CI | | PENDING |
| **Total** | | | **~2.25 h wall clock (05:15-07:30) + final CI** |
| Agents per effort | | | 18 medium auditors; 6 medium fixers; 1 hook integrator; 1 first-week fixer |
| Images used | | | 50 |
| ACE credits used | | | 0 |

## Still open

- **Calendar and board:** eve poster prop on the board, gang board look, lamp in front of the board.
- **Festivals:** real-time steer and rhythm mini-games, Secret Star giver, a second harvest and star category, crown and costume items, Hollow Night treat doors, year-end speech, Gala Wheel; beach, farm and city festivals play only what their scene owners built (music, crowds, venue dressing for Blossom in the park).
- **Seasonal goods:** wheat "any" still grows in winter (crop season lists in game_state.gd), fall is the weakest crop season, frosty growth strips for the new winter crops, seasonal player wear, seasonal gift likes.
- **Fish and critters:** ice fishing and frozen ponds, winter farm pond, fish size for the derby, a seasonal catch of the day, ranch seasonal goods, bats by day in twilight regions.
- **Villagers:** seasonal portraits to match the new walkers, per-outfit pose strips (spring and summer outfits still borrow base poses), Hazel's spring outfit held back, seasonal heart scenes, companion and indoor seasonal lines, crew outfits.
- **Gang arc:** gang seasonal quests and side stories, casino seasons, gang interior seasonal props, Block Board, Hideout leave line.
- **Look and FX:** window boxes, snow on paving, roof-snow building twins, fall big oaks, lawns to snow in city regions, special-weather sky FX (meteors, aurora, moonglow, rainbow), snow depth drawing, icicles and hail; a few P4 snow twins are slightly off (black car angle, water tower legs, blank billboard).
- **Weather:** storm and fog effects in fishing, world gen and mega travel; weather pausing under dialogue; fireflies by day.
- **Tests:** first_week_test was failing on gang Exhausted days; fixed by the first-week weather fix.
- **Art and audio queue:** docs/ART-QUEUE.md (C15 sections): new festival and seasonal songs for after Dec 1, special-weather beds, the art above.

## Tom's call

1. **Bug net and critter log.** Seasonal critters are in; should you be able to catch them with a bug net and fill a critter log? Default: yes, in C16 as part of the skill ecosystems.

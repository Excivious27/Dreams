# CONDUCT 13 report: audio depth (2026-11-22)

A deep audio pass over both arcs. The music now changes with the season, dawn, evening and night, rain, storms and snow, the weekend, the story and the after-ending, and a different take plays on different days. The gangster arc has its own farm, town and valley songs, its own jingles and its own menu sounds. Every festival has its own song, and the casino, the museum and the crew venues have songs of their own. Story scenes play mood songs. Options gained mono, softer loud sounds, sound captions and separate Voices, UI and Footsteps sliders. Co-op has join and leave sounds. 18 focus auditors (398 findings) fed 6 fix packages (scopes in /home/claude/wt/C13_SCOPES.txt, song names and APIs fixed up front in C13_CONTRACT.md), then one hook integration pass. **Final full CI c13i: PASS** (5 of 6 shards, 20 bots and the playtest green on the first run; shard 3 caught a merge slip in the web export presets and a loop point the P3 merge brought back, and the relay end-to-end test had a stale probe; all fixed, shard 3 + relay + end-to-end rerun green).

**Whole game after C13: about 81% done, 19% remaining** (average of the 103 systems in docs/inventory.csv). Seven new audio rows: music resolver 88%, song library 80%, jingles 88%, sfx library 88%, ambience 85%, audio accessibility 85%, co-op audio 70%.

## Audit (18 focus auditors, 398 findings: 1 blocker, 111 major, 212 minor, 74 polish, plus 18 verified-clean notes)

| Area | Main findings |
|---|---|
| Music maps (01-04) | One song per map all year: no seasons, dawn, evening or weather alternates. The gangster arc heard the penguin pastoral songs on the farm, in town and in the valley. The interiors and crew venues reused other songs. The one blocker: town shots came out blank, because of the sweep's class cache. |
| Events, bosses, minigames (05) | No festival day songs, no final-boss themes, no gang danger song. The casino and arcade used stand-in sounds. The web prefetch loop never ended. |
| Story cues (06) | 41 live story beats had no music or sound. The endings shared the music box. The dream beats and heart scenes had no moods. |
| SFX (07, 09, 14) | No casino, arcade, carpet, metal or ice sounds. The reel was 9 dB too quiet and rock_break was quieter than pick. The pup's bite was the fishing bite. Babies chimed like a pickup. Knockout had no body fall. |
| UI (08) | j_buy and j_confirm were brick-walled. ach_unlock was missing. The gang arc used the penguin UI kit. The craft screen, the wardrobe and the pad keyboard were silent. |
| Ambience, mix (10-11) | The Hideout had city hum. Many rooms had no bed. Ducks held through silent tails. Low sounds lost 6-8 dB on a phone. |
| Tests, plan, arc, perf (12-16) | No full place x state song test or action x sound test. 15 songs were muffled. |
| Accessibility, co-op (17-18) | No mono, captions or separate sliders. A guest's clock ran while the host was paused. Joins and leaves made no sound. |

## Fix packages

| Package | Fixed |
|---|---|
| P1 Music engine | `Music.resolve` / `MusicResolve.pick`: after > weather > dawn/evening/night > season > weekend > base, arc twin first, daily rotation through _2.._5. Festival day songs, crew venue songs, boss songs (Dark Crystal, President). `GameState.weekday/day_name/story_stage`, `Music.sfx_log`, gang sfx swap, jingle arbitration and duck length, `Music.mood/release_mood`, gang stand-in songs. The web prefetch blocker is fixed. Tests: music_resolve_test, music_map_test (7,499 checks), music_stream_test block. |
| P2 Songs A (outdoor) | 55 ACE calls. 102 files: 57 new songs, 13 muffled base songs re-rendered, 32 free second takes imported as `_2`. |
| P3 Songs B, jingles, mix | 40 ACE calls. 38 songs (interiors, festivals, 12 moods, finale bosses, danger_gang, dates, arcade, after-ending, 2 free takes). 20 jingles plus a 9-sound gang UI kit. j_buy and j_confirm re-cut. reel, rock_break, cv_gloam and the low phone cues re-levelled. New `tools/sfx_level_check.py`, `data/sfx_meta.json`, `ace_batch --alt/--pair`. |
| P4 Story and minigame cues | Every live 5+ line beat has a cue; each ending has its own song; chapter title cards; dream and heart-scene moods; `Dialogue.scene_song`; one crew-join cue; hack, drill and capture cues; gun sounds only for gang-arc people. Test: story_audio_test. |
| P5 SFX world | 22 CC0 sounds (below). Footsteps for carpet, metal and ice; vehicle beds; rowboat oars; reload blocks firing; gold-star harvest; pet howl and hurt; the tracker barks once; baby voices. sfx_audit hard-checks the contract sounds and fails on a new stand-in (`tools/sfx_standins.txt`). Test: action_audio_test. |
| P6 UI, ambience, accessibility, co-op | `Captions`, `Settings.mono/reduce_loud/captions`, Voices/UI/Steps buses (`data/sfx_buses.json`), Options headers. Room tones for every interior. The Hideout is now woodland. dB fades. No-silence map (13,934 checks). UI cues on the craft, wardrobe, decor and pad keyboard screens. Guest clock hold, guest morning cues, join/leave cues. Tests: access_audio_test, ambience_map_test, ui_cue_test. |
| Hook integration (01:35-01:50) | Call sites renamed to cabinet_coin and ticket_out. Step levels for carpet, metal and ice. `_is_jingle` strips `_gang`. boss_* and keeper never rotate. `Quests.announce` plays j_quest everywhere. The breaking swing plays rock_break alone. `Music.mood` is safe on a missing file. The bakery, library, museum, workshop and casino interior songs are wired, and sfx_meta is regenerated. 0 failures on 16 audio tests. |

## Songs made (ACE Music, instrumental)

**140 new or replaced songs**: 102 from P2 and 38 from P3. 34 of them were free second takes (P2 32, P3 2: keeper_2, arcade_gallery).
- **Gang arc outdoor (P2):** farm_gang(+_2), town_gang(+_2), forest_gang, meadow_gang, lake_gang, mountain_gang, beach_gang(+_2); farm_fall_gang(+_2), farm_winter_gang, winter_gang, town_winter_gang, forest/meadow_fall_gang, forest/meadow_winter_gang; night_gang (re-render), night_winter_gang(+_2), rain_gang, storm_gang(+_2); hub nights neon_night, uptown_night, outskirts_night(+_2).
- **Penguin seasons (P2):** farm_summer, town_fall(+_2), town_winter(+_2), beach_spring(+_2), beach_fall(+_2), meadow_fall(+_2), meadow_winter(+_2), lake_fall(+_2), lake_winter, mountain_fall(+_2), mountain_winter.
- **Dawn, night, weather (P2):** morning, storm(+_2), rain (+rain_2, re-rendered on guitar), night (re-render), night_summer, night_winter(+_2).
- **Muffled re-renders (P2):** night, rain, lake, sky(+_2), marsh(+_2), wastes, forest, hideout, night_gang, mega_gloam, mega_hollow_deeps(+_2), sanctuary. The town base song was swapped to its brighter take, and the old one was kept as town_2.
- **Free second takes (P2, 0 credits):** battle_escort_gang, battle_gang, battle_penguin, battle_siege_gang, beach, campaign_map_gang, cattopia, colony_ember, combat_elite(+gang), combat_light(+gang), docks, festival_night, finargle, house, inn, meadow, mega_desert(+canyon), mega_gilt, mega_iron, mega_station, mega_wind, neon, orchard, outskirts, quarry, raid, shop(+gang), town (all as `_2`).
- **Interiors and venues (P3):** casino, museum, library, workshop, bakery, house_gang, inn_gang, deuce_arcade, trading_post, net_cafe.
- **Festivals (P3):** festival_egg, festival_lantern, festival_star. The harvest fair keeps the existing fiddle "festival" song.
- **Story moods (P3):** mood_tender, sad, tense, triumph, mystery and comic, each with a `_gang` twin (12 songs).
- **Bosses and danger (P3):** boss_dark_crystal(+_2), boss_president(+_2), danger_gang. The `_2` takes are kept for a phase-2 switch and never rotate.
- **Other (P3):** date_evening (re-render), date_evening_gang, arcade_stack, arcade_whack, arcade_gallery (free), keeper_2 (free), farm_after, town_after.
- **Not shipped (failed the accept rule):** hideout_night, docks_night, beach_winter, forest_winter, forest_fall, orchard_winter, lake_winter_2, night_2, the mega_frost_caverns and mega_frost_summit re-renders. Never rendered: farm_spring, town_summer, orchard_spring.

## Jingles and sfx made

- **Jingles (ACE, P3):** a gang set of 16 noir stings (levelup_gang, quest_done_gang, j_skill/victory/battle_won/battle_lost/battle_start/campaign_won/secret/page/region/treasure/heart/gift/birthday/morning_gang), plus j_casino_small, j_casino_big, ach_unlock and j_quest. j_buy and j_confirm were re-cut from their kits. A gang UI kit of 9 sounds: menu_open/close_gang, ui_tap_gang x3, page_gang, tab_gang, scroll_tick_gang.
- **CC0 sfx (P5; licences in docs/AUDIO-CREDITS.md and audio/CC0_USED.json):** from BigSoundBank (CC0), roulette_spin, roulette_ball, slot_spin, slot_stop, target_tin, claw_move, claw_drop, ticket_out, cabinet_coin, gallery_ding, step_carpet, scooter_ride, motor_loop, sled_snow, milk, shear, howl_far and pet_howl. From Kenney "54 Casino sound effects" (OpenGameArt, CC0), card_deal, card_flip, chip_clack and chips_stack. Made from CC0 files already in the game: skee_roll, egg_collect, step_metal, step_ice, cv_crystal_baby (from "80 CC0 creature SFX"), knockout (re-cut with a body fall), block_fall, croak, forage and march. No synth recipes were needed.

## ACE credits and images

- ACE: P2 made 55 create_song calls (220 credits) and P3 made 40 (160 credits). 444 credits at the start; **64 left until the Dec 1 refill**.
- Images: 0.

## Key finding (kept in docs/AUDIO-PLAN.md)

Muffled ACE renders come from the arrangement, not from the prompt's hi-fi words. Calm songs led by piano, celesta or harp (also cello, vibes or clarinet) with no drums come out dull, and so does anything called lo-fi or vinyl. The same brief led by guitar or mandolin, with a shaker, brushed hi-hat or tambourine pulse, measures 7-10 kHz. On piano, rain failed twice (1.4 and 2.1 kHz). On guitar with a shaker it passed (8.4 and 9.2 kHz).

## Timing

| Stage | Role | Effort | Minutes |
|---|---|---|---|
| Auditors (18 focus, read/play-only), 23:50-00:35 PT | auditor | medium | ~45 |
| Packages + contract (hand-built, 398 findings into 6 packages), 00:35-00:42 | conductor | medium | ~7 |
| Fix agents P1-P6 in parallel, 00:42-01:30 | fixer | medium | ~48 |
| Rolling CI, 01:15 | CI | | 2 fails, both fixed |
| Merges, 01:20-01:35 | integrator | medium | ~15 |
| Hook agent, 01:35-01:50 (server restart mid-run) | integrator | medium | ~15 |
| Final full CI c13i 01:40-02:30 + fixes + rerun c13i2 to 03:10 | CI | | PASS |
| **Total** | | | **~2 h wall clock (23:50-01:52) + final CI** |
| Agents per effort | | | 18 medium auditors; 6 medium fixers; 1 hook integrator |
| CI first-run result | | | rolling CI: 2 fails, fixed before the merge |
| CI minutes | | | rolling run + final full run c13i |
| Images used | | | 0 |
| ACE credits used | | | 380 (95 create_song calls; 64 left until Dec 1) |

## Still open

- **Songs:** farm_spring, town_summer, orchard_spring and orchard_winter, beach_winter, forest_fall and forest_winter, hideout_night, docks_night, night_2. Also the mega hub nights, the mega gang songs, the chapel, clinic, mega_frost_caverns and mega_frost_summit re-renders, festival_night_gang, house_winter, intro overtures, a penguin ranch-home song and gang jingles that quote the arc theme. Wait for the Dec 1 credit refill.
- **Engine:** the boss phase-2 switch to boss_*_2 and keeper_2 on the deep tiers has no caller yet. Also open: a market-day song, colony restored songs, region and mega_travel music, raising WEB_CACHE_CAP, and web/post_export.py.
- **Sounds:** j_recruit (j_skill plays) and quake (stone_grind plays) are allow-listed stand-ins. Also open: boss_down take 1, extra takes for scythe/dig/cast/reel, per-family foe hit and death sounds, animal team cues, chore cues, the ladder door creak, impact timing in mine/region/mountain/moon, and a cash_3 re-import.
- **Story:** portrait moods on about 945 story and heart lines, Hale and Auk portraits, a per-villager voice table, and per-line cues in events, romance and quests.
- **Ambience:** seasonal and weather layers, landmark emitters, indoor weather from the last sky, Gilt Gardens birds, per-festival spots, thunder, ranch room tones and bed seams.
- **UI:** toast keyword cues, GameMenu slot and skill-node cues, hotkey tab cues, the drink-vs-eat sound and the energy-warning sound.
- **Co-op:** partner sounds on puppets, a shared room song, guest weather rollover and forecast, a shared danger tier, the host away frame, the state send rate and the Steam state sequence. Net findings in net.gd and server.js are still open.
- 8 sfx groups have a 4-5 dB take spread on a phone. This is report-only in sfx_level_check.
- The town and festival shots were not re-run after the sweep fix: the next sweep does that.

## Tom's calls

None new. Earlier calls still stand (Guide 40).

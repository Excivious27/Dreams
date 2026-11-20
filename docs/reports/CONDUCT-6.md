# CONDUCT 6 report: Audio and music (2026-11-20)

The second CONDUCT on the optimised process. 14 focus auditors and 6 checklist auditors (c6_01..20, 313 findings) fed 7 file-disjoint fix packages (docs/reports/C6-PACKAGES.md): six audio packages plus P7 for Tom's phone playtest at 22:37. Everything was merged once and checked on GitHub Actions (check.sh in 6 shards, 20 bots, the scripted playtest with screenshots).

**Whole game after CONDUCT 6: about 66% done, 34% remaining.** Audio was already counted at 93% in the inventory; this round made it sound right on a phone rather than adding new systems, so the whole-game number holds. Systems Tom added for later CONDUCTs (hazards/lava C20, General Store C21, marina C14) still count at 0%.

## Audit (20 auditors, 313 findings: 1 blocker, 68 major, 166 minor, 78 polish)

| Area | Main findings |
|---|---|
| Music files (26) | The blocker: the loop splice in ace_import broke seams on every looping song. False endings and dead air, the title and arc themes not mastered, quiet intros dipping at the loop, songs too bassy for a phone speaker. |
| Web streaming (14) | Ending and credits songs carried a fight song, the cache never checked versions, memory grew without limit, one failed prefetch stalled the rest, a 45 s total timeout, boss/keeper/mine songs not fetched ahead. |
| Combat music (10) | Minions restarted combat after a boss died, more than one victory sting, the boss song held through post-boss talk, area songs restarted from 0:00. |
| Songs by place and boss (18) | Gangster captains and mega rivals got the penguin boss song, the festival song played at night, no gangster night song, outskirts and countryside picks wrong. |
| Combat sounds (16) | Enemy deaths all sounded alike, archers zapped, the war horn was a bicycle horn, rock breaking played crate_break, no player hurt or knockout sound. |
| Footsteps (11) | Seamless-ground regions had no ground word, snow steps on any ground in winter, no wood on piers and bridges, no wading splash, step timer ignored walk speed. |
| Ambience (16) | Surface beds in caves, mega beds ignored time and weather, battlefields had no beds, hearth crackle in rooms with no hearth, bed loops clicked. |
| Sound files (17) | 13 files never softened, one-shots 25-35 dB too hot, takes 6+ dB apart, low-end sounds silent on a phone, identical takes, late starts. |
| UI, arcade, rec (27) | Arcade results played the losing jingle on winning rounds, coins in the gangster arc, silent mail and ticket gifts, menus without close sounds, the Music Box and home Arcade Cabinet did nothing. |
| Story and cutscenes (22) | The final boss beats overrode the arc themes, bell beats were silent, merkitty_song never played, sad beats ended on quest_done, endings resolved to the meadow song. |
| Mix and settings (24) | Jingles didn't duck the song, no limiter, a flat volume curve, no audio options on the title, unmute restarted the song, muted music still downloaded, audio kept playing in a hidden web page. |
| Farm, pets, campaigns (40) | Silent morning, stations, chests, drinks, horse, keg and pet commands; convoy, retreat and muster gave no feedback. |
| Docs, generators, bots (12) | Stale inventory and audio plan, mega "light" written twice, a town freeze, bot coverage gaps. |

## Fix packages

| Package | Fixed |
|---|---|
| P1 Music engine, streaming, mix | Versioned music cache (hash per song), LRU of 4 streamed songs and a 40 MB cache cap, prefetch never stalls, a stall watch instead of the 45 s timeout, the wanted song first, boss/keeper/mine/neighbour songs fetched about 1 s after a map loads, ending and credits prefetched. Play-once songs never carry a fight. Combat music: minions die with the boss, one victory sting, area songs resume where they left off. Duck layers (`set_duck_layer`) so jingles and battles dip the song and Ambience can't undo it; a master limiter, a volume curve, audio options on the title, reset to defaults, unmute doesn't restart, muted music doesn't download, audio pauses when the page is hidden. Talk blips have their own voice. Deploy checks the music count. New mix_test. |
| P2 Songs | The loop blocker fixed (sample-accurate numpy crossfade with a self-check) and every looping song re-imported from its raw render (49 raws re-downloaded). New music_loop_check.py in check.sh. False endings cut on 9 tracks; title and arc themes mastered; phone-speaker shaping (low shelf, presence lift, phone-loudness trim); loop offsets past quiet intros in data/music_loops.json. Re-renders of the weakest and quietest gangster songs; new night_gang, outskirts, battle_escort_gang, festival_night, campaign_map_gang and longer boss songs. |
| P3 Sound and ambience files | 662 audio files re-imported from source and softened once; sfx_audit fails on any unsoftened file. Loudness measured K-weighted, bright sounds never boosted, takes matched within 3 dB, phone-audible low ends. Every ambience bed re-imported with a real crossfade, longer loops, one level target. New sounds: war horn, gangster stab, car horn, animal voices, bell tolls, chest close, scythe, harvest pluck, swim stroke, dice, knockout, player hurt, hoof hits, room tones and more (list in new_sounds.md). |
| P4 Where music and ambience play | Penguin countryside song, festival song by day and festival_night after dark, night_gang, outskirts, sanctuary at night, winter song on snow days, battlefield arc variants, gangster bosses and rivals on boss_gang, keeper drums only in the mine. Footsteps by ground (seam words, wood, snow only on snow ground, wading, hooves, speed-timed). Ambience: no surface beds in caves, mega beds follow time/season/weather, themed battlefield beds, hearth only by a hearth, urban city areas. Animal voices on petting, rock_break, door_close, bobber plop, knockout, retreat confirm. Mega "light" written once. New ambience_test. |
| P5 Gameplay cues | Morning cues, station sounds for all 24 stations, scythe swish, harvest pluck, swim strokes, horse hooves and whinny, pet voices and commands (cats meow), rock_break everywhere, enemy deaths by family, guard/block, spells and Gift moves, wind-up and enrage cues, gun levels, war horn, convoy and retreat cues. Commons earnings go through add_money. New c6_cue_test. |
| P6 UI, arcade, rec, story | Boss beats no longer override the arc themes; per-line sfx/music keys in Dialogue; bell tolls, merkitty_song, soft endings for sad beats, the ending holds title_musicbox. Arcade three-tier result stings, per-arc coin and cash sounds, mail and ticket cues, close sounds on every full-screen UI, dialogue cursor tick. Music Box and home Jukebox play music, the home Arcade Cabinet gives free practice, claw and skee sounds, one claw win jingle. |
| P7 Tom's playtest | Early mining and chopping take more hits (pickaxe x1.6, axe x1.8 at the start, less with tool tier and skill), energy a bit higher early. The watering can holds 20 pours (more with tier and skill), shows its level and refills at any water. The stuck "Turnip Seeds" text fades after 2.5 s. Pup's Pack option waits for a pack. Drag and drop in the bag, toolbar, trash and chests. Stardew-style Organise, Add to stacks, Deposit all, Take all and a trash can (asks for stacks worth 100+). |

CI-only fixes after the merge:
- The CI runner lacked numpy, which the new music_loop_check needs: added to the workflow's setup.
- The CI runner lacked ffmpeg for the audio checks: added to the workflow's setup.

## Timing (optimised process)

| Stage | Effort | Start | End | Minutes |
|---|---|---|---|---|
| Auditors: 14 focus (medium) + 6 checklist (low), during the C5 wrap-up | medium / low | before 22:45 | | overlapped |
| Package plan | | 22:45 | 22:58 | 13 |
| Fix agents (7, medium) | medium | 22:58 | 00:15 | 77 |
| Merges as packages finished | | 23:40 | 00:05 | overlapped |
| CI (6 shards + 20 bots + playtest, incl. the numpy and ffmpeg fixes) | | 00:05 | 00:50 | 45 |
| **Total from plan to verified merge** | | | | **~120** |

## Still open (next CONDUCTs)
- Audio depth (C13): alternate area and season soundtracks, a second take for the most-heard songs.
- Footstep prominence and background-sound levels judged by ear on a phone.
- A hatch-day peep for the coop. Festival lantern fireworks and ArcIntro cues (unowned files).
- Real field recordings for town chatter, festival crowd and rain on the roof where CC0 takes are thin.
- Still open from CONDUCT 5: Nova's hat, Sal's gangster portrait, merkitty walks and the crystal baby, seasonal portraits, moss joins, pixel font (C23).

## Questions for Tom (defaults are in place)
See Guide 30.

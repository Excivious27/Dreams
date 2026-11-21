# Dreams — Audio plan through ACE Music

## Status (Nov 19, CONDUCT 6): done — the sections after this one are the original plan (history)

- **Music: 95 songs** in audio/music (91 looping + 4 play-once: both endings, credits, the merkitty lullaby), all ACE Music renders except the title and the two arc themes (Tom's uploads in audio/incoming, re-mastered through the same importer). Every version id is in audio/ACE_LOG.json (with `previous` takes for re-rendered songs).
- **C6 import fix (all songs re-imported from their raw renders):** the old loop seam silently dropped its crossfade, so every looping song ended 6 s short with a hard splice. `tools/ace_import.py` now does a sample-accurate equal-power crossfade in numpy, cuts false endings (a render that stopped and restarted a fragment), keeps a quiet intro once (loop point in data/music_loops.json, `"track": seconds`, read by Music), masters for the phone speaker (low shelf on bass-heavy songs, -16 LUFS / -1.5 dBTP, then a -1.5..+3 dB trim measured through a 300 Hz high-pass) and encodes Vorbis q3 (~112 kbps). `tools/music_loop_check.py` (check.sh) fails any join that clicks or jumps more than 4 dB.
- **C6 re-renders (2.5 min, full-range, mid-heavy for phones):** mine_deep, night, rain, hideout, boss_penguin (45 s -> 2.5 min), quarry, boss_gang (68 s -> 2.5 min), moon, campaign_map, clinic, ending_gangster (66 s -> 2.7 min), mine, shop_gang, title_musicbox, danger, battle_gang, docks, underground; mega_gloam_moonpool swapped to its full-range take.
- **C6 new songs:** night_gang (gangster nights, noir jazz), outskirts (gangster Outskirts turf, street funk), battle_escort_gang, festival_night (festival evenings).
- **Still soft (ACE renders quiet acoustic styles band-limited, ~2 kHz top):** marsh, sanctuary, chapel, meadow, sky, house, forest, mega_wind_storm, ending_penguin, night/rain/clinic/moon (better than before, not hi-fi). Both takes were checked; neither is full-range. Next step if wanted: re-render with brighter instrumentation.
- **Jingles and instrument sounds (45, from ACE), recorded effects and ambience (CC0 packs):** see docs/AUDIO-CREDITS.md and audio/sfx/ACE.txt.
- **Checks:** `tools/sfx_audit.py` (every sound/song the game asks for exists) and `tools/music_loop_check.py` (loop seams) run in check.sh.
- **Phone size:** every song except the packed few streams on demand (data/music_stream.json, rebuilt by tools/music_stream.py) and is cached after first play; ~150 MB of music in total at q3 (was ~121 MB at q2).
- **Make or fix a song:** `tools/ace_batch.py` (stdin `name kind id url page`), `--swap name`, `--reimport-all [--jobs N] [names]` (raws in /home/claude/work/ace_raw; re-download by id from ACE_LOG with download_song when missing). Score a take: `tools/ace_pick.py` (seam, holes, late holes = false endings, intro dip, r999 band-limit, low-end share).

## 1. The connection is ready

I checked every step end to end:

- **Account:** Creator plan, 988 credits, refilled with 1,000 on Dec 1. One song costs 4 credits and gives 2 versions, so you have about 247 songs' worth now.
- **Downloads:** fetched "Dreams" as an MP3 (192 kbps, 48 kHz).
- **Into the game:** the new `tools/ace_import.py` turns a download into a game-ready track. It:
  - trims the silence at both ends;
  - sets the loudness so every track plays at the same level (−16 LUFS for music, −14 for jingles);
  - blends the end into the start so the loop has no gap;
  - saves it in the game's sound format (OGG);
  - adds the track to a "real tracks" list, so my placeholder generators never overwrite it;
  - keeps your original download in `audio/incoming/ace/`.

  A test on "Dreams" came out at −15.9 LUFS with a clean loop.
- **Short jingles:** the game now prefers a real `.ogg` sound over the generated placeholder, so ACE jingles drop straight in.
- **Upload minutes:** 30. Uploading a song lets ACE turn its melody into sheet music, which I use to build matching themes (section 4).

**What ACE can and can't do:** it makes music only, and every render is at least 30 seconds long.
- **Music:** all of it comes from ACE.
- **Jingles and stingers** (level up, quest done, heart gained, victory and so on): ACE renders a short piece, then I cut out the best 1–4 seconds.
- **Footsteps, hits, doors, rain and birds:** these aren't music, so ACE can't make them. Section 6 covers them.

---

## 2. What the game has now

- **Music:** 30 tracks. 3 are real (title "Dreams" and the two arc themes); the other 27 are placeholders I generated.
- **Sound effects:** 54 placeholders.
- **Ambience:** 26 placeholder loops (birds, crickets, wind, rain, waves, town chatter and so on).
- **Doubled-up areas:** several areas share a track. For example, the hideout uses Neon's song, uptown uses "danger", and the moon uses "boss". All eight battlefields share one battle track.

---

## 3. How every track is made (same steps each time)

1. **Prompt.** I write a full production brief: genre, tempo, key, instruments and what each one does, the mood and how it builds. I add section tags so the piece has a shape (intro, theme, contrast, return, loop point). Everything is instrumental unless noted, made with ACE Music v1. Area tracks are 2–3 minutes long and built to loop.
2. **Render.** One call gives two versions.
3. **Choose.** I check both versions for length, loudness, clipping, silence and how well the loop joins, and pick one.
   - You hear both on the ACE player in chat and on each song's page.
   - If you prefer the other version, say "swap 12" and I switch it.
4. **Import.** `ace_import.py`, then the full check, then push. The track plays at its spot in the next build.
5. **Log.** Each track's prompt, ID, chosen version and status go into the progress sheet. You'll see an Audio tab there, and the guide lists what's still waiting.

**Batches:** 6 tracks at a time (about 24 credits). After each batch I play the songs here, push, and start the next. Unless you stop me, I keep going until the plan is done.

---

## 4. Themes that tie the game together

The title "Dreams" holds the main melody, and the two arc themes hold each story's melody. I'll upload those three (about 8 of your 30 upload minutes) so ACE turns their melodies into sheet music. Then I use ACE Music v1.1, which plays a melody I give it, to build:

- **The two endings:** each arc's theme, slowed down into a farewell.
- **The final boss tracks:** each arc's theme turned dark and heavy.
- **The title's music box:** a gentle music-box version of "Dreams" for the house and the save screen.
- **Victory jingles:** the opening of each arc's theme.

This way the endings and big moments sound like the same game you started.

---

## 5. Music list (64 pieces, in order)

★ = replaces a placeholder. ◆ = new; I add the code that plays it.

### Wave A — what you hear most (12)

| # | File | Plays | Brief |
|---|---|---|---|
| A1 | farm ★ | farm by day, spring/summer | warm acoustic guitar, wooden flute, light shaker, 92 bpm, D major, sunrise feel, easy loop |
| A2 | farm_fall ◆ | farm in autumn | same feel, cello and harvest fiddle, 88 bpm |
| A3 | winter ★ | farm in winter | sleigh bells, soft piano, celesta, 80 bpm, snowy calm |
| A4 | town ★ | town plaza by day | bouncy accordion, pizzicato strings, tuba bass, 108 bpm, friendly bustle |
| A5 | house ★ | inside your house | soft piano and music box, cosy fireplace, 70 bpm |
| A6 | night ★ | outdoors after sunset | slow celesta, warm pads, soft harp, 60 bpm |
| A7 | rain ★ | rainy days | felt piano, soft strings, gentle pulse, 74 bpm, wistful |
| A8 | mine ★ | mine floors 1–30 | low marimba, dripping echoes, plucked double bass, 84 bpm, curious |
| A9 | mine_deep ◆ | mine floors 31–150 | deeper drones, glass harmonica, slow heartbeat drum, 70 bpm |
| A10 | meadow ★ | meadow and forest edge | woodwinds and glockenspiel, playful, 100 bpm |
| A11 | forest ★ | forest | harp, alto flute, soft frame drum, dappled light, 90 bpm |
| A12 | beach ★ | beach | ukulele, steel pan, soft congas, 110 bpm, sunny |

### Wave B — places (14)

| # | File | Plays | Brief |
|---|---|---|---|
| B1 | lake ★ | lake, riverlands | harp, soft strings, flowing arpeggios, 80 bpm |
| B2 | mountain ★ | mountain, highlands | French horns and strings, open and brave, 96 bpm |
| B3 | quarry ◆ | quarry | low brass, anvil-like percussion, steady work rhythm, 92 bpm |
| B4 | ruins ◆ | ruins | ancient lyre, low choir pad, mysterious, 76 bpm |
| B5 | orchard ◆ | orchard hills | mandolin, fiddle, light hand claps, 104 bpm, golden afternoon |
| B6 | marsh ★ | marsh | misty clarinet, low strings, a little eerie, 68 bpm |
| B7 | jungle ★ | jungle | hand drums, marimba, wooden flute, lush, 106 bpm |
| B8 | wastes ★ | wastes | dusty slide guitar, low drone, lonely, 84 bpm |
| B9 | sky ★ | sky islands, station | airy synth pads, wordless choir, wonder, 80 bpm |
| B10 | moon ◆ | the moon | sparse retro synth arpeggios, gentle space ambience, 72 bpm |
| B11 | cattopia ★ | Cat-topia (penguin arc) | jazzy, purring upright bass, brushed drums, playful, 100 bpm |
| B12 | hollow_heart ★ | the Hollow Heart | glassy bells, deep warm pads, slow heartbeat pulse, 60 bpm |
| B13 | festival ★ | festival days | folk band, fiddle, clapping, 116 bpm |
| B14 | countryside ◆ | countryside (gangster arc) | Americana guitar, harmonica, open road, 96 bpm |

### Wave C — gangster arc (8)

| # | File | Plays | Brief |
|---|---|---|---|
| C1 | hideout ◆ | hideout | lo-fi jazz, warm vinyl crackle, Rhodes, 80 bpm |
| C2 | docks ◆ | docks | noir jazz, upright bass, muted trumpet, foghorn feel, 92 bpm |
| C3 | neon ★ | Neon district | synthwave pulse, jazz sax hook, 112 bpm |
| C4 | uptown ◆ | uptown | sleek big-band brass, confident swing, 118 bpm |
| C5 | underground ◆ | underground | low noir strings, ticking percussion, tension, 88 bpm |
| C6 | raid ◆ | raids, collectors, chases | fast synth bass, snare rolls, sax stabs, 128 bpm |
| C7 | shop_gang ◆ | gang shops and arcade | cheeky lounge jazz, vibraphone, 98 bpm |
| C8 | boss_gang ◆ | lieutenant and President fights | the gangster theme played heavy: brass, strings, driving drums, 138 bpm (v1.1, using the arc theme's melody) |

### Wave D — penguin arc and colonies (8)

| # | File | Plays | Brief |
|---|---|---|---|
| D1 | colony_coral ★ | Coral Reach | island marimba, steel pan, soft "ooh" choir, sunny, 98 bpm |
| D2 | colony_kelp ★ | Kelp Hollow | same melody, deep green: low flutes, soft bass, 86 bpm |
| D3 | colony_ice ★ | Frostfin Isle | same melody, icy: celesta, glass, airy strings, 80 bpm |
| D4 | colony_ember ★ | Emberclaw Atoll | same melody, fiery: taiko, brass, 110 bpm |
| D5 | sanctuary ◆ | penguin sanctuary, pool, shrine | gentle chimes, soft strings, peaceful, 74 bpm |
| D6 | finargle ◆ | finargle prison and lair | sneaky pizzicato, bassoon, playful menace, 96 bpm |
| D7 | boss_penguin ◆ | Grump Commander, Dark Crystal | the penguin theme played dark: choir, low strings, timpani, 132 bpm (v1.1) |
| D8 | merkitty_song ◆ | the merkitty verse scenes (vocal) | soft female choir lullaby, harp and ocean, 72 bpm; original lyrics, all ages |

### Wave E — fights and campaigns (8)

| # | File | Plays | Brief |
|---|---|---|---|
| E1 | battle ★ | battlefields | marching snare, brass, strategic tension, 120 bpm |
| E2 | battle_siege ◆ | siege and defend nodes | slow heavy drums, low brass, 100 bpm |
| E3 | battle_escort ◆ | escort nodes | steady march, light strings, hopeful, 112 bpm |
| E4 | campaign_map ◆ | the campaign board | tactical drums, plucked strings, a map-room feel, 90 bpm |
| E5 | boss ★ | every other boss | driving strings and drums, heroic, 140 bpm |
| E6 | keeper ◆ | mine keepers | stone-heavy percussion, low brass, 126 bpm |
| E7 | marked ◆ | Gift fights with the Marked | eerie bells plus a hero's pulse, 124 bpm |
| E8 | danger ★ | danger zones | tense ostinato strings, 116 bpm |

### Wave F — rooms and moments (8)

| # | File | Plays | Brief |
|---|---|---|---|
| F1 | shop ◆ | general store, smith, other shops | friendly shop jazz, piano and brushes, 100 bpm |
| F2 | inn ◆ | inn, saloon, bakery | warm tavern folk, fiddle and guitar, 104 bpm (no drinking theme) |
| F3 | clinic ◆ | clinic (also where you wake after passing out in the mines) | soft hopeful piano, 72 bpm |
| F4 | chapel ◆ | chapel, library, school | gentle organ pad, harp, 66 bpm |
| F5 | title_musicbox ◆ | save screen and creator | music-box version of "Dreams" (v1.1, using the title's melody) |
| F6 | ending_penguin ◆ | penguin ending slides | the penguin theme slowed down, piano and strings, hopeful, about 3 minutes (v1.1) |
| F7 | ending_gangster ◆ | gangster ending slides | the gangster theme as a slow jazz ballad (v1.1) |
| F8 | credits ◆ | credits and post-game | medley of the title and both arc themes, about 3 minutes |

### Wave G — jingles and stingers (6 renders, cut into 18 short sounds)

| Render | Cut into |
|---|---|
| G1 bright fanfare | levelup, quest_done, skill_learned |
| G2 warm chime | heart_up, gift_loved, birthday |
| G3 discovery | secret_found, journal_page, new_region |
| G4 victory / defeat | battle_won, battle_lost, campaign_won |
| G5 shop and cash | coin (musical), sale_done, shop_bell |
| G6 night and sleep | sleep, morning, festival_start |

**Total for music:** 70 renders. About 280 credits, or about 360 allowing for some do-overs. That leaves well over half your credits for remakes and future content.

---

## 6. Every sound effect and ambience

### 6.1 How ACE covers effects

ACE renders music, not single sound effects. Effects come from four sources:

- **ACE jingles (J):** short musical phrases cut from a render (fanfares, chimes, stingers). These are section 5, wave G.
- **ACE one-shot kits (K):** a render of one instrument playing separate hits with silence between them, for example "solo marimba, single notes, 1 second apart" or "taiko, single hits". `tools/ace_slice_hits.py` (new) cuts each hit at the silences, trims and normalises it, and names it. Every effect that comes from an instrument (UI clicks, magic, crystals, bells, coins, drums, harp sweeps, plucks) can come from ACE this way.
- **Layered synthesis (S):** for noises that no instrument plays, such as footsteps, impacts, water, wood, tools, fire, wind and machines. `tools/make_audio.py` and `make_ambience.py` get rewritten. Each sound is built from noise, filtered body, transients and room reverb, with 3–4 variations and random pitch, so it stops sounding beepy.
- **Recordings (R):** later and optional. You upload free CC0 packs (for example Kenney or Sonniss GDC bundles) to `audio/incoming/sfx/`, and I match each file to its sound. A recording always wins over S.

Every effect gets 3 variations, played at random with a ±8% pitch shift. A new loudness pass sets each group's level: UI −20, footsteps −24, actions −16, combat −14, stingers −12 LUFS. Effects that fire often get a cooldown so they don't stack.

### 6.2 Full list (what exists ✓, what's new ◆, source)

**Movement**
- step_grass ✓, step_dirt ✓, step_sand ✓, step_stone ✓, step_wood ✓, step_snow ✓ (S)
- step_water ◆, step_mud ◆, step_metal ◆, step_carpet ◆, step_crystal ◆, step_moon ◆ (S)
- swim stroke ◆, dive/splash-in ◆ (S); stairs ◆, ladder ◆ (S)
- jump/hop down a ledge ◆ (S), land ◆ (S), dodge roll ◆ (S)
- mount pet ◆, pet run ◆ (S)

**Farm tools and actions**
- hoe: dig ✓, plus till_soft ◆, till_hard ◆ (S)
- watering can: water ✓, plus can_refill ◆, sprinkler ◆ (S)
- plant ✓, harvest ✓, plus crop_ready sparkle ◆ (K glock), scythe ◆, fertilise ◆ (S)
- axe: chop ✓, timber ✓, plus stump ◆, log_split ◆ (S)
- pickaxe: pick ✓, plus ore_hit ◆, gem_ping ◆ (K glass), rock_break ◆ (S)
- seed bag ◆, hay ◆, milk ◆, shear ◆, egg ◆, animal_feed ◆ (S)
- forage pick ◆ (S), bush rustle ◆ (S), berry pop ◆ (S)

**Fishing**
- cast ✓, reel ✓, splash ✓, fish_escape ✓
- bite ✓ becomes a K bell; nibble ◆ (S), hook set ◆ (S), line tension loop ◆ (S), catch fanfare ◆ (J), rare catch ◆ (J)

**Animals and creatures**
- bark ✓, whimper ✓ (pup)
- cat meow ◆, purr loop ◆, chicken ◆, cow ◆, sheep ◆, goat ◆, duck ◆, pig ◆, horse ◆ (S, cartoon-voiced)
- penguin squawk ◆, penguin happy ◆, merkitty chirp ◆, crow caw ◆ (S)
- critter scurry ◆, frog croak ◆, owl ✓ (amb), bee buzz ◆ (S)

**Combat, melee and magic**
- swing ✓, hit ✓, crit ✓, hurt ✓, die ✓, stun ✓, thud ✓
- new swing families ◆: sword whoosh light/heavy, hammer, spear, dagger, fist (S)
- parry/block ◆ (S), shield bash ◆ (S), charge-up loop ◆ (K synth), combo finisher ◆ (S)
- spell ✓, cast ✓, zap ✓, plus separate spell families ◆ (K, synth/harp/bell): fire, ice, water/tide, nature, light, shadow, wind, earth/tremor, heal, buff, debuff, summon, teleport
- status effects ◆: poison bubble, burn crackle, freeze crack, slow, shield up/down, invisible, stink ✓ (S/K)
- enemy families ◆: slime squish, golem stone grind, bat flap, spirit wail (soft), robot servo, gangster grunt (non-graphic), penguin grump (S)
- enemy alert ✓ (alert), enemy aggro sting ◆ (K), boss roar ◆ (S), boss phase change ◆ (J), boss_down ✓ → becomes a J stinger
- heartbeat ✓ (low HP loop), revive ◆ (J)

**Gangster arc weapons (no blood, no graphic violence)**
- shot ✓, plus pistol ◆, smg burst ◆, shotgun ◆, rifle ◆ (S; cartoony, short)
- reload ◆, empty click (dry_click ✓), shell drop ◆ (S)
- ricochet ◆, bullet hits cover ◆ (S), grenade/smoke pop ◆ (S, puff not explosion gore)
- car door ◆, car horn ◆, siren pass ◆, tyres ◆ (S)
- safe dial ◆, lockpick ◆, vault open ◆ (S), alarm loop ◆ (K synth)
- cash register ◆ (K), coin ✓, money bag ◆ (S)

**Cyber and robots**
- hack keys ◆, hack success ◆ (K synth), hack fail ◆, terminal beep ◆ (K)
- emp ◆, scrub ◆, drone loop ◆, bot servo ◆, bot laser ◆ (S/K)
- chrome install ◆ (S)

**Building, crafting, campaigns**
- craft_done ✓ becomes J
- hammer ◆, saw ◆, anvil ◆, forge loop ◆, kiln ◆, loom ◆, cooking sizzle ◆, cooking done ◆ (S/K)
- place furniture ◆, place fence ◆, build complete ◆ (J), demolish ◆ (S)
- campaign: map move ◆, node select ◆ (K drum), battle start horn ◆ (K brass), node won ◆ (J), node lost ◆ (J), supply spent ◆, fortify ◆, barrage ◆, mend ◆, helper deploy ◆ (S/K)
- battle units: march loop ◆, gate break ◆, banner capture ◆ (S/K)

**World objects**
- door ✓, locked ✓, chest_open ✓, crate_break ✓, mail ✓
- gate ◆, window ◆, shop bell ◆ (K), bed ◆ (S), lamp on ◆ (S), campfire loop ◆ (S)
- secret found ◆ (J), buried cache dig-up ◆ (S), journal page ◆ (page; S paper)
- mine: descend shaft ◆, ladder ◆, keeper awakens ◆ (J), cave-in rumble ◆ (S)
- water wheel ◆, windmill ◆, train ◆ (station), rocket launch ◆ (moon pad), teleport pad ◆ (K) (S)
- fireworks ✓, festival games ◆ (K), prize ◆ (J)

**People and story**
- talk_blip ✓, plus one voice blip per character type ◆: kid, elder, gruff, cheerful, penguin, robot, cat. Each comes from a K kit (plucks, woodwind, marimba), pitched per NPC.
- tell ✓, gift given ◆, gift loved/liked/disliked ◆ (J/K), heart up ◆ (J), birthday ◆ (J), wedding bells ◆ (K)
- quest_done ✓ → J, quest new ◆ (J), levelup ✓ → J, skill learned ◆ (J), perk unlocked ◆ (J)
- sleep ✓ → J, morning ◆ (J), pass-out ◆ (S/J), clinic wake ◆ (K)

**Menus and UI**
- ui_tap ✓, menu_open ✓, menu_close ✓, nope ✓, plus equip ◆ (currently uses ui_tap), page ◆ (currently uses pickup)
- tab switch ◆, scroll tick ◆, slider ◆, toggle on/off ◆, confirm ◆, cancel ◆, buy ◆, sell ◆, can't afford ◆, sort bag ◆, stack to chest ◆, bag full ◆, save done ◆ (all K: wood block, marimba, soft bells)
- notification toast ◆, new item ◆, achievement ◆ (K/J)
- hero tab: stat up ◆, gear set complete ◆ (J)

**Weather and time stingers**
- spot_thunder ✓, plus lightning crack ◆, rain start ◆, snow hush ◆, wind gust ◆ (S)
- rooster ✓ (morning), evening bell ◆ (K), festival start ◆ (J)

### 6.3 Ambience beds (loops)

The 26 existing beds ✓ get rebuilt with layered synthesis: birds_dawn, birds_day, crickets, frogs, leaves, wind_soft, wind_strong, rain_light, rain_heavy, rain_roof, waves, water_lap, town_day, city_hum, crowd, cave, lava, crystal_hum, hearth, space, plus spot sounds (bird chirp, drip, owl, penguin chatter, rooster, thunder).

New beds ◆:
- river flow, waterfall, marsh bubbles, jungle insects, desert wind (wastes), snowstorm, sky wind, moon hum
- mine depths (one per tier), docks (gulls, creaks), neon street, underground hum, quarry machines
- shop murmur, inn/saloon chatter (no drinking theme), clinic quiet, chapel echo, school, library
- battlefield distant drums, campaign map-room, colony reef, colony ice, colony ember, sanctuary pool, festival crowd, night farm

**Music-like beds** come from ACE as soft drones and pads with no melody, so they never clash with the area song: crystal_hum, space, moon hum, sanctuary, Hollow Heart, sky.

### 6.4 Code work so every action has a sound

- `Music.sfx` picks a random variation (`name_1..3`) and a pitch, and keeps a per-sound cooldown.
- **Hook pass:** I go through the game's scripts and give every action a sound. Each hook names the closest existing sound as its fallback, so nothing goes silent while new files arrive.
  - Ground types for footsteps come from `GameMap.ground_word`; I add water, mud, metal, carpet and crystal.
  - NPCs get a `voice` (type and pitch) for their talk blips.
- New test `tools/sfx_audit.py`, run by check.sh:
  - every sound name used in the scripts must exist as a file or have a fallback;
  - every file must be used;
  - it prints a coverage table.
- **Count:** about 54 existing effects get rebuilt, and about 190 new ones are added. About 70 of the new ones come from ACE: 18 jingles plus about 50 kit hits from about 10 kit renders.

### 6.5 Extra ACE renders for effects (on top of section 5)

| Kit | Gives |
|---|---|
| K1 marimba and wood block hits | UI clicks, confirm, cancel, scroll, buy and sell |
| K2 glockenspiel and celesta | sparkle, crop ready, gem ping, new item |
| K3 tubular and hand bells | shop bell, bite bell, evening bell, wedding |
| K4 harp sweeps and plucks | heal, buff, water magic, NPC voices |
| K5 synth blips and sweeps | hacking, robots, alarms, teleport, charge-up |
| K6 taiko, toms and snare hits | battle horns and drums, node select, aggro |
| K7 brass stabs | battle start, boss, campaign won |
| K8 glass and crystal tones | ice magic, crystals, freeze |
| K9 low drones and pads | magic families: shadow, earth, light, wind |
| K10 woodwind and plucked voice notes | NPC talk blips by character type |

These add 10 renders (about 40 credits), bringing the whole plan to about 80 renders, or 320–400 credits.

## 7. Phone loading size

Today the music is about 11 MB. 64 real tracks at about 2 MB each would add roughly 120 MB to the first download, which is too much for a phone. So, as part of wave A:

- Music moves out of the main game package into separate files. The game downloads each track the first time you enter an area, then keeps it in the browser's storage.
- The first start stays small, with only the title, farm and house tracks included.
- Tracks are encoded at about 112 kbps stereo, which sounds clean on phone speakers.

I'll measure the package size in the build after each wave.

---

## 8. Music that changes with what you do

Added as each track arrives:

- **Variants:** day, night and rain versions of the farm and town, and season variants. The game picks one by time and weather and crossfades between them over 2 seconds.
- **Fights:** when a fight starts near you, the area track lowers and a short combat layer joins (from E-wave cuts), then fades out when the fight ends.
- **Bosses:** boss music starts on the boss card, and a victory jingle plays on the win.
- **Endings:** the ending slides play their own ending track, and the title returns after the credits.

---

## 9. Order and timing

| Step | What | Credits | Time on my side |
|---|---|---|---|
| 0 | Upload the 3 themes and get their sheet music; set up on-demand music loading | 0 (8 upload min) | 1–2 h |
| 1 | Wave A (12) | ~55 | 1 h |
| 2 | Wave B (14) | ~60 | 1 h |
| 3 | Waves C and D (16) | ~70 | 1.5 h |
| 4 | Waves E and F (16) | ~70 | 1.5 h |
| 5 | Wave G jingles (6, cut into 18) | ~25 | 1 h |
| 6 | Effects: 10 ACE one-shot kits sliced, then about 190 new and 54 rebuilt sounds, then hooking every action, then sfx_audit | ~40 | 4–5 h |
| 6b | Ambience: 26 beds rebuilt, about 26 new, ACE drones | ~10 | 2 h |
| 7 | Music variants and fight layers | 0 | 2 h |

Every wave ends with the full check, bots, a push and an updated Audio tab in the progress sheet.

## C11b creature voices and ranch sound (CONDUCT 11b P6)

Naming rule (c11b_14-01): every new creature voice is `cv_<group>`, never a name an effect already
uses (the planned ostrich "boom" was the firework bang). One shared table: `scripts/ranch_voices.gd`
(VOICES kind -> voice, NIGHT kinds); `GameMap.animal_voice` and `Ambience` read it.

| voice | species | source (local CC0, tools/cc0_import.py MAP) |
|---|---|---|
| cv_ostrich x3 | ostrich, chrome_runner | 80-cc0-creture-sfx-2 misc_10/11/12, pitched 0.7 |
| cv_emu x2 | emu | misc_11/10, pitched 0.85 |
| cv_komodo x2 | komodo, tortoise, ember_newt | 80-cc0-creature-sfx nose + breath (soft snort) |
| cv_moon x3 | moon_cow, moon_hare, star_jelly, star_sheep | alien_02/03/08 |
| cv_merkitty x3 | coral_seahorse, kelp_calf | cute_02/06 + burble_01 |
| cv_gloam x2 | deep_glowworm, glow_gecko, lantern_moth, volt_gecko | insect-sounds insect0/4 |
| cv_frost x2 | aurora_fox, frost_otter, frost_wyrmling | ooh + weird_07 |
| cv_sky x2 | peacock, storm_roc | bird-chirping slices |
| classic | alpaca/cloud_sheep/glow_sheep sheep, buffalo/snow_yak/circuit_cow moo, crystal_hen/chrome_hen cluck, circuit_goat bleat, drone_hog oink, turbo_bunny thump | existing |

Cues (c11b_14-09): egg_crack x3 (7-eating-crunches 2/4/5, pitched 1.3), feeder_fill x2 (workshop
rummaging, low-passed). Still to wire: the morning hatch cue (House.morning_cues / Ranch hatch) and the
feeder add (ranch.json adds[].sfx) when those systems call them.

Beds (c11b_14-04): aviary_room (bird-chirping, -6), terrarium_room (30-cc0-sfx-loops ambient_02 + noise_01,
low-passed); Ambience.HOME_BEDS maps interior ids (aviary, drone_loft, terrarium, grow_tank, enclosure,
bio_dome, lab_barn, star_dome) to room tones. Outdoor positional enclosure beds wait for the buildings.

Pen calls (c11b_14-11): a C11b species with no PEN_SPOTS row calls with its voice (50-110 s, -22 dB);
after dark only NIGHT kinds call (-4 dB), day kinds by day.

Music (c11b_14-05, no new song, no credits): `ranch` = the unused countryside take (so_08dc2510...),
coop/barn/hutch/aviary/terrarium/enclosure interiors; `animal_show` = the unused festival take
(so_2b45c6a9...), played within 5 cells of the fair ribbon stand. Both logged in ACE_LOG with alt_of.
Not yet re-fetched: amb_space / amb_crystal second takes (habitat_moon / habitat_crystal beds),
kit second takes (creature chimes), jin_warm second (j_ranch_up), gang lab pen take.

## C13 P2 songs: outdoor seasons, night/weather, gang valley, hub nights, imports (CONDUCT 13 P2)

Names follow C13_CONTRACT section 3 (all optional at runtime: `Music.resolve` falls back when a file is missing).
Penguin seasonal `<map>_<season>`; gang day `<map>_gang`; gang seasonal `<map>_<season>_gang`; `morning` (dawn);
`storm`/`storm_gang`; `<hub>_night`; second takes and rotation partners as `<name>_2`; re-renders replace the base
file (old take stays in ACE_LOG `previous`, swap back with `tools/ace_batch.py --swap`).

How they were made: ACE v1, 150 s, lyrics = six cue-tagged sections (intro, theme A, theme B, bridge, theme A,
outro "no ritardando, ready to loop"), instrumental. Imported through `ace_import.py` (trim, -16 LUFS phone master,
loop seam). Accept rule: ace_pick score >= 60 and r999 >= 6000 Hz; a re-render only replaced its base when it passed;
a second take became `<name>_2` only at score >= 60.

Finding from this batch (keep for every future calm render): the "hi-fi" phrase does NOT fix muffled renders on
either model (C12's v1.1 re-renders of night/rain/chapel/sanctuary still measured r999 ~1.8-2.6 kHz). What sets the
top end is the arrangement: a piano-, celesta-, harp- or cello-led calm song with no drums comes out band-limited;
the same brief with a fingerpicked/strummed guitar or mandolin and a crisp shaker / brushed hi-hat / tambourine
pulse measures 7-10 kHz. Rain on piano failed twice the r999 gate (1.4 and 2.1 kHz); rain on guitar + shaker passed
(8.4 and 9.2 kHz). Every calm prompt here carries "crisp shaker and brushed hi-hat" and a plucked string lead.

Two takes of one gang valley prompt were split across maps (forest_gang/meadow_gang, lake_gang/mountain_gang,
forest_fall_gang/meadow_fall_gang, forest_winter_gang/meadow_winter_gang) so each valley map has its own song;
countryside/riverlands/highlands fall back through the resolver (P1 maps them to a valley base).

| Song | Kind | ACE id (chosen) | score | r999 Hz | from |
|---|---|---|---|---|---|
| battle_escort_gang_2 | import of unused take | so_64c97c92bb064fc2b918f443 | 75.83 | 10304 | ACE_LOG second take of battle_escort_gang |
| battle_gang_2 | import of unused take | so_cf83d1537fcf4ba8af7e6f67 | 79.54 | 9363 | ACE_LOG second take of battle_gang |
| battle_penguin_2 | import of unused take | so_0217f2f8cb7a49bc9a4ad78d | 89.06 | 9908 | ACE_LOG second take of battle_penguin |
| battle_siege_gang_2 | import of unused take | so_a24de07c94ab43b9a5683208 | 77.32 | 9165 | ACE_LOG second take of battle_siege_gang |
| beach_2 | import of unused take | so_33c672be2032459abfec3f79 | 95.77 | 9584 | ACE_LOG second take of beach |
| beach_fall | new render | so_a9b9952198b44649a9b2f0ea | 94.21 | 7830 | beach_fall |
| beach_fall_2 | new render | so_d766b9b93f4e4da38ee556e9 | 91.97 | 8566 | beach_fall |
| beach_gang | new render | so_f356fef9b93e4430860081e4 | 94.36 | 8851 | beach_gang |
| beach_gang_2 | new render | so_b2cb0e7239ad42d2b39d76a1 | 79.95 | 9739 | beach_gang |
| beach_spring | new render | so_a6cf07b39756472c9906f468 | 94.29 | 9263 | beach_spring |
| beach_spring_2 | new render | so_1f1c6444c27842238559e58b | 92.34 | 8379 | beach_spring |
| campaign_map_gang_2 | import of unused take | so_b7b0059ee5e2471caf0b077e | 81.13 | 9125 | ACE_LOG second take of campaign_map_gang |
| cattopia_2 | import of unused take | so_b502908c48b949dfb1b24747 | 91.05 | 7775 | ACE_LOG second take of cattopia |
| colony_ember_2 | import of unused take | so_b0286c28d4294931a20ca39e | 75.92 | 9911 | ACE_LOG second take of colony_ember |
| combat_elite_2 | import of unused take | so_931840c6750b475a8d6c7d9a | 90.72 | 9685 | ACE_LOG second take of combat_elite |
| combat_elite_gang_2 | import of unused take | so_748b08ebbb4d4a35b455fef9 | 76.41 | 9239 | ACE_LOG second take of combat_elite_gang |
| combat_light_2 | import of unused take | so_e616f10fc7aa422296c138f6 | 91.44 | 9365 | ACE_LOG second take of combat_light |
| combat_light_gang_2 | import of unused take | so_37513ad16ec64be286506818 | 78.63 | 9947 | ACE_LOG second take of combat_light_gang |
| docks_2 | import of unused take | so_a0677377e0ee4f28840516fa | 77.72 | 7119 | ACE_LOG second take of docks |
| farm_fall_gang | new render | so_3041c6263181412bab9cbf57 | 97.17 | 9841 | farm_fall_gang |
| farm_fall_gang_2 | new render | so_f9299b764d6641e49ac31555 | 81.4 | 9395 | farm_fall_gang |
| farm_gang | new render | so_2b53b177fd704d7ea7334538 | 97.37 | 8715 | farm_gang |
| farm_gang_2 | new render | so_18df151f3686476b96afced0 | 91.4 | 8737 | farm_gang |
| farm_summer | new render | so_055c1168afa746e080e430da | 87.73 | 9603 | farm_summer |
| farm_winter_gang | new render | so_0016b94948ee4ec181b22d75 | 74.92 | 7633 | farm_winter_gang |
| festival_night_2 | import of unused take | so_64d77828112c4bc4a1d5767d | 85.33 | 8401 | ACE_LOG second take of festival_night |
| finargle_2 | import of unused take | so_fc0d26604eae4f67a92a0b45 | 81.66 | 8360 | ACE_LOG second take of finargle |
| forest | re-render | so_a0c5fc98b3fd4c27a5aabe24 | 89.5 | 8358 | forest(rerender) |
| forest_fall_gang | new render | so_c1dd4bac48c5488cb2673322 | 93.47 | 8929 | valley_fall_gang |
| forest_gang | new render | so_7f4d8088b9fd449eb61de722 | 81.86 | 9634 | valley_gang |
| forest_winter_gang | new render | so_f32323d4a60b49f58839c2d5 | 94.6 | 7001 | valley_winter_gang |
| hideout | re-render | so_416f5478cf0042f2a6190801 | 76.43 | 8106 | hideout(retry,cool jazz) |
| house_2 | import of unused take | so_8b5dfc56175945479e5b0add | 82.4 | 8555 | ACE_LOG second take of house |
| inn_2 | import of unused take | so_abddc00e18cd4952833a1db1 | 85.76 | 9432 | ACE_LOG second take of inn |
| lake | re-render | so_7b1abfa3314746fd96aeebcd | 74.03 | 6583 | lake(rerender) |
| lake_fall | new render | so_c92822a13a454b54a61c5f69 | 83.73 | 7290 | lake_fall(retry,guitar) |
| lake_fall_2 | new render | so_e69e87c59e7941ecbe668337 | 80.42 | 8541 | lake_fall(retry,guitar) |
| lake_gang | new render | so_6957b910cf56407082a0daf8 | 91.06 | 8629 | valley_gang_2 |
| lake_winter | new render | so_c4b1fc3019ea440c920b1fd8 | 86.82 | 8484 | lake_winter |
| marsh | re-render | so_ec9f8a85a292442a9d5a8555 | 91.64 | 9273 | marsh(rerender) |
| marsh_2 | new render | so_8ac4fb59bc284eab9da4d60b | 90.6 | 7834 | marsh(rerender) |
| meadow_2 | import of unused take | so_b9914927cd834d459fc6455c | 88.49 | 9592 | ACE_LOG second take of meadow |
| meadow_fall | new render | so_89fde07a117f433d8a500f5b | 93.35 | 8266 | meadow_fall |
| meadow_fall_2 | new render | so_f6ec74de03c74492816ed56e | 87.61 | 8275 | meadow_fall |
| meadow_fall_gang | new render | so_254acc01f98c4abb8060434f | 77.55 | 9800 | valley_fall_gang |
| meadow_gang | new render | so_b4a35532bffe4c85ade0cc7f | 73.45 | 9122 | valley_gang |
| meadow_winter | new render | so_041ea613d76a421dabb022bc | 92.91 | 9283 | meadow_winter |
| meadow_winter_2 | new render | so_359f3e03f71e445ca02fb483 | 91.55 | 6962 | meadow_winter |
| meadow_winter_gang | new render | so_f6f50fd5923145ad97025035 | 81.43 | 8982 | valley_winter_gang |
| mega_desert_2 | import of unused take | so_064380943990443781c0153d | 84.21 | 9473 | ACE_LOG second take of mega_desert |
| mega_desert_canyon_2 | import of unused take | so_78f15a8b872b4fb1ba0ddec8 | 95.41 | 9000 | ACE_LOG second take of mega_desert_canyon |
| mega_gilt_2 | import of unused take | so_ed8c7d6ad6d249cab4cfa488 | 76.5 | 6589 | ACE_LOG second take of mega_gilt |
| mega_gloam | re-render | so_7b51e3a1f2484a3ba02638f7 | 72.03 | 6841 | mega_gloam(rerender) |
| mega_hollow_deeps | re-render | so_b7b88e9c4e3041bb90b900db | 85.01 | 8417 | mega_hollow_deeps(rerender) |
| mega_hollow_deeps_2 | new render | so_379983798f3748b4a01f1915 | 76.42 | 8952 | mega_hollow_deeps(rerender) |
| mega_iron_2 | import of unused take | so_f82aa988f1e547639a094ad8 | 89.42 | 9326 | ACE_LOG second take of mega_iron |
| mega_station_2 | import of unused take | so_603e8dcb11144ee19796ccbb | 83.05 | 10064 | ACE_LOG second take of mega_station |
| mega_wind_2 | import of unused take | so_4001713a3c9341728f396c1e | 89.02 | 9430 | ACE_LOG second take of mega_wind |
| morning | new render | so_c12601f0fc3349839ffcd9db | 73.21 | 9044 | morning |
| mountain_fall | new render | so_f4403252b7014ba49e77ce1e | 88.57 | 8767 | mountain_fall |
| mountain_fall_2 | new render | so_6c19bdadfd5343958daa60b3 | 71.02 | 9839 | mountain_fall |
| mountain_gang | new render | so_277648162bfe41748ec237d5 | 71.85 | 9261 | valley_gang_2 |
| mountain_winter | new render | so_37516c9ef06d46b186eb666d | 65.5 | 10294 | mountain_winter |
| neon_2 | import of unused take | so_4edc36b94cf14541afc54ef7 | 79.06 | 10086 | ACE_LOG second take of neon |
| neon_night | new render | so_6685f7569d944294ad4abe69 | 62.3 | 10293 | neon_night |
| night | re-render | so_32d4cb3ae0824f2eb0b54f96 | 61.74 | 8416 | night(rerender) |
| night_gang | re-render | so_3255160d23d0415e97348616 | 71.53 | 8045 | night_gang(rerender) |
| night_summer | new render | so_2355895065f0455e866a43b1 | 90.74 | 7311 | night_summer |
| night_winter | new render | so_88ea22291d084405a8b32bd3 | 69.65 | 7892 | night_winter |
| night_winter_2 | new render | so_99bca08abd184db494568d11 | 64.32 | 8154 | night_winter |
| night_winter_gang | new render | so_5456989509a3495284c5d7cc | 88.51 | 7635 | night_winter_gang |
| night_winter_gang_2 | new render | so_2de22007982342b2b047952b | 83.78 | 6917 | night_winter_gang |
| orchard_2 | import of unused take | so_f2032f939c1a43db84c4f836 | 94.96 | 9125 | ACE_LOG second take of orchard |
| outskirts_2 | import of unused take | so_e91016b2d0be49aeb60203a4 | 73.34 | 9696 | ACE_LOG second take of outskirts |
| outskirts_night | new render | so_3d9795b881c14168a3e2f98d | 77.98 | 10220 | outskirts_night |
| outskirts_night_2 | new render | so_1145cf3dea054f6a96961823 | 67.27 | 9381 | outskirts_night |
| quarry_2 | import of unused take | so_4e62e5b1cef84fd6b90cf7ea | 77.0 | 9540 | ACE_LOG second take of quarry |
| raid_2 | import of unused take | so_106bd2c3dea9439dbba24201 | 76.76 | 10212 | ACE_LOG second take of raid |
| rain | re-render | so_9a3504eb701640afbb2df7cb | 87.85 | 8363 | rain(retry,guitar) |
| rain_2 | new render | so_fbfa8dfef4a649af9aef4af9 | 77.98 | 9155 | rain(retry,guitar) |
| rain_gang | new render | so_3b7550df261e42b3ab66475d | 75.18 | 8914 | rain_gang |
| sanctuary | re-render | so_9bdf63fc83b443868d8697b1 | 86.9 | 6353 | sanctuary(rerender) |
| shop_2 | import of unused take | so_dc4053df76b44890a02a0463 | 77.46 | 7226 | ACE_LOG second take of shop |
| shop_gang_2 | import of unused take | so_8650580e16b04317bdbb404a | 77.92 | 9306 | ACE_LOG second take of shop_gang |
| sky | re-render | so_68a8b3a3688943a8847552dc | 91.02 | 9594 | sky(retry,guitar) |
| sky_2 | new render | so_e4e54ec07bb3412dbec9be8f | 77.72 | 9496 | sky(retry,guitar) |
| storm | new render | so_03cffc0d0ec04c9cbb7e88ba | 76.85 | 7651 | storm |
| storm_2 | new render | so_8b22b8c16604472094d73098 | 68.98 | 7469 | storm |
| storm_gang | new render | so_a340a460dc2148ada475dc61 | 71.54 | 9189 | storm_gang |
| storm_gang_2 | new render | so_e1e43770284b4d41900788d0 | 69.92 | 9345 | storm_gang |
| town | re-render | so_48d4ab28e17e4fc398dbe18f | 92.34 |  | ACE_LOG second take of town |
| town_2 | import of unused take | so_0b8240c213be46339e892860 | 70.3 | 4008 | ACE_LOG second take of town |
| town_fall | new render | so_d5c9d2a697334a699c6aa9e8 | 89.27 | 8295 | town_fall |
| town_fall_2 | new render | so_8d32f3d613844ae9a3456099 | 86.92 | 8228 | town_fall |
| town_gang | new render | so_95285d538bdc4f348d4b002b | 79.56 | 9059 | town_gang |
| town_gang_2 | new render | so_ed684e4dc97b44baa92c3176 | 73.41 | 10165 | town_gang |
| town_winter | new render | so_1231d87a7d5e435da7d2e39a | 81.49 | 10384 | town_winter |
| town_winter_2 | new render | so_3378af41951e4bcaba57d64c | 76.63 | 9916 | town_winter |
| town_winter_gang | new render | so_cc53979c3ead4e80b23f86f6 | 69.99 | 9058 | town_winter_gang |
| uptown_night | new render | so_b781ed67f44f435b9366c0ab | 62.27 | 9319 | uptown_night |
| wastes | re-render | so_e8a3db03bea44a5f820371a5 | 87.18 | 8344 | wastes(rerender) |
| winter_gang | new render | so_4583c00e54e842498903c5c0 | 68.98 | 8640 | farm_winter_gang |

Not shipped (failed the accept rule; raw takes stay in /home/claude/work/ace_raw, ids in the C13 P2 fix report):
hideout_night (28/21), beach_winter (44/34, r999 1.3-2.0 kHz), forest_winter (50/14, clarinet lead, r999 1.8 kHz),
docks_night (59.1), forest_fall (58.3), orchard_winter (54.0), lake_winter_2 (r999 4190), mega_frost_caverns and
mega_frost_summit re-renders (both takes failed: base songs kept), the winter / lake / mega_frost / wastes / jungle
unused takes (muffled or < 75), countryside/festival second takes (already shipped as ranch / animal_show).
town: the unused take (so_48d4ab28..., score 92.3, r999 6886) is now the town song; the old one is town_2.
Still to render (after the Dec 1 refill): hideout_night, beach_winter, forest_winter, orchard_winter, docks_night,
forest_fall, farm_spring, town_summer, orchard_spring, mega hub nights (c13_13-10), mega gang variants (c13_13-24),
town_after / town_gang_after (P3 owns town_after), chapel / clinic re-renders (interiors).

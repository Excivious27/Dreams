# Dreams — Audio plan through ACE Music

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

# CONDUCT 13 contract (fixed before launch; every package codes against it)

## 1. Song resolver (P1 builds; everyone relies on it)
`Music.resolve(base: String, ctx := {}) -> String` returns the most specific EXISTING track (Music.has_track) for a base name. ctx keys (all optional; defaults read from GameState): arc ("penguins"/"gangsters"), season ("spring"/"summer"/"fall"/"winter"), phase ("dawn"/"day"/"night"), weather ("clear"/"rain"/"storm"/"snow"), stage (int, GameState.story_stage()), weekday (0-6).
Candidate order, first existing wins:
  1. `<base>_after` when stage >= epilogue (flags.epilogue_done)
  2. `<base>_<weather>` for rain/storm/snow (storm falls back to rain), then the shared `rain`/`storm`/`snow` (gang: `rain_gang`...) only for maps that used them before
  3. `<base>_night` / `<base>_dawn` by phase, then the existing shared night (`night`, `night_gang`) only where it played before
  4. `<base>_<season>`
  5. `<base>`
  Each step tries the arc variant first: gang arc tries `<name>_gang` before `<name>`; penguin arc never plays a `_gang` file and the gang arc never plays a penguin pastoral base when a `_gang` sibling exists at ANY step (fall through to the next gang candidate first).
  Rotation: when `<pick>_2`, `<pick>_3` exist, choose by (day_of_year + weekday) % count, stable for the whole in-game day.
`Music.play_area(base)` = play(resolve(base)). GameMap.area_track keeps its per-map base picks and calls resolve at the end.
Season/time/weather names exactly: spring summer fall winter / dawn night / rain storm snow. Suffix order when combined: `<base>_<season>_night` is NOT used (keep files to single suffixes + _gang + _2/_3).

## 2. New APIs
- `GameState.weekday() -> int` (0 = first day of the week, from GameState.day), `GameState.day_name() -> String` ("Mon".."Sun"). P1.
- `GameState.story_stage() -> int` (0..N chapters, epilogue = 99). P1.
- `Music.sfx_log` (Array, last 64 entries {asked, played, fallback(bool), arc_swap(bool), dropped(bool)}) + `Music.clear_sfx_log()`. Added by P1 inside Music.sfx; P5/P6 tests read it.
- `Music.sfx` arc swap: if arc is gangsters and `<name>_gang` exists, play it (P1 adds; P3 makes the files).
- `Music.sfx` mix rules follow the PLAYED name, not the asked one (12-27/14-16). P1.
- Jingle duck: duck only while the jingle is audible (trim to the file's non-silent length, P3 provides lengths via tools/sfx_soften.py writing data/sfx_meta.json {name: {len_audible}}); no duck when the SFX bus is muted; one jingle at a time (a second musical sting within 2.5 s is queued or dropped by priority: achievement > levelup > quest_done > heart > others). P1 implements in music.gd, reading data/sfx_meta.json if present.
- `Music.mood(name)` plays `mood_<name>` (resolve applies the arc suffix) held for a scene and returns to the area song after; story/hearts/events call it (P4). Names: mood_sad, mood_tense, mood_mystery, mood_triumph, mood_comic, mood_tender (+ _gang files).
- `Captions.say(text, kind)` (new scripts/captions.gd, P6) shows a short caption when Settings.captions is on; Music.sfx calls `Captions.for_sfx(name)` (P6 adds a one-line hook in music.gd's sfx and a table of captionable names).
- Settings (P6): `Settings.mono`, `Settings.reduce_loud`, `Settings.captions`, extra bus volumes `Voices`, `UI`, `Steps` (buses created in default_bus_layout or code by P6; Music.sfx routes by group: P6 gives P1 the group->bus table in data/sfx_buses.json, P1 reads it).

## 3. Song names (create exactly these; all optional at runtime)
P2 songs (outdoor): penguin seasonal `<map>_<season>` for farm town beach forest meadow lake mountain orchard countryside; gang day `<map>_gang` for farm town beach forest lake meadow mountain countryside; gang seasonal `<map>_<season>_gang` (resolver tries the _gang sibling of each candidate); `morning` (penguin dawn, shared) and `<map>_dawn` where made; extra night/rain rotation as `night_2`, `rain_2`; `storm`, `storm_gang`; `<hub>_night` for uptown docks hideout outskirts neon and the mega hubs; imports of second takes as `<name>_2`; re-renders replace the base file (rm first, then write).
P3 songs: `casino` (+`casino_gang` is the default floor: the casino is gang-styled → `casino` only), `museum`, `library`, `workshop`, `bakery`, `house_gang`, `inn_gang`, crew venues `deuce_arcade`, `trading_post`, `net_cafe`; festivals `festival_egg festival_lantern festival_harvest festival_star` (+`_night` optional); moods (section 2); `boss_dark_crystal`, `boss_president`; `danger_gang`; `date_evening` re-render + `date_evening_gang`; `arcade_stack arcade_whack arcade_gallery`; `keeper_2` (free take, deep tiers); `farm_after` `town_after`.
Jingles (P3): `ach_unlock`, `j_casino_small`, `j_casino_big`, gang set `j_<x>_gang` for every existing j_* jingle + levelup/quest_done.
SFX names P5 delivers (casino/arcade call sites in P4 use these): card_deal, card_flip, chip_clack, roulette_spin, roulette_ball, slot_spin, slot_stop, target_tin, claw_move, claw_drop, skee_roll, ticket_out, cabinet_coin; steps step_carpet step_metal step_ice step_wood; vehicle: scooter_ride, motor_loop, sled_snow; ranch: milk, shear, egg_collect; howl_far (story distant howl), knockout, swim; creature voices cv_merkitty, cv_crystal_baby, baby_<species> as RanchVoice words.

## 4. Hooks owners must leave for others (one or two lines)
- game_map.gd (P1 owns): P4 may add the festival/boss/story one-liners it needs; P5 may move impact sfx timing calls; P6 may add join/leave cue calls. Keep each hook at most 2 lines and name the package in a comment-free commit message.
- music.gd (P1 owns): P6 adds the Captions hook (1 line) and bus routing read; nobody else edits it.
- game_state.gd (P1 owns the two APIs): P6 may add the energy-warning sfx line, P4 the new-quest sound unification line.
- farm.gd (P5 owns): P4 may add the opening-cutscene music line.
- house.gd (P6 owns): P5 may add chore/crow sound lines.

## 5. Rules
- Tests: deterministic, game time, --fixed-fps 60; new test blocks in tools/check.sh each self-contained with a blank line before and after (append at the END of check.sh to ease merging).
- Data with a generator: edit the generator, then bash tools/regen_data.sh.
- Audio files: never modify an existing file under audio/ in place (rm first, then write; files are hardlinked).
- No family/staff names; all ages; gang arc serious/cool, penguin arc whimsical.
- Notes between packages: append to /home/claude/wt/c13f_reports/NOTES.md ("P3 -> P2: ...").

# CONDUCT 15 contract (seasons)

## 1. Festival rows (P6 owns data/festivals.json via tools/gen_festivals.py)
Row: {id, season ("spring"|"summer"|"fall"|"winter"), day (1-28), kind ("festival"|"holiday"|"marina"), arc ("both"|"penguins"|"gangsters"), name, name_gang, venue {scene, cell}, hours ("day" 9-18 | "evening" sunset-4..sunset+3.5 | "night" sunset..sunset+4 | "allday"), closes_shops (bool), year_min (1), every (1; 3 = years 3,6,...), weather (optional forced weather id), host, host_gang, handler (town.gd match id), stall ("festival_<id>"), prize_pool ("festival_<id>_prize"), music ("festival_<id>"), needs {marina_tier, flag}}.
The four existing festivals keep their ids (egg, lantern, harvest, star) and day 14 unless P6 moves them; any move must keep saves working (P1 migration if needed).

## 2. Calendar API (P1 builds scripts/calendar.gd, class_name Calendar, static)
- `Calendar.events_on(season: String, day: int, year := -1, arc := "") -> Array[Dictionary]` merges festivals.json rows (P6), calendar.json rows (P1: markets, small events, holidays P6 doesn't own), birthdays (GameState.birthday_of / npcs), marina events (Marina rows), filtered by arc, year_min/every and needs. Each entry {id, name, kind, icon, where, hours, line}.
- `Calendar.festival_today() -> Dictionary` (empty if none) and `Calendar.is_festival_hour(h)`; `GameState.festival_today()` keeps its old signature and delegates to Calendar (P1). `Npc.festival_hours()/in_festival(h)` (C14) delegate to Calendar.
- `Calendar.season_days() -> 28`, `Calendar.year() -> int` (1-based), `Calendar.day_of_year()`.
- `Calendar.eve(id) -> bool` true the day before an event (mail eve letters, P3).
- Calendar screen (P1): opened from the town board (first choice), a Menu entry and a tap on the HUD date box; 7x4 grid, L/R pages seasons, both arcs, way out last.

## 3. Ownership
- game_state.gd: P1 only (others: 1-2 line hooks with a note). town.gd: P6 (festivals) + P1 board-entry hook line. world_gen.gd: P2 forage functions / P4 critter functions only. gen_mega_new.py/regions.json: P4. game_map.gd: P5 small seasonal hooks only. npc.gd/talk/mail/events: P3. shops/farm/items generators: P2. music_resolve/ambience/scenery/interior seasonal: P5.
- tools/regen_data.sh: P1 (gen_calendar) and P6 (gen_festivals) append one line each near the end; gen_festivals must run before gen_calendar if P1 reads festivals at generation time (prefer reading at runtime).
- tools/check.sh: new blocks appended at the END with an `echo "== ... =="` header.
- art/gen/manifest.json: each slicer appends (json_merge). Ids prefixed c15<pk>_.

## 4. Budgets
dreams-image today ~470 left: P1 20, P2 120, P3 20, P4 80, P5 150, P6 80. ACE: none (64 credits until Dec 1); new festival songs go to docs/ART-QUEUE.md "audio after Dec 1" and map to existing songs meanwhile (festival, festival_night, mood_*, existing festival_<id>).

## 5. Rules
Deterministic tests (game time, --fixed-fps 60, seed). Saves: new run blocks -> GameState.RUN_BLOCKS + SAVE_VERSION bump + _migrate (P1 only; others ask P1 in NOTES.md). All ages (fall "haunted" events: friendly lantern/costume tone); alcohol trade-only; no animal deaths; no family/staff names. Both arcs everywhere. Notes: /home/claude/wt/c15f_reports/NOTES.md.

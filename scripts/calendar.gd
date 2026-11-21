class_name Calendar
extends RefCounted
## C15 P1: the one calendar. Every festival, holiday, small event, market, marina
## evening and birthday comes from here (C15 contract section 2):
##   data/festivals.json  (P6, tools/gen_festivals.py): festivals + holidays + marina rows
##   data/calendar.json   (P1, tools/gen_calendar.py): markets, small events, holidays P6 doesn't own
##   data/npcs.json birthdays, data/marina.json "festival" rows with a day.
## Rows: {id, season, day, kind, arc, name, name_gang, venue{scene,cell}, hours, closes_shops,
##        year_min, every, weather, needs{marina_tier, flag}, line, line_gang, icon}.
## Without festivals.json the four classic day-14 festivals stand in (FALLBACK).
## GameState.festival_today() / Npc.festival_hours() delegate here.

const SEASON_DAYS := 28
const YEAR_DAYS := 112
const SEASONS := ["spring", "summer", "fall", "winter"]

## The classic four (C14), used only when data/festivals.json is missing.
const FALLBACK := [
	{"id": "egg", "season": "spring", "day": 14, "kind": "festival", "arc": "both", "name": "Egg Festival", "name_gang": "Block Party Egg Run", "venue": {"scene": "town"}, "hours": "day", "closes_shops": true, "icon": "egg", "weather": "petals", "line": "Egg hunt on the plaza, nine till six.", "line_gang": "Block party on the plaza: hunt the painted eggs, nine till six."},
	{"id": "lantern", "season": "summer", "day": 14, "kind": "festival", "arc": "both", "name": "Lantern Festival", "name_gang": "Neon Lantern Night", "venue": {"scene": "town"}, "hours": "evening", "closes_shops": true, "icon": "lantern", "weather": "fireflies", "line": "Lanterns on the plaza from late afternoon into the night.", "line_gang": "Neon lanterns over the plaza from late afternoon into the night."},
	{"id": "harvest", "season": "fall", "day": 14, "kind": "festival", "arc": "both", "name": "Harvest Fair", "name_gang": "Harvest Hustle Market", "venue": {"scene": "town"}, "hours": "day", "closes_shops": true, "icon": "wheat", "weather": "leaves", "line": "Harvest Fair on the plaza: bring your best crop.", "line_gang": "Hustle market on the plaza: bring your best crop."},
	{"id": "star", "season": "winter", "day": 14, "kind": "festival", "arc": "both", "name": "Star Festival", "name_gang": "Midwinter Gift Swap", "venue": {"scene": "town"}, "hours": "evening", "closes_shops": true, "icon": "star", "weather": "snow", "line": "Star Festival: the gift swap under the big tree.", "line_gang": "Midwinter Gift Swap: black-and-gold boxes under the neon star."},
]

## Icon names (index into the c15p1 calendar icon sheet, fallback to a drawn glyph).
const ICONS := ["egg", "lantern", "wheat", "star", "cake", "fish", "boat", "flower", "firework", "snow", "pumpkin", "kite", "moon", "market", "music", "face"]
const KIND_ICON := {"festival": "star", "holiday": "firework", "event": "music", "market": "market", "marina": "boat", "birthday": "cake", "weather": "moon"}

static var _fest: Array = []
static var _cal: Array = []
static var _loaded := false
static var _memo := {}


static func reload() -> void:
	_loaded = false
	_memo.clear()


static func _rows_of(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var out: Array = []
	if d is Array:
		out = d
	elif d is Dictionary:
		if (d as Dictionary).has("rows"):
			out = d["rows"]
		elif (d as Dictionary).has("festivals"):
			out = d["festivals"]
		else:
			for k in d:
				if d[k] is Dictionary:
					var r: Dictionary = (d[k] as Dictionary).duplicate()
					r["id"] = str(r.get("id", k))
					out.append(r)
	var ok: Array = []
	for r in out:
		if r is Dictionary and str(r.get("season", "")) in SEASONS and int(r.get("day", 0)) >= 1:
			ok.append(r)
	return ok


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_fest = _rows_of("res://data/festivals.json")
	if _fest.is_empty():
		_fest = FALLBACK.duplicate(true)
	_cal = _rows_of("res://data/calendar.json")


## Festival/holiday/marina rows (P6 data or the classic four).
static func festival_rows() -> Array:
	_load()
	return _fest


static func calendar_rows() -> Array:
	_load()
	return _cal


static func has_festival_data() -> bool:
	return FileAccess.file_exists("res://data/festivals.json")


# ---- dates ---------------------------------------------------------------------

static func season_days() -> int:
	return SEASON_DAYS


static func _today() -> int:
	return int(GameState.run.get("day", 1)) if not GameState.run.is_empty() else 1


## 1-based year of a save day (default today). Days 1..112 are year 1.
static func year(day := -1) -> int:
	if day < 1:
		day = _today()
	return (day - 1) / YEAR_DAYS + 1


static func day_of_year(day := -1) -> int:
	if day < 1:
		day = _today()
	return (day - 1) % YEAR_DAYS + 1


static func season_of(day: int) -> String:
	return SEASONS[((day - 1) / SEASON_DAYS) % 4]


static func dos_of(day: int) -> int:
	return (day - 1) % SEASON_DAYS + 1


## Absolute save day for a season/day in a year.
static func abs_day(season: String, dos: int, yr: int) -> int:
	return (yr - 1) * YEAR_DAYS + maxi(0, SEASONS.find(season)) * SEASON_DAYS + dos


static func arc() -> String:
	if GameState.run.is_empty():
		return "penguins"
	return "penguins" if GameState.is_penguins() else "gangsters"


static func short_season(se: String) -> String:
	return {"spring": "Spr", "summer": "Sum", "fall": "Fal", "winter": "Win"}.get(se, se.capitalize())


# ---- rows ----------------------------------------------------------------------

## Does this row happen in that year/arc (year_min, every, needs)?
static func row_ok(r: Dictionary, yr: int, ar: String) -> bool:
	var ra := str(r.get("arc", "both"))
	if ra != "both" and ra != ar:
		return false
	if yr < int(r.get("year_min", 1)):
		return false
	var ev := int(r.get("every", 1))
	if ev > 1 and yr % ev != 0:
		return false
	var nd: Dictionary = r.get("needs", {}) if r.get("needs", {}) is Dictionary else {}
	if int(nd.get("marina_tier", 0)) > 0:
		if GameState.run.is_empty() or Marina.tier() < int(nd["marina_tier"]):
			return false
	if str(nd.get("flag", "")) != "":
		if GameState.run.is_empty() or not (GameState.run.get("flags", {}) as Dictionary).has(str(nd["flag"])):
			return false
	return true


## Hours of a row as Vector2(start, end) in game hours; ZERO = all day / no hours.
static func row_hours(r: Dictionary) -> Vector2:
	var h: Variant = r.get("hours", "day")
	if h is Array and (h as Array).size() == 2:
		return Vector2(float(h[0]), float(h[1]))
	var ss := GameState.sunset() / 60.0
	match str(h):
		"day": return Vector2(9.0, 18.0)
		"evening": return Vector2(ss - 4.0, minf(23.5, ss + 3.5))
		"night": return Vector2(ss, minf(23.9, ss + 4.0))
		"morning": return Vector2(6.0, 12.0)
	return Vector2.ZERO


static func hours_text(hv: Vector2) -> String:
	if hv == Vector2.ZERO:
		return "all day"
	return "%s-%s" % [GameState.clock_of(int(hv.x * 60.0)), GameState.clock_of(int(hv.y * 60.0))]


static func _where(r: Dictionary) -> String:
	if r.has("where"):
		return str(r["where"])
	var v: Variant = r.get("venue", {})
	var sc := str((v as Dictionary).get("scene", "")) if v is Dictionary else str(v)
	return {"town": "plaza", "beach": "pier", "": "town", "farm": "your farm", "commons": "Commons", "rec_center": "Rec Center", "mail": "by mail"}.get(sc, sc.replace("_", " "))


static func _entry(r: Dictionary, ar: String) -> Dictionary:
	var gang := ar == "gangsters"
	var nm := str(r.get("name_gang", "")) if gang and str(r.get("name_gang", "")) != "" else str(r.get("name", str(r.get("id", "")).capitalize()))
	var ln := str(r.get("line_gang", "")) if gang and str(r.get("line_gang", "")) != "" else str(r.get("line", ""))
	var kind := str(r.get("kind", "event"))
	var hv := row_hours(r)
	return {"id": str(r.get("id", "")), "name": nm, "kind": kind, "icon": str(r.get("icon", KIND_ICON.get(kind, "star"))),
		"where": _where(r), "hours": hv, "time": hours_text(hv), "line": ln, "season": str(r.get("season", "")), "day": int(r.get("day", 0)),
		"closes_shops": bool(r.get("closes_shops", kind == "festival")), "row": r}


static func _birthdays(season: String, day: int) -> Array:
	var out: Array = []
	for id: String in GameState.npcs:
		var b: Array = GameState.npcs[id].get("birthday", [])
		if b.size() == 2 and str(b[0]) == season and int(b[1]) == day:
			var nm := str(GameState.npcs[id].get("name", id.capitalize()))
			out.append({"id": "bday_" + id, "npc": id, "name": "%s's birthday" % nm, "kind": "birthday", "icon": "cake",
				"where": "", "hours": Vector2.ZERO, "time": "all day", "line": "It's %s's birthday: a gift today counts triple." % nm,
				"season": season, "day": day, "closes_shops": false, "met": not GameState.run.is_empty() and (GameState.run.get("friendship", {}) as Dictionary).has(id)})
	return out


## Marina rows from data/marina.json that carry a day (skipped when festivals.json has the id).
static func _marina_rows(seen: Dictionary) -> Array:
	var out: Array = []
	var fest: Dictionary = Marina.data().get("festival", {})
	for k: String in fest:
		var f: Dictionary = fest[k]
		if not f.has("day") or seen.has(k):
			continue
		var r := f.duplicate()
		r["id"] = k
		r["kind"] = "marina"
		r["venue"] = {"scene": "beach"}
		r["needs"] = {"marina_tier": int(f.get("tier", 1))}
		if not r.has("hours") or r["hours"] is Array and (r["hours"] as Array).is_empty():
			r["hours"] = "day"
		r["icon"] = "fish" if k == "derby" else "boat"
		out.append(r)
	return out


static func _all_rows() -> Array:
	_load()
	var seen := {}
	var rows: Array = []
	for r in _fest:
		seen[str(r.get("id", ""))] = true
		rows.append(r)
	for r in _cal:
		if not seen.has(str(r.get("id", ""))):
			rows.append(r)
	rows.append_array(_marina_rows(seen))
	return rows


## Everything on a season/day, in display order (festivals, holidays, marina, events,
## markets, birthdays). year -1 = this year, arc "" = this save's arc.
static func events_on(season: String, day: int, yr := -1, ar := "") -> Array:
	if yr < 1:
		yr = year()
	if ar == "":
		ar = arc()
	var out: Array = []
	for r: Dictionary in _all_rows():
		if str(r.get("season", "")) == season and int(r.get("day", 0)) == day and row_ok(r, yr, ar):
			out.append(_entry(r, ar))
	var order := {"festival": 0, "holiday": 1, "marina": 2, "event": 3, "market": 4}
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(order.get(a["kind"], 5)) < int(order.get(b["kind"], 5)))
	out.append_array(_birthdays(season, day))
	return out


## The plaza festival on a season/day ({} if none). Only kind "festival".
static func festival_on(season: String, day: int, yr := -1, ar := "") -> Dictionary:
	if yr < 1:
		yr = year()
	if ar == "":
		ar = arc()
	var key := "%s:%d:%d:%s:%d" % [season, day, yr, ar, Marina.tier() if not GameState.run.is_empty() else 0]
	if _memo.has(key):
		return _memo[key]
	var hit := {}
	for r: Dictionary in festival_rows():
		if str(r.get("kind", "festival")) == "festival" and str(r.get("season", "")) == season and int(r.get("day", 0)) == day and row_ok(r, yr, ar):
			hit = _entry(r, ar)
			break
	if _memo.size() > 256:
		_memo.clear()
	_memo[key] = hit
	return hit


## The festival on a save day ({} if none).
static func festival_for_day(d: int) -> Dictionary:
	return festival_on(season_of(d), dos_of(d), year(d))


static func festival_today() -> Dictionary:
	return festival_for_day(_today())


static func festival_id_today() -> String:
	return str(festival_today().get("id", ""))


## Hours of a festival (by id; "" = today's). ZERO when none.
static func festival_hours(id := "") -> Vector2:
	var f := festival_today() if id == "" else find(id)
	if f.is_empty():
		return Vector2.ZERO
	return f["hours"] if f.has("hours") else row_hours(f)


static func is_festival_hour(h: float) -> bool:
	var fh := festival_hours()
	return fh.y > 0.0 and h >= fh.x and h < fh.y


## A row by id as an entry ({} if none), for names and hours.
static func find(id: String, ar := "") -> Dictionary:
	if ar == "":
		ar = arc()
	for r: Dictionary in _all_rows():
		if str(r.get("id", "")) == id:
			return _entry(r, ar)
	return {}


static func name_of(id: String) -> String:
	var e := find(id)
	return str(e.get("name", id.capitalize())) if not e.is_empty() else id.capitalize()


## Do shops shut today (a festival, or a holiday marked closes_shops)?
static func shops_closed_today() -> bool:
	for e: Dictionary in today():
		if e["kind"] in ["festival", "holiday"] and bool(e.get("closes_shops", false)):
			return true
	return false


static func today() -> Array:
	var d := _today()
	return events_on(season_of(d), dos_of(d), year(d))


## True the day before event id happens (mail eve letters).
static func eve(id: String) -> bool:
	var d := _today() + 1
	for e: Dictionary in events_on(season_of(d), dos_of(d), year(d)):
		if str(e["id"]) == id:
			return true
	return false


## Events tomorrow (for eve letters): non-birthday entries.
static func tomorrow() -> Array:
	var d := _today() + 1
	return events_on(season_of(d), dos_of(d), year(d)).filter(func(e: Dictionary) -> bool: return e["kind"] != "birthday")


## Upcoming entries over the next n days (today excluded): [{abs, season, day, e}].
static func upcoming(days := 7, include_birthdays := true) -> Array:
	var out: Array = []
	var t := _today()
	for i in range(1, days + 1):
		var d := t + i
		for e: Dictionary in events_on(season_of(d), dos_of(d), year(d)):
			if e["kind"] == "birthday" and (not include_birthdays or not bool(e.get("met", false))):
				continue
			out.append({"abs": d, "season": season_of(d), "day": dos_of(d), "e": e})
	return out


## One line for the community board: "Coming up: Egg Festival (Spr 14, plaza) . Maple's birthday (Spr 15)".
static func board_notices(days := 7) -> String:
	var bits: PackedStringArray = []
	for u: Dictionary in upcoming(days):
		var e: Dictionary = u["e"]
		var w := str(e.get("where", ""))
		bits.append("%s (%s %d%s)" % [e["name"], short_season(u["season"]), u["day"], (", " + w) if w != "" and e["kind"] != "birthday" else ""])
		if bits.size() >= 4:
			break
	if bits.is_empty():
		return "Nothing on the calendar this week."
	return "Coming up: " + " · ".join(bits)

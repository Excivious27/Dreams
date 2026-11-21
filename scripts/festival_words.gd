class_name FestivalWords
extends RefCounted
## Festival words for the town plaza (C12 P3): hosts who left town are replaced,
## arc voice (crystals / cash) and time of day (no night sky at noon).

## C12 P3: a festival host who has left town (gangster story: posy_gone, lumi_gone) is
## replaced by someone who is still here, like the Star Festival's Bram swap.
const FEST_FALLBACK := {"Posy": "Hazel", "Lumi": "Theo", "Hazel": "Maple", "Bram": "Maple", "Benno": "Hazel"}


static func fest_host(nm: String) -> String:
	var fl: Dictionary = GameState.run.get("flags", {})
	var tries := 0
	while fl.has(nm.to_lower() + "_gone") and FEST_FALLBACK.has(nm) and tries < 4:
		nm = str(FEST_FALLBACK[nm])
		tries += 1
	return nm


## C12 P3 festival words: arc voice and time of day.
const EGG_COUNT := 12


static func egg_call() -> String:
	if GameState.is_penguins():
		return "The egg hunt! Twelve eggs hidden round the plaza. Find them before the kids do."
	return "Egg hunt. Twelve hidden round the plaza. The kids are fast and they don't play fair."


static func egg_prize_text() -> String:
	if GameState.is_penguins():
		return "Every last egg! Mayor Alder hands you %s and a sticky handful of candy." % Money.amount(200)
	return "Every last egg. Alder peels %s off his own roll." % Money.amount(200)


static func lantern_tail() -> String:
	return " The sky fills." if GameState.is_night() else " Later tonight the whole river will be lit."


static func star_call() -> String:
	if GameState.is_night():
		return "Now look up and make a star-wish. Just one. The sky's listening tonight." if GameState.is_penguins() else "One wish. Look up. Even this block gets stars tonight."
	return "Make a star-wish. Just one. The stars are up there even now; they're listening." if GameState.is_penguins() else "One wish. The stars are up there even in daylight. Make it count."


## C15 P6: the festival year (data/festivals.json from tools/gen_festivals.py, contract row format).
## Calendar (P1) merges these rows; town.gd and the venues read defs through here.
static var _rows: Array = []


static func rows() -> Array:
	if _rows.is_empty():
		var f := FileAccess.open("res://data/festivals.json", FileAccess.READ)
		if f:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_rows = (d as Dictionary).get("festivals", [])
	return _rows


static func def(id: String) -> Dictionary:
	for r: Dictionary in rows():
		if str(r.get("id", "")) == id:
			return r
	return {}


## The year (1-based) of a save day, 112 days a year.
static func year_of(day: int) -> int:
	return maxi(0, day - 1) / 112 + 1


## Is the row on in this year for this arc ("penguins"/"gangsters")? Marina rows also need the marina tier.
static func row_active(r: Dictionary, year: int, arc: String) -> bool:
	var a := str(r.get("arc", "both"))
	if a != "both" and a != arc:
		return false
	var ym := int(r.get("year_min", 1))
	var ev := maxi(1, int(r.get("every", 1)))
	if year < ym or (ev > 1 and year % ev != 0):
		return false
	var mt := int((r.get("needs", {}) as Dictionary).get("marina_tier", 0))
	if mt > 0:
		if GameState.run.is_empty() or Marina.tier() < mt:
			return false
	var fl := str((r.get("needs", {}) as Dictionary).get("flag", ""))
	return fl == "" or (GameState.run.get("flags", {}) as Dictionary).has(fl)


## Rows on a season day (arc + year filtered). year/arc default to the save's.
static func rows_on(season: String, day: int, year := -1, arc := "", check_needs := true) -> Array:
	if year < 0:
		year = year_of(int(GameState.run.get("day", 1)))
	if arc == "":
		arc = "penguins" if GameState.is_penguins() else "gangsters"
	var out: Array = []
	for r: Dictionary in rows():
		if str(r["season"]) != season or int(r["day"]) != day:
			continue
		if check_needs:
			if row_active(r, year, arc):
				out.append(r)
		else:
			var a := str(r.get("arc", "both"))
			var ev := maxi(1, int(r.get("every", 1)))
			if (a == "both" or a == arc) and year >= int(r.get("year_min", 1)) and (ev == 1 or year % ev == 0):
				out.append(r)
	return out


## Arc-aware festival name (name_gang in the gangster arc).
static func name_of(id: String) -> String:
	var r := def(id)
	if r.is_empty():
		return id.capitalize()
	if not GameState.is_penguins() and str(r.get("name_gang", "")) != "":
		return str(r["name_gang"])
	return str(r["name"])


## Arc-aware host (host_gang in the gangster arc), through fest_host's left-town fallbacks.
static func host_of(id: String, fallback := "Mayor Alder") -> String:
	var r := def(id)
	if r.is_empty():
		return fallback
	var h := str(r.get("host_gang" if not GameState.is_penguins() else "host", ""))
	if h == "":
		return fallback
	if h == "Alder":
		return "Mayor Alder"
	return fest_host(h)

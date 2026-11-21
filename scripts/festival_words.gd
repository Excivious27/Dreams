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
	var n := "Twelve" if egg_count() == EGG_COUNT else "Sixteen, and one of them is golden,"
	if GameState.is_penguins():
		return "The egg hunt! %s eggs hidden round the plaza. Find them before the kids do." % n
	return "Stash hunt. %s envelopes hidden round the plaza. The kids are fast and they don't play fair." % n


static func egg_prize_text() -> String:
	if GameState.is_penguins():
		return "Every last egg! Mayor Alder hands you %s and a sticky handful of candy." % Money.amount(200)
	return "Every last envelope. Halo peels %s off the roll." % Money.amount(200)


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


## C15 P6 egg hunt words (arc voice: penguins hunt eggs, the crew hunts cash envelopes).
static func egg_count() -> int:
	return EGG_COUNT + 4 if year_of(int(GameState.run.get("day", 1))) >= 2 else EGG_COUNT


static func egg_go_text(n: int) -> String:
	return ("%d eggs hidden. Go!" if GameState.is_penguins() else "%d envelopes stashed. Go!") % n


static func egg_left_text(n: int) -> String:
	if GameState.is_penguins():
		return "%d eggs left." % n if n != 1 else "1 egg left."
	return "%d envelopes left." % n if n != 1 else "1 envelope left."


static func egg_hint(golden: bool) -> String:
	if golden:
		return "A: a golden egg!" if GameState.is_penguins() else "A: a gold envelope!"
	return "A: an egg!" if GameState.is_penguins() else "A: an envelope!"


static func golden_egg_text() -> String:
	return "The golden egg! Something special is inside." if GameState.is_penguins() else "The gold envelope. Something better than cash inside."


## The host's line when you've already had your turn today (eggs_left > 0: the hunt is still on).
static func again_text(fest: String, eggs_left := 0) -> String:
	var pen := GameState.is_penguins()
	if fest == "egg" and eggs_left > 0:
		return ("Keep looking! %s still hidden." if pen else "Still %s out there. Keep moving.") % egg_left_text(eggs_left).trim_suffix(" left.").to_lower()
	var again := {
		"egg": ["You've had your hunt. Go and eat your candy before the kids find it.", "You've had your run. Spend it somewhere nice."],
		"lantern": ["Your lantern's on the water. Watch the river for a while.", "Your light's on the water. Watch it go."],
		"harvest": ["The judges have your entry. Have a look round the Harvest Fair!", "Entry's in. Go walk the Street Fair."],
		"star": ["One wish a year. Enjoy the Star Festival!", "One wish. That's the deal. Enjoy the roof."],
		"blossom": ["You've had your dance. Enjoy the petals!", "You've had your turn on the floor."],
		"founders": ["You've had your questions. Enjoy the parade!", "You've had your questions. Enjoy Turf Day."],
		"hollow": ["You've walked the maze. Mind the bedsheet ghosts!", "You've walked the alley. Keep the mask on."],
		"winter_market": ["Your sculptures are judged. Stay warm!", "You've had your entry. Stay warm out there."],
		"gift_swap": ["Your gift's given. Happy year's end!", "Gift's given. Good year."],
	}
	if again.has(fest):
		return str(again[fest][0 if pen else 1])
	return "You've had your turn. Enjoy the %s!" % name_of(fest)


## The toast when a festival thing is used outside its hours.
static func not_open_text(fest: String, fh: Vector2, early: bool) -> String:
	var a := int(floor(fh.x))
	var b := int(ceil(fh.y))
	if early:
		return "The %s starts at %s." % [name_of(fest), TownHours.hours_text(a, b).split(" to ")[0]]
	return "The %s is over for this year." % name_of(fest)


## C15 P6: a festival's hours from its row (hours day 9-18 | evening sunset-4..sunset+3.5 |
## night sunset..sunset+4 | allday 6-24), in game hours. Vector2.ZERO for an unknown id.
static func hours_of(fest: String) -> Vector2:
	var r := def(fest)
	if r.is_empty():
		return Vector2.ZERO
	var ss := GameState.sunset() / 60.0
	match str(r.get("hours", "day")):
		"evening":
			return Vector2(ss - 4.0, minf(23.5, ss + 3.5))
		"night":
			return Vector2(ss, minf(24.0, ss + 4.0))
		"allday":
			return Vector2(6.0, 24.0)
	return Vector2(9.0, 18.0)

class_name RegionSeason
extends RefCounted
## C15 P4: how regions (regions.json) change by season: weather, stall menus and
## the region's leave line. Static helpers; Region.build/_shop call them.
##
## "weather" may be a string (all year) or {season: id, "default": id}; "" means
## the day's own weather. The day's storm/snow/blizzard and festival days always
## win over a region's flavour weather (c15_16-02 / c15_15-08: Neon no longer
## rains every day of the year, and snows in winter).

const DAY_WINS := ["storm", "snow", "blizzard"]


static func weather(r: Dictionary, se := "", today := "", festival := "?") -> String:
	if not r.has("weather"):
		return ""
	if se == "":
		se = GameState.look_se()
	if today == "":
		today = GameState.weather_today()
	if festival == "?":
		festival = GameState.festival_today()
	var v: Variant = r["weather"]
	var w := ""
	if v is Dictionary:
		w = str((v as Dictionary).get(se, (v as Dictionary).get("default", "")))
	else:
		w = str(v)
		if w == "rain" and se == "winter":
			w = "snow"  # a rainy city snows in winter
	if w == "":
		return ""
	if v is Dictionary and (today in DAY_WINS or festival != ""):
		return ""  # the day's big weather (or a festival's sky) wins over a city's flavour
	return w


static func items(thing: Dictionary, se := "") -> Array:
	if se == "":
		se = GameState.season()
	var out: Array = (thing.get("items", []) as Array).duplicate()
	for row in thing.get("items_" + se, []):
		out.append(row)
	return out


static func greet(thing: Dictionary, se := "") -> String:
	if se == "":
		se = GameState.season()
	return str(thing.get("greet_" + se, thing.get("greet", "What'll it be?")))

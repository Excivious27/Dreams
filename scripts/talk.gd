class_name Talk
extends RefCounted
## Everyday villager lines from data/talk.json, picked by season, weather, arc
## and story, never the same line twice in a row. Used when nothing more
## specific (story, hearts, quests) has something to say.

static var _d: Dictionary = {}


static func data() -> Dictionary:
	if _d.is_empty():
		_d = GameState.load_json("res://data/talk.json")
	return _d


## Pool keys (C12): every key of an NPC block is a condition; its lines join the
## pool only when the whole key holds. A key may join parts with "&" (all must
## hold), e.g. "gangsters&q:clear_meadow" or "winter&evening". Parts:
##   always | spring/summer/fall/winter | a weather id (clear/rain/storm/fog/wind/
##   petals/blizzard; "rain" also holds in storms) | penguins/gangsters | heat
##   (gang heat >= 3) | festival / festival_<id> (festival day) |
##   morning (5-11) / afternoon (11-17) / evening (17-21) / night (21-5) |
##   q:<quest> / !q:<quest> (quest done / not done) |
##   f:<flag> / !f:<flag> (also if:<flag> / not:<flag>) (run.flags has / lacks).
## C15 P3 seasonal parts: sun / leaves / fireflies / snow (seasonal weathers; "heat"
## stays gang heat) | early (season days 1-7) / mid (8-21) / late (22-28) | first
## (season day 1) | eve (a festival tomorrow) | birthday (the speaker's birthday) |
## y1 / y2 (year 1 / year 2 and later) | weekend (Sat, Sun) / weekday.
## Unknown parts never hold. On festival days festival lines win 70% of picks;
## on the speaker's birthday birthday lines win 80%.
static var _who := ""


static func year() -> int:
	return (int(GameState.run.get("day", 1)) - 1) / (GameState.DAYS_PER_SEASON * 4) + 1


## A festival tomorrow (SeasonCal: P1's Calendar when merged, else day 13).
static func festival_eve() -> bool:
	return SeasonCal.eve()


static func part_ok(part: String) -> bool:
	var arc := str(GameState.run.get("arc", "penguins"))
	var flags: Dictionary = GameState.run.get("flags", {})
	if part == "always":
		return true
	if part in ["spring", "summer", "fall", "winter"]:
		return GameState.season() == part
	if part in ["penguins", "gangsters"]:
		return arc == part
	if part == "rain":
		return GameState.is_wet() or GameState.weather_today() == "rain"
	if part in ["clear", "storm", "fog", "wind", "petals", "blizzard", "snow", "sun", "leaves", "fireflies"]:
		return GameState.weather_today() == part
	if part in ["early", "mid", "late", "first"]:
		var ds := GameState.day_of_season()
		match part:
			"early": return ds <= 7
			"mid": return ds > 7 and ds < 22
			"late": return ds >= 22
		return ds == 1
	if part == "eve":
		return festival_eve()
	if part == "birthday":
		return _who != "" and GameState.is_birthday(_who)
	if part == "y1":
		return year() == 1
	if part == "y2":
		return year() >= 2
	if part == "weekend":
		return GameState.weekday() >= 5
	if part == "weekday":
		return GameState.weekday() < 5
	if part == "heat":
		return arc == "gangsters" and Racket.heat() >= 3
	if part == "festival":
		return Calendar.town_festival_today() != ""  # C15 integ: plaza festivals ("Are you going to the plaza?")
	if part.begins_with("festival_"):
		return GameState.festival_today() == part.substr(9)
	if part in ["morning", "afternoon", "evening", "night"]:
		return part == phase()
	if part.begins_with("q:"):
		return GameState.quest_done(part.substr(2))
	if part.begins_with("!q:"):
		return not GameState.quest_done(part.substr(3))
	if part.begins_with("f:"):
		return flags.has(part.substr(2))
	if part.begins_with("if:"):
		return flags.has(part.substr(3))
	if part.begins_with("!f:"):
		return not flags.has(part.substr(3))
	if part.begins_with("not:"):
		return not flags.has(part.substr(4))
	return false


static func key_ok(key: String) -> bool:
	for part in key.split("&"):
		if not part_ok(part):
			return false
	return true


## Time of day for chatter: morning 5-11, afternoon 11-17, evening 17-21, night.
static func phase() -> String:
	var h := (int(GameState.run.get("time", 360)) % (24 * 60)) / 60
	if h >= 5 and h < 11:
		return "morning"
	if h >= 11 and h < 17:
		return "afternoon"
	if h >= 17 and h < 21:
		return "evening"
	return "night"


## Every line an NPC could say right now (own pool only, no Commons/Rec extras).
## Used by tools/talk_conditions_test.gd.
static func own_pool(id: String) -> Array:
	_who = id
	var pool: Array = []
	var d: Dictionary = data().get(id, data().get("_any", {}))
	for key: String in d:
		if key_ok(key):
			for l in d[key]:
				pool.append(str(l))
	return pool


static func festival_pool(id: String) -> Array:
	_who = id
	var pool: Array = []
	if Calendar.town_festival_today() == "":
		return pool
	var d: Dictionary = data().get(id, data().get("_any", {}))
	for key: String in d:
		if "festival" in key and key_ok(key):
			for l in d[key]:
				pool.append(str(l))
	if pool.is_empty() and data().has(id):  # C15 integ: new festivals' shared lines (_any) for anyone without their own
		var an: Dictionary = data().get("_any", {})
		for key: String in an:
			if "festival" in key and key_ok(key):
				for l in an[key]:
					pool.append(str(l))
	return pool


## C15 P3 (c15_10-13, 11-14): lines keyed "birthday" (own block, else _any) on the
## speaker's birthday.
static func birthday_pool(id: String) -> Array:
	_who = id
	var pool: Array = []
	if not GameState.is_birthday(id):
		return pool
	for src: String in [id, "_any"]:
		var d: Dictionary = data().get(src, {})
		for key: String in d:
			if "birthday" in key and key_ok(key):
				for l in d[key]:
					pool.append(str(l))
		if not pool.is_empty():
			break
	return pool


static func fill(text: String) -> String:
	var names: Dictionary = GameState.run.get("names", {})
	return text.replace("{town}", str(names.get("town", "town"))).replace("{name}", str(names.get("character", "friend"))).replace("{horse}", str(names.get("horse", "your horse"))).replace("{weapon}", GameState.weapon_word())


static func line(id: String) -> Array:
	var who := str(GameState.npcs.get(id, {}).get("name", id.capitalize()))
	var pool: Array = own_pool(id)
	pool.append_array(Commons.talk_pool(id))  # the community farm's progress
	pool.append_array(RecCenter.talk_pool(id))
	var fest := festival_pool(id)
	if not fest.is_empty() and randf() < 0.7:
		pool = fest
	var bday := birthday_pool(id)
	if not bday.is_empty() and randf() < 0.8:
		pool = bday
	if pool.is_empty():
		return [{"who": who, "text": "Good to see you."}]
	var last: Dictionary = GameState.run.get("talk_last", {})
	var pick := str(pool[randi() % pool.size()])
	if pool.size() > 1 and pick == str(last.get(id, "")):
		pick = str(pool[(pool.find(pick) + 1) % pool.size()])
	last[id] = pick
	GameState.run["talk_last"] = last
	return [{"who": who, "text": fill(pick)}]


## Indoor lines (npcs.json "inside", C12 P3): only in the NPC's own workplace
## (elsewhere they use their everyday Talk.line pool). "inside_gangsters" replaces
## the list in the gangster arc; an entry may be {"text", "when": <pool key>}.
static func inside_pool(id: String, interior_id: String) -> Array:
	var nd: Dictionary = GameState.npcs.get(id, {})
	if str(nd.get("work", "")) != interior_id:
		return []
	var src: Array = nd.get("inside", [])
	if not GameState.is_penguins() and not (nd.get("inside_gangsters", []) as Array).is_empty():
		src = nd["inside_gangsters"]
	var out: Array = []
	for e in src:
		if e is Dictionary:
			if key_ok(str(e.get("when", "always"))):
				out.append(fill(str(e.get("text", ""))))
		else:
			out.append(fill(str(e)))
	return out


## C12 P3: a region npc's daily lines for the arc and progress. regions.json npcs
## may carry "lines_gangsters" (gangster arc), "after" + "after_flag" (once the
## area's boss flag is set) and "done_lines" + "done_quest" (once their job is done).
static func region_lines(nd: Dictionary) -> Array:
	var flags: Dictionary = GameState.run.get("flags", {})
	if nd.has("done_quest") and GameState.quest_done(str(nd["done_quest"])):
		var dl: Array = nd.get("done_lines_gangsters", []) if not GameState.is_penguins() else []
		return dl if not dl.is_empty() else nd.get("done_lines", [])
	if nd.has("after_flag") and flags.has(str(nd["after_flag"])):
		var al: Array = nd.get("after_gangsters", []) if not GameState.is_penguins() else []
		return al if not al.is_empty() else nd.get("after", [])
	if not GameState.is_penguins() and not (nd.get("lines_gangsters", []) as Array).is_empty():
		return nd["lines_gangsters"]
	return nd.get("lines", [])

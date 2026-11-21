class_name MusicResolve
## C13 song resolver (contract section 1): the most specific EXISTING track for a base
## name and the moment (arc, season, phase, weather, story stage, weekday). Every name
## is optional at runtime (Music.has_track), so new songs drop in without code.
## Music.resolve(base, ctx) calls pick(); GameMap.area_track ends with it.

## Penguin-toned shared songs the gang arc never hears (sleigh bells, harvest fiddle):
## it falls through to its own base instead (c13_02-02 / c13_04-03).
const PENGUIN_ONLY := ["winter", "farm_fall", "sanctuary", "countryside_penguin", "morning"]
const SEASONS := ["spring", "summer", "fall", "winter"]
## Highest rotation take tried (<pick>_2 .. _N).
const MAX_TAKE := 5
## Tests: a fake track list (non-empty = only these names exist).
static var fake_tracks: Array = []


static func has(t: String) -> bool:
	if t == "":
		return false
	if not fake_tracks.is_empty():
		return t in fake_tracks
	return Music.has_track(t)


## The moment's defaults from GameState; ctx keys override (arc, season, phase,
## weather, stage, weekday, day). Extra keys: shared_night (bool: the map used the shared
## night song before), shared_weather (bool: shared rain/storm/snow), season_alias
## (Dictionary season -> legacy seasonal name, e.g. the farm's "farm_fall"/"winter").
static func context(ctx := {}) -> Dictionary:
	var c := ctx.duplicate()
	var run_ok := not GameState.run.is_empty()
	if not c.has("arc"):
		c["arc"] = str(GameState.run.get("arc", "penguins")) if run_ok else "penguins"
	if not c.has("season"):
		c["season"] = GameState.season() if run_ok else "spring"
	if not c.has("phase"):
		c["phase"] = phase_now() if run_ok else "day"
	if not c.has("weather"):
		c["weather"] = weather_now() if run_ok else "clear"
	if not c.has("stage"):
		c["stage"] = GameState.story_stage()
	if not c.has("day"):
		c["day"] = int(GameState.run.get("day", 1)) if run_ok else 1
	if not c.has("weekday"):
		c["weekday"] = (int(c["day"]) - 1) % 7
	return c


## dawn = first light until ~1.5 h after sunrise; night = GameState.is_night().
static func phase_now() -> String:
	if GameState.is_night():
		return "night"
	var t := int(GameState.run.get("time", 720)) % 1440
	var sr := GameState.sunrise()
	if t >= sr - 60 and t < sr + 90:
		return "dawn"
	return "day"


static func weather_now() -> String:
	var w := GameState.weather_today()
	if w == "storm":
		return "storm"
	if w == "rain":
		return "rain"
	if w in ["snow", "blizzard"] and GameState.season() == "winter":
		return "snow"
	return "clear"


## Ordered candidate names (no arc suffix yet; [name, base_family] pairs).
static func candidates(base: String, c: Dictionary) -> Array:
	var out: Array = []
	var gang := str(c["arc"]) == "gangsters"
	if int(c.get("stage", 0)) >= 99:
		out.append([base + "_after", true])
	var w := str(c.get("weather", "clear"))
	if w in ["rain", "storm", "snow"]:
		out.append([base + "_" + w, true])
		if w == "storm":
			out.append([base + "_rain", true])
		if c.get("shared_weather", false):
			if w == "storm":
				out.append(["storm", false])
			if w in ["rain", "storm"]:
				out.append(["rain", false])
			if w == "snow":
				out.append(["snow", false])
				if not gang:
					out.append(["winter", false])  # snow days: the shared winter piece (penguin)
	var ph := str(c.get("phase", "day"))
	if ph == "night":
		out.append([base + "_night", true])
		if c.get("shared_night", false):
			out.append(["night", false])
	elif ph == "dawn":
		out.append([base + "_dawn", true])
		if c.get("shared_night", false):
			out.append(["morning", false])
	var se := str(c.get("season", ""))
	if se != "":
		out.append([base + "_" + se, true])
		var al: Dictionary = c.get("season_alias", {})
		if al.has(se):
			out.append([str(al[se]), true])
	out.append([base, true])
	return out


## The resolver. Gang arc: each candidate tries `<name>_gang` first; a penguin pastoral
## base-family name is skipped when the area has a `_gang` family song; PENGUIN_ONLY
## shared songs are skipped. Penguin arc never plays a `_gang` file. Then rotation.
static func pick(base: String, ctx := {}) -> String:
	if base == "":
		return ""
	var c := context(ctx)
	var gang := str(c["arc"]) == "gangsters"
	if not gang and base.ends_with("_gang"):
		base = base.trim_suffix("_gang")
	var root := base.trim_suffix("_gang")
	var fam_gang := gang and has(root + "_gang")
	var got := ""
	for pr: Array in candidates(root, c):
		var n := str(pr[0])
		var fam := bool(pr[1])
		if gang:
			if has(n + "_gang"):
				got = n + "_gang"
				break
			if n in PENGUIN_ONLY and n != root:
				continue
			if fam and fam_gang and n != root:
				continue  # the area has gang songs: never its penguin seasonal/after/night take
		if has(n):
			got = n
			break
	if got == "":
		return base if has(base) else ""
	return rotate(got, c)


## `<pick>_2`, `_3` ... rotate by in-game day: stable all day, a new take the next day
## (any count >= 2), different areas on different takes.
static func rotate(t: String, c: Dictionary) -> String:
	var takes: Array = [t]
	for i in range(2, MAX_TAKE + 1):
		var n := "%s_%d" % [t, i]
		if not has(n):
			break
		takes.append(n)
	if takes.size() == 1:
		return t
	var d := int(c.get("day", 1))
	return str(takes[(d + _h(t)) % takes.size()])


static func _h(s: String) -> int:
	var h := 0
	for i in s.length():
		h = (h * 31 + s.unicode_at(i)) % 9973
	return h

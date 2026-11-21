class_name Critters
extends RefCounted
## C16a P4 (c16a_08-12): the Critter log's rules. Data: data/collections.json "critters" (tools/gen_collections.py
## CRITTERS; edit that). Each entry: id (cr_*), kind (the WorldGen wildlife kind the net catches, "" for legends),
## seasons ([] = all year), time day|night|"", net (tier 0 Twig / 1 Silk / 2 Star), lvl (Foraging), spook 0..1,
## optional arc, optional legend {weather, hours [from, to), chance}. All ages: nothing is harmed or kept.

static var _by_id: Dictionary = {}
static var _by_kind: Dictionary = {}


static func all() -> Array:
	return Collections.data().get("critters", [])


static func _index() -> void:
	if not _by_id.is_empty():
		return
	for e: Dictionary in all():
		_by_id[str(e["id"])] = e
		if str(e.get("kind", "")) != "":
			_by_kind[str(e["kind"])] = e


static func get_def(id: String) -> Dictionary:
	_index()
	return _by_id.get(id, {})


## The log entry for a wildlife kind (butterfly_blue -> cr_sky_wing), or {} when the net can't catch it.
static func for_kind(kind: String) -> Dictionary:
	_index()
	return _by_kind.get(kind, {})


static func name_of(id: String) -> String:
	var e := get_def(id)
	if e.is_empty():
		return GameState.item_name(id)
	if not GameState.is_penguins() and str(e.get("name_gang", "")) != "":
		return str(e["name_gang"])
	return str(e.get("name", id))


static func _arc_ok(e: Dictionary) -> bool:
	var a := str(e.get("arc", ""))
	return a == "" or GameState.run.is_empty() or a == str(GameState.run.get("arc", ""))


static func _time_ok(e: Dictionary, hour: int) -> bool:
	var night := hour >= 20 or hour < 6
	match str(e.get("time", "")):
		"day": return not night
		"night": return night
	return true


## Contract API: the critter ids out at this scene, season and hour (legends not included: they need weather).
## `scene` is kept for region-only critters (none yet: every kind follows WorldGen's own spawn pools).
static func catchable(scene: String, season: String, hour: int) -> Array:
	var out := []
	for e: Dictionary in all():
		if e.has("legend") or not _arc_ok(e):
			continue
		var se: Array = e.get("seasons", [])
		if not se.is_empty() and not se.has(season):
			continue
		if not _time_ok(e, hour):
			continue
		var only: Array = e.get("scenes", [])
		if not only.is_empty() and not only.has(scene):
			continue
		out.append(str(e["id"]))
	return out


## Why the held net can't take this one ("" = it can).
static func blocked_by(e: Dictionary, net_tier: int, forage_lvl: int) -> String:
	if net_tier < int(e.get("net", 0)):
		return "It's too quick for this net. A %s would do it." % BugNet.net_name(int(e.get("net", 0)))
	if forage_lvl < int(e.get("lvl", 0)):
		return "It slips away. (Foraging %d)" % int(e.get("lvl", 0))
	return ""


## Catch chance for one swing: spooky critters slip away more, far more while they flee.
## The Star Net never spooks.
static func catch_chance(e: Dictionary, fleeing: bool, net_tier: int) -> float:
	var sp := float(e.get("spook", 0.2))
	if net_tier >= 2:
		return 1.0
	return clampf(1.0 - sp * (0.8 if fleeing else 0.25) + 0.1 * net_tier, 0.15, 1.0)


## A season legend on this swing, or "" (Star Net, Foraging 40+, its season, weather and hours; once per run).
static func legend_roll(season: String, weather: String, hour: int, net_tier: int, forage_lvl: int) -> String:
	for e: Dictionary in all():
		if not e.has("legend") or not _arc_ok(e):
			continue
		var id := str(e["id"])
		if Collections.have("critters", id):
			continue
		if net_tier < int(e.get("net", 2)) or forage_lvl < int(e.get("lvl", 40)):
			continue
		if not (e.get("seasons", []) as Array).has(season):
			continue
		var L: Dictionary = e["legend"]
		var wx: Array = L.get("weather", [])
		if not wx.is_empty() and not wx.has(weather):
			continue
		var hr: Array = L.get("hours", [0, 24])
		if hour < int(hr[0]) or hour >= int(hr[1]):
			continue
		if randf() < float(L.get("chance", 0.04)):
			return id
	return ""

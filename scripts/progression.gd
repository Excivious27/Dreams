class_name Progression
extends RefCounted
## C16a P1: the intended unlock timeline (docs/PROGRESSION.md table, compiled into
## data/progression.json by tools/gen_progression.py). Game days: Spring 1 = 1, year 2 = 113.
## Used by tools/progression_test.gd and the 3-year simulator (tools/sim.gd) for unlock bands.

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = GameState.load_json("res://data/progression.json").get("unlocks", {})
	return _data


## Intended first day `id` can open (-1 = not in the table).
static func unlock_day(id: String) -> int:
	return int((data().get(id, {}) as Dictionary).get("day", -1))


## Ids whose gate the game data holds (tested), as opposed to planned rows.
static func enforced() -> Array:
	var out: Array = []
	for k: String in data():
		if str(data()[k].get("status", "")) == "enforced":
			out.append(k)
	out.sort()
	return out

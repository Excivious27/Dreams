class_name RegionData
extends RefCounted
## data/regions.json parsed once per session (250 KB: ~7 ms a parse here, more on a
## phone). It was parsed on every region load, and twice on the way into a campaign
## battle (Campaign.attack read the spawn, then Region.build read it again).
## Treat the result as read-only; Region.build takes a deep copy of its own entry.

static var _all: Dictionary = {}


static func all() -> Dictionary:
	if _all.is_empty():
		_all = GameState.load_json("res://data/regions.json")
	return _all


## One region's entry (shared: don't modify it).
static func region(id: String) -> Dictionary:
	return all().get(id, {})

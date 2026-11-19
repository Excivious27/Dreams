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


static func line(id: String) -> Array:
	var who := str(GameState.npcs.get(id, {}).get("name", id.capitalize()))
	var pool: Array = []
	var d: Dictionary = data().get(id, data().get("_any", {}))
	var arc := str(GameState.run.get("arc", "penguins"))
	var keys := ["always", GameState.season(), GameState.weather_today(), arc]
	if GameState.is_wet() and not "rain" in keys:
		keys.append("rain")
	for key in keys:
		for l in d.get(key, []):
			pool.append(str(l))
	if GameState.festival_today() != "":
		for l in d.get("festival", []):
			pool.append(str(l))
	pool.append_array(Commons.talk_pool(id))  # the community farm's progress
	if arc == "gangsters" and Racket.heat() >= 3:
		for l in d.get("heat", []):
			pool.append(str(l))
	if pool.is_empty():
		return [{"who": who, "text": "Good to see you."}]
	var last: Dictionary = GameState.run.get("talk_last", {})
	var pick := str(pool[randi() % pool.size()])
	if pool.size() > 1 and pick == str(last.get(id, "")):
		pick = str(pool[(pool.find(pick) + 1) % pool.size()])
	last[id] = pick
	GameState.run["talk_last"] = last
	return [{"who": who, "text": pick.replace("{town}", str(GameState.run.get("names", {}).get("town", "town"))).replace("{name}", str(GameState.run.get("names", {}).get("character", "friend")))}]

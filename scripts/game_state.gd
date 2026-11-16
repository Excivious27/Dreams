class_name GameState
extends RefCounted
## The one place the player's run lives: arc, character, names, skills, crystals.
## Kept as a plain Dictionary so it can be saved to user:// and, later, synced for co-op.

const SAVE_KEY := "run"
static var run: Dictionary = {}


static func new_run(arc: String, playable_id: String, character_name: String, town_name: String, pet_name: String) -> void:
	var skills := {}
	for id in load_json("res://data/skills.json").keys():
		skills[id] = {"level": 1, "xp": 0}
	run = {
		"arc": arc,
		"playable": playable_id,
		"names": {"character": character_name, "town": town_name, "pet": pet_name},
		"crystals": 0,
		"skills": skills,
		"flags": {},
		"day": 1,
	}
	save()


static func has_run() -> bool:
	if run.is_empty():
		var saved: Variant = SaveGame.get_value(SAVE_KEY)
		if saved is Dictionary and not saved.is_empty():
			run = saved
	return not run.is_empty()


static func save() -> void:
	SaveGame.set_value(SAVE_KEY, run)


static func sprite_for_playable(playable_id: String) -> String:
	var p: Dictionary = load_json("res://data/playable.json").get(playable_id, {})
	return str(p.get("sprite", ""))


static func load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("GameState: can't open " + path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

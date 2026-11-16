class_name GameState
extends RefCounted
## The one place the player's run lives. Plain Dictionary so it saves to user://
## and can be synced for co-op later. Everything that changes the world goes here.

const SAVE_KEY := "run"
const DAY_START := 6 * 60      # 6:00
const DAY_END := 26 * 60       # 2:00 next day: pass out
const MINUTES_PER_SECOND := 1.0 / 0.7  # one game minute every 0.7s (about 23 min per day)

static var run: Dictionary = {}
static var items: Dictionary = {}
static var crops: Dictionary = {}
static var npcs: Dictionary = {}
static var arcs: Dictionary = {}
static var playables: Dictionary = {}


static func load_data() -> void:
	if not items.is_empty():
		return
	items = load_json("res://data/items.json")
	crops = load_json("res://data/crops.json")
	npcs = load_json("res://data/npcs.json")
	arcs = load_json("res://data/arcs.json")
	playables = load_json("res://data/playable.json")


static func new_run(arc: String, playable_id: String, character_name: String, town_name: String, pet_name: String) -> void:
	load_data()
	var skills := {}
	for id in load_json("res://data/skills.json").keys():
		skills[id] = {"level": 1, "xp": 0}
	run = {
		"arc": arc,
		"playable": playable_id,
		"names": {"character": character_name, "town": town_name, "pet": pet_name},
		"crystals": 20 if arc == "penguins" else 35,
		"day": 1,
		"time": DAY_START,
		"energy": 100, "max_energy": 100,
		"hp": 6, "max_hp": 6,
		"skills": skills,
		"flags": {},
		"decisions": {},
		"friendship": {},
		"talked_today": {},
		"inventory": {},
		"tools": ["hoe", "can", "axe", "pickaxe", "sword", "rod"],
		"selected": "",
		"farm": {},
		"sellbox": {},
		"quests": [],
		"scene": "farm",
		"mine_floor": 1,
		"kills": 0,
		"intro_done": false,
	}
	add_item("turnip_seed", 6)
	add_item("berry", 2)
	save()


static func has_run() -> bool:
	load_data()
	if run.is_empty():
		var saved: Variant = SaveGame.get_value(SAVE_KEY)
		if saved is Dictionary and not saved.is_empty():
			run = saved
			_migrate()
	return not run.is_empty()


## Older saves (or saves from before a new field existed) get the missing keys.
static func _migrate() -> void:
	var defaults := {
		"crystals": 20, "day": 1, "time": DAY_START, "energy": 100, "max_energy": 100,
		"hp": 6, "max_hp": 6, "skills": {}, "flags": {}, "decisions": {}, "friendship": {},
		"talked_today": {}, "inventory": {}, "tools": ["hoe", "can", "axe", "pickaxe", "sword", "rod"],
		"selected": "", "farm": {}, "sellbox": {}, "quests": [], "scene": "farm", "mine_floor": 1,
		"kills": 0, "intro_done": false,
	}
	for k in defaults:
		if not run.has(k):
			run[k] = defaults[k]
	for id in load_json("res://data/skills.json").keys():
		if not run["skills"].has(id):
			run["skills"][id] = {"level": 1, "xp": 0}
	if not run.has("names") or not run.has("arc") or not run.has("playable"):
		run = {}


static func save() -> void:
	SaveGame.set_value(SAVE_KEY, run)


static func names() -> Dictionary:
	return run["names"]


static func is_penguins() -> bool:
	return run.get("arc", "") == "penguins"


static func sprite_for_playable(playable_id: String) -> String:
	load_data()
	return str(playables.get(playable_id, {}).get("sprite", ""))


# ---- items -------------------------------------------------------------------

static func item_name(id: String) -> String:
	return str(items.get(id, {}).get("name", id.capitalize()))


static func item_value(id: String) -> int:
	return int(items.get(id, {}).get("value", 0))


static func count(id: String) -> int:
	return int(run["inventory"].get(id, 0))


static func add_item(id: String, n: int = 1) -> void:
	var inv: Dictionary = run["inventory"]
	inv[id] = int(inv.get(id, 0)) + n
	if inv[id] <= 0:
		inv.erase(id)
		if run["selected"] == id:
			run["selected"] = ""


static func has_tool(id: String) -> bool:
	return run["tools"].has(id)


static func add_tool(id: String) -> void:
	if not has_tool(id):
		run["tools"].append(id)


static func sword_damage() -> int:
	var best := 0
	for t in run["tools"]:
		best = maxi(best, int(items.get(t, {}).get("damage", 0)))
	return maxi(best, 1)


# ---- skills ------------------------------------------------------------------

static func add_xp(skill: String, xp: int) -> bool:
	var s: Dictionary = run["skills"].get(skill, {"level": 1, "xp": 0})
	s["xp"] = int(s["xp"]) + xp
	var leveled := false
	while int(s["xp"]) >= xp_for_next(int(s["level"])):
		s["xp"] = int(s["xp"]) - xp_for_next(int(s["level"]))
		s["level"] = int(s["level"]) + 1
		leveled = true
	run["skills"][skill] = s
	return leveled


static func xp_for_next(level: int) -> int:
	return 20 + level * 15


static func skill_level(skill: String) -> int:
	return int(run["skills"].get(skill, {}).get("level", 1))


# ---- energy / hp -------------------------------------------------------------

static func spend_energy(n: int) -> bool:
	if int(run["energy"]) < n:
		return false
	run["energy"] = int(run["energy"]) - n
	return true


static func heal(n: int) -> void:
	run["hp"] = mini(int(run["hp"]) + n, int(run["max_hp"]))


static func restore_energy(n: int) -> void:
	run["energy"] = mini(int(run["energy"]) + n, int(run["max_energy"]))


# ---- quests ------------------------------------------------------------------

static func add_quest(id: String, text: String) -> void:
	for q in run["quests"]:
		if q["id"] == id:
			return
	run["quests"].append({"id": id, "text": text, "done": false})


static func complete_quest(id: String) -> bool:
	for q in run["quests"]:
		if q["id"] == id and not q["done"]:
			q["done"] = true
			return true
	return false


static func quest_done(id: String) -> bool:
	for q in run["quests"]:
		if q["id"] == id:
			return bool(q["done"])
	return false


# ---- time / days -------------------------------------------------------------

static func clock_text() -> String:
	var t := int(run["time"]) % (24 * 60)
	var h := t / 60
	var m := t % 60
	var suffix := "am" if h < 12 else "pm"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, suffix]


## Advance to the next morning: crops grow, sell box pays, energy restores.
static func sleep(passed_out := false) -> Dictionary:
	var report := {"earned": 0, "sold": [], "grown": 0}
	var total := 0
	for id in run["sellbox"].keys():
		var n: int = int(run["sellbox"][id])
		var v := item_value(id) * n
		total += v
		report["sold"].append("%s x%d = %d" % [item_name(id), n, v])
	if total > 0:
		var bonus := 1.0 + 0.05 * (skill_level("bartering") - 1)
		total = int(total * bonus)
		add_xp("bartering", total / 4)
	run["crystals"] = int(run["crystals"]) + total
	report["earned"] = total
	run["sellbox"] = {}
	for key in run["farm"].keys():
		var tile: Dictionary = run["farm"][key]
		if tile.get("crop", "") != "":
			if tile.get("watered", false):
				tile["days"] = int(tile.get("days", 0)) + 1
				report["grown"] += 1
			tile["watered"] = false
		else:
			tile["watered"] = false
	run["day"] = int(run["day"]) + 1
	run["time"] = DAY_START
	run["energy"] = int(run["max_energy"]) if not passed_out else int(run["max_energy"]) / 2
	run["hp"] = int(run["max_hp"])
	run["talked_today"] = {}
	save()
	return report


static func load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("GameState: can't open " + path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

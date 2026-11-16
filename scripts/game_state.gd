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
static var skills_data: Dictionary = {}
static var recipes: Dictionary = {}
static var enemy_data: Dictionary = {}
static var forage_data: Dictionary = {}
static var quests_data: Dictionary = {}
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
	skills_data = load_json("res://data/skills.json")
	recipes = load_json("res://data/recipes.json")
	enemy_data = load_json("res://data/enemies.json")
	forage_data = load_json("res://data/forage.json")
	quests_data = load_json("res://data/quests.json")


static func new_run(arc: String, playable_id: String, character_name: String, town_name: String, pet_name: String) -> void:
	load_data()
	var skills := {}
	for id in load_json("res://data/skills.json").keys():
		skills[id] = {"level": 1, "xp": 0}
	run = {
		"equip": {"head": "", "body": "", "feet": "", "ring": "", "charm": ""},
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
		"toolbar": ["hoe", "can", "axe", "pickaxe", "sword", "rod", "", "", "", "", "", ""],
		"slot": 0,
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
		"toolbar": ["hoe", "can", "axe", "pickaxe", "sword", "rod", "", "", "", "", "", ""], "slot": 0,
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
	var sprite := str(playables.get(playable_id, {}).get("sprite", ""))
	if run.get("arc", "") == "gangsters" and CharacterLibrary.has_character(sprite + "_gang"):
		sprite += "_gang"
	if sprite != "" and not CharacterLibrary.has_character(sprite):
		return ""
	return sprite


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
		var tb: Array = run["toolbar"]
		var i := tb.find(id)
		if i >= 0:
			tb[i] = ""
	elif n > 0 and not run["toolbar"].has(id):
		# New item: drop it into the first free toolbar slot, like Stardew's backpack.
		var tb: Array = run["toolbar"]
		var free := tb.find("")
		if free >= 0:
			tb[free] = id
	sync_selected()


## What's "in hand": the toolbar slot's item if it's a usable item with count > 0.
static func sync_selected() -> void:
	var tb: Array = run["toolbar"]
	var slot := clampi(int(run["slot"]), 0, tb.size() - 1)
	run["slot"] = slot
	var id := str(tb[slot])
	if id != "" and run["inventory"].has(id):
		run["selected"] = id
	else:
		run["selected"] = ""


static func held_tool() -> String:
	var tb: Array = run["toolbar"]
	var id := str(tb[int(run["slot"])])
	return id if has_tool(id) else ""


static func select_slot(i: int) -> void:
	run["slot"] = clampi(i, 0, run["toolbar"].size() - 1)
	sync_selected()


## Items in the inventory that are not on the toolbar (the backpack).
static func backpack() -> Array:
	var out: Array = []
	for id in run["inventory"].keys():
		if not run["toolbar"].has(id):
			out.append(id)
	out.sort()
	return out


static func has_tool(id: String) -> bool:
	return run["tools"].has(id)


static func add_tool(id: String) -> void:
	if not has_tool(id):
		run["tools"].append(id)
		var tb: Array = run["toolbar"]
		# Upgrades replace the older tool of the same kind on the toolbar.
		var old := tb.find("sword") if id == "iron_sword" else -1
		if old >= 0:
			tb[old] = id
		else:
			var free := tb.find("")
			if free >= 0:
				tb[free] = id


static func sword_damage() -> int:
	var held := held_tool()
	var best := int(items.get(held, {}).get("damage", 0))
	if best == 0:
		for t in run["tools"]:
			best = maxi(best, int(items.get(t, {}).get("damage", 0)))
	best += (1 if has_perk("combat", "Fighter") else 0) + (1 if has_perk("combat", "Berserker") else 0) + gear_stat("damage")
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
	if leveled:
		_apply_max_stats()
	return leveled


## Slow, steady curve: 40, 76, 136, 220, 328, 460, 616, 796, 1000...
static func xp_for_next(level: int) -> int:
	return 40 + level * level * 12 - 12 * level + (level - 1) * 24


static func skill_level(skill: String) -> int:
	return int(run["skills"].get(skill, {}).get("level", 1))


## Perk unlocked when the skill reaches the perk's level (see data/skills.json).
static func has_perk(skill: String, perk_name: String) -> bool:
	for pk in skills_data.get(skill, {}).get("perks", []):
		if str(pk[1]) == perk_name:
			return skill_level(skill) >= int(pk[0])
	return false


static func perks_of(skill: String) -> Array:
	return skills_data.get(skill, {}).get("perks", [])


# ---- equipment ----------------------------------------------------------------

const SLOTS := ["head", "body", "feet", "ring", "charm"]


static func equipped(slot: String) -> String:
	return str(run.get("equip", {}).get(slot, ""))


static func equip(id: String) -> void:
	var it: Dictionary = items.get(id, {})
	if it.get("type", "") != "equip":
		return
	var slot := str(it.get("slot", ""))
	var eq: Dictionary = run.get("equip", {})
	var old := str(eq.get(slot, ""))
	if old != "":
		add_item(old, 1)
	add_item(id, -1)
	eq[slot] = id
	run["equip"] = eq
	_apply_max_stats()


static func unequip(slot: String) -> void:
	var eq: Dictionary = run.get("equip", {})
	var old := str(eq.get(slot, ""))
	if old == "":
		return
	add_item(old, 1)
	eq[slot] = ""
	run["equip"] = eq
	_apply_max_stats()


## Sum of a stat across worn gear: defense, speed, luck, damage, energy.
static func gear_stat(stat: String) -> int:
	var total := 0
	for slot in SLOTS:
		var id := equipped(slot)
		if id != "":
			total += int(items.get(id, {}).get("stats", {}).get(stat, 0))
	return total


static func _apply_max_stats() -> void:
	var base_hp := 6 + (1 if has_perk("combat", "Tough") else 0) + (2 if has_perk("combat", "Warrior") else 0)
	var base_en := 100 + (10 if has_perk("combat", "Stamina") else 0) + gear_stat("energy")
	run["max_hp"] = base_hp
	run["max_energy"] = base_en
	run["hp"] = mini(int(run["hp"]), base_hp)


static func refresh_stats() -> void:
	_apply_max_stats()


# ---- economy modifiers ---------------------------------------------------------

static func buy_multiplier() -> float:
	var m := 1.0
	if has_perk("bartering", "Haggler"): m -= 0.05
	if has_perk("bartering", "Tycoon"): m -= 0.15
	return maxf(0.5, m)


static func sell_multiplier() -> float:
	var m := 1.0
	if has_perk("bartering", "Trader"): m += 0.05
	if has_perk("bartering", "Appraiser"): m += 0.10
	if has_perk("bartering", "Monopolist"): m += 0.20
	return m


## Roll a drop table: Array of [item, chance, n]. Luck nudges the chance.
static func roll_drops(table: Array, luck_bonus := 0) -> Dictionary:
	var out := {}
	var luck := 1.0 + 0.05 * (gear_stat("luck") + luck_bonus)
	for row in table:
		if randf() < float(row[1]) * luck:
			var n := int(row[2])
			if has_perk("combat", "Champion"):
				n *= 2
			out[str(row[0])] = int(out.get(str(row[0]), 0)) + n
	return out


## Pick one forage item for a region: Array of [item, weight, (skill, level)].
static func roll_forage(region: String) -> String:
	var pool: Array = forage_data.get(region, forage_data.get("farm", []))
	var total := 0.0
	var ok: Array = []
	for row in pool:
		if row.size() >= 4 and skill_level(str(row[2])) < int(row[3]):
			continue
		ok.append(row)
		total += float(row[1])
	var r := randf() * total
	for row in ok:
		r -= float(row[1])
		if r <= 0.0:
			return str(row[0])
	return str(ok[0][0]) if not ok.is_empty() else "berry"


static func rarity_color(id: String) -> Color:
	match str(items.get(id, {}).get("rarity", "common")):
		"uncommon": return Color(0.5, 0.9, 0.5)
		"rare": return Color(0.45, 0.65, 1.0)
		"epic": return Color(0.8, 0.5, 1.0)
		"legendary": return Color(1.0, 0.75, 0.3)
	return Color(0.9, 0.9, 0.9)


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
			_give_reward(_quest_def(id).get("reward", {}))
			return true
	return false


static func has_quest(id: String) -> bool:
	for q in run["quests"]:
		if q["id"] == id:
			return true
	return false


static func _quest_def(id: String) -> Dictionary:
	for q in quests_data.get("main", []) + quests_data.get("side", []):
		if str(q["id"]) == id and str(q.get("arc", "both")) in ["both", str(run["arc"])]:
			return q
	return {}


static func _cond_ok(when: Dictionary) -> bool:
	if when.has("day") and int(run["day"]) < int(when["day"]):
		return false
	if when.has("quest") and not quest_done(str(when["quest"])):
		return false
	if when.has("skill") and skill_level(str(when["skill"][0])) < int(when["skill"][1]):
		return false
	if when.has("flag") and not run["flags"].has(str(when["flag"])):
		return false
	if when.has("item"):
		var it = when["item"]
		if it is Array:
			if count(str(it[0])) < int(it[1]):
				return false
		elif count(str(it)) < 1:
			return false
	if when.has("items"):
		for pair in when["items"]:
			if count(str(pair[0])) < int(pair[1]):
				return false
	return true


static func _give_reward(rw: Dictionary) -> void:
	if rw.has("crystals"):
		run["crystals"] = int(run["crystals"]) + int(rw["crystals"])
	if rw.has("item"):
		add_item(str(rw["item"][0]), int(rw["item"][1]))
	if rw.has("xp"):
		add_xp(str(rw["xp"][0]), int(rw["xp"][1]))
	if rw.has("friend"):
		var fr: Dictionary = run["friendship"]
		fr[str(rw["friend"][0])] = int(fr.get(str(rw["friend"][0]), 0)) + int(rw["friend"][1])


## Main-story quests appear as the game progresses; side quests come from the
## person who gives them (see town talk). Returns ids of quests just completed.
static func tick_quests() -> Array:
	var done: Array = []
	for q in quests_data.get("main", []):
		if str(q.get("arc", "both")) not in ["both", str(run["arc"])]:
			continue
		var id := str(q["id"])
		if not has_quest(id) and _cond_ok(q.get("when", {})):
			add_quest(id, str(q["text"]))
	for q in run["quests"]:
		if q["done"]:
			continue
		var d := _quest_def(str(q["id"]))
		if d.has("done_when") and _cond_ok(d["done_when"]):
			if bool(d.get("take", false)):
				var dw: Dictionary = d["done_when"]
				if dw.has("item"):
					add_item(str(dw["item"][0]), -int(dw["item"][1]))
				for pair in dw.get("items", []):
					add_item(str(pair[0]), -int(pair[1]))
			if complete_quest(str(q["id"])):
				done.append(str(q["id"]))
	return done


## A side quest this NPC can offer right now (not yet taken, conditions met).
static func side_quest_for(npc: String) -> Dictionary:
	for q in quests_data.get("side", []):
		if str(q.get("giver", "")) != npc or has_quest(str(q["id"])):
			continue
		if str(q.get("arc", "both")) not in ["both", str(run["arc"])]:
			continue
		if _cond_ok(q.get("when", {})):
			return q
	return {}


static func side_quest_pending(npc: String) -> Dictionary:
	for q in run["quests"]:
		if q["done"]:
			continue
		var d := _quest_def(str(q["id"]))
		if str(d.get("giver", "")) == npc:
			return d
	return {}


static func quest_done(id: String) -> bool:
	for q in run["quests"]:
		if q["id"] == id:
			return bool(q["done"])
	return false


# ---- time / days -------------------------------------------------------------

const DAYS_PER_SEASON := 28
const SEASONS := ["spring", "summer", "fall", "winter"]


static func season() -> String:
	return SEASONS[((int(run.get("day", 1)) - 1) / DAYS_PER_SEASON) % 4]


static func day_of_season() -> int:
	return (int(run.get("day", 1)) - 1) % DAYS_PER_SEASON + 1


static func grass_tile() -> String:
	match season():
		"summer": return "grass_summer"
		"fall": return "grass_fall"
		"winter": return "grass_winter"
	return "grass"


## Tree/bush sprite names per season (variant 0..2).
static func tree_sprite(v: int) -> String:
	match season():
		"summer": return ["apple_tree", "pine", "orange_tree"][v % 3] if Art.has("nature", "apple_tree") else ["oak", "pine", "oak"][v % 3]
		"fall": return ["tree_red", "tree_orange", "tree_birch"][v % 3] if Art.has("nature", "tree_red") else ["oak_autumn", "pine", "oak_autumn"][v % 3]
		"winter": return ["tree_bare", "pine_snow", "tree_bare_s"][v % 3] if Art.has("nature", "tree_bare") else ["oak", "pine", "oak"][v % 3]
	return ["oak", "pine", "oak"][v % 3]


static func bush_sprite(berries: bool) -> String:
	match season():
		"fall": return "berry_bush_fall" if berries else "bush_fall_orange"
		"winter": return "berry_bush_snow" if berries else "bush_snow"
		"summer": return "bush_red" if berries else "bush"
	return "berry_bush" if berries else "bush"


## Weather is rolled per day from the day number so it's stable across scenes.
static func weather_today() -> String:
	var d := int(run.get("day", 1))
	var r := (d * 7919) % 100
	match season():
		"spring": return "rain" if r < 22 else ("petals" if r < 32 else "clear")
		"summer": return "rain" if r < 12 else ("fireflies" if r < 40 else "clear")
		"fall": return "rain" if r < 20 else ("leaves" if r < 60 else "clear")
		"winter": return "snow" if r < 45 else "clear"
	return "clear"


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
	if has_perk("bartering", "Crystal Baron"):
		run["crystals"] = int(run["crystals"] * 1.01)
	var total := 0
	for id in run["sellbox"].keys():
		var n: int = int(run["sellbox"][id])
		var v := int(round(item_value(id) * n * sell_multiplier()))
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
			if tile.get("watered", false) or weather_today() == "rain":
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

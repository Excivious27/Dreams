extends GameMap
## Your plot of land, Sun Haven scale: a big open field with a crooked house,
## a mailbox, a shipping bin and nothing else. The rest is weeds, rocks, logs
## and trees to clear (progress is saved). Buildings and crafting stations are
## added later from the plans board. Farming works on any open grass cell.
## Exits: forest (north), meadow (east), town (south), lake (west).

const HOUSE := Rect2i(10, 6, 6, 5)
const DOOR := Vector2i(13, 10)
const MAILBOX := Vector2i(16, 10)
const SELLBOX := Vector2i(8, 10)
const PLANS := Vector2i(18, 10)
const CRYSTAL_SPOT := Vector2i(12, 14)
const POND_C := Vector2(48.0, 37.0)
const LEDGE_Y := 11
const LEDGE_X0 := 38
const STAIRS_X := 52
const TOWN_EXIT := Rect2i(34, 58, 4, 2)
const MEADOW_EXIT := Rect2i(70, 28, 2, 4)
const FOREST_EXIT := Rect2i(34, 0, 4, 2)
const LAKE_EXIT := Rect2i(0, 28, 2, 4)
## Buildable things: name -> {cell, w, h, cost, group, sprite, thing}
const BUILDS := {
	"workbench": {"cell": Vector2i(6, 13), "w": 1, "h": 1, "cost": {"wood": 20}, "group": "props", "sprite": "workbench3", "thing": "workbench", "label": "Workbench (20 wood)"},
	"chest": {"cell": Vector2i(9, 13), "w": 0, "h": 1, "cost": {"wood": 10}, "group": "props", "sprite": "chest_closed", "thing": "chest", "label": "Storage chest (10 wood)"},
	"furnace": {"cell": Vector2i(8, 13), "w": 0, "h": 1, "cost": {"stone": 20, "copper": 5}, "group": "props", "sprite": "furnace2_off", "thing": "furnace", "label": "Furnace (20 stone, 5 copper ore)"},
	"well": {"cell": Vector2i(19, 13), "w": 0, "h": 1, "cost": {"stone": 30}, "group": "props", "sprite": "well_roofed", "thing": "well", "label": "Well (30 stone)"},
	"keg": {"cell": Vector2i(6, 15), "w": 0, "h": 1, "cost": {"wood": 30, "copper_bar": 1}, "group": "props", "sprite": "keg2", "thing": "keg", "label": "Keg (30 wood, 1 copper bar)"},
	"beehive": {"cell": Vector2i(21, 15), "w": 0, "h": 1, "cost": {"wood": 15, "fiber": 10}, "group": "props", "sprite": "beehive3_a", "thing": "beehive", "label": "Beehive (15 wood, 10 fiber)"},
	"resonator": {"cell": Vector2i(16, 16), "w": 0, "h": 1, "cost": {"stone": 10, "shard": 1}, "group": "props", "sprite": "resonator", "thing": "resonator", "label": "Crystal resonator (10 stone, 1 shard)"},
	"scarecrow": {"cell": Vector2i(22, 12), "w": 0, "h": 1, "cost": {"wood": 8, "fiber": 4}, "group": "props", "sprite": "scarecrow_classic", "thing": "", "label": "Scarecrow (8 wood, 4 fiber)"},
	"coop": {"cell": Vector2i(26, 8), "w": 3, "h": 3, "cost": {"wood": 120, "stone": 40}, "group": "props", "sprite": "coop_small", "thing": "", "label": "Coop (120 wood, 40 stone) - chickens"},
	"barn": {"cell": Vector2i(32, 5), "w": 4, "h": 3, "cost": {"wood": 200, "stone": 80}, "group": "props", "sprite": "barn_small", "thing": "", "label": "Barn (200 wood, 80 stone) - cows & sheep"},
	"silo": {"cell": Vector2i(30, 4), "w": 1, "h": 3, "cost": {"stone": 60, "wood": 30}, "group": "props", "sprite": "silo2", "thing": "", "label": "Silo (60 stone, 30 wood)"},
	"fish_pond": {"cell": Vector2i(26, 16), "w": 2, "h": 2, "cost": {"stone": 80, "wood": 20}, "group": "props", "sprite": "fish_pond", "anim": "fish_pond", "thing": "water", "label": "Fish pond (80 stone, 20 wood) - fish at home"},
	"shed": {"cell": Vector2i(6, 20), "w": 2, "h": 2, "cost": {"wood": 80, "stone": 20}, "group": "props", "sprite": "shed", "thing": "chest", "label": "Shed (80 wood, 20 stone) - big storage"},
	"stable": {"cell": Vector2i(32, 11), "w": 3, "h": 3, "cost": {"wood": 150, "iron_bar": 2}, "group": "props", "sprite": "stable2", "thing": "", "label": "Stable (150 wood, 2 iron bars) - a horse, soon"},
	"mill": {"cell": Vector2i(26, 2), "w": 2, "h": 4, "cost": {"wood": 120, "stone": 60}, "group": "props", "sprite": "windmill3", "anim": "windmill3", "thing": "", "label": "Mill (120 wood, 60 stone)"},
	"greenhouse": {"cell": Vector2i(20, 4), "w": 3, "h": 3, "cost": {"wood": 150, "stone": 100, "iron_bar": 2}, "group": "props", "sprite": "greenhouse2", "anim": "greenhouse2", "thing": "", "label": "Greenhouse (150 wood, 100 stone, 2 iron bars)"},
}

var _pond_cells := {}
var _ledge_cells := {}
var _path_cells := {}
var _crystal: Node2D
var _fishing := false
var _fish_bite := false
var _crystal_t := 0.0
var _rng := RandomNumberGenerator.new()


func scene_id() -> String:
	return "farm"


func default_spawn() -> Vector2:
	return cell_center(Vector2i(13, 13))


func build() -> void:
	cols = 72
	rows = 60
	pad = 6
	border = {"n": "trees", "s": "trees", "w": "trees", "e": "cliff"}
	music_track = "farm"
	add_exit(TOWN_EXIT, "town", Vector2(40 * TILE, 3 * TILE), "down", "▼ town")
	add_exit(MEADOW_EXIT, "meadow", Vector2(2 * TILE, 10 * TILE), "right", "meadow ▶")
	add_exit(FOREST_EXIT, "forest", Vector2(36 * TILE, 46 * TILE + 8), "up", "▲ forest")
	add_exit(LAKE_EXIT, "lake", Vector2(34 * TILE, 14 * TILE), "left", "◀ lake")
	block_rect(HOUSE.position.x, HOUSE.position.y, HOUSE.size.x, HOUSE.size.y)
	set_thing(DOOR.x, DOOR.y, {"type": "door", "hint": "A: go inside"})
	set_thing(MAILBOX.x, MAILBOX.y, {"type": "mailbox", "hint": "A: check mailbox"})
	set_thing(SELLBOX.x, SELLBOX.y, {"type": "sellbox", "hint": "A: shipping bin (sell what you hold)"})
	set_thing(PLANS.x, PLANS.y, {"type": "plans", "hint": "A: building plans"})
	# Pond: an organic blob.
	_rng.seed = 404
	for y in range(int(POND_C.y) - 6, int(POND_C.y) + 7):
		for x in range(int(POND_C.x) - 8, int(POND_C.x) + 9):
			var d := Vector2((x - POND_C.x) / 7.0, (y - POND_C.y) / 4.5).length()
			if d + _rng.randf_range(-0.12, 0.12) < 1.0:
				_pond_cells[Vector2i(x, y)] = true
	# Pond cells need to be a solid shape with no 1-wide bits for the autotiler.
	for c: Vector2i in _pond_cells.keys():
		set_thing(c.x, c.y, {"type": "water", "hint": "A: fish" if GameState.has_tool("rod") else ""})
	# Raised terrace in the north-east with a cliff ledge and stairs down.
	for x in range(LEDGE_X0, cols):
		var c := Vector2i(x, LEDGE_Y)
		if x == STAIRS_X or x == STAIRS_X + 1:
			continue
		_ledge_cells[c] = true
		blocked[c] = true
	for y in range(0, LEDGE_Y):
		var c := Vector2i(LEDGE_X0, y)
		if y < 3:
			continue
		_ledge_cells[c] = true
		blocked[c] = true
	# Paths (dirt): door to south exit, and the east-west track.
	_path_cells = cells_of([Rect2i(13, 11, 1, 20), Rect2i(13, 30, 24, 2), Rect2i(35, 30, 2, 28), Rect2i(2, 29, 70, 2), Rect2i(35, 2, 2, 28), TOWN_EXIT, MEADOW_EXIT, FOREST_EXIT, LAKE_EXIT])
	for c: Vector2i in _pond_cells:
		_path_cells.erase(c)
	# Everything you've built so far.
	var builds: Dictionary = GameState.run.get("builds", {})
	for id: String in builds:
		var b: Dictionary = BUILDS.get(id, {})
		if b.is_empty():
			continue
		var c: Vector2i = b["cell"]
		block_rect(c.x, c.y - int(b["h"]) + 1, int(b["w"]) + 1, int(b["h"]))
		if str(b["thing"]) != "":
			set_thing(c.x, c.y, {"type": str(b["thing"]), "hint": "A: " + str(id)})
	if GameState.is_penguins() and bool(GameState.run["intro_done"]):
		set_thing(CRYSTAL_SPOT.x, CRYSTAL_SPOT.y, {"type": "crystal", "hint": "A: talk to the Light Crystal"})
	_place_debris()


## Weeds, rocks, logs, stumps and saplings all over the field, thicker away from
## the house. Deterministic from a seed; cleared cells are remembered in the save.
func _place_debris() -> void:
	_rng.seed = 77
	var home := Vector2(DOOR)
	for y in range(1, rows - 1):
		for x in range(1, cols - 1):
			var c := Vector2i(x, y)
			if blocked.has(c) or things.has(c) or _path_cells.has(c) or _pond_cells.has(c) or _ledge_cells.has(c):
				continue
			if HOUSE.grow(2).has_point(c) or c.distance_to(CRYSTAL_SPOT) < 3:
				continue
			var near_pond := false
			for pc: Vector2i in _pond_cells:
				if pc.distance_to(c) < 2.0:
					near_pond = true
					break
			if near_pond:
				continue
			var dist := Vector2(c).distance_to(home)
			# Stardew/Sun Haven start: the farm is properly overrun. Thick near the
			# edges, a cleared ring round the house and the first plot by the door.
			var chance := clampf(0.12 + dist / 70.0 * 0.26, 0.12, 0.36)
			if dist < 9.0:
				chance = 0.03
			var r := _rng.randf()
			if r > chance:
				continue
			if is_cleared(c):
				continue
			var k := _rng.randf()
			if k < 0.40:
				things[c] = {"type": "weeds", "hint": "A: pull weeds"}
				blocked[c] = true
			elif k < 0.62:
				things[c] = {"type": "rock", "hp": 2, "hint": "A: break rock"}
				blocked[c] = true
			elif k < 0.76:
				things[c] = {"type": "log" if _rng.randf() < 0.6 else "stump", "hp": 2, "hint": "A: chop"}
				blocked[c] = true
			elif k < 0.94:
				things[c] = {"type": "tree", "hp": 4, "fell": true, "hint": "A: chop down"}
				blocked[c] = true
			else:
				var key := "bush_farm_%d_%d" % [c.x, c.y]
				var has := int(GameState.run["flags"].get(key, 0)) < int(GameState.run["day"])
				things[c] = {"type": "bush", "key": key, "berries": has, "hint": "A: pick berries" if has else ""}
				blocked[c] = true


func after_ready() -> void:
	WorldGen.add_backdrop(self, "hills")
	_place_props()
	if GameState.is_penguins() and bool(GameState.run["intro_done"]):
		_make_crystal()
	if not bool(GameState.run["intro_done"]):
		_intro.call_deferred()


func _make_crystal() -> void:
	_crystal = Node2D.new()
	_crystal.position = cell_center(CRYSTAL_SPOT)
	_crystal.draw.connect(func() -> void:
		var c := _crystal
		var glow := 0.5 + 0.5 * sin(_crystal_t * 2.0)
		c.draw_circle(Vector2(0, -8), 11.0 + glow * 2.0, Color(0.6, 0.85, 1.0, 0.18))
		var pts := PackedVector2Array([Vector2(0, -20), Vector2(5, -10), Vector2(0, 2), Vector2(-5, -10)])
		c.draw_colored_polygon(pts, Color(0.75, 0.9, 1.0))
		c.draw_colored_polygon(PackedVector2Array([Vector2(0, -20), Vector2(5, -10), Vector2(0, -8)]), Color(1, 1, 1, 0.8))
		c.draw_circle(Vector2(0, 1), 5.0, Color(0, 0, 0, 0.2)))
	add_child(_crystal)


func _process(delta: float) -> void:
	super(delta)
	if _crystal:
		_crystal_t += delta
		_crystal.position.y = cell_center(CRYSTAL_SPOT).y - 3.0 - sin(_crystal_t * 1.5) * 2.0
		_crystal.queue_redraw()


# ---- interaction -------------------------------------------------------------

func interact(c: Vector2i, thing: Dictionary) -> bool:
	var sel := str(GameState.run["selected"])
	match str(thing.get("type", "")):
		"door":
			go_to("house", Vector2(8 * TILE + 8, 10 * TILE), "up")
			return true
		"mailbox":
			_mailbox()
			return true
		"sellbox":
			_sellbox(sel)
			return true
		"water":
			if GameState.held_tool() == "rod" and not _fishing:
				_fish()
			elif GameState.has_tool("rod"):
				hud.toast("Hold the fishing rod.")
			return true
		"well":
			if int(GameState.run["flags"].get("well_day", 0)) < int(GameState.run["day"]):
				GameState.run["flags"]["well_day"] = int(GameState.run["day"])
				GameState.restore_energy(20)
				hud.toast("Cold water. +20 energy.")
			else:
				hud.toast("You already drank today.")
			return true
		"crystal":
			_talk_crystal()
			return true
		"workbench":
			_workbench()
			return true
		"furnace":
			_furnace()
			return true
		"chest":
			_sellbox_like_chest()
			return true
		"beehive":
			_daily_pickup("beehive", "honey", "The bees are still working.")
			return true
		"keg":
			_keg(sel)
			return true
		"resonator":
			_resonator(sel)
			return true
		"plans":
			_plans()
			return true
		"":
			# Open grass in front of you: farm it (hoe / seeds / water / harvest).
			if _tillable(c) and _farm_tile(c, sel):
				return true
	# Nothing in front of you: eat/drink what you hold.
	return use_consumable(sel)


## Any free grass cell inside the field can be tilled, Stardew-style.
func can_till(c: Vector2i) -> bool:
	return _tillable(c) and not things.has(c) and not blocked.has(c)


func _tillable(c: Vector2i) -> bool:
	if not in_content(c) or blocked.has(c) or _path_cells.has(c) or _pond_cells.has(c) or _ledge_cells.has(c):
		return false
	if c.y <= LEDGE_Y and c.x >= LEDGE_X0:
		return false  # the terrace is for later
	for e in exits:
		if (e["rect"] as Rect2i).has_point(c):
			return false
	return true


func _plans() -> void:
	var builds: Dictionary = GameState.run.get("builds", {})
	var ids: Array = []
	var opts: Array = []
	for id: String in BUILDS:
		if builds.has(id):
			continue
		ids.append(id)
		opts.append(str(BUILDS[id]["label"]))
	if ids.is_empty():
		await say([{"text": "You've built everything on the plans. (Tom: more plans come with Guide #3.)"}])
		return
	opts.append("Leave")
	var d := Dialogue.instance(get_tree())
	d.say([{"who": "Plans", "text": "Build what? Clearing the field gives you the wood and stone.", "choice": opts, "key": ""}])
	await d.finished
	var i := d.last_choice
	if i < 0 or i >= ids.size():
		return
	var id := str(ids[i])
	var b: Dictionary = BUILDS[id]
	for need: String in b["cost"]:
		if GameState.count(need) < int(b["cost"][need]):
			hud.toast("Need %d %s." % [int(b["cost"][need]), GameState.item_name(need)], Color(1, 0.7, 0.7))
			return
	for need: String in b["cost"]:
		GameState.add_item(need, -int(b["cost"][need]))
	builds[id] = true
	GameState.run["builds"] = builds
	xp("building", 10)
	hud.toast("Built the %s." % id, Color(1, 0.9, 0.4))
	fx("levelup", cell_center(b["cell"]) + Vector2(0, -10), 10.0, 0.8)
	GameState.save()
	# Simplest reliable refresh: reload the scene in place.
	GameMap.next_spawn = player.position - offset()
	GameMap.next_facing = player.facing
	get_tree().reload_current_scene()


func _farm_tile(c: Vector2i, sel: String) -> bool:
	var key := "%d,%d" % [c.x, c.y]
	var farm: Dictionary = GameState.run["farm"]
	var tile: Dictionary = farm.get(key, {})
	if tile.is_empty():
		if GameState.held_tool() != "hoe":
			return false
		if not GameState.spend_for("hoe"):
			hud.toast("Too tired.", Color(1, 0.7, 0.7))
			return true
		farm[key] = {"watered": false, "crop": "", "days": 0}
		player.play_tool("hoe")
		Music.instance(get_tree()).sfx("dig")
		xp("farming", 1)
		queue_redraw()
		return true
	var crop := str(tile.get("crop", ""))
	if crop == "":
		var it: Dictionary = GameState.items.get(sel, {})
		if it.get("type", "") == "seed" and GameState.count(sel) > 0:
			tile["crop"] = str(it["crop"])
			tile["days"] = 0
			GameState.add_item(sel, -1)
			player.play_tool("hoe")
			Music.instance(get_tree()).sfx("plant")
			fx("sprout_pop", cell_center(c), 8.0, 0.5)
			xp("farming", 2)
			queue_redraw()
			return true
		if not bool(tile.get("watered", false)):
			return _water(tile)
		hud.toast("Hold seeds (MENU) to plant here.")
		return true
	var cd: Dictionary = GameState.crops[crop]
	if int(tile["days"]) >= int(cd["days"]):
		var n := 1 + (1 if randf() < 0.03 * GameState.skill_level("farming") + GameState.bonus("farming", "extra_crop") else 0)
		if randf() < GameState.bonus("farming", "double_harvest"):
			n *= 2
		give(str(cd["yield"]), n)
		if randf() < GameState.bonus("farming", "seed_back") and GameState.items.has(crop + "_seed"):
			give(crop + "_seed", 1)
		player.play_tool("hold")
		xp("farming", 6)
		tile["crop"] = ""
		tile["days"] = 0
		_check_first_harvest()
		queue_redraw()
		return true
	if not bool(tile.get("watered", false)):
		return _water(tile)
	hud.toast("%s: %d more day%s." % [cd["name"], int(cd["days"]) - int(tile["days"]), "" if int(cd["days"]) - int(tile["days"]) == 1 else "s"])
	return true


func _water(tile: Dictionary) -> bool:
	if GameState.held_tool() != "can":
		if GameState.has_tool("can") and str(GameState.run["selected"]) == "":
			hud.toast("Hold the watering can.")
		return false
	if not GameState.spend_for("can"):
		hud.toast("Too tired.", Color(1, 0.7, 0.7))
		return true
	tile["watered"] = true
	player.play_tool("water")
	Music.instance(get_tree()).sfx("water")
	queue_redraw()
	return true


func _check_first_harvest() -> void:
	if GameState.complete_quest("first_harvest"):
		hud.toast("Quest done: first harvest!", Color(1, 0.9, 0.4))
		GameState.run["crystals"] = int(GameState.run["crystals"]) + 25


func _sellbox(sel: String) -> void:
	var box: Dictionary = GameState.run["sellbox"]
	if sel != "" and GameState.count(sel) > 0 and GameState.items.get(sel, {}).get("type", "") != "tool":
		var n := GameState.count(sel)
		box[sel] = int(box.get(sel, 0)) + n
		GameState.add_item(sel, -n)
		hud.toast("Put %d %s in the sell box (◆%d tonight)." % [n, GameState.item_name(sel), n * GameState.item_value(sel)])
		Music.instance(get_tree()).sfx("pickup")
		return
	if box.is_empty():
		await say([{"text": "The sell box is empty. Hold an item (MENU) and press A here to sell it. You get paid in crystals overnight."}])
	else:
		var lines: Array = []
		var total := 0
		for id in box:
			total += GameState.item_value(id) * int(box[id])
		await say([{"text": "In the box: %s. Worth ◆%d, paid tonight." % [", ".join(box.keys().map(func(k: String) -> String: return "%s x%d" % [GameState.item_name(k), int(box[k])])), total]}])


func _mailbox() -> void:
	var flags: Dictionary = GameState.run["flags"]
	var day := int(GameState.run["day"])
	if GameState.is_penguins():
		if not flags.has("mail_1"):
			flags["mail_1"] = true
			await say([
				{"who": "Letter", "text": "Welcome to %s! Stop by the general store when you can. First bag of seeds is on me. - Maple" % GameState.names()["town"]},
			])
			give("strawberry_seed", 3)
			return
		if day >= 3 and not flags.has("mail_2"):
			flags["mail_2"] = true
			await say([{"who": "Letter", "text": "Dear neighbor, something has been howling from the east meadow at night. Mayor Alder says it's nothing. It is not nothing. - Wren"}])
			GameState.add_quest("clear_meadow", "Find out what's howling in the east meadow.")
			return
	else:
		if not flags.has("mail_1"):
			flags["mail_1"] = true
			await say([
				{"who": "Letter", "text": "The plot is yours under the name on the deed. Nobody here knows your real one. Keep it that way. Earn your keep and don't draw eyes. - M."},
			])
			return
		if day >= 3 and not flags.has("mail_2"):
			flags["mail_2"] = true
			await say([{"who": "Letter", "text": "A man came through town asking about a face like yours. He went east, toward the meadow. Be careful. - M."}])
			GameState.add_quest("clear_meadow", "Someone is asking about you. Check the east meadow.")
			return
	await say([{"text": "No new mail."}])


func _talk_crystal() -> void:
	var r := GameState.run
	var d: Dictionary = r["decisions"]
	if not GameState.quest_done("first_harvest"):
		await say([
			{"who": "Light Crystal", "text": "Tend the soil, %s. Every living thing you raise feeds the Meow Pow Wow a little." % GameState.names()["character"]},
			{"who": "Light Crystal", "text": "Till with A. Hold seeds from the MENU and press A to plant. Water each day. The sell box pays you in crystals overnight."},
		])
	elif not GameState.quest_done("clear_meadow"):
		await say([
			{"who": "Light Crystal", "text": "I feel Grumps gathering in the meadow to the east. They are small now. They will not stay small."},
			{"who": "Light Crystal", "text": "Your sword is wood, but your heart is not. Go when you're ready."},
		])
	else:
		await say([
			{"who": "Light Crystal", "text": "The first spark of the Meow Pow Wow is yours. The rest is scattered across this world, and beyond it."},
			{"who": "Light Crystal", "text": "Tom hasn't written the next chapter yet. (Really. That's the next guide.)"},
		])


# ---- crafting ----------------------------------------------------------------

func _workbench() -> void:
	await Crafting.run(self, "workbench", "Workbench")


func _furnace() -> void:
	await Crafting.run(self, "smith", "Furnace")
	var fc: Vector2i = BUILDS["furnace"]["cell"]
	if props.has(fc) and Art.tex("props", "furnace2_on"):
		(props[fc] as Sprite2D).texture = Art.tex("props", "furnace2_on")


func _sellbox_like_chest() -> void:
	# A simple stash: moves everything that isn't a tool or seed into the chest, or takes it all back.
	var chest: Dictionary = GameState.run["flags"].get("chest", {})
	if chest.is_empty():
		var moved := 0
		for id in GameState.run["inventory"].keys():
			var t := str(GameState.items.get(id, {}).get("type", ""))
			if t in ["tool", "seed", "potion", "gift"]:
				continue
			chest[id] = GameState.count(id)
			GameState.add_item(id, -GameState.count(id))
			moved += 1
		GameState.run["flags"]["chest"] = chest
		hud.toast("Stored %d stacks in the chest." % moved if moved > 0 else "Nothing to store.")
	else:
		for id in chest:
			GameState.add_item(id, int(chest[id]))
		GameState.run["flags"]["chest"] = {}
		hud.toast("Took everything back out.")


func _daily_pickup(key: String, item: String, wait_msg: String) -> void:
	var day := int(GameState.run["day"])
	if int(GameState.run["flags"].get(key, 0)) < day - 2:
		GameState.run["flags"][key] = day
		give(item)
		xp("farming", 2)
	else:
		hud.toast(wait_msg)


func _keg(sel: String) -> void:
	var keg: Dictionary = GameState.run["flags"].get("keg", {})
	var day := int(GameState.run["day"])
	if not keg.is_empty():
		if day >= int(keg["ready"]):
			GameState.run["flags"]["keg"] = {}
			give(str(keg["out"]))
			xp("farming", 5)
		else:
			hud.toast("Fermenting... %d more day(s)." % (int(keg["ready"]) - day))
		return
	var out := {"strawberry": "strawberry_wine", "corn": "corn_ale", "berry": "berry_juice", "dreamflower": "dream_tonic"}
	if out.has(sel) and GameState.count(sel) > 0:
		GameState.add_item(sel, -1)
		GameState.run["flags"]["keg"] = {"out": out[sel], "ready": day + 3}
		hud.toast("The keg bubbles. Come back in 3 days.")
	else:
		hud.toast("Hold a fruit or crop and press A to start a brew.")


func _resonator(sel: String) -> void:
	if sel == "shard" and GameState.count("shard") >= 3:
		GameState.add_item("shard", -3)
		give("crystal_refined")
		xp("mining", 8)
		fx("pawring", cell_center(BUILDS["resonator"]["cell"]) + Vector2(0, -12), 10.0, 0.6)
	else:
		hud.toast("Hold 3 Crystal Shards to refine one.")


# ---- fishing -----------------------------------------------------------------

func _fish() -> void:
	if not GameState.spend_for("rod"):
		hud.toast("Too tired.", Color(1, 0.7, 0.7))
		return
	_fishing = true
	_fish_bite = false
	player.play_tool("cast")
	player.frozen = true
	hud.toast("Casting... wait for the !")
	var bob: AnimatedSprite2D = null
	if Art.has("fx", "bobber"):
		bob = AnimatedSprite2D.new()
		var b2 := Art.has("fx", "bobber2")
		bob.sprite_frames = Art.frames("fx", {"bobber": "bobber2" if b2 else "bobber", "bite": "bobber2_bite" if b2 else "bobber_bite"}, {"bobber": 4.0, "bite": 8.0})
		bob.animation = "bobber"
		bob.scale = Vector2(0.5, 0.5)
		bob.position = cell_center(player.facing_cell()) + Vector2(0, -6)
		bob.z_index = 1
		add_child(bob)
		bob.play("bobber")
	var wait := randf_range(1.5, 4.0)
	var t := 0.0
	var caught := false
	while t < wait + 1.0:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		if not _fish_bite and t >= wait:
			_fish_bite = true
			hud.toast("!!!  Press A!", Color(1, 1, 0.4))
			fx("alert", player.position + Vector2(0, -26), 10.0, 0.5)
			Music.instance(get_tree()).sfx("bite")
			if bob:
				bob.play("bite")
		if Input.is_action_just_pressed("a") and t > 0.2:
			if _fish_bite:
				caught = true
			break
	player.frozen = false
	_fishing = false
	if bob:
		fx("reel_splash" if Art.has("fx", "reel_splash") else "splash", bob.position, 12.0, 0.5)
		if caught and Art.has("fx", "fish_jump_a"):
			fx(["fish_jump_a", "fish_jump_b", "fish_jump_c"][randi() % 3], bob.position + Vector2(0, 4), 12.0, 0.5, player.facing == "left")
		bob.queue_free()
	if caught:
		var roll := randf()
		var lvl := GameState.skill_level("fishing")
		var fish := "boot"
		if roll >= 0.12:
			var pool: Array = ["sunfish", "carp", "minnow", "trout", "bass", "catfish", "salmon", "eel", "puffer", "goldfish", "starfin", "mooncarp"]
			var reach := mini(pool.size(), 3 + lvl * 2)
			fish = pool[randi() % reach]
		player.play_tool("reel")
		give(fish)
		xp("fishing", 4)
	else:
		hud.toast("It got away.")


# ---- story -------------------------------------------------------------------

func _intro() -> void:
	player.frozen = true
	var n := GameState.names()
	if GameState.is_penguins():
		await _intro_penguins(n)
	else:
		await _intro_gangsters(n)
	GameState.run["intro_done"] = true
	GameState.save()
	player.frozen = false


func _intro_penguins(n: Dictionary) -> void:
	var who: String = n["character"]
	var pet_name: String = n["pet"]
	var town: String = n["town"]
	await say([
		{"text": "Far past the edge of the sky, something fell."},
		{"text": "It crossed a thousand dark skies, dimmer with every one, looking for a place that still had joy in it."},
		{"text": "It found %s. It found a little plot of land with a crooked house. It found you, %s." % [town, who]},
	])
	await hud.fade_out(0.6)
	_make_crystal()
	set_thing(CRYSTAL_SPOT.x, CRYSTAL_SPOT.y, {"type": "crystal", "hint": "A: talk to the Light Crystal"})
	player.position = cell_center(Vector2i(13, 15))
	player.facing = "up"
	if pet:
		pet.position = player.position + Vector2(-14, 4)
	await hud.fade_in(0.8)
	Music.instance(get_tree()).sfx("levelup")
	await say([
		{"who": "???", "text": "...you can hear me? Good. Good. I was starting to think I'd landed on a world of rocks."},
		{"who": "Light Crystal", "text": "I am a Light Crystal. Where I come from, we are the memory of every kind thing anyone ever did. We are... fewer than we were."},
		{"who": "Light Crystal", "text": "One of us went dark. It calls itself the Dark Crystal now. It turned others. It built an army of Grumps whose only job is to squeeze the joy out of everything, world by world."},
		{"who": "Light Crystal", "text": "I carry the last piece of something that can stop it. A power called the Meow Pow Wow. Most of it is scattered. I can only give you the first spark."},
		{"who": "Light Crystal", "text": "I need someone with their feet in the dirt and their heart in the right place. The question is whether that's you."},
		{"who": "Light Crystal", "text": "So. %s. Will you help me?" % who, "choice": ["I'll help. Where do we start?", "I just want to farm in peace.", "Who said I'd trust a talking rock?"], "key": "crystal_answer"},
	])
	var ans := int(GameState.run["decisions"].get("crystal_answer", 0))
	if ans == 0:
		await say([
			{"who": "Light Crystal", "text": "Then we start small. Here, in this soil. The Meow Pow Wow grows from living things, so grow living things."},
		])
		GameState.run["crystals"] = int(GameState.run["crystals"]) + 10
		GameState.run["flags"]["crystal_trust"] = 2
	elif ans == 1:
		await say([
			{"who": "Light Crystal", "text": "...Peace. Yes. That's exactly what the Grumps will take first. Farm, then. I'll wait. I'm very good at waiting."},
		])
		GameState.run["flags"]["crystal_trust"] = 1
	else:
		await say([
			{"who": "Light Crystal", "text": "Fair. I wouldn't either. I'll be here, glowing uselessly in your yard, until you change your mind."},
			{"who": "Light Crystal", "text": "...I am not a rock."},
		])
		GameState.run["flags"]["crystal_trust"] = 0
	await say([
		{"who": "Light Crystal", "text": "That little one by your feet - %s, is it? - has more Meow Pow Wow in one paw than this whole valley. Keep them close." % pet_name},
		{"who": "Light Crystal", "text": "Till the ground with A. Plant seeds from your MENU. Water every morning. When your first crop comes in, we'll talk again."},
	])
	GameState.add_quest("first_harvest", "Grow and harvest your first crop.")
	GameState.add_quest("meet_town", "Walk south and meet the people of %s." % town)
	hud.toast("New quests. Open MENU to see them.", Color(1, 0.9, 0.4))


func _intro_gangsters(n: Dictionary) -> void:
	var who: String = n["character"]
	var pet_name: String = n["pet"]
	var town: String = n["town"]
	Music.instance(get_tree()).play("rain")
	await say([
		{"text": "Rain. The kind that gets in under your collar and stays."},
		{"text": "You came up the south road after dark so nobody in %s would see your face. The deed in your pocket has a name on it that isn't yours." % town},
		{"text": "A crooked house. A plot of mud. A mailbox. This is what's left of your life, %s." % who},
		{"text": "Somewhere a long way from here, the man who took the rest of it is probably sleeping very well."},
	])
	await hud.fade_out(0.6)
	player.position = cell_center(Vector2i(14, 13))
	player.facing = "up"
	if pet:
		pet.position = player.position + Vector2(-14, 4)
	await hud.fade_in(0.8)
	await say([
		{"text": "There's a letter in the mailbox. You already know who it's from. M. is the only one who knows you're alive."},
		{"text": "The envelope has something written on the back, in a hand you don't recognize:"},
		{"who": "Unknown hand", "text": "\"WE KNOW WHERE YOU WENT.\""},
		{"who": who, "text": "...", "choice": ["Burn the letter. Leave no trail.", "Keep it. Evidence is evidence.", "Read it twice. Memorize the handwriting."], "key": "letter"},
	])
	var ans := int(GameState.run["decisions"].get("letter", 0))
	if ans == 0:
		await say([{"text": "You burn it in the sink. The handwriting goes with it. Whoever they are, they'll have to find you the hard way."}])
		GameState.run["flags"]["letter"] = "burned"
	elif ans == 1:
		await say([{"text": "You fold it into the deed. If this goes to court someday, or to a grave, it goes with you."}])
		GameState.run["flags"]["letter"] = "kept"
	else:
		await say([{"text": "The loops on the W. The hard press on the K. You'll know it when you see it again. You're sure you will."}])
		GameState.run["flags"]["letter"] = "memorized"
	await say([
		{"text": "%s shakes the rain off and looks up at you like all of this is normal. Maybe for a while it can be." % pet_name},
		{"text": "You'll need money to move on anyone. Money means crops. Crops mean dirt under your nails. Fine."},
		{"text": "Till with A. Hold seeds from the MENU and press A to plant. Water each morning. Sell at the box. Don't draw eyes."},
	])
	GameState.add_quest("first_harvest", "Grow and sell something. You need ◆200 before you can do anything.")
	GameState.add_quest("meet_town", "Go south. Learn who in %s can be bought, and who is watching." % town)
	hud.toast("New quests. Open MENU to see them.", Color(1, 0.9, 0.4))


# ---- drawing -----------------------------------------------------------------

func draw_map() -> void:
	draw_grass(1)
	WorldGen.draw_ground_detail(self, 21, 0.05)
	draw_ground("dirt", _path_cells)
	# Terrace: a lighter, drier grass up top and a cliff lip along the ledge.
	draw_ground("stone", cells_of([Rect2i(LEDGE_X0 + 1, 1, 6, 3)]))
	draw_water(_pond_cells, "grass")
	if Art.has("tiles", "t_cliffg"):
		var top := {}
		for y in range(0, LEDGE_Y):
			for x in range(LEDGE_X0 + 1, cols):
				top[Vector2i(x, y)] = true
		for y in range(0, 3):
			top[Vector2i(LEDGE_X0, y)] = true
		draw_plateau(top, "cliffg", {Vector2i(STAIRS_X, LEDGE_Y): true, Vector2i(STAIRS_X + 1, LEDGE_Y): true})
	else:
		for c: Vector2i in _ledge_cells:
			var t := Art.tex("tiles", "cliff2_1")
			if t:
				draw_texture_rect(t, Rect2(c.x * TILE, (c.y - 1) * TILE, TILE, TILE * 2), false)
	if not Art.has("tiles", "t_cliffg"):
		Art.draw_prop(self, "props", "cliff_stairs_down", Vector2((STAIRS_X + 1) * TILE, (LEDGE_Y + 1) * TILE))
	draw_exits()
	var farm: Dictionary = GameState.run["farm"]
	for key in farm:
		var parts: PackedStringArray = str(key).split(",")
		var c := Vector2i(int(parts[0]), int(parts[1]))
		var tile: Dictionary = farm[key]
		var wet := bool(tile.get("watered", false))
		if not Art.draw_tile(self, "tiles", "tilled_wet" if wet else "tilled_dry", Vector2(c * TILE), 4):
			draw_rect(Rect2(c * TILE + Vector2i(1, 1), Vector2i(TILE - 2, TILE - 2)), Color("5c3d22") if wet else Color("8a5f38"))
		var crop := str(tile.get("crop", ""))
		if crop != "":
			var cd: Dictionary = GameState.crops[crop]
			var frac := clampf(float(tile["days"]) / float(cd["days"]), 0.0, 1.0)
			var stage := mini(4, int(frac * 5.0))
			if frac >= 1.0:
				stage = 4
			var t := Art.tex("crops", crop)
			if Art.has("crops", crop + "_seed"):
				# Prompts-09 crops: one sprite per stage (seed, sprout, young, growing, mature, ready).
				var st: String = ["seed", "sprout", "young", "growing", "mature", "ready"][mini(5, int(frac * 6.0)) if frac < 1.0 else 5]
				var tex := Art.tex("crops", "%s_%s" % [crop, st])
				var w2 := tex.get_width() / 2.0
				var h2 := tex.get_height() / 2.0
				draw_texture_rect(tex, Rect2(c.x * TILE + TILE / 2.0 - w2 / 2.0, (c.y + 1) * TILE - h2, w2, h2), false)
			elif t:
				var info := Art.info("crops", crop)
				var cw := int(info.get("cell_w", 32))
				var ch := int(info.get("cell_h", 32))
				var w := cw / 2.0
				var h := ch / 2.0
				draw_texture_rect_region(t, Rect2(c.x * TILE + TILE / 2.0 - w / 2.0, (c.y + 1) * TILE - h, w, h), Rect2(stage * cw, 0, cw, ch))
			else:
				var hgt := 3 + int(frac * 9)
				var cx := c.x * TILE + TILE / 2.0
				var base := (c.y + 1) * TILE - 2.0
				draw_rect(Rect2(cx - 1, base - hgt, 2, hgt), Color(cd["color"]))
				if frac >= 1.0:
					draw_circle(Vector2(cx, base - hgt - 1), 3.0, Color(cd["top"]))
	if not Art.has("buildings", "house"):
		draw_building(HOUSE.position.x, HOUSE.position.y, HOUSE.size.x, HOUSE.size.y, Color("8b5a2b"), Color("b03a2e"), "")


func _place_props() -> void:
	if Art.has("buildings", "house"):
		prop("buildings", "house", Vector2i(HOUSE.position.x, HOUSE.end.y - 1), HOUSE.size.x - 1)
		prop("buildings", "mailbox", MAILBOX)
		prop("buildings", "sellbox", SELLBOX)
	prop("props", "notice_board", PLANS)
	# Built things.
	var builds: Dictionary = GameState.run.get("builds", {})
	for id: String in builds:
		var b: Dictionary = BUILDS.get(id, {})
		if b.is_empty():
			continue
		var c: Vector2i = b["cell"]
		# Tiered station animations (Prompts 09 w177): the station's look follows the
		# crafting tier you've unlocked there.
		var station_anim := ""
		match id:
			"workbench": station_anim = "bench_%d" % clampi(Crafting.tier_unlocked("workbench"), 1, 4)
			"furnace": station_anim = "forge_%d" % clampi(Crafting.tier_unlocked("smith"), 1, 4)
			"keg": station_anim = "cider_press"
			"beehive": station_anim = "honey_extractor"
		if station_anim != "" and Art.has("stations", station_anim):
			var st := AnimatedSprite2D.new()
			st.sprite_frames = Art.frames("stations", {"idle": station_anim}, {"idle": 4.0})
			st.animation = "idle"
			st.scale = Vector2(0.5, 0.5)
			st.position = cell_center(c)
			st.offset = Vector2(0, -float(Art.info("stations", station_anim).get("cell_h", 64)) / 2.0)
			add_child(st)
			st.play("idle")
			blocked[c] = true
			continue
		if b.has("anim") and Art.has("props", str(b["anim"])):
			var sc := AnimatedSprite2D.new()
			sc.sprite_frames = Art.frames("props", {"idle": str(b["anim"])}, {"idle": 5.0})
			sc.animation = "idle"
			sc.scale = Vector2(0.5, 0.5)
			sc.position = cell_center(c)
			sc.offset = Vector2(0, -float(Art.info("props", str(b["anim"])).get("cell_h", 96)) / 2.0)
			add_child(sc)
			sc.play("idle")
		elif id == "resonator" and Art.has("props", "resonator"):
			var a := AnimatedSprite2D.new()
			a.sprite_frames = Art.frames("props", {"idle": "resonator"}, {"idle": 4.0})
			a.animation = "idle"
			a.scale = Vector2(0.5, 0.5)
			a.position = cell_center(c)
			a.offset = Vector2(0, -float(Art.info("props", "resonator").get("cell_h", 80)) / 2.0)
			add_child(a)
			a.play("idle")
		else:
			prop(str(b["group"]), str(b["sprite"]), c, int(b["w"]))
	if builds.has("coop"):
		var pen := Rect2i(26, 9, 6, 3)
		_animal("chicken", Vector2i(27, 10), pen); _animal("chicken", Vector2i(29, 10), pen); _animal("rooster", Vector2i(30, 11), pen); _animal("chick", Vector2i(28, 11), pen, true)
	if builds.has("barn"):
		var pen := Rect2i(32, 6, 8, 4)
		_animal("cow2", Vector2i(33, 7), pen); _animal("cow_bw", Vector2i(36, 8), pen); _animal("sheep2", Vector2i(34, 9), pen); _animal("calf", Vector2i(38, 9), pen, true); _animal("lamb", Vector2i(36, 7), pen, true)
	# Debris sprites for the things placed in build().
	var season := GameState.season()
	for c: Vector2i in things.keys():
		var t: Dictionary = things[c]
		match str(t.get("type", "")):
			"weeds":
				prop("nature", "bush_bare_snow" if season == "winter" and Art.has("nature", "bush_bare_snow") else ("fdeco_%d" % ((c.x * 3 + c.y) % 4) if Art.has("nature", "fdeco_0") else "bush"), c)
			"rock":
				var nm := "rock_s" if (c.x + c.y) % 3 != 0 else "rock_m"
				if season == "winter" and Art.has("nature", nm.replace("rock_", "rock_snow_")):
					nm = nm.replace("rock_", "rock_snow_")
				prop("nature", nm, c)
			"log":
				var nm: String = {"fall": "log_fall", "summer": "logs"}.get(season, "log")
				prop("nature", nm if Art.has("nature", nm) else "log", c)
			"stump":
				var nm: String = {"fall": "stump_fall", "winter": "stump_snow"}.get(season, "stump")
				prop("nature", nm if Art.has("nature", nm) else "stump", c)
			"tree":
				prop("nature", GameState.tree_sprite((c.x * 7 + c.y) % 3), c)
			"bush":
				prop("nature", GameState.bush_sprite(bool(t.get("berries", false))), c)
	# Background life only: birds, butterflies, a rabbit. No livestock until you build for it.
	WorldGen.add_critters(self, Rect2i(2, 2, cols - 4, rows - 4), 15, 14, ["sparrow", "sparrow", "butterfly_orange", "butterfly_yellow", "bee", "rabbit", "squirrel", "pigeon"])
	# Stray pieces of the old world: a few boulders and a dead tree on the terrace.
	prop("nature", "rock_l", Vector2i(44, 5))
	prop("nature", "rock_m", Vector2i(60, 7))
	prop("nature", "tree_bare" if GameState.season() == "winter" else "dead_tree_m", Vector2i(66, 4))
	prop("props", "signpost_1" if Art.has("props", "signpost_1") else "signpost", Vector2i(32, 56))
	if Art.has("props", "abandoned_cart"):
		prop("props", "abandoned_cart", Vector2i(60, 50), 2)


func _animal(kind: String, c: Vector2i, pen: Rect2i = Rect2i(), is_baby := false) -> void:
	var full: String = {"cow2": "cow_brown", "sheep2": "sheep_woolly", "chicken": "chicken2", "pig": "pig_a", "horse": "horse3"}.get(kind, kind)
	if Art.has("animals/" + full, "idle"):
		var fa := FarmAnimal.new()
		fa.setup(self, str(full), c, pen, is_baby)
		add_child(fa)
		return
	if not Art.has("props", kind):
		return
	var a := AnimatedSprite2D.new()
	a.sprite_frames = Art.frames("props", {"idle": kind}, {"idle": 2.0})
	a.animation = "idle"
	a.scale = Vector2(0.5, 0.5)
	a.position = cell_center(c)
	a.offset = Vector2(0, -float(Art.info("props", kind).get("cell_h", 48)) / 2.0)
	add_child(a)
	a.play("idle")
	blocked[c] = true



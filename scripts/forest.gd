extends GameMap
## The north forest: dense trees, winding path, forage, a woodcutter's clearing,
## a hidden pond, and a shrine. Enemies at dusk. Exits: farm (south), lake (west).

const FARM_EXIT := Rect2i(35, 49, 3, 1)
const LAKE_EXIT := Rect2i(0, 20, 1, 3)
const SHRINE := Vector2i(12, 9)


func scene_id() -> String:
	return "forest"


func default_spawn() -> Vector2:
	return cell_center(Vector2i(36, 46))


func build() -> void:
	cols = 48
	rows = 50
	pad = 8
	border = "trees"
	music_track = "meadow"
	add_exit(FARM_EXIT, "farm", Vector2(36 * TILE, 3 * TILE + 8), "down", "▼ farm")
	add_exit(LAKE_EXIT, "lake", Vector2(45 * TILE, 2 * TILE + 8), "down", "◀ lake")
	add_exit(Rect2i(22, 0, 4, 1), "orchard_hills", Vector2(26 * TILE, 41 * TILE + 8), "up", "▲ orchard hills")
	set_thing(SHRINE.x, SHRINE.y, {"type": "shrine", "hint": "A: forest shrine"})
	# Groves: dense tree masses with dark floor; clearings between them stay open.
	var sd := 61
	for y in range(1, rows - 1):
		for x in range(1, cols - 1):
			var c := Vector2i(x, y)
			if _in_clearing(c) or _on_path(c):
				continue
			var n := WorldGen.fbm(float(x), float(y), sd, 7.0)
			if n > 0.18:
				_grove[c] = true
	# Forage: a few per clearing, respawning (region pools + rarity).
	var rng := RandomNumberGenerator.new()
	rng.seed = 61 + int(GameState.run["day"])
	for i in 18:
		var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(2, rows - 3))
		if things.has(c) or _grove.has(c) or _on_path(c):
			continue
		var key := "forage_forest_%d_%d" % [c.x, c.y]
		var every := 1 if GameState.has_perk("foraging", "Tracker") else 2
		if int(GameState.run["flags"].get(key, 0)) > int(GameState.run["day"]) - every:
			continue
		var item := GameState.roll_forage("forest")
		things[c] = {"type": "forage", "key": key, "item": item, "hint": "A: pick %s" % GameState.item_name(item)}


const CLEARINGS := [[16, 6, 7], [24, 27, 6], [8, 32, 5], [36, 14, 6], [38, 40, 5], [16, 42, 5]]  # x, y, radius
var _grove := {}


func _in_clearing(c: Vector2i) -> bool:
	for cl in CLEARINGS:
		if Vector2(c).distance_to(Vector2(cl[0], cl[1])) < float(cl[2]):
			return true
	return false


func _on_path(c: Vector2i) -> bool:
	return c in _path_cells() or (c + Vector2i(1, 0)) in _path_cells() or (c + Vector2i(-1, 0)) in _path_cells()


func after_ready() -> void:
	WorldGen.add_backdrop(self, "forest")
	var rng := RandomNumberGenerator.new()
	rng.seed = 64
	# Grove trees: every other cell, mix of mid trees, bigger ones in the middle of a mass.
	var placed := 0
	var use_groves := Art.has("nature", "grove_0")
	if use_groves:
		# Composed canopy clusters every ~4 cells inside the grove mass; single trees fill the rest.
		for c: Vector2i in _grove:
			if c.x % 4 != 0 or c.y % 3 != 0:
				continue
			var ok := true
			for dx in range(-1, 3):
				for dy in range(-2, 1):
					if not _grove.has(c + Vector2i(dx, dy)):
						ok = false
			if not ok:
				continue
			var sp := prop("nature", "grove_%d" % rng.randi_range(0, 7), c, 2, rng.randf_range(-2.0, 2.0), false)
			if sp:
				for dx in range(-1, 3):
					for dy in range(-1, 1):
						var cc := c + Vector2i(dx, dy)
						blocked[cc] = true
						# A grove is a wall of old trees: scenery, not 8 choppable trees
						# under one picture (that gave 8× wood and left invisible walls).
						things[cc] = {"type": "grove", "hint": ""}
	for c: Vector2i in _grove:
		if (c.x + c.y) % 2 == 1 or things.has(c) or is_cleared(c):
			continue
		if use_groves and rng.randf() < 0.45:
			continue
		var deep := _grove.has(c + Vector2i(2, 0)) and _grove.has(c + Vector2i(-2, 0)) and _grove.has(c + Vector2i(0, 2)) and _grove.has(c + Vector2i(0, -2))
		var nm := GameState.tree_sprite(rng.randi_range(0, 2))
		if Art.has("nature", "mid_oak"):
			nm = ["mid_oak", "mid_pine", "mid_birch", "mid_oak_b"][rng.randi_range(0, 3)] if not deep or rng.randf() < 0.5 else ["big_oak_a", "big_pine_a", "big_birch_a", "big_oak_b"][rng.randi_range(0, 3)]
		set_thing(c.x, c.y, {"type": "tree", "hp": 3, "hint": "A: chop"})
		prop("nature", nm, c, 0, rng.randf_range(-2.0, 2.0))
		placed += 1
	# Clearing contents: each one has a reason to exist.
	if Art.has("buildings", "great_tree"):
		prop("buildings", "great_tree", Vector2i(14, 5), 6)
		set_thing(16, 6, {"type": "great_tree", "hint": "A: the great tree"}, false)
		things.erase(SHRINE)
		set_thing(12, 9, {"type": "shrine", "hint": "A: forest shrine"})
		prop("nature", "forest_shrine", Vector2i(12, 9), 0, 2.0)
	else:
		prop("nature", "forest_shrine", SHRINE, 0, 2.0)
	if Art.has("buildings", "woodcutter_hut"):
		prop("buildings", "woodcutter_hut", Vector2i(22, 25), 4)
		prop("nature", "stump_axe", Vector2i(27, 27))
		prop("nature", "giant_log", Vector2i(24, 30), 3)
		set_thing(23, 27, {"type": "note", "text": "The woodcutter's hut. Axe in the stump, kettle on, nobody home. A list on the door: 'oak 40, pine 20, birch 10' with the first line crossed out.", "hint": "A: the hut"}, false)
	if Art.has("props", "stone_circle"):
		prop("props", "stone_circle", Vector2i(34, 13), 5)
		set_thing(36, 14, {"type": "note", "text": "Standing stones, older than the town, each carved with a spiral. Stand in the middle and the wind stops.", "hint": "A: the stones"}, false)
	# Hidden pond clearing.
	for y in range(37, 42):
		for x in range(35, 42):
			if Vector2(x, y).distance_to(Vector2(38, 39.5)) < 3.2:
				_pond[Vector2i(x, y)] = true
				set_thing(x, y, {"type": "water", "hint": "A: fish" if GameState.has_tool("rod") else ""})
	prop("nature", "hollow_tree", Vector2i(6, 30), 1)
	set_thing(7, 30, {"type": "note", "text": "A hollow tree big enough to sleep in. Somebody has. There's a blanket and a tin cup.", "hint": "A: look inside"}, false)
	if Art.has("props", "hollow_log"):
		prop("props", "hollow_log", Vector2i(14, 44), 3)
	prop("nature", "berry_thicket", Vector2i(18, 40), 1)
	set_thing(18, 40, {"type": "bush", "key": "forest_thicket", "berries": int(GameState.run["flags"].get("forest_thicket", 0)) < int(GameState.run["day"]), "hint": "A: pick berries"})
	for k in things.keys():
		if str(things[k].get("type", "")) == "forage":
			var it := str(things[k]["item"])
			var nm := "mushrooms_fall" if it in ["mushroom", "glowcap", "truffle"] and Art.has("nature", "mushrooms_fall") else "flowers"
			prop("nature", nm, k)
	# Sparse, purposeful ground props only in clearings.
	var avoid := _grove.duplicate()
	for c in _path_cells():
		avoid[c] = true
	WorldGen.scatter_props(self, Rect2i(3, 3, cols - 6, rows - 6), 65, 10, avoid)
	WorldGen.add_critters(self, Rect2i(3, 3, cols - 6, rows - 6), 66, 10, ["deer", "fox", "rabbit", "squirrel", "hedgehog", "owl", "sparrow", "butterfly_yellow", "crow"])
	if Art.has("props", "lantern_lit"):
		for c: Vector2i in [Vector2i(13, 11), Vector2i(19, 11)]:
			prop("props", "lantern_lit", c)
	var n := GameState.enemy_count(2 + (2 if int(GameState.run["time"]) > 18 * 60 else 0))
	for i in n:
		var at := cell_center(Vector2i(randi_range(6, cols - 7), randi_range(12, rows - 8)))
		if not blocked.has(world_to_cell(at)):
			spawn_enemy("wisp" if GameState.is_penguins() else "thug_speedster", at)
	if not GameState.run["flags"].has("forest_seen"):
		GameState.run["flags"]["forest_seen"] = true
		player.frozen = true
		await say([{"text": "The forest closes over the path. It smells of wet bark and something sweeter. Mushrooms grow in rings here, and something glints between the trees."}])
		player.frozen = false


var _pond := {}


var _path_cache: Array[Vector2i] = []
func _path_cells() -> Array[Vector2i]:
	if not _path_cache.is_empty():
		return _path_cache
	# A hand-laid winding route: farm exit -> pond clearing -> woodcutter -> stones -> great tree, with a spur to the lake.
	var pts := [Vector2i(36, 49), Vector2i(36, 44), Vector2i(32, 40), Vector2i(28, 34), Vector2i(24, 30), Vector2i(20, 24), Vector2i(22, 18), Vector2i(28, 14), Vector2i(24, 10), Vector2i(18, 8), Vector2i(16, 10)]
	var spur := [Vector2i(20, 24), Vector2i(14, 26), Vector2i(8, 28), Vector2i(3, 24), Vector2i(0, 21)]
	for seq in [pts, spur]:
		for i in range(seq.size() - 1):
			var a: Vector2i = seq[i]
			var b: Vector2i = seq[i + 1]
			var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
			for t in steps + 1:
				var p := Vector2(a).lerp(Vector2(b), float(t) / maxf(1.0, steps))
				_path_cache.append(Vector2i(roundi(p.x), roundi(p.y)))
	return _path_cache


func interact(c: Vector2i, thing: Dictionary) -> bool:
	match str(thing.get("type", "")):
		"note":
			tell([{"text": str(thing.get("text", "..."))}])
			return true
		"shrine":
			_shrine()
			return true
		"water":
			hud.toast("Fishing here is coming with the next lake art.")
			return true
		"great_tree":
			if GameState.is_penguins() and (GameState.quest_done("commander") or GameState.has_quest("sky_stair")):
				go_to("sky", Vector2(16 * TILE, 26 * TILE), "up")
			else:
				tell([{"text": "A tree older than the town, with lanterns in its branches and a stair winding up its trunk. The top is out of sight." + (" Something tells you it's not time yet." if GameState.is_penguins() else " The stair is roped off.")}])
			return true
	return false


func _shrine() -> void:
	var sel := str(GameState.run["selected"])
	var day := int(GameState.run["day"])
	if sel != "" and GameState.count(sel) > 0 and GameState.item_value(sel) >= 20:
		GameState.add_item(sel, -1)
		GameState.run["flags"]["shrine_day"] = day
		GameState.run["flags"]["shrine_gifts"] = int(GameState.run["flags"].get("shrine_gifts", 0)) + 1
		fx("pawring" if GameState.is_penguins() else "sparkle", cell_center(SHRINE) + Vector2(0, -10), 10.0, 0.6)
		var gifts := int(GameState.run["flags"]["shrine_gifts"])
		if gifts == 3:
			GameState.grow_vital("energy", 20)
			await say([{"who": "Shrine", "text": "The stone warms under your hand. You feel steadier. (+20 max energy)"}])
		else:
			await say([{"who": "Shrine", "text": "The offering sinks into the stone. Something, somewhere, is pleased."}])
		return
	await say([{"who": "Shrine", "text": "An old stone altar with a pale crystal set in it. Hold something worth at least 20 crystals and press A to offer it." if GameState.is_penguins() else "An old altar. Someone left fresh flowers. Someone in this town still believes in something. Hold an item worth 20+ and press A to leave an offering."}])


func draw_map() -> void:
	draw_grass(6)
	WorldGen.draw_ground_detail(self, 67, 0.06)
	# Dark floor under the groves, soft-edged.
	for c: Vector2i in _grove:
		var hv := absi((c.x * 73856093) ^ (c.y * 19349663))
		if Art.has("tiles", "ffloor_0"):
			Art.draw_tile(self, "tiles", "ffloor_%d" % [[7, 8, 7, 8, 13, 14, 15, 0, 7, 8][hv % 10]], Vector2(c * TILE), 0)
		elif not Art.draw_tile(self, "tiles", "forest_floor", Vector2(c * TILE), 4):
			draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color(0.2, 0.35, 0.18, 0.6))
	for c: Vector2i in _grove:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if not _grove.has(n) and (n.x * 3 + n.y * 5) % 3 != 0:
				Art.draw_tile(self, "tiles", "forest_floor", Vector2(n * TILE), 4)
	var pc := {}
	for c in _path_cells():
		pc[c] = true
		pc[c + Vector2i(1, 0)] = true
	draw_ground("dirt", pc)
	draw_water(_pond, "grass")
	draw_tileset_rect("stone", Rect2i(10, 8, 5, 3), Color("9a9aa6"))
	draw_exits()
	if not Art.has("nature", "forest_shrine"):
		var p := cell_center(SHRINE)
		draw_rect(Rect2(p.x - 14, p.y - 14, 28, 12), Color("7a7a86"))
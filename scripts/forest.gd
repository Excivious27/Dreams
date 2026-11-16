extends GameMap
## The north forest: dense trees, winding path, forage, a woodcutter's clearing,
## a hidden pond, and a shrine. Enemies at dusk. Exits: farm (south), lake (west).

const FARM_EXIT := Rect2i(15, 39, 3, 1)
const LAKE_EXIT := Rect2i(0, 20, 1, 3)
const SHRINE := Vector2i(16, 6)


func scene_id() -> String:
	return "forest"


func default_spawn() -> Vector2:
	return Vector2(16 * TILE, 37 * TILE)


func build() -> void:
	cols = 34
	rows = 40
	pad = 7
	border = "trees"
	music_track = "meadow"
	add_exit(FARM_EXIT, "farm", Vector2(36 * TILE, 3 * TILE + 8), "down", "▼ farm")
	add_exit(LAKE_EXIT, "lake", Vector2(34 * TILE, 6 * TILE), "left", "◀ lake")
	set_thing(SHRINE.x, SHRINE.y, {"type": "shrine", "hint": "A: forest shrine"})
	block_rect(15, 5, 3, 2)
	# Forage spots that respawn daily.
	var rng := RandomNumberGenerator.new()
	rng.seed = 61 + int(GameState.run["day"])
	for i in 14:
		var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(2, rows - 3))
		if things.has(c):
			continue
		var key := "forage_forest_%d_%d" % [c.x, c.y]
		if int(GameState.run["flags"].get(key, 0)) >= int(GameState.run["day"]):
			continue
		var item: String = ["mushroom", "mushroom", "berry", "fiber", "wild_leek"][rng.randi_range(0, 4)]
		things[c] = {"type": "forage", "key": key, "item": item, "hint": "A: pick %s" % GameState.item_name(item)}
	extend(14, 10)


func after_ready() -> void:
	WorldGen.add_backdrop(self, "hills")
	if Art.has("props", "stone_circle"):
		prop("props", "stone_circle", Vector2i(cols - 12, rows - 10), 5)
		set_thing(cols - 10, rows - 9, {"type": "note", "text": "Standing stones, older than the town, each carved with a spiral. Stand in the middle and the wind stops. (Tom: lore door.)", "hint": "A: the stones"}, false)
	if Art.has("props", "hollow_log"):
		prop("props", "hollow_log", Vector2i(6, rows - 6), 3)
	var avoid := {}
	# Winding path: keep it clear.
	for c in _path_cells():
		avoid[c] = true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			avoid[c + d] = true
	for y in range(3, 9):
		for x in range(12, 21):
			avoid[Vector2i(x, y)] = true
	for y in range(24, 31):
		for x in range(22, 31):
			avoid[Vector2i(x, y)] = true
	WorldGen.tree_clumps(self, Rect2i(3, 3, cols - 6, rows - 6), 64, 26, avoid)
	WorldGen.scatter_props(self, Rect2i(3, 3, cols - 6, rows - 6), 65, 30, avoid)
	WorldGen.add_critters(self, Rect2i(3, 3, cols - 6, rows - 6), 66, 12, ["deer", "fox", "rabbit", "squirrel", "hedgehog", "owl", "sparrow", "butterfly_yellow", "crow"])
	for k in things:
		if str(things[k].get("type", "")) == "forage":
			var nm := "mushrooms_fall" if str(things[k]["item"]) == "mushroom" and Art.has("nature", "mushrooms_fall") else "flowers"
			prop("nature", nm, k)
	# Woodcutter's clearing (NE) and the hidden pond (SE).
	if Art.has("buildings", "woodcutter_hut"):
		prop("buildings", "woodcutter_hut", Vector2i(23, 27), 4)
		block_rect(23, 24, 5, 4)
		prop("nature", "stump_axe", Vector2i(29, 27))
		blocked[Vector2i(29, 27)] = true
		prop("nature", "giant_log", Vector2i(4, 30), 3)
		block_rect(4, 30, 4, 1)
	else:
		prop("props", "stall", Vector2i(24, 25), 1)
		block_rect(24, 24, 2, 2)
	prop("nature", "forest_shrine", SHRINE, 0, 2.0)
	if Art.has("buildings", "great_tree"):
		prop("buildings", "great_tree", Vector2i(16, 20), 6)
		block_rect(15, 15, 7, 6)
		set_thing(18, 21, {"type": "great_tree", "hint": "A: the great tree"}, false)
	for c: Vector2i in [Vector2i(6, 12), Vector2i(28, 10), Vector2i(10, 33)]:
		prop("nature", "hollow_tree" if c.x == 6 else ("willow" if c.x == 28 else "big_oak"), c, 1)
		block_rect(c.x, c.y - 1, 2, 2)
	prop("nature", "berry_thicket", Vector2i(21, 34), 1)
	set_thing(21, 34, {"type": "bush", "key": "forest_thicket", "berries": int(GameState.run["flags"].get("forest_thicket", 0)) < int(GameState.run["day"]), "hint": "A: pick berries"})
	var pond := Scenery.Pond.new()
	pond.rect = Rect2(26 * TILE, 30 * TILE, 5 * TILE, 4 * TILE)
	pond.z_index = -1
	add_child(pond)
	for y in range(30, 34):
		for x in range(26, 31):
			set_thing(x, y, {"type": "water", "hint": "A: fish" if GameState.has_tool("rod") else ""})
	if Art.has("props", "lantern_lit"):
		for c: Vector2i in [Vector2i(14, 8), Vector2i(18, 8)]:
			prop("props", "lantern_lit", c)
			blocked[c] = true
	# A few things lurk in the woods (more at night).
	var n := 2 + (2 if int(GameState.run["time"]) > 18 * 60 else 0)
	for i in n:
		var at := Vector2(randf_range(6, 28) * TILE, randf_range(10, 34) * TILE)
		spawn_enemy("wisp" if GameState.is_penguins() else "thug_speedster", at)
	if not GameState.run["flags"].has("forest_seen"):
		GameState.run["flags"]["forest_seen"] = true
		player.frozen = true
		await say([{"text": "The forest closes over the path. It smells of wet bark and something sweeter. Mushrooms grow in rings here, and something glints between the trees."}])
		player.frozen = false


func _path_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var x := 16
	for y in range(39, 8, -1):
		if y % 6 == 0:
			x += (-3 if (y / 6) % 2 == 0 else 3)
		x = clampi(x, 6, cols - 7)
		out.append(Vector2i(x, y))
		out.append(Vector2i(x + 1, y))
	return out


func interact(c: Vector2i, thing: Dictionary) -> bool:
	match str(thing.get("type", "")):
		"note":
			await say([{"text": str(thing.get("text", "..."))}])
			return true
		"shrine":
			_shrine()
			return true
		"water":
			hud.toast("Fishing here is coming with the next lake art.")
			return true
		"great_tree":
			if GameState.is_penguins() and GameState.quest_done("clear_meadow"):
				go_to("sky", Vector2(16 * TILE, 26 * TILE), "up")
			else:
				await say([{"text": "A tree older than the town, with lanterns in its branches and a stair winding up its trunk. The top is out of sight." + (" Something tells you it's not time yet." if GameState.is_penguins() else " The stair is roped off.")}])
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
			GameState.run["max_energy"] = int(GameState.run["max_energy"]) + 20
			await say([{"who": "Shrine", "text": "The stone warms under your hand. You feel steadier. (+20 max energy)"}])
		else:
			await say([{"who": "Shrine", "text": "The offering sinks into the stone. Something, somewhere, is pleased."}])
		return
	await say([{"who": "Shrine", "text": "An old stone altar with a pale crystal set in it. Hold something worth at least 20 crystals and press A to offer it." if GameState.is_penguins() else "An old altar. Someone left fresh flowers. Someone in this town still believes in something. Hold an item worth 20+ and press A to leave an offering."}])


func draw_map() -> void:
	if Art.has("tiles", "forest_floor"):
		for y in rows:
			for x in cols:
				Art.draw_tile(self, "tiles", "forest_floor", Vector2(x * TILE, y * TILE), 4)
		var rng := RandomNumberGenerator.new()
		rng.seed = 68
		for y in range(1, rows - 1):
			for x in range(1, cols - 1):
				if rng.randf() < 0.1:
					Art.draw_prop(self, "nature", "fdeco_%d" % rng.randi_range(0, 9), Vector2(x * TILE + 8, y * TILE + 16))
	else:
		draw_grass(6)
		WorldGen.draw_ground_detail(self, 67, 0.22)
	var pc := {}
	for c in _path_cells():
		pc[c] = true
	for c: Vector2i in pc:
		if not Art.draw_tile(self, "tiles", "forest_path" if Art.has("tiles", "forest_path") else "dirt", Vector2(c * TILE), 4):
			draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color("8a6a40"))
	draw_tileset_rect("stone", Rect2i(13, 4, 7, 5), Color("9a9aa6"))
	draw_exits()
	if not Art.has("nature", "forest_shrine"):
		var p := cell_center(SHRINE)
		draw_rect(Rect2(p.x - 14, p.y - 14, 28, 12), Color("7a7a86"))
		draw_colored_polygon(PackedVector2Array([Vector2(p.x, p.y - 30), Vector2(p.x + 4, p.y - 22), Vector2(p.x, p.y - 17), Vector2(p.x - 4, p.y - 22)]), Color("a8d8ff"))
	if pad == 0:
		draw_fence_border()

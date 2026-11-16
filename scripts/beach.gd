extends GameMap
## The south beach: sand, the sea along the bottom, a pier, shells and coconuts
## to forage, and a wrecked boat. Exit: town (north).

const TOWN_EXIT := Rect2i(13, 0, 3, 1)
const SEA_Y := 20


func scene_id() -> String:
	return "beach"


func default_spawn() -> Vector2:
	return Vector2(14 * TILE, 3 * TILE)


func build() -> void:
	cols = 30
	rows = 28
	music_track = "town"
	add_exit(TOWN_EXIT, "town", Vector2(13 * TILE, 37 * TILE), "up", "▲ town")
	for y in range(SEA_Y, rows):
		for x in cols:
			set_thing(x, y, {"type": "sea", "hint": "A: fish" if GameState.has_tool("rod") else ""})
	# Pier out into the sea.
	for y in range(SEA_Y, SEA_Y + 6):
		for x in range(14, 16):
			things.erase(Vector2i(x, y))
			blocked.erase(Vector2i(x, y))
			things[Vector2i(x, y)] = {"type": "dock"}
	var rng := RandomNumberGenerator.new()
	rng.seed = 81 + int(GameState.run["day"])
	for i in 12:
		var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(9, SEA_Y - 1))
		if things.has(c):
			continue
		var key := "forage_beach_%d_%d" % [c.x, c.y]
		if int(GameState.run["flags"].get(key, 0)) >= int(GameState.run["day"]):
			continue
		var item: String = ["seashell", "seashell", "coconut", "fiber"][rng.randi_range(0, 3)]
		things[c] = {"type": "forage", "key": key, "item": item, "hint": "A: pick up %s" % GameState.item_name(item)}
	set_thing(5, 16, {"type": "wreck", "hint": "A: search the wreck"})
	block_rect(3, 14, 5, 3)


func after_ready() -> void:
	WorldGen.add_backdrop(self, "sea")
	var dock := DockLayer.new()
	dock.map = self
	dock.z_index = -1
	add_child(dock)
	var avoid := {}
	for y in range(8, rows):
		for x in cols:
			avoid[Vector2i(x, y)] = true
	WorldGen.tree_border(self, Rect2i(1, 1, cols - 2, 7), 82, [TOWN_EXIT.grow(2)], 2)
	WorldGen.tree_clumps(self, Rect2i(2, 2, cols - 4, 6), 83, 4, avoid)
	WorldGen.scatter_props(self, Rect2i(2, 2, cols - 4, 6), 84, 8, avoid)
	WorldGen.add_critters(self, Rect2i(2, 2, cols - 4, 16), 85, 8)
	for k in things:
		if str(things[k].get("type", "")) == "forage":
			var nm := "deco_4" if str(things[k]["item"]) == "seashell" else "deco_3"
			var s := Art.sprite("tiles", nm)
			if s:
				s.position = cell_center(k)
				s.offset = Vector2(0, -16)
				add_child(s)
				props[k] = s
	prop("props", "crates_c", Vector2i(18, 12), 1)
	block_rect(18, 11, 2, 2)
	prop("props", "stall", Vector2i(22, 10), 1)
	block_rect(22, 9, 2, 2)
	prop("props", "lantern_lit", Vector2i(13, 19))
	prop("props", "lantern_lit", Vector2i(16, 19))
	blocked[Vector2i(13, 19)] = true
	blocked[Vector2i(16, 19)] = true
	if not GameState.run["flags"].has("beach_seen"):
		GameState.run["flags"]["beach_seen"] = true
		player.frozen = true
		await say([{"text": "Salt wind. Gulls. The sea goes on until it becomes the sky. Half a boat lies in the sand like something the water spat out."}])
		player.frozen = false


func interact(c: Vector2i, thing: Dictionary) -> bool:
	match str(thing.get("type", "")):
		"sea":
			if GameState.has_tool("rod"):
				_fish(c)
			return true
		"wreck":
			if int(GameState.run["flags"].get("wreck_day", 0)) < int(GameState.run["day"]) - 3:
				GameState.run["flags"]["wreck_day"] = int(GameState.run["day"])
				var loot: String = ["copper", "iron", "shard", "key_rusty"][randi() % 4]
				if loot == "key_rusty":
					loot = "shard"
				give(loot, 2)
			else:
				hud.toast("Nothing new in the wreck yet.")
			return true
	return false


func _fish(c: Vector2i) -> void:
	if not GameState.spend_energy(2):
		hud.toast("Too tired.", Color(1, 0.7, 0.7))
		return
	player.play_tool("cast")
	player.frozen = true
	hud.toast("Casting into the surf...")
	var wait := randf_range(2.0, 5.0)
	var t := 0.0
	var bite := false
	var caught := false
	var bob: AnimatedSprite2D = null
	if Art.has("fx", "bobber"):
		bob = AnimatedSprite2D.new()
		bob.sprite_frames = Art.frames("fx", {"bobber": "bobber", "bite": "bobber_bite"}, {"bobber": 4.0, "bite": 8.0})
		bob.animation = "bobber"
		bob.scale = Vector2(0.5, 0.5)
		bob.position = cell_center(c) + Vector2(0, -6)
		add_child(bob)
		bob.play("bobber")
	while t < wait + 1.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		if not bite and t >= wait:
			bite = true
			hud.toast("!!!  Press A!", Color(1, 1, 0.4))
			Music.instance(get_tree()).sfx("bite")
			if bob:
				bob.play("bite")
		if Input.is_action_just_pressed("a") and t > 0.2:
			caught = bite
			break
	player.frozen = false
	if bob:
		fx("splash", bob.position, 12.0, 0.5)
		bob.queue_free()
	if caught:
		var pool: Array = ["sunfish", "bass", "salmon", "eel", "puffer", "goldfish", "starfin"]
		give(pool[randi() % mini(pool.size(), 2 + GameState.skill_level("fishing") * 2)])
		player.play_tool("reel")
		xp("fishing", 6)
	else:
		hud.toast("It got away.")


func _draw() -> void:
	draw_grass(8)
	WorldGen.draw_ground_detail(self, 86, 0.1)
	# Sand from row 8 down, sea from SEA_Y.
	draw_tileset_rect("shore_set", Rect2i(0, 8, cols, SEA_Y - 8), Color("e3cf8f"))
	var frame := int(Time.get_ticks_msec() / 250) % 4
	for y in range(SEA_Y, rows):
		for x in cols:
			if not Art.draw_tile(self, "tiles", "water", Vector2(x * TILE, y * TILE), frame):
				draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), Color("2f6fb5"))
	# Foam line.
	for x in cols:
		draw_rect(Rect2(x * TILE, SEA_Y * TILE, TILE, 2), Color(1, 1, 1, 0.5 + 0.3 * sin(Time.get_ticks_msec() / 400.0 + x)))
	draw_tileset_rect("dirt", Rect2i(13, 1, 3, 8), Color("b8945a"))
	draw_exits()
	# Wreck: a broken hull.
	var p := cell_center(Vector2i(5, 16))
	draw_rect(Rect2(p.x - 36, p.y - 20, 72, 18), Color("5a3a1a"))
	draw_rect(Rect2(p.x - 30, p.y - 28, 10, 10), Color("4a2e14"))
	draw_rect(Rect2(p.x - 2, p.y - 44, 3, 26), Color("3a2412"))
	draw_colored_polygon(PackedVector2Array([Vector2(p.x + 1, p.y - 44), Vector2(p.x + 22, p.y - 30), Vector2(p.x + 1, p.y - 24)]), Color("e8dcc2"))
	for x in range(0, cols, 2):
		if x < 11 or x > 17:
			draw_rect(Rect2(x * TILE + 4, 8 * TILE - 2, 8, 2), Color("c9a86b"))


func _process(delta: float) -> void:
	super(delta)
	queue_redraw()

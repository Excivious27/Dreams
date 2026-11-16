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
	pad = 6
	border = {"n": "trees", "s": "water", "w": "water", "e": "cliff"}
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
	extend(14, 6)


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
	WorldGen.add_critters(self, Rect2i(2, 2, cols - 4, 16), 85, 9, ["seagull", "seagull", "crab", "crab", "sparrow", "butterfly_yellow"])
	_place_props()
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
		"hut":
			await say([{"text": "A thatched hut with surfboards leaning on it. Closed. A sign says 'back when the fish are'. (Tom: a beach shop goes here.)"}])
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


func draw_map() -> void:
	draw_grass(8)
	WorldGen.draw_ground_detail(self, 86, 0.1)
	# Sand (with grass transition), wet strip, then sea with foam.
	var sand := cells_of([Rect2i(0, 8, cols, SEA_Y - 8)])
	if Art.has("tiles", "sand"):
		draw_ground("sand", sand)
		for x in cols:
			Art.draw_tile(self, "tiles", "sand_wet", Vector2(x * TILE, (SEA_Y - 1) * TILE), 4)
	else:
		draw_tileset_rect("shore_set", Rect2i(0, 8, cols, SEA_Y - 8), Color("e3cf8f"))
	var frame := int(Time.get_ticks_msec() / 250) % 4
	for y in range(SEA_Y, rows):
		for x in cols:
			var nm := "sea" if Art.has("tiles", "sea") else "water"
			if not Art.draw_tile(self, "tiles", nm, Vector2(x * TILE, y * TILE), 4 if nm == "sea" else frame):
				draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), Color("2f6fb5"))
	for x in cols:
		if not Art.draw_tile(self, "tiles", "foam", Vector2(x * TILE, SEA_Y * TILE), (frame + x) % 4):
			draw_rect(Rect2(x * TILE, SEA_Y * TILE, TILE, 2), Color(1, 1, 1, 0.5))
	draw_ground("dirt", cells_of([Rect2i(13, 1, 3, 8), TOWN_EXIT]))
	draw_exits()
	if not Art.has("buildings", "galleon"):
		var p := cell_center(Vector2i(5, 16))
		draw_rect(Rect2(p.x - 36, p.y - 20, 72, 18), Color("5a3a1a"))


func _place_props() -> void:
	if not Art.has("buildings", "galleon"):
		return
	prop("buildings", "galleon", Vector2i(2, 18), 13)
	block_rect(3, 13, 12, 5)
	things.erase(Vector2i(5, 16))
	set_thing(8, 18, {"type": "wreck", "hint": "A: search the wreck"}, false)
	prop("buildings", "beach_hut", Vector2i(21, 11), 3)
	block_rect(21, 8, 4, 4)
	set_thing(22, 12, {"type": "hut", "hint": "A: beach hut"}, false)
	for c: Vector2i in [Vector2i(3, 9), Vector2i(26, 8), Vector2i(18, 7), Vector2i(8, 10)]:
		prop("nature", "palm", c, 1)
		block_rect(c.x, c.y, 2, 1)
	prop("props", "beached_boat", Vector2i(17, 17), 2)
	block_rect(17, 16, 3, 2)
	prop("props", "umbrella_red", Vector2i(9, 14), 1); prop("props", "umbrella_blue", Vector2i(25, 15), 1)
	block_rect(9, 13, 2, 2); block_rect(25, 14, 2, 2)
	prop("props", "lifeguard", Vector2i(12, 16))
	blocked[Vector2i(12, 16)] = true
	_anim("props", "bonfire", Vector2i(20, 15), 0, 8.0)
	blocked[Vector2i(20, 15)] = true
	_anim("props", "buoy", Vector2i(6, 23), 0, 2.0)
	_anim("props", "buoy", Vector2i(24, 25), 0, 2.0)
	_anim("props", "tide_pool", Vector2i(27, 18), 1, 3.0)
	block_rect(27, 17, 2, 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 87
	for i in 10:
		var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(9, SEA_Y - 2))
		if things.has(c) or blocked.has(c):
			continue
		prop("nature", "dune_%d" % rng.randi_range(0, 9), c)
	for k in things.keys():
		if str(things[k].get("type", "")) == "forage":
			var item := str(things[k]["item"])
			var nm: String = {"seashell": ["shell_a", "shell_b", "shell_c", "starfish"][(k.x + k.y) % 4], "coconut": "coconut_p", "fiber": "seaweed"}.get(item, "shell_a")
			if props.has(k):
				(props[k] as Node).queue_free()
			prop("props", nm, k)
	# Pier planks: replace dock tiles with the pier set.
	for k in things.keys():
		if str(things[k].get("type", "")) == "dock" and Art.has("tiles", "pier"):
			var sp := Sprite2D.new()
			sp.texture = Art.tex("tiles", "pier")
			sp.region_enabled = true
			sp.region_rect = Rect2(32, 0, 32, 32)
			sp.scale = Vector2(0.5, 0.5)
			sp.position = Vector2(k * TILE) + Vector2(8, 8)
			sp.z_index = -1
			add_child(sp)


func _anim(group: String, name: String, c: Vector2i, extra_w := 0, fps := 4.0) -> void:
	if not Art.has(group, name):
		return
	var a := AnimatedSprite2D.new()
	a.sprite_frames = Art.frames(group, {"idle": name}, {"idle": fps})
	a.animation = "idle"
	a.scale = Vector2(0.5, 0.5)
	a.position = Vector2((c.x + (extra_w + 1) / 2.0) * TILE, (c.y + 1) * TILE)
	a.offset = Vector2(0, -float(Art.info(group, name).get("cell_h", 48)) / 2.0)
	add_child(a)
	a.play("idle")


func _process(delta: float) -> void:
	super(delta)
	queue_redraw()

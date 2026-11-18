extends GameMap
## The south beach: sand, the sea along the bottom, a pier, shells and coconuts
## to forage, and a wrecked boat. Exit: town (north).

const TOWN_EXIT := Rect2i(30, 0, 4, 1)
const MARSH_EXIT := Rect2i(0, 12, 1, 4)
const QUARRY_EXIT := Rect2i(63, 12, 1, 4)
const SEA_Y := 24
var _sea := {}
var _sand := {}


func scene_id() -> String:
	return "beach"


func default_spawn() -> Vector2:
	return Vector2(32 * TILE, 3 * TILE)


func build() -> void:
	cols = 64
	rows = 36
	pad = 7
	border = {"n": "trees", "s": "water", "w": "trees", "e": "cliff"}
	music_track = "beach"
	add_exit(TOWN_EXIT, "town", Vector2(40 * TILE, 92 * TILE), "up", "▲ town")
	add_exit(MARSH_EXIT, "marsh", Vector2(49 * TILE, 22 * TILE + 8), "left", "◀ marsh")
	add_exit(QUARRY_EXIT, "quarry", Vector2(2 * TILE, 22 * TILE + 8), "right", "quarry ▶")
	# The tide line wanders: sea cells start at SEA_Y ± noise, with a cove on the east.
	for y in range(8, rows):
		for x in cols:
			var n := WorldGen.fbm(float(x), 3.0, 505, 9.0) * 3.0
			var cove := 0.0
			if x > 46:
				cove = (x - 46) * 0.35
			var edge := SEA_Y + n - cove
			if y >= edge:
				_sea[Vector2i(x, y)] = true
				set_thing(x, y, {"type": "sea", "hint": "A: fish" if GameState.has_tool("rod") else ""})
			else:
				_sand[Vector2i(x, y)] = true
	# Two piers out into the sea.
	for px in [Vector2i(31, 0), Vector2i(12, 0)]:
		var y0 := SEA_Y - 3
		while not _sea.has(Vector2i(px.x, y0)) and y0 < rows - 1:
			y0 += 1
		for y in range(y0 - 1, y0 + 6):
			for x in range(px.x, px.x + 2):
				var c := Vector2i(x, y)
				things.erase(c)
				blocked.erase(c)
				hard.erase(c)
				_sea.erase(c)
				things[c] = {"type": "dock"}
	# The ferry to the merkitty colonies waits at the end of the west pier.
	var tip := Vector2i(12, SEA_Y + 4)
	for y in range(SEA_Y - 3, rows):
		if things.get(Vector2i(12, y), {}).get("type", "") == "dock":
			tip = Vector2i(12, y)
	things[tip] = {"type": "ferry", "hint": "A: the ferry to the colonies"}
	var rng := RandomNumberGenerator.new()
	rng.seed = 81 + int(GameState.run["day"]) / 7
	for i in 12:
		var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(9, SEA_Y + 2))
		if not _sand.has(c):
			continue
		if things.has(c):
			continue
		var key := "forage_beach_%d_%d" % [c.x, c.y]
		if int(GameState.run["flags"].get(key, -9)) > int(GameState.run["day"]) - 2:
			continue
		var item: String = ["seashell", "seashell", "coconut", "fiber"][rng.randi_range(0, 3)]
		things[c] = {"type": "forage", "key": key, "item": item, "hint": "A: pick up %s" % GameState.item_name(item)}
	set_thing(5, 16, {"type": "wreck", "hint": "A: search the wreck"})


func after_ready() -> void:
	WorldGen.add_backdrop(self, "sea")
	if Art.has("props", "campsite"):
		var cs := AnimatedSprite2D.new()
		cs.sprite_frames = Art.frames("props", {"idle": "campsite"}, {"idle": 6.0})
		cs.animation = "idle"
		cs.scale = Vector2(0.5, 0.5)
		cs.position = cell_center(Vector2i(cols - 12, 10)) + Vector2(16, 0)
		cs.offset = Vector2(0, -32)
		add_child(cs)
		cs.play("idle")
		set_thing(cols - 10, 11, {"type": "note", "text": "Someone's camp. The fire's still warm. Footprints lead into the sea and don't come back.", "hint": "A: the camp"}, false)
	var dock := DockLayer.new()
	dock.map = self
	dock.z_index = -1
	add_child(dock)
	var avoid := {}
	for y in range(8, rows):
		for x in cols:
			avoid[Vector2i(x, y)] = true
	for c in cells_of([Rect2i(28, 0, 8, 9), MARSH_EXIT.grow(3), QUARRY_EXIT.grow(3)]):
		avoid[c] = true
	WorldGen.tree_clumps(self, Rect2i(2, 2, cols - 4, 6), 83, 8, avoid)
	WorldGen.scatter_props(self, Rect2i(2, 2, cols - 4, 6), 84, 10, avoid)
	WorldGen.add_critters(self, Rect2i(2, 2, cols - 4, 20), 85, 16, ["seagull", "seagull", "crab", "crab", "sparrow", "butterfly_yellow", "crab"])
	_place_props()
	prop("props", "lantern_lit", Vector2i(30, SEA_Y - 5))
	prop("props", "lantern_lit", Vector2i(33, SEA_Y - 5))
	if not GameState.run["flags"].has("beach_seen"):
		GameState.run["flags"]["beach_seen"] = true
		player.frozen = true
		await say([{"text": "Salt wind. Gulls. The sea goes on until it becomes the sky. Half a boat lies in the sand like something the water spat out."}])
		player.frozen = false


func interact(c: Vector2i, thing: Dictionary) -> bool:
	match str(thing.get("type", "")):
		"note":
			tell([{"text": str(thing.get("text", "..."))}])
			return true
		"sea":
			if GameState.has_tool("rod"):
				_fish(c)
			return true
		"hut":
			tell([{"text": "A thatched hut with surfboards leaning on it. Closed. A sign says 'back when the fish are'."}])
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
	fish_at(c, ["sunfish", "bass", "salmon", "eel", "puffer", "goldfish", "starfin"])


func _fish_old(c: Vector2i) -> void:
	if not GameState.spend_for("rod"):
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
		var b2 := Art.has("fx", "bobber2")
		bob.sprite_frames = Art.frames("fx", {"bobber": "bobber2" if b2 else "bobber", "bite": "bobber2_bite" if b2 else "bobber_bite"}, {"bobber": 4.0, "bite": 8.0})
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
			hud.toast("!!!  Tap USE!", Color(1, 1, 0.4))
			fx("alert", player.position + Vector2(0, -26), 10.0, 0.5)
			Music.instance(get_tree()).sfx("bite")
			if bob:
				bob.play("bite")
		if Input.is_action_just_pressed("a") and t > 0.2:
			caught = bite
			break
	player.frozen = false
	if bob:
		fx("reel_splash" if Art.has("fx", "reel_splash") else "splash", bob.position, 12.0, 0.5)
		if caught and Art.has("fx", "fish_jump_a"):
			fx(["fish_jump_a", "fish_jump_b", "fish_jump_c"][randi() % 3], bob.position + Vector2(0, 4), 12.0, 0.5, player.facing == "left")
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
	var sand := _sand.duplicate()
	for k in things:
		if str(things[k].get("type", "")) == "dock":
			sand[k] = true
	if Art.has("tiles", "sand"):
		draw_ground("sand", sand)
		for c: Vector2i in sand:
			if _sea.has(c + Vector2i(0, 1)):
				Art.draw_tile(self, "tiles", "sand_wet", Vector2(c * TILE), 4)
	else:
		draw_tileset_rect("shore_set", Rect2i(0, 8, cols, SEA_Y - 8), Color("e3cf8f"))
	_anim_layer.jobs.append(func(ci: CanvasItem) -> void:
		var frame := int(Time.get_ticks_msec() / 250) % 4
		var nm := "sea" if Art.has("tiles", "sea") else "water"
		var tt := Time.get_ticks_msec() / 1000.0
		for c: Vector2i in _sea:
			if Art.has("seamless", "sea"):
				seam_cell(ci, "sea", c, Color.WHITE, Vector2(tt * 4.0, tt * 1.5))
				seam_cell(ci, "sea", c, Color(1, 1, 1, 0.3), Vector2(-tt * 2.5 + 40.0, tt * 3.0 + 60.0))
			elif not Art.draw_tile(ci, "tiles", nm, Vector2(c * TILE), 4 if nm == "sea" else frame):
				ci.draw_rect(Rect2(c.x * TILE, c.y * TILE, TILE, TILE), Color("2f6fb5"))
		var foam_t := Art.tex("props", "bk_foam_%d" % (int(tt * 3.0) % 4))
		if foam_t:
			# The painted wave line: sand on top, surf, then sea; one window per edge cell.
			var fw := float(foam_t.get_width()) / 8.0
			for c: Vector2i in _sea:
				if not _sea.has(c + Vector2i(0, -1)) and not things.get(c + Vector2i(0, -1), {}).get("type", "") == "dock":
					ci.draw_texture_rect_region(foam_t, Rect2(c.x * TILE, (c.y - 1) * TILE + 4, TILE, TILE * 1.5), Rect2(fw * posmod(c.x, 8), foam_t.get_height() * 0.25, fw, foam_t.get_height() * 0.6))
			return
		for c: Vector2i in _sea:
			if not _sea.has(c + Vector2i(0, -1)) and not things.get(c + Vector2i(0, -1), {}).get("type", "") == "dock":
				if not Art.draw_tile(ci, "tiles", "foam", Vector2(c * TILE), (frame + c.x) % 4):
					ci.draw_rect(Rect2(c.x * TILE, c.y * TILE, TILE, 2), Color(1, 1, 1, 0.5)))
	# Only the town lane is dirt (it runs over grass); on the sand, paths are just sand.
	draw_ground("dirt", cells_of([Rect2i(30, 1, 4, 8), TOWN_EXIT]))
	draw_exits()
	if not Art.has("buildings", "galleon"):
		var p := cell_center(Vector2i(5, 16))
		draw_rect(Rect2(p.x - 36, p.y - 20, 72, 18), Color("5a3a1a"))


func _place_props() -> void:
	if not Art.has("buildings", "galleon"):
		return
	prop("buildings", "galleon", Vector2i(4, 20), 13)
	things.erase(Vector2i(5, 16))
	set_thing(10, 20, {"type": "wreck", "hint": "A: search the wreck"}, false)
	prop("buildings", "beach_hut", Vector2i(40, 12), 3)
	set_thing(41, 13, {"type": "hut", "hint": "A: beach hut"}, false)
	for c: Vector2i in [Vector2i(3, 10), Vector2i(20, 9), Vector2i(44, 8), Vector2i(57, 10), Vector2i(8, 11), Vector2i(50, 9), Vector2i(26, 10)]:
		prop("nature", "palm", c, 1)
	prop("props", "beached_boat", Vector2i(22, 20), 2)
	var bk := Art.has("props", "bk_umbrella_red")
	prop("props", "bk_umbrella_red" if bk else "umbrella_red", Vector2i(16, 16), 1, 0.0, true, 0.35 if bk else 0.5)
	prop("props", "bk_umbrella_blue" if bk else "umbrella_blue", Vector2i(37, 17), 1, 0.0, true, 0.35 if bk else 0.5)
	prop("props", "bk_lifeguard" if bk else "lifeguard", Vector2i(27, 18), 0, 0.0, true, 0.35 if bk else 0.5)
	if bk:
		prop("props", "bk_towel", Vector2i(18, 17), 0, 0.0, false, 0.3)
		prop("props", "bk_sandcastle", Vector2i(31, 17), 0, 0.0, true, 0.3)
		# Small decals scattered over the sand (no pickup; the shells you can
		# take are the forage ones).
		var drng := RandomNumberGenerator.new()
		drng.seed = 4242
		var decals := ["bk_pebbles_s", "bk_pebbles_m", "bk_footprints", "bk_driftwood_a", "bk_driftwood_b", "bk_seaweed_a", "bk_seaweed_b", "bk_pebbles_s"]
		for i in 26:
			var dc := Vector2i(drng.randi_range(2, cols - 3), drng.randi_range(10, SEA_Y - 1))
			if things.has(dc) or blocked.has(dc) or props.has(dc) or not _sand.has(dc):
				continue
			var sp := prop("props", decals[drng.randi() % decals.size()], dc, 0, 0.0, false, 0.22)
			if sp:
				sp.z_index = -1
	_anim("props", "bonfire", Vector2i(36, 15), 0, 8.0)
	_anim("props", "buoy", Vector2i(8, 29), 0, 2.0)
	_anim("props", "buoy", Vector2i(44, 30), 0, 2.0)
	_anim("props", "buoy", Vector2i(58, 26), 0, 2.0)
	_anim("props", "tide_pool", Vector2i(48, 17), 1, 3.0)
	_anim("props", "tide_pool", Vector2i(56, 16), 1, 3.0)
	for c: Vector2i in [Vector2i(53, 18), Vector2i(60, 19), Vector2i(2, 15)]:
		prop("nature", "rock_l" if Art.has("nature", "rock_l") else "rock_m", c, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 87
	for i in 10:
		var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(9, SEA_Y - 2))
		if things.has(c) or blocked.has(c) or not _sand.has(c):
			continue
		if Art.has("props", "bk_dune_s"):
			prop("props", ["bk_dune_s", "bk_dune_m", "bk_dune_l"][rng.randi_range(0, 2)], c, 1, 0.0, true, 0.3)
		else:
			prop("nature", "dune_%d" % rng.randi_range(0, 9), c)
	for k in things.keys():
		if str(things[k].get("type", "")) == "forage":
			var item := str(things[k]["item"])
			var nm: String = {"seashell": ["shell_a", "shell_b", "shell_c", "starfish"][(k.x + k.y) % 4], "coconut": "coconut_p", "fiber": "seaweed"}.get(item, "shell_a")
			var sc := 0.5
			if Art.has("props", "bk_shell_conch") and item in ["seashell", "fiber"]:
				nm = (["bk_shell_conch", "bk_shell_scallop", "bk_shell_clam", "bk_shell_cowrie", "bk_starfish_orange", "bk_starfish_pink", "bk_sand_dollar_a"][(k.x * 3 + k.y) % 7]) if item == "seashell" else "bk_seaweed_c"
				sc = 0.22
			if props.has(k):
				(props[k] as Node).queue_free()
			prop("props", nm, k, 0, 0.0, true, sc)
	# Pier planks: replace dock tiles with the pier set.
	for k in things.keys():
		if str(things[k].get("type", "")) == "dock" and Art.has("tiles", "pier"):
			var sp := Sprite2D.new()
			sp.texture = Art.tex("tiles", "pier")
			sp.region_enabled = true
			sp.region_rect = Rect2(32, 0, 32, 32)
			sp.scale = Vector2(0.5, 0.5)
			sp.position = cell_pos(k.x, k.y) + Vector2(8, 8)
			sp.z_index = -1
			add_child(sp)


func _anim(group: String, name: String, c: Vector2i, extra_w := 0, fps := 4.0) -> void:
	if not Art.has(group, name):
		return
	var a := AnimatedSprite2D.new()
	a.sprite_frames = Art.frames(group, {"idle": name}, {"idle": fps})
	a.animation = "idle"
	a.scale = Vector2(0.5, 0.5)
	a.position = cell_pos(c.x + (extra_w + 1) / 2.0, c.y + 1)
	a.offset = Vector2(0, -float(Art.info(group, name).get("cell_h", 48)) / 2.0)
	add_child(a)
	a.play("idle")
	# Footprint like prop(): base row, plus body rows for big structures.
	var tw := float(Art.info(group, name).get("cell_w", 32)) / 2.0
	var th := float(Art.info(group, name).get("cell_h", 48)) / 2.0
	if group == "buildings" or tw >= 56.0:
		var w_cells := maxi(extra_w + 1, int(round(tw / TILE)))
		var x0 := c.x + (extra_w + 1) / 2 - w_cells / 2
		for i in w_cells:
			for j in clampi(int(round(th / TILE)) - 1, 1, 5):
				blocked[Vector2i(x0 + i, c.y - j)] = true



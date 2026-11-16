extends GameMap
## The mine: a floor of rock to break with the pickaxe (stone, copper, iron,
## crystal shards), slimes and bats, and a ladder down to a harder floor.
## The layout is generated from the floor number so it's the same each visit.

var floor_no := 1
var _ladder := Vector2i.ZERO


func scene_id() -> String:
	return "mine"


func default_spawn() -> Vector2:
	return cell_center(Vector2i(2, 2))


func build() -> void:
	cols = 18
	rows = 18
	has_sky = false
	has_pet = false
	music_track = "mine"
	floor_no = int(GameState.run.get("mine_floor", 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + floor_no
	set_thing(1, 1, {"type": "up", "hint": "A: climb out"})
	_ladder = Vector2i(rng.randi_range(12, 16), rng.randi_range(12, 16))
	things[_ladder] = {"type": "down", "hint": "A: climb down to floor %d" % (floor_no + 1)}
	var count := 40 + floor_no * 4
	for i in count:
		var c := Vector2i(rng.randi_range(1, cols - 2), rng.randi_range(1, rows - 2))
		if c.distance_to(Vector2i(1, 1)) < 3 or c == _ladder or things.has(c):
			continue
		var roll := rng.randf()
		var ore := "stone"
		if floor_no >= 4 and roll < 0.02:
			ore = "dark"
		elif roll < 0.04 + floor_no * 0.01:
			ore = "shard"
		elif floor_no >= 3 and roll < 0.08 + floor_no * 0.01:
			ore = "gold"
		elif roll < 0.12 + floor_no * 0.03:
			ore = "iron"
		elif roll < 0.35 + floor_no * 0.03:
			ore = "copper"
		set_thing(c.x, c.y, {"type": "rock", "ore": ore, "hp": 2 if ore == "stone" else 3, "hint": "A: mine"})


func after_ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2000 + floor_no + int(GameState.run["day"])
	_place_props()
	var n := 3 + floor_no
	for i in n:
		var c := Vector2i(rng.randi_range(4, cols - 2), rng.randi_range(4, rows - 2))
		if blocked.has(c):
			continue
		var roll := rng.randf()
		var kind := "slime"
		if floor_no >= 5 and roll < 0.1:
			kind = "knight"
		elif floor_no >= 3 and roll < 0.2:
			kind = "golem"
		elif floor_no >= 2 and roll < 0.35:
			kind = "shard" if GameState.is_penguins() else "thug_cyber"
		elif floor_no >= 2 and roll < 0.45:
			kind = "wisp"
		elif roll < 0.7:
			kind = "bat"
		spawn_enemy(kind, cell_center(c))
	if not GameState.run["flags"].has("mine_seen"):
		GameState.run["flags"]["mine_seen"] = true
		player.frozen = true
		await say([
			{"text": "Cold air, and the smell of wet stone. Something drips. Something else squelches."},
			{"text": "Swing your pickaxe at rocks with A: stone, copper, iron, and now and then a crystal shard. Ladders go down. Down is worse, and pays better."},
		])
		player.frozen = false


func interact(c: Vector2i, thing: Dictionary) -> bool:
	match str(thing.get("type", "")):
		"up":
			GameState.run["mine_floor"] = 1
			go_to("meadow", Vector2(21 * TILE, 8 * TILE + 8), "down")
			return true
		"down":
			GameState.run["mine_floor"] = floor_no + 1
			xp("mining", 4)
			go_to("mine", Vector2.ZERO)
			return true
		"rock":
			if not GameState.has_tool("pickaxe"):
				return false
			if not GameState.spend_energy(2):
				hud.toast("Too tired.", Color(1, 0.7, 0.7))
				return true
			player.play_tool("pickaxe")
			Music.instance(get_tree()).sfx("chop")
			thing["hp"] = int(thing["hp"]) - 1
			if int(thing["hp"]) <= 0:
				var ore := str(thing["ore"])
				things.erase(c)
				blocked.erase(c)
				if props.has(c):
					(props[c] as Sprite2D).queue_free()
					props.erase(c)
				give(ore, 1 if ore != "stone" else 2)
				xp("mining", 2 if ore == "stone" else 5)
				queue_redraw()
			return true
	return false


func _draw() -> void:
	if Art.has("tiles", "mine_floor"):
		draw_tileset_rect("mine_floor", Rect2i(1, 1, cols - 2, rows - 2), Color("3b3542"))
		draw_rect(Rect2(0, 0, cols * TILE, rows * TILE), Color(0.05, 0.03, 0.1, 0.3 + 0.05 * mini(floor_no, 6)))
		for x in range(1, cols - 1):
			Art.draw_tile(self, "tiles", "wall_t", Vector2(x * TILE, 0), 0)
			Art.draw_tile(self, "tiles", "wall_b", Vector2(x * TILE, (rows - 1) * TILE), 0)
		for y in range(1, rows - 1):
			Art.draw_tile(self, "tiles", "wall_l", Vector2(0, y * TILE), 0)
			Art.draw_tile(self, "tiles", "wall_r", Vector2((cols - 1) * TILE, y * TILE), 0)
		Art.draw_tile(self, "tiles", "wall_tl", Vector2(0, 0), 0)
		Art.draw_tile(self, "tiles", "wall_tr", Vector2((cols - 1) * TILE, 0), 0)
		Art.draw_tile(self, "tiles", "wall_bl", Vector2(0, (rows - 1) * TILE), 0)
		Art.draw_tile(self, "tiles", "wall_br", Vector2((cols - 1) * TILE, (rows - 1) * TILE), 0)
	elif Art.has("tiles", "stone"):
		for y in rows:
			for x in cols:
				Art.draw_tile(self, "tiles", "stone", Vector2(x * TILE, y * TILE), 4)
		draw_rect(Rect2(0, 0, cols * TILE, rows * TILE), Color(0.1, 0.05, 0.2, 0.45))
	else:
		for y in rows:
			for x in cols:
				draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), Color("3b3542") if (x + y) % 2 == 0 else Color("433c4b"))
	for k in things:
		var t: Dictionary = things[k]
		var p := cell_center(k)
		match str(t.get("type", "")):
			"rock":
				if props.has(k):
					continue
				draw_circle(p + Vector2(0, -6), 7.0, Color("7a7a86"))
			"up", "down":
				var nm := "ladder_up" if str(t["type"]) == "up" else "ladder_down"
				if not Art.draw_prop(self, "props", nm, p):
					draw_rect(Rect2(p.x - 6, p.y - 14, 12, 14), Color("1a1620"))
	if not Art.has("tiles", "mine_floor"):
		draw_rect(Rect2(0, 0, cols * TILE, TILE), Color("221d28"))
		draw_rect(Rect2(0, (rows - 1) * TILE, cols * TILE, TILE), Color("221d28"))
		draw_rect(Rect2(0, 0, TILE, rows * TILE), Color("221d28"))
		draw_rect(Rect2((cols - 1) * TILE, 0, TILE, rows * TILE), Color("221d28"))
	label("floor %d" % floor_no, Vector2(2 * TILE, TILE - 3), 6 * TILE)


func _place_props() -> void:
	if Art.has("props", "ore_copper"):
		for k in things:
			var t: Dictionary = things[k]
			if str(t.get("type", "")) != "rock":
				continue
			var ore := str(t["ore"])
			var nm: String = {"stone": "mrock_a" if (k.x + k.y) % 3 != 0 else "mrock_b", "copper": "ore_copper", "iron": "ore_iron", "shard": "ore_crystal", "gold": "ore_gold", "dark": "ore_dark"}.get(ore, "mrock_a")
			prop("props", nm, k)
		var rng := RandomNumberGenerator.new()
		rng.seed = 3000 + floor_no
		for i in 4:
			var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(2, rows - 3))
			if not things.has(c) and not blocked.has(c):
				prop("props", "cave_mushroom" if rng.randf() < 0.5 else "cave_moss", c)
		if floor_no % 3 == 0:
			prop("props", "beam", Vector2i(cols / 2 - 1, 1), 1)
		return
	if not Art.has("nature", "rock_m"):
		return
	for k in things:
		var t: Dictionary = things[k]
		if str(t.get("type", "")) != "rock":
			continue
		prop("nature", "rock_m", k)

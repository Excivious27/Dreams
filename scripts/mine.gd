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
		if roll < 0.04 + floor_no * 0.01:
			ore = "shard"
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
		if floor_no >= 3 and roll < 0.15:
			kind = "golem"
		elif floor_no >= 2 and roll < 0.3:
			kind = "shard"
		elif roll < 0.6:
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
	if Art.has("tiles", "stone"):
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
				draw_rect(Rect2(p.x - 6, p.y - 14, 12, 14), Color("1a1620"))
				for i in 4:
					draw_rect(Rect2(p.x - 5, p.y - 13 + i * 3.5, 10, 1), Color("a07a4c"))
	draw_rect(Rect2(0, 0, cols * TILE, TILE), Color("221d28"))
	draw_rect(Rect2(0, (rows - 1) * TILE, cols * TILE, TILE), Color("221d28"))
	draw_rect(Rect2(0, 0, TILE, rows * TILE), Color("221d28"))
	draw_rect(Rect2((cols - 1) * TILE, 0, TILE, rows * TILE), Color("221d28"))
	label("floor %d" % floor_no, Vector2(2 * TILE, TILE - 3), 6 * TILE)


func _place_props() -> void:
	if not Art.has("nature", "rock_m"):
		return
	for k in things:
		var t: Dictionary = things[k]
		if str(t.get("type", "")) != "rock":
			continue
		var ore := str(t["ore"])
		var sp := prop("nature", "rock_l" if ore != "stone" else ("rock_m" if (k.x + k.y) % 2 == 0 else "rock_s"), k)
		if sp:
			match ore:
				"copper": sp.modulate = Color(1.0, 0.85, 0.7)
				"iron": sp.modulate = Color(0.85, 0.9, 1.0)
				"shard": sp.modulate = Color(0.8, 0.95, 1.2)
	if Art.has("props", "crystal_rock"):
		for k in things:
			if str(things[k].get("type", "")) == "rock" and str(things[k]["ore"]) == "shard" and props.has(k):
				(props[k] as Sprite2D).texture = Art.tex("props", "crystal_rock")
				(props[k] as Sprite2D).offset = Vector2(0, -Art.tex("props", "crystal_rock").get_height() / 2.0)
				(props[k] as Sprite2D).modulate = Color.WHITE

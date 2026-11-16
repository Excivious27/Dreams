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
	add_child(GameMenu.new())
	var rng := RandomNumberGenerator.new()
	rng.seed = 2000 + floor_no + int(GameState.run["day"])
	var n := 3 + floor_no
	for i in n:
		var c := Vector2i(rng.randi_range(4, cols - 2), rng.randi_range(4, rows - 2))
		if blocked.has(c):
			continue
		spawn_enemy("bat" if rng.randf() < 0.4 else "slime", cell_center(c))
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
				give(ore, 1 if ore != "stone" else 2)
				xp("mining", 2 if ore == "stone" else 5)
				queue_redraw()
			return true
	return false


func _draw() -> void:
	for y in rows:
		for x in cols:
			draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), Color("3b3542") if (x + y) % 2 == 0 else Color("433c4b"))
	for k in things:
		var t: Dictionary = things[k]
		var p := cell_center(k)
		match str(t.get("type", "")):
			"rock":
				var col := Color("7a7a86")
				var fleck := Color.TRANSPARENT
				match str(t["ore"]):
					"copper": fleck = Color("d9823a")
					"iron": fleck = Color("c9cfe0")
					"shard": fleck = Color("8ae0ff")
				draw_circle(p + Vector2(0, -6), 7.0, col)
				draw_circle(p + Vector2(-2, -8), 3.0, Color("9a9aa6"))
				if fleck != Color.TRANSPARENT:
					draw_rect(Rect2(p.x - 3, p.y - 7, 2, 2), fleck)
					draw_rect(Rect2(p.x + 1, p.y - 5, 2, 2), fleck)
					draw_rect(Rect2(p.x - 1, p.y - 10, 2, 2), fleck)
			"up", "down":
				draw_rect(Rect2(p.x - 6, p.y - 14, 12, 14), Color("1a1620"))
				for i in 4:
					draw_rect(Rect2(p.x - 5, p.y - 13 + i * 3.5, 10, 1), Color("a07a4c"))
	draw_rect(Rect2(0, 0, cols * TILE, TILE), Color("221d28"))
	draw_rect(Rect2(0, (rows - 1) * TILE, cols * TILE, TILE), Color("221d28"))
	draw_rect(Rect2(0, 0, TILE, rows * TILE), Color("221d28"))
	draw_rect(Rect2((cols - 1) * TILE, 0, TILE, rows * TILE), Color("221d28"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(2 * TILE, TILE - 3), "floor %d" % floor_no, HORIZONTAL_ALIGNMENT_LEFT, 6 * TILE, 7, Color(1, 1, 0.85))

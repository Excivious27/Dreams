extends GameMap
## The moon (penguin arc): lavender dust, craters, crystal gardens, the rocket
## house, a landing pad back to the mountain, a teleporter that isn't powered yet,
## and Grumps in space helmets (plain Grumps for now). Exit: mountain (pad).

const PAD := Vector2i(12, 19)
const CRATER := Rect2i(18, 6, 8, 7)


func scene_id() -> String:
	return "moon"


func default_spawn() -> Vector2:
	return Vector2(12 * TILE, 18 * TILE)


func build() -> void:
	cols = 30
	rows = 26
	has_sky = false
	music_track = "boss"
	set_thing(PAD.x, PAD.y, {"type": "pad", "hint": "A: fly home"}, false)
	set_thing(PAD.x + 1, PAD.y, {"type": "pad", "hint": "A: fly home"}, false)
	block_rect(CRATER.position.x + 1, CRATER.position.y + 1, CRATER.size.x - 2, CRATER.size.y - 2)
	set_thing(5, 6, {"type": "house", "hint": "A: the rocket house"})
	block_rect(3, 2, 5, 5)
	set_thing(24, 20, {"type": "tele", "hint": "A: teleporter (unpowered)"})
	block_rect(23, 19, 3, 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 111
	for i in 30:
		var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(2, rows - 3))
		if things.has(c) or blocked.has(c) or Rect2i(10, 17, 5, 4).has_point(c):
			continue
		var roll := rng.randf()
		if roll < 0.5:
			set_thing(c.x, c.y, {"type": "mrock", "ore": "shard" if roll < 0.2 else "stone", "hp": 3, "hint": "A: mine"})
		else:
			var key := "forage_moon_%d_%d" % [c.x, c.y]
			if int(GameState.run["flags"].get(key, 0)) < int(GameState.run["day"]):
				things[c] = {"type": "forage", "key": key, "item": "crystal_bloom", "hint": "A: pick"}


func after_ready() -> void:
	WorldGen.add_backdrop(self, "moon")
	prop("props", "landing_pad", Vector2i(11, 21), 2)
	prop("props", "rocket_house", Vector2i(3, 6), 4)
	var t := prop("props", "teleporter", Vector2i(23, 20), 2)
	if t:
		t.queue_free()
		var a := AnimatedSprite2D.new()
		a.sprite_frames = Art.frames("props", {"idle": "teleporter"}, {"idle": 2.0})
		a.animation = "idle"
		a.scale = Vector2(0.5, 0.5)
		a.position = cell_center(Vector2i(24, 20)) + Vector2(0, 2)
		a.offset = Vector2(0, -float(Art.info("props", "teleporter").get("cell_h", 72)) / 2.0)
		add_child(a)
		a.play("idle")
	for k in things.keys():
		var th: Dictionary = things[k]
		match str(th.get("type", "")):
			"mrock":
				prop("props", "moon_crystal_blue_s" if str(th["ore"]) == "shard" else "mrock_b", k)
			"forage":
				prop("props", ["moon_grass_a", "moon_grass_b", "moon_grass_c"][(k.x + k.y) % 3], k)
	for c: Vector2i in [Vector2i(14, 4), Vector2i(27, 14), Vector2i(8, 22), Vector2i(26, 3)]:
		prop("props", "moon_crystal_pink" if c.x > 15 else "moon_crystal_blue", c)
		blocked[c] = true
	for c: Vector2i in [Vector2i(16, 22), Vector2i(2, 14), Vector2i(20, 15)]:
		prop("props", "bulb_plant", c)
		blocked[c] = true
	for c: Vector2i in [Vector2i(9, 12), Vector2i(21, 3), Vector2i(28, 22)]:
		prop("props", "spiral_fern", c)
	for i in 4:
		spawn_enemy(["grump", "soldier", "shard", "wisp"][i], Vector2(randf_range(14, 28) * TILE, randf_range(3, 23) * TILE))
	if not GameState.run["flags"].has("moon_seen"):
		GameState.run["flags"]["moon_seen"] = true
		player.frozen = true
		await say([
			{"text": "Silence, and lavender dust that puffs up and falls slower than it should. The sky is black and full of stars, and the valley is a green coin far below."},
			{"who": "Light Crystal", "text": "This is where I fell from. There's a teleporter here that goes further out. It needs power we don't have yet. (Tom: chapter 3 goes through here.)", "mood": "worried"},
		])
		player.frozen = false


func interact(c: Vector2i, thing: Dictionary) -> bool:
	match str(thing.get("type", "")):
		"pad":
			go_to("mountain", Vector2(17 * TILE, 8 * TILE), "down")
			return true
		"house":
			await say([{"text": "A house built into a rocket, or a rocket built around a house. Round windows. A kettle. Somebody has been living here a long time, and left recently."}])
			return true
		"tele":
			await say([{"text": "The pad glows faintly and does nothing. A panel beside it wants a Refined Crystal. Three, in fact."}])
			return true
		"mrock":
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
				give(ore, 2)
				xp("mining", 4)
			return true
	return false


func _draw() -> void:
	draw_tileset_rect("moon_dust", Rect2i(0, 0, cols, rows), Color("b9a8d8"))
	draw_tileset_rect("crater", CRATER, Color("8a7ab8"))
	draw_rect(Rect2(0, 0, cols * TILE, TILE), Color("2a1a44"))
	draw_rect(Rect2(0, (rows - 1) * TILE, cols * TILE, TILE), Color("2a1a44"))
	draw_rect(Rect2(0, 0, TILE, rows * TILE), Color("2a1a44"))
	draw_rect(Rect2((cols - 1) * TILE, 0, TILE, rows * TILE), Color("2a1a44"))

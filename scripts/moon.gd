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
	pad = 5
	border = "cliff"
	has_sky = false
	music_track = "boss"
	set_thing(PAD.x, PAD.y, {"type": "pad", "hint": "A: fly home"}, false)
	set_thing(PAD.x + 1, PAD.y, {"type": "pad", "hint": "A: fly home"}, false)
	block_rect(CRATER.position.x + 1, CRATER.position.y + 1, CRATER.size.x - 2, CRATER.size.y - 2)
	set_thing(5, 6, {"type": "house", "hint": "A: the rocket house"})
	set_thing(24, 20, {"type": "tele", "hint": "A: teleporter (unpowered)"})
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
	extend(10, 8)


func after_ready() -> void:
	WorldGen.add_backdrop(self, "moon")
	prop("props", "landing_pad", Vector2i(11, 21), 2)
	if Art.has("props", "warp_pad"):
		var wp := AnimatedSprite2D.new()
		wp.sprite_frames = Art.frames("props", {"idle": "warp_pad"}, {"idle": 6.0})
		wp.animation = "idle"
		wp.scale = Vector2(0.5, 0.5)
		wp.position = cell_center(Vector2i(24, 20)) + Vector2(0, 2)
		wp.offset = Vector2(0, -float(Art.info("props", "warp_pad").get("cell_h", 64)) / 2.0 + 14)
		wp.z_index = -1
		add_child(wp)
		wp.play("idle")
	prop("props", "rocket_house", Vector2i(3, 6), 4)
	if Art.has("buildings", "greenhouse_dome"):
		prop("buildings", "greenhouse_dome", Vector2i(24, 5), 4)
		prop("props", "radio_dish", Vector2i(15, 3), 1)
		prop("props", "solar_field", Vector2i(5, 14), 2)
		prop("props", "rover", Vector2i(18, 23), 2)
		prop("props", "crashed_probe", Vector2i(26, 14), 2)
		prop("props", "alien_stall", Vector2i(9, 6), 3)
		set_thing(10, 7, {"type": "alien_shop", "hint": "A: alien stall"}, false)
		prop("props", "alien_vend_a", Vector2i(13, 7))
		var mc := AnimatedSprite2D.new()
		mc.sprite_frames = Art.frames("props", {"idle": "moon_cow"}, {"idle": 2.0})
		mc.animation = "idle"
		mc.scale = Vector2(0.5, 0.5)
		mc.position = cell_center(Vector2i(21, 16))
		mc.offset = Vector2(0, -22)
		add_child(mc)
		mc.play("idle")
		var sp := AnimatedSprite2D.new()
		sp.sprite_frames = Art.frames("props", {"idle": "moon_spire_anim"}, {"idle": 3.0})
		sp.animation = "idle"
		sp.scale = Vector2(0.5, 0.5)
		sp.position = cell_center(Vector2i(22, 11)) + Vector2(8, 0)
		sp.offset = Vector2(0, -80)
		add_child(sp)
		sp.play("idle")
		set_thing(22, 12, {"type": "spire", "hint": "A: the crystal spire"}, false)
		for c: Vector2i in [Vector2i(3, 20), Vector2i(27, 8), Vector2i(10, 12)]:
			prop("props", ["starflower_blue", "starflower_pink", "starflower_yellow"][c.x % 3], c)
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
	for c: Vector2i in [Vector2i(16, 22), Vector2i(2, 14), Vector2i(20, 15)]:
		prop("props", "bulb_plant", c)
	for c: Vector2i in [Vector2i(9, 12), Vector2i(21, 3), Vector2i(28, 22)]:
		prop("props", "spiral_fern", c)
	for i in 4:
		spawn_enemy(["grump", "soldier", "shard", "wisp"][i], Vector2(randf_range(14, 28) * TILE, randf_range(3, 23) * TILE))
	if not GameState.run["flags"].has("moon_seen"):
		GameState.run["flags"]["moon_seen"] = true
		player.frozen = true
		await say([
			{"text": "Silence, and lavender dust that puffs up and falls slower than it should. The sky is black and full of stars, and the valley is a green coin far below."},
			{"who": "Star Crystal", "text": "This is where I fell from. There's a teleporter here that goes further out. It needs power we don't have yet.", "mood": "worried"},
		])
		player.frozen = false


func interact(c: Vector2i, thing: Dictionary) -> bool:
	match str(thing.get("type", "")):
		"pad":
			go_to("mountain", Vector2(17 * TILE, 8 * TILE), "down")
			return true
		"alien_shop":
			later(_alien_shop)
			return true
		"spire":
			later(func() -> void:
				if await Story.talk(self, "spire"):
					return
				tell([{"who": "Star Crystal", "text": "Not yet. Light the teleporter first; the way to its heart is through the station.", "mood": "worried"}]))
			return true
		"spire_old":
			tell([{"who": "Star Crystal", "text": "This is it. The missing piece. It's grown into the moon itself. We can't just pick it up; it has to be... persuaded.", "mood": "worried"}])
			return true
		"house":
			tell([{"text": "A house built into a rocket, or a rocket built around a house. Round windows. A kettle. Somebody has been living here a long time, and left recently."}])
			return true
		"tele":
			if GameState.count("crystal_refined") >= 3 or GameState.run["flags"].has("tele_on"):
				if not GameState.run["flags"].has("tele_on"):
					GameState.add_item("crystal_refined", -3)
					GameState.run["flags"]["tele_on"] = true
					fx("levelup", cell_center(Vector2i(24, 20)), 10.0, 0.8)
					later(_tele_first)
					return true
				go_to("station", Vector2(4 * TILE, 12 * TILE + 8), "right")
			else:
				tell([{"text": "The pad glows faintly and does nothing. A panel beside it wants Refined Crystals. Three. (You have %d.)" % GameState.count("crystal_refined")}])
			return true
		"mrock":
			if not GameState.has_tool("pickaxe"):
				return false
			var ob := GameState.ore_block(str(thing.get("ore", "stone")))
			if ob != "":
				player.play_tool("pickaxe")
				hud.toast(ob, Color(1, 0.85, 0.6))
				return true
			if not GameState.spend_for("pickaxe"):
				hud.toast("Too tired.", Color(1, 0.7, 0.7))
				return true
			player.play_tool("pickaxe")
			Music.instance(get_tree()).sfx("chop")
			thing["hp"] = int(thing["hp"]) - (1 + GameState.tool_tier("pickaxe") / 2)
			if int(thing["hp"]) <= 0:
				var ore := str(thing["ore"])
				things.erase(c)
				blocked.erase(c)
				if props.has(c):
					(props[c] as Sprite2D).queue_free()
					props.erase(c)
				give(ore, 2)
				if ore == "shard" and randf() < 0.35:
					give("moon_shard", 1)
				xp("mining", 4)
			return true
	return false


func draw_map() -> void:
	draw_tileset_rect("moon_dust", Rect2i(0, 0, cols, rows), Color("b9a8d8"))
	draw_tileset_rect("crater", CRATER, Color("8a7ab8"))
	draw_rect(Rect2(0, 0, cols * TILE, TILE), Color("2a1a44"))
	draw_rect(Rect2(0, (rows - 1) * TILE, cols * TILE, TILE), Color("2a1a44"))
	draw_rect(Rect2(0, 0, TILE, rows * TILE), Color("2a1a44"))
	draw_rect(Rect2((cols - 1) * TILE, 0, TILE, rows * TILE), Color("2a1a44"))


func _alien_shop() -> void:
	var d := Dialogue.instance(get_tree())
	d.say([{"who": "Alien trader", "text": "Zzzt. Crystals for goods. Goods for crystals. Zzzt. (◆%d)" % int(GameState.run["crystals"]), "choice": ["Dream Tonic  ◆200", "Energy Tea  ◆20", "Leave"], "key": ""}])
	await d.finished
	if d.last_choice == 0 and int(GameState.run["crystals"]) >= 200:
		GameState.run["crystals"] = int(GameState.run["crystals"]) - 200
		give("dream_tonic")
	elif d.last_choice == 1 and int(GameState.run["crystals"]) >= 20:
		GameState.run["crystals"] = int(GameState.run["crystals"]) - 20
		give("energy_tea")


func _tele_first() -> void:
	await say([{"who": "Star Crystal", "text": "There. It remembers where it goes.", "mood": "happy"}])
	go_to("station", Vector2(4 * TILE, 12 * TILE + 8), "right")

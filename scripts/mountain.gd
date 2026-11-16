extends GameMap
## The mountain pass east of town: switchback path up rocky terrain, a lookout,
## a hot spring, rock fields to mine, and the rocket pad (penguin arc) or a
## smugglers' camp (gangster arc) at the top. Exits: town (west), moon (pad).

const TOWN_EXIT := Rect2i(0, 11, 1, 3)
const PAD := Vector2i(16, 4)
const SPRING := Rect2i(24, 20, 3, 2)


func scene_id() -> String:
	return "mountain"


func default_spawn() -> Vector2:
	return Vector2(2 * TILE, 12 * TILE)


func build() -> void:
	cols = 34
	rows = 32
	music_track = "mine"
	add_exit(TOWN_EXIT, "town", Vector2(25 * TILE, 13 * TILE + 8), "left", "◀ town")
	# Rock walls forming terraces.
	for x in range(4, 30):
		if x < 10 or x > 13:
			block_rect(x, 8, 1, 1)
		if x < 18 or x > 21:
			block_rect(x, 16, 1, 1)
		if x < 7 or x > 10:
			block_rect(x, 24, 1, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for i in 40:
		var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(2, rows - 3))
		if things.has(c) or blocked.has(c) or Rect2i(14, 2, 6, 5).has_point(c):
			continue
		var roll := rng.randf()
		var ore := "stone" if roll < 0.55 else ("copper" if roll < 0.8 else ("iron" if roll < 0.95 else "shard"))
		set_thing(c.x, c.y, {"type": "mrock", "ore": ore, "hp": 2 if ore == "stone" else 3, "hint": "A: mine"})
	for y in range(SPRING.position.y, SPRING.end.y):
		for x in range(SPRING.position.x, SPRING.end.x):
			set_thing(x, y, {"type": "spring", "hint": "A: soak in the hot spring"})
	if GameState.is_penguins():
		set_thing(PAD.x, PAD.y, {"type": "pad", "hint": "A: the landing pad"}, false)
		block_rect(14, 2, 2, 5)
		block_rect(19, 2, 2, 5)
	else:
		set_thing(PAD.x, PAD.y, {"type": "camp", "hint": "A: smugglers' camp"})
		block_rect(14, 2, 6, 2)


func after_ready() -> void:
	WorldGen.add_backdrop(self, "mountains")
	for k in things.keys():
		var t: Dictionary = things[k]
		if str(t.get("type", "")) == "mrock":
			var nm: String = {"stone": "mrock_a", "copper": "ore_copper", "iron": "ore_iron", "shard": "ore_crystal"}[str(t["ore"])]
			if not prop("props", nm, k):
				prop("nature", "rock_m", k)
	if not Art.has("tiles", "cliff2_0"):
		for x in range(4, 30):
			for yy in [8, 16, 24]:
				if blocked.has(Vector2i(x, yy)) and not things.has(Vector2i(x, yy)):
					prop("nature", "rock_l" if x % 3 == 0 else "rock_m", Vector2i(x, yy))
	if Art.has("props", "hot_spring"):
		var a := AnimatedSprite2D.new()
		a.sprite_frames = Art.frames("props", {"idle": "hot_spring"}, {"idle": 3.0})
		a.animation = "idle"
		a.scale = Vector2(0.5, 0.5)
		a.position = Vector2((SPRING.position.x + 1.5) * TILE, (SPRING.end.y) * TILE)
		a.offset = Vector2(0, -float(Art.info("props", "hot_spring").get("cell_h", 96)) / 2.0)
		a.z_index = -1
		add_child(a)
		a.play("idle")
	prop("props", "lookout_tower", Vector2i(3, 29), 1)
	block_rect(3, 26, 2, 4)
	prop("props", "cliff_stairs_up", Vector2i(11, 8))
	prop("props", "cliff_stairs_up", Vector2i(19, 16))
	prop("props", "cliff_stairs_up", Vector2i(8, 24))
	prop("props", "rockslide", Vector2i(26, 27), 2)
	block_rect(26, 26, 3, 2)
	prop("props", "goat", Vector2i(28, 10))
	for c: Vector2i in [Vector2i(5, 20), Vector2i(23, 12)]:
		prop("props", "boulder_l", c)
		blocked[c] = true
	if Art.has("props", "cave_mouth"):
		prop("props", "cave_mouth", Vector2i(4, 2), 2)
		block_rect(4, 1, 3, 2)
		set_thing(5, 3, {"type": "cave", "hint": "A: a dark cave"}, false)
	if GameState.is_penguins():
		prop("props", "landing_pad", Vector2i(15, 6), 2)
		prop("props", "rocket_house", Vector2i(26, 6), 3)
		block_rect(26, 2, 4, 5)
		prop("props", "moon_crystal_blue", Vector2i(12, 4))
		blocked[Vector2i(12, 4)] = true
	else:
		prop("props", "black_market", Vector2i(14, 3), 4)
		prop("props", "fire_barrel_0", Vector2i(21, 4))
		prop("props", "crates_c", Vector2i(23, 4), 1)
		block_rect(21, 3, 4, 2)
	var avoid := {}
	for y in range(2, 8):
		for x in range(11, 31):
			avoid[Vector2i(x, y)] = true
	WorldGen.tree_clumps(self, Rect2i(2, 26, 30, 4), 92, 4, avoid)
	WorldGen.scatter_props(self, Rect2i(2, 9, 30, 20), 93, 12, avoid)
	WorldGen.add_critters(self, Rect2i(2, 2, cols - 4, rows - 4), 94, 6, ["goat", "crow", "crow", "hedgehog", "sparrow"])
	for i in 3:
		spawn_enemy("golem" if GameState.is_penguins() else "thug_enforcer", Vector2(randf_range(6, 28) * TILE, randf_range(10, 23) * TILE))
	if not GameState.run["flags"].has("mountain_seen"):
		GameState.run["flags"]["mountain_seen"] = true
		player.frozen = true
		if GameState.is_penguins():
			await say([{"text": "The path climbs in switchbacks. Up top, past the goats and the hot spring, somebody has built a rocket out of a house. Or a house out of a rocket."}])
		else:
			await say([{"text": "Switchbacks, loose rock, and at the top a tarp camp with a fire going. Smugglers. The kind who sell to anyone, including you."}])
		player.frozen = false


func interact(c: Vector2i, thing: Dictionary) -> bool:
	match str(thing.get("type", "")):
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
				give(ore, 1 if ore != "stone" else 2)
				xp("mining", 2 if ore == "stone" else 5)
			return true
		"spring":
			if int(GameState.run["flags"].get("spring_day", 0)) < int(GameState.run["day"]):
				GameState.run["flags"]["spring_day"] = int(GameState.run["day"])
				GameState.restore_energy(50)
				GameState.heal(3)
				hud.toast("Ahh. +50 energy, +3 hearts.")
				fx("heal", player.position + Vector2(0, -10), 10.0, 0.6)
			else:
				hud.toast("Once a day is plenty.")
			return true
		"pad":
			_pad()
			return true
		"cave":
			await say([{"text": "Cold air breathes out of the dark. Something glitters far inside. (Tom: a second mine or a secret goes here.)"}])
			return true
		"camp":
			_camp()
			return true
	return false


func _pad() -> void:
	if not GameState.quest_done("clear_meadow"):
		await say([{"who": "Light Crystal", "text": "(faintly) Not yet. The first spark has to be lit before we leave the ground."}])
		return
	var d := Dialogue.instance(get_tree())
	d.say([{"who": "Light Crystal", "text": "The pad hums under your feet. I can take us up. The moon is where the next piece of the Meow Pow Wow is hidden. Ready?", "choice": ["Launch", "Not yet"], "key": ""}])
	await d.finished
	if d.last_choice == 0:
		GameState.run["flags"]["moon_unlocked"] = true
		fx("levelup", cell_center(PAD) + Vector2(0, -8), 10.0, 0.8)
		go_to("moon", Vector2(12 * TILE, 18 * TILE), "down")


func _camp() -> void:
	var d := Dialogue.instance(get_tree())
	d.say([{"who": "Smuggler", "text": "No names, no questions. Iron Sword ◆90, Red Potion ◆20, Energy Tea ◆15. You have ◆%d." % int(GameState.run["crystals"]), "choice": ["Iron Sword  ◆90", "Red Potion  ◆20", "Energy Tea  ◆15", "Leave"], "key": ""}])
	await d.finished
	var picks := [["iron_sword", 90], ["potion", 20], ["energy_tea", 15]]
	if d.last_choice >= 0 and d.last_choice < picks.size():
		var id: String = picks[d.last_choice][0]
		var price: int = picks[d.last_choice][1]
		if GameState.has_tool(id):
			hud.toast("You already have one.")
			return
		if int(GameState.run["crystals"]) < price:
			hud.toast("Not enough crystals.", Color(1, 0.7, 0.7))
			return
		GameState.run["crystals"] = int(GameState.run["crystals"]) - price
		if id == "iron_sword":
			GameState.add_tool(id)
			hud.toast("Got the Iron Sword.", Color(1, 0.9, 0.4))
		else:
			give(id)


func _draw() -> void:
	draw_grass(9)
	WorldGen.draw_ground_detail(self, 95, 0.1)
	draw_ground("stone", cells_of([Rect2i(0, 0, cols, 8), Rect2i(0, 15, cols, 2), Rect2i(0, 23, cols, 2)]))
	draw_ground("dirt", cells_of([Rect2i(1, 11, 9, 3), Rect2i(7, 17, 4, 8), Rect2i(10, 8, 4, 6), Rect2i(18, 13, 4, 5), Rect2i(10, 17, 12, 2), Rect2i(14, 7, 6, 2), TOWN_EXIT]))
	# Cliff faces along the terrace rows.
	for yy in [8, 16, 24]:
		for x in range(1, cols - 1):
			if blocked.has(Vector2i(x, yy)) and not things.has(Vector2i(x, yy)):
				var idx := 1 if (x > 1 and blocked.has(Vector2i(x - 1, yy))) and (x < cols - 2 and blocked.has(Vector2i(x + 1, yy))) else (0 if not blocked.has(Vector2i(x - 1, yy)) else 2)
				var nm := "cliff2_%d" % idx
				var t := Art.tex("tiles", nm)
				if t:
					draw_texture_rect(t, Rect2(x * TILE, (yy - 1) * TILE, TILE, TILE * 2), false)
	draw_exits()
	if not Art.has("props", "hot_spring"):
		var r := Rect2(SPRING.position * TILE, SPRING.size * TILE)
		draw_rect(r.grow(3), Color("7a7a86"))
		draw_rect(r, Color("6fc8d8"))
	draw_fence_border(Color("5a5a66"))


func _process(delta: float) -> void:
	super(delta)
	queue_redraw()

extends GameMap
## The mountain pass east of town: three wide terraces split by long cliff ledges,
## a hot spring, rock fields to mine, a lookout, a cave, and the rocket pad
## (penguin arc) or a smugglers' camp (gangster arc) up top. Exits: town, moon (pad).

const TOWN_EXIT := Rect2i(0, 38, 1, 4)
const PAD := Vector2i(28, 5)
const SPRING := Rect2i(44, 20, 3, 2)
const LEDGES := [[14, 24, 27], [28, 10, 13]]   # [row, stair x0, stair x1]
var _ledge := {}


func scene_id() -> String:
	return "mountain"


func default_spawn() -> Vector2:
	return cell_center(Vector2i(3, 39))


func build() -> void:
	cols = 56
	rows = 46
	pad = 6
	border = "cliff"
	music_track = "mountain"
	add_exit(TOWN_EXIT, "town", Vector2(80 * TILE, 47 * TILE + 8), "left", "◀ town")
	add_exit(Rect2i(12, 0, 4, 1), "highlands", Vector2(26 * TILE, 41 * TILE + 8), "up", "▲ highlands")
	add_exit(Rect2i(40, 45, 4, 1), "quarry", Vector2(26 * TILE, 2 * TILE + 8), "down", "▼ quarry")
	# Three wide terraces split by two long cliff ledges, each with one stair gap.
	for l in LEDGES:
		var y: int = l[0]
		for x in range(0, cols):
			if x >= int(l[1]) and x <= int(l[2]):
				continue
			_ledge[Vector2i(x, y)] = true
			blocked[Vector2i(x, y)] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var placed := 0
	while placed < 22:
		var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(2, rows - 3))
		if things.has(c) or blocked.has(c) or Rect2i(22, 1, 14, 8).has_point(c) or SPRING.grow(2).has_point(c) or is_cleared(c):
			continue
		var near_stairs := false
		for l in LEDGES:
			if absi(c.y - int(l[0])) <= 2 and c.x >= int(l[1]) - 2 and c.x <= int(l[2]) + 2:
				near_stairs = true
		if near_stairs or TOWN_EXIT.grow(3).has_point(c):
			continue
		var roll := rng.randf()
		var ore := "stone" if roll < 0.5 else ("copper" if roll < 0.78 else ("iron" if roll < 0.94 else "shard"))
		set_thing(c.x, c.y, {"type": "mrock", "ore": ore, "hp": 2 if ore == "stone" else 3, "hint": "A: mine"})
		placed += 1
	for y in range(SPRING.position.y, SPRING.end.y):
		for x in range(SPRING.position.x, SPRING.end.x):
			set_thing(x, y, {"type": "spring", "hint": "A: soak in the hot spring"})
	if GameState.is_penguins():
		set_thing(PAD.x, PAD.y, {"type": "pad", "hint": "A: the landing pad"}, false)
	else:
		set_thing(PAD.x, PAD.y, {"type": "camp", "hint": "A: smugglers' camp"})


func after_ready() -> void:
	WorldGen.add_backdrop(self, "mountains")
	for k in things.keys():
		var t: Dictionary = things[k]
		if str(t.get("type", "")) == "mrock":
			var nm: String = {"stone": "mrock_a", "copper": "ore_copper", "iron": "ore_iron", "shard": "ore_crystal"}[str(t["ore"])]
			if not prop("props", nm, k):
				prop("nature", "rock_m", k)
	if Art.has("props", "hot_spring"):
		var a := AnimatedSprite2D.new()
		a.sprite_frames = Art.frames("props", {"idle": "hot_spring"}, {"idle": 3.0})
		a.animation = "idle"
		a.scale = Vector2(0.5, 0.5)
		a.position = cell_pos(SPRING.position.x + 1.5, SPRING.end.y)
		a.offset = Vector2(0, -float(Art.info("props", "hot_spring").get("cell_h", 96)) / 2.0)
		a.z_index = -1
		add_child(a)
		a.play("idle")
	prop("props", "lookout_tower", Vector2i(48, 42), 1)
	block_rect(48, 39, 2, 4)
	if not Art.has("tiles", "t_cliffg"):
		for l in LEDGES:
			prop("props", "cliff_stairs_up", Vector2i(int(l[1]) + 1, int(l[0])), 0, 0.0, false)
	if Art.has("props", "rope_bridge2"):
		walk_over(prop("props", "rope_bridge2", Vector2i(44, 12), 3, 0.0, false), 4)
	prop("props", "rockslide", Vector2i(6, 20), 2)
	block_rect(6, 19, 3, 2)
	prop("props", "goat", Vector2i(40, 8))
	for c: Vector2i in [Vector2i(12, 34), Vector2i(36, 22), Vector2i(50, 32), Vector2i(8, 6)]:
		prop("props", "boulder_l", c)
	if Art.has("props", "cave_mouth2") or Art.has("props", "cave_mouth"):
		prop("props", "cave_mouth2" if Art.has("props", "cave_mouth2") else "cave_mouth", Vector2i(4, 2), 2)
		block_rect(4, 1, 3, 2)
		set_thing(5, 3, {"type": "cave", "hint": "A: enter the mine"}, false)
	if GameState.is_penguins():
		prop("props", "landing_pad", Vector2i(27, 7), 2, 0.0, false)
		prop("props", "rocket_house", Vector2i(32, 6), 3)
		block_rect(32, 2, 4, 5)
		prop("props", "moon_crystal_blue", Vector2i(24, 5))
	else:
		prop("props", "black_market", Vector2i(26, 4), 4)
		prop("props", "fire_barrel_0", Vector2i(33, 5))
		prop("props", "crates_c", Vector2i(35, 5), 1)
	var avoid := {}
	for y in range(1, 9):
		for x in range(22, 38):
			avoid[Vector2i(x, y)] = true
	for l in LEDGES:
		for y in range(int(l[0]) - 2, int(l[0]) + 3):
			for x in range(int(l[1]) - 3, int(l[2]) + 4):
				avoid[Vector2i(x, y)] = true
	WorldGen.tree_clumps(self, Rect2i(2, 30, cols - 4, 14), 92, 5, avoid)
	WorldGen.tree_clumps(self, Rect2i(2, 16, 18, 10), 95, 2, avoid)
	WorldGen.scatter_props(self, Rect2i(2, 2, cols - 4, rows - 4), 93, 16, avoid)
	WorldGen.add_critters(self, Rect2i(2, 2, cols - 4, rows - 4), 94, 8, ["goat", "crow", "crow", "hedgehog", "sparrow"])
	for i in GameState.enemy_count(4):
		var at := cell_center(Vector2i(randi_range(6, cols - 7), randi_range(16, rows - 6)))
		spawn_enemy("golem" if GameState.is_penguins() else "thug_enforcer", at)
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
			if GameState.held_tool() != "pickaxe":
				if GameState.has_tool("pickaxe"):
					hud.toast("Use the pickaxe.")
				return GameState.has_tool("pickaxe")
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
			# The mountain cave is the mine's upper entrance (the meadow has the other).
			GameState.run["flags"]["mine_from"] = "mountain"
			go_to("mine", Vector2.ZERO)
			return true
		"camp":
			_camp()
			return true
	return false


func _pad() -> void:
	if not GameState.quest_done("clear_meadow"):
		await say([{"who": "Star Crystal", "text": "(faintly) Not yet. The first spark has to be lit before we leave the ground."}])
		return
	var d := Dialogue.instance(get_tree())
	d.say([{"who": "Star Crystal", "text": "The pad hums under your feet. I can take us up. The moon is where the next piece of the Meow Pow Wow is hidden. Ready?", "choice": ["Launch", "Not yet"], "key": ""}])
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


func draw_map() -> void:
	draw_grass(9)
	WorldGen.draw_ground_detail(self, 95, 0.05)
	# Top terrace is bare stone; the others grassy with a dirt switchback.
	draw_ground("stone", cells_of([Rect2i(20, 1, 18, 8)]))
	# One continuous switchback: west gate → up the left stairs → across → up the
	# middle stairs → the top terrace. Every stair gap has the path running through it.
	draw_ground("dirt", cells_of([Rect2i(1, 38, 10, 3), Rect2i(10, 27, 3, 14), Rect2i(10, 29, 18, 2), Rect2i(25, 13, 3, 18), Rect2i(25, 8, 3, 6)]))
	if Art.has("tiles", "t_cliffg"):
		var stairs := {}
		for l in LEDGES:
			for x in range(int(l[1]), int(l[2]) + 1):
				stairs[Vector2i(x, int(l[0]))] = true
		for l in LEDGES:
			var top := {}
			var y: int = int(l[0])
			var y_from: int = 0
			for l2 in LEDGES:
				if int(l2[0]) < y:
					y_from = maxi(y_from, int(l2[0]) + 1)
			for yy in range(y_from, y):
				for x in range(0, cols):
					top[Vector2i(x, yy)] = true
			draw_plateau(top, "cliffg", stairs)
	else:
		for c: Vector2i in _ledge:
			var t := Art.tex("tiles", "cliff2_1")
			if t:
				draw_texture_rect(t, Rect2(c.x * TILE, (c.y - 1) * TILE, TILE, TILE * 2), false)
	if Art.has("tiles", "waterfall2") and _anim_layer:
		_anim_layer.jobs.append(func(ci: CanvasItem) -> void:
			var fr := int(Time.get_ticks_msec() / 120) % 4
			var wt := Art.tex("tiles", "waterfall2")
			for yy in range(2, 10, 2):
				ci.draw_texture_rect_region(wt, Rect2(52 * TILE, yy * TILE, TILE, TILE * 2), Rect2(fr * 32, 0, 32, 64)))
	draw_exits()
	if not Art.has("props", "hot_spring"):
		var r := Rect2(SPRING.position * TILE, SPRING.size * TILE)
		draw_rect(r.grow(3), Color("7a7a86"))
		draw_rect(r, Color("6fc8d8"))




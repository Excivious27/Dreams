extends GameMap
## The mountain pass east of town: three wide terraces split by long cliff ledges,
## a hot spring, rock fields to mine, a lookout, a cave, and the rocket pad
## (penguin arc) or a smugglers' camp (gangster arc) up top. Exits: town, moon (pad).

const TOWN_EXIT := Rect2i(0, 38, 1, 4)
const PAD := Vector2i(28, 5)
const SPRING := Rect2i(44, 20, 3, 2)
const LEDGES := [[14, 24, 27], [28, 10, 13]]   # [row, stair x0, stair x1]
const FALLS_X := 52   # the stream runs down the top terrace and pours over the first ledge
const FALLS_BRIDGE := Vector2i(FALLS_X, 9)
const STREAM_BEND := {3: -1, 4: -1, 5: -1, 6: 1, 7: 1, 11: 1}  # row -> column offset of the stream
var _ledge := {}
var _falls_water := {}


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
	# Stream (1 wide) down the top terrace, the falls over the ledge, a pool at the foot.
	# It wanders a cell either way (straight under the bridge and at the lip), and
	# the bends are two cells wide so the water stays one body (c5_03 #4).
	var prev := 0
	for y in range(2, 14):
		var dx: int = STREAM_BEND.get(y, 0)
		for k in range(mini(dx, prev), maxi(dx, prev) + 1):
			var c := Vector2i(FALLS_X + k, y)
			if blocked.has(c) and not _falls_water.has(c):
				continue
			_falls_water[c] = true
			if c != FALLS_BRIDGE:  # the rope bridge crosses here
				set_thing(c.x, c.y, {"type": "water", "hint": ""})
		prev = dx
	# The plunge pool: an oval, not a box.
	for c: Vector2i in cells_of([Rect2i(FALLS_X - 1, 15, 3, 1), Rect2i(FALLS_X - 2, 16, 5, 1), Rect2i(FALLS_X - 1, 17, 3, 1)]):
		if blocked.has(c) or things.has(c):
			continue
		_falls_water[c] = true
		set_thing(c.x, c.y, {"type": "water", "hint": ""})
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
		if near_stairs or TOWN_EXIT.grow(3).has_point(c) or Rect2i(27, 29, 16, 2).has_point(c) or Rect2i(41, 29, 2, 16).has_point(c):
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
		to_under(a)
		a.play("idle")
	prop("props", "lookout_tower", Vector2i(48, 42), 1)
	block_rect(48, 39, 2, 4)
	if not Art.has("tiles", "t_cliffg"):
		for l in LEDGES:
			prop("props", "cliff_stairs_up", Vector2i(int(l[1]) + 1, int(l[0])), 0, 0.0, false)
	if Art.has("props", "rope_bridge2"):
		walk_over(prop("props", "rope_bridge2", FALLS_BRIDGE - Vector2i(1, 0), 2, 0.0, false), 4)
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
	for c in cells_of([Rect2i(26, 28, 18, 4), Rect2i(40, 28, 4, 18)]):
		avoid[c] = true  # the road to the quarry exit
	WorldGen.tree_clumps(self, Rect2i(2, 30, cols - 4, 14), 92, 5, avoid)
	WorldGen.tree_clumps(self, Rect2i(2, 16, 18, 10), 95, 2, avoid)
	WorldGen.scatter_props(self, Rect2i(2, 2, cols - 4, rows - 4), 93, 16, avoid)
	WorldGen.add_critters(self, Rect2i(2, 2, cols - 4, rows - 4), 94, 8, ["goat", "crow", "crow", "hedgehog", "sparrow"])
	for i in GameState.enemy_count(4):
		var at := cell_center(Vector2i(randi_range(6, cols - 7), randi_range(16, rows - 6)))
		spawn_enemy("golem" if GameState.is_penguins() else ("thug_enforcer" if GameState.progress_tier() >= 2 else "thug_brute"), at)
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
				return ToolHint.need(self, "pickaxe", "to break it")
			var ob := GameState.ore_block(str(thing.get("ore", "stone")))
			if ob != "":
				player.play_tool("pickaxe")
				hud.toast(ob, Color(1, 0.85, 0.6))
				Music.instance(get_tree()).sfx("dry_click", "thud")
				return true
			if not GameState.spend_for("pickaxe"):
				hud.toast("Too tired.", Color(1, 0.7, 0.7))
				return true
			player.play_tool("pickaxe")
			Music.instance(get_tree()).sfx("pick", "chop")
			hitstop = maxf(hitstop, 0.025)
			wobble(c, 0.04)
			fx("stone_chips", cell_center(c) + Vector2(0, -8), 16.0, 0.5)
			thing["hp"] = int(thing["hp"]) - 1
			if int(thing["hp"]) <= 0:
				hitstop = maxf(hitstop, 0.05)
				Music.instance(get_tree()).sfx("crate_break", "thud")
				fx("poof", cell_center(c) + Vector2(0, -6), 12.0, 0.4)
				var ore := str(thing["ore"])
				things.erase(c)
				blocked.erase(c)
				hard.erase(c)
				if props.has(c):
					(props[c] as Sprite2D).queue_free()
					props.erase(c)
				give(ore, 1 if ore != "stone" else 2)
				xp("mining", 2 if ore == "stone" else 5)
			return true
		"spring":
			if (int(GameState.run["energy"]) >= int(GameState.run["max_energy"]) or int(GameState.run.get("rest_en", 0)) >= int(GameState.run["max_energy"]) / 2) and int(GameState.run["hp"]) >= int(GameState.run["max_hp"]):
				hud.toast("You're fully rested. Come back when you're tired.")  # keep today's soak for later
			elif int(GameState.run["flags"].get("spring_day", 0)) < int(GameState.run["day"]):
				GameState.run["flags"]["spring_day"] = int(GameState.run["day"])
				var got := GameState.rest_energy(50)
				GameState.heal(3)
				hud.toast(("Ahh. +%d energy, +3 hearts." % got) if got > 0 else ("Ahh. +3 hearts. You've rested plenty today." if int(GameState.run.get("rest_en", 0)) >= int(GameState.run["max_energy"]) / 2 else "Ahh. +3 hearts."))
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
			GameState.run["mine_floor"] = 1
			go_to("mine", Vector2.ZERO)
			return true
		"camp":
			_camp()
			return true
	return false


func _pad() -> void:
	if not GameState.quest_done("clear_meadow") or (GameState.is_penguins() and not GameState.run["flags"].has("merkitty_done")):
		await say([{"who": "Star Crystal", "text": "(faintly) Not yet. The first spark has to be lit, and the merkitties freed, before we leave the ground."}])
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
	var picks := [[_blade(), 90], ["potion", GameState.shop_price("potion", 20)], ["energy_tea", GameState.shop_price("energy_tea", 60)]]
	var ch: Array = []
	for pk in picks:
		ch.append("%s  ◆%d" % [GameState.item_name(str(pk[0])), int(pk[1])])
	# The gangster road to Space (CONDUCT 4): the smugglers run a cargo rocket to the
	# moon, and once you've ridden it the farm's launchpad has a beacon to fly to.
	var moon_i := -1
	if GameState.quest_done("clear_meadow"):
		moon_i = ch.size()
		ch.append("Ride the cargo rocket to the moon")
	ch.append("Leave")
	d.say([{"who": "Smuggler", "text": "No names, no questions. You have ◆%d." % int(GameState.run["crystals"]), "choice": ch, "key": ""}])
	await d.finished
	if moon_i >= 0 and d.last_choice == moon_i:
		await say([{"who": "Smuggler", "text": "Moon run leaves when you sit down. We drop a landing beacon up there for regulars, so your own rocket can find it after. Don't touch the crates with the stamp on."}])
		GameState.run["flags"]["moon_unlocked"] = true
		fx("levelup", cell_center(PAD) + Vector2(0, -8), 10.0, 0.8)
		go_to("moon", Vector2(12 * TILE, 18 * TILE), "down")
		return
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
		if id == _blade():
			GameState.add_tool(id)
			hud.toast("Got the %s." % GameState.item_name(id), Color(1, 0.9, 0.4))
		else:
			give(id)


func draw_map() -> void:
	draw_grass(9)
	WorldGen.draw_ground_detail(self, 95, 0.05)
	# Top terrace is bare stone; the others grassy with a dirt switchback.
	draw_ground("stone", cells_of([Rect2i(20, 1, 18, 8)]))
	# One continuous switchback: west gate → up the left stairs → across → up the
	# middle stairs → the top terrace. Every stair gap has the path running through it.
	var trail := cells_of([Rect2i(1, 38, 10, 3), Rect2i(10, 27, 3, 14), Rect2i(10, 29, 18, 2), Rect2i(25, 13, 3, 18), Rect2i(25, 8, 3, 6), Rect2i(13, 1, 2, 3), Rect2i(13, 3, 8, 2), Rect2i(27, 29, 16, 2), Rect2i(41, 29, 2, 16)])  # + the quarry exit  # + the highlands exit
	# The trail stops at each stair set (soft ground draws over the map, so it
	# would bury the steps) and carries on at its foot and top.
	for l in LEDGES:
		for x in range(int(l[1]) - 1, int(l[2]) + 2):
			for yy in range(int(l[0]) - 2, int(l[0]) + 1):
				trail.erase(Vector2i(x, yy))
	draw_ground("dirt", trail)
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
				for x in range(-pad, cols + pad):  # on under the border band: no edge at the map side
					top[Vector2i(x, yy)] = true
			draw_plateau(top, "cliffg", stairs)
	if not _falls_water.is_empty():
		draw_water(_falls_water, "river")
	if Art.has("tiles", "waterfall2") and _anim_layer:
		# One fall over the ledge: cap once, a run of middle pieces, foam foot at the pool.
		_anim_layer.jobs.append(func(ci: CanvasItem) -> void:
			var fr := int(Time.get_ticks_msec() / 120) % 4
			var wt := Art.tex("tiles", "waterfall2")
			var fx0 := FALLS_X * TILE
			ci.draw_texture_rect_region(wt, Rect2(fx0, 13 * TILE, TILE, 10), Rect2(fr * 32, 0, 32, 20))
			var yy := 13 * TILE + 10
			while yy < 15 * TILE - 2:
				ci.draw_texture_rect_region(wt, Rect2(fx0, yy, TILE, 12), Rect2(fr * 32, 20, 32, 24))
				yy += 12
			ci.draw_texture_rect_region(wt, Rect2(fx0, 15 * TILE - 2, TILE, 10), Rect2(fr * 32, 44, 32, 20)))
	draw_exits()
	if not Art.has("props", "hot_spring"):
		var r := Rect2(SPRING.position * TILE, SPRING.size * TILE)
		draw_rect(r.grow(3), Color("7a7a86"))
		draw_rect(r, Color("6fc8d8"))


## The vendor's weapon: an Iron Sword, or in the gangster arc a Crowbar (the
## gang arc's blade-free equivalent, same punch; C4 P6).
static func _blade() -> String:
	return "crowbar" if GameState.street_bat() else "iron_sword"

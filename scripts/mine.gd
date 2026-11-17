extends GameMap
## The mine: a floor of rock to break with the pickaxe (stone, copper, iron,
## crystal shards), slimes and bats, and a ladder down to a harder floor.
## The layout is generated from the floor number so it's the same each visit.

var floor_no := 1
var _grotto := false
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
	# Floor 5: the flooded grotto. Half the floor is black water; crystals sit
	# under it. Mer the mercat lives here; with her you can swim and dive.
	_grotto = floor_no == 5
	if _grotto:
		for y in range(6, rows - 1):
			for x in range(1, cols - 1):
				var wc := Vector2i(x, y)
				if WorldGen.fbm(float(x), float(y), 55, 6.0) > -0.1 and wc.distance_to(_ladder) > 2:
					set_thing(x, y, {"type": "water", "hint": ""}, true)
		swim_ok = true
		set_thing(4, 4, {"type": "mer", "hint": "A: ...a cat?"}, false)
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = 5555
		var placed := 0
		for i in 60:
			var c := Vector2i(rng2.randi_range(2, cols - 3), rng2.randi_range(8, rows - 2))
			if is_water_cell(c) and not things[c].has("crystal"):
				things[c] = {"type": "water", "crystal": true, "key": "grotto_%d" % placed, "hint": "A: dive for the crystal"}
				placed += 1
				if placed >= 6:
					break
	var count := 40 + floor_no * 4
	for i in count:
		if _grotto and i > count / 2:
			break
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
			if str(GameState.run["flags"].get("mine_from", "meadow")) == "mountain":
				go_to("mountain", Vector2(6 * TILE, 5 * TILE), "down")
			else:
				go_to("meadow", Vector2(31 * TILE, 8 * TILE + 8), "down")
			return true
		"mer":
			later(_meet_mer)
			return true
		"water":
			if bool(thing.get("crystal", false)):
				if not Companion.has_ability("tail"):
					hud.toast("Too deep. Something glints down there.", Color(0.8, 0.9, 1.0))
					return true
				if GameState.run["flags"].has(str(thing["key"])):
					hud.toast("Already took that one.")
					return true
				GameState.run["flags"][str(thing["key"])] = true
				thing.erase("crystal")
				thing["hint"] = ""
				player.play_tool("hold")
				fx("splash", player.position, 12.0, 0.6)
				pop_items(cell_center(c), "shard", 2)
				xp("mining", 8)
				var got := 0
				for k in GameState.run["flags"]:
					if str(k).begins_with("grotto_"):
						got += 1
				if got >= 6:
					GameState.run["flags"]["grotto_done"] = true
					hud.toast("That's all six. Mer hums.", Color(0.8, 0.9, 1.0))
				return true
			return false
		"down":
			if _grotto and not GameState.run["flags"].has("grotto_done"):
				hud.toast("The ladder is under the water. You'd need to swim like she does.", Color(0.8, 0.9, 1.0))
				return true
			GameState.run["mine_floor"] = floor_no + 1
			xp("mining", 4)
			go_to("mine", Vector2.ZERO)
			return true
		"skeleton":
			if not GameState.run["flags"].has("skel_%d" % floor_no):
				GameState.run["flags"]["skel_%d" % floor_no] = true
				give("gold", 2)
				tell([{"text": "Somebody didn't make it back up. Their pack still has something in it."}])
			return true
		"rock":
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


func _variant() -> String:
	if floor_no >= 10:
		return "lava"
	if floor_no >= 7:
		return "ice"
	if floor_no >= 4:
		return "stone"
	return "earth"


func draw_map() -> void:
	var v := _variant()
	if _grotto:
		var wc := {}
		for c in things:
			if str(things[c].get("type", "")) == "water":
				wc[c] = true
		draw_water(wc, "grass")
	if Art.has("tiles", "mf_" + v) and Art.has("tiles", "mw_" + v):
		draw_tileset_rect("mf_" + v, Rect2i(1, 1, cols - 2, rows - 2), Color("3b3542"))
		draw_rect(Rect2(0, 0, cols * TILE, rows * TILE), Color(0.05, 0.03, 0.1, 0.15 + 0.03 * mini(floor_no, 8)))
		var w := "mw_" + v
		for x in range(1, cols - 1):
			Art.draw_tile(self, "tiles", w, Vector2(x * TILE, 0), 1)
			Art.draw_tile(self, "tiles", w, Vector2(x * TILE, (rows - 1) * TILE), 7)
		for y in range(1, rows - 1):
			Art.draw_tile(self, "tiles", w, Vector2(0, y * TILE), 3)
			Art.draw_tile(self, "tiles", w, Vector2((cols - 1) * TILE, y * TILE), 5)
		Art.draw_tile(self, "tiles", w, Vector2(0, 0), 0)
		Art.draw_tile(self, "tiles", w, Vector2((cols - 1) * TILE, 0), 2)
		Art.draw_tile(self, "tiles", w, Vector2(0, (rows - 1) * TILE), 6)
		Art.draw_tile(self, "tiles", w, Vector2((cols - 1) * TILE, (rows - 1) * TILE), 8)
		if v == "lava" and Art.has("tiles", "lava"):
			_anim_layer.jobs.append(func(ci: CanvasItem) -> void:
				var frame := int(Time.get_ticks_msec() / 300) % 4
				for c: Vector2i in cells_of([Rect2i(3, 12, 4, 3), Rect2i(12, 4, 3, 2)]):
					Art.draw_tile(ci, "tiles", "lava", Vector2(c * TILE), frame))
	elif Art.has("tiles", "mine_floor"):
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
				if Art.has("props", "ladder_a"):
					nm = "ladder_a" if str(t["type"]) == "up" else "shaft"
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
		var v := _variant()
		var deep := Art.has("props", "node_copper")
		for k in things:
			var t: Dictionary = things[k]
			if str(t.get("type", "")) != "rock":
				continue
			var ore := str(t["ore"])
			var nm: String = {"stone": "mrock_a" if (k.x + k.y) % 3 != 0 else "mrock_b", "copper": "ore_copper", "iron": "ore_iron", "shard": "ore_crystal", "gold": "ore_gold", "dark": "ore_dark"}.get(ore, "mrock_a")
			if deep:
				nm = {"stone": "mrock_%s_%d" % [v, (k.x + k.y) % 2], "copper": "node_copper", "iron": "node_iron", "shard": "node_crystal", "gold": "node_gold", "dark": "node_dark"}.get(ore, nm)
			prop("props", nm, k)
		if deep:
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = 4000 + floor_no
			for i in 3:
				var c := Vector2i(rng2.randi_range(2, cols - 3), rng2.randi_range(2, rows - 3))
				if not things.has(c) and not blocked.has(c):
					prop("props", ["cluster_blue", "cluster_purple", "gmush_blue", "gmush_red", "stalagmite_a"][rng2.randi_range(0, 4)], c)
			for x in [3, cols - 4]:
				var sp := Art.sprite("props", "stalactite_%s" % ["a", "b", "c"][x % 3])
				if sp:
					sp.position = Vector2(x * TILE + 8, TILE + 20)
					add_child(sp)
			prop("props", "beam_lamp", Vector2i(cols / 2 - 1, 1), 1)
			if floor_no % 2 == 0:
				prop("props", "cart_full", Vector2i(2, rows - 3))
				blocked[Vector2i(2, rows - 3)] = true
			if floor_no % 5 == 0:
				prop("props", "skeleton", Vector2i(cols - 3, 2))
				blocked[Vector2i(cols - 3, 2)] = true
				set_thing(cols - 3, 2, {"type": "skeleton", "hint": "A: an old miner"})
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


func _process(delta: float) -> void:
	super(delta)


## Mer, the mercat of the grotto. Join her and the water opens.
func _meet_mer() -> void:
	player.frozen = true
	if Companion.party()["known"].has("mer"):
		var d0 := Dialogue.instance(get_tree())
		d0.say([{"who": "Mer", "text": "Swim with me?" if Companion.active_id() != "mer" else "I'm right here. The ladder's under the deep part, past the six stones.", "choice": ["Mer joins me", "Not now"] if Companion.active_id() != "mer" else ["OK"], "key": ""}])
		await d0.finished
		if d0.last_choice == 0 and Companion.active_id() != "mer":
			Companion.recruit("mer")
			hud.toast("Mer is with you. The water is yours.", Color(0.8, 0.95, 1.0))
			_refresh_party()
		player.frozen = false
		return
	await say([
		{"who": "", "text": "On a dry rock at the water's edge: a cat. Grey, wet, entirely unbothered. Its tail is... not a cat's tail."},
		{"who": "Mer", "text": "You came down the dark stair with a lantern and no fear. That's rarer than crystal."},
		{"who": "Mer", "text": "I'm Mer. I was a cat once, before the water. Now I'm a mercat, which is better in every way but the fur."},
		{"who": "Mer", "text": "The crystals you want are under the black water. Six of them. You can't reach them; your kind sinks."},
		{"who": "Mer", "text": "But if I'm beside you, the water remembers me, and it'll let you borrow a tail. Breathe, dive, the lot. Only while I'm with you, mind."},
	])
	var d := Dialogue.instance(get_tree())
	d.say([{"who": "Mer", "text": "Come on, then. The water's warmer than it looks.", "choice": ["Swim with Mer", "Not yet"], "key": ""}])
	await d.finished
	if d.last_choice == 0:
		Companion.recruit("mer")
		GameState.add_quest("mer_crystals", "Dive with Mer for the six grotto crystals.")
		hud.toast("Mer joined you! Walk into the water.", Color(0.8, 0.95, 1.0))
		Music.instance(get_tree()).sfx("levelup")
		_refresh_party()
	else:
		Companion.refuse("mer")
		await say([{"who": "Mer", "text": "...Suit yourself. I'll be here. I'm always here."}])
	player.frozen = false

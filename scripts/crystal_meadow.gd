extends GameMap
## East of the meadow. Penguin arc: the Crystal Meadow, where the Light Crystal's
## power has soaked into the ground: glowing crystals, crystal blooms to forage,
## standing stones, and Grumps pushing in from the wastes (east). Gangster arc:
## the Outskirts, a run-down strip with the hideout shack, a black market and
## the President's muscle. Exits: meadow (west), wastes/city (east, locked for now).

const MEADOW_EXIT := Rect2i(0, 11, 1, 3)
const EAST_GATE := Vector2i(33, 12)
const STONES := Rect2i(14, 8, 7, 7)


func scene_id() -> String:
	return "crystal_meadow"


func default_spawn() -> Vector2:
	return Vector2(2 * TILE, 12 * TILE)


func build() -> void:
	cols = 34
	rows = 26
	music_track = "meadow" if GameState.is_penguins() else "rain"
	add_exit(MEADOW_EXIT, "meadow", Vector2(33 * TILE, 15 * TILE + 8), "left", "◀ meadow")
	set_thing(EAST_GATE.x, EAST_GATE.y, {"type": "gate", "hint": "A: the way east"})
	set_thing(EAST_GATE.x, EAST_GATE.y + 1, {"type": "gate", "hint": "A: the way east"})
	var rng := RandomNumberGenerator.new()
	rng.seed = 101 + int(GameState.run["day"])
	if GameState.is_penguins():
		# Standing stones ring.
		for c: Vector2i in [Vector2i(14, 8), Vector2i(17, 7), Vector2i(20, 8), Vector2i(13, 11), Vector2i(21, 11), Vector2i(14, 14), Vector2i(17, 15), Vector2i(20, 14)]:
			set_thing(c.x, c.y, {"type": "stone", "hint": ""})
		set_thing(17, 11, {"type": "altar", "hint": "A: the crystal altar"})
		for i in 10:
			var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(2, rows - 3))
			if things.has(c) or STONES.has_point(c):
				continue
			var key := "forage_cm_%d_%d" % [c.x, c.y]
			if int(GameState.run["flags"].get(key, 0)) >= int(GameState.run["day"]):
				continue
			things[c] = {"type": "forage", "key": key, "item": "crystal_bloom", "hint": "A: pick crystal bloom"}
	else:
		set_thing(10, 6, {"type": "shack", "hint": "A: the old shack"})
		block_rect(7, 2, 7, 5)
		set_thing(24, 7, {"type": "market", "hint": "A: black market"})
		block_rect(22, 4, 5, 4)


func after_ready() -> void:
	WorldGen.add_backdrop(self, "hills" if GameState.is_penguins() else "gritty")
	var avoid := {}
	if GameState.is_penguins():
		for c in things.keys():
			if str(things[c].get("type", "")) == "stone":
				prop("props", "moon_crystal_blue_s" if (c.x + c.y) % 2 == 0 else "moon_crystal_pink_s", c)
			elif str(things[c].get("type", "")) == "forage":
				prop("props", "moon_grass_c", c)
		prop("props", "moon_crystal_blue", Vector2i(17, 11))
		for c: Vector2i in [Vector2i(5, 4), Vector2i(28, 5), Vector2i(6, 21), Vector2i(27, 21), Vector2i(30, 16)]:
			prop("props", "moon_crystal_pink" if c.x > 17 else "moon_crystal_blue", c)
			blocked[c] = true
		for y in range(STONES.position.y - 1, STONES.end.y + 1):
			for x in range(STONES.position.x - 1, STONES.end.x + 1):
				avoid[Vector2i(x, y)] = true
		WorldGen.tree_border(self, Rect2i(1, 1, cols - 2, rows - 2), 102, [MEADOW_EXIT.grow(2), Rect2i(31, 10, 3, 5)], 2)
		WorldGen.tree_clumps(self, Rect2i(2, 2, cols - 4, rows - 4), 103, 5, avoid)
		WorldGen.scatter_props(self, Rect2i(2, 2, cols - 4, rows - 4), 104, 14, avoid)
		WorldGen.add_critters(self, Rect2i(2, 2, cols - 4, rows - 4), 105, 8)
		for i in 4:
			spawn_enemy(["soldier", "archer", "wisp", "grump"][i], Vector2(randf_range(22, 31) * TILE, randf_range(4, 22) * TILE))
	else:
		prop("props", "shack", Vector2i(7, 6), 6)
		prop("props", "black_market", Vector2i(22, 7), 4)
		prop("props", "dumpster", Vector2i(16, 4), 1)
		block_rect(16, 3, 2, 2)
		for c: Vector2i in [Vector2i(4, 14), Vector2i(29, 15)]:
			prop("props", "crates_a", c)
			blocked[c] = true
		prop("props", "crates_c", Vector2i(18, 20), 1)
		block_rect(18, 19, 2, 2)
		var fb := prop("props", "fire_barrel_0", Vector2i(12, 18))
		if fb and Art.has("props", "fire_barrel"):
			fb.queue_free()
			var a := AnimatedSprite2D.new()
			a.sprite_frames = Art.frames("props", {"idle": "fire_barrel"}, {"idle": 8.0})
			a.animation = "idle"
			a.scale = Vector2(0.5, 0.5)
			a.position = cell_center(Vector2i(12, 18))
			a.offset = Vector2(0, -float(Art.info("props", "fire_barrel").get("cell_h", 40)) / 2.0)
			add_child(a)
			a.play("idle")
		blocked[Vector2i(12, 18)] = true
		for x in range(2, 32, 2):
			if x < 30 and x > 4:
				prop("props", "chain_fence_h", Vector2i(x, 23), 1)
				blocked[Vector2i(x, 23)] = true
				blocked[Vector2i(x + 1, 23)] = true
		for y in range(3, 24):
			for x in range(5, 28):
				avoid[Vector2i(x, y)] = true
		WorldGen.scatter_props(self, Rect2i(2, 2, cols - 4, rows - 4), 106, 10, avoid)
		WorldGen.add_critters(self, Rect2i(2, 2, cols - 4, rows - 4), 107, 3)
		for i in 4:
			spawn_enemy(["thug_cyber", "thug_gambler", "thug_speedster", "thug_flame"][i], Vector2(randf_range(20, 31) * TILE, randf_range(10, 22) * TILE))
	if not GameState.run["flags"].has("cm_seen"):
		GameState.run["flags"]["cm_seen"] = true
		player.frozen = true
		if GameState.is_penguins():
			await say([{"text": "The grass here glows at the tips. Crystals grow out of the ground like flowers. In the middle, a ring of standing stones hums the same note as the thing in your field."}])
		else:
			await say([{"text": "The Outskirts. A shack with boarded windows, a market under a torn tarp, and a fence that says the city starts past here. The President's people are already around."}])
		player.frozen = false


func interact(_c: Vector2i, thing: Dictionary) -> bool:
	match str(thing.get("type", "")):
		"altar":
			_altar()
			return true
		"gate":
			if GameState.is_penguins():
				await say([{"who": "Light Crystal", "text": "Past here the colour drains out of everything. The Grump Wastes. We go in when you've got more than a wooden sword and a good heart. (Tom: this is where chapter 2 starts.)"}])
			else:
				await say([{"text": "A chain-link gate, and past it the road to the city. The lock is new. Somebody doesn't want you leaving. (Tom: the districts start here.)"}])
			return true
		"shack":
			await say([{"text": "The old shack. Someone lived here before you and left in a hurry. A corkboard inside has photos with the faces cut out."}])
			return true
		"market":
			_market()
			return true
	return false


func _altar() -> void:
	var refined := GameState.count("crystal_refined")
	if refined > 0:
		GameState.add_item("crystal_refined", -1)
		GameState.run["flags"]["altar_charges"] = int(GameState.run["flags"].get("altar_charges", 0)) + 1
		fx("pawring", cell_center(Vector2i(17, 11)) + Vector2(0, -12), 10.0, 0.8)
		GameState.run["max_hp"] = int(GameState.run["max_hp"]) + 1
		GameState.run["hp"] = int(GameState.run["max_hp"])
		await say([{"who": "Light Crystal", "text": "Yes. That's it. Every refined crystal you bring here grows the Meow Pow Wow a little. (+1 max heart)", "mood": "happy"}])
	else:
		await say([{"who": "Light Crystal", "text": "Bring a Refined Crystal (3 shards in the resonator on your farm) and set it here."}])


func _market() -> void:
	var d := Dialogue.instance(get_tree())
	d.say([{"who": "Black market", "text": "Cash only. No receipts. (◆%d)" % int(GameState.run["crystals"]), "choice": ["Iron Sword  ◆100", "Red Potion  ◆22", "Dark Shard  ◆60", "Leave"], "key": ""}])
	await d.finished
	var picks := [["iron_sword", 100], ["potion", 22], ["dark", 60]]
	if d.last_choice >= 0 and d.last_choice < picks.size():
		var id: String = picks[d.last_choice][0]
		var price: int = picks[d.last_choice][1]
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
	if GameState.is_penguins():
		draw_grass(9)
		WorldGen.draw_ground_detail(self, 108, 0.2)
		draw_tileset_rect("moon_dust", STONES, Color("c9c0e0"))
		draw_tileset_rect("dirt", Rect2i(1, 11, 13, 3), Color("b8945a"))
		draw_tileset_rect("dirt", Rect2i(21, 11, 13, 3), Color("b8945a"))
	else:
		draw_tileset_rect("dirt_lot", Rect2i(0, 0, cols, rows), Color("6a5a40"))
		draw_tileset_rect("asphalt", Rect2i(1, 11, 32, 3), Color("3a3a40"))
		draw_tileset_rect("sidewalk", Rect2i(6, 8, 22, 1), Color("8a8a90"))
		draw_tileset_rect("sidewalk", Rect2i(6, 15, 22, 1), Color("8a8a90"))
	draw_exits()
	var gp := cell_center(EAST_GATE)
	draw_rect(Rect2(gp.x - 8, gp.y - 30, 16, 32), Color("3a2412") if GameState.is_penguins() else Color("5a5a66"))
	label("east", Vector2(gp.x - 24, gp.y - 34), 48)
	draw_fence_border(Color("6b4a2b") if GameState.is_penguins() else Color("5a5a66"))

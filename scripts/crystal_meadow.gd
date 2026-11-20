extends GameMap
## East of the meadow. Penguin arc: the Crystal Meadow, where the Star Crystal's
## power has soaked into the ground: glowing crystals, crystal blooms to forage,
## standing stones, and Grumps pushing in from the wastes (east). Gangster arc:
## the Outskirts, a run-down strip with the hideout shack, a black market and
## the President's muscle. Exits: meadow (west), wastes/city (east, locked for now).

const MEADOW_EXIT := Rect2i(0, 11, 1, 3)
const EAST_GATE := Vector2i(33, 12)
const STONES := Rect2i(14, 8, 7, 7)
const POND := Rect2i(4, 13, 4, 4)  # the glow pond and its rim: no forage or scatter on it


func scene_id() -> String:
	return "crystal_meadow"


func default_spawn() -> Vector2:
	return Vector2(2 * TILE, 12 * TILE) + offset()


func build() -> void:
	cols = 34
	rows = 26
	pad = 6
	border = {"n": "trees", "s": "trees", "w": "trees", "e": "cliff"}
	music_track = "cattopia" if GameState.is_penguins() else GameMap.first_track(["outskirts", "hideout", "rain"])  # gang turf song (c6_02)
	add_exit(MEADOW_EXIT, "meadow", Vector2(51 * TILE, 15 * TILE + 8), "left", "◀ meadow")
	set_thing(EAST_GATE.x, EAST_GATE.y, {"type": "gate", "hint": "A: the way east"})
	set_thing(EAST_GATE.x, EAST_GATE.y + 1, {"type": "gate", "hint": "A: the way east"})
	var rng := RandomNumberGenerator.new()
	rng.seed = 101 + int(GameState.run["day"])
	if GameState.is_penguins():
		# Standing stones ring.
		for c: Vector2i in [Vector2i(14, 8), Vector2i(17, 7), Vector2i(20, 8), Vector2i(13, 11), Vector2i(21, 11), Vector2i(14, 14), Vector2i(17, 15), Vector2i(20, 14)]:
			set_thing(c.x, c.y, {"type": "stone", "hint": ""})
		set_thing(17, 11, {"type": "altar", "hint": "A: the crystal altar"})
		for i in 4:  # crystal blooms: a handful a day (70 each), not a 700/day forage battery
			var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(2, rows - 3))
			if things.has(c) or STONES.has_point(c) or POND.has_point(c):
				continue
			var key := "forage_cm_%d_%d" % [c.x, c.y]
			if int(GameState.run["flags"].get(key, 0)) >= int(GameState.run["day"]):
				continue
			things[c] = {"type": "forage", "key": key, "item": "crystal_bloom", "hint": "A: pick crystal bloom"}
	else:
		set_thing(10, 6, {"type": "shack", "hint": "A: the old shack"})
		set_thing(24, 7, {"type": "market", "hint": "A: black market"})
	extend(14, 10)
	# The gate belongs on the east edge of the grown map, with the road running to it.
	var g := Vector2i(cols - 1, EAST_GATE.y)
	for k in 2:
		var o := EAST_GATE + Vector2i(0, k)
		var t: Dictionary = things.get(o, {})
		things.erase(o)
		blocked.erase(o)
		hard.erase(o)
		set_thing(g.x, g.y + k, t)
	for x in range(EAST_GATE.x, cols - 1):
		for y in range(11, 14):
			if GameState.is_penguins():
				_ext_paths[Vector2i(x, y)] = true  # (gangsters: the asphalt already runs to the gate)
			blocked.erase(Vector2i(x, y))
			hard.erase(Vector2i(x, y))
	_gate = g


var _gate := EAST_GATE


func after_ready() -> void:
	set_aurora(GameState.is_penguins())
	WorldGen.add_backdrop(self, "hills" if GameState.is_penguins() else "gritty")
	if GameState.is_penguins():
		_catkins = Npc.new()
		_catkins.map = self
		_catkins.setup("catkins", GameState.npcs["catkins"], cell_center(Vector2i(cols - 12, 8)))
		_catkins.wander = 6.0
		add_child(_catkins)
	if Art.has("props", "cat_statue") and GameState.is_penguins():
		prop("props", "cat_statue", Vector2i(cols - 10, 6), 1)
		set_thing(cols - 9, 7, {"type": "note", "text": "A stone cat, smiling, holding a crystal to its chest. Moss on its ears. Somebody still leaves flowers here.", "hint": "A: the cat statue"}, false)
	var avoid := {}
	if GameState.is_penguins():
		for c in things.keys():
			if str(things[c].get("type", "")) == "stone":
				prop("props", "moon_crystal_blue_s" if (c.x + c.y) % 2 == 0 else "moon_crystal_pink_s", c)
			elif str(things[c].get("type", "")) == "forage":
				prop("props", "moon_grass_c", c)
		if Art.has("props", "standing_stones"):
			for c in things.keys():
				if str(things[c].get("type", "")) == "stone" and props.has(c):
					(props[c] as Node).queue_free()
					props.erase(c)
			prop("props", "standing_stones", Vector2i(14, 14), 6, -4.0)
		prop("props", "ccrystal_4" if Art.has("props", "ccrystal_4") else "moon_crystal_blue", Vector2i(17, 11))
		for c: Vector2i in [Vector2i(5, 4), Vector2i(28, 5), Vector2i(6, 21), Vector2i(27, 21), Vector2i(30, 16)]:
			prop("props", ["ccrystal_2", "ccrystal_3"][c.x % 2] if Art.has("props", "ccrystal_2") else "moon_crystal_blue", c)
		if Art.has("props", "crystal_tree"):
			for c: Vector2i in [Vector2i(8, 7), Vector2i(26, 19)]:
				prop("props", "crystal_tree", c, 2)
			prop("props", "crystal_arch_c", Vector2i(21, 11), 2)
			var a := AnimatedSprite2D.new()
			a.sprite_frames = Art.frames("props", {"idle": "star_crater"}, {"idle": 3.0})
			a.animation = "idle"
			a.scale = Vector2(0.5, 0.5)
			a.position = cell_center(Vector2i(28, 22)) + Vector2(8, 0)
			a.offset = Vector2(0, -float(Art.info("props", "star_crater").get("cell_h", 200)) / 2.0)
			add_child(a)
			a.play("idle")
			set_thing(28, 23, {"type": "crater", "hint": "A: the fallen star"}, false)
			var gp := AnimatedSprite2D.new()
			gp.sprite_frames = Art.frames("props", {"idle": "glow_pond"}, {"idle": 3.0})
			gp.animation = "idle"
			gp.scale = Vector2(0.5, 0.5)
			gp.position = cell_center(Vector2i(5, 15)) + Vector2(8, 0)  # bottom at row 16's top: covers rows 14-15, its water cells
			gp.offset = Vector2(0, -float(Art.info("props", "glow_pond").get("cell_h", 72)) / 2.0)
			to_under(gp)
			# The pond is real water: you can't stand in it, and you can fish it.
			for c: Vector2i in cells_of([Rect2i(5, 14, 2, 2)]):
				set_thing(c.x, c.y, {"type": "water", "hint": "A: fish" if GameState.has_tool("rod") else ""})
		for y in range(STONES.position.y - 1, STONES.end.y + 1):
			for x in range(STONES.position.x - 1, STONES.end.x + 1):
				avoid[Vector2i(x, y)] = true
		for c: Vector2i in cells_of([POND]):
			avoid[c] = true
		WorldGen.tree_clumps(self, Rect2i(2, 2, cols - 4, rows - 4), 103, 5, avoid)
		WorldGen.scatter_props(self, Rect2i(2, 2, cols - 4, rows - 4), 104, 14, avoid)
		WorldGen.add_critters(self, Rect2i(2, 2, cols - 4, rows - 4), 105, 10, ["moon_rabbit", "crystal_fish", "butterfly_blue", "firefly", "rabbit"])
		for i in 4:
			spawn_enemy(["soldier", "archer", "wisp", "grump"][i], Vector2(randf_range(22, 31) * TILE, randf_range(4, 22) * TILE))
	else:
		prop("props", "shack", Vector2i(7, 6), 6)
		prop("props", "black_market", Vector2i(22, 7), 4)
		prop("props", "dumpster", Vector2i(16, 4), 1)
		for c: Vector2i in [Vector2i(4, 14), Vector2i(29, 15)]:
			prop("props", "crates_a", c)
		prop("props", "crates_c", Vector2i(18, 20), 1)
		# One barrel with a flickering fire (fire_barrel is a merged 4-barrel sheet).
		if anim_prop("props", "fire_barrel2", Vector2i(12, 18), 0, 8.0, true) == null:
			prop("props", "fire_barrel_0", Vector2i(12, 18))
		# The chain fence runs unbroken along the lot's south edge (30 px art = one cell).
		for x in range(5, 30):
			prop("props", "chain_fence_h", Vector2i(x, 23), 0, 0.0, true)
		# Lot clutter: a few drums, tyres and pipes on the dirt, off the road and sidewalks.
		var lot_rng := RandomNumberGenerator.new()
		lot_rng.seed = 110
		var junk := ["oil_drums", "tyres", "crates_b", "pipe_t", "tyres", "oil_drums"]
		var placed := 0
		for tries in 60:
			if placed >= 7:
				break
			var c := Vector2i(lot_rng.randi_range(4, 29), lot_rng.randi_range(16, 21))
			if lot_rng.randf() < 0.35:
				c.y = lot_rng.randi_range(3, 6)
			var clear := true
			for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var o := c + d
				if things.has(o) or blocked.has(o) or props.has(o) or (o.y >= 8 and o.y <= 15):
					clear = false
			if clear:
				prop("props", junk[placed % junk.size()], c)
				placed += 1
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


var _catkins: Npc = null


func _talk_catkins() -> void:
	player.frozen = true
	_catkins.face(player.position)
	if await Story.talk(self, "catkins"):
		player.frozen = false
		return
	if await Hearts.talk(self, "catkins"):
		player.frozen = false
		return
	if await SideStory.talk(self, "catkins"):  # C7 P4 side stories
		player.frozen = false
		return
	if not GameState.run["talked_today"].has("catkins"):
		GameState.run["talked_today"]["catkins"] = true
		GameState.add_friend("catkins", 5)
	var sel := str(GameState.run["selected"])
	if GameState.can_gift("catkins", sel) and await confirm_gift("Catkins", sel):
		var gain := GameState.give_gift("catkins", sel)
		await say([{"who": "Catkins", "text": gift_reaction("Catkins", sel, gain)}])
		hud.toast("Catkins %s%d" % ["+" if gain >= 0 else "", gain], Color(1, 0.8, 0.9) if gain > 0 else Color(1, 0.7, 0.7))
		player.frozen = false
		return
	var lines: Array = GameState.npcs["catkins"].get("lines", ["..."])
	if GameState.run["flags"].has("st_p2_spark"):
		# After the cave shook, Cat-topia's stores are open to you.
		var d := Dialogue.instance(get_tree())
		d.say([{"who": "Catkins", "text": str(lines[int(GameState.run["day"]) % lines.size()]), "choice": ["Buy supplies", "Just visiting"], "key": ""}])
		await d.finished
		if d.last_choice == 0:
			await Shops.run(self, "catkins")
		player.frozen = false
		return
	await say([{"who": "Catkins", "text": str(lines[int(GameState.run["day"]) % lines.size()])}])
	player.frozen = false


func interact(_c: Vector2i, thing: Dictionary) -> bool:
	if _catkins and _catkins.visible and (_catkins.cell() == _c or (thing.is_empty() and _catkins.position.distance_to(player.position + player.facing_dir() * 14.0) < 16.0)):
		later(_talk_catkins)
		return true
	match str(thing.get("type", "")):
		"water":
			# fish_at casts with the rod in hand, else says how to get it there
			fish_at(_c, ["minnow", "sunfish", "carp", "trout", "goldfish", "mooncarp"])
			return true
		"note":
			tell([{"text": str(thing.get("text", "..."))}])
			return true
		"altar":
			_altar()
			return true
		"gate":
			if not GameState.quest_done("clear_meadow"):
				if GameState.is_penguins():
					tell([{"who": "Star Crystal", "text": "Past here the colour drains out of everything. Clear the meadow first; I need you with the first spark lit."}])
				else:
					tell([{"text": "A chain-link gate, and past it the road to the city. Deal with the President's man in the meadow first. He has the key."}])
				return true
			if GameState.is_penguins():
				go_to("wastes", Vector2(2 * TILE, 13 * TILE + 8), "right")
			else:
				go_to("hideout", Vector2(2 * TILE, 14 * TILE + 8), "right")
			return true
		"crater":
			var sq := (GameState.has_quest("wren_starflower") and not GameState.quest_done("wren_starflower")) or (GameState.has_quest("lumi_starflower") and not GameState.quest_done("lumi_starflower"))
			if sq and GameState.count("starflower") == 0 and int(GameState.run["flags"].get("crater_flower", 0)) != int(GameState.run["day"]):
				GameState.run["flags"]["crater_flower"] = int(GameState.run["day"])
				give("starflower", 1)
				tell([{"text": "At the crater's lip, a small flower with light inside it. A starflower."}])
				return true
			tell([{"who": "Star Crystal", "text": ("This is where I landed first. The ground remembers, and now it's glad." if GameState.run["flags"].has("final_done") else "This is where I landed first, before your field. The ground remembers."), "mood": "happy"}])
			return true
		"shack":
			tell([{"text": "The old shack. Someone lived here before you and left in a hurry. A corkboard inside has a map of the valley with your farm circled."}])
			return true
		"market":
			_market()
			return true
	return false


func _altar() -> void:
	var refined := GameState.count("crystal_refined")
	var charges := int(GameState.run["flags"].get("altar_charges", 0))
	if charges >= 10:
		await say([{"who": "Star Crystal", "text": "The altar is full. It has given you all it can.", "mood": "happy"}])
	elif refined > 0:
		if refined <= 3 and GameState.has_quest("teleporter") and not GameState.quest_done("teleporter"):
			await say([{"who": "Star Crystal", "text": "Careful: the teleporter on the moon needs 3 refined crystals. Bring me a fourth and I'll take that one."}])
			return
		GameState.add_item("crystal_refined", -1)
		GameState.run["flags"]["altar_charges"] = charges + 1
		fx("pawring", cell_center(Vector2i(17, 11)) + Vector2(0, -12), 10.0, 0.8)
		GameState.grow_vital("hp", 5)
		GameState.run["hp"] = int(GameState.run["max_hp"])
		await say([{"who": "Star Crystal", "text": "Yes. That's it. Every refined crystal you bring here makes you a little sturdier. (+5 max health, %d/10)" % (charges + 1), "mood": "happy"}])
	else:
		await say([{"who": "Star Crystal", "text": "Bring a Refined Crystal (3 shards in the resonator on your farm) and set it here."}])


func _market() -> void:
	var d := Dialogue.instance(get_tree())
	var picks := [[_blade(), 100], ["potion", GameState.shop_price("potion", 22)], ["dark", GameState.shop_price("dark", 60)]]
	var ch: Array = []
	for pk in picks:
		ch.append("%s · ◆%d%s" % [GameState.item_name(str(pk[0])), int(pk[1]), " (owned)" if GameState.has_tool(str(pk[0])) else ""])
	ch.append("Leave")
	d.say([{"who": "Black market", "text": "Cash only. No receipts. (◆%d)" % int(GameState.run["crystals"]), "choice": ch, "key": ""}])
	await d.finished
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
	if GameState.is_penguins():
		draw_grass(9)
		var no_pond := {}
		for c: Vector2i in cells_of([POND]):
			no_pond[c] = true
		WorldGen.draw_ground_detail(self, 108, 0.2, no_pond)
		if Art.has("tiles", "g_glow"):
			# Glowing turf spreads out from the crystals in soft noise blobs, not boxes.
			var glow := {}
			for c: Vector2i in cells_of([Rect2i(6, 1, 28, 24)]):
				var n := WorldGen.fbm(float(c.x), float(c.y), 77, 7.0)
				var dist := Vector2(c).distance_to(Vector2(17, 11)) / 14.0
				if n - dist * 0.5 > -0.15:
					glow[c] = true
			# Tint stays <= 1 and half see-through: a soft cyan glow over the grass, not flat lime.
			if not soft_ground(glow, "meadow_grass", Color(0, 0, 0, 0), Color(0.78, 1.0, 0.96, 0.55)):
				for c: Vector2i in glow:
					Art.draw_tile(self, "tiles", "g_glow" if (c.x * 3 + c.y) % 5 != 0 else "g_glow_b", Vector2(c * TILE), 4)
			var rng := RandomNumberGenerator.new()
			rng.seed = 109
			for c: Vector2i in cells_of([Rect2i(10, 4, 23, 20)]):
				if rng.randf() < 0.08 and not blocked.has(c):
					Art.draw_prop(self, "props", "cdeco_%d" % rng.randi_range(0, 6), Vector2(c * TILE) + Vector2(8, 16))
		draw_tileset_rect("pale_stone" if Art.has("tiles", "pale_stone") else "moon_dust", STONES, Color("c9c0e0"))
		draw_ground("dirt", cells_of([Rect2i(-pad, 11, 14 + pad, 3), Rect2i(21, 11, 13, 3)]))  # the west path runs through the band in one patch
	else:
		draw_tileset_rect("dirt_lot", Rect2i(-pad, -pad, cols + 2 * pad, rows + 2 * pad), Color("6a5a40"))  # under the band too: no void column
		draw_tileset_rect("asphalt", Rect2i(1, 11, cols - 1, 3), Color("3a3a40"))  # on to the gate column
		draw_tileset_rect("sidewalk", Rect2i(6, 8, cols - 8, 1), Color("8a8a90"))
		draw_tileset_rect("sidewalk", Rect2i(6, 15, cols - 8, 1), Color("8a8a90"))
	draw_exits()
	# The east fence leaves a gap at the gate rows; the gate is drawn over it.
	var gap := {}
	for yy in range(_gate.y - 1, _gate.y + 3):
		gap[yy] = true
	if GameState.is_penguins() and Art.has("buildings", "fence_v"):
		for yy in range(1, rows - 1):  # only the east fence by the gate (rows +-5): the other sides are forest
			if not gap.has(yy + 1) and absi(yy + 1 - _gate.y) <= 5:
				Art.draw_prop(self, "buildings", "fence_v", Vector2((cols - 0.5) * TILE, (yy + 1) * TILE))
	else:
		draw_fence_border(Color("6b4a2b") if GameState.is_penguins() else Color("5a5a66"), gap)
	# Drawing space is content cells (no pad); cell_center() is world space.
	var gp := Vector2(_gate.x * TILE + TILE / 2.0, (_gate.y + 1) * TILE)
	if GameState.is_penguins() or not Art.draw_prop(self, "props", "chain_broken", gp + Vector2(0, 8)):
		draw_rect(Rect2(gp.x - 8, gp.y - 30, 16, 32), Color("3a2412") if GameState.is_penguins() else Color("5a5a66"))
	label("east" if GameState.is_penguins() else "hideout ▶", Vector2(gp.x - 24, gp.y - 34), 48)


## Penguins: draw_map already runs the west path through the band in one patch
## (a second corridor patch on top left a darker slab with a seam).
func draw_corridor(cells: Dictionary) -> void:
	if not GameState.is_penguins():
		# The asphalt road runs on through the band to the west edge (no dirt blob on it).
		var road := Rect2i(-pad, 11, pad + 3, 3)  # (the corridor reaches 2 cells in)
		var rest := {}
		for c: Vector2i in cells:
			if not road.has_point(c):
				rest[c] = true
		draw_tileset_rect("asphalt", road, Color("3a3a40"))
		if not rest.is_empty():
			super(rest)


## The vendor's weapon: an Iron Sword, or in the gangster arc a Crowbar (the
## gang arc's blade-free equivalent, same punch; C4 P6).
static func _blade() -> String:
	return "crowbar" if GameState.street_bat() else "iron_sword"

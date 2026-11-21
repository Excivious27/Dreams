extends GameMap
## The moon (penguin arc): lavender dust, craters, crystal gardens, the rocket
## house, a landing pad back to the mountain, a teleporter that isn't powered yet,
## and Grumps in space helmets (plain Grumps for now). Exit: mountain (pad).

const PAD := Vector2i(12, 19)
const CRATER := Rect2i(18, 6, 8, 7)


const ROCK_DAYS := [3, 7]          # stone / shard moon rocks come back after this many days
const MOON_SHARD_CHANCE := 0.35    # a shard rock's Moon Shard roll (moon-tier pick + Mining 7)

func scene_id() -> String:
	return "moon"


func default_spawn() -> Vector2:
	return Vector2(12 * TILE, 18 * TILE) + offset()


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
	set_thing(24, 20, {"type": "tele", "hint": "A: teleporter" if GameState.run["flags"].has("tele_on") else "A: teleporter (unpowered)"})
	var rng := RandomNumberGenerator.new()
	rng.seed = 111
	for i in 30:
		var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(2, rows - 3))
		if things.has(c) or blocked.has(c) or Rect2i(10, 17, 5, 4).has_point(c):
			continue
		var roll := rng.randf()
		if roll < 0.8:
			# C8 P4: broken moon rocks stay broken for ROCK_DAYS (shard rocks longer).
			if GameState.respawned("mrock_moon_%d_%d" % [c.x, c.y], ROCK_DAYS[1] if roll < 0.2 else ROCK_DAYS[0]):
				set_thing(c.x, c.y, {"type": "mrock", "ore": "shard" if roll < 0.2 else "stone", "hp": 3, "hint": "A: mine"})
		else:
			var key := "forage_moon_%d_%d" % [c.x, c.y]
			if int(GameState.run["flags"].get(key, 0)) < int(GameState.run["day"]):
				things[c] = {"type": "forage", "key": key, "item": "crystal_bloom", "hint": "A: pick"}
	fill_ext = false
	extend(10, 8)


func after_ready() -> void:
	WorldGen.add_backdrop(self, "moon")
	prop("props", "landing_pad", Vector2i(11, 21), 2, 0.0, false)  # you walk up onto the pad (it was a wall across its steps)
	if Art.has("props", "warp_pad"):
		var wp := AnimatedSprite2D.new()
		wp.sprite_frames = Art.frames("props", {"idle": "warp_pad"}, {"idle": 6.0})
		wp.animation = "idle"
		wp.scale = Vector2(0.5, 0.5)
		wp.position = cell_center(Vector2i(24, 20)) + Vector2(0, 2)
		wp.offset = Vector2(0, -float(Art.info("props", "warp_pad").get("cell_h", 64)) / 2.0 + 14)
		to_under(wp)
		wp.play("idle")
	prop("props", "rocket_house", Vector2i(3, 6), 3)  # footprint = the art (4 cells), no invisible cell beside it
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
		mc.visible = not RanchGift.given(MOON_COW_KEY)
		set_thing(21, 16, {"type": "moon_cow", "hint": "A: moon cow"}, false)  # C11b P3: she can come home
		var sp := AnimatedSprite2D.new()
		sp.sprite_frames = Art.frames("props", {"idle": "moon_spire_anim"}, {"idle": 3.0})
		sp.animation = "idle"
		sp.scale = Vector2(0.5, 0.5)
		sp.position = cell_center(Vector2i(22, 11)) + Vector2(8, 0)
		sp.offset = Vector2(0, -80)
		add_child(sp)
		sp.play("idle")
		for c: Vector2i in [Vector2i(3, 20), Vector2i(27, 8), Vector2i(10, 12)]:
			prop("props", ["starflower_blue", "starflower_pink", "starflower_yellow"][c.x % 3], c)
	# The finale's only trigger: placed even if the moon art is missing.
	set_thing(22, 12, {"type": "spire", "hint": "A: the crystal spire"}, false)
	var t := prop("props", "teleporter", Vector2i(23, 20), 2)
	if t:
		t.queue_free()
		props.erase(Vector2i(23, 20))
		blocked.erase(Vector2i(23, 20))  # the 2-cell teleporter is drawn over 24-25
		hard.erase(Vector2i(23, 20))
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
	var gang := not GameState.is_penguins()
	for i in 4:
		var kind: String = (["thug_lookout", "thug_enforcer", "shard", "wisp"] if gang else ["grump", "soldier", "shard", "wisp"])[i]
		var at := Vector2(randf_range(14, 28) * TILE, randf_range(3, 23) * TILE)
		for tries in 30:  # never on top of where you land (>= 64 px from the arrival)
			if player == null or at.distance_to(player.position) >= 64.0:
				break
			at = Vector2(randf_range(14, 28) * TILE, randf_range(3, 23) * TILE)
		spawn_enemy(kind, at, 4)
	if not GameState.run["flags"].has("moon_seen"):
		GameState.run["flags"]["moon_seen"] = true
		player.frozen = true
		if gang:
			await say([
				{"text": "Silence, and lavender dust that puffs up and falls slower than it should. The sky is black and full of stars, and the city is a little glowing coin far below."},
				{"text": "Somebody got here first: crates with the President's stamp, and a teleporter pad that goes further out. " + ("Three Refined Crystals would wake it, and you're carrying them." if GameState.count("crystal_refined") >= 3 else "Its panel wants three Refined Crystals.")},
			])
		else:
			await say([
				{"text": "Silence, and lavender dust that puffs up and falls slower than it should. The sky is black and full of stars, and the valley is a green coin far below."},
				{"who": "Star Crystal", "text": "This is where I fell from. There's a teleporter here that goes further out. " + ("Three Refined Crystals would wake it, and you're carrying them." if GameState.count("crystal_refined") >= 3 else "It wants three Refined Crystals. The resonator makes them."), "mood": "worried"},
			])
		player.frozen = false


func interact(c: Vector2i, thing: Dictionary) -> bool:
	match str(thing.get("type", "")):
		"pad":
			go_to("mountain", Vector2(27 * TILE + 8, 9 * TILE), "down")
			return true
		"alien_shop":
			later(_alien_shop)
			return true
		"moon_cow":
			later(_moon_cow)
			return true
		"spire" when not GameState.is_penguins():
			tell([{"text": "A spire of glass grown out of the moon. Something inside hums the same tune the neon signs do. Not your business. Yet."}])
			return true
		"spire_old" when not GameState.is_penguins():
			tell([{"text": "A crystal the size of a house, grown right into the rock. The President's crates are stacked around it like he's waiting to move it."}])
			return true
		"spire":
			later(func() -> void:
				if await Story.talk(self, "spire"):
					return
				tell([{"who": "Star Crystal", "text": (("It's quiet now. Whatever lived in it has somewhere better to be." if GameState.run["flags"].has("dc_reverted") else "It's quiet now. Just glass, and the stars through it.") if GameState.run["flags"].has("final_done") else ("It's still in there. Steady, and finish it." if GameState.run["flags"].has("final_started") else "Not yet. Light the teleporter first. The spire won't listen until it's lit.")), "mood": "worried"}]))
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
					things[Vector2i(24, 20)]["hint"] = "A: teleporter"
					fx("levelup", cell_center(Vector2i(24, 20)), 10.0, 0.8)
					later(_tele_first)
					return true
				go_to("station", Vector2(4 * TILE, 12 * TILE + 8), "right")
			else:
				tell([{"text": "The pad glows faintly and does nothing. A panel beside it wants Refined Crystals. Three. (You have %d.)" % GameState.count("crystal_refined")}])
			return true
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
			GameState.toughen(thing, "pickaxe")
			thing["hp"] = int(thing["hp"]) - Mining.swing_roll()
			if int(thing["hp"]) <= 0:
				hitstop = maxf(hitstop, 0.05)
				Music.instance(get_tree()).sfx("rock_break", "crate_break")
				fx("poof", cell_center(c) + Vector2(0, -6), 12.0, 0.4)
				var ore := str(thing["ore"])
				things.erase(c)
				blocked.erase(c)
				hard.erase(c)
				if props.has(c):
					(props[c] as Sprite2D).queue_free()
					props.erase(c)
				GameState.run["flags"]["mrock_moon_%d_%d" % [c.x, c.y]] = maxi(1, int(GameState.run["day"]))
				give(ore, 2)
				# Moon Shards need the pick and Mining their tier asks for (ORE_TIER/ORE_SKILL).
				if ore == "shard" and randf() < MOON_SHARD_CHANCE and GameState.ore_block("moon_shard") == "":
					give("moon_shard", 1)
				xp("mining", 4)
			return true
	return false


func draw_map() -> void:
	draw_tileset_rect("moon_dust", Rect2i(-pad, -pad, cols + 2 * pad, rows + 2 * pad), Color("b9a8d8"))  # under the band too: no void rows
	draw_tileset_rect("crater", CRATER, Color("8a7ab8"))


func _alien_shop() -> void:
	var d := Dialogue.instance(get_tree())
	var p1 := GameState.shop_price("dream_tonic", 200)
	var p2 := GameState.shop_price("energy_tea", 70)
	var ch: Array = ["Dream Tonic  %s" % Money.fmt(p1), "Energy Tea  %s" % Money.fmt(p2)]
	var pets := not Shops.animals_for("alien").is_empty()  # C11b P3: the Moon Hare line, once the story opens it
	if pets:
		ch.append("Moon creatures")
	ch.append("Leave")
	d.say([{"who": "Alien trader", "text": "Zzzt. Crystals for goods. Goods for crystals. Zzzt. (%s)" % Money.fmt(int(GameState.run["crystals"])), "choice": ch, "key": ""}])
	await d.finished
	if pets and d.last_choice == 2:
		await Shops.animal_counter(self, "alien", "Alien trader")
		return
	if d.last_choice == 0 and int(GameState.run["crystals"]) >= p1:
		GameState.run["crystals"] = int(GameState.run["crystals"]) - p1
		give("dream_tonic")
	elif d.last_choice == 1 and int(GameState.run["crystals"]) >= p2:
		GameState.run["crystals"] = int(GameState.run["crystals"]) - p2
		give("energy_tea")
	elif d.last_choice in [0, 1]:
		hud.toast("Not enough crystals.", Color(1, 0.7, 0.7))


## C11b P3 (c11b_02-04): the Moon's crystal-horned cow goes home with you once Gideon's moon quest is done.
const MOON_COW_KEY := "moon:cow"


func _moon_cow() -> void:
	if RanchGift.given(MOON_COW_KEY):
		await say([{"text": "The moon cow's old grazing spot. A ring of nibbled moon moss is all she left."}])
		return
	if not GameState.quest_done("gideon_moon") or not GameState.is_penguins():
		await say([{"text": "A cow with crystal horns, grazing on nothing at all. She looks at you, then back at the stars. Maybe someone down home knows about the moon." if GameState.is_penguins()
			else "A cow with chrome-bright horns, chewing moon dust. She doesn't trust you yet. Maybe someone back in the city knows about this place."}])
		return
	await say([{"who": "Alien trader", "text": "Zzzt. She likes you. She follows anyone who brings a moon shard home to a friend. Take her. Zzzt."}])
	RanchGift.give("moon_cow", MOON_COW_KEY, {"giver": "Alien trader", "home": "barn"})


func _tele_first() -> void:
	if GameState.is_penguins():
		await say([{"who": "Star Crystal", "text": "There. Feel that? It's waking up.", "mood": "happy"}])
	else:
		await say([{"text": "The pad hums, then roars. Whatever the President was shipping out here, you're about to see where it went."}])
	go_to("station", Vector2(4 * TILE, 12 * TILE + 8), "right")

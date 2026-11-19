extends SceneTree
## Round 13: gangster heroes mine with a real pickaxe pose at the same pace as
## the penguin side, swing a visible blade, and the pup comes into the mines
## (placed on open floor, keeps its command across floors, fights, digs and
## fetches finds).
##   godot --headless --path . -s res://tools/gang_play_test.gd
var fails := 0
var _layout := 1700


## The next mine load builds a fixed layout (a new one each load, the same list
## every run): the game seeds floors from the clock.
func _next_layout() -> void:
	_layout += 1
	(load("res://scripts/mine.gd") as Variant).force_seed = _layout


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	Campaign.bypass = true
	seed(1717)  # the game's own randf/randi rolls (drops, pup picks) repeat every run
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


## Wait `t` seconds of GAME time (summed frame deltas), never the wall clock:
## check.sh runs this with --fixed-fps 60, so every wait is the same frame count
## however loaded the box is.
func secs(t: float) -> void:
	var gt := 0.0
	while gt < t:
		await process_frame
		gt += root.get_process_delta_time()


func _mine(arc: String, hero: String) -> GameMap:
	GameState.new_run(arc, hero, "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["mine_seen"] = true
	GameState.run["energy"] = 999
	GameState.run["max_energy"] = 999
	GameMap.next_spawn = Vector2.ZERO
	_next_layout()
	change_scene_to_file("res://scenes/mine.tscn")
	await frames(12)
	return current_scene as GameMap


## Put the hero beside a rock, facing it; returns the rock cell.
func _at_rock(m: GameMap) -> Vector2i:
	for k in m.things:
		if str(m.things[k].get("type", "")) == "rock":
			var s: Vector2i = k + Vector2i(-1, 0)
			if not m.blocked.has(s) and not m.things.has(s):
				m.player.position = m.cell_center(s)
				m.player.facing = "right"
				m.things[k]["hp"] = 99999
				m.things[k]["ore"] = "stone"
				return k
	return Vector2i(-1, -1)


## Swings in `t` seconds of USE held on a rock.
func _swings(m: GameMap, t: float) -> int:
	for x in m.enemies.duplicate():  # a foe in front turns USE into a punch
		if is_instance_valid(x):
			x.queue_free()
	m.enemies.clear()
	var rk := _at_rock(m)
	GameState.select_slot((GameState.run["toolbar"] as Array).find("pickaxe"))
	var n := 0
	var hp := int(m.things[rk]["hp"])
	var gt := 0.0
	while gt < t:
		if not m.player._busy:
			m.player.do_action("tool")
		await process_frame
		gt += root.get_process_delta_time()
		if int(m.things[rk]["hp"]) != hp:
			hp = int(m.things[rk]["hp"])
			n += 1
	return n


func _run() -> void:
	InputSetup.ensure_actions()
	# 1. Mining pose and pace.
	var m := await _mine("penguins", "kairi")
	var pen := await _swings(m, 2.5)
	for hero in ["dad", "pax", "june", "rafe", "nia", "ollie", "marisol", "bo"]:
		m = await _mine("gangsters", hero)
		var p: Player = m.player
		check(p.char_id.ends_with("_gang"), "%s plays the gang outfit (%s)" % [hero, p.char_id])
		for x in m.enemies.duplicate():  # a foe in front turns USE into a punch
			if is_instance_valid(x):
				x.queue_free()
		m.enemies.clear()
		_at_rock(m)
		GameState.select_slot((GameState.run["toolbar"] as Array).find("pickaxe"))
		p.do_action("tool")
		var a := p.anim_name
		check(a.begins_with("pickaxe_") and not CharacterLibrary.is_alias(p._anim.sprite_frames, a), "%s mines with a drawn pickaxe pose (%s)" % [hero, a])
		await secs(0.6)
		var g := await _swings(m, 2.5)
		check(pen > 0 and absf(g - pen) <= maxf(1.0, pen * 0.25), "%s mines at the penguin pace (%d vs %d swings)" % [hero, g, pen])
	# 2. Sword: gang heroes punch with empty hands, so the blade is drawn over the swing.
	m = await _mine("gangsters", "dad")
	GameState.select_slot((GameState.run["toolbar"] as Array).find("sword"))
	m.player._attack_cd = 0.0
	m.player._swing()
	await frames(1)
	var hs: Node = m.player.get_node_or_null("HeldSwing")
	check(hs is HeldSwing and (hs as HeldSwing).kind == "sweep", "gang sword swing shows the blade")
	m = await _mine("penguins", "kairi")
	GameState.select_slot((GameState.run["toolbar"] as Array).find("sword"))
	m.player._attack_cd = 0.0
	m.player._swing()
	await frames(1)
	check(m.player.get_node_or_null("HeldSwing") == null, "penguin heroes keep their own drawn swing")
	# A hero with no pickaxe pose at all still swings (and is slowed to the same pace).
	m = await _mine("penguins", "big_jim")
	_at_rock(m)
	GameState.select_slot((GameState.run["toolbar"] as Array).find("pickaxe"))
	check(m.player.play_tool("pickaxe") and m.player.get_node_or_null("HeldSwing") != null, "no pickaxe pose: attack frames + the pickaxe drawn")
	# 3. The pup in the mines.
	m = await _mine("gangsters", "pax")
	await frames(3)
	var pt := m.pet as Pet
	check(pt != null and pt.visible, "the pup comes into the mine")
	if pt:
		var pc := m.world_to_cell(pt.position - Vector2(0, 4))
		check(not m.blocked.has(pc) and not m.things.has(pc), "the pup stands on open floor")
		# Fights: a foe next to you gets bitten.
		var e := m.spawn_enemy("slime", pt.position + Vector2(12, 0))
		if e:
			e.set_process(false)
			var hp0 := e.hp
			await secs(2.5)
			check(not is_instance_valid(e) or e.hp < hp0 or not e._alive, "the pup bites a foe in the mine")
			if is_instance_valid(e):
				e.queue_free()
				m.enemies.erase(e)
		await frames(2)
		# Digs and fetches: a dig run ends with a find in your bag.
		var before := 0
		for id in GameState.run["inventory"]:
			before += int(GameState.run["inventory"][id])
		for x in m.enemies.duplicate():  # a calm floor: dig runs wait out fights
			if is_instance_valid(x):
				x.queue_free()
		m.enemies.clear()
		await frames(2)
		pt.set_meta("forage_t", 999.0)
		pt._target = null
		var gt := 0.0
		var got := false
		while gt < 30.0:  # game seconds (fixed frames under --fixed-fps)
			await process_frame
			gt += root.get_process_delta_time()
			if pt._carry_item == "" and pt._carry_find == "":
				pt.set_meta("forage_t", 999.0)  # no open cell picked this try: look again now
			var now := 0
			for id in GameState.run["inventory"]:
				now += int(GameState.run["inventory"][id])
			if now > before:
				got = true
				break
		check(got, "the pup digs up a find and brings it back (state %s/%s, %.0f px from you, %.1f game s)" % [pt._carry_item, pt._carry_find, pt.position.distance_to(m.player.position), gt])
		# Commands across floors: told to stay, it waits by the lift on the new layout.
		pt.set_mode("wait")
		GameMap.next_spawn = Vector2.ZERO
		_next_layout()
		change_scene_to_file("res://scenes/mine.tscn")
		await frames(12)
		m = current_scene as GameMap
		var pt2 := m.pet as Pet
		check(pt2 != null and pt2.visible and str(Pet.state().get("mode", "")) == "wait", "stay holds on the next floor")
		if pt2:
			var w: Array = Pet.state().get("wait", [])
			check(w.size() >= 3 and str(w[0]) == "mine" and Vector2(float(w[1]), float(w[2])).distance_to(pt2.position) < 1.0, "it waits by the lift on the new layout")
			check(not m.blocked.has(m.world_to_cell(pt2.position - Vector2(0, 4))), "and on open floor")
			pt2.set_mode("follow")
			GameMap.next_spawn = Vector2.ZERO
			_next_layout()
			change_scene_to_file("res://scenes/mine.tscn")
			await frames(12)
			m = current_scene as GameMap
			check(m.pet != null and m.pet.visible and m.pet.position.distance_to(m.player.position) < 48.0, "following, it comes down to the next floor at your heel")
	print("gang_play_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

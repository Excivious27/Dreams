extends SceneTree
## Mine progression test: no shaft at first; digging wakes the keeper; killing it
## opens the shaft; the shaft leads to floor 2; tiers scale enemies; a juggled
## enemy lunges back. Run: xvfb-run godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/mine_test.gd

var fails := 0


func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	seed(4242)  # the game's own randf/randi rolls (keeper wake, drops) repeat every run
	_run.call_deferred()


## The game seeds each floor from the clock; tests build fixed layouts (0 = clock).
func _layout(sd: int) -> void:
	(load("res://scripts/mine.gd") as Variant).force_seed = sd


## Wait up to `t` seconds of GAME time (summed frame deltas; check.sh runs this
## with --fixed-fps 60, so it is a fixed frame count) while `busy` says so.
func _wait(t: float, busy: Callable) -> void:
	var gt := 0.0
	while gt < t and busy.call():
		await process_frame
		gt += root.get_process_delta_time()


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["mine_seen"] = true
	GameState.run["energy"] = 999
	GameState.run["max_energy"] = 999
	GameMap.next_spawn = Vector2.ZERO
	_layout(4242)
	change_scene_to_file("res://scenes/mine.tscn")
	await frames(15)
	var m := current_scene as GameMap
	check(m != null and m.scene_id() == "mine", "in the mine")
	var downs := 0
	for k in m.things:
		if str(m.things[k].get("type", "")) == "down":
			downs += 1
	check(downs == 0, "no shaft on a fresh floor")
	check(str((m.get("_style") as Dictionary).get("id", "")) != "", "layout style rolled: %s / %s" % [str((m.get("_style") as Dictionary).get("id", "")), str(m.get("_dress"))])
	# Floor 1's keeper needs real progress AND time: lots of digging alone, at once, isn't enough.
	GameState.select_slot((GameState.run["toolbar"] as Array).find("pickaxe"))
	GameState.run["mine_tried"] = {"1_%d" % int(GameState.run["day"]): 999}
	m.call("_try_more", 1)
	await frames(2)
	check(m.get("_guardian") == null and not bool(m.get("_summoning")), "keeper waits for time on the floor (needs %.0f s)" % float(m.call("_min_secs")))
	GameState.run["mine_tried"] = {}
	check(int(m.call("_threshold")) >= 12, "floor 1 threshold is meaningful (%d, rocks %d)" % [int(m.call("_threshold")), int(m.get("_rock_total"))])
	m.set("_secs_live", 999.0)
	# Dig: break rocks via interact until the keeper wakes (pickaxe in hand).
	var broke := 0
	for k in m.things.keys():
		var t: Dictionary = m.things.get(k, {})
		if str(t.get("type", "")) != "rock":
			continue
		for n in 6:
			if not m.things.has(k):
				break
			m.interact(k, m.things[k])
		if not m.things.has(k):
			broke += 1
		await frames(1)
		if m.get("_guardian") != null or bool(m.get("_summoning")):
			break
	# The keeper surfaces after a 0.4-0.9 s wake timer: wait on game time
	# (headless frames can be very fast or, on a loaded box, very slow).
	await _wait(3.0, func() -> bool: return m.get("_guardian") == null)
	var g: Enemy = m.get("_guardian")
	check(g != null, "keeper woke after %d rocks (threshold %d)" % [broke, m.call("_threshold")])
	if g:
		var tot := 0
		for k: Enemy in m.call("keepers_left"):
			tot += k.max_hp
		check(g.is_guardian and g.tier >= 0 and tot >= 8, "keeper encounter %s has real hp (lead %s, total hp %d)" % [str((m.get("encounter") as Dictionary).get("id", "")), g.kind, tot])
		# Knock it around: by the third hit it should telegraph a lunge if it has one.
		var had_lunge := g.abilities.has("lunge")
		for i in 3:
			g.hit(1, g.position + Vector2(-10, 0))
			await frames(2)
		check(not had_lunge or float(g.get("_lunge_tele")) > 0.0 or float(g.get("_lunge")) > 0.0 or float(g.get("_lunge_cd")) > 0.0, "juggled keeper answers with a lunge")
		for k: Enemy in m.call("keepers_left"):
			k.hit(9999, k.position + Vector2(-10, 0))
			await frames(3)
		await frames(20)
	downs = 0
	for k in m.things:
		if str(m.things[k].get("type", "")) == "down":
			downs += 1
	check(downs == 1 and GameState.run["flags"].has("mine_open_1"), "shaft opened after the keeper fell")
	# Take it: just walk onto the shaft (no USE, no exact spot).
	var lad: Vector2i = m.get("_ladder")
	m.player.position = m.cell_center(lad + Vector2i(1, 0))
	await frames(3)
	check(str(m.call("action_word", lad)) == "Down", "USE says Down beside the shaft")
	m.player.position = m.cell_center(lad)
	await _wait(4.0, func() -> bool: return current_scene == m or current_scene == null)
	m = current_scene as GameMap
	check(m != null and m.scene_id() == "mine" and int(GameState.run["mine_floor"]) == 2, "stepping onto the shaft descended to floor 2")
	# Variety: floor 1 entered again and again rarely repeats.
	# Fixed seeds keep the run repeatable; the style rotation (never one of the
	# last five) is the game's own. Then two clock-seeded entries prove the live
	# game rolls a new layout seed each time.
	var seen := {}
	var sizes := {}
	for i in 5:
		GameState.run["mine_floor"] = 1
		_layout(101 + i)
		change_scene_to_file("res://scenes/mine.tscn")
		await frames(8)
		var mm := current_scene as GameMap
		seen[str((mm.get("_style") as Dictionary).get("id", ""))] = true
		sizes["%dx%d" % [mm.cols, mm.rows]] = true
		var rocks := 0
		var ores := 0
		for k in mm.things:
			if str(mm.things[k].get("type", "")) == "rock":
				rocks += 1
				if str(mm.things[k].get("ore", "stone")) != "stone":
					ores += 1
		check(rocks > 20 and ores * 3 <= rocks, "floor 1 entry %d: %s, %d rocks, %d ore" % [i, str((mm.get("_style") as Dictionary).get("id", "")), rocks, ores])
	check(seen.size() >= 4 and sizes.size() >= 4, "5 entries to floor 1: %d styles %s, %d sizes" % [seen.size(), str(seen.keys()), sizes.size()])
	_layout(0)
	var seeds := {}
	for i in 2:
		GameState.run["mine_floor"] = 1
		change_scene_to_file("res://scenes/mine.tscn")
		await frames(8)
		seeds[int((current_scene as GameMap).get("_seed"))] = true
	check(seeds.size() == 2, "the live game seeds every floor-1 entry afresh (%s)" % str(seeds.keys()))
	_layout(4243)
	GameState.run["mine_floor"] = 2
	change_scene_to_file("res://scenes/mine.tscn")
	await frames(10)
	m = current_scene as GameMap
	# Tier scaling: a slime at tier 3 has more hp than at tier 0.
	var e0 := m.spawn_enemy("slime", m.cell_center(Vector2i(8, 8)), 0)
	var e3 := m.spawn_enemy("slime", m.cell_center(Vector2i(9, 9)), 3)
	check(e3.max_hp > e0.max_hp and e3.armor > e0.armor and e3.kb_resist > e0.kb_resist and e3.abilities.size() >= 2, "tier 3 slime: hp %d>%d, armour %d, kb %.1f, abilities %s" % [e3.max_hp, e0.max_hp, e3.armor, e3.kb_resist, str(e3.abilities)])
	# Statuses: poison ticks hp down and expires. Tick it directly on simulated
	# time: the player's own tick can sit frozen (toasts, dialogue, a stale
	# user dir's settings), which made the frame-based check flaky.
	GameState.status_clear()
	GameState.status_apply("poison", 2)
	check(GameState.status_active("poison"), "poison applied")
	var pdmg := 0
	var pt := 0.0
	while pt < 20.0 and GameState.status_active("poison"):
		pdmg += GameState.status_tick(0.1)
		pt += 0.1
	check(pdmg > 0 and not GameState.status_active("poison"), "poison ticked %d hp and wore off after %.1f s" % [pdmg, pt])
	GameState.status_clear()
	check(GameState.status_speed() == 1.0, "no speed status active")
	GameState.status_apply("chill", 1)
	check(GameState.status_speed() < 1.0, "chill slows")
	# Deep floor: tier mapping and lift availability.
	check(GameState.mine_tier(1) == 0 and GameState.mine_tier(25) == 0 and GameState.mine_tier(26) == 1 and GameState.mine_tier(126) == 5, "floor -> tier mapping")
	GameState.run["flags"]["mine_deepest"] = 10
	GameState.run["mine_floor"] = 1
	change_scene_to_file("res://scenes/mine.tscn")
	await frames(15)
	m = current_scene as GameMap
	var lift := false
	for k in m.things:
		if str(m.things[k].get("type", "")) == "lift":
			lift = true
	check(lift, "lift on floor 1 once floor 5+ opened")
	print("MINE DONE, failures: %d" % fails)
	quit(1 if fails > 0 else 0)

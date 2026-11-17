extends SceneTree
## Mine progression test: no shaft at first; digging wakes the keeper; killing it
## opens the shaft; the shaft leads to floor 2; tiers scale enemies; a juggled
## enemy lunges back. Run: xvfb-run godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/mine_test.gd

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


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
	change_scene_to_file("res://scenes/mine.tscn")
	await frames(15)
	var m := current_scene as GameMap
	check(m != null and m.scene_id() == "mine", "in the mine")
	var downs := 0
	for k in m.things:
		if str(m.things[k].get("type", "")) == "down":
			downs += 1
	check(downs == 0, "no shaft on a fresh floor")
	# Dig: break rocks via interact until the keeper wakes (pickaxe in hand).
	GameState.select_slot((GameState.run["toolbar"] as Array).find("pickaxe"))
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
		if m.get("_guardian") != null:
			break
	for w in 120:
		if m.get("_guardian") != null: break
		await frames(1)
	var g: Enemy = m.get("_guardian")
	check(g != null, "keeper woke after %d rocks (threshold %d)" % [broke, m.call("_threshold")])
	if g:
		check(g.is_guardian and g.tier >= 0 and g.max_hp >= 12, "keeper is a guardian with real hp (kind %s, hp %d)" % [g.kind, g.max_hp])
		# Knock it around: by the third hit it should telegraph a lunge if it has one.
		var had_lunge := g.abilities.has("lunge")
		for i in 3:
			g.hit(1, g.position + Vector2(-10, 0))
			await frames(2)
		check(not had_lunge or float(g.get("_lunge_tele")) > 0.0 or float(g.get("_lunge")) > 0.0 or float(g.get("_lunge_cd")) > 0.0, "juggled keeper answers with a lunge")
		g.hit(9999, g.position + Vector2(-10, 0))
		await frames(20)
	downs = 0
	for k in m.things:
		if str(m.things[k].get("type", "")) == "down":
			downs += 1
	check(downs == 1 and GameState.run["flags"].has("mine_open_1"), "shaft opened after the keeper fell")
	# Take it.
	for k in m.things.keys():
		if str(m.things[k].get("type", "")) == "down":
			m.interact(k, m.things[k])
	await frames(40)
	m = current_scene as GameMap
	check(m != null and m.scene_id() == "mine" and int(GameState.run["mine_floor"]) == 2, "descended to floor 2")
	# Tier scaling: a slime at tier 3 has more hp than at tier 0.
	var e0 := m.spawn_enemy("slime", m.cell_center(Vector2i(8, 8)), 0)
	var e3 := m.spawn_enemy("slime", m.cell_center(Vector2i(9, 9)), 3)
	check(e3.max_hp > e0.max_hp and e3.armor > e0.armor and e3.kb_resist > e0.kb_resist and e3.abilities.has("ranged"), "tier 3 slime: hp %d>%d, armour %d, kb %.1f, abilities %s" % [e3.max_hp, e0.max_hp, e3.armor, e3.kb_resist, str(e3.abilities)])
	# Statuses: poison ticks hp down and expires.
	GameState.status_apply("poison", 2)
	var hp0 := int(GameState.run["hp"])
	await frames(90)
	check(int(GameState.run["hp"]) < hp0, "poison ticked (%d -> %d)" % [hp0, int(GameState.run["hp"])])
	check(GameState.status_speed() == 1.0, "no speed status active")
	GameState.status_apply("chill", 1)
	check(GameState.status_speed() < 1.0, "chill slows")
	# Deep floor: tier mapping and lift availability.
	check(GameState.mine_tier(1) == 0 and GameState.mine_tier(5) == 1 and GameState.mine_tier(13) == 3 and GameState.mine_tier(40) == 5, "floor -> tier mapping")
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

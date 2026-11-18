extends SceneTree
## The big systems: conquest battles, the town projects, the merkitty colonies,
## large mine caverns and plateaus.   godot --headless --path . -s res://tools/campaign_test.gd
var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	_run.call_deferred()

func _go(sc: String, at := Vector2.ZERO) -> GameMap:
	GameMap.next_spawn = at
	change_scene_to_file("res://scenes/%s.tscn" % sc)
	for i in 12:
		await process_frame
	var d := Dialogue.instance(self)
	for i in 30:
		if d.active:
			if d._in_choice:
				d._choose("", d._choices.get_child_count() - 1)
			else:
				d._advance()
		await process_frame
	return current_scene as GameMap

func _drain() -> void:
	for i in 80:
		var d := Dialogue.instance(self)
		if d.active:
			if d._in_choice:
				d._choose("", d._choices.get_child_count() - 1)
			else:
				d._advance()
		await process_frame


func _run() -> void:
	InputSetup.ensure_actions()
	# --- mines: big and organic
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	GameState.run["mine_floor"] = 3
	print("mine")
	var m := await _go("mine")
	check(m.cols >= 40 and m.rows >= 32, "mine floor is large (%dx%d)" % [m.cols, m.rows])
	check(m._open.size() > 500, "mine has a big open cavern (%d cells)" % m._open.size())
	check(m._ladder.distance_to(m._entry) > 15, "the way down is a real walk from the entrance")
	# --- colony
	GameState.run["quests"].append({"id": "clear_meadow", "text": "", "done": true})
	print("colony")
	m = await _go("colony_coral")
	check(m != null and m.scene_id() == "colony_coral", "colony map loads")
	var water := 0
	for c in m.things:
		if m.is_water_cell(c):
			water += 1
	check(water > 1500, "the colony is islands in the sea (%d water cells)" % water)
	var s := Colony.st("colony_coral")
	var elder := Vector2i(40, 44)
	m.player.position = m.cell_center(elder + Vector2i(0, 1))
	Colony.interact(m, "colony_coral", m.things[elder])
	await _drain()
	check(bool(s["met"]), "talking to the elder starts the colony")
	GameState.add_item("trout", 6)
	s["gave"] = false
	Colony.interact(m, "colony_coral", m.things[elder])
	await _drain()
	check(bool(s["gave"]), "bringing the fish counts")
	s["kills"] = 99
	GameState.add_item("crystal_refined", 3)
	for b in Colony.data()["colony_coral"].get("beacons", 3):
		var bc: Array = [[24, 30], [42, 57], [70, 58], [18, 16]][b]  # gen_colonies.py beacon cells
		Colony.interact(m, "colony_coral", m.things.get(Vector2i(int(bc[0]), int(bc[1])), {}))
	check((s["beacons"] as Dictionary).size() == 3, "three beacons lit (%d)" % (s["beacons"] as Dictionary).size())
	check(Colony.ready_to_wake("colony_coral"), "ready to wake the crystal")
	var old_m := m
	Colony._restore(m, "colony_coral")
	await _drain()
	# Restoring reloads the region (lit crystal, open stall): wait for the new map.
	var t0 := Time.get_ticks_msec()
	while (current_scene == old_m or not (current_scene is GameMap)) and Time.get_ticks_msec() - t0 < 4000:
		await process_frame
	for i in 12:
		await process_frame
	await _drain()
	m = current_scene as GameMap
	check(bool(s["done"]) and Colony.has_ability("coral_ward") and GameState.count("colony_light") == 1, "saving the colony grants its ability and light")
	# --- project: the Crystal Ward
	var pd := Project.def()
	check(str(pd.get("id", "")) == "crystal_ward", "penguins build the Crystal Ward")
	GameState.add_item("stone", 40); GameState.add_item("clay", 10); GameState.add_item("shard", 6); GameState.add_item("crystal_refined", 2); GameState.add_item("sunflower", 5)
	Project.contribute(0, 0)
	Project.contribute(0, 1)
	check(Project.bundle_done(0, 0) and Project.bundle_done(0, 1), "stage 1 bundles fill (%s)" % str(Project.st()))
	Project._check_stage(m)
	await _drain()
	check(Project.stage() == 1 and Project.has("ward_stone"), "stage 1 completes")
	# --- battle
	GameState.run["flags"]["proj_war_table"] = true
	print("battle")
	m = await _go("bf_frostfield")
	var bt: Variant = m.get("battle")
	check(bt != null, "battlefield starts a battle")
	if bt != null:
		var b: Battle = bt
		check(b.points.size() >= 5, "battle has control points")
		check(m.plateaus.size() >= 3, "battlefield has plateaus (%d)" % m.plateaus.size())
		var tgt: Dictionary = b.points[1]
		for e in m.enemies.duplicate():
			if is_instance_valid(e):
				e.queue_free()
		m.enemies.clear()
		m.player.position = tgt["pos"]
		m.player.invuln = 999.0
		for i in 2000:
			await process_frame
			m.player.position = tgt["pos"]
			for e in m.enemies.duplicate():
				if is_instance_valid(e):
					e.queue_free()
			m.enemies.clear()
			if str(tgt["owner"]) == "ally":
				break
		check(str(tgt["owner"]) == "ally", "standing on a point captures it (%s %.2f)" % [tgt["owner"], tgt["prog"]])
		b.supply = 100
		tgt["spawner"] = "healer"
		tgt["t"] = 11.0
		for i in 240:
			await process_frame
		var helpers := 0
		for h in get_nodes_in_group("allies"):
			if h is HelperUnit:
				helpers += 1
		check(helpers >= 1, "a spawner makes helper crystals")
	# --- gangster HQ
	GameState.new_run("gangsters", "dad", "T", "Town", "Pup")
	check(str(Project.def().get("id", "")) == "hq", "gangsters build Headquarters")
	check(Gift.data().get("lieutenants", {}).size() == 8, "eight lieutenants")
	print("campaign_test: %d failures" % fails)
	quit(1 if fails else 0)

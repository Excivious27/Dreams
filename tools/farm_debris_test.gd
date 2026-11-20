extends SceneTree
## Farm debris (Tom, Guide 26 #23): tall grass and weeds change with the seasons,
## lots of cuttable grass (fiber, hay with the scythe), and cleared debris grows
## back on a rarity ladder (farm.REGROW), never by the house or beside soil.
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(5)
	Campaign.bypass = true
	_run.call_deferred()


func frames(k: int) -> void:
	for i in k:
		await process_frame


func load_farm() -> GameMap:
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/farm.tscn")
	await frames(12)
	return current_scene as GameMap


func counts(m: GameMap) -> Dictionary:
	var d := {"grass": 0, "weed": 0, "rock": 0, "log": 0, "tree": 0}
	for c: Vector2i in m.things:
		var t: Dictionary = m.things[c]
		match str(t.get("type", "")):
			"weeds":
				d["grass" if bool(t.get("grass", false)) else "weed"] += 1
			"rock":
				d["rock"] += 1
			"log", "stump":
				d["log"] += 1
			"tree":
				d["tree"] += 1
	return d


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	var per := {}
	for se_i in 4:
		GameState.run["day"] = 1 + se_i * GameState.DAYS_PER_SEASON + 3
		var m := await load_farm()
		per[GameState.season()] = counts(m)
		print("  %s: %s" % [GameState.season(), str(per[GameState.season()])])
	check(int(per["summer"]["grass"]) >= 60, "summer: lots of tall grass to cut (%d)" % int(per["summer"]["grass"]))
	check(int(per["winter"]["grass"]) < int(per["summer"]["grass"]) / 2, "winter: the grass dies back")
	check(per["spring"]["grass"] != per["fall"]["grass"] or per["spring"]["weed"] != per["fall"]["weed"], "the patches shift between seasons")
	# Regrowth: clear one far rock and one rock by the house, then let days pass.
	GameState.run["day"] = 30
	var m := await load_farm()
	var far := Vector2i(-1, -1)
	var near := Vector2i(-1, -1)
	var grass := Vector2i(-1, -1)
	for c: Vector2i in m.things:
		var ty := str(m.things[c].get("type", ""))
		var dd := Vector2(c).distance_to(Vector2(m.get("DOOR")))
		if ty == "rock" and dd > 20.0 and not m.call("_by_soil", c) and far.x < 0:
			far = c
		if ty == "weeds" and bool(m.things[c].get("grass", false)) and grass.x < 0:
			grass = c
	check(far.x >= 0 and grass.x >= 0, "found a far rock and a tall-grass clump")
	check(m.call("regrow_days", "rock", Vector2i(m.get("DOOR")) + Vector2i(3, 3)) == 0, "stone never regrows by the house")
	check(int(m.call("regrow_days", "grass", far)) < int(m.call("regrow_days", "rock", far)) and int(m.call("regrow_days", "rock", far)) < int(m.call("regrow_days", "tree", far)), "rarity ladder: grass < rock < tree")
	check(float(m.things[grass].get("hay", 0.0)) >= 0.5, "tall grass gives hay to the scythe")
	# C4 P6: tall grass is walk-through, weeds stay solid; meadow clumps hay ~half the time.
	var gw := 0
	var gb := 0
	var wb := 0
	var wn := 0
	var hays := []
	for c: Vector2i in m.things:
		var t: Dictionary = m.things[c]
		if str(t.get("type", "")) != "weeds":
			continue
		if bool(t.get("grass", false)):
			gw += 1
			if m.blocked.has(c) and not m.hard.has(c):
				gb += 1  # (a building's body row may cover a clump: that's the building)
			hays.append(float(t.get("hay", 0.0)))
		else:
			wn += 1
			if m.blocked.has(c):
				wb += 1
	for c: Vector2i in m.things:
		if bool(m.things[c].get("grass", false)) and m.blocked.has(c) and not m.hard.has(c):
			print("  (blocked grass %s hard=%s prop=%s)" % [str(c), str(m.hard.has(c)), str(m.props.get(c))])
	check(gw > 0 and gb == 0, "tall grass never blocks (%d of %d)" % [gb, gw])
	check(wn == 0 or wb == wn, "weeds stay solid (%d of %d)" % [wb, wn])
	check(hays.has(0.5), "meadow clumps: hay half the time")
	# Walking into grass sways it; the scythe cuts three cells across your facing.
	var row := Vector2i(-1, -1)
	for c: Vector2i in m.things:
		if bool(m.things[c].get("walk", false)) and bool(m.things.get(c + Vector2i(1, 0), {}).get("walk", false)) and bool(m.things.get(c - Vector2i(1, 0), {}).get("walk", false)):
			row = c
			break
	if row.x >= 0:
		m.player.position = m.cell_center(row - Vector2i(1, 0)) - Vector2(0, 5)
		m.player.facing = "up"
		await frames(1)
		await frames(1)
		var sp: Node2D = m.props.get(row - Vector2i(1, 0), null)
		await frames(3)
		check(sp != null and absf(sp.skew) > 0.01, "tall grass sways when you walk in (%s %s %s)" % [str(sp), str(m.get("_grass_cell")), str(m.world_to_cell(m.player.position))])
		m.player.position = m.cell_center(row + Vector2i(0, 1))
		m.call("scythe_sweep", row)
		check(not m.things.has(row + Vector2i(1, 0)) and not m.things.has(row - Vector2i(1, 0)), "the scythe sweeps the cells beside the aim")
	else:
		check(false, "found a row of three tall-grass cells")
	m.call("_mark_cleared", far)
	m.call("_mark_cleared", grass)
	GameState.run["day"] = 30 + 5
	m = await load_farm()
	check(not m.things.has(far), "a broken rock stays gone for a while")
	GameState.run["day"] = 30 + int(m.call("regrow_days", "rock", far))
	m = await load_farm()
	check(m.things.has(far) and str(m.things[far].get("type", "")) == "rock", "the rock grows back after %d days" % int(m.call("regrow_days", "rock", far)))
	print("farm_debris_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)

extends SceneTree
## Farm look (CONDUCT 5 P1): crops wither at the season's turn and stay until pulled,
## the farmhouse art and door follow the house tier, the greenhouse plot is clear of
## the Manor, farm animals have true-to-life heights, debris never sits on a path.
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
	await frames(14)
	var d := Dialogue.instance(self)
	for k in 10:
		if d.active:
			d._advance()
			await frames(2)
	return current_scene as GameMap


func new_run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	GameState.run["flags"]["farm_seen"] = true
	GameState.run["quests"] = [{"id": "clear_meadow", "text": "x", "done": true}]


func _run() -> void:
	new_run()
	# --- 1. Withering at the season's turn (c5_14 #1) ---
	GameState.run["day"] = GameState.DAYS_PER_SEASON  # last day of spring
	var spring_crop := ""
	for cid: String in GameState.crops:
		var cd: Dictionary = GameState.crops[cid]
		if str(cd.get("season", "")) == "spring" and not bool(cd.get("tree", false)):
			spring_crop = cid
			break
	check(spring_crop != "", "a spring-only crop exists (%s)" % spring_crop)
	GameState.run["farm"]["20,20"] = {"watered": true, "crop": spring_crop, "days": 1}
	GameState.run["farm"]["21,20"] = {"watered": true, "crop": "", "days": 0}
	var rep := GameState.sleep()
	var t: Dictionary = GameState.run["farm"]["20,20"]
	check(GameState.season() == "summer", "it is summer after sleeping on spring's last day")
	check(str(t.get("crop", "")) == "" and str(t.get("dead", "")) != "", "the spring crop withered (dead=%s)" % str(t.get("dead", "")))
	check(int(rep.get("died", 0)) >= 1, "the sleep report counts it")
	check(not (GameState.run["farm"]["21,20"] as Dictionary).has("dead"), "an empty bed stays empty")
	var m := await load_farm()
	m.player.position = m.cell_center(Vector2i(20, 21))
	m.player.facing = "up"
	GameState.run["hotbar_sel"] = -1
	var handled: bool = m.call("_farm_tile", Vector2i(20, 20), "")
	check(handled and not (GameState.run["farm"]["20,20"] as Dictionary).has("dead"), "a bare hand pulls the withered plant")
	check(GameState.run["farm"].has("20,20"), "the bed stays tilled")
	# --- 2. Farmhouse tiers (c5_01 #1), greenhouse plot clear of the Manor ---
	for tier in [1, 2, 3]:
		new_run()
		GameState.run["day"] = 30
		GameState.run["builds"] = {"house": tier, "greenhouse": 1, "coop": 2, "barn": 2, "beehive": 1, "scarecrow": 1}
		GameState.run["flags"]["coop_day"] = 1
		GameState.run["flags"]["barn_day"] = 1
		GameState.run["flags"]["barn2_day"] = 1
		Ranch.st()["legacy_done"] = false  # fix2: the farm draws the roster only; an old save's full herd
		Ranch.migrate()
		if tier == 3:
			GameState.run["farm"]["18,8"] = {"watered": false, "crop": "turnip", "days": 2}  # old greenhouse plot, now under the Manor
		m = await load_farm()
		var hl: Dictionary = m.call("house_look", tier)
		var want := str(hl["sprite"])
		var found := false
		for ch in m.get_children():
			if ch is Sprite2D and (ch as Sprite2D).texture == Art.tex("buildings", want):
				found = true
		check(found, "tier %d farmhouse shows %s" % [tier, want])
		var door: Vector2i = hl["door"]
		check(str((m.things.get(door, {}) as Dictionary).get("type", "")) == "door", "tier %d door thing at %s" % [tier, str(door)])
		check(not m.blocked.has(door + Vector2i(0, 1)), "tier %d: you can stand below the door" % tier)
		var mail: Vector2i = hl["mail"]
		check(str((m.things.get(mail, {}) as Dictionary).get("type", "")) == "mailbox", "tier %d mailbox at %s" % [tier, str(mail)])
		var hr: Rect2i = hl["rect"]
		check(not hr.intersects(GameState.GREENHOUSE_PLOT.grow(1)), "tier %d house clear of the greenhouse plot" % tier)
		var gc: Array = Builds.data()["greenhouse"]["cell"]
		check(not hr.grow(1).has_point(Vector2i(int(gc[0]), int(gc[1]))), "tier %d house clear of the greenhouse" % tier)
		var bad := 0
		for c: Vector2i in m.cells_of([GameState.GREENHOUSE_PLOT]):
			if m.blocked.has(c) or (m.things.has(c) and str((m.things[c] as Dictionary).get("type", "")) in ["weeds", "rock", "log", "stump", "tree"]):
				bad += 1
		check(bad == 0, "tier %d greenhouse plot is open ground (%d blocked)" % [tier, bad])
		if tier == 3:
			check(not GameState.run["farm"].has("18,8"), "a bed under the Manor moved off (seed back)")
		# Animals: true-to-life heights (c5_09 #1).
		var hts := {}
		for ch in m.get_children():
			if ch is FarmAnimal:
				var fa := ch as FarmAnimal
				var tx := fa.sprite_frames.get_frame_texture("idle", 0)
				var h := float(fa.call("_drawn_size", fa.kind).y) * fa.scale.y
				hts[fa.kind + ("_baby" if fa.baby else "")] = h
		if tier == 1:
			print("    animal heights: %s" % str(hts))
			check(hts.has("llama") and hts.has("cow_brown") and float(hts["llama"]) > float(hts["cow_brown"]) and float(hts["llama"]) < float(hts["cow_brown"]) * 1.4, "llama a bit taller than a cow")
			check(hts.has("goat2") and float(hts["goat2"]) < float(hts["cow_brown"]), "goats (goat2) smaller than cows")
			# Fences round the pens, with a walk-in gate.
			var fences: Array = m.get("_fences")
			var gates := 0
			for f: Array in fences:
				if not bool(f[2]):
					gates += 1
			check(fences.size() >= 16 and gates == 3, "pens fenced (%d pieces, %d gates: coop, barn, beehive)" % [fences.size(), gates])  # C11b: the apiary pen [29,19] is fenced too
	# --- 3. Debris never on a path (c5_12 #1) ---
	var pm := m
	var on_path := 0
	for c: Vector2i in m.things:
		var pcs: Dictionary = m.get("_path_cells")
		if str((m.things[c] as Dictionary).get("type", "")) in ["weeds", "rock", "log", "stump", "tree", "bush"] and (pcs.has(c) or pcs.has(c + Vector2i.LEFT) or pcs.has(c + Vector2i.RIGHT) or pcs.has(c + Vector2i.UP) or pcs.has(c + Vector2i.DOWN)):
			on_path += 1
	check(on_path == 0, "no debris on path cells (%d)" % on_path)
	# --- 4. The house inside grows with the tier (c5_04 #2) ---
	for tier in [1, 3]:
		GameState.run["builds"]["house"] = tier
		GameMap.next_spawn = Vector2(8 * 16 + 8, 10 * 16)
		change_scene_to_file("res://scenes/house.tscn")
		await frames(14)
		var hm := current_scene as GameMap
		check(hm.cols == (16 if tier == 1 else 26), "tier %d house is %d cells wide" % [tier, hm.cols])
		var names := {}
		for ch in hm.get_children():
			if ch is Sprite2D and (ch as Sprite2D).texture:
				names[(ch as Sprite2D).texture.resource_path.get_file().get_basename()] = true
		for ch in hm.under_layer().get_children():
			if ch is Sprite2D and (ch as Sprite2D).texture:
				names[(ch as Sprite2D).texture.resource_path.get_file().get_basename()] = true
		if tier == 3:
			for want: String in ["study_desk", "cellar_hatch", "keg_wall", "bathtub", "bed_double"]:
				check(names.has(want), "Manor has %s" % want)
		else:
			check(not names.has("study_desk") and names.has("bed_blue"), "the cottage has no study, a single bed")
	# --- results ---
	print("farm_look_test: %s (%d fails)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)

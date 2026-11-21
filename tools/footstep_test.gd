extends SceneTree
## Footsteps follow the ground: lawns and meadows step on grass, roads and
## plazas on stone, docks on wood, tilled soil on dirt (Footsteps.word).
##   godot --headless --path . -s res://tools/footstep_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	InputSetup.ensure_actions()
	GameState.load_data()
	_run.call_deferred()


func _share(m: GameMap) -> Dictionary:
	var cnt := {}
	var n := 0
	for y in m.rows:
		for x in m.cols:
			var c := Vector2i(x, y)
			if m.blocked.has(c) or not m.in_content(c):
				continue
			var w := Footsteps.word(m, c)
			cnt[w] = int(cnt.get(w, 0)) + 1
			n += 1
	var out := {}
	for k in cnt:
		out[k] = float(cnt[k]) / maxf(1.0, n)
	return out


func _run() -> void:
	# [scene, arc, word, min share, max share]
	var cases := [
		["town", "penguins", "grass", 0.3, 1.0], ["town", "penguins", "stone", 0.03, 0.6],
		["uptown", "gangsters", "stone", 0.6, 1.0],  # C14 P5: Uptown is paved now (c14_06-03)
		["highlands", "penguins", "grass", 0.4, 1.0], ["meadow", "penguins", "grass", 0.5, 1.0],
		["farm", "penguins", "grass", 0.4, 1.0], ["neon", "gangsters", "stone", 0.5, 1.0],
		["docks", "gangsters", "stone", 0.4, 1.0], ["docks", "gangsters", "wood", 0.03, 0.6], ["beach", "penguins", "sand", 0.8, 1.0], ["beach", "penguins", "wood", 0.0, 0.2],
		# C6 (c6_06): seamless region ground, the marsh's dry paths, winter only on soft natural ground.
		["desert_dune_sea", "penguins", "sand", 0.5, 1.0], ["gilt_casino_row", "gangsters", "stone", 0.5, 1.0],
		["iron_freight_yards", "gangsters", "grass", 0.0, 0.3], ["marsh", "penguins", "mud", 0.0, 0.9],
		["farm", "penguins", "snow", 0.4, 1.0, 92], ["gilt_casino_row", "gangsters", "snow", 0.0, 0.2, 92],
		["iron_tunnels", "gangsters", "snow", 0.0, 0.05, 92],
		# C13 P5 (c13_07-27): the quarry's meadow and Hollow Heart's moss step as their own ground, not stone.
		["quarry", "penguins", "stone", 0.2, 1.0], ["hollow_heart", "penguins", "grass", 0.3, 1.0]]
	var shares := {}
	for cs: Array in cases:
		var day := int(cs[5]) if cs.size() > 5 else 1
		var key := "%s/%s/d%d" % [cs[1], cs[0], day]
		if not shares.has(key):
			GameState.new_run(str(cs[1]), "man", "Tester", "Dreamhollow", "Pip")
			GameState.run["intro_done"] = true
			GameState.run["day"] = day
			for f in ["cm_seen", "mine_open_1", "meow_taught", "intro_done", "gangsters_intro", str(cs[0]) + "_seen"]:
				GameState.run["flags"][f] = true
			GameMap.next_spawn = Vector2.ZERO
			change_scene_to_file("res://scenes/%s.tscn" % cs[0])
			for i in 6:
				await process_frame
			var m := current_scene as GameMap
			shares[key] = _share(m) if m else {}
			print("%s: %s" % [key, str(shares[key])])
		var s: float = float(shares[key].get(cs[2], 0.0))
		check(s >= float(cs[3]) and s <= float(cs[4]), "%s %s share %.2f not in [%.2f, %.2f]" % [key, cs[2], s, cs[3], cs[4]])
	# Exact texture names (c6_06).
	check(Footsteps.seam_word("cobble_moss") == "stone", "cobble_moss is stone")
	check(Footsteps.seam_word("floor_carpet") == "carpet", "carpet steps on carpet")
	# C13 P5: carpets, grates and ice have their own takes.
	check(Footsteps.seam_word("floor_metal_grate") == "metal", "metal grate is metal")
	check(Footsteps.seam_word("ice_rink") == "ice", "ice is ice")
	check(Footsteps.path_word("metal_b") == "metal", "metal path is metal")
	check(Footsteps.INTERIOR_FLOOR.get("fl_grate", "") == "metal", "grate interior floor is metal")
	check(Footsteps.INTERIOR_FLOOR.get("fl_carpet_red", "") == "carpet", "carpet interior floor is carpet")
	# Vehicle ticks follow the ground (c13_07-04): the sled crunches only on snow or ice.
	check(Player.veh_tick_word("crystal_sled", "grass") != "snow", "sled on grass is no snow crunch")
	check(Player.veh_tick_word("crystal_sled", "ice") == "ice", "sled on ice")
	check(Player.veh_tick_word("rowboat", "water") == "water", "rowboat tick")
	check(Footsteps.seam_word("cave_crystal_floor") == "stone", "crystal cave floor is stone")
	check(Footsteps.seam_word("cave_earth_floor") == "dirt", "earth cave floor is dirt")
	# Words map to real sounds.
	for w: String in ["grass", "dirt", "sand", "stone", "wood", "snow", "water", "mud", "gravel", "leaves", "carpet", "metal", "ice"]:
		check(ResourceLoader.exists("res://audio/sfx/step_%s.ogg" % w), "step_%s exists" % w)
	print("footstep_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

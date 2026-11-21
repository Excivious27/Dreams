extends SceneTree
## C14b P2 (c14b_04-18, 14-03): mine life. Miners' lamps flicker as fire, dust
## motes drift in their light, some stalactites drip on game time, and the lava
## strip frame period is a whole number of anim-layer ticks.
##   godot --headless --path . --fixed-fps 60 -s res://tools/mine_life_test.gd
var fails := 0


func _initialize() -> void:
	seed(18)
	Campaign.bypass = true
	_run.call_deferred()


func _ok(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("MINE LIFE FAIL: ", msg)


func _run() -> void:
	_ok(NightGlow.kind_for("cave_lamp") == "fire" and NightGlow.kind_for("mine_stone_lamp_0") == "fire", "miners' lamps are fire lights")
	var src := FileAccess.get_file_as_string("res://scripts/mine.gd")
	_ok(not ("get_ticks_msec() / 300" in src), "lava frames are not on a 300 ms wall clock")
	var any_drips := false
	var any_motes := false
	for fl in [1, 12, 25, 45]:
		GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
		GameState.run["intro_done"] = true
		GameState.run["flags"]["mine_seen"] = true
		GameState.run["mine_floor"] = fl
		GameMap.next_spawn = Vector2.ZERO
		(load("res://scripts/mine.gd") as Variant).force_seed = 1000 + fl
		change_scene_to_file("res://scenes/mine.tscn")
		for k in 12:
			await process_frame
		var m := current_scene as GameMap
		var ml: MineLife = m.get_node_or_null("MineLife") if m else null
		_ok(ml != null, "floor %d has its MineLife layer" % fl)
		if m and OS.get_environment("MLDBG") != "":
			var names := {}
			for n in m.get_children():
				if n is Sprite2D and n.texture:
					names[NightGlow.art_name(n)] = true
			var ks := []
			for l: Array in m.glow.lights:
				ks.append(NightGlow.art_name(l[0]) + ":" + str(l[0].get_parent() == m))
			print(fl, " lights ", ks, " reduced ", Settings.reduced_motion(), " ml children ", ml.get_child_count() if ml else -1)
		if ml:
			any_drips = any_drips or not ml.drips.is_empty()
			any_motes = any_motes or ml.get_node_or_null("Motes") != null
			for d: Array in ml.drips:
				_ok(float(d[1]) >= 3.0 and float(d[1]) <= 7.0, "drip beat 3-7 s")
	_ok(any_drips, "some stalactites drip")
	_ok(any_motes or Settings.reduced_motion(), "dust motes drift in lamp light")
	(load("res://scripts/mine.gd") as Variant).force_seed = 0
	print("mine_life_test: %s (%d fails)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)

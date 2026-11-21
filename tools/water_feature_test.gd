extends SceneTree
## C14b P2 (c14b_01-01, 14-01, 16-01): the Town Hall fountain is ONE still frame
## (full flow, never the dry frame) with the water moving in water_flow.gdshader
## on game time, seamless across the LOOP wrap, a random phase per fountain,
## droplets off under reduced motion. Optional arg: a folder -> saves 8 frames
## of the fountain 1/8 s apart (needs a renderer, not --headless).
##   godot --headless --path . --fixed-fps 60 -s res://tools/water_feature_test.gd
var fails := 0


func _initialize() -> void:
	seed(21)
	Campaign.bypass = true
	_run.call_deferred()


func _ok(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("WATER FEATURE FAIL: ", msg)


func _fountain(t: Node) -> Sprite2D:
	for n in t.get_children():
		if n is Sprite2D and n.has_meta("water_look"):
			return n
	return null


func _find_look(n: Node, look: String) -> Node:
	if n.has_meta("water_look") and str(n.get_meta("water_look")) == look:
		return n
	for ch in n.get_children():
		var r := _find_look(ch, look)
		if r:
			return r
	return null


func _run() -> void:
	var out := ""
	for a in OS.get_cmdline_user_args():
		out = a
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["flags"]["town_seen"] = true
	GameState.run["flags"]["town_tour"] = true
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/town.tscn")
	for k in 10:
		await process_frame
	var t := current_scene
	var f := _fountain(t)
	_ok(f != null, "the plaza fountain is a WaterFeature still (not a looping strip)")
	if f:
		_ok(int(f.get_meta("water_frame")) == 2, "full-flow frame 2, never the dry frame 0")
		_ok(f.material is ShaderMaterial and (f.material as ShaderMaterial).shader.resource_path.ends_with("water_flow.gdshader"), "water shader on the basin")
		var at := f.texture as AtlasTexture
		_ok(at != null and is_equal_approx(at.region.position.x, 246.0), "atlas region is frame 2 (x 246)")
		var wf: WaterFeature = f.get_node_or_null("WaterFeature")
		_ok(wf != null, "WaterFeature driver child")
		var m := f.material as ShaderMaterial
		paused = false  # an arrival card may hold the tree; this checks the clock, not the card
		var t0 := float(m.get_shader_parameter("t"))
		var gt := 0.0
		while gt < 0.5:
			paused = false
			await process_frame
			gt += root.get_process_delta_time()
		var t1 := float(m.get_shader_parameter("t"))
		_ok(t1 > t0 + 0.3, "water time runs on game time (%.2f -> %.2f)" % [t0, t1])
		paused = true
		for k in 10:
			await process_frame
		var t2 := float(m.get_shader_parameter("t"))
		for k in 10:
			await process_frame
		_ok(is_equal_approx(t2, float(m.get_shader_parameter("t"))), "water stops while paused (game time)")
		paused = false
		_ok(FileAccess.get_file_as_string("res://shaders/water_flow.gdshader").contains("MODEL_MATRIX[3]"), "per-fountain phase from world position (shared material)")
		if wf:
			_ok(Settings.reduced_motion() or wf.get_node_or_null("Drops") != null, "splash droplets when motion is on")
		if out != "":
			await _frames(f, out)
	# every water feature strip in the world holds still with flowing water (c14b_01-04)
	for sc in [["beach", "tide_pool"], ["mountain", "hot_spring"], ["lake", "waterfall_pool"]]:
		GameMap.next_spawn = Vector2.ZERO
		change_scene_to_file("res://scenes/%s.tscn" % sc[0])
		for k in 8:
			await process_frame
		var hit := _find_look(current_scene, str(sc[1]))
		if sc[0] == "beach":
			var mats := {}
			for n in current_scene.get_children():
				if n.has_meta("water_look") and str(n.get_meta("water_look")) == "tide_pool":
					mats[n.material] = true
			_ok(mats.size() == 1, "the beach tide pools share one water material (%d)" % mats.size())
		_ok(hit != null, "%s: %s is a still WaterFeature" % [sc[0], sc[1]])
		if out != "" and hit is Node2D:
			await _frames(hit, "%s/%s" % [out, sc[0]])
		if hit is AnimatedSprite2D:
			_ok(not (hit as AnimatedSprite2D).is_playing(), "%s: %s strip no longer loops" % [sc[0], sc[1]])
	# a still water strip placed with prop() shows its flowing frame, never the dry frame 0
	var m := current_scene as GameMap
	if m:
		var g := m.prop("props", "fountain2", Vector2i(2, 2), 0, 0.0, false)
		_ok(g != null and g.has_meta("water_look") and int(g.get_meta("water_frame")) == 2, "prop(fountain2) shows the full-flow frame with water")
		var a := m.anim_prop("props", "gold_fountain", Vector2i(4, 2))
		_ok(a != null and a.has_meta("water_look") and not a.is_playing(), "anim_prop(gold_fountain) holds still with flowing water")
	# seamless wrap: every shader frequency (Hz) times LOOP is a whole number of cycles
	for hz in [0.5, 0.3, 0.4, 1.5, 2.0]:
		var cyc: float = hz * WaterFeature.LOOP
		_ok(absf(cyc - roundf(cyc)) < 0.001, "%.2f Hz is seamless over LOOP" % hz)
	var src := FileAccess.get_file_as_string("res://shaders/water_flow.gdshader")
	_ok(not ("TIME" in src), "water_flow uses game time t, not shader TIME")
	print("water_feature_test: %s (%d fails)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)


func _frames(f: Node2D, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var cam := Camera2D.new()
	f.get_parent().add_child(cam)
	cam.global_position = f.global_position + Vector2(0, -18)
	cam.zoom = Vector2(3, 3)
	cam.make_current()
	for k in 8:
		var gt := 0.0
		while gt < 0.125:
			paused = false
			await process_frame
			gt += root.get_process_delta_time()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/f%d.png" % [out, k])

extends SceneTree
## C14b P1: the shared animation core (scripts/anim.gd, shaders/sway.gdshader).
##   godot --headless --fixed-fps 60 --path . -s res://tools/anim_test.gd
## - every strip named in data/anim_c14b.json loads (Art.has)
## - Anim.phase differs between neighbouring cells / nodes (no lockstep)
## - reduced motion lowers ambient amplitude (amp, wind cap, no gusts, bob)
## - Anim.t() is game time: it stops while the tree is paused
## - sway material is shared per strength, loads its shader; wind by weather; indoor = 0
## - anim_prop gives identical strips different start frames (town on game time)
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	seed(14)
	Campaign.bypass = true
	_run.call_deferred()


func _run() -> void:
	# data strips load
	var d := Anim.data()
	check(d is Dictionary, "anim_c14b.json parses")
	for id: String in d:
		var parts := id.split("/")
		var ok := false
		if parts.size() >= 2:
			ok = Art.has("/".join(parts.slice(0, parts.size() - 1)), parts[parts.size() - 1])
		else:
			for g: String in ["props", "nature", "fx", "buildings", "animals", "decor"]:
				ok = ok or Art.has(g, id)
		check(ok, "anim_c14b.json strip loads: " + id)
		var e: Dictionary = d[id]
		check(float(e.get("fps", 8.0)) > 0.0 and float(e.get("fps", 8.0)) <= 24.0, "sane fps for " + id)
	# phases
	var seen := {}
	var same := 0
	for x in 12:
		for y in 4:
			var p := Anim.phase(Vector2i(x, y))
			check(p >= 0.0 and p < 1.0, "phase in 0..1")
			var k := int(p * 50.0)
			if seen.has(k):
				same += 1
			seen[k] = true
	check(same < 24, "phases spread (%d collisions of 48)" % same)
	for x in 11:
		check(absf(Anim.phase(Vector2i(x, 3)) - Anim.phase(Vector2i(x + 1, 3))) > 0.01, "neighbour phases differ at %d" % x)
	check(Anim.phase(Vector2i(4, 4)) == Anim.phase(Vector2i(4, 4)), "phase stable")
	# reduced motion
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	var was := bool(Settings.get_v("shake"))
	Settings.set_v("shake", true)
	Anim._reset()
	Anim.set_weather("storm", "town", false)
	var full_amp := Anim.amp()
	var full_wind := Anim.wind_target()
	Settings.set_v("shake", false)
	check(Anim.reduced(), "reduced() follows Settings")
	check(Anim.amp() < full_amp * 0.5, "reduced amplitude (%.2f < %.2f)" % [Anim.amp(), full_amp])
	check(Anim.wind_target() <= 0.31 and Anim.wind_target() < full_wind, "reduced caps wind")
	var gmax := 0.0
	PlayClock.advance(0.0)
	for i in 200:
		PlayClock.advance(0.5)
		gmax = maxf(gmax, Anim.gust())
	check(gmax == 0.0, "no gusts with reduced motion")
	Settings.set_v("shake", true)
	gmax = 0.0
	for i in 200:
		PlayClock.advance(0.5)
		gmax = maxf(gmax, Anim.gust())
	check(gmax > 0.3, "gusts happen with full motion (%.2f)" % gmax)
	var n := Node2D.new()
	n.position = Vector2(40, 100)
	var bfull := 0.0
	for i in 60:
		PlayClock.advance(0.05)
		bfull = maxf(bfull, absf(Anim.bob(n, 2.0, 1.5)))
	Settings.set_v("shake", false)
	var bred := 0.0
	for i in 60:
		PlayClock.advance(0.05)
		bred = maxf(bred, absf(Anim.bob(n, 2.0, 1.5)))
	check(bfull >= 1.5 and bred <= 1.0 and bred < bfull, "bob amplitude reduced (%.1f -> %.1f)" % [bfull, bred])
	n.free()
	Settings.set_v("shake", true)
	# wind by weather; indoors 0
	Anim.set_weather("clear", "town", false)
	var calm := Anim.wind_target()
	Anim.set_weather("storm", "town", false)
	var storm := Anim.wind_target()
	check(storm > calm + 0.4, "storm windier than clear (%.2f vs %.2f)" % [storm, calm])
	Anim.set_weather("storm", "house", true)
	check(Anim.wind_target() == 0.0, "no wind indoors")
	# sway material shared, shader loads
	var m1 := Anim.sway_material(1.0)
	check(m1 != null and m1.shader != null, "sway shader loads")
	check(Anim.sway_material(1.05) == m1, "sway material shared per strength")
	check(Anim.sway_strength("tree_oak") > 0.0 and Anim.sway_strength("rock_big") == 0.0 and Anim.sway_strength("streetlight") == 0.0, "sway kinds by name")
	# game time stops while paused (DisplayMode ticks PlayClock only unpaused)
	var t0 := Anim.t()
	for i in 10:
		await process_frame
	var t1 := Anim.t()
	check(t1 > t0, "Anim.t advances unpaused (%.3f -> %.3f)" % [t0, t1])
	paused = true
	for i in 10:
		await process_frame
	var t2 := Anim.t()
	paused = false
	check(absf(t2 - t1) < 0.02, "Anim.t stops while paused (%.3f -> %.3f)" % [t1, t2])
	# tick pushes game time into the shared material
	for i in 3:
		await process_frame
	Anim.tick()
	check(absf(float(m1.get_shader_parameter("game_t")) - Anim.t()) < 0.05, "tick feeds game_t")
	# town: identical anim_props do not start in lockstep; foliage uses the sway material
	var scn := load("res://scenes/town.tscn") as PackedScene
	var m := scn.instantiate()
	root.add_child(m)
	for i in 4:
		await process_frame
	var by_strip := {}
	var names := {}
	for a in m.find_children("*", "AnimatedSprite2D", true, false):
		var sp := a as AnimatedSprite2D
		if sp.animation != "idle" or sp.get_script() != null or sp.sprite_frames == null or sp.sprite_frames.get_frame_count(sp.animation) < 2:  # anim_props (characters: P5)
			continue
		var key := str(sp.sprite_frames.get_instance_id()) + sp.animation
		if not by_strip.has(key):
			by_strip[key] = []
			names[key] = str(sp.get_parent().name) + "/" + str(sp.name) + " " + str(sp.get_script().resource_path if sp.get_script() else "")
		by_strip[key].append(sp.frame * 1000 + int(sp.speed_scale * 100.0))
	var groups := 0
	var lock := 0
	for key: String in by_strip:
		var arr: Array = by_strip[key]
		if arr.size() >= 3:
			groups += 1
			var uniq := {}
			for v: int in arr:
				uniq[v] = true
			if uniq.size() == 1:
				lock += 1
				printerr("lockstep group: ", key, " ", arr, " ", names[key])
	check(lock == 0, "no strip group of 3+ in lockstep (%d of %d groups)" % [lock, groups])
	var sway_n := 0
	for s in m.find_children("*", "Sprite2D", true, false):
		var mat := (s as Sprite2D).material
		if mat is ShaderMaterial and (mat as ShaderMaterial).shader != null and (mat as ShaderMaterial).shader.resource_path.ends_with("sway.gdshader"):
			sway_n += 1
	check(sway_n > 0, "town foliage sways via the shared material (%d sprites)" % sway_n)
	var mats := {}
	for s in m.find_children("*", "CanvasItem", true, false):
		var mt: Material = (s as CanvasItem).material
		if mt is ShaderMaterial:
			mats[mt.get_instance_id()] = true
	check(mats.size() <= 12, "distinct ShaderMaterials under the town <= 12 (%d)" % mats.size())
	m.queue_free()
	Settings.set_v("shake", was)
	await process_frame
	print("anim_test: %d failures (%d sway sprites, %d strip groups, %d materials)" % [fails, sway_n, groups, mats.size()])
	quit(1 if fails > 0 else 0)

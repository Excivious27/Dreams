extends SceneTree
## C14b P2 lights (c14b_04-01, 04-04, 04-06, 04-07, 04-19, 16-16): fires flicker,
## electric lamps hold steady, neon drops out now and then, crystals breathe, all
## on game time and per-light phase; reduced motion calms them; homes' windows go
## out one by one with a fade; room fires glow by day and their animated props
## start on different frames; kettles steam.
##   godot --headless --path . --fixed-fps 60 -s res://tools/glow_kinds_test.gd
var fails := 0


func _initialize() -> void:
	seed(4)
	Campaign.bypass = true
	_run.call_deferred()


func _ok(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("GLOW KINDS FAIL: ", msg)


func _spread(kind: String, ph: float, reduced: bool, comp: int) -> float:
	var lo := 9.0
	var hi := -9.0
	for i in 600:
		var v: float = NightGlow.flicker(kind, i * 0.05, ph, reduced)[comp]
		lo = minf(lo, v)
		hi = maxf(hi, v)
	return hi - lo


func _run() -> void:
	_ok(NightGlow.kind_for("hearth") == "fire" and NightGlow.kind_for("candle_stand") == "fire" and NightGlow.kind_for("torch_wall") == "fire", "fires are fire")
	_ok(NightGlow.kind_for("lamp_floor") == "electric" and NightGlow.kind_for("streetlight_2") == "electric", "lamps are electric")
	_ok(NightGlow.kind_for("neon_sign_3") == "neon" and NightGlow.kind_for("ice_crystal_lit") == "crystal", "neon and crystal kinds")
	_ok(_spread("fire", 0.3, false, 0) > 0.06 and _spread("fire", 0.3, false, 1) > 0.1, "fire flickers in size and brightness")
	_ok(_spread("fire", 0.3, true, 0) < _spread("fire", 0.3, false, 0) * 0.5, "reduced motion calms the fire")
	_ok(_spread("electric", 0.3, false, 1) < 0.001 and _spread("electric", 0.3, false, 0) < 0.03, "electric lamps hold steady")
	_ok(_spread("neon", 0.4, false, 1) > 0.5, "neon drops out now and then")
	_ok(_spread("neon", 0.4, true, 1) < 0.001, "no neon dropouts under reduced motion")
	_ok(_spread("crystal", 0.1, false, 1) > 0.15, "crystals breathe")
	var a := NightGlow.flicker("fire", 3.0, 0.1, false)
	var b := NightGlow.flicker("fire", 3.0, 0.7, false)
	_ok(not a.is_equal_approx(b), "two fires are not in step")
	# windows: homes go dark one by one and fade
	_ok(NightGlow.window_level("home", 21.0) == 1.0 and NightGlow.window_level("home", 23.5) == 0.0, "homes lit at 21, dark at 23:30")
	_ok(NightGlow.window_level("home", 22.4, 0.0) < 0.5 and NightGlow.window_level("home", 22.4, 1.0) > 0.99, "homes go out at different times")
	var mid := NightGlow.window_level("home", 22.6, 0.5)
	_ok(mid > 0.05 and mid < 0.95, "a window fades out, no snap (%.2f)" % mid)
	# interiors
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["time"] = 12 * 60  # midday
	for room in ["chapel", "smith", "lighthouse"]:
		GameMap.next_interior = room
		GameMap.next_spawn = Vector2.ZERO
		change_scene_to_file("res://scenes/interior.tscn")
		for k in 8:
			await process_frame
		var m := current_scene as GameMap
		_ok(m != null and m.glow != null, "%s loads with a glow layer" % room)
		if m == null or m.glow == null:
			continue
		var anims: Array = []
		var lit_anim := false
		var steam := false
		for n in m.get_children():
			if n is AnimatedSprite2D:
				anims.append(n)
				for l: Array in m.glow.lights:
					if l[0] == n:
						lit_anim = true
			if n is Node2D and n.get_node_or_null("Steam") != null:
				steam = true
		match room:
			"chapel":
				_ok(lit_anim, "chapel candles glow")
				var sp := {}
				for an: AnimatedSprite2D in anims:
					sp[snappedf(an.speed_scale, 0.001)] = true
				_ok(anims.size() < 2 or sp.size() >= 2, "twin candles run at their own pace")
			"smith":
				_ok(lit_anim, "the forge glows")
				var fire := false
				for l: Array in m.glow.lights:
					if is_instance_valid(l[0]) and m.glow.kind_of(l[0]) == "fire":
						fire = true
				_ok(fire, "the forge is a fire light")
			"lighthouse":
				_ok(steam or Settings.reduced_motion(), "the kettle stove steams")
	print("glow_kinds_test: %s (%d fails)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)

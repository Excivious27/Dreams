extends SceneTree
## C14b P2 (c14b_13-02, 13-03): the lit lighthouse holds its lit-lens frame and a
## code beam sweeps smoothly (reach = cos, no jumps between poses), dark by day;
## the water mill holds one frame instead of boiling through 4 renders.
##   godot --headless --path . --fixed-fps 60 -s res://tools/shore_motion_test.gd
var fails := 0


func _initialize() -> void:
	seed(13)
	Campaign.bypass = true
	_run.call_deferred()


func _ok(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("SHORE MOTION FAIL: ", msg)


func _find(n: Node, nm: String) -> Node:
	if n.name == nm:
		return n
	for ch in n.get_children():
		var r := _find(ch, nm)
		if r:
			return r
	return null


func _run() -> void:
	# smooth sweep: small game-time steps never jump the reach
	var prev := LighthouseBeam.sweep(0.0, false).x
	var maxj := 0.0
	for i in range(1, 600):
		var v := LighthouseBeam.sweep(i / 60.0, false).x
		maxj = maxf(maxj, absf(v - prev))
		prev = v
	_ok(maxj < 0.05, "the beam turns smoothly (max step %.3f)" % maxj)
	_ok(LighthouseBeam.sweep(0.0, true) == LighthouseBeam.sweep(9.0, true), "reduced motion holds the beam still")
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["flags"]["lighthouse_lit"] = true
	GameState.run["time"] = 12 * 60
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/lake.tscn")
	for k in 10:
		await process_frame
	var lit := _find(current_scene, "LighthouseLit") as AnimatedSprite2D
	_ok(lit != null, "the lit lighthouse is placed")
	if lit:
		_ok(not lit.is_playing() and lit.frame == 1, "the tower holds its lit-lens frame")
		_ok(lit.get_node_or_null("Beam") is LighthouseBeam, "a code beam turns on the lamp")
	_ok(GameState.weather_today() in ["fog", "storm", "rain"] or LighthouseBeam.strength() < 0.03, "no beam at noon")
	var mill: AnimatedSprite2D = null
	for n in current_scene.get_children():
		if n is AnimatedSprite2D and (n as AnimatedSprite2D).sprite_frames and "water_mill" in NightGlow.art_name(n):
			mill = n
	_ok(mill == null or not mill.is_playing(), "the water mill holds still (no boiling frames)")
	print("shore_motion_test: %s (%d fails)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)

extends SceneTree
## Mine arrival (c5_16 #1): entering a mine floor (and descending) must not sit on
## a black cover waiting for a ground bake that chunked mines never start.
## The cover has to start fading within 0.3 s of game time.
##   godot --headless --path . --fixed-fps 60 -s res://tools/mine_arrival_test.gd
var fails := 0

func _initialize() -> void:
	seed(5)
	Campaign.bypass = true
	(load("res://scripts/mine.gd") as Variant).force_seed = 7
	_run.call_deferred()

func _ok(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("MINE ARRIVAL FAIL: ", msg)

func _arrive(label: String) -> void:
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/mine.tscn")
	var gt := 0.0
	var lifted := -1.0
	for k in 120:
		await process_frame
		gt += root.get_process_delta_time()
		var m := current_scene as GameMap
		if m == null or m.hud == null:
			continue
		var cover: ColorRect = m.hud.get("_fade")
		if cover != null and k >= 1 and (not cover.visible or cover.color.a < 0.99):
			lifted = gt
			break
	print("  %s: cover starts fading after %.2f s" % [label, lifted])
	_ok(lifted >= 0.0 and lifted <= 0.3, "%s: black cover held %.2f s (> 0.3 s)" % [label, lifted])
	var m2 := current_scene as GameMap
	_ok(m2 != null and not bool(m2.get("_bake_covered")), "%s: bake cover flag released" % label)

func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	GameState.run["flags"]["mine_seen"] = true
	await _arrive("floor 1")
	GameState.run["mine_floor"] = 2
	await _arrive("floor 2 (descent)")
	print("mine_arrival_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

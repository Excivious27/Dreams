extends SceneTree
## c11b_08-03: a ♥ (ability) tap made while the player is busy is dropped, never kept to fire later.
##   godot --headless --path . --fixed-fps 60 -s res://tools/ability_tap_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(811)
	Campaign.bypass = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	Companion.recruit("penguin_f", false)
	Companion.party()["active"] = "penguin_f"
	change_scene_to_file("res://scenes/farm.tscn")
	for i in 30:
		await process_frame
	var m := current_scene as GameMap
	check(m != null and m.player != null, "farm and player loaded")
	if m == null or m.player == null:
		print("ability_tap_test: %d fails" % (fails + 1))
		quit(1)
		return
	# Before Catkins the button only explains (sets meow_wait_hint): a clean marker for "it fired".
	GameState.run["flags"].erase("meow_wait_hint")
	m.player.set("_busy", true)
	TouchControls.ability_pressed = true
	await _frames(3)
	check(not TouchControls.ability_pressed, "the tap is consumed while busy")
	check(not GameState.run["flags"].has("meow_wait_hint"), "a refused tap does nothing")
	m.player.set("_busy", false)
	await _frames(20)
	check(not GameState.run["flags"].has("meow_wait_hint"), "and it never fires later, unasked")
	# Sanity: a tap while free still works.
	TouchControls.ability_pressed = true
	await _frames(3)
	check(GameState.run["flags"].has("meow_wait_hint"), "a tap while free uses the ability")
	print("ability_tap_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)

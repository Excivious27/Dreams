extends SceneTree
## Enemies defend themselves against the pup, and the pup command strip works.
##   godot --headless --path . -s res://tools/ally_test.gd
var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	_run.call_deferred()

func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	GameMap.next_spawn = Vector2(40 * 16, 40 * 16)
	change_scene_to_file("res://scenes/farm.tscn")
	for i in 10:
		await process_frame
	var m := current_scene as GameMap
	var d := Dialogue.instance(self)
	for i in 30:
		if d.active:
			Input.action_press("a"); await process_frame; Input.action_release("a")
		await process_frame
	var pet := m.pet as Pet
	check(pet != null and m.allies().has(pet), "the pup counts as an ally")
	if pet == null:
		print("ally_test: %d failures" % fails); quit(1); return
	# The player stands well away; the pup is next to the enemy.
	m.player.position = pet.position + Vector2(-150, 0)
	m.player.frozen = true
	Pet.state()["hp"] = Pet.max_hp()
	Pet.state()["mode"] = "wait"
	var e := m.spawn_enemy("grump", pet.position + Vector2(20, 0))
	for i in 3:
		await process_frame
	e.position = pet.position + Vector2(18, 0)
	var hp0 := int(Pet.state()["hp"])
	e.provoke(pet)
	var struck := false
	for i in 400:
		await process_frame
		pet.position = e.position + Vector2(-14, 0)  # hold the pup in reach
		e.provoke(pet)
		if int(Pet.state()["hp"]) < hp0:
			struck = true
			break
	check(struck, "a provoked enemy strikes the pup back (hp %d → %d)" % [hp0, int(Pet.state()["hp"])])
	# Hitting it yourself pulls it back onto you.
	e.provoke(m.player)
	check(e._aggro == m.player, "your own hit takes its attention back")
	# The command strip.
	var tc: TouchControls = null
	for ch in m.get_children():
		if ch is TouchControls:
			tc = ch
	check(tc != null, "touch controls present")
	if tc:
		Pet.state()["hp"] = Pet.max_hp()
		check(tc._hit(Vector2(TouchControls.PUP_X, TouchControls.PUP_Y0 + TouchControls.PUP_STEP)) == "pup:attack", "the strip's second button is Attack")
		tc._press("pup:attack"); tc._release("pup:attack")
		check(str(Pet.state()["mode"]) == "attack", "tapping it sets attack mode")
		tc._press("pup:follow"); tc._release("pup:follow")
		check(str(Pet.state()["mode"]) == "follow", "Heel sets follow")
		tc._press("pup:wait"); tc._release("pup:wait")
		check(str(Pet.state()["mode"]) == "wait", "Stay sets wait")
		tc.release_all()
	print("ally_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

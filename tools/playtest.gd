extends SceneTree
## Scripted playthrough: starts a new penguin run, gets through the intro, farms a
## tile, sleeps, visits town, fights in the meadow, mines. Saves screenshots to the
## path after "--" and fails loudly if a step doesn't do what it should.
## Run: xvfb-run godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/playtest.gd -- /tmp/shots

var out := "/tmp"
var fails := 0
var shots := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		out = OS.get_cmdline_user_args()[0]
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameMap.next_spawn = Vector2.ZERO
	var farm: Node = (load("res://scenes/farm.tscn") as PackedScene).instantiate()
	root.add_child(farm)
	current_scene = farm
	await frames(30)
	await shot("01_intro")
	# Advance intro until a choice appears.
	var d := Dialogue.instance(self)
	for i in 30:
		if d._in_choice:
			break
		await press("a", 2)
		await frames(6)
	check(d._in_choice, "intro reached the crystal's question")
	await shot("02_choice")
	await press("a", 2)   # choose option 0
	for i in 30:
		if not d.active:
			break
		await press("a", 2)
		await frames(6)
	check(not d.active, "intro finished")
	check(bool(GameState.run["intro_done"]), "intro_done flag set")
	check(GameState.run["quests"].size() >= 2, "quests added")
	await frames(10)
	await shot("03_after_intro")

	# Walk to the plot and farm one tile.
	var p: Player = farm.player
	p.position = farm.cell_center(Vector2i(12, 9))
	p.facing = "up"
	await frames(5)
	var fc := p.facing_cell()
	check(farm.things.get(fc, {}).get("type", "") == "plot", "facing a plot tile (%s)" % str(fc))
	await press("a", 3)
	await frames(5)
	var key := "%d,%d" % [fc.x, fc.y]
	check(GameState.run["farm"].has(key), "tilled a tile")
	GameState.run["selected"] = "turnip_seed"
	await press("a", 3)
	await frames(5)
	check(GameState.run["farm"][key].get("crop", "") == "turnip", "planted turnip")
	GameState.run["selected"] = ""
	await press("a", 3)
	await frames(5)
	check(bool(GameState.run["farm"][key].get("watered", false)), "watered the tile")
	await shot("04_farming")

	# Run test (keyboard path): hold B + right and check speed.
	p.position = farm.cell_center(Vector2i(12, 16))
	Input.action_press("right"); Input.action_press("b")
	await frames(40)
	var spd := p.velocity.length()
	Input.action_release("right"); Input.action_release("b")
	check(spd > Player.WALK_SPEED * 1.3, "running is faster than walking (%.0f)" % spd)
	await frames(30)
	# Touch path: finger 0 on the D-pad (right), finger 1 holding B.
	p.position = farm.cell_center(Vector2i(3, 13))
	touch(0, TouchControls.DPAD_CENTER + Vector2(30, 0), true)
	touch(1, TouchControls.BUTTONS["b"]["pos"], true)
	await frames(40)
	var tspd := p.velocity.length()
	check(tspd > Player.WALK_SPEED * 1.3, "touch D-pad + B runs (%.0f)" % tspd)
	touch(1, TouchControls.BUTTONS["b"]["pos"], false)
	await frames(25)
	var wspd := p.velocity.length()
	check(wspd < Player.WALK_SPEED * 1.15 and wspd > 10.0, "releasing B walks (%.0f)" % wspd)
	touch(0, TouchControls.DPAD_CENTER + Vector2(30, 0), false)
	await frames(10)
	# Tap B while moving toggles run mode.
	touch(0, TouchControls.DPAD_CENTER + Vector2(-30, 0), true)
	await frames(5)
	touch(1, TouchControls.BUTTONS["b"]["pos"], true)
	await frames(3)
	touch(1, TouchControls.BUTTONS["b"]["pos"], false)
	await frames(40)
	check(TouchControls.run_toggle and p.velocity.length() > Player.WALK_SPEED * 1.3, "tapping B toggles run (%.0f)" % p.velocity.length())
	touch(0, TouchControls.DPAD_CENTER + Vector2(-30, 0), false)
	TouchControls.run_toggle = false
	await frames(10)
	await shot("05_running")
	# Touch A on the sell box opens a dialogue, tapping the box advances it.
	p.position = farm.cell_center(Vector2i(3, 11))
	p.facing = "up"
	await frames(3)
	touch(1, TouchControls.BUTTONS["a"]["pos"], true)
	await frames(3)
	touch(1, TouchControls.BUTTONS["a"]["pos"], false)
	await frames(10)
	check(d.active, "touch A talks to the sell box")
	touch(0, Vector2(135, 300), true)
	await frames(2)
	touch(0, Vector2(135, 300), false)
	await frames(2)
	touch(0, Vector2(135, 300), true)
	await frames(2)
	touch(0, Vector2(135, 300), false)
	await frames(10)
	check(not d.active, "tapping the dialogue box advances/closes it")

	# Enter the house via the door.
	p.position = farm.cell_center(Vector2i(5, 8))
	p.facing = "up"
	await frames(3)
	check(farm.things.get(p.facing_cell(), {}).get("type", "") == "door", "facing the door")
	await press("a", 3)
	await frames(50)
	var house := current_scene
	check(house != null and house.scene_id() == "house", "entered the house")
	await shot("06_house")
	# Sleep.
	house.player.position = house.cell_center(Vector2i(2, 3))
	house.player.facing = "up"
	await frames(3)
	var day0 := int(GameState.run["day"])
	await press("a", 3)
	for i in 40:
		await frames(5)
		if d.active:
			await press("a", 2)
		if int(GameState.run["day"]) > day0 and not d.active:
			break
	check(int(GameState.run["day"]) == day0 + 1, "slept to the next day")
	check(int(GameState.run["farm"][key]["days"]) == 1, "crop grew overnight")
	await shot("07_morning")

	# Go to town directly.
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/town.tscn")
	await frames(40)
	var town := current_scene
	check(town != null and town.scene_id() == "town", "in town")
	for i in 10:
		if not d.active:
			break
		await press("a", 2)
		await frames(6)
	await shot("08_town")
	# Talk to Maple.
	var maple: Npc = town.npcs[0]
	town.player.position = maple.position + Vector2(0, 14)
	town.player.facing = "up"
	await frames(20)
	await press("a", 3)
	await frames(10)
	check(d.active, "Maple talks")
	await shot("09_talk")
	for i in 10:
		if not d.active:
			break
		await press("a", 2)
		await frames(6)
	check(GameState.quest_done("meet_town"), "meet_town quest completed")
	# Shop: buy strawberry seeds.
	town.player.position = town.cell_center(Vector2i(5, 9))
	town.player.facing = "up"
	await frames(3)
	var before := int(GameState.run["crystals"])
	await press("a", 3)
	await frames(10)
	for i in 10:  # first-visit freebie lines
		if d._in_choice:
			break
		await press("a", 2)
		await frames(6)
	check(d._in_choice, "shop menu open")
	await shot("10_shop")
	await press("down", 2)
	await press("a", 2)   # buy option 1 (strawberry seeds)
	await frames(10)
	check(int(GameState.run["crystals"]) < before, "bought something")
	# Leave the shop: focus starts at 0, so one "up" wraps to the last option (Leave).
	for i in 10:
		if not d.active:
			break
		if d._in_choice:
			await press("up", 2)
			await press("a", 2)
		else:
			await press("a", 2)
		await frames(6)
	for i in 5:
		if not d.active:
			break
		await press("a", 2)
		await frames(6)
	check(not d.active, "left the shop")

	# Meadow combat.
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/meadow.tscn")
	await frames(40)
	var meadow := current_scene
	for i in 10:
		if not d.active:
			break
		await press("a", 2)
		await frames(6)
	check(meadow.enemies.size() >= 3, "grumps spawned (%d)" % meadow.enemies.size())
	await shot("11_meadow")
	var kills0 := int(GameState.run["kills"])
	for i in 12:
		if meadow.enemies.is_empty():
			break
		var e: Enemy = meadow.enemies[0]
		meadow.player.position = e.position + Vector2(-12, 0)
		meadow.player.facing = "right"
		meadow.player.invuln = 1.0
		await press("a", 2)
		await frames(14)
	check(int(GameState.run["kills"]) > kills0, "defeated a grump")
	await shot("12_fight")

	# Mine.
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/mine.tscn")
	await frames(40)
	var mine := current_scene
	for i in 10:
		if not d.active:
			break
		await press("a", 2)
		await frames(6)
	check(mine.scene_id() == "mine", "in the mine")
	await shot("13_mine")

	# ---- Gangster arc: intro, choice, and the meadow boss. ----
	GameState.new_run("gangsters", "pax", "Pax", "Dreamhollow", "Rex")
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/farm.tscn")
	await frames(40)
	for i in 30:
		if d._in_choice:
			break
		await press("a", 2)
		await frames(6)
	check(d._in_choice, "gangster intro reaches the letter choice")
	await shot("14_gangster_choice")
	await press("down", 2)
	await press("a", 2)
	for i in 30:
		if not d.active:
			break
		await press("a", 2)
		await frames(6)
	check(str(GameState.run["flags"].get("letter", "")) == "kept", "letter decision stored")
	GameState.run["kills"] = 4
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/meadow.tscn")
	await frames(40)
	var m2 := current_scene
	for i in 10:
		if not d.active:
			break
		await press("a", 2)
		await frames(6)
	# Swinging was verified above; here just finish one grump to trigger the boss.
	var e0: Enemy = m2.enemies[0]
	m2.player.invuln = 3.0
	e0.hit(10, m2.player.position)
	await frames(60)
	for i in 10:
		if not d.active:
			break
		await press("a", 2)
		await frames(6)
	await frames(10)
	var boss: Enemy = null
	for e in m2.enemies:
		if e.kind == "big_grump":
			boss = e
	check(boss != null, "boss appeared after 5 kills")
	await shot("15_boss")
	if boss:
		boss.hp = 1
		m2.player.position = boss.position + Vector2(-12, 0)
		m2.player.facing = "right"
		m2.player.invuln = 2.0
		await press("a", 2)
		await frames(20)
		for i in 10:
			if not d.active:
				break
			await press("a", 2)
			await frames(6)
		check(GameState.quest_done("clear_meadow"), "boss defeated completes the meadow quest")
	print("PLAYTEST DONE, failures: ", fails, ", screenshots: ", shots)
	quit(1 if fails > 0 else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		fails += 1
		printerr("  FAIL ", what)


func press(action: String, hold_frames: int) -> void:
	Input.action_press(action)
	await frames(hold_frames)
	Input.action_release(action)
	await frames(1)


func touch(index: int, pos: Vector2, pressed: bool) -> void:
	# Test positions are in game (viewport) space; real touches arrive in window
	# space and Godot maps them through the stretch transform, so do the reverse.
	var scale := Vector2(root.size) / Vector2(270, 480)
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos * scale
	ev.pressed = pressed
	Input.parse_input_event(ev)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await frames(2)
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	shots += 1

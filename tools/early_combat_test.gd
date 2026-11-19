extends SceneTree
## Early combat test (CONDUCT 1, c1_12): the first fights of a new player.
## - the clinic's first visit is free, later bills stay small on a thin purse
## - the pup/fight lesson is told once
## - a melee wind-up shows the tele_strike icon (art present and loaded)
## - the pup's mine dig clock doesn't run while it fights
## - the meadow's first boss can be beaten toe to toe from full health with
##   the starter sword (scripted naive fighter keeps over a third of its health)
## Run: godot --headless --path . -s res://tools/early_combat_test.gd
## Screenshot of the telegraph: xvfb-run -a godot --path . --rendering-driver opengl3
##   --resolution 540x960 -s res://tools/early_combat_test.gd -- /tmp/shots

var fails := 0


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	InputSetup.ensure_actions()
	var out := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
		DirAccess.make_dir_recursive_absolute(out)
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	# Clinic bills.
	check(Faint.clinic_fee(50, 0, 1.0) == 0, "first clinic visit is free")
	check(Faint.free_line().begins_with("First visit"), "first free visit says why")
	check(Faint.free_line() == "No charge this time.", "the first-visit line is said once")
	var f50 := Faint.clinic_fee(50, 1, 1.0)
	check(f50 > 0 and f50 <= 15, "a thin purse pays a small bill (%d of 50)" % f50)
	var f1000 := Faint.clinic_fee(1000, 0, 1.0)
	check(f1000 >= 80 and f1000 <= 110, "a full purse pays ~10%% (%d of 1000)" % f1000)
	check(Faint.clinic_fee(1000, 0, 0.0) == 0, "discounts still zero the bill")
	# The lesson.
	var l1 := PupIntro.lines()
	check(l1.size() == 3 and str(l1[1]["text"]).contains("Biscuit"), "pup lesson told with the pup's name")
	check(PupIntro.lines().is_empty(), "pup lesson told only once")
	# Telegraph art.
	check(Art.has("ui", "tele_strike") and Art.tex("ui", "tele_strike") != null, "tele_strike icon is in the manifest and imported")
	# Meadow: wind-up shows the icon, then the boss fight.
	GameState.run["flags"]["meadow_seen"] = true
	GameState.run["energy"] = 999
	GameState.run["max_energy"] = 999
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/meadow.tscn")
	await frames(12)
	var m := current_scene as GameMap
	check(m != null and m.scene_id() == "meadow", "in the meadow")
	for e in m.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	m.enemies.clear()
	var p := m.player
	p.position = m.cell_center(Vector2i(14, 10))
	if m.pet:
		m.pet.position = p.position + Vector2(-16, 6)
	var g := m.spawn_enemy("grump", p.position + Vector2(18, 0))
	await frames(2)
	g._windup = 5.0
	g._cooldown = 9.0
	await frames(3)
	check(g._sprite == null or g._sprite.modulate.g < 0.7, "a winding-up foe is tinted red")
	if out != "":
		p.invuln = 99.0
		await frames(4)
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out.path_join("tele_strike.png"))
		print("  shot ", out.path_join("tele_strike.png"))
	g.queue_free()
	m.enemies.clear()
	# Pup dig clock pauses mid-fight.
	if m.pet is Pet:
		var pt := m.pet as Pet
		var dummy := m.spawn_enemy("grump", p.position + Vector2(-40, -30))
		pt._carry_item = "fetch"
		pt._carry_find = "mine"
		pt._target = dummy
		pt.set_meta("forage_run", 3.9)
		PupMine.tick(pt, 1.0)
		check(pt._carry_item == "fetch", "the pup doesn't stop to dig with a foe on it")
		pt._carry_item = ""
		pt._carry_find = ""
		pt._target = null
		dummy.queue_free()
		m.enemies.clear()
		pt.visible = false
		pt.process_mode = Node.PROCESS_MODE_DISABLED
	# First boss, as meadow.gd sets it up, against a fighter who never dodges.
	p.invuln = 0.0
	GameState.run["hp"] = 100
	GameState.select_slot((GameState.run["toolbar"] as Array).find("sword"))
	var b := m.spawn_enemy("big_grump", p.position + Vector2(40, 0))
	b.damage = 1
	var t := 0.0
	while is_instance_valid(b) and b._alive and t < 40.0 and int(GameState.run["hp"]) > 0:
		await process_frame
		t += 1.0 / 60.0
		var to: Vector2 = b.position - p.position
		if to.length() > 16.0:
			p.position += to.normalized() * Player.WALK_SPEED / 60.0
		else:
			p.face_toward(b.position)
			if p._attack_cd <= 0.0 and not p._busy:
				p.do_action("tool")
	var won := not (is_instance_valid(b) and b._alive)
	check(won and int(GameState.run["hp"]) >= 34, "first boss beaten toe to toe, %d/100 health left" % int(GameState.run["hp"]))
	print("early_combat_test: %s (%d fails)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)

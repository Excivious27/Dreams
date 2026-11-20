extends SceneTree
## Early-combat audit (CONDUCT 1): a new player's first fights in both arcs.
## Prints each early foe's numbers and runs two scripted fighters against it in
## the meadow: "naive" stands and swings, "careful" steps back while the foe
## winds up (the red tint / ! telegraph). Reports health lost per fight.
## Run: godot --headless --path . -s res://tools/early_fight_audit.gd
## DIFF=0..3 env plays a difficulty mode (0 Very easy .. 3 Hard; default 2).

const FOES := {
	"penguins": [["grump", -1], ["big_grump", -1], ["slime", 0], ["bat", 0], ["mud_slime", 0], ["golem", 0], ["keeper1", 0]],
	"gangsters": [["thug_lookout", -1], ["thug_brute", 1], ["slime", 0], ["bat", 0], ["mud_slime", 0], ["golem", 0], ["keeper1", 0]],
}


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	InputSetup.ensure_actions()
	for arc in ["penguins", "gangsters"]:
		print("== %s ==" % arc)
		for f in FOES[arc]:
			for style in ["naive", "careful"]:
				await _fight(arc, str(f[0]), int(f[1]), style)
	quit(0)


func _fight(arc: String, kind: String, tier: int, style: String) -> void:
	GameState.new_run(arc, "kairi" if arc == "penguins" else "vic", "Kai", "Town", "Pup", {"difficulty": int(OS.get_environment("DIFF")) if OS.get_environment("DIFF") != "" else Difficulty.DEFAULT})
	GameState.run["intro_done"] = true
	GameState.run["flags"]["meadow_seen"] = true
	GameState.run["energy"] = 999
	GameState.run["max_energy"] = 999
	GameState.run["meadow_kills"] = 0
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/meadow.tscn")
	await frames(12)
	var m := current_scene as GameMap
	for e in m.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	m.enemies.clear()
	if m.pet:
		m.pet.visible = false
		m.pet.process_mode = Node.PROCESS_MODE_DISABLED
	var tb: Array = GameState.run["toolbar"]
	GameState.select_slot(tb.find("sword"))
	var p := m.player
	p.position = m.cell_center(Vector2i(14, 10))
	var e := m.spawn_enemy("golem" if kind == "keeper1" else kind, p.position + Vector2(40, 0), tier)
	if kind in ["thug_brute", "big_grump"]:
		e.damage = 1  # as meadow.gd's _summon_boss sets it
	if kind == "keeper1":
		# Floor 1's keeper as Mine._summon_guardian builds it.
		e.is_guardian = true
		e.max_hp = int(int(e.max_hp * 1.3) * 1.45)
		e.speed = maxf(e.speed, 27.0)
		for a in ["lunge", "stomp"]:
			if not e.abilities.has(a):
				e.abilities.append(a)
		e.hp = e.max_hp
	var hp0 := int(GameState.run["hp"])
	var t := 0.0
	var swings := 0
	var start := Time.get_ticks_msec()
	while is_instance_valid(e) and e._alive and t < 60.0 and int(GameState.run["hp"]) > 0:
		await process_frame
		var dt := 1.0 / 60.0
		t += dt
		var to: Vector2 = e.position - p.position
		var tele: bool = e._windup > 0.0 or e._lunge_tele > 0.0 or e._stomp_tele > 0.0 or e._range_tele > 0.0
		if style == "careful" and tele and to.length() < 34.0:
			p.position -= to.normalized() * Player.WALK_SPEED * 1.4 * dt
		elif to.length() > 16.0:
			p.position += to.normalized() * Player.WALK_SPEED * dt
		else:
			p.face_toward(e.position)
			if p._attack_cd <= 0.0 and not p._busy:
				p.do_action("tool")
				swings += 1
		if Time.get_ticks_msec() - start > 20000:
			break
	var lost := hp0 - int(GameState.run["hp"])
	var won := not (is_instance_valid(e) and e._alive)
	print("  %-13s t%-2d %-8s hp %3d dmg %2d spd %3d reach %2d -> %s in %4.1fs, %2d swings, lost %3d/%d health" % [
		kind, (e.tier if is_instance_valid(e) else tier), style, (e.max_hp if is_instance_valid(e) else 0),
		(GameState.enemy_damage(e.damage) if is_instance_valid(e) else 0), (int(e.speed) if is_instance_valid(e) else 0),
		(int(e.reach) if is_instance_valid(e) else 0), "won" if won else "LOST/timeout", t, swings, lost, hp0])

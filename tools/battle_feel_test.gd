extends SceneTree
## C16b P2: battle feel and unit AI, headless on a real battlefield (bf_frostfield).
##  - c16b_11-01 a striker helper closes in and stands its ground: a melee foe lands at
##    least one hit on it, and the helper still beats it (no endless kiting).
##  - c16b_11-02 a ranged foe shoots a lone turret from range (> 34 px) instead of walking
##    up to melee it, and its rounds can hit allies.
##  - c16b_11-12 a team animal with speed 1.3 covers more ground than one with 1.0.
##  - c16b_11-11 helpers arrive with a scale-in; c16b_11-13 the alert sting is throttled.
##   godot --headless --fixed-fps 60 --path . -s res://tools/battle_feel_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(16)
	_run.call_deferred()


func _arrive(sc: String, limit := 600) -> GameMap:
	for i in limit:
		var gm := current_scene as GameMap
		if gm != null and gm.scene_id() == sc and gm.player != null and not gm._changing:
			for k in 6:
				await process_frame
			return gm
		var d := Dialogue.instance(self)
		if d.active:
			if d._in_choice:
				d._choose("", d._choices.get_child_count() - 1)
			else:
				d._advance()
		await process_frame
	return current_scene as GameMap


## Run game time (frames at --fixed-fps 60), closing any dialogue that opens.
func _run_for(sec: float) -> void:
	var gt := 0.0
	while gt < sec:
		var d := Dialogue.instance(self)
		if d.active:
			if d._in_choice:
				d._choose("", d._choices.get_child_count() - 1)
			else:
				d._advance()
		await process_frame
		gt += root.get_process_delta_time() if root.get_process_delta_time() > 0.0 else 1.0 / 60.0


func _clear(m: GameMap) -> void:
	for e in m.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	m.enemies.clear()
	for n in get_nodes_in_group("allies"):
		if n is HelperUnit or n.get_script() == load("res://scripts/battle_turret.gd"):
			n.queue_free()
	for k in ["follow_me", "rally_pos", "team_push"]:
		if m.has_meta(k):
			m.remove_meta(k)


## An open spot: a walkable cell with walkable cells all round it (r cells).
func _open_spot(m: GameMap, r := 4) -> Vector2:
	var pc := m.world_to_cell(m.player.position)
	for rad in range(0, 30):
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				var c := pc + Vector2i(dx, dy)
				var ok := true
				for yy in range(-r, r + 1):
					for xx in range(-r, r + 1):
						var cc := c + Vector2i(xx, yy)
						if m.blocked.has(cc) or m.is_water_cell(cc) or not m.in_content(cc):
							ok = false
							break
					if not ok:
						break
				if ok:
					return m.cell_center(c)
	return m.player.position


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["hp"] = 999
	GameState.run["max_hp"] = 999
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/bf_frostfield.tscn")
	var m := await _arrive("bf_frostfield")
	check(m != null, "the field loads")
	if m == null:
		quit(1)
		return
	var bt: Variant = m.get("battle")
	if bt != null:
		bt._over = true  # no waves, no spawners: just the units we place
	await _run_for(0.5)
	_clear(m)
	await _run_for(0.2)
	var spot := _open_spot(m)
	m.player.position = spot + Vector2(0, 400)  # well out of the way
	if m.blocked.has(m.world_to_cell(m.player.position)):
		m.player.position = spot + Vector2(0, -400)
	# ---- 11-01: striker vs a melee foe ------------------------------------------------
	var h := HelperUnit.make(m, "striker", spot, spot)
	check(h.scale.x < 1.0 or Anim.reduced(), "c16b_11-11: a helper steps out with a scale-in (scale %.2f)" % h.scale.x)
	var foe := m.spawn_enemy("grump", spot + Vector2(36, 0), 0)
	check(foe != null, "a grump to fight")
	if foe:
		foe.hp = 14
		foe.max_hp = 14
		foe._noticed = true
	var hp0 := h.hp
	var hit := false
	var far := 0.0
	var gt := 0.0
	while gt < 12.0 and is_instance_valid(foe) and foe._alive:
		await process_frame
		gt += 1.0 / 60.0
		if is_instance_valid(h) and h.hp < hp0:
			hit = true
		if is_instance_valid(h) and is_instance_valid(foe):
			far = maxf(far, h.position.distance_to(foe.position))
	check(hit, "c16b_11-01: the melee foe lands at least one hit on the striker (hp %d -> %d)" % [hp0, h.hp if is_instance_valid(h) else 0])
	check(not is_instance_valid(foe) or not foe._alive, "c16b_11-01: the striker still beats it within 12 s (%.1f s)" % gt)
	check(far < 80.0, "c16b_11-01: no kiting away across the field (max gap %.0f px)" % far)
	_clear(m)
	await _run_for(0.3)
	# ---- 11-02: a ranged foe shoots a lone turret from range --------------------------
	var it: Dictionary = GameState.items.get("guard_bot", {"life": 60, "dmg": 4, "reach": 90})
	var tur: Node2D = load("res://scripts/battle_turret.gd").make_at(m, spot, it)
	tur.set("dmg", 0)
	tur.set("reach", 0.0)
	var t_hp0 := int(tur.get("hp"))
	var sh := m.spawn_enemy("archer", spot + Vector2(70, 0), 0)
	check(sh != null and sh.abilities.has("ranged"), "an archer (ranged)")
	var min_d := 9999.0
	var dmg_far := false
	var last_hp := t_hp0
	gt = 0.0
	while gt < 10.0 and is_instance_valid(tur) and is_instance_valid(sh):
		await process_frame
		gt += 1.0 / 60.0
		var d := sh.position.distance_to(tur.position)
		min_d = minf(min_d, d)
		var nh := int(tur.get("hp"))
		if nh < last_hp and d > 34.0:
			dmg_far = true
		last_hp = nh
	check(is_instance_valid(tur) and int(tur.get("hp")) < t_hp0 or not is_instance_valid(tur), "c16b_11-02: the ranged foe damages the turret (%d -> %d)" % [t_hp0, int(tur.get("hp")) if is_instance_valid(tur) else 0])
	check(dmg_far, "c16b_11-02: ... from range, > 34 px (closest it came %.0f px)" % min_d)
	_clear(m)
	if is_instance_valid(tur):
		tur.queue_free()
	await _run_for(0.3)
	# ---- 11-12: a quicker team animal covers more ground ------------------------------
	m.player.position = spot
	await _run_for(0.1)
	var slow := HelperUnit.make_team(m, ["animal:test_a", "Slow", "animal"], "striker", spot + Vector2(-6, 0))
	var quick := HelperUnit.make_team(m, ["animal:test_b", "Quick", "animal"], "striker", spot + Vector2(6, 0))
	slow.team_spd = 1.0
	quick.team_spd = 1.3
	var s0 := slow.position
	var q0 := quick.position
	m.player.position = spot + Vector2(0, -300) if not m.blocked.has(m.world_to_cell(spot + Vector2(0, -300))) else spot + Vector2(0, 300)
	await _run_for(2.0)
	var sd := slow.position.distance_to(s0)
	var qd := quick.position.distance_to(q0)
	check(qd > sd + 8.0, "c16b_11-12: speed 1.3 covers more ground than 1.0 in 2 s (%.0f vs %.0f px)" % [qd, sd])
	_clear(m)
	# ---- 11-13: the alert sting is throttled map-wide on a battlefield ----------------
	var e1 := m.spawn_enemy("grump", spot, 0)
	var e2 := m.spawn_enemy("grump", spot + Vector2(10, 0), 0)
	if m.has_meta("alert_ms"):
		m.remove_meta("alert_ms")
	if e1 and e2:
		e1._alert_sting()
		var t1 := int(m.get_meta("alert_ms", -1))
		await _run_for(0.2)
		e2._alert_sting()
		check(t1 >= 0 and int(m.get_meta("alert_ms", -1)) == t1, "c16b_11-13: a second sting within 1.5 s is skipped")
	# ---- 11-15: a point of yours under attack, off screen, gets the red pointer -------
	if bt != null and not bt.points.is_empty():
		var p0: Dictionary = bt.points[0]
		p0["owner"] = "ally"
		p0["prog"] = 0.3
		m.player.position = p0["pos"] + Vector2(0, 300)
		var tp := BattleFx.threat_point(bt)
		check(not tp.is_empty() and tp == p0, "c16b_11-15: a held point losing its hold is flagged for the red pointer")
		p0["prog"] = 1.0
		check(BattleFx.threat_point(bt).is_empty() or BattleFx.threat_point(bt) != p0, "c16b_11-15: a safe point is not")
	# ---- 11-08 / 11-17: units stand down with a fade, the field clears with a beat ----
	var u := HelperUnit.make(m, "striker", spot, spot)
	BattleFx.stand_down(m, u)
	check(is_instance_valid(u) and not u.is_in_group("allies"), "c16b_11-08: a stood-down helper leaves the ally list at once but fades out")
	await _run_for(0.6)
	check(not is_instance_valid(u), "c16b_11-08: ... and is gone within 0.6 s")
	var f1 := m.spawn_enemy("grump", spot + Vector2(30, 0), 0)
	var u2 := HelperUnit.make(m, "striker", spot, spot)
	BattleFx.clear_field(m, true)
	check(m.enemies.is_empty() and is_instance_valid(f1), "c16b_11-17: foes leave the fight at once but stay on screen for the outro")
	await _run_for(BattleFx.OUTRO + 0.3)
	check(not is_instance_valid(f1) and not is_instance_valid(u2), "c16b_11-17: everything is cleared after the outro")
	# ---- 11-14: a live battle's frame cost (14 foes + 12 helpers, following you) ---------
	_clear(m)
	await _run_for(0.3)
	m.player.position = spot
	m.set_meta("follow_me", true)
	for i in 12:
		HelperUnit.make(m, "striker" if i % 3 else "healer", spot + Vector2(randf_range(-30, 30), randf_range(-20, 20)), spot)
	for i in 14:
		var fe := m.spawn_enemy("grump", spot + Vector2.from_angle(TAU * i / 14.0) * 110.0, 0)
		if fe:
			fe.hp = 999
			fe.max_hp = 999
	var tot := 0
	var worst := 0
	var nf := 0
	var last := Time.get_ticks_usec()
	for i in 180:
		m.player.position += Vector2(0.6 if (i / 60) % 2 == 0 else -0.6, 0)
		await process_frame
		var now := Time.get_ticks_usec()
		if i >= 30:  # (first half second: flow fields warm up)
			tot += now - last
			worst = maxi(worst, now - last)
			nf += 1
		last = now
	var avg := tot / 1000.0 / maxf(1.0, nf)
	print("PERF_JSON " + JSON.stringify({"scene": "battle_feel", "battle_ms_avg": snappedf(avg, 0.1), "battle_ms_worst": snappedf(worst / 1000.0, 0.1)}))
	check(avg < 16.0, "c16b_11-14: a 14-foe, 12-helper battle runs under 16 ms a frame headless (avg %.1f ms, worst %.1f ms)" % [avg, worst / 1000.0])
	print("battle_feel_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)

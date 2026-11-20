extends SceneTree
## CONDUCT 8 P5: one speed ladder with caps (MoveSpeed), the Hero tab shows the
## same number, five movement nodes per arc (= the 25% cap), converted nodes do
## their own thing, Haste/Blink Step, maxed trees stop glowing, renown is capped,
## and tap-to-move on a fast mount stops on the tap without bouncing.
##   godot --headless --path . --fixed-fps 60 -s res://tools/move_speed_test.gd
const SkillGlow := preload("res://scripts/skill_glow.gd")
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(5)
	Campaign.bypass = true
	_run.call_deferred()


func _total(mode := "foot", running := false, vs := 1.0) -> float:
	return float(MoveSpeed.calc(null, running, mode, vs)["total"])


func _buy_all(sk: String) -> void:
	var nodes := {}
	for nd: Dictionary in GameState.skills_data[sk]["nodes"]:
		nodes[str(nd["id"])] = int(nd.get("ranks", 1))
	GameState.run["skills"][sk] = {"level": 200, "xp": 0, "nodes": nodes}


func _run() -> void:
	InputSetup.ensure_actions()
	for arc in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi" if arc == "penguins" else "dad", "T", "Town", "Pup")
		var n := 0
		var sum := 0.0
		for sk in GameState.skills_data.keys():
			if not GameState.skill_in_arc(str(sk)):
				continue
			for nd: Dictionary in GameState.skills_data[sk]["nodes"]:
				var v := float((nd.get("effect", {}) as Dictionary).get("move_speed", 0.0))
				if v > 0.0:
					n += 1
					sum += v * int(nd.get("ranks", 1))
		check(n == 5, "%s: five movement nodes (got %d)" % [arc, n])
		check(absf(sum - 0.25) < 0.001, "%s: movement nodes add up to the 25%% cap (got %.2f)" % [arc, sum])

	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	check(absf(_total() - 1.0) < 0.001, "base walk is 100%")
	# Stacked foot bonus is capped at +60%.
	GameState.run["buffs"] = {"speed": {"amount": 10.0, "until": GameState.now_abs() + 600}}
	check(absf(MoveSpeed.foot_bonus() - MoveSpeed.FOOT_CAP) < 0.001, "foot bonus capped at +%d%%" % roundi(MoveSpeed.FOOT_CAP * 100))
	var c := MoveSpeed.calc(null, false)
	check(bool(c["capped"]), "calc says capped")
	GameState.run["flags"]["haste_abs"] = GameState.now_abs() + 60
	check(absf(_total() - MoveSpeed.FOOT_MAX) < 0.001, "haste on top of a full foot bonus clamps at x%.2f (%.2f)" % [MoveSpeed.FOOT_MAX, _total()])
	check(absf(_total("mount", true) - MoveSpeed.RIDE_MAX) < 0.001, "galloping with everything clamps at x%.1f (%.2f)" % [MoveSpeed.RIDE_MAX, _total("mount", true)])
	check(absf(_total("vehicle", true, 2.3) - MoveSpeed.VEH_MAX) < 0.001, "getaway car with everything clamps at x%.1f" % MoveSpeed.VEH_MAX)
	GameState.run["buffs"] = {}
	GameState.run["flags"].erase("haste_abs")
	check(absf(_total("mount", true) - MoveSpeed.MOUNT_RUN) < 0.001, "plain gallop x%.1f" % MoveSpeed.MOUNT_RUN)
	check(absf(_total("swim") - MoveSpeed.SWIM) < 0.001, "plain swim x%.2f" % MoveSpeed.SWIM)
	# Converted nodes: Strong Strokes swims faster, Smooth Ride rides faster, Blink Step stretches Haste.
	GameState.run["skills"]["fishing"] = {"level": 30, "xp": 0, "nodes": {"fishing_u_strong_strokes": 1}}
	await process_frame  # GameState.bonus caches per frame
	await process_frame
	check(_total("swim") > MoveSpeed.SWIM * 1.25, "Strong Strokes: swim faster (%.2f)" % _total("swim"))
	GameState.run["skills"]["building"] = {"level": 30, "xp": 0, "nodes": {"building_u_light_feet": 1}}
	await process_frame  # GameState.bonus caches per frame
	await process_frame
	check(absf(_total("mount", true) - MoveSpeed.MOUNT_RUN * 1.1) < 0.001, "Smooth Ride: +10% on the horse")
	var h0 := Spells.haste_secs()
	GameState.run["skills"]["magic"] = {"level": 30, "xp": 0, "nodes": {"magic_u_blink_step": 1}}
	await process_frame  # GameState.bonus caches per frame
	await process_frame
	check(absf(Spells.haste_secs() - h0 * 1.5) < 0.01, "Blink Step: Haste lasts half as long again (%.0f s)" % Spells.haste_secs())
	check(not str(Spells.SPELLS["haste"]["desc"]).contains("hour"), "Haste text no longer promises an hour")
	# Hero tab speed card shows the same number the hero moves by.
	GameState.run["buffs"] = {"speed": {"amount": 1.0, "until": GameState.now_abs() + 600}}
	var card := {}
	for s: Dictionary in CharSheet.stats():
		if str(s.get("id", "")) == "speed":
			card = s
	check(not card.is_empty() and str(card["value"]) == "%d%%" % roundi(_total() * 100), "Hero tab speed %s = moves at %d%%" % [card.get("value", "?"), roundi(_total() * 100)])
	# A fully bought tree stops glowing even with points left over.
	_buy_all("farming")
	var raw := GameState.skill_level("farming") - 1 - GameState.points_spent("farming")  # points_free is capped by ranks_left since C8 P1
	check(raw > 0 and GameState.points_free("farming") == 0, "maxed farming still has raw points (%d), none to spend" % raw)
	check(SkillGlow.usable("farming") == 0, "maxed tree: no glow, no 'points to spend'")
	# Renown: one runaway skill no longer makes you a Legend.
	var rn := CharSheet.renown()
	check(rn <= CharSheet.RENOWN_SKILL_CAP + 40, "renown with farming lv 200 stays modest (%d)" % rn)
	GameState.run["skills"] = {}
	GameState.run["buffs"] = {}

	# Tap-to-move on a galloping, buffed horse: no overshoot, no bounce.
	change_scene_to_file("res://scenes/farm.tscn")
	for i in 40:
		await process_frame
	var m := current_scene as GameMap
	var p := m.player
	GameState.run["buffs"] = {"speed": {"amount": 4.0, "until": GameState.now_abs() + 600}}
	p.mounted = true
	# Start from an open stretch of the farm (a cell with 12 free cells each way).
	var open_at := Vector2.INF
	for y in range(8, 40):
		for x in range(8, 40):
			var cc := m.cell_center(Vector2i(x, y))
			var hb := Rect2(cc - Vector2(5, 3), Vector2(10, 6))
			var ok := true
			for k in range(-12, 13):
				if m.rect_blocked(Rect2(hb.position + Vector2(k * 16, 0), hb.size)) or m.rect_blocked(Rect2(hb.position + Vector2(0, k * 16), hb.size)):
					ok = false
					break
			if ok:
				open_at = cc
				break
		if open_at != Vector2.INF:
			break
	check(open_at != Vector2.INF, "found an open stretch on the farm")
	p.position = open_at
	var best := 999.0
	var tried := 0
	for dirv in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var start := p.position
		var goal: Vector2 = start + dirv * 160.0
		p.velocity = Vector2.ZERO
		p.auto_target = goal
		var past := 0.0
		var flips := 0
		var last_sign := 1.0
		var gt := 0.0
		while gt < 4.0:
			await physics_frame
			gt += 1.0 / 60.0
			var along := (p.position - start).dot(dirv)
			past = maxf(past, along - 160.0)
			var sg := signf(p.velocity.dot(dirv))
			if sg != 0.0 and sg != last_sign:
				flips += 1
				last_sign = sg
			if p.auto_target == Vector2.INF and p.velocity.length() < 1.0:
				break
		var reached := (p.position - start).dot(dirv) > 150.0
		print("    dir %s: went %.0f px, past %.1f, flips %d, busy %s, dlg %s" % [dirv, (p.position - start).dot(dirv), past, flips, p._busy, Dialogue.instance(self).active])
		if reached:
			tried += 1
			best = minf(best, past)
			check(past < 10.0 and flips == 0, "tap-to-move %s: overshoot %.1f px, %d reversals" % [dirv, past, flips])
		p.position = start
	check(tried > 0, "tap-to-move: at least one open direction tested (%d)" % tried)
	print("move_speed_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)

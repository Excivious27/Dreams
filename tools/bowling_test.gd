extends SceneTree
## Bowling feel (CONDUCT 2): pocket hits strike most of the time and miss-hits don't,
## the aim preview matches the real roll, villagers bowl to their skill (Tobin low,
## Maple high), split names, the release bar, and a whole versus game played by the
## screen's own bot (pinsetter sweep, villager frames, result + ticket bonus).
##   godot --headless --path . -s res://tools/bowling_test.gd [-- -v]
var fails := 0
var verbose := false


func ok(c: bool, what: String) -> void:
	if c:
		if verbose:
			print("  ok  ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _press(p: Vector2, down: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = p
	e.pressed = down
	return e


func _initialize() -> void:
	verbose = "-v" in OS.get_cmdline_user_args()
	InputSetup.ensure_actions()
	_run.call_deferred()


func _run() -> void:
	# --- the preview is the truth: a no-noise throw crosses the head-pin line where entry_x says ---
	var spd := 230.0 + 140.0 * 0.78
	for spin in [0.0, 0.66, 1.0]:
		var a := Bowling.Sim.aim_for(Bowling.POCKET, 6.0, spd, spin)
		var ex := Bowling.Sim.entry_x(6.0, a, spd, spin)
		ok(absf(ex - Bowling.POCKET) < 0.2, "aim_for finds the pocket (spin %.2f: %.2f)" % [spin, ex])
		var s := Bowling.Sim.new()
		s.aim_noise = 0.0
		s.rack()
		s.throw(6.0, a, spd, spin)
		var cross := INF
		for k in 3000:
			s.step(Bowling.Sim.DT)
			if s.ball_p.y >= Bowling.Sim.HEAD_Y - Bowling.Sim.BALL_R - Bowling.Sim.PIN_R - 1.0:
				cross = s.ball_p.x
				break
		ok(absf(cross - ex) < 1.5, "the roll follows the preview (%.2f vs %.2f)" % [cross, ex])

	# --- strike window: pocket hits carry, light/heavy hits mostly don't ---
	var rate := {}
	for off in [0.0, 1.0, -2.0, 5.0]:
		var st := 0
		var pins := 0
		for i in 24:
			var s2 := Bowling.Sim.new()
			s2.rng.seed = 300 + i
			s2.aim_noise = 0.03
			s2.rack()
			var sp := 1.0 if i % 2 == 0 else 0.66
			var a2 := Bowling.Sim.aim_for(Bowling.POCKET + off, 6.0, spd, sp)
			var n := s2.run_throw(6.0, a2, spd, sp)
			pins += n
			if n == 10:
				st += 1
		rate[off] = st
		print("  entry %+.1f in: %d/24 strikes, %.1f pins" % [Bowling.POCKET + off, st, pins / 24.0])
	ok(int(rate[0.0]) >= 14 and int(rate[0.0]) <= 23, "pocket strikes often, not always (%d/24)" % int(rate[0.0]))
	ok(int(rate[5.0]) <= 4 and int(rate[-2.0]) < int(rate[0.0]) and int(rate[1.0]) >= 6, "the window falls off gently: near misses still strike sometimes, wide ones rarely")

	# --- release bar ---
	ok(Bowling.release_noise(0.78) < 0.05 and Bowling.release_noise(0.2) > 0.4, "gold band is clean, a weak release wanders")

	# --- splits ---
	ok(Bowling.split_name([6, 9]) == "7-10 split", "7-10 split named")
	ok(Bowling.split_name([3, 9]) == "4-10 split" and Bowling.split_name([1, 3]) == "", "4-10 is a split; 2-4 isn't")
	ok(Bowling.split_name([0, 6, 9]) == "", "head pin up: not a split")

	# --- villagers bowl to their skill ---
	var avg := {}
	for id in ["tobin", "finn", "maple"]:
		var o := Bowling.opponent(id)
		var tot := 0
		for g in 5:
			var sim := Bowling.Sim.new()
			sim.rng.seed = 900 + g * 7 + hash(id) % 100
			var rs: Array = []
			var guard := 0
			while not bool(Bowling.next_state(rs)["over"]) and guard < 12:
				Bowling.bowl_frame(sim, rs, float(o["skill"]), int(o["spin"]))
				guard += 1
			ok(bool(Bowling.next_state(rs)["over"]), "%s finishes a line" % id)
			tot += Bowling.score_of(rs)
		avg[id] = tot / 5.0
		print("  %s averages %.0f" % [id, avg[id]])
	ok(float(avg["tobin"]) < float(avg["finn"]) and float(avg["finn"]) < float(avg["maple"]), "skill order Tobin < Finn < Maple")
	ok(float(avg["tobin"]) >= 40.0 and float(avg["tobin"]) <= 125.0, "Tobin is beatable (%.0f)" % avg["tobin"])
	ok(float(avg["maple"]) >= 150.0, "Maple is a real champion (%.0f)" % avg["maple"])

	# --- phone input: drag lines up, a still tap is GO, spin buttons ---
	GameState.new_run("penguins", "kairi", "Kairi", "Town", "Pup")
	GameState.run["intro_done"] = true
	var holder := Node.new()
	root.add_child(holder)
	var tb := Bowling.new()
	tb.manual = true
	holder.add_child(tb)
	for k in 10:
		tb.tick(1.0 / 30.0)
	var x_before := tb.x0
	tb._tap(_press(Vector2(135, 300), true))
	var mv := InputEventMouseMotion.new()
	mv.position = Vector2(102, 300)
	tb._tap(mv)
	tb._tap(_press(Vector2(102, 300), false))
	tb.tick(1.0 / 30.0)
	ok(tb.phase == "line" and tb.x0 < x_before - 5.0, "dragging left moves the ball (%.1f -> %.1f), no throw" % [x_before, tb.x0])
	var sp0 := tb.spin_step
	tb._tap(_press(Bowling.BTN_SPIN_L.get_center(), true))
	tb._tap(_press(Bowling.BTN_SPIN_L.get_center(), false))
	ok(tb.spin_step == sp0 + 1, "the left spin button adds hook to the left")
	tb._tap(_press(Vector2(135, 300), true))
	tb._tap(_press(Vector2(135, 300), false))
	tb.tick(1.0 / 30.0)
	ok(tb.phase == "aim", "a still tap on the lane is GO")
	tb._tap(_press(Vector2(135, 300), true))
	tb.tick(1.0 / 30.0)
	ok(tb.phase == "power", "a tap locks the aim")
	ok(tb.power < 0.1, "the power bar starts empty")
	tb._finish()

	# --- a whole versus game on the real screen, played by its bot ---
	var b := Bowling.new()
	b.lane = 2
	b.opp_id = "gideon"
	b.manual = true
	b.bot = 0.9
	holder.add_child(b)
	var phases := {}
	var n2 := 0
	while b.phase != "over" and n2 < 60000:
		b.tick(1.0 / 30.0)
		phases[b.phase] = true
		n2 += 1
	ok(b.phase == "over", "bot game reaches the end (%d ticks)" % n2)
	for ph in ["line", "aim", "power", "roll", "result", "sweep", "opp"]:
		ok(phases.has(ph), "phase seen: " + ph)
	var res := b.result
	ok(bool(Bowling.next_state(res.get("rolls", []))["over"]), "player line complete")
	ok(bool(Bowling.next_state(b.opp_rolls)["over"]), "Gideon's line complete")
	ok(int(res.get("opp_score", -1)) == Bowling.score_of(b.opp_rolls) and res.get("opponent") == "gideon", "result carries Gideon's score")
	print("  bot game: you %d vs Gideon %d" % [int(res.get("score", 0)), int(res.get("opp_score", 0))])
	ok(int(res.get("score", 0)) >= 90, "a skilled bot bowls a decent game (%d)" % int(res.get("score", 0)))
	var t0 := Tickets.count()
	var won := bool(res.get("won", false))
	var got := RecCenter.finish_game(null, res)
	ok(got == Tickets.payout("bowling", RecCenter.tickets_for(int(res["score"]), int(res["strikes"]), int(res["spares"])) + int(res.get("bonus", 0))) and Tickets.count() == t0 + got, "tickets include the versus bonus, through the bowling payout cap")
	ok(got <= int((Tickets.prizes().get("payout", {}) as Dictionary).get("bowling", {}).get("cap", 999)), "never past the bowling cap (%d)" % got)
	# One villager system: friendship once a day per villager, from the same finish_game.
	var f1 := int(GameState.run["friendship"].get("gideon", 0))
	RecCenter.finish_game(null, res)
	ok(int(GameState.run["friendship"].get("gideon", 0)) == f1, "friendship from a game with Gideon once a day")
	var line := RecCenter.together_result("gideon", 150, 120)
	ok(str(line[0]["text"]).contains("150") and str(line[0]["text"]).contains("120"), "the after-game line names both scores")
	# Strength comes from the one table (gen_rec BOWL_AVG) through SKILL_AVG.
	ok(int(Bowling.opponent("maple")["avg"]) == RecCenter.bowl_avg("maple") and Bowling.opponent("maple")["skill"] > Bowling.opponent("tobin")["skill"], "opponent strength from BOWL_AVG")
	ok(won == (int(res.get("bonus", 0)) == int(Bowling.opponent("gideon")["bonus"])), "bonus only for a win")
	b._finish()
	print("bowling_test: %s" % ("OK" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)

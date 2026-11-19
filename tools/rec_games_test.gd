extends SceneTree
## Rec chance games (c2_04): Skee-Ball scoring rule and a full scripted game,
## the claw's grip curve / pity / win text, Duck Pond payout, the snack bar menu.
##   godot --headless --path . -s res://tools/rec_games_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	_run.call_deferred()


func _open(id: String) -> ArcadeGame:
	var g := ArcadeHub.make(id)
	g.manual = true
	root.add_child(g)
	return g


func _frames(g: ArcadeGame, n: int, input := {}) -> void:
	for i in n:
		if not is_instance_valid(g) or not g.is_inside_tree():
			return
		g.bot = input
		g.frame()


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["crystals"] = 5000
	await process_frame

	# --- Skee-Ball: the scoring rule ------------------------------------------
	check(int(ArcadeSkee.zone_at(Vector2(512, 268))[0]) == 50, "centre cup pays 50")
	check(int(ArcadeSkee.zone_at(Vector2(304, 181))[0]) == 100 and int(ArcadeSkee.zone_at(Vector2(720, 181))[0]) == 100, "corner cups pay 100")
	check(int(ArcadeSkee.zone_at(Vector2(512, 400))[0]) == 30, "inner ring pays 30")
	check(int(ArcadeSkee.zone_at(Vector2(512, 500))[0]) == 20, "outer ring pays 20")
	check(int(ArcadeSkee.zone_at(Vector2(260, 540))[0]) == 10, "bare board pays 10")
	check(int(ArcadeSkee.zone_at(Vector2(512, 60))[0]) == 10, "the net pays 10")
	check(int(ArcadeSkee.zone_at(ArcadeSkee.landing(0.0, 0.05))[0]) == 0, "a feeble roll dies on the ramp")
	check(int(ArcadeSkee.zone_at(ArcadeSkee.landing(0.0, ArcadeSkee.p_for(268)))[0]) == 50, "p_for(cup) on the centre line lands in the cup")
	check(absf(ArcadeSkee.landing(0.0, ArcadeSkee.p_for(300)).y - 300.0) < 0.5, "p_for inverts landing")
	# Every scoring zone is on the board the art shows (inside the blue panel).
	for z: Array in ArcadeSkee.ZONES:
		var ctr: Vector2 = z[1]
		check(ctr.y > ArcadeSkee.BOARD_TOP and ctr.y < ArcadeSkee.BOARD_BOT, "zone %d sits on the board" % int(z[0]))

	# --- Skee-Ball: a whole game with the real buttons ------------------------
	var tickets0 := Tickets.count()
	var money0 := ArcadeHub.money()
	var sk := _open("skee_ball") as ArcadeSkee
	sk.rng.seed = 4
	_frames(sk, 8)
	_frames(sk, 1, {"a": true})
	_frames(sk, 1)
	check(sk.state == "play" and ArcadeHub.money() == money0 - ArcadeSkee.FEE, "skee starts and charges the fee")
	_frames(sk, 30, {"left": true})
	check(sk.u < -0.2, "◀ moves the line")
	_frames(sk, 30, {"right": true})
	var rolled := 0
	for i in 60 * 90:
		if sk.state != "play":
			break
		if sk.phase == "aim":
			# Hold ROLL until the meter is near the cup's power, then let go.
			var want := ArcadeSkee.p_for(268)
			var guard := 0
			_frames(sk, 1, {"a": true})
			while sk.charging and absf(sk.power - want) > 0.03 and guard < 200:
				_frames(sk, 1, {"a": true})
				guard += 1
			_frames(sk, 1)
			rolled += 1
		_frames(sk, 1)
	check(rolled == ArcadeSkee.BALLS, "nine balls rolled (%d)" % rolled)
	check(sk.state == "over" and sk.history.size() == ArcadeSkee.BALLS, "skee game ends after nine balls")
	check(sk.score >= 200, "aimed rolls at the cup score (%d)" % sk.score)
	check(Tickets.count() > tickets0 and Tickets.best_score("skee_ball") == sk.score, "skee pays tickets and records the best")
	check(Tickets.plays("skee_ball") == 1, "skee play counted")
	sk.close()
	# A tap on the lane sets the line.
	var sk2 := _open("skee_ball") as ArcadeSkee
	_frames(sk2, 8)
	_frames(sk2, 1, {"a": true})
	_frames(sk2, 1)
	sk2._tap(Vector2(230, 320))
	check(sk2.u > 0.5, "tapping the lane right moves the line right (%.2f)" % sk2.u)
	_frames(sk2, 2, {"b": true})
	check(sk2.state == "over", "B ends a skee game")
	sk2.close()
	check(ArcadeHub.make_info("skee_ball")["fee"] == ArcadeSkee.FEE, "skee fee in the hub")

	# --- Claw: grip curve, pity, win text ---------------------------------------
	var g0 := ArcadeClaw.grip_for(0.0, 11.0, 1.0, 0.0, 0)
	var g2 := ArcadeClaw.grip_for(2.0, 11.0, 1.0, 0.0, 0)
	var g5 := ArcadeClaw.grip_for(5.0, 11.0, 1.0, 0.0, 0)
	check(g0 > g2 and g2 > g5 and g0 > 0.9, "centring sets the grip (%.2f %.2f %.2f)" % [g0, g2, g5])
	check(ArcadeClaw.slip_rate(g0) < 0.02 and ArcadeClaw.slip_rate(g5) > 0.25, "slip rate follows the grip")
	check(ArcadeClaw.grip_for(5.0, 11.0, 1.0, 0.0, 8) > g5, "a long dry run firms the grip")
	check(ArcadeClaw.grip_for(5.0, 11.0, 1.0, 2.0, 0) > g5, "luck firms the grip")
	check(ArcadeClaw.grip_for(20.0, 11.0, 1.0, 3.0, 9) == 0.0, "no pity for a claw that missed the plush")
	check(ArcadeClaw.grip_for(0.0, 11.0, 0.45, 0.0, 0) < g0 * 0.5, "wins today loosen the machine")
	var cl := _open("claw") as ArcadeClaw
	_frames(cl, 8)
	_frames(cl, 1, {"a": true})
	_frames(cl, 1)
	ArcadeClaw.pile[0]["item"] = "candy"
	ArcadeClaw.pile[0]["look"] = "bear"
	cl._win(0)
	var txt := " ".join(cl.over_lines)
	check(txt.contains("Candy") and not txt.contains("(bear plush)"), "claw win names the prize, no '(bear plush)' tag: " + txt)
	check(ArcadeClaw.dry_streak() == 0, "a win resets the dry run")
	cl.close()
	var cl2 := _open("claw") as ArcadeClaw
	_frames(cl2, 8)
	_frames(cl2, 1, {"a": true})
	_frames(cl2, 1)
	ArcadeClaw.pile[0]["item"] = "rp_teddy"
	cl2._win(0)
	check(" ".join(cl2.over_lines).contains("Teddy Bear") and not " ".join(cl2.over_lines).contains("Tucked"), "a plush prize is just the plush")
	cl2.close()
	var cl3 := _open("claw") as ArcadeClaw
	_frames(cl3, 8)
	_frames(cl3, 1, {"a": true})
	_frames(cl3, 1)
	cl3._lose()
	check(ArcadeClaw.dry_streak() == 1, "a loss adds to the dry run")
	cl3.close()

	# --- Duck Pond payout ------------------------------------------------------
	var gl := ArcadeGallery.new()
	check(gl._tickets_for(500) == 20 and gl._tickets_for(1000) == 40, "duck pond pays score/25")
	gl.free()

	# --- Snack bar -------------------------------------------------------------
	var menu := RecCenter.snack_menu()
	check(menu.size() == 4, "four snacks on the menu")
	for s: Array in menu:
		var id := str(s[0])
		check(GameState.items.has(id) and Art.has("items", str(GameState.items[id].get("icon", ""))), "snack %s has its icon" % id)
		check(GameState.item_value(id) < int(s[1]), "snack %s sells for less than it costs" % id)
	var c0 := int(GameState.run["crystals"])
	var n0 := GameState.count("rp_popcorn")
	check(RecCenter.buy_snack(null, 0) and GameState.count("rp_popcorn") == n0 + 1 and int(GameState.run["crystals"]) == c0 - int(menu[0][1]), "buying popcorn")
	GameState.run["crystals"] = 3
	check(not RecCenter.buy_snack(null, 1), "no pretzel without the money")
	check(GameState.items["rp_popcorn"].get("buff", {}).get("kind", "") == "luck", "popcorn is the lucky snack")

	print("rec_games_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

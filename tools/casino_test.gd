extends SceneTree
## The Gilded Ace (C10b P4): odds from data/casino.json match the rules (exact for
## slots/roulette/dice), stacked-deck blackjack/poker payouts, purse round trips,
## limits (keep floor, loss limit, hands cap, break lock, heat refusal, hours),
## outcome stream determinism, luck-independence (source grep), every table plays a
## hand through its screen (title -> bet -> reveal -> result -> B closes) with tap
## targets >= 20 px, and the region door/odds things exist on Casino Row.
##   godot --headless --path . --fixed-fps 60 -s res://tools/casino_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(7)
	_run.call_deferred()


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("gangsters", "kairi", "T", "Town", "Pup")
	Casino.skip_save = true
	GameState.run["crystals"] = 5000
	GameState.run["time"] = 20 * 60
	_odds()
	_rules()
	_money()
	_limits()
	_stream()
	_no_luck()
	_tables()
	_region()
	print("casino_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


func _odds() -> void:
	var d := Casino.data()
	check(not d.is_empty(), "data/casino.json loads")
	# Slots: enumerate every stop combination with the game's own rule.
	var st := CasinoRules.strips()
	var tot := 0.0
	var n := 0
	for a in st[0]:
		for b in st[1]:
			for c in st[2]:
				tot += CasinoRules.slot_pay(str(a), str(b), str(c))
				n += 1
	var srtp := tot / n
	check(absf(srtp - float(d["rtp"]["slots"])) < 0.001, "slots RTP %.4f matches json %.4f" % [srtp, float(d["rtp"]["slots"])])
	check(srtp < 0.99, "slots RTP < 0.99")
	for bet in d["roulette"]["bets"]:
		var g := 0
		for p in 37:
			g += CasinoRules.roulette_pays(str(bet), p, 17)
		check(absf(g / 37.0 - float(d["rtp"]["roulette"][bet])) < 0.001 and g / 37.0 < 0.99, "roulette %s RTP %.4f" % [bet, g / 37.0])
	for bet in ["small", "big"]:
		var w := 0
		for x in range(1, 7):
			for y in range(1, 7):
				for z in range(1, 7):
					w += 1 if CasinoRules.dice_wins(bet, [x, y, z]) else 0
		check(absf(2.0 * w / 216.0 - float(d["rtp"]["dice"][bet])) < 0.001, "dice %s RTP" % bet)
	check(float(d["rtp"]["blackjack"]) + 2.0 * float(d["rtp"]["blackjack_sd"]) < 0.99, "blackjack RTP bound < 0.99")
	check(float(d["rtp"]["poker"]) < 0.99, "poker RTP < 0.99")


func _rules() -> void:
	# Blackjack (per 1 staked, gross).
	check(is_equal_approx(CasinoRules.bj_settle([1, 13], [10, 7]), 2.2), "natural pays 6:5")
	check(is_equal_approx(CasinoRules.bj_settle([1, 13], [1, 12]), 1.0), "two naturals push")
	check(is_equal_approx(CasinoRules.bj_settle([10, 9], [1, 10]), 0.0), "dealer natural wins")
	check(is_equal_approx(CasinoRules.bj_settle([5, 6, 10], [10, 8], true), 4.0), "doubled 21 v 18 returns 4x")
	check(is_equal_approx(CasinoRules.bj_settle([10, 6, 9], [10, 7]), 0.0), "bust loses even if dealer would bust")
	check(is_equal_approx(CasinoRules.bj_settle([10, 7], [10, 6, 9]), 2.0), "dealer bust pays even money")
	check(is_equal_approx(CasinoRules.bj_settle([10, 8], [9, 9]), 1.0), "18 v 18 push")
	check(CasinoRules.bj_total([1, 6]) == [17, true], "A6 = soft 17")
	check(not CasinoRules.dealer_should_hit([1, 6]), "dealer stands on soft 17")
	check(CasinoRules.bj_total([1, 1, 9]) == [21, true], "AA9 = soft 21")
	# Poker.
	check(CasinoRules.poker_rank([[10, 0], [11, 0], [12, 0], [13, 0], [14, 0]]) == "royal", "royal flush")
	check(CasinoRules.poker_rank([[14, 1], [2, 0], [3, 2], [4, 3], [5, 0]]) == "straight", "A-5 straight")
	check(CasinoRules.poker_rank([[11, 1], [11, 0], [3, 2], [4, 3], [9, 0]]) == "jacks", "pair of jacks pays")
	check(CasinoRules.poker_rank([[10, 1], [10, 0], [3, 2], [4, 3], [9, 0]]) == "", "pair of tens pays nothing")
	check(CasinoRules.poker_rank([[9, 1], [9, 0], [9, 2], [4, 3], [4, 0]]) == "full_house", "full house")
	check(CasinoRules.poker_pays([[9, 1], [9, 0], [9, 2], [4, 3], [4, 0]]) == 8, "full house pays 8 (8/5)")
	# Roulette.
	check(CasinoRules.roulette_pays("red", 0) == 0 and CasinoRules.roulette_pays("dozen2", 13) == 3 and CasinoRules.roulette_pays("single", 17, 17) == 36, "roulette pays")
	# Slots: no paying line under 2x.
	check(CasinoRules.slot_pay("cherry", "bell", "bar") == 2 and CasinoRules.slot_pay("bell", "cherry", "cherry") == 0, "cherry pays leftmost only")


func _money() -> void:
	GameState.run["crystals"] = 1000
	GameState.run.erase("casino")
	var p0 := Casino.purse()
	check(Casino.take(20, "slots"), "take 20")
	check(Casino.purse() == p0 - 20, "stake left the purse")
	var net := Casino.settle("slots", 20, 20)
	check(net == 0 and Casino.purse() == p0, "push gives it back exactly")
	Casino.take(20, "slots")
	net = Casino.settle("slots", 20, 60)
	check(net == 40 and Casino.purse() == p0 + 40, "win pays gross")
	check(int(Casino.today()["won"]) == 40 and int(Casino.today()["hands"]) == 2, "ledger counts")
	var et := int(GameState.run.get("earned_total", 0))
	Casino.leave()
	check(int(GameState.run.get("earned_total", 0)) == et + 40, "a winning visit counts its net once on the way out")
	Casino.leave()
	check(int(GameState.run.get("earned_total", 0)) == et + 40, "never twice")
	# Practice hands touch nothing.
	var p1 := Casino.purse()
	Casino.take(50, "slots", true)
	Casino.settle("slots", 50, 0, null, true)
	check(Casino.purse() == p1, "practice hand is free")
	# The clock moves a little per hand, never past bedtime.
	GameState.run["time"] = GameState.DAY_END - 16
	Casino.take(10, "slots")
	Casino.settle("slots", 10, 0)
	check(int(GameState.run["time"]) <= GameState.DAY_END - 15, "hands never push the clock to a faint")
	GameState.run["time"] = 20 * 60


func _limits() -> void:
	GameState.run.erase("casino")
	GameState.run["crystals"] = Casino.keep() + 5
	check(Casino.why_no_bet(10) != "", "the purse floor keeps money for the road")
	GameState.run["crystals"] = 100000
	check(Casino.why_no_bet(10) == "", "a fine bet is fine")
	check(Casino.why_no_bet(Casino.max_bet() + 10) != "", "over the table max refused")
	check(Casino.why_no_bet(15) != "", "off-step bet refused")
	# Loss limit.
	Casino._st()["loss_limit"] = 200
	for i in 30:
		if Casino.why_no_bet(10) != "":
			break
		Casino.take(10, "roulette")
		Casino.settle("roulette", 10, 0)
	check(Casino.net_loss_today() == 200, "loss limit stops at exactly the limit (lost %d)" % Casino.net_loss_today())
	check(Casino.why_no_bet(10) == Casino.line("loss_stop"), "loss stop reason")
	check(Casino.max_stake() == 0, "no stake left today")
	# Tomorrow it resets.
	GameState.run["day"] = int(GameState.run["day"]) + 1
	check(Casino.why_no_bet(10) == "", "a new day, a new limit")
	# Hands cap.
	Casino._st()["loss_limit"] = 0
	Casino.today()["hands"] = int(Casino.lim("hands_cap"))
	check(Casino.why_no_bet(10) == Casino.line("hands_cap"), "hands cap")
	# Cold streak words and the reality check.
	GameState.run["day"] = int(GameState.run["day"]) + 1
	Casino._st()["cold"] = 0
	for i in 5:
		Casino.take(10, "dice")
		Casino.settle("dice", 10, 0)
	check(Casino.after_hand_note() == Casino.line("cold_1"), "kind words after 5 losses")
	# Break lock and doors.
	check(Casino.why_shut() == "", "open at 8pm")
	Casino.take_break()
	check(Casino.why_shut().begins_with("You asked the house"), "break lock shuts the floor")
	GameState.run["day"] = int(GameState.run["day"]) + 7
	check(Casino.why_shut() == "", "break ends")
	GameState.run["time"] = 12 * 60
	check(Casino.why_shut() == Casino.line("doorman_closed"), "closed at noon")
	GameState.run["time"] = 20 * 60
	Racket.set_heat(3)
	check(Casino.why_shut() == Casino.line("doorman_heat"), "heat 3 turns you away")
	Racket.set_heat(0)
	# Big net day: +1 heat once.
	GameState.run["day"] = int(GameState.run["day"]) + 1
	var big := Casino.max_bet() * (int(Casino.lim("big_win_x")) + 1)
	Casino.take(10, "slots")
	Casino.settle("slots", 10, 10 + big)
	check(Racket.heat() == 1, "big win day adds heat (heat %d)" % Racket.heat())
	Casino.take(10, "slots")
	Casino.settle("slots", 10, 20)
	check(Racket.heat() == 1, "only once a day")
	Racket.set_heat(0)


func _stream() -> void:
	Casino._st()["hand_no"] = 5
	var a := Casino.rng_for("roulette", "red|10").randi()
	var b := Casino.rng_for("roulette", "red|10").randi()
	check(a == b, "same hand, same bet: same outcome (reload can't re-roll)")
	var c := Casino.rng_for("roulette", "black|10").randi()
	check(a != c, "a different bet draws a different outcome (no peeking)")


func _no_luck() -> void:
	var bad := ["gear_stat(", "buff(", "luck_eff", "ArcadeSkee", "Difficulty.", ".bonus(", "Perks."]
	for f in ["casino", "casino_rules", "casino_game", "casino_slots", "casino_roulette", "casino_dice", "casino_blackjack", "casino_poker"]:
		var src := FileAccess.get_file_as_string("res://scripts/%s.gd" % f)
		for ln in src.split("\n"):
			var code := ln.split("#")[0]
			for w in bad:
				if code.contains(w):
					check(false, "%s.gd reads %s: casino odds must never touch luck/perks" % [f, w])


func _frames(g: CasinoGame, n: int, input := {}) -> void:
	for i in n:
		if not is_instance_valid(g) or not g.is_inside_tree() or g.is_queued_for_deletion():
			return
		g.bot = input
		g.t += 1.0 / 60.0
		g.frame()


func _tap(g: CasinoGame, a: String) -> void:
	_frames(g, 1, {a: true})
	_frames(g, 1, {"_": false})


func _tables() -> void:
	GameState.run["day"] = int(GameState.run["day"]) + 1
	GameState.run["crystals"] = 5000
	Casino._st()["loss_limit"] = 0
	for id in ["slots", "roulette", "blackjack", "dice", "poker"]:
		var g := Casino.make(id)
		check(g != null, "%s table exists" % id)
		g.manual = true
		root.add_child(g)
		_frames(g, 8)
		check(g.state == "title" and g.practice, "%s opens on its how-to with a practice hand" % id)
		_tap(g, "a")
		check(g.state == "bet", "%s: A sits down" % id)
		var p0 := Casino.purse()
		_tap(g, "a")  # practice hand
		for k in 400:
			if g.state == "result":
				break
			_frames(g, 1, {"a": true} if g.state == "play" and k % 2 == 0 else {"_": false})
		check(g.state == "result", "%s: practice hand resolves (state %s)" % [id, g.state])
		check(Casino.purse() == p0, "%s: practice hand is free" % id)
		_frames(g, 30)
		_tap(g, "a")
		check(g.state == "bet", "%s: A bets again" % id)
		_tap(g, "right")
		check(g.stake == Casino.min_bet() + Casino.step(), "%s: RIGHT raises the bet" % id)
		var before := Casino.purse()
		var hands := int(Casino.today().get("hands", 0))
		_tap(g, "a")
		check(Casino.purse() == before - g.stake or g.state == "result", "%s: stake taken on the deal" % id)
		# B mid-hand finishes the hand, then leaves.
		_frames(g, 1, {"b": true})
		for k in 300:
			if g.is_queued_for_deletion():
				break
			_frames(g, 1, {"_": false})
		check(g.is_queued_for_deletion(), "%s: B mid-hand settles and closes (state %s)" % [id, g.state])
		check(int(Casino.today().get("hands", 0)) == hands + 1, "%s: that hand was settled, never dropped" % id)
		var g2 := Casino.make(id)
		for r: Rect2 in g2.hit_rects():
			check(r.size.x >= 20 and r.size.y >= 20, "%s tap target %s >= 20 px" % [id, r])
		for b: Dictionary in g2._deck_buttons():
			var r2: Rect2 = b["rect"]
			check(r2.size.x >= 20 and r2.size.y >= 20 and r2.end.y <= 480 and r2.end.x <= 270, "%s deck button %s fits" % [id, b["action"]])
		g2.free()


func _region() -> void:
	var f := FileAccess.get_file_as_string("res://data/regions.json")
	var r: Dictionary = (JSON.parse_string(f) as Dictionary).get("gilt_casino_row", {})
	var types := {}
	for t: Dictionary in r.get("things", []):
		types[str(t["type"])] = true
	check(types.has("casino"), "Casino Row has the casino door")
	check(types.has("casino_odds"), "Casino Row has the odds board")
	check(Casino.odds_board().contains("Roulette $2.70"), "odds board posts the roulette edge")

extends SceneTree
## Odds/payout survey for the rec's chance games (claw, duck pond, skee-ball):
## plays many scripted rounds with a human-like aim error and prints win rates,
## score spread and tickets per crystal. Dev tool, not in check.sh.
##   godot --headless --path . -s res://tools/rec_odds.gd -- [rounds]
var rounds := 200


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


func _tap(g: ArcadeGame, a: String) -> void:
	_frames(g, 1, {a: true})
	_frames(g, 1, {"_": false})


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		rounds = int(args[0])
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["crystals"] = 1000000
	await process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var only := OS.get_environment("ONLY")
	for err in ([] if only == "skee" else [0.0, 4.0, 9.0]):
		var wins := 0
		var tix := 0
		var value := 0
		for r in rounds:
			ArcadeHub._data()["claw_today"] = []
			ArcadeHub._data()["claw_dry"] = 0
			var cl := _open("claw") as ArcadeClaw
			cl.rng.seed = 1000 + r
			_frames(cl, 8)
			_tap(cl, "a")
			var target := rng.randi() % ArcadeClaw.pile.size()
			var tx := float(ArcadeClaw.pile[target]["x"]) + rng.randfn(0.0, err)
			for i in 900:
				if absf(cl.claw.x - tx) < 1.2:
					break
				_frames(cl, 1, {"right": true} if cl.claw.x < tx else {"left": true})
			_tap(cl, "a")
			for i in 60 * 14:
				if cl.state != "play":
					break
				_frames(cl, 1)
			if cl.won_item != "":
				wins += 1
				value += GameState.item_value(cl.won_item)
			tix += cl.won_tickets
			cl.close()
		print("claw aim_err=%.0f  win %.0f%%  tickets/play %.1f  item value/play %.1f  (fee %d)" % [err, 100.0 * wins / rounds, float(tix) / rounds, float(value) / rounds, ArcadeClaw.FEE])
	# Wins in a row on one day (tightness).
	ArcadeHub._data()["claw_today"] = []
	var day_w := 0
	for r in (0 if only == "skee" else 30):
		var cl2 := _open("claw") as ArcadeClaw
		cl2.rng.seed = 5000 + r
		_frames(cl2, 8)
		_tap(cl2, "a")
		var tx2 := float(ArcadeClaw.pile[0]["x"])
		for i in 900:
			if absf(cl2.claw.x - tx2) < 1.2:
				break
			_frames(cl2, 1, {"right": true} if cl2.claw.x < tx2 else {"left": true})
		_tap(cl2, "a")
		for i in 60 * 14:
			if cl2.state != "play":
				break
			_frames(cl2, 1)
		if cl2.won_item != "":
			day_w += 1
		cl2.close()
	print("claw: 30 perfect plays in one day -> %d wins" % day_w)
	# Duck pond: a player who reacts with an aim error and a pause between shots.
	for skill in ([] if only == "skee" else [[14.0, 0.9], [8.0, 0.6], [4.0, 0.4]]):
		var scores: Array = []
		var tix2 := 0
		for r in maxi(10, rounds / 10):
			var gl := _open("gallery") as ArcadeGallery
			gl.rng.seed = 200 + r
			_frames(gl, 8)
			_tap(gl, "a")
			var wait := 0.0
			for i in 60 * 50:
				if gl.state != "play":
					break
				wait -= 1.0 / 60.0
				if wait <= 0.0:
					for d: Dictionary in gl.ducks:
						if bool(d["alive"]) and str(d["kind"]) != "frog" and float(d["x"]) > 20 and float(d["x"]) < 250:
							var lane := int(d["lane"])
							gl.sight = Vector2(float(d["x"]), ArcadeGallery.LANES[lane] - 16.0 * ArcadeGallery.LANE_SCALE[lane]) + Vector2(rng.randfn(0, skill[0]), rng.randfn(0, skill[0]))
							gl.shoot()
							wait = float(skill[1]) * rng.randf_range(0.7, 1.3)
							break
				_frames(gl, 1)
			scores.append(gl.score)
			tix2 += gl.won_tickets
			gl.close()
		scores.sort()
		print("duck err=%.0f gap=%.1fs  median %d  max %d  tickets/play %.1f (fee %d)" % [skill[0], skill[1], scores[scores.size() / 2], scores[-1], float(tix2) / scores.size(), 10])
	# Skee-ball: aim for the 50 cup down the middle (power error sd), and a
	# corner-cup hunter (line +-0.82, corner power).
	for plan in [[0.0, 0.10], [0.0, 0.06], [0.0, 0.03], [0.82, 0.06], [0.82, 0.03]]:
		var sc: Array = []
		var tix3 := 0
		for r in maxi(10, rounds / 5):
			var sk := _open("skee_ball") as ArcadeSkee
			sk.rng.seed = 300 + r
			_frames(sk, 8)
			_tap(sk, "a")
			for i in 60 * 120:
				if sk.state != "play":
					break
				if sk.phase == "aim":
					var lu := float(plan[0]) * (1.0 if r % 2 == 0 else -1.0)
					var tp := ArcadeSkee.p_for(268.0 if plan[0] == 0.0 else 181.0)
					sk.throw(lu + rng.randfn(0, float(plan[1]) * 0.5), tp + rng.randfn(0, float(plan[1])))
				_frames(sk, 1)
			sc.append(sk.score)
			tix3 += sk.won_tickets
			sk.close()
		sc.sort()
		print("skee line=%.2f err=%.2f  median %d  min %d  max %d  tickets/play %.1f (fee %d)" % [plan[0], plan[1], sc[sc.size() / 2], sc[0], sc[-1], float(tix3) / sc.size(), ArcadeSkee.FEE])
	quit()

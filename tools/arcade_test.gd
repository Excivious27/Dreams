extends SceneTree
## Arcade cabinets: every game starts, plays a few hundred scripted frames,
## ends, pays tickets; jumper levels unlock in order and level 1 is played
## to the end by following the solver's plan; the picker launches games.
##   godot --headless --path . -s res://tools/arcade_test.gd
var fails := 0
const DT := 1.0 / 60.0


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


## Press an action for one frame, then release for one.
func _tap_action(g: ArcadeGame, a: String) -> void:
	_frames(g, 1, {a: true})
	_frames(g, 1, {"_": false})


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["crystals"] = 2000
	await process_frame

	# Tickets API.
	var t0 := Tickets.count()
	Tickets.add(5, "test")
	check(Tickets.count() == t0 + 5, "tickets add")
	check(Tickets.spend(3) and Tickets.count() == t0 + 2, "tickets spend")
	check(not Tickets.spend(99999), "can't overspend tickets")
	check(Tickets.set_best("x", 10) and not Tickets.set_best("x", 5) and Tickets.best_score("x") == 10, "best score keeps the max")
	check(ArcadeHub.money_word() == "crystals", "penguin arc pays crystals")

	# --- Block Jumper ------------------------------------------------------
	var j := _open("jumper") as BlockJumper
	await process_frame
	check(paused, "cabinet pauses the game")
	_frames(j, 8)
	check(j.state == "select", "jumper opens on level select")
	check(not BlockJumper.is_unlocked(2) and not BlockJumper.is_unlocked(0), "level 2 and endless start locked")
	check(not j.play_tile(1), "locked level refuses to start")
	var before := ArcadeHub.money()
	var tk := Tickets.count()
	check(j.play_tile(0), "level 1 starts")
	check(ArcadeHub.money() == before - BlockJumper.FEE, "level costs the fee")
	var plan: Array = JumperLevels.stored_plan(1)
	check(not plan.is_empty(), "solver finds a way through level 1")
	while j.intro_t - DT > 0.5:
		_frames(j, 1)
	var acts := [{}, {"a": true}, {"down": true}]
	for ai: int in plan:
		_frames(j, 1, acts[ai])
	check(j.win_t > 0.0 or j.state == "over", "following the plan reaches the goal (x=%d of %d)" % [int(j.st[JumperLevels.X]), int(j.lv["finish"])])
	_frames(j, 140)
	check(j.state == "over" and j.cleared_now, "level clear shows results")
	check(Tickets.count() > tk, "level clear pays tickets (%d)" % (Tickets.count() - tk))
	check(BlockJumper.cleared(1) and BlockJumper.is_unlocked(2) and BlockJumper.is_unlocked(0), "clearing 1 unlocks 2 and endless")
	check(ArcadeHub.milestone("jumper_1"), "milestone jumper_1")
	check(BlockJumper.best(1) == 100 and Tickets.best_score("jumper") == 100, "best distance for level 1 is 100%")
	_frames(j, 40)
	_tap_action(j, "a")
	check(j.state == "select" and j.sel == 1, "A after a clear returns to select on level 2")
	# Level 2 with no input: three deaths, then results.
	check(j.play_tile(1), "level 2 starts")
	_frames(j, 60 * 40)
	check(j.state == "over" and j.lives <= 0, "doing nothing loses all lives (state %s lives %d)" % [j.state, j.lives])
	check(BlockJumper.best(2) > 0 and BlockJumper.best(2) < 100, "partial distance recorded (%d%%)" % BlockJumper.best(2))
	_frames(j, 40)
	_tap_action(j, "a")
	# Endless: jump now and then, run a while.
	j.sel = JumperLevels.LEVELS.size()
	check(j.play_tile(j.sel), "endless starts")
	for i in 60 * 25:
		if j.state != "play":
			break
		_frames(j, 1, {"a": i % 50 < 12})
	_frames(j, 60 * 10)
	check(j.state == "over" and BlockJumper.best(0) > 0, "endless ends with a distance (%d m)" % BlockJumper.best(0))
	_frames(j, 40)
	_tap_action(j, "b")
	check(not is_instance_valid(j) or j.is_queued_for_deletion(), "B on results leaves")
	await process_frame
	check(not paused, "leaving unpauses")
	# Double jump physics once level 4 is clear.
	var lvd := JumperLevels.build(1, true)
	var st := JumperLevels.new_state(40.0, JumperLevels.GY0)
	var evs := []
	for i in 40:
		var a := i < 3 or (i >= 20 and i < 24)
		evs.append(JumperLevels.step(st, lvd, a, false))
	check(evs.has("djump"), "a second A in the air double-jumps when unlocked")
	# Ducking under a ceiling.
	var lvc := {"n": 1, "def": JumperLevels.LEVELS[0], "solids": [], "plats": [], "movers": [], "spikes": [], "coins": [], "checks": [], "buckets": {}, "finish": 900.0, "dbl": false, "speed0": 100.0, "speed1": 100.0, "length": 1000.0}
	JumperLevels._ground(lvc, -100, 1200, 248)
	JumperLevels._add(lvc, "solids", Rect2(200, -400, 80, 400 + 248 - JumperLevels.CEIL_GAP))
	var s1 := JumperLevels.new_state(100, 248)
	var e1 := ""
	while e1 == "" or e1 == "land":
		e1 = JumperLevels.step(s1, lvc, false, false)
	check(e1 == "dead", "standing into a low ceiling crashes")
	var s2 := JumperLevels.new_state(100, 248)
	var e2 := ""
	for i in 700:
		e2 = JumperLevels.step(s2, lvc, false, true)
		if e2 == "dead" or e2 == "win":
			break
	check(e2 == "win", "ducking passes under it (%s)" % e2)

	# --- Crystal Stack -----------------------------------------------------
	var s := _open("stack") as ArcadeStack
	_frames(s, 8)
	_tap_action(s, "a")
	check(s.state == "play", "stack starts")
	# A ready-made row: an I piece lying in the gap clears it.
	for cx in ArcadeStack.COLS:
		s.board[17][cx] = "" if cx >= 3 and cx <= 6 else "O"
	s.cur = "I"
	s.cells = (ArcadeStack.SHAPES["I"] as Array).duplicate()
	s.pos = Vector2i(4, 17)
	s._lock()
	_frames(s, 30)
	check(s.lines == 1 and s.score >= 100, "a full row clears and scores (%d rows, %d)" % [s.lines, s.score])
	for i in 900:
		if s.state != "play":
			break
		var inp := {}
		if i % 20 == 3:
			inp["a"] = true
		if i % 9 < 4:
			inp["left" if (i / 60) % 2 == 0 else "right"] = true
		if i % 45 == 40:
			inp["up"] = true
		_frames(s, 1, inp)
	if s.state == "play":
		_tap_action(s, "b")  # B pauses (ArcadePause) ...
		_frames(s, 12)
		_tap_action(s, "b")  # ... and B again ends the round
	_frames(s, 90)  # a top-out greys the well before the results card
	check(s.state == "over", "stack ends")
	check(Tickets.best_score("stack") > 0, "stack best score saved")
	s.close()

	# --- Whack-a-Grump ------------------------------------------------------
	var w := _open("whack") as ArcadeWhack
	_frames(w, 8)
	tk = Tickets.count()
	_tap_action(w, "a")
	check(w.state == "play", "whack starts")
	for i in 60 * 44:
		if w.state != "play":
			break
		for h in 9:
			var hd: Dictionary = w.holes[h]
			if str(hd["kind"]) != "" and str(hd["kind"]) != "bunny" and bool(hd["out"]) and float(hd["up"]) > 0.6:
				w.whack(h)
				break
		_frames(w, 1)
	check(w.state == "over", "whack times out")
	check(w.score >= 150 and w.bunnies == 0, "a good player scores (%d)" % w.score)
	check(Tickets.count() > tk, "whack pays tickets")
	check(ArcadeHub.milestone("whack_150"), "milestone whack_150")
	w.close()

	# --- Claw Machine ------------------------------------------------------
	var won := false
	for attempt in 4:
		var cl := _open("claw") as ArcadeClaw
		cl.rng.seed = 7 + attempt
		_frames(cl, 8)
		_tap_action(cl, "a")
		check(cl.state == "play", "claw starts")
		# Steer over the nearest plush, then drop.
		var target := 0
		for i in ArcadeClaw.pile.size():
			if float(ArcadeClaw.pile[i]["y"]) < float(ArcadeClaw.pile[target]["y"]):
				target = i
		var tx := float(ArcadeClaw.pile[target]["x"])
		for i in 600:
			if absf(cl.claw.x - tx) < 1.0:
				break
			_frames(cl, 1, {"right": true} if cl.claw.x < tx else {"left": true})
		_tap_action(cl, "a")
		_frames(cl, 60 * 12)
		check(cl.state == "over", "claw round ends (%s)" % cl.phase)
		if cl.won_item != "":
			won = true
			check(GameState.count(cl.won_item) >= 1, "claw prize lands in the bag")
		cl.close()
		if won:
			break
	check(won, "a centred claw wins a prize within four tries")
	check(not won or ArcadeHub.milestone("claw_win"), "milestone claw_win")

	# --- Duck Pond ---------------------------------------------------------
	var gl := _open("gallery") as ArcadeGallery
	gl.rng.seed = 4242  # fixed ducks: an unseeded run could put a frog in front of an aimed cork
	_frames(gl, 8)
	_tap_action(gl, "a")
	check(gl.state == "play", "gallery starts")
	for i in 60 * 50:
		if gl.state != "play":
			break
		var aim := Vector2.INF
		for d: Dictionary in gl.ducks:
			if bool(d["alive"]) and str(d["kind"]) != "frog" and float(d["x"]) > 20 and float(d["x"]) < 250:
				var lane := int(d["lane"])
				aim = Vector2(float(d["x"]), ArcadeGallery.LANES[lane] - 10.0 * ArcadeGallery.LANE_SCALE[lane])
				break
		if aim != Vector2.INF and gl.cool <= 0.0:
			gl.sight = aim
			gl.shoot()
		_frames(gl, 1)
	check(gl.state == "over", "gallery ends")
	check(gl.score >= 200 and gl.frogs == 0, "aimed corks score (%d)" % gl.score)
	gl.close()

	# --- Picker and money ----------------------------------------------------
	var hub := _open("") as ArcadeHub
	_frames(hub, 8)
	_tap_action(hub, "down")
	_tap_action(hub, "a")
	check(hub._child is ArcadeStack and not hub.visible, "picker launches the chosen cabinet")
	var child := hub._child
	child.manual = true
	_frames(child, 8)
	_tap_action(child, "b")
	check(hub._child == null and hub.visible, "closing a cabinet returns to the picker")
	_frames(hub, 8)
	_tap_action(hub, "b")
	await process_frame
	check(not is_instance_valid(hub), "B leaves the arcade")
	check(Hud.extra_rects.is_empty(), "deck buttons unregistered (%d left)" % Hud.extra_rects.size())
	# The Rec Center's call: ArcadeHub.open(map, id).
	var viamap := ArcadeHub.open(root, "whack")
	check(viamap is ArcadeWhack and viamap.get_parent() == root, "open(map, id) puts the cabinet on the map")
	viamap.close()
	await process_frame
	check(ArcadeHub.open("nope_game") == null, "unknown id opens nothing")
	GameState.run["crystals"] = 3
	var j2 := _open("jumper") as BlockJumper
	_frames(j2, 8)
	check(not j2.play_tile(0) and j2.state == "select" and ArcadeHub.money() == 3, "no money, no game")
	j2.close()
	check(ArcadeHub.milestone("all_games"), "every cabinet played: all_games milestone")
	GameState.run["arc"] = "gangsters"
	check(ArcadeHub.money_word() == "cash", "gangster arc pays cash")

	print("arcade_test: %d failures" % fails)
	quit(1 if fails else 0)

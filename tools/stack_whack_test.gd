extends SceneTree
## Crystal Stack + Whack-a-Grump (CONDUCT 2, c2_03): speed curves, pause card,
## soft-drop lock between pieces, top-out flow, line-clear scoring, READY lead,
## dizzy hold / double-tap rule, tap boxes, countdown, scoring bands of a
## scripted good / sloppy player.
##   godot --headless --path . -s res://tools/stack_whack_test.gd  (-- -v prints the score bands)
var fails := 0
var verbose := false


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
		g.t += 1.0 / 60.0
		g.frame()


func _tap(g: ArcadeGame, a: String) -> void:
	_frames(g, 1, {a: true})
	_frames(g, 1, {"_": false})


func _start(id: String) -> ArcadeGame:
	var g := _open(id)
	_frames(g, 8)
	_tap(g, "a")
	return g


func _run() -> void:
	verbose = "-v" in OS.get_cmdline_user_args()
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["crystals"] = 5000
	_stack()
	_whack()
	print("stack_whack_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


func _stack() -> void:
	# Speed curve: gentle start, steady, never faster than a phone can follow.
	var prev := 99.0
	for lv in range(1, 30):
		var g := ArcadeStack.gravity_for(lv)
		check(g <= prev and g >= 0.07, "stack gravity falls smoothly (lvl %d: %.3f)" % [lv, g])
		prev = g
	check(absf(ArcadeStack.gravity_for(1) - 0.8) < 0.001, "level 1 is 0.8 s a row")
	check(ArcadeStack.gravity_for(5) > 0.3 and ArcadeStack.gravity_for(10) > 0.12, "mid levels stay playable")

	var s := _start("stack") as ArcadeStack
	check(s.state == "play", "stack starts")
	# Pause: B pauses, the piece stands still, A resumes.
	var y0 := s.pos.y
	_tap(s, "b")
	check(s.state == "paused", "B pauses the stack (no lost coin)")
	_frames(s, 120)
	check(s.pos.y == y0 and s.state == "paused", "nothing falls while paused")
	_tap(s, "a")
	check(s.state == "play", "A resumes")
	# Soft drop stays with its piece: hold ▼ through a lock, the next piece waits.
	var first := s.cur
	var guard := 0
	while s.cur == first and guard < 600:
		_frames(s, 1, {"down": true})
		guard += 1
	_frames(s, 2, {"down": true})
	var yb := s.pos.y
	_frames(s, 20, {"down": true})
	check(s.pos.y - yb <= 1, "held ▼ from the last piece doesn't rush the new one (%d rows)" % (s.pos.y - yb))
	_frames(s, 1)
	var yc := s.pos.y
	_frames(s, 20, {"down": true})
	check(s.pos.y - yc >= 4, "a fresh ▼ press soft-drops (%d rows)" % (s.pos.y - yc))
	# Line clears score per level; the level bar advances every 8 rows.
	s._setup_round()
	for r in [16, 17]:
		for cx in ArcadeStack.COLS:
			s.board[r][cx] = "" if cx >= 3 and cx <= 6 else "O"
	for cx in ArcadeStack.COLS:
		s.board[15][cx] = "" if cx >= 3 and cx <= 6 else "O"
		s.board[14][cx] = "" if cx >= 3 and cx <= 6 else "O"
	# Four I pieces lying flat fill the 4x4 gap: rows 14-17 clear together.
	for r in [17, 16, 15]:
		s.cur = "I"
		s.cells = (ArcadeStack.SHAPES["I"] as Array).duplicate()
		s.pos = Vector2i(4, r)
		for c: Vector2i in s.cells:
			s.board[r][c.x + 4] = "I"
	s.cur = "I"
	s.cells = (ArcadeStack.SHAPES["I"] as Array).duplicate()
	s.pos = Vector2i(4, 14)
	var sc0 := s.score
	s._lock()
	check(s.score - sc0 == 800 and s.tetras == 1, "four rows at once score 800 at level 1 (%d)" % (s.score - sc0))
	_frames(s, 30)
	check(s.lines == 4, "rows removed (%d)" % s.lines)
	# Top-out: the well greys, then the results card carries the rows.
	for r in ArcadeStack.ROWS:
		for cx in ArcadeStack.COLS:
			s.board[r][cx] = "Z" if cx != 0 else ""
	s._spawn()
	check(s.state == "topout", "a blocked spawn starts the top-out")
	_frames(s, 30)
	check(s.state == "topout", "top-out plays for a moment")
	_frames(s, 60)
	check(s.state == "over", "then the results card")
	check(str(s.over_lines[0]) == "!STACKED OUT" and s.over_lines.has("Crystal Crushes: 1"), "results name the top-out and crushes (%s)" % str(s.over_lines))
	# Pause then B ends the round.
	_frames(s, 40)
	_tap(s, "a")
	_tap(s, "a")
	check(s.state == "play", "again from the results card")
	_tap(s, "b")
	_frames(s, 12)
	_tap(s, "b")
	check(s.state == "over" and str(s.over_lines[0]) == "!GAME ENDED", "B, B ends the round")
	s.close()


func _whack() -> void:
	check(ArcadeWhack.hole_at(Vector2(55, 75)) == 0, "a tap on a top-row grump's head hits hole 0")
	check(ArcadeWhack.hole_at(Vector2(135, 205)) == 4, "middle hole")
	check(ArcadeWhack.hole_at(Vector2(255, 300)) == 8, "bottom-right hole")
	check(ArcadeWhack.hole_at(Vector2(100, 40)) == -1, "the HUD strip is not a hole")
	var w := _start("whack") as ArcadeWhack
	check(w.state == "play", "whack starts")
	# READY: no critters, the clock waits.
	_frames(w, 60)
	var any := false
	for h: Dictionary in w.holes:
		any = any or str(h["kind"]) != ""
	check(not any and w.time_left() >= ArcadeWhack.ROUND, "READY: nothing pops, the clock waits")
	check(w.whack(4) == 0 and w.combo == 0, "a swing during READY does nothing")
	# Bop a grump: it stays up dizzy, and a second tap is no miss.
	_frames(w, 30)
	w.holes[2] = {"kind": "grump", "life": 2.0, "up": 1.0, "hp": 1, "hit": 0.0, "out": true}
	w.combo = 2
	check(w.whack(2) == 5 and w.combo == 3, "bop scores")
	_frames(w, 10)
	check(float(w.holes[2]["up"]) >= 0.99, "a bopped grump stays up dizzy for a beat")
	check(w.whack(2) == 0 and w.combo == 3, "a second tap on the dizzy grump keeps the combo")
	var ducked := false
	for i in 30:
		_frames(w, 1)
		ducked = ducked or str(w.holes[2]["kind"]) == ""
	check(ducked, "then it ducks")
	# Combo multiplier: 10 in a row x2.
	w.combo = ArcadeWhack.COMBO_STEP - 1
	w.holes[0] = {"kind": "grump", "life": 2.0, "up": 1.0, "hp": 1, "hit": 0.0, "out": true}
	check(w.whack(0) == 10, "the 10th bop in a row pays x2")
	# Pause holds the clock.
	var tl := w.time_left()
	_tap(w, "b")
	_frames(w, 120)
	check(w.state == "paused" and absf(w.time_left() - tl) < 0.05, "pause holds the clock")
	_tap(w, "a")
	check(w.state == "play", "resume")
	w.close()

	# Score bands: a sharp player and a sloppy one, seeded.
	var bands := []
	for skill in [[0.25, 0.0], [0.45, 0.15]]:
		var tot := 0
		var tix := 0
		for seed in 4:
			var g := _open("whack") as ArcadeWhack
			g.rng.seed = 100 + seed
			_frames(g, 8)
			_tap(g, "a")
			var react := {}
			for i in 60 * 45:
				if g.state != "play":
					break
				for h in 9:
					var hd: Dictionary = g.holes[h]
					var k := str(hd["kind"])
					if k == "" or not bool(hd["out"]) or float(hd["hit"]) > 0.0:
						react.erase(h)
						continue
					react[h] = int(react.get(h, 0)) + 1
					# Reaction time in seconds; the sloppy one sometimes bops a bunny.
					if float(react[h]) / 60.0 >= float(skill[0]):
						if k != "bunny" or g.rng.randf() < float(skill[1]):
							g.whack(h)
							react.erase(h)
							break
				_frames(g, 1)
			check(g.state == "over", "whack round ends on time")
			tot += g.score
			tix += g.won_tickets
			g.close()
		bands.append([tot / 4, tix / 4])
	if verbose:
		print("  whack bands (score, tickets) sharp=%s sloppy=%s" % [str(bands[0]), str(bands[1])])
	check(bands[0][0] > bands[1][0], "a sharper player scores more")
	check(bands[0][0] >= 300 and bands[0][0] <= 800, "a sharp player scores near the 400 milestone (%d)" % bands[0][0])
	check(bands[1][0] >= 120 and bands[1][0] <= 400, "a casual player scores near 150-350 (%d)" % bands[1][0])

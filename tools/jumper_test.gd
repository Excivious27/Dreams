extends SceneTree
## Block Jumper feel and fairness: coyote time, jump buffer, the difficulty
## curve (each level faster, longer and denser than the last), checkpoints
## on calm ground with a respawn on the straight run's clock (moving
## platforms in the solved phase), and the play area working as a JUMP button.
##   godot --headless --path . -s res://tools/jumper_test.gd
var fails := 0
const DT := 1.0 / 60.0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	_run.call_deferred()


func _flat(len_x := 2000.0) -> Dictionary:
	var lv := {"n": 1, "def": JumperLevels.LEVELS[0], "solids": [], "plats": [], "movers": [], "spikes": [], "coins": [], "checks": [], "buckets": {}, "finish": 1.0e9, "dbl": false, "speed0": 100.0, "speed1": 100.0, "length": len_x}
	return lv


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["crystals"] = 2000
	await process_frame

	# Coyote time: A a few frames after running off a ledge still jumps.
	var lv := _flat()
	JumperLevels._ground(lv, -100.0, 300.0, 248.0)   # ledge ends at x=200
	JumperLevels._ground(lv, 400.0, 800.0, 248.0)
	var st := JumperLevels.new_state(150.0, 248.0)
	var off_k := -1
	var ev := ""
	for k in 80:
		ev = JumperLevels.step(st, lv, off_k >= 0 and k == off_k + 3, false)
		if off_k < 0 and int(st[JumperLevels.GND]) == 0:
			off_k = k
		if ev == "jump":
			break
	check(ev == "jump", "coyote: A 3 frames after leaving the ledge still jumps")
	st = JumperLevels.new_state(150.0, 248.0)
	off_k = -1
	ev = ""
	for k in 80:
		ev = JumperLevels.step(st, lv, off_k >= 0 and k == off_k + 9, false)
		if off_k < 0 and int(st[JumperLevels.GND]) == 0:
			off_k = k
		if ev == "jump":
			break
	check(ev != "jump", "coyote ends: A 9 frames after leaving the ledge does nothing")
	# Jump buffer: A pressed just before landing jumps on touchdown.
	var lv2 := _flat()
	JumperLevels._ground(lv2, -100.0, 3000.0, 248.0)
	st = JumperLevels.new_state(100.0, 248.0)
	JumperLevels.step(st, lv2, true, false)
	var land_k := -1
	var evs: Array = []
	for k in 120:
		evs.append(JumperLevels.step(st, lv2, false, false))
		if evs[-1] == "land":
			land_k = k
			break
	check(land_k > 0, "a plain jump lands (%d)" % land_k)
	st = JumperLevels.new_state(100.0, 248.0)
	JumperLevels.step(st, lv2, true, false)
	var rejump := false
	for k in land_k + 6:
		var e2 := JumperLevels.step(st, lv2, k == land_k - 4, false)
		if e2 == "jump" and k >= land_k - 4:
			rejump = true
	check(rejump, "buffer: A 4 frames before landing jumps again on touchdown")
	# Hold for higher.
	var tops := []
	for hold in [1, 14]:
		st = JumperLevels.new_state(100.0, 248.0)
		var top := 248.0
		for k in 60:
			JumperLevels.step(st, lv2, k < hold, false)
			top = minf(top, float(st[JumperLevels.Y]))
		tops.append(248.0 - top)
	check(float(tops[1]) > float(tops[0]) + 25.0, "holding A jumps clearly higher (%d vs %d px)" % [int(tops[1]), int(tops[0])])

	# Difficulty curve: faster, longer (in seconds) and harder level by level.
	var prev_secs := 0.0
	var prev_sp := 0.0
	var prev_d := -1.0
	for n in range(1, JumperLevels.LEVELS.size() + 1):
		var d: Dictionary = JumperLevels.LEVELS[n - 1]
		var lvn := JumperLevels.build(n, false)
		var secs := 0.0
		var x := 0.0
		while x < float(lvn["finish"]):
			x += JumperLevels.speed_at(lvn, x) * DT
			secs += DT
		check(secs > prev_secs, "level %d runs longer than the one before (%.1fs)" % [n, secs])
		check(float(d["speed0"]) > prev_sp and float(d["diff"]) > prev_d, "level %d starts faster and harder" % n)
		prev_secs = secs
		prev_sp = float(d["speed0"])
		prev_d = float(d["diff"])
		# Checkpoints: at least two, each on calm ground (a second of flat run after it).
		var checks: Array = lvn["checks"]
		check(checks.size() >= 2, "level %d has %d checkpoints" % [n, checks.size()])
		for c: Vector2 in checks:
			var sp := JumperLevels.speed_at(lvn, c.x)
			var calm := true
			var cx := c.x
			while cx < c.x + sp * 1.0:
				var s2 := JumperLevels.new_state(cx, c.y)
				var sup := JumperLevels._support(lvn, s2)
				if float(sup[0]) != c.y or JumperLevels._solid_hit(lvn, cx, c.y - 1.0, JumperLevels.H_STAND) or _spike_near(lvn, cx - 8.0, cx + 8.0):
					calm = false
					break
				cx += 4.0
			check(calm, "level %d checkpoint x=%d has a calm second ahead" % [n, int(c.x)])
		if n == JumperLevels.LEVELS.size():
			check(secs >= 38.0, "the last level is a real gauntlet (%.1fs)" % secs)
		if n == 1:
			check(secs <= 30.0, "level 1 is short (%.1fs)" % secs)
	check(JumperLevels.LEVELS[0]["kinds"].size() <= 3, "level 1 only uses the three basic obstacles")

	# Respawn keeps the straight run's clock (moving platforms in phase).
	var lv5 := JumperLevels.build(5, false)
	var run := JumperLevels.new_state(0.0, JumperLevels.GY0)
	var plan := JumperLevels.stored_plan(5)
	var acts := [[false, false], [true, false], [false, true]]
	var c0: Vector2 = (lv5["checks"] as Array)[0]
	for a: int in plan:
		JumperLevels.step(run, lv5, bool(acts[a][0]), bool(acts[a][1]))
		if float(run[JumperLevels.X]) >= c0.x:
			break
	var rs := JumperLevels.respawn_state(lv5, c0.x, c0.y)
	check(absf(float(rs[JumperLevels.X]) - float(run[JumperLevels.X])) < 0.01 and absf(float(rs[JumperLevels.T]) - float(run[JumperLevels.T])) < 0.001,
		"respawn at a checkpoint has the same x and clock as a straight run (%.2f/%.3f vs %.2f/%.3f)" % [float(rs[JumperLevels.X]), float(rs[JumperLevels.T]), float(run[JumperLevels.X]), float(run[JumperLevels.T])])

	# In the game: die after a checkpoint, respawn there on that clock.
	var j := ArcadeHub.make("jumper") as BlockJumper
	j.manual = true
	root.add_child(j)
	for n in range(1, 5):
		BlockJumper._jd()["clear"][str(n)] = true
	for i in 8:
		j.frame()
	check(j.play_tile(4), "level 5 starts")
	j.lv["dbl"] = false
	while j.intro_t - DT > 0.5:
		j.bot = {}
		j.frame()
	for a: int in plan:
		j.bot = [{}, {"a": true}, {"down": true}][a]
		j.frame()
		if j.check_i >= 0:
			break
	check(j.check_i == 0, "reached the first checkpoint")
	j.bot = {}
	var guard := 0
	while j.dead_t <= 0.0 and guard < 60 * 20:
		j.frame()
		guard += 1
	check(j.dead_t > 0.0 and j.lives == 2, "running blind dies (lives %d)" % j.lives)
	guard = 0
	while j.dead_t > 0.0 and guard < 200:
		j.frame()
		guard += 1
	var want := JumperLevels.respawn_state(j.lv, c0.x, c0.y)
	check(absf(float(j.st[JumperLevels.X]) - float(want[JumperLevels.X])) < 0.01 and absf(float(j.st[JumperLevels.T]) - float(want[JumperLevels.T])) < 0.001, "respawn puts you back at the checkpoint on the run's clock")
	var seg := JumperLevels.stored_check_plan(5, 0)
	check(not seg.is_empty(), "a stored plan from checkpoint 1 exists")

	# The play area is a JUMP button while running (touch and release).
	j.manual = false
	var tch := InputEventScreenTouch.new()
	tch.index = 3
	tch.position = Vector2(150, 200)
	tch.pressed = true
	j._input(tch)
	check(Input.is_action_pressed("a"), "touching the picture holds JUMP")
	tch.pressed = false
	j._input(tch)
	check(not Input.is_action_pressed("a"), "lifting the thumb lets go of JUMP")
	j.state = "select"
	tch.pressed = true
	j._input(tch)
	check(not Input.is_action_pressed("a"), "on the level select the picture is not a JUMP button")
	tch.pressed = false
	j._input(tch)
	j.manual = true
	j.close()
	await process_frame

	print("jumper_test: %d failures" % fails)
	quit(1 if fails else 0)


## A spike actually overlapping x0..x1 (near() returns whole 64 px buckets).
func _spike_near(lv: Dictionary, x0: float, x1: float) -> bool:
	var sp: Array = lv["spikes"]
	for i: int in JumperLevels.near(lv, "spikes", x0, x1):
		var r: Rect2 = sp[i]
		if r.position.x < x1 and r.end.x > x0:
			return true
	return false

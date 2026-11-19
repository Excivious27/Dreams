extends SceneTree
## Block Jumper level audit: how forgiving each jump is for a human.
## For every take-off in the stored winning plan it tries taking off d frames
## earlier/later (with the plan's hold, a tap or a full hold) and counts the
## take-off frames that still get through the next two landings. Prints the
## tightest jumps per level plus counts, and solves from every checkpoint.
##   godot --headless --path . -s res://tools/jumper_audit.gd [-- --levels 1,2 --checks]
const OFFS := 16


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var only: Array = []
	var i := args.find("--levels")
	if i >= 0 and i + 1 < args.size():
		for s in args[i + 1].split(","):
			only.append(int(s))
	var do_checks := args.has("--checks")
	for n in range(1, JumperLevels.LEVELS.size() + 1):
		if not only.is_empty() and not only.has(n):
			continue
		_audit(n, do_checks)
	quit(0)


func _audit(n: int, do_checks: bool) -> void:
	var lv := JumperLevels.build(n, false)
	var plan := JumperLevels.stored_plan(n)
	var acts := [[false, false], [true, false], [false, true]]
	var st := JumperLevels.new_state(0.0, JumperLevels.GY0)
	var states: Array = []   # state BEFORE frame k
	var evs: Array = []
	for a: int in plan:
		states.append(st.duplicate())
		evs.append(JumperLevels.step(st, lv, bool(acts[a][0]), bool(acts[a][1])))
	var takeoffs: Array = []
	var lands: Array = []
	for k in evs.size():
		if evs[k] == "jump":
			takeoffs.append(k)
		elif evs[k] == "land":
			lands.append(k)
	var counts := {}
	for kk in ["gap", "spikes", "block", "step", "ceiling", "plats", "mover", "pit"]:
		counts[kk] = 0
	var windows: Array = []
	for ti in takeoffs.size():
		var f: int = takeoffs[ti]
		var hold := 0
		while f + hold < plan.size() and int(plan[f + hold]) == 1:
			hold += 1
		# Must survive until the landing after the next take-off (or 90 frames).
		var end := mini(plan.size(), f + 90)
		var later := 0
		for l: int in lands:
			if l > f:
				later += 1
				if later == 2:
					end = mini(plan.size(), l + 1)
					break
		var ok_d: Array = []
		for d in range(-OFFS, OFFS + 1):
			var s0 := f + d
			if s0 < 1 or s0 >= plan.size():
				continue
			var good := false
			for hh in [hold, 1, 14]:
				if _try(lv, states[s0], plan, f, hold, s0, hh, end):
					good = true
					break
			if good:
				ok_d.append(d)
		# Longest run of consecutive ok offsets that contains 0.
		var lo := 0
		while ok_d.has(lo - 1):
			lo -= 1
		var hi := 0
		while ok_d.has(hi + 1):
			hi += 1
		var win := hi - lo + 1
		windows.append([win, float(states[f][JumperLevels.X]), lo, hi])
	windows.sort_custom(func(p: Array, q: Array) -> bool: return int(p[0]) < int(q[0]))
	var secs := plan.size() / 60.0
	var tight := 0
	var hard := 0
	for w: Array in windows:
		if int(w[0]) < 6:
			tight += 1
		if int(w[0]) < 4:
			hard += 1
	var hist := {}
	for w: Array in windows:
		var b := mini(int(w[0]), 12)
		hist[b] = int(hist.get(b, 0)) + 1
	var line := "L%d %-13s %4.1fs jumps=%d  <4f:%d  <6f:%d  checks=%s finish=%d" % [n, lv["def"]["name"], secs, takeoffs.size(), hard, tight, str((lv["checks"] as Array).map(func(c: Vector2) -> int: return int(c.x))), int(lv["finish"])]
	print(line)
	var hs := "   window hist:"
	for b in range(1, 13):
		if hist.has(b):
			hs += " %d:%d" % [b, hist[b]]
	print(hs)
	var tl := "   tightest:"
	for w in windows.slice(0, 6):
		tl += " [%df @x%d %+d..%+d]" % [w[0], int(w[1]), w[2], w[3]]
	print(tl)
	if do_checks:
		for c: Vector2 in lv["checks"]:
			var t0 := Time.get_ticks_msec()
			var res := JumperLevels.solve(lv, c.x)
			print("   from checkpoint x=%d: ok=%s (%dms)" % [int(c.x), res["ok"], Time.get_ticks_msec() - t0])


## Takes off at frame s0 holding A for hh frames instead of the plan's own jump at f.
func _try(lv: Dictionary, st0: Array, plan: Array, f: int, hold: int, s0: int, hh: int, end: int) -> bool:
	var st: Array = st0.duplicate()
	for k in range(s0, end):
		var a := false
		var dn := false
		if k >= s0 and k < s0 + hh:
			a = true
		elif k >= f and k < f + hold:
			a = false
		elif k < s0 and k >= f:
			a = false
		else:
			a = int(plan[k]) == 1
			dn = int(plan[k]) == 2
		var ev := JumperLevels.step(st, lv, a, dn)
		if ev == "dead":
			return false
		if ev == "win":
			return true
	return true

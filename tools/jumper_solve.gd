extends SceneTree
## Block Jumper levels can all be finished without the double jump, from the
## start and from every checkpoint (a respawn lands on the straight run's
## clock, so moving platforms are in the same phase as a clean run).
##   godot --headless --path . -s res://tools/jumper_solve.gd            replay the stored plans (fast; check.sh)
##   godot --headless --path . -s res://tools/jumper_solve.gd -- --solve  search again and rewrite data/jumper_plans.json
##   ... -- --solve --levels 3,5   only those levels (keeps the others' plans)
##   ... -- --seeds 5,7             try seeds after each listed level's own and print the first that solves
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var solve := args.has("--solve")
	var only: Array = []
	var li := args.find("--levels")
	if li >= 0 and li + 1 < args.size():
		for s in args[li + 1].split(","):
			only.append(int(s))
	var fails := 0
	var plans := {}
	if solve and not only.is_empty() and FileAccess.file_exists(JumperLevels.PLANS):
		plans = JSON.parse_string(FileAccess.get_file_as_string(JumperLevels.PLANS))
	var si := args.find("--seeds")
	if si >= 0 and si + 1 < args.size():
		for sn in args[si + 1].split(","):
			var n := int(sn)
			var base := int(JumperLevels.LEVELS[n - 1]["seed"])
			for sd in range(base + 1, base + 40):
				var lv := JumperLevels.build(n, false, sd * 7919 + 13)
				var ok := (lv["checks"] as Array).size() >= 2
				if ok:
					var res := JumperLevels.solve(lv)
					ok = bool(res["ok"])
					print("level %d seed %d: %s (x=%d)" % [n, sd, ok, int(res["x"])])
				if ok:
					print("SEED level %d -> %d" % [n, sd])
					break
		quit(0)
		return
	var segs := 0
	for n in range(1, JumperLevels.LEVELS.size() + 1):
		if not only.is_empty() and not only.has(n):
			continue
		var lv := JumperLevels.build(n, false)
		var checks: Array = lv["checks"]
		if checks.size() < 2:
			fails += 1
			print("  FAIL level %d: only %d checkpoints" % [n, checks.size()])
		# Segment -1 is the whole level from the start; i is checkpoint i to the next one (or the goal).
		for i in range(-1, checks.size()):
			var from := Vector2(0.0, JumperLevels.GY0) if i < 0 else (checks[i] as Vector2)
			var to_x := INF if i < 0 or i + 1 >= checks.size() else (checks[i + 1] as Vector2).x + 1.0
			var key := str(n) if i < 0 else "%d@%d" % [n, i]
			segs += 1
			if solve:
				var t0 := Time.get_ticks_msec()
				var res := JumperLevels.solve(lv, from.x, 150, from.y, to_x)
				if not res["ok"]:  # the beam can prune the only way through: look wider
					res = JumperLevels.solve(lv, from.x, 600, from.y, to_x)
				print("level %d %s seg %s: ok=%s x=%d %dms" % [n, lv["def"]["name"], key, res["ok"], int(res["x"]), Time.get_ticks_msec() - t0])
				if res["ok"]:
					plans[key] = JumperLevels.rle(res["plan"])
				else:
					fails += 1
			else:
				var plan := JumperLevels.stored_plan(n) if i < 0 else JumperLevels.stored_check_plan(n, i)
				var ev := JumperLevels.replay(JumperLevels.build(n, false), plan, from, to_x)
				if ev != "win":
					fails += 1
					print("  FAIL level %d seg %s: stored plan ends in %s (re-run with -- --solve after changing levels)" % [n, key, ev])
	if solve and fails == 0:
		var f := FileAccess.open("res://data/jumper_plans.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(plans))
		f.close()
		print("wrote data/jumper_plans.json")
	print("jumper_solve: %d failures (%d segments)" % [fails, segs])
	quit(1 if fails else 0)

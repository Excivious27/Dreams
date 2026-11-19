extends SceneTree
## Block Jumper levels can all be finished without the double jump.
##   godot --headless --path . -s res://tools/jumper_solve.gd            replay the stored plans (fast; check.sh)
##   godot --headless --path . -s res://tools/jumper_solve.gd -- --solve  search again and rewrite data/jumper_plans.json
func _initialize() -> void:
	var solve := OS.get_cmdline_user_args().has("--solve")
	var fails := 0
	var plans := {}
	for n in range(1, JumperLevels.LEVELS.size() + 1):
		var lv := JumperLevels.build(n, false)
		if solve:
			var t0 := Time.get_ticks_msec()
			var res := JumperLevels.solve(lv)
			print("level %d %s: ok=%s x=%d/%d %dms" % [n, lv["def"]["name"], res["ok"], int(res["x"]), int(lv["finish"]), Time.get_ticks_msec() - t0])
			if res["ok"]:
				plans[str(n)] = JumperLevels.rle(res["plan"])
			else:
				fails += 1
		else:
			var plan := JumperLevels.stored_plan(n)
			var ev := JumperLevels.replay(JumperLevels.build(n, false), plan)
			if ev != "win":
				fails += 1
				print("  FAIL level %d: stored plan ends in %s (re-run with -- --solve after changing levels)" % [n, ev])
	if solve and fails == 0:
		var f := FileAccess.open("res://data/jumper_plans.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(plans))
		f.close()
		print("wrote data/jumper_plans.json")
	print("jumper_solve: %d failures" % fails)
	quit(1 if fails else 0)

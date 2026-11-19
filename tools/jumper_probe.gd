extends SceneTree
## Debug: from (x, y) on a level, jump after k frames (full hold) and report the outcome.
##   godot --headless --path . -s res://tools/jumper_probe.gd -- LEVEL X Y
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var lv := JumperLevels.build(int(a[0]), false)
	for k in range(0, 40, 2):
		var st := JumperLevels.respawn_state(lv, float(a[1]), float(a[2]))
		var out := ""
		var jx := 0.0
		for f in 120:
			var ev := JumperLevels.step(st, lv, f >= k and f < k + 14, false)
			if ev == "jump":
				jx = float(st[JumperLevels.X])
			if ev == "land" and jx > 0.0:
				out = "land x=%d y=%d" % [int(st[JumperLevels.X]), int(st[JumperLevels.Y])]
				break
			if ev == "dead":
				out = "dead x=%d y=%d vy=%d gnd=%d" % [int(st[JumperLevels.X]), int(st[JumperLevels.Y]), int(st[JumperLevels.VY]), int(st[JumperLevels.GND])]
				break
		print("k=%d jump@%d -> %s" % [k, int(jx), out])
	quit(0)

extends SceneTree
## Lists Block Jumper level geometry in an x range (debugging unsolvable spots).
##   godot --headless --path . -s res://tools/jumper_dump.gd -- LEVEL X0 X1
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var lv := JumperLevels.build(int(a[0]), false)
	var x0 := float(a[1])
	var x1 := float(a[2])
	print("speed %.0f reach full %.0f tap %.0f" % [JumperLevels.speed_at(lv, x0), JumperLevels.reach(JumperLevels.speed_at(lv, x0)), JumperLevels.reach(JumperLevels.speed_at(lv, x0), false)])
	for kind in ["solids", "plats", "spikes"]:
		for r: Rect2 in lv[kind]:
			if r.end.x >= x0 and r.position.x <= x1:
				print("%s x %.0f..%.0f y %.0f..%.0f" % [kind, r.position.x, r.end.x, r.position.y, r.end.y])
	for m: Dictionary in lv["movers"]:
		if float(m["x"]) + 80 >= x0 and float(m["x"]) - 40 <= x1:
			print("mover ", m)
	quit(0)

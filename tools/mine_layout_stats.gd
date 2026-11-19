extends SceneTree
## Dev helper: how big each mine layout style comes out (walkable share of the
## grid, hazard share) over many seeds. -- [floor] [runs]
const L := preload("res://scripts/mine_layouts.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var f := int(args[0]) if args.size() > 0 else 1
	var runs := int(args[1]) if args.size() > 1 else 6
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for st: Dictionary in L.STYLES:
		var tot := 0.0
		var lo := 1.0
		var haz := 0.0
		var t0 := Time.get_ticks_msec()
		for i in runs:
			var cols := int((54 + mini(f, 40) * 0.7 + rng.randi_range(0, 18)) * float(st["size"]))
			var rows := int((46 + mini(f, 40) / 2.5 + rng.randi_range(0, 14)) * float(st["size"]))
			var lay := L.carve(str(st["id"]), cols, rows, rng, f, false)
			var h := (lay["water"] as Dictionary).size() + (lay["chasm"] as Dictionary).size() + (lay["lava"] as Dictionary).size()
			var w := float((lay["open"] as Dictionary).size() - h) / (cols * rows)
			tot += w
			lo = minf(lo, w)
			haz += float(h) / (cols * rows)
		print("%-18s walk avg %.2f min %.2f haz %.2f  %d ms/run" % [st["id"], tot / runs, lo, haz / runs, (Time.get_ticks_msec() - t0) / runs])
	quit()

extends SceneTree
## C14b P1 (c14b_15-01, c14b_17-02): the web/phone animation budget, headless.
##   godot --headless --fixed-fps 60 --path . -s res://tools/anim_budget_test.gd
## Loads the heaviest maps of both arcs and asserts per map at rest (Anim.budget):
## AnimatedSprite2D <= 120 total and <= 40 in the 270x480 phone view, nodes processing
## <= 220, distinct ShaderMaterials <= 12 (sway/crisp shared, never per prop), and no
## group of 3+ anim_props on one strip in lockstep. Prints the table (docs baseline).
const MAX_ANIM := 120
const MAX_ON := 40
const MAX_PROC := 220
const MAX_MATS := 12
const SETS := {"penguins": ["farm", "town", "beach", "forest", "meadow", "crystal_meadow"],
	"gangsters": ["farm", "town", "neon", "uptown", "docks", "hideout"]}
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	seed(15)
	Campaign.bypass = true
	_run.call_deferred()


func _run() -> void:
	InputSetup.ensure_actions()
	print("%-10s %-16s %6s %6s %6s %6s %5s" % ["arc", "scene", "anim", "onscr", "proc", "mats", "lock"])
	for arc: String in SETS:
		for sc: String in SETS[arc]:
			if not ResourceLoader.exists("res://scenes/%s.tscn" % sc):
				continue
			GameState.new_run(arc, "kairi", "Kairi", "Dreamhollow", "Biscuit")
			GameState.run["intro_done"] = true
			GameState.run["flags"]["partner_scene"] = true
			var m := (load("res://scenes/%s.tscn" % sc) as PackedScene).instantiate()
			root.add_child(m)
			for i in 6:
				await process_frame
			var view := Rect2()
			var cam := root.get_viewport().get_camera_2d()
			if cam:
				var sz := Vector2(270, 480) / cam.zoom
				view = Rect2(cam.get_screen_center_position() - sz / 2.0, sz)
			var b := Anim.budget(m, view)
			print("%-10s %-16s %6d %6d %6d %6d %5d" % [arc, sc, b["anim"], b["anim_onscreen"], b["proc"], b["mats"], b["lock"]])
			var tag := "%s/%s" % [arc, sc]
			check(int(b["anim"]) <= MAX_ANIM, "%s: animated sprites %d <= %d" % [tag, b["anim"], MAX_ANIM])
			check(int(b["anim_onscreen"]) <= MAX_ON, "%s: on-screen animated sprites %d <= %d" % [tag, b["anim_onscreen"], MAX_ON])
			check(int(b["proc"]) <= MAX_PROC, "%s: processing nodes %d <= %d" % [tag, b["proc"], MAX_PROC])
			check(int(b["mats"]) <= MAX_MATS, "%s: shader materials %d <= %d" % [tag, b["mats"], MAX_MATS])
			check(int(b["lock"]) == 0, "%s: %d anim_prop groups in lockstep" % [tag, b["lock"]])
			m.queue_free()
			for i in 2:
				await process_frame
	print("anim_budget_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

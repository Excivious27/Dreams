extends SceneTree
## Dev helper: prints each map's plateaus (bbox, first stair) and size, for area_shot coordinates.
##   godot --headless --path . -s res://tools/plateau_list_d.gd   (MAPS env: comma list)
var MAPS: Array = ["farm", "forest", "meadow", "mountain", "highlands", "orchard_hills", "quarry", "colony_coral", "colony_ice", "town"]

func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	InputSetup.ensure_actions()
	GameState.load_data()
	_run.call_deferred()

func _run() -> void:
	if OS.get_environment("MAPS") != "":
		MAPS = Array(OS.get_environment("MAPS").split(","))
	GameState.new_run("penguins", "man", "Tester", "Dreamhollow", "Pip")
	GameState.run["intro_done"] = true
	for id in MAPS:
		GameState.run["flags"][id + "_seen"] = true
	for id in MAPS:
		GameMap.next_spawn = Vector2.ZERO
		change_scene_to_file("res://scenes/%s.tscn" % id)
		for i in 10:
			await process_frame
		var m := current_scene as GameMap
		if m == null:
			continue
		print("%s %dx%d content=%s spawn=%s" % [id, m.cols, m.rows, str(m.content_rect()) if m.has_method("content_rect") else "?", m.player.cell()])
		for pl: Dictionary in m.plateaus:
			var r := Rect2i()
			var first := true
			for c: Vector2i in pl["cells"]:
				if first:
					r = Rect2i(c, Vector2i.ONE); first = false
				else:
					r = r.expand(c).expand(c + Vector2i.ONE)
			var st: Array = pl["stairs"].keys()
			print("   plateau bbox=%s cells=%d stairs=%s" % [r, pl["cells"].size(), str(st.slice(0, 3))])
	quit()

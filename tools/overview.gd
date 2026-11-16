extends SceneTree
## Dev helper: whole-map overviews (zoomed out) for layout review. Args: out dir, scene names...
var out := "/tmp"
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["quests"] = [{"id": "clear_meadow", "text": "x", "done": true}]
	for i in range(1, args.size()):
		var sc: String = args[i]
		GameState.run["flags"][sc + "_seen"] = true
		GameMap.next_spawn = Vector2.ZERO
		change_scene_to_file("res://scenes/%s.tscn" % sc)
		for k in 20: await process_frame
		var d := Dialogue.instance(self)
		for k in 6:
			if d.active:
				d._advance(); await process_frame; await process_frame
		var m := current_scene as GameMap
		var cam: Camera2D = null
		for ch in m.player.get_children():
			if ch is Camera2D: cam = ch
		var w := (m.cols + 2 * m.pad) * GameMap.TILE
		var h := (m.rows + 2 * m.pad) * GameMap.TILE
		var z := minf(540.0 / w, 960.0 / h) / 2.0
		var focus := OS.get_environment("OV_FOCUS")
		if focus != "":
			z = 1.0
			var fx := focus.split(",")
			var fc := m.cell_center(Vector2i(int(fx[0]), int(fx[1])))
			w = int(fc.x * 2.0)
			h = int(fc.y * 2.0)
		cam.zoom = Vector2(z, z)
		cam.position_smoothing_enabled = false
		cam.limit_left = -100000; cam.limit_top = -100000; cam.limit_right = 100000; cam.limit_bottom = 100000
		cam.global_position = Vector2(w / 2.0, h / 2.0)
		cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
		cam.global_position = Vector2(w / 2.0, h / 2.0) - Vector2(270.0, 480.0) / z / 2.0 * 1.0
		for k in 8: await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/ov_%s.png" % [out, sc])
		if OS.get_environment("OV_BLOCKED") != "":
			# Second shot with every blocked cell tinted red and things green: invisible-wall hunting.
			var dbg := Node2D.new()
			dbg.z_index = 4000
			dbg.draw.connect(func() -> void:
				for c: Vector2i in m.blocked:
					dbg.draw_rect(Rect2(m.cell_pos(c.x, c.y), Vector2(GameMap.TILE, GameMap.TILE)), Color(1, 0, 0, 0.45))
				for c: Vector2i in m.things:
					dbg.draw_rect(Rect2(m.cell_pos(c.x, c.y) + Vector2(4, 4), Vector2(8, 8)), Color(0, 1, 0, 0.7)))
			m.add_child(dbg)
			for k in 4: await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s/bl_%s.png" % [out, sc])
	quit()

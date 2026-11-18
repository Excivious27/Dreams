extends SceneTree
## Dev helper: 1:1 screenshots of a scene at given cells.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/area_shot.gd -- /tmp/out scene:x:y [scene:x:y ...]
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	var arc := OS.get_environment("ARC") if OS.get_environment("ARC") != "" else "penguins"
	GameState.new_run(arc, "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	if OS.get_environment("DAY") != "":
		GameState.run["day"] = int(OS.get_environment("DAY"))
	if OS.get_environment("TIME") != "":
		GameState.run["time"] = int(OS.get_environment("TIME"))
	GameState.run["flags"]["partner_scene"] = true
	GameState.run["quests"] = [{"id": "clear_meadow", "text": "x", "done": true}]
	for i in range(1, args.size()):
		var p: PackedStringArray = args[i].split(":")
		var sc := p[0]
		GameState.run["flags"][sc + "_seen"] = true
		GameMap.next_spawn = Vector2(int(p[1]) * 16 + 8, int(p[2]) * 16 + 8) if p.size() >= 3 else Vector2.ZERO
		change_scene_to_file("res://scenes/%s.tscn" % sc)
		for k in 25:
			await process_frame
		var d := Dialogue.instance(self)
		for k in 8:
			if d.active:
				d._advance(); await process_frame; await process_frame
		var m := current_scene as GameMap
		for e in m.enemies:
			if is_instance_valid(e):
				e.queue_free()
		m.enemies.clear()
		for k in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s_%s.png" % [out, sc, "_".join(p.slice(1))])
	quit()

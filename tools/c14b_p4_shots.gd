extends SceneTree
## Dev helper (C14b P4): frames of a map's magic layer on game time, after dialogue.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/c14b_p4_shots.gd -- /tmp/out scene[:minutes] [...]
func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	DirAccess.make_dir_recursive_absolute(out)
	GameState.new_run(OS.get_environment("ARC") if OS.get_environment("ARC") != "" else "penguins", "kairi", "T", "Town", "Pup")
	for spec in args.slice(1):
		var parts := str(spec).split(":")
		GameState.run["time"] = int(parts[1]) if parts.size() > 1 else 720
		GameState.run["scene"] = parts[0]
		GameMap.next_spawn = Vector2(-1, -1)
		change_scene_to_file("res://scenes/%s.tscn" % parts[0])
		for i in 8:
			await process_frame
		var d := Dialogue.instance(self)
		for k in 40:
			if d.active:
				d._advance()
			await process_frame
		for h in get_nodes_in_group("toast_hold"):
			h.visible = false
		var gt := 0.0
		var shot := 0
		while shot < 3:
			await process_frame
			gt += root.get_process_delta_time()
			if gt > 4.0 + shot * 0.4:
				root.get_texture().get_image().save_png("%s/%s_%s_%d.png" % [out, parts[0], parts[1] if parts.size() > 1 else "720", shot])
				shot += 1
	quit()

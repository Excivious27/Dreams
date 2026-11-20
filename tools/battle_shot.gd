extends SceneTree
## Battle HUD screenshots: a field's first seconds (intro line, toasts, battle
## bar, objective banner), then with the brief closed.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/battle_shot.gd -- /tmp/out bf_bog_crossing [gangsters]
## Desktop: --resolution 1280x720 (DisplayMode widens the view).


func _initialize() -> void:
	Campaign.bypass = true
	seed(5)
	_run.call_deferred()


func _shot(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var sc := args[1] if args.size() > 1 else "bf_bog_crossing"
	DirAccess.make_dir_recursive_absolute(out)
	GameState.new_run("gangsters" if "gangsters" in args else "penguins", "mom", "T", "Town", "Pup")
	GameState.run["flags"]["proj_war_table"] = true
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/%s.tscn" % sc)
	for i in 20:
		await process_frame
	await _shot(out, sc + "_t0")
	for i in 40:
		await process_frame
	await _shot(out, sc + "_t1")
	var d := Dialogue.instance(self)
	for i in 120:
		if d.active:
			if d._in_choice:
				d._choose("", d._choices.get_child_count() - 1)
			else:
				d._advance()
		await process_frame
	await _shot(out, sc + "_t2")
	quit(0)

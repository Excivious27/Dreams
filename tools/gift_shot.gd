extends SceneTree
## Dev helper: a few Marked mid-fight, as PNGs.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/gift_shot.gd -- /tmp/shots
func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	_run.call_deferred()

func _run() -> void:
	var out := "/tmp/shots"
	if OS.get_cmdline_user_args().size() > 0:
		out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	GameState.new_run("gangsters", "nia", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	for id in ["juno", "ember", "tomas", "atlas", "dahlia", "rio"]:
		GameMap.next_spawn = Vector2(30 * 16, 30 * 16)
		change_scene_to_file("res://scenes/farm.tscn")
		for i in 30:
			await process_frame
		var m := current_scene as GameMap
		var d := Dialogue.instance(self)
		for i in 20:
			if d.active:
				Input.action_press("a"); await process_frame; Input.action_release("a")
			await process_frame
		m.player.invuln = 9999.0
		var e := Marked.spawn(m, id, m.player.position + Vector2(44, -30))
		if id == "tomas":
			await process_frame
			e.hit(int(e.max_hp * 0.3) + 1, m.player.position)
		for k in 3:
			for i in [150, 70, 60][k]:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/gift_%s_%d.png" % [out, id, k])
	quit()

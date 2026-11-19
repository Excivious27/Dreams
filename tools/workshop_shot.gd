extends SceneTree
## Dev helper: the farm with every station built and a bed of crops, as PNGs.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/workshop_shot.gd -- /tmp/shots
func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	_run.call_deferred()

func _run() -> void:
	var out := "/tmp/shots"
	if OS.get_cmdline_user_args().size() > 0:
		out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	for arc in ["gangsters", "penguins"]:
		GameState.new_run(arc, "dad" if arc == "gangsters" else "kairi", "T", "Town", "Pup")
		GameState.run["intro_done"] = true
		GameState.run["flags"]["partner_scene"] = true
		GameState.run["builds"] = {}
		for id in Builds.data():
			GameState.run["builds"][id] = mini(3, (Builds.data()[id]["tiers"] as Array).size())
		var names: Array = GameState.crops.keys()
		for i in 60:
			var cid := str(names[(i * 7) % names.size()])
			GameState.run["farm"]["%d,%d" % [18 + (i % 10) * 2, 19 + (i / 10) * 2]] = {"crop": cid, "days": int(GameState.crops[cid]["days"]) if i % 3 != 0 else 1, "watered": i % 2 == 0}
		for spot in [Vector2(9, 18), Vector2(27, 24), Vector2(14, 23)]:
			GameMap.next_spawn = spot * 16.0
			change_scene_to_file("res://scenes/farm.tscn")
			for i in 30:
				await process_frame
			var d := Dialogue.instance(self)
			for i in 20:
				if d.active:
					Input.action_press("a"); await process_frame; Input.action_release("a")
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/workshop_%s_%d_%d.png" % [out, arc, int(spot.x), int(spot.y)])
	quit()

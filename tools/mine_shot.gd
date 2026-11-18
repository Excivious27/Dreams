extends SceneTree
## Dev helper: screenshots of mine floors.  -- /tmp/out 1 45 105 150
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := str(args[0]) if args.size() > 0 else "/tmp/shots"
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["mine_seen"] = true
	GameState.run["flags"]["partner_scene"] = true
	for a in args.slice(1):
		GameState.run["mine_floor"] = int(a)
		change_scene_to_file("res://scenes/mine.tscn")
		for i in 40:
			await process_frame
		var m := current_scene as GameMap
		var d := Dialogue.instance(self)
		for i in 20:
			if d.active:
				d._advance() if not d._in_choice else d._choose("", 0)
			await process_frame
		var n := 0
		for c in m.things:
			if str(m.things[c].get("type", "")) in ["forage", "crate", "mchest", "bigchest"]:
				n += 1
		print("floor ", a, " ", m.cols, "x", m.rows, " findables=", n, " enemies=", m.enemies.size())
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/mine_%s.png" % [out, a])
	quit()

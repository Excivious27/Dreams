extends SceneTree
## Screenshots of the weather layer: forest with each weather.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/weather_shot.gd -- /tmp/out [scene] [w1,w2,...] [minutes]
func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp/wx"
	var sc := args[1] if args.size() > 1 else "forest"
	var list: PackedStringArray = (args[2] if args.size() > 2 else "leaves,petals,storm,blizzard,snow,fireflies").split(",")
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["time"] = int(args[3]) if args.size() > 3 else 11 * 60
	GameState.run["flags"][sc + "_seen"] = true
	GameState.run["flags"]["partner_scene"] = true
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/%s.tscn" % sc)
	for i in 30:
		await process_frame
	var m := current_scene as GameMap
	for w in list:
		m.sky.process_mode = Node.PROCESS_MODE_ALWAYS
		m.sky._canvas.process_mode = Node.PROCESS_MODE_ALWAYS
		m.sky.weather = w
		for i in 90:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s_%s.png" % [out, sc, w])
	quit(0)

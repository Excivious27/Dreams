extends SceneTree
## Screenshots for dating/marriage (C7 P1): the Farmhouse with the spouse and their
## corner, a spouse line with the blush portrait, the wedding panel line.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/romance_shot.gd -- /tmp/out [id]
func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _shot(out: String, name: String) -> void:
	for k in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/rom_%s.png" % [out, name])


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var id := args[1] if args.size() > 1 else "lumi"
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	GameState.new_run(OS.get_environment("ARC") if OS.get_environment("ARC") != "" else "penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	if not GameState.run.get("builds") is Dictionary:
		GameState.run["builds"] = {}
	GameState.run["builds"]["house"] = 2
	var s := Romance.st()
	s["spouse"] = id
	s["married_day"] = int(GameState.run["day"])
	GameState.run["day"] = 3  # not a job day for lumi (job days 2, 4)
	GameState.run["time"] = 11 * 60
	GameMap.next_spawn = Vector2(15 * 16 + 8, 8 * 16 + 8)
	change_scene_to_file("res://scenes/house.tscn")
	for k in 30:
		await process_frame
	var m := current_scene as GameMap
	var d := Dialogue.instance(self)
	while d.active:
		d._advance()
		await process_frame
	await _shot(out, "house_" + id)
	m.say([{"who": Romance.name_of(id), "text": Romance.spouse_line(id), "mood": "love"}])
	await _shot(out, "talk_" + id)
	d._advance()
	await process_frame
	m.say([{"text": "Your wedding day.", "pic": "cut_wedding_penguins" if GameState.is_penguins() else "cut_wedding_gangsters"}])
	await _shot(out, "wedding")
	quit(0)

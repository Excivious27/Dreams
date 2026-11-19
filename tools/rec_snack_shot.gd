extends SceneTree
## Snack bar menu screenshot upstairs at the rec (c2_04).
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/rec_snack_shot.gd -- /tmp/out
var out := "/tmp/rec"


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _shot(name: String) -> void:
	for k in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	var arc := OS.get_environment("ARC") if OS.get_environment("ARC") != "" else "penguins"
	GameState.new_run(arc, "kairi" if arc == "penguins" else "dad", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	for f in ["town_seen", "town_tour", "partner_scene", "rec_visited", "interior_seen", "int_rec", "int_rec_up"]:
		GameState.run["flags"][f] = true
	GameState.run["flags"]["rec_open"] = 1
	GameState.run["day"] = 10
	GameState.run["time"] = 16 * 60
	GameState.run["crystals"] = 240
	GameMap.next_interior = "rec_up"
	GameMap.next_spawn = Vector2(10 * 16 + 8, 15 * 16 + 8)
	change_scene_to_file("res://scenes/interior.tscn")
	for k in 25:
		await process_frame
	var d := Dialogue.instance(self)
	for k in 8:
		if d.active:
			d._advance()
			await process_frame
			await process_frame
	var m := current_scene as GameMap
	RecCenter.use(m, {"act": "snack"}, Vector2i(10, 16))
	for k in 30:
		await process_frame
	await _shot("snack_menu_" + arc.left(1))
	quit()

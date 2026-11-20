extends SceneTree
## Screenshots of decorate mode (C10b P2): the house with the bar, the paged box
## list, and the yard on the farm with the Decorate yard button.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/decor_mode_shot.gd -- /tmp/dshots
var out := "/tmp/dshots"


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	Campaign.bypass = true
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func shot(name: String) -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out + "/" + name + ".png")


func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["time"] = 12 * 60
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	var n := 0
	for id in Decor.data()["items"]:
		if n < 80 and DecorMode.placeable(str(id)) or DecorMode.is_surface(str(id)):
			Decor.give(str(id), 1)
			n += 1
	change_scene_to_file("res://scenes/farm.tscn")
	await frames(30)
	var f := current_scene as GameMap
	for k in 40:
		if Dialogue.instance(self).active:
			Dialogue.instance(self)._advance()
		await frames(2)
	await shot("farm_button")
	# A test path + statue (injected entries) to check the flat layer and standing pieces.
	var items: Dictionary = Decor.data()["items"]
	items["t_shot_path"] = {"name": "Cobble Path", "cat": "outdoor_path", "layer": "outdoor", "seam": "cobble_warm", "sub": "path", "size": [1, 1], "rot": 1, "art": "props/birdbath", "rarity": "common", "arc": ""}
	items["t_shot_bath"] = {"name": "Bird Bath", "cat": "outdoor_statue", "layer": "outdoor", "size": [1, 1], "rot": 1, "art": "props/birdbath", "rarity": "common", "arc": ""}
	Decor.give("t_shot_path", 12)
	Decor.give("t_shot_bath", 2)
	var pc: Vector2i = f.player.cell()
	for k in 8:
		DecorMode.place(f, "t_shot_path", pc + Vector2i(2 + k, 2))
	print("bath: ", DecorMode.place(f, "t_shot_bath", pc + Vector2i(3, 4)), " path: ", DecorMode.why_not(f, "t_shot_path", pc + Vector2i(2, 2)), " at ", pc)
	await shot("yard_pieces")
	var dm := DecorMode.open(f)
	await frames(4)
	if dm:
		await shot("yard_mode")
		dm._toggle_list()
		await shot("yard_list")
		dm.close()
	change_scene_to_file("res://scenes/house.tscn")
	await frames(30)
	for k in 40:
		if Dialogue.instance(self).active:
			Dialogue.instance(self)._advance()
		await frames(2)
	var h := current_scene as GameMap
	await shot("house_button")
	dm = DecorMode.open(h)
	await frames(4)
	if dm:
		await shot("house_mode")
		dm._toggle_list()
		await shot("house_list")
	quit(0)

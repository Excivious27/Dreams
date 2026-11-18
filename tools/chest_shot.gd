extends SceneTree
## Dev helper: screenshot of the chest screen and the Items tab.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/chest_shot.gd -- /tmp/out
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	for id in ["turnip", "potato", "carrot", "stone", "wood", "copper", "fiber", "sap", "bread", "potion"]:
		GameState.add_item(id, 12)
	for id in ["wood", "stone", "iron", "coal", "clay"]:
		Storage.box("chest")["items"][id] = 40
	GameState.run["builds"] = GameState.run.get("builds", {})
	change_scene_to_file("res://scenes/farm.tscn")
	for k in 25:
		await process_frame
	var d := Dialogue.instance(self)
	for k in 8:
		if d.active:
			d._advance(); await process_frame; await process_frame
	var m := current_scene as GameMap
	ChestScreen.open(m, "chest", "Chest")
	for k in 15:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/chest.png")
	quit()

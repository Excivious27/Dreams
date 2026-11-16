extends SceneTree
## Dev helper: renders the test map and saves PNGs to the path given after "--".
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var out_dir := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	var node: Node = (load("res://scenes/test_map.tscn") as PackedScene).instantiate()
	root.add_child(node)
	for i in 30: await process_frame
	root.get_texture().get_image().save_png(out_dir + "/shot_idle.png")
	Input.action_press("right"); Input.action_press("b")
	for i in 40: await process_frame
	root.get_texture().get_image().save_png(out_dir + "/shot_run.png")
	Input.action_release("right"); Input.action_release("b")
	Input.action_press("menu"); await process_frame; Input.action_release("menu")
	Input.action_press("menu"); await process_frame; Input.action_release("menu")
	Input.action_press("down")
	for i in 20: await process_frame
	root.get_texture().get_image().save_png(out_dir + "/shot_down.png")
	quit()

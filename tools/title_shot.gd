extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var t: Node = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	root.add_child(t); current_scene = t
	for i in 20: await process_frame
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/title.png")
	quit()

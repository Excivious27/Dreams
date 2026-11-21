extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	InputSetup.ensure_actions()
	change_scene_to_file("res://scenes/title.tscn")
	for i in 20: await process_frame
	var le := LineEdit.new()
	le.text = "ROOM"
	root.add_child(le)
	TextEntry.steam_force = 0
	TextEntry.open(le)
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/p3_kb.png")
	quit()

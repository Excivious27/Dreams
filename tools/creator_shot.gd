extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var t: Node = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	root.add_child(t); current_scene = t
	for i in 10: await process_frame
	var cr := Creator.new(PaperDoll.random_look(), "", true)
	var page: Control = t.get("_page")
	for c in page.get_children(): c.queue_free()
	page.add_child(cr)
	for i in 15: await process_frame
	root.get_texture().get_image().save_png("/tmp/cshots/creator.png")
	for c in page.get_children(): c.queue_free()
	var cr2 := Creator.new({}, "penguin", true)
	page.add_child(cr2)
	for i in 15: await process_frame
	root.get_texture().get_image().save_png("/tmp/cshots/creator_penguin.png")
	quit()

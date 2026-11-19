extends SceneTree
## Dev helper: the hero picker for each arc as PNGs.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/title_shot.gd -- /tmp/shots
func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	_run.call_deferred()

func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp/shots"
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://scenes/title.tscn")
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/title.png")
	var t := current_scene
	for arc in ["penguins", "gangsters"]:
		t.set("_arc", arc)
		t.call("_show_characters")
		for i in 10:
			await process_frame
		for sc in t.find_children("*", "ScrollContainer", true, false):
			(sc as ScrollContainer).scroll_vertical = 100000 if arc == "penguins" else 0
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/pick_%s.png" % [out, arc])
	quit()

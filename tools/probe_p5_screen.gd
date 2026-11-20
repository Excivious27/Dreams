extends SceneTree
## Probe (C10b P5): wardrobe screen + Hero tab shots at large text.
func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _shot(n: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/p5/%s.png" % n)


func _go(arc: String, pid: String) -> GameMap:
	GameState.new_run(arc, pid, "Robin", "X", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	if pid == "custom":
		GameState.run["look"] = {"body": "medium_slim", "hair": PaperDoll.hair_styles()[0], "hair_color": "red", "hat": "", "outfit": "outfit_farmer"}
	change_scene_to_file("res://scenes/farm.tscn")
	for i in 30:
		await process_frame
	var d := Dialogue.instance(self)
	for i in 40:
		if d.active:
			Input.action_press("a"); await process_frame; Input.action_release("a")
		await process_frame
	return current_scene as GameMap


func _run() -> void:
	InputSetup.ensure_actions()
	Settings.set_v("text_size", 2)
	var m := await _go("gangsters", "custom")
	for id in ["wr_outfit_pinstripe", "wr_fedora", "wr_cape_black"]:
		Decor.give(id); Wardrobe.put_on(id)
	var ws := WardrobeScreen.open(m)
	ws.sel = "wr_fedora"; ws.slot = "hat"; ws._build()
	await _shot("ws_custom_t2")
	ws._close()
	m = await _go("penguins", "penguin_f")
	for id in ["wr_scarf_red", "wr_goggles_ice"]:
		Decor.give(id); Wardrobe.put_on(id)
	ws = WardrobeScreen.open(m)
	await _shot("ws_nova_t2")
	ws._close()
	Settings.set_v("text_size", 0)
	m = await _go("gangsters", "rafe")
	for id in ["wr_fedora", "wr_shades"]:
		Decor.give(id); Wardrobe.put_on(id)
	m.player.refresh_doll()
	ws = WardrobeScreen.open(m)
	await _shot("ws_rafe")
	ws._close()
	await _shot("rafe_field")
	quit()

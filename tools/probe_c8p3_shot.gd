extends SceneTree
func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()
func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["time"] = 720
	for id in ["coal", "ruby", "gold", "fossil", "relic_crown", "bass", "trout", "seashell", "luna_moth", "old_coin", "emerald"]:
		GameState.add_item(id, 1, true)
		Collections.donate(id)
	Collections.record_catch("bass")
	GameMap.next_interior = "museum"
	GameMap.next_spawn = Vector2(8 * 16 + 8, 8 * 16 + 8)
	change_scene_to_file("res://scenes/interior.tscn")
	for i in 40:
		await process_frame
	var d := Dialogue.instance(self)
	for i in 30:
		if d.active:
			d._advance()
		await process_frame
	var out := OS.get_cmdline_user_args()[0]
	root.get_texture().get_image().save_png(out + "/museum.png")
	var gm: GameMenu = null
	for ch in current_scene.get_children():
		if ch is GameMenu:
			gm = ch
	GameMenu.open_page(self, "Book", "")
	for i in 10:
		await process_frame
	root.get_texture().get_image().save_png(out + "/book.png")
	CollectionScreen.open("museum")
	CollectionScreen.sel = "ruby"
	gm._refresh()
	for i in 10:
		await process_frame
	root.get_texture().get_image().save_png(out + "/book_museum.png")
	quit(0)

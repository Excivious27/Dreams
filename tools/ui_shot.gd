extends SceneTree
## Dev helper: screenshots of the new screens (crafting, options, save slots, relationships).
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/ui_shot.gd -- /tmp/shots
func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	_run.call_deferred()

func _shot(out: String, name: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/ui_%s.png" % [out, name])

func _run() -> void:
	var out := "/tmp/shots"
	if OS.get_cmdline_user_args().size() > 0:
		out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	GameState.run["builds"] = {"furnace": 2, "workbench": 2}
	GameState.add_item("copper", 7)
	GameState.add_item("coal", 3)
	GameState.add_item("stone", 20)
	GameState.add_item("wood", 30)
	GameState.add_item("turnip", 5)
	GameState.add_quality("turnip", "g", 2)
	change_scene_to_file("res://scenes/farm.tscn")
	for i in 30:
		await process_frame
	var m := current_scene as GameMap
	var d := Dialogue.instance(self)
	for i in 30:
		if d.active:
			Input.action_press("a"); await process_frame; Input.action_release("a")
		await process_frame
	Crafting.run(m, "furnace")
	await _shot(out, "craft_furnace")
	for c in m.get_children():
		if c is CraftScreen:
			var cs := c as CraftScreen
			var rcs: Array = Crafting.available("furnace", 2)
			if not rcs.is_empty():
				cs._sel = rcs[0]
				cs._refresh()
			await _shot(out, "craft_picked")
			cs.close()
	await process_frame
	var menu: GameMenu = null
	for c in m.get_children():
		if c is GameMenu:
			menu = c
	if menu:
		menu.toggle()
		GameState.run["skills"]["farming"]["level"] = 9
		GameState.buy_node("farming", "green_thumb")
		GameState.buy_node("farming", "farming_1_0")
		GameState.buy_node("farming", "farming_1_0")
		GameState.buy_node("farming", "quick_hands")
		menu._node_sel = "green_thumb"
		for t in ["Skills", "Items", "Options", "Social"]:
			menu._tab = t
			menu._refresh()
			await _shot(out, "menu_" + t.to_lower())
		menu.toggle()
	await process_frame
	HackGame.play(m, 2)
	for i in 40:
		await process_frame
	await _shot(out, "hack")
	for c in m.get_children():
		if c is HackGame:
			(c as HackGame)._finish()
	await process_frame
	GameState.run["ending"] = "revert"
	GameState.add_friend("maple", 200)
	Epilogue.play(m)
	await _shot(out, "epilogue_1")
	for c in m.get_children():
		if c is Epilogue:
			var ep := c as Epilogue
			ep._arm = 20
			ep._next()
			await _shot(out, "epilogue_2")
			ep._arm = 20
			ep._next()
			ep._arm = 20
			ep._next()
			await _shot(out, "epilogue_4")
			ep._close()
	quit()

extends SceneTree
## Dev helper: goal-line campaign pointer, Map tab (Campaign map button, locked pins), board with a toast hidden.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/campaign_ui_shot_g.gd -- OUT
func _initialize() -> void:
	_run.call_deferred()

func shot(out: String, n: String) -> void:
	for k in 6:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, n])

func _run() -> void:
	var out := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	var arc := OS.get_environment("ARC") if OS.get_environment("ARC") != "" else "penguins"
	GameState.new_run(arc, "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	GameState.run["quests"] = [{"id": "clear_meadow", "text": "x", "done": true}, {"id": "hideout", "text": "x", "done": true}]
	var q := "wastes_gate" if arc == "penguins" else "docks"
	GameState.add_quest(q, str(GameState._quest_def(q)["text"]))
	change_scene_to_file("res://scenes/farm.tscn")
	for k in 30:
		await process_frame
	var d := Dialogue.instance(self)
	for k in 8:
		if d.active:
			d._advance(); await process_frame; await process_frame
	var m := current_scene as GameMap
	GameState.run["quests"] = [{"id": "clear_meadow", "text": "x", "done": true}, {"id": "hideout", "text": "x", "done": true}, {"id": "first_harvest", "text": "x", "done": true}, {"id": "cattopia", "text": "x", "done": true}]
	GameState.add_quest(q, str(GameState._quest_def(q)["text"]))
	print("goal: ", GameState.next_step())
	await shot(out, arc + "_goal")
	for c in m.get_children():
		if c is GameMenu:
			(c as GameMenu)._tab = "Map"
			(c as GameMenu).toggle()
	await shot(out, arc + "_maptab")
	var pressed := false
	for c in m.get_children():
		if c is GameMenu:
			for b in (c as GameMenu).find_children("*", "Button", true, false):
				if (b as Button).text.begins_with("Campaign map") and not pressed:
					pressed = true
					(b as Button).pressed.emit()
	print("menu button pressed: ", pressed)
	for k in 10:
		await process_frame
	m.hud.toast("This toast should not show over the board.", Color.WHITE)
	await shot(out, arc + "_board")
	quit()

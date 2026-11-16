extends SceneTree
## Dev helper: renders a set of situations and saves PNGs to the path after "--".
var out := "/tmp"
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		out = OS.get_cmdline_user_args()[0]
	InputSetup.ensure_actions()
	await _shoot("res://scenes/title.tscn", "title", 30)
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["town_seen"] = true
	GameState.run["flags"]["meadow_seen"] = true
	GameState.run["flags"]["mine_seen"] = true
	GameState.run["quests"] = [{"id": "clear_meadow", "text": "x", "done": true}]
	await _scene("farm", "farm_spring", 40)
	var f := current_scene
	f.player.position = f.cell_center(Vector2i(12, 9)); f.player.facing = "up"
	GameState.run["farm"]["12,8"] = {"watered": true, "crop": "strawberry", "days": 5}
	f.queue_redraw()
	Input.action_press("a"); await frames(8); Input.action_release("a")
	await frames(2)
	await _shot("farm_hoe")
	await frames(40)
	# Talk to the crystal with a portrait.
	Dialogue.instance(self).say([{"who": "Light Crystal", "text": "Portrait test.", "mood": "happy"}])
	await frames(30)
	await _shot("dialogue_portrait")
	Input.action_press("a"); await frames(3); Input.action_release("a"); await frames(5)
	Input.action_press("a"); await frames(3); Input.action_release("a"); await frames(5)
	for sc in ["forest", "lake", "beach", "mountain", "crystal_meadow", "moon"]:
		GameState.run["flags"]["moon_unlocked"] = true
		await _scene(sc, sc, 45)
	GameState.run["day"] = 60   # fall
	await _scene("farm", "farm_fall", 40)
	GameState.run["day"] = 95   # winter
	await _scene("farm", "farm_winter", 40)
	GameState.run["day"] = 2
	await _scene("house", "house", 40)
	await _scene("town", "town", 40)
	var t := current_scene
	t.player.position = t.cell_center(Vector2i(8, 11)); t.player.facing = "up"
	await frames(5)
	await _shot("town_closeup")
	await _scene("meadow", "meadow", 50)
	GameState.run["mine_floor"] = 5
	await _scene("mine", "mine5", 50)
	# Gangster arc
	GameState.new_run("gangsters", "dad", "Dad", "Dreamhollow", "Rex")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["meadow_seen"] = true
	GameState.run["quests"] = [{"id": "clear_meadow", "text": "x", "done": true}]
	await _scene("meadow", "gang_meadow", 50)
	for sc in ["hideout", "docks", "neon", "uptown", "underground", "countryside"]:
		GameState.run["flags"][sc + "_seen"] = true
		await _scene(sc, sc, 50)
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	for sc in ["wastes", "sky", "station", "jungle"]:
		GameState.run["flags"][sc + "_seen"] = true
		await _scene(sc, sc, 50)
	GameState.run["flags"]["town_seen"] = true
	await _scene("farm", "farm_map_open", 30)
	Input.action_press("menu"); await frames(3); Input.action_release("menu"); await frames(10)
	var gm := Dialogue.instance(self).get_parent().get_node_or_null("GameMenu")
	await frames(5)
	await _shot("menu_items")
	quit()
func _scene(name: String, shot_name: String, n: int) -> void:
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/%s.tscn" % name)
	await frames(n)
	var d := Dialogue.instance(self)
	for i in 12:
		if not d.active:
			break
		Input.action_press("a"); await frames(3); Input.action_release("a"); await frames(6)
	await frames(10)
	await _shot(shot_name)
func _shoot(scene: String, shot_name: String, n: int) -> void:
	change_scene_to_file(scene)
	await frames(n)
	await _shot(shot_name)
func _shot(name: String) -> void:
	await frames(2)
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
func frames(n: int) -> void:
	for i in n:
		await process_frame

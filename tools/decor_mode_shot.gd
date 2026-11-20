extends SceneTree
## Screenshots of decorate mode (C10a P2): the Manor with placed decor, room
## wallpaper/flooring and the open decorate screen with a ghost.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/decor_mode_shot.gd -- /tmp/out
var out := "/tmp/decor_shots"


func _initialize() -> void:
	Campaign.bypass = true
	var a := OS.get_cmdline_user_args()
	if not a.is_empty():
		out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _ent(name: String, layer: String, size: Array, art: String, extra := {}) -> Dictionary:
	var e := {"name": name, "cat": "furniture", "rarity": "rare", "arc": "", "layer": layer, "size": size, "rot": 1,
		"glow": false, "art": art, "icon": art, "price": 100, "sell": 25, "sources": ["test"], "set": ""}
	e.merge(extra, true)
	return e


func _shot(n: String) -> void:
	await frames(4)
	get_root().get_texture().get_image().save_png(out + "/" + n + ".png")


func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["time"] = 12 * 60
	GameState.run["builds"] = {"house": int(OS.get_environment("TIER")) if OS.get_environment("TIER") != "" else 3}
	var items: Dictionary = Decor.data()["items"]
	if items.is_empty():
		items["t_lamp"] = _ent("Floor Lamp", "floor", [1, 1], "furniture/lamp_floor", {"glow": true})
		items["t_table"] = _ent("Round Table", "floor", [2, 1], "furniture/table_round_cloth")
		items["t_chair"] = _ent("Chair", "floor", [1, 1], "furniture/chair_down")
		items["t_arm"] = _ent("Armchair", "floor", [2, 1], "furniture/armchair_a", {"rarity": "epic"})
		items["t_rug"] = _ent("Red Rug", "under", [4, 2], "furniture/rug_rect_red")
		items["t_paint"] = _ent("Painting", "wall", [1, 1], "furniture/painting_a")
		items["t_wall"] = _ent("Striped Paper", "wallpaper", [1, 1], "tiles/wl_striped")
		items["t_floor"] = _ent("Dark Boards", "flooring", [1, 1], "tiles/fl_wood_dark")
	change_scene_to_file("res://scenes/house.tscn")
	await frames(20)
	var d := Dialogue.instance(self)
	for k in 60:
		if not d.active:
			break
		d._advance()
		await frames(2)
	var m := current_scene as GameMap
	for id in ["t_arm", "t_paint", "t_paint", "t_wall", "t_floor", "t_chair"]:
		Decor.give(id, 1)
	print("arm: ", DecorMode.place(m, "t_arm", Vector2i(9, 5)))
	print("paint: ", DecorMode.place(m, "t_paint", Vector2i(3, 1)))
	print("paint2: ", DecorMode.place(m, "t_paint", Vector2i(17, 1)))
	if m.has_method("decor_rooms") and (m.call("decor_rooms") as Dictionary).has("study"):
		print("wall: ", DecorMode.set_surface(m, "study", "t_wall"))
		print("floor: ", DecorMode.set_surface(m, "study", "t_floor"))
	await frames(30)
	await _shot("house_decor")
	var dm := DecorMode.open(m)
	await frames(3)
	dm.held = "t_chair"
	dm.cursor = Vector2i(6, 9)
	dm._refresh()
	await _shot("decor_mode_ok")
	dm.cursor = Vector2i(12, 3)
	dm._refresh()
	await _shot("decor_mode_bad")
	dm._toggle_list()
	await _shot("decor_box")
	dm._toggle_list()
	dm.held = ""
	dm.cursor = Vector2i(19, 6)
	dm._refresh()
	await _shot("decor_study")
	quit()

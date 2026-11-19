extends SceneTree
## Agent C check: an old save with a crop, a sprinkler and a placed chest on
## what is now river comes through: seed back, things moved, chest contents kept.
func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	_run.call_deferred()

func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	var rc := Vector2i(20, 45)  # river at x=20 (centre ~45)
	GameState.run["farm"]["%d,%d" % [rc.x, rc.y]] = {"crop": "turnip", "age": 1}
	GameState.run["farm"]["12,42"] = {"crop": "", "age": 0}
	GameState.run["placed"] = {"21,45": "sprinkler", "22,45": "chest_item"}
	GameState.run["chests"] = {"p:22,45": [{"id": "wood", "n": 5}]}
	var seeds0 := GameState.count("turnip_seed")
	change_scene_to_file("res://scenes/farm.tscn")
	for k in 20:
		await process_frame
	var m := current_scene as GameMap
	var ok := true
	for k in ["20,45", "21,45", "22,45"]:
		var xy: PackedStringArray = str(k).split(",")
		if not m.is_water_cell(Vector2i(int(xy[0]), int(xy[1]))):
			print("NOTE: %s is not river in this layout" % k)
	print("farm keys on river: ", GameState.run["farm"].has("20,45"), " deck soil: ", GameState.run["farm"].has("12,42"))
	print("seed back: ", GameState.count("turnip_seed") - seeds0)
	print("placed now: ", GameState.run["placed"])
	print("chests now: ", GameState.run["chests"].keys())
	for k in GameState.run["placed"]:
		var xy := str(k).split(",")
		if m.is_water_cell(Vector2i(int(xy[0]), int(xy[1]))):
			ok = false
	print("RIVER MIGRATE ", "OK" if ok and not GameState.run["farm"].has("20,45") else "FAIL")
	quit()

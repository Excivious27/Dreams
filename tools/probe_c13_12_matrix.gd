extends SceneTree
## Auditor probe c13_12 (read-only): the place/state -> song matrix that area_track() gives today.
## Writes /tmp/c13_12/matrix.tsv: arc map day season weather time night track
var out: FileAccess


func _initialize() -> void:
	seed(12)
	Campaign.bypass = true
	InputSetup.ensure_actions()
	GameState.load_data()
	_run.call_deferred()


func _scene_ids() -> Array:
	var ids: Array = []
	for f in DirAccess.get_files_at("res://scenes"):
		var n := f.trim_suffix(".remap").trim_suffix(".tscn")
		if f.ends_with(".tscn") or f.ends_with(".tscn.remap"):
			if n not in ["title", "test_map", "interior"] and not ids.has(n):
				ids.append(n)
	ids.sort()
	return ids


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/c13_12")
	out = FileAccess.open("/tmp/c13_12/matrix.tsv", FileAccess.WRITE)
	var interiors := GameState.load_json("res://data/interiors.json")
	var days := [5, 14, 33, 42, 61, 70, 89, 98]
	for arc: String in ["penguins", "gangsters"]:
		GameState.new_run(arc, "man", "Tester", "Dreamhollow", "Pip")
		GameState.run["intro_done"] = true
		for f in ["cm_seen", "mine_open_1", "meow_taught", "moon_seen", "mine_seen", "intro_done", "gangsters_intro"]:
			GameState.run["flags"][f] = true
		var maps := _scene_ids()
		for id: String in maps:
			GameState.run["flags"][id + "_seen"] = true
		var jobs: Array = []
		for id: String in maps:
			jobs.append([id, ""])
		for iid: String in interiors:
			if interiors[iid] is Dictionary:
				jobs.append(["interior", iid])
		for j: Array in jobs:
			GameMap.next_spawn = Vector2.ZERO
			GameMap.next_interior = str(j[1])
			GameState.run["day"] = 5
			GameState.run["weather"] = {"4": "clear", "5": "clear", "6": "clear"}
			GameState.run["time"] = 600
			change_scene_to_file("res://scenes/%s.tscn" % j[0])
			for i in 4:
				await process_frame
			var m := current_scene as GameMap
			var label := str(j[0]) + ((":" + str(j[1])) if str(j[1]) != "" else "")
			if m == null:
				out.store_line("%s\t%s\tLOADFAIL" % [arc, label])
				continue
			if m.sky != null:
				m.sky.weather = "clear"
			for d: int in days:
				for w: String in ["clear", "rain", "snow"]:
					for t: int in [420, 720, 1140, 1320, 1500]:
						GameState.run["day"] = d
						GameState.run["weather"] = {str(d - 1): "clear", str(d): w, str(d + 1): "clear"}
						GameState.run["time"] = t
						out.store_line("%s\t%s\t%d\t%s\t%s\t%d\t%s\t%s" % [arc, label, d, GameState.season(), w, t,
							"1" if GameState.is_night() else "0", m.area_track()])
			out.flush()
	# Combat / boss tiers per arc
	for arc: String in ["penguins", "gangsters"]:
		GameState.new_run(arc, "man", "Tester", "Dreamhollow", "Pip")
		for tr in [1, 2, 3]:
			out.store_line("%s\tTIER\t%d\t%s" % [arc, tr, DangerMusic.tier_track(tr)])
	out.close()
	print("probe_c13_12: done")
	quit(0)

extends SceneTree
## c13_07 probe (read-only): footstep words as an ASCII grid per map.

func _initialize() -> void:
	Campaign.bypass = true
	InputSetup.ensure_actions()
	GameState.load_data()
	_run.call_deferred()

func _run() -> void:
	for cs: Array in [["beach", "penguins"], ["mine", "penguins"], ["farm", "gangsters"]]:
		GameState.new_run(str(cs[1]), "man", "Tester", "Dreamhollow", "Pip")
		GameState.run["intro_done"] = true
		GameState.run["day"] = 8
		for f in ["cm_seen", "mine_open_1", "meow_taught", "intro_done", "gangsters_intro", str(cs[0]) + "_seen"]:
			GameState.run["flags"][f] = true
		GameMap.next_spawn = Vector2.ZERO
		change_scene_to_file("res://scenes/%s.tscn" % cs[0])
		for i in 8:
			await process_frame
		var m := current_scene as GameMap
		if m == null:
			print("no map ", cs)
			continue
		var pc: Vector2i = m.player.cell() if m.player else Vector2i.ZERO
		print("== %s/%s cols %d rows %d player %s theme %s" % [cs[1], cs[0], m.cols, m.rows, pc, str(m.get("theme")).substr(0, 80)])
		var cnt := {}
		for y in range(maxi(0, pc.y - 14), mini(m.rows, pc.y + 24)):
			var line := ""
			for x in range(maxi(0, pc.x - 16), mini(m.cols, pc.x + 16)):
				var c := Vector2i(x, y)
				var w := Footsteps.word(m, c)
				var ch := w.substr(0, 1)
				if w == "gravel": ch = "v"
				if w == "stone": ch = "S"
				if w == "snow": ch = "n"
				if c == pc: ch = "@"
				elif m.blocked.has(c): ch = ch.to_upper() if ch != "S" else "#"
				line += ch
				cnt[w] = int(cnt.get(w, 0)) + 1
			print(line)
		print(cnt)
	quit(0)

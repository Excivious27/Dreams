extends SceneTree
## Decor perf probe (C10a P2): draw calls and frame time in the Manor before and
## after filling it with distinct furniture (one texture each), placed by DecorMode.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/decor_perf_probe.gd
func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _measure(label: String) -> void:
	await frames(30)
	var dc := 0.0
	var ms: Array = []
	for i in 60:
		var t0 := Time.get_ticks_usec()
		await process_frame
		ms.append((Time.get_ticks_usec() - t0) / 1000.0)
		dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	ms.sort()
	print("%s: draw calls %.0f, median frame %.1f ms, nodes %d" % [label, dc / 60.0, ms[30], Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])


func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["time"] = 12 * 60
	GameState.run["builds"] = {"house": 3}
	var items: Dictionary = Decor.data()["items"]
	var arts: Array = []
	for f in DirAccess.get_files_at("res://art/gen/furniture"):
		if f.ends_with(".png") and not f.contains("window") and not f.contains("rug"):
			arts.append(f.get_basename())
	arts.sort()
	for i in mini(90, arts.size()):
		items["pp_%d" % i] = {"name": arts[i], "layer": "floor", "size": [1, 1], "rot": 1, "art": "furniture/" + str(arts[i]), "rarity": "common"}
	change_scene_to_file("res://scenes/house.tscn")
	await frames(20)
	var d := Dialogue.instance(self)
	for k in 60:
		if not d.active:
			break
		d._advance()
		await frames(2)
	var m := current_scene as GameMap
	await _measure("Manor as built")
	var n := 0
	for i in mini(90, arts.size()):
		var id := "pp_%d" % i
		Decor.give(id, 1)
		for y in range(3, 11):
			var done := false
			for x in range(1, 25):
				if DecorMode.place(m, id, Vector2i(x, y)) == "":
					n += 1
					done = true
					break
			if done:
				break
	print("placed %d distinct pieces" % n)
	await _measure("Manor full of decor")
	quit()

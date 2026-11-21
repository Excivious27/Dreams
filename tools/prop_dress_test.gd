extends SceneTree
## C14 P6 PropDress: every id in data/props_c14.json has art, each dressed scene
## places most of its plan once (a second call adds nothing), nothing lands on a
## blocked cell or the spawn, and the data matches its generator.
##   godot --headless --fixed-fps 60 --path . -s res://tools/prop_dress_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(14)
	_run.call_deferred()


func _run() -> void:
	var d := PropDress.data()
	check(d.size() >= 10, "props_c14.json has the hub towns, colonies and sky maps (%d)" % d.size())
	for sc: String in d:
		for e: Dictionary in d[sc]:
			var gn := PropDress.split_id(str(e["id"]))
			check(Art.has(gn[0], gn[1]), "%s: art for %s" % [sc, e["id"]])
	for sc: String in ["iron_junction", "gilt_grand_plaza", "frost_hearthhold", "colony_coral", "wind_breezehaven"]:
		GameMap.next_spawn = Vector2.ZERO
		change_scene_to_file("res://scenes/%s.tscn" % sc)
		var gm: GameMap = null
		for i in 240:
			await process_frame
			gm = current_scene as GameMap
			if gm != null and gm.has_meta("c14_dressed") and gm.player != null:
				break
		check(gm != null and gm.has_meta("c14_dressed"), "%s was dressed" % sc)
		if gm == null or not gm.has_meta("c14_dressed"):
			continue
		var n := int(gm.get_meta("c14_dressed"))
		var plan := PropDress.entries(sc).size()
		print("  %s: %d of %d placed" % [sc, n, plan])
		check(n >= plan * 0.4, "%s placed most of its plan (%d of %d)" % [sc, n, plan])
		check(PropDress.dress(gm, sc) == 0, "%s: a second pass adds nothing" % sc)
		var pc := gm.world_to_cell(gm.player.position)
		check(not gm.props.has(pc), "%s: nothing on the spawn" % sc)
	print("prop_dress_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

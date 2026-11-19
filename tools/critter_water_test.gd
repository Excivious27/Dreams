extends SceneTree
## Every fish critter (WorldGen.WATER_CRITTERS) sits in water and every ground
## critter on land, on every outdoor map that spawns critters, after a few
## seconds of wandering. Run:
##   godot --headless --path . --fixed-fps 60 -s res://tools/critter_water_test.gd
## MAPS=a,b picks maps. Exits 1 on any fish on land / walker in water.
const MAPS := ["farm", "town", "forest", "lake", "meadow", "beach", "mountain", "crystal_meadow", "community_farm", "riverlands", "marsh", "jungle", "docks"]
var fails := 0


func _initialize() -> void:
	Campaign.bypass = true
	seed(7)
	_run.call_deferred()


func _check(m: GameMap, s: String, when: String) -> int:
	var fish := 0
	for n in m.get_children():
		if not (n is WorldGen.Critter):
			continue
		var cr := n as WorldGen.Critter
		var c := m.world_to_cell(cr.position - Vector2(0, 2))
		if cr.kind in WorldGen.WATER_CRITTERS:
			fish += 1
			if not m.is_water_cell(c):
				fails += 1
				print("FAIL %s %s: %s on land at %s" % [s, when, cr.kind, c])
		elif not cr._flyer and m.is_water_cell(c):
			fails += 1
			print("FAIL %s %s: %s standing in water at %s" % [s, when, cr.kind, c])
	return fish


func _run() -> void:
	InputSetup.ensure_actions()
	var only := OS.get_environment("MAPS")
	var list: Array = Array(only.split(",")) if only != "" else MAPS
	for arc in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi", "T", "Town", "Pup")
		GameState.run["intro_done"] = true
		for s in list:
			GameState.run["flags"][s + "_seen"] = true
		for f in ["cm_seen", "mine_open_1", "meow_taught", "moon_seen", "mine_seen", "forest_seen", "lake_seen"]:
			GameState.run["flags"][f] = true
		for s: String in list:
			if not ResourceLoader.exists("res://scenes/%s.tscn" % s):
				continue
			GameMap.next_spawn = Vector2.ZERO
			GameState.run["scene"] = s
			change_scene_to_file("res://scenes/%s.tscn" % s)
			for i in 8:
				await process_frame
			var m := current_scene as GameMap
			if m == null:
				continue
			# Park the player far away so nothing flees, then let them wander.
			if m.player:
				m.player.position = Vector2(-4000, -4000)
			var f0 := _check(m, s, "spawn")
			var gt := 0.0
			while gt < 6.0:
				await process_frame
				gt += root.get_process_delta_time()
			_check(m, s, "after 6s")
			print("%s %s: %d fish ok" % [arc, s, f0])
	print("critter_water_test: %s (%d fails)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)

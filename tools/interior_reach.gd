extends SceneTree
## Loads every interior and checks that from the spawn cell you can reach a cell
## next to every thing (counter, bed, note...) and every villager standing there.
var fails := 0

func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	_run.call_deferred()

func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	var all := GameState.load_json("res://data/interiors.json")
	for id in all.keys():
		if str(id).begins_with("_"):
			continue
		GameMap.next_interior = str(id)
		GameMap.next_spawn = Vector2.ZERO
		change_scene_to_file("res://scenes/interior.tscn")
		for i in 8:
			await process_frame
		var m := current_scene as GameMap
		if m == null:
			print("  FAIL ", id, ": didn't load"); fails += 1; continue
		var start := m.player.cell()
		var seen := {start: true}
		var q := [start]
		while not q.is_empty():
			var c: Vector2i = q.pop_front()
			for o in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var n: Vector2i = c + o
				if seen.has(n) or n.x < 0 or n.y < 0 or n.x >= m.cols or n.y >= m.rows:
					continue
				if m.blocked.has(n):
					continue
				seen[n] = true
				q.append(n)
		var targets := []
		for c in m.things.keys():
			targets.append([str(m.things[c].get("type", "?")), c])
		for n in m.get("npcs"):
			if is_instance_valid(n):
				targets.append(["npc " + str(n.id), m.world_to_cell(n.position)])
		for t in targets:
			var c: Vector2i = t[1]
			var ok := seen.has(c)
			for o in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				if seen.has(c + o):
					ok = true
			if not ok:
				print("  FAIL ", id, ": can't reach ", t[0], " at ", c)
				fails += 1
	print("interior_reach: %d failures" % fails)
	quit(1 if fails > 0 else 0)

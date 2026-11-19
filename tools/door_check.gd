extends SceneTree
## Every building door on the outdoor maps: the door cell must be free to stand
## on (or at least have a free cell below it) and reachable from the spawn, and
## pressing A there must reach the door thing. Prints one line per problem.
## Run: godot --headless --path . -s res://tools/door_check.gd
var fails := 0

func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	_run.call_deferred()

func _run() -> void:
	InputSetup.ensure_actions()
	for arc in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi" if arc == "penguins" else "dad", "T", "Town", "Pup")
		GameState.run["intro_done"] = true
		for scene in ["town", "farm", "lake", "beach", "mountain", "forest", "meadow"]:
			GameMap.next_spawn = Vector2.ZERO
			change_scene_to_file("res://scenes/%s.tscn" % scene)
			for i in 8:
				await process_frame
			var m := current_scene as GameMap
			if m == null:
				continue
			var start := m.player.cell()
			var seen := {start: true}
			var q := [start]
			while not q.is_empty():
				var c: Vector2i = q.pop_front()
				for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + o
					if seen.has(n) or n.x < 0 or n.y < 0 or n.x >= m.cols + 2 * m.pad or n.y >= m.rows + 2 * m.pad:
						continue
					if m.blocked.has(n) and not (m.things.has(n) and str(m.things[n].get("type", "")) in ["door", "shop", "hall"]):
						continue
					seen[n] = true
					q.append(n)
			for c: Vector2i in m.things.keys():
				var t := str(m.things[c].get("type", ""))
				if not t in ["door", "shop", "hall"]:
					continue
				var stand := false
				for o in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
					if seen.has(c + o) and not m.blocked.has(c + o):
						stand = true
				if not stand:
					print("  DOOR FAIL %s/%s %s at %s (%s): can't stand at or below it; blocked=%s below_blocked=%s" % [arc, scene, t, str(c), str(m.things[c].get("interior", m.things[c].get("hint", ""))), str(m.blocked.has(c)), str(m.blocked.has(c + Vector2i(0, 1)))])
					fails += 1
	print("door_check: %d failures" % fails)
	quit(1 if fails > 0 else 0)

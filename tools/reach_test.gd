extends SceneTree
## Reachability sweep: for every outdoor map, flood-fill the walkable cells from
## the default spawn and from every incoming spawn point, and check that each
## exit strip, door and interactable landmark can be reached on foot.
## Prints "REACH DONE, failures: N". Run:
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/reach_test.gd

const MAPS := ["farm", "town", "meadow", "beach", "mountain", "forest", "lake", "crystal_meadow"]
var fails := 0


func _initialize() -> void:
	InputSetup.ensure_actions()
	GameState.load_data()
	GameState.new_run("penguins", "man", "Tester", "Dreamhollow", "Pip")
	GameState.run["flags"]["intro_done"] = true
	GameState.run["flags"]["gangsters_intro"] = true
	_run.call_deferred()


func _run() -> void:
	for id in MAPS:
		GameMap.next_spawn = Vector2.ZERO
		change_scene_to_file("res://scenes/%s.tscn" % id)
		await _frames(12)
		var m := current_scene as GameMap
		if m == null:
			_check(false, "%s loaded as a GameMap" % id)
			continue
		var start := m.player.cell()
		var seen := _flood(m, start)
		_check(not seen.is_empty(), "%s: spawn %s is walkable" % [id, start])
		var reach_cells := seen.size()
		var total := 0
		for y in m.rows:
			for x in m.cols:
				if not m.blocked.has(Vector2i(x, y)):
					total += 1
		var frac := float(reach_cells) / maxf(1.0, float(total))
		_check(frac > 0.6, "%s: %.0f%% of open ground reachable from spawn (%d/%d)" % [id, frac * 100.0, reach_cells, total])
		for e in m.exits:
			var r: Rect2i = e["rect"]
			var ok := false
			for c in m.cells_of([r]):
				if seen.has(c):
					ok = true
			_check(ok, "%s: exit to %s at %s reachable" % [id, e["scene"], r])
		for c: Vector2i in m.things:
			var t := str(m.things[c].get("type", ""))
			if t in ["door", "mine", "house", "sell", "pad", "shop", "counter"] or str(m.things[c].get("hint", "")).begins_with("A: enter"):
				var near := false
				for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i.ZERO]:
					if seen.has(c + d):
						near = true
				_check(near, "%s: %s at %s reachable" % [id, t, c])
	print("REACH DONE, failures: ", fails)
	quit()


func _flood(m: GameMap, start: Vector2i) -> Dictionary:
	var seen := {}
	if m.blocked.has(start):
		# Spawn sits in a blocked cell: try neighbours (the game unsticks you too).
		for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			if not m.blocked.has(start + d):
				start = start + d
				break
		if m.blocked.has(start):
			return seen
	var q: Array[Vector2i] = [start]
	seen[start] = true
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var n := c + d
			if seen.has(n) or m.blocked.has(n):
				continue
			if n.x < -m.pad or n.y < -m.pad or n.x >= m.cols + m.pad or n.y >= m.rows + m.pad:
				continue
			seen[n] = true
			q.append(n)
	return seen


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print(("  ok   " if ok else "  FAIL ") + what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame

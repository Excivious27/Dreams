extends SceneTree
## Exit-zone audit (round 11): on every map of both arcs, every exit's zone must be
## reachable from the spawn, and no walkable cell out in the border band (outside
## the content) right beside an exit zone may sit outside it (a pocket where you'd stand beside the
## road mouth without leaving: the "go round the signpost" bug).
##   xvfb-run -a godot --headless --path . -s res://tools/exit_check_r11.gd
const MAPS := ["farm", "town", "meadow", "beach", "mountain", "forest", "lake", "crystal_meadow", "orchard_hills", "highlands", "ruins", "quarry", "marsh", "riverlands",
	"wastes", "hideout", "docks", "neon", "uptown", "underground", "countryside", "sky", "station", "jungle", "moon",
	"colony_coral", "colony_kelp", "colony_ice", "colony_ember"]

var bad := 0


func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	InputSetup.ensure_actions()
	GameState.load_data()
	_run.call_deferred()


func _run() -> void:
	var only := OS.get_environment("MAPS")
	for arc in ["penguins", "gangsters"]:
		GameState.new_run(arc, "man", "Tester", "Dreamhollow", "Pip")
		GameState.run["intro_done"] = true
		for id in MAPS:
			GameState.run["flags"][id + "_seen"] = true
		for f in ["cm_seen", "mine_open_1", "meow_taught", "moon_seen", "mine_seen", "intro_done", "gangsters_intro"]:
			GameState.run["flags"][f] = true
		for id: String in MAPS:
			if only != "" and not (id in only.split(",")):
				continue
			GameMap.next_spawn = Vector2.ZERO
			change_scene_to_file("res://scenes/%s.tscn" % id)
			for i in 8:
				await process_frame
			var m := current_scene as GameMap
			if m == null:
				continue
			m.set_process(false)  # don't let check_exits fire while we look
			var seen := _flood(m, m.player.cell())
			var zones: Array = []
			for e in m.exits:
				zones.append(m._exit_zone(e))
			var line := "[%s] %s exits=%d" % [arc, id, m.exits.size()]
			for i in m.exits.size():
				var z: Rect2i = zones[i]
				var n := 0
				for c: Vector2i in seen:
					if m.in_exit(m.exits[i], c):
						n += 1
				line += " | %s %s->%s reach=%d" % [m.exits[i]["scene"], m.exits[i]["rect"], z, n]
				if n == 0:
					line += " UNREACHABLE"
					bad += 1
			var pockets := []
			for c: Vector2i in seen:
				if m.in_content(c):
					continue
				var inz := false
				var near := false
				for i in zones.size():
					if m.in_exit(m.exits[i], c):
						inz = true
						break
					if (zones[i] as Rect2i).grow(2).has_point(c):
						near = true
				if near and not inz:
					pockets.append(c)
			if not pockets.is_empty():
				line += " | POCKETS %d e.g. %s" % [pockets.size(), str(pockets.slice(0, 4))]
				bad += 1
			print(line)
	print("EXIT CHECK: %d problems" % bad)
	quit()


func _flood(m: GameMap, start: Vector2i) -> Dictionary:
	var seen := {}
	if m.blocked.has(start):
		for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			if not m.blocked.has(start + d):
				start += d
				break
	var q: Array[Vector2i] = [start]
	seen[start] = true
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var n := c + d
			if seen.has(n) or m.blocked.has(n):
				continue
			if n.x < -m.pad or n.y < -m.pad or n.x >= m.cols + m.pad or n.y >= m.rows + m.pad:
				continue
			# Inside an exit zone you'd have left already: don't walk on past it.
			var stop := false
			for e in m.exits:
				if m.in_exit(e, c):
					stop = true
			seen[n] = true
			if not stop:
				q.append(n)
	return seen

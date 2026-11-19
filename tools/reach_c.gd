extends SceneTree
## Agent C's subset of reach_all (MAPS env: comma list), plus plateau checks.
var MAPS: Array = ["farm", "beach", "meadow", "mountain", "forest", "orchard_hills", "highlands", "quarry", "colony_coral", "colony_ice"]

func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	InputSetup.ensure_actions()
	GameState.load_data()
	_run.call_deferred()

func _run() -> void:
	if OS.get_environment("MAPS") != "":
		MAPS = Array(OS.get_environment("MAPS").split(","))
	for arc in (["penguins"] if OS.get_environment("ARCS") == "" else Array(OS.get_environment("ARCS").split(","))):
		GameState.new_run(arc, "man", "Tester", "Dreamhollow", "Pip")
		GameState.run["intro_done"] = true
		for id in MAPS:
			GameState.run["flags"][id + "_seen"] = true
		for f in ["cm_seen", "mine_open_1", "meow_taught", "moon_seen", "mine_seen", "intro_done", "gangsters_intro"]:
			GameState.run["flags"][f] = true
		for id in MAPS:
			GameMap.next_spawn = Vector2.ZERO
			change_scene_to_file("res://scenes/%s.tscn" % id)
			for i in 14:
				await process_frame
			var m := current_scene as GameMap
			if m == null:
				print("[%s] %s: not a map" % [arc, id]); continue
			var start := m.player.cell()
			var seen := _flood(m, start)
			var total := 0
			for y in m.rows:
				for x in m.cols:
					if not m.blocked.has(Vector2i(x, y)):
						total += 1
			var cnt := {}
			for c in m.things:
				var t := str(m.things[c].get("type", ""))
				cnt[t] = int(cnt.get(t, 0)) + 1
			print("[%s] %s %dx%d reach %d/%d (%.0f%%) props=%d things=%s enemies=%d" % [arc, id, m.cols, m.rows, seen.size(), total, 100.0 * seen.size() / maxf(1, total), m.props.size(), str(cnt), m.enemies.size()])
			var pi := 0
			for pl: Dictionary in m.plateaus:
				var st_ok := 0
				for st: Vector2i in pl["stairs"]:
					if seen.has(st): st_ok += 1
					else: print("     stair %s blocked=%s thing=%s prop=%s below=%s/%s above=%s/%s" % [st, m.blocked.has(st), str(m.things.get(st, {}).get("type", "")), m.props.has(st), m.blocked.has(st + Vector2i(0, 1)), str(m.things.get(st + Vector2i(0, 1), {}).get("type", "")), m.blocked.has(st + Vector2i(0, -1)), str(m.things.get(st + Vector2i(0, -1), {}).get("type", ""))])
				var top := 0
				for c: Vector2i in pl["cells"]:
					if seen.has(c): top += 1
				print("   plateau %d: %d cells, stairs reached %d/%d, top reached %d" % [pi, pl["cells"].size(), st_ok, pl["stairs"].size(), top])
				pi += 1
			for e in m.exits:
				var ok := false
				for c in m.cells_of([e["rect"]]):
					if seen.has(c): ok = true
				if not ok: print("   UNREACH exit -> %s %s" % [e["scene"], e["rect"]])
			for c: Vector2i in m.things:
				var t := str(m.things[c].get("type", ""))
				if t in ["water", "sea", "forage", "tree", "rock", "bush", "log", "stump", "weed", "grass", "fruit_tree", "crop", "soil"]:
					continue
				var near := false
				for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i.ZERO]:
					if seen.has(c + d): near = true
				if not near: print("   UNREACH thing %s at %s %s" % [t, c, str(m.things[c].get("hint", ""))])
			var unforage := 0
			for c: Vector2i in m.things:
				if str(m.things[c].get("type", "")) == "forage":
					var near := false
					for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i.ZERO]:
						if seen.has(c + d): near = true
					if not near: unforage += 1
			if unforage > 0: print("   UNREACH forage x%d" % unforage)
			for e in m.enemies:
				if is_instance_valid(e):
					var d: float = e.position.distance_to(m.player.position)
					if d < 80.0:
						print("   ENEMY %s %.0fpx from spawn" % [e.kind if "kind" in e else "?", d])
					if m.blocked.has(m.world_to_cell(e.position)):
						print("   ENEMY in blocked cell %s" % m.world_to_cell(e.position))
			for n in m.get_children():
				if n is Npc:
					if m.blocked.has(m.world_to_cell(n.position)): print("   NPC %s in blocked cell" % n.id)
	print("AUD DONE")
	quit()

func _flood(m: GameMap, start: Vector2i) -> Dictionary:
	var seen := {}
	if m.blocked.has(start):
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
			if seen.has(n) or (m.blocked.has(n) and not str(m.things.get(n, {}).get("type", "")) in ["weeds", "rock", "log", "stump", "tree", "bush"]):
				continue  # clearable debris counts as open
			if n.x < -m.pad or n.y < -m.pad or n.x >= m.cols + m.pad or n.y >= m.rows + m.pad:
				continue
			seen[n] = true
			q.append(n)
	return seen

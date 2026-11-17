extends SceneTree
const MAPS := ["farm", "town", "meadow", "beach", "mountain", "forest", "lake", "crystal_meadow", "orchard_hills", "highlands", "ruins", "quarry", "marsh", "riverlands",
	"wastes", "hideout", "docks", "neon", "uptown", "underground", "countryside", "sky", "station", "jungle", "moon", "mine"]

func _initialize() -> void:
	InputSetup.ensure_actions()
	GameState.load_data()
	_run.call_deferred()

func _run() -> void:
	for arc in ["penguins", "gangsters"]:
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
			if seen.has(n) or m.blocked.has(n):
				continue
			if n.x < -m.pad or n.y < -m.pad or n.x >= m.cols + m.pad or n.y >= m.rows + m.pad:
				continue
			seen[n] = true
			q.append(n)
	return seen

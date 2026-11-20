extends SceneTree
## Every building door on the outdoor maps: the door cell must be free to stand
## on (or at least have a free cell below it) and reachable from the spawn, and
## pressing A there must reach the door thing. Prints one line per problem.
## Round 13: every building on every map (towns and regions) either has a way in
## by its front or answers with a reason (BuildingAccess), from any wall cell.
## Run: godot --headless --path . -s res://tools/door_check.gd
var fails := 0
const ALL := ["town", "farm", "lake", "beach", "mountain", "forest", "meadow", "crystal_meadow", "moon",
	"countryside", "docks", "hideout", "neon", "uptown", "underground", "highlands", "jungle", "marsh",
	"orchard_hills", "quarry", "riverlands", "ruins", "sky", "station", "wastes", "hollow_heart",
	"colony_coral", "colony_ember", "colony_ice", "colony_kelp"]

func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	_run.call_deferred()

func _run() -> void:
	InputSetup.ensure_actions()
	for pass_id in ["penguins", "gangsters", "crew"]:
		var arc := "penguins" if pass_id == "penguins" else "gangsters"
		GameState.new_run(arc, "kairi" if arc == "penguins" else "dad", "T", "Town", "Pup")
		GameState.run["intro_done"] = true
		if pass_id == "crew":  # every crew shop moved into town (c5_02 #2: their size/door follow the old building)
			for f in ["shop_1", "shop_2", "shop_3", "crew_mama_rosa", "crew_halo", "crew_marlene"]:
				GameState.run["flags"][f] = true
		for scene in (["town"] if pass_id == "crew" else ALL):
			GameState.run["flags"][scene + "_seen"] = true
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
			_check_buildings(m, arc, scene)
	print("door_check: %d failures (%d buildings answer)" % [fails, answered])
	quit(1 if fails > 0 else 0)


var answered := 0


## Each building: USE on any cell of its front wall (from the row below) reaches a
## door or a reason, and that thing is somewhere you can stand next to.
func _check_buildings(m: GameMap, arc: String, scene: String) -> void:
	if scene == "farm":
		return
	for bp: Array in m._bprops:
		var nm := str(bp[0])
		if BuildingAccess.SKIP.any(func(k: String) -> bool: return nm.contains(k)):
			continue
		var fp := BuildingAccess.footprint(bp)
		var x0: int = fp[0]
		var by: int = fp[1]
		var w: int = fp[2]
		if not m.in_content(Vector2i(x0 + w / 2, by)):
			continue
		var bad := []
		var ok_any := false
		for dx in range(w):
			var wall := Vector2i(x0 + dx, by)
			var front := wall + Vector2i(0, 1)
			if not m.blocked.has(wall) or m.blocked.has(front):
				continue  # not a wall cell, or you can't stand in front of it
			var t: Dictionary = m.things.get(wall, {})
			var tgt := wall
			if t.is_empty() and m._building_doors.has(wall):
				tgt = m._building_doors[wall]
				t = m.things.get(tgt, {})
			if t.is_empty():
				t = m.things.get(front, {})  # the door cell itself, in front of the wall
			if str(t.get("type", "")) in BuildingAccess.ENTRY or str(t.get("hint", "")) != "":
				ok_any = true
			else:
				bad.append(wall)
		if not bad.is_empty() or not ok_any:
			# A front wholly walled off by other props: nothing to knock on, nobody can get there.
			if not ok_any and bad.is_empty():
				continue
			print("  DOOR FAIL %s/%s building %s at %s: silent wall cells %s" % [arc, scene, nm, str(bp[1]), str(bad)])
			fails += 1
		else:
			answered += 1

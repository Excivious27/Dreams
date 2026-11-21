extends SceneTree
## CONDUCT 14 P2 (c14_03-04/-05/-14/-18/-20): town props never stack, lamps keep off the
## lanes, the plaza is dressed and lit, and the avenues still reach the fountain.
## Every season, a plain day and its festival day, both arcs.
##   godot --headless --path . --fixed-fps 60 -s res://tools/town_props_test.gd
var fails := 0

func _initialize() -> void:
	seed(14)
	Campaign.bypass = true
	_run.call_deferred()

func _ok(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("TOWN PROPS FAIL: ", msg)

func _go() -> GameMap:
	GameState.run["flags"]["town_seen"] = true
	GameState.run["flags"]["town_tour"] = true
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/town.tscn")
	for k in 10:
		await process_frame
	return current_scene as GameMap

## Cells reachable from `from` without crossing blocked cells, within the plaza box.
func _reach(t: GameMap, from: Vector2i, to: Vector2i) -> bool:
	var seen := {from: true}
	var q: Array[Vector2i] = [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c.distance_to(to) <= 1.0:
			return true
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := c + d
			if seen.has(n) or n.x < 26 or n.x > 56 or n.y < 32 or n.y > 64 or t.blocked.has(n):
				continue
			seen[n] = true
			q.append(n)
	return false

func _reach2(t: GameMap, from: Vector2i, to: Vector2i) -> bool:
	var seen := {from: true}
	var q: Array[Vector2i] = [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == to:
			return true
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := c + d
			if seen.has(n) or n.x < 40 or n.x > 70 or n.y < 0 or n.y > 14 or (t.blocked.has(n) and n != to):
				continue
			seen[n] = true
			q.append(n)
	return false


func _reach2b(t: GameMap, from: Vector2i, to: Vector2i) -> bool:
	var seen := {from: true}
	var q: Array[Vector2i] = [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == to:
			return true
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := c + d
			if seen.has(n) or n.x < 30 or n.x > 50 or n.y < 55 or n.y > 123 or t.blocked.has(n):
				continue
			seen[n] = true
			q.append(n)
	return false


func _run() -> void:
	InputSetup.ensure_actions()
	_ok(Art.has("tiles", "c14p2_flag") and Art.has("props", "c14p2_mosaic"), "plaza flagstone variants and mosaic art exist")
	var idx := {}
	for y in range(36, 60):
		for x in range(29, 53):
			idx[load("res://scripts/town.gd").plaza_flag_index(Vector2i(x, y)) % 8 / 2] = true
	_ok(idx.size() == 4, "the plaza uses all four flagstone variants (%d)" % idx.size())
	for arc in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi", "Kairi", "Dreamhollow", "Biscuit")
		GameState.run["intro_done"] = true
		for day in [1, 14, 29, 42, 57, 70, 85, 98]:
			GameState.run["day"] = day
			GameState.run["time"] = 11 * 60
			var t := await _go()
			var tag := "%s day %d (%s)" % [arc, day, GameState.festival_today()]
			if t == null:
				_ok(false, tag + ": town loaded")
				continue
			var placed: Array = t.get("placed")
			# no two guarded footprints overlap
			var own := {}
			for p: Array in placed:
				var r: Rect2i = p[1]
				for yy in range(r.position.y, r.end.y):
					for xx in range(r.position.x, r.end.x):
						var c := Vector2i(xx, yy)
						# festival props may chain (garlands, strings); nothing permanent may meet anything
						if own.has(c) and not (bool(p[2]) and bool(own[c][1])):
							_ok(false, "%s: %s overlaps %s at %s" % [tag, p[0], own[c][0], c])
						own[c] = [p[0], bool(p[2])]
			var lanes: Dictionary = t.cells_of(t.LANES + [t.QUAY])
			var lamps := 0
			var plaza_lamps := 0
			for p: Array in placed:
				var r: Rect2i = p[1]
				var nm := str(p[0])
				if nm.begins_with("lamp"):
					lamps += 1
					var base := Vector2i(r.position.x + r.size.x / 2, r.end.y - 1)
					_ok(not lanes.has(base), "%s: lamp on a lane at %s" % [tag, base])
					if Vector2(base.x + 0.5, base.y + 0.5).distance_to(t.PLAZA_C) < t.PLAZA_R + 1.0:
						plaza_lamps += 1
			_ok(plaza_lamps >= (4 if GameState.festival_today() != "" else 6), "%s: plaza lamp ring (%d)" % [tag, plaza_lamps])
			_ok(lamps >= 20, "%s: avenue lamps (%d)" % [tag, lamps])
			if day == 1:
				var names := placed.map(func(p: Array) -> String: return str(p[0]))
				_ok(names.has("c14p2_tree_planter") and names.has("c14p2_bench_curved"), "%s: plaza dressing placed %s" % [tag, names.filter(func(n: String) -> bool: return n.begins_with("c14p2"))])
				_ok(not t.props.has(Vector2i(36, 22)) or str(t.props[Vector2i(36, 22)].texture.resource_path).find("crates") < 0, "crates moved off the avenue lamp")
			# c14_03-21: winter roofs: every town building with a snow twin shows it in winter
			if GameState.look_se() == "winter":
				var green := []
				for b: Array in t.get("_bprops"):
					var nm := str(b[0])
					if not nm.ends_with("_snow") and Art.has("buildings", nm + "_snow"):
						green.append(nm)
				_ok(green.is_empty(), "%s: green roofs in winter %s" % [tag, green])
				for base: String in ["store", "smith", "bakery", "hall", "inn", "library", "school", "cottage_a", "chapel", "bank"]:
					_ok(Art.has("buildings", base + "_snow"), "winter twin for " + base)
			if day == 1:  # c14_03-13: Harbour Row: the town grew south, the beach road still meets the exit
				_ok(t.rows == 124 and t.BEACH_EXIT.position.y == 122, "%s: town is 124 rows, beach exit at the new south edge" % tag)
				for b: String in ["c14p2_fish_market", "c14p2_chandlery", "c14p2_ticket_office"]:
					_ok(t.get("_bprops").any(func(e: Array) -> bool: return str(e[0]).begins_with(b)), "%s: Harbour Row has %s" % [tag, b])
				_ok(not t.blocked.has(Vector2i(40, 120)) and _reach2b(t, Vector2i(40, 120), Vector2i(40, 60)), "%s: beach arrival walks up the avenue to the plaza" % tag)
			if day == 1:  # c14_03-13: the Mayor's garden maze is walkable to its heart and gives its keepsake once
				var pc: Vector2i = t.MAZE_AT + Vector2i(4, 4)
				_ok(str(t.things.get(pc, {}).get("type", "")) == "maze_prize", "%s: maze heart has its keepsake" % tag)
				_ok(_reach2(t, Vector2i(51, 12), pc), "%s: the maze can be walked to its heart" % tag)
				_ok(Art.has("buildings", "c14p2_greenhouse") and t.blocked.has(Vector2i(61, 7)), "%s: conservatory stands in the garden" % tag)
				var before := Decor.owned("dc_y_penguin_topiary" if arc == "penguins" else "dc_out_topiary_b") if t.has_method("interact") else 0
				t.interact(pc, t.things[pc])
				var after := Decor.owned("dc_y_penguin_topiary" if arc == "penguins" else "dc_out_topiary_b")
				_ok(after == before + 1, "%s: maze keepsake granted (%d -> %d)" % [tag, before, after])
				t.interact(pc, t.things[pc])
				_ok(Decor.owned("dc_y_penguin_topiary" if arc == "penguins" else "dc_out_topiary_b") == after, "%s: keepsake only once" % tag)
				var dl := Dialogue.instance(self)
				for k in 30:
					if dl.active:
						dl._advance()
					await process_frame
			# the four avenues still reach the fountain
			var fc := Vector2i(40, 49)
			for from: Vector2i in [Vector2i(40, 34), Vector2i(40, 62), Vector2i(27, 47), Vector2i(55, 47)]:
				_ok(_reach(t, from, fc), "%s: %s reaches the fountain" % [tag, from])
	print("town_props_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

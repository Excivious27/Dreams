extends SceneTree
## Community farm layout, every stage in both arcs: the paths are one connected
## network from the town road, every station (board, shed, well, beds, stand,
## donation box, greenhouse) can be walked up to, the woodland edge wanders
## (organic, on all four sides) and never sits on a path, bed or yard, every
## debris kind has its own art, and the orchard trees are in leaf (never bare)
## in spring and summer. Gangster arc: the band is a city block (buildings on
## every side, alleys/walls/fences, no trees), never drawn over the walkable lot.
##   godot --headless --path . -s res://tools/cf_layout_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	InputSetup.ensure_actions()
	for arc in ["penguins", "gangsters"]:
		for s in range(0, 9):
			await _stage(arc, s, 10)
		await _stage(arc, 8, 38)  # summer
	print("cf_layout_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


func _stage(arc: String, s: int, day: int) -> void:
	GameState.new_run(arc, "kairi" if arc == "penguins" else "dad", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["day"] = day
	for f in ["partner_scene", "community_farm_seen", "cf_intro", "cf_known", "cf_met", "cf_letter"]:
		GameState.run["flags"][f] = true
	Commons.st()["stage"] = s
	GameMap.next_spawn = Vector2(49 * 16 + 8, 19 * 16 + 8)
	change_scene_to_file("res://scenes/community_farm.tscn")
	await _frames(14)
	var d := Dialogue.instance(self)
	for k in 10:
		if d.active:
			d._advance()
			await _frames(2)
	var m := current_scene as GameMap
	var tag := "[%s s%d d%d]" % [arc.left(1), s, day]
	var start := Vector2i(49, 19)
	# Walkable cells reachable from the town road.
	var seen := {start: true}
	var q: Array[Vector2i] = [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for dd: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + dd
			if seen.has(n) or n.x < 0 or n.y < 0 or n.x >= m.cols or n.y >= m.rows or m.blocked.has(n) or m.is_water_cell(n):
				continue
			seen[n] = true
			q.append(n)
	# Paths: every path cell walkable and reached.
	var paths: Array = m.call("_paths")
	var cut: Array = []
	var plaza: Dictionary = m.call("_plaza")  # paths run into the plaza; the well stands there
	for c in m.cells_of(paths):
		if not seen.has(c) and not plaza.has(c):
			cut.append(c)
	check(cut.is_empty(), "%s path cells cut off or blocked: %s" % [tag, str(cut)])
	# Paths form one network (4-connected).
	var pset := {}
	for c in m.cells_of(paths):
		pset[c] = true
	var first: Vector2i = pset.keys()[0]
	var ps := {first: true}
	var pq: Array[Vector2i] = [first]
	while not pq.is_empty():
		var c: Vector2i = pq.pop_back()
		for dd: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + dd
			if pset.has(n) and not ps.has(n):
				ps[n] = true
				pq.append(n)
	check(ps.size() == pset.size(), "%s paths split into pieces (%d of %d joined)" % [tag, ps.size(), pset.size()])
	# Every station can be walked up to.
	var types := {}
	for c: Vector2i in m.things:
		var t := str((m.things[c] as Dictionary).get("type", ""))
		if not t.begins_with("cf_"):
			continue
		var near := seen.has(c)
		for dd: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			near = near or seen.has(c + dd)
		if near:
			types[t] = true
		elif t != "cf_plot":
			check(false, "%s %s at %s can't be reached" % [tag, t, str(c)])
	for need in ["cf_board", "cf_shed", "cf_well"] + (["cf_debris"] if s == 0 else []) + (["cf_plot", "cf_donate", "cf_stand"] if s >= 3 else []) + (["cf_greenhouse"] if s >= 7 else []):
		check(types.has(need), "%s no reachable %s" % [tag, need])
	# The woodland edge: organic (several depths), on every side, never on a path/bed/yard.
	var wood: Dictionary = m.get("_wood")
	var busy: Dictionary = m.get("_busy")
	var sides := {}
	var depths := {}
	var bad := 0
	for c: Vector2i in wood:
		if busy.has(c):
			bad += 1
		var dist := mini(mini(c.x, c.y), mini(m.cols - 1 - c.x, m.rows - 1 - c.y))
		depths[dist] = true
		if c.y <= 6: sides["n"] = true
		if c.y >= m.rows - 7: sides["s"] = true
		if c.x <= 6: sides["w"] = true
		if c.x >= m.cols - 7: sides["e"] = true
	check(bad == 0, "%s %d edge-wood cells on paths/beds/yards" % [tag, bad])
	check(sides.size() == 4, "%s woodland edge on only %s" % [tag, str(sides.keys())])
	check(depths.size() >= 4, "%s woodland edge too even (depths %s)" % [tag, str(depths.keys())])
	# Edge style: gangsters get a city block (buildings, no border trees), penguins the woods.
	var bc: Dictionary = m.get("_border_cells")
	var kinds := {}
	for c: Vector2i in bc:
		kinds[str(bc[c])] = true
	var bd: Array = m.get("_border_draw")
	var city_n := 0
	var tree_n := 0
	var sides_c := {}
	for it: Array in bd:
		if str(it[2]).begins_with("city_"):
			city_n += 1
			var c: Vector2i = it[0]
			if c.y < 0: sides_c["n"] = true
			if c.y >= m.rows: sides_c["s"] = true
			if c.x < 0: sides_c["w"] = true
			if c.x >= m.cols: sides_c["e"] = true
		elif str(it[1]) == "nature":
			tree_n += 1
	if arc == "gangsters":
		check(not kinds.has("tree"), "%s gangster band still has tree cells" % tag)
		check(tree_n == 0, "%s gangster band still draws %d trees" % [tag, tree_n])
		check(city_n >= 30, "%s city edge too thin (%d pieces)" % [tag, city_n])
		check(sides_c.size() == 4, "%s city edge on only %s" % [tag, str(sides_c.keys())])
		var names := {}
		for it: Array in bd:
			names[str(it[2])] = true
		for nm in ["city_tenement", "city_apartment", "city_walkup", "city_roof_a"]:
			check(names.has(nm), "%s city edge never uses %s" % [tag, nm])
		check(names.has("city_alley") or names.has("city_brickwall") or names.has("city_chainlink"), "%s no alley/wall/fence in the city edge" % tag)
		# No band prop (old inner-edge trees) left standing, and nothing in the band is walkable.
		var leaks := 0
		for c: Vector2i in bc:
			if m.in_content(c) and not m.blocked.has(c):
				leaks += 1
			if m.props.has(c) and is_instance_valid(m.props[c]) and str((m.props[c] as Sprite2D).texture.resource_path).contains("/nature/"):
				leaks += 1
		check(leaks == 0, "%s %d band cells walkable or still wooded" % [tag, leaks])
		# Pieces stay inside the band: no building picture over the walkable lot.
		var over := 0
		for it: Array in bd:
			var t := Art.tex(str(it[1]), str(it[2]))
			if t == null:
				continue
			var c: Vector2i = it[0]
			var wc := t.get_width() * 0.5 / 16.0
			var hc := t.get_height() * 0.5 / 16.0
			for y in range(floori(c.y + 1.0 - hc + 0.35), c.y + 1):
				for x in range(floori(c.x + 0.5 - wc / 2.0 + 0.25), ceili(c.x + 0.5 + wc / 2.0 - 0.25)):
					if seen.has(Vector2i(x, y)):
						over += 1
		check(over == 0, "%s city pictures over %d walkable cells" % [tag, over])
	else:
		check(kinds.has("tree") and city_n == 0 and tree_n > 50, "%s penguin edge should stay woodland (%d trees, %d city)" % [tag, tree_n, city_n])
	# Debris art.
	if s == 0:
		for k: String in m.JUNK:
			var j: Array = m.JUNK[k]
			check(Art.has(str(j[0]), str(j[1])), "%s no art for junk %s" % [tag, k])
	# Orchard in leaf in spring/summer (never the bare winter sprite).
	if s == 8:
		for o: Array in Commons.data().get("orchard", []):
			var c := Vector2i(int(o[0]), int(o[1]))
			var sp: Node = m.props.get(c)
			var name := ""
			if sp is Sprite2D and (sp as Sprite2D).texture:
				name = (sp as Sprite2D).texture.resource_path.get_file()
			check(sp != null and name != "" and not name.contains("bare"), "%s orchard %s at %s is bare (%s)" % [tag, str(o[2]), str(c), name])

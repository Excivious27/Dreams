class_name InteriorSeason
## C15 P5 (c15_13-04, c15_13-08): rooms follow the season. A wreath or garland
## hangs on the back wall between the windows and the room's own wall pieces
## (spring paper-flower garland, fall leaf wreath, winter evergreen wreath), and
## in fall a small harvest table stands in a free back corner. Summer keeps the
## room as drawn. Both arcs. Never on a window, a wall prop, a thing or the
## door's way in; no extra blocking except the fall table in a free corner.

const WALL := {"spring": ["c15p5_spring_garland"], "fall": ["dc_fest_leaf_wreath"], "winter": ["c15p5_winter_wreath"]}
const FLOOR := {"fall": "c15p5_harvest_table"}


static func _I(m: GameMap) -> Dictionary:
	var d = m.get("I")
	return d if d is Dictionary else {}


## Rooms left alone: the rec centre and museum dress themselves; the clinic ward,
## mine and moon rooms have no back wall that suits a wreath.
static func skip(m: GameMap) -> bool:
	return bool(_I(m).get("rec", false)) or bool(_I(m).get("museum", false)) or bool(_I(m).get("no_season", false))


## Back-wall columns free for a hanging piece (no window or window neighbour, no prop).
static func wall_cols(m: GameMap) -> Array:
	var wins: Array = (m.call("window_cols") as Array)
	var taken := {}
	for p in _I(m).get("props", []):
		var c := Vector2i(int(p["cell"][0]), int(p["cell"][1]))
		if c.y <= 2:
			for i in range(-1, int(p.get("w", 0)) + 2):
				taken[c.x + i] = true
	var out := []
	for x in range(2, m.cols - 2):
		if taken.has(x) or x in wins or (x - 1) in wins or (x + 1) in wins:
			continue
		if m.things.has(Vector2i(x, 1)) or m.things.has(Vector2i(x, 2)):
			continue
		out.append(x)
	return out


## Picks: up to two wall columns, spread (one in each half of the room).
static func picks(m: GameMap, se := "") -> Array:
	if se == "":
		se = GameState.look_se()
	var out := []
	if skip(m) or not WALL.has(se):
		return out
	var cols := wall_cols(m)
	if cols.is_empty():
		return out
	var left := cols.filter(func(x): return x < m.cols / 2)
	var right := cols.filter(func(x): return x >= m.cols / 2)
	var names: Array = WALL[se]
	if not left.is_empty():
		out.append([str(names[0]), Vector2i(int(left[left.size() / 2]), 1)])
	if not right.is_empty() and m.cols >= 10:
		out.append([str(names[names.size() - 1]), Vector2i(int(right[right.size() / 2]), 1)])
	return out


## A free back corner for the floor piece: the cell and its neighbours clear.
static func floor_cell(m: GameMap) -> Vector2i:
	var door: Array = _I(m).get("door", [m.cols / 2, m.rows - 2])
	for c: Vector2i in [Vector2i(1, 2), Vector2i(m.cols - 2, 2)]:
		var ok := true
		for off: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
			var fc := c + off
			if fc.x < 1 or fc.x > m.cols - 2:
				continue
			if m.blocked.has(fc) or m.things.has(fc) or m.props.has(fc):
				ok = false
		if ok and absi(c.x - int(door[0])) > 1:
			return c
	return Vector2i(-1, -1)


static func dress(m: GameMap) -> int:
	var placed := 0
	var se := GameState.look_se()
	for pk: Array in picks(m, se):
		var nm: String = pk[0]
		if not Art.has("decor", nm):
			continue
		var info := Art.info("decor", nm)
		var sc := minf(0.5, minf(GameMap.TILE * 1.6 / float(info.get("w", 32)), GameMap.TILE * 1.4 / float(info.get("h", 32))))
		if m.prop("decor", nm, pk[1], 0, 2.0, false, sc):
			placed += 1
	if FLOOR.has(se) and not skip(m) and Art.has("decor", FLOOR[se]):
		var fc := floor_cell(m)
		if fc.x >= 0 and m.prop("decor", FLOOR[se], fc, 0, 0.0, true, 0.4):
			placed += 1
	return placed

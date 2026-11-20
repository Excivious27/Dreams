class_name DecorMode
extends CanvasLayer
## Decorate mode (CONDUCT 10a P2): place, move, rotate and store decor in your
## house (any map that answers decor_bounds()), and swap each room's wallpaper
## and flooring. Placement lives in run.decor (Decor.st()):
##   placed[room_key] = [{id, cell: [x, y], rot}]  (cell = the footprint's bottom-left)
##   wall[room] / floor[room] = decor id ("" or missing = the map's own look)
## Pieces come out of and go back into the decor box (Decor.take/give), so nothing
## is ever lost or duplicated; uniques move the same way.
##
## Map hooks (all optional except decor_bounds):
##   decor_bounds() -> Rect2i        floor cells pieces may stand on
##   decor_wall_row() -> int         the back-wall row wall/window pieces hang on (default bounds.y - 1)
##   decor_reserved() -> Dictionary  cells no floor piece may cover (fixed function, spouse spots, door lane)
##   decor_must_reach() -> Array     cells that must stay reachable from decor_door()
##   decor_door() -> Vector2i        the cell inside the door the walk check starts from
##   decor_rooms() -> Dictionary     room id -> Rect2i (wallpaper/flooring rooms)
##   decor_windows() -> Array        wall columns with a window (wall art can't cover them)
##   decor_changed()                 called after any change (redraw walls/floors)
##
## Layers (entry "layer"): floor (stands on cells, blocks them), under (rugs: flat,
## never block, one per cell), wall / window (hang on the back wall row), wallpaper /
## flooring (room surfaces, applied from the box list). Glow comes from entry "glow".
## Co-op: guests never decorate the host's house (open() refuses); they see the
## host's placed/wall/floor through run.decor_home (Net WORLD_KEYS, home_view()).

const PLACE_LAYERS := ["floor", "under", "wall", "window"]
const SURFACE_LAYERS := ["wallpaper", "flooring"]
const BAR_H := 92.0          # bottom control panel height (column px)
const OK_COL := Color(0.35, 0.95, 0.45, 0.42)
const BAD_COL := Color(1.0, 0.3, 0.3, 0.42)

# ---- session state (undo) -----------------------------------------------------
## Ops of the open session, newest last: {op: place|pick|move|surface, ...} (undo pops one).
static var undo_stack: Array = []


# ---- data (static, testable without UI) ----------------------------------------

## The state the current player's view is drawn from: our own run.decor, or the
## host's house while visiting (read-only).
static func view() -> Dictionary:
	if Net.visiting():
		var v: Variant = GameState.run.get("decor_home", null)
		if v is Dictionary:
			for k in ["placed", "wall", "floor"]:
				if not ((v as Dictionary).get(k, null) is Dictionary):
					(v as Dictionary)[k] = {}
			return v
		return {"placed": {}, "wall": {}, "floor": {}}
	return Decor.st()


## What the host shares with guests: only the house's looks (never the box or wardrobe).
static func home_view() -> Dictionary:
	var d := Decor.st()
	return {"placed": (d["placed"] as Dictionary).duplicate(true), "wall": (d["wall"] as Dictionary).duplicate(true), "floor": (d["floor"] as Dictionary).duplicate(true)}


static func room_key(m: GameMap) -> String:
	return m.scene_id()


static func placed(key: String) -> Array:
	var p: Variant = (view()["placed"] as Dictionary).get(key, [])
	return p if p is Array else []


static func _own_placed(key: String) -> Array:
	var pl: Dictionary = Decor.st()["placed"]
	if not (pl.get(key, null) is Array):
		pl[key] = []
	return pl[key]


static func can_decorate(m: GameMap) -> bool:
	return m != null and m.has_method("decor_bounds")


static func layer_of(id: String) -> String:
	return str(Decor.entry(id).get("layer", "floor"))


static func placeable(id: String) -> bool:
	return Decor.is_decor(id) and layer_of(id) in PLACE_LAYERS


static func is_surface(id: String) -> bool:
	return Decor.is_decor(id) and layer_of(id) in SURFACE_LAYERS


## Number of facings the art has (entry "rot", 1 = front only).
static func rot_count(id: String) -> int:
	return clampi(int(Decor.entry(id).get("rot", 1)), 1, 4)


## Footprint size in cells for a facing (side facings of a 4-way piece swap w/h).
static func size_of(id: String, rot := 0) -> Vector2i:
	var s: Variant = Decor.entry(id).get("size", [1, 1])
	var v := Vector2i(1, 1)
	if s is Array and (s as Array).size() >= 2:
		v = Vector2i(maxi(1, int(s[0])), maxi(1, int(s[1])))
	if rot_count(id) == 4 and rot % 2 == 1:
		v = Vector2i(v.y, v.x)
	return v


static func footprint(id: String, cell: Vector2i, rot := 0) -> Array:
	var sz := size_of(id, rot)
	var out: Array = []
	for y in range(cell.y - sz.y + 1, cell.y + 1):
		for x in range(cell.x, cell.x + sz.x):
			out.append(Vector2i(x, y))
	return out


static func _cell_of(p: Dictionary) -> Vector2i:
	var c: Variant = p.get("cell", [0, 0])
	return Vector2i(int(c[0]), int(c[1])) if c is Array and (c as Array).size() >= 2 else Vector2i.ZERO


static func _map_call(m: GameMap, fn: String, fallback: Variant) -> Variant:
	return m.call(fn) if m.has_method(fn) else fallback


static func bounds(m: GameMap) -> Rect2i:
	return _map_call(m, "decor_bounds", Rect2i()) as Rect2i


static func wall_row(m: GameMap) -> int:
	return int(_map_call(m, "decor_wall_row", bounds(m).position.y - 1))


## Cells that the map itself blocks (walls, bed, stove...), without any placed decor.
static func fixed_blocked(m: GameMap) -> Dictionary:
	if not m.has_meta("decor_fixed"):
		m.set_meta("decor_fixed", m.blocked.duplicate())
	return m.get_meta("decor_fixed")


## Cells covered (blocked) by floor pieces in this room, skipping one index.
static func decor_blocked(m: GameMap, skip := -1) -> Dictionary:
	var out := {}
	var list := placed(room_key(m))
	for i in list.size():
		if i == skip or not (list[i] is Dictionary):
			continue
		var p: Dictionary = list[i]
		if layer_of(str(p.get("id", ""))) != "floor":
			continue
		for c: Vector2i in footprint(str(p["id"]), _cell_of(p), int(p.get("rot", 0))):
			out[c] = i
	return out


## "" when the piece fits there, else a short reason (shown under the ghost).
static func why_not(m: GameMap, id: String, cell: Vector2i, rot := 0, skip := -1) -> String:
	if not Decor.is_decor(id):
		return "That isn't decor."
	var layer := layer_of(id)
	if not (layer in PLACE_LAYERS):
		return "Pick a room to use this on."
	var b := bounds(m)
	var fp := footprint(id, cell, rot)
	var list := placed(room_key(m))
	if layer in ["wall", "window"]:
		var wr := wall_row(m)
		var wins: Array = _map_call(m, "decor_windows", [])
		for c: Vector2i in fp:
			if c.y > wr or c.y < wr - 1 or c.x < b.position.x or c.x >= b.end.x:
				return "Wall pieces hang on the back wall."
			if layer == "wall" and c.x in wins:
				return "There's a window there."
		for i in list.size():
			if i == skip or not (list[i] is Dictionary) or not (layer_of(str(list[i].get("id", ""))) in ["wall", "window"]):
				continue
			for c: Vector2i in footprint(str(list[i]["id"]), _cell_of(list[i]), int(list[i].get("rot", 0))):
				if c.x in fp.map(func(v: Vector2i) -> int: return v.x):
					return "Another piece hangs there."
		return ""
	for c: Vector2i in fp:
		if not b.has_point(c):
			return "That's outside the room."
	if layer == "under":
		var door := _map_call(m, "decor_door", Vector2i(-99, -99)) as Vector2i
		for i in list.size():
			if i == skip or not (list[i] is Dictionary) or layer_of(str(list[i].get("id", ""))) != "under":
				continue
			for c: Vector2i in footprint(str(list[i]["id"]), _cell_of(list[i]), int(list[i].get("rot", 0))):
				if c in fp:
					return "A rug is already there."
		if (door + Vector2i(0, 1)) in fp:
			return "Keep the doorway clear."
		return ""
	var fixed := fixed_blocked(m)
	var res: Dictionary = _map_call(m, "decor_reserved", {})
	var mine := decor_blocked(m, skip)
	for c: Vector2i in fp:
		if res.has(c):
			return "That spot is needed (%s)." % str(res[c]) if res[c] is String else "That spot is needed."
		if fixed.has(c) or mine.has(c):
			return "Something is already there."
	var extra := {}
	for c: Vector2i in fp:
		extra[c] = true
	if not reach_ok(m, extra, skip):
		return "That would block the way through."
	return ""


## Every must-reach cell keeps an open neighbour reachable from the door.
static func reach_ok(m: GameMap, extra: Dictionary = {}, skip := -1) -> bool:
	var b := bounds(m)
	var start := _map_call(m, "decor_door", Vector2i(-99, -99)) as Vector2i
	if not b.has_point(start):
		return true
	var fixed := fixed_blocked(m)
	var mine := decor_blocked(m, skip)
	var open := func(c: Vector2i) -> bool:
		return b.has_point(c) and not fixed.has(c) and not mine.has(c) and not extra.has(c)
	if not open.call(start):
		return false
	var seen := {start: true}
	var q: Array = [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := c + d
			if not seen.has(n) and open.call(n):
				seen[n] = true
				q.append(n)
	for t: Vector2i in _map_call(m, "decor_must_reach", []):
		var ok := false
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.ZERO]:
			if seen.has(t + d):
				ok = true
				break
		if not ok:
			return false
	return true


## Index of the piece at a cell (wall pieces answer for their wall cells, rugs last).
static func piece_at(m: GameMap, c: Vector2i) -> int:
	var list := placed(room_key(m))
	var rug := -1
	for i in range(list.size() - 1, -1, -1):
		if not (list[i] is Dictionary):
			continue
		var id := str(list[i].get("id", ""))
		if c in footprint(id, _cell_of(list[i]), int(list[i].get("rot", 0))):
			if layer_of(id) == "under":
				if rug < 0:
					rug = i
			else:
				return i
	return rug


## USE with decor or a placeable in hand indoors (on an empty cell): say where it goes.
## True when a line was shown.
static func held_hint(m: GameMap) -> bool:
	var sel := str(GameState.run.get("selected", ""))
	if sel == "" or GameState.count(sel) <= 0:
		return false
	var t := str(GameState.items.get(sel, {}).get("type", ""))
	if not (t in ["decor", "placeable"] or Decor.is_decor(sel)):
		return false
	if t == "placeable":
		ToolHint.say(m, "Chests, sprinklers and scarecrows go on your farm.")
	elif not Decor.is_decor(sel):
		ToolHint.say(m, "Keep it in your bag: it stands on display in your house.")
	elif can_decorate(m):
		ToolHint.say(m, "Decorate to place things here (the button at the top, or the dresser).")
	else:
		ToolHint.say(m, "Decor goes in your house: decorate from the dresser there.")
	return true


static func can_edit() -> bool:
	return not Net.visiting()


## Place a piece from the box. "" on success, else the reason.
static func place(m: GameMap, id: String, cell: Vector2i, rot := 0) -> String:
	if not can_edit():
		return "Only the host decorates this house."
	if Decor.owned(id) <= 0:
		return "None left in your decor box."
	var why := why_not(m, id, cell, rot)
	if why != "":
		return why
	Decor.take(id)
	_own_placed(room_key(m)).append({"id": id, "cell": [cell.x, cell.y], "rot": rot % rot_count(id)})
	undo_stack.append({"op": "place", "key": room_key(m), "id": id})
	_changed(m)
	return ""


## Put a placed piece back in the box. Returns its id ("" if none).
static func pick(m: GameMap, idx: int, record := true) -> String:
	if not can_edit():
		return ""
	var list := _own_placed(room_key(m))
	if idx < 0 or idx >= list.size():
		return ""
	var p: Dictionary = list[idx]
	list.remove_at(idx)
	var id := str(p.get("id", ""))
	_box_back(id)
	if record:
		undo_stack.append({"op": "pick", "key": room_key(m), "piece": p.duplicate(true), "at": idx})
	_changed(m)
	return id


## Move / turn a placed piece. "" on success.
static func move(m: GameMap, idx: int, cell: Vector2i, rot := -1) -> String:
	if not can_edit():
		return "Only the host decorates this house."
	var list := _own_placed(room_key(m))
	if idx < 0 or idx >= list.size():
		return "Nothing to move."
	var p: Dictionary = list[idx]
	var id := str(p["id"])
	var r := int(p.get("rot", 0)) if rot < 0 else rot % rot_count(id)
	var why := why_not(m, id, cell, r, idx)
	if why != "":
		return why
	undo_stack.append({"op": "move", "key": room_key(m), "at": idx, "cell": (p["cell"] as Array).duplicate(), "rot": int(p.get("rot", 0))})
	p["cell"] = [cell.x, cell.y]
	p["rot"] = r
	_changed(m)
	return ""


## Use a wallpaper/flooring from the box on a room; the old one goes back to the box.
static func set_surface(m: GameMap, room: String, id: String, record := true) -> String:
	if not can_edit():
		return "Only the host decorates this house."
	var kind := "wall" if layer_of(id) == "wallpaper" else "floor"
	if id != "" and not is_surface(id):
		return "That isn't wallpaper or flooring."
	if id != "" and Decor.owned(id) <= 0:
		return "None left in your decor box."
	var tab: Dictionary = Decor.st()[kind]
	var old := str(tab.get(room, ""))
	if old == id:
		return ""
	if id != "":
		Decor.take(id)
		tab[room] = id
	else:
		tab.erase(room)
	if old != "":
		_box_back(old)
	if record:
		undo_stack.append({"op": "surface", "kind": kind, "room": room, "old": old, "new": id})
	_changed(m)
	return ""


## Take back the last change of this session. True if something was undone.
static func undo(m: GameMap) -> bool:
	if undo_stack.is_empty() or not can_edit():
		return false
	var op: Dictionary = undo_stack.pop_back()
	var list := _own_placed(str(op.get("key", room_key(m))))
	match str(op["op"]):
		"place":
			for i in range(list.size() - 1, -1, -1):
				if str(list[i].get("id", "")) == str(op["id"]):
					list.remove_at(i)
					_box_back(str(op["id"]))
					break
		"pick":
			var p: Dictionary = op["piece"]
			if Decor.take(str(p["id"])):
				list.insert(mini(int(op["at"]), list.size()), p)
		"move":
			var i := int(op["at"])
			if i < list.size():
				list[i]["cell"] = op["cell"]
				list[i]["rot"] = int(op["rot"])
		"surface":
			var tab: Dictionary = Decor.st()[str(op["kind"])]
			var nw := str(op["new"])
			var old := str(op["old"])
			if nw != "":
				tab.erase(str(op["room"]))
				_box_back(nw)
			if old != "" and Decor.take(old):
				tab[str(op["room"])] = old
	_changed(m)
	return true


## Everything placed in this room back to the box (wallpaper/flooring too).
static func store_all(m: GameMap) -> int:
	if not can_edit():
		return 0
	var list := _own_placed(room_key(m))
	var n := list.size()
	for p in list:
		_box_back(str(p.get("id", "")))
	list.clear()
	for kind in ["wall", "floor"]:
		var tab: Dictionary = Decor.st()[kind]
		for room in (_map_call(m, "decor_rooms", {}) as Dictionary):
			if tab.has(room):
				_box_back(str(tab[room]))
				tab.erase(room)
				n += 1
	undo_stack.clear()
	_changed(m)
	return n


## Store the room, then let the map put its starting pieces back (map.decor_reset()).
static func reset_layout(m: GameMap) -> int:
	if not can_edit() or not m.has_method("decor_reset"):
		return 0
	store_all(m)
	return int(m.call("decor_reset"))


## A piece going back to the box: through Decor.give, except a unique (give()
## refuses a unique that is "already owned", and a placed one counted as owned).
static func _box_back(id: String) -> void:
	if id == "" or not Decor.is_decor(id):
		return
	if Decor.is_unique(id):
		Decor.st()["box"][id] = Decor.owned(id) + 1
	else:
		Decor.give(id, 1, "decor_mode")


## Pieces no longer valid after the room changed (a house tier change, a new
## reserved cell): back to the box. Returns their names.
static func relayout(m: GameMap) -> Array:
	if not can_edit():
		return []
	var list := _own_placed(room_key(m))
	var gone: Array = []
	var keep: Array = []
	for p in list:
		if not (p is Dictionary) or not Decor.is_decor(str(p.get("id", ""))):
			continue  # an id the catalogue dropped: keep the record, draw nothing
		keep.append(p)
	list.clear()
	for p: Dictionary in keep:
		var id := str(p["id"])
		list.append(p)
		if why_not(m, id, _cell_of(p), int(p.get("rot", 0)), list.size() - 1) != "":
			list.pop_back()
			_box_back(id)
			gone.append(str(Decor.entry(id).get("name", id)))
	return gone


static func _changed(m: GameMap) -> void:
	if m == null or not is_instance_valid(m):
		return
	dress(m)
	if m.has_method("decor_changed"):
		m.call("decor_changed")


# ---- drawing placed pieces --------------------------------------------------------

## The art for a piece at a facing: "<name>_r<rot>" when drawn, else the base art
## (mirrored for facing 3 of a 2-way piece).
static func art_of(id: String, rot := 0) -> Array:
	var a := str(Decor.entry(id).get("art", ""))
	var g := "decor"
	var n := id
	if a.contains("/"):
		g = a.get_slice("/", 0)
		n = a.get_slice("/", 1)
	if rot > 0 and Art.has(g, n + "_r%d" % rot):
		return [g, n + "_r%d" % rot, false]
	return [g, n, rot > 0 and rot_count(id) == 2]


## (Re)build every placed piece's sprite and blocking for this map. Cheap: one
## Sprite2D per piece (y-sorted with the map), rugs on the under layer.
static func dress(m: GameMap) -> void:
	if not can_decorate(m):
		return
	var fixed := fixed_blocked(m)
	var old: Variant = m.get_meta("decor_nodes", [])
	for n in old:
		if is_instance_valid(n):
			if m.glow:
				m.glow.lights = m.glow.lights.filter(func(l: Array) -> bool: return l[0] != n)
			(n as Node).queue_free()
	for c in m.get_meta("decor_cells", {}):
		if not fixed.has(c):
			m.blocked.erase(c)
			m.hard.erase(c)
	var nodes: Array = []
	var cells := {}
	var list := placed(room_key(m))
	for p in list:
		if not (p is Dictionary) or not Decor.is_decor(str(p.get("id", ""))):
			continue
		var id := str(p["id"])
		var rot := int(p.get("rot", 0))
		var cell := _cell_of(p)
		if is_flat(id):
			continue  # drawn into the baked map (draw_flat): no node, no draw call of its own
		var s := sprite_for(id, rot)
		if s == null:
			continue
		var sz := size_of(id, rot)
		var layer := layer_of(id)
		s.position = m.cell_pos(cell.x + sz.x / 2.0, cell.y + 1)
		s.set_meta("decor_id", id)
		m.add_child(s)
		if layer == "under":
			m.to_under(s)
		elif layer in ["wall", "window"]:
			s.position.y = m.cell_pos(0, wall_row(m) + 1).y - 2.0  # hangs on the wall, bottom just above the floor line
		else:
			for c: Vector2i in footprint(id, cell, rot):
				cells[c] = true
				m.blocked[c] = true
				m.hard[c] = true
		if bool(Decor.entry(id).get("glow", false)) and m.glow and s.texture:
			m.glow.lights.append([s, 34.0, s.texture.get_height() * s.scale.y * 0.7])
		nodes.append(s)
	m.set_meta("decor_nodes", nodes)
	m.set_meta("decor_cells", cells)
	m._flows.clear()


## Rugs and wall pieces without a light are always behind everything: they are
## drawn into the map's baked drawing instead of one Sprite2D each (a full house
## stays cheap: only standing pieces are nodes).
static func is_flat(id: String) -> bool:
	return layer_of(id) in ["under", "wall", "window"] and not bool(Decor.entry(id).get("glow", false))


## Draw this room's flat pieces (call at the end of the map's draw_map; works on the painter twin).
static func draw_flat(ci: GameMap) -> void:
	var list := placed(room_key(ci))
	for layer in ["under", "wall"]:
		for p in list:
			if not (p is Dictionary) or not Decor.is_decor(str(p.get("id", ""))):
				continue
			var id := str(p["id"])
			var ly := layer_of(id)
			if not is_flat(id) or (ly == "under") != (layer == "under"):
				continue
			var rot := int(p.get("rot", 0))
			var a := art_of(id, rot)
			var t := Art.tex(str(a[0]), str(a[1]))
			if t == null:
				continue
			var fr := int(Art.info(str(a[0]), str(a[1])).get("frames", 1))
			var src := Rect2(0, 0, float(Art.info(str(a[0]), str(a[1])).get("cell_w", t.get_width() / fr)) if fr > 1 else float(t.get_width()), t.get_height())
			var sz := size_of(id, rot)
			var k := _fit_k(id, rot, src.size.x)
			var wsz := src.size * k
			var cell := _cell_of(p)
			var bottom := float((cell.y + 1) * GameMap.TILE) if ly == "under" else float((wall_row(ci) + 1) * GameMap.TILE) - 2.0
			var cx := (cell.x + sz.x / 2.0) * GameMap.TILE
			if ly == "under":
				# A rug fills its footprint (flat art reads best stretched to its cells).
				ci.draw_texture_rect_region(t, Rect2(cell.x * GameMap.TILE, (cell.y - sz.y + 1) * GameMap.TILE, sz.x * GameMap.TILE, sz.y * GameMap.TILE), src)
			else:
				var r := Rect2(cx - wsz.x / 2.0, bottom - wsz.y, wsz.x, wsz.y)
				if bool(a[2]):
					r = Rect2(r.position.x + r.size.x, r.position.y, -r.size.x, r.size.y)
				ci.draw_texture_rect_region(t, r, src)


static func _fit_k(id: String, rot: int, tw: float) -> float:
	var w := float(size_of(id, rot).x * GameMap.TILE)
	if tw * 0.5 > w * 1.35 or tw * 0.5 < w * 0.6:
		return w / maxf(1.0, tw)
	return 0.5


## A piece's sprite, fitted to its footprint width (catalogue art comes at mixed scales).
static func sprite_for(id: String, rot := 0) -> Sprite2D:
	var a := art_of(id, rot)
	var s := Art.sprite(str(a[0]), str(a[1]))
	if s == null:
		return null
	var fr := int(Art.info(str(a[0]), str(a[1])).get("frames", 1))
	if fr > 1 and s.texture:
		var at := AtlasTexture.new()
		at.atlas = s.texture
		at.region = Rect2(0, 0, float(Art.info(str(a[0]), str(a[1])).get("cell_w", s.texture.get_width() / fr)), s.texture.get_height())
		s.texture = at
		s.offset = Vector2(0, -at.get_height() / 2.0)
	var k := _fit_k(id, rot, float(s.texture.get_width()))  # mixed source scales: fit the piece to its cells
	s.scale = Vector2(k, k)
	s.flip_h = bool(a[2])
	CrispArt.apply(s)
	return s


# ---- room surfaces (wallpaper / flooring) -------------------------------------------

## interior.gd has no class_name: its statics through the script resource.
static func _interior() -> Variant:
	return load("res://scripts/interior.gd")


static func surface_of(kind: String, room: String) -> String:
	var id := str((view()[kind] as Dictionary).get(room, ""))
	return id if is_surface(id) else ""


## Draw one floor cell of a flooring entry: a seamless 256 texture (8-cell period)
## or a tiles/ floor set through Interior's gutter-safe painter. False = not drawable.
static func draw_floor_cell(ci: CanvasItem, id: String, c: Vector2i) -> bool:
	var a := art_of(id)
	if str(a[0]) == "tiles" and (Art.has("tiles", str(a[1])) or Art.has("tiles", str(a[1]) + "_0")):
		return bool(_interior().paint_floor_cell(ci, str(a[1]), c))
	var t := Art.tex(str(a[0]), str(a[1]))
	if t == null:
		return false
	_seam(ci, t, c, Vector2i(1, 1))
	return true


## One wall column (2 cells high) of a wallpaper entry: a tiles/ wall kit (_l/_m/_r)
## or a seamless texture.
static func draw_wall_col(ci: CanvasItem, id: String, x: int, part: String) -> bool:
	var a := art_of(id)
	if str(a[0]) == "tiles":
		var mids: Array = (_interior().WALL_MIDS as Dictionary).get(str(a[1]), ["_m", "_m2", "_m3"])
		mids = mids.filter(func(mm: String) -> bool: return Art.has("tiles", str(a[1]) + mm))
		var nm: String = str(a[1]) + (part if part != "_m" else (str(mids[x % mids.size()]) if not mids.is_empty() else "_m"))
		if not Art.has("tiles", nm):
			nm = str(a[1]) + "_m"
		var t := Art.tex("tiles", nm)
		if t == null:
			return false
		ci.draw_texture_rect(t, Rect2(x * GameMap.TILE, 0, GameMap.TILE, GameMap.TILE * 2), false)
		return true
	var tx := Art.tex(str(a[0]), str(a[1]))
	if tx == null:
		return false
	_seam(ci, tx, Vector2i(x, 0), Vector2i(1, 2))
	return true


## Sample a seamless texture for a cell block (16 px cells = 32 texture px, wraps).
static func _seam(ci: CanvasItem, t: Texture2D, c: Vector2i, cells: Vector2i) -> void:
	var tw := float(t.get_width())
	var th := float(t.get_height())
	var span := float(GameMap.TILE) * 2.0 * tw / 256.0
	for j in cells.y:
		for i in cells.x:
			var cc := c + Vector2i(i, j)
			var wx := fposmod(cc.x * span, tw)
			var wy := fposmod(cc.y * span, th)
			var dst := Rect2(Vector2(cc * GameMap.TILE), Vector2(GameMap.TILE, GameMap.TILE))
			if wx + span <= tw and wy + span <= th:
				ci.draw_texture_rect_region(t, dst, Rect2(wx, wy, span, span))
			else:
				ci.draw_texture_rect_region(t, dst, Rect2(minf(wx, tw - span), minf(wy, th - span), span, span))


# ---- the screen -----------------------------------------------------------------------

var map: GameMap
var held := ""           # id held from the box ("" = none)
var moving := -1         # index of the placed piece being moved (-1 = none)
var rot := 0
var cursor := Vector2i.ZERO
var _ghost: Node2D
var _ghost_sprite: Sprite2D
var _status: Label
var _bar: PanelContainer
var _list_panel: PanelContainer
var _list_box: VBoxContainer
var _drag_from := Vector2.INF
var _dragging := false
var _rep := 0.0
var _confirm_store := false
var _player_was := false


static func open(m: GameMap) -> DecorMode:
	if m == null:
		return null
	if Net.visiting():
		m.hud.toast("This is your host's home: only they can decorate it.", Color(1, 0.85, 0.6))
		return null
	if not can_decorate(m):
		m.hud.toast("You can decorate inside your house.", Color(1, 0.9, 0.7))
		return null
	for n in m.get_children():
		if n is DecorMode:
			return n
	var d := DecorMode.new()
	d.map = m
	m.add_child(d)
	return d


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	undo_stack.clear()
	var b := bounds(map)
	cursor = map.player.cell() if map.player and b.has_point(map.player.cell()) else b.position + b.size / 2
	_player_was = map.player.frozen if map.player else false
	if map.player:
		map.player.frozen = true
	_ghost = Node2D.new()
	_ghost.z_index = 50
	_ghost.process_mode = Node.PROCESS_MODE_ALWAYS
	_ghost.draw.connect(_draw_ghost)
	map.add_child(_ghost)
	_build_ui()
	Hud.pause(get_tree(), "decor")
	Hud.modal_rect = Rect2(0, 0, 270, 480)
	_refresh()
	if not GameState.run["flags"].has("decor_tip"):
		GameState.run["flags"]["decor_tip"] = true
		_say("Decorating! Tap a spot, then Place. Tap a piece to pick it up and move it.")


func _exit_tree() -> void:
	if _ghost and is_instance_valid(_ghost):
		_ghost.queue_free()
	if _bar:
		Hud.extra_rects.erase(Rect2(_bar.position, _bar.size))
	if Hud.modal_rect == Rect2(0, 0, 270, 480):
		Hud.modal_rect = Rect2()


func close() -> void:
	Hud.modal_rect = Rect2()
	if not Hud.keep_paused(get_tree(), self):
		get_tree().paused = false
	if map and map.player:
		map.player.frozen = _player_was
		var cam := map.get_viewport().get_camera_2d()
		if cam:
			cam.offset.x = 0.0
	Dialogue.block_input()
	undo_stack.clear()
	queue_free()


func _btn(parent: Control, text: String, cb: Callable, w := 42.0) -> Button:
	var bt := Button.new()
	bt.text = text
	bt.custom_minimum_size = Vector2(w, 26)
	bt.add_theme_font_size_override("font_size", Settings.font(9))
	bt.focus_mode = Control.FOCUS_NONE
	bt.pressed.connect(func() -> void:
		Music.instance(get_tree()).sfx("ui_tap")
		cb.call())
	parent.add_child(bt)
	return bt


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_bar = PanelContainer.new()
	_bar.add_theme_stylebox_override("panel", Hud.panel_stylebox("panel_wood"))
	_bar.position = Vector2(2, 480 - BAR_H)
	_bar.size = Vector2(266, BAR_H - 2)
	root.add_child(_bar)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	_bar.add_child(v)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(250, 24)
	_status.add_theme_font_size_override("font_size", Settings.font(9))
	v.add_child(_status)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 3)
	v.add_child(row1)
	_btn(row1, "Box", _toggle_list, 48)
	_btn(row1, "Place", _confirm, 48)
	_btn(row1, "Turn", _rotate, 48)
	_btn(row1, "Store", _store, 48)
	_btn(row1, "Undo", _undo, 48)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 3)
	v.add_child(row2)
	for dv: Array in [["◀", Vector2i.LEFT], ["▲", Vector2i.UP], ["▼", Vector2i.DOWN], ["▶", Vector2i.RIGHT]]:
		var dd: Vector2i = dv[1]
		_btn(row2, str(dv[0]), func() -> void: _step(dd), 30)
	_btn(row2, "Done", close, 116)
	_list_panel = PanelContainer.new()
	_list_panel.add_theme_stylebox_override("panel", Hud.panel_stylebox("panel_wood"))
	_list_panel.position = Vector2(8, 40)
	_list_panel.size = Vector2(254, 480 - BAR_H - 48)
	_list_panel.visible = false
	root.add_child(_list_panel)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(246, 480 - BAR_H - 58)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_panel.add_child(sc)
	_list_box = VBoxContainer.new()
	_list_box.custom_minimum_size = Vector2(238, 0)
	sc.add_child(_list_box)
	Hud.extra_rects.append(Rect2(_bar.position, _bar.size))


## Box rows: every placeable / surface the box holds, rarest first; Store all at the end.
func box_ids() -> Array:
	var ids: Array = []
	for id in (Decor.st()["box"] as Dictionary):
		if (placeable(str(id)) or is_surface(str(id))) and Decor.owned(str(id)) > 0:
			ids.append(str(id))
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ra := Decor.rarity_rank(Decor.rarity(a))
		var rb := Decor.rarity_rank(Decor.rarity(b))
		return ra > rb if ra != rb else str(Decor.entry(a).get("name", a)) < str(Decor.entry(b).get("name", b)))
	return ids


func _toggle_list() -> void:
	_list_panel.visible = not _list_panel.visible
	if not _list_panel.visible:
		return
	for c in _list_box.get_children():
		c.queue_free()
	var ids := box_ids()
	if ids.is_empty():
		var l := Label.new()
		l.text = "Your decor box is empty. Decor from shops, prizes and finds lands here."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(230, 40)
		l.add_theme_font_size_override("font_size", Settings.font(9))
		_list_box.add_child(l)
	for id: String in ids:
		var e := Decor.entry(id)
		var r := Decor.rarity(id)
		var dots := "●".repeat(clampi(Decor.rarity_rank(r) + 1, 1, 7))
		var bt := Button.new()
		bt.text = "%s  x%d  %s %s" % [str(e.get("name", id)), Decor.owned(id), dots, r.capitalize()]
		bt.alignment = HORIZONTAL_ALIGNMENT_LEFT
		bt.custom_minimum_size = Vector2(236, 24)
		bt.add_theme_font_size_override("font_size", Settings.font(8))
		bt.add_theme_color_override("font_color", Decor.rarity_color(r))
		bt.focus_mode = Control.FOCUS_NONE
		var ia := art_of(id)
		var itx := Art.tex(str(ia[0]), str(ia[1]) + ("_icon" if Art.has(str(ia[0]), str(ia[1]) + "_icon") else ""))
		if itx:
			bt.icon = itx
			bt.expand_icon = true
			bt.add_theme_constant_override("icon_max_width", 20)
		bt.pressed.connect(_choose.bind(id))
		_list_box.add_child(bt)
	_confirm_store = false
	var st := Button.new()
	st.text = "Store everything in this room"
	st.custom_minimum_size = Vector2(236, 24)
	st.add_theme_font_size_override("font_size", Settings.font(8))
	st.focus_mode = Control.FOCUS_NONE
	st.pressed.connect(func() -> void:
		if not _confirm_store:
			_confirm_store = true
			st.text = "Tap again: store everything"
			return
		var n := store_all(map)
		_list_panel.visible = false
		_say("%d pieces back in your decor box." % n))
	_list_box.add_child(st)
	if map.has_method("decor_reset"):
		var rs := Button.new()
		rs.text = "Starting layout"
		rs.custom_minimum_size = Vector2(236, 24)
		rs.add_theme_font_size_override("font_size", Settings.font(8))
		rs.focus_mode = Control.FOCUS_NONE
		var armed := [false]
		rs.pressed.connect(func() -> void:
			if not armed[0]:
				armed[0] = true
				rs.text = "Tap again: back to the starting layout"
				return
			_list_panel.visible = false
			_say("Starting layout: %d pieces back in place." % reset_layout(map)))
		_list_box.add_child(rs)
	_btn(_list_box, "Close", _toggle_list, 236)


func _choose(id: String) -> void:
	_list_panel.visible = false
	if is_surface(id):
		var room := room_at(cursor)
		var why := set_surface(map, room, id)
		_say(why if why != "" else "%s on the %s." % [str(Decor.entry(id).get("name", id)), room])
		return
	held = id
	moving = -1
	rot = 0
	_refresh()


## The wallpaper/flooring room under a cell (first room rect holding it; else "main").
func room_at(c: Vector2i) -> String:
	var rooms: Dictionary = _map_call(map, "decor_rooms", {})
	for r in rooms:
		var rr: Rect2i = rooms[r]
		if c.x >= rr.position.x and c.x < rr.end.x:
			return str(r)
	return "main"


func _cur_id() -> String:
	if moving >= 0:
		var list := placed(room_key(map))
		return str(list[moving].get("id", "")) if moving < list.size() else ""
	return held


func _confirm() -> void:
	if held != "":
		var why := place(map, held, cursor, rot)
		if why == "":
			Music.instance(get_tree()).sfx("thud", "pop")
			if Decor.owned(held) <= 0:
				held = ""
		else:
			Haptics.buzz("deny")
		_say(why if why != "" else "Placed.")
	elif moving >= 0:
		var why := move(map, moving, cursor, rot)
		if why == "":
			Music.instance(get_tree()).sfx("thud", "pop")
			moving = -1
		else:
			Haptics.buzz("deny")
		_say(why if why != "" else "Moved.")
	else:
		var i := piece_at(map, cursor)
		if i >= 0:
			_lift(i)
		else:
			_say("Nothing here. Open the Box to pick a piece.")
	_refresh()


func _lift(i: int) -> void:
	var list := placed(room_key(map))
	moving = i
	held = ""
	rot = int(list[i].get("rot", 0))
	cursor = _cell_of(list[i])
	Haptics.buzz("press", true)
	Music.instance(get_tree()).sfx("pop", "ui_tap")
	_say("Moving %s. Place it, or Store it in the box." % str(Decor.entry(str(list[i]["id"])).get("name", "")))


func _rotate() -> void:
	var id := _cur_id()
	if id == "":
		_say("Pick a piece first.")
		return
	if rot_count(id) <= 1:
		_say("This piece only faces one way.")
		return
	rot = (rot + 1) % rot_count(id)
	_refresh()


func _store() -> void:
	if moving >= 0:
		var id := pick(map, moving)
		moving = -1
		_say("%s is back in your decor box." % str(Decor.entry(id).get("name", id)))
	elif held != "":
		held = ""
		_say("Put away.")
	else:
		var i := piece_at(map, cursor)
		if i >= 0:
			var id := pick(map, i)
			_say("%s is back in your decor box." % str(Decor.entry(id).get("name", id)))
		else:
			_say("Nothing here to store.")
	_refresh()


func _undo() -> void:
	moving = -1
	_say("Undone." if undo(map) else "Nothing to undo.")
	_refresh()


func _step(d: Vector2i) -> void:
	var b := bounds(map)
	var lo := Vector2i(b.position.x, wall_row(map))
	var c := cursor + d
	cursor = Vector2i(clampi(c.x, lo.x, b.end.x - 1), clampi(c.y, lo.y, b.end.y - 1))
	_refresh()


func _say(t: String) -> void:
	if _status:
		_status.text = t


func _refresh() -> void:
	var id := _cur_id()
	if _ghost_sprite and is_instance_valid(_ghost_sprite):
		_ghost_sprite.queue_free()
		_ghost_sprite = null
	if id != "":
		_ghost_sprite = sprite_for(id, rot)
		if _ghost_sprite:
			_ghost_sprite.modulate = Color(1, 1, 1, 0.6)
			_ghost.add_child(_ghost_sprite)
		if _status and (_status.text == "" or _status.text.begins_with("Holding")):
			_say("Holding %s (%s)." % [str(Decor.entry(id).get("name", id)), Decor.rarity(id)])
	elif _status and _status.text == "":
		_say("Tap a piece to move it, or open the Box.")
	_ghost.queue_redraw()
	# Keep the cursor on screen (the Manor is 416 px wide, the phone view 270).
	var cam := map.get_viewport().get_camera_2d() if map.is_inside_tree() else null
	if cam and map.player:
		var dx := map.cell_pos(cursor.x, cursor.y).x + GameMap.TILE / 2.0 - map.player.position.x
		if absf(dx - cam.offset.x) > 80.0:
			cam.offset.x = dx


func _draw_ghost() -> void:
	var id := _cur_id()
	var cells: Array = footprint(id, cursor, rot) if id != "" else [cursor]
	var ok := id == "" or (why_not(map, id, cursor, rot, moving) == "")
	var col := OK_COL if ok else BAD_COL
	for c: Vector2i in cells:
		var p := map.cell_pos(c.x, c.y)
		var r := Rect2(p, Vector2(GameMap.TILE, GameMap.TILE))
		_ghost.draw_rect(r, col)
		_ghost.draw_rect(r, Color(col, 1.0), false, 1.0)
		if not ok:  # not just red: a cross on every blocked cell (colour-blind safe)
			_ghost.draw_line(r.position, r.end, Color(1, 1, 1, 0.8), 1.0)
			_ghost.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Color(1, 1, 1, 0.8), 1.0)
	if _ghost_sprite:
		var sz := size_of(id, rot)
		_ghost_sprite.position = map.cell_pos(cursor.x + sz.x / 2.0, cursor.y + 1)
		if layer_of(id) in ["wall", "window"]:
			_ghost_sprite.position.y = map.cell_pos(0, wall_row(map) + 1).y - 2.0


func _world_cell(screen: Vector2) -> Vector2i:
	var w := map.get_viewport().get_canvas_transform().affine_inverse() * screen
	return Vector2i(floori(w.x / GameMap.TILE) - map.pad, floori(w.y / GameMap.TILE) - map.pad)


func _input(ev: InputEvent) -> void:
	if _list_panel.visible:
		return
	var p := TapInput.press_pos(ev)
	if p != Vector2.INF:
		if DisplayMode.ui(p).y >= 480 - BAR_H:
			return  # the control bar
		_drag_from = p
		_dragging = false
		_tap_cell(_world_cell(p), false)
		get_viewport().set_input_as_handled()
		return
	if _drag_from != Vector2.INF and (ev is InputEventScreenDrag or (ev is InputEventMouseMotion and not TapInput.is_echo(ev))):
		_dragging = true
		var c := _world_cell(ev.position)
		if c != cursor:
			cursor = c
			_step(Vector2i.ZERO)
		get_viewport().set_input_as_handled()
		return
	if _drag_from == Vector2.INF and ev is InputEventMouseMotion and not TapInput.is_echo(ev) and DisplayMode.ui(ev.position).y < 480 - BAR_H:
		# Desktop: the ghost follows the mouse (hover), a click places / lifts.
		var hc := _world_cell(ev.position)
		var b := bounds(map)
		if hc != cursor and hc.x >= b.position.x and hc.x < b.end.x and hc.y >= wall_row(map) and hc.y < b.end.y:
			cursor = hc
			_step(Vector2i.ZERO)
		return
	if _drag_from != Vector2.INF and TapInput.is_release(ev):
		_drag_from = Vector2.INF
		get_viewport().set_input_as_handled()


## A tap on the room: first tap moves the cursor there; tapping the cursor's cell
## again places the held piece or lifts the piece standing there (no one-tap pickups).
func _tap_cell(c: Vector2i, _drag: bool) -> void:
	var b := bounds(map)
	if c.x < b.position.x - 1 or c.x > b.end.x or c.y < wall_row(map) - 1 or c.y > b.end.y:
		return
	if c == cursor:
		_confirm()
		return
	cursor = c
	_step(Vector2i.ZERO)
	var i := piece_at(map, c)
	if _cur_id() == "" and i >= 0:
		_say("%s. Tap again to pick it up." % str(Decor.entry(str(placed(room_key(map))[i]["id"])).get("name", "")))


func _process(delta: float) -> void:
	if Dialogue.input_blocked():
		return
	if _list_panel.visible:
		if Input.is_action_just_pressed("b") or Input.is_action_just_pressed("menu"):
			_toggle_list()
		return
	if Input.is_action_just_pressed("a"):
		_confirm()
	elif Input.is_action_just_pressed("b"):
		if held != "" or moving >= 0:
			held = ""
			moving = -1
			_say("Cancelled.")
			_refresh()
		else:
			close()
	elif Input.is_action_just_pressed("menu"):
		_toggle_list()
	elif Input.is_action_just_pressed("cycle_tool"):
		_rotate()
	elif Input.is_action_just_pressed("tool"):
		_store()
	_rep -= delta
	for dv: Array in [["left", Vector2i.LEFT], ["right", Vector2i.RIGHT], ["up", Vector2i.UP], ["down", Vector2i.DOWN]]:
		if Input.is_action_just_pressed(str(dv[0])):
			_step(dv[1])
			_rep = 0.32
		elif Input.is_action_pressed(str(dv[0])) and _rep <= 0.0:
			_step(dv[1])
			_rep = 0.09

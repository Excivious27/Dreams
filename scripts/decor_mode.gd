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
## relayout/load checks skip "someone stands there" (it is about taps, not saves).
static var _no_people := false
## Undo survives closing and re-opening on the same map (c10b_09-09); a new map starts clean.
static var _undo_map := 0
## relayout outdoors: every piece passed the walk check when it was placed; only
## reserved/blocked cells are re-checked (one farm-wide flood per piece was ~250 ms).
static var _no_reach := false
## relayout keeps the kept pieces' cells here (no O(n^2) decor_blocked scans).
static var _mine_override: Variant = null
static var _under_override: Variant = null
## Last relayout signature per room (house entry skips the full check when nothing changed).
static var _lay_sig := {}


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
	var out := {"placed": (d["placed"] as Dictionary).duplicate(true), "wall": (d["wall"] as Dictionary).duplicate(true), "floor": (d["floor"] as Dictionary).duplicate(true)}
	if d.get("ext", null) is Dictionary:
		out["ext"] = (d["ext"] as Dictionary).duplicate(true)  # P3's farmhouse exterior look rides along (c10b_01-06)
	return out


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


## The placement layer: the entry's "layer", normalised (C10b): catalogue wallpaper /
## flooring (cat wallpaper/flooring, layer wall/under in decor.json) are room surfaces;
## yard pieces (layer "outdoor") stand like floor pieces, flat ones ("flat", a path
## "seam" or sub path/flowerbed) lie like rugs.
static func layer_of(id: String) -> String:
	var e := Decor.entry(id)
	var cat := str(e.get("cat", ""))
	if cat == "wallpaper":
		return "wallpaper"
	if cat == "flooring":
		return "flooring"
	var ly := str(e.get("layer", "floor"))
	if ly == "outdoor":
		return "under" if (bool(e.get("flat", false)) or e.has("seam") or str(e.get("sub", "")) in ["path", "flowerbed"]) else "floor"
	return ly


## Where a piece may go: "in" (house), "out" (yard) or "both". Entry "where" wins;
## layer "outdoor" / cat outdoor_* default to the yard.
static func where_of(id: String) -> String:
	var e := Decor.entry(id)
	if e.has("where"):
		return str(e["where"])
	if str(e.get("layer", "")) == "outdoor" or str(e.get("cat", "")).begins_with("outdoor") or str(e.get("cat", "")) == "yard":
		return "out"
	return "in"


## A yard (outdoor) map: the farm answers decor_outdoor() true.
static func outdoor(m: GameMap) -> bool:
	return m != null and bool(_map_call(m, "decor_outdoor", false))


## This piece belongs on this map (house pieces indoors, yard pieces outdoors).
static func fits_map(m: GameMap, id: String) -> bool:
	var w := where_of(id)
	if outdoor(m):
		return w in ["out", "both"] and not (layer_of(id) in ["wall", "window", "wallpaper", "flooring"])
	return w in ["in", "both"]


## Name shown for a piece (arc names through Decor.display_name).
static func nm(id: String) -> String:
	return Decor.display_name(id) if Decor.is_decor(id) else id


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
	if rot % 2 == 1 and (rot_count(id) == 4 or (rot_count(id) == 2 and _has_side_view(id))):
		v = Vector2i(v.y, v.x)  # a real side view turns the footprint (c10b_08-09); mirrored-only pieces keep it
	return v


static func _has_side_view(id: String) -> bool:
	var e := Decor.entry(id)
	if e.get("rot_art", null) is Array and (e["rot_art"] as Array).size() > 1:
		return true
	var a := str(e.get("art", ""))
	var g := a.get_slice("/", 0) if a.contains("/") else "decor"
	var n := a.get_slice("/", 1) if a.contains("/") else id
	return Art.has(g, n + "_r1")


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
	if outdoor(m):
		# Outdoors blocked changes all day (debris cleared, sprinklers, regrowth): read
		# it live, minus the cells our own decor blocks (C10b c10b_02_03).
		var dc: Dictionary = m.get_meta("decor_cells", {})
		if dc.is_empty():
			return m.blocked
		var live := {}
		for c in m.blocked:
			if not dc.has(c):
				live[c] = true
		return live
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
		if not Decor.is_decor(str(p.get("id", ""))) or layer_of(str(p.get("id", ""))) != "floor":
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
	if not fits_map(m, id):
		return "That goes in your yard: Decorate yard on the farm." if where_of(id) == "out" else "That goes in your house: decorate from the dresser."
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
			return "That's outside your yard." if outdoor(m) else "That's outside the room."
	if outdoor(m):
		var ow := _yard_why(m, fp)
		if ow != "":
			return ow
	if layer == "under":
		var door := _map_call(m, "decor_door", Vector2i(-99, -99)) as Vector2i
		if _under_override is Dictionary:
			for c: Vector2i in fp:
				if (_under_override as Dictionary).has(c):
					return "A rug is already there."
		else:
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
	var mine: Dictionary = _mine_override if _mine_override is Dictionary else decor_blocked(m, skip)
	var who := {} if _no_people else occupied_cells(m)
	for c: Vector2i in fp:
		if res.has(c):
			return "That spot is needed (%s)." % str(res[c]) if res[c] is String else "That spot is needed."
		if fixed.has(c) or mine.has(c):
			return "Something is already there."
		if who.has(c):
			return str(who[c])
	var extra := {}
	for c: Vector2i in fp:
		extra[c] = true
	if not _no_reach and not reach_ok(m, extra, skip):
		return "That would block the way through."
	return ""


## Cells someone stands on (you, your pet and partner, co-op players): no standing
## piece may drop on them (they'd be stuck inside it). Cell -> reason.
static func occupied_cells(m: GameMap) -> Dictionary:
	var out := {}
	if m.player and is_instance_valid(m.player):
		out[m.player.cell()] = "You're standing there."
	for n: Variant in [m.pet, m.companion]:
		if n != null and is_instance_valid(n) and (n as Node2D).is_inside_tree():
			var pc := m.world_to_cell((n as Node2D).position)
			if not out.has(pc):
				out[pc] = "Someone is standing there."
	if Net.peers is Dictionary:
		for pid in Net.peers:
			var pe: Variant = Net.peers[pid]
			if pe is Dictionary and str((pe as Dictionary).get("scene", "")) == m.scene_id():
				var pv: Variant = (pe as Dictionary).get("pos", null)
				if pv is Array and (pv as Array).size() >= 2:
					out[m.world_to_cell(Vector2(float(pv[0]), float(pv[1])))] = "Someone is standing there."
	return out


## Debris kinds outdoors: clearable (open ground for the walk check, but nothing is placed on them).
const CLEARABLE := ["tree", "rock", "log", "stump", "bush", "weeds", "grass", "forage", "boulder"]


## Yard-only checks for a footprint (both layers): fields, placed things, debris,
## forage, exits and water. "" = fine.
static func _yard_why(m: GameMap, fp: Array) -> String:
	var farm: Dictionary = (view_run("farm") as Dictionary)
	var pl: Dictionary = (view_run("placed") as Dictionary)
	for c: Vector2i in fp:
		var k := "%d,%d" % [c.x, c.y]
		if farm.has(k):
			return "That's your field."
		if pl.has(k):
			return "Something is already there."
		var t: Variant = m.things.get(c, null)
		if t is Dictionary:
			var ty := str((t as Dictionary).get("type", ""))
			if ty in CLEARABLE:
				return "Clear it first."
			return "Something is already there."
	return ""


## A run block of the farm being decorated (the host's while visiting: guests never
## edit, but the walk/field checks still read the host's farm).
static func view_run(key: String) -> Variant:
	var v: Variant = GameState.run.get(key, {})
	return v if v is Dictionary else {}


## Every must-reach cell keeps an open neighbour reachable from the door. Outdoors
## a target the yard already can't reach (behind trees, a fenced field) is not held
## against the new piece: only what this piece would cut off counts.
static func reach_ok(m: GameMap, extra: Dictionary = {}, skip := -1) -> bool:
	var b := bounds(m)
	var start := _map_call(m, "decor_door", Vector2i(-99, -99)) as Vector2i
	if not b.has_point(start):
		return true
	var fixed := fixed_blocked(m)
	var mine := decor_blocked(m, skip)
	var yard := outdoor(m)
	var seen := _flood(m, b, start, fixed, mine, extra, yard)
	if seen.is_empty():
		return false
	var before := {}
	var targets: Array = _map_call(m, "decor_must_reach", [])
	for t: Vector2i in targets:
		var tc := Vector2i(clampi(t.x, b.position.x, b.end.x - 1), clampi(t.y, b.position.y, b.end.y - 1))
		if _near(seen, tc):
			continue
		if yard:
			if before.is_empty():
				before = _flood(m, b, start, fixed, mine, {}, yard)
			if not _near(before, tc):
				continue  # already out of reach without this piece
		return false
	return true


static func _near(seen: Dictionary, t: Vector2i) -> bool:
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.ZERO]:
		if seen.has(t + d):
			return true
	return false


static func _flood(m: GameMap, b: Rect2i, start: Vector2i, fixed: Dictionary, mine: Dictionary, extra: Dictionary, yard: bool) -> Dictionary:
	var open := func(c: Vector2i) -> bool:
		if not b.has_point(c) or mine.has(c) or extra.has(c):
			return false
		if not fixed.has(c):
			return true
		# Outdoors debris and tall grass are clearable: open ground for the walk check.
		return yard and m.things.get(c, {}) is Dictionary and str((m.things.get(c, {}) as Dictionary).get("type", "")) in CLEARABLE
	if not open.call(start):
		return {}
	var seen := {start: true}
	var q: Array = [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := c + d
			if not seen.has(n) and open.call(n):
				seen[n] = true
				q.append(n)
	return seen


## Index of the piece at a cell (wall pieces answer for their wall cells, rugs last;
## rug_first: the rug under the furniture, c10b_09-19).
static func piece_at(m: GameMap, c: Vector2i, rug_first := false) -> int:
	var list := placed(room_key(m))
	var rug := -1
	var top := -1
	for i in range(list.size() - 1, -1, -1):
		if not (list[i] is Dictionary) or not Decor.is_decor(str(list[i].get("id", ""))):
			continue
		var id := str(list[i].get("id", ""))
		if c in footprint(id, _cell_of(list[i]), int(list[i].get("rot", 0))):
			if layer_of(id) == "under":
				if rug < 0:
					rug = i
			elif top < 0:
				top = i
	if rug_first and rug >= 0:
		return rug
	return top if top >= 0 else rug


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
	elif can_decorate(m) and fits_map(m, sel):
		ToolHint.say(m, "Decorate to place things here (the Decorate button, or the dresser)." if not outdoor(m) else "Tap Decorate yard to place things out here.")
	elif where_of(sel) == "out":
		ToolHint.say(m, "Yard pieces go outside: Decorate yard on the farm.")
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
		"bulk":
			list.clear()
			list.append_array((op["placed"] as Array).duplicate(true))
			var d := Decor.st()
			for k in ["wall", "floor", "box"]:
				(d[k] as Dictionary).clear()
				(d[k] as Dictionary).merge((op[k] as Dictionary).duplicate(true))
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
static func store_all(m: GameMap, record := true) -> int:
	if not can_edit():
		return 0
	if record:
		undo_stack.append(_snapshot(m))  # the biggest change can be undone too (c10b_09-09)
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
	_changed(m)
	return n


## The whole room's state (pieces, surfaces, box) for undoing a bulk change.
static func _snapshot(m: GameMap) -> Dictionary:
	var d := Decor.st()
	return {"op": "bulk", "key": room_key(m), "placed": _own_placed(room_key(m)).duplicate(true), "wall": (d["wall"] as Dictionary).duplicate(true), "floor": (d["floor"] as Dictionary).duplicate(true), "box": (d["box"] as Dictionary).duplicate(true)}


## Store the room, then let the map put its starting pieces back (map.decor_reset()).
static func reset_layout(m: GameMap) -> int:
	if not can_edit() or not m.has_method("decor_reset"):
		return 0
	var snap := _snapshot(m)
	var depth := undo_stack.size()
	store_all(m, false)
	_no_people = true
	var n := int(m.call("decor_reset"))
	_no_people = false
	undo_stack.resize(mini(depth, undo_stack.size()))
	undo_stack.append(snap)
	return n


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
	var sig := hash([bounds(m), wall_row(m), (_map_call(m, "decor_reserved", {}) as Dictionary).keys(), _map_call(m, "decor_must_reach", []), _map_call(m, "decor_windows", []), fixed_blocked(m).keys(), list])
	if int(_lay_sig.get(room_key(m), 0)) == sig:
		return []  # nothing changed since the last check this session (c10b_12 #1)
	var gone: Array = []
	var keep: Array = []
	var unknown: Array = []
	for p in list:
		if not (p is Dictionary):
			continue
		if not Decor.is_decor(str(p.get("id", ""))):
			unknown.append(p)  # an id the catalogue dropped: keep the record, draw nothing (c10b_12)
			continue
		keep.append(p)
	list.clear()
	_no_people = true
	_no_reach = outdoor(m)
	var mine := {}
	var under := {}
	for p: Dictionary in keep:
		var id := str(p["id"])
		list.append(p)
		_mine_override = mine if _no_reach else null
		_under_override = under
		if why_not(m, id, _cell_of(p), int(p.get("rot", 0)), list.size() - 1) != "":
			list.pop_back()
			_box_back(id)
			gone.append(nm(id))
		else:
			for c: Vector2i in footprint(id, _cell_of(p), int(p.get("rot", 0))):
				if layer_of(id) == "floor":
					mine[c] = list.size() - 1
				elif layer_of(id) == "under":
					under[c] = true
	_mine_override = null
	_under_override = null
	_no_people = false
	_no_reach = false
	list.append_array(unknown)
	_lay_sig[room_key(m)] = hash([bounds(m), wall_row(m), (_map_call(m, "decor_reserved", {}) as Dictionary).keys(), _map_call(m, "decor_must_reach", []), _map_call(m, "decor_windows", []), fixed_blocked(m).keys(), list])
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
	var ra: Variant = Decor.entry(id).get("rot_art", null)
	if rot > 0 and ra is Array and rot < (ra as Array).size() and str(ra[rot]) != "":
		var r := str(ra[rot])  # explicit facing art (chair2_a_right/_up/_left, c10b_08-10)
		return [r.get_slice("/", 0), r.get_slice("/", 1), false] if r.contains("/") else [g, r, false]
	if rot > 0 and Art.has(g, n + "_r%d" % rot):
		return [g, n + "_r%d" % rot, false]
	# Windows follow the clock: a *_day piece shows its *_night twin after dark (c10b_08-28).
	if layer_of(id) == "window" and GameState.is_night():
		for pair: Array in [["_day", "_night"], ["day", "night"]]:
			if n.contains(str(pair[0])) and Art.has(g, n.replace(str(pair[0]), str(pair[1]))):
				return [g, n.replace(str(pair[0]), str(pair[1])), false]
	return [g, n, rot > 0 and rot_count(id) == 2]


## (Re)build every placed piece's sprite and blocking for this map. Cheap: one
## node per standing piece (y-sorted with the map), rugs/wall art baked (draw_flat)
## or, outdoors, drawn on one small layer of their own (never a farm re-bake).
## Outdoors tall pieces fade when you walk behind them, take their winter look and
## a lamp's wider glow (C10b c10b_02_10).
static func dress(m: GameMap) -> void:
	if not can_decorate(m):
		return
	var yard := outdoor(m)
	var fixed := fixed_blocked(m)
	# Incremental: a piece whose id/cell/facing/look didn't change keeps its node
	# (a full house no longer rebuilds 160 sprites per tap: c10b_12 / c10b_02_06).
	var old: Variant = m.get_meta("decor_nodes", [])
	var reuse := {}
	for n in old:
		if is_instance_valid(n) and not (n as Node).is_queued_for_deletion():
			var k := str((n as Node).get_meta("decor_sig", ""))
			if k != "" and not reuse.has(k):
				reuse[k] = n
			else:
				reuse[str((n as Node).get_instance_id())] = n
	var dead := {}
	var looks := "%s|%s" % [GameState.look_se() if yard else "", GameState.is_night()]
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
		var layer := layer_of(id)
		if not yard and is_flat(id):
			continue  # drawn into the baked map (draw_flat): no node, no draw call of its own
		if yard and layer == "under":
			continue  # the yard's flat layer draws it (_yard_flat)
		var sig := "%s|%d,%d|%d|%s" % [id, cell.x, cell.y, rot, looks]
		var fresh := false
		var s: Node2D = null
		if reuse.has(sig):
			s = reuse[sig]
			reuse.erase(sig)
		else:
			s = sprite_for(id, rot, yard)
			fresh = true
		if s == null:
			continue
		var sz := size_of(id, rot)
		var h := node_height(s)
		if fresh:
			s.position = m.cell_pos(cell.x + sz.x / 2.0, cell.y + 1)
			s.set_meta("decor_id", id)
			s.set_meta("decor_sig", sig)
			m.add_child(s)
		if layer == "under":
			if fresh:
				m.to_under(s)
		elif layer in ["wall", "window"]:
			s.position.y = m.cell_pos(0, wall_row(m) + 1).y - 2.0  # hangs on the wall, bottom just above the floor line
		else:
			for c: Vector2i in footprint(id, cell, rot):
				if bool(Decor.entry(id).get("walk", false)):
					continue  # gates and arches: you walk through them
				cells[c] = true
				m.blocked[c] = true
				m.hard[c] = true
			if fresh and yard and h > 30.0:
				m._canopies.append(s)  # tall yard pieces fade when you walk behind them
		if fresh and bool(Decor.entry(id).get("glow", false)) and m.glow and h > 0.0:
			var gr := float(Decor.entry(id).get("glow_r", 56.0 if yard else 34.0))
			m.glow.lights.append([s, gr, h * 0.7])
		nodes.append(s)
	for k in reuse:
		dead[reuse[k]] = true
		(reuse[k] as Node).queue_free()
	if not dead.is_empty():
		if m.glow:
			m.glow.lights = m.glow.lights.filter(func(l: Array) -> bool: return not dead.has(l[0]))
		m._canopies = m._canopies.filter(func(c: Variant) -> bool: return is_instance_valid(c) and not dead.has(c))
	if yard:
		var fl: Node2D = m.get_meta("decor_flat", null) if m.has_meta("decor_flat") else null
		if fl == null or not is_instance_valid(fl):
			fl = Node2D.new()
			fl.name = "DecorFlat"
			fl.draw.connect(func() -> void: _draw_yard_flat(m, fl))
			m.add_child(fl)
			m.to_under(fl)
			m.set_meta("decor_flat", fl)
		fl.queue_redraw()
	m.set_meta("decor_nodes", nodes)
	m.set_meta("decor_cells", cells)
	m._flows.clear()


## Drawn height of a decor node (Sprite2D or AnimatedSprite2D), in world px.
static func node_height(n: Node2D) -> float:
	if n is Sprite2D and (n as Sprite2D).texture:
		return (n as Sprite2D).texture.get_height() * n.scale.y
	if n is AnimatedSprite2D and (n as AnimatedSprite2D).sprite_frames:
		var sf := (n as AnimatedSprite2D).sprite_frames
		var an := (n as AnimatedSprite2D).animation
		if sf.has_animation(an) and sf.get_frame_count(an) > 0:
			return sf.get_frame_texture(an, 0).get_height() * n.scale.y
	return 0.0


## The yard's flat pieces (paths, flowerbeds, rugs laid outside) on one under-layer
## node: a path with a "seam" samples that seamless texture per cell (no box per
## cell), anything else fills its footprint.
static func _draw_yard_flat(m: GameMap, ci: Node2D) -> void:
	for p in placed(room_key(m)):
		if not (p is Dictionary) or not Decor.is_decor(str(p.get("id", ""))):
			continue
		var id := str(p["id"])
		if layer_of(id) != "under":
			continue
		var rot := int(p.get("rot", 0))
		var cell := _cell_of(p)
		var o := Vector2(m.pad * GameMap.TILE, m.pad * GameMap.TILE)
		var seam := str(Decor.entry(id).get("seam", ""))
		var st: Texture2D = Art.tex("seamless", seam) if seam != "" else null
		for c: Vector2i in footprint(id, cell, rot):
			if st:
				ci.draw_set_transform(o)
				_seam(ci, st, c, Vector2i.ONE)
				ci.draw_set_transform(Vector2.ZERO)
		if st:
			continue
		var a := art_of(id, rot)
		var t := Art.tex(str(a[0]), WorldGen.winter_look(str(a[0]), str(a[1])))
		if t == null:
			continue
		var sz := size_of(id, rot)
		ci.draw_texture_rect(t, Rect2(o + Vector2(cell.x * GameMap.TILE, (cell.y - sz.y + 1) * GameMap.TILE), Vector2(sz.x, sz.y) * GameMap.TILE), false)


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
			var k := _fit_k(id, rot, src.size.x, src.size.y)
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


static func _fit_k(id: String, rot: int, tw: float, th := 0.0) -> float:
	var w := float(size_of(id, rot).x * GameMap.TILE)
	var k := 0.5
	if tw * 0.5 > w * 1.35 or tw * 0.5 < w * 0.6:
		k = w / maxf(1.0, tw)
	if th > 0.0 and layer_of(id) in ["wall", "window"]:
		k = minf(k, (2.0 * GameMap.TILE - 2.0) / th)  # wall pieces stay inside the 2-row wall band (c10b_09-30)
	return k


## A piece's node, fitted to its footprint width (catalogue art comes at mixed
## scales): a Sprite2D, or an AnimatedSprite2D for strips with frames (fireplaces,
## crystal trees: c10b_08-24). `yard`: winter looks apply.
static func sprite_for(id: String, rot := 0, yard := false) -> Node2D:
	var a := art_of(id, rot)
	var g := str(a[0])
	var n := str(a[1])
	if yard:
		n = WorldGen.winter_look(g, n)
	var inf := Art.info(g, n)
	var fr := int(inf.get("frames", 1))
	var t := Art.tex(g, n)
	if t == null:
		return null
	var cw := float(inf.get("cell_w", t.get_width() / maxi(1, fr))) if fr > 1 else float(t.get_width())
	var k := _fit_k(id, rot, cw, float(t.get_height()))  # mixed source scales: fit the piece to its cells
	if fr > 1:
		var an := AnimatedSprite2D.new()
		an.sprite_frames = Art.frames(g, {"idle": n}, {"idle": float(inf.get("fps", Decor.entry(id).get("fps", 6)))})
		an.offset = Vector2(0, -t.get_height() / 2.0)
		an.scale = Vector2(k, k)
		an.flip_h = bool(a[2])
		an.play("idle")
		CrispArt.apply(an)
		return an
	var s := Art.sprite(g, n)
	s.scale = Vector2(k, k)
	s.flip_h = bool(a[2])
	CrispArt.apply(s)
	return s


# ---- room surfaces (wallpaper / flooring) -------------------------------------------

## interior.gd has no class_name: its statics through the script resource.
static func _interior() -> Variant:
	return load("res://scripts/interior.gd")


## The art a wallpaper/flooring draws with: its entry "style" (a tiles/ kit name,
## or group/name of a seamless texture), else its art (C10b c10b_09-01).
static func surface_art(id: String) -> Array:
	var st := str(Decor.entry(id).get("style", ""))
	if st != "":
		if st.contains("/"):
			return [st.get_slice("/", 0), st.get_slice("/", 1), false]
		return ["tiles", st, false]
	return art_of(id)


static func surface_of(kind: String, room: String) -> String:
	var id := str((view()[kind] as Dictionary).get(room, ""))
	return id if is_surface(id) else ""


## Draw one floor cell of a flooring entry: a seamless 256 texture (8-cell period)
## or a tiles/ floor set through Interior's gutter-safe painter. False = not drawable.
static func draw_floor_cell(ci: CanvasItem, id: String, c: Vector2i) -> bool:
	var a := surface_art(id)
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
	var a := surface_art(id)
	if str(a[0]) == "tiles":
		var mids: Array = (_interior().WALL_MIDS as Dictionary).get(str(a[1]), ["_m", "_m2", "_m3"])
		mids = mids.filter(func(mm: String) -> bool: return Art.has("tiles", str(a[1]) + mm))
		var nm: String = str(a[1]) + (part if part != "_m" else (str(mids[x % mids.size()]) if not mids.is_empty() else "_m"))
		if not Art.has("tiles", nm):
			nm = str(a[1]) + "_m"
		var t := Art.tex("tiles", nm)
		if t == null:
			return false
		ci.draw_texture_rect_region(t, Rect2(x * GameMap.TILE, 0, GameMap.TILE, GameMap.TILE * 2), _wall_src(t))
		return true
	var tx := Art.tex(str(a[0]), str(a[1]))
	if tx == null:
		return false
	_seam(ci, tx, Vector2i(x, 0), Vector2i(1, 2))
	return true


## A wall tile's source rect without the magenta key rules some kit sheets carry on
## their top/bottom rows and outer columns (c10b_08-29). Cached per texture.
static var _wall_src_cache := {}


static func _wall_src(t: Texture2D) -> Rect2:
	var key := t.resource_path if t.resource_path != "" else str(t.get_instance_id())
	if _wall_src_cache.has(key):
		return _wall_src_cache[key]
	var r := Rect2(Vector2.ZERO, t.get_size())
	var img := t.get_image()
	if img:
		if img.is_compressed():
			img.decompress()
		var w := img.get_width()
		var h := img.get_height()
		var pink_row := func(y: int) -> bool:
			var n := 0
			for x in w:
				var c := img.get_pixel(x, y)
				if c.a > 0.5 and c.r - c.g > 0.24 and c.b - c.g > 0.24:
					n += 1
			return n > w / 3
		var pink_col := func(x: int) -> bool:
			var n := 0
			for y in h:
				var c := img.get_pixel(x, y)
				if c.a > 0.5 and c.r - c.g > 0.24 and c.b - c.g > 0.24:
					n += 1
			return n > h / 3
		var top := 0
		while top < 3 and pink_row.call(top):
			top += 1
		var bot := 0
		while bot < 3 and pink_row.call(h - 1 - bot):
			bot += 1
		var lft := 0
		while lft < 2 and pink_col.call(lft):
			lft += 1
		var rgt := 0
		while rgt < 2 and pink_col.call(w - 1 - rgt):
			rgt += 1
		r = Rect2(lft, top, w - lft - rgt, h - top - bot)
	_wall_src_cache[key] = r
	return r


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

const PAGE_ROWS := 30        # box rows per page (a full catalogue is 700+ kinds: c10b_09-04/05)
const FILTERS := [["all", "All"], ["floor", "Furniture"], ["under", "Rugs"], ["wall", "Wall"], ["surface", "Rooms"]]
const YARD_FILTERS := [["all", "All"], ["floor", "Standing"], ["under", "Paths & beds"]]
## The box list remembers its filter, search and page between opens (c10b_09-32).
static var list_filter := "all"
static var list_search := ""
static var list_page := 0

var map: GameMap
var held := ""           # id held from the box ("" = none)
var moving := -1         # index of the placed piece being moved (-1 = none)
var rot := 0
var cursor := Vector2i.ZERO
var rug_first := false   # empty hands: Turn switches between the furniture and the rug under it
var _ghost: Node2D
var _ghost_sprite: Node2D
var _status: Label
var _tip: Label
var _bar: PanelContainer
var _bar_rect := Rect2()
var _btns := {}
var _list_panel: PanelContainer
var _list_box: VBoxContainer
var _list_head: VBoxContainer
var _list_sc: ScrollContainer
var _list_cur: ScreenCursor
var _confirm_row: HBoxContainer
var _drag_from := Vector2.INF
var _dragging := false
var _painted := {}
var _rep := 0.0
var _guard := 0.0        # just placed: a quick second tap doesn't lift it straight back (c10b_09-14)
var _player_was := false
var _hud_was := true
var _esc_frame := -1
var _hidden_node: Node2D
var _surf_room := ""     # the room wallpaper/flooring go on ("" = the room under the cursor)


## Why decorate mode can't open right now ("" = it can): fights, scenes, menus, riding.
static func busy_why(m: GameMap) -> String:
	if Story.is_playing() or GameMenu.story_busy(m.get_tree()):
		return "Not now: finish what's happening first."
	if DangerMusic.tier > 0:
		return "Not now: deal with the trouble first."
	if m.player and bool(m.player.get("mounted")):
		return "Hop off first to decorate."
	return ""


static func open(m: GameMap) -> DecorMode:
	if m == null:
		return null
	if Net.visiting():
		m.hud.toast("This is your host's home: only they can decorate it.", Color(1, 0.85, 0.6))
		return null
	if not can_decorate(m):
		m.hud.toast("You can decorate inside your house, or your yard on the farm.", Color(1, 0.9, 0.7))
		return null
	var bw := busy_why(m)
	if bw != "":
		m.hud.toast(bw, Color(1, 0.9, 0.7))
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
	if _undo_map != map.get_instance_id():
		undo_stack.clear()
		_undo_map = map.get_instance_id()
	var b := bounds(map)
	cursor = map.player.cell() if map.player and b.has_point(map.player.cell()) else b.position + b.size / 2
	if map.player and b.has_point(map.player.cell() + Vector2i.UP):
		cursor = map.player.cell() + Vector2i.UP  # not under your own feet
	_player_was = map.player.frozen if map.player else false
	if map.player:
		map.player.frozen = true
	if is_instance_valid(map.hud):
		_hud_was = map.hud.visible
		map.hud.visible = false  # hotbar, hearts and farm hints stay out of the way (c10b_09-16)
		if map.hud._toasts:
			for c in map.hud._toasts.get_children():
				c.queue_free()  # toasts on screen (a tool tip) would sit over the box list
			map.hud._toasts.visible = false
	_ghost = Node2D.new()
	_ghost.z_index = 50
	_ghost.process_mode = Node.PROCESS_MODE_ALWAYS
	_ghost.draw.connect(_draw_ghost)
	map.add_child(_ghost)
	_build_ui()
	Hud.pause(get_tree(), "decor")
	Hud.modal_rect = Rect2(0, 0, 270, 480)
	_say("Decorating your %s. Comfort %d." % ["yard" if outdoor(map) else "house", Decor.comfort(room_key(map))])
	_refresh()
	var tip_key := "decor_tip_yard" if outdoor(map) else "decor_tip"
	if not GameState.run["flags"].has(tip_key):
		GameState.run["flags"][tip_key] = true
		_say("Pick a piece from the Box, tap a spot, tap it again to place." + (" Drag a path to lay a row." if outdoor(map) else ""))


## One line under the status: the controls for the device in use (pad, keys or touch).
func _tip_text() -> String:
	if ScreenCursor.pad_active():
		return "%s place · %s back · %s turn · %s store · %s undo · %s box" % [InputSetup.prompt("a"), InputSetup.prompt("b"), InputSetup.prompt("cycle_tool"), InputSetup.prompt("tool"), InputSetup.prompt("ability"), InputSetup.prompt("menu")]
	if not TouchControls.visible_controls:
		return "Click place · right-click cancel · wheel turn · R undo · E box · Esc leave"
	return "Tap a spot, tap again to place or pick up. Drag to move."


func _exit_tree() -> void:
	if _ghost and is_instance_valid(_ghost):
		_ghost.queue_free()
	Hud.extra_rects.erase(_bar_rect)  # the rect recorded when it was added (c10b_09-18)
	if Hud.modal_rect == Rect2(0, 0, 270, 480):
		Hud.modal_rect = Rect2()
	if _hidden_node and is_instance_valid(_hidden_node):
		_hidden_node.modulate.a = 1.0
	if map and is_instance_valid(map) and is_instance_valid(map.hud) and map.hud._toasts:
		map.hud._toasts.visible = true


func close() -> void:
	Hud.modal_rect = Rect2()
	Hud.extra_rects.erase(_bar_rect)
	if not Hud.keep_paused(get_tree(), self):
		get_tree().paused = false
	if map and map.player:
		map.player.frozen = _player_was
		var cam := map.get_viewport().get_camera_2d()
		if cam:
			cam.offset = Vector2.ZERO
	if map and is_instance_valid(map.hud):
		map.hud.visible = _hud_was
		if map.hud._toasts:
			map.hud._toasts.visible = true
	Dialogue.block_input()
	queue_free()


func _btn(parent: Control, text: String, cb: Callable, w := 42.0, any_time := false) -> Button:
	var bt := Button.new()
	bt.text = text
	bt.custom_minimum_size = Vector2(w, 26)
	bt.add_theme_font_size_override("font_size", Settings.font(9))
	bt.clip_text = true
	bt.focus_mode = Control.FOCUS_NONE
	bt.pressed.connect(func() -> void:
		if not any_time and _list_panel and _list_panel.visible:
			return  # the room is hidden under the list: its buttons wait (c10b_09-24)
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
	root.add_child(_bar)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	_bar.add_child(v)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(250, Settings.font(9) * 2.0 + 6.0)  # two lines, sized before layout
	_status.max_lines_visible = 2
	_status.add_theme_font_size_override("font_size", Settings.font(9))
	v.add_child(_status)
	_tip = Label.new()
	_tip.custom_minimum_size = Vector2(250, Settings.font(7) + 4.0)
	_tip.clip_text = true
	_tip.add_theme_font_size_override("font_size", Settings.font(7))
	_tip.modulate = Color(1, 1, 1, 0.75)
	v.add_child(_tip)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 3)
	v.add_child(row1)
	_btns["box"] = _btn(row1, "Box", _toggle_list, 48, true)
	_btns["place"] = _btn(row1, "Place", _confirm, 48)
	_btns["turn"] = _btn(row1, "Turn", _rotate, 48)
	_btns["store"] = _btn(row1, "Store", _store, 48)
	_btns["undo"] = _btn(row1, "Undo", _undo, 48)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 3)
	v.add_child(row2)
	for dv: Array in [["◀", Vector2i.LEFT], ["▲", Vector2i.UP], ["▼", Vector2i.DOWN], ["▶", Vector2i.RIGHT]]:
		var dd: Vector2i = dv[1]
		_btn(row2, str(dv[0]), func() -> void: _step(dd), 30)
	_btns["done"] = _btn(row2, "Done", close, 116)
	# The bar's height follows its contents (Text size larger grows it): it always
	# ends at the screen's bottom edge (c10b_09-07).
	var h := maxf(BAR_H - 2.0, v.get_combined_minimum_size().y + 16.0)
	_bar.position = Vector2(2, 480 - h - 2)
	_bar.size = Vector2(266, h)
	_bar_rect = Rect2(_bar.position, _bar.size)
	Hud.extra_rects.append(_bar_rect)
	_list_panel = PanelContainer.new()
	_list_panel.add_theme_stylebox_override("panel", Hud.panel_stylebox("panel_wood"))
	_list_panel.position = Vector2(6, 22)
	_list_panel.size = Vector2(258, _bar.position.y - 26)
	_list_panel.visible = false
	root.add_child(_list_panel)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 2)
	_list_panel.add_child(lv)
	_list_head = VBoxContainer.new()
	_list_head.add_theme_constant_override("separation", 2)
	lv.add_child(_list_head)
	_list_sc = ScrollContainer.new()
	_list_sc.custom_minimum_size = Vector2(250, 60)
	_list_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(_list_sc)
	_list_box = VBoxContainer.new()
	_list_box.custom_minimum_size = Vector2(240, 0)
	_list_sc.add_child(_list_box)
	_list_cur = ScreenCursor.make(self, _list_panel)
	_list_cur.enabled = false
	_list_cur.on_page = func(_d: int) -> void: _page(1)


## Box rows: every piece the box holds that belongs on this map (house or yard),
## through the filter and search, rarest first.
func box_ids() -> Array:
	var ids: Array = []
	var q := list_search.strip_edges().to_lower()
	for id in (Decor.st()["box"] as Dictionary):
		var sid := str(id)
		if not (placeable(sid) or is_surface(sid)) or Decor.owned(sid) <= 0 or not fits_map(map, sid):
			continue
		if not _filter_ok(sid):
			continue
		if q != "" and not nm(sid).to_lower().contains(q):
			continue
		ids.append(sid)
	_new_cache = _new_set()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var na := is_new(a)
		var nb := is_new(b)
		if na != nb:
			return na  # new pieces first (c10b_09-32)
		var ra := Decor.rarity_rank(Decor.rarity(a))
		var rb := Decor.rarity_rank(Decor.rarity(b))
		return ra > rb if ra != rb else nm(a) < nm(b))
	return ids


## Arrived in the last two days and never placed: marked "new" in the box list.
static var _new_cache := {}


static func is_new(id: String) -> bool:
	return _new_cache.has(id)


## One pass over got + every placed piece (no per-id placed scans).
static func _new_set() -> Dictionary:
	var day := int(GameState.run.get("day", 1))
	var out := {}
	var got: Dictionary = Decor.st()["got"]
	for id in got:
		if int(got[id]) >= day - 1:
			out[str(id)] = true
	if out.is_empty():
		return out
	var pl: Dictionary = Decor.st()["placed"]
	for room in pl:
		if pl[room] is Array:
			for p in pl[room]:
				if p is Dictionary:
					out.erase(str(p.get("id", "")))
	return out


func _filter_ok(id: String) -> bool:
	var ly := layer_of(id)
	match list_filter:
		"floor":
			return ly == "floor"
		"under":
			return ly == "under"
		"wall":
			return ly in ["wall", "window"]
		"surface":
			return ly in SURFACE_LAYERS
	return true


## Where a piece goes and its size, for its row (c10b_09-21).
static func where_word(id: String) -> String:
	var ly := layer_of(id)
	var w: String = {"floor": "floor", "under": "rug", "wall": "wall", "window": "window", "wallpaper": "wallpaper", "flooring": "flooring"}.get(ly, ly)
	if where_of(id) == "out":
		w = "yard" if ly == "floor" else "path/bed"
	var sz := size_of(id)
	return w if ly in SURFACE_LAYERS or sz == Vector2i.ONE else "%s %dx%d" % [w, sz.x, sz.y]


func _toggle_list() -> void:
	_list_panel.visible = not _list_panel.visible
	_list_cur.enabled = _list_panel.visible
	if _list_panel.visible:
		_fill_list()
		Music.instance(get_tree()).sfx("page", "ui_tap")


func _small(parent: Control, text: String, cb: Callable, w: float) -> Button:
	var bt := Button.new()
	bt.text = text
	bt.custom_minimum_size = Vector2(w, 22)
	bt.clip_text = true
	bt.add_theme_font_size_override("font_size", Settings.font(8))
	bt.focus_mode = Control.FOCUS_NONE
	bt.set_meta("pc_key", "b:" + text)
	bt.pressed.connect(func() -> void:
		Music.instance(get_tree()).sfx("ui_tap")
		cb.call())
	parent.add_child(bt)
	return bt


func _fill_list() -> void:
	var keep_scroll := _list_sc.scroll_vertical
	for c in _list_head.get_children():
		c.queue_free()
	for c in _list_box.get_children():
		c.queue_free()
	# Top: close and the bulk actions (never at the bottom of hundreds of rows).
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 2)
	_list_head.add_child(top)
	_small(top, "Close", _toggle_list, 50)
	_small(top, "Store all", func() -> void: _ask("store"), 72)
	if map.has_method("decor_reset"):
		_small(top, "Starting layout", func() -> void: _ask("reset"), 104)
	_confirm_row = HBoxContainer.new()
	_confirm_row.visible = false
	_list_head.add_child(_confirm_row)
	# Filters (house: furniture/rugs/wall/rooms; yard: standing/paths) and search.
	var fr := HBoxContainer.new()
	fr.add_theme_constant_override("separation", 2)
	_list_head.add_child(fr)
	var filters: Array = YARD_FILTERS if outdoor(map) else FILTERS
	if not filters.any(func(f: Array) -> bool: return str(f[0]) == list_filter):
		list_filter = "all"
	for f: Array in filters:
		var fid := str(f[0])
		var fb := _small(fr, ("• " if fid == list_filter else "") + str(f[1]), func() -> void:
			list_filter = fid
			list_page = 0
			_list_sc.scroll_vertical = 0
			_fill_list(), 250.0 / filters.size() - 2.0)
		fb.set_meta("pc_key", "f:" + fid)
	var sr := HBoxContainer.new()
	_list_head.add_child(sr)
	var le := LineEdit.new()
	le.placeholder_text = "Search names"
	le.text = list_search
	le.custom_minimum_size = Vector2(180, 22)
	le.add_theme_font_size_override("font_size", Settings.font(8))
	le.text_submitted.connect(func(t: String) -> void:
		list_search = t
		list_page = 0
		_fill_list())
	sr.add_child(le)
	_small(sr, "Clear" if list_search != "" else "Go", func() -> void:
		list_search = "" if list_search != "" else le.text
		list_page = 0
		_fill_list(), 64)
	var ids := box_ids()
	var pages := maxi(1, ceili(ids.size() / float(PAGE_ROWS)))
	list_page = clampi(list_page, 0, pages - 1)
	# Room picker for wallpaper/flooring: name the room instead of walking the cursor there (c10b_09-20).
	var rooms: Dictionary = _map_call(map, "decor_rooms", {})
	if rooms.size() > 1 and list_filter in ["all", "surface"]:
		var rr := HBoxContainer.new()
		rr.add_theme_constant_override("separation", 2)
		_list_head.add_child(rr)
		var cur_room := _surf_room if rooms.has(_surf_room) else room_at(cursor)
		for rm in rooms:
			var rid := str(rm)
			var rb := _small(rr, ("• " if rid == cur_room else "") + rid.capitalize(), func() -> void:
				_surf_room = rid
				_fill_list(), 250.0 / rooms.size() - 2.0)
			rb.set_meta("pc_key", "room:" + rid)
	var head := Label.new()
	var room_line := "" if outdoor(map) else "  ·  Rooms: wallpaper/flooring go on the %s" % (_surf_room if rooms.has(_surf_room) else room_at(cursor))
	head.text = "%d kinds%s%s" % [ids.size(), ("  ·  page %d/%d" % [list_page + 1, pages]) if pages > 1 else "", room_line]
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size = Vector2(246, 0)
	head.add_theme_font_size_override("font_size", Settings.font(7))
	_list_head.add_child(head)
	if pages > 1:
		var pr := HBoxContainer.new()
		_list_head.add_child(pr)
		_small(pr, "◀ Prev", func() -> void: _page(-1), 122)
		_small(pr, "Next ▶", func() -> void: _page(1), 122)
	if ids.is_empty():
		var l := Label.new()
		l.text = "Nothing here. Decor from shops, prizes and finds lands in your box." if list_search == "" and list_filter == "all" else "Nothing matches."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(230, 40)
		l.add_theme_font_size_override("font_size", Settings.font(9))
		_list_box.add_child(l)
	# Only this page's rows (and icons) are built.
	for id: String in ids.slice(list_page * PAGE_ROWS, (list_page + 1) * PAGE_ROWS):
		var r := Decor.rarity(id)
		var bt := Button.new()
		bt.text = "%s%s  x%d · %s" % ["★ " if is_new(id) else "", nm(id), Decor.owned(id), where_word(id)]
		bt.tooltip_text = "%s %s" % [Decor.rarity_glyph(r), r.capitalize()]
		bt.alignment = HORIZONTAL_ALIGNMENT_LEFT
		bt.clip_text = true
		bt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		bt.custom_minimum_size = Vector2(238, 24)
		bt.add_theme_font_size_override("font_size", Settings.font(8))
		bt.add_theme_color_override("font_color", Decor.rarity_color(r))
		bt.focus_mode = Control.FOCUS_NONE
		bt.set_meta("pc_key", "id:" + id)
		var ia := surface_art(id) if is_surface(id) else art_of(id)
		var itx := Art.tex(str(ia[0]), str(ia[1]) + ("_icon" if Art.has(str(ia[0]), str(ia[1]) + "_icon") else ""))
		if itx == null and Art.has(str(ia[0]), str(ia[1]) + "_m"):
			itx = Art.tex(str(ia[0]), str(ia[1]) + "_m")
		if itx:
			bt.icon = itx
			bt.expand_icon = true
			bt.add_theme_constant_override("icon_max_width", 20)
		bt.pressed.connect(_choose.bind(id))
		_list_box.add_child(bt)
	_list_sc.set_deferred("scroll_vertical", keep_scroll)


func _page(d: int) -> void:
	list_page += d
	_list_sc.scroll_vertical = 0
	_fill_list()


## Store all / Starting layout ask on a separate Yes / No row: a double tap on the
## same button can no longer wipe the room (c10b_09-31).
func _ask(what: String) -> void:
	for c in _confirm_row.get_children():
		c.queue_free()
	var l := Label.new()
	l.text = "Store every piece?" if what == "store" else "Back to the starting layout?"
	l.custom_minimum_size = Vector2(130, 22)
	l.add_theme_font_size_override("font_size", Settings.font(8))
	_confirm_row.add_child(l)
	_small(_confirm_row, "No", func() -> void: _confirm_row.visible = false, 44)
	_small(_confirm_row, "Yes", func() -> void:
		_confirm_row.visible = false
		held = ""
		_set_moving(-1)  # the indexes are gone (c10b_09-22)
		_list_panel.visible = false
		_list_cur.enabled = false
		if what == "store":
			_say("%d pieces back in your decor box. Undo puts them back." % store_all(map))
		else:
			_say("Starting layout: %d pieces back in place. Undo goes back." % reset_layout(map))
		Music.instance(get_tree()).sfx("drop", "pop")
		_refresh(), 60)
	_confirm_row.visible = true


func _choose(id: String) -> void:
	_list_panel.visible = false
	_list_cur.enabled = false
	_status.text = ""
	if is_surface(id):
		var rooms: Dictionary = _map_call(map, "decor_rooms", {})
		var room := _surf_room if rooms.has(_surf_room) else room_at(cursor)
		var why := set_surface(map, room, id)
		if why == "":
			Music.instance(get_tree()).sfx("cloth", "ui_tap")
		_say(why if why != "" else "%s on the %s. Undo takes it back." % [nm(id), room])
		return
	held = id
	_set_moving(-1)
	rot = 0
	_say("Holding %s (%s)." % [nm(id), where_word(id)])
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


## The footprint cell (bottom-left) for the cursor: wide pieces centre on it and wall
## pieces hang on the back wall above it (c10b_09-26 / c10b_09-06).
func _anchor(id: String) -> Vector2i:
	if id == "":
		return cursor
	var sz := size_of(id, rot)
	var c := cursor - Vector2i((sz.x - 1) / 2, 0)
	if layer_of(id) in ["wall", "window"]:
		c.y = wall_row(map)
	return c


## The piece being moved is drawn faint at its old spot (only the ghost reads solid).
func _set_moving(i: int) -> void:
	moving = i
	if _hidden_node and is_instance_valid(_hidden_node):
		_hidden_node.modulate.a = 1.0
	_hidden_node = null
	if i < 0:
		return
	var list := placed(room_key(map))
	if i >= list.size():
		return
	var cell := _cell_of(list[i])
	for n in map.get_meta("decor_nodes", []):
		if is_instance_valid(n) and str((n as Node).get_meta("decor_id", "")) == str(list[i]["id"]):
			var sz := size_of(str(list[i]["id"]), int(list[i].get("rot", 0)))
			if (n as Node2D).position.distance_to(map.cell_pos(cell.x + sz.x / 2.0, cell.y + 1)) < 2.0 or layer_of(str(list[i]["id"])) in ["wall", "window"] and absf((n as Node2D).position.x - map.cell_pos(cell.x + sz.x / 2.0, 0).x) < 2.0:
				_hidden_node = n
				(n as Node2D).modulate.a = 0.25
				break


func _deny(why: String) -> void:
	Haptics.buzz("deny")
	Music.instance(get_tree()).sfx("status_tick", "ui_tap")
	_say(why)


func _confirm() -> void:
	var id := _cur_id()
	if held != "":
		var why := place(map, held, _anchor(held), rot)
		if why == "":
			Music.instance(get_tree()).sfx("step_stone" if outdoor(map) and layer_of(held) == "under" else "thud", "pop")
			_guard = 0.45
			if Decor.owned(held) <= 0:
				held = ""
			_say("Placed. Comfort %d." % Decor.comfort(room_key(map)))
		else:
			_deny(why)
	elif moving >= 0:
		var why := move(map, moving, _anchor(id), rot)
		if why == "":
			Music.instance(get_tree()).sfx("thud", "pop")
			_set_moving(-1)
			_guard = 0.45
			_say("Moved.")
		else:
			_deny(why)
	else:
		if _guard > 0.0:
			return
		var i := piece_at(map, cursor, rug_first)
		if i >= 0:
			_lift(i)
		else:
			_say("Nothing here. Open the Box to pick a piece.")
	_refresh()


func _lift(i: int) -> void:
	var list := placed(room_key(map))
	held = ""
	rot = int(list[i].get("rot", 0))
	var id := str(list[i]["id"])
	var sz := size_of(id, rot)
	cursor = _cell_of(list[i]) + Vector2i((sz.x - 1) / 2, 0)
	if layer_of(id) in ["wall", "window"]:
		cursor.y = wall_row(map) + 1
	_set_moving(i)
	rug_first = false
	Haptics.buzz("press", true)
	Music.instance(get_tree()).sfx("pop", "ui_tap")
	_say("Moving %s. Place it, or Store it in the box." % nm(id))


func _rotate() -> void:
	var id := _cur_id()
	if id == "":
		var i := piece_at(map, cursor)
		var r := piece_at(map, cursor, true)
		if i >= 0 and r >= 0 and i != r:
			rug_first = not rug_first  # furniture on a rug: choose which one a tap picks up
			_say("Picking up the %s here." % ("rug" if rug_first else "furniture"))
			_refresh()
			return
		_say("Pick a piece first.")
		return
	if rot_count(id) <= 1:
		_say("This piece only faces one way.")
		return
	rot = (rot + 1) % rot_count(id)
	Music.instance(get_tree()).sfx("cloth", "ui_tap")
	_refresh()


func _store() -> void:
	if moving >= 0:
		var id := pick(map, moving)
		_set_moving(-1)
		_say("%s is back in your decor box." % nm(id))
	elif held != "":
		held = ""
		_say("Put away.")
	else:
		var i := piece_at(map, cursor, rug_first)
		if i >= 0:
			var id := pick(map, i)
			_say("%s is back in your decor box." % nm(id))
		else:
			_say("Nothing here to store.")
			_refresh()
			return
	Music.instance(get_tree()).sfx("drop", "pop")
	_refresh()


func _undo() -> void:
	_set_moving(-1)
	var ok := undo(map)
	if ok:
		Music.instance(get_tree()).sfx("page", "ui_tap")
	_say("Undone." if ok else "Nothing to undo.")
	_refresh()


func _step(d: Vector2i, pan := true) -> void:
	var b := bounds(map)
	var lo := Vector2i(b.position.x, wall_row(map) if not outdoor(map) else b.position.y)
	var c := cursor + d
	cursor = Vector2i(clampi(c.x, lo.x, b.end.x - 1), clampi(c.y, lo.y, b.end.y - 1))
	_refresh(pan)


func _say(t: String) -> void:
	if _status:
		_status.text = t


func _refresh(pan := true) -> void:
	var id := _cur_id()
	if _ghost_sprite and is_instance_valid(_ghost_sprite):
		_ghost_sprite.queue_free()
		_ghost_sprite = null
	if id != "":
		_ghost_sprite = sprite_for(id, rot, outdoor(map))
		if _ghost_sprite:
			_ghost_sprite.modulate = Color(1, 1, 1, 0.6)
			_ghost.add_child(_ghost_sprite)
		var why := why_not(map, id, _anchor(id), rot, moving)
		if why != "":
			_say(why)  # the reason shows while you aim, not only after Place
		elif _status and (_status.text == "" or not _status.text.begins_with("Placed")):
			_say("%s %s%s." % ["Moving" if moving >= 0 else "Holding", nm(id), "" if outdoor(map) else " · " + room_at(cursor)])
	elif _status and _status.text == "":
		_say("Tap a piece to move it, or open the Box.")
	if _tip:
		_tip.text = _tip_text()
	if _btns.has("place"):
		var under := piece_at(map, cursor, rug_first)
		(_btns["place"] as Button).text = "Place" if id != "" else ("Pick up" if under >= 0 else "Place")
		(_btns["store"] as Button).text = "Cancel" if held != "" else "Store"
	_ghost.queue_redraw()
	if pan:
		_pan()


## Keep the cursor on screen: the camera pans (both ways) only when the cursor
## leaves an inner box, and never past the map; a room that fits the view never
## pans (c10b_09-29 / c10b_02_11). Mouse hover never pans (c10b_09-12).
func _pan() -> void:
	var cam := map.get_viewport().get_camera_2d() if map.is_inside_tree() else null
	if cam == null or map.player == null:
		return
	var view := map.get_viewport().get_visible_rect().size / cam.zoom
	var b := bounds(map)
	var top := (wall_row(map) - 1) if not outdoor(map) else b.position.y
	var area := Rect2(map.cell_pos(b.position.x, top), Vector2(b.size.x, b.end.y - top) * GameMap.TILE)
	var cp := map.cell_pos(cursor.x + 0.5, cursor.y + 0.5)
	var free_h := view.y - (480.0 - _bar_rect.position.y)  # the bar covers the bottom
	var off := cam.offset
	for ax in 2:
		var span := view.x if ax == 0 else free_h
		var a_len := area.size.x if ax == 0 else area.size.y
		if a_len <= span - 8.0:
			off[ax] = 0.0
			continue
		var centre := map.player.position[ax] + off[ax] - (0.0 if ax == 0 else (480.0 - _bar_rect.position.y) / 2.0)
		var inner := span * 0.3
		if cp[ax] < centre - inner:
			off[ax] += cp[ax] - (centre - inner)
		elif cp[ax] > centre + inner:
			off[ax] += cp[ax] - (centre + inner)
		# Never past the room/yard edge: no black void beside the Manor (c10b_09-11).
		var lo := (area.position.x if ax == 0 else area.position.y) + span / 2.0
		var hi := (area.end.x if ax == 0 else area.end.y) - span / 2.0
		var shift := 0.0 if ax == 0 else (480.0 - _bar_rect.position.y) / 2.0
		var c2 := map.player.position[ax] + off[ax] - shift
		off[ax] += clampf(c2, lo, hi) - c2
	cam.offset = off


func _draw_ghost() -> void:
	var id := _cur_id()
	if id == "":
		# Empty hands: outline what a tap would pick up (c10b_09-34).
		var i := piece_at(map, cursor, rug_first)
		if i >= 0:
			var p: Dictionary = placed(room_key(map))[i]
			for c: Vector2i in footprint(str(p["id"]), _cell_of(p), int(p.get("rot", 0))):
				_ghost.draw_rect(Rect2(map.cell_pos(c.x, c.y), Vector2(GameMap.TILE, GameMap.TILE)), Color(1, 0.85, 0.3, 0.9), false, 1.0)
	var at := _anchor(id)
	var cells: Array = footprint(id, at, rot) if id != "" else [cursor]
	var ok := id == "" or (why_not(map, id, at, rot, moving) == "")
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
		_ghost_sprite.position = map.cell_pos(at.x + sz.x / 2.0, at.y + 1)
		if layer_of(id) in ["wall", "window"]:
			_ghost_sprite.position.y = map.cell_pos(0, wall_row(map) + 1).y - 2.0


func _world_cell(screen: Vector2) -> Vector2i:
	var w := map.get_viewport().get_canvas_transform().affine_inverse() * screen
	return Vector2i(floori(w.x / GameMap.TILE) - map.pad, floori(w.y / GameMap.TILE) - map.pad)


## A 1x1 yard path/bed being painted by dragging (one per crossed cell).
func _paints() -> bool:
	return held != "" and outdoor(map) and size_of(held, rot) == Vector2i.ONE


func _input(ev: InputEvent) -> void:
	# Desktop keys and mouse buttons (c10b_09-13).
	if ev is InputEventKey and (ev as InputEventKey).pressed and not (ev as InputEventKey).echo:
		var k := (ev as InputEventKey).keycode
		if k == KEY_ESCAPE:
			_esc_frame = Engine.get_process_frames()
			_back()
			get_viewport().set_input_as_handled()
			return
		if k == KEY_Z and (ev as InputEventKey).ctrl_pressed:
			_undo()
			get_viewport().set_input_as_handled()
			return
	if _list_panel.visible:
		# A tap outside the list closes it (c10b_09-38).
		var lp := TapInput.press_pos(ev)
		if lp != Vector2.INF:
			var u := DisplayMode.ui(lp)
			if not Rect2(_list_panel.position, _list_panel.size).has_point(u) and not _bar_rect.has_point(u):
				_toggle_list()
				get_viewport().set_input_as_handled()
		return
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var mb := (ev as InputEventMouseButton).button_index
		if mb == MOUSE_BUTTON_RIGHT:
			_back(false)
			get_viewport().set_input_as_handled()
			return
		if mb == MOUSE_BUTTON_WHEEL_UP or mb == MOUSE_BUTTON_WHEEL_DOWN:
			if _cur_id() != "":
				_rotate()
			get_viewport().set_input_as_handled()
			return
	var p := TapInput.press_pos(ev)
	if p != Vector2.INF:
		if _bar_rect.has_point(DisplayMode.ui(p)):
			return  # the control bar
		_drag_from = p
		_dragging = false
		_painted = {}
		_tap_cell(_world_cell(p), false)
		get_viewport().set_input_as_handled()
		return
	if _drag_from != Vector2.INF and (ev is InputEventScreenDrag or (ev is InputEventMouseMotion and not TapInput.is_echo(ev))):
		if not _dragging and ev.position.distance_to(_drag_from) < 6.0:
			return
		_dragging = true
		var c := _world_cell(ev.position)
		if c != cursor:
			cursor = c
			_step(Vector2i.ZERO)
			if _paints() and not _painted.has(c) and why_not(map, held, c, rot) == "":
				_painted[c] = true
				_confirm()  # paint: one piece per crossed cell
		get_viewport().set_input_as_handled()
		return
	if _drag_from == Vector2.INF and ev is InputEventMouseMotion and not TapInput.is_echo(ev) and not _bar_rect.has_point(DisplayMode.ui(ev.position)):
		# Desktop: the ghost follows the mouse (hover; the camera stays put), a click places / lifts.
		var hc := _world_cell(ev.position)
		var b := bounds(map)
		var top := wall_row(map) if not outdoor(map) else b.position.y
		if hc != cursor and hc.x >= b.position.x and hc.x < b.end.x and hc.y >= top and hc.y < b.end.y:
			cursor = hc
			_step(Vector2i.ZERO, false)
		return
	if _drag_from != Vector2.INF and TapInput.is_release(ev):
		var was := _dragging
		_drag_from = Vector2.INF
		_dragging = false
		if was and moving >= 0:
			_confirm()  # drag-to-move drops where you let go (c10b_09-14)
		get_viewport().set_input_as_handled()


## B / Esc / right-click: drop what you hold, else close the list, else leave.
func _back(can_leave := true) -> void:
	if _list_panel.visible:
		_toggle_list()
	elif held != "" or moving >= 0:
		held = ""
		_set_moving(-1)
		_say("Cancelled.")
		_refresh()
	elif can_leave:
		close()


## A tap on the room: first tap moves the cursor there; tapping the cursor's cell
## again places the held piece or lifts the piece standing there (no one-tap pickups).
func _tap_cell(c: Vector2i, _drag: bool) -> void:
	var b := bounds(map)
	var top := wall_row(map) if not outdoor(map) else b.position.y
	if c.x < b.position.x - 1 or c.x > b.end.x or c.y < top - 1 or c.y > b.end.y:
		return
	if c == cursor:
		if _paints() and _painted.has(c):
			return
		_confirm()
		if _paints():
			_painted[c] = true
		return
	cursor = c
	_step(Vector2i.ZERO)
	var i := piece_at(map, c, rug_first)
	if _cur_id() == "" and i >= 0:
		_say("%s. Tap again to pick it up." % nm(str(placed(room_key(map))[i]["id"])))


func _process(delta: float) -> void:
	_guard = maxf(0.0, _guard - delta)
	if Dialogue.input_blocked():
		return
	if _list_panel.visible:
		if Input.is_action_just_pressed("b") or (Input.is_action_just_pressed("menu") and _esc_frame != Engine.get_process_frames()):
			_toggle_list()
		elif _list_cur.cur and is_instance_valid(_list_cur.cur) and _list_cur.shown and _list_sc.is_ancestor_of(_list_cur.cur):
			_list_sc.ensure_control_visible(_list_cur.cur)
		return
	if Input.is_action_just_pressed("a"):
		_confirm()
	elif Input.is_action_just_pressed("b"):
		_back()
	elif Input.is_action_just_pressed("menu") and _esc_frame != Engine.get_process_frames():
		_toggle_list()
	elif Input.is_action_just_pressed("cycle_tool"):
		_rotate()
	elif Input.is_action_just_pressed("tool"):
		_store()
	elif InputMap.has_action("ability") and Input.is_action_just_pressed("ability"):
		_undo()  # pad / R key: Undo (c10b_09-03)
	_rep -= delta
	for dv: Array in [["left", Vector2i.LEFT], ["right", Vector2i.RIGHT], ["up", Vector2i.UP], ["down", Vector2i.DOWN]]:
		if Input.is_action_just_pressed(str(dv[0])):
			_step(dv[1])
			_rep = 0.32
		elif Input.is_action_pressed(str(dv[0])) and _rep <= 0.0:
			_step(dv[1])
			_rep = 0.09

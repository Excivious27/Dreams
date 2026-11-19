class_name CliffPainter
extends RefCounted
## Organic cliffs and raised ground (round 11).
## A plateau (or a cliff border band) is traced into outline loops, the loops get
## rounded corners (stepped edges become smooth curves), and then each piece of
## the outline is drawn by which way it faces the camera:
##   front (faces south): a hanging window of the painted cliff strip (art/gen/cliffs
##     <style>_strip), a soft shadow at its foot; stair runs are cut out of it;
##   sides (east / west): a narrow rock wall from <style>_side_l/_r just inside the
##     rim, with a grass (snow, sand) lip on its top edge;
##   back (faces north): a thin lip line, so the top reads as raised ground.
## The top itself is the map's own ground, so the rim always matches the ground
## colour (no pale cap ring). Winter swaps grass pieces for the snow pieces.

const T := 16.0
const FACE_H := T * 1.6      # painted face height in world px
const FACE_TOP := 5.0        # the strip's grass fringe overlaps the rim by this much
const SIDE_W := 9.0          # side wall width (world px)
const CORNER_R := 0.9        # corner rounding (cells)


## Outline loops of a cell set, in cell-corner units. Walking a loop keeps the
## inside on the left; the outward normal of a step d is (-d.y, d.x).
static func loops(cells: Dictionary) -> Array:
	var edges := {}
	for c: Vector2i in cells:
		if not cells.has(c + Vector2i(0, 1)):
			_add(edges, Vector2i(c.x, c.y + 1), Vector2i(c.x + 1, c.y + 1))
		if not cells.has(c + Vector2i(0, -1)):
			_add(edges, Vector2i(c.x + 1, c.y), Vector2i(c.x, c.y))
		if not cells.has(c + Vector2i(1, 0)):
			_add(edges, Vector2i(c.x + 1, c.y + 1), Vector2i(c.x + 1, c.y))
		if not cells.has(c + Vector2i(-1, 0)):
			_add(edges, Vector2i(c.x, c.y), Vector2i(c.x, c.y + 1))
	var out := []
	var guard := 0
	while not edges.is_empty() and guard < 4096:
		guard += 1
		var start: Vector2i = edges.keys()[0]
		var p := start
		var prev := Vector2i.ZERO
		var loop := PackedVector2Array()
		for _i in 200000:
			var ends: Array = edges.get(p, [])
			if ends.is_empty():
				break
			var idx := 0
			if ends.size() > 1 and prev != Vector2i.ZERO:
				var left := Vector2i(prev.y, -prev.x)  # turn toward the inside at a pinch
				for k in ends.size():
					if (ends[k] as Vector2i) - p == left:
						idx = k
			var q: Vector2i = ends[idx]
			ends.remove_at(idx)
			if ends.is_empty():
				edges.erase(p)
			loop.append(Vector2(p))
			prev = q - p
			p = q
			if p == start:
				break
		if loop.size() >= 4:
			out.append(loop)
	return out


## Holes (inner loops) wind the other way round: positive shoelace area.
static func is_hole(loop: PackedVector2Array) -> bool:
	var a := 0.0
	var n := loop.size()
	for i in n:
		a += loop[i].x * loop[(i + 1) % n].y - loop[(i + 1) % n].x * loop[i].y
	return a > 0.0


static func _add(edges: Dictionary, a: Vector2i, b: Vector2i) -> void:
	(edges.get_or_add(a, []) as Array).append(b)


## Rounded copy of a loop (cell units in, world px out). Corners get a quadratic
## curve of radius up to `r` cells; one-cell steps melt into smooth slopes.
static func smooth(loop: PackedVector2Array, r := CORNER_R, keep: Dictionary = {}) -> PackedVector2Array:
	var pts: Array = []
	var n := loop.size()
	for i in n:
		var a := loop[(i - 1 + n) % n]
		var b := loop[i]
		var c := loop[(i + 1) % n]
		if absf((b - a).cross(c - b)) > 0.001:
			pts.append(b)
	var m := pts.size()
	var out := PackedVector2Array()
	if m < 3:
		for p in loop:
			out.append(p * T)
		return out
	for i in m:
		var a: Vector2 = pts[(i - 1 + m) % m]
		var b: Vector2 = pts[i]
		var c: Vector2 = pts[(i + 1) % m]
		var rr := minf(r, minf(a.distance_to(b), b.distance_to(c)) * 0.5)
		if keep.has(Vector2i(b)):
			rr = minf(rr, 0.2)  # stair cut corners stay crisp
		var p0 := b + (a - b).normalized() * rr
		var p2 := b + (c - b).normalized() * rr
		var steps := 6 if rr > 0.4 else 3
		for s in steps + 1:
			var t := float(s) / steps
			out.append(p0.lerp(b, t).lerp(b.lerp(p2, t), t) * T)
	return out


## Split a closed polyline into pieces no longer than `seg` px: [a, b] pairs.
static func segments(poly: PackedVector2Array, seg := 8.0) -> Array:
	var out := []
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var l := a.distance_to(b)
		if l < 0.01:
			continue
		var k := maxi(1, ceili(l / seg))
		for j in k:
			out.append([a.lerp(b, float(j) / k), a.lerp(b, float(j + 1) / k)])
	return out


## Which cliff piece set to use: grass/sand/snow (grass turns to snow in winter).
static func piece_set(style: String) -> String:
	if style == "grass" and GameState.look_se() == "winter" and Art.tex("cliffs", "snow_strip") != null:
		return "snow"
	return style


static func lip_colour(pset: String, ground := Color(0, 0, 0, 0)) -> Color:
	if ground.a > 0.0:
		return ground
	var se := GameState.look_se()
	if se == "winter":
		return Color(0.93, 0.96, 1.0, 0.95)
	if pset == "sand":
		return Color(0.86, 0.74, 0.5, 0.9)
	if se == "fall":
		return Color(0.6, 0.6, 0.25, 0.9)
	return Color(0.42, 0.66, 0.27, 0.9)   # snow pieces on a green map still get a grass lip


## Draw raised ground: `cells` is the top, `stairs` are cells in the face row
## where a stair set is cut in. opts: {"style": "grass"/"sand"/"snow",
## "skip_rect": Rect2i (outline pieces on this rect's border are not drawn, e.g.
## the outer edge of a border band), "no_front": true, "stair_set": name}
static func draw(ci: CanvasItem, cells: Dictionary, stairs: Dictionary, opts: Dictionary = {}) -> bool:
	var style := str(opts.get("style", "grass"))
	var pset := piece_set(style)
	var strip := Art.tex("cliffs", pset + "_strip")
	if strip == null:
		strip = Art.tex("cliffs", style + "_strip")
		pset = style
	if strip == null:
		return false
	var side_l := Art.tex("cliffs", pset + "_side_l")
	var side_r := Art.tex("cliffs", pset + "_side_r")
	var skip: Rect2i = opts.get("skip_rect", Rect2i())
	var lip := lip_colour(pset, opts.get("lip", Color(0, 0, 0, 0)))
	# Stair cuts: the face pieces over a stair cell are left out.
	var stair_x := {}
	var keep := {}
	for s: Vector2i in stairs:
		stair_x[s] = true
		keep[Vector2i(s.x, s.y)] = true
		keep[Vector2i(s.x + 1, s.y)] = true
	var k := float(strip.get_height()) / FACE_H  # strip texels per world px
	# inset: the face sits inside the cells (border bands), not on the row below.
	var lift := FACE_H - FACE_TOP - 2.0 if opts.get("inset", false) else 0.0
	var sw := float(strip.get_width())
	var fronts: Array = []
	var sides: Array = []
	var backs: Array = []
	for lp: PackedVector2Array in loops(cells):
		var poly := smooth(lp, CORNER_R, keep)
		for sg: Array in segments(poly, 6.0):
			var a: Vector2 = sg[0]
			var b: Vector2 = sg[1]
			if skip.size != Vector2i.ZERO and _on_rect_border(a, b, skip):
				continue
			var d := b - a
			var nrm := Vector2(-d.y, d.x).normalized()
			if nrm.y > 0.25:
				var mid := (a + b) * 0.5
				var sc := Vector2i(floori(mid.x / T), floori((mid.y + 2.0) / T))
				if stair_x.has(sc):
					continue
				fronts.append([a, b, nrm])
			elif absf(nrm.x) > 0.5:
				sides.append([a, b, nrm])
			else:
				backs.append([a, b, nrm])
	# 1. Soft shadow at the foot of every face (and a faint one beside the side walls).
	if not opts.get("no_front", false):
		for f: Array in fronts:
			var a: Vector2 = f[0] + Vector2(0, FACE_H - FACE_TOP - 1.0 - lift)
			var b: Vector2 = f[1] + Vector2(0, FACE_H - FACE_TOP - 1.0 - lift)
			ci.draw_polygon(PackedVector2Array([a, b, b + Vector2(0, 5), a + Vector2(0, 5)]),
				PackedColorArray([Color(0.05, 0.04, 0.08, 0.32), Color(0.05, 0.04, 0.08, 0.32), Color(0.05, 0.04, 0.08, 0.0), Color(0.05, 0.04, 0.08, 0.0)]))
	for s: Array in sides:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var nrm: Vector2 = s[2]
		ci.draw_polygon(PackedVector2Array([a, b, b + nrm * 4.0, a + nrm * 4.0]),
			PackedColorArray([Color(0.05, 0.04, 0.08, 0.22), Color(0.05, 0.04, 0.08, 0.22), Color(0.05, 0.04, 0.08, 0.0), Color(0.05, 0.04, 0.08, 0.0)]))
	# 2. Back rims: a dark line just outside, a light lip just inside.
	for bk: Array in backs:
		var a: Vector2 = bk[0]
		var b: Vector2 = bk[1]
		var nrm: Vector2 = bk[2]
		ci.draw_line(a + nrm * 1.0, b + nrm * 1.0, Color(0.06, 0.05, 0.1, 0.4), 2.0, true)
		ci.draw_line(a - nrm * 1.0, b - nrm * 1.0, Color(lip.r * 1.1, lip.g * 1.1, lip.b * 1.1, 0.55), 1.0, true)
	# 3. Side walls: rock from the side piece, inside the rim, with a lip on top.
	if side_l != null and side_r != null:
		for s: Array in sides:
			var a: Vector2 = s[0]
			var b: Vector2 = s[1]
			var nrm: Vector2 = s[2]
			var tex: Texture2D = side_r if nrm.x > 0 else side_l
			var tw := float(tex.get_width())
			var th := float(tex.get_height())
			# Rock part of the piece (below its grass cap), repeating every ~2 cells.
			var v_top := th * 0.32
			var v_span := th * 0.6
			var per := T * 2.0
			var va := v_top + fposmod(minf(a.y, b.y), per) / per * v_span
			var vb := va + absf(b.y - a.y) / per * v_span
			if vb > v_top + v_span:
				va = v_top
				vb = va + absf(b.y - a.y) / per * v_span
			var top_a := a if a.y < b.y else b
			var top_b := b if a.y < b.y else a
			var inner := -nrm * SIDE_W
			var u0 := 0.15 if nrm.x > 0 else 0.35
			var u1 := 0.65 if nrm.x > 0 else 0.85
			# Outer edge of the wall is on the outline; the inner edge is SIDE_W inside.
			var o0 := 0.0 if nrm.x < 0 else 1.0
			var uo := lerpf(u0, u1, o0)
			var ui := lerpf(u0, u1, 1.0 - o0)
			ci.draw_polygon(PackedVector2Array([top_a, top_b, top_b + inner, top_a + inner]),
				PackedColorArray([Color.WHITE]),
				PackedVector2Array([Vector2(uo, va / th), Vector2(uo, vb / th), Vector2(ui, vb / th), Vector2(ui, va / th)]), tex)
			ci.draw_line(a + inner, b + inner, Color(0.08, 0.06, 0.1, 0.25), 1.0, true)
			ci.draw_line(a + inner * 1.15, b + inner * 1.15, lip, 1.6, true)
	# 4. Faces: the painted strip, sampled by world x so straight runs never repeat
	#    a seam, hanging from the (curved) front outline.
	if not opts.get("no_front", false):
		for f: Array in fronts:
			var a: Vector2 = f[0]
			var b: Vector2 = f[1]
			var u0 := fposmod(a.x * k, sw)
			var u1 := u0 + (b.x - a.x) * k
			if u1 > sw:
				u0 = 0.0
				u1 = (b.x - a.x) * k
			var ta := a - Vector2(0, FACE_TOP + lift)
			var tb := b - Vector2(0, FACE_TOP + lift)
			ci.draw_polygon(PackedVector2Array([ta, tb, tb + Vector2(0, FACE_H), ta + Vector2(0, FACE_H)]),
				PackedColorArray([Color.WHITE]),
				PackedVector2Array([Vector2(u0 / sw, 0), Vector2(u1 / sw, 0), Vector2(u1 / sw, 1), Vector2(u0 / sw, 1)]), strip)
	# 5. Stairs: one painted set per run, fitted to the face height, with cheeks.
	var nm0 := str(opts.get("stair_set", ""))
	if pset == "snow" and nm0 == "stair_stone" and Art.has("stairs", "stair_snow"):
		nm0 = "stair_snow"  # winter: snowy steps to match the snowy faces
	if nm0 != "" and Art.has("stairs", nm0):
		draw_stairs(ci, stairs, nm0)
	return true


static func _on_rect_border(a: Vector2, b: Vector2, r: Rect2i) -> bool:
	var x0 := r.position.x * T
	var y0 := r.position.y * T
	var x1 := r.end.x * T
	var y1 := r.end.y * T
	for p: Vector2 in [a, b]:
		if not (absf(p.x - x0) < 0.5 or absf(p.x - x1) < 0.5 or absf(p.y - y0) < 0.5 or absf(p.y - y1) < 0.5):
			return false
	return true


## Stair sets sized to the cliff: they reach from a little above the rim to the
## foot of the face, a few px wider than the walkable run (the art's own stone
## cheeks sit on the blocked rim beside it).
static func draw_stairs(ci: CanvasItem, stairs: Dictionary, base: String) -> void:
	var done := {}
	for b: Vector2i in stairs:
		if done.has(b):
			continue
		var run := [b]
		var x := b.x + 1
		while stairs.has(Vector2i(x, b.y)):
			run.append(Vector2i(x, b.y))
			x += 1
		x = b.x - 1
		while stairs.has(Vector2i(x, b.y)):
			run.push_front(Vector2i(x, b.y))
			x -= 1
		for rc in run:
			done[rc] = true
		var nm := base
		if run.size() >= 3 and Art.has("stairs", base + "_wide"):
			nm = base + "_wide"
		var t := Art.tex("stairs", nm)
		if t == null:
			continue
		var w := run.size() * T + 14.0
		var foot := (b.y + 1) * T + 3.0
		var nat := w * float(t.get_height()) / float(t.get_width())
		var h := clampf(nat, FACE_H + T * 0.9, FACE_H + T * 1.4)
		var left: Vector2i = run[0]
		# Shadow under the steps' foot, then the set.
		ci.draw_rect(Rect2(left.x * T - 6.0, foot - 2.0, w - 2.0, 3.0), Color(0.05, 0.04, 0.08, 0.22))
		ci.draw_texture_rect(t, Rect2(left.x * T - 7.0, foot - h, w, h), false)


## Cells drawn as one patch of a seamless texture with rounded outer corners and
## filleted inner corners (no square steps at the edge). Used for forest floor
## under border trees and similar ground masses.
static func draw_rounded_cells(ci: CanvasItem, cells: Dictionary, tex: Texture2D, period: float, col := Color.WHITE) -> void:
	if tex == null:
		return
	var r := T * 0.5
	for c: Vector2i in cells:
		var n := cells.has(c + Vector2i(0, -1))
		var s := cells.has(c + Vector2i(0, 1))
		var w := cells.has(c + Vector2i(-1, 0))
		var e := cells.has(c + Vector2i(1, 0))
		var o := Vector2(c) * T
		if n and s and w and e:
			_seam_poly(ci, tex, PackedVector2Array([o, o + Vector2(T, 0), o + Vector2(T, T), o + Vector2(0, T)]), o, period, col)
			continue
		# Round a corner where both of its sides are open.
		var pts := PackedVector2Array()
		var corners := [[Vector2(0, 0), not n and not w, Vector2(0, 1), Vector2(1, 0)], [Vector2(T, 0), not n and not e, Vector2(-1, 0), Vector2(0, 1)], [Vector2(T, T), not s and not e, Vector2(0, -1), Vector2(-1, 0)], [Vector2(0, T), not s and not w, Vector2(1, 0), Vector2(0, -1)]]
		for cr: Array in corners:
			var p: Vector2 = cr[0]
			if cr[1]:
				var p0: Vector2 = p + (cr[2] as Vector2) * r
				var p2: Vector2 = p + (cr[3] as Vector2) * r
				for st in 5:
					var t := st / 4.0
					pts.append(o + p0.lerp(p, t).lerp(p.lerp(p2, t), t))
			else:
				pts.append(o + p)
		_seam_poly(ci, tex, pts, o, period, col)
	# Fillets in concave corners: three cells of a 2x2 filled, the fourth (the
	# hole) gets a small curved wedge in the corner they share.
	var fil := {}
	for c: Vector2i in cells:
		for d: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var hole := c + Vector2i(d.x, 0)
			if cells.has(hole) or not cells.has(c + d) or not cells.has(c + Vector2i(0, d.y)):
				continue
			var key := "%d,%d,%d" % [hole.x, hole.y, d.y]
			if fil.has(key):
				continue
			fil[key] = true
			var ho := Vector2(hole) * T
			var cp := ho + Vector2(0.0 if d.x > 0 else T, T if d.y > 0 else 0.0)
			var ax := Vector2(1 if d.x > 0 else -1, 0)
			var ay := Vector2(0, -1 if d.y > 0 else 1)
			var p0 := cp + ax * r
			var p2 := cp + ay * r
			var fan := PackedVector2Array([cp])
			for st in 7:
				var t := st / 6.0
				fan.append(p0.lerp(cp, t).lerp(cp.lerp(p2, t), t))
			_seam_poly(ci, tex, fan, ho, period, col)


## A polygon inside one cell (cell origin `o`) filled from a seamless texture of
## `period` world px; uvs stay inside the texture (cell windows never straddle).
static func _seam_poly(ci: CanvasItem, tex: Texture2D, pts: PackedVector2Array, o: Vector2, period: float, col: Color) -> void:
	var base := Vector2(fposmod(o.x, period), fposmod(o.y, period))
	var uvs := PackedVector2Array()
	for p in pts:
		uvs.append((base + (p - o)) / period)
	ci.draw_polygon(pts, PackedColorArray([col]), uvs, tex)

extends RefCounted
## Many small polygons and lines as ONE draw command.
## Godot's canvas renderer gives every draw_polygon / draw_colored_polygon /
## thick draw_line its own draw call (only rects batch). The cliff outlines and
## the rounded forest floor drew thousands of those per map, and the baked
## ground re-issues the whole list for every 256 px chunk it renders: a chunk on a
## battlefield cost ~7000 draw calls. Collect the pieces here (same texture,
## same order) and flush() adds them as one triangle array: same pixels.

const FEATHER := 1.0  # Godot's antialiasing feather for draw_line(..., true)

var pts := PackedVector2Array()
var cols := PackedColorArray()
var uvs := PackedVector2Array()
var idx := PackedInt32Array()


func is_empty() -> bool:
	return idx.is_empty()


## A convex (or star-shaped from pts[0]) polygon, fanned from its first point.
## col: one colour, or one per point. uv: empty, or one per point.
func fan(p: PackedVector2Array, col: PackedColorArray, uv := PackedVector2Array()) -> void:
	var n := p.size()
	if n < 3:
		return
	var b := pts.size()
	pts.append_array(p)
	for i in n:
		cols.append(col[i] if col.size() == n else col[0])
	if not uv.is_empty():
		uvs.append_array(uv)
	for i in range(1, n - 1):
		idx.append(b)
		idx.append(b + i)
		idx.append(b + i + 1)


## draw_line(a, b, col, w, true): the core quad plus a 1 px feather fading to clear.
func line(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var d := b - a
	if d.length_squared() < 0.000001:
		return
	var nrm := d.orthogonal().normalized()
	var dir := d.normalized()
	var t := nrm * w * 0.5
	var fs := FEATHER * (w if w < 1.0 else 1.0)
	var bn := nrm * fs
	var bd := dir * fs
	var clear := Color(col.r, col.g, col.b, 0.0)
	var base := pts.size()
	# 0..3 core (a+t, b+t, b-t, a-t); 4..7 feather ring around it.
	pts.append_array(PackedVector2Array([a + t, b + t, b - t, a - t,
		a + t + bn - bd, b + t + bn + bd, b - t - bn + bd, a - t - bn - bd]))
	for i in 4:
		cols.append(col)
	for i in 4:
		cols.append(clear)
	if not uvs.is_empty():
		for i in 8:
			uvs.append(Vector2.ZERO)
	for tri: Array in [[0, 1, 2], [0, 2, 3], [4, 5, 1], [4, 1, 0], [5, 6, 2], [5, 2, 1], [6, 7, 3], [6, 3, 2], [7, 4, 0], [7, 0, 3]]:
		for k: int in tri:
			idx.append(base + k)


## draw_rect(r, col) (filled).
func rect(r: Rect2, col: Color) -> void:
	fan(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([col]))


## draw_circle(c, rad, col) (filled); fewer segments for small circles (sub-pixel same).
func circle(c: Vector2, rad: float, col: Color) -> void:
	var n := clampi(int(rad * 4.0), 12, 64)
	var p := PackedVector2Array()
	p.resize(n)
	for i in n:
		p[i] = c + Vector2.from_angle(TAU * i / n) * rad
	fan(p, PackedColorArray([col]))


## draw_line(a, b, col, w) without antialiasing: just the w-wide quad.
func seg(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var d := b - a
	if d.length_squared() < 0.000001:
		return
	var t := d.orthogonal().normalized() * w * 0.5
	fan(PackedVector2Array([a + t, b + t, b - t, a - t]), PackedColorArray([col]))


## draw_arc(c, rad, from, to, n, col, w) without antialiasing, as n quads.
func arc(c: Vector2, rad: float, from: float, to: float, n: int, col: Color, w: float) -> void:
	var prev := c + Vector2.from_angle(from) * rad
	for i in range(1, n + 1):
		var nx := c + Vector2.from_angle(lerpf(from, to, float(i) / n)) * rad
		seg(prev, nx, col, w)
		prev = nx


## One draw command for everything collected; then starts empty again.
func flush(ci: CanvasItem, tex: Texture2D = null) -> void:
	if idx.is_empty():
		return
	if recording:
		var bb := Rect2(pts[0], Vector2.ZERO)
		for p in pts:
			bb = bb.expand(p)
		rec.append(["tri", idx, pts, cols, uvs if uvs.size() == pts.size() else PackedVector2Array(), tex, bb.grow(2.0)])
	if not Art.clipped(_last_bb(pts)):
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols,
		uvs if uvs.size() == pts.size() else PackedVector2Array(), PackedInt32Array(), PackedFloat32Array(),
		tex.get_rid() if tex != null else RID())
	pts = PackedVector2Array()
	cols = PackedColorArray()
	uvs = PackedVector2Array()
	idx = PackedInt32Array()


# ---- recorded drawing (geometry memo for the baked ground, c3_16 #2) ----------
## While `recording`, flush() and the draw helpers below also append what they
## draw to `rec`; replay() re-issues the same commands in the same order (helpers
## skip those wholly outside Art.clip), with none of the geometry work again.
static var recording := false
static var rec: Array = []


static func _last_bb(p: PackedVector2Array) -> Rect2:
	if not Art.clip.has_area() or p.is_empty():
		return Rect2(Vector2.ZERO, Vector2(1, 1))  # (not clipping: never skipped)
	var bb := Rect2(p[0], Vector2.ZERO)
	for q in p:
		bb = bb.expand(q)
	return bb.grow(2.0)


static func begin_rec() -> void:
	recording = true
	rec = []


static func end_rec() -> Array:
	recording = false
	var out := rec
	rec = []
	return out


static func tex_rect_region(ci: CanvasItem, tex: Texture2D, r: Rect2, src: Rect2, col := Color.WHITE) -> void:
	if recording:
		rec.append(["trr", tex, r, src, col])
	if not Art.clipped(r):
		ci.draw_texture_rect_region(tex, r, src, col)


static func tex_rect(ci: CanvasItem, tex: Texture2D, r: Rect2) -> void:
	if recording:
		rec.append(["tr", tex, r])
	if not Art.clipped(r):
		ci.draw_texture_rect(tex, r, false)


static func solid(ci: CanvasItem, r: Rect2, col: Color) -> void:
	if recording:
		rec.append(["rect", r, col])
	if not Art.clipped(r):
		ci.draw_rect(r, col)


static func replay(ci: CanvasItem, cmds: Array) -> void:
	var item := ci.get_canvas_item()
	for c: Array in cmds:
		match str(c[0]):
			"tri":
				if not Art.clipped(c[6]):
					RenderingServer.canvas_item_add_triangle_array(item, c[1], c[2], c[3], c[4], PackedInt32Array(), PackedFloat32Array(),
						(c[5] as Texture2D).get_rid() if c[5] != null else RID())
			"trr":
				if not Art.clipped(c[2]):
					ci.draw_texture_rect_region(c[1], c[2], c[3], c[4])
			"tr":
				if not Art.clipped(c[2]):
					ci.draw_texture_rect(c[1], c[2], false)
			"rect":
				if not Art.clipped(c[1]):
					ci.draw_rect(c[1], c[2])

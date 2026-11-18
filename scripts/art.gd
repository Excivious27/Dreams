class_name Art
extends RefCounted
## Access to the sliced art in art/gen (made by tools/slice_art.py from Tom's
## uploads). Everything there is at 2x detail: draw it at 0.5 scale, or use
## draw_tile() which handles that. Missing files return null so placeholder
## drawing can take over.

const ROOT := "res://art/gen/"
static var _manifest: Dictionary = {}
static var _tex: Dictionary = {}
static var _frames: Dictionary = {}


static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var f := FileAccess.open(ROOT + "manifest.json", FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_manifest = parsed
	return _manifest


static func has(group: String, name: String) -> bool:
	return manifest().get(group, {}).has(name)


static func info(group: String, name: String) -> Dictionary:
	return manifest().get(group, {}).get(name, {})


static func tex(group: String, name: String) -> Texture2D:
	var key := group + "/" + name
	if _tex.has(key):
		return _tex[key]
	var path := ROOT + key + ".png"
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex[key] = t
	return t


## SpriteFrames built from one or more strips: {"anim_name": "strip_name", ...}.
## Called on every scene change: textures pile up as you travel (the web build
## has little memory), so past a budget everything is let go and reloaded on use.
static func trim_cache(budget := 1500) -> void:
	if _tex.size() <= budget:
		return
	_tex.clear()
	_frames.clear()
	CharacterLibrary._frames_cache.clear()


static func frames(group: String, anims: Dictionary, fps: Dictionary = {}, loops: Dictionary = {}) -> SpriteFrames:
	var key := group + ":" + str(anims) + str(fps) + str(loops)
	if _frames.has(key):
		return _frames[key]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim: String in anims:
		var strip_name := str(anims[anim])
		var i := info(group, strip_name)
		var t := tex(group, strip_name)
		if t == null or i.is_empty():
			continue
		var n := int(i.get("frames", 1))
		var cw := int(i.get("cell_w", i.get("w", t.get_width())))
		var ch := int(i.get("cell_h", i.get("h", t.get_height())))
		sf.add_animation(anim)
		sf.set_animation_speed(anim, float(fps.get(anim, 8.0)))
		sf.set_animation_loop(anim, bool(loops.get(anim, true)))
		for k in n:
			var at := AtlasTexture.new()
			at.atlas = t
			at.region = Rect2(k * cw, 0, cw, ch)
			sf.add_frame(anim, at)
	_frames[key] = sf
	return sf


## Add the strips in `anims` to an existing SpriteFrames (used to extend the
## character pack with the new toward/away frames).
static func add_frames(sf: SpriteFrames, group: String, anims: Dictionary, fps: Dictionary = {}, loops: Dictionary = {}) -> void:
	for anim: String in anims:
		var strip_name := str(anims[anim])
		var i := info(group, strip_name)
		var t := tex(group, strip_name)
		if t == null or i.is_empty() or sf.has_animation(anim):
			continue
		var n := int(i.get("frames", 1))
		var cw := int(i.get("cell_w", i.get("w", t.get_width())))
		var ch := int(i.get("cell_h", i.get("h", t.get_height())))
		sf.add_animation(anim)
		sf.set_animation_speed(anim, float(fps.get(anim, 8.0)))
		sf.set_animation_loop(anim, bool(loops.get(anim, true)))
		for k in n:
			var at := AtlasTexture.new()
			at.atlas = t
			at.region = Rect2(k * cw, 0, cw, ch)
			sf.add_frame(anim, at)


## A Sprite2D at 0.5 scale whose position is its bottom-center (feet).
static func sprite(group: String, name: String) -> Sprite2D:
	var t := tex(group, name)
	if t == null:
		return null
	var s := Sprite2D.new()
	s.texture = t
	s.scale = Vector2(0.5, 0.5)
	s.offset = Vector2(0, -t.get_height() / 2.0)
	return s


## Draw a 32px source tile into a 16px cell. `index` picks a cell of a 3x3 set
## (0..8) or a frame of a strip.
static func draw_tile(ci: CanvasItem, group: String, name: String, at: Vector2, index := 4, size := 16.0) -> bool:
	var t := tex(group, name)
	if t == null:
		return false
	var i := info(group, name)
	var cw := int(i.get("cell_w", 32))
	var ch := int(i.get("cell_h", 32))
	var cols := maxi(1, t.get_width() / cw)
	var rows := maxi(1, t.get_height() / ch)
	index = clampi(index, 0, cols * rows - 1)
	# Sample 1px inside the cell so keyed fringes never show as seams.
	var src := Rect2((index % cols) * cw + 1.0, (index / cols) * ch + 1.0, cw - 2.0, ch - 2.0)
	ci.draw_texture_rect_region(t, Rect2(at, Vector2(size, size)), src)
	return true


## Draw a whole texture scaled to 0.5 with its bottom-center at `feet`.
static func draw_prop(ci: CanvasItem, group: String, name: String, feet: Vector2) -> bool:
	var t := tex(group, name)
	if t == null:
		return false
	var w := t.get_width() / 2.0
	var h := t.get_height() / 2.0
	ci.draw_texture_rect(t, Rect2(feet.x - w / 2.0, feet.y - h, w, h), false)
	return true


## Draw a region of `inside` cells with a transition set. `inside` is a Dictionary of
## Vector2i -> true. The set's index map says which cell of the sheet to use for
## each edge/corner case. Fill is drawn with `fill` (a 3x3 ground, index 4) and
## edges from `tset`. Cells outside `inside` are not drawn.
## idx keys: top,bottom,left,right,tl,tr,bl,br (outer), itl,itr,ibl,ibr (inner), mid
static func draw_autotile(ci: CanvasItem, inside: Dictionary, fill: String, tset: String, idx: Dictionary, size := 16.0) -> void:
	var t := tex("tiles", tset)
	var i := info("tiles", tset)
	var cols := int(i.get("cols", 4))
	for c: Vector2i in inside:
		var at := Vector2(c) * size
		var n := inside.has(c + Vector2i(0, -1))
		var s := inside.has(c + Vector2i(0, 1))
		var w := inside.has(c + Vector2i(-1, 0))
		var e := inside.has(c + Vector2i(1, 0))
		var key := "mid"
		if not n and not w: key = "tl"
		elif not n and not e: key = "tr"
		elif not s and not w: key = "bl"
		elif not s and not e: key = "br"
		elif not n: key = "top"
		elif not s: key = "bottom"
		elif not w: key = "left"
		elif not e: key = "right"
		elif not inside.has(c + Vector2i(-1, -1)): key = "itl"
		elif not inside.has(c + Vector2i(1, -1)): key = "itr"
		elif not inside.has(c + Vector2i(-1, 1)): key = "ibl"
		elif not inside.has(c + Vector2i(1, 1)): key = "ibr"
		if key == "mid" or t == null or not idx.has(key):
			if fill == "@":
				# Use the transition sheet's own middle cell so colours match.
				var k0 := int(idx.get("mid", 1))
				ci.draw_texture_rect_region(t, Rect2(at, Vector2(size, size)), Rect2((k0 % cols) * 32 + 1.0, (k0 / cols) * 32 + 1.0, 30.0, 30.0))
			elif fill != "":
				draw_tile(ci, "tiles", fill, at, 4, size)
			continue
		var k := int(idx[key])
		var src := Rect2((k % cols) * 32 + 1.0, (k / cols) * 32 + 1.0, 30.0, 30.0)
		ci.draw_texture_rect_region(t, Rect2(at, Vector2(size, size)), src)


## Index maps for the W1 transition sheets (grass outside, ground inside).
const T_GROUND_IDX := {"mid": 1, "top": 0, "bottom": 2, "left": 4, "right": 7, "tl": 8, "tr": 9, "bl": 10, "br": 11, "itl": 12, "itr": 13, "ibl": 14, "ibr": 15}
## Water-edge sheets (grass outside, water inside): 18 pieces, 6 columns.
## W28/W29 cliff plateau sets (17 tiles in one row): tl top tr left mid right ibl ib ibr il ir itl it itr bl bottom br
const T_CLIFF_IDX := {"mid": 4, "top": 1, "bottom": 15, "left": 3, "right": 5, "tl": 0, "tr": 2, "bl": 14, "br": 16, "itl": 11, "itr": 13, "ibl": 6, "ibr": 8}
const T_WATER_IDX := {"top": 1, "bottom": 14, "left": 10, "right": 3, "tl": 5, "tr": 9, "bl": 13, "br": 16, "itl": 6, "itr": 2, "ibl": 0, "ibr": 4}


## 47-tile blob autotile from the W52+ strict-grid sets: tiles are saved as
## "<set>_<role>_<variant>" (roles: top bottom left right tl tr bl br itl itr ibl ibr
## tb lr u_down u_up open_left open_right iso diag_a diag_b diag_c fill).
## `inside` cells are the material; neighbours outside get the edge treatment.
## Missing roles fall back sensibly, so 12-piece simple sets work too.
static func draw_blob(ci: CanvasItem, inside: Dictionary, set_name: String, size := 16.0, fill_count := 12) -> void:
	var by_tex := {}  # piece name -> cell positions
	for c: Vector2i in inside:
		var n := inside.has(c + Vector2i(0, -1))
		var s := inside.has(c + Vector2i(0, 1))
		var w := inside.has(c + Vector2i(-1, 0))
		var e := inside.has(c + Vector2i(1, 0))
		var missing := int(not n) + int(not s) + int(not w) + int(not e)
		var role := "fill"
		if missing == 4:
			role = "iso"
		elif missing == 3:
			role = "u_down" if s else ("u_up" if n else ("open_left" if w else "open_right"))
		elif missing == 2:
			if not n and not s: role = "tb"
			elif not w and not e: role = "lr"
			elif not n and not w: role = "tl"
			elif not n and not e: role = "tr"
			elif not s and not w: role = "bl"
			else: role = "br"
		elif missing == 1:
			role = "top" if not n else ("bottom" if not s else ("left" if not w else "right"))
		else:
			var dtl := not inside.has(c + Vector2i(-1, -1))
			var dtr := not inside.has(c + Vector2i(1, -1))
			var dbl := not inside.has(c + Vector2i(-1, 1))
			var dbr := not inside.has(c + Vector2i(1, 1))
			var dn := int(dtl) + int(dtr) + int(dbl) + int(dbr)
			if dn == 1:
				role = "itl" if dtl else ("itr" if dtr else ("ibl" if dbl else "ibr"))
			elif dn == 2 and ((dtl and dbr) or (dtr and dbl)):
				role = "diag_a" if dtl else "diag_b"
			elif dn >= 2:
				role = "itl" if dtl else ("itr" if dtr else ("ibl" if dbl else "ibr"))
		if role == "fill" and fill_count == 0:
			continue
		var h := absi((c.x * 73856093) ^ (c.y * 19349663) ^ hash(set_name))
		var nm := _blob_name(set_name, role, maxi(1, h), maxi(1, fill_count))
		if nm == "":
			continue
		(by_tex.get_or_add(nm, []) as Array).append(Vector2(c) * size)
	# Every piece fills exactly its own cell, so drawing them grouped by texture looks
	# the same and batches: one draw call per piece kind instead of one per edge cell.
	for nm: String in by_tex:
		for at: Vector2 in by_tex[nm]:
			draw_tile(ci, "tiles", nm, at, 0, size)


## Same as draw_blob but draws only `c`, using `inside` for context.
static func draw_blob_cell(ci: CanvasItem, inside: Dictionary, c: Vector2i, set_name: String, size := 16.0) -> void:
	var one := {}
	for k: Vector2i in inside:
		one[k] = true
	# Trick: temporarily drop everything except c from the draw loop by calling with a filtered dict
	_draw_blob_one(ci, one, c, set_name, size)


static func _draw_blob_one(ci: CanvasItem, inside: Dictionary, c: Vector2i, set_name: String, size: float) -> void:
	var sub := {c: true}
	var saved := inside
	# reuse draw_blob logic on a single cell by building a dictionary whose iteration yields only c
	# but whose lookups see the full context: emulate with a small wrapper
	var n := saved.has(c + Vector2i(0, -1))
	var s := saved.has(c + Vector2i(0, 1))
	var w := saved.has(c + Vector2i(-1, 0))
	var e := saved.has(c + Vector2i(1, 0))
	var missing := int(not n) + int(not s) + int(not w) + int(not e)
	var role := "fill"
	if missing == 4:
		role = "iso"
	elif missing == 3:
		role = "u_down" if s else ("u_up" if n else ("open_left" if w else "open_right"))
	elif missing == 2:
		if not n and not s: role = "tb"
		elif not w and not e: role = "lr"
		elif not n and not w: role = "tl"
		elif not n and not e: role = "tr"
		elif not s and not w: role = "bl"
		else: role = "br"
	elif missing == 1:
		role = "top" if not n else ("bottom" if not s else ("left" if not w else "right"))
	else:
		var dtl := not saved.has(c + Vector2i(-1, -1))
		var dtr := not saved.has(c + Vector2i(1, -1))
		var dbl := not saved.has(c + Vector2i(-1, 1))
		var dbr := not saved.has(c + Vector2i(1, 1))
		var dn := int(dtl) + int(dtr) + int(dbl) + int(dbr)
		if dn == 1:
			role = "itl" if dtl else ("itr" if dtr else ("ibl" if dbl else "ibr"))
		elif dn == 2 and ((dtl and dbr) or (dtr and dbl)):
			role = "diag_a" if dtl else "diag_b"
		elif dn >= 2:
			role = "itl" if dtl else ("itr" if dtr else ("ibl" if dbl else "ibr"))
		else:
			return
	var h := absi((c.x * 73856093) ^ (c.y * 19349663) ^ hash(set_name))
	var nm := _blob_name(set_name, role, maxi(1, h), 12)
	if nm != "":
		draw_tile(ci, "tiles", nm, Vector2(c) * size, 0, size)


static func _blob_name(set_name: String, role: String, h: int, fill_count: int) -> String:
	var vmax := fill_count if role == "fill" else 3
	for tries in 3:
		var v := (h / (tries + 1)) % vmax
		var nm := "%s_%s_%d" % [set_name, role, v]
		if has("tiles", nm):
			return nm
	# fallbacks for roles a simple set lacks
	var fb := {"tb": "top", "lr": "left", "u_down": "tl", "u_up": "bl", "open_left": "tr", "open_right": "tl", "iso": "tl", "diag_a": "itl", "diag_b": "itr", "diag_c": "itl"}
	if fb.has(role):
		for v in 3:
			var nm := "%s_%s_%d" % [set_name, str(fb[role]), v]
			if has("tiles", nm):
				return nm
	if role != "fill":
		for v in fill_count:
			var nm := "%s_fill_%d" % [set_name, v]
			if has("tiles", nm):
				return nm
	return ""


## The clean fill tiles of a ground/water set (tools/tile_clean.py): picking
## from these keeps big areas reading as one surface instead of a patchwork.
static var _clean: Dictionary = {}
static func fill_name(set_name: String, h: int) -> String:
	if _clean.is_empty():
		var f := FileAccess.open("res://data/tile_clean.json", FileAccess.READ)
		if f:
			var d: Variant = JSON.parse_string(f.get_as_text())
			_clean = d if d is Dictionary else {"_": []}
		else:
			_clean = {"_": []}
	var idx: Array = _clean.get(set_name, [])
	if idx.is_empty():
		return "%s_fill_%d" % [set_name, absi(h) % 12]
	return "%s_fill_%d" % [set_name, int(idx[absi(h) % idx.size()])]

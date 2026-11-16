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
static func frames(group: String, anims: Dictionary, fps: Dictionary = {}, loops: Dictionary = {}) -> SpriteFrames:
	var key := group + ":" + str(anims.keys())
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

class_name ClockHands
extends Node2D
## C14b P3 (c14b_13-10): the Town Hall clock and the Clock Tower show the game's
## time. The face's painted hands are covered with a disc of the face's own colour
## (sampled from the picture), then an hour hand (0.5 r) and a minute hand (0.82 r)
## are drawn; redrawn once per game minute, the minute hand eases over 0.15 s
## (no ease under reduced motion). Child of the building sprite, at the face centre.

var radius := 12.0
var face := Color(0.95, 0.9, 0.75)
var ink := Color(0.16, 0.12, 0.1)
var _min := -1
var _shown := -1.0
var _ease_from := 0.0
var _ease_t := 1.0

## Face centre and radius per building picture, in art px of the picture.
const FACES := {"hall": [Vector2(119, 86), 12.0], "clock_tower": [Vector2(38.5, 76.5), 8.5]}


static func attach(s: Sprite2D, name: String) -> ClockHands:
	var base := name.trim_suffix("_snow").trim_suffix("_night")
	if s == null or not FACES.has(base) or s.texture == null:
		return null
	var f: Array = FACES[base]
	var h := ClockHands.new()
	h.name = "ClockHands"
	var tw := float(s.texture.get_width())
	var th := float(s.texture.get_height())
	var c: Vector2 = f[0]
	h.radius = float(f[1])
	# Sprite origin = feet (bottom centre), the picture drawn up from it.
	h.position = Vector2(c.x - tw / 2.0, c.y - th) + s.offset + Vector2(0, th / 2.0)
	h.face = _sample_face(s.texture, c, h.radius)
	s.add_child(h)
	return h


static func _sample_face(t: Texture2D, c: Vector2, r: float) -> Color:
	var img := t.get_image()
	if img == null:
		return Color(0.95, 0.9, 0.75)
	if img.is_compressed():
		img.decompress()
	var cols: Array[Color] = []
	for k in 12:
		var a := TAU * (k + 0.5) / 12.0
		var p := c + Vector2(cos(a), sin(a)) * r * 0.42
		var px := Vector2i(clampi(int(p.x), 0, img.get_width() - 1), clampi(int(p.y), 0, img.get_height() - 1))
		cols.append(img.get_pixelv(px))
	cols.sort_custom(func(x: Color, y: Color) -> bool: return x.get_luminance() < y.get_luminance())
	var m := cols[cols.size() / 2]
	return Color(m.r, m.g, m.b, 1.0)


func _process(delta: float) -> void:
	var t := int(GameState.run.get("time", 0)) % (24 * 60)
	if t != _min:
		_ease_from = _shown if _shown >= 0.0 else float(t)
		_min = t
		_ease_t = 1.0 if AmbientMotion.reduced() or _shown < 0.0 else 0.0
	if _ease_t < 1.0:
		_ease_t = minf(1.0, _ease_t + delta / 0.15)
		queue_redraw()
	var target := float(_min)
	var nv := lerpf(_ease_from, target, 1.0 - pow(1.0 - _ease_t, 3.0)) if absf(target - _ease_from) < 5.0 else target
	if nv != _shown:
		_shown = nv
		queue_redraw()


func _draw() -> void:
	var m := maxf(_shown, 0.0)
	draw_circle(Vector2.ZERO, radius * 0.74, face)
	var ha := TAU * fmod(m / 60.0, 12.0) / 12.0 - PI / 2.0
	var ma := TAU * fmod(m, 60.0) / 60.0 - PI / 2.0
	draw_line(Vector2.ZERO, Vector2(cos(ha), sin(ha)) * radius * 0.5, ink, 2.0)
	draw_line(Vector2.ZERO, Vector2(cos(ma), sin(ma)) * radius * 0.8, ink, 1.4)
	draw_circle(Vector2.ZERO, 1.4, Color(0.7, 0.5, 0.2))

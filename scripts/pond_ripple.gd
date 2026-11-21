class_name PondRipple
extends Node2D
## C14b P3 (c14b_01-13): a still pond picture (its frame 0: the rim, pads and
## mushroom never shift) with soft ripple rings drawn in code at random points of
## its water every 2-5 s (game time), plus a glint that drifts; no frame jitter.
## `water` is the water's rect in the parent's local px.

var water := Rect2()
var _rings: Array = []  # [centre, age]
var _next := 0.0
var _rng := RandomNumberGenerator.new()


static func attach(parent: Node2D, water_rect: Rect2) -> PondRipple:
	var p := PondRipple.new()
	p.name = "PondRipple"
	p.water = water_rect
	p._rng.seed = int(parent.position.x * 31.0 + parent.position.y)
	parent.add_child(p)
	return p


func _process(delta: float) -> void:
	var t := PlayClock.now()
	if t >= _next:
		_next = t + _rng.randf_range(2.0, 5.0) * (2.0 if AmbientMotion.reduced() else 1.0)
		_rings.append([water.position + Vector2(_rng.randf_range(0.2, 0.8) * water.size.x, _rng.randf_range(0.25, 0.75) * water.size.y), 0.0])
	for r: Array in _rings:
		r[1] = float(r[1]) + delta
	_rings = _rings.filter(func(r: Array) -> bool: return float(r[1]) < 2.2)
	queue_redraw()


func _draw() -> void:
	for r: Array in _rings:
		var age := float(r[1])
		var k := age / 2.2
		var rad := 2.0 + 9.0 * (1.0 - pow(1.0 - k, 2.0))
		var col := Color(0.85, 0.95, 1.0, 0.55 * (1.0 - k))
		draw_set_transform(r[0], 0.0, Vector2(1.0, 0.55))
		draw_arc(Vector2.ZERO, rad, 0.0, TAU, 20, col, 1.0)
		if age > 0.4:
			draw_arc(Vector2.ZERO, rad * 0.55, 0.0, TAU, 14, Color(col, col.a * 0.6), 1.0)
	draw_set_transform(Vector2.ZERO)
	var g := water.position + Vector2(water.size.x * (0.5 + 0.3 * sin(PlayClock.now() * 0.31)), water.size.y * 0.35)
	draw_rect(Rect2(g, Vector2(3, 1)), Color(1, 1, 1, 0.35))

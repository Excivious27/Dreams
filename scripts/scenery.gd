class_name Scenery
extends CanvasLayer
## Living background: drifting clouds and flocks of birds crossing the sky,
## all drawn procedurally in pixel style. Sits behind the world (layer -1).
## Also has a Pond helper for animated water in a map (see Pond class below).

var _clouds: Array = []
var _birds: Array = []
var _t := 0.0
var _next_flock := 2.0
var _canvas: Node2D
var _w := 270.0
var _h := 480.0
## true: draws over the world (birds overhead, cloud shadows on the ground).
## false: draws behind everything (title screen sky).
var overhead := true
## Rain streaks over everything (gangster arc opening, storms later).
var raining := false
## "clear", "rain", "snow", "leaves", "petals", "fireflies"
var weather := "clear":
	set(v):
		weather = v
		raining = v == "rain"
var _drops: Array = []
var _parts: Array = []


func _ready() -> void:
	layer = 3 if overhead else -1
	_canvas = Node2D.new()
	_canvas.draw.connect(_on_draw)
	add_child(_canvas)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 6:
		_clouds.append({
			"pos": Vector2(rng.randf_range(-60, _w + 60), rng.randf_range(10, 150)),
			"w": rng.randf_range(28, 60),
			"speed": rng.randf_range(3, 7),
			"alpha": rng.randf_range(0.5, 0.9),
		})


func _process(delta: float) -> void:
	_t += delta
	for c: Dictionary in _clouds:
		c["pos"].x += c["speed"] * delta
		if c["pos"].x > _w + 70:
			c["pos"].x = -70
	_next_flock -= delta
	if _next_flock <= 0.0 and not raining:
		_spawn_flock()
		_next_flock = randf_range(7.0, 16.0)
	for b: Dictionary in _birds:
		b["pos"] += b["vel"] * delta
		b["pos"].y += sin(_t * 2.0 + b["phase"]) * 6.0 * delta
	_birds = _birds.filter(func(b: Dictionary) -> bool: return b["pos"].x > -40 and b["pos"].x < _w + 40)
	var pkind := ""
	match weather:
		"snow": pkind = "snowflake"
		"leaves": pkind = "leaf_orange"
		"petals": pkind = "leaf_green"
		"fireflies": pkind = "firefly"
	if pkind != "" and Art.has("fx", pkind):
		var want := 40 if weather != "fireflies" else 14
		while _parts.size() < want:
			_parts.append({"pos": Vector2(randf_range(-20, _w + 20), randf_range(-20, _h)), "f": randi() % 4, "t": randf() * TAU, "k": pkind})
		for p: Dictionary in _parts:
			if weather == "fireflies":
				p["t"] += delta
				p["pos"] += Vector2(sin(p["t"] * 1.3) * 12.0, cos(p["t"] * 0.9) * 8.0) * delta
			else:
				var fall := 18.0 if weather == "snow" else 26.0
				p["pos"] += Vector2(sin(p["t"] + _t) * 8.0, fall) * delta
				if p["pos"].y > _h + 10:
					p["pos"] = Vector2(randf_range(0, _w + 40), -10)
			p["f"] = int(_t * 4.0 + p["t"]) % 4
	else:
		_parts.clear()
	if raining:
		while _drops.size() < 90:
			_drops.append(Vector2(randf_range(-20, _w + 20), randf_range(-20, _h)))
		for i in _drops.size():
			_drops[i] += Vector2(-40, 260) * delta
			if _drops[i].y > _h + 10:
				_drops[i] = Vector2(randf_range(0, _w + 40), -10)
	_canvas.queue_redraw()


func _spawn_flock() -> void:
	var going_right := randf() < 0.5
	var y := randf_range(20, 120)
	var n := randi_range(3, 7)
	var speed := randf_range(28, 42)
	for i in n:
		var row := i / 2 + 1
		var side := -1.0 if i % 2 == 0 else 1.0
		var off := Vector2(-row * 7.0 * (1.0 if going_right else -1.0), side * row * 4.0)
		_birds.append({
			"pos": Vector2(-30 if going_right else _w + 30, y) + off,
			"vel": Vector2(speed if going_right else -speed, 0),
			"phase": randf() * TAU,
			"flap": randf() * TAU,
			"dark": randf() < 0.3,
		})


func _on_draw() -> void:
	if raining:
		var rd := Art.tex("fx", "raindrop")
		for d: Vector2 in _drops:
			if rd:
				_canvas.draw_texture_rect_region(rd, Rect2(d, Vector2(5, 12)), Rect2(0, 0, rd.get_width() / 3.0, rd.get_height()), Color(1, 1, 1, 0.7))
			else:
				_canvas.draw_line(d, d + Vector2(-2, 9), Color(0.75, 0.85, 1.0, 0.35), 1.0)
	for p: Dictionary in _parts:
		var t := Art.tex("fx", str(p["k"]))
		if t == null:
			continue
		var info := Art.info("fx", str(p["k"]))
		var cw := float(info.get("cell_w", t.get_width() / 4.0))
		var ch := float(info.get("cell_h", t.get_height()))
		var n := int(info.get("frames", 4))
		var f: int = int(p["f"]) % n
		_canvas.draw_texture_rect_region(t, Rect2(p["pos"], Vector2(cw, ch) * 0.5), Rect2(f * cw, 0, cw, ch))
	for c: Dictionary in _clouds:
		var p: Vector2 = c["pos"]
		var w: float = c["w"]
		var col := Color(0, 0, 0.1, c["alpha"] * 0.13) if overhead else Color(1, 1, 1, c["alpha"] * 0.55)
		_canvas.draw_rect(Rect2(p.x, p.y, w, 8), col)
		_canvas.draw_rect(Rect2(p.x + w * 0.2, p.y - 5, w * 0.5, 5), col)
		_canvas.draw_rect(Rect2(p.x + w * 0.35, p.y - 9, w * 0.25, 4), col)
	for b: Dictionary in _birds:
		var p: Vector2 = b["pos"]
		var flap := sin(_t * 9.0 + b["flap"])
		var wing := 2.0 * flap
		var col := Color("1c1c2c") if b["dark"] else Color("3a3a4a")
		var dir := signf(b["vel"].x)
		if overhead:
			# Shadow on the ground, below and a little behind the bird.
			var sp := p + Vector2(-2, 26)
			_canvas.draw_rect(Rect2(sp.x - 2, sp.y, 6, 1), Color(0, 0, 0, 0.18))
		# A "V" bird: body pixel, two wing strokes that flap.
		_canvas.draw_rect(Rect2(p.x, p.y, 2, 1), col)
		_canvas.draw_line(p + Vector2(0, 0.5), p + Vector2(-3 * dir, -wing), col, 1.0)
		_canvas.draw_line(p + Vector2(2, 0.5), p + Vector2(2 + 3 * dir, -wing), col, 1.0)


## Animated pond drawn into a map: shimmering water with rings and a soft edge.
class Pond:
	extends Node2D
	var rect := Rect2(0, 0, 64, 48)
	var _t := 0.0
	var _rings: Array = []

	func _process(delta: float) -> void:
		_t += delta
		if randf() < delta * 0.8:
			_rings.append({"pos": Vector2(randf_range(rect.position.x + 8, rect.end.x - 8), randf_range(rect.position.y + 8, rect.end.y - 8)), "age": 0.0})
		for r: Dictionary in _rings:
			r["age"] += delta
		_rings = _rings.filter(func(r: Dictionary) -> bool: return r["age"] < 2.2)
		queue_redraw()

	func _draw() -> void:
		if Art.has("tiles", "shore_set") and Art.has("tiles", "water"):
			var cols := int(rect.size.x / 16)
			var rows := int(rect.size.y / 16)
			var frame := int(_t * 4.0) % 4
			for y in rows:
				for x in cols:
					var at := rect.position + Vector2(x * 16, y * 16)
					var ix := 0 if x == 0 else (2 if x == cols - 1 else 1)
					var iy := 0 if y == 0 else (2 if y == rows - 1 else 1)
					if ix == 1 and iy == 1:
						Art.draw_tile(self, "tiles", "water", at, frame)
					else:
						Art.draw_tile(self, "tiles", "shore_set", at, iy * 3 + ix)
			for r: Dictionary in _rings:
				var a: float = r["age"]
				draw_arc(r["pos"], 2.0 + a * 5.0, 0, TAU, 20, Color(1, 1, 1, 0.45 * (1.0 - a / 2.2)), 1.0)
			return
		var deep := Color("2f6fb5")
		var shallow := Color("4d93d6")
		draw_rect(rect.grow(2), Color("c9a86b"))
		draw_rect(rect, deep)
		draw_rect(rect.grow(-6), shallow)
		# Moving highlight bands.
		for i in 7:
			var y := rect.position.y + 4 + i * (rect.size.y - 8) / 7.0
			var x := rect.position.x + 4 + fposmod(_t * 9.0 + i * 13.0, rect.size.x - 16)
			draw_rect(Rect2(x, y, 6, 1), Color(1, 1, 1, 0.35))
		for r: Dictionary in _rings:
			var a: float = r["age"]
			draw_arc(r["pos"], 2.0 + a * 5.0, 0, TAU, 20, Color(1, 1, 1, 0.45 * (1.0 - a / 2.2)), 1.0)

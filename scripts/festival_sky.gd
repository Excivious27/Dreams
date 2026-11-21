class_name FestivalSky
extends Node2D
## C14b P3 festival motion, code-drawn on game time (PlayClock), so it costs no art:
## - Lantern Festival (c14b_18-02, 04-14): from dusk, paper lanterns drift down the
##   river with a gentle bob and per-lantern phase, sky lanterns rise from the plaza
##   with a sway and fade near the top; after the player's lantern float, a short
##   fireworks show (soft bursts, no screen flash).
## - Star Festival (c14b_18-06): shooting stars streak across the night sky every
##   6-10 s; star_for(target) sends one to end over the player when a wish lands.
## - C15 P6 (c15_07-17): "jellies" (Moon Jellies / Neon Tide: glowing jellies drift over the water
##   rect, a gold one from year 3), "comet" (Comet Night: crystal streaks fall every 2-4 s) and
##   "fireworks" (Gift Swap / Gilt Gala: a burst over the plaza every 5-8 s after dark).
## Brightness follows GameState.darkness(); reduced motion = fewer, slower, no flicker.

var mode := ""
var river := Rect2()       # map px: lanterns drift top -> bottom along its centre line
var plaza := Vector2.ZERO  # map px: sky lanterns rise from here
var _river_l: Array = []   # [y, x_off, speed, phase]
var _sky_l: Array = []     # [pos, speed, phase, age]
var _bursts: Array = []    # [centre, age, colour, n, style]
var _stars: Array = []     # [from, to, age, dur]
var _next_sky := 0.0
var _next_star := 0.0
var _jel: Array = []       # [pos, phase, speed, gold]
var _next_burst := 0.0
var _rng := RandomNumberGenerator.new()


static func make(host: Node, m: String, river_px := Rect2(), plaza_px := Vector2.ZERO) -> FestivalSky:
	var f := FestivalSky.new()
	f.name = "FestivalSky"
	f.mode = m
	f.river = river_px
	f.plaza = plaza_px
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	f.material = mat
	f._rng.seed = int(GameState.run.get("day", 1)) * 977 + (1 if m == "star" else 2)
	if not m in ["lantern", "star", "jellies", "comet", "fireworks"]:
		f.mode = ""
	# Above the map's night CanvasModulate (like NightGlow), so the lights aren't darkened.
	var cl := CanvasLayer.new()
	cl.name = "FestivalSkyLayer"
	cl.layer = 1
	cl.follow_viewport_enabled = true
	cl.add_child(f)
	host.add_child(cl)
	return f


static func of(host: Node) -> FestivalSky:
	var n := host.get_node_or_null("FestivalSkyLayer/FestivalSky") if host else null
	return n as FestivalSky


func _ready() -> void:
	if mode == "jellies" and river.size.x > 0.0:
		var n := 5 if AmbientMotion.reduced() else 10
		var gold := FestivalWords.year_of(int(GameState.run.get("day", 1))) >= 3
		for i in n:
			_jel.append([river.position + Vector2(_rng.randf() * river.size.x, _rng.randf() * river.size.y), _rng.randf() * TAU, _rng.randf_range(3.0, 6.0), gold and i == 0])
	if mode == "lantern" and river.size.y > 0.0:
		var n := 6 if AmbientMotion.reduced() else 12
		for i in n:
			_river_l.append([river.position.y + river.size.y * (float(i) + _rng.randf() * 0.6) / n,
				_rng.randf_range(-0.3, 0.3) * river.size.x, _rng.randf_range(6.0, 10.0), _rng.randf() * TAU])


func _dark() -> float:
	return clampf(GameState.darkness(), 0.0, 1.0)


## The fireworks after a lantern float (3-5 soft bursts over the plaza, staggered).
func fireworks(over: Vector2) -> void:
	var n := 1 if AmbientMotion.reduced() else _rng.randi_range(3, 5)
	var cols := [Color(1, 0.85, 0.45), Color(0.6, 0.85, 1), Color(1, 0.55, 0.7), Color(0.7, 1, 0.6), Color(0.9, 0.7, 1)]
	var delay := 0.0
	for i in n:
		var c := over + Vector2(_rng.randf_range(-50, 50), _rng.randf_range(-90, -40))
		_bursts.append([c, -delay, cols[_rng.randi() % cols.size()], 18 + _rng.randi() % 8, _rng.randi() % 2])
		delay += _rng.randf_range(0.4, 0.9)


## A shooting star that ends over `target` (map px).
func star_for(target: Vector2) -> void:
	var from := target + Vector2(_rng.randf_range(60, 110) * (1 if _rng.randf() < 0.5 else -1), -140)
	_stars.append([from, target + Vector2(0, -60), 0.0, 0.9])


func _process(delta: float) -> void:
	var dk := _dark()
	var slow := 0.6 if AmbientMotion.reduced() else 1.0
	var t := PlayClock.now()
	if mode == "lantern":
		for l: Array in _river_l:
			l[0] = float(l[0]) + float(l[2]) * delta * slow
			if float(l[0]) > river.end.y:
				l[0] = river.position.y
		if dk > 0.35 and t >= _next_sky and _sky_l.size() < (3 if AmbientMotion.reduced() else 8):
			_sky_l.append([plaza + Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-10, 20)), _rng.randf_range(5.0, 8.0), _rng.randf() * TAU, 0.0])
			_next_sky = t + _rng.randf_range(2.5, 5.0) / slow
		for s: Array in _sky_l:
			s[3] = float(s[3]) + delta
			s[0] = (s[0] as Vector2) + Vector2(sin(t * 0.7 + float(s[2])) * 3.0, -float(s[1])) * delta * slow
		_sky_l = _sky_l.filter(func(s: Array) -> bool: return float(s[3]) < 40.0)
	elif mode == "star":
		if dk > 0.5 and t >= _next_star:
			var view := get_viewport_rect().size
			var cam := get_viewport().get_camera_2d()
			var c := cam.get_screen_center_position() if cam else view / 2.0
			star_for(c + Vector2(_rng.randf_range(-80, 80), _rng.randf_range(-40, 10)))
			_next_star = t + (_rng.randf_range(10.0, 14.0) if AmbientMotion.reduced() else _rng.randf_range(6.0, 10.0))
	elif mode == "jellies":
		for j: Array in _jel:
			j[0] = (j[0] as Vector2) + Vector2(sin(t * 0.4 + float(j[1])) * 2.0, -float(j[2])) * delta * slow
			if (j[0] as Vector2).y < river.position.y:
				j[0] = Vector2((j[0] as Vector2).x, river.end.y)
	elif mode == "comet":
		if dk > 0.5 and t >= _next_star:
			var cam2 := get_viewport().get_camera_2d()
			var c2 := cam2.get_screen_center_position() if cam2 else get_viewport_rect().size / 2.0
			star_for(c2 + Vector2(_rng.randf_range(-100, 100), _rng.randf_range(-20, 60)))
			_next_star = t + (_rng.randf_range(4.0, 6.0) if AmbientMotion.reduced() else _rng.randf_range(2.0, 4.0))
	elif mode == "fireworks":
		if dk > 0.4 and t >= _next_burst:
			fireworks(plaza)
			_next_burst = t + (_rng.randf_range(9.0, 12.0) if AmbientMotion.reduced() else _rng.randf_range(5.0, 8.0))
	for b: Array in _bursts:
		b[1] = float(b[1]) + delta
	_bursts = _bursts.filter(func(b: Array) -> bool: return float(b[1]) < 1.8)
	for s: Array in _stars:
		s[2] = float(s[2]) + delta
	_stars = _stars.filter(func(s: Array) -> bool: return float(s[2]) < float(s[3]) + 0.4)
	queue_redraw()


func _draw() -> void:
	var dk := _dark()
	var t := PlayClock.now()
	var flick := not AmbientMotion.reduced()
	if mode == "lantern" and dk > 0.05:
		var cx := river.position.x + river.size.x / 2.0
		for l: Array in _river_l:
			var p := Vector2(cx + float(l[1]) + sin(t * 0.5 + float(l[3])) * 1.5, float(l[0]) + sin(t * 1.3 + float(l[3])) * 1.0)
			_lantern(p, dk, flick, t, float(l[3]), true)
		for s: Array in _sky_l:
			var a := clampf(1.0 - float(s[3]) / 40.0, 0.0, 1.0) * clampf(float(s[3]) / 1.5, 0.0, 1.0)
			_lantern(s[0], dk * a, flick, t, float(s[2]), false)
	if mode == "jellies" and dk > 0.05:
		for j: Array in _jel:
			var jp: Vector2 = j[0]
			var pulse := 1.0 + (0.15 * sin(t * 2.0 + float(j[1])) if flick else 0.0)
			var jc := Color(1.0, 0.85, 0.4) if bool(j[3]) else Color(0.6, 0.85, 1.0)
			draw_circle(jp, 8.0 * pulse, Color(jc, 0.15 * dk))
			draw_circle(jp, 3.5, Color(jc, 0.6 * dk))
			for k in 3:
				draw_rect(Rect2(jp + Vector2(-2 + k * 2, 3 + sin(t * 3.0 + k) * 1.0), Vector2(1, 4)), Color(jc, 0.4 * dk))
	for b: Array in _bursts:
		var age := float(b[1])
		if age < 0.0:
			continue
		var k := age / 1.8
		var r := 34.0 * (1.0 - pow(1.0 - minf(age / 0.7, 1.0), 3.0))
		var col: Color = b[2]
		var n := int(b[3])
		for i in n:
			var ang := TAU * i / n
			var p := (b[0] as Vector2) + Vector2(cos(ang), sin(ang)) * r * (1.0 if int(b[4]) == 0 or i % 2 == 0 else 0.7) + Vector2(0, 14.0 * k * k)
			draw_rect(Rect2(p - Vector2(0.75, 0.75), Vector2(1.5, 1.5)), Color(col, (1.0 - k) * 0.9))
			if int(b[4]) == 1 and age > 0.3:
				draw_rect(Rect2(p + Vector2(0, 3.0 * k) - Vector2(0.5, 0.5), Vector2(1, 1)), Color(col, (1.0 - k) * 0.5))
		if age < 0.25:
			draw_circle(b[0], 6.0 * (1.0 - age / 0.25), Color(col, 0.35))
	for s: Array in _stars:
		var u := clampf(float(s[2]) / float(s[3]), 0.0, 1.0)
		var e := 1.0 - pow(1.0 - u, 2.0)
		var fade := 1.0 if float(s[2]) <= float(s[3]) else 1.0 - (float(s[2]) - float(s[3])) / 0.4
		var from: Vector2 = s[0]
		var to: Vector2 = s[1]
		var head := from.lerp(to, e) + Vector2(0, -8.0 * sin(e * PI))
		var dir := (to - from).normalized()
		for i in 6:
			var tp := head - dir * 3.0 * (i + 1)
			draw_rect(Rect2(tp - Vector2(0.5, 0.5), Vector2(1, 1)), Color(0.85, 0.9, 1, fade * (0.7 - i * 0.11)))
		draw_rect(Rect2(head - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, fade))


func _lantern(p: Vector2, a: float, flick: bool, t: float, ph: float, river_l: bool) -> void:
	var f := 1.0 + (0.08 * sin(t * 7.0 + ph * 3.0) if flick else 0.0)
	draw_circle(p, 7.0 * f, Color(1.0, 0.6, 0.25, 0.18 * a))
	draw_rect(Rect2(p - Vector2(2, 2.5), Vector2(4, 5)), Color(1.0, 0.72, 0.35, 0.85 * a))
	draw_rect(Rect2(p - Vector2(1, 1.5), Vector2(2, 3)), Color(1.0, 0.95, 0.7, 0.9 * a * f))
	if river_l:
		draw_rect(Rect2(p + Vector2(-3, 3), Vector2(6, 1)), Color(1.0, 0.7, 0.4, 0.25 * a))

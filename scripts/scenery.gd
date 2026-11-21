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
		_parts.clear()
		_drops.clear()
		_snow.clear()
		_fade = 0.0
		# Today's calendar weather follows the day; a region's own weather stays put.
		follow_day = not GameState.run.is_empty() and v == GameState.weather_today()
		_day = int(GameState.run.get("day", -1)) if not GameState.run.is_empty() else -1
## true while `weather` is the calendar's: refreshed when the day changes (c5_11 #8).
var follow_day := false
var _day := -1
## Weathers with no birds overhead.
const NO_FLOCKS := ["rain", "storm", "snow", "blizzard", "sandstorm", "ash", "fog"]
var _drops: Array = []  # rain/storm/drizzle/hail: {p, v, len, a}
var _snow: Array = []  # snow/blizzard flakes: {p, layer, fall, sway, fq, ph}
## C14b: drop count, fall velocity (px/s) and streak length per wet weather.
const PRECIP := {"rain": [140, Vector2(-40, 260), 10.0], "drizzle": [60, Vector2(-20, 200), 6.0],
	"storm": [220, Vector2(-90, 380), 14.0], "hail": [80, Vector2(-30, 320), 4.0]}
## Snow depth layers: [count, size px, alpha, fall min, fall max, sway px] (c14b_18-03).
const SNOW_LAYERS := [[50, 1.5, 0.75, 10.0, 14.0, 3.0], [40, 2.0, 0.9, 18.0, 26.0, 6.0], [20, 3.0, 1.0, 30.0, 40.0, 10.0]]
var _fade := 1.0  # weather particles fade in after a change (c14b_18-09)
var _parts: Array = []
var _ov_t := 0.0
## Painted aurora band across the top of the sky (crystal meadow / moon nights).
var aurora := false
## Overcast washes per weather (c14_16-02): rainy and grey days are dimmer and cooler than sunny ones.
const OVERCAST := {"rain": Color(0.1, 0.12, 0.18, 0.15), "fog": Color(0.55, 0.58, 0.64, 0.08), "snow": Color(0.5, 0.55, 0.65, 0.07), "sandstorm": Color(0.45, 0.32, 0.15, 0.1), "ash": Color(0.15, 0.1, 0.1, 0.12)}
const OVERLAYS := {"rain": "ov_rain", "storm": "ov_heavy_rain", "snow": "ov_snow", "blizzard": "ov_blizzard", "petals": "ov_petals", "leaves": "ov_leaves", "fireflies": "ov_fireflies", "fog": "ov_fog", "dust": "ov_dust", "sandstorm": "ov_sandstorm", "ash": "ov_ash", "meteors": "ov_meteors"}


func _overlay() -> Texture2D:
	var nm := str(OVERLAYS.get(weather, ""))
	if nm == "":
		return null
	if PRECIP.has(weather) or weather in ["snow", "blizzard"]:
		return null  # C14b: falling drops/flakes in code (the tiled strips strobed in place: c14b_16-04, c14b_18-04)
	if weather == "fireflies":
		return null  # drifting glow particles (CONDUCT 4: the tiled strip read as a grid of orbs)
	if weather in ["leaves", "petals"] and Art.has("fx", _pkind()):
		return null  # drifting particles too: the tiled leaf/petal strips read as a grid (c5_11 #1)
	var pk := "firefly" if weather == "fireflies" else "snowflake"
	if weather in ["fireflies", "snow"] and Art.has("fx", pk) and int(Art.info("fx", pk).get("h", 0)) <= 48:  # (fx/firefly is a mis-cut 393x137 slab: use the overlay strip)
		return null  # drifting particles; a tiled frame reads as a grid
	var nm2 := nm.replace("ov_", "ov2_").replace("ov2_heavy_rain", "ov2_storm")
	# These ov2 strips cut their shapes at the 128-px frame edges (a grid of half
	# blobs once tiled): use the clean ov_ strip when there is one.
	if Art.has("fx", nm2) and not (Art.has("fx", nm) and weather in ["fireflies", "leaves", "petals", "snow", "ash"]):
		return Art.tex("fx", nm2)
	if not Art.has("fx", nm):
		return null
	return Art.tex("fx", nm)


## The particle art for leaves/petals/snow (petal_pink when sliced, else a tinted leaf).
func _pkind() -> String:
	match weather:
		"snow": return ""  # C14b: code-drawn depth layers (_snow)
		"leaves": return "leaf_orange"
		"petals": return "petal_pink" if Art.has("fx", "petal_pink") else "leaf_green"
		"fireflies": return "firefly"
	var sp := _sprinkle()
	return sp


## C14b (c14b_18-05): a light seasonal sprinkle on clear/sun/wind days outdoors:
## spring petals, fall leaves. Not in cities, caves or under a fixed dark.
func _sprinkle() -> String:
	if not overhead or not (weather in ["clear", "sun", "wind"]) or GameState.run.is_empty():
		return ""
	var host := get_parent()
	if host is GameMap:
		var gm := host as GameMap
		if gm.fixed_dark >= 0.0 or gm.scene_id() in Ambience.CITY_MAPS:
			return ""
	match GameState.look_se():
		"spring": return "petal_pink" if Art.has("fx", "petal_pink") else ""
		"fall": return "leaf_orange" if Art.has("fx", "leaf_orange") else ""
	return ""


func _ready() -> void:
	layer = 3 if overhead else -1
	_w = DisplayMode.view.x
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
	_w = DisplayMode.view.x  # wide desktop view: weather and clouds span it
	if overhead:
		var hm := get_parent()
		Anim.set_weather(weather, (hm as GameMap).scene_id() if hm is GameMap else "", false)
	Anim.tick()
	_t += delta
	_ov_t += delta
	for c: Dictionary in _clouds:
		c["pos"].x += c["speed"] * delta
		if c["pos"].x > _w + 70:
			c["pos"].x = -70
	if follow_day and not GameState.run.is_empty() and int(GameState.run.get("day", -1)) != _day:
		weather = GameState.weather_today()
	_tint_acc += delta
	if overhead and _tint_acc >= 0.5:
		# Layer 3 sits above the map's CanvasModulate: dim it with the night, lifted (c5_11 #2).
		_tint_acc = 0.0
		var host := get_parent()
		if host is GameMap and not GameState.run.is_empty() and GameState.run.has("time"):
			_canvas.modulate = (host as GameMap).sky_tint(int(GameState.run["time"])).lerp(Color.WHITE, 0.3)
	_next_flock -= delta
	if _next_flock <= 0.0 and (raining or weather in NO_FLOCKS):
		_next_flock = 3.0
	elif _next_flock <= 0.0:
		_spawn_flock()
		_next_flock = randf_range(7.0, 16.0)
	for b: Dictionary in _birds:
		b["pos"] += b["vel"] * delta
		b["pos"].y += sin(_t * 2.0 + b["phase"]) * 6.0 * delta
	for i in range(_birds.size() - 1, -1, -1):
		var bx: float = _birds[i]["pos"].x
		if bx <= -40 or bx >= _w + 40:
			_birds.remove_at(i)
	# C14b (c14b_06-10): world-space particles (fireflies, leaves, petals) stay put
	# in the world when the camera moves instead of sliding with the screen.
	var co := get_viewport().get_canvas_transform().origin if overhead else Vector2.ZERO
	var cd := co - _cam_prev if _cam_prev.x < INF else Vector2.ZERO
	_cam_prev = co
	if cd.length_squared() > 0.0 and cd.length_squared() < 400.0 * 400.0:
		for p: Dictionary in _parts:
			p["pos"] += cd
	var pkind := _pkind()
	if weather == "fireflies":
		# Fireflies: soft glows that wander on their own slow loops, pulse, and wrap.
		if _parts.is_empty() or str(_parts[0].get("k", "")) != "glow":
			_parts.clear()
		while _parts.size() < 16:
			_parts.append({"pos": Vector2(randf_range(0, _w), randf_range(30, _h - 30)), "t": randf() * TAU, "k": "glow",
				"sp": randf_range(0.5, 1.1), "r": randf_range(6.0, 14.0), "f": 0})
		for p: Dictionary in _parts:
			p["t"] += delta * float(p["sp"])
			var tt: float = p["t"]
			p["pos"] += Vector2(sin(tt * 1.1) + 0.35 * sin(tt * 2.7), cos(tt * 0.8) * 0.8 - 0.15) * float(p["r"]) * delta
			p["pos"].x = fposmod(p["pos"].x + 10.0, _w + 20.0) - 10.0
			p["pos"].y = fposmod(p["pos"].y + 10.0, _h + 20.0) - 10.0
			p["f"] = int(tt * 3.0) % 4
	elif _overlay() != null:
		_parts.clear()
	elif pkind != "" and Art.has("fx", pkind):
		var sprinkle := not (weather in ["leaves", "petals"])
		var leafy := true
		var want := 18
		if sprinkle:
			want = (10 if weather == "wind" else (5 if pkind == "petal_pink" else 7))
		if Settings.reduced_motion():
			want = maxi(10, want / 2) if not sprinkle else maxi(2, want / 2)
		while _parts.size() < want:
			# Each leaf/petal has its own fall speed, sway, spin and flutter rate, so
			# they drift loose instead of marching down in a grid.
			_parts.append({"pos": Vector2(randf_range(-20, _w + 20), randf_range(-20, _h)), "f": randi() % 4, "t": randf() * TAU, "k": pkind,
				"fall": randf_range(14.0, 30.0) if leafy else 18.0, "sway": randf_range(6.0, 16.0) if leafy else 8.0, "wob": randf_range(0.6, 1.4) if leafy else 1.0,
				"rot": randf() * TAU, "spin": randf_range(-1.6, 1.6), "fps": randf_range(2.5, 5.0) if leafy else 4.0, "sz": (randf_range(0.6, 0.85) if pkind == "petal_pink" else randf_range(0.35, 0.55)) if leafy else 0.5})
		for p: Dictionary in _parts:
			if weather == "fireflies":
				p["t"] += delta
				p["pos"] += Vector2(sin(p["t"] * 1.3) * 12.0, cos(p["t"] * 0.9) * 8.0) * delta
			else:
				var fall: float = p.get("fall", 18.0)
				var sway: float = p.get("sway", 8.0)
				p["t"] += delta * float(p.get("wob", 1.0))
				p["pos"] += Vector2(sin(p["t"]) * sway + 6.0 + Anim.wind() * 30.0, fall) * delta * (0.6 if Settings.reduced_motion() else 1.0)
				p["rot"] = float(p.get("rot", 0.0)) + float(p.get("spin", 0.0)) * delta
				if p["pos"].y > _h + 10:
					p["pos"] = Vector2(randf_range(-20, _w + 20), -10)
				if p["pos"].x > _w + 20:
					p["pos"].x = -20.0
				elif p["pos"].x < -24.0:
					p["pos"].x = _w + 20.0
				if p["pos"].y < -30.0:
					p["pos"].y = randf_range(0.0, _h)  # camera walked down: refill
			p["f"] = int(_t * float(p.get("fps", 4.0)) + float(p["t"])) % 4
	else:
		_parts.clear()
	_fade = minf(1.0, _fade + delta / 1.0)
	_streak_x += delta * (0.6 + Anim.wind() * 0.6)
	_tick_precip(delta)
	# Clear calm sky: clouds drift a few px/s, so 20 redraws a second is plenty.
	_redraw_acc += delta
	if not _drops.is_empty() or not _snow.is_empty() or not _parts.is_empty() or not _birds.is_empty() or (_overlay() != null and weather != "fog") or aurora or weather in ["wind", "storm"] or _redraw_acc >= 0.05:
		_redraw_acc = 0.0
		_canvas.queue_redraw()


## C14b: rain/storm/drizzle/hail as real falling streaks and snow/blizzard as 3
## parallax depth layers, all on one wind (Anim.wind) and fewer/slower with reduced motion.
func _tick_precip(delta: float) -> void:
	var calm := Settings.reduced_motion()
	var wv := Anim.wind()
	if PRECIP.has(weather) and overhead:
		var pr: Array = PRECIP[weather]
		var want := int(pr[0]) / (2 if calm else 1)
		var v: Vector2 = pr[1] * (0.6 if calm else 1.0)
		v.x -= wv * 40.0
		while _drops.size() < want:
			var dep := randf_range(0.6, 1.0)
			_drops.append({"p": Vector2(randf_range(-20, _w + 60), randf_range(-20, _h)), "d": dep, "len": float(pr[2]) * randf_range(0.7, 1.2) * dep, "a": randf_range(0.4, 0.75) * dep})
		while _drops.size() > want:
			_drops.pop_back()
		for dr: Dictionary in _drops:
			dr["p"] += v * float(dr["d"]) * delta
			if dr["p"].y > _h + 10 or dr["p"].x < -30:
				dr["p"] = Vector2(randf_range(0, _w + 80), randf_range(-30, -5))
	elif not _drops.is_empty():
		_drops.clear()
	if weather in ["snow", "blizzard"] and overhead:
		var bl := weather == "blizzard"
		var k := (1.45 if bl else 1.0) * (0.5 if calm else 1.0)
		if _snow.is_empty():
			for li in SNOW_LAYERS.size():
				var L: Array = SNOW_LAYERS[li]
				for i in int(float(L[0]) * k):
					_snow.append({"p": Vector2(randf_range(-20, _w + 20), randf_range(-10, _h)), "l": li,
						"fall": randf_range(float(L[3]), float(L[4])) * (3.0 if bl else 1.0), "sw": float(L[5]), "fq": randf_range(0.5, 1.3), "ph": randf() * TAU})
		var drift := (4.0 + 6.0 * sin(_ov_t * 0.13)) + wv * 20.0
		if bl:
			drift = -70.0 - 40.0 * (0.5 + 0.5 * sin(_ov_t * 0.4))
		var sp := 0.6 if calm else 1.0
		for f: Dictionary in _snow:
			var par := 0.5 + 0.5 * float(f["l"])  # far layers drift less (parallax)
			f["ph"] += delta * float(f["fq"])
			f["p"] += Vector2(drift * par + cos(float(f["ph"])) * float(f["sw"]) * float(f["fq"]), float(f["fall"])) * delta * sp
			if f["p"].y > _h + 6:
				f["p"] = Vector2(randf_range(-20, _w + 20), -6)
			f["p"].x = fposmod(f["p"].x + 20.0, _w + 40.0) - 20.0
	elif not _snow.is_empty():
		_snow.clear()


## C14b (c14b_05-01/02/07): the aurora as soft code-drawn light ribbons, not a boxed
## picture: each ribbon's crest follows slow sums of sines, its colour fades to 0 at
## the top, bottom and both ends (no hard edge), hues drift, and it breathes. One
## mesh, one draw call. Reduced motion: held still and dimmer.
const AURORA_COLS := [Color(0.35, 1.0, 0.75), Color(0.45, 0.8, 1.0), Color(0.75, 0.5, 1.0)]
var _aur_tris := 0
var _aur_node: Node2D


## Own node: additive light, not dimmed by the night tint on the weather canvas.
func _aurora_node() -> Node2D:
	if _aur_node == null:
		_aur_node = Node2D.new()
		var cm := CanvasItemMaterial.new()
		cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_aur_node.material = cm
		_aur_node.draw.connect(func() -> void: _draw_aurora(GameState.darkness()))
		add_child(_aur_node)
		move_child(_aur_node, 0)
	_aur_node.visible = true
	return _aur_node


func _draw_aurora(dark: float) -> void:
	var calm := Settings.reduced_motion()
	var t := 0.0 if calm else Anim.t()
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var n := 28
	var breath := (0.8 + 0.2 * sin(t * 0.4)) * (0.6 if calm else 1.0)
	for r in 3:
		var base := 118.0 + r * 22.0  # crests below the HUD rows, curtains rising behind them
		var hgt := 56.0 - r * 8.0
		var c: Color = AURORA_COLS[r].lerp(AURORA_COLS[(r + 1) % 3], 0.5 + 0.5 * sin(t * 0.05 + r * 2.0))
		var amax := (0.42 - r * 0.08) * dark * breath
		var x0 := -20.0 + sin(t * 0.07 + r) * 12.0
		var w := _w + 40.0
		for i in n:
			var ua := float(i) / n
			var ub := float(i + 1) / n
			for pair in [[ua, ub]]:
				var xs := [x0 + pair[0] * w, x0 + pair[1] * w]
				var ys := []
				var es := []
				for k in 2:
					var u: float = pair[k]
					var crest: float = base + sin(u * 5.0 + t * 0.21 + r * 1.3) * 10.0 + sin(u * 11.0 - t * 0.33 + r) * 4.0
					ys.append(crest)
					es.append(sin(u * PI) * (0.75 + 0.25 * sin(u * 17.0 + t * 0.5 + r)))  # ends fade, vertical streaks shimmer
				var top0 := Vector2(xs[0], ys[0] - hgt)
				var top1 := Vector2(xs[1], ys[1] - hgt)
				var mid0 := Vector2(xs[0], ys[0])
				var mid1 := Vector2(xs[1], ys[1])
				var bot0 := Vector2(xs[0], ys[0] + 8.0)
				var bot1 := Vector2(xs[1], ys[1] + 8.0)
				var c0 := Color(c, 0.0)
				var cm0 := Color(c, amax * float(es[0]))
				var cm1 := Color(c, amax * float(es[1]))
				# upper curtain: transparent top -> bright crest
				verts.append_array([top0, top1, mid1, top0, mid1, mid0])
				cols.append_array([c0, c0, cm1, c0, cm1, cm0])
				# short soft fall-off below the crest
				verts.append_array([mid0, mid1, bot1, mid0, bot1, bot0])
				cols.append_array([cm0, cm1, c0, cm0, c0, c0])
	_aur_tris = verts.size() / 3
	for i in range(0, verts.size(), 6):  # each 6 verts = one quad (2 tris): draw as a 4-point polygon
		_aur_node.draw_polygon(PackedVector2Array([verts[i], verts[i + 1], verts[i + 2], verts[i + 5]]),
			PackedColorArray([cols[i], cols[i + 1], cols[i + 2], cols[i + 5]]))


func _draw_precip() -> void:
	if not _drops.is_empty():
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var pr: Array = PRECIP.get(weather, PRECIP["rain"])
		var dir: Vector2 = (pr[1] as Vector2) + Vector2(-Anim.wind() * 40.0, 0)
		dir = dir.normalized()
		var hail := weather == "hail"
		for dr: Dictionary in _drops:
			var p: Vector2 = dr["p"]
			pts.append(p)
			pts.append(p + dir * float(dr["len"]))
			var c := Color(0.85, 0.9, 1.0, float(dr["a"]) * _fade) if not hail else Color(0.95, 0.97, 1.0, 0.8 * _fade)
			cols.append(c)
		_canvas.draw_multiline_colors(pts, cols, 2.0 if hail else 1.0)
	if not _snow.is_empty():
		var bl := weather == "blizzard"
		for f: Dictionary in _snow:
			var L: Array = SNOW_LAYERS[int(f["l"])]
			var sz := float(L[1])
			var a := float(L[2]) * _fade
			var p: Vector2 = f["p"]
			if bl and int(f["l"]) == 2:
				_canvas.draw_line(p, p + Vector2(4, -1.2), Color(1, 1, 1, a), 1.0)  # near blizzard flakes streak along the wind
			elif sz >= 3.0:
				_canvas.draw_circle(p, 2.5, Color(1, 1, 1, a * 0.3))
				_canvas.draw_circle(p, 1.5, Color(1, 1, 1, a))
			else:
				_canvas.draw_rect(Rect2(p, Vector2(sz, sz)), Color(1, 1, 1, a))
		if bl:
			_canvas.draw_rect(Rect2(0, 0, _w, _h), Color(0.92, 0.95, 1.0, 0.04 * (sin(_ov_t * 0.7) + sin(_ov_t * 1.9) + 2.0) * _fade))


var _redraw_acc := 0.0
var _tint_acc := 1.0
var _flash_t := 0.0
var _next_flash := 4.0
var _flash_x := 40.0
var _streak_x := 0.0
var _cam_prev := Vector2(INF, INF)


func _draw_weather_extras() -> void:
	var t := int(GameState.run.get("time", 0))
	# Rainbow: the first clear hours after a wet day, morning only.
	var daylit := GameState.darkness(t) < 0.25  # sun effects only while the sun is up (c14_16-03)
	if daylit and weather in ["clear", "sun", "petals"] and GameState.weather_for(int(GameState.run["day"]) - 1) in ["rain", "storm"] and t < 11 * 60 and Art.has("fx", "rainbow"):
		_canvas.draw_texture_rect(Art.tex("fx", "rainbow"), Rect2(Vector2(20, 40), Vector2(268, 84)), false, Color(1, 1, 1, 0.55))
	# God rays on sunny mornings, drifting slowly.
	if daylit and weather == "sun" and t >= 6 * 60 and t < 10 * 60 and Art.has("fx", "godrays_a"):
		var gx := sin(_ov_t * 0.15) * 10.0
		_canvas.draw_texture_rect(Art.tex("fx", "godrays_a"), Rect2(Vector2(140 + gx, -10), Vector2(140, 100)), false, Color(1, 1, 1, 0.35))
	# Wind streaks race across on windy days.
	if weather == "wind" and Art.has("fx", "wind_streak_0"):
		for i in 4:
			var x := fmod(_streak_x * (120.0 + i * 25.0) + i * 90.0, _w + 120.0) - 60.0  # C14b: speed follows Anim.wind
			var wt := Art.tex("fx", "wind_streak_%d" % i)
			# Its own aspect (squashing it to 40x24 crushed the streak), half size.
			var wsz := Vector2(wt.get_width(), wt.get_height()) * 0.5
			if wsz.x > 90.0:
				wsz *= 90.0 / wsz.x
			_canvas.draw_texture_rect(wt, Rect2(Vector2(x, 60 + i * 95 + sin(_ov_t + i) * 6.0), wsz), false, Color(1, 1, 1, 0.65))
	# Storms are dark and blizzards white out a little (c5_11 #3): a soft wash.
	# Rain, snow and fog days get their own grey overcast light too (c14_16-02).
	if weather == "storm":
		_canvas.draw_rect(Rect2(0, 0, _w, _h), Color(0.08, 0.1, 0.16, 0.18))
	elif weather in OVERCAST:
		_canvas.draw_rect(Rect2(0, 0, _w, _h), OVERCAST[weather])
	elif weather == "blizzard":
		_canvas.draw_rect(Rect2(0, 0, _w, _h), Color(0.92, 0.95, 1.0, 0.12))
	# Lightning in storms: a quick 4-frame flash every few seconds.
	if weather == "storm" and Art.has("fx", "lightning_flash"):
		_next_flash -= get_process_delta_time()
		if _next_flash <= 0.0:
			_flash_t = 0.5
			_flash_x = randf_range(-20, _w - 150)  # one spot per bolt (it jumped sideways every redraw: c14b_14-15)
			_next_flash = randf_range(3.0, 9.0)
			if Settings.reduced_motion():
				_next_flash = maxf(_next_flash, Settings.CALM_FLASH_GAP)  # C9: never more than one per 6 s
			if is_inside_tree():
				Ambience.instance(get_tree()).thunder()
		if _flash_t > 0.0:
			_flash_t -= get_process_delta_time()
			var fr := clampi(int((0.5 - _flash_t) * 8.0), 0, 3)
			var info := Art.info("fx", "lightning_flash")
			var fw := float(info.get("cell_w", 188))
			var fh := float(info.get("cell_h", 136))
			# Reduced motion and flashes (Settings, C9): the bolt stays soft, the screen flash is gentle.
			var calm := Settings.reduced_motion()
			_canvas.draw_texture_rect_region(Art.tex("fx", "lightning_flash"), Rect2(Vector2(_flash_x, 0), Vector2(170, 120)), Rect2(fr * fw, 0, fw, fh), Color(1, 1, 1, Settings.CALM_FLASH_ALPHA if calm else 0.8))
			_canvas.draw_rect(Rect2(0, 0, _w, _h), Color(1, 1, 1, (0.03 if calm else 0.12) if fr < 2 else (0.0 if calm else 0.04)))


var _puff: Texture2D


## The fog puff: white-blue, alpha as 5 stacked 2.5% discs (r 70..22) gave, smoothed.
func _fog_puff() -> Texture2D:
	if _puff == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.31, 0.49, 0.66, 0.83, 1.0])
		var c := Color(0.9, 0.92, 0.95)
		g.colors = PackedColorArray([Color(c, 0.119), Color(c, 0.097), Color(c, 0.074), Color(c, 0.05), Color(c, 0.025), Color(c, 0.0)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_puff = gt
	return _puff


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
	if overhead and weather == "clear" and Art.has("fx", "cloud_shadow") and _canvas.visible and GameState.darkness() < 0.25:  # no sun, no cloud shadows (c14_16-03)
		# Soft cloud shadows drifting over the ground on clear days.
		var cs := Art.tex("fx", "cloud_shadow")
		var fr := 2  # the one frame whose blobs aren't cut by the frame edge (frames swapping made the shadows jump)
		var span := maxf(768.0, _w + 512.0)
		for i in 3:
			var sx := fposmod(i * span / 3.0 + _ov_t * 6.0, span) - 256.0  # each shadow keeps its own path across the wrap (c14b_16-25)
			_canvas.draw_texture_rect_region(cs, Rect2(Vector2(sx, 120 + sin(_ov_t * 0.1 + i * 2.1) * 40.0), Vector2(256, 160)), Rect2(fr * 256 + 2, 0, 252, 160), Color(0.12, 0.14, 0.2, 0.16))  # purple-keyed art: tint it to a neutral shade
	if aurora and overhead and GameState.darkness() > 0.0:
		_aurora_node().queue_redraw()
	elif _aur_node != null and _aur_node.visible:
		_aur_node.visible = false
	if overhead:
		_draw_weather_extras()
	var ov := _overlay()
	if weather == "fog" and overhead:
		# Soft drifting haze, drawn in code: the tiled fog strip read as hard grey bands.
		ov = null
		var lift := 0.4 if not GameState.run.is_empty() and Perks.flag("fog_lift") else 1.0
		_canvas.draw_rect(Rect2(0, 0, _w, _h), Color(0.85, 0.88, 0.92, 0.10 * lift))
		# One soft blob texture per puff (it was 5 stacked draw_circles: 35 draw calls
		# and twice the blended fill).
		var puff := _fog_puff()
		for i in 7:
			var cx := fmod(i * 97.0 + _ov_t * (4.0 + i), _w + 160.0) - 80.0
			var cy := 60.0 + fmod(i * 131.0, _h - 120.0) + sin(_ov_t * 0.2 + i) * 12.0
			_canvas.draw_texture_rect(puff, Rect2(cx - 70.0, cy - 70.0, 140.0, 140.0), false, Color(1, 1, 1, lift))
	if ov != null and overhead:
		# Painted weather overlay: 4-frame 128x96 strip tiled across the screen, additive-ish.
		var fw := 128
		var fh := 96
		var fr := int(_ov_t * 8.0) % 4
		var src := Rect2(fr * fw, 0, fw, fh)
		var alpha := 0.55 if weather in ["fog", "dust", "sandstorm"] else 0.8
		var drift := Vector2(fmod(_ov_t * 10.0, fw), fmod(_ov_t * 30.0, fh)) if weather in ["fog", "dust", "sandstorm", "ash"] else Vector2.ZERO
		for y in range(-1, int(_h / fh) + 2):
			for x in range(-1, int(_w / fw) + 2):
				_canvas.draw_texture_rect_region(ov, Rect2(Vector2(x * fw, y * fh) + drift, Vector2(fw, fh)), src, Color(1, 1, 1, alpha))
	if overhead:
		_draw_precip()
	var dark := clampf(GameState.darkness() if GameState.run.has("time") else 0.5, 0.0, 1.0)
	for p: Dictionary in _parts:
		if str(p["k"]) == "glow":
			var pulse := 0.5 + 0.5 * sin(float(p["t"]) * 2.3)
			var a := (0.25 + 0.75 * pulse) * dark * _fade  # fireflies glow only after sunset
			var gp: Vector2 = p["pos"]
			var ft := Art.tex("fx", "firefly_%d" % int(p["f"]))
			if ft != null and ft.get_height() <= 48:
				var sz := Vector2(ft.get_width(), ft.get_height()) * 0.5
				_canvas.draw_texture_rect(ft, Rect2(gp - sz / 2.0, sz), false, Color(1, 1, 1, a))
			else:
				_canvas.draw_circle(gp, 4.5, Color(1.0, 0.85, 0.35, a * 0.18))
				_canvas.draw_circle(gp, 2.5, Color(1.0, 0.9, 0.45, a * 0.35))
				_canvas.draw_circle(gp, 1.1, Color(1.0, 1.0, 0.8, a))
			continue
		var t := Art.tex("fx", str(p["k"]))
		if t == null:
			continue
		var info := Art.info("fx", str(p["k"]))
		var cw := float(info.get("cell_w", t.get_width() / 4.0))
		var ch := float(info.get("cell_h", t.get_height()))
		var n := int(info.get("frames", 4))
		var f: int = int(p["f"]) % n
		if p.has("rot") and (weather in ["leaves", "petals"] or _sprinkle() != ""):
			var sz := Vector2(cw, ch) * float(p.get("sz", 0.5))
			var tint := Color(1.0, 0.72, 0.84) if str(p["k"]) == "leaf_green" else Color.WHITE  # no petal art: pink leaves
			tint.a *= _fade
			_canvas.draw_set_transform(p["pos"], float(p["rot"]), Vector2.ONE)
			_canvas.draw_texture_rect_region(t, Rect2(-sz / 2.0, sz), Rect2(f * cw, 0, cw, ch), tint)
			_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			continue
		_canvas.draw_texture_rect_region(t, Rect2(p["pos"], Vector2(cw, ch) * 0.5), Rect2(f * cw, 0, cw, ch))
	for c: Dictionary in _clouds:
		if overhead:
			break  # over the world these were hard-edged boxes on the ground; cloud_shadow does the shadows
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

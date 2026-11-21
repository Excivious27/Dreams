class_name MagicFx
extends Node2D
## C14b P4 (c14b_05-08, c14b_06-04, c14b_05-15, c14b_06-05, c14b_05-16): the ambient
## magic layer of the magic and tech areas. Two nodes per map:
##  * ground: twinkling four-point sparkles that bloom and fade on free cells near the
##    camera (and on crystal props), each on its own eased life and phase, below
##    everything that stands (GameMap.to_under);
##  * air: soft light veils that ripple slowly across the upper sky, high shimmer glints
##    and motes (wisps, spores, embers) that drift up with a sine sway, over the map.
## Everything runs on game time (Anim.t() when P1's Anim API is there, else PlayClock),
## is culled to the view, halves its counts on web/phone and drops to ~30% motion with
## no flashing under Settings.reduced_motion(). Profiles: PROFILES below, keyed by map
## id; a regions.json "magic": {...} block overrides or adds one.

const PROFILES := {
	"crystal_meadow": {"pal": ["7ff0e6", "ff9fd6", "ffffff", "b9a6ff"], "spark": 16, "motes": 12, "veil": 0.10, "veil_pal": ["6fe8d8", "c7a0ff"], "day": 0.7, "glint": "crystal"},
	"moon": {"pal": ["d9c8ff", "ffffff", "a9c4ff"], "spark": 14, "motes": 8, "veil": 0.13, "veil_pal": ["b48cff", "7fd8ff"], "day": 0.9, "stars": 14, "kind": "dust"},
	"gloam_violet_glade": {"pal": ["8ff3ff", "c58cff", "ff9be0"], "spark": 16, "motes": 12, "veil": 0.10, "veil_pal": ["9a7bff", "6fe0ff"], "day": 0.55},
	"gloam_moonpool": {"pal": ["bfe8ff", "ffffff", "c9a8ff"], "spark": 14, "motes": 10, "veil": 0.12, "veil_pal": ["a8c8ff", "d0a0ff"], "day": 0.6, "stars": 8},
	"gloam_crystal_thicket": {"pal": ["8ff3ff", "e0b0ff", "ffffff"], "spark": 18, "motes": 8, "veil": 0.07, "veil_pal": ["7fe8ff", "c49aff"], "day": 0.6, "glint": "crystal"},
	"gloam_lanternfall": {"pal": ["ffd98a", "ffb0d8", "9ff0ff"], "spark": 12, "motes": 14, "veil": 0.08, "veil_pal": ["ffc88a", "b48cff"], "day": 0.55},
	"sky": {"pal": ["fff2b0", "ffffff", "ffe08a"], "spark": 12, "motes": 6, "veil": 0.09, "veil_pal": ["fff0c0", "c8e4ff"], "day": 0.8, "stars": 10},
	"sky_reaches": {"pal": ["fff2b0", "ffffff", "cfe8ff"], "spark": 12, "motes": 6, "veil": 0.10, "veil_pal": ["ffeec0", "b8dcff"], "day": 0.8, "stars": 12},
	"wind_starfall_garden": {"pal": ["fff6c8", "ffd0f0", "c8e8ff"], "spark": 16, "motes": 10, "veil": 0.11, "veil_pal": ["ffe6a0", "c8a8ff"], "day": 0.7, "stars": 14},
	"bf_cloud_stair": {"pal": ["fff2b0", "ffffff"], "spark": 8, "motes": 4, "veil": 0.07, "veil_pal": ["fff0c0", "c8e4ff"], "day": 0.8},
	"colony_coral": {"pal": ["ffb0c0", "ffe0a8", "ffffff"], "spark": 10, "motes": 8, "veil": 0.05, "veil_pal": ["ffb0c8", "ffd8a8"], "day": 0.6},
	"colony_ember": {"pal": ["ffb04a", "ff7a3a", "ffe08a"], "spark": 8, "motes": 14, "veil": 0.0, "day": 0.8, "kind": "ember"},
	"colony_ice": {"pal": ["d8f4ff", "ffffff", "a8dcff"], "spark": 14, "motes": 8, "veil": 0.08, "veil_pal": ["a0f0e0", "b0c8ff"], "day": 0.7, "kind": "dust"},
	"colony_kelp": {"pal": ["a8ffd0", "8fe0ff", "ffffff"], "spark": 10, "motes": 10, "veil": 0.05, "veil_pal": ["90f0c8", "8fd8ff"], "day": 0.6},
	"hollow_deeps": {"pal": ["6ff0d8", "b48cff", "8fd0ff"], "spark": 10, "motes": 14, "veil": 0.0, "day": 1.0, "kind": "spore"},
	"hollow_heart": {"pal": ["6ff0d8", "c890ff", "ffffff"], "spark": 12, "motes": 14, "veil": 0.0, "day": 1.0, "kind": "spore", "glint": "crystal"},
	"jungle": {"pal": ["d8ff8a", "a8ffb0"], "spark": 4, "motes": 10, "veil": 0.0, "day": 0.35, "kind": "firefly"},
	"gilt_vaults": {"pal": ["ffe08a", "fff4c8", "ffc850"], "spark": 14, "motes": 4, "veil": 0.0, "day": 1.0, "kind": "dust"},
	"gilt_casino_row": {"pal": ["ffe08a", "ff8ad8", "8ff0ff"], "spark": 10, "motes": 0, "veil": 0.0, "day": 0.8},
	"gilt_grand_plaza": {"pal": ["ffe08a", "fff4c8"], "spark": 8, "motes": 0, "veil": 0.0, "day": 0.8},
	"station": {"pal": ["7fe8ff", "a8ffe0", "ffffff"], "spark": 6, "motes": 6, "veil": 0.06, "veil_pal": ["5fd0ff", "8a7bff"], "day": 0.8, "stars": 16, "kind": "data"},
	"neon": {"pal": ["ff5fd0", "5ff0ff", "ffe07a"], "spark": 8, "motes": 0, "veil": 0.05, "veil_pal": ["ff4fc0", "4fe0ff"], "day": 0.4},
	"bf_neon_block": {"pal": ["ff5fd0", "5ff0ff"], "spark": 6, "motes": 0, "veil": 0.04, "veil_pal": ["ff4fc0", "4fe0ff"], "day": 0.4},
	"bf_station_deck": {"pal": ["7fe8ff", "ffffff"], "spark": 4, "motes": 4, "veil": 0.04, "veil_pal": ["5fd0ff", "8a7bff"], "day": 0.8, "stars": 10, "kind": "data"},
}
## The gangster arc keeps the same life in its magic areas but in its own colours
## (cold neon dust rather than fairy light).
const GANG_PAL := ["5ff0ff", "ff5fd0", "d0d8ff"]
const GANG_VEIL := ["3fd0ff", "b04fff"]

var map: GameMap
var prof: Dictionary
var air := false  # false: the ground sparkles node; true: the veils/motes/glints node
var _sparks: Array = []  # [pos, born, life, col, size, rot]
var _motes: Array = []   # [pos, born, life, col, size, phase, speed]
var _stars: Array = []   # [frac_x, frac_y, phase, period, col]
var _rng := RandomNumberGenerator.new()
var _glint_cells: Array = []
var _anim: Script = null


## Adds the magic layer for `key` (a map id) to `m`; returns the air node, or null when
## the map has no profile. `extra` (regions.json "magic") merges over the profile.
static func attach(m: GameMap, key: String, extra: Dictionary = {}) -> MagicFx:
	if m == null:
		return null
	var p: Dictionary = (PROFILES.get(key, {}) as Dictionary).duplicate()
	p.merge(extra, true)
	if p.is_empty():
		return null
	if not GameState.is_penguins() and not bool(p.get("gang_same", false)) and not key.begins_with("gilt") and not key in ["neon", "bf_neon_block", "station", "bf_station_deck"]:
		p["pal"] = GANG_PAL
		p["veil_pal"] = GANG_VEIL
	var g := MagicFx.new()
	g.name = "MagicGround"
	g.map = m
	g.prof = p
	g.air = false
	m.add_child(g)
	m.to_under(g)
	var a := MagicFx.new()
	a.name = "MagicAir"
	a.map = m
	a.prof = p
	a.air = true
	a.z_index = 40
	m.add_child(a)
	return a


static func reduced() -> bool:
	return Settings.reduced_motion()


## Web and phones draw half as many.
static func lite() -> bool:
	return OS.has_feature("web") or OS.has_feature("mobile")


func _ready() -> void:
	_rng.seed = hash(str(name) + str(map.name if map else ""))
	if ResourceLoader.exists("res://scripts/anim.gd"):
		_anim = load("res://scripts/anim.gd")
	position = Vector2.ZERO if air else position
	if not air and str(prof.get("glint", "")) != "" and map:
		var key := str(prof["glint"])
		for c: Vector2i in map.props:
			var sp: Node = map.props[c]
			if is_instance_valid(sp) and (str(sp.name).to_lower().contains(key) or str(sp.get_meta("art", "")).contains(key)):
				_glint_cells.append(c)
	if air:
		var ns := int(prof.get("stars", 0))
		for i in ns:
			_stars.append([_rng.randf(), _rng.randf() * 0.45, _rng.randf() * TAU, _rng.randf_range(2.0, 4.0), _pick()])


## Game time in seconds (stops while paused).
func now() -> float:
	if _anim != null and _anim.has_method("t"):
		return float(_anim.call("t"))
	return PlayClock.now()


func _pick() -> Color:
	var pal: Array = prof.get("pal", ["ffffff"])
	return Color(str(pal[_rng.randi() % pal.size()]))


## The view in this node's local space.
func view() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2()
	var inv := get_canvas_transform().affine_inverse()
	var r := vp.get_visible_rect()
	var a := inv * r.position
	var b := inv * (r.position + r.size)
	return Rect2(a, b - a).abs()


func count(k: String) -> int:
	var n := int(prof.get(k, 0))
	if lite():
		n = int(ceil(n * 0.5))
	if reduced():
		n = int(ceil(n * 0.6))
	return n


## Night (or a cave) brings the magic out; by day it shows at the profile's "day" level.
func strength() -> float:
	var d := clampf(GameState.darkness(), 0.0, 1.0)
	return lerpf(float(prof.get("day", 0.7)), 1.0, d)


func _process(_delta: float) -> void:
	if map == null or not is_visible_in_tree():
		return
	var t := now()
	var vr := view()
	if vr.size.x <= 0.0:
		return
	if air:
		_tick_motes(t, vr)
	else:
		_tick_sparks(t, vr)
	queue_redraw()


func _tick_sparks(t: float, vr: Rect2) -> void:
	var want := count("spark")
	var i := _sparks.size() - 1
	while i >= 0:
		var s: Array = _sparks[i]
		if t - float(s[1]) > float(s[2]) or not vr.grow(24).has_point(s[0]):
			_sparks.remove_at(i)
		i -= 1
	var tries := 0
	while _sparks.size() < want and tries < 6:
		tries += 1
		var pos := Vector2.ZERO
		if not _glint_cells.is_empty() and _rng.randf() < 0.35:
			var c: Vector2i = _glint_cells[_rng.randi() % _glint_cells.size()]
			pos = to_local(map.to_global(map.cell_center(c))) + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-22, -4))
		else:
			pos = Vector2(_rng.randf_range(vr.position.x, vr.end.x), _rng.randf_range(vr.position.y, vr.end.y))
			var mc: Vector2i = map.world_to_cell(map.to_local(to_global(pos))) if map.has_method("world_to_cell") else Vector2i(-1, -1)
			if map.blocked.has(mc):
				continue
		# Staggered births: a sparkle waits 0.2-2.4 s before it blooms, so they never pop together.
		var delay := _rng.randf_range(0.2, 2.4)
		var life := _rng.randf_range(0.9, 1.7) * (1.8 if reduced() else 1.0)
		_sparks.append([pos.snapped(Vector2(0.5, 0.5)), t + delay, life + 0.0, _pick(), _rng.randf_range(2.5, 4.5), _rng.randf_range(-0.3, 0.3)])


func _tick_motes(t: float, vr: Rect2) -> void:
	var want := count("motes")
	var i := _motes.size() - 1
	while i >= 0:
		var m: Array = _motes[i]
		if t - float(m[1]) > float(m[2]):
			_motes.remove_at(i)
		i -= 1
	while _motes.size() < want:
		var kind := str(prof.get("kind", "wisp"))
		var y0 := _rng.randf_range(vr.position.y + vr.size.y * 0.2, vr.end.y + 8)
		var spd := _rng.randf_range(4.0, 8.0)
		if kind == "ember":
			spd = _rng.randf_range(9.0, 15.0)
		elif kind == "dust":
			spd = -_rng.randf_range(1.5, 3.0)  # moon/frost dust sinks, slowly
			y0 = _rng.randf_range(vr.position.y - 8, vr.end.y - vr.size.y * 0.2)
		elif kind == "firefly":
			spd = _rng.randf_range(-1.5, 1.5)
		if reduced():
			spd *= 0.3
		_motes.append([Vector2(_rng.randf_range(vr.position.x, vr.end.x), y0), t - _rng.randf_range(0.0, 1.5), _rng.randf_range(3.5, 6.5), _pick(), _rng.randf_range(0.6, 1.2), _rng.randf() * TAU, spd])


## Smooth 0..1..0 over a life: eased in, held a breath, eased out (no pops).
static func bloom(u: float) -> float:
	if u <= 0.0 or u >= 1.0:
		return 0.0
	return pow(sin(PI * u), 1.6)


func _draw() -> void:
	var t := now()
	var st := strength()
	var amp := 0.3 if reduced() else 1.0
	if air:
		_draw_air(t, st, amp)
		return
	for s: Array in _sparks:
		var u := (t - float(s[1])) / float(s[2])
		var e := bloom(u)
		if e <= 0.01:
			continue
		var c: Color = s[3]
		var pos: Vector2 = s[0]
		# Reduced motion: a gentle glow that brightens and dims, never a flash.
		var a := e * st * (0.55 if reduced() else 1.0)
		var r := float(s[4]) * (0.55 + 0.45 * e) if not reduced() else float(s[4]) * 0.7
		draw_circle(pos, r * 0.9, Color(c, 0.10 * a))
		draw_circle(pos, r * 0.45, Color(c, 0.22 * a))
		_star(pos, r, float(s[5]) + u * 0.5 * amp, Color(c.lightened(0.35), 0.95 * a))
		draw_circle(pos, 0.6, Color(1, 1, 1, a))


## A crisp four-point star: two thin diamonds, the long one upright, the short one across.
func _star(p: Vector2, r: float, rot: float, c: Color) -> void:
	var w := maxf(0.6, r * 0.18)
	for k in 2:
		var ang := rot + k * PI * 0.5
		var len := r if k == 0 else r * 0.72
		var d := Vector2(cos(ang - PI * 0.5), sin(ang - PI * 0.5))
		var n := Vector2(-d.y, d.x)
		draw_colored_polygon(PackedVector2Array([p + d * len, p + n * w, p - d * len, p - n * w]), c)


func _draw_air(t: float, st: float, amp: float) -> void:
	var vr := view()
	if vr.size.x <= 0.0:
		return
	# Sky veils: two soft ribbons of light ripple across the top of the view, each
	# built from vertical slices whose alpha fades to nothing at both edges.
	var va := float(prof.get("veil", 0.0)) * st
	if va > 0.0:
		var vp: Array = prof.get("veil_pal", ["ffffff", "ffffff"])
		for k in 2:
			var col := Color(str(vp[k % vp.size()]))
			var base_y := vr.position.y + vr.size.y * (0.10 + 0.13 * k)
			var thick := vr.size.y * (0.10 + 0.04 * k)
			var steps := 14
			var top := PackedVector2Array()
			var bot := PackedVector2Array()
			var cols_top := PackedColorArray()
			var cols_bot := PackedColorArray()
			for j in steps + 1:
				var fx := float(j) / steps
				var x := vr.position.x + vr.size.x * fx
				var wave := sin(fx * 5.0 + t * 0.35 * amp + k * 2.1) * 6.0 + sin(fx * 11.0 - t * 0.21 * amp + k) * 3.0
				var shimmer := 0.65 + 0.35 * sin(fx * 9.0 + t * 0.9 * amp + k * 1.3)
				var edge := sin(PI * fx)
				top.append(Vector2(x, base_y + wave))
				bot.append(Vector2(x, base_y + wave + thick * (0.7 + 0.3 * sin(fx * 7.0 + t * 0.5 * amp))))
				cols_top.append(Color(col, va * shimmer * edge))
				cols_bot.append(Color(col, 0.0))
			for j in steps:
				var q := PackedVector2Array([top[j], top[j + 1], bot[j + 1], bot[j]])
				var qc := PackedColorArray([cols_top[j], cols_top[j + 1], cols_bot[j + 1], cols_bot[j]])
				draw_polygon(q, qc)
				# A thin bright crest along the top of the ribbon: the shimmer you notice first.
				draw_line(top[j], top[j + 1], Color(col.lightened(0.4), cols_top[j].a * 0.9), 1.0)
	# High shimmer glints: tiny stars that breathe on their own phases (2-4 s).
	for s: Array in _stars:
		var p := Vector2(vr.position.x + vr.size.x * float(s[0]), vr.position.y + vr.size.y * float(s[1]))
		var b := 0.5 + 0.5 * sin(t * TAU / float(s[3]) + float(s[2]))
		b = lerpf(0.6, b, amp)
		var c: Color = s[4]
		var a := b * st * 0.85
		draw_circle(p, 1.6, Color(c, 0.18 * a))
		if b > 0.75 and not reduced():
			_star(p, 2.2 * b, 0.0, Color(c.lightened(0.3), a))
		else:
			draw_circle(p, 0.6, Color(c, a))
	# Motes: soft dots that drift with a sine sway and fade in and out.
	var kind := str(prof.get("kind", "wisp"))
	for m: Array in _motes:
		var age := t - float(m[1])
		var u := age / float(m[2])
		var e := bloom(u)
		if e <= 0.01:
			continue
		var pos: Vector2 = m[0]
		var sway := sin(age * 1.3 + float(m[5])) * 3.0 * amp
		var p := pos + Vector2(sway, -age * float(m[6]))
		if kind == "firefly":
			p += Vector2(sin(age * 0.7 + float(m[5]) * 2.0) * 6.0, cos(age * 0.9 + float(m[5])) * 4.0) * amp
		if not vr.grow(8).has_point(p):
			continue
		var c: Color = m[3]
		var r := float(m[4])
		var a := e * st * (0.75 if kind != "firefly" else (0.4 + 0.6 * GameState.darkness()))
		if kind == "data":
			# Tech areas: tiny square blips that rise and blink twice, not round fairy light.
			var on := 1.0 if fposmod(age * 2.0 + float(m[5]), 1.0) < 0.7 or reduced() else 0.35
			draw_rect(Rect2(p.snapped(Vector2(0.5, 0.5)), Vector2(1, 1)), Color(c, a * on))
			draw_rect(Rect2(p.snapped(Vector2(0.5, 0.5)) - Vector2(1, 1), Vector2(3, 3)), Color(c, a * on * 0.15))
			continue
		draw_circle(p, r * 2.6, Color(c, 0.08 * a))
		draw_circle(p, r * 1.4, Color(c, 0.22 * a))
		draw_circle(p, r * 0.6, Color(c.lightened(0.5), 0.9 * a))

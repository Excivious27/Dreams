class_name AmbientFx
extends RefCounted
## C14b P2 small ambient-motion helpers for fires, water and interiors.
## random_start: an animated prop starts on a stable pseudo-random frame and runs
## at 0.92..1.08 speed, so neighbours never tick in lockstep (c14b_04-04).
## steam(): a soft rising wisp emitter (kettles, stoves, hot springs, forges).


## Stable 0..1 from a cell or position (same spot = same phase every visit).
static func phase(key: Variant) -> float:
	var v := Vector2.ZERO
	if key is Vector2i:
		v = Vector2(key)
	elif key is Vector2:
		v = key
	elif key is Node2D:
		v = (key as Node2D).position
	return fposmod(sin(v.x * 12.9898 + v.y * 78.233) * 43758.5453, 1.0)


static func random_start(a: AnimatedSprite2D, key: Variant) -> void:
	if a == null or a.sprite_frames == null or not a.sprite_frames.has_animation(a.animation):
		return
	var n := a.sprite_frames.get_frame_count(a.animation)
	if n <= 1:
		return
	var ph := phase(key)
	a.set_frame_and_progress(int(ph * 997.0) % n, fposmod(ph * 7.0, 1.0))
	a.speed_scale = 0.92 + 0.16 * fposmod(ph * 13.0, 1.0)


const STEAM_WORDS := ["kettle", "stove", "bubbling_pot", "cook_pot", "cauldron", "soup_pot", "teapot", "hot_spring"]


static func steams(name: String) -> bool:
	if name.ends_with("_off") or name.ends_with("unlit"):
		return false
	for w: String in STEAM_WORDS:
		if w in name:
			return true
	return false


## Soft white wisps rising from `at` (local to `parent`): `rate` puffs a second.
## Off under reduced motion (returns null). Particles run on process time, so
## they stop with the tree under menus like the rest of the map.
static func steam(parent: Node2D, at: Vector2, rate := 3.0, rise := 10.0, size := 1.0, tint := Color(1, 1, 1, 0.5)) -> CPUParticles2D:
	if Settings.reduced_motion() or parent == null:
		return null
	var p := CPUParticles2D.new()
	p.name = "Steam"
	p.position = at
	p.lifetime = 2.4
	p.amount = maxi(2, int(rate * p.lifetime))
	p.preprocess = 2.4
	p.randomness = 0.6
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 2.0 * size
	p.direction = Vector2(0, -1)
	p.spread = 12.0
	p.gravity = Vector2(1.5, -rise * 0.4)
	p.initial_velocity_min = rise * 0.6
	p.initial_velocity_max = rise
	p.damping_min = 2.0
	p.damping_max = 4.0
	var gt := GradientTexture2D.new()
	gt.width = 16
	gt.height = 16
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var dg := Gradient.new()
	dg.set_color(0, Color(1, 1, 1, 1))
	dg.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = dg
	p.texture = gt
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.35))
	sc.add_point(Vector2(1, 1.0))
	p.scale_amount_curve = sc
	p.scale_amount_min = 0.45 * size
	p.scale_amount_max = 0.7 * size
	var g := Gradient.new()
	g.set_color(0, Color(tint.r, tint.g, tint.b, 0.0))
	g.add_point(0.2, tint)
	g.set_color(g.get_point_count() - 1, Color(tint.r, tint.g, tint.b, 0.0))
	p.color_ramp = g
	parent.add_child(p)
	return p


## Lake shore buildings drawn as 4 separate renders (c14b_13-02, 13-03): the
## lighthouse holds its lit frame with a code beam (LighthouseBeam); the water
## mill holds frame 0 (its house, roof and lantern jumped 2-4 px a frame) with
## its wheel turned in code when a wheel sprite exists (MillWheel).
static func shore_building(a: AnimatedSprite2D, name: String) -> void:
	if a == null:
		return
	if name == "lighthouse":
		LighthouseBeam.fit(a)
	elif "water_mill" in name:
		a.stop()
		a.frame = 0

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
		# life without re-drawn frames: chimney smoke and spray where the wheel meets the race
		var tl := a.offset - Vector2(163, 200) / 2.0
		steam(a, tl + Vector2(115, 18), 2.0, 14.0, 1.8, Color(0.92, 0.92, 0.95, 0.42))
		splash(a, tl + Vector2(84, 178))


## Water spray: pale droplets hopping up and falling back (wheel foot, weirs).
static func splash(parent: Node2D, at: Vector2, n := 10) -> CPUParticles2D:
	if Settings.reduced_motion() or parent == null:
		return null
	var d := CPUParticles2D.new()
	d.name = "Splash"
	d.position = at
	d.amount = n
	d.lifetime = 0.6
	d.preprocess = 0.6
	d.randomness = 0.5
	d.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	d.emission_rect_extents = Vector2(8, 2)
	d.direction = Vector2(0.3, -1)
	d.spread = 40.0
	d.initial_velocity_min = 20.0
	d.initial_velocity_max = 40.0
	d.gravity = Vector2(0, 200)
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	d.texture = ImageTexture.create_from_image(img)
	d.scale_amount_min = 0.6
	d.scale_amount_max = 1.0
	var g := Gradient.new()
	g.set_color(0, Color(0.9, 0.97, 1.0, 0.9))
	g.set_color(1, Color(0.75, 0.9, 1.0, 0.0))
	d.color_ramp = g
	parent.add_child(d)
	return d


## Casino and arcade lights (c14b_04-17): slot machines, marquees, signs,
## jukeboxes and arcade cabinets hum: a soft per-prop brightness pulse (never in
## step), a little faster on marquees. Off under reduced motion. One tween each.
const HUM_WORDS := ["casino_slot", "casino_marquee", "casino_ace_sign", "jukebox", "arcade_cab", "neon_sign", "slot_machine"]


static func hums(name: String) -> bool:
	for w: String in HUM_WORDS:
		if w in name:
			return true
	return false


static func hum(ci: CanvasItem, name := "") -> Tween:
	if ci == null or Settings.reduced_motion() or not ci.is_inside_tree():
		return null
	var ph := phase(ci.position if ci is Node2D else Vector2.ZERO)
	var period := (0.9 if "marquee" in name or "sign" in name else 1.8) * (0.85 + 0.3 * ph)
	var hi := Color(1.1, 1.07, 1.0)
	var tw := ci.create_tween().set_loops()
	tw.tween_property(ci, "modulate", hi, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(ci, "modulate", Color.WHITE, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw

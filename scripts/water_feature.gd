class_name WaterFeature
extends Node2D
## C14b P2: smooth, seamless fountains (Tom 2026-11-21: the Town Hall fountain
## was "choppy and jumbled"). The old strips (props/fountain2, gold_fountain)
## are a "turning on" sequence of 4 separately drawn renders: looping them made
## the whole fountain re-draw and pop back to dry every 0.8 s. Now ONE frame
## (the best full-flow drawing) is drawn still and only its water moves, in
## shaders/water_flow.gdshader (streaks sliding down the falling sheets, ripples
## and glints in the pools) plus a few splash droplets where the streams land.
## Game time (PlayClock), random phase per fountain, reduced motion = 30 % and
## no droplets. Place with WaterFeature.place(map, group, name, cell, extra_w).

const LOOP := 600.0  # t wraps here; every shader frequency is k/LOOP Hz (seamless)

## Per strip: the still frame to show, the water zones (local 0..1) and the
## splash points where streams hit the basin.
const LOOKS := {
	"fountain2": {"frame": 2, "fall_top": 0.26, "fall_bottom": 0.55, "basin": Vector2(0.5, 0.63),
		"bowl": Vector2(0.5, 0.18), "splash": [Vector2(0.23, 0.57), Vector2(0.42, 0.6), Vector2(0.62, 0.6), Vector2(0.74, 0.56)]},
	"gold_fountain": {"frame": 3, "fall_top": 0.08, "fall_bottom": 0.5, "basin": Vector2(0.5, 0.68),
		"bowl": Vector2(0.5, 0.05), "splash": [Vector2(0.36, 0.55), Vector2(0.5, 0.5), Vector2(0.64, 0.55)]},
	# pools: no falling water (fall zone empty), ripples from the centre (c14b_01-04)
	"hot_spring": {"frame": 0, "fall_top": 0.0, "fall_bottom": 0.0, "basin": Vector2(0.5, 0.52), "bowl": Vector2(0.5, 0.52),
		"splash": [], "steam": Vector2(0.5, 0.45)},
	"glow_pond": {"frame": 0, "fall_top": 0.0, "fall_bottom": 0.0, "basin": Vector2(0.5, 0.5), "bowl": Vector2(0.5, 0.5), "splash": []},
	"tide_pool": {"frame": 1, "fall_top": 0.0, "fall_bottom": 0.0, "basin": Vector2(0.5, 0.5), "bowl": Vector2(0.5, 0.5), "splash": []},
	"glow_pool_moon": {"frame": 0, "fall_top": 0.0, "fall_bottom": 0.0, "basin": Vector2(0.5, 0.5), "bowl": Vector2(0.5, 0.5), "splash": []},
	"waterfall_pool": {"frame": 1, "fall_top": 0.12, "fall_bottom": 0.8, "basin": Vector2(0.5, 0.9), "bowl": Vector2(0.5, 0.9),
		"splash": [Vector2(0.44, 0.8), Vector2(0.52, 0.82), Vector2(0.6, 0.8)]},
}

static var _shader: Shader
var _mat: ShaderMaterial
var _phase := 0.0
var _drops: CPUParticles2D
var _look := ""
var _size := Vector2.ONE


static func has_look(name: String) -> bool:
	return LOOKS.has(name)


## A fountain placed like GameMap.prop() (feet at the bottom-centre of `c`):
## the prop sprite shows the still frame with the water shader, and a
## WaterFeature child drives game time and the droplets. Returns the sprite.
static func place(m: Node, group: String, name: String, c: Vector2i, extra_w := 0, solid := false, scale := 0.5) -> Sprite2D:
	return attach(m.prop(group, name, c, extra_w, 0.0, solid, scale), group, name)


## A still prop sprite of a water strip (GameMap.prop() hook): show the look's
## frame with flowing water. Idempotent; null-safe. Returns `s`.
static func attach(s: Sprite2D, group: String, name: String) -> Sprite2D:
	if s == null or s.has_meta("water_look") or not LOOKS.has(name) or not (s.texture is AtlasTexture):
		return s
	var w := WaterFeature.new()
	w.name = "WaterFeature"
	w.setup(group, name, s)
	s.add_child(w)
	return s


## An AnimatedSprite2D already placed by a map (the old looping strip): hold it
## on the look's still frame and give it the flowing-water shader. One-line hook
## after the map's own a.play(). Returns `a` (null-safe).
static func still(a: AnimatedSprite2D, name: String) -> AnimatedSprite2D:
	if a == null or a.has_meta("water_look") or not LOOKS.has(name) or a.sprite_frames == null or not a.sprite_frames.has_animation(a.animation):
		return a
	var n := a.sprite_frames.get_frame_count(a.animation)
	var fr := clampi(int(LOOKS[name]["frame"]), 0, n - 1)
	a.stop()
	a.frame = fr
	var ft := a.sprite_frames.get_frame_texture(a.animation, fr)
	if not (ft is AtlasTexture):
		return a
	var at := ft as AtlasTexture
	var w := WaterFeature.new()
	w.name = "WaterFeature"
	w._make_mat(name, at.atlas, at.region)
	a.material = w._mat
	a.set_meta("water_look", name)
	a.set_meta("water_frame", fr)
	a.add_child(w)
	return a


func _make_mat(name: String, tex: Texture2D, reg: Rect2) -> void:
	var look: Dictionary = LOOKS[name]
	if _shader == null:
		_shader = load("res://shaders/water_flow.gdshader")
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	var ts := tex.get_size()
	_mat.set_shader_parameter("cell", Vector4(reg.position.x / ts.x, reg.position.y / ts.y, reg.size.x / ts.x, reg.size.y / ts.y))
	for k in ["fall_top", "fall_bottom", "basin", "bowl"]:
		_mat.set_shader_parameter(k, look[k])
	_look = name
	_size = reg.size


func setup(group: String, name: String, s: Sprite2D) -> void:
	var look: Dictionary = LOOKS[name]
	var info := Art.info(group, name)
	var frames := maxi(int(info.get("frames", 1)), 1)
	var at := s.texture as AtlasTexture
	var tex: Texture2D = at.atlas
	var cw := float(info.get("cell_w", tex.get_width() / frames))
	var chh := float(tex.get_height())
	var fr := clampi(int(look["frame"]), 0, frames - 1)
	var at2 := AtlasTexture.new()  # never edit the shared AtlasTexture of another prop
	at2.atlas = tex
	at2.region = Rect2(cw * fr, 0, cw, chh)
	s.texture = at2
	_make_mat(name, tex, at2.region)
	s.material = _mat
	s.set_meta("water_look", name)
	s.set_meta("water_frame", fr)


## A spot on the still frame (local 0..1) in this node's space (the parent
## sprite is centred on its offset).
func _at(v: Vector2) -> Vector2:
	var po: Vector2 = get_parent().get("offset") if get_parent().get("offset") is Vector2 else Vector2(0, -_size.y / 2.0)
	return po + (v - Vector2(0.5, 0.5)) * _size


func _ready() -> void:
	_phase = fposmod(sin(global_position.x * 12.9898 + global_position.y * 78.233) * 43758.5453, 1.0)
	_mat.set_shader_parameter("phase", _phase)
	_mat.set_shader_parameter("amp", 0.3 if Settings.reduced_motion() else 1.0)
	if not Settings.reduced_motion():
		if not (LOOKS[_look]["splash"] as Array).is_empty():
			_add_drops()
		if LOOKS[_look].has("steam"):
			var sp: Vector2 = LOOKS[_look]["steam"]
			AmbientFx.steam(self, _at(sp), 3.5, 18.0, 1.6, Color(1, 1, 1, 0.38))
	_process(0.0)


func _process(_d: float) -> void:
	if _mat:
		_mat.set_shader_parameter("t", fmod(PlayClock.now(), LOOP))


## Splash droplets where the streams land: tiny pale-blue dots that hop up and
## fall back, spread over the splash points so it never pulses in step.
func _add_drops() -> void:
	var look: Dictionary = LOOKS[_look]
	var pts: Array = look["splash"]
	var r := _size
	var em := PackedVector2Array()
	for p in pts:
		var v: Vector2 = p
		em.append(_at(v))
	var d := CPUParticles2D.new()
	d.name = "Drops"
	d.amount = 4 * pts.size()
	d.lifetime = 0.55
	d.preprocess = 0.6
	d.randomness = 0.5
	d.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	d.emission_points = em
	d.direction = Vector2(0, -1)
	d.spread = 55.0
	d.initial_velocity_min = 22.0
	d.initial_velocity_max = 46.0
	d.gravity = Vector2(0, 240)
	var gt := GradientTexture2D.new()  # a soft 6 px dot (drawn ~1.5 px at map scale)
	gt.width = 6
	gt.height = 6
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var dg := Gradient.new()
	dg.set_color(0, Color(1, 1, 1, 1))
	dg.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = dg
	d.texture = gt
	d.scale_amount_min = 0.5
	d.scale_amount_max = 0.8
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.95, 1.0, 0.9))
	g.set_color(1, Color(0.7, 0.88, 1.0, 0.0))
	d.color_ramp = g
	d.seed = int(_phase * 100000.0)
	d.use_fixed_seed = false
	add_child(d)
	_drops = d

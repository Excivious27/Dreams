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
	var s: Sprite2D = m.prop(group, name, c, extra_w, 0.0, solid, scale)
	if s == null or not LOOKS.has(name) or not (s.texture is AtlasTexture):
		return s
	var w := WaterFeature.new()
	w.name = "WaterFeature"
	w.setup(group, name, s)
	s.add_child(w)
	return s


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
	if _shader == null:
		_shader = load("res://shaders/water_flow.gdshader")
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	var tw := float(tex.get_width())
	_mat.set_shader_parameter("cell", Vector4(cw * fr / tw, 0.0, cw / tw, 1.0))
	for k in ["fall_top", "fall_bottom", "basin", "bowl"]:
		_mat.set_shader_parameter(k, look[k])
	s.material = _mat
	_look = name
	_size = Vector2(cw, chh)
	s.set_meta("water_look", name)
	s.set_meta("water_frame", fr)


func _ready() -> void:
	_phase = fposmod(sin(global_position.x * 12.9898 + global_position.y * 78.233) * 43758.5453, 1.0)
	_mat.set_shader_parameter("phase", _phase)
	_mat.set_shader_parameter("amp", 0.3 if Settings.reduced_motion() else 1.0)
	if not Settings.reduced_motion():
		_add_drops()
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
		em.append(Vector2((v.x - 0.5) * r.x, v.y * r.y - r.y))
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

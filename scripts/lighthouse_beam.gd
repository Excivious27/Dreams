class_name LighthouseBeam
extends Node2D
## C14b P2 (c14b_13-02): the lit lighthouse no longer pops between 4 drawn beam
## poses (left / none / right / dim) at 4 fps, and no longer burns at noon. The
## tower holds its lit-lens frame (1) and this node draws a soft additive cone
## that turns smoothly around the lamp: its reach is cos(angle), so it sweeps
## out to one side, shortens as it faces you, and swings to the other side.
## Strength follows darkness (0 by day, a touch more in fog/storm). Game time;
## reduced motion holds the beam still on one side.

const LAMP := Vector2(0.5, 0.17)   # lamp centre in the lighthouse frame (local 0..1)
const SPEED := 0.9                 # rad/s
const REACH := 120.0               # beam length in texture px
var lamp := Vector2.ZERO
var _acc := 1.0


## Turn a placed lit-lighthouse AnimatedSprite2D into a still tower + beam.
static func fit(a: AnimatedSprite2D) -> LighthouseBeam:
	if a == null or a.sprite_frames == null or not a.sprite_frames.has_animation(a.animation):
		return null
	if a.get_node_or_null("Beam") != null:
		return a.get_node("Beam")
	var n := a.sprite_frames.get_frame_count(a.animation)
	a.stop()
	a.frame = 1 if n > 1 else 0  # lit lens, no beam drawn in
	var ft := a.sprite_frames.get_frame_texture(a.animation, a.frame)
	var sz := ft.get_size() if ft else Vector2(148, 224)
	var b := LighthouseBeam.new()
	b.name = "Beam"
	b.lamp = a.offset - sz / 2.0 + LAMP * sz
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	b.material = m
	b.z_index = 1
	a.add_child(b)
	return b


static func strength() -> float:
	var d := GameState.darkness() if not GameState.run.is_empty() else 0.0
	var w := GameState.weather_today() if not GameState.run.is_empty() else ""
	if w in ["fog", "storm", "rain"]:
		d = maxf(d, 0.35)
	return clampf(d, 0.0, 1.0)


func _process(d: float) -> void:
	_acc += d
	if _acc >= 1.0 / 30.0:
		_acc = 0.0
		queue_redraw()


## Reach factor (-1..1, sign = side) and brightness of the beam at game time t.
static func sweep(t: float, reduced: bool) -> Vector2:
	var c := 0.85 if reduced else cos(t * SPEED)
	return Vector2(c, 0.45 + 0.55 * absf(c))


func _draw() -> void:
	var s := strength()
	if s < 0.03:
		return
	var sw := sweep(PlayClock.now(), Settings.reduced_motion())
	var reach := REACH * sw.x
	var a := s * sw.y
	var core := Color(1.0, 0.92, 0.65, 0.5 * a)
	var tip := Color(1.0, 0.9, 0.6, 0.0)
	var half := 5.0 + 22.0 * absf(sw.x)
	var end := lamp + Vector2(reach, 0)
	if absf(reach) > 2.0:  # facing you the cone is a point: only the core shows
		draw_polygon(PackedVector2Array([lamp + Vector2(0, -3), end + Vector2(0, -half), end + Vector2(0, half), lamp + Vector2(0, 3)]),
			PackedColorArray([core, tip, tip, core]))
	# a soft bright core on the lens, strongest when the beam faces you
	draw_circle(lamp, 6.0, Color(1.0, 0.95, 0.75, 0.35 * s * (1.2 - absf(sw.x))))

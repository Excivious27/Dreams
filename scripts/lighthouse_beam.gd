class_name LighthouseBeam
extends Node2D
## C14b P3 (c14b_13-01, 14-11, 04-12): a smooth turning lighthouse beam instead of
## the 4-frame strip that strobed left / none / right / off. The tower is drawn as
## its lit-lamp still; this node, placed at the lamp, draws two soft additive cones
## whose width follows cos(t) so the beam reads as sweeping round the lamp. Bright
## at dusk, night and in fog, faint by day; never fully off. Game time (PlayClock).
## Reduced motion: a steady soft glow, no sweep.

const PERIOD := 6.5  # seconds per full turn
var length := 70.0   # art px (the node inherits the tower sprite's scale)
var half_w := 9.0


## Add a beam to a lighthouse sprite. `lamp` is the lamp centre in the sprite's
## local (art) pixels.
static func attach(tower: Node2D, lamp: Vector2) -> LighthouseBeam:
	if tower == null:
		return null
	var b := LighthouseBeam.new()
	b.name = "Beam"
	b.position = lamp
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	b.material = mat
	tower.add_child(b)
	return b


## The lit-lamp, no-beam frame of the lighthouse strip (frame 1) as a texture.
static func lit_frame(name := "lighthouse") -> Texture2D:
	var info := Art.info("buildings", name)
	var fr := int(info.get("frames", 1))
	var t := Art.tex("buildings", name)
	if fr <= 1 or t == null:
		return t
	var at := AtlasTexture.new()
	at.atlas = t
	var fw := float(info.get("cell_w", t.get_width() / fr))
	at.region = Rect2(fw * mini(1, fr - 1), 0, fw, float(info.get("cell_h", t.get_height())))
	return at


static func strength() -> float:
	var d := GameState.darkness()
	var w := GameState.weather_today() if GameState.run.has("day") else "clear"
	var s := 0.12 + 0.88 * d
	if w in ["fog", "storm", "rain", "blizzard"]:
		s = maxf(s, 0.6)
	return clampf(s, 0.12, 1.0)


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var s := strength()
	var glow := Color(1.0, 0.93, 0.62, 0.35 * s)
	draw_circle(Vector2.ZERO, 7.0, glow)
	draw_circle(Vector2.ZERO, 4.0, Color(1, 0.97, 0.8, 0.45 * s))
	if AmbientMotion.reduced():
		return
	var a := PlayClock.now() * TAU / PERIOD
	var c := cos(a)
	# Two opposite cones; the one facing "away" (sin < 0) is dimmer, like the far side.
	for side in [1.0, -1.0]:
		var reach: float = length * c * side
		if absf(reach) < 2.0:
			continue
		var facing: float = 0.55 + 0.45 * sin(a) * side
		var col := Color(1.0, 0.92, 0.6, 0.5 * s * facing)
		var tip := Color(1.0, 0.92, 0.6, 0.0)
		var hw := half_w * (0.6 + 0.4 * absf(c))
		draw_polygon(PackedVector2Array([Vector2(0, -2.5), Vector2(reach, -hw), Vector2(reach, hw), Vector2(0, 2.5)]),
			PackedColorArray([col, tip, tip, col]))

class_name HeldSwing
extends Node2D
## The held tool or weapon, drawn swinging over a hero whose frames don't show
## it (the gangster outfits punch with empty hands; a few have no tool poses).
## Spawned by Player.play_tool / Player._swing / Player._fire; frees itself.
##   kind: "chop" (pickaxe, axe, hoe: overhead and down), "sweep" (sword, club:
##   an arc across the front), "pour" (watering can), "aim" (a gun, held out).

var tex: Texture2D
var kind := "chop"
var dur := 0.4
var face := "right"
var _t := 0.0
var _spr: Sprite2D


static func spawn(p: Node2D, item_id: String, kind_: String, dur_: float, facing: String) -> HeldSwing:
	if p == null or item_id == "":
		return null
	var t := Art.tex("items", Hud.icon_for(item_id))
	if t == null:
		return null
	for c in p.get_children():
		if c is HeldSwing:
			c.queue_free()
	var h := HeldSwing.new()
	h.tex = t
	h.kind = kind_
	h.dur = maxf(0.08, dur_)
	h.face = facing
	h.name = "HeldSwing"
	p.add_child(h)
	return h


func _ready() -> void:
	_spr = Sprite2D.new()
	_spr.texture = tex
	_spr.centered = false
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var s := (15.0 if kind == "sweep" else 12.0) / maxf(1.0, maxf(tex.get_width(), tex.get_height()))
	if kind == "aim":
		s = 10.0 / maxf(1.0, maxf(tex.get_width(), tex.get_height()))
	_spr.scale = Vector2(s, s)
	# Item icons lie on the diagonal, handle bottom-left: pivot on the handle.
	_spr.offset = Vector2(-tex.get_width() * 0.12, -tex.get_height() * 0.88)
	if kind == "aim":
		_spr.offset = Vector2(-tex.get_width() * 0.2, -tex.get_height() * 0.6)
	add_child(_spr)
	# Hand height, in front of the body except when facing away.
	position = {"right": Vector2(3, -10), "left": Vector2(-3, -10), "down": Vector2(3, -9), "up": Vector2(-2, -12)}.get(face, Vector2(0, -10))
	scale.x = -1.0 if face == "left" else 1.0
	z_index = -1 if face == "up" else 1
	z_as_relative = true
	_pose(0.0)


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / dur, 0.0, 1.0)
	_pose(k)
	if _t >= dur + 0.06:
		queue_free()


## The pointing angle (screen degrees, 0 = right, -90 = up) at k in 0..1.
func _angle(k: float) -> float:
	var e := k * k * (3.0 - 2.0 * k)
	match kind:
		"chop":
			# Wind up over the shoulder for the first 35%, then a fast strike.
			var w := clampf(k / 0.35, 0.0, 1.0)
			var s := clampf((k - 0.35) / 0.4, 0.0, 1.0)
			s = s * s
			match face:
				"down":
					return lerpf(lerpf(-60.0, -110.0, w), 80.0, s)
				"up":
					return lerpf(lerpf(-60.0, -20.0, w), -160.0, s)
				_:
					return lerpf(lerpf(-70.0, -135.0, w), 35.0, s)
		"sweep":
			match face:
				"down":
					return lerpf(170.0, 10.0, e)
				"up":
					return lerpf(190.0, 350.0, e)
				_:
					return lerpf(-115.0, 70.0, e)
		"pour":
			return lerpf(-45.0, 10.0, minf(1.0, k * 2.0)) + (90.0 if face == "down" else 0.0)
		"aim":
			return {"down": 90.0, "up": -90.0}.get(face, 0.0)
	return 0.0


func _pose(k: float) -> void:
	if _spr == null:
		return
	var a := _angle(k)
	# The icon itself points up-right (-45°) for tools; guns point right.
	_spr.rotation_degrees = a + (0.0 if kind == "aim" else 45.0)
	modulate.a = 1.0 if k < 1.0 else maxf(0.0, 1.0 - (_t - dur) / 0.06)

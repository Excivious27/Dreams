class_name MineLife
extends Node2D
## C14b P2 (c14b_04-18): the mines breathe. Water drips from some stalactites
## (a drop gathers, falls and splashes in a tiny ring, each tip on its own
## 3-7 s beat), and dust motes drift slowly through every lamp's light. Lamp
## flames flicker through NightGlow ("fire" kind for mine lamps). Game time
## (PlayClock), only on-screen drips drawn; reduced motion: no motes, drips
## stay (slow and calm).

const FALL := 15.0       # px a drop falls before it splashes
var drips: Array = []    # [tip Vector2 (local), period s, phase s]


static func attach(m: GameMap) -> MineLife:
	var ml := MineLife.new()
	ml.name = "MineLife"
	m.add_child(ml)
	ml.z_index = 2
	var k := 0
	for n in m.get_children():
		if n is Sprite2D and (n as Sprite2D).texture and ("stalag" in (n as Sprite2D).texture.resource_path):
			k += 1
			if k % 2 == 0:
				continue  # every other one drips: a few, not a rainstorm
			var s := n as Sprite2D
			var ph := AmbientFx.phase(s.position)
			var top := s.position.y + (s.offset.y - s.texture.get_height() / 2.0) * s.scale.y
			ml.drips.append([Vector2(s.position.x, top + 2.0 - FALL), 3.0 + ph * 4.0, ph * 7.0])
	if not Settings.reduced_motion() and m.glow != null:
		for l: Array in m.glow.lights:
			if is_instance_valid(l[0]) and l[0] is Node2D and NightGlow.kind_for(NightGlow.art_name(l[0])) == "fire":
				ml._motes(l[0] as Node2D, float(l[2]))
	return ml


## A few slow, faint specks drifting in a lamp's light.
func _motes(lamp: Node2D, lift: float) -> void:
	var p := CPUParticles2D.new()
	p.name = "Motes"
	p.amount = 6
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.randomness = 0.7
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 14.0
	p.direction = Vector2(1, -0.3)
	p.spread = 180.0
	p.gravity = Vector2(0, -0.6)
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.5
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.7, 0.0))
	g.add_point(0.5, Color(1.0, 0.9, 0.7, 0.55))
	g.set_color(g.get_point_count() - 1, Color(1.0, 0.9, 0.7, 0.0))
	p.color_ramp = g
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p.texture = ImageTexture.create_from_image(img)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 0.6
	p.position = lamp.position + Vector2(0, -lift)
	p.z_index = 3
	add_child(p)


func _process(_d: float) -> void:
	if not drips.is_empty():
		queue_redraw()


func _draw() -> void:
	var t := PlayClock.now()
	var xf := get_viewport().get_canvas_transform() * get_global_transform()
	var view := xf.affine_inverse() * get_viewport_rect()
	view = view.grow(24.0)
	for d: Array in drips:
		var tip: Vector2 = d[0]
		if not view.has_point(tip):
			continue
		var per: float = d[1]
		var u := fposmod(t + float(d[2]), per)
		var col := Color(0.72, 0.86, 1.0, 0.85)
		if u < 1.2:
			pass  # the drop gathers in the dark above
		elif u < 1.5:  # falls (accelerating)
			var f := (u - 1.2) / 0.3
			var y := FALL * f * f
			draw_line(tip + Vector2(0, y - 1.5), tip + Vector2(0, y), col, 1.0)
		elif u < 2.1:  # splash ring spreading and fading
			var s := (u - 1.5) / 0.6
			draw_set_transform(tip + Vector2(0, FALL), 0.0, Vector2(1.0, 0.45))  # a flat ring on the floor
			draw_arc(Vector2.ZERO, 1.0 + s * 4.0, 0.0, TAU, 12, Color(col.r, col.g, col.b, 0.6 * (1.0 - s)), 0.8)
			draw_set_transform(Vector2.ZERO)

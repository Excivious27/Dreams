class_name NightGlow
extends CanvasLayer
## Soft warm light around lamps, lanterns, torches and lit windows after dark.
## It sits above the map's CanvasModulate so the glow isn't darkened with it.

var map: GameMap
var lights: Array = []   # [Node2D, radius]
var _tex: Texture2D
var _canvas: Node2D


func _ready() -> void:
	layer = 1
	follow_viewport_enabled = true
	_canvas = Node2D.new()
	add_child(_canvas)
	_canvas.draw.connect(_draw_glow)
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.55, 0.55))
	g.set_color(1, Color(1.0, 0.75, 0.4, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	_tex = gt
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_canvas.material = mat


var _was_on := false


func _process(_d: float) -> void:
	var on := map != null and map.has_sky and GameState.darkness() * Settings.night_strength() > 0.05
	if on or _was_on:
		_canvas.queue_redraw()
	_was_on = on


func _draw_glow() -> void:
	if map == null or not map.has_sky:
		return
	var a := GameState.darkness() * Settings.night_strength()
	if a < 0.05:
		return
	var tm := Time.get_ticks_msec() / 1000.0
	var cam := map.get_viewport().get_camera_2d()
	var cc := cam.get_screen_center_position() if cam else Vector2.ZERO
	for l: Array in lights:
		var n := l[0] as Node2D
		if not is_instance_valid(n) or not n.visible:
			continue
		if cam and n.global_position.distance_to(cc) > 320.0:
			continue
		var r := float(l[1]) * (1.0 + 0.04 * sin(tm * 3.0 + n.position.x))
		var p := n.global_position + Vector2(0, -float(l[2]))
		_canvas.draw_texture_rect(_tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, a))

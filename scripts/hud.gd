class_name Hud
extends CanvasLayer
## Top bar: day/clock, crystals, hearts, energy, selected item. Also toasts
## ("+3 Turnip", "Farming level 2!") and the fade used for scene changes/sleep.

var _top: Label
var _right: Label
var _bars: Control
var _toasts: VBoxContainer
var _fade: ColorRect
var _hint: Label


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_top = _mk_label(Vector2(6, 3), Vector2(180, 24), HORIZONTAL_ALIGNMENT_LEFT)
	_right = _mk_label(Vector2(150, 3), Vector2(114, 24), HORIZONTAL_ALIGNMENT_RIGHT)
	_bars = Control.new()
	_bars.position = Vector2(6, 25)
	_bars.draw.connect(_draw_bars)
	add_child(_bars)
	_hint = _mk_label(Vector2(6, 40), Vector2(258, 14), HORIZONTAL_ALIGNMENT_LEFT)
	_hint.modulate = Color(1, 1, 1, 0.85)
	_toasts = VBoxContainer.new()
	_toasts.position = Vector2(6, 58)
	_toasts.size = Vector2(258, 100)
	_toasts.add_theme_constant_override("separation", 1)
	add_child(_toasts)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func _mk_label(pos: Vector2, size: Vector2, align: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(l)
	return l


func set_hint(text: String) -> void:
	_hint.text = text


func _process(_delta: float) -> void:
	if GameState.run.is_empty():
		return
	var r := GameState.run
	_top.text = "Day %d  %s" % [int(r["day"]), GameState.clock_text()]
	var sel := str(r["selected"])
	var sel_text := ""
	if sel != "":
		sel_text = "  [%s x%d]" % [GameState.item_name(sel), GameState.count(sel)]
	_right.text = "◆ %d%s" % [int(r["crystals"]), sel_text]
	_bars.queue_redraw()


func _draw_bars() -> void:
	var r := GameState.run
	if r.is_empty():
		return
	var hp := int(r["hp"])
	var max_hp := int(r["max_hp"])
	for i in max_hp:
		var p := Vector2(i * 9 + 4, 4)
		var col := Color("e8484a") if i < hp else Color(0, 0, 0, 0.4)
		_bars.draw_circle(p + Vector2(-2, -1), 2.2, col)
		_bars.draw_circle(p + Vector2(2, -1), 2.2, col)
		_bars.draw_colored_polygon(PackedVector2Array([p + Vector2(-4, 0), p + Vector2(4, 0), p + Vector2(0, 4)]), col)
	var e := float(r["energy"]) / float(r["max_energy"])
	var bx := max_hp * 9 + 10
	_bars.draw_rect(Rect2(bx, 1, 50, 6), Color(0, 0, 0, 0.5))
	_bars.draw_rect(Rect2(bx + 1, 2, 48 * e, 4), Color("f2c84b") if e > 0.25 else Color("e86a3a"))


func toast(text: String, color := Color.WHITE) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_color_override("font_color", color)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_toasts.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func fade_out(seconds := 0.4) -> void:
	var tw := _fade.create_tween()
	tw.tween_property(_fade, "color:a", 1.0, seconds)
	await tw.finished


func fade_in(seconds := 0.4) -> void:
	var tw := _fade.create_tween()
	tw.tween_property(_fade, "color:a", 0.0, seconds)
	await tw.finished


func set_night(amount: float) -> void:
	# Tint for evening: a separate soft overlay under the fade.
	pass

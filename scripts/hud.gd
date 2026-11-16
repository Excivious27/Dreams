class_name Hud
extends CanvasLayer
## Stardew-style HUD for a portrait phone: hearts top-left, clock box top-right,
## a 12-slot toolbar under them, a vertical energy bar on the right, toasts, and
## the fade used for scene changes and sleep.

const TOOLBAR_Y := 34.0
const SLOT := 20.0
const TOOLBAR_X := 15.0
const TOOLBAR_BOTTOM := 70.0

var _canvas: Control
var _toasts: VBoxContainer
var _fade: ColorRect
var _hint := ""
var _font: Font


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = ThemeDB.fallback_font
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)
	_toasts = VBoxContainer.new()
	_toasts.position = Vector2(6, 76)
	_toasts.size = Vector2(258, 100)
	_toasts.add_theme_constant_override("separation", 1)
	add_child(_toasts)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func set_hint(text: String) -> void:
	_hint = text


func _process(_delta: float) -> void:
	if GameState.run.is_empty():
		return
	# Keyboard: number keys pick a toolbar slot (1-9, 0, -, =).
	for i in 12:
		if Input.is_action_just_pressed("slot_%d" % (i + 1)):
			GameState.select_slot(i)
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if GameState.run.is_empty():
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		var p: Vector2 = (event as InputEventScreenTouch).position
		if p.y >= TOOLBAR_Y - 2 and p.y <= TOOLBAR_Y + SLOT + 2 and p.x >= TOOLBAR_X and p.x < TOOLBAR_X + 12 * SLOT:
			GameState.select_slot(int((p.x - TOOLBAR_X) / SLOT))
			Music.instance(get_tree()).sfx("plant")
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			GameState.select_slot((int(GameState.run["slot"]) + 1) % 12)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			GameState.select_slot((int(GameState.run["slot"]) + 11) % 12)


func _draw_hud() -> void:
	var r := GameState.run
	if r.is_empty():
		return
	var c := _canvas
	# Hearts
	var hp := int(r["hp"])
	var max_hp := int(r["max_hp"])
	var heart_full := Art.tex("ui", "heart_full")
	var heart_empty := Art.tex("ui", "heart_empty")
	for i in max_hp:
		var p := Vector2(6 + i * 11, 4)
		if heart_full and heart_empty:
			c.draw_texture_rect(heart_full if i < hp else heart_empty, Rect2(p, Vector2(10, 10)), false)
		else:
			c.draw_circle(p + Vector2(5, 5), 4.0, Color("e8484a") if i < hp else Color(0, 0, 0, 0.4))
	# Clock box (top right)
	var box := Rect2(166, 2, 100, 28)
	_panel(c, "panel_parchment", box)
	var dark := Color(0.25, 0.15, 0.05)
	c.draw_string(_font, Vector2(box.position.x + 6, box.position.y + 11), "Day %d" % int(r["day"]), HORIZONTAL_ALIGNMENT_LEFT, 50, 8, dark)
	c.draw_string(_font, Vector2(box.position.x + 6, box.position.y + 22), GameState.clock_text(), HORIZONTAL_ALIGNMENT_LEFT, 60, 8, dark)
	var crystal := Art.tex("ui", "crystal")
	var cx := box.end.x - 6
	var ctext := str(int(r["crystals"]))
	var tw := _font.get_string_size(ctext, HORIZONTAL_ALIGNMENT_RIGHT, -1, 8).x
	c.draw_string(_font, Vector2(cx - tw, box.position.y + 17), ctext, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, dark)
	if crystal:
		c.draw_texture_rect(crystal, Rect2(cx - tw - 11, box.position.y + 9, 9, 9), false)
	else:
		c.draw_string(_font, Vector2(cx - tw - 10, box.position.y + 17), "◆", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, dark)
	# Toolbar
	var tb: Array = r["toolbar"]
	var slot := int(r["slot"])
	c.draw_rect(Rect2(TOOLBAR_X - 2, TOOLBAR_Y - 2, 12 * SLOT + 4, SLOT + 4), Color(0.1, 0.07, 0.04, 0.75))
	for i in 12:
		var rect := Rect2(TOOLBAR_X + i * SLOT, TOOLBAR_Y, SLOT, SLOT)
		c.draw_rect(rect.grow(-1), Color(0.35, 0.25, 0.15, 0.9) if i != slot else Color(0.55, 0.42, 0.2, 1.0))
		if i == slot:
			c.draw_rect(rect.grow(-0.5), Color(1, 0.9, 0.5), false, 1.5)
		var id := str(tb[i])
		if id == "":
			continue
		var icon := Art.tex("items", icon_for(id))
		if icon:
			c.draw_texture_rect(icon, rect.grow(-2), false)
		else:
			c.draw_string(_font, Vector2(rect.position.x + 1, rect.position.y + 13), GameState.item_name(id).left(3), HORIZONTAL_ALIGNMENT_LEFT, SLOT, 7, Color.WHITE)
		if r["inventory"].has(id):
			var n := str(int(r["inventory"][id]))
			var nw := _font.get_string_size(n, HORIZONTAL_ALIGNMENT_RIGHT, -1, 7).x
			c.draw_string(_font, Vector2(rect.end.x - nw - 1, rect.end.y - 1), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)
	# Held item name / hint line
	var held := str(tb[slot])
	var line := ""
	if held != "":
		line = GameState.item_name(held)
	if _hint != "":
		line = (line + "   " if line != "" else "") + _hint
	c.draw_string(_font, Vector2(TOOLBAR_X, TOOLBAR_Y + SLOT + 11), line, HORIZONTAL_ALIGNMENT_LEFT, 240, 8, Color(1, 1, 0.9))
	# Energy bar (vertical, right side, Stardew style)
	var e := float(r["energy"]) / float(r["max_energy"])
	var bar := Rect2(256, 200, 9, 130)
	c.draw_rect(bar.grow(1), Color(0.1, 0.07, 0.04, 0.8))
	var fill_h := bar.size.y * e
	var col := Color("7ad35a") if e > 0.5 else (Color("f2c84b") if e > 0.25 else Color("e86a3a"))
	c.draw_rect(Rect2(bar.position.x, bar.end.y - fill_h, bar.size.x, fill_h), col)
	var bolt := Art.tex("ui", "bolt_full")
	if bolt:
		c.draw_texture_rect(bolt, Rect2(bar.position.x - 2, bar.position.y - 14, 13, 13), false)


static func icon_for(id: String) -> String:
	if Art.has("items", id):
		return id
	if id.ends_with("_seed"):
		return "seeds"
	match id:
		"minnow", "trout": return "fish"
		"berry": return "apple"
		"mushroom": return "bread"
		"boot": return "map"
	return id


func _panel(c: CanvasItem, name: String, rect: Rect2) -> void:
	var t := Art.tex("ui", name)
	if t == null:
		c.draw_rect(rect, Color(0.95, 0.88, 0.7, 0.95))
		c.draw_rect(rect, Color(0.4, 0.25, 0.1), false, 1.0)
		return
	# 3x3 cells of 24px -> draw as a 9-slice with 8px corners.
	var cs := 24
	var m := 8.0
	var w := rect.size.x
	var h := rect.size.y
	var p := rect.position
	var pieces := [
		[Rect2(0, 0, cs, cs), Rect2(p, Vector2(m, m))],
		[Rect2(cs, 0, cs, cs), Rect2(p + Vector2(m, 0), Vector2(w - 2 * m, m))],
		[Rect2(2 * cs, 0, cs, cs), Rect2(p + Vector2(w - m, 0), Vector2(m, m))],
		[Rect2(0, cs, cs, cs), Rect2(p + Vector2(0, m), Vector2(m, h - 2 * m))],
		[Rect2(cs, cs, cs, cs), Rect2(p + Vector2(m, m), Vector2(w - 2 * m, h - 2 * m))],
		[Rect2(2 * cs, cs, cs, cs), Rect2(p + Vector2(w - m, m), Vector2(m, h - 2 * m))],
		[Rect2(0, 2 * cs, cs, cs), Rect2(p + Vector2(0, h - m), Vector2(m, m))],
		[Rect2(cs, 2 * cs, cs, cs), Rect2(p + Vector2(m, h - m), Vector2(w - 2 * m, m))],
		[Rect2(2 * cs, 2 * cs, cs, cs), Rect2(p + Vector2(w - m, h - m), Vector2(m, m))],
	]
	for pc in pieces:
		c.draw_texture_rect_region(t, pc[1], pc[0])


## Panels in the art's palette: parchment (light, dark ink) or wood (dark, light text).
static func panel_stylebox(name: String) -> StyleBox:
	var sb := StyleBoxFlat.new()
	if name == "panel_parchment":
		sb.bg_color = Color(0.96, 0.9, 0.74, 0.97)
		sb.border_color = Color(0.45, 0.28, 0.12)
	else:
		sb.bg_color = Color(0.36, 0.22, 0.1, 0.97)
		sb.border_color = Color(0.78, 0.55, 0.25)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(7)
	return sb


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

extends CanvasLayer
## Farmhouse style picker (C10b P3): opened from the Plans board ("Restyle the
## farmhouse") via HouseExterior.open(map). The camera frames the house and every
## change previews live on the real farmhouse; the panel sits in the bottom third.
## Part tabs (Roof, Walls, Windows, Stonework, Door, Porch, Pen fence), < style >,
## then Apply (buys a style the first time; owned styles switch free) or Original.
## Closing without applying puts the saved look back. Pad: ScreenCursor, B closes.

const INK := Color("3b2412")
const INK_SOFT := Color("6b4a2c")
const PAPER := Color("f3e2bf")
const EDGE := Color("8a5a2b")

var map: Node
var part := "roof"
var idx := {}  # part -> index into [""] + styles(part)
var preview := {}
var _root: Control
var _arm := 0
var _was_paused := false
var _cursor: ScreenCursor
var _cam: Camera2D
var _cam_off := Vector2.ZERO
var _msg := ""


func _ready() -> void:
	layer = 72
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("toast_hold")
	_was_paused = get_tree().paused
	Hud.modal_rect = Rect2(0, 0, 270, 480)
	Hud.pause(get_tree(), "house_style")
	preview = HouseExterior.look().duplicate()
	for p: String in HouseExterior.PARTS:
		var opts := _opts(p)
		idx[p] = maxi(0, opts.find(str(preview.get(p, ""))))
	_frame_house(true)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_build()
	_cursor = ScreenCursor.make(self, _root)


func _opts(p: String) -> Array:
	var o: Array = [""]
	for s: Dictionary in HouseExterior.styles(p):
		o.append(str(s["id"]))
	return o


func _sprite() -> Sprite2D:
	if map and "_house_sprite" in map and map._house_sprite and is_instance_valid(map._house_sprite):
		return map._house_sprite
	return null


func _frame_house(on: bool) -> void:
	var sp := _sprite()
	if sp == null:
		return
	if on:
		_cam = get_viewport().get_camera_2d()
		if _cam == null:
			return
		_cam_off = _cam.offset
		var h := sp.texture.get_height() * sp.scale.y if sp.texture else 80.0
		var centre := sp.global_position + Vector2(0, -h * 0.5)
		# the house sits in the top two thirds, above the panel
		_cam.offset = _cam_off + (centre - _cam.get_screen_center_position()) + Vector2(0, 72)
	elif _cam and is_instance_valid(_cam):
		_cam.offset = _cam_off


func _lab(parent: Control, text: String, size := 8, col := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", Settings.font(size))
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _btn(parent: Control, text: String, cb: Callable, w := 0.0, on := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	b.custom_minimum_size = Vector2(w, 22)
	b.add_theme_font_size_override("font_size", 8)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("e7c98f") if on else Color("f8ecd2")
	sb.border_color = EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	for s: String in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(s, sb)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, INK)
	b.pressed.connect(func() -> void:
		Music.instance(get_tree()).sfx("ui_tap")
		cb.call())
	parent.add_child(b)
	return b


func cur_id() -> String:
	var o := _opts(part)
	return str(o[clampi(int(idx.get(part, 0)), 0, o.size() - 1)])


func _build() -> void:
	for c in _root.get_children():
		c.queue_free()
	var bg := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	bg.add_theme_stylebox_override("panel", sb)
	bg.position = Vector2(6, 270)
	bg.size = Vector2(258, 204)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(bg)
	var v := VBoxContainer.new()
	v.position = Vector2(12, 274)
	v.size = Vector2(246, 196)
	v.add_theme_constant_override("separation", 3)
	_root.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_lab(top, "Farmhouse style", 11).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn(top, "Close", _close, 44).set_meta("pc_key", "close")
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 3)
	g.add_theme_constant_override("v_separation", 3)
	v.add_child(g)
	for p: String in HouseExterior.PARTS:
		var pp := p
		_btn(g, str(HouseExterior.PART_WORDS[p]), func() -> void:
			part = pp
			_msg = ""
			_build(), 58, p == part).set_meta("pc_key", "tab_" + p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	v.add_child(row)
	_btn(row, "<", func() -> void: _step(-1), 30).set_meta("pc_key", "prev")
	var id := cur_id()
	var s := HouseExterior.style(id)
	var nm := _lab(row, str(s.get("name", "Original")) if id != "" else "Original", 10)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	_btn(row, ">", func() -> void: _step(1), 30).set_meta("pc_key", "next")
	var info := ""
	var saved := str(HouseExterior.look().get(part, ""))
	if id == saved:
		info = "On your house now."
	elif id == "":
		info = "The house as it was painted."
	elif HouseExterior.owns(id):
		info = "You own this style: switching is free."
	else:
		info = "%s once, then free to switch back any time." % Money.amount(int(s.get("price", 0)))
	if part == "roof" and GameState.look_se() == "winter":
		info += " Snow hides most of the roof until spring."
	if part == "fence":
		info += " Pen fences change next time you come to the farm."
	_lab(v, info, 8, INK_SOFT).custom_minimum_size = Vector2(246, 0)
	var act := HBoxContainer.new()
	act.add_theme_constant_override("separation", 4)
	v.add_child(act)
	var label := "Apply"
	if id != "" and id != saved and not HouseExterior.owns(id):
		label = "Buy %s" % Money.amount(int(s.get("price", 0)))
	var ab := _btn(act, label, _apply, 120, true)
	ab.set_meta("pc_key", "apply")
	ab.disabled = id == saved
	_btn(act, "Original", func() -> void:
		idx[part] = 0
		_preview(), 70).set_meta("pc_key", "orig")
	if _msg != "":
		_lab(v, _msg, 8, Color("2e6b2e"))


func _step(d: int) -> void:
	var n := _opts(part).size()
	idx[part] = posmod(int(idx.get(part, 0)) + d, n)
	_msg = ""
	_preview()


func _preview() -> void:
	var id := cur_id()
	if id == "":
		preview.erase(part)
	else:
		preview[part] = id
	var sp := _sprite()
	if sp:
		HouseExterior.apply(map, sp, preview)
	_build()


func _apply() -> void:
	var id := cur_id()
	match HouseExterior.choose(part, id):
		"ok":
			_msg = "Done! The house wears its new %s." % str(HouseExterior.PART_WORDS[part]).to_lower()
			Music.instance(get_tree()).sfx("hammer", "craft_done")
		"poor":
			_msg = "Not enough %s for that one yet." % ("cash" if Money.cash() else "crystals")
			Music.instance(get_tree()).sfx("nope", "thud")
		_:
			_msg = "That can't go on this house."
	_build()


func _process(_delta: float) -> void:
	_arm += 1
	if _arm < 8:
		return
	if Input.is_action_just_pressed("b") or Input.is_action_just_pressed("menu"):
		_close()


func _close() -> void:
	if not is_inside_tree():
		return
	var sp := _sprite()
	if sp:
		HouseExterior.apply(map, sp)  # back to the saved look (drops an unbought preview)
	_frame_house(false)
	Hud.modal_rect = Rect2()
	get_tree().paused = _was_paused and Hud.keep_paused(get_tree(), self)
	Music.instance(get_tree()).sfx("menu_close", "ui_tap")
	Dialogue.block_input(0.3)
	queue_free()

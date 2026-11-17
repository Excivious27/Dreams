class_name Hud
extends CanvasLayer
## Stardew-style HUD for a portrait phone: hearts top-left, clock box top-right,
## a 12-slot toolbar under them, a vertical energy bar on the right, toasts, and
## the fade used for scene changes and sleep.

const TOOLBAR_Y := 34.0
const SLOT := 20.0
const TOOLBAR_X := 15.0
const TOOLBAR_BOTTOM := 70.0
## Inside buildings the HUD block sits just above the touch controls so it never
## covers the room (the whole block is drawn shifted by this much).
const INTERIOR_SHIFT := 280.0
static var y_offset := 0.0


static func hud_rect_blocks(p: Vector2) -> bool:
	return p.y >= y_offset and p.y < y_offset + TOOLBAR_BOTTOM

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
	var sc := get_tree().current_scene
	var want := INTERIOR_SHIFT if sc is GameMap and (sc as GameMap).scene_id() in ["house", "interior"] else 0.0
	if want != y_offset:
		y_offset = want
		_canvas.queue_redraw()
	# Keyboard: number keys pick a toolbar slot (1-9, 0, -, =).
	for i in 12:
		if Input.is_action_just_pressed("slot_%d" % (i + 1)):
			GameState.select_slot(i)
	if Input.is_action_just_pressed("cycle_tool") and not Dialogue.input_blocked():
		GameState.select_slot((int(GameState.run["slot"]) + 1) % 12)
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if GameState.run.is_empty():
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		var p: Vector2 = (event as InputEventScreenTouch).position
		if p.y >= y_offset + TOOLBAR_Y - 2 and p.y <= y_offset + TOOLBAR_Y + SLOT + 2 and p.x >= TOOLBAR_X and p.x < TOOLBAR_X + 12 * SLOT:
			GameState.select_slot(int((p.x - TOOLBAR_X) / SLOT))
			Music.instance(get_tree()).sfx("plant")
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.device != InputEvent.DEVICE_ID_EMULATION:
			var p := mb.position
			if p.y >= y_offset + TOOLBAR_Y - 2 and p.y <= y_offset + TOOLBAR_Y + SLOT + 2 and p.x >= TOOLBAR_X and p.x < TOOLBAR_X + 12 * SLOT:
				GameState.select_slot(int((p.x - TOOLBAR_X) / SLOT))
				get_viewport().set_input_as_handled()
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			GameState.select_slot((int(GameState.run["slot"]) + 1) % 12)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			GameState.select_slot((int(GameState.run["slot"]) + 11) % 12)


func _draw_hud() -> void:
	var r := GameState.run
	if r.is_empty():
		return
	var c := _canvas
	c.draw_set_transform(Vector2(0, y_offset))
	# Hearts
	# Hearts: one per 20 HP; the last heart drains as a partial fill.
	var hp := int(r["hp"])
	var max_hp := int(r["max_hp"])
	var hearts := int(ceil(max_hp / float(GameState.HEART_HP)))
	var heart_full := Art.tex("ui", "heart2_full") if Art.has("ui", "heart2_full") else Art.tex("ui", "heart_full")
	var heart_empty := Art.tex("ui", "heart2_empty") if Art.has("ui", "heart2_empty") else Art.tex("ui", "heart_empty")
	for i in hearts:
		var p := Vector2(6 + i * 11, 4)
		var f := clampf((hp - i * GameState.HEART_HP) / float(GameState.HEART_HP), 0.0, 1.0)
		if heart_full and heart_empty:
			c.draw_texture_rect(heart_empty, Rect2(p, Vector2(10, 10)), false)
			if f > 0.0:
				c.draw_texture_rect_region(heart_full, Rect2(p + Vector2(0, 10 * (1.0 - f)), Vector2(10, 10 * f)), Rect2(0, heart_full.get_height() * (1.0 - f), heart_full.get_width(), heart_full.get_height() * f))
		else:
			c.draw_circle(p + Vector2(5, 5), 4.0, Color("e8484a") if f >= 1.0 else Color(0, 0, 0, 0.4))
	c.draw_string(_font, Vector2(6 + hearts * 11 + 2, 13), "%d/%d" % [hp, max_hp], HORIZONTAL_ALIGNMENT_LEFT, 60, 7, Color(1, 0.95, 0.9))
	# Mana (small blue bar under the hearts), only once you can cast.
	if int(r.get("max_mana", 0)) > 0 and (GameState.skill_level("magic") > 1 or int(r.get("mana", 0)) > 0):
		var mb := Rect2(6, 16, 50, 4)
		if Art.has("ui", "bar_h_empty") and Art.has("ui", "bar_h_blue"):
			_hbar(c, Rect2(4, 15, 54, 7), GameState.vital("mana"), "bar_h_blue")
		else:
			c.draw_rect(mb.grow(1), Color(0.1, 0.07, 0.04, 0.8))
			c.draw_rect(Rect2(mb.position, Vector2(mb.size.x * GameState.vital("mana"), mb.size.y)), Color("5aa8f0"))
		c.draw_string(_font, Vector2(mb.end.x + 3, mb.end.y), "%d/%d" % [int(r.get("mana", 0)), int(r.get("max_mana", 0))], HORIZONTAL_ALIGNMENT_LEFT, 50, 7, Color(0.8, 0.9, 1.0))
	# Active buffs (Prompts 10 icons) under the hearts.
	var bx := 6.0
	var buffs: Dictionary = r.get("buffs", {})
	for k in buffs:
		if GameState.buff(str(k)) <= 0.0:
			continue
		var bi := "buff2_" + str(k)
		if Art.has("ui", bi):
			c.draw_texture_rect(Art.tex("ui", bi), Rect2(bx, 24, 9, 9), false)
			bx += 11
	for k in r.get("status", {}):
		var sd := GameState.status_def(str(k))
		var si := str(sd.get("icon", ""))
		if si != "" and Art.has("ui", si):
			c.draw_texture_rect(Art.tex("ui", si), Rect2(bx, 24, 9, 9), false)
			c.draw_rect(Rect2(bx, 34, 9.0 * clampf(float(r["status"][k].get("secs", 0.0)) / 6.0, 0.0, 1.0), 1), Color(sd.get("colour", "ffffff")))
			bx += 11
	if int(r["flags"].get("shield", 0)) > 0 and Art.has("ui", "buff2_shield"):
		c.draw_texture_rect(Art.tex("ui", "buff2_shield"), Rect2(bx, 24, 9, 9), false); bx += 11
	if int(r["flags"].get("haste_until", 0)) > int(r["time"]) and Art.has("ui", "buff2_haste"):
		c.draw_texture_rect(Art.tex("ui", "buff2_haste"), Rect2(bx, 24, 9, 9), false); bx += 11
	if int(r["flags"].get("glow_day", -1)) == int(r["day"]) and Art.has("ui", "buff2_glow"):
		c.draw_texture_rect(Art.tex("ui", "buff2_glow"), Rect2(bx, 24, 9, 9), false); bx += 11
	# Clock box (top right)
	var box := Rect2(166, 2, 100, 28)
	_panel(c, "panel_parchment", box)
	var dark := Color(0.25, 0.15, 0.05)
	var sicon := Art.tex("ui", "season2_" + GameState.season()) if Art.has("ui", "season2_" + GameState.season()) else Art.tex("ui", "season_" + GameState.season())
	if sicon:
		c.draw_texture_rect(sicon, Rect2(box.position.x + 4, box.position.y + 3, 9, 9), false)
	c.draw_string(_font, Vector2(box.position.x + (15 if sicon else 6), box.position.y + 11), "%s %d" % [GameState.season().capitalize().left(3), GameState.day_of_season()], HORIZONTAL_ALIGNMENT_LEFT, 50, 8, dark)
	c.draw_string(_font, Vector2(box.position.x + 6, box.position.y + 22), GameState.clock_text(), HORIZONTAL_ALIGNMENT_LEFT, 60, 8, dark)
	var wx := GameState.weather_today()
	var wicon: String = {"rain": "☂", "storm": "⚡", "snow": "❄", "blizzard": "❄❄", "fog": "≈", "sun": "☀", "wind": "〰", "petals": "✿", "leaves": "❧", "fireflies": "✦"}.get(wx, "☼")
	var wxa := "wx_" + (wx if wx != "petals" else "petals_a")
	if Art.has("ui", wxa):
		c.draw_texture_rect(Art.tex("ui", wxa), Rect2(box.position.x + 50, box.position.y + 14, 11, 11), false)
	else:
		c.draw_string(_font, Vector2(box.position.x + 52, box.position.y + 22), str(wicon), HORIZONTAL_ALIGNMENT_LEFT, 20, 8, dark)
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
	var frame := Art.tex("ui", "hotbar_frame")
	if frame:
		c.draw_texture_rect(frame, Rect2(TOOLBAR_X - 6, TOOLBAR_Y - 5, 12 * SLOT + 12, SLOT + 10), false)
	else:
		c.draw_rect(Rect2(TOOLBAR_X - 2, TOOLBAR_Y - 2, 12 * SLOT + 4, SLOT + 4), Color(0.1, 0.07, 0.04, 0.75))
	var slot_tex := Art.tex("ui", "slot")
	var slot_sel := Art.tex("ui", "slot_selected")
	for i in 12:
		var rect := Rect2(TOOLBAR_X + i * SLOT, TOOLBAR_Y, SLOT, SLOT)
		if slot_tex and slot_sel:
			c.draw_texture_rect(slot_sel if i == slot else slot_tex, rect, false)
		else:
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
	c.draw_set_transform(Vector2.ZERO)  # the energy bar stays where it is
	var e := float(r["energy"]) / float(r["max_energy"])
	var bar := Rect2(256, 200, 9, 130)
	var fill_h := bar.size.y * e
	var col := Color("7ad35a") if e > 0.5 else (Color("f2c84b") if e > 0.25 else Color("e86a3a"))
	if Art.has("ui", "ebar_empty") and Art.has("ui", "ebar_green"):
		# Painted vertical bar (Prompts 09 HUD sheet): empty frame, fill cropped from the bottom.
		var fr := Rect2(250, 186, 20, 150)
		var fill_name := "ebar_green" if e > 0.5 else ("ebar_amber" if e > 0.25 else "ebar_red")
		var fe := Art.tex("ui", "ebar_empty")
		var ff := Art.tex("ui", fill_name) if Art.has("ui", fill_name) else Art.tex("ui", "ebar_green")
		c.draw_texture_rect(fe, fr, false)
		# The tube inside the frame runs ~12%..95% of its height; crop the fill texture to that.
		var top := 0.12
		var bot := 0.95
		var frac := clampf(e, 0.0, 1.0)
		var y0 := bot - (bot - top) * frac
		c.draw_texture_rect_region(ff, Rect2(fr.position.x, fr.position.y + fr.size.y * y0, fr.size.x, fr.size.y * (bot - y0)), Rect2(0, ff.get_height() * y0, ff.get_width(), ff.get_height() * (bot - y0)))
	else:
		c.draw_rect(bar.grow(1), Color(0.1, 0.07, 0.04, 0.8))
		c.draw_rect(Rect2(bar.position.x, bar.end.y - fill_h, bar.size.x, fill_h), col)
		var bolt := Art.tex("ui", "bolt_full")
		if bolt:
			c.draw_texture_rect(bolt, Rect2(bar.position.x - 2, bar.position.y - 14, 13, 13), false)
	c.draw_string(_font, Vector2(bar.position.x - 30, bar.end.y + 10), "%d/%d" % [int(r["energy"]), int(r["max_energy"])], HORIZONTAL_ALIGNMENT_RIGHT, 40, 7, Color(1, 1, 0.9))


static func icon_for(id: String) -> String:
	if GameState.TOOL_KINDS.has(id) or id == "iron_sword":
		var ti := GameState.tool_icon(id)
		if Art.has("items", ti):
			return ti
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
## Horizontal painted bar: bar_h_empty frame + fill cropped from the left.
func _hbar(c: CanvasItem, r: Rect2, frac: float, fill: String) -> void:
	c.draw_texture_rect(Art.tex("ui", "bar_h_empty"), r, false)
	var ff := Art.tex("ui", fill)
	var f := clampf(frac, 0.0, 1.0)
	if f > 0.0:
		c.draw_texture_rect_region(ff, Rect2(r.position, Vector2(r.size.x * f, r.size.y)), Rect2(0, 0, ff.get_width() * f, ff.get_height()))


## Wooden button skin (Prompts 09 menu sheet) as a 9-slice on a Theme.
static func skin_buttons(ctrl: Control) -> void:
	if not Art.has("ui", "btn2_wood"):
		return
	var th := Theme.new()
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxTexture.new()
		sb.texture = Art.tex("ui", "btn2_wood" if st != "disabled" else "btn2_disabled")
		var w := sb.texture.get_width()
		var h := sb.texture.get_height()
		sb.texture_margin_left = w * 0.12
		sb.texture_margin_right = w * 0.12
		sb.texture_margin_top = h * 0.25
		sb.texture_margin_bottom = h * 0.3
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		if st == "pressed":
			sb.modulate_color = Color(0.85, 0.8, 0.75)
		elif st == "hover":
			sb.modulate_color = Color(1.1, 1.05, 1.0)
		th.set_stylebox(st, "Button", sb)
	th.set_color("font_color", "Button", Color(1, 0.95, 0.85))
	th.set_color("font_hover_color", "Button", Color(1, 1, 0.9))
	th.set_color("font_pressed_color", "Button", Color(1, 0.9, 0.7))
	th.set_constant("outline_size", "Button", 2)
	th.set_color("font_outline_color", "Button", Color(0.2, 0.1, 0.05))
	ctrl.theme = th


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

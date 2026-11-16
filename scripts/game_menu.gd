class_name GameMenu
extends CanvasLayer
## The pause menu, laid out like Stardew's: tabs for Items, Skills, Social,
## Map, Quests and Options. Items shows the 12-slot toolbar plus the backpack;
## tap a backpack item to swap it into the selected toolbar slot.
## Pauses the game while open.

const TABS := ["Items", "Skills", "Social", "Map", "Quests", "Options"]
const SLOT := 34

var _panel: PanelContainer
var _body: VBoxContainer
var _tabs: HBoxContainer
var _open := false
var _tab := "Items"
var _tab_buttons := {}


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.position = Vector2(6, 30)
	_panel.size = Vector2(258, 320)
	_panel.visible = false
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_panel.add_theme_stylebox_override("panel", Hud.panel_stylebox("panel_wood"))
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_panel.add_child(v)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 1)
	v.add_child(_tabs)
	for t: String in TABS:
		var b := Button.new()
		b.text = t
		b.add_theme_font_size_override("font_size", 7)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 18)
		b.pressed.connect(func() -> void: _tab = t; _refresh())
		_tabs.add_child(b)
		_tab_buttons[t] = b
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 246)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 3)
	scroll.add_child(_body)
	var close := Button.new()
	close.text = "Close  (MENU / E)"
	close.add_theme_font_size_override("font_size", 8)
	close.pressed.connect(toggle)
	v.add_child(close)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("menu"):
		if Dialogue.instance(get_tree()).active:
			return
		toggle()


func toggle() -> void:
	_open = not _open
	_panel.visible = _open
	get_tree().paused = _open
	if _open:
		_refresh()
	else:
		Dialogue.block_input()


func _line(text: String, size := 9, color := Color(1, 0.96, 0.85)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(l)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 9)
	b.pressed.connect(cb)
	_body.add_child(b)
	return b


func _slot_button(id: String, selected: bool, cb: Callable) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(SLOT, SLOT)
	b.pressed.connect(cb)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.42, 0.2) if selected else Color(0.25, 0.17, 0.1)
	sb.border_color = Color(1, 0.9, 0.5) if selected else Color(0.1, 0.07, 0.04)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	if id != "":
		var icon := Art.tex("items", Hud.icon_for(id))
		if icon:
			var tr := TextureRect.new()
			tr.texture = icon
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_SCALE
			tr.set_anchors_preset(Control.PRESET_FULL_RECT)
			tr.offset_left = 3
			tr.offset_top = 3
			tr.offset_right = -3
			tr.offset_bottom = -3
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(tr)
		else:
			b.text = GameState.item_name(id).left(4)
			b.add_theme_font_size_override("font_size", 7)
		if GameState.run["inventory"].has(id):
			var n := Label.new()
			n.text = str(int(GameState.run["inventory"][id]))
			n.add_theme_font_size_override("font_size", 7)
			n.add_theme_constant_override("outline_size", 2)
			n.add_theme_color_override("font_outline_color", Color.BLACK)
			n.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			n.offset_left = -14
			n.offset_top = -11
			n.offset_right = -2
			n.offset_bottom = -1
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(n)
	return b


func _grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 2)
	g.add_theme_constant_override("v_separation", 2)
	_body.add_child(g)
	return g


func _refresh() -> void:
	for c in _body.get_children():
		c.queue_free()
	for t in _tab_buttons:
		(_tab_buttons[t] as Button).modulate = Color(1, 0.9, 0.5) if t == _tab else Color(0.85, 0.85, 0.85)
	var r := GameState.run
	match _tab:
		"Items":
			var slot := int(r["slot"])
			var tb: Array = r["toolbar"]
			var sel := str(tb[slot])
			_line("In hand: %s" % (GameState.item_name(sel) if sel != "" else "nothing"), 9)
			var g := _grid(6)
			for i in 12:
				var id := str(tb[i])
				g.add_child(_slot_button(id, i == slot, func() -> void: GameState.select_slot(i); _refresh()))
			_line("Backpack (tap to put in the selected slot)", 8, Color(0.9, 0.85, 0.7))
			var pack := GameState.backpack()
			var g2 := _grid(6)
			for id: String in pack:
				g2.add_child(_slot_button(id, false, func() -> void: _swap_into_toolbar(id)))
			for i in maxi(0, 12 - pack.size()):
				g2.add_child(_slot_button("", false, func() -> void: pass))
			if sel != "" and GameState.items.get(sel, {}).has("heal"):
				_button("Eat %s" % GameState.item_name(sel), func() -> void: _eat(sel))
			_line("Tools: " + ", ".join(r["tools"].map(func(t: String) -> String: return GameState.item_name(t))), 7, Color(0.8, 0.8, 0.8))
		"Skills":
			for s in r["skills"]:
				var d: Dictionary = r["skills"][s]
				var lvl := int(d["level"])
				var need := GameState.xp_for_next(lvl)
				var h := HBoxContainer.new()
				_body.add_child(h)
				var ic := Art.tex("ui", "skill_" + str(s))
				if ic:
					var tr := TextureRect.new()
					tr.texture = ic
					tr.custom_minimum_size = Vector2(14, 14)
					tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					h.add_child(tr)
				var l := Label.new()
				l.text = "  %s   Lv %d" % [str(s).capitalize(), lvl]
				l.add_theme_font_size_override("font_size", 9)
				h.add_child(l)
				var bar := ProgressBar.new()
				bar.max_value = need
				bar.value = int(d["xp"])
				bar.custom_minimum_size = Vector2(0, 8)
				bar.show_percentage = false
				_body.add_child(bar)
			_line("")
			_line("Sword damage: %d" % GameState.sword_damage(), 8)
			_line("Enemies defeated: %d" % int(r.get("kills", 0)), 8)
		"Social":
			var fr: Dictionary = r["friendship"]
			var full := Art.tex("ui", "pheart_full") if Art.has("ui", "pheart_full") else Art.tex("ui", "heart_full")
			var empty := Art.tex("ui", "pheart_empty") if Art.has("ui", "pheart_empty") else Art.tex("ui", "heart_empty")
			for id in GameState.npcs:
				var d: Dictionary = GameState.npcs[id]
				var pts := int(fr.get(id, 0))
				var h := HBoxContainer.new()
				_body.add_child(h)
				var pt := Art.tex("portraits/" + str(d.get("portrait", id)), "neutral")
				if pt:
					var tr := TextureRect.new()
					tr.texture = pt
					tr.custom_minimum_size = Vector2(22, 22)
					tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					h.add_child(tr)
				var l := Label.new()
				l.text = "%s\n%s" % [d["name"], d["role"]]
				l.add_theme_font_size_override("font_size", 8)
				l.custom_minimum_size = Vector2(70, 0)
				h.add_child(l)
				var hearts := HBoxContainer.new()
				hearts.add_theme_constant_override("separation", 0)
				h.add_child(hearts)
				for i in 10:
					var tr := TextureRect.new()
					tr.custom_minimum_size = Vector2(11, 11)
					tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					tr.texture = full if i < pts / 25 else empty
					hearts.add_child(tr)
				var pl := Label.new()
				pl.text = " %d" % pts
				pl.add_theme_font_size_override("font_size", 7)
				h.add_child(pl)
		"Map":
			var m := Control.new()
			m.custom_minimum_size = Vector2(240, 190)
			m.draw.connect(func() -> void: _draw_map(m))
			_body.add_child(m)
			_line("You are in: %s" % str(r["scene"]).capitalize(), 8)
		"Quests":
			if r["quests"].is_empty():
				_line("No quests yet.")
			for q in r["quests"]:
				_line(("✓ " if q["done"] else "• ") + str(q["text"]), 9, Color(0.7, 0.9, 0.7) if q["done"] else Color(1, 0.96, 0.85))
		"Options":
			var arc_title: String = GameState.arcs.get(r["arc"], {}).get("title", "")
			_line("%s of %s · Pet: %s\n%s\nDay %d" % [r["names"]["character"], r["names"]["town"], r["names"]["pet"], arc_title, int(r["day"])])
			_button("Music: %s" % ("off" if bool(SaveGame.get_value("muted", false)) else "on"), func() -> void: Music.instance(get_tree()).toggle_mute(); _refresh())
			_button("On-screen controls: %s" % ("shown" if TouchControls.visible_controls else "hidden"), func() -> void: TouchControls.visible_controls = not TouchControls.visible_controls; _refresh())
			_button("Save & back to title", func() -> void:
				GameState.save()
				get_tree().paused = false
				get_tree().change_scene_to_file("res://scenes/title.tscn"))
			_line("Touch: D-pad or tap where to go · A use/attack · B run · tap the toolbar to pick an item\nKeyboard: WASD/arrows · click to use · Z/Space = A · Shift = run · 1-9 0 - = toolbar · E/Esc menu", 7, Color(0.8, 0.8, 0.8))


func _swap_into_toolbar(id: String) -> void:
	var r := GameState.run
	var tb: Array = r["toolbar"]
	var slot := int(r["slot"])
	var was := str(tb[slot])
	if GameState.has_tool(was):
		# Don't bump a tool; use the first free slot instead.
		var free := tb.find("")
		if free >= 0:
			tb[free] = id
			r["slot"] = free
		else:
			tb[slot] = id
	else:
		tb[slot] = id
	GameState.sync_selected()
	_refresh()


func _eat(id: String) -> void:
	var it: Dictionary = GameState.items.get(id, {})
	GameState.add_item(id, -1)
	GameState.heal(int(it.get("heal", 0)))
	GameState.restore_energy(int(it.get("energy", 0)) + int(it.get("heal", 0)) * 8)
	Music.instance(get_tree()).sfx("pickup")
	_refresh()


func _draw_map(m: Control) -> void:
	var font := ThemeDB.fallback_font
	var boxes := {
		"farm": Rect2(70, 60, 70, 60), "town": Rect2(70, 130, 70, 50), "meadow": Rect2(150, 70, 80, 40),
		"mine": Rect2(190, 10, 45, 40), "house": Rect2(20, 20, 40, 30),
	}
	var cols := {"farm": Color(0.45, 0.7, 0.35), "town": Color(0.75, 0.65, 0.45), "meadow": Color(0.55, 0.75, 0.4), "mine": Color(0.4, 0.38, 0.45), "house": Color(0.7, 0.45, 0.3)}
	m.draw_rect(Rect2(0, 0, 240, 190), Color(0.85, 0.78, 0.6))
	var road := Color(0.4, 0.3, 0.2)
	m.draw_line(Vector2(105, 120), Vector2(105, 130), road, 2)
	m.draw_line(Vector2(140, 90), Vector2(150, 90), road, 2)
	m.draw_line(Vector2(212, 70), Vector2(212, 50), road, 2)
	m.draw_line(Vector2(60, 35), Vector2(70, 60), road, 2)
	var here := str(GameState.run["scene"])
	for k: String in boxes:
		var b: Rect2 = boxes[k]
		m.draw_rect(b, cols[k])
		m.draw_rect(b, Color(0.3, 0.2, 0.1), false, 1.5 if k != here else 3.0)
		m.draw_string(font, Vector2(b.position.x, b.position.y + b.size.y / 2 + 3), k.capitalize(), HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 8, Color(0.1, 0.1, 0.1))
	if boxes.has(here):
		var scene := get_tree().current_scene
		var b: Rect2 = boxes[here]
		var p := b.get_center()
		if scene is GameMap and (scene as GameMap).player:
			var gm := scene as GameMap
			var f := gm.player.position / Vector2(gm.cols * GameMap.TILE, gm.rows * GameMap.TILE)
			p = b.position + Vector2(f.x * b.size.x, f.y * b.size.y)
		m.draw_circle(p, 4.0, Color(0.9, 0.2, 0.2))
		m.draw_arc(p, 4.0, 0, TAU, 16, Color.WHITE, 1.0)

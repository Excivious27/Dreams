class_name GameMenu
extends CanvasLayer
## MENU panel: pick what's in your hand (seeds, food, gifts), see quests and
## skills, mute music, go back to title. Pauses the game while open.

var _panel: PanelContainer
var _body: VBoxContainer
var _open := false
var _tab := "items"


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.position = Vector2(10, 40)
	_panel.size = Vector2(250, 300)
	_panel.visible = false
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.12, 0.95)
	sb.border_color = Color(0.9, 0.85, 0.6, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(6)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var v := VBoxContainer.new()
	_panel.add_child(v)
	var tabs := HBoxContainer.new()
	v.add_child(tabs)
	for t in ["items", "quests", "skills", "options"]:
		var b := Button.new()
		b.text = t.capitalize()
		b.add_theme_font_size_override("font_size", 8)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: _tab = t; _refresh())
		tabs.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 232)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 2)
	scroll.add_child(_body)
	var close := Button.new()
	close.text = "Close"
	close.add_theme_font_size_override("font_size", 9)
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


func _line(text: String, size := 9) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
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


func _refresh() -> void:
	for c in _body.get_children():
		c.queue_free()
	var r := GameState.run
	match _tab:
		"items":
			_line("Tap an item to hold it. A uses it on what's in front of you (plant seeds, eat food, give gifts).", 8)
			var sel := str(r["selected"])
			if sel != "":
				_button("[ Empty hands ]", func() -> void: r["selected"] = ""; _refresh())
			var inv: Dictionary = r["inventory"]
			var keys := inv.keys()
			keys.sort()
			if keys.is_empty():
				_line("Nothing yet. Forage, farm, fish, fight.")
			for id in keys:
				var mark := "▶ " if id == sel else "   "
				_button("%s%s x%d  (◆%d)" % [mark, GameState.item_name(id), int(inv[id]), GameState.item_value(id)],
					func() -> void: r["selected"] = id; _refresh())
			_line("Tools: " + ", ".join(r["tools"].map(func(t: String) -> String: return GameState.item_name(t))), 8)
		"quests":
			if r["quests"].is_empty():
				_line("No quests yet.")
			for q in r["quests"]:
				_line(("✓ " if q["done"] else "• ") + str(q["text"]))
		"skills":
			for s in r["skills"]:
				var d: Dictionary = r["skills"][s]
				_line("%s  Lv %d  (%d/%d xp)" % [str(s).capitalize(), int(d["level"]), int(d["xp"]), GameState.xp_for_next(int(d["level"]))])
			_line("")
			_line("Sword damage: %d" % GameState.sword_damage(), 8)
			_line("Grumps defeated: %d" % int(r.get("kills", 0)), 8)
		"options":
			var arc_title: String = GameState.arcs.get(r["arc"], {}).get("title", "")
			_line("%s of %s · Pet: %s\n%s\nDay %d" % [r["names"]["character"], r["names"]["town"], r["names"]["pet"], arc_title, int(r["day"])])
			_button("Music: %s" % ("off" if bool(SaveGame.get_value("muted", false)) else "on"), func() -> void: Music.instance(get_tree()).toggle_mute(); _refresh())
			_button("Save & back to title", func() -> void:
				GameState.save()
				get_tree().paused = false
				get_tree().change_scene_to_file("res://scenes/title.tscn"))
			_line("Keyboard: arrows/WASD move · Z/Space = A · X/Shift = B (run) · Esc/M = MENU", 8)

class_name Dialogue
extends CanvasLayer
## Story/dialogue box with typewriter text and choices. Tap the box or press A to
## advance. Choices are real buttons (touch) and also work with up/down + A.
## Usage: Dialogue.instance(tree).say([{"who": "Maple", "text": "Hi"}, ...]) then await finished.
## A line can be {"choice": ["Yes", "No"], "key": "trust"} -> stores the answer in
## GameState.run.decisions[key] (index) and sets last_choice.

signal finished
signal choice_made(key: String, index: int)

const BOX_Y := 286.0
const BOX_H := 72.0

## Game code ignores A for a moment after a dialogue/menu closes so the press
## that closed it doesn't also swing a sword or reopen a shop.
static var block_until_ms := 0

var active := false
var last_choice := -1
var _queue: Array = []
var _panel: PanelContainer
var _who: Label
var _text: Label
var _choices: VBoxContainer
var _full := ""
var _shown := 0.0
var _choice_focus := 0
var _in_choice := false
var _typing := false
var _hint: Label
var _opened_frame := 0
var _portrait: TextureRect
var _row: HBoxContainer

## Portrait id per speaker name. Player/pet names come from the run.
static func portrait_for(who: String) -> String:
	if GameState.run.is_empty():
		return ""
	var n: Dictionary = GameState.run.get("names", {})
	if who == str(n.get("character", "")):
		var sprite := GameState.sprite_for_playable(str(GameState.run["playable"]))
		if sprite == "penguin":
			return ""
		# Paper-doll hero: portrait by equipped costume, else by body base.
		var look: Dictionary = GameState.run.get("look", {})
		if look.has("body"):
			var cs := str(GameState.items.get(GameState.equipped("body"), {}).get("costume", ""))
			if cs != "" and Art.has("portraits/hero_" + cs, "neutral"):
				return "hero_" + cs
			var body := str(look.get("body", "medium_slim"))
			if Art.has("portraits/hero_" + body, "neutral"):
				return "hero_" + body
		return sprite
	if who == str(n.get("pet", "")):
		return "dog"
	var lower := who.to_lower()
	var map := {"star crystal": "light_crystal", "dark crystal": "dark_crystal", "the president": "president", "president": "president",
		"maple": "barnaby", "gideon": "greta", "wren": "wren", "mayor alder": "mayor", "sal": "nico",
		"riley": "riley", "manny": "manny", "eli": "eli", "jax": "jax", "vex": "vex", "nico": "nico",
		"grandmother brine": "elder_brine", "old tidewhisker": "elder_tidewhisker", "captain icewhisker": "elder_icewhisker", "lady cinderpaw": "elder_cinderpaw",
		"barnaby": "barnaby", "greta": "greta", "finn": "finn", "lumi": "lumi", "theo": "theo", "hazel": "hazel"}
	map["nova"] = "penguin_wizard"
	map["pip-pip"] = "penguin_king"
	var comp := Companion.data()
	for cid in comp:
		var cd: Variant = comp[cid]
		if cd is Dictionary and (cd as Dictionary).has("name"):
			map[str(cd["name"]).to_lower()] = str((cd as Dictionary).get("sprite", cid))
	var crew: Variant = Crew.data().get("members", {})
	if crew is Dictionary:
		for cid in crew:
			if crew[cid] is Dictionary:
				map[str(crew[cid].get("name", cid)).to_lower()] = str(crew[cid].get("sprite", cid))
	var se := GameState.season()
	for k in GameState.npcs:
		var pid := str(GameState.npcs[k].get("portrait", k))
		# Their own painted portrait (by season) beats the shared job portrait.
		for g in ["npc_%s_%s" % [k, se], "npc_%s_normal" % k, "npc_" + str(k)]:
			if Art.has("portraits/" + g, "neutral"):
				pid = g
				break
		map[str(GameState.npcs[k].get("name", "")).to_lower()] = pid
		map[str(k)] = pid
	var out := str(map.get(lower, ""))
	if out == "" and lower.begins_with("mayor "):
		out = str(map.get(lower.trim_prefix("mayor "), ""))
	return out if out == "" or Art.has("portraits/" + out, "neutral") else ""


static func instance(tree: SceneTree) -> Dialogue:
	var d := tree.root.get_node_or_null("Dialogue") as Dialogue
	if d == null:
		d = Dialogue.new()
		d.name = "Dialogue"
		tree.root.add_child(d)
	return d


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.position = Vector2(8, BOX_Y)
	_panel.size = Vector2(254, BOX_H)
	_panel.visible = false
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_panel.add_theme_stylebox_override("panel", Hud.panel_stylebox("panel_parchment"))
	var ink := Art.has("ui", "panel_parchment")
	add_child(_panel)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 6)
	_panel.add_child(_row)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(48, 48)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_portrait.visible = false
	_row.add_child(_portrait)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(v)
	_who = Label.new()
	_who.add_theme_font_size_override("font_size", 8)
	_who.add_theme_color_override("font_color", Color(0.5, 0.25, 0.05) if ink else Color(0.95, 0.85, 0.5))
	v.add_child(_who)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 9)
	if ink:
		_text.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(180, 34)
	v.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 2)
	_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Long choice lists (Dreamwalk) scroll instead of running off the screen.
	_choice_scroll = ScrollContainer.new()
	_choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_choice_scroll.add_child(_choices)
	v.add_child(_choice_scroll)
	_hint = Label.new()
	_hint.text = "▼"
	_hint.add_theme_font_size_override("font_size", 8)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.modulate = Color(0.3, 0.2, 0.1, 0.8) if ink else Color(1, 1, 1, 0.6)
	v.add_child(_hint)


var _choice_scroll: ScrollContainer


func say(lines: Array) -> void:
	_queue.append_array(lines)
	if not active:
		active = true
		_opened_frame = Engine.get_process_frames()
		get_tree().paused = true
		_panel.visible = true
		_next()


func _next() -> void:
	for c in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()
	_choice_scroll.custom_minimum_size = Vector2.ZERO
	_in_choice = false
	if _queue.is_empty():
		_close()
		return
	var line: Dictionary = _queue.pop_front()
	_set_pic(str(line.get("pic", "")))
	_set_portrait(str(line.get("who", "")), str(line.get("mood", "neutral")))
	if line.has("choice"):
		_show_choice(line)
		return
	_who.text = str(line.get("who", ""))
	_who.visible = _who.text != ""
	_full = str(line.get("text", ""))
	if is_inside_tree():
		Music.instance(get_tree()).sfx("talk_blip")
	_shown = 0.0
	_typing = true
	_text.text = ""
	_hint.visible = false
	_panel.size.y = BOX_H
	_panel.position.y = BOX_Y


func _set_portrait(who: String, mood: String) -> void:
	var pid := portrait_for(who)
	var tex: Texture2D = null
	if pid != "":
		if pid.ends_with("_gang") and not Art.has("portraits/" + pid, "neutral"):
			pid = pid.trim_suffix("_gang")
		tex = Art.tex("portraits/" + pid, mood)
		if tex == null:
			tex = Art.tex("portraits/" + pid, "neutral")
	_portrait.texture = tex
	_portrait.visible = tex != null
	_text.custom_minimum_size = Vector2(180 if tex else 240, 34)


func _show_choice(line: Dictionary) -> void:
	_in_choice = true
	_choice_opened = Engine.get_process_frames()
	_who.text = str(line.get("who", ""))
	_who.visible = _who.text != ""
	_text.text = str(line.get("text", ""))
	_typing = false
	_hint.visible = false
	var opts: Array = line["choice"]
	var key := str(line.get("key", ""))
	_choice_focus = 0
	for i in opts.size():
		var b := Button.new()
		b.text = str(opts[i])
		b.add_theme_font_size_override("font_size", 9)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 20)
		# Dark text on parchment: every choice readable, the focused one outlined in gold.
		for st in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.96, 0.9, 0.74)
			sb.border_color = Color(0.45, 0.3, 0.15)
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(3)
			sb.content_margin_left = 6
			sb.content_margin_right = 6
			b.add_theme_stylebox_override(st, sb)
		for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(fc, Color(0.2, 0.12, 0.06))
		b.pressed.connect(func() -> void: _choose(key, i))
		_choices.add_child(b)
	# Size the list by the rows' real (wrapped) heights, up to about half the screen.
	var want := 0.0
	for c in _choices.get_children():
		want += maxf(20.0, (c as Button).get_combined_minimum_size().y) + 2.0
	var cap := 7 * 22.0
	_choice_scroll.custom_minimum_size = Vector2(0, minf(want, cap))
	_panel.size.y = BOX_H + minf(want, cap)
	# Keep the choices above the touch controls.
	_panel.position.y = minf(BOX_Y, TouchControls.TOP_OF_CONTROLS - _panel.size.y - 6)
	_refresh_focus()


func _refresh_focus() -> void:
	var i := 0
	for c in _choices.get_children():
		var on := i == _choice_focus
		for st in ["normal", "hover", "focus"]:
			var sb := (c as Button).get_theme_stylebox(st) as StyleBoxFlat
			if sb:
				sb.border_color = Color(0.95, 0.7, 0.15) if on else Color(0.45, 0.3, 0.15)
				sb.set_border_width_all(2 if on else 1)
		if i == _choice_focus and _choice_scroll:
			_choice_scroll.ensure_control_visible.call_deferred(c)
		i += 1


func _choose(key: String, index: int) -> void:
	last_choice = index
	if is_inside_tree():
		Music.instance(get_tree()).sfx("ui_tap")
	if key != "":
		GameState.run["decisions"][key] = index
	choice_made.emit(key, index)
	_next()


static func block_input(seconds := 0.25) -> void:
	block_until_ms = Time.get_ticks_msec() + int(seconds * 1000)


static func input_blocked() -> bool:
	return Time.get_ticks_msec() < block_until_ms


## A painted story panel above the box ("pic": "cut_star" -> ui/cut_star).
## It stays up for the following lines until another pic or "pic": "none".
var _pic: TextureRect


func _set_pic(name: String) -> void:
	if name == "":
		return
	if name == "none" or not Art.has("ui", name):
		if _pic:
			_pic.visible = false
		return
	if _pic == null:
		_pic = TextureRect.new()
		_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pic.position = Vector2(8, 70)
		_pic.size = Vector2(254, 156)
		add_child(_pic)
	_pic.texture = Art.tex("ui", name)
	_pic.visible = true


func _close() -> void:
	if _pic:
		_pic.visible = false
	active = false
	_panel.visible = false
	get_tree().paused = false
	block_input()
	finished.emit()


func _process(delta: float) -> void:
	if not active:
		return
	# The box grows upward as text wraps, so it never covers the touch buttons.
	_panel.position.y = maxf(4.0, minf(BOX_Y, TouchControls.TOP_OF_CONTROLS - 6.0 - _panel.size.y))
	_process_input()
	if _typing:
		_shown += delta * 45.0
		var n := mini(int(_shown), _full.length())
		_text.text = _full.substr(0, n)
		if n >= _full.length():
			_typing = false
			_hint.visible = true


var _choice_opened := 0


func _process_input() -> void:
	# The press that opened the box must not also advance it.
	if Engine.get_process_frames() - _opened_frame < 2:
		return
	if _in_choice:
		var n := _choices.get_child_count()
		if n == 0:
			return
		# A tap meant to skip text must not also pick an answer (moving is fine).
		var settling := Engine.get_process_frames() - _choice_opened < 12
		if Input.is_action_just_pressed("down"):
			_choice_focus = (_choice_focus + 1) % n
			_refresh_focus()
		elif Input.is_action_just_pressed("up"):
			_choice_focus = (_choice_focus - 1 + n) % n
			_refresh_focus()
		elif settling:
			return
		elif InputSetup.confirm_pressed():
			(_choices.get_child(_choice_focus) as Button).pressed.emit()
		elif Input.is_action_just_pressed("b"):
			# B backs out when the last option is a way out.
			var last := _choices.get_child(n - 1) as Button
			var t := last.text.strip_edges().to_lower()
			for w in ["leave", "back", "←", "cancel", "never mind", "nevermind", "not now", "no thanks", "close", "done"]:
				if t.begins_with(w):
					last.pressed.emit()
					break
		return
	if InputSetup.confirm_pressed():
		_advance()


func _input(event: InputEvent) -> void:
	# Tapping the box itself (not the controls) also advances.
	if not active or _in_choice:
		return
	var pos := Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		pos = (event as InputEventMouseButton).position
	if pos != Vector2.INF and pos.y < TouchControls.TOP_OF_CONTROLS:
		_advance()
		get_viewport().set_input_as_handled()


func _advance() -> void:
	if _typing:
		_typing = false
		_text.text = _full
		_hint.visible = true
	else:
		_next()

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
	var map := {"light crystal": "light_crystal", "dark crystal": "dark_crystal", "the president": "president", "president": "president",
		"maple": "barnaby", "gideon": "greta", "wren": "wren", "mayor alder": "alder", "sal": "nico",
		"riley": "riley", "manny": "manny", "eli": "eli", "jax": "jax", "vex": "vex", "nico": "nico",
		"barnaby": "barnaby", "greta": "greta", "finn": "finn", "lumi": "lumi", "theo": "theo", "hazel": "hazel"}
	for k in GameState.npcs:
		map[str(GameState.npcs[k].get("name", "")).to_lower()] = str(GameState.npcs[k].get("portrait", k))
	return str(map.get(lower, ""))


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
	v.add_child(_choices)
	_hint = Label.new()
	_hint.text = "▼"
	_hint.add_theme_font_size_override("font_size", 8)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.modulate = Color(0.3, 0.2, 0.1, 0.8) if ink else Color(1, 1, 1, 0.6)
	v.add_child(_hint)


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
		c.queue_free()
	_in_choice = false
	if _queue.is_empty():
		_close()
		return
	var line: Dictionary = _queue.pop_front()
	_set_portrait(str(line.get("who", "")), str(line.get("mood", "neutral")))
	if line.has("choice"):
		_show_choice(line)
		return
	_who.text = str(line.get("who", ""))
	_who.visible = _who.text != ""
	_full = str(line.get("text", ""))
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
		b.custom_minimum_size = Vector2(0, 20)
		b.pressed.connect(func() -> void: _choose(key, i))
		_choices.add_child(b)
	_panel.size.y = BOX_H + opts.size() * 22
	# Keep the choices above the touch controls.
	_panel.position.y = minf(BOX_Y, TouchControls.TOP_OF_CONTROLS - _panel.size.y - 6)
	_refresh_focus()


func _refresh_focus() -> void:
	var i := 0
	for c in _choices.get_children():
		(c as Button).modulate = Color(1, 1, 0.7) if i == _choice_focus else Color(0.8, 0.8, 0.8)
		i += 1


func _choose(key: String, index: int) -> void:
	last_choice = index
	if key != "":
		GameState.run["decisions"][key] = index
	choice_made.emit(key, index)
	_next()


static func block_input(seconds := 0.25) -> void:
	block_until_ms = Time.get_ticks_msec() + int(seconds * 1000)


static func input_blocked() -> bool:
	return Time.get_ticks_msec() < block_until_ms


func _close() -> void:
	active = false
	_panel.visible = false
	get_tree().paused = false
	block_input()
	finished.emit()


func _process(delta: float) -> void:
	if not active:
		return
	_process_input()
	if _typing:
		_shown += delta * 45.0
		var n := mini(int(_shown), _full.length())
		_text.text = _full.substr(0, n)
		if n >= _full.length():
			_typing = false
			_hint.visible = true


func _process_input() -> void:
	# The press that opened the box must not also advance it.
	if Engine.get_process_frames() - _opened_frame < 2:
		return
	if _in_choice:
		var n := _choices.get_child_count()
		if n == 0:
			return
		if Input.is_action_just_pressed("down"):
			_choice_focus = (_choice_focus + 1) % n
			_refresh_focus()
		elif Input.is_action_just_pressed("up"):
			_choice_focus = (_choice_focus - 1 + n) % n
			_refresh_focus()
		elif InputSetup.confirm_pressed():
			(_choices.get_child(_choice_focus) as Button).pressed.emit()
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

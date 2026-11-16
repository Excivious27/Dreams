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
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.1, 0.92)
	sb.border_color = Color(0.9, 0.85, 0.6, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(6)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	_panel.add_child(v)
	_who = Label.new()
	_who.add_theme_font_size_override("font_size", 8)
	_who.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	v.add_child(_who)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 9)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(240, 34)
	v.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 2)
	v.add_child(_choices)
	_hint = Label.new()
	_hint.text = "▼"
	_hint.add_theme_font_size_override("font_size", 8)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.modulate = Color(1, 1, 1, 0.6)
	v.add_child(_hint)


func say(lines: Array) -> void:
	_queue.append_array(lines)
	if not active:
		active = true
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
		elif Input.is_action_just_pressed("a"):
			(_choices.get_child(_choice_focus) as Button).pressed.emit()
		return
	if Input.is_action_just_pressed("a"):
		_advance()


func _input(event: InputEvent) -> void:
	# Tapping the box itself (not the controls) also advances.
	if not active or _in_choice:
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		var pos := (event as InputEventScreenTouch).position
		if pos.y < TouchControls.TOP_OF_CONTROLS:
			_advance()
			get_viewport().set_input_as_handled()


func _advance() -> void:
	if _typing:
		_typing = false
		_text.text = _full
		_hint.visible = true
	else:
		_next()

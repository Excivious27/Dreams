class_name PadKeyboard
extends CanvasLayer
## S1 s1_08-01: the built-in on-screen keyboard for controller-only typing
## (Steam Deck without Steam's own keyboard, any desktop pad). Opened by
## TextEntry.open(field). D-pad/stick moves, A types the key, B deletes the
## last letter (closes when the text is empty), MENU is Done; keys can also be
## clicked or tapped. It reads the actions first each frame and releases them,
## so the screen underneath never sees those presses.

const ROWS := [
	["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
	["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
	["A", "S", "D", "F", "G", "H", "J", "K", "L", "-"],
	["Z", "X", "C", "V", "B", "N", "M", ".", ":", "/"],
	["SHIFT", "SPACE", "DEL", "DONE"],
]
const KEY_W := 24.0
const KEY_H := 24.0
const GAP := 2.0
const TOP := 250.0
const FONT := 11
const INK := Color(0.96, 0.93, 0.85)
const KEY_BG := Color(0.18, 0.16, 0.24)
const KEY_HI := Color(0.95, 0.78, 0.3)
const ACTIONS := ["up", "down", "left", "right", "a", "b", "menu", "action", "tool", "cycle_tool", "cycle_back"]

var field: Control
var buf := ""
var row := 1
var col := 0
var lower := false
var _arm := 2
var _panel: Control


func _init() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -250


func _ready() -> void:
	add_to_group("toast_hold")
	if field is LineEdit:
		buf = (field as LineEdit).text
	elif field is TextEdit:
		buf = (field as TextEdit).text
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_panel = Control.new()
	_panel.position = Vector2(0, 0)
	_panel.size = Vector2(270, 480)
	_panel.focus_mode = Control.FOCUS_ALL
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.draw.connect(_draw_panel)
	_panel.gui_input.connect(_gui)
	add_child(_panel)
	_panel.grab_focus.call_deferred()


func _exit_tree() -> void:
	TextEntry._closed(self)


func _row_keys(r: int) -> Array:
	return ROWS[r]


func key_rect(r: int, c: int) -> Rect2:
	var keys: Array = _row_keys(r)
	if r == ROWS.size() - 1:
		var widths := [48.0, 96.0, 48.0, 48.0]
		var x := (270.0 - (240.0 + GAP * 3)) / 2.0
		for i in c:
			x += widths[i] + GAP
		return Rect2(x, TOP + 30 + r * (KEY_H + GAP), widths[c], KEY_H)
	var w := keys.size() * KEY_W + (keys.size() - 1) * GAP
	var x0 := (270.0 - w) / 2.0
	return Rect2(x0 + c * (KEY_W + GAP), TOP + 30 + r * (KEY_H + GAP), KEY_W, KEY_H)


func label_of(r: int, c: int) -> String:
	var k := str(_row_keys(r)[c])
	if k.length() == 1 and lower:
		return k.to_lower()
	if k == "SHIFT":
		return "abc" if not lower else "ABC"
	return {"SPACE": "Space", "DEL": "Del", "DONE": "Done"}.get(k, k)


func max_len() -> int:
	if field is LineEdit and (field as LineEdit).max_length > 0:
		return (field as LineEdit).max_length
	return 512


## Act on a key (pad A, a click or a test).
func hit(r: int, c: int) -> void:
	var k := str(_row_keys(r)[c])
	match k:
		"SHIFT":
			lower = not lower
			_sfx("keypress")
		"SPACE":
			_type(" ")
		"DEL":
			buf = buf.substr(0, maxi(buf.length() - 1, 0))
			if is_inside_tree():
				Music.instance(get_tree()).sfx_pitched("keypress", "ui_tap", 0.85)  # c13_08-18
		"DONE":
			_sfx("j_confirm")
			finish(true)
			return
		_:
			_type(k.to_lower() if lower else k)
	_panel.queue_redraw()


func _type(ch: String) -> void:
	if buf.length() < max_len():
		buf += ch
		_sfx("keypress")
	else:
		_sfx("nope")  # the field is full


## c13_08-18: the controller keyboard sounds like every other pad screen.
func _sfx(n: String) -> void:
	if is_inside_tree():
		Music.instance(get_tree()).sfx(n, "ui_tap")


func finish(ok: bool) -> void:
	if ok and is_instance_valid(field):
		if field is LineEdit:
			var le := field as LineEdit
			le.text = buf
			le.caret_column = buf.length()
			le.text_changed.emit(buf)
		elif field is TextEdit:
			var te := field as TextEdit
			te.text = buf
			te.text_changed.emit()
	if is_instance_valid(field) and field.is_inside_tree():
		field.grab_focus.call_deferred()  # pad A on it reopens typing (TextEntry._input), never submits
	TextEntry._closed(self)
	queue_free()


func move(d: Vector2i) -> void:
	if d.y != 0:
		var frac := (col + 0.5) / float(_row_keys(row).size())
		row = clampi(row + d.y, 0, ROWS.size() - 1)
		col = clampi(int(frac * _row_keys(row).size()), 0, _row_keys(row).size() - 1)
	else:
		col = wrapi(col + d.x, 0, _row_keys(row).size())
	_sfx("scroll_tick")
	_panel.queue_redraw()


func _process(_d: float) -> void:
	if _arm > 0:
		_arm -= 1
		_eat()
		return
	if PadInput.nav_pressed("up"):
		move(Vector2i(0, -1))
	elif PadInput.nav_pressed("down"):
		move(Vector2i(0, 1))
	elif PadInput.nav_pressed("left"):
		move(Vector2i(-1, 0))
	elif PadInput.nav_pressed("right"):
		move(Vector2i(1, 0))
	if Input.is_action_just_pressed("a"):
		hit(row, col)
	elif Input.is_action_just_pressed("b"):
		if buf.is_empty():
			finish(false)
		else:
			buf = buf.substr(0, buf.length() - 1)
			_panel.queue_redraw()
	elif Input.is_action_just_pressed("menu"):
		finish(true)
	_eat()


## The screen underneath must not act on presses the keyboard used.
func _eat() -> void:
	for a: String in ACTIONS:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			Input.action_release(a)


func _gui(ev: InputEvent) -> void:
	_panel.accept_event()  # no Godot focus walk out of the keyboard
	var p := TapInput.press_pos(ev)
	if p == Vector2.INF:
		return
	for r in ROWS.size():
		for c in _row_keys(r).size():
			if key_rect(r, c).has_point(p):
				row = r
				col = c
				hit(r, c)
				return


func _draw_panel() -> void:
	var font := ThemeDB.fallback_font
	var title := "Type with the controller"
	_panel.draw_rect(Rect2(6, TOP - 34, 258, 30 + 30 + ROWS.size() * (KEY_H + GAP) + 26), Color(0.08, 0.07, 0.12, 0.96))
	_panel.draw_string(font, Vector2(12, TOP - 18), title, HORIZONTAL_ALIGNMENT_LEFT, 246, 10, INK)
	_panel.draw_rect(Rect2(12, TOP - 8, 246, 28), Color(0.02, 0.02, 0.04))
	var shown := buf + "_"
	_panel.draw_string(font, Vector2(16, TOP + 11), shown.right(30), HORIZONTAL_ALIGNMENT_LEFT, 238, 12, Color.WHITE)
	for r in ROWS.size():
		for c in _row_keys(r).size():
			var rc := key_rect(r, c)
			var on := r == row and c == col
			_panel.draw_rect(rc, KEY_HI if on else KEY_BG)
			var t := label_of(r, c)
			var col_t := Color(0.1, 0.08, 0.05) if on else INK
			_panel.draw_string(font, Vector2(rc.position.x, rc.position.y + 16), t, HORIZONTAL_ALIGNMENT_CENTER, rc.size.x, FONT if t.length() < 3 else 10, col_t)
	var hint := "%s type   %s delete   %s done" % [InputSetup.prompt("a"), InputSetup.prompt("b"), InputSetup.prompt("menu")]
	_panel.draw_string(font, Vector2(12, TOP + 30 + ROWS.size() * (KEY_H + GAP) + 14), hint, HORIZONTAL_ALIGNMENT_LEFT, 246, 9, Color(0.8, 0.78, 0.7))

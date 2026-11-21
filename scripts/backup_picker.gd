class_name BackupPicker
extends CanvasLayer
## S1 s1_08-07: controller-friendly stand-in for the OS file dialog (Steam Deck
## Gaming Mode can't drive the desktop file chooser with a pad). SaveTransfer
## uses it while a pad is the device or on the Deck: backups go to
## user://backups/ and this list picks one back, newest first. Up/down moves,
## A picks, B (or the last row, "Cancel") closes with done(""). Taps work too.
## Reads the actions first each frame and releases them (the screen below
## never sees them), like PadKeyboard.

const DIR := "user://backups"
const ROW_H := 22.0
const TOP := 120.0
const MAX_ROWS := 10
const ACTIONS := ["up", "down", "left", "right", "a", "b", "menu", "action", "tool"]

var done: Callable
var files: Array = []   # file names, newest first
var sel := 0
var _top := 0
var _arm := 2
var _panel: Control


static func list_files() -> Array:
	var out: Array = []
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.get_extension() in [SaveTransfer.FILE_EXT, "txt"]:
			out.append(f)
	out.sort_custom(func(a: String, b: String) -> bool:
		return FileAccess.get_modified_time(DIR + "/" + a) > FileAccess.get_modified_time(DIR + "/" + b))
	return out


static func open(host: Node, cb: Callable) -> BackupPicker:
	var p := BackupPicker.new()
	p.done = cb
	p.files = list_files()
	host.get_tree().root.add_child(p)
	return p


func _init() -> void:
	layer = 118
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -250


func _ready() -> void:
	add_to_group("toast_hold")
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_panel = Control.new()
	_panel.size = Vector2(270, 480)
	_panel.focus_mode = Control.FOCUS_ALL
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.draw.connect(_draw_panel)
	_panel.gui_input.connect(_gui)
	add_child(_panel)
	_panel.grab_focus.call_deferred()


func rows() -> int:
	return files.size() + 1  # + Cancel


func row_rect(i: int) -> Rect2:
	return Rect2(16, TOP + 30 + (i - _top) * (ROW_H + 2), 238, ROW_H)


func pick(i: int) -> void:
	var txt := ""
	if i >= 0 and i < files.size():
		txt = FileAccess.get_file_as_string(DIR + "/" + str(files[i]))
	queue_free()
	if done.is_valid():
		done.call(txt)


func _process(_d: float) -> void:
	if _arm > 0:
		_arm -= 1
		_eat()
		return
	if PadInput.nav_pressed("up"):
		sel = wrapi(sel - 1, 0, rows())
	elif PadInput.nav_pressed("down"):
		sel = wrapi(sel + 1, 0, rows())
	_top = clampi(_top, maxi(sel - MAX_ROWS + 1, 0), sel)
	if Input.is_action_just_pressed("a"):
		_eat()
		pick(sel)
		return
	if Input.is_action_just_pressed("b"):
		_eat()
		pick(-1)
		return
	_eat()
	_panel.queue_redraw()


func _eat() -> void:
	for a: String in ACTIONS:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			Input.action_release(a)


func _gui(ev: InputEvent) -> void:
	_panel.accept_event()
	var p := TapInput.press_pos(ev)
	if p == Vector2.INF:
		return
	for i in range(_top, mini(rows(), _top + MAX_ROWS)):
		if row_rect(i).has_point(p):
			pick(i if i < files.size() else -1)
			return


func _draw_panel() -> void:
	var font := ThemeDB.fallback_font
	var n := mini(rows() - _top, MAX_ROWS)
	_panel.draw_rect(Rect2(8, TOP - 4, 254, 40 + n * (ROW_H + 2) + 22), Color(0.08, 0.07, 0.12, 0.97))
	var title := "Load a backup" if not files.is_empty() else "No backups yet (Save to a file makes one)"
	_panel.draw_string(font, Vector2(16, TOP + 16), title, HORIZONTAL_ALIGNMENT_LEFT, 238, 11, Color(1, 0.92, 0.7))
	for i in range(_top, _top + n):
		var r := row_rect(i)
		var on := i == sel
		_panel.draw_rect(r, Color(0.95, 0.78, 0.3) if on else Color(0.18, 0.16, 0.24))
		var t := str(files[i]) if i < files.size() else "Cancel"
		_panel.draw_string(font, r.position + Vector2(6, 15), t, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 10, Color(0.1, 0.08, 0.05) if on else Color(0.95, 0.92, 0.85))
	var hint := "%s load   %s back" % [InputSetup.prompt("a"), InputSetup.prompt("b")]
	_panel.draw_string(font, Vector2(16, TOP + 30 + n * (ROW_H + 2) + 14), hint, HORIZONTAL_ALIGNMENT_LEFT, 238, 9, Color(0.8, 0.78, 0.7))

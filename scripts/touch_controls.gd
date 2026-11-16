class_name TouchControls
extends CanvasLayer
## On-screen D-pad plus A, B and MENU buttons. Multi-touch; slide your thumb
## around the D-pad to change direction (8-way). Presses the same input actions
## as the keyboard, so game code only reads actions.
## B: hold to run, or tap to toggle run on/off (shown on the button).

const DPAD_CENTER := Vector2(58, 408)
const DPAD_RADIUS := 40.0
const TOP_OF_CONTROLS := 352.0
const BUTTONS := {
	"a": {"pos": Vector2(234, 392), "r": 22.0, "label": "A"},
	"b": {"pos": Vector2(189, 432), "r": 20.0, "label": "B"},
	"menu": {"pos": Vector2(135, 463), "r": 13.0, "label": "MENU"},
}
const DIRS := {"left": Vector2.LEFT, "right": Vector2.RIGHT, "up": Vector2.UP, "down": Vector2.DOWN}

static var run_toggle := false

var _touches := {}  # touch index -> "dpad" or action name
var _dpad_dir := Vector2.ZERO
var _held := {}  # action -> true while held by touch
var _canvas: Control
var _b_down_at := 0.0
var _b_moved := false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_canvas.draw.connect(_on_draw)
	add_child(_canvas)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		release_all()


func _process(_delta: float) -> void:
	# Keep the B button lit when run mode is toggled on.
	_canvas.queue_redraw()


func release_all() -> void:
	for action: String in _held.keys():
		Input.action_release(action)
	_held.clear()
	_touches.clear()
	_dpad_dir = Vector2.ZERO
	if _canvas:
		_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			var hit := _hit(t.position)
			if hit == "":
				return
			_touches[t.index] = hit
			if hit == "dpad":
				_update_dpad(t.position)
			else:
				if hit == "b":
					_b_down_at = Time.get_ticks_msec() / 1000.0
					_b_moved = _dpad_dir != Vector2.ZERO
				_press(hit)
			get_viewport().set_input_as_handled()
		elif _touches.has(t.index):
			var what: String = _touches[t.index]
			_touches.erase(t.index)
			if what == "dpad":
				_set_dpad(Vector2.ZERO)
			else:
				if what == "b":
					var held_for := Time.get_ticks_msec() / 1000.0 - _b_down_at
					if held_for < 0.3 and (_b_moved or _dpad_dir != Vector2.ZERO):
						run_toggle = not run_toggle
				_release(what)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _touches.get(d.index, "") == "dpad":
			_update_dpad(d.position)
			get_viewport().set_input_as_handled()


func _hit(pos: Vector2) -> String:
	if pos.distance_to(DPAD_CENTER) <= DPAD_RADIUS * 1.5:
		return "dpad"
	for action: String in BUTTONS:
		var b: Dictionary = BUTTONS[action]
		if pos.distance_to(b["pos"]) <= float(b["r"]) * 1.4:
			return action
	return ""


func _update_dpad(pos: Vector2) -> void:
	var v := pos - DPAD_CENTER
	if v.length() < 7.0:
		_set_dpad(Vector2.ZERO)
		return
	var a := snappedf(v.angle(), PI / 4.0)
	var dir := Vector2(cos(a), sin(a))
	_set_dpad(Vector2(roundf(dir.x), roundf(dir.y)))


func _set_dpad(dir: Vector2) -> void:
	if dir == _dpad_dir:
		return
	_dpad_dir = dir
	for action: String in DIRS:
		var want := dir.dot(DIRS[action]) > 0.5
		if want and not _held.has(action):
			_press(action)
		elif not want and _held.has(action):
			_release(action)
	_canvas.queue_redraw()


func _press(action: String) -> void:
	_held[action] = true
	Input.action_press(action)
	_canvas.queue_redraw()


func _release(action: String) -> void:
	_held.erase(action)
	Input.action_release(action)
	_canvas.queue_redraw()


func _on_draw() -> void:
	var font := ThemeDB.fallback_font
	var base := Color(1, 1, 1, 0.16)
	var edge := Color(1, 1, 1, 0.45)
	var lit := Color(1, 1, 1, 0.5)
	# D-pad
	_canvas.draw_circle(DPAD_CENTER, DPAD_RADIUS, base)
	_canvas.draw_arc(DPAD_CENTER, DPAD_RADIUS, 0, TAU, 48, edge, 1.5, true)
	for action: String in DIRS:
		var d: Vector2 = DIRS[action]
		var c := DPAD_CENTER + d * DPAD_RADIUS * 0.62
		var tip := c + d * 7.0
		var side := d.orthogonal() * 7.0
		var col := lit if _held.has(action) else edge
		_canvas.draw_colored_polygon(PackedVector2Array([tip, c - d * 4.0 + side, c - d * 4.0 - side]), col)
	if _dpad_dir != Vector2.ZERO:
		_canvas.draw_circle(DPAD_CENTER + _dpad_dir.normalized() * DPAD_RADIUS * 0.35, 9.0, lit)
	# Buttons
	for action: String in BUTTONS:
		var b: Dictionary = BUTTONS[action]
		var p: Vector2 = b["pos"]
		var r := float(b["r"])
		var on := _held.has(action) or (action == "b" and run_toggle)
		_canvas.draw_circle(p, r, Color(1, 0.9, 0.5, 0.45) if (action == "b" and run_toggle) else (lit if on else base))
		_canvas.draw_arc(p, r, 0, TAU, 40, edge, 1.5, true)
		var size := 14 if r > 15.0 else 7
		var label := str(b["label"])
		if action == "b" and run_toggle:
			label = "RUN"
			size = 9
		_canvas.draw_string(font, p + Vector2(-r, size * 0.36), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, size, Color(1, 1, 1, 0.9))

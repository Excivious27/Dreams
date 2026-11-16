class_name TouchControls
extends CanvasLayer
## Stardew-mobile style touch controls:
##  - Floating joystick: touch and drag anywhere on the lower-left of the screen.
##    Push further to run. Analog 8-way steering.
##  - A quick tap (no drag) anywhere in the world walks there / uses what's there.
##  - Right side: USE (tool / sword / check), CHECK (talk, pick up, eat), MENU.
## Presses the same input actions as the keyboard, so game code only reads actions.

const TOP_OF_CONTROLS := 352.0
const BUTTONS := {
	"a": {"pos": Vector2(232, 398), "r": 24.0, "label": "USE"},
	"action": {"pos": Vector2(186, 438), "r": 18.0, "label": "CHECK"},
	"menu": {"pos": Vector2(237, 460), "r": 13.0, "label": "MENU"},
}
const DIRS := {"left": Vector2.LEFT, "right": Vector2.RIGHT, "up": Vector2.UP, "down": Vector2.DOWN}
const STICK_R := 34.0
const RUN_AT := 0.72
const TAP_MAX_T := 0.26
const TAP_MAX_D := 10.0

static var run_toggle := false
## False on desktop (a keyboard or mouse was used): the on-screen pad hides.
static var visible_controls := true

var _touches := {}  # touch index -> "stick" | "pending" | action name
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _stick_active := false
var _stick_vec := Vector2.ZERO
var _pending_at := Vector2.ZERO
var _pending_t := 0.0
var _held := {}  # action -> true while held by touch
var _canvas: Control
var _running := false


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
	_canvas.visible = visible_controls
	_canvas.queue_redraw()


func release_all() -> void:
	for action: String in _held.keys():
		Input.action_release(action)
	_held.clear()
	_touches.clear()
	_stick_active = false
	_stick_vec = Vector2.ZERO
	_running = false
	if _canvas:
		_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	# Desktop detection: a real key or mouse motion hides the pad; a real touch shows it.
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		visible_controls = false
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).relative != Vector2.ZERO and not DisplayServer.is_touchscreen_available():
		visible_controls = false
	elif event is InputEventScreenTouch and DisplayServer.is_touchscreen_available():
		visible_controls = true
	if not visible_controls:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			var hit := _hit(t.position)
			if hit != "":
				_touches[t.index] = hit
				_press(hit)
				get_viewport().set_input_as_handled()
				return
			if t.position.y < Hud.TOOLBAR_BOTTOM:
				return  # toolbar / clock: the HUD handles it
			if get_tree().paused or Dialogue.instance(get_tree()).active:
				return  # menus and dialogue take their own taps
			if _stick_active:
				return  # second finger while steering: let the world take it (tap on enemy etc.)
			# Could become a joystick drag or a tap: decide on release/drag.
			_touches[t.index] = "pending"
			_pending_at = t.position
			_pending_t = Time.get_ticks_msec() / 1000.0
			get_viewport().set_input_as_handled()
		elif _touches.has(t.index):
			var what: String = _touches[t.index]
			_touches.erase(t.index)
			if what == "stick":
				_end_stick()
			elif what == "pending":
				var held_for := Time.get_ticks_msec() / 1000.0 - _pending_t
				if held_for <= TAP_MAX_T:
					var m := get_tree().current_scene
					if m is GameMap:
						(m as GameMap).handle_tap(t.position)
			else:
				_release(what)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		var what: String = _touches.get(d.index, "")
		if what == "pending":
			if d.position.distance_to(_pending_at) > TAP_MAX_D:
				_touches[d.index] = "stick"
				_stick_origin = _pending_at
				_stick_active = true
				_update_stick(d.position)
			get_viewport().set_input_as_handled()
		elif what == "stick":
			_update_stick(d.position)
			get_viewport().set_input_as_handled()


func _hit(pos: Vector2) -> String:
	for action: String in BUTTONS:
		var b: Dictionary = BUTTONS[action]
		if pos.distance_to(b["pos"]) <= float(b["r"]) * 1.35:
			return action
	return ""


func _update_stick(pos: Vector2) -> void:
	var v := pos - _stick_origin
	# The stick base follows your thumb if you push well past its edge (floating).
	if v.length() > STICK_R * 1.6:
		_stick_origin = pos - v.normalized() * STICK_R * 1.6
		v = pos - _stick_origin
	_stick_pos = pos
	var mag := clampf(v.length() / STICK_R, 0.0, 1.0)
	if mag < 0.18:
		_set_vec(Vector2.ZERO, false)
		return
	# 8-way like Stardew's pad, but keep the analog magnitude for walk/run.
	var a := snappedf(v.angle(), PI / 4.0)
	var dir := Vector2(cos(a), sin(a)).normalized()
	_set_vec(dir, mag >= RUN_AT)


func _set_vec(dir: Vector2, running: bool) -> void:
	_stick_vec = dir
	for action: String in DIRS:
		var want := dir.dot(DIRS[action]) > 0.5
		if want and not _held.has(action):
			_press(action)
		elif not want and _held.has(action):
			_release(action)
	if running != _running:
		_running = running
		if running:
			_press("b")
		else:
			_release("b")
	_canvas.queue_redraw()


func _end_stick() -> void:
	_stick_active = false
	_set_vec(Vector2.ZERO, false)


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
	# Joystick: faint resting ring bottom-left until you touch; then it floats under your thumb.
	var origin := _stick_origin if _stick_active else Vector2(58, 412)
	_canvas.draw_circle(origin, STICK_R, base if not _stick_active else Color(1, 1, 1, 0.22))
	_canvas.draw_arc(origin, STICK_R, 0, TAU, 48, edge, 1.5, true)
	if _stick_active:
		var knob := origin + (_stick_pos - origin).limit_length(STICK_R)
		_canvas.draw_circle(knob, 13.0, Color(1, 1, 1, 0.6 if _running else 0.45))
		_canvas.draw_arc(knob, 13.0, 0, TAU, 32, Color(1, 1, 1, 0.8), 1.5, true)
	else:
		for action: String in DIRS:
			var d: Vector2 = DIRS[action]
			var c := origin + d * STICK_R * 0.62
			var tip := c + d * 6.0
			var side := d.orthogonal() * 6.0
			_canvas.draw_colored_polygon(PackedVector2Array([tip, c - d * 4.0 + side, c - d * 4.0 - side]), edge)
	# Buttons
	var btn := Art.tex("ui", "button")
	var btn_down := Art.tex("ui", "button_pressed")
	for action: String in BUTTONS:
		var b: Dictionary = BUTTONS[action]
		var p: Vector2 = b["pos"]
		var r := float(b["r"])
		var on := _held.has(action)
		if btn and btn_down:
			_canvas.draw_texture_rect(btn_down if on else btn, Rect2(p - Vector2(r, r), Vector2(r * 2, r * 2)), false, Color(1, 1, 1, 0.85))
		else:
			_canvas.draw_circle(p, r, lit if on else base)
			_canvas.draw_arc(p, r, 0, TAU, 40, edge, 1.5, true)
		var label := str(b["label"])
		var size := 9 if r > 20.0 else 7
		if action == "a":
			# Show what USE will do: the held tool's icon, or a sword.
			var held := GameState.held_tool() if not GameState.run.is_empty() else ""
			var icon := Art.tex("items", held if held != "" else "sword")
			if icon:
				_canvas.draw_texture_rect(icon, Rect2(p - Vector2(10, 14), Vector2(20, 20)), false)
				_canvas.draw_string(font, p + Vector2(-r, 15), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 7, Color(1, 1, 1, 0.9))
				continue
		_canvas.draw_string(font, p + Vector2(-r, size * 0.36), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, size, Color(1, 1, 1, 0.9))

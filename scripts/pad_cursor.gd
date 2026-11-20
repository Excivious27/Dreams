class_name PadCursor
extends CanvasLayer
## Virtual pointer for drawn screens and FOCUS_NONE button grids (C9 P1).
## A screen opts in by joining group "pad_cursor" while it is open (and
## leaving it on close). While a pad is the device and such a node is visible,
## the left stick / d-pad move an arrow and pad A sends a real mouse press and
## release there (and motion while held, so SlotDrag drags work). Installed
## by PadInput; PadCursor.sending is true around its own synthetic events.

const GROUP := "pad_cursor"
const SPEED := 190.0       ## px/s at full tilt (logical 270-wide view)
const FAST := 1.8          ## held stick past FAST_AT speeds up
const FAST_AT := 0.6       ## seconds held before FAST applies
const TIP := Color(1, 0.92, 0.55)

static var sending := false
static var pos := Vector2(135, 240)
static var _inst: PadCursor = null

var _canvas: Control
var _held := false
var _move_t := 0.0


static func instance() -> PadCursor:
	return _inst if _inst != null and is_instance_valid(_inst) else null


static func shown() -> bool:
	var c := instance()
	return c != null and c._canvas != null and c._canvas.visible


func _ready() -> void:
	_inst = self
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_meta("dm_skip", true)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_tip)
	_canvas.visible = false
	add_child(_canvas)


func _exit_tree() -> void:
	if _inst == self:
		_inst = null


## A screen in the group is on screen.
func _wanted() -> bool:
	for n in get_tree().get_nodes_in_group(GROUP):
		if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
			continue
		if n is CanvasLayer and not (n as CanvasLayer).visible:
			continue
		return true
	return false


func _process(delta: float) -> void:
	var on := PadInput.using_pad() and _wanted()
	if on != _canvas.visible:
		_canvas.visible = on
		if not on and _held:
			_click(false)
	if not on:
		return
	var v := Input.get_vector("left", "right", "up", "down")
	if v != Vector2.ZERO:
		_move_t += delta
		var sp := SPEED * (FAST if _move_t > FAST_AT else 1.0)
		var vs := get_viewport().get_visible_rect().size
		var np := (pos + v * sp * delta).clamp(Vector2.ZERO, vs - Vector2.ONE)
		if np != pos:
			var rel := np - pos
			pos = np
			_send_motion(rel)
			_canvas.queue_redraw()
	else:
		_move_t = 0.0
	if Input.is_action_just_pressed("a"):
		_click(true)
	elif _held and not Input.is_action_pressed("a"):
		_click(false)


func _window_pos() -> Vector2:
	return get_tree().root.get_final_transform() * pos


func _send_motion(rel: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = _window_pos()
	ev.global_position = ev.position
	ev.relative = rel
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if _held else 0
	sending = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()  # dispatch now, while `sending` marks it as ours
	sending = false


func _click(down: bool) -> void:
	_held = down
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = _window_pos()
	ev.global_position = ev.position
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	sending = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()  # dispatch now, while `sending` marks it as ours
	sending = false
	# A clicked FOCUS_ALL button keeps focus; the cursor is the selection here.
	var f := get_viewport().gui_get_focus_owner()
	if not down and f is BaseButton and not PadFocus.owns(f):
		f.release_focus()
	_canvas.queue_redraw()


func _draw_tip() -> void:
	var p := pos
	var pts := PackedVector2Array([p, p + Vector2(0, 11), p + Vector2(3, 8), p + Vector2(6, 13), p + Vector2(8, 12), p + Vector2(5, 7), p + Vector2(9, 7)])
	_canvas.draw_colored_polygon(pts, Color(0.9, 0.75, 0.3) if _held else TIP)
	pts.append(p)
	_canvas.draw_polyline(pts, Color(0.12, 0.08, 0.04), 1.0)

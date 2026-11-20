class_name SlotDrag
extends Node
## Tom (C6 P7): drag and drop for item slots (Items tab, ChestScreen).
## Each screen makes one SlotDrag child, calls clear() when it rebuilds its
## slots, and add(ctrl, payload, on_drop) for every slot (payload {} = a slot
## you can drop on but not lift, like an empty slot or the trash can).
##   * Phone: a long press (LONG s, finger still) lifts the item; it follows the
##     finger (drawn above it so it stays visible); lifting the finger over
##     another slot calls that slot's on_drop(payload_from). A finger that moves
##     before the long press is a scroll (ScrollContainer), never a drag.
##   * Desktop mouse: press and move MOUSE_MOVE px also lifts (or long press).
## While a drag is on, every ScrollContainer of the screen keeps its offset.
## on_lift(payload) (optional) runs when an item lifts (the screens use it to
## show the "picked" actions). After a drop the source button's own tap is
## swallowed (`eat_tap()` says so for SWALLOW_MS).

const LONG := 0.4
const MOVE_CANCEL := 8.0
const MOUSE_MOVE := 6.0
const SWALLOW_MS := 180

var on_lift: Callable
var on_drop_nowhere: Callable  ## dropped outside any slot (payload)
var _targets: Array = []  # [{ctrl, payload, drop}]
var _pending := {}  # {payload, at, t}
var dragging := {}  # payload while dragging
var _ghost: TextureRect
var _scrolls: Array = []  # [[ScrollContainer, v]]
var _swallow_until := 0
## Tests: drive the pointer without real input.
var test_pos := Vector2.INF
var test_down := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func clear() -> void:
	_targets.clear()


func add(ctrl: Control, payload: Dictionary, drop: Callable, tag := "") -> void:
	_targets.append({"ctrl": ctrl, "payload": payload, "drop": drop, "tag": tag})
	if not payload.is_empty() and ctrl is BaseButton:
		(ctrl as BaseButton).button_down.connect(func() -> void: begin(payload))


## The slot registered with this tag ("bag:3", "bar:0", "trash", "c:2"...), for tests.
func find(tag: String) -> Control:
	for t: Dictionary in _targets:
		if str(t["tag"]) == tag and is_instance_valid(t["ctrl"]):
			return t["ctrl"]
	return null


## The payload a tagged slot would lift ({} if none).
func payload_of(tag: String) -> Dictionary:
	for t: Dictionary in _targets:
		if str(t["tag"]) == tag:
			return t["payload"]
	return {}


## A press landed on a liftable slot (button_down; tests call it directly).
func begin(payload: Dictionary) -> void:
	if not dragging.is_empty():
		return
	_pending = {"payload": payload, "at": _pos(), "t": 0.0}


func eat_tap() -> bool:
	return Time.get_ticks_msec() < _swallow_until


func _pos() -> Vector2:
	if test_pos != Vector2.INF:
		return test_pos
	var p := get_parent()
	if p is CanvasItem:
		return (p as CanvasItem).get_global_mouse_position()
	if p is CanvasLayer:
		var vp := get_viewport()
		return (p as CanvasLayer).get_final_transform().affine_inverse() * vp.get_mouse_position()
	return get_viewport().get_mouse_position()


func _down() -> bool:
	if test_pos != Vector2.INF:
		return test_down
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _touch() -> bool:
	return DisplayServer.is_touchscreen_available() or TouchControls.visible_controls


func _process(delta: float) -> void:
	if pad_carry:
		return  # carried by the cursor: no pointer to follow or release
	if not dragging.is_empty():
		_hold_scrolls()
		if _ghost:
			_ghost.position = _pos() + Vector2(-12, -34)  # above the finger
		if not _down():
			_finish()
		return
	if _pending.is_empty():
		return
	if not _down():
		_pending = {}
		return
	_pending["t"] = float(_pending["t"]) + delta
	var moved := _pos().distance_to(_pending["at"])
	if moved > MOVE_CANCEL and _touch():
		_pending = {}  # a finger that moves is scrolling
		return
	if float(_pending["t"]) >= LONG or (moved > MOUSE_MOVE and not _touch()):
		_lift(_pending["payload"])
		_pending = {}


func _lift(payload: Dictionary) -> void:
	dragging = payload
	Haptics.buzz("press", true)  # a long-press lift is felt (the finger hides the slot, c10_13)
	_scrolls.clear()
	_find_scrolls(get_parent())
	var id := str(payload.get("id", ""))
	var tex := Art.tex("items", Hud.icon_for(id)) if id != "" else null
	if _ghost and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = TextureRect.new()
	_ghost.texture = tex
	_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ghost.size = Vector2(26, 26)
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.modulate = Color(1, 1, 1, 0.9)
	_ghost.z_index = 100
	_ghost.position = _pos() + Vector2(-12, -34)
	get_parent().add_child(_ghost)
	if get_tree():
		Music.instance(get_tree()).sfx("ui_tap", "pickup")
	if on_lift.is_valid():
		on_lift.call(payload)


func _finish() -> void:
	var payload := dragging
	dragging = {}
	if _ghost and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_swallow_until = Time.get_ticks_msec() + SWALLOW_MS
	var at := _pos()
	for t: Dictionary in _targets:
		var c: Variant = t["ctrl"]
		if not is_instance_valid(c) or not (c as Control).is_visible_in_tree():
			continue
		if (c as Control).get_global_rect().has_point(at):
			if t["payload"] == payload:
				if on_drop_nowhere.is_valid():
					on_drop_nowhere.call(payload)  # dropped back where it came from: stays picked
				return
			(t["drop"] as Callable).call(payload)
			return
	if on_drop_nowhere.is_valid():
		on_drop_nowhere.call(payload)


func _find_scrolls(n: Node) -> void:
	if n == null:
		return
	for c in n.get_children():
		if c is ScrollContainer:
			_scrolls.append([c, (c as ScrollContainer).scroll_vertical])
		_find_scrolls(c)


func _hold_scrolls() -> void:
	for s: Array in _scrolls:
		if is_instance_valid(s[0]):
			(s[0] as ScrollContainer).scroll_vertical = int(s[1])


# --- C9 P3: carry by pad / keyboard (no pointer) -------------------------------
# A screen with a cursor maps one button to "pick up / put down":
#   pad_lift(tag)   lifts the tagged slot's item (ghost over the slot, on_lift runs)
#   pad_hover(tag)  the cursor moved: the ghost follows to that slot
#   pad_drop(tag)   drops on that slot (its on_drop, like a finger let go there;
#                   on the slot it came from = on_drop_nowhere, it stays picked)
#   pad_cancel()    puts it back (on_drop_nowhere)
var pad_carry := false
const PAD_GHOST_OFF := Vector2(2, -12)  # the ghost floats just above the slot


func pad_lift(tag: String) -> bool:
	var pl := payload_of(tag)
	if pl.is_empty() or not dragging.is_empty():
		return false
	_pending = {}
	pad_carry = true
	_lift(pl)
	pad_hover(tag)
	return true


func pad_hover(tag: String) -> void:
	if not pad_carry or _ghost == null:
		return
	var c := find(tag)
	if c:
		_ghost.global_position = c.get_global_rect().position + PAD_GHOST_OFF


func pad_drop(tag: String) -> void:
	if not pad_carry:
		return
	var payload := dragging
	_end_pad()
	for t: Dictionary in _targets:
		if str(t["tag"]) == tag and is_instance_valid(t["ctrl"]):
			if t["payload"] == payload:
				break
			(t["drop"] as Callable).call(payload)
			return
	if on_drop_nowhere.is_valid():
		on_drop_nowhere.call(payload)


func pad_cancel() -> void:
	if not pad_carry:
		return
	var payload := dragging
	_end_pad()
	if on_drop_nowhere.is_valid():
		on_drop_nowhere.call(payload)


func _end_pad() -> void:
	pad_carry = false
	dragging = {}
	if _ghost and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_swallow_until = Time.get_ticks_msec() + SWALLOW_MS

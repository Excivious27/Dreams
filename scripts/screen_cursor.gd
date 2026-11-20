class_name ScreenCursor
extends Node
## CONDUCT 9 P3: a gamepad/keyboard cursor for the Button-built full-screen
## screens (ChestScreen, CraftScreen, the campaign list...). It walks the
## visible, enabled Buttons under `root` by the d-pad actions (spatially: the
## nearest button in that direction), draws a gold frame on the current one,
## and A ("a") presses it. Optional hooks per screen:
##   on_alt(ctrl)   CONFIRM_ALT action ("pick up / put down" in chests, Max in crafting)
##   on_tool(ctrl)  TOOL action (chest: cycle the move amount)
##   on_page(dir)   PAGE action (crafting: next category)
##   on_move(dir) -> bool   return true when the screen used the move itself
##   filter(ctrl) -> bool   false = skip this button
## It reads actions only (no joypad code): P1's bindings put every pad button on
## them. The frame shows after a key/pad press and hides on a touch or click, so
## phones never see it. Held directions repeat (Rep, below), also while paused.
## The cursor survives a screen rebuilding its buttons: give a button
## `set_meta("pc_key", "...")` (else its text is the key).

const CONFIRM := "a"
const CONFIRM_ALT := "action"
const TOOL := "tool"
const PAGE := "cycle_tool"
const DIRS := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}
const ARM_FRAMES := 8          ## the press that opened the screen doesn't act in it
const CONE := 0.5              ## min cos(angle) to count as "in that direction" (60 deg)
const SIDE_WEIGHT := 2.5       ## sideways distance counts this much more than forward
const FRAME_COL := Color(1, 0.85, 0.3)
const STICK_SHOW := 0.5        ## a stick pushed this far shows the cursor

## Last input was a pad (any ScreenCursor or a screen calling note() saw it).
static var pad_used := false

var root: Control
var enabled := true
var shown := false
var cur: Control
var cur_key := ""
var last_pos := Vector2(-1, -1)
var filter: Callable
var on_alt: Callable
var on_tool: Callable
var on_page: Callable
var on_move: Callable
var rep := Rep.new()
var _arm := 0
var _frame: Control


## Held-direction auto-repeat for lists (pads never echo): pressed(action, dt)
## is true on the press, then after DELAY held, then every RATE.
class Rep:
	const DELAY := 0.35
	const RATE := 0.09
	var _t := {}
	var _pf := {}  # the frame each press was taken (a second call that frame is "held")

	func pressed(action: String, dt: float) -> bool:
		if not InputMap.has_action(action):
			return false
		var f := Engine.get_process_frames()
		if Input.is_action_just_pressed(action) and int(_pf.get(action, -1)) != f:
			_t[action] = 0.0
			_pf[action] = f
			return true
		if not Input.is_action_pressed(action):
			_t.erase(action)
			return false
		var before := float(_t.get(action, 0.0))
		var now := before + dt
		_t[action] = now
		if now < DELAY:
			return false
		# Fire once each time the held clock crosses DELAY + k*RATE.
		var k0 := floori((before - DELAY) / RATE) if before >= DELAY else -1
		var k1 := floori((now - DELAY) / RATE)
		return k1 > k0


static func make(host: Node, root_ctrl: Control) -> ScreenCursor:
	var s := ScreenCursor.new()
	s.root = root_ctrl
	host.add_child(s)
	return s


## A pad is in use: P1's PadInput when it exists, else what we saw last.
static func pad_active() -> bool:
	if pad_used:
		return true
	for g: Dictionary in ProjectSettings.get_global_class_list():
		if str(g.get("class", "")) == "PadInput":
			var sc: Script = load(str(g["path"]))
			if sc and sc.has_method("using_pad"):
				return bool(sc.call("using_pad"))
	return pad_used


## Screens without a cursor (arcade decks, bowling) feed their input here.
static func note(ev: InputEvent) -> void:
	if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).pressed:
		pad_used = true
	elif ev is InputEventJoypadMotion and absf((ev as InputEventJoypadMotion).axis_value) > STICK_SHOW:
		pad_used = true
	elif ev is InputEventScreenTouch or (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed) or ev is InputEventKey:
		pad_used = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	shown = not TouchControls.visible_controls or pad_used
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.z_index = 50
	_frame.draw.connect(_draw_frame)
	get_parent().add_child.call_deferred(_frame)


func _exit_tree() -> void:
	if _frame and is_instance_valid(_frame):
		_frame.queue_free()


func _input(ev: InputEvent) -> void:
	note(ev)
	if ev is InputEventKey and (ev as InputEventKey).pressed:
		shown = true
	elif ev is InputEventJoypadButton and (ev as InputEventJoypadButton).pressed:
		shown = true
	elif ev is InputEventJoypadMotion and absf((ev as InputEventJoypadMotion).axis_value) > STICK_SHOW:
		shown = true
	elif ev is InputEventScreenTouch or (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed):
		shown = false


## Every button the cursor may land on, in tree order.
func items() -> Array:
	var out: Array = []
	if root and is_instance_valid(root):
		_collect(root, out)
	return out


func _collect(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is BaseButton:
			var b := c as BaseButton
			if b.is_visible_in_tree() and not b.disabled and not b.has_meta("pc_skip") and (not filter.is_valid() or bool(filter.call(b))):
				out.append(b)
		if c is Control and not (c as Control).visible:
			continue
		_collect(c, out)


func key_of(c: Control) -> String:
	if c.has_meta("pc_key"):
		return str(c.get_meta("pc_key"))
	if c is Button:
		return "t:" + (c as Button).text
	return str(c.get_path())


func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


## Put the cursor back on its button after the screen rebuilt its buttons.
func resync() -> void:
	if cur and is_instance_valid(cur) and cur.is_inside_tree() and not cur.is_queued_for_deletion() and cur in items():
		return
	cur = null
	var all := items()
	if all.is_empty():
		return
	for c: Control in all:
		if not c.is_queued_for_deletion() and key_of(c) == cur_key and cur_key != "":
			_place(c)
			return
	var best: Control = null
	var bd := INF
	for c: Control in all:
		if c.is_queued_for_deletion():
			continue
		var d := _center(c).distance_to(last_pos) if last_pos.x >= 0 else float(all.find(c))
		if d < bd:
			bd = d
			best = c
	if best:
		_place(best)


func select(c: Control) -> void:
	_place(c)


func select_key(k: String) -> bool:
	for c: Control in items():
		if key_of(c) == k and not c.is_queued_for_deletion():
			_place(c)
			return true
	return false


func _place(c: Control) -> void:
	cur = c
	cur_key = key_of(c)
	last_pos = _center(c)
	var p := c.get_parent()
	while p:
		if p is ScrollContainer:
			(p as ScrollContainer).ensure_control_visible(c)
			break
		p = p.get_parent()


## Step to the nearest button in a direction. Returns whether it moved.
func move(dir: Vector2) -> bool:
	resync()
	if cur == null:
		return false
	var p := _center(cur)
	var best: Control = null
	var bs := INF
	for c: Control in items():
		if c == cur or c.is_queued_for_deletion():
			continue
		var d := _center(c) - p
		var fwd := d.dot(dir)
		if fwd <= 1.0 or fwd < d.length() * CONE:
			continue
		var side := absf(d.dot(Vector2(-dir.y, dir.x)))
		var s := fwd + side * SIDE_WEIGHT
		if s < bs:
			bs = s
			best = c
	if best:
		_place(best)
		Music.instance(get_tree()).sfx("ui_tap", "")
		return true
	return false


func press() -> void:
	resync()
	if cur and cur is BaseButton and not (cur as BaseButton).disabled:
		(cur as BaseButton).pressed.emit()


func _process(delta: float) -> void:
	_arm += 1
	if _frame and is_instance_valid(_frame):
		_frame.queue_redraw()
	if not enabled or _arm < ARM_FRAMES:
		return
	var host := get_parent()
	if host is CanvasLayer and not (host as CanvasLayer).visible:
		return  # the screen is hidden under another one (crafting's hack game)
	for a: String in DIRS:
		if rep.pressed(a, delta):
			if not shown:
				shown = true
				resync()
				continue
			if on_move.is_valid() and bool(on_move.call(DIRS[a])):
				continue
			move(DIRS[a])
	if Input.is_action_just_pressed(CONFIRM) and shown:
		press()
	if InputMap.has_action(CONFIRM_ALT) and Input.is_action_just_pressed(CONFIRM_ALT) and on_alt.is_valid():
		resync()
		shown = true
		on_alt.call(cur)
	if InputMap.has_action(TOOL) and Input.is_action_just_pressed(TOOL) and on_tool.is_valid():
		resync()
		on_tool.call(cur)
	if InputMap.has_action(PAGE) and Input.is_action_just_pressed(PAGE) and on_page.is_valid():
		on_page.call(1)


func _draw_frame() -> void:
	if not shown or not enabled:
		return
	var host := get_parent()
	if host is CanvasLayer and not (host as CanvasLayer).visible:
		return
	resync()
	if cur == null or not is_instance_valid(cur) or not cur.is_visible_in_tree():
		return
	var r := cur.get_global_rect()
	# Only inside a ScrollContainer's view (a half-scrolled row draws clipped).
	var p := cur.get_parent()
	while p:
		if p is ScrollContainer:
			r = r.intersection((p as ScrollContainer).get_global_rect())
			break
		p = p.get_parent()
	if r.size.x <= 0 or r.size.y <= 0:
		return
	var inv := _frame.get_global_transform().affine_inverse()
	var lr := Rect2(inv * r.position, r.size)
	_frame.draw_rect(lr.grow(1), FRAME_COL, false, 2.0)

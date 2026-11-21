class_name PadInput
extends Node
## Controller service (C9 P1). Installed once under the root by
## InputSetup.ensure_actions (no autoload needed). Tracks which device the
## player is using ("touch" / "keys" / "pad"), the pad family for button names
## (xbox / ps / switch), hot-plug, held-direction auto-repeat for lists, the
## analog walk curve, and a rumble stub that Haptics (P4) can call.
##   PadInput.using_pad()          true while a controller is the last device
##   PadInput.device_kind()        "touch" | "keys" | "pad"
##   PadInput.nav_pressed(action)  just_pressed + auto-repeat while held
##   PadInput.shape(v)             stick vector -> walk vector (deadzone, curve)
##   PadInput.words(text)          "Tap USE" -> "Press A" on a pad
##   PadInput.rumble(weak, strong, secs)
## Screens that care connect to PadInput.instance().device_changed(kind).

signal device_changed(kind: String)

## Stick/trigger push that counts as "the pad is being used".
const WAKE_AXIS := 0.5
## Analog walk: below DEAD no move, then walking never slower than WALK_MIN of
## full speed, full speed from DEAD + SPAN of tilt; RUN_AT tilt runs.
const DEAD := 0.25
const SPAN := 0.6
const WALK_MIN := 0.55
const RUN_AT := 0.9
## List auto-repeat: first repeat after REPEAT_DELAY s, then every REPEAT_EVERY s.
const REPEAT_DELAY := 0.35
const REPEAT_EVERY := 0.09
const NAV := ["up", "down", "left", "right", "cycle_tool", "cycle_back"]
const TOAST_ON := "Controller connected."
const TOAST_OFF := "Controller disconnected: game paused."

static var active := false
static var kind := "xbox"
static var device := -1
static var last := "touch"  # last device: touch / keys / pad
static var _inst: PadInput = null
static var _held_t := {}    # action -> seconds held
static var _fire := {}      # action -> true on a repeat frame
static var _frame := -1


static func instance() -> PadInput:
	return _inst if _inst != null and is_instance_valid(_inst) else null


## Add the service under the root once (deferred: safe from _ready).
static func install() -> void:
	if instance() != null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_inst = PadInput.new()
	_inst.name = "PadInput"
	tree.root.add_child.call_deferred(_inst)


static func using_pad() -> bool:
	return active


static func device_kind() -> String:
	if active:
		return "pad"
	if TouchControls.visible_controls:
		return "touch"
	return "keys"


## The controller family from its name (button labels follow it).
static func kind_of(joy_name: String) -> String:
	var n := joy_name.to_lower()
	# S1 s1_08-02 / s1_08-09: the Deck's own pad, and under Steam Input every pad
	# is a "Steam Virtual Gamepad": ask SteamService for the real type first.
	var st := steam_kind()
	if st != "":
		return st
	if n.contains("steam deck") or ((n.contains("steam virtual") or n.contains("steam controller")) and DisplayMode.is_deck()):
		return "deck"
	if n.contains("ps4") or n.contains("ps5") or n.contains("dualsense") or n.contains("dualshock") or n.contains("playstation") or n.contains("wireless controller"):
		return "ps"
	if n.contains("nintendo") or n.contains("pro controller") or n.contains("joy-con") or n.contains("switch"):
		return "switch"
	return "xbox"


## Tests: the Steam Input type to pretend SteamService reported ("" = none).
static var steam_kind_force := ""


## The controller type Steam Input reports (deck/ps/switch/xbox), "" without Steam.
## Duck-typed: SteamService (S1 P1) is optional and never named as a class.
static func steam_kind() -> String:
	if steam_kind_force != "":
		return steam_kind_force
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or OS.has_feature("web"):
		return ""
	var ss := tree.root.get_node_or_null("SteamService")
	if ss != null and ss.has_method("input_type"):
		return str(ss.call("input_type", device))
	return ""


## S1 s1_08-04: a native desktop/Deck boot with a pad already connected starts
## in pad mode (no touch overlay, pad words), not touch mode. Web and phones
## keep the old behaviour (pad mode only after a button press).
static func boot_pad_mode() -> bool:
	return not OS.has_feature("web") and not DisplayMode.is_phone() and DisplayServer.get_name() != "headless" \
			and int(Settings.get_v("touch_ui")) != 1 and not Input.get_connected_joypads().is_empty()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(PadCursor.new())
	add_child(TextEntry.new())  # S1: pad typing (Steam keyboard / PadKeyboard)
	process_priority = -100  # repeat timers tick before screens read them
	Input.joy_connection_changed.connect(_on_joy)
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		device = int(pads[0])
		kind = kind_of(Input.get_joy_name(device))
		if boot_pad_mode():
			_set_active(true)
			TouchControls.visible_controls = false


func _exit_tree() -> void:
	if _inst == self:
		_inst = null


func _input(ev: InputEvent) -> void:
	note_event(ev, get_viewport())


## Switch the device on a real event (tests call it directly too).
static func note_event(ev: InputEvent, vp: Viewport = null) -> void:
	var pad := false
	if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).pressed:
		pad = true
	elif ev is InputEventJoypadMotion and absf((ev as InputEventJoypadMotion).axis_value) > WAKE_AXIS:
		pad = true
	if pad:
		if device != ev.device:
			device = ev.device
			kind = kind_of(Input.get_joy_name(device))
		_set_active(true)
		if int(Settings.get_v("touch_ui")) == 0:
			TouchControls.visible_controls = false
		# A Button that took focus from a tap must not catch pad A in the field
		# (only in open play: menus and screens keep whatever focus they set).
		var tree := vp.get_tree() if vp != null else null
		if vp != null and tree != null and tree.current_scene is GameMap and not tree.paused and not Hud.modal_rect.has_area():
			var f := vp.gui_get_focus_owner()
			if f != null and f is BaseButton and not PadFocus.owns(f):
				f.release_focus()
		return
	if ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
		last = "touch"
		_set_active(false)
	elif ev is InputEventKey and (ev as InputEventKey).pressed and not (ev as InputEventKey).echo:
		if active and keys_keep_pad():
			return
		last = "keys"
		_set_active(false)
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and ev.device != InputEvent.DEVICE_ID_EMULATION and not PadCursor.sending:
		if active and DisplayMode.is_deck():
			return  # S1 s1_08-03: the Deck's trackpad clicks as a mouse: keep pad prompts
		last = "keys"
		_set_active(false)


static func _set_active(on: bool) -> void:
	if on:
		last = "pad"
	if active == on:
		return
	active = on
	var mode := int(Settings.get_v("touch_ui"))
	if on and mode == 0:
		TouchControls.visible_controls = false
	elif not on and mode == 0 and last == "touch":
		TouchControls.visible_controls = true
	var inst := instance()
	if inst:
		inst.device_changed.emit(device_kind())


func _on_joy(dev: int, connected: bool) -> void:
	var tree := get_tree()
	if connected:
		device = dev
		kind = kind_of(Input.get_joy_name(dev))
		_toast(tree, TOAST_ON)
		return
	if dev != device:
		return
	_set_active(false)
	if not TouchControls.visible_controls and int(Settings.get_v("touch_ui")) == 0 and DisplayServer.is_touchscreen_available():
		TouchControls.visible_controls = true
	# The pad dropped mid-play: open the menu so nothing hits a player who can't move.
	var m := tree.current_scene
	if m is GameMap and not tree.paused:
		for ch in m.get_children():
			if ch is GameMenu and not (ch as GameMenu)._open:
				(ch as GameMenu).toggle()
	_toast(tree, TOAST_OFF)


static func _toast(tree: SceneTree, text: String) -> void:
	var m := tree.current_scene
	if m is GameMap and (m as GameMap).hud:
		(m as GameMap).hud.toast(text, Color(0.8, 0.95, 1))


func _process(delta: float) -> void:
	_frame = Engine.get_process_frames()
	_fire.clear()
	for a: String in NAV:
		if not InputMap.has_action(a) or not Input.is_action_pressed(a):
			_held_t.erase(a)
			continue
		var t0 := float(_held_t.get(a, 0.0))
		var t1 := t0 + delta
		_held_t[a] = t1
		if t0 < REPEAT_DELAY and t1 >= REPEAT_DELAY:
			_fire[a] = true
		elif t1 > REPEAT_DELAY and int((t1 - REPEAT_DELAY) / REPEAT_EVERY) != int((t0 - REPEAT_DELAY) / REPEAT_EVERY):
			_fire[a] = true


## True on the press, then repeating while held (lists, cursors, the hack pad).
static func nav_pressed(action: String) -> bool:
	if Input.is_action_just_pressed(action):
		return true
	return bool(_fire.get(action, false))


## Test hook: advance the repeat timers without a running service.
static func tick_repeat(delta: float) -> void:
	var inst := instance()
	if inst:
		inst._process(delta)


## Stick vector -> walk vector: no creep below DEAD, a real walk above it.
static func shape(v: Vector2) -> Vector2:
	if not active or v == Vector2.ZERO:
		return v
	var m := v.length()
	if m < DEAD:
		return Vector2.ZERO
	return v.normalized() * lerpf(WALK_MIN, 1.0, clampf((m - DEAD) / SPAN, 0.0, 1.0))


## A full stick tilt runs on a pad (B is "back" there).
static func wants_run(raw: Vector2) -> bool:
	return active and raw.length() >= RUN_AT


## Touch words -> the pad's buttons ("Tap USE" -> "Press A") or keys.
static func words(text: String) -> String:
	var dev := device_kind()
	if dev == "touch":
		return text
	var t := text
	for pair: Array in [["USE", "a"], ["CHECK", "action"], ["MENU", "menu"], ["ROLL", "dodge"], ["CALL", "pup"]]:
		t = t.replace(" " + str(pair[0]), " " + InputSetup.prompt(str(pair[1])))
		if t.begins_with(str(pair[0])):
			t = InputSetup.prompt(str(pair[1])) + t.substr(str(pair[0]).length())
	t = t.replace("Tap ", "Press ").replace("tap ", "press ").replace("Hold USE", "Hold " + InputSetup.prompt("a"))
	return t


## S1 s1_08-03: keys typed by Steam's on-screen keyboard (or our own pad
## keyboard) while a text field is open never flip prompts to keyboard keys.
static func keys_keep_pad() -> bool:
	return TextEntry.is_open()


## Controller rumble (P4's Haptics calls this; no-op without a pad).
static func rumble(weak: float, strong: float, secs: float) -> void:
	if not active or device < 0:
		return
	Input.start_joy_vibration(device, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), maxf(secs, 0.0))

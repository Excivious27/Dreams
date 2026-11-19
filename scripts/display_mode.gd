class_name DisplayMode
extends Node
## Desktop / full-screen play (CONDUCT 2, P8). Autoload "DisplayModeSvc".
##
## Phones (and any portrait window) keep the original 270x480 portrait view
## exactly as before. On a computer with a landscape window the logical view
## widens instead of letterboxing: height stays 480, width follows the window
## (up to MAX_W; beyond that thin bars). The world camera shows more of the map,
## the HUD spreads to the screen edges (Hud), and every other CanvasLayer (menus,
## dialogue, full-screen panels; all laid out for 270 px) is centred in a 270-px
## column (`cx`). While a full-screen panel or the menu is open, dark side
## curtains cover the world beside the column.
##
## Fullscreen: F11 or Alt+Enter (and Menu > Options); the web build asks the
## browser for fullscreen on the first click when the Fullscreen setting is on.
## On-screen touch controls: hidden on desktop unless Options > Touch buttons is
## "on" (setting touch_ui: 0 auto, 1 always, 2 never).

signal changed

const BASE := Vector2(270, 480)
const MAX_W := 960.0
## Layers that lay themselves out against the whole view (or follow the camera).
const SKIP_CLASSES := ["Hud", "TouchControls", "Scenery", "NightGlow", "RecGlow"]

## The logical view size (BASE on phones and portrait windows).
static var view := BASE
## Left edge of the centred 270-px UI column.
static var cx := 0.0
## Tests: -1 auto, 0 force phone, 1 force desktop.
static var force := -1
## Tests: pretend the window is this size (headless can't resize a window).
static var test_size := Vector2i.ZERO
static var _svc: DisplayMode = null

var _curtain: CanvasLayer
var _sides: Array = []
var _last_size := Vector2i.ZERO
var _web_fs_armed := false


static func is_phone() -> bool:
	if force >= 0:
		return force == 0
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("android") or OS.has_feature("ios")


## True when the view is wider than the phone's 270 px.
static func wide() -> bool:
	return view.x > BASE.x + 0.5


## Screen point (viewport coords) -> point in the centred 270-px column.
static func ui(p: Vector2) -> Vector2:
	return p - Vector2(cx, 0)


## Extra width on the right of a 270-px layout (HUD clock box, energy bar).
static func extra() -> float:
	return view.x - BASE.x


## The view width the camera should frame.
static func view_w() -> float:
	return view.x


static func svc() -> DisplayMode:
	return _svc


## Tests: refit now (after setting force / test_size).
static func refit() -> void:
	if _svc:
		_svc._refit()
		if force >= 0:
			TouchControls.visible_controls = force == 0 or int(Settings.get_v("touch_ui")) == 1


func _ready() -> void:
	_svc = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	get_tree().root.size_changed.connect(_refit)
	_curtain = CanvasLayer.new()
	_curtain.layer = 89  # under the toasts (90), over the world, HUD and every panel's sides
	_curtain.process_mode = Node.PROCESS_MODE_ALWAYS
	_curtain.set_meta("dm_skip", true)
	add_child(_curtain)
	for i in 2:
		var r := ColorRect.new()
		r.color = Color(0.05, 0.04, 0.08, 0.82)  # the paused world shows faintly beside the panel
		r.mouse_filter = Control.MOUSE_FILTER_STOP  # clicks beside a panel don't reach the world
		r.visible = false
		_curtain.add_child(r)
		_sides.append(r)
	if not is_phone() and DisplayServer.get_name() != "headless" and not _tool_run():
		# Desktop: no on-screen pad unless asked for.
		TouchControls.visible_controls = int(Settings.get_v("touch_ui")) == 1
		if not OS.has_feature("web") and force < 0:
			_desktop_window()
	elif int(Settings.get_v("touch_ui")) == 2:
		TouchControls.visible_controls = false
	_refit()


## Test/shot tools (-s script, or a forced --resolution) keep the window they asked for.
static func _tool_run() -> bool:
	var a := OS.get_cmdline_args()
	return a.has("-s") or a.has("--script") or a.has("--resolution")


## Native desktop runs open in a landscape window (the project's window override
## is the phone's portrait 540x960), or fullscreen if that was chosen last time.
func _desktop_window() -> void:
	var w := get_window()
	if bool(Settings.get_v("fullscreen")):
		w.mode = Window.MODE_FULLSCREEN
		return
	var scr := DisplayServer.screen_get_usable_rect(w.current_screen)
	if scr.size.x <= 0:
		return
	var sz := Vector2i(1280, 720)
	while sz.x > scr.size.x * 0.92 or sz.y > scr.size.y * 0.92:
		sz = Vector2i(int(sz.x * 0.85), int(sz.y * 0.85))
	w.size = sz
	w.position = scr.position + (scr.size - sz) / 2


## Window size in pixels (tests may resize the root viewport instead).
func _win_size() -> Vector2i:
	if test_size != Vector2i.ZERO:
		return test_size
	var w := get_window()
	var s := w.size
	if s.x <= 0 or s.y <= 0:
		s = Vector2i(get_tree().root.size)
	return s


func _refit() -> void:
	var s := _win_size()
	var root := get_tree().root
	var nv := BASE
	if not is_phone() and s.x > 0 and s.y > 0 and float(s.x) / float(s.y) > BASE.x / BASE.y + 0.01:
		nv = Vector2(clampf(roundf(BASE.y * float(s.x) / float(s.y)), BASE.x, MAX_W), BASE.y)
	if force == 0:
		nv = BASE
	_last_size = s
	var was := view
	view = nv
	cx = floorf((view.x - BASE.x) / 2.0)
	root.content_scale_size = Vector2i(int(view.x), int(view.y))
	for i in 2:
		var r: ColorRect = _sides[i]
		r.position = Vector2(0.0 if i == 0 else cx + BASE.x, 0)
		r.size = Vector2(cx if i == 0 else view.x - cx - BASE.x, view.y)
	_recenter(root)
	if was != view:
		changed.emit()


func _recenter(n: Node) -> void:
	for c in n.get_children():
		if c is CanvasLayer:
			_place(c as CanvasLayer)
		if c is Window:
			continue
		_recenter(c)


func _skip(l: CanvasLayer) -> bool:
	if l.has_meta("dm_skip") or l.follow_viewport_enabled:
		return true
	var s := l.get_script() as Script
	if s and s.get_global_name() in SKIP_CLASSES:
		return true
	var p := l.get_parent()
	return p is CanvasLayer and _skip(p as CanvasLayer)  # Hud's own toast layer


func _place(l: CanvasLayer) -> void:
	if _skip(l):
		return
	l.offset.x = cx
	if not l.has_meta("dm_hooked"):
		l.set_meta("dm_hooked", true)
		l.child_entered_tree.connect(func(ch: Node) -> void: _pin.call_deferred(ch))
		for ch in l.get_children():
			_pin.call_deferred(ch)


## A Control anchored to the view (full rect, right edge, centre) under a centred
## layer: re-anchor it to the 270-px column so it lays out exactly as on a phone.
func _pin(ch: Node) -> void:
	if not is_instance_valid(ch) or not (ch is Control) or ch.has_meta("dm_pinned"):
		return
	var c := ch as Control
	c.set_meta("dm_pinned", true)
	if c.anchor_left == 0.0 and c.anchor_right == 0.0:
		return
	var ol := c.offset_left + c.anchor_left * BASE.x
	var orr := c.offset_right + c.anchor_right * BASE.x
	c.anchor_left = 0.0
	c.anchor_right = 0.0
	c.offset_left = ol
	c.offset_right = orr


func _on_node_added(n: Node) -> void:
	if n is CanvasLayer:
		_place.call_deferred(n)


func _process(_d: float) -> void:
	var s := _win_size()
	if s != _last_size:
		_refit()
	var on := wide() and _modal_open()
	for r: ColorRect in _sides:
		r.visible = on


## A full-screen panel (Hud.modal_rect), the game menu or a pausing UI is up.
func _modal_open() -> bool:
	if Hud.modal_rect.has_area():
		return true
	var sc := get_tree().current_scene
	if sc == null:
		return false
	for c in sc.get_children():
		if c is GameMenu and (c as GameMenu)._open:
			return true
	return false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var k := event as InputEventKey
		if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed) or (k.keycode == KEY_KP_ENTER and k.alt_pressed):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and OS.has_feature("web") and not is_phone():
		# Browsers only allow fullscreen from a click: ask once, on the first one.
		if not _web_fs_armed and bool(Settings.get_v("fullscreen")):
			_web_fs_armed = true
			set_fullscreen(true)


static func is_fullscreen() -> bool:
	if _svc == null:
		return false
	var m := _svc.get_window().mode
	return m == Window.MODE_FULLSCREEN or m == Window.MODE_EXCLUSIVE_FULLSCREEN


static func set_fullscreen(on: bool) -> void:
	Settings.set_v("fullscreen", on)
	if _svc == null or DisplayServer.get_name() == "headless":
		return
	var w := _svc.get_window()
	if on:
		w.mode = Window.MODE_FULLSCREEN
	else:
		w.mode = Window.MODE_WINDOWED
		if not OS.has_feature("web") and not is_phone():
			_svc._desktop_window.call_deferred()
	_svc._refit.call_deferred()


static func toggle_fullscreen() -> void:
	set_fullscreen(not is_fullscreen())


## Options > Touch buttons: auto (shown on phones, hidden on computers), on, off.
static func touch_mode_name() -> String:
	return ["auto", "on", "off"][clampi(int(Settings.get_v("touch_ui")), 0, 2)]


static func cycle_touch_mode() -> void:
	var m := (int(Settings.get_v("touch_ui")) + 1) % 3
	Settings.set_v("touch_ui", m)
	if m == 1:
		TouchControls.visible_controls = true
	elif m == 2:
		TouchControls.visible_controls = false
	else:
		TouchControls.visible_controls = is_phone() or DisplayServer.is_touchscreen_available()

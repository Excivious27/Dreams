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
## S1 s1_10-06: the native window never shrinks below this (the 270 column stays >= 1x).
const MIN_WIN := Vector2i(540, 480)
## Options > Frame rate cap choices (0 = no cap). Physics runs at 60, so 30/60/120 only.
const FPS_CAPS := [0, 30, 60, 120]
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
var _dim: ColorRect  # C5 c5_13 #7: the column behind the game menu dims too (desktop)
var _last_size := Vector2i.ZERO
var _web_fs_armed := false
var _was_fs := false
var _back_t := 0
var _tap_release: Array = []   # actions pressed by _tap, released next frame
## Native: the game lost focus or the app was suspended (Deck overlay, alt-tab).
signal app_backgrounded


static func is_phone() -> bool:
	if force >= 0:
		return force == 0
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("android") or OS.has_feature("ios")


## Steam Deck (or a gamescope / SteamOS session). S1 s1_10-02: never guessed
## from the screen size any more (a 1080p laptop at 150% reported 1280x720 and
## was forced fullscreen with touch buttons). Tests set deck_force (0/1).
static var deck_force := -1


static func is_deck() -> bool:
	if deck_force >= 0:
		return deck_force == 1
	if force >= 0 or OS.has_feature("web"):
		return false
	if _deck_env < 0:
		_deck_env = 1 if (OS.get_environment("SteamDeck") == "1" or OS.get_environment("SteamOS") == "1" \
				or OS.get_environment("XDG_CURRENT_DESKTOP").to_lower() == "gamescope") else 0
	return _deck_env == 1


static var _deck_env := -1


## Native desktop build (Windows/Linux/macOS window), not web, not a phone.
## Desktop-only options (window, VSync, frame cap) show only here.
static var desktop_force := -1


static func native_desktop() -> bool:
	if desktop_force >= 0:
		return desktop_force == 1
	return not OS.has_feature("web") and not is_phone() and DisplayServer.get_name() != "headless"


## S1 s1_07-01/03: Valve's Deck rule, no character under 9 px tall at 1280x800.
## The 480-tall view scales by window_h/480 (1.667 on the Deck), and a glyph's
## cap height is 0.714 of the font size, so size 7 is 8.3 px there: too small.
const DECK_CAP_PX := 9.0
const CAP_RATIO := 0.714


## The smallest font size that meets the Deck floor at the current scale (0 off
## the Deck: phones and desktops keep their sizes exactly).
static func deck_min_font() -> int:
	if not is_deck():
		return 0
	var h := 800.0
	if _svc != null and DisplayServer.get_name() != "headless" and test_size == Vector2i.ZERO:
		h = float(_svc._win_size().y)
	elif test_size != Vector2i.ZERO:
		h = float(test_size.y)
	var k := maxf(h / BASE.y, 0.1)
	return int(ceilf(DECK_CAP_PX / (k * CAP_RATIO) - 0.001))


## Drawn text size through the Deck floor (draw_string sizes 5-7 use this).
static func df(fs: int) -> int:
	return maxi(fs, deck_min_font())


## Controls (Label, Button, LineEdit, RichTextLabel...) added on the Deck get
## their font size raised to the floor (a runtime clamp, no per-screen edits).
func _deck_clamp(n: Node) -> void:
	if not is_instance_valid(n) or not (n is Control):
		return
	var mf := deck_min_font()
	if mf <= 0:
		return
	var c := n as Control
	if c is RichTextLabel:
		for key: String in ["normal_font_size", "bold_font_size", "italics_font_size", "mono_font_size"]:
			if c.get_theme_font_size(key) < mf:
				c.add_theme_font_size_override(key, mf)
	elif c is Label or c is Button or c is LineEdit or c is TextEdit or c is OptionButton:
		if c.get_theme_font_size("font_size") < mf:
			c.add_theme_font_size_override("font_size", mf)


## Touch buttons on "auto": phones, the Deck and any touchscreen computer show them.
static func touch_auto() -> bool:
	return is_phone() or is_deck() or DisplayServer.is_touchscreen_available()


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
	var dl := CanvasLayer.new()
	dl.layer = 8  # over the HUD (5), under the game menu (9)
	dl.process_mode = Node.PROCESS_MODE_ALWAYS
	dl.set_meta("dm_skip", true)
	add_child(dl)
	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.04, 0.08, 0.55)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	dl.add_child(_dim)
	if not is_phone() and DisplayServer.get_name() != "headless" and not _tool_run():
		# Desktop: no on-screen pad unless asked for (or a touchscreen / Deck on auto).
		var tm := int(Settings.get_v("touch_ui"))
		TouchControls.visible_controls = tm == 1 or (tm == 0 and touch_auto())
		if not OS.has_feature("web") and force < 0:
			_desktop_window(true)
			get_window().min_size = MIN_WIN
			apply_frame_settings()
	elif int(Settings.get_v("touch_ui")) == 2:
		TouchControls.visible_controls = false
	_refit()


## Test/shot tools (-s script, or a forced --resolution) keep the window they asked for.
static func _tool_run() -> bool:
	var a := OS.get_cmdline_args()
	return a.has("-s") or a.has("--script") or a.has("--resolution")


## Native desktop runs open in a landscape window (the project's window override
## is the phone's portrait 540x960), or fullscreen if that was chosen last time.
func _desktop_window(startup := false) -> void:
	var w := get_window()
	# Handhelds (Deck) start fullscreen at the panel's native 16:10 size, never a shrunken 16:9 window.
	if bool(Settings.get_v("fullscreen")) or (startup and is_deck()):
		w.mode = Window.MODE_FULLSCREEN
		return
	if _restore_window(w):
		return
	var scr := DisplayServer.screen_get_usable_rect(w.current_screen)
	if scr.size.x <= 0:
		return
	var sz := Vector2i(1280, 720)
	# S1 s1_10-01: hi-DPI aware now (allow_hidpi.pc), so a 150% Windows screen gets a 150% window.
	var dpi_k := clampf(float(DisplayServer.screen_get_dpi(w.current_screen)) / 96.0, 1.0, 2.0)
	if dpi_k > 1.05:
		sz = Vector2i(int(sz.x * dpi_k), int(sz.y * dpi_k))
	while sz.x > scr.size.x * 0.92 or sz.y > scr.size.y * 0.92:
		sz = Vector2i(int(sz.x * 0.85), int(sz.y * 0.85))
	w.size = sz
	w.position = scr.position + (scr.size - sz) / 2


## S1 s1_10-05: the windowed size, position and monitor come back next launch
## (Settings win_rect [x, y, w, h]), if that spot is still on a connected screen.
func _restore_window(w: Window) -> bool:
	var r: Variant = Settings.get_v("win_rect")
	if not (r is Array) or (r as Array).size() != 4:
		return false
	var rect := Rect2i(int(r[0]), int(r[1]), maxi(int(r[2]), MIN_WIN.x), maxi(int(r[3]), MIN_WIN.y))
	if not window_rect_ok(rect):
		return false
	w.size = rect.size
	w.position = rect.position
	return true


## A saved window rect is usable when its centre sits on a connected screen.
static func window_rect_ok(rect: Rect2i) -> bool:
	if rect.size.x < MIN_WIN.x or rect.size.y < MIN_WIN.y:
		return false
	if DisplayServer.get_name() == "headless":
		return true
	for i in DisplayServer.get_screen_count():
		if DisplayServer.screen_get_usable_rect(i).has_point(rect.get_center()):
			return true
	return false


var _win_save_t := 0.0
var _win_saved := Rect2i()


## Remember the windowed rect (checked about once a second, written on change).
func _track_window(d: float) -> void:
	if not native_desktop() or _tool_run() or force >= 0:
		return
	_win_save_t += d
	if _win_save_t < 1.0:
		return
	_win_save_t = 0.0
	var w := get_window()
	if w.mode != Window.MODE_WINDOWED:
		return
	var rect := Rect2i(w.position, w.size)
	if rect != _win_saved and rect.size.x >= MIN_WIN.x and rect.size.y >= MIN_WIN.y:
		_win_saved = rect
		Settings.set_v("win_rect", [rect.position.x, rect.position.y, rect.size.x, rect.size.y])


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
	var k_int := pixel_scale(s)
	if not is_phone() and s.x > 0 and s.y > 0 and float(s.x) / float(s.y) > BASE.x / BASE.y + 0.01:
		nv = Vector2(clampf(roundf(BASE.y * float(s.x) / float(s.y)), BASE.x, MAX_W), BASE.y)
		if k_int > 0:
			# Pixel-perfect: whole-number scale, so the view takes the width that scale allows.
			nv.x = clampf(floorf(float(s.x) / float(k_int)), BASE.x, MAX_W)
	# Headless runs (tests, bots) have no real window: the phone view unless a test forces desktop.
	if force == 0 or (force < 0 and DisplayServer.get_name() == "headless"):
		nv = BASE
	_last_size = s
	var was := view
	view = nv
	cx = floorf((view.x - BASE.x) / 2.0)
	root.content_scale_size = Vector2i(int(view.x), int(view.y))
	root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if k_int > 0 else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	for i in 2:
		var r: ColorRect = _sides[i]
		r.position = Vector2(0.0 if i == 0 else cx + BASE.x, 0)
		r.size = Vector2(cx if i == 0 else view.x - cx - BASE.x, view.y)
	if _dim:
		_dim.position = Vector2(cx, 0)
		_dim.size = BASE
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
	elif n is Control and is_deck():
		_deck_clamp.call_deferred(n)


func _process(_d: float) -> void:
	PlayClock.tick(_d, get_tree().paused)
	_track_window(_d)
	for a: String in _tap_release:
		Input.action_release(a)
	_tap_release.clear()
	if OS.has_feature("web") and DisplayServer.get_name() != "headless":
		_web_tick()
	var s := _win_size()
	if s != _last_size:
		_refit()
	var on := wide() and _modal_open()
	for r: ColorRect in _sides:
		r.visible = on
	if _dim:
		_dim.visible = on and _menu_open()


func _menu_open() -> bool:
	var sc := get_tree().current_scene
	if sc == null:
		return false
	for c in sc.get_children():
		if c is GameMenu and (c as GameMenu)._open:
			return true
	return false


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
			release_actions_for(event)
			toggle_fullscreen()
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_TAB and k.alt_pressed:
			release_actions_for(event)  # alt-tabbing away must not switch the tool
			get_viewport().set_input_as_handled()
	elif _first_press(event) and OS.has_feature("web") and (not is_phone() or OS.has_feature("web_android")):
		# Browsers only allow fullscreen from a click or tap: ask once, on the first one.
		if not _web_fs_armed and bool(Settings.get_v("fullscreen")) and not web_standalone():
			_web_fs_armed = true
			set_fullscreen(true)
	_cursor_follow(event)


## S1 s1_10-12: Input has already turned Alt+Enter into a press of "a" (Enter)
## before _input runs, and every screen polls is_action_just_pressed: release
## every action the shortcut matched so it confirms nothing.
static func release_actions_for(event: InputEvent) -> void:
	for a: StringName in InputMap.get_actions():
		if not str(a).begins_with("ui_") and InputMap.event_is_action(event, a) and Input.is_action_pressed(a):
			Input.action_release(a)


static func _first_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


## Native computers: the mouse cursor hides while playing by touch or pad and
## comes back when the mouse really moves.
func _cursor_follow(event: InputEvent) -> void:
	if OS.has_feature("web") or is_phone() or DisplayServer.get_name() == "headless":
		return
	if event is InputEventJoypadButton or event is InputEventScreenTouch \
			or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5):
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 2.0:
		if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Running as the installed home-screen app (no browser bars to hide).
static func web_standalone() -> bool:
	if not OS.has_feature("web"):
		return false
	var r: Variant = JavaScriptBridge.eval("window.dreamsStandalone===true", true)
	return r == true


## Press an action for one frame (Android back, focus-loss pause).
func _tap(action: String) -> void:
	if not InputMap.has_action(action):
		return
	Input.action_press(action)
	_tap_release.append(action)


## The back gesture/button closes what is open, else opens the menu. Returns the action used.
func back_pressed() -> String:
	var a := "b" if (get_tree().paused or Hud.modal_rect.has_area()) else "menu"
	_tap(a)
	return a


func _web_tick() -> void:
	# Leaving fullscreen with the browser's Esc writes the setting back.
	var fs := is_fullscreen()
	if _was_fs and not fs and bool(Settings.get_v("fullscreen")):
		Settings.set_v("fullscreen", false)
	_was_fs = fs
	# Android back (web/head_include.html keeps a history entry and counts presses).
	_back_t += 1
	if _back_t % 6 != 0:
		return
	var n: Variant = JavaScriptBridge.eval("(function(){var n=window.dreamsBack|0;window.dreamsBack=0;return n;})()", true)
	if n != null and int(n) > 0:
		back_pressed()


## Native: pause into the menu when the game loses focus or is suspended
## (Deck Quick Access, alt-tab, a phone call on Android), like Stardew.
func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT and what != NOTIFICATION_APPLICATION_PAUSED:
		return
	if OS.has_feature("web") or DisplayServer.get_name() == "headless" or _tool_run() or not is_inside_tree():
		return
	app_backgrounded.emit()
	if focus_pauses() or what == NOTIFICATION_APPLICATION_PAUSED:
		pause_for_focus()


## S1 s1_10-08: its own option now ("Pause when window inactive"), no longer
## tied to "Sound in background".
static func focus_pauses() -> bool:
	return bool(Settings.get_v("pause_unfocused"))


## S1 s1_10-09: the Steam overlay (Shift+Tab) keeps the window focused, so
## SteamService calls this from its overlay_toggled signal.
func overlay_toggled(active: bool) -> void:
	if active and not OS.has_feature("web"):
		app_backgrounded.emit()
		pause_for_focus()


## S1 s1_10-03: Options > Scaling "pixel-perfect" (native desktop, not the Deck):
## the 480-tall view scales by a whole number (thin bars instead of uneven
## pixel columns). Returns that whole scale, or 0 when smooth scaling is on.
static func pixel_scale(s: Vector2i) -> int:
	if not bool(Settings.get_v("pixel_perfect")) or is_phone() or OS.has_feature("web") or is_deck():
		return 0
	if force < 0 and DisplayServer.get_name() == "headless" and test_size == Vector2i.ZERO:
		return 0
	return maxi(int(floor(float(s.y) / BASE.y)), 1)


static func toggle_pixel_perfect() -> void:
	Settings.set_v("pixel_perfect", not bool(Settings.get_v("pixel_perfect")))
	if _svc:
		_svc._refit()


## S1 s1_10-11: VSync and the frame-rate cap (native desktop only).
static func apply_frame_settings() -> void:
	if not native_desktop():
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(Settings.get_v("vsync")) else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(Settings.get_v("fps_cap"))


static func cycle_fps_cap() -> void:
	var i := FPS_CAPS.find(int(Settings.get_v("fps_cap")))
	Settings.set_v("fps_cap", FPS_CAPS[(i + 1) % FPS_CAPS.size()])
	apply_frame_settings()


static func toggle_vsync() -> void:
	Settings.set_v("vsync", not bool(Settings.get_v("vsync")))
	apply_frame_settings()


## Opens the game menu over a running map (nothing when a menu/screen is already up).
func pause_for_focus() -> bool:
	var sc := get_tree().current_scene
	if sc == null or not (sc is GameMap) or get_tree().paused or Hud.modal_rect.has_area():
		return false
	_tap("menu")
	return true


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
		if OS.has_feature("web_android"):
			JavaScriptBridge.eval("try{screen.orientation.lock('portrait').catch(function(){})}catch(e){}", true)
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
		TouchControls.visible_controls = touch_auto()

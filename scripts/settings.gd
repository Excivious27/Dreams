class_name Settings
extends RefCounted
## Player settings that live outside any one save: volumes, button size,
## left-handed layout. Stored with SaveGame's global values. Difficulty and
## day length are per save slot (Difficulty, GameState.day_len).

const DEFAULTS := {"music_vol": 9, "sfx_vol": 8, "amb_vol": 7, "bg_sound": false, "btn_size": 1, "left_handed": false, "night": 2, "shake": true, "touch_ui": 0, "fullscreen": false, "text_size": 0,
	"text_speed": 1, "toast_hold": 1, "timing_help": false, "pause_unfocused": true, "vsync": true, "fps_cap": 0}
const NIGHT_NAMES := ["off", "soft", "full"]
const BTN_SCALES := [0.85, 1.0, 1.2]
const BTN_NAMES := ["small", "normal", "large"]
const TEXT_NAMES := ["normal", "large", "larger"]  # C5 c5_13 #2 / C9: Text size for every reading screen
## Extra font pixels per Text size step (C9 c9_07: +1 px was invisible on a phone).
const TEXT_STEP := 2
## Dialogue typing speed in characters per second; 0 = instant (C9 c9_07).
const TEXT_SPEEDS := [30.0, 45.0, 90.0, 0.0]
const TEXT_SPEED_NAMES := ["slow", "normal", "fast", "instant"]
## How long toasts stay up, as a factor on Hud's own timing (C9 c9_07).
const TOAST_HOLDS := [0.75, 1.0, 1.6, 2.4]
const TOAST_HOLD_NAMES := ["short", "normal", "long", "longest"]
## Fishing bite window factor with Timing help on (rewards unchanged).
const TIMING_HELP_WINDOW := 1.5
## Reduced motion: caps on flashes and pulses (C9 c9_07).
const CALM_FLASH_ALPHA := 0.25  # full-screen lightning flash
const CALM_FLASH_GAP := 6.0  # seconds between lightning flashes, at least
const CALM_HIT_FLASH := 0.5  # enemy white hit flash strength


static func get_v(key: String) -> Variant:
	return SaveGame.get_value("set_" + key, DEFAULTS.get(key))


static func set_v(key: String, v: Variant) -> void:
	SaveGame.set_value("set_" + key, v)
	if key in ["music_vol", "sfx_vol", "amb_vol"]:
		apply_audio()


static func btn_scale() -> float:
	return float(BTN_SCALES[clampi(int(get_v("btn_size")), 0, 2)])


## Text size step (0 normal, 1 large, 2 larger).
static func text_step() -> int:
	return clampi(int(get_v("text_size")), 0, TEXT_NAMES.size() - 1)


## Extra font pixels for reading text (0 / 2 / 4).
static func text_bonus() -> int:
	return text_step() * TEXT_STEP


## A reading font size after Options > Text size (`base` is the normal size).
static func font(base: int) -> int:
	return maxi(base + text_bonus(), DisplayMode.deck_min_font())  # S1: Deck 9-px floor


## Dialogue characters per second (0 = the whole line at once).
static func text_cps() -> float:
	return float(TEXT_SPEEDS[clampi(int(get_v("text_speed")), 0, TEXT_SPEEDS.size() - 1)])


## Factor on toast display time (Hud multiplies its hold by this).
static func toast_hold() -> float:
	return float(TOAST_HOLDS[clampi(int(get_v("toast_hold")), 0, TOAST_HOLDS.size() - 1)])


## Reduced motion and flashes: the old "Screen shake" switch (save key "shake"
## kept so old saves keep their choice). Off = no shakes, soft flashes, still pulses.
static func reduced_motion() -> bool:
	return not bool(get_v("shake"))


## Fishing (and later other timing games) window factor.
static func timing_factor() -> float:
	return TIMING_HELP_WINDOW if bool(get_v("timing_help")) else 1.0


static func left_handed() -> bool:
	return bool(get_v("left_handed"))


## How dark nights get: 0 off, 0.6 soft, 1 full.
static func night_strength() -> float:
	return [0.0, 0.6, 1.0][clampi(int(get_v("night")), 0, 2)]


## 0..10 -> decibels on the Music / SFX buses (0 = silent). An even dB scale
## (C6): every step is 3 dB, so the whole control is useful (the old linear
## curve spent 14 dB on 1-5 and 4 dB on 6-10).
static func _db(v: int) -> float:
	return -80.0 if v <= 0 else -3.0 * float(10 - clampi(v, 0, 10))


## Per-bus offsets so the default mix lands where it did before the even-dB
## curve (SFX 8 and Nature 7 kept their old level; music is ~5 dB up via Music.MUSIC_DB).
const BUS_TRIM := {"Music": 0.0, "SFX": 4.0, "Ambience": 6.0}
const AUDIO_KEYS := ["music_vol", "sfx_vol", "amb_vol"]


static func ensure_buses() -> void:
	for bn in ["Music", "SFX", "Ambience"]:
		if AudioServer.get_bus_index(bn) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bn)
			AudioServer.set_bus_send(i, "Master")
	ensure_limiter()


## A safety limiter on Master (ceiling -1 dB): music, six effect voices, steps,
## blips and ambience can sum past full scale on a loud moment.
static func ensure_limiter() -> void:
	var mi := AudioServer.get_bus_index("Master")
	for i in AudioServer.get_bus_effect_count(mi):
		if AudioServer.get_bus_effect(mi, i) is AudioEffectHardLimiter:
			return
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -1.0
	AudioServer.add_bus_effect(mi, lim)


static func apply_audio() -> void:
	ensure_buses()
	for pair: Array in [["Music", "music_vol"], ["SFX", "sfx_vol"], ["Ambience", "amb_vol"]]:
		var bi := AudioServer.get_bus_index(str(pair[0]))
		var v := int(get_v(str(pair[1])))
		AudioServer.set_bus_volume_db(bi, _db(v) + float(BUS_TRIM[pair[0]]) if v > 0 else -80.0)
		AudioServer.set_bus_mute(bi, v <= 0)


## Sound back to the defaults (volumes, all sound on, silent in the background).
static func reset_audio(tree: SceneTree) -> void:
	for k: String in AUDIO_KEYS + ["bg_sound"]:
		SaveGame.set_value("set_" + k, DEFAULTS[k])
	apply_audio()
	var mu := Music.instance(tree)
	if mu.is_muted():
		mu.toggle_mute()
	mu.audio_changed()


## The sound rows (All sound, three volumes, Sound in background, Reset), shared
## by Menu > Options and the title screen. `refresh` rebuilds the page after a change.
static func audio_rows(parent: Control, tree: SceneTree, refresh: Callable, fsize := 8) -> void:
	var mk := func(text: String, cb: Callable) -> Button:
		var b := Button.new()
		b.text = text
		b.add_theme_font_size_override("font_size", font(fsize + 1))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE  # a finger scrolling the page never fires it
		b.custom_minimum_size = Vector2(0, 24)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: Music.instance(tree).sfx("ui_tap", "pickup"))
		b.pressed.connect(cb)
		parent.add_child(b)
		return b
	mk.call("All sound: %s" % ("off" if bool(SaveGame.get_value("muted", false)) else "on"), func() -> void:
		Music.instance(tree).toggle_mute()
		refresh.call())
	for vk: String in AUDIO_KEYS:
		var row := HBoxContainer.new()
		parent.add_child(row)
		var vl := Label.new()
		vl.text = "%s volume  %d/10" % [{"music_vol": "Music", "sfx_vol": "Sound", "amb_vol": "Nature" if GameState.run.is_empty() or GameState.is_penguins() else "Ambience"}[vk], int(get_v(vk))]
		vl.add_theme_font_size_override("font_size", font(fsize))
		vl.custom_minimum_size = Vector2(110, 0)
		vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(vl)
		for step: int in [-1, 1]:
			var bt := Button.new()
			bt.text = " − " if step < 0 else " + "
			bt.custom_minimum_size = Vector2(34, 22)
			bt.pressed.connect(func() -> void:
				set_v(vk, clampi(int(get_v(vk)) + step, 0, 10))
				Music.instance(tree).sfx("ui_tap", "pickup")
				if vk == "music_vol":
					Music.instance(tree).audio_changed()
				refresh.call())
			row.add_child(bt)
	mk.call("Sound in background: %s" % ("on" if bool(get_v("bg_sound")) else "off"), func() -> void:
		set_v("bg_sound", not bool(get_v("bg_sound")))
		refresh.call())
	mk.call("Reset sound to defaults", func() -> void:
		reset_audio(tree)
		refresh.call())
	# Vibration rows (C9 P4's Haptics service, when present).
	if ResourceLoader.exists("res://scripts/haptics.gd"):
		var hs: Script = load("res://scripts/haptics.gd")
		for md in hs.get_script_method_list():
			if str(md.get("name", "")) == "rows":
				hs.call("rows", parent)
				break


## A touch button's centre and radius after the size and handedness settings.
static func button_at(pos: Vector2, r: float) -> Array:
	var p := pos
	if left_handed():
		p.x = 270.0 - p.x
	return [p, r * btn_scale()]


## A section header for an Options page ("Sound", "Display and controls", ...).
static func header(parent: Control, text: String, fsize := 9) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font(fsize))
	l.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


## A centred Options row button (same look as the sound rows).
static func row_button(parent: Control, tree: SceneTree, text: String, cb: Callable, fsize := 8) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font(fsize + 1))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	b.custom_minimum_size = Vector2(0, 24)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void: GameMenu.last_press = "Options > " + text)
	b.pressed.connect(func() -> void: Music.instance(tree).sfx("ui_tap", "pickup"))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


## A small grey note under a row.
static func note(parent: Control, text: String, fsize := 7) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font(fsize))
	l.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


## Fullscreen is offered on desktops and on Android browsers (a tap may ask for it);
## never on iOS Safari (no element fullscreen) or a native phone app.
static func fullscreen_offered() -> bool:
	if OS.has_feature("web_ios") or OS.has_feature("ios") or OS.has_feature("android"):
		return false
	if OS.has_feature("web_android"):
		return not _installed_app()
	return not DisplayMode.is_phone()


static var _standalone := -1


## The web build runs as an installed app (PWA display-mode standalone/fullscreen):
## the browser bars are gone already, so no Fullscreen row.
static func _installed_app() -> bool:
	if _standalone < 0:
		_standalone = 0
		if OS.has_feature("web"):
			var v: Variant = JavaScriptBridge.eval("(window.matchMedia('(display-mode: standalone)').matches || window.matchMedia('(display-mode: fullscreen)').matches) ? 1 : 0", true)
			_standalone = 1 if int(v) == 1 else 0
	return _standalone == 1


static func _cycle(key: String, n: int) -> void:
	set_v(key, (clampi(int(get_v(key)), 0, n - 1) + 1) % n)


## Display, reading and control rows shared by Menu > Options and the title
## screen (C9 c9_07): night, text size/speed, toast time, motion, timing help,
## button size, handedness, on-screen controls, fullscreen.
static func general_rows(parent: Control, tree: SceneTree, refresh: Callable, fsize := 8) -> void:
	var rb := func(text: String, cb: Callable) -> Button:
		return row_button(parent, tree, text, func() -> void: cb.call(); refresh.call_deferred(), fsize)
	rb.call("Night darkness: %s" % NIGHT_NAMES[clampi(int(get_v("night")), 0, 2)], func() -> void: _cycle("night", 3))
	rb.call("Text size: %s" % TEXT_NAMES[text_step()], func() -> void: _cycle("text_size", TEXT_NAMES.size()))
	rb.call("Text speed: %s" % TEXT_SPEED_NAMES[clampi(int(get_v("text_speed")), 0, TEXT_SPEEDS.size() - 1)], func() -> void: _cycle("text_speed", TEXT_SPEEDS.size()))
	rb.call("Messages stay up: %s" % TOAST_HOLD_NAMES[clampi(int(get_v("toast_hold")), 0, TOAST_HOLDS.size() - 1)], func() -> void: _cycle("toast_hold", TOAST_HOLDS.size()))
	rb.call("Motion and flashes: %s" % ("reduced" if reduced_motion() else "full"), func() -> void: set_v("shake", not bool(get_v("shake"))))
	note(parent, "Reduced: no screen shake, softer lightning and hit flashes, no pulsing.")
	rb.call("Timing help: %s" % ("on" if bool(get_v("timing_help")) else "off"), func() -> void: set_v("timing_help", not bool(get_v("timing_help"))))
	note(parent, "On: fish bites wait longer for your tap.")
	rb.call("Button size: %s" % BTN_NAMES[clampi(int(get_v("btn_size")), 0, 2)], func() -> void: _cycle("btn_size", 3))
	rb.call("Controls: %s-handed" % ("left" if left_handed() else "right"), func() -> void: set_v("left_handed", not left_handed()))
	rb.call("On-screen controls: %s" % {"auto": "auto (%s)" % ("shown" if TouchControls.visible_controls else "hidden"), "on": "always", "off": "never"}[DisplayMode.touch_mode_name()], func() -> void: DisplayMode.cycle_touch_mode())
	if fullscreen_offered():
		# S1 s1_10-10: the key hint only for keyboard players, never on a pad or the Deck.
		var fk := "  (F11 or Alt+Enter)" if fullscreen_key_hint() else ""
		rb.call("Fullscreen: %s%s" % ["on" if DisplayMode.is_fullscreen() else "off", fk], func() -> void: DisplayMode.toggle_fullscreen())
	if DisplayMode.native_desktop():
		# S1 s1_10-08 / s1_10-11: desktop window options.
		rb.call("Pause when window inactive: %s" % ("on" if DisplayMode.focus_pauses() else "off"), func() -> void: set_v("pause_unfocused", not DisplayMode.focus_pauses()))
		rb.call("VSync: %s" % ("on" if bool(get_v("vsync")) else "off"), func() -> void: DisplayMode.toggle_vsync())
		var cap := int(get_v("fps_cap"))
		rb.call("Frame rate cap: %s" % ("none" if cap == 0 else str(cap)), func() -> void: DisplayMode.cycle_fps_cap())


static func fullscreen_key_hint() -> bool:
	return not DisplayMode.is_phone() and not OS.has_feature("web_android") and not DisplayMode.is_deck() and PadInput.device_kind() == "keys"

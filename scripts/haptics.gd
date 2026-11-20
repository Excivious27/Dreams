class_name Haptics
extends RefCounted
## Vibration (C9 P4). Every buzz in the game goes through Haptics.buzz(kind).
##
## - PATTERNS: kind -> [pulses ms (on, off, on, ...), amplitude 0..1, cooldown ms, flags].
##   Flags: "ui" = a menu/button tap (only with the "Vibrate on taps" option, default off);
##   "menu_ok" = a result that may buzz while a menu or dialogue is up (level up, quest done).
##   Every other kind is gameplay and stays quiet while the tree is paused or a full-screen
##   screen owns the view (Tom: never buzz inside menus by default).
## - JINGLES / SFX: Music.sfx names that buzz (explicit whitelist; Music.sfx calls
##   Haptics.from_sfx before its mute check, so a muted phone still feels a bite).
## - Web: one navigator.vibrate([...]) call plays the whole pattern; strength is done by
##   pulse length (the web API has no amplitude). iPhone Safari has no Vibration API, so
##   supported() is false there and the Options rows say so.
## - Native phone: Input.vibrate_handheld; joypads: Input.start_joy_vibration (weak motor
##   for light kinds, strong motor for heavy ones).
## Settings live in SaveGame globals: set_haptics (on), set_haptics_str (0/1/2), set_haptics_ui (off).

const PATTERNS := {
	"ui_light": [[12], 0.25, 60, "ui"],
	"press": [[12], 0.25, 80, "ui"],
	"tool_hit": [[18], 0.45, 90, ""],
	"tool_break": [[35], 0.7, 120, ""],
	"hit": [[14], 0.4, 90, ""],
	"hit_big": [[28], 0.75, 120, ""],
	"recoil": [[16], 0.5, 120, ""],
	"block": [[10], 0.35, 150, ""],
	"deny": [[12], 0.3, 250, ""],
	"bite": [[50, 40, 50], 0.9, 0, ""],
	"catch": [[30], 0.6, 200, ""],
	"harvest": [[14], 0.4, 80, ""],
	"harvest_star": [[25], 0.6, 120, "menu_ok"],
	"hurt": [[45], 0.85, 150, ""],
	"ko": [[90], 1.0, 300, "menu_ok"],
	"warn": [[25, 60, 25], 0.5, 500, ""],
	"boss": [[70], 0.9, 300, ""],
	"boss_down": [[120], 1.0, 300, "menu_ok"],
	"level_up": [[30, 60, 60, 60, 30], 0.8, 400, "menu_ok"],
	"purr": [[15, 35, 15, 35, 15], 0.3, 400, "menu_ok"],
	"region": [[20, 80, 20], 0.5, 400, "menu_ok"],
}

## Music.sfx name -> kind. Exact names only: j_confirm, j_buy, j_page, j_gift,
## j_battle_start, craft_done and every ui_/menu_ cue are left out on purpose
## (menu confirms must not buzz by default).
const SFX := {
	# jingles
	"levelup": "level_up", "quest_done": "level_up", "boss_down": "boss_down",
	"j_victory": "boss_down", "j_battle_won": "boss_down", "j_campaign_won": "boss_down",
	"j_battle_lost": "ko", "j_heart": "purr", "j_treasure": "harvest_star", "j_secret": "harvest_star",
	"j_region": "region", "j_wedding": "level_up", "j_proposal": "level_up",
	# gameplay moments
	"bite": "bite", "reel": "catch",
	"chop": "tool_hit", "pick": "tool_hit",
	"timber": "tool_break", "rock_break": "tool_break", "crate_break": "tool_break",
	"hit": "hit", "crit": "hit_big", "block": "block", "dry_click": "deny",
	"hurt": "hurt", "knockout": "ko", "heartbeat": "warn",
	"harvest": "harvest", "boss_fall": "boss_down",
	"shot_smg": "recoil",
}

## Strength setting: pulse length scale and amplitude scale.
const STR_NAMES := ["light", "normal", "strong"]
const STR_LEN := [0.6, 1.0, 1.5]
const STR_AMP := [0.55, 0.8, 1.0]
## Shortest pulse many Android motors actually spin up for.
const MIN_PULSE := 12
## Two buzzes this close together are one: the weaker is dropped.
const MERGE_MS := 30

## Tests: pretend the device can vibrate, read the log, drive the clock.
static var force_supported := false
static var history: Array = []
static var clock_override := -1
static var _last := {}          # kind -> ms
static var _last_any := -10000
static var _last_amp := 0.0
static var _web_ok := -1        # -1 unknown, 0 no, 1 yes


static func enabled() -> bool:
	return bool(SaveGame.get_value("set_haptics", true))


static func strength() -> int:
	return clampi(int(SaveGame.get_value("set_haptics_str", 1)), 0, 2)


static func taps_on() -> bool:
	return bool(SaveGame.get_value("set_haptics_ui", false))


static func _now() -> int:
	return clock_override if clock_override >= 0 else Time.get_ticks_msec()


## Can this device buzz at all?
static func supported() -> bool:
	if force_supported:
		return true
	if not Input.get_connected_joypads().is_empty():
		return true
	if OS.has_feature("web"):
		if _web_ok < 0:
			_web_ok = 0
			if ClassDB.class_exists("JavaScriptBridge"):
				var r: Variant = JavaScriptBridge.eval("(typeof navigator!=='undefined'&&typeof navigator.vibrate==='function')?1:0", true)
				_web_ok = 1 if int(r if r != null else 0) == 1 else 0
		return _web_ok == 1
	return OS.has_feature("android") or OS.has_feature("ios")


## A menu, dialogue or full-screen screen owns the view.
static func in_menu() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	if tree.paused:
		return true
	return Hud.modal_rect.has_area()


## The pulse list after the strength setting (ms, on/off alternating).
static func pattern_for(kind: String, str_level := -1) -> Array:
	var p: Array = PATTERNS.get(kind, [[]])[0]
	var lv := strength() if str_level < 0 else str_level
	var out: Array = []
	for i in p.size():
		var ms := int(p[i])
		if i % 2 == 0:
			ms = maxi(MIN_PULSE, int(round(ms * STR_LEN[lv])))
		out.append(ms)
	return out


## Buzz for a game moment. force = a preview (Options) that ignores the gates
## except the device check.
static func buzz(kind: String, force := false) -> bool:
	if not PATTERNS.has(kind):
		push_warning("Haptics: unknown kind " + kind)
		return false
	var spec: Array = PATTERNS[kind]
	var flags: String = spec[3]
	if not force:
		if not enabled():
			return false
		if flags == "ui" and not taps_on():
			return false
		if flags == "" and in_menu():
			return false
	var now := _now()
	if not force:
		if now - int(_last.get(kind, -100000)) < int(spec[2]):
			return false
		var amp_new := float(spec[1])
		if now - _last_any < MERGE_MS and amp_new <= _last_amp:
			return false
	if not supported():
		return false
	_last[kind] = now
	_last_any = now
	_last_amp = float(spec[1])
	var pulses := pattern_for(kind)
	var amp := clampf(float(spec[1]) * STR_AMP[strength()], 0.05, 1.0)
	history.append({"kind": kind, "pulses": pulses, "amp": amp, "t": now})
	if history.size() > 200:
		history.pop_front()
	_fire(pulses, amp, float(spec[1]) >= 0.6)
	return true


## Music.sfx hook (exact-name whitelist).
static func from_sfx(name: String) -> void:
	var k: String = SFX.get(name, "")
	if k != "":
		buzz(k)


## A screen-shake strength (ArcadeGame.shake, story effects) as a buzz.
static func buzz_amount(a: float) -> bool:
	if a <= 0.0:
		return false
	return buzz("hit" if a < 2.0 else ("hit_big" if a < 3.5 else "boss"))


## The JS array literal for navigator.vibrate.
static func web_array(pulses: Array) -> String:
	var parts: PackedStringArray = []
	for v: Variant in pulses:
		parts.append(str(int(v)))
	return "[" + ",".join(parts) + "]"


static func _fire(pulses: Array, amp: float, heavy: bool) -> void:
	if force_supported and not OS.has_feature("web") and Input.get_connected_joypads().is_empty() \
			and not (OS.has_feature("android") or OS.has_feature("ios")):
		return  # a test run: logged only
	if OS.has_feature("web"):
		if ClassDB.class_exists("JavaScriptBridge"):
			JavaScriptBridge.eval("navigator.vibrate&&navigator.vibrate(%s)" % web_array(pulses), true)
	else:
		var t := 0
		var tree := Engine.get_main_loop() as SceneTree
		for i in range(0, pulses.size(), 2):
			var ms := int(pulses[i])
			if t == 0 or tree == null:
				_pulse(ms, amp, heavy)
			else:
				tree.create_timer(t / 1000.0, true, false, true).timeout.connect(_pulse.bind(ms, amp, heavy))
			t += ms + (int(pulses[i + 1]) if i + 1 < pulses.size() else 0)


static func _pulse(ms: int, amp: float, heavy: bool) -> void:
	if OS.has_feature("android") or OS.has_feature("ios"):
		Input.vibrate_handheld(ms, amp)
	for dev: int in Input.get_connected_joypads():
		var weak := amp if not heavy else amp * 0.5
		var strong := amp if heavy else 0.0
		Input.start_joy_vibration(dev, weak, strong, ms / 1000.0)


static func reset_for_tests() -> void:
	history.clear()
	_last.clear()
	_last_any = -10000
	_last_amp = 0.0


## Options / title Sound page rows: Vibration on/off, strength, taps. Buttons
## rewrite their own text, so no refresh callback is needed.
static func rows(parent: Control, font := 8) -> void:
	if not supported():
		var l := Label.new()
		l.text = "Vibration: not supported on this device" + (" (iPhone browsers can't vibrate)" if OS.has_feature("web_ios") else "")
		l.add_theme_font_size_override("font_size", font)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(l)
		return
	var mk := func(cb: Callable) -> Button:
		var b := Button.new()
		b.add_theme_font_size_override("font_size", font + 1)
		b.custom_minimum_size = Vector2(0, 24)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = cb.call(false)
		b.pressed.connect(func() -> void: b.text = cb.call(true))
		parent.add_child(b)
		return b
	var str_btn: Button
	var tap_btn: Button
	var on_btn: Button = mk.call(func(press: bool) -> String:
		if press:
			SaveGame.set_value("set_haptics", not enabled())
			if enabled():
				buzz("tool_hit", true)
			if str_btn:
				str_btn.visible = enabled()
			if tap_btn:
				tap_btn.visible = enabled()
		return "Vibration: %s" % ("on" if enabled() else "off"))
	str_btn = mk.call(func(press: bool) -> String:
		if press:
			SaveGame.set_value("set_haptics_str", (strength() + 1) % STR_NAMES.size())
			buzz("tool_break", true)
		return "Vibration strength: %s" % STR_NAMES[strength()])
	tap_btn = mk.call(func(press: bool) -> String:
		if press:
			SaveGame.set_value("set_haptics_ui", not taps_on())
			if taps_on():
				buzz("press", true)
		return "Vibrate on button taps: %s" % ("on" if taps_on() else "off"))
	str_btn.visible = enabled()
	tap_btn.visible = enabled()
	on_btn.tooltip_text = "Buzz on bites, hits, harvests and big moments"

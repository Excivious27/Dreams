class_name Settings
extends RefCounted
## Player settings that live outside any one save: volumes, button size,
## left-handed layout. Stored with SaveGame's global values. Difficulty and
## day length are per save slot (Difficulty, GameState.day_len).

const DEFAULTS := {"music_vol": 9, "sfx_vol": 8, "amb_vol": 7, "bg_sound": false, "btn_size": 1, "left_handed": false, "night": 2, "shake": true, "touch_ui": 0, "fullscreen": false, "text_size": 0}
const NIGHT_NAMES := ["off", "soft", "full"]
const BTN_SCALES := [0.85, 1.0, 1.2]
const BTN_NAMES := ["small", "normal", "large"]
const TEXT_NAMES := ["normal", "large"]  # C5 c5_13 #2: Text size for dialogue and its choices


static func get_v(key: String) -> Variant:
	return SaveGame.get_value("set_" + key, DEFAULTS.get(key))


static func set_v(key: String, v: Variant) -> void:
	SaveGame.set_value("set_" + key, v)
	if key in ["music_vol", "sfx_vol", "amb_vol"]:
		apply_audio()


static func btn_scale() -> float:
	return float(BTN_SCALES[clampi(int(get_v("btn_size")), 0, 2)])


## Extra font pixels for reading text (0 normal, 1 large).
static func text_bonus() -> int:
	return clampi(int(get_v("text_size")), 0, TEXT_NAMES.size() - 1)


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
static func audio_rows(parent: Control, tree: SceneTree, refresh: Callable, font := 8) -> void:
	var mk := func(text: String, cb: Callable) -> Button:
		var b := Button.new()
		b.text = text
		b.add_theme_font_size_override("font_size", font + 1)
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
		vl.add_theme_font_size_override("font_size", font)
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


## A touch button's centre and radius after the size and handedness settings.
static func button_at(pos: Vector2, r: float) -> Array:
	var p := pos
	if left_handed():
		p.x = 270.0 - p.x
	return [p, r * btn_scale()]

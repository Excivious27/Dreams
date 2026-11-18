class_name Settings
extends RefCounted
## Player settings that live outside any one save: volumes, button size,
## left-handed layout, easy mode. Stored with SaveGame's global values.

const DEFAULTS := {"music_vol": 8, "sfx_vol": 8, "btn_size": 1, "left_handed": false, "easy": false}
const BTN_SCALES := [0.85, 1.0, 1.2]
const BTN_NAMES := ["small", "normal", "large"]


static func get_v(key: String) -> Variant:
	return SaveGame.get_value("set_" + key, DEFAULTS.get(key))


static func set_v(key: String, v: Variant) -> void:
	SaveGame.set_value("set_" + key, v)
	if key in ["music_vol", "sfx_vol"]:
		apply_audio()


static func btn_scale() -> float:
	return float(BTN_SCALES[clampi(int(get_v("btn_size")), 0, 2)])


static func left_handed() -> bool:
	return bool(get_v("left_handed"))


static func easy() -> bool:
	return bool(get_v("easy"))


## 0..10 -> decibels on the Music / SFX buses (0 = silent).
static func _db(v: int) -> float:
	return -80.0 if v <= 0 else linear_to_db(float(v) / 10.0)


static func ensure_buses() -> void:
	for bn in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bn) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bn)
			AudioServer.set_bus_send(i, "Master")


static func apply_audio() -> void:
	ensure_buses()
	var mi := AudioServer.get_bus_index("Music")
	var si := AudioServer.get_bus_index("SFX")
	var mv := int(get_v("music_vol"))
	var sv := int(get_v("sfx_vol"))
	AudioServer.set_bus_volume_db(mi, _db(mv))
	AudioServer.set_bus_mute(mi, mv <= 0)
	AudioServer.set_bus_volume_db(si, _db(sv))
	AudioServer.set_bus_mute(si, sv <= 0)


## A touch button's centre and radius after the size and handedness settings.
static func button_at(pos: Vector2, r: float) -> Array:
	var p := pos
	if left_handed():
		p.x = 270.0 - p.x
	return [p, r * btn_scale()]

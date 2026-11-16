class_name SaveGame
extends RefCounted
## Tiny key/value save stored in user:// (browser storage on the web build).

const PATH := "user://save.json"


static func load_all() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


static func get_value(key: String, default: Variant = null) -> Variant:
	return load_all().get(key, default)


static func set_value(key: String, value: Variant) -> void:
	var d := load_all()
	d[key] = value
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

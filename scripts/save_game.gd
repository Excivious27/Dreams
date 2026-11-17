class_name SaveGame
extends RefCounted
## Tiny key/value save stored in user:// (browser storage on the web build).
## Writes go to a temp file that's renamed over the real one, the previous good
## save is kept as save.bak.json, and an unreadable save is set aside rather than
## overwritten (and writes are blocked for that session so nothing clobbers it).

const PATH := "user://save.json"
const TMP := "user://save.tmp.json"
const BAK := "user://save.bak.json"
const BAD := "user://save.bad.json"

static var _cache: Dictionary = {}
static var _loaded := false
static var _blocked := false


static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt := f.get_as_text()
	f.close()
	if txt.strip_edges() == "":
		return null
	return JSON.parse_string(txt)


static func load_all() -> Dictionary:
	if _loaded:
		return _cache
	_loaded = true
	var parsed: Variant = _read(PATH)
	if parsed is Dictionary:
		_cache = parsed
		return _cache
	if FileAccess.file_exists(PATH):
		# Corrupt or truncated: keep a copy, fall back to the backup.
		DirAccess.copy_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(BAD))
		var bak: Variant = _read(BAK)
		if bak is Dictionary:
			_cache = bak
			push_warning("save.json was unreadable; restored save.bak.json (bad copy kept as save.bad.json)")
			return _cache
		_blocked = true
		push_warning("save.json was unreadable and there's no backup; kept as save.bad.json, saving disabled this session")
	_cache = {}
	return _cache


static func get_value(key: String, default: Variant = null) -> Variant:
	return load_all().get(key, default)


static func set_value(key: String, value: Variant) -> void:
	var d := load_all()
	d[key] = value
	flush()


static func flush() -> void:
	if _blocked:
		return
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_cache))
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if FileAccess.file_exists(PATH):
		if dir.file_exists("save.bak.json"):
			dir.remove("save.bak.json")
		dir.rename("save.json", "save.bak.json")
	dir.rename("save.tmp.json", "save.json")


## Tests and "new game" flows that wipe the run in memory use this.
static func reset_cache() -> void:
	_loaded = false
	_cache = {}

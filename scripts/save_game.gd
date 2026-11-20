class_name SaveGame
extends RefCounted
## Tiny key/value save stored in user:// (browser storage on the web build).
## Writes go to a temp file that's renamed over the real one, the previous good
## save is kept as save.bak.json, and an unreadable save is set aside rather than
## overwritten. On the web build every save is also mirrored, synchronously, to
## the browser's localStorage, because the file copy only reaches the browser's
## storage on the next frame and a phone that hides the app gives it none.

const PATH := "user://save.json"
const TMP := "user://save.tmp.json"
const BAK := "user://save.bak.json"
const BAD := "user://save.bad.json"

static var _cache: Dictionary = {}
static var _loaded := false
static var _blocked := false
static var _js_cb: Variant = null
const LS_KEY := "dreams_save"
## Corrupt saves set aside (save.bad.json + timestamped ones): at most this many.
const BAD_KEEP := 3
## C9: did the last flush really land? last_why: "" | "other" (another Dreams tab
## owns the farm) | "full" (browser storage full) | "file" (couldn't write user://).
static var last_ok := true
static var last_why := ""


## On the web: let the page save us when it's hidden or about to update.
static func web_hook() -> void:
	if not OS.has_feature("web") or _js_cb != null:
		return
	_js_cb = JavaScriptBridge.create_callback(_save_now_js)
	var w: Variant = JavaScriptBridge.get_interface("window")
	if w:
		w.dreamsSaveNow = _js_cb


static func _save_now_js(_args: Array) -> void:
	var sc := (Engine.get_main_loop() as SceneTree).current_scene
	if sc is GameMap and (sc as GameMap)._transitioning:
		return  # mid door: the next map saves itself once it's in
	if GameState.run.is_empty():
		return
	# Hide/update banner: record where you stand too, like the focus/close path.
	if sc is GameMap and not (sc as GameMap)._changing:
		(sc as GameMap).save_here()
	else:
		GameState.save()


static func _ls_read() -> Variant:
	if not OS.has_feature("web"):
		return null
	var ls: Variant = JavaScriptBridge.get_interface("localStorage")
	if ls == null:
		return null
	var txt: Variant = ls.getItem(LS_KEY)
	if txt == null or str(txt) == "" or str(txt) == "null":
		return null
	return JSON.parse_string(str(txt))


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
	var lsd: Variant = _ls_read()
	if lsd is Dictionary and (not parsed is Dictionary or int((lsd as Dictionary).get("_saved_at", 0)) > int((parsed as Dictionary).get("_saved_at", 0))):
		# The browser copy is newer (the page closed before the file synced).
		if not parsed is Dictionary and FileAccess.file_exists(PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))  # never rotate a corrupt file onto the backup
		parsed = lsd
	if parsed is Dictionary:
		_cache = parsed
		return _cache
	if not FileAccess.file_exists(PATH):
		# Interrupted between renames: the temp file is the newest complete save,
		# then the backup. Promote whichever reads.
		for alt in [TMP, BAK]:
			var got: Variant = _read(alt)
			if got is Dictionary and not (got as Dictionary).is_empty():
				_cache = got
				flush()
				push_warning("save.json was missing; recovered from " + alt)
				return _cache
	if FileAccess.file_exists(PATH):
		# Corrupt or truncated: keep a copy, fall back to the backup.
		# Keep the first bad copy (the one worth recovering by hand); later ones get a timestamp.
		var bad := BAD if not FileAccess.file_exists(BAD) else "user://save.bad.%d.json" % int(Time.get_unix_time_from_system())
		DirAccess.copy_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(bad))
		_prune_bad()
		var bak: Variant = _read(BAK)
		if bak is Dictionary:
			_cache = bak
			# Remove the corrupt file so the next save doesn't rotate it onto the good backup.
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
			push_warning("save.json was unreadable; restored save.bak.json (bad copy kept as save.bad.json)")
			return _cache
		# Nothing readable: keep the bad copy aside and start clean, so saving works again.
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		push_warning("save.json was unreadable and there's no backup; kept as save.bad.json")
	_cache = {}
	return _cache


static func get_value(key: String, default: Variant = null) -> Variant:
	return load_all().get(key, default)


static func set_value(key: String, value: Variant) -> void:
	var d := load_all()
	d[key] = value
	flush()


static func flush() -> bool:
	last_ok = false
	if _blocked:
		last_why = "other"
		return false
	if OS.has_feature("web") and bool(JavaScriptBridge.eval("window.dreamsOtherOpen === true", true)):
		_blocked = true  # a newer window owns the farm; a hidden tab never ran GameMap's 3 s check
		last_why = "other"
		return false
	if OS.has_feature("web") and _ls_counter() > int(_cache.get("_saved_at", 0)):
		# C9: an old background tab (frozen, then restored) must never write over
		# newer progress saved by another tab/the home-screen app since it loaded.
		_blocked = true
		last_why = "other"
		JavaScriptBridge.eval("window.dreamsOtherOpen = true", true)  # GameMap tells the player
		return false
	_cache["_saved_at"] = int(_cache.get("_saved_at", 0)) + 1
	var txt := JSON.stringify(_cache, "", false)  # keep key order (sorted bags and chests)
	var full := false
	if OS.has_feature("web"):
		# Through eval so a full or blocked localStorage is noticed (the wrapper drops the error).
		var ok: Variant = JavaScriptBridge.eval("(function(t){try{localStorage.setItem(%s,t);return true}catch(e){return false}})(%s)" % [JSON.stringify(LS_KEY), JSON.stringify(txt)], true)
		if not bool(ok):
			full = true
			push_warning("localStorage mirror failed (storage full?)")
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	if f == null:
		last_why = "full" if full else "file"
		return false
	f.store_string(txt)
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		last_why = "file"
		return false
	if FileAccess.file_exists(PATH):
		if dir.file_exists("save.bak.json"):
			dir.remove("save.bak.json")
		dir.rename("save.json", "save.bak.json")
	dir.rename("save.tmp.json", "save.json")
	last_ok = not full
	last_why = "full" if full else ""
	return last_ok


## The save counter stored in the browser copy (0 when none): just the number,
## read with a regex so a big save is never parsed twice.
static func _ls_counter() -> int:
	var n: Variant = JavaScriptBridge.eval("(function(){try{var t=localStorage.getItem(%s)||'';var m=t.match(/\"_saved_at\":(\\d+)/);return m?parseInt(m[1]):0}catch(e){return 0}})()" % JSON.stringify(LS_KEY), true)
	return int(n) if n != null else 0


## Keep at most BAD_KEEP set-aside saves: the first one (save.bad.json, worth
## recovering by hand) and the newest timestamped ones.
static func _prune_bad() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	var stamped: Array = []
	for fn in dir.get_files():
		if fn.begins_with("save.bad.") and fn != "save.bad.json" and fn.ends_with(".json"):
			stamped.append(fn)
	stamped.sort()  # unix stamps of the same width sort by age
	while stamped.size() > BAD_KEEP - 1:
		dir.remove(str(stamped.pop_front()))


## Tests and "new game" flows that wipe the run in memory use this.
static func reset_cache() -> void:
	_loaded = false
	_cache = {}

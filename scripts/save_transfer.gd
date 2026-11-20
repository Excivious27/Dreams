class_name SaveTransfer
extends RefCounted
## C9: moving a farm between phones/computers and backing farms up.
## A code (or a .dreams file: same text) is
##   DRM2:<save version>:<check>:<label>:<base64 gzip json>   one farm
##   DRMALL:<save version>:<check>:<label>:<base64 gzip json> every slot + Restore farms
## <check> = first 8 hex of the SHA-256 of the json, <label> ("Ann-day87") is only
## for people telling codes apart. Old DRM1:<base64> codes still load.
## Decoding forgives what notes/mail/chat apps do to long text: line breaks and
## spaces inside, quote marks, a lowercased prefix.
## Callers: GameState.export_code / import_code (the stable API), title.gd's
## Save slots page (preview -> confirm -> apply), game_menu's Back up row.

const PREFIX_ONE := "DRM2"
const PREFIX_ALL := "DRMALL"
const PREFIX_OLD := "DRM1"
const ARCS := ["penguins", "gangsters"]
const FILE_EXT := "dreams"
const UNZIP_MAX := 32 * 1024 * 1024
const SLOTS := [1, 2, 3]
const INVISIBLE := [0x200b, 0x200c, 0x200d, 0xfeff, 0x00a0]
const CURLY_QUOTES := [0x201c, 0x201d, 0x2018, 0x2019]
## Keys that must hold this type when present (null is fine: _migrate rebuilds it).
const TYPED := {
	"names": TYPE_DICTIONARY, "inventory": TYPE_DICTIONARY, "flags": TYPE_DICTIONARY,
	"skills": TYPE_DICTIONARY, "farm": TYPE_DICTIONARY, "friendship": TYPE_DICTIONARY,
	"equip": TYPE_DICTIONARY, "quests": TYPE_ARRAY, "tools": TYPE_ARRAY, "toolbar": TYPE_ARRAY,
}
## What makes two saves "the same farm at the same moment" (same_farm).
const SAME_KEYS := ["names", "arc", "playable", "day", "time", "crystals", "inventory", "kills", "farm"]
const NUMBERS := ["day", "time", "energy", "max_energy", "hp", "max_hp", "crystals"]

const WHY := {
	"empty": "Paste a save code first.",
	"not_code": "That doesn't look like a Dreams save code (it starts with DRM).",
	"cut": "The code is cut off: copy all of it, from DRM to the very end, and try again.",
	"typo": "Some letters in the code changed (a typo, or an app 'fixed' it). Copy it again from where you saved it.",
	"newer": "This code is from a newer Dreams. Reload the page (or update the app), then load it again.",
	"bad_farm": "The code opened, but the farm inside it is damaged, so it was not loaded. Nothing here changed.",
	"all_here": "That is a backup of every farm: use 'Load a backup of all farms'.",
	"one_here": "That code holds one farm: load it into a slot instead.",
	"other": "Close the other Dreams tab or window first: this one can't save while it is open. Nothing was loaded.",
	"full": "Your browser's storage is full, so the farm could not be saved. Nothing was loaded.",
	"file": "The farm could not be written to this device's storage. Nothing was loaded.",
	"no_farm": "This slot is empty: there is no farm to copy.",
}


## The farm in slot n as saved data (the live run when n is the slot being played).
static func farm_of(n: int) -> Dictionary:
	if n == GameState.slot() and not GameState.run.is_empty():
		return (Net.save_view(GameState.run) as Dictionary).duplicate(true)
	var d: Variant = SaveGame.get_value(GameState.slot_key(n), null)
	return (d as Dictionary).duplicate(true) if d is Dictionary and (d as Dictionary).has("names") else {}


## Restore ("farm you can bring back") key of any slot; mirrors GameState.prev_key.
static func prev_key_of(n: int) -> String:
	return "run_prev" if n <= 1 else "run_prev_%d" % n


static func restore_of(n: int) -> Dictionary:
	var d: Variant = SaveGame.get_value(prev_key_of(n), null)
	return d if d is Dictionary and (d as Dictionary).has("names") else {}


static func _check(json: String) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(json.to_utf8_buffer())
	return h.finish().hex_encode().substr(0, 8)


static func _label(d: Dictionary) -> String:
	var nm := ""
	var names: Variant = d.get("names", {})
	if names is Dictionary:
		for ch in str((names as Dictionary).get("character", "")):
			if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
				nm += ch
	if nm == "":
		nm = "farm"
	return "%s-day%d" % [nm.substr(0, 12), int(d.get("day", 1))]


static func _pack(prefix: String, d: Dictionary, label: String) -> String:
	var json := JSON.stringify(d, "", false)
	var b64 := Marshalls.raw_to_base64(json.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	return "%s:%d:%s:%s:%s" % [prefix, GameState.SAVE_VERSION, _check(json), label, b64]


## One farm as a code; "" when the slot is empty.
static func encode_slot(n: int) -> String:
	var d := farm_of(n)
	return "" if d.is_empty() else _pack(PREFIX_ONE, d, _label(d))


static func encode_farm(d: Dictionary) -> String:
	return "" if d.is_empty() or not d.has("names") else _pack(PREFIX_ONE, d, _label(d))


## Every slot and every Restore farm in one code; "" when there are none.
static func encode_all() -> String:
	var slots := {}
	var rest := {}
	for n in SLOTS:
		var f := farm_of(n)
		if not f.is_empty():
			slots[str(n)] = f
		var r := restore_of(n)
		if not r.is_empty():
			rest[str(n)] = r
	if slots.is_empty() and rest.is_empty():
		return ""
	return _pack(PREFIX_ALL, {"slots": slots, "restore": rest}, "%dfarms" % (slots.size() + rest.size()))


static func file_name(code: String) -> String:
	var parts := code.split(":")
	var lab := str(parts[3]) if parts.size() >= 5 else "farm"
	return "dreams-%s.%s" % [lab, FILE_EXT]


## Text from a note/mail/chat back into a bare code: no whitespace (incl.
## zero-width), no quote marks, prefix upper-cased.
static func clean(text: String) -> String:
	var t := text
	for z in INVISIBLE:  # zero-width spaces, BOM, no-break space (by code: no odd glyphs in source)
		t = t.replace(String.chr(z), "")
	t = RegEx.create_from_string("\\s+").sub(t, "", true)
	for q in ["\"", "'", "`", ">", "<", "*"]:
		t = t.replace(q, "")
	for z in CURLY_QUOTES:
		t = t.replace(String.chr(z), "")
	var at := t.to_upper().find("DRM")
	if at < 0:
		return t
	t = t.substr(at)
	var colon := t.find(":")
	if colon > 0:
		t = t.substr(0, colon).to_upper() + t.substr(colon)
	return t


## {ok, why (text), code (WHY key), kind "one"|"all", data, ver}
static func decode(text: String) -> Dictionary:
	var t := clean(text)
	if t == "":
		return _no("empty")
	if not t.begins_with("DRM"):
		return _no("not_code")
	var parts := t.split(":")
	var kind := ""
	var ver := 0
	var chk := ""
	var b64 := ""
	match str(parts[0]):
		PREFIX_OLD:
			kind = "one"
			b64 = t.substr(5)
		PREFIX_ONE, PREFIX_ALL:
			if parts.size() < 5:
				return _no("cut")
			kind = "one" if parts[0] == PREFIX_ONE else "all"
			if not str(parts[1]).is_valid_int():
				return _no("typo")
			ver = int(parts[1])
			chk = str(parts[2]).to_lower()
			b64 = str(parts[parts.size() - 1])
		_:
			return _no("not_code")
	if ver > GameState.SAVE_VERSION:
		return _no("newer")
	if b64 == "" or not RegEx.create_from_string("^[A-Za-z0-9+/]+=*$").search(b64):
		return _no("cut" if b64 == "" else "typo")
	var buf := Marshalls.base64_to_raw(b64)
	if buf.size() < 18:
		return _no("cut")
	var raw := buf.decompress_dynamic(UNZIP_MAX, FileAccess.COMPRESSION_GZIP)
	if raw.is_empty():
		return _no("cut")
	var json := raw.get_string_from_utf8()
	if chk != "" and _check(json) != chk:
		return _no("typo")
	var d: Variant = JSON.parse_string(json)
	if not d is Dictionary:
		return _no("cut" if chk == "" else "bad_farm")
	if kind == "one":
		var why := validate(d)
		if why != "":
			return _no("bad_farm", why)
		if int((d as Dictionary).get("save_ver", 0)) > GameState.SAVE_VERSION:
			return _no("newer")
	else:
		for blk in ["slots", "restore"]:
			if not (d as Dictionary).get(blk, {}) is Dictionary:
				return _no("bad_farm", blk)
			for k in (d[blk] as Dictionary).keys():
				if not str(k) in ["1", "2", "3"] or validate(d[blk][k]) != "":
					return _no("bad_farm", "%s %s" % [blk, k])
	return {"ok": true, "why": "", "code": "", "kind": kind, "data": d, "ver": ver}


static func _no(key: String, detail := "") -> Dictionary:
	return {"ok": false, "why": str(WHY.get(key, key)), "code": key, "detail": detail, "kind": "", "data": {}, "ver": 0}


## "" when d is a farm the game can open; else what is wrong (for logs/tests).
static func validate(d: Variant) -> String:
	if not d is Dictionary:
		return "not a dictionary"
	var r: Dictionary = d
	if not r.get("names") is Dictionary or not (r["names"] as Dictionary).get("character") is String:
		return "names"
	for k in (r["names"] as Dictionary).keys():
		if not r["names"][k] is String:
			return "names." + str(k)
	if not str(r.get("arc", "")) in ARCS or not r.get("arc") is String:
		return "arc"
	if not r.get("playable") is String:
		return "playable"
	GameState.load_data()
	if not GameState.playables.is_empty() and not GameState.playables.has(str(r["playable"])):
		return "playable id"
	for k in NUMBERS:
		if r.has(k) and r[k] != null and not (r[k] is int or r[k] is float):
			return k
	for k in TYPED:
		if r.has(k) and r[k] != null and typeof(r[k]) != int(TYPED[k]):
			return k
	return ""


## Same farm? (through JSON so ints and floats from a code match).
static func same_farm(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	# Loading migrates a farm (new keys, fixed values), so compare the parts that
	# say which farm and which moment it is, not every key.
	var pa := {}
	var pb := {}
	for k in SAME_KEYS:
		pa[k] = a.get(k)
		pb[k] = b.get(k)
	var ja := JSON.stringify(JSON.parse_string(JSON.stringify(pa)), "", true)
	var jb := JSON.stringify(JSON.parse_string(JSON.stringify(pb)), "", true)
	return ja == jb


## One line for a farm: "Ann · Penguins · day 12".
static func summary(d: Dictionary) -> String:
	if d.is_empty() or not d.get("names") is Dictionary:
		return "Empty"
	var arc := "Penguins" if str(d.get("arc", "")) == "penguins" else "Gangsters"
	return "%s · %s · day %d" % [str((d["names"] as Dictionary).get("character", "?")), arc, int(d.get("day", 1))]


## What loading one farm into slot n would do, for the confirm card:
## {same, replaces (summary or ""), drops_restore (summary or "")}.
static func plan_one(d: Dictionary, n: int) -> Dictionary:
	var cur := farm_of(n)
	var same := same_farm(cur, d)
	var prev := restore_of(n)
	return {"same": same, "replaces": "" if same or cur.is_empty() else summary(cur),
		"drops_restore": "" if same or cur.is_empty() or prev.is_empty() else summary(prev)}


static func empty_slots() -> Array:
	var out: Array = []
	for n in SLOTS:
		if farm_of(n).is_empty():
			out.append(n)
	return out


## Loads one farm into slot n (n becomes the slot being played). The farm that
## was there goes to that slot's Restore. {ok, why, moved, same, name, day}.
static func apply_one(d: Dictionary, n: int) -> Dictionary:
	var res := {"ok": false, "why": "", "moved": false, "same": false, "name": "", "day": int(d.get("day", 1))}
	var names: Variant = d.get("names", {})
	res["name"] = str((names as Dictionary).get("character", "?")) if names is Dictionary else "?"
	if validate(d) != "":
		res["why"] = WHY["bad_farm"]
		return res
	if n != GameState.slot():
		GameState.use_slot(n)
	var cur := farm_of(n)
	if same_farm(cur, d):
		res["ok"] = true
		res["same"] = true
		return res
	var cache_before: Dictionary = SaveGame.load_all().duplicate(true)
	var live: Dictionary = GameState.run
	if not cur.is_empty():
		SaveGame.load_all()[GameState.prev_key()] = cur
		res["moved"] = true
	SaveGame.set_value(GameState.save_key(), d.duplicate(true))
	if not SaveGame.last_ok:
		_roll_back(cache_before, live)
		res["why"] = WHY.get(SaveGame.last_why, WHY["file"])
		res["moved"] = false
		return res
	GameState.run = {}
	if not GameState.has_run():
		_roll_back(cache_before, live)
		SaveGame.flush()
		res["why"] = WHY["bad_farm"]
		res["moved"] = false
		return res
	return res.merged({"ok": true}, true)


static func _roll_back(cache_before: Dictionary, live: Dictionary) -> void:
	var c := SaveGame.load_all()
	c.clear()
	c.merge(cache_before)
	GameState.run = live


## Loads a backup of all farms. Each backed-up slot replaces what is there
## (that farm goes to its Restore, unless it is the same farm); a backed-up
## Restore farm comes back only where the slot's Restore would otherwise be empty.
## {ok, why, loaded: [slot numbers], moved: [slot numbers]}
static func apply_all(d: Dictionary) -> Dictionary:
	var res := {"ok": false, "why": "", "loaded": [], "moved": []}
	var keep := GameState.slot()
	if not GameState.run.is_empty():
		GameState.save()
	var cache_before: Dictionary = SaveGame.load_all().duplicate(true)
	var live: Dictionary = GameState.run
	var c := SaveGame.load_all()
	var slots: Dictionary = d.get("slots", {})
	var rest: Dictionary = d.get("restore", {})
	for n in SLOTS:
		var f: Dictionary = slots.get(str(n), {})
		var cur := farm_of(n)
		if not f.is_empty() and not same_farm(cur, f):
			if not cur.is_empty():
				c[prev_key_of(n)] = cur
				(res["moved"] as Array).append(n)
			c[GameState.slot_key(n)] = f.duplicate(true)
			(res["loaded"] as Array).append(n)
		var r: Dictionary = rest.get(str(n), {})
		var pv: Variant = c.get(prev_key_of(n))
		if not r.is_empty() and not (pv is Dictionary and (pv as Dictionary).has("names")):
			c[prev_key_of(n)] = r.duplicate(true)
	if not SaveGame.flush():
		_roll_back(cache_before, live)
		res["why"] = WHY.get(SaveGame.last_why, WHY["file"])
		return res
	GameState.run = {}
	SaveGame.set_value("slot", keep)
	GameState.has_run()
	res["ok"] = true
	return res


## The confirm-card words for a decoded code going into slot n.
static func confirm_text(d: Dictionary, n: int) -> String:
	var p := plan_one(d, n)
	if bool(p["same"]):
		return "Slot %d already holds this farm (%s). Nothing to load." % [n, summary(d)]
	var t := "Load %s into slot %d?" % [summary(d), n]
	if str(p["replaces"]) != "":
		t += "\n%s, who is in slot %d now, moves to Restore." % [p["replaces"], n]
	if str(p["drops_restore"]) != "":
		t += "\nThe older Restore farm (%s) will be gone for good." % p["drops_restore"]
	return t


## The line after a load.
static func done_text(r: Dictionary, n: int) -> String:
	if not bool(r.get("ok", false)):
		return str(r.get("why", WHY["file"]))
	if bool(r.get("same", false)):
		return "Slot %d already holds %s's farm: nothing changed." % [n, r["name"]]
	var t := "Loaded %s (day %d) into slot %d." % [r["name"], int(r["day"]), n]
	if bool(r.get("moved", false)):
		t += " The farm that was here can be brought back with Restore."
	return t


## In-game Options "Back up this farm" (game_menu calls this guarded): saves first,
## then shows the code (web: a page box with Copy/Share/Save file) or copies it and
## offers a file (desktop). done(line) gets the words to show.
static func back_up_this_farm(host: Node, done: Callable) -> void:
	if GameState.run.is_empty():
		done.call(WHY["no_farm"])
		return
	GameState.save()
	var code := encode_slot(GameState.slot())
	if code == "":
		done.call(WHY["no_farm"])
		return
	if OS.has_feature("web"):
		web_code_box(code)
		done.call("Your code is on screen: Copy, Share or Save it somewhere safe.")
		return
	DisplayServer.clipboard_set(code)
	save_file(host, code, func(ok: bool, where: String) -> void:
		done.call(("Copied the code and saved %s." % where) if ok else "Copied the code. Paste it somewhere safe."))


# ---------------------------------------------------------------- files

static var _web_cb: Variant = null  # keeps the JS callback alive
static var _web_done: Callable


## Saves a code as a .dreams file: a download on the web, a save dialog elsewhere.
## done(ok: bool, where: String) is called when finished (web: right away).
static func save_file(host: Node, code: String, done: Callable) -> void:
	var fname := file_name(code)
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(code.to_utf8_buffer(), fname, "text/plain")
		done.call(true, fname)
		return
	var fd := _dialog(host, FileDialog.FILE_MODE_SAVE_FILE)
	fd.current_file = fname
	fd.file_selected.connect(func(path: String) -> void:
		var f := FileAccess.open(path, FileAccess.WRITE)
		var ok := f != null
		if ok:
			f.store_string(code)
			f.close()
		fd.queue_free()
		done.call(ok, path.get_file()))
	fd.canceled.connect(func() -> void:
		fd.queue_free()
		done.call(false, ""))
	fd.popup_centered_ratio(0.9)


## Picks a .dreams/.txt file and hands its text to done(text: String) ("" = cancelled).
static func open_file(host: Node, done: Callable) -> void:
	if OS.has_feature("web"):
		_web_listen(done)
		JavaScriptBridge.eval("""(function(){var i=document.createElement('input');i.type='file';i.accept='.dreams,.txt,text/plain';
i.onchange=function(){var f=i.files&&i.files[0];if(!f){return;}var r=new FileReader();r.onload=function(){window.dreamsTextIn(String(r.result||''));};r.readAsText(f);};
i.click();})();""", true)
		return
	var fd := _dialog(host, FileDialog.FILE_MODE_OPEN_FILE)
	fd.file_selected.connect(func(path: String) -> void:
		var txt := FileAccess.get_file_as_string(path)
		fd.queue_free()
		done.call(txt))
	fd.canceled.connect(func() -> void:
		fd.queue_free()
		done.call(""))
	fd.popup_centered_ratio(0.9)


static func _dialog(host: Node, mode: int) -> FileDialog:
	var fd := FileDialog.new()
	fd.file_mode = mode as FileDialog.FileMode
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.use_native_dialog = true
	fd.filters = PackedStringArray(["*.%s ; Dreams save" % FILE_EXT, "*.txt ; Text"])
	var docs := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if docs != "":
		fd.current_dir = docs
	host.add_child(fd)
	return fd


static func _web_listen(done: Callable) -> void:
	_web_done = done
	if _web_cb == null:
		_web_cb = JavaScriptBridge.create_callback(func(args: Array) -> void:
			if _web_done.is_valid():
				_web_done.call(str(args[0]) if args.size() > 0 else ""))
		var w: Variant = JavaScriptBridge.get_interface("window")
		if w:
			w.dreamsTextIn = _web_cb


## Web phones: a real page box to paste into (the game canvas gets no long-press
## Paste menu), with a Paste button that reads the clipboard when allowed.
## done(text) gets the box's text ("" = cancelled).
static func web_paste(done: Callable) -> void:
	_web_listen(done)
	JavaScriptBridge.eval("""(function(){var o=document.createElement('div');o.style.cssText='position:fixed;inset:0;z-index:9999;background:#000c;display:flex;align-items:center;justify-content:center';
var b=document.createElement('div');b.style.cssText='background:#f4e6c4;border-radius:12px;padding:14px;width:86%;max-width:420px;font:15px sans-serif;color:#2a1a10';
b.innerHTML='<b>Paste your Dreams save code</b><br><small>Press and hold in the box, then Paste. Or use the Paste button.</small>';
var t=document.createElement('textarea');t.style.cssText='width:100%;height:120px;margin:8px 0;font:11px monospace';t.placeholder='DRM2:...';
var row=document.createElement('div');row.style.cssText='display:flex;gap:8px';
function btn(l,f){var x=document.createElement('button');x.textContent=l;x.style.cssText='flex:1;padding:10px;font:bold 15px sans-serif;border-radius:8px;border:0;background:#c98a3a;color:#fff';x.onclick=f;row.appendChild(x);return x;}
if(navigator.clipboard&&navigator.clipboard.readText){var pb=btn('Paste',function(){navigator.clipboard.readText().then(function(v){t.value=v;},function(){pb.textContent='Hold the box';});});}
btn('Load',function(){var v=t.value;o.remove();window.dreamsTextIn(v);});
btn('Cancel',function(){o.remove();window.dreamsTextIn('');});
b.appendChild(t);b.appendChild(row);o.appendChild(b);document.body.appendChild(o);t.focus();})();""", true)


## Web: the code in a page box with Copy (with a fallback that works on iPhone),
## Share and Save as file.
static func web_code_box(code: String) -> void:
	var js := """(function(){var o=document.createElement('div');o.style.cssText='position:fixed;inset:0;z-index:9999;background:#000c;display:flex;align-items:center;justify-content:center';
var b=document.createElement('div');b.style.cssText='background:#f4e6c4;border-radius:12px;padding:14px;width:86%;max-width:420px;font:15px sans-serif;color:#2a1a10';
b.innerHTML='<b>Your Dreams save code</b><br><small>Keep it in a note or message, or save it as a file. Paste or load it on the other device.</small>';
var t=document.createElement('textarea');t.readOnly=true;t.value=CODE;t.style.cssText='width:100%;height:120px;margin:8px 0;font:11px monospace';
var row=document.createElement('div');row.style.cssText='display:flex;gap:8px;flex-wrap:wrap';
function btn(l,f){var x=document.createElement('button');x.textContent=l;x.style.cssText='flex:1;padding:10px;font:bold 15px sans-serif;border-radius:8px;border:0;background:#c98a3a;color:#fff';x.onclick=function(){f(x);};row.appendChild(x);return x;}
function byHand(x){t.readOnly=false;t.focus();t.setSelectionRange(0,t.value.length);var ok=false;try{ok=document.execCommand('copy');}catch(e){}t.readOnly=true;x.textContent=ok?'Copied!':'Select and copy';}
btn('Copy',function(x){if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(t.value).then(function(){x.textContent='Copied!';},function(){byHand(x);});}else{byHand(x);}});
if(navigator.share)btn('Share',function(){navigator.share({text:t.value}).catch(function(){});});
btn('Save file',function(x){var a=document.createElement('a');a.href=URL.createObjectURL(new Blob([t.value],{type:'text/plain'}));a.download=FNAME;document.body.appendChild(a);a.click();a.remove();x.textContent='Saved';});
btn('Close',function(){o.remove();});
b.appendChild(t);b.appendChild(row);o.appendChild(b);document.body.appendChild(o);t.focus();t.setSelectionRange(0,t.value.length);})();"""
	JavaScriptBridge.eval(js.replace("CODE", JSON.stringify(code)).replace("FNAME", JSON.stringify(file_name(code))), true)


## Web on iPhone/iPad in a Safari tab (not the Home Screen app): Safari may
## clear the farm after a week away.
static func ios_tab() -> bool:
	if not OS.has_feature("web_ios"):
		return false
	return not bool(JavaScriptBridge.eval("(window.matchMedia&&window.matchMedia('(display-mode: standalone)').matches)||navigator.standalone===true", true))

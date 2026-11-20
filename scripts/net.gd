class_name NetNode
extends Node
## Multiplayer (web-first). Talks to the relay in server/ over one WebSocket.
## Host-authoritative: the host's run is the world. Guests keep their OWN
## character, skills, inventory, pup and party (saved locally) but the host's
## day/time/weather, farm tiles, builds, sell box, quests-done and town flags.
##   Net.host(url) / Net.join(url, code) / Net.leave()
##   Net.online() / Net.is_host() / Net.room
## Every 0.1 s each player broadcasts {pos, scene, anim, flip}; GameMap spawns a
## Puppet per peer in the same scene. World actions by guests (till, plant,
## water, harvest, chop, mine, build, buy) are sent to the host as "act"; the
## host applies them to run and broadcasts the resulting "world" delta.

signal connected(host: bool)
signal disconnected(reason: String)
signal peers_changed
## A guest's own world was put back (left, host gone, gave up reconnecting).
signal went_home

const TICK := 0.1
var ws: WebSocketPeer = null
var url := ""
var room := ""
var my_id := -1
var _host := false
var peers := {}          # id -> {name, look, arc, scene, pos, anim, flip}
var _t := 0.0
var _pending_join := {}
var _world_t := 0.0
var _last_world := {}
var _arc_mismatch := false
# Reconnect: after an unexpected drop, try to rejoin the same room a few times.
var _retries := 0
var _retry_t := 0.0
var _last_room := ""
const MAX_RETRIES := 3
const BUFFER_BYTES := 1 << 20     # WebSocket buffers (the relay allows the host 1 MB frames)
const SAVE_EVERY := 10.0          # host_save (late joiners' snapshot): at most this often while only the clock moves
var _pushed := {}                 # host: the world as last broadcast (deltas are against this)
var _save_t := 0.0
## A stable id for this device, so a reconnect replaces our old socket on the
## relay instead of leaving a ghost (and keeps the host role).
var _token := ""
## A guest's own world (farm, day...) set aside while they visit someone else's,
## put back when they leave, and what gets saved meanwhile.
var _solo_backup: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func online() -> bool:
	return ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN and my_id > 0


func is_host() -> bool:
	return not online() or _host


func _connect(u: String) -> bool:
	url = u.strip_edges()
	if url == "":
		return false
	ws = WebSocketPeer.new()
	ws.inbound_buffer_size = BUFFER_BYTES   # a late farm's world is bigger than the 64 KB default
	ws.outbound_buffer_size = BUFFER_BYTES
	var err := ws.connect_to_url(url)
	if err != OK:
		ws = null
		disconnected.emit("Couldn't reach %s" % url)
		return false
	SaveGame.set_value("net_url", url)
	return true


func _tok() -> String:
	if _token == "":
		_token = str(SaveGame.get_value("net_token", ""))
		if _token == "":
			_token = "%x%x" % [randi(), Time.get_ticks_usec()]
			SaveGame.set_value("net_token", _token)
	return _token


func host(u: String) -> void:
	_host = true
	_pushed = {}
	_pending_join = {"t": "join", "room": "", "token": _tok(), "name": GameState.names()["character"], "look": _my_look(), "arc": GameState.run["arc"]}
	_connect(u)


func join(u: String, code: String) -> void:
	_host = false
	_pending_join = {"t": "join", "room": code.to_upper().strip_edges(), "create": false, "token": _tok(), "name": GameState.names()["character"], "look": _my_look(), "arc": GameState.run["arc"]}
	_connect(u)


func leave(why := "left") -> void:
	_retries = MAX_RETRIES  # a deliberate leave never reconnects
	_last_room = ""
	_restore_solo(why if why != "left" else "You left. You're back on your own farm.")
	if ws:
		ws.close()
	ws = null
	my_id = -1
	room = ""
	peers.clear()
	peers_changed.emit()
	disconnected.emit(why)


const LOOK_EVERY := 2.0
var _look_hash := 0
var _look_t := 0.0


func _my_look() -> Dictionary:
	var lk: Variant = GameState.run.get("look", {})
	var eq: Variant = GameState.run.get("equip", {})
	var dv: Variant = GameState.run.get("decor", {})
	var wr: Variant = (dv as Dictionary).get("wear", {}) if dv is Dictionary else {}
	return {"playable": GameState.run.get("playable", ""), "arc": str(GameState.run.get("arc", "")), "look": lk if lk is Dictionary else {}, "equip": eq if eq is Dictionary else {}, "wear": wr if wr is Dictionary else {}}


func _send(o: Dictionary) -> void:
	if ws and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(o))


func send_all(d: Dictionary) -> void:
	_send({"t": "all", "d": d})


func send_host(d: Dictionary) -> void:
	if _host:
		_handle_action(my_id, d)
	else:
		_send({"t": "all", "d": d})  # the host is in the room; others ignore "act"


func _process(delta: float) -> void:
	if ws == null:
		if _retry_t > 0.0:
			_retry_t -= delta
			if _retry_t <= 0.0 and _last_room != "" and _retries < MAX_RETRIES:
				_retries += 1
				_pending_join = {"t": "join", "room": _last_room, "create": false, "token": _tok(), "name": GameState.names()["character"], "look": _my_look(), "arc": GameState.run["arc"]}
				if not _connect(url):
					if _retries >= MAX_RETRIES:
						_restore_solo()  # gave up: back to our own world, not the host's offline
					else:
						_retry_t = 2.0 * (_retries + 1)
		return
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _pending_join.is_empty():
			_send(_pending_join)
			_pending_join = {}
		while ws != null and ws.get_available_packet_count() > 0:
			var pkt := ws.get_packet().get_string_from_utf8()
			var m: Variant = JSON.parse_string(pkt)
			if m is Dictionary:
				_on_msg(m)
		if ws == null:
			return  # a message made us leave
		if my_id > 0:
			_t += delta
			if _t >= TICK:
				_t = 0.0
				_broadcast_state()
			if _host:
				_save_t += delta
				_world_t += delta
				if _world_t >= 2.0:
					_world_t = 0.0
					_push_world()
	elif st == WebSocketPeer.STATE_CLOSED:
		var why := "connection closed (%d)" % ws.get_close_code()
		ws = null
		my_id = -1
		peers.clear()
		peers_changed.emit()
		if _last_room != "" and _retries < MAX_RETRIES:
			_retry_t = 2.0 * (_retries + 1)
			why += "; reconnecting (%d/%d)" % [_retries + 1, MAX_RETRIES]
		else:
			_restore_solo()
		if why.contains("reconnecting"):
			_toast("Connection lost, " + why.get_slice("; ", 1) + "...", Color(1, 0.85, 0.6))
		disconnected.emit(why)


func _on_msg(m: Dictionary) -> void:
	match str(m.get("t", "")):
		"joined":
			_look_hash = 0
			my_id = int(m["id"])
			room = str(m["room"])
			_last_room = room
			_retries = 0
			_host = bool(m.get("host", false))
			var fresh := _solo_backup.is_empty()  # first join, not a reconnect
			_arc_mismatch = false
			if _host and not _solo_backup.is_empty():
				# Rejoined a room whose host is gone: the host's farm goes with the host, we go home.
				leave("Your host left. You're back on your own farm.")
				return
			if not _host and _solo_backup.is_empty():
				for k in WORLD_KEYS:
					# null = the guest had no such key: drop it again later, never keep the host's.
					_solo_backup[k] = ((GameState.run[k].duplicate(true) if GameState.run[k] is Dictionary or GameState.run[k] is Array else GameState.run[k]) if GameState.run.has(k) else null)
			for p in m.get("peers", []):
				peers[int(p["id"])] = p
				if str(p.get("arc", "")) != str(GameState.run["arc"]):
					_arc_mismatch = true
			connected.emit(_host)
			if _arc_mismatch and not _host and fresh:
				var gm := get_tree().current_scene as GameMap if is_inside_tree() else null
				if gm and gm.hud:
					gm.hud.toast("Your host is on the other story: some places and builds will look different.")
			peers_changed.emit()
		"full":
			leave("That room is full (8 players).")
		"no_room":
			leave("No game with that code. Check the code with your host.")
		"peer_joined":
			_look_hash = 0  # the newcomer gets our look with the next state packet
			var p: Dictionary = m["peer"]
			peers[int(p["id"])] = p
			if str(p.get("arc", "")) != str(GameState.run["arc"]):
				_arc_mismatch = true
			peers_changed.emit()
			if _host:
				_push_world(int(p["id"]))
		"peer_left":
			peers.erase(int(m["id"]))
			peers_changed.emit()
		"peer_scene":
			if peers.has(int(m["id"])):
				peers[int(m["id"])]["scene"] = str(m["scene"])
			peers_changed.emit()
		"you_are_host":
			if not _solo_backup.is_empty():
				leave("Your host left. You're back on your own farm.")  # the host's farm goes with the host
				return
			_host = true
			_became_host()
			connected.emit(true)
		"world":
			_apply_world(m["d"])
		"msg":
			var from := int(m.get("from", 0))
			var dv: Variant = m.get("d", {})
			if not (dv is Dictionary):
				return
			var d: Dictionary = dv
			match str(d.get("k", "")):
				"state":
					var pv: Variant = d.get("pos", [0, 0])
					if peers.has(from) and pv is Array and (pv as Array).size() >= 2:
						peers[from]["pos"] = pv
						peers[from]["scene"] = str(d.get("scene", ""))
						peers[from]["anim"] = str(d.get("anim", "idle"))
						peers[from]["flip"] = bool(d.get("flip", false))
						peers[from]["look"] = d.get("look", peers[from].get("look", {}))
				"act":
					if _host:
						_handle_action(from, d)
				"world":
					var wd: Variant = d.get("d", {})
					if not _host and wd is Dictionary and bool(m.get("host", false)):  # only the host's world counts
						_apply_world(wd)
				"toast":
					if not bool(m.get("host", false)):
						return
					var m2 := get_tree().current_scene
					if m2 is GameMap:
						(m2 as GameMap).hud.toast(str(d.get("text", "")), Color(0.8, 0.9, 1.0))


func _broadcast_state() -> void:
	var m := get_tree().current_scene
	if not (m is GameMap) or (m as GameMap).player == null:
		return
	var p := (m as GameMap).player
	var st := {"k": "state", "pos": [snappedf(p.position.x, 0.5), snappedf(p.position.y, 0.5)], "scene": (m as GameMap).scene_id(), "anim": p.anim_name, "flip": p._anim.flip_h if p._anim else false}
	# The look (and wardrobe) rides along only when it changed, or every LOOK_EVERY s for
	# late joiners: receivers keep the last one (c10_10: it was sent whole 10x a second).
	var lk := _my_look()
	var h := hash(lk)
	_look_t += TICK
	if h != _look_hash or _look_t >= LOOK_EVERY:
		_look_hash = h
		_look_t = 0.0
		st["look"] = lk
	send_all(st)


# ---- world sync (host -> guests) ---------------------------------------------
## Only what's truly shared: the host's clock (and day length), difficulty
## (run.opts), weather and farm. Each player
## keeps their own money, bank, sell box, quests, story flags and friendships
## (overwriting those from the host let guests copy crystals and replay story).
## "decor_home" is the host's house look (DecorMode.home_view: placed pieces, wallpaper,
## flooring; never the decor box or wardrobe), so guests in the house see the host's decor.
const WORLD_KEYS := ["day", "time", "weather", "farm", "builds", "construction", "permits", "cleared", "placed", "day_len", "opts", "decor_home"]


func _push_world(to_id := -1) -> void:
	var d := {}
	for k in WORLD_KEYS:
		if k == "decor_home":
			d[k] = DecorMode.home_view()  # derived from run.decor, never stored in the host's run
		elif GameState.run.has(k):
			d[k] = GameState.run[k]
	if to_id > 0:
		_send({"t": "to", "id": to_id, "d": {"k": "world", "d": d}})  # a new guest gets everything
		return
	# Everyone else gets only what changed since the last push (a late farm's full
	# world passes the 64 KB frame size; the clock alone is a few bytes).
	var delta := world_delta(_pushed, d)
	_pushed = d.duplicate(true)
	if delta.size() > 2 or not (delta["_gone"] as Array).is_empty():
		send_all({"k": "world", "d": delta})
	var busy := delta.keys().any(func(k): return not (k in ["_delta", "_gone", "time"]))
	if busy or _save_t >= SAVE_EVERY:
		_save_t = 0.0
		_send({"t": "host_save", "d": d})  # the relay keeps a full copy for late joiners


## What changed between two worlds: changed keys whole, the farm per tile
## ("farm_d": key -> tile or null), removed keys in "_gone".
static func world_delta(old: Dictionary, now: Dictionary) -> Dictionary:
	var out := {"_delta": true, "_gone": []}
	for k in now:
		if old.has(k) and old[k] == now[k]:
			continue
		if k == "farm" and old.get("farm") is Dictionary and now[k] is Dictionary:
			var fd := {}
			var of: Dictionary = old["farm"]
			var nf: Dictionary = now["farm"]
			for t in nf:
				if not of.has(t) or of[t] != nf[t]:
					fd[t] = nf[t]
			for t in of:
				if not nf.has(t):
					fd[t] = null
			out["farm_d"] = fd
		else:
			out[k] = now[k]
	for k in old:
		if not now.has(k):
			out["_gone"].append(k)
	return out


## A delta from world_delta merged into run (guests).
static func merge_delta(run: Dictionary, d: Dictionary) -> void:
	for k in d:
		if k in WORLD_KEYS:
			run[k] = d[k]
	var fv: Variant = d.get("farm_d", null)
	if fv is Dictionary:
		var farm: Variant = run.get("farm", null)
		if not (farm is Dictionary):
			farm = {}
			run["farm"] = farm
		for t in fv:
			if fv[t] == null:
				(farm as Dictionary).erase(t)
			else:
				farm[t] = fv[t]
	var gv: Variant = d.get("_gone", [])
	if gv is Array:
		for k in gv:
			if str(k) in WORLD_KEYS:
				run.erase(str(k))


func _apply_world(d: Dictionary) -> void:
	if d.is_empty():
		return
	if bool(d.get("_delta", false)):
		if _last_world.is_empty():
			return  # a delta before our first full world: wait for the full one
		var day_was := int(GameState.run.get("day", 0))
		merge_delta(GameState.run, d)
		if int(GameState.run.get("day", 0)) > day_was and not _host:
			var rep := GameState.guest_morning()
			var m1 := get_tree().current_scene
			if m1 is GameMap and int(rep.get("earned", 0)) > 0:
				(m1 as GameMap).hud.toast("Morning! Your sell box paid ◆%d." % int(rep["earned"]), Color(1, 0.95, 0.6))
		_last_world = {"day": int(GameState.run.get("day", 0))}
		var md := get_tree().current_scene
		if md is GameMap and md.has_method("on_world_sync"):
			md.call("on_world_sync", d)
		return
	var scene_changed := false
	# The host's day we last saw (0 = first world since joining): only a real rollover is a morning.
	var host_day := int(_last_world.get("day", 0))
	var abs0 := GameState.now_abs()
	var day0 := int(GameState.run.get("day", 1))
	for k in d:
		if not (k in WORLD_KEYS):
			continue
		if k == "time" or k == "day":
			scene_changed = scene_changed or int(GameState.run.get(k, -1)) != int(d[k])
		if k == "farm" and not (d[k] is Dictionary):
			continue
		GameState.run[k] = d[k]
	if not _host:
		# A full world from the host: keys it doesn't have aren't ours to show (ours are in _solo_backup).
		for k in ["builds", "construction", "permits", "cleared", "weather", "placed", "decor_home"]:
			if not d.has(k):
				GameState.run.erase(k)
	if not _host and host_day == 0:
		GameState.shift_clock(GameState.now_abs() - abs0, int(GameState.run.get("day", 1)) - day0)  # first world: our timers move onto the host's clock
	# The host slept: a new morning for us too (our sell box, energy, health).
	if not _host and host_day > 0 and int(GameState.run.get("day", 0)) > host_day:
		var rep := GameState.guest_morning()
		var m0 := get_tree().current_scene
		if m0 is GameMap and int(rep.get("earned", 0)) > 0:
			(m0 as GameMap).hud.toast("Morning! Your sell box paid ◆%d." % int(rep["earned"]), Color(1, 0.95, 0.6))
	_last_world = d
	var m := get_tree().current_scene
	if m is GameMap and m.has_method("on_world_sync"):
		m.call("on_world_sync", d)


## Actions guests ask the host to do. Kept small and whitelisted; the host
## re-validates nothing fancy (friends only), just applies and re-broadcasts.
func _handle_action(from: int, d: Dictionary) -> void:
	var a := str(d.get("a", ""))
	var m := get_tree().current_scene
	match a:
		"farm_tile":
			var tv: Variant = d.get("tile", null)
			if tv is Dictionary and str(d.get("key", "")).contains(","):
				GameState.run["farm"][str(d["key"])] = tv
		"farm_clear":
			GameState.run["farm"].erase(str(d.get("key", "")))
		"cleared":
			var all_c: Dictionary = GameState.run.get("cleared", {})
			var lst: Variant = all_c.get(str(d.get("scene", "")), {})
			if lst is Dictionary:
				(lst as Dictionary)[str(d.get("key", ""))] = int(GameState.run["day"])
				all_c[str(d.get("scene", ""))] = lst
				GameState.run["cleared"] = all_c
		"build":
			# The guest asked; the host decides and pays (it's the host's farm).
			var msg := Builds.start(str(d.get("id", "")))
			_send({"t": "to", "id": from, "d": {"k": "toast", "text": "Host: " + msg}})
		"permit":
			var pm: Dictionary = GameState.run.get("permits", {})
			pm[str(d.get("id", ""))] = maxi(int(pm.get(str(d.get("id", "")), 0)), int(d.get("tier", 1)))
			GameState.run["permits"] = pm
		"sleep":
			# Guests in bed wait for the host: the day ends when the host sleeps.
			_beds[from] = true
			var all := true
			for pid in peers:
				if not _beds.has(pid):
					all = false
			if all and m is GameMap:
				(m as GameMap).hud.toast("Everyone else is in bed. Sleep when you're ready.", Color(0.9, 0.95, 1.0))
	if m is GameMap:
		(m as GameMap).on_world_sync({})  # soil now, full redraw at most every 2 s
	_push_world()


var _beds := {}  # guests in bed tonight (not saved)


func clear_beds() -> void:
	_beds.clear()


## We now own the world, so saves write it from here on. Our own farm
## (kept aside while visiting) goes to Restore instead of being lost.
func _became_host() -> void:
	_pushed = {}
	if not _solo_backup.is_empty() and not GameState.run.is_empty():
		var keep := GameState.run.duplicate(true)
		for k in _solo_backup:
			if _solo_backup[k] == null:
				keep.erase(k)
			else:
				keep[k] = _solo_backup[k]
		GameState.shift_clock(int(keep.get("day", 1)) * 1440 + int(keep.get("time", GameState.DAY_START)) - GameState.now_abs(), int(keep.get("day", 1)) - int(GameState.run.get("day", 1)), keep)
		var had_prev := SaveGame.get_value(GameState.prev_key(), null) is Dictionary
		SaveGame.set_value(GameState.prev_key(), keep)
		var gm := get_tree().current_scene as GameMap if is_inside_tree() else null
		if gm and gm.hud:
			gm.hud.toast("You're host now. Your own farm is kept under Restore%s." % (" (it replaced the older Restore farm)" if had_prev else ""))
	_solo_backup = {}


func _restore_solo(why := "Lost your host. You're back on your own farm.") -> void:
	_last_world = {}  # the next join's first world is not a morning
	if _solo_backup.is_empty():
		return
	if GameState.run.is_empty():
		_solo_backup = {}
		return
	var abs0 := GameState.now_abs()
	var day0 := int(GameState.run.get("day", 1))
	for k in _solo_backup:
		if _solo_backup[k] == null:
			GameState.run.erase(k)
		else:
			GameState.run[k] = _solo_backup[k]
	GameState.shift_clock(GameState.now_abs() - abs0, int(GameState.run.get("day", 1)) - day0)  # and back onto ours
	_solo_backup = {}
	GameState.save()
	went_home.emit()
	# The map on screen is still the host's: walk home so what's drawn is our own farm.
	var gm := get_tree().current_scene as GameMap if is_inside_tree() else null
	if gm and not gm._changing:
		_toast(why, Color(1, 0.85, 0.6))
		gm.go_to("farm", Vector2.ZERO, "down", true)


func _toast(text: String, col := Color.WHITE) -> void:
	var gm := get_tree().current_scene as GameMap if is_inside_tree() else null
	if gm and gm.hud:
		gm.hud.toast(text, col)


## A guest on someone else's world, also while reconnecting (the host's world is still loaded).
func visiting() -> bool:
	return not _host and not _solo_backup.is_empty()


## Our OWN builds: while visiting, run.builds is the host's, ours are kept aside.
## Use this wherever a guest must not borrow the host's progress (station tiers,
## region unlocks). Static so script-mode tests without the autoload work.
static func own_builds() -> Dictionary:
	var n := Net.i()
	var v: Variant = GameState.run.get("builds", {})
	if n != null and n.visiting():
		v = n._solo_backup.get("builds", {})
	return v if v is Dictionary else {}


## Tier of one of OUR builds (Builds.built_tier semantics, but never the host's).
static func own_tier(id: String) -> int:
	var v: Variant = own_builds().get(id, 0)
	if v is bool:
		v = 1 if v else 0
	return maxi(1, int(v)) if id == "house" else int(v)


## What to write to the save file: while visiting as a guest, your own world.
func save_view(run: Dictionary) -> Dictionary:
	if _solo_backup.is_empty() or _host:
		return run
	var v := run.duplicate(true)  # deep: the timers are moved on the copy only
	var host_abs := GameState.now_abs()
	var host_day := int(run.get("day", 1))
	for k in _solo_backup:
		if _solo_backup[k] == null:
			v.erase(k)
		else:
			v[k] = _solo_backup[k]
	# Back onto our own clock, so a save made mid-visit doesn't keep host-clock timers.
	GameState.shift_clock(int(v.get("day", 1)) * 1440 + int(v.get("time", GameState.DAY_START)) - host_abs, int(v.get("day", 1)) - host_day, v)
	return v

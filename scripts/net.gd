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
	_pending_join = {"t": "join", "room": "", "token": _tok(), "name": GameState.names()["character"], "look": _my_look(), "arc": GameState.run["arc"]}
	_connect(u)


func join(u: String, code: String) -> void:
	_host = false
	_pending_join = {"t": "join", "room": code.to_upper().strip_edges(), "create": false, "token": _tok(), "name": GameState.names()["character"], "look": _my_look(), "arc": GameState.run["arc"]}
	_connect(u)


func leave() -> void:
	_retries = MAX_RETRIES  # a deliberate leave never reconnects
	_last_room = ""
	_restore_solo()
	if ws:
		ws.close()
	ws = null
	my_id = -1
	room = ""
	peers.clear()
	peers_changed.emit()
	disconnected.emit("left")


func _my_look() -> Dictionary:
	var lk: Variant = GameState.run.get("look", {})
	var eq: Variant = GameState.run.get("equip", {})
	return {"playable": GameState.run.get("playable", ""), "arc": str(GameState.run.get("arc", "")), "look": lk if lk is Dictionary else {}, "equip": eq if eq is Dictionary else {}}


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
					_retry_t = 2.0 * (_retries + 1)
		return
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _pending_join.is_empty():
			_send(_pending_join)
			_pending_join = {}
		while ws.get_available_packet_count() > 0:
			var pkt := ws.get_packet().get_string_from_utf8()
			var m: Variant = JSON.parse_string(pkt)
			if m is Dictionary:
				_on_msg(m)
		if my_id > 0:
			_t += delta
			if _t >= TICK:
				_t = 0.0
				_broadcast_state()
			if _host:
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
		disconnected.emit(why)


func _on_msg(m: Dictionary) -> void:
	match str(m.get("t", "")):
		"joined":
			my_id = int(m["id"])
			room = str(m["room"])
			_last_room = room
			_retries = 0
			_host = bool(m.get("host", false))
			if not _host and _solo_backup.is_empty():
				for k in WORLD_KEYS:
					if GameState.run.has(k):
						_solo_backup[k] = GameState.run[k].duplicate(true) if GameState.run[k] is Dictionary or GameState.run[k] is Array else GameState.run[k]
			for p in m.get("peers", []):
				peers[int(p["id"])] = p
				if str(p.get("arc", "")) != str(GameState.run["arc"]):
					_arc_mismatch = true
			connected.emit(_host)
			peers_changed.emit()
		"full":
			disconnected.emit("That room is full (8 players).")
			leave()
		"no_room":
			disconnected.emit("No game with that code. Check the code with your host.")
			leave()
		"peer_joined":
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
			_host = true
			# We now own the world, so saves write it from here on. Our own farm
			# (kept aside while visiting) goes to Restore instead of being lost.
			if not _solo_backup.is_empty():
				var keep := GameState.run.duplicate(true)
				keep.merge(_solo_backup, true)
				SaveGame.set_value(GameState.prev_key(), keep)
				var gm := get_tree().current_scene as GameMap if is_inside_tree() else null
				if gm and gm.hud:
					gm.hud.toast("You're host now. Your own farm is kept under Restore.")
			_solo_backup = {}
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
					if not _host and wd is Dictionary:
						_apply_world(wd)
				"toast":
					var m2 := get_tree().current_scene
					if m2 is GameMap:
						(m2 as GameMap).hud.toast(str(d.get("text", "")), Color(0.8, 0.9, 1.0))


func _broadcast_state() -> void:
	var m := get_tree().current_scene
	if not (m is GameMap) or (m as GameMap).player == null:
		return
	var p := (m as GameMap).player
	send_all({"k": "state", "pos": [snappedf(p.position.x, 0.5), snappedf(p.position.y, 0.5)], "scene": (m as GameMap).scene_id(), "anim": p.anim_name, "flip": p._anim.flip_h if p._anim else false, "look": _my_look()})


# ---- world sync (host -> guests) ---------------------------------------------
## Only what's truly shared: the host's clock, weather and farm. Each player
## keeps their own money, bank, sell box, quests, story flags and friendships
## (overwriting those from the host let guests copy crystals and replay story).
const WORLD_KEYS := ["day", "time", "weather", "farm", "builds", "construction", "permits", "cleared"]


func _push_world(to_id := -1) -> void:
	var d := {}
	for k in WORLD_KEYS:
		if GameState.run.has(k):
			d[k] = GameState.run[k]
	if to_id > 0:
		_send({"t": "to", "id": to_id, "d": {"k": "world", "d": d}})
	else:
		send_all({"k": "world", "d": d})
		_send({"t": "host_save", "d": d})


func _apply_world(d: Dictionary) -> void:
	if d.is_empty():
		return
	var scene_changed := false
	var old_day := int(GameState.run.get("day", 0))
	for k in d:
		if not (k in WORLD_KEYS):
			continue
		if k == "time" or k == "day":
			scene_changed = scene_changed or int(GameState.run.get(k, -1)) != int(d[k])
		if k == "farm" and not (d[k] is Dictionary):
			continue
		GameState.run[k] = d[k]
	# The host slept: a new morning for us too (our sell box, energy, health).
	if not _host and int(GameState.run.get("day", 0)) > old_day and old_day > 0:
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
		(m as GameMap).queue_redraw()
	_push_world()


var _beds := {}  # guests in bed tonight (not saved)


func clear_beds() -> void:
	_beds.clear()


func _restore_solo() -> void:
	if _solo_backup.is_empty():
		return
	for k in _solo_backup:
		GameState.run[k] = _solo_backup[k]
	_solo_backup = {}
	GameState.save()


## What to write to the save file: while visiting as a guest, your own world.
func save_view(run: Dictionary) -> Dictionary:
	if _solo_backup.is_empty() or _host:
		return run
	var v := run.duplicate()
	for k in _solo_backup:
		v[k] = _solo_backup[k]
	return v

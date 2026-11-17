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


func host(u: String) -> void:
	_host = true
	_pending_join = {"t": "join", "room": "", "name": GameState.names()["character"], "look": _my_look(), "arc": GameState.run["arc"]}
	_connect(u)


func join(u: String, code: String) -> void:
	_host = false
	_pending_join = {"t": "join", "room": code.to_upper().strip_edges(), "create": false, "name": GameState.names()["character"], "look": _my_look(), "arc": GameState.run["arc"]}
	_connect(u)


func leave() -> void:
	_retries = MAX_RETRIES  # a deliberate leave never reconnects
	_last_room = ""
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
	return {"playable": GameState.run.get("playable", ""), "look": lk if lk is Dictionary else {}, "equip": eq if eq is Dictionary else {}}


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
				_pending_join = {"t": "join", "room": _last_room, "create": false, "name": GameState.names()["character"], "look": _my_look(), "arc": GameState.run["arc"]}
				_connect(url)
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
		disconnected.emit(why)


func _on_msg(m: Dictionary) -> void:
	match str(m.get("t", "")):
		"joined":
			my_id = int(m["id"])
			room = str(m["room"])
			_last_room = room
			_retries = 0
			_host = bool(m.get("host", false))
			for p in m.get("peers", []):
				peers[int(p["id"])] = p
				if str(p.get("arc", "")) != str(GameState.run["arc"]):
					_arc_mismatch = true
			connected.emit(_host)
			peers_changed.emit()
		"full":
			disconnected.emit("That room is full (8 players).")
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
			connected.emit(true)
		"world":
			_apply_world(m["d"])
		"msg":
			var from := int(m.get("from", 0))
			var d: Dictionary = m.get("d", {})
			match str(d.get("k", "")):
				"state":
					if peers.has(from):
						peers[from]["pos"] = d.get("pos", [0, 0])
						peers[from]["scene"] = str(d.get("scene", ""))
						peers[from]["anim"] = str(d.get("anim", "idle"))
						peers[from]["flip"] = bool(d.get("flip", false))
						peers[from]["look"] = d.get("look", peers[from].get("look", {}))
				"act":
					if _host:
						_handle_action(from, d)
				"world":
					if not _host:
						_apply_world(d.get("d", {}))
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
const WORLD_KEYS := ["day", "time", "weather", "farm", "builds", "construction", "permits", "sellbox", "flags", "quests", "board", "jobs", "friendship", "bank"]


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
	for k in d:
		if k == "time" or k == "day":
			scene_changed = scene_changed or int(GameState.run.get(k, -1)) != int(d[k])
		GameState.run[k] = d[k]
	_last_world = d
	var m := get_tree().current_scene
	if m is GameMap and m.has_method("on_world_sync"):
		m.call("on_world_sync", d)


## Actions guests ask the host to do. Kept small and whitelisted; the host
## re-validates nothing fancy (friends only), just applies and re-broadcasts.
func _handle_action(from: int, d: Dictionary) -> void:
	var a := str(d.get("a", ""))
	match a:
		"farm_tile":
			GameState.run["farm"][str(d["key"])] = d["tile"]
		"farm_clear":
			GameState.run["farm"].erase(str(d["key"]))
		"flag":
			GameState.run["flags"][str(d["key"])] = d["val"]
		"sellbox":
			GameState.run["sellbox"][str(d["id"])] = int(GameState.run["sellbox"].get(str(d["id"]), 0)) + int(d["n"])
		"build":
			Builds.start(str(d["id"]))
		"sleep":
			# A guest went to bed: the day ends when every player is in bed (or the host sleeps).
			GameState.run["flags"]["bed_" + str(from)] = true
			var all := true
			for pid in peers:
				if not GameState.run["flags"].has("bed_" + str(pid)):
					all = false
			if all:
				var m := get_tree().current_scene
				if m is GameMap and m.has_method("_sleep"):
					m.call("_sleep")
				for pid in peers:
					GameState.run["flags"].erase("bed_" + str(pid))
	_push_world()

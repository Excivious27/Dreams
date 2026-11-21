class_name NetRelayRoom
extends RefCounted
## One co-op room, run the way server/server.js runs it (S1 P4): join/reconnect by
## token, host role with a grace period, peer_joined/peer_left/peer_scene, msg
## fan-out stamped with from + host, the host's snapshot for late joiners, 8 max,
## guest frame-size and rate guards. Used by NetTransportLoop (tests) and by the
## Steam lobby owner (NetTransportSteam), so every transport behaves like the relay.
## Members are small ints; out[id] is a Callable(frame: Dictionary) that delivers.

const MAX := 8

var code := ""
var host := -1
var host_token := ""
var host_gone := -1.0          # seconds since the host left (-1 = host present)
var world: Variant = null
var guard := true              # enforce GUEST_CAP / HOST_CAP and the msg budget
var info := {}                 # id -> {id, name, look, arc, scene}
var token := {}                # id -> device token / SteamID string
var out := {}                  # id -> Callable(frame)
var budget := {}               # id -> msgs left this second
var _refill := 0.0


func _send(id: int, o: Dictionary) -> void:
	var c: Variant = out.get(id)
	if c is Callable and (c as Callable).is_valid():
		(c as Callable).call(o)


## A member's "join" frame. deliver = Callable(frame) for that member.
func join(id: int, m: Dictionary, deliver: Callable) -> void:
	var tok := str(m.get("token", ""))
	if tok != "":
		for pid: int in info.keys():
			if pid != id and str(token.get(pid, "")) == tok:
				_drop(pid)
				for q: int in info:
					_send(q, {"t": "peer_left", "id": pid})
				if host == pid:
					host = id
		if host_token != "" and host_token == tok:
			host = id
			host_gone = -1.0
	if host < 0 or (not info.has(host) and host != id and host_gone < 0.0) or (not info.has(host) and host != id and host_gone >= NetTransport.HOST_GRACE):
		host = id
		host_token = tok
		host_gone = -1.0
	if info.size() >= MAX:
		deliver.call({"t": "full"})
		return
	out[id] = deliver
	token[id] = tok
	budget[id] = NetTransport.RATE_PER_SEC
	var me := {"id": id, "name": str(m.get("name", "Player")).substr(0, 24), "look": m.get("look", {}), "arc": m.get("arc", "penguins"), "scene": "farm"}
	if m.has("proto"):
		me["proto"] = m["proto"]
	var others: Array = []
	for pid: int in info:
		others.append(info[pid])
	info[id] = me
	var is_host := host == id
	_send(id, {"t": "joined", "id": id, "room": code, "host": is_host, "peers": others})
	if not is_host and world != null:
		_send(id, {"t": "world", "d": world})
	for pid: int in info:
		if pid != id:
			_send(pid, {"t": "peer_joined", "peer": me})


## Any other frame from a member. size = its bytes on the wire (for the guards).
func frame(id: int, m: Dictionary, size := 0) -> void:
	if not info.has(id):
		return
	if guard:
		if size > (NetTransport.HOST_CAP if host == id else NetTransport.GUEST_CAP):
			return
		budget[id] = int(budget.get(id, 0)) - 1
		if int(budget[id]) < 0:
			return
	var t := str(m.get("t", ""))
	if t == "host_save":
		if host == id:
			var d: Variant = m.get("d")
			if d is Dictionary and bool((d as Dictionary).get("_delta", false)) and world is Dictionary:
				for k: String in d:
					if k != "_delta":
						world[k] = d[k]
			else:
				world = d
		return
	if t == "scene":
		info[id]["scene"] = str(m.get("scene", ""))
		for pid: int in info:
			if pid != id:
				_send(pid, {"t": "peer_scene", "id": id, "scene": str(m.get("scene", ""))})
		return
	var from_host := host == id
	if t == "to":
		var to := int(m.get("id", -1))
		if info.has(to):
			_send(to, {"t": "msg", "from": id, "host": from_host, "d": m.get("d")})
	elif t == "all":
		for pid: int in info:
			if pid != id:
				_send(pid, {"t": "msg", "from": id, "host": from_host, "d": m.get("d")})


func _drop(id: int) -> void:
	info.erase(id)
	out.erase(id)
	token.erase(id)
	budget.erase(id)


## A member's connection closed.
func leave(id: int) -> void:
	if not info.has(id):
		return
	_drop(id)
	for pid: int in info:
		_send(pid, {"t": "peer_left", "id": id})
	if host == id and not info.is_empty():
		host_gone = 0.0


## Game time passes: refill budgets, hand the host role on after the grace.
func tick(delta: float) -> void:
	_refill += delta
	if _refill >= 1.0:
		_refill = 0.0
		for pid: int in budget:
			budget[pid] = NetTransport.RATE_PER_SEC
	if host_gone >= 0.0:
		host_gone += delta
		if host_gone >= NetTransport.HOST_GRACE and not info.has(host) and not info.is_empty():
			host = int(info.keys()[0])
			host_token = str(token.get(host, ""))
			host_gone = -1.0
			_send(host, {"t": "you_are_host"})

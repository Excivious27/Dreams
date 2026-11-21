class_name NetTransportLoop
extends NetTransport
## In-memory relay twin for headless tests (S1 P4): every NetTransportLoop on the
## same Bus talks through a NetRelayRoom exactly like the live relay, and frames
## go through JSON like the wire (ints come back as floats, as on the relay).


class Bus:
	extends RefCounted
	var rooms := {}        # code -> NetRelayRoom
	var next_id := 1
	var _frame := -1
	var _n := 0

	func tick(delta: float) -> void:
		var f := Engine.get_process_frames()
		if f == _frame:
			return
		_frame = f
		for k: String in rooms.keys():
			var r: NetRelayRoom = rooms[k]
			r.tick(delta)
			if r.ended:
				rooms.erase(k)  # C17: a room the host ended is gone (next join: no_room)

	func new_code() -> String:
		_n += 1
		return "LP%02d" % _n


var bus: Bus
var id := -1
var room: NetRelayRoom = null
var _open := false
var _closed := false
var _inbox: Array = []
var _last_join := {}


func _init(b: Bus) -> void:
	bus = b


func open(_target: String, _join_msg: Dictionary) -> bool:
	id = bus.next_id
	bus.next_id += 1
	_open = true
	_closed = false
	return true


func poll(delta: float) -> void:
	bus.tick(delta)


func is_open() -> bool:
	return _open


func closed() -> bool:
	return _closed


func close_reason() -> String:
	return "connection closed (1006)"


func _deliver(o: Dictionary) -> void:
	var w: Variant = JSON.parse_string(JSON.stringify(o))
	if w is Dictionary:
		_inbox.append(w)


func send(frame: Dictionary) -> void:
	if not _open:
		return
	var bytes := JSON.stringify(frame).to_utf8_buffer().size()
	var m: Variant = JSON.parse_string(JSON.stringify(frame))
	if not (m is Dictionary):
		return
	if str(m.get("t", "")) == "join":
		_last_join = m
		var code := str(m.get("room", "")).to_upper().substr(0, 8)
		if bus.rooms.has(code) and (bus.rooms[code] as NetRelayRoom).ended:
			bus.rooms.erase(code)
		if code != "" and not bus.rooms.has(code) and m.get("create", true) == false:
			_deliver({"t": "no_room"})
			return
		if code == "" or not bus.rooms.has(code):
			if code == "":
				code = bus.new_code()
			var r := NetRelayRoom.new()
			r.code = code
			bus.rooms[code] = r
		room = bus.rooms[code]
		room.join(id, m, _deliver)
		return
	if room:
		room.frame(id, m, bytes)


func take() -> Array:
	var o := _inbox
	_inbox = []
	return o


## Simulate a dropped line (tests): the room sees us leave, we see "closed".
func drop() -> void:
	if room:
		room.leave(id)
	room = null
	_open = false
	_closed = true


func close() -> void:
	if room:
		room.leave(id)
	room = null
	_open = false


func reopen() -> bool:
	return open("", {})


func caps() -> Dictionary:
	return {"max_frame": NetTransport.HOST_CAP, "keeps_snapshot": true, "kind": "loop"}

class_name NetLag
extends NetTransport
## C17 P3 (c17_11-05, c17_01-18): a phone-network shim around any NetTransport
## (the loop relay twin in tests). Adds latency + jitter both ways, loss of the
## frames a busy relay may drop (NetTransport.droppable: plain position ticks; the
## relay is a TCP WebSocket, so nothing else is ever lost), cell-handover stalls
## (hold everything, then release in one burst), a half-open line (sends vanish,
## nothing arrives, the socket still looks open) and app background (nothing taken
## until resumed, then the whole backlog at once).
## Time is the sum of poll() deltas: deterministic under --fixed-fps 60 with seed.
## Settings: configure("lat=250,jit=100,loss=0.05") or the fields directly.

var inner: NetTransport
var lat := 0.0        # seconds one way
var jit := 0.0        # seconds of extra random delay (0..jit)
var loss := 0.0       # chance a droppable frame is lost
var half_open := false
var paused := false
var t := 0.0
var rng := RandomNumberGenerator.new()
var sent := 0         # frames handed to the line (tests)
var lost := 0         # frames the shim dropped (tests)
var _out: Array = []  # [release_time, frame]
var _in: Array = []   # [release_time, frame]
var _stall_until := -1.0
var _last_in := 0.0
var _last_out := 0.0


func _init(wrap: NetTransport, seed_v := 1) -> void:
	inner = wrap
	rng.seed = seed_v


## "lat=250,jit=100,loss=0.05,stall=800" (ms; stall starts now).
func configure(spec: String) -> NetLag:
	for part in spec.split(",", false):
		var kv := part.split("=")
		if kv.size() != 2:
			continue
		var v := float(kv[1])
		match kv[0].strip_edges():
			"lat": lat = v / 1000.0
			"jit": jit = v / 1000.0
			"loss": loss = v
			"stall": stall(v / 1000.0)
	return self


## Hold every frame (both ways) for sec, then release them together.
func stall(sec: float) -> void:
	_stall_until = maxf(_stall_until, t + sec)


func _delay() -> float:
	return lat + (rng.randf() * jit if jit > 0.0 else 0.0)


func open(target: String, join_msg: Dictionary) -> bool:
	return inner.open(target, join_msg)


func poll(delta: float) -> void:
	t += maxf(0.0, delta)
	var held := t < _stall_until
	# Outbound: release due frames in order (a WebSocket keeps order).
	while not held and not _out.is_empty() and float(_out[0][0]) <= t:
		var f: Dictionary = _out.pop_front()[1]
		inner.send(f)
	inner.poll(delta)
	for f: Dictionary in inner.take():
		if half_open:
			lost += 1
			continue
		if loss > 0.0 and NetTransport.droppable(f) and rng.randf() < loss:
			lost += 1
			continue
		_last_in = maxf(_last_in, t + _delay())
		_in.append([_last_in, f])


func is_open() -> bool:
	return inner.is_open()


func closed() -> bool:
	return inner.closed()


func close_reason() -> String:
	return inner.close_reason()


func send(frame: Dictionary) -> void:
	sent += 1
	if half_open:
		lost += 1
		return
	if loss > 0.0 and NetTransport.droppable(frame) and rng.randf() < loss:
		lost += 1
		return
	if lat <= 0.0 and jit <= 0.0 and t >= _stall_until and _out.is_empty():
		inner.send(frame)
		return
	_last_out = maxf(_last_out, t + _delay())
	_out.append([_last_out, frame])


func take() -> Array:
	if paused or t < _stall_until:
		return []
	var o: Array = []
	while not _in.is_empty() and float(_in[0][0]) <= t:
		o.append(_in.pop_front()[1])
	return o


## Frames still on the line, both ways (tests).
func in_flight() -> int:
	return _in.size() + _out.size()


func close() -> void:
	_out.clear()
	_in.clear()
	inner.close()


func reopen() -> bool:
	_out.clear()
	_in.clear()
	return inner.reopen()


func caps() -> Dictionary:
	var c := inner.caps().duplicate()
	c["lag"] = true
	return c


## Pass-through for the loop twin's simulated drop.
func drop() -> void:
	_out.clear()
	_in.clear()
	if inner.has_method("drop"):
		inner.call("drop")

class_name NetTransportWs
extends NetTransport
## The live relay (server/) over one WebSocket: the web/phone transport, and the
## desktop "room code" path for cross-play with phones. Moved out of net.gd as is.

const BUFFER_BYTES := 1 << 20     # WebSocket buffers (the relay allows the host 1 MB frames)

var ws: WebSocketPeer = null
var url := ""
var _code := 0


func open(target: String, _join_msg: Dictionary) -> bool:
	url = target.strip_edges()
	if url == "":
		return false
	ws = WebSocketPeer.new()
	ws.inbound_buffer_size = BUFFER_BYTES   # a late farm's world is bigger than the 64 KB default
	ws.outbound_buffer_size = BUFFER_BYTES
	var err := ws.connect_to_url(url)
	if err != OK:
		ws = null
		return false
	return true


func poll(_delta: float) -> void:
	if ws:
		ws.poll()


func is_open() -> bool:
	return ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN


func closed() -> bool:
	return ws == null or ws.get_ready_state() == WebSocketPeer.STATE_CLOSED


func close_reason() -> String:
	return "connection closed (%d)" % (ws.get_close_code() if ws else _code)


func send(frame: Dictionary) -> void:
	if is_open():
		ws.send_text(JSON.stringify(frame))


func take() -> Array:
	var out: Array = []
	while ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN and ws.get_available_packet_count() > 0:
		var m: Variant = JSON.parse_string(ws.get_packet().get_string_from_utf8())
		if m is Dictionary:
			out.append(m)
	return out


func close() -> void:
	if ws:
		ws.close()
	ws = null


func reopen() -> bool:
	return open(url, {})


func caps() -> Dictionary:
	return {"max_frame": NetTransport.HOST_CAP, "keeps_snapshot": true, "kind": "relay"}

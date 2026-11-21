class_name NetTransport
extends RefCounted
## The wire under NetNode (S1 P4). Every transport speaks the RELAY PROTOCOL
## (server/server.js): it takes the frames NetNode sends ({t: join/all/to/
## host_save/scene}) and hands back the frames the relay sends ({t: joined/
## peer_joined/peer_left/peer_scene/msg/world/full/no_room/you_are_host/
## old_build}). So nothing above the transport knows which wire it is on.
##   NetTransportWs    - the live relay over a WebSocket (web, phone, desktop room codes)
##   NetTransportLoop  - an in-memory relay twin for headless tests
##   NetTransportSteam - Steam lobbies + Steam Networking Messages (desktop only;
##                       loaded by path, never named, so the web export never parses it)

## Guest guards, the same numbers as server/server.js (GUEST_CAP, the 120 msg/s
## budget, HOST_CAP). A transport that plays relay (Steam's lobby owner) enforces them.
const GUEST_CAP := 64 * 1024
const HOST_CAP := 1024 * 1024
const RATE_PER_SEC := 120
## Sanity cap on any decoded frame: bigger is dropped and logged, never a crash.
const MAX_FRAME := 4 * 1024 * 1024
## Seconds a gone host keeps the host role before the room moves on (server.js HOST_GRACE_MS).
const HOST_GRACE := 30.0


## Start connecting. target: a URL (relay) or a lobby id ("" = create, Steam).
func open(_target: String, _join_msg: Dictionary) -> bool:
	return false


func poll(_delta: float) -> void:
	pass


## Connected and ready to send.
func is_open() -> bool:
	return false


## The connection ended (after open() succeeded).
func closed() -> bool:
	return true


func close_reason() -> String:
	return "connection closed"


func send(_frame: Dictionary) -> void:
	pass


## Frames received since the last call, decoded (relay-protocol dictionaries).
func take() -> Array:
	return []


func close() -> void:
	pass


## Reconnect to the same place after a drop (same URL / same lobby). False = can't.
func reopen() -> bool:
	return false


func caps() -> Dictionary:
	return {"max_frame": MAX_FRAME, "keeps_snapshot": false, "kind": "none"}


## Frames that may be dropped on a busy line: position ticks without a look.
static func droppable(frame: Dictionary) -> bool:
	if str(frame.get("t", "")) != "all":
		return false
	var d: Variant = frame.get("d", {})
	return d is Dictionary and str((d as Dictionary).get("k", "")) == "state" and not (d as Dictionary).has("look")

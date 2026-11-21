class_name FakeSteam
extends RefCounted
## In-process Steam double for headless co-op tests (S1 P4): the slice of the
## GodotSteam surface NetTransportSteam uses (lobbies, lobby data, Steam
## Networking Messages, session requests, rich presence). One FakeSteam = one
## "Steam"; user(sid) gives each fake player its own backend object.
## loss = chance an UNRELIABLE send is dropped (reliable sends always arrive).

var lobbies := {}     # id -> {owner, members: Array, data: {}, max}
var users := {}       # sid -> User
var loss := 0.0
var _next_lobby := 109775241000000000


class User:
	extends Object
	signal lobby_created(connect: int, lobby_id: int)
	signal lobby_joined(lobby_id: int, permissions: int, locked: bool, response: int)
	signal lobby_chat_update(lobby_id: int, changed_id: int, making_change_id: int, chat_state: int)
	signal network_messages_session_request(remote_steam_id: int)
	signal join_requested(lobby_id: int, steam_id: int)

	var bus: FakeSteam
	var sid := 0
	var queue := {0: [], 1: []}
	var accepted := {}
	var requested := {}
	var presence := {}
	var sent := 0

	func getSteamID() -> int:
		return sid

	func createLobby(_type: int, max_members: int) -> void:
		var id := bus._next_lobby
		bus._next_lobby += 1
		bus.lobbies[id] = {"owner": sid, "members": [sid], "data": {}, "max": max_members}
		lobby_created.emit(1, id)

	func joinLobby(id: int) -> void:
		var l: Variant = bus.lobbies.get(id)
		if l == null:
			lobby_joined.emit(id, 0, false, 2)  # doesn't exist
			return
		if (l["members"] as Array).size() >= int(l["max"]):
			lobby_joined.emit(id, 0, false, 4)  # full
			return
		if not (l["members"] as Array).has(sid):
			(l["members"] as Array).append(sid)
		lobby_joined.emit(id, 0, false, 1)
		for m: int in l["members"]:
			if m != sid:
				bus.users[m].lobby_chat_update.emit(id, sid, sid, 1)

	func leaveLobby(id: int) -> void:
		var l: Variant = bus.lobbies.get(id)
		if l == null:
			return
		(l["members"] as Array).erase(sid)
		if (l["members"] as Array).is_empty():
			bus.lobbies.erase(id)
			return
		if int(l["owner"]) == sid:
			l["owner"] = int(l["members"][0])  # Steam hands the lobby on at once
		for m: int in l["members"]:
			bus.users[m].lobby_chat_update.emit(id, sid, sid, 2)

	func getLobbyOwner(id: int) -> int:
		return int(bus.lobbies[id]["owner"]) if bus.lobbies.has(id) else 0

	func setLobbyOwner(id: int, to: int) -> bool:
		if bus.lobbies.has(id) and int(bus.lobbies[id]["owner"]) == sid:
			bus.lobbies[id]["owner"] = to
			return true
		return false

	func getNumLobbyMembers(id: int) -> int:
		return (bus.lobbies[id]["members"] as Array).size() if bus.lobbies.has(id) else 0

	func getLobbyMemberByIndex(id: int, i: int) -> int:
		return int(bus.lobbies[id]["members"][i]) if bus.lobbies.has(id) else 0

	func setLobbyData(id: int, k: String, v: String) -> bool:
		if bus.lobbies.has(id) and int(bus.lobbies[id]["owner"]) == sid:
			bus.lobbies[id]["data"][k] = v
			return true
		return false

	func getLobbyData(id: int, k: String) -> String:
		return str(bus.lobbies[id]["data"].get(k, "")) if bus.lobbies.has(id) else ""

	func sendMessageToUser(to: int, data: PackedByteArray, flags: int, channel: int) -> int:
		sent += 1
		var u: User = bus.users.get(to)
		if u == null:
			return 3
		if (flags & 8) == 0 and bus.loss > 0.0 and randf() < bus.loss:
			return 1
		(u.queue[channel] as Array).append({"payload": data, "identity": sid})
		if not u.accepted.has(sid) and not u.requested.has(sid):
			u.requested[sid] = true
			u.network_messages_session_request.emit(sid)
		return 1

	func receiveMessagesOnChannel(channel: int, max_messages: int) -> Array:
		var q: Array = queue[channel]
		var out: Array = []
		var keep: Array = []
		for m: Dictionary in q:
			if not accepted.has(int(m["identity"])):
				continue  # a session we never accepted: Steam drops it
			if out.size() < max_messages:
				out.append(m)
			else:
				keep.append(m)
		queue[channel] = keep
		return out

	func acceptSessionWithUser(remote: int) -> bool:
		accepted[remote] = true
		return true

	func closeSessionWithUser(remote: int) -> bool:
		accepted.erase(remote)
		requested.erase(remote)
		return true

	func setRichPresence(k: String, v: String) -> bool:
		presence[k] = v
		return true

	func clearRichPresence() -> void:
		presence.clear()


func user(sid: int) -> User:
	if not users.has(sid):
		var u := User.new()
		u.bus = self
		u.sid = sid
		users[sid] = u
	return users[sid]


func free_all() -> void:
	for u: User in users.values():
		u.free()
	users.clear()

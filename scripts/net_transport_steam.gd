class_name NetTransportSteam
extends NetTransport
## Steam co-op (S1 P4): GodotSteam lobbies + Steam Networking Messages, speaking
## the relay protocol so NetNode never knows it is on Steam. DESKTOP ONLY: NetNode
## load()s this file by path when Steam is up; the Web preset excludes it.
##
## The lobby OWNER plays relay: it runs a NetRelayRoom (server.js rules: ids,
## joined/peer_joined/peer_left/peer_scene, msg fan-out stamped from + host, 8 max,
## guest 64 KB / 120 msgs-per-second guards). Star topology like the relay: guests
## only ever talk to the owner, and only the owner's identity counts as host, so a
## guest can never claim host or forward someone else's frames.
## Wire: byte 0 = 0 plain JSON | 1 zstd (u32 raw size, then data) | 2 chunk
## (u32 msg id, u16 index, u16 count, then a slice of a type-0/1 packet). Frames
## over 8 KB are compressed; packets over 480 KB (Steam's cap is 512 KB) are
## chunked, always on the reliable channel, so in-order delivery makes
## reassembly a plain append.
## All Steam calls go through `steam` (the Steam singleton, or tools/fake_steam.gd
## in tests). GodotSteam 4.x signatures; values from steamnetworkingtypes.h /
## isteammatchmaking.h.

const CH_RELIABLE := 0
const CH_FAST := 1
const SEND_UNRELIABLE := 1          # k_nSteamNetworkingSend_UnreliableNoNagle
const SEND_RELIABLE := 9            # k_nSteamNetworkingSend_ReliableNoNagle
const LOBBY_FRIENDS_ONLY := 1       # ELobbyType k_ELobbyTypeFriendsOnly
const MAX_MEMBERS := 8
const ENTER_OK := 1                 # k_EChatRoomEnterResponseSuccess
const ENTER_FULL := 4               # k_EChatRoomEnterResponseFull
const CHAT_ENTERED := 1             # k_EChatMemberStateChangeEntered
const CHAT_GONE := 2 | 4 | 8 | 16   # left, disconnected, kicked, banned
const ZSTD_OVER := 8 * 1024
const CHUNK := 480 * 1024
const OWNER_ID := 1
const CHAT_LEFT := 2                # k_EChatMemberStateChangeLeft: a deliberate leave
const JOIN_RESEND := 2.0            # c17_12-02: guest resends its join until the owner answers
const JOIN_GIVE_UP := 15.0
const GUEST_SILENT := 20.0          # c17_12-03: no packet from the owner this long = dropped
const OWNER_SILENT := 45.0          # owner: a seated guest silent this long is let go
const PENDING_FOR := 10.0           # owner: a session request from a not-yet-listed member waits

var steam: Object
var me := 0                         # my SteamID64
var lobby_id := 0
var owner := false
var owner_sid := 0
var room: NetRelayRoom = null       # owner only
var proto := 0                      # from our join frame: the owner refuses other builds
var _ids := {}                      # SteamID -> small id (owner)
var _sids := {}                     # small id -> SteamID (owner)
var _next := OWNER_ID + 1
var _inbox: Array = []
var _open := false
var _closed := false
var _reason := "Steam lobby closed"
var _parts := {}                    # SteamID -> {id, n, got: PackedByteArray}
var _msg_id := 0
var _owner_gone := -1.0
var _wired := false
var _code := ""
var _waiting_create := false        # c17_12-17: only the transport that asked claims lobby_created
var _cancel := false                # c17_12-18: closed before lobby_created: leave it on arrival
var _join_frame := {}               # guest: our join, resent until the owner answers
var _join_t := -1.0
var _resend_t := 0.0
var _heard := 0.0                   # guest: seconds since the owner's last packet
var _seen := {}                     # owner: SteamID -> seconds since its last packet
var _pending := {}                  # owner: SteamID -> seconds waiting for the lobby list
var _warned := false


func _init(backend: Object) -> void:
	steam = backend
	me = int(steam.call("getSteamID"))


func _wire() -> void:
	if _wired:
		return
	_wired = true
	for pair: Array in _signals():
		if steam.has_signal(pair[0]) and not steam.is_connected(pair[0], pair[1]):
			steam.connect(pair[0], pair[1])


func _unwire() -> void:
	if not _wired:
		return
	_wired = false
	for pair: Array in _signals():
		if steam.has_signal(pair[0]) and steam.is_connected(pair[0], pair[1]):
			steam.disconnect(pair[0], pair[1])


func _signals() -> Array:
	return [["lobby_created", _on_lobby_created], ["lobby_joined", _on_lobby_joined], ["lobby_chat_update", _on_chat_update], ["network_messages_session_request", _on_session_request], ["network_messages_session_failed", _on_session_failed], ["steam_server_disconnected", _on_steam_down]]


## target "" = create a friends-only lobby; otherwise the lobby id to join.
func open(target: String, join_msg: Dictionary) -> bool:
	proto = int(join_msg.get("proto", 0))
	_open = false
	_closed = false
	_cancel = false
	_join_frame = {}
	_join_t = -1.0
	_heard = 0.0
	_wire()
	if target == "":
		owner = true
		_waiting_create = true
		steam.call("createLobby", LOBBY_FRIENDS_ONLY, MAX_MEMBERS)
	else:
		owner = false
		lobby_id = int(target)
		steam.call("joinLobby", lobby_id)
	return true


func _on_lobby_created(result: int, lid: int) -> void:
	if not owner or not _waiting_create or lobby_id != 0 and lid != lobby_id:
		return
	_waiting_create = false
	if _cancel:
		# Left the title before Steam answered: Steam already put us in it, so leave it now.
		if result == 1:
			steam.call("leaveLobby", lid)
		_cancel = false
		_unwire()
		return
	if result != 1:
		_fail("Couldn't start a Steam lobby. Check that Steam is online, then try again.")
		return
	lobby_id = lid
	owner_sid = me
	_code = _make_code(lid)
	for kv: Array in [["dreams", "1"], ["proto", str(proto)], ["code", _code]]:
		steam.call("setLobbyData", lobby_id, kv[0], kv[1])
	room = NetRelayRoom.new()
	room.code = _code
	_ids = {me: OWNER_ID}
	_sids = {OWNER_ID: me}
	_open = true
	_presence()


func _on_lobby_joined(lid: int, _perms: int, _locked: bool, response: int) -> void:
	if owner or lid != lobby_id:
		return
	if response == ENTER_FULL:
		_inbox.append({"t": "full"})
		_open = true
		return
	if response != ENTER_OK:
		_fail(enter_words(response))
		return
	if str(steam.call("getLobbyData", lobby_id, "dreams")) != "1":
		steam.call("leaveLobby", lobby_id)  # c17_12-23: not a Dreams lobby (App 480 is shared)
		_fail("That isn't a Dreams game.")
		return
	owner_sid = int(steam.call("getLobbyOwner", lobby_id))
	_owner_gone = -1.0
	_heard = 0.0
	var their := str(steam.call("getLobbyData", lobby_id, "proto"))
	if their == "" or int(their) != proto:
		_inbox.append({"t": "old_build", "need": int(their) if their.is_valid_int() else 0})
	_open = true
	_presence()


## c17_12-06 / c17_01-13: EChatRoomEnterResponse in words, never a raw number.
static func enter_words(response: int) -> String:
	match response:
		2:
			return "That game has ended."
		3, 5:
			return "You can't join that game."
		4:
			return "That room is full (8 players)."
		6:
			return "Your Steam account can't join lobbies yet (limited account)."
	return "Couldn't join that game. Try again."


func _fail(why: String) -> void:
	_reason = why
	_open = false
	_closed = true
	_waiting_create = false
	_join_frame = {}
	_join_t = -1.0
	_clear_connect()  # c17_01-13: friends' Join Game must not lead to a dead lobby
	if owner:
		_unwire()  # c17_12-17: a failed host never claims the next lobby_created (a guest's reopen() rewires)


func _on_session_failed(info: Variant = null, _a: Variant = null) -> void:
	var sid := 0
	if info is Dictionary:
		sid = _sid_of((info as Dictionary).get("identity", (info as Dictionary).get("remote_steam_id", 0)))
	else:
		sid = _sid_of(info)
	if owner:
		_let_go(sid)
	elif _open and (sid == 0 or sid == owner_sid):
		_fail("Lost the connection to your friend's game.")


func _on_steam_down(_a: Variant = null) -> void:
	if _open or not _closed:
		_fail("Lost the connection to Steam.")


## Owner: a seated guest is gone (session failed or silent).
func _let_go(sid: int) -> void:
	var small := int(_ids.get(sid, 0))
	if small > 0 and room:
		room.leave(small)
	_ids.erase(sid)
	_sids.erase(small)
	_parts.erase(sid)
	_seen.erase(sid)
	if sid != 0:
		steam.call("closeSessionWithUser", sid)


## The 4-character room code shown in status text ("Connected. Room ABCD.").
static func _make_code(lid: int) -> String:
	var a := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var s := ""
	var v := absi(lid)
	for i in 4:
		s += a[v % a.length()]
		v = v / a.length()
	return s


func is_member(sid: int) -> bool:
	if lobby_id == 0:
		return false
	var n := int(steam.call("getNumLobbyMembers", lobby_id))
	for i in n:
		if int(steam.call("getLobbyMemberByIndex", lobby_id, i)) == sid:
			return true
	return false


## Only lobby members may open a session: strangers are never accepted.
func _on_session_request(remote: Variant) -> void:
	var sid := _sid_of(remote)
	if sid == 0:
		return
	if is_member(sid):
		steam.call("acceptSessionWithUser", sid)
		_pending.erase(sid)
	elif owner:
		_pending[sid] = 0.0  # c17_12-02: the lobby list may not have caught up yet


static func _sid_of(v: Variant) -> int:
	if v is int:
		return v
	var s := str(v)
	if s.contains(":"):
		s = s.get_slice(":", 1)
	return int(s) if s.is_valid_int() else 0


func _on_chat_update(lid: int, changed: int, _by: int, state: int) -> void:
	if lid != lobby_id:
		return
	if state & CHAT_GONE:
		if owner:
			_let_go(changed)
			_pending.erase(changed)
		elif changed == owner_sid:
			_clear_connect()
			if state & CHAT_LEFT:
				# c17_12-04: the host left on purpose; a Steam owner can't come back, so no grace.
				_owner_gone = -1.0
				_heard = 0.0
				_inbox.append({"t": "you_are_host"})
			else:
				_owner_gone = 0.0   # dropped: the relay's 30 s host grace, then home
		_presence()
	elif state & CHAT_ENTERED:
		if owner and _pending.has(changed):
			_pending.erase(changed)
			steam.call("acceptSessionWithUser", changed)
		if not owner and changed == owner_sid:
			_owner_gone = -1.0
		_presence()


func poll(delta: float) -> void:
	if not _open:
		return
	for ch in [CH_RELIABLE, CH_FAST]:
		var msgs: Variant = steam.call("receiveMessagesOnChannel", ch, 256)
		if msgs is Array:
			for m: Variant in msgs:
				if m is Dictionary:
					_on_packet(_sid_of((m as Dictionary).get("identity", (m as Dictionary).get("remote_steam_id", 0))), (m as Dictionary).get("payload", PackedByteArray()))
	if owner and room:
		room.tick(delta)
		for sid: int in _pending.keys():
			_pending[sid] = float(_pending[sid]) + delta
			if is_member(sid):
				_pending.erase(sid)
				steam.call("acceptSessionWithUser", sid)
			elif float(_pending[sid]) > PENDING_FOR:
				_pending.erase(sid)
		for sid: int in _seen.keys():
			_seen[sid] = float(_seen[sid]) + delta
			if float(_seen[sid]) > OWNER_SILENT:
				_let_go(sid)
		return
	_heard += delta
	if _join_t >= 0.0:
		_join_t += delta
		_resend_t += delta
		if _join_t > JOIN_GIVE_UP:
			_fail("Your friend's game didn't answer.")
			return
		if _resend_t >= JOIN_RESEND and owner_sid != 0:
			_resend_t = 0.0
			_send_to(owner_sid, _join_frame)
	elif _heard > GUEST_SILENT and _owner_gone < 0.0 and _inbox.is_empty():
		_fail("Lost the connection to your friend's game.")
		return
	if _owner_gone >= 0.0:
		_owner_gone += delta
		if _owner_gone >= NetTransport.HOST_GRACE:
			_owner_gone = -1.0
			_heard = 0.0
			_inbox.append({"t": "you_are_host"})


func is_open() -> bool:
	return _open


func closed() -> bool:
	return _closed


func close_reason() -> String:
	return _reason


func take() -> Array:
	var o := _inbox
	_inbox = []
	return o


func _local(o: Dictionary) -> void:
	var w: Variant = JSON.parse_string(JSON.stringify(o))
	if w is Dictionary:
		_inbox.append(w)


func send(frame: Dictionary) -> void:
	if not _open:
		return
	if owner:
		if str(frame.get("t", "")) == "join":
			room.join(OWNER_ID, frame, _local)
		else:
			room.frame(OWNER_ID, frame, 0)
	elif owner_sid != 0:
		if str(frame.get("t", "")) == "join":
			_join_frame = frame.duplicate(true)
			_join_t = 0.0
			_resend_t = 0.0
		_send_to(owner_sid, frame)


## Owner: deliver a relay frame to one guest.
func _out_for(small: int) -> Callable:
	return func(o: Dictionary) -> void:
		var sid := int(_sids.get(small, 0))
		if sid != 0:
			_send_to(sid, o)


static func _fast(frame: Dictionary) -> bool:
	if NetTransport.droppable(frame):
		return true
	if str(frame.get("t", "")) != "msg":
		return false
	var d: Variant = frame.get("d", {})
	return d is Dictionary and str((d as Dictionary).get("k", "")) == "state" and not (d as Dictionary).has("look")


func _send_to(sid: int, frame: Dictionary) -> void:
	var pkts := encode(frame, _msg_id)
	_msg_id += 1
	if pkts.size() == 1 and _fast(frame):
		steam.call("sendMessageToUser", sid, pkts[0], SEND_UNRELIABLE, CH_FAST)
		return
	for p: PackedByteArray in pkts:
		var r: Variant = steam.call("sendMessageToUser", sid, p, SEND_RELIABLE, CH_RELIABLE)
		if r != null and int(r) != 1 and not _warned:
			_warned = true  # c17_12-20: say it once (e.g. 25 = LimitExceeded on a huge frame)
			push_warning("NetTransportSteam: sendMessageToUser returned %d" % int(r))


static func _u32(b: PackedByteArray, v: int) -> void:
	for i in 4:
		b.append((v >> (8 * i)) & 0xFF)


static func _r32(b: PackedByteArray, at: int) -> int:
	return b[at] | (b[at + 1] << 8) | (b[at + 2] << 16) | (b[at + 3] << 24)


## A frame -> one or more wire packets.
static func encode(frame: Dictionary, msg_id := 0) -> Array:
	var raw := JSON.stringify(frame).to_utf8_buffer()
	var pkt := PackedByteArray()
	if raw.size() > ZSTD_OVER:
		pkt.append(1)
		_u32(pkt, raw.size())
		pkt.append_array(raw.compress(FileAccess.COMPRESSION_ZSTD))
	else:
		pkt.append(0)
		pkt.append_array(raw)
	if pkt.size() <= CHUNK:
		return [pkt]
	var out: Array = []
	var n := int(ceil(float(pkt.size()) / CHUNK))
	for i in n:
		var c := PackedByteArray([2])
		_u32(c, msg_id)
		c.append(i & 0xFF); c.append((i >> 8) & 0xFF)
		c.append(n & 0xFF); c.append((n >> 8) & 0xFF)
		c.append_array(pkt.slice(i * CHUNK, mini((i + 1) * CHUNK, pkt.size())))
		out.append(c)
	return out


## A type-0/1 packet -> [frame or null, raw JSON size].
static func decode(pkt: PackedByteArray) -> Array:
	if pkt.is_empty():
		return [null, 0]
	var raw: PackedByteArray
	if pkt[0] == 0:
		raw = pkt.slice(1)
	elif pkt[0] == 1 and pkt.size() > 5:
		var size := _r32(pkt, 1)
		if size <= 0 or size > NetTransport.MAX_FRAME:
			push_warning("NetTransportSteam: dropped a %d-byte frame" % size)
			return [null, size]
		raw = pkt.slice(5).decompress(size, FileAccess.COMPRESSION_ZSTD)
	else:
		return [null, 0]
	var m: Variant = JSON.parse_string(raw.get_string_from_utf8())
	return [m if m is Dictionary else null, raw.size()]


func _on_packet(sid: int, pkt: PackedByteArray) -> void:
	if sid == 0 or pkt.is_empty():
		return
	if not owner and sid != owner_sid:
		return  # guests only listen to the lobby owner
	if owner and not is_member(sid):
		return
	if owner:
		if _ids.has(sid):
			_seen[sid] = 0.0
	else:
		_heard = 0.0
		_join_t = -1.0  # the owner answered: stop resending the join
	if pkt[0] == 2:
		if pkt.size() < 10:
			return
		var mid := _r32(pkt, 1)
		var i := pkt[5] | (pkt[6] << 8)
		var n := pkt[7] | (pkt[8] << 8)
		var st: Dictionary = _parts.get(sid, {})
		if i == 0 or int(st.get("id", -1)) != mid:
			st = {"id": mid, "n": n, "next": 0, "got": PackedByteArray()}
		if int(st["next"]) != i:
			_parts.erase(sid)  # out of order can't happen on the reliable channel: drop it
			return
		var acc: PackedByteArray = st["got"]   # packed arrays are values: write it back
		acc.append_array(pkt.slice(9))
		st["got"] = acc
		st["next"] = i + 1
		_parts[sid] = st
		if acc.size() > NetTransport.MAX_FRAME:
			_parts.erase(sid)
			return
		if i + 1 < n:
			return
		_parts.erase(sid)
		pkt = acc
	var dec := decode(pkt)
	var m: Variant = dec[0]
	if not (m is Dictionary):
		return
	if not owner:
		_inbox.append(m)
		return
	_owner_frame(sid, m, int(dec[1]))


func _owner_frame(sid: int, m: Dictionary, size: int) -> void:
	if str(m.get("t", "")) == "join":
		if int(m.get("proto", 0)) != proto:
			_send_to(sid, {"t": "old_build", "need": proto})
			return
		var small := int(_ids.get(sid, 0))
		if small == 0:
			small = _next
			_next += 1
			_ids[sid] = small
			_sids[small] = sid
		elif room.info.has(small):
			room._drop(small)  # c17_12-16: a rejoin (or a resent join) reuses its own seat, never 'full'
		_seen[sid] = 0.0
		var jm := m.duplicate()
		jm["token"] = str(sid)  # Steam identity, not the device token, is who this is
		room.join(small, jm, _out_for(small))
		_presence()
		return
	var from := int(_ids.get(sid, 0))
	if from > 0:
		room.frame(from, m, size)


## Steam friends list: "In co-op", grouped by lobby (tokens in steam/rich_presence_english.vdf).
func _presence() -> void:
	if not steam.has_method("setRichPresence") or lobby_id == 0:
		return
	var n := int(steam.call("getNumLobbyMembers", lobby_id))
	steam.call("setRichPresence", "steam_display", "#Status_Coop")
	steam.call("setRichPresence", "players", str(n))
	steam.call("setRichPresence", "steam_player_group", str(lobby_id))
	steam.call("setRichPresence", "steam_player_group_size", str(n))
	# c17_12-14 (Tom's call, default): only the host advertises Join Game, so friends of a
	# guest (strangers to the host) can't walk into the host's friends-only lobby.
	if owner:
		steam.call("setRichPresence", "connect", "+connect_lobby %d" % lobby_id)
	else:
		steam.call("setRichPresence", "connect", "")


func _clear_connect() -> void:
	if steam.has_method("setRichPresence"):
		steam.call("setRichPresence", "connect", "")


func close() -> void:
	if owner and lobby_id == 0 and _waiting_create:
		_cancel = true  # c17_12-18: stay wired for lobby_created only, then leave that lobby
		_open = false
		if steam.has_method("clearRichPresence"):
			steam.call("clearRichPresence")
		return
	if lobby_id != 0:
		var n := int(steam.call("getNumLobbyMembers", lobby_id))
		for i in n:
			var sid := int(steam.call("getLobbyMemberByIndex", lobby_id, i))
			if sid != me:
				steam.call("closeSessionWithUser", sid)
		steam.call("leaveLobby", lobby_id)
	if steam.has_method("clearRichPresence"):
		steam.call("clearRichPresence")
	_unwire()
	_open = false
	_join_t = -1.0
	_pending.clear()
	_seen.clear()
	Presence._last = ""  # c17_12-12: our normal status goes back up with the next push
	if owner:
		lobby_id = 0


## A guest drops: rejoin the same lobby if it is still there. The owner can't
## (its room state went with it; guests go home after the grace, like the relay).
func reopen() -> bool:
	if owner or lobby_id == 0:
		return false
	_inbox.clear()
	_parts.clear()
	return open(str(lobby_id), {"proto": proto})


func caps() -> Dictionary:
	return {"max_frame": NetTransport.MAX_FRAME, "keeps_snapshot": false, "kind": "steam"}

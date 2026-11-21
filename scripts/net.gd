class_name NetNode
extends Node
## Multiplayer (web-first). Talks to the relay in server/ through a NetTransport
## (S1 P4): NetTransportWs (the live relay over a WebSocket) everywhere, plus
## NetTransportSteam (Steam lobbies) on desktop builds with Steam running.
## Every transport speaks the relay protocol, so the code below never changes per wire.
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
## C17 router (contract section 2): the host dropped (grace) / came back; a friend arrived / left.
signal host_away
signal host_back
signal peer_joined(peer: String)
signal peer_left(peer: String)

const TICK := 0.1
## The live Dreams relay (DigitalOcean droplet, see server/README.md): used out of the box.
## SaveGame "net_url" holds only a custom server ("" = this default), so a later default move reaches everyone.
const DEFAULT_URL := "wss://dreams-64-23-239-63.sslip.io"
var tr: NetTransport = null
## Tests (and SteamService) may set this to a Steam backend object (the Steam
## singleton or tools/fake_steam.gd); null = ask the SteamService autoload.
var steam_backend: Object = null
## Bump whenever WORLD_KEYS, the delta format, act names or frame shapes change:
## Steam builds update on their own schedule while the web build auto-deploys.
const PROTO := 2  # C17: router frames, bye/host_left, world seq + resync, ping
var url := ""
var room := ""
var my_id := -1
var _host := false
var host_paused := false  # guests: the host's last push said its game was paused (c13_18-01)
var _ahead := false       # guests: at the last push our clock was ahead of the host's: wait
const HOLD_MINUTES := 30  # a guest ahead by up to this many minutes waits instead of rewinding
var _cue_ms := -100000
const PEER_CUE_GAP_MS := 3000
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
## C17: phones drop for longer than 12 s (a text, a lock screen, a tunnel): retry for about
## a minute (1, 2, 4, 8, 15, 30 s), at once when the app comes back to the front.
const RETRY_GAPS := [1.0, 2.0, 4.0, 8.0, 15.0, 30.0]
const MAX_RETRIES := 6
var _reconnecting := false   # a drop happened: the next "joined" is a rejoin
const CONNECT_TIMEOUT := 10.0
var _connect_t := 0.0
const SILENCE_DROP := 12.0   # no frame at all from the relay this long: the socket is dead
const HOST_SILENT := 6.0     # guests: no host frame this long: hold (the host pushes every 2 s)
const APP_PING_EVERY := 4.0
var _rx_t := 0.0             # seconds since any inbound frame
var _host_rx_t := 0.0        # guests: seconds since a frame from the host
var _app_ping_t := 0.0
var _pong_ok := false        # this relay answers {t:"ping"} (older ones don't)
var _slow_t := 0.0           # the relay said slow: skip position ticks this long
# Host push coalescing (C17): a guest act marks the world dirty; it goes out at most
# every PUSH_GAP s; host_save at most every SAVE_EVERY s, never per act.
const PUSH_GAP := 0.2
var _dirty := false
var _since_push := 0.0
var _save_dirty := false
var _resync_all := false     # host: after our own reconnect, everyone gets a full world
var _wseq := 0               # host: world frame seq
var _wseen := -1             # guests: last world seq applied (-1 = none yet)
var _resync_t := 0.0
# Outgoing budget (mirrors the relay's 120 msg/s with headroom): droppable ticks drop, the rest queue.
const OUT_PER_SEC := 60
var _out_budget := OUT_PER_SEC
var _out_refill := 0.0
var _outq: Array = []
# State ticks: unchanged positions go out at most once a second.
var _last_state := {}
var _state_idle := 0.0
const BUFFER_BYTES := NetTransportWs.BUFFER_BYTES
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
	pending_lobby = lobby_from_args(OS.get_cmdline_args())


## Steam invites (S1 P4): a lobby waiting to be joined: a cold start from an
## invite ("+connect_lobby <id>") or Steam's join_requested (SteamService calls
## on_join_requested). Asked about once a farm map is up, so the guest has a save.
var pending_lobby := 0
var pending_from := ""
var _asking := false


static func lobby_from_args(args: PackedStringArray) -> int:
	for i in args.size():
		var a := args[i]
		if a == "+connect_lobby" and i + 1 < args.size() and args[i + 1].is_valid_int():
			return int(args[i + 1])
		if a.begins_with("+connect_lobby=") and a.get_slice("=", 1).is_valid_int():
			return int(a.get_slice("=", 1))
	return 0


## Steam's join_requested(lobby_id, friend_steam_id) lands here (SteamService connects it).
func on_join_requested(lobby_id: int, friend_name := "") -> void:
	if lobby_id <= 0:
		return
	pending_lobby = lobby_id
	pending_from = friend_name


func _ask_pending() -> void:
	if pending_lobby <= 0 or _asking or not is_inside_tree() or not steam_ready():
		return
	var gm := get_tree().current_scene as GameMap
	if gm == null or gm.hud == null or get_tree().paused or gm.scene_id().begins_with("bf_") or not (Campaign.st().get("fight", {}) as Dictionary).is_empty():
		return  # c16b_16-04: the invite waits until the battle is over
	var d := Dialogue.instance(get_tree())
	if d.active or Dialogue.input_blocked():
		return
	var lid := pending_lobby
	pending_lobby = 0
	var cur: Variant = tr.get("lobby_id") if tr != null else null
	if cur != null and int(cur) == lid:
		return  # already in that lobby
	_asking = true
	var who := pending_from if pending_from != "" else "your friend"
	d.say([{"who": "", "text": ("Leave this game and visit %s's farm?" if online() else "Visit %s's farm? Your own farm waits here.") % who, "choice": ["Visit", "Not now"], "key": ""}])
	await d.finished
	_asking = false
	if d.last_choice != 0:
		return
	if tr != null:
		leave("left")
	join_steam(lid)


func online() -> bool:
	return tr != null and tr.is_open() and my_id > 0


# ---- C17 message router (contract section 2) ----------------------------------
## Typed messages ride inside the relay's "all"/"to" frames as {k:"r", t, d}.
## Handlers: cb(from_peer: String, d: Dictionary). Types are namespaced
## (farm_op, harvest_ok, mine_*, battle_*, game_*, emote, ping, party_*, kick).
var _routes := {}         # t -> Array[Callable]
var _host_id := -1        # the room's host peer id (learned from joined/host frames)
var _host_away := false   # guests: the host's socket is gone (grace) or silent
var _seq := 0             # guests: last seq stamped on a send_host message
var _acks := {}           # host: peer id (String) -> highest seq applied
var _acked := 0           # guests: the host's last ack of our seq
var _ping_t := 0.0
const PING_EVERY := 3.0


func on_msg(t: String, cb: Callable) -> void:
	var a: Array = _routes.get(t, [])
	if not a.has(cb):
		a.append(cb)
	_routes[t] = a


func off_msg(t: String, cb: Callable) -> void:
	var a: Array = _routes.get(t, [])
	a.erase(cb)
	if a.is_empty():
		_routes.erase(t)
	else:
		_routes[t] = a


## Hand a typed message to its handlers (also used for local delivery).
func route(from_peer: String, t: String, d: Dictionary) -> void:
	for cb: Callable in (_routes.get(t, []) as Array).duplicate():
		if cb.is_valid():
			cb.call(from_peer, d)
		else:
			off_msg(t, cb)


func my_peer() -> String:
	return str(my_id) if my_id > 0 else "local"


## Guest -> host (the host itself delivers locally). Stamps "seq" for echo rollback.
func send_host_msg(t: String, d: Dictionary) -> void:
	if not d.has("seq"):
		_seq += 1
		d["seq"] = _seq
	if is_host():
		_note_seq(my_peer(), d)
		route(my_peer(), t, d)
		return
	var f := {"k": "r", "t": t, "d": d}
	if _host_id > 0:
		_send({"t": "to", "id": _host_id, "d": f})
	else:
		f["h"] = 1  # host unknown yet: everyone gets it, only the host handles it
		_send({"t": "all", "d": f})


func send_peer(peer: String, t: String, d: Dictionary) -> void:
	if peer == my_peer() or (not online() and peer == "local"):
		route(my_peer(), t, d)
		return
	if online() and peer.is_valid_int():
		_send({"t": "to", "id": int(peer), "d": {"k": "r", "t": t, "d": d}})


func broadcast(t: String, d: Dictionary, include_self := false) -> void:
	if online():
		_send({"t": "all", "d": {"k": "r", "t": t, "d": d}})
	if include_self:
		route(my_peer(), t, d)


## False while we're a guest and the host is away (grace) or not yet known: spend nothing.
func host_present() -> bool:
	if not online():
		return not visiting()  # solo play: our own world; a reconnecting guest: no host
	return _host or not _host_away


## peer (String) -> {name, arc, scene, ping_ms, host, me}; includes ourselves.
func roster() -> Dictionary:
	var out := {}
	if online():
		out[my_peer()] = {"name": GameState.names().get("character", "") if not GameState.run.is_empty() else "", "arc": str(GameState.run.get("arc", "")), "scene": _my_scene(), "ping_ms": 0, "host": _host, "me": true}
	for pid in peers:
		var p: Dictionary = peers[pid]
		out[str(pid)] = {"name": NameFilter.clean(str(p.get("name", ""))), "arc": str(p.get("arc", "")), "scene": str(p.get("scene", "")), "ping_ms": int(p.get("ping_ms", -1)), "host": int(pid) == _host_id, "me": false}
	return out


func _my_scene() -> String:
	var m := get_tree().current_scene if is_inside_tree() else null
	if m is GameMap:
		return (m as GameMap).net_scene() if (m as GameMap).has_method("net_scene") else (m as GameMap).scene_id()
	return ""


## Guests: the highest seq of ours the host has applied (older local echoes can be dropped).
func acked_seq() -> int:
	return _acked


func last_seq() -> int:
	return _seq


func _note_seq(peer: String, d: Dictionary) -> void:
	if d.has("seq"):
		_acks[peer] = maxi(int(_acks.get(peer, 0)), int(d["seq"]))


## Guests: world frame seq. False = an old frame, skip it. A gap asks the host for a full world.
func _take_seq(wd: Dictionary) -> bool:
	if not wd.has("_s"):
		return true
	var sq := int(wd["_s"])
	wd.erase("_s")
	if not bool(wd.get("_delta", false)):
		_wseen = sq  # a full world
		return true
	if _wseen >= 0 and sq <= _wseen:
		return false
	if _wseen >= 0 and sq > _wseen + 1 and Time.get_ticks_msec() - _resync_t > 3000.0:
		_resync_t = Time.get_ticks_msec()
		send_host({"k": "act", "a": "resync"})
	_wseen = sq
	return true


func _set_host_away(away: bool) -> void:
	if _host or away == _host_away:
		return
	_host_away = away
	if away:
		host_away.emit()
	else:
		host_back.emit()


func is_host() -> bool:
	return not online() or _host


## The server to use: the saved custom one, else DEFAULT_URL.
static func server_url() -> String:
	var u := str(SaveGame.get_value("net_url", "")).strip_edges()
	return u if u != "" else DEFAULT_URL


## True when no custom server is saved.
static func uses_default() -> bool:
	return server_url() == DEFAULT_URL


## What Host/Join connect to: the typed address, or DEFAULT_URL when the field is empty.
static func pick_url(u: String) -> String:
	return u.strip_edges() if u.strip_edges() != "" else DEFAULT_URL


## Forget the custom server: back to DEFAULT_URL.
static func reset_server() -> void:
	SaveGame.set_value("net_url", "")


func _connect(u: String) -> bool:
	url = u.strip_edges()
	if url == "":
		return false
	_connect_t = 0.0
	_rx_t = 0.0
	_pong_ok = false
	tr = NetTransportWs.new()
	if not tr.open(url, _pending_join):
		tr = null
		disconnected.emit(CANT_REACH)
		return false
	SaveGame.set_value("net_url", "" if url == DEFAULT_URL else url)
	return true


## A random token per app launch (C17): two tabs or two players on one browser never
## share it (the joiner used to replace the host), and it can't be guessed.
func _tok() -> String:
	if _token == "":
		_token = Crypto.new().generate_random_bytes(16).hex_encode()
	return _token


const CANT_REACH := "Couldn't reach the co-op server. Check your signal and try again."
const OLD_BUILD := "You and your friend are on different versions of Dreams. Close and reopen Dreams on both phones to update, then try again."


func host(u: String) -> void:
	_host = true
	_pushed = {}
	_pending_join = {"t": "join", "room": "", "token": _tok(), "name": GameState.names()["character"], "look": _my_look(), "arc": GameState.run["arc"], "proto": PROTO}
	_connect(pick_url(u))


func join(u: String, code: String) -> void:
	if code.strip_edges() == "":
		disconnected.emit("Type your friend's room code first.")  # an empty code used to host a new room
		return
	_host = false
	_pending_join = {"t": "join", "room": code.to_upper().strip_edges(), "create": false, "token": _tok(), "name": GameState.names()["character"], "look": _my_look(), "arc": GameState.run["arc"], "proto": PROTO}
	_connect(pick_url(u))


## Steam friends (S1 P4): host a friends-only Steam lobby. Desktop builds with
## Steam running only (steam_ready()); the room-code relay stays for phones/web.
func host_steam() -> bool:
	var t := _steam_transport()
	if t == null:
		return false
	_host = true
	_pushed = {}
	_pending_join = {"t": "join", "room": "", "token": _tok(), "name": GameState.names()["character"], "look": _my_look(), "arc": GameState.run["arc"], "proto": PROTO}
	tr = t
	if not tr.open("", _pending_join):
		tr = null
		disconnected.emit("Couldn't start a Steam lobby.")
		return false
	return true


## Join a friend's Steam lobby (an invite, the friends list, or +connect_lobby).
func join_steam(lobby_id: int) -> bool:
	var t := _steam_transport()
	if t == null or lobby_id <= 0:
		return false
	_host = false
	_pending_join = {"t": "join", "room": "", "create": false, "token": _tok(), "name": GameState.names()["character"], "look": _my_look(), "arc": GameState.run["arc"], "proto": PROTO}
	tr = t
	if not tr.open(str(lobby_id), _pending_join):
		tr = null
		disconnected.emit("Couldn't join that Steam lobby.")
		return false
	return true


## Steam is up (desktop build, client running, or a test backend).
func steam_ready() -> bool:
	return _steam_obj() != null


func _steam_obj() -> Object:
	if steam_backend != null:
		return steam_backend
	var svc := get_node_or_null("/root/SteamSvc") if is_inside_tree() else null
	if svc and svc.has_method("is_live") and bool(svc.call("is_live")):
		var b: Variant = svc.call("steam_object") if svc.has_method("steam_object") else null
		if b is Object:
			return b
	return null


## Loaded by path so the web export (which leaves the file out) never parses Steam code.
func _steam_transport() -> NetTransport:
	var b := _steam_obj()
	if b == null:
		return null
	var sc: Variant = load("res://scripts/net_transport_steam.gd")
	if not (sc is Script):
		return null
	return (sc as Script).new(b) as NetTransport


## Try the same place again after a drop: the same lobby on Steam, the same URL on the relay.
var _last_tr: NetTransport = null


func _reconnect() -> bool:
	if _last_tr != null and str(_last_tr.caps().get("kind", "")) in ["steam", "loop"]:
		if _last_tr.reopen():
			tr = _last_tr
			return true
		return false
	return _connect(url)


func leave(why := "left") -> void:
	_retries = MAX_RETRIES  # a deliberate leave never reconnects
	_last_room = ""
	_restore_solo(why if why != "left" else "You left. You're back on your own farm.")
	_reconnecting = false
	_outq.clear()
	if tr:
		if tr.is_open() and why == "left":
			tr.send({"t": "bye"})  # C17: a deliberate leave; a host's ends the room for everyone at once
		tr.close()
	tr = null
	my_id = -1
	room = ""
	_host_id = -1
	_host_away = false
	_acks.clear()
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
	if tr and tr.is_open():
		if _out_budget <= 0 or not _outq.is_empty():
			if not NetTransport.droppable(o):
				_outq.append(o)  # over our own budget: queue, never lose an act or a world frame
			return
		_out_budget -= 1
		tr.send(o)


func _flush_out(delta: float) -> void:
	_out_refill += delta
	if _out_refill >= 1.0 / OUT_PER_SEC:
		_out_budget = mini(OUT_PER_SEC, _out_budget + int(_out_refill * OUT_PER_SEC))
		_out_refill = fmod(_out_refill, 1.0 / OUT_PER_SEC)
	while not _outq.is_empty() and _out_budget > 0 and tr and tr.is_open():
		_out_budget -= 1
		tr.send(_outq.pop_front())


## Tell the room which scene we're in (game_map.gd on every map change).
func send_scene(scene_id: String) -> void:
	_send({"t": "scene", "scene": scene_id})


func send_all(d: Dictionary) -> void:
	_send({"t": "all", "d": d})


## send_host(d) = a legacy world act; send_host(t, d) = a router message (contract section 2).
func send_host(a: Variant, b: Variant = null) -> void:
	if a is String:
		send_host_msg(a, b if b is Dictionary else {})
		return
	var d: Dictionary = a
	if not d.has("seq"):
		_seq += 1
		d["seq"] = _seq
	if _host:
		_handle_action(my_id, d)
	elif _host_id > 0:
		_send({"t": "to", "id": _host_id, "d": d})
	else:
		_send({"t": "all", "d": d})  # the host is in the room; others ignore "act"


var _web_t := 0.0
var _web_coop := false


## Web (C17): no "new version" banner mid co-op (updating drops the room), and a tab
## coming back to the front reconnects at once. head_include.html reads/sets the flags.
func _web_tick(delta: float) -> void:
	if not OS.has_feature("web"):
		return
	_web_t += delta
	if _web_t < 1.0:
		return
	_web_t = 0.0
	var coop := online() or _retry_t > 0.0
	if coop != _web_coop:
		_web_coop = coop
		JavaScriptBridge.eval("window.dreamsCoop=%s;" % ("true" if coop else "false"), true)
	var woke: Variant = JavaScriptBridge.eval("(function(){var n=window.dreamsWoke|0;window.dreamsWoke=0;return n;})()", true)
	if int(woke) > 0:
		_notification(NOTIFICATION_APPLICATION_FOCUS_IN)


func _process(delta: float) -> void:
	_web_tick(delta)
	if pending_lobby > 0 and not _asking:
		_ask_pending()
	if tr == null:
		if _retry_t > 0.0:
			_retry_t -= delta
			if _retry_t <= 0.0 and _last_room != "" and _retries < MAX_RETRIES:
				_retry_now()
		return
	tr.poll(delta)
	if tr.is_open():
		if not _pending_join.is_empty():
			tr.send(_pending_join)
			_pending_join = {}
		_rx_t += delta
		var got := tr.take()
		if not got.is_empty():
			_rx_t = 0.0
		for m: Dictionary in got:
			_on_msg(m)
			if tr == null:
				return  # a message made us leave
		if tr == null:
			return
		_flush_out(delta)
		# C17 liveness: a half-dead socket after a phone sleep or network switch.
		_app_ping_t += delta
		if _app_ping_t >= APP_PING_EVERY:
			_app_ping_t = 0.0
			tr.send({"t": "ping", "s": 0})
		if _rx_t >= SILENCE_DROP and (_pong_ok or not peers.is_empty()):  # an older relay never answers ping
			_rx_t = 0.0
			tr.close()
			_on_drop("no answer from the server")
			return
		if my_id > 0 and not _host and visiting():
			_host_rx_t += delta
			if _host_rx_t >= HOST_SILENT:
				_set_host_away(true)
		if my_id > 0:
			_t += delta
			_slow_t = maxf(0.0, _slow_t - delta)
			if _t >= TICK:
				_t = 0.0
				if _slow_t <= 0.0:
					_broadcast_state()
			_ping_t += delta
			if _ping_t >= PING_EVERY and not peers.is_empty():
				_ping_t = 0.0
				send_all({"k": "png", "s": Time.get_ticks_msec()})
			if _host:
				_save_t += delta
				_world_t += delta
				_since_push += delta
				if peers.is_empty():
					# Alone: no pushes, only the relay snapshot (late joiners, a relay restart):
					# the first within 2 s, then every SAVE_EVERY s when the world changed.
					if _world_t >= 2.0:
						_world_t = 0.0
						if _save_n == 0 or _save_t >= SAVE_EVERY:
							_alone_save()
				elif _world_t >= 2.0 or (_dirty and _since_push >= PUSH_GAP) or _resync_all:
					_world_t = 0.0
					_push_world()
	elif tr.closed():
		_on_drop(tr.close_reason())
	else:
		_connect_t += delta
		if _connect_t >= CONNECT_TIMEOUT:
			tr.close()
			_on_drop("timed out")


## The line went down (closed, silent or never opened): reconnect, or go home.
func _on_drop(why: String) -> void:
	_last_tr = tr
	tr = null
	_set_host_away(true)  # guests: nothing is spent until a host is back
	var was_online := my_id > 0
	my_id = -1
	peers.clear()
	_outq.clear()
	peers_changed.emit()
	if _last_room != "" and _retries < MAX_RETRIES:
		_reconnecting = true
		_retry_t = float(RETRY_GAPS[mini(_retries, RETRY_GAPS.size() - 1)])
		why = "Reconnecting..."
		if was_online:
			_toast("Connection lost. Reconnecting...", Color(1, 0.85, 0.6))
	elif _last_room == "" and not was_online:
		why = CANT_REACH
	else:
		_reconnecting = false
		_restore_solo()
	disconnected.emit(why)


func _retry_now() -> void:
	_retries += 1
	_retry_t = 0.0
	# The host asks to recreate its code (a relay restart forgets every room); guests only rejoin.
	_pending_join = {"t": "join", "room": _last_room, "create": _host, "token": _tok(), "name": GameState.names()["character"], "look": _my_look(), "arc": GameState.run["arc"], "proto": PROTO}
	if not _reconnect():
		if _retries >= MAX_RETRIES or url == "" and (_last_tr == null or not (str(_last_tr.caps().get("kind", "")) in ["steam", "loop"])):
			_reconnecting = false
			_restore_solo()  # gave up: back to our own world, not the host's offline
		else:
			_retry_t = float(RETRY_GAPS[mini(_retries, RETRY_GAPS.size() - 1)])


## Back to the front (phone unlocked, tab visible): reconnect at once instead of waiting.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if tr == null and _retry_t > 0.0 and _last_room != "" and _retries < MAX_RETRIES:
			_retry_now()
		elif tr != null and tr.is_open() and _rx_t > 5.0:
			tr.send({"t": "ping", "s": 0})  # check the line now


func _on_msg(m: Dictionary) -> void:
	match str(m.get("t", "")):
		"joined":
			_look_hash = 0
			my_id = int(m["id"])
			room = str(m["room"])
			_last_room = room
			var rejoin := _reconnecting
			_reconnecting = false
			_retries = 0
			_retry_t = 0.0
			_host_rx_t = 0.0
			_wseen = -1
			_save_n = 0
			_host = bool(m.get("host", false))
			_host_id = my_id if _host else int(m.get("host_id", -1))
			if _host_away:
				_host_away = false
				host_back.emit()
			_acks.clear()
			var fresh := _solo_backup.is_empty()  # first join, not a reconnect
			_arc_mismatch = false
			if _host and not _solo_backup.is_empty():
				# Rejoined a room whose host is gone: the host's farm goes with the host, we go home.
				leave("Your host left. You're back on your own farm.")
				return
			if _host and rejoin:
				_resync_all = true  # guests' acts in the gap were lost and deltas missed: full world to all
			if rejoin:
				_toast("Back online.", Color(0.8, 0.95, 1.0))
			if not _host and _solo_backup.is_empty():
				for k in WORLD_KEYS:
					# null = the guest had no such key: drop it again later, never keep the host's.
					_solo_backup[k] = ((GameState.run[k].duplicate(true) if GameState.run[k] is Dictionary or GameState.run[k] is Array else GameState.run[k]) if GameState.run.has(k) else null)
			for p in m.get("peers", []):
				peers[int(p["id"])] = p
				if bool((p as Dictionary).get("host", false)):
					_host_id = int(p["id"])
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
		"old_build":
			leave(OLD_BUILD)
		"no_room":
			if _reconnecting and _retries < MAX_RETRIES and not _host:
				# The relay restarted: the host recreates the code in a moment, keep trying.
				tr.close()
				_last_tr = tr
				tr = null
				_retry_t = float(RETRY_GAPS[mini(_retries, RETRY_GAPS.size() - 1)])
				return
			leave("No game with that code. Check the code with your host.")
		"host_left":
			leave("Your host ended the game. You're back on your own farm." if visiting() else "The game ended.")
		"slow":
			_slow_t = 1.0  # over the relay's budget: hold position ticks a second
		"pong":
			_pong_ok = true
		"peer_joined":
			_look_hash = 0  # the newcomer gets our look with the next state packet
			var p: Dictionary = m["peer"]
			if not peers.has(int(p["id"])):
				_peer_cue(str(p.get("name", "")), true)
			peers[int(p["id"])] = p
			if str(p.get("arc", "")) != str(GameState.run["arc"]):
				_arc_mismatch = true
			if bool(p.get("host", false)):
				_host_id = int(p["id"])
			if int(p["id"]) == _host_id:
				_set_host_away(false)
			peers_changed.emit()
			peer_joined.emit(str(int(p["id"])))
			if _host:
				_push_world(int(p["id"]))
		"peer_left":
			if bool(m.get("host", false)) and not _host:
				_toast("Your host lost signal. Waiting up to %d s..." % int(int(m.get("grace", 30000)) / 1000), Color(1, 0.85, 0.6))
			elif peers.has(int(m["id"])):
				_peer_cue(str((peers[int(m["id"])] as Dictionary).get("name", "")), false)
			peers.erase(int(m["id"]))
			_acks.erase(str(int(m["id"])))
			if int(m["id"]) == _host_id and not _host:
				_set_host_away(true)
			peers_changed.emit()
			peer_left.emit(str(int(m["id"])))
		"peer_scene":
			if peers.has(int(m["id"])):
				peers[int(m["id"])]["scene"] = str(m["scene"])
			peers_changed.emit()
		"you_are_host":
			if not _solo_backup.is_empty():
				leave("Your host left. You're back on your own farm.")  # the host's farm goes with the host
				return
			_host = true
			_host_id = my_id
			_host_away = false
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
			if bool(m.get("host", false)) and from > 0:
				_host_id = from
				_host_rx_t = 0.0
				_set_host_away(false)
			match str(d.get("k", "")):
				"r":
					if d.has("h") and not _host:
						return  # meant for the host
					var rd: Variant = d.get("d", {})
					if rd is Dictionary:
						if _host:
							_note_seq(str(from), rd)
						route(str(from), str(d.get("t", "")), rd)
				"png":
					_send({"t": "to", "id": from, "d": {"k": "pong", "s": d.get("s", 0)}})
				"pong":
					if peers.has(from):
						peers[from]["ping_ms"] = maxi(0, Time.get_ticks_msec() - int(d.get("s", 0)))
				"state":
					var pv: Variant = d.get("pos", [0, 0])
					if peers.has(from) and pv is Array and (pv as Array).size() >= 2:
						peers[from]["pos"] = pv
						peers[from]["scene"] = str(d.get("scene", ""))
						peers[from]["anim"] = str(d.get("anim", "idle"))
						peers[from]["flip"] = bool(d.get("flip", false))
						peers[from]["look"] = d.get("look", peers[from].get("look", {}))
						peers[from]["pal"] = str(d.get("pal", ""))  # C11b P3: their partner and pup trail their puppet
						peers[from]["pup"] = bool(d.get("pup", false))
				"act":
					if _host:
						_note_seq(str(from), d)
						if str(d.get("a", "")) == "resync":
							_push_world(from)  # a guest missed a delta: a full world to it alone
						else:
							_handle_action(from, d)
				"world":
					var wd: Variant = d.get("d", {})
					if not _host and wd is Dictionary and bool(m.get("host", false)):  # only the host's world counts
						var ak: Variant = (wd as Dictionary).get("_ack", null)
						if ak is Dictionary:
							_acked = maxi(_acked, int((ak as Dictionary).get(str(my_id), _acked)))
							(wd as Dictionary).erase("_ack")
						if not _take_seq(wd as Dictionary):
							return
						_apply_world(wd)
				"toast":
					if not bool(m.get("host", false)):
						return
					var m2 := get_tree().current_scene
					if m2 is GameMap:
						var tx := str(d.get("text", "")).substr(0, 120)
						if tx.begins_with("Host: ") and _toast_ok(tx):  # C17: only our own host lines, filtered (no free-text channel)
							(m2 as GameMap).hud.toast(tx, Color(0.8, 0.9, 1.0))


func _broadcast_state() -> void:
	if peers.is_empty():
		return  # C17: alone in the room, nobody to tell
	var m := get_tree().current_scene
	if not (m is GameMap) or (m as GameMap).player == null:
		return
	var p := (m as GameMap).player
	var st := {"k": "state", "pos": [snappedf(p.position.x, 0.5), snappedf(p.position.y, 0.5)], "scene": (m as GameMap).scene_id(), "anim": p.anim_name, "flip": p._anim.flip_h if p._anim else false,
		"pal": Companion.active_id(), "pup": (m as GameMap).pet != null and is_instance_valid((m as GameMap).pet) and ((m as GameMap).pet as Node2D).visible}
	# The look (and wardrobe) rides along only when it changed, or every LOOK_EVERY s for
	# late joiners: receivers keep the last one (c10_10: it was sent whole 10x a second).
	var lk := _my_look()
	var h := hash(lk)
	_look_t += TICK
	if h != _look_hash or _look_t >= LOOK_EVERY:
		_look_hash = h
		_look_t = 0.0
		st["look"] = lk
	# C17: standing still or in a menu, the same state goes out once a second, not 10x.
	_state_idle += TICK
	if not st.has("look") and st == _last_state and _state_idle < 1.0:
		return
	_state_idle = 0.0
	_last_state = st.duplicate()
	send_all(st)


# ---- world sync (host -> guests) ---------------------------------------------
## Only what's truly shared: the host's clock (and day length), difficulty
## (run.opts), weather and farm. Each player
## keeps their own money, bank, sell box, quests, story flags and friendships
## (overwriting those from the host let guests copy crystals and replay story).
## "decor_home" is the host's house look (DecorMode.home_view: placed pieces, wallpaper,
## flooring; never the decor box or wardrobe), so guests in the house see the host's decor.
const WORLD_KEYS := ["day", "time", "weather", "farm", "builds", "construction", "permits", "cleared", "placed", "day_len", "opts", "decor_home", "ranch", "coop_hatch"]


var _save_n := 0         # host_saves sent this connection
var _save_hash := 0


func _alone_save() -> void:
	var d := _world_now()
	var hv := hash(d)
	_save_t = 0.0
	if _save_n > 0 and hv == _save_hash:
		return
	_save_hash = hv
	_save_n += 1
	_send({"t": "host_save", "d": d})


func _world_now() -> Dictionary:
	var d := {}
	for k in WORLD_KEYS:
		if k == "decor_home":
			d[k] = DecorMode.home_view()
		elif GameState.run.has(k):
			d[k] = GameState.run[k]
	return d


func _push_world(to_id := -1) -> void:
	var d := {}
	for k in WORLD_KEYS:
		if k == "decor_home":
			d[k] = DecorMode.home_view()  # derived from run.decor, never stored in the host's run
		elif GameState.run.has(k):
			d[k] = GameState.run[k]
	if to_id > 0:
		var full := d.duplicate()
		full["_s"] = _wseq
		_send({"t": "to", "id": to_id, "d": {"k": "world", "d": full}})  # a new guest gets everything
		return
	_dirty = false
	_since_push = 0.0
	if _resync_all:
		_resync_all = false
		_pushed = d.duplicate(true)
		var full_all := d.duplicate()
		full_all["_s"] = _wseq
		if not _acks.is_empty():
			full_all["_ack"] = _acks.duplicate()
		send_all({"k": "world", "d": full_all})
		_save_t = 0.0
		_send({"t": "host_save", "d": d})
		return
	# Everyone else gets only what changed since the last push (a late farm's full
	# world passes the 64 KB frame size; the clock alone is a few bytes).
	var delta := world_delta(_pushed, d)
	_pushed = d.duplicate(true)
	# c13_18-01: every push stamps the host's clock and whether it is paused (a dialogue or
	# menu), so a guest holds its clock instead of free-running and snapping back.
	delta["time"] = int(GameState.run.get("time", 0))
	delta["_paused"] = is_inside_tree() and get_tree().paused
	if not _acks.is_empty():
		delta["_ack"] = _acks.duplicate()  # C17: each guest's highest applied seq (echo rollback)
	_wseq += 1
	delta["_s"] = _wseq  # guests spot a missed delta and ask for a full world
	send_all({"k": "world", "d": delta})
	var busy := delta.keys().any(func(k): return not (k in ["_delta", "_gone", "time", "_paused", "_ack", "_s"]))
	if busy:
		_save_dirty = true
	# C17: the relay snapshot (late joiners, a restart) at most every SAVE_EVERY s, never per act.
	if _save_t >= SAVE_EVERY and (_save_dirty or busy or delta.has("day")):
		_save_t = 0.0
		_save_dirty = false
		_save_n += 1
		_send({"t": "host_save", "d": d})


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
		elif k == "decor_home" and old.get(k) is Dictionary and now[k] is Dictionary:
			# Per room: only the rooms whose pieces changed (a full house is ~41 B a piece).
			var op: Dictionary = (old[k] as Dictionary).get("placed", {})
			var np: Dictionary = (now[k] as Dictionary).get("placed", {})
			var pd := {}
			for r in np:
				if not op.has(r) or op[r] != np[r]:
					# A big room (the yard: hundreds of path cells) sends only the pieces
					# that came and went (c10b_02_07), a small one the whole list.
					if op.get(r) is Array and np[r] is Array and (np[r] as Array).size() > 40:
						pd[r] = _piece_ops(op[r], np[r])
					else:
						pd[r] = np[r]
			for r in op:
				if not np.has(r):
					pd[r] = null
			out["decor_home_d"] = {"placed": pd, "wall": (now[k] as Dictionary).get("wall", {}), "floor": (now[k] as Dictionary).get("floor", {})}
			# Every other part of the look (ext, house, ...) rides along whole (C17: "house" was dropped).
			for hk in (now[k] as Dictionary):
				if not (str(hk) in ["placed", "wall", "floor"]):
					out["decor_home_d"][hk] = (now[k] as Dictionary)[hk]
		else:
			out[k] = now[k]
	for k in old:
		if not now.has(k):
			out["_gone"].append(k)
	return out


## C17: the same piece keys the same on both sides of the wire (JSON turns ints into floats,
## and key order may differ), so a removal always finds its piece.
static func _piece_key(p: Variant) -> String:
	return JSON.stringify(_norm(p), "", true) if p is Dictionary or p is Array else str(p)


static func _norm(v: Variant) -> Variant:
	if v is float and is_equal_approx(v, roundf(v)) and absf(v) < 1e15:
		return int(v)
	if v is Dictionary:
		var o := {}
		for k in v:
			o[str(k)] = _norm(v[k])
		return o
	if v is Array:
		var a: Array = []
		for x in v:
			a.append(_norm(x))
		return a
	return v


## Pieces removed (by key) and added between two placed lists of one room.
static func _piece_ops(a: Array, b: Array) -> Dictionary:
	var ak := {}
	for p in a:
		ak[_piece_key(p)] = int(ak.get(_piece_key(p), 0)) + 1
	var add: Array = []
	for p in b:
		var k := _piece_key(p)
		if int(ak.get(k, 0)) > 0:
			ak[k] = int(ak[k]) - 1
		else:
			add.append(p)
	var del: Array = []
	for k in ak:
		for i in int(ak[k]):
			del.append(k)
	return {"_ops": true, "del": del, "add": add}


static func _apply_ops(list: Variant, ops: Dictionary) -> Array:
	var out: Array = (list as Array).duplicate(true) if list is Array else []
	for k in ops.get("del", []):
		for i in out.size():
			if _piece_key(out[i]) == str(k):
				out.remove_at(i)
				break
	out.append_array((ops.get("add", []) as Array).duplicate(true))
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
	var dh: Variant = d.get("decor_home_d", null)
	if dh is Dictionary:
		var home: Variant = run.get("decor_home", null)
		if not (home is Dictionary):
			home = {"placed": {}, "wall": {}, "floor": {}}
			run["decor_home"] = home
		if not ((home as Dictionary).get("placed", null) is Dictionary):
			home["placed"] = {}
		var pv: Variant = (dh as Dictionary).get("placed", {})
		if pv is Dictionary:
			for r in pv:
				if pv[r] == null:
					(home["placed"] as Dictionary).erase(r)
				elif pv[r] is Dictionary and (pv[r] as Dictionary).has("_ops"):
					home["placed"][r] = _apply_ops((home["placed"] as Dictionary).get(r, []), pv[r])
				else:
					home["placed"][r] = pv[r]
		home["wall"] = (dh as Dictionary).get("wall", {})
		home["floor"] = (dh as Dictionary).get("floor", {})
		for hk in (dh as Dictionary):
			if not (str(hk) in ["placed", "wall", "floor"]):
				home[hk] = (dh as Dictionary)[hk]  # ext, house, ...
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
		if not _host and d.get("ranch") is Dictionary:
			d["ranch"] = clean_ranch_names(d["ranch"])  # c13_18-24: deltas are filtered like full worlds
		if not _host:
			host_paused = bool(d.get("_paused", false))
			var ht := int(d.get("time", GameState.run.get("time", 0)))
			var lt := int(GameState.run.get("time", 0))
			_ahead = d.has("time") and not d.has("day") and lt > ht and lt - ht <= HOLD_MINUTES
			if _ahead:
				d["time"] = lt  # c13_18-20: a small backward step is held (our clock waits), not rewound
		merge_delta(GameState.run, d)
		if int(GameState.run.get("day", 0)) > day_was and not _host:
			_guest_morning()
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
		if k == "ranch" and not _host and d[k] is Dictionary:
			d[k] = clean_ranch_names(d[k])
		GameState.run[k] = d[k]
	if not _host:
		# A full world from the host: keys it doesn't have aren't ours to show (ours are in _solo_backup).
		for k in ["builds", "construction", "permits", "cleared", "weather", "placed", "decor_home", "ranch", "coop_hatch"]:
			if not d.has(k):
				GameState.run.erase(k)
	if not _host and host_day == 0:
		GameState.shift_clock(GameState.now_abs() - abs0, int(GameState.run.get("day", 1)) - day0)  # first world: our timers move onto the host's clock
	# The host slept: a new morning for us too (our sell box, energy, health).
	if not _host and host_day > 0 and int(GameState.run.get("day", 0)) > host_day:
		_guest_morning()
	_last_world = d
	var m := get_tree().current_scene
	if m is GameMap and m.has_method("on_world_sync"):
		m.call("on_world_sync", d)


## c13_18-06: one guest morning for both world paths: the report, the toast and the
## morning's sounds (wake jingle, till, builds), like the host's own wake-up.
func _guest_morning() -> void:
	host_paused = false
	_ahead = false
	var rep := GameState.guest_morning()
	var m0 := get_tree().current_scene
	if m0 is GameMap and int(rep.get("earned", 0)) > 0:
		(m0 as GameMap).hud.toast("Morning! Your sell box paid ◆%d." % int(rep["earned"]), Color(1, 0.95, 0.6))
	var day := int(GameState.run.get("day", 0))
	load("res://scripts/house.gd").morning_cues(get_tree(), rep, int(GameState.run["flags"].get("guest_out_day", -1)) == day - 1)


## S1 s1_13-03: animal names typed on another player's game are filtered before a
## guest shows them (NameFilter; a bad name falls back to the species name).
static func clean_ranch_names(r: Dictionary) -> Dictionary:
	var an: Variant = r.get("animals", null)
	if not (an is Dictionary):
		return r
	var out := r.duplicate()
	var animals := (an as Dictionary).duplicate()
	for uid in animals:
		var a: Variant = animals[uid]
		if a is Dictionary and (a as Dictionary).has("name"):
			var nm := str((a as Dictionary)["name"])
			var fixed := preload("res://scripts/name_filter.gd").clean(nm, Ranch.display_name(str((a as Dictionary).get("species", ""))))
			if fixed != nm:
				var c := (a as Dictionary).duplicate()
				c["name"] = fixed
				animals[uid] = c
	out["animals"] = animals
	return out


## Actions guests ask the host to do. Kept small and whitelisted; the host
## re-validates nothing fancy (friends only), just applies and re-broadcasts.
func _handle_action(from: int, d: Dictionary) -> void:
	var a := str(d.get("a", ""))
	var m := get_tree().current_scene
	if not valid_act(d):
		return  # C17: a modified client can't write junk into the host's save
	if from != my_id and not peers.has(from):
		return
	match a:
		"farm_tile":
			var tv: Variant = d.get("tile", null)
			if tv is Dictionary and str(d.get("key", "")).contains(","):
				GameState.run["farm"][str(d["key"])] = tv
		"farm_clear":
			GameState.run["farm"].erase(str(d.get("key", "")))
		"farm_tiles":
			# C17: many tiles in one act (area spells, hold-to-repeat): key -> tile, null = cleared.
			var tt: Dictionary = d.get("tiles", {})
			for key in tt:
				if tt[key] == null:
					GameState.run["farm"].erase(str(key))
				else:
					GameState.run["farm"][str(key)] = tt[key]
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
	_dirty = true  # C17: coalesced, out within PUSH_GAP s (a held hoe no longer means a push per tile)


## Host toast words: per word, the hard block list (whole-sentence squash hits "this hit").
static func _toast_ok(tx: String) -> bool:
	for w in tx.split(" ", false):
		var sq := NameFilter.squash(w)
		for b in NameFilter.BLOCK:
			if sq.contains(b):
				return false
	return true


## C17: shape checks on a guest's act before the host applies it (friends-only was the
## old assumption; codes can be shared on). Static so tests can call it.
static func valid_act(d: Dictionary) -> bool:
	match str(d.get("a", "")):
		"farm_tile", "farm_clear":
			var key := str(d.get("key", ""))
			var parts := key.split(",")
			if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
				return false
			if absi(int(parts[0])) > 512 or absi(int(parts[1])) > 512:
				return false
			if str(d.get("a", "")) == "farm_tile":
				var tv: Variant = d.get("tile", null)
				return tv is Dictionary and JSON.stringify(tv).length() <= 1024
			return true
		"cleared":
			var rx := RegEx.create_from_string("^[a-z0-9_:\\-]{1,48}$")
			return rx.search(str(d.get("scene", ""))) != null and str(d.get("key", "")).length() in range(1, 49)
		"permit":
			var id := str(d.get("id", ""))
			var tier := int(d.get("tier", 0))
			return id != "" and tier >= 1 and tier <= 10 and not Builds.tier_def(id, tier).is_empty()
		"build":
			return str(d.get("id", "")) != "" and str(d.get("id", "")).length() <= 48
		"farm_tiles":
			var tv2: Variant = d.get("tiles", null)
			if not (tv2 is Dictionary) or (tv2 as Dictionary).size() > 600:
				return false
			for key in tv2:
				var t2: Variant = tv2[key]
				if not valid_act({"a": "farm_clear" if t2 == null else "farm_tile", "key": str(key), "tile": t2}):
					return false
			return true
		"sleep", "resync":
			return true
	return true  # other acts (other packages' handlers) check their own


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


## c13_18-09: a friend joining or leaving gets a toast and a soft cue (rate-limited
## so a reconnect storm is one sound).
func _peer_cue(nm: String, joined: bool) -> void:
	var now := Time.get_ticks_msec()
	if now - _cue_ms < PEER_CUE_GAP_MS or not is_inside_tree():
		return
	_cue_ms = now
	var who := NameFilter.clean(nm) if nm != "" else "A friend"
	_toast("%s %s." % [who, "joined" if joined else "left"], Color(0.8, 0.95, 1.0) if joined else Color(0.85, 0.85, 0.9))
	Music.instance(get_tree()).sfx("j_confirm" if joined else "door_close", "pop")


## Guests: should the local clock wait (the host is paused, or we're ahead of it)?
static func guest_hold() -> bool:
	var n := Net.i()
	if n == null or n._host or not n.visiting():
		return false
	return n.host_paused or n._ahead


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

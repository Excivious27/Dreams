class_name Net
## Static facade over the Net autoload (so script-mode tests that have no
## autoloads still compile and behave as "offline").

static var _node: NetNode = null


static func i() -> NetNode:
	if _node == null or not is_instance_valid(_node):
		var ml := Engine.get_main_loop()
		if ml is SceneTree and (ml as SceneTree).root.has_node("NetSvc"):
			_node = (ml as SceneTree).root.get_node("NetSvc") as NetNode
	return _node


static func online() -> bool:
	var n := i()
	return n != null and n.online()


## True while we are a co-op guest on someone else's farm (online, not the host).
static func visiting() -> bool:
	var n := i()
	return n != null and n.visiting()


static func is_host() -> bool:
	var n := i()
	return n == null or n.is_host()


static var peers: Dictionary:
	get:
		var n := i()
		return n.peers if n else {}


static var room: String:
	get:
		var n := i()
		return n.room if n else ""


static var peers_changed: Signal:
	get:
		return i().peers_changed


static var connected: Signal:
	get:
		return i().connected


static var disconnected: Signal:
	get:
		return i().disconnected


static func host(u: String) -> void:
	var n := i()
	if n: n.host(u)


static func join(u: String, code: String) -> void:
	var n := i()
	if n: n.join(u, code)


static func leave() -> void:
	var n := i()
	if n: n.leave()


static func send_all(d: Dictionary) -> void:
	var n := i()
	if n: n.send_all(d)


## send_host(d) = a legacy world act; send_host(t, d) = a router message.
static func send_host(a: Variant, b: Variant = null) -> void:
	var n := i()
	if n: n.send_host(a, b)


# ---- C17 message router (contract section 2) ----
## cb(from_peer: String, d: Dictionary). Works offline too (local delivery).
static func on_msg(t: String, cb: Callable) -> void:
	var n := i()
	if n: n.on_msg(t, cb)


static func off_msg(t: String, cb: Callable) -> void:
	var n := i()
	if n: n.off_msg(t, cb)


static func send_peer(peer: String, t: String, d: Dictionary) -> void:
	var n := i()
	if n: n.send_peer(peer, t, d)


static func broadcast(t: String, d: Dictionary, include_self := false) -> void:
	var n := i()
	if n: n.broadcast(t, d, include_self)


## False while we're a visiting guest and the host is away (grace / reconnecting).
static func host_present() -> bool:
	var n := i()
	return n == null or n.host_present()


## peer (String) -> {name, arc, scene, ping_ms, host, me}, ourselves included.
## (Contract "Net.peers()": the name Net.peers is the legacy id -> info property.)
static func roster() -> Dictionary:
	var n := i()
	return n.roster() if n else {}


static func my_peer() -> String:
	var n := i()
	return n.my_peer() if n else "local"


static func acked_seq() -> int:
	var n := i()
	return n.acked_seq() if n else 0


static func last_seq() -> int:
	var n := i()
	return n.last_seq() if n else 0


static var host_away: Signal:
	get:
		return i().host_away


static var host_back: Signal:
	get:
		return i().host_back


static var peer_joined: Signal:
	get:
		return i().peer_joined


static var peer_left: Signal:
	get:
		return i().peer_left


static func _send(o: Dictionary) -> void:
	var n := i()
	if n: n._send(o)


static func save_view(run: Dictionary) -> Dictionary:
	var n := i()
	return n.save_view(run) if n else run


static func send_scene(scene_id: String) -> void:
	var n := i()
	if n: n.send_scene(scene_id)


## Steam friends co-op (desktop + Steam only; false/no-op everywhere else).
static func steam_ready() -> bool:
	var n := i()
	return n != null and n.steam_ready()


static func host_steam() -> bool:
	var n := i()
	return n != null and n.host_steam()


static func join_steam(lobby_id: int) -> bool:
	var n := i()
	return n != null and n.join_steam(lobby_id)

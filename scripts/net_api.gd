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


static func send_host(d: Dictionary) -> void:
	var n := i()
	if n: n.send_host(d)


static func _send(o: Dictionary) -> void:
	var n := i()
	if n: n._send(o)


static func save_view(run: Dictionary) -> Dictionary:
	var n := i()
	return n.save_view(run) if n else run

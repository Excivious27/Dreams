extends SceneTree
## Play together uses the live relay out of the box (NetNode.DEFAULT_URL); a custom server
## can be typed and saved; "Reset to default" forgets it. Title page: server field filled
## with the default, Reset button (tap >= 20 px), "Back" last. Prints "net_url_test: N checks, 0 failures".
var checks := 0
var fails := 0


func _ok(c: bool, what: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL ", what)


func _initialize() -> void:
	seed(5)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _buttons(t: Node) -> Array:
	var out: Array = []
	for b in t.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion():
			out.append(b)
	return out


func _run() -> void:
	SaveGame.set_value("net_url", "")
	_ok(NetNode.DEFAULT_URL == "wss://dreams-64-23-239-63.sslip.io", "default is the live relay")
	_ok(NetNode.server_url() == NetNode.DEFAULT_URL and NetNode.uses_default(), "no saved server -> the default")
	SaveGame.set_value("net_url", "  wss://example.invalid/relay ")
	_ok(NetNode.server_url() == "wss://example.invalid/relay" and not NetNode.uses_default(), "a saved custom server is used (trimmed)")
	NetNode.reset_server()
	_ok(str(SaveGame.get_value("net_url", "x")) == "" and NetNode.uses_default(), "reset_server forgets the custom server")
	# Title page
	SaveGame.set_value("net_url", "wss://example.invalid/relay")
	change_scene_to_file("res://scenes/title.tscn")
	await _frames(10)
	var t := current_scene
	t.call("_show_net")
	await _frames(4)
	var field: LineEdit = t.get("_net_url")
	_ok(field != null and field.text == "wss://example.invalid/relay", "field shows the saved custom server")
	var bs := _buttons(t)
	var reset: Button = null
	for b: Button in bs:
		if b.text == "Reset to default":
			reset = b
	_ok(reset != null, "Reset to default button")
	_ok(bs.size() > 0 and (bs[bs.size() - 1] as Button).text == "Back", "Back is the last button (way out last)")
	if reset:
		_ok(reset.size.y >= 20 and reset.size.x >= 20, "Reset tap target >= 20 px (%s)" % str(reset.size))
		reset.pressed.emit()
		await _frames(2)
		_ok(field.text == NetNode.DEFAULT_URL and NetNode.uses_default(), "Reset puts the default back and forgets the custom one")
	# A fresh page with nothing saved shows the default, ready to Host/Join with no typing.
	t.call("_show_net")
	await _frames(4)
	field = t.get("_net_url")
	_ok(field.text == NetNode.DEFAULT_URL, "fresh page: the default is filled in")
	# Connecting with the default (or an empty field) saves "" so a later default move reaches everyone.
	var net := NetNode.new()
	root.add_child(net)
	_ok(NetNode.pick_url("  ") == NetNode.DEFAULT_URL and NetNode.pick_url(" wss://a.b ") == "wss://a.b", "an empty field means the default")
	net._connect(NetNode.DEFAULT_URL)
	_ok(net.url == NetNode.DEFAULT_URL and str(SaveGame.get_value("net_url", "x")) == "", "connecting to the default saves \"\"")
	net._connect("wss://example.invalid/relay")
	_ok(str(SaveGame.get_value("net_url", "")) == "wss://example.invalid/relay", "a custom server is saved on connect")
	net.tr = null
	NetNode.reset_server()
	print("net_url_test: %d checks, %d failures" % [checks, fails])
	quit(0 if fails == 0 else 1)

class_name CoopPanel
extends RefCounted
## CONDUCT 17 P5: the in-game "Play together" page (Menu > Options > Play together, and
## Party > Play together) plus the small HUD co-op strip. Everything a phone player needs
## once the title page is gone: the room code (big, with Copy), who is here (name, arc,
## where, host mark, link bars), Host / Join / Rejoin while offline, Go home (guest) and
## End co-op with a confirm (host), and the host's per-guest controls (kick, permissions,
## lock room). All words, no free text: names go through NameFilter.
##   CoopPanel.build(menu)          game_menu.gd "Coop" page
##   CoopPanel.row_text()           the Options row label
##   CoopPanel.allowed(peer, what)  host side: may this guest "farm" / "build" / "chests"?
##   CoopPanel.attach_strip(hud)    hud.gd: the chip under the date box while online

const PERMS := {"farm": "Can farm my fields", "chests": "Can open my chests", "build": "Can build and spend"}
const PERM_DEFAULT := {"farm": true, "chests": true, "build": false}
## host: peer id (String) -> {farm, chests, build}. Not saved: a room's rules end with the room.
static var perms := {}
static var locked := false
static var _arm := ""  # "end" / "kick:<id>": the next tap of the same row confirms
static var _join_code := ""
static var last_room := ""  # the room we were last in (Rejoin offers it after a drop)


static func _n() -> NetNode:
	return Net.i()


## Peer dictionary (router `Net.peers()` when P1's router is in, else NetNode.peers).
static func peer_list() -> Dictionary:
	var n := _n()
	if n == null:
		return {}
	if n.has_method("roster"):  # P1's router: String peer -> {name, arc, scene, ping_ms, host, me}
		var out := {}
		var v: Variant = n.call("roster")
		if v is Dictionary:
			for k in v:
				if v[k] is Dictionary and not bool((v[k] as Dictionary).get("me", false)):
					out[str(k)] = v[k]
		return out
	var pv: Variant = n.get("peers")
	return pv if pv is Dictionary else {}


## The HUD place words while visiting: "Your Farm" -> "Kairi's farm" (the host's filtered name).
static func visit_place(words: String) -> String:
	var host := "Your host"
	var pl := peer_list()
	for k in pl:
		if pl[k] is Dictionary and bool((pl[k] as Dictionary).get("host", false)):
			host = NameFilter.clean(str((pl[k] as Dictionary).get("name", "")), "Your host")
	var lw := words.to_lower()
	if lw.contains("your farm") or lw == "farm":
		return "%s's farm" % host
	if lw.contains("farmhouse") or lw.contains("your house") or lw == "home":
		return "%s's house" % host
	return words


## One line said when the next map is up (the guest's welcome, c17_14-08).
static var arrival_note := ""


static func online() -> bool:
	return Net.online()


static func room_code() -> String:
	var r := Net.room
	if r != "":
		last_room = r
	return r


## Host side: may guest `peer` do `what` ("farm", "chests", "build")? Unknown guests get the defaults.
static func allowed(peer: Variant, what: String) -> bool:
	var p: Dictionary = perms.get(str(peer), {})
	return bool(p.get(what, PERM_DEFAULT.get(what, false)))


static func set_perm(peer: Variant, what: String, on: bool) -> void:
	var k := str(peer)
	if not perms.has(k):
		perms[k] = PERM_DEFAULT.duplicate()
	perms[k][what] = on
	var n := _n()
	if n and n.has_method("send_peer"):
		n.call("send_peer", k, "party_perm", {"perms": perms[k]})


## Host: the room is locked (no new players). Mirrored to the relay when P1's router has set_locked.
static func set_locked(on: bool) -> void:
	locked = on
	var n := _n()
	if n and n.has_method("set_locked"):
		n.call("set_locked", on)


static func kick(peer: Variant) -> void:
	var n := _n()
	if n == null:
		return
	perms.erase(str(peer))
	if n.has_method("kick"):
		n.call("kick", peer)
	if n.has_method("send_peer"):
		n.call("send_peer", str(peer), "kick", {})


## Players in the room (us first), each {id, name, arc, scene, ping, host, me}.
## Router hooks (once): a guest obeys the host's "kick" and keeps the host's permission words.
static var _hooked := false
static var my_perms := {}


static func hook() -> void:
	var n := _n()
	if _hooked or n == null or not n.has_method("on_msg"):
		return
	_hooked = true
	n.call("on_msg", "kick", Callable(CoopPanel, "_on_kick"))
	n.call("on_msg", "party_perm", Callable(CoopPanel, "_on_perm"))


static func _from_host(from: String) -> bool:
	var pl := peer_list()
	return pl.has(from) and bool((pl[from] as Dictionary).get("host", false))


static func _on_kick(from: String, _d: Dictionary) -> void:
	if Net.is_host() or not _from_host(from):
		return
	last_room = ""  # no Rejoin offer into a room we were sent home from
	var n := _n()
	if n:
		n._last_room = ""
		n.leave("The host sent you home. You're back on your own farm.")


static func _on_perm(from: String, d: Dictionary) -> void:
	if Net.is_host() or not _from_host(from):
		return
	var pv: Variant = d.get("perms", {})
	my_perms = pv if pv is Dictionary else {}
	var ml := Engine.get_main_loop()
	if ml is SceneTree and (ml as SceneTree).current_scene is GameMap and ((ml as SceneTree).current_scene as GameMap).hud:
		var bits: Array = []
		for k in PERMS:
			if not bool(my_perms.get(k, PERM_DEFAULT[k])):
				bits.append(str(PERMS[k]).to_lower().replace("can ", "").replace(" my ", " the host's "))
		((ml as SceneTree).current_scene as GameMap).hud.toast("Host rules: you can't %s." % ", ".join(bits) if not bits.is_empty() else "Host rules: you can farm, open chests and build.", Color(0.85, 0.95, 1.0))


static func players() -> Array:
	var out: Array = []
	var me_host := Net.is_host()
	out.append({"id": "me", "name": NameFilter.clean(str(GameState.names().get("character", "You")) if not GameState.run.is_empty() else "You"), "arc": str(GameState.run.get("arc", "")),
		"scene": _my_scene(), "ping": -1, "host": me_host, "me": true})
	var pl := peer_list()
	for id in pl:
		var p: Dictionary = pl[id] if pl[id] is Dictionary else {}
		out.append({"id": str(id), "name": NameFilter.clean(str(p.get("name", "Player"))), "arc": str(p.get("arc", "")), "scene": str(p.get("scene", "")),
			"ping": int(p.get("ping_ms", -1)), "host": bool(p.get("host", false)), "me": false})
	return out


static func _my_scene() -> String:
	var ml := Engine.get_main_loop()
	if ml is SceneTree and (ml as SceneTree).current_scene is GameMap:
		return ((ml as SceneTree).current_scene as GameMap).scene_id()
	return ""


static func place(scene: String) -> String:
	if scene == "":
		return "on the way"
	if scene.begins_with("bf_"):
		return "in a fight"
	var base := scene.split(":")[0]
	var t := PlaceNames.for_id(base)
	return t if t != "" else base.capitalize()


static func arc_word(arc: String) -> String:
	return "Penguins" if arc == "penguins" else ("Gangsters" if arc == "gangsters" else "")


## Link quality words from a round trip in ms (-1 unknown).
static func link_word(ms: int) -> String:
	if ms < 0:
		return ""
	return "good link" if ms < 150 else ("ok link" if ms < 300 else "slow link")


static func row_text() -> String:
	if online():
		var c := room_code()
		var k := players().size()
		return "Play together: room %s · %d here ›" % [c if c != "" else "(Steam)", k]
	return "Play together ›"


static func status_word() -> String:
	var n := _n()
	if n == null:
		return ""
	if n.tr == null and n._retry_t > 0.0 and n._retries < NetNode.MAX_RETRIES:
		return "Reconnecting %d/%d…" % [n._retries + 1, NetNode.MAX_RETRIES]
	if online() and not Net.is_host():
		if n.has_method("host_present") and not bool(n.call("host_present")):
			return "Waiting for your host…"
		if NetNode.guest_hold():
			return "Host is in a menu: the clock waits" if n.host_paused else "Catching up with your host…"
	return ""


## The Coop page inside GameMenu. `menu` is the GameMenu (its _line/_button add rows).
static func build(menu: Node) -> void:
	menu.call("_line", "Play together", 12, Color(1, 0.95, 0.8))
	var n := _n()
	if not Settings.online_ok():
		menu.call("_line", "Online play is off in Options > Play together. Turn it on to host or join friends.", 8, Color(0.85, 0.85, 0.85))
		menu.call("_button", "Turn online play on", func() -> void: Settings.set_online_ok(true); menu.call("_refresh"))
		return
	var st := status_word()
	if st != "":
		menu.call("_line", st, 9, Color(1, 0.8, 0.45))
	if online():
		_build_online(menu, n)
	else:
		_build_offline(menu, n)


static func _build_online(menu: Node, n: NetNode) -> void:
	var code := room_code()
	var host := Net.is_host()
	if code != "":
		var l: Label = menu.call("_line", "Room  %s" % code, 20, Color(1, 0.92, 0.55))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		menu.call("_button", "Copy the code", func() -> void:
			DisplayServer.clipboard_set(code)
			var m := menu.get_tree().current_scene as GameMap
			if m and m.hud:
				m.hud.toast("Room code %s copied." % code))
		menu.call("_line", "Friends open Dreams, tap Play together, then Join with code.", 8, Color(0.8, 0.8, 0.8))
	else:
		menu.call("_line", "Steam lobby: friends join from your Steam friends list.", 8, Color(0.8, 0.8, 0.8))
	menu.call("_line", "Players", 10, Color(1, 0.95, 0.8))
	for p: Dictionary in players():
		var tag := ("Host: " if p["host"] else "") + str(p["name"]) + (" (you)" if p["me"] else "")
		var bits: Array = []
		if arc_word(str(p["arc"])) != "":
			bits.append(arc_word(str(p["arc"])))
		bits.append(place(str(p["scene"])))
		if link_word(int(p["ping"])) != "":
			bits.append(link_word(int(p["ping"])))
		menu.call("_line", "  %s · %s" % [tag, " · ".join(bits)], 8, Color(1, 1, 0.9) if p["me"] else Color(0.85, 0.95, 1.0))
		if host and not p["me"]:
			_guest_controls(menu, str(p["id"]), str(p["name"]))
	if host:
		menu.call("_button", ("Room locked: no new players (tap to open)" if locked else "Lock the room (no new players)"), func() -> void: set_locked(not locked); menu.call("_refresh"))
		var k := players().size() - 1
		menu.call("_line", "Friends' clocks wait while your menu is open.", 8, Color(0.75, 0.85, 0.75))
		var arm := _arm == "end"
		menu.call("_button", ("Sure? Tap again: your %d friend%s go back to their own farms" % [k, "" if k == 1 else "s"]) if arm else "End co-op for everyone", func() -> void:
			if _arm == "end":
				_arm = ""
				Net.leave()
				menu.call("_refresh")
			else:
				_arm = "end"
				menu.call("_refresh"))
	else:
		menu.call("_button", "Go home (leave the room)", func() -> void:
			_arm = ""
			Net.leave()  # restores our own farm and walks us home (NetNode._restore_solo)
			menu.call("_refresh"))


static func _guest_controls(menu: Node, id: String, nm: String) -> void:
	for what in PERMS:
		var on := allowed(id, what)
		menu.call("_button", "     %s %s" % ["[x]" if on else "[ ]", PERMS[what]], func() -> void: set_perm(id, what, not on); menu.call("_refresh"))
	var arm := _arm == "kick:" + id
	menu.call("_button", ("     Sure? Tap again to send %s home" % nm) if arm else "     Send %s home" % nm, func() -> void:
		if _arm == "kick:" + id:
			_arm = ""
			kick(id)
		else:
			_arm = "kick:" + id
		menu.call("_refresh"))


static func _build_offline(menu: Node, n: NetNode) -> void:
	if n == null:
		menu.call("_line", "Co-op isn't available here.", 8, Color(0.8, 0.8, 0.8))
		return
	menu.call("_line", "Open your farm to friends, or visit a friend's farm. Everyone keeps their own character, pack and money; the host's farm is the world.", 8, Color(0.85, 0.85, 0.85))
	if last_room != "" or str(n._last_room) != "":
		var lr := last_room if last_room != "" else str(n._last_room)
		menu.call("_button", "Rejoin room %s" % lr, func() -> void:
			Net.join(NetNode.server_url(), lr)
			menu.call("_line", "Connecting...", 8, Color(1, 0.9, 0.6)))
	menu.call("_button", "Host a room (open my farm)", func() -> void:
		Net.host(NetNode.server_url())
		menu.call("_line", "Connecting...", 8, Color(1, 0.9, 0.6)))
	if n.steam_ready():
		menu.call("_button", "Host with Steam friends", func() -> void: n.host_steam())
	menu.call("_line", "Join a friend: type their code", 8, Color(0.85, 0.85, 0.85))
	var e := LineEdit.new()
	e.max_length = 6
	e.placeholder_text = "ABCD"
	e.custom_minimum_size = Vector2(0, 22)
	e.add_theme_font_size_override("font_size", Settings.font(12))
	e.text = _join_code
	e.text_changed.connect(func(t: String) -> void:
		var up := clean_code(t)
		_join_code = up
		if up != t:
			e.text = up
			e.caret_column = up.length())
	menu.get("_body").add_child(e)
	menu.call("_button", "Join with code", func() -> void:
		var why := code_problem(_join_code)
		if why != "":
			Music.instance(menu.get_tree()).sfx("nope", "thud")
			menu.call("_line", why, 8, Color(1, 0.7, 0.5))
			return
		Net.join(NetNode.server_url(), _join_code)
		menu.call("_line", "Connecting...", 8, Color(1, 0.9, 0.6)))


## Codes are upper case letters/digits only (the relay alphabet skips O, 0, I and 1).
static func clean_code(t: String) -> String:
	var out := ""
	for ch in t.to_upper():
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out.substr(0, 6)


## "" when `code` can be sent, else the words to show (empty or short codes never connect:
## an empty join used to host a brand-new room, c17_01-05).
static func code_problem(code: String) -> String:
	var c := clean_code(code)
	if c.length() < 4:
		return "Type the 4-letter code from your host."
	return ""


## Friendly words for a connect failure (never a raw close code or wss:// address).
static func friendly_error(why: String) -> String:
	var w := why.to_lower()
	if w.begins_with("couldn't reach") or w.contains("1006") or w.contains("connection closed") or w.contains("closed ("):
		return "Couldn't reach the Dreams server. Check your internet and try again."
	if w.contains("no game with that code"):
		return "No game with that code. Check it with your host (codes never use O, 0, I or 1)."
	return why


# ---- HUD strip -----------------------------------------------------------------

static func attach_strip(hud: Node) -> void:
	if hud == null or hud.has_node("CoopStrip"):
		return
	var s := CoopStripNode.new()
	s.name = "CoopStrip"
	hud.add_child(s)


class CoopStripNode extends CanvasLayer:
	var _btn: Button
	var _t := 0.0
	var _rect := Rect2()

	func _ready() -> void:
		layer = 6
		process_mode = Node.PROCESS_MODE_ALWAYS
		if CoopPanel.arrival_note != "" and get_parent() is Hud:
			(get_parent() as Hud).toast.call_deferred(CoopPanel.arrival_note, Color(0.8, 0.95, 1.0))
			CoopPanel.arrival_note = ""
		_btn = Button.new()
		_btn.focus_mode = Control.FOCUS_NONE
		_btn.add_theme_font_size_override("font_size", Settings.font(7))
		_btn.position = Vector2(166, 32)
		_btn.size = Vector2(100, 20)
		_btn.custom_minimum_size = Vector2(100, 20)
		_btn.clip_text = true
		_btn.visible = false
		_btn.pressed.connect(func() -> void: GameMenu.open_page(get_tree(), "Coop"))
		add_child(_btn)

	func _process(delta: float) -> void:
		_t += delta
		if _t < 0.25:
			return
		_t = 0.0
		var show := CoopPanel.online() or CoopPanel.status_word() != ""
		var sc := get_tree().current_scene
		if sc == null or not (sc is GameMap) or str((sc as GameMap).scene_id()).begins_with("bf_") or get_tree().paused:
			show = false
		_btn.visible = show
		if _rect != Rect2():
			Hud.extra_rects.erase(_rect)
			_rect = Rect2()
		if not show:
			return
		var st := CoopPanel.status_word()
		var c := CoopPanel.room_code()
		var k := CoopPanel.players().size()
		_btn.text = st if st != "" else ("Room %s · %d" % [c, k] if c != "" else "Together · %d" % k)
		_btn.modulate = Color(1, 0.8, 0.45) if st != "" else Color(1, 1, 1)
		_rect = Rect2(_btn.position, _btn.size)
		Hud.extra_rects.append(_rect)

	func _exit_tree() -> void:
		if _rect != Rect2():
			Hud.extra_rects.erase(_rect)

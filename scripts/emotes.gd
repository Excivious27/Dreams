class_name Emotes
extends RefCounted
## CONDUCT 17 P5 (c17_09-04, c17_17-20): co-op emotes, preset phrases and a map ping.
## All ages: NO free text ever crosses the wire. A phrase is an index into PHRASES, an emote
## an id from EMOTES (art/gen/emotes), a ping a cell in a scene. Rate-limited to one a second.
## Rides P1's message router (`emote` / `ping` types): host broadcasts, guests send to each peer.
##   Emotes.send_emote(id) / send_phrase(i) / send_ping(cell)
##   Emotes.receive(from_peer, d)   router callback (also used by tests)
##   Emotes.attach_button(hud)      HUD button that opens the wheel (>= 20 px, Hud.extra_rects)

const EMOTES := ["hero_wave", "heart", "laugh", "idea", "music", "gift", "confused", "sleep"]
const PHRASES := ["Hi!", "Over here!", "Help!", "Thanks!", "Nice!", "Follow me", "Wait for me", "Let's go home", "Good night"]
const GAP_MS := 1000
const PING_SECS := 4.0
static var _last_ms := -100000
static var _hooked := false
static var log: Array = []  # last received {from, k, ...} (tests and the strip read it)


static func _n() -> NetNode:
	return Net.i()


## Hook the router once (P1's Net.on_msg). Safe to call every map load.
static func hook() -> void:
	var n := _n()
	if _hooked or n == null or not n.has_method("on_msg"):
		return
	_hooked = true
	n.call("on_msg", "emote", Callable(Emotes, "receive"))
	n.call("on_msg", "ping", Callable(Emotes, "receive"))


static func _now_ms() -> int:
	return PlayClock.ms()


static func _rate_ok() -> bool:
	var t := _now_ms()
	if t - _last_ms < GAP_MS:
		return false
	_last_ms = t
	return true


static func _send(t: String, d: Dictionary) -> bool:
	if not _rate_ok():
		return false
	var n := _n()
	if n != null and Net.online():
		if Net.is_host() and n.has_method("broadcast"):
			n.call("broadcast", t, d)
		elif n.has_method("send_peer"):
			for pid in CoopPanel.peer_list():
				n.call("send_peer", str(pid), t, d)
	return true


static func send_emote(id: String) -> bool:
	if id not in EMOTES:
		return false
	var ok := _send("emote", {"e": id})
	if ok:
		_show_on(_local_player(), {"e": id})
	return ok


static func send_phrase(i: int) -> bool:
	if i < 0 or i >= PHRASES.size():
		return false
	var ok := _send("emote", {"p": i})
	if ok:
		_show_on(_local_player(), {"p": i})
	return ok


static func send_ping(cell: Vector2i) -> bool:
	var m := _map()
	var sc := m.scene_id() if m else ""
	var ok := _send("ping", {"scene": sc, "cell": [cell.x, cell.y]})
	if ok and m:
		_drop_ping(m, cell, "You")
	return ok


## Router callback: cb(from_peer, d). Unknown ids / out-of-range phrases are ignored (never shown as text).
static func receive(from_peer: Variant, d: Dictionary) -> void:
	var from := str(from_peer)
	if not Settings.emotes_on():
		return
	var entry := {"from": from}
	if d.has("e"):
		if str(d["e"]) not in EMOTES:
			return
		entry["e"] = str(d["e"])
	elif d.has("p"):
		var i := int(d["p"])
		if i < 0 or i >= PHRASES.size():
			return
		entry["p"] = i
	elif d.has("cell"):
		var cv: Variant = d["cell"]
		if not (cv is Array) or (cv as Array).size() < 2:
			return
		entry["cell"] = Vector2i(int(cv[0]), int(cv[1]))
		entry["scene"] = str(d.get("scene", ""))
	else:
		return
	log.append(entry)
	if log.size() > 20:
		log.pop_front()
	var m := _map()
	if m == null:
		return
	if entry.has("cell"):
		if str(entry["scene"]) == m.scene_id():
			_drop_ping(m, entry["cell"], _peer_name(from))
		elif m.hud:
			m.hud.toast("%s pinged %s." % [_peer_name(from), CoopPanel.place(str(entry["scene"]))], Color(1, 0.9, 0.55))
		return
	var pup := _puppet(m, from)
	if pup:
		_show_on(pup, entry)
	elif m.hud and entry.has("p"):
		m.hud.toast("%s: %s" % [_peer_name(from), PHRASES[int(entry["p"])]], Color(0.85, 0.95, 1.0))


static func _peer_name(from: String) -> String:
	var pl := CoopPanel.peer_list()
	for k in pl:
		if str(k) == from and pl[k] is Dictionary:
			return NameFilter.clean(str((pl[k] as Dictionary).get("name", "A friend")), "A friend")
	return "A friend"


static func _map() -> GameMap:
	var ml := Engine.get_main_loop()
	if ml is SceneTree and (ml as SceneTree).current_scene is GameMap:
		return (ml as SceneTree).current_scene as GameMap
	return null


static func _local_player() -> Node2D:
	var m := _map()
	return m.player if m else null


static func _puppet(m: GameMap, from: String) -> Node2D:
	for p in m.get_tree().get_nodes_in_group("net_puppet"):
		if str(p.get("peer_id")) == from:
			return p
	return null


## An emote bubble or a phrase card over a player or puppet (2.5 s).
static func _show_on(over: Node2D, entry: Dictionary) -> void:
	if over == null or not over.is_inside_tree():
		return
	var m := _map()
	if entry.has("e") and m:
		m.emote(over, str(entry["e"]), 1.8, -30.0)
		return
	if not entry.has("p"):
		return
	var l := Label.new()
	l.text = PHRASES[int(entry["p"])]
	l.add_theme_font_size_override("font_size", Settings.font(7))
	l.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.97, 0.88, 0.95)
	sb.border_color = Color(0.35, 0.22, 0.1)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	l.add_theme_stylebox_override("normal", sb)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 40
	l.set_meta("phrase", true)
	over.add_child(l)
	l.reset_size()
	l.position = Vector2(-l.size.x / 2.0, -54)
	var tw := l.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


## A bouncing marker on a cell both players see for PING_SECS.
static func _drop_ping(m: GameMap, cell: Vector2i, who: String) -> void:
	var node := PingMarker.new()
	node.who = who
	node.position = m.cell_center(cell)
	node.z_index = 35
	m.add_child(node)
	Music.instance(m.get_tree()).sfx("ui_tap", "pop")


class PingMarker extends Node2D:
	var who := ""
	var t := 0.0

	func _ready() -> void:
		add_to_group("coop_ping")

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
		if t >= Emotes.PING_SECS:
			queue_free()

	func _draw() -> void:
		var bob := -absf(sin(t * 5.0)) * 4.0
		var ring := fmod(t, 1.0)
		draw_arc(Vector2.ZERO, 4.0 + ring * 8.0, 0, TAU, 20, Color(1, 0.85, 0.3, 1.0 - ring), 1.0)
		var p := Vector2(0, -10 + bob)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-4, -4), p + Vector2(4, -4), p + Vector2(0, 5)]), Color(1, 0.8, 0.2))
		draw_circle(p + Vector2(0, -4), 4.0, Color(1, 0.8, 0.2))
		draw_circle(p + Vector2(0, -4), 1.6, Color(0.35, 0.2, 0.05))


# ---- the wheel (HUD button) ----------------------------------------------------

static func attach_button(hud: Node) -> void:
	if hud == null or hud.has_node("EmoteBtn"):
		return
	var l := EmoteLayer.new()
	l.name = "EmoteBtn"
	hud.add_child(l)


class EmoteLayer extends CanvasLayer:
	var _btn: TextureButton
	var _wheel: Control
	var _rect := Rect2()
	var _t := 0.0

	func _ready() -> void:
		layer = 6
		process_mode = Node.PROCESS_MODE_ALWAYS
		_btn = TextureButton.new()
		_btn.texture_normal = Art.tex("emotes", "hero_wave") if Art.has("emotes", "hero_wave") else null
		_btn.ignore_texture_size = true
		_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		_btn.position = Vector2(244, 54)
		_btn.size = Vector2(22, 22)
		_btn.focus_mode = Control.FOCUS_NONE
		_btn.visible = false
		_btn.pressed.connect(_toggle)
		add_child(_btn)

	func _process(delta: float) -> void:
		_t += delta
		if _t < 0.25:
			return
		_t = 0.0
		var sc := get_tree().current_scene
		var show := Net.online() and sc is GameMap and not get_tree().paused
		_btn.visible = show
		if not show and _wheel:
			_close()
		if _rect != Rect2():
			Hud.extra_rects.erase(_rect)
			_rect = Rect2()
		if show:
			_rect = Rect2(_btn.position, _btn.size)
			Hud.extra_rects.append(_rect)

	func _exit_tree() -> void:
		if _rect != Rect2():
			Hud.extra_rects.erase(_rect)
		if _wheel:
			_close()

	func _toggle() -> void:
		if _wheel:
			_close()
			return
		_wheel = PanelContainer.new()
		_wheel.position = Vector2(62, 80)
		_wheel.size = Vector2(180, 0)
		var v := VBoxContainer.new()
		_wheel.add_child(v)
		var g := GridContainer.new()
		g.columns = 4
		v.add_child(g)
		for e in Emotes.EMOTES:
			var b := TextureButton.new()
			b.texture_normal = Art.tex("emotes", e) if Art.has("emotes", e) else null
			b.ignore_texture_size = true
			b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			b.custom_minimum_size = Vector2(28, 26)
			b.pressed.connect(func() -> void: Emotes.send_emote(e); _close())
			g.add_child(b)
		var g2 := GridContainer.new()
		g2.columns = 2
		v.add_child(g2)
		for i in Emotes.PHRASES.size():
			var pb := Button.new()
			pb.text = Emotes.PHRASES[i]
			pb.add_theme_font_size_override("font_size", Settings.font(8))
			pb.custom_minimum_size = Vector2(80, 20)
			pb.pressed.connect(func() -> void: Emotes.send_phrase(i); _close())
			g2.add_child(pb)
		var ping := Button.new()
		ping.text = "Ping my spot"
		ping.add_theme_font_size_override("font_size", Settings.font(8))
		ping.custom_minimum_size = Vector2(0, 20)
		ping.pressed.connect(func() -> void:
			var m := Emotes._map()
			if m and m.player:
				Emotes.send_ping(m.world_to_cell(m.player.position))
			_close())
		v.add_child(ping)
		var close := Button.new()
		close.text = "Close"
		close.add_theme_font_size_override("font_size", Settings.font(8))
		close.custom_minimum_size = Vector2(0, 20)
		close.pressed.connect(_close)
		v.add_child(close)
		Hud.skin_buttons(_wheel)
		add_child(_wheel)
		_wheel.reset_size()
		Hud.extra_rects.append(Rect2(_wheel.position, _wheel.size))
		_wheel.set_meta("rect", Rect2(_wheel.position, _wheel.size))

	func _close() -> void:
		if _wheel:
			Hud.extra_rects.erase(_wheel.get_meta("rect", Rect2()))
			_wheel.queue_free()
			_wheel = null

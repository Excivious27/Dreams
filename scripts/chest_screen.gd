class_name ChestScreen
extends CanvasLayer
## Sun Haven-style chest: the chest's slots on top, your bag below.
## Tap an item to move it across (All / 10 / 1). Sort, Quick stack (same items
## in), Deposit all, Take all. B or MENU closes.

signal closed

var m: GameMap
var key := ""
var head := ""
var _root: PanelContainer
var _top: GridContainer
var _bot: GridContainer
var _ttl: Label
var _btl: Label
var _amt := 0   # 0 all, 1 ten, 2 one
var _amt_btn: Button
var _was_paused := false
var _arm := 0
const SLOT := 30


static func open(map: GameMap, k: String, title: String) -> void:
	var s := ChestScreen.new()
	s.m = map
	s.key = k
	s.head = title
	map.add_child(s)
	await s.closed


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	Hud.modal_rect = Rect2(0, 0, 270, 480)
	get_tree().paused = true
	Music.instance(get_tree()).sfx("chest_open", "door")
	_root = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.11, 0.07, 0.97)
	sb.border_color = Color(0.85, 0.7, 0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(5)
	_root.add_theme_stylebox_override("panel", sb)
	_root.position = Vector2(4, 22)
	_root.size = Vector2(262, 440)
	add_child(_root)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	_root.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_ttl = _label("", 10, Color(1, 0.9, 0.6))
	_ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_ttl)
	var x := _btn("✕", close)
	x.custom_minimum_size = Vector2(26, 22)
	top.add_child(x)
	_top = _scroll_grid(v, 150)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	v.add_child(row)
	row.add_child(_btn("Sort", func() -> void: Storage.sort_box(key); GameState.sort_bag(); _refresh()))
	row.add_child(_btn("Quick stack", func() -> void: _note(Storage.quick_stack(key), "stacked")))
	row.add_child(_btn("Deposit all", func() -> void: _note(Storage.deposit_all(key), "stored")))
	row.add_child(_btn("Take all", func() -> void: _note(Storage.take_all(key), "taken")))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 2)
	v.add_child(row2)
	_btl = _label("", 9, Color(0.95, 0.9, 0.75))
	_btl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(_btl)
	_amt_btn = _btn("Move: all", func() -> void: _amt = (_amt + 1) % 3; _refresh())
	row2.add_child(_amt_btn)
	if key.begins_with("p:"):
		row2.add_child(_btn("Pick up", _pick_up))
	_bot = _scroll_grid(v, 225)
	_refresh()


func _scroll_grid(v: VBoxContainer, h: float) -> GridContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(250, h)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var g := GridContainer.new()
	g.columns = 8
	g.add_theme_constant_override("h_separation", 1)
	g.add_theme_constant_override("v_separation", 1)
	sc.add_child(g)
	return g


func _process(_d: float) -> void:
	_arm += 1
	if _arm < 8:
		return
	if Input.is_action_just_pressed("b") or Input.is_action_just_pressed("menu"):
		close()


func close() -> void:
	if not is_inside_tree():
		return
	get_tree().paused = _was_paused
	Dialogue.block_input(0.3)
	Hud.modal_rect = Rect2()
	if m and m.player and m.player.has_method("refresh_held"):
		m.player.call("refresh_held")
	closed.emit()
	queue_free()


func _label(t: String, sz: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", c)
	return l


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 8)
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _note(n: int, verb: String) -> void:
	Music.instance(get_tree()).sfx("pickup" if n > 0 else "nope", "thud")
	if m and m.hud:
		m.hud.toast("%d stack%s %s." % [n, "" if n == 1 else "s", verb] if n > 0 else "Nothing to move.")
	_refresh()


func _n(have: int) -> int:
	return have if _amt == 0 else mini(have, 10 if _amt == 1 else 1)


func _slot(id: String, count: int, cb: Callable, q: Dictionary = {}) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(SLOT, SLOT)
	b.focus_mode = Control.FOCUS_NONE
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE  # a drag to scroll never moves an item
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.17, 0.1) if id != "" else Color(0.19, 0.13, 0.08)
	sb.border_color = GameState.rarity_color(id).darkened(0.3) if id != "" else Color(0.1, 0.07, 0.04)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	if id != "":
		b.pressed.connect(cb)
		b.tooltip_text = GameState.item_name(id)
		var tex := Art.tex("items", Hud.icon_for(id))
		if tex:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.set_anchors_preset(Control.PRESET_FULL_RECT)
			tr.offset_left = 3
			tr.offset_top = 3
			tr.offset_right = -3
			tr.offset_bottom = -3
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(tr)
		else:
			b.text = GameState.item_name(id).left(4)
			b.add_theme_font_size_override("font_size", 7)
		if count > 1:
			var n := _label(str(count), 7, Color.WHITE)
			n.add_theme_constant_override("outline_size", 2)
			n.add_theme_color_override("font_outline_color", Color.BLACK)
			n.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			n.offset_left = -18
			n.offset_top = -11
			n.offset_right = -2
			n.offset_bottom = -1
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(n)
		if int(q.get("g", 0)) + int(q.get("s", 0)) > 0:
			var st := _label("★" if int(q.get("g", 0)) > 0 else "☆", 8, Color(1, 0.85, 0.3) if int(q.get("g", 0)) > 0 else Color(0.85, 0.9, 1.0))
			st.position = Vector2(2, 0)
			st.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(st)
	return b


func _refresh() -> void:
	for g in [_top, _bot]:
		for c in (g as Node).get_children():
			c.queue_free()
	_ttl.text = "%s  %d/%d" % [head, Storage.slots_used(key), Storage.cap(key)]
	_amt_btn.text = ["Move: all", "Move: 10", "Move: 1"][_amt]
	var b := Storage.box(key)
	var shown := 0
	for id: String in (b["items"] as Dictionary).keys():
		var have := int(b["items"][id])
		while have > 0:
			var stack := mini(have, Storage.STACK)
			have -= stack
			shown += 1
			_top.add_child(_slot(id, stack, _take.bind(id), b["q"].get(id, {})))
	for i in maxi(0, Storage.cap(key) - shown):
		_top.add_child(_slot("", 0, func() -> void: pass))
	_btl.text = "Bag %d/%d" % [GameState.bag_used(), GameState.bag_size()] + ("  · %s" % _last if _last != "" else "")
	var inv: Dictionary = GameState.run["inventory"]
	for id: String in inv.keys():
		_bot.add_child(_slot(id, int(inv[id]), _put.bind(id), GameState.quality_of(id)))
	for i in maxi(0, GameState.bag_size() - inv.size()):
		_bot.add_child(_slot("", 0, func() -> void: pass))


var _last := ""


func _take(id: String) -> void:
	_last = GameState.item_name(id)
	if Storage.withdraw(key, id, _n(Storage.amount(key, id))) == 0:
		Music.instance(get_tree()).sfx("nope", "thud")
		if m and m.hud:
			m.hud.toast("Your bag is full.")
	else:
		Music.instance(get_tree()).sfx("pickup")
	_refresh()


func _put(id: String) -> void:
	_last = GameState.item_name(id)
	if Storage.deposit(key, id, _n(GameState.count(id))) == 0:
		Music.instance(get_tree()).sfx("nope", "thud")
		if m and m.hud:
			m.hud.toast("The chest is full.")
	else:
		Music.instance(get_tree()).sfx("ui_tap", "pickup")
	_refresh()


func _pick_up() -> void:
	if not Storage.is_empty(key):
		if m and m.hud:
			m.hud.toast("Empty the chest first.")
		return
	var xy := key.substr(2).split(",")
	var c := Vector2i(int(xy[0]), int(xy[1]))
	(GameState.run["chests"] as Dictionary).erase(key)
	close()
	if m and m.has_method("pickup_placed"):
		m.call("pickup_placed", c)

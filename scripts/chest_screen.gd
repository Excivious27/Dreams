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
var _amt := 0   # 0 all, 1 half, 2 ten, 3 one
var _pick := {}  # {"grid": "c"/"b", "i": slot, "id": id} after a long press
var _press := {}  # the slot under the finger: {"grid", "i", "t"}
var _acts: HBoxContainer
var _trash_arm := ""
var _amt_btn: Button
var _trash_btn: Button
var _trash_icon: TextureRect
var _drag: SlotDrag
var _was_paused := false
var _arm := 0
var _cur: ScreenCursor  # C9 P3: pad/keyboard cursor (A = tap, CONFIRM_ALT = pick/place, TOOL = move amount)
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
	Hud.pause(get_tree(), "chest_screen")
	add_to_group("toast_hold")  # C9 P3: toasts wait while the chest covers the screen
	Music.instance(get_tree()).sfx("chest_open", "pickup")
	_root = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.11, 0.07, 1.0)  # opaque: no toolbar/buttons showing through
	sb.border_color = Color(0.85, 0.7, 0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(5)
	_root.add_theme_stylebox_override("panel", sb)
	Hud.skin_buttons(_root)  # wooden buttons, like the menu
	_root.position = Vector2(4, 30)  # below the clock
	_root.size = Vector2(262, 446)
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
	_top = _scroll_grid(v, 156)  # 5 rows: a 36-slot chest fits
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	v.add_child(row)
	row.add_child(_btn("Organise", func() -> void: Storage.sort_box(key); _pick = {}; _refresh()))
	row.add_child(_btn("Add to stacks", func() -> void: _note(Storage.quick_stack(key), "stacked")))
	row.add_child(_btn("Deposit all", func() -> void: _note(Storage.deposit_all(key), "stored")))
	row.add_child(_btn("Take all", func() -> void:
		var n := Storage.take_all(key)
		if n == 0 and not Storage.is_empty(key):
			_fail("Your bag is full.")
			_pick = {}
			_refresh()
		else:
			_note(n, "taken")
			if not Storage.is_empty(key) and m and m.hud:
				_say("Bag full: some stacks stay in the chest.")))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 2)
	v.add_child(row2)
	_btl = _label("", 9, Color(0.95, 0.9, 0.75))
	_btl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(_btl)
	_amt_btn = _btn("Move: all", func() -> void: _amt = (_amt + 1) % 4; _refresh())
	row2.add_child(_amt_btn)
	# C6 P7: the trash can (drop a bag item on it, or tap it with one picked).
	_trash_btn = Button.new()
	_trash_btn.custom_minimum_size = Vector2(24, 22)
	_trash_btn.focus_mode = Control.FOCUS_NONE
	_trash_btn.tooltip_text = "Trash"
	_trash_btn.pressed.connect(_trash_pressed)
	_trash_icon = TextureRect.new()
	_trash_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_trash_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_trash_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_trash_icon.offset_left = 3
	_trash_icon.offset_top = 2
	_trash_icon.offset_right = -3
	_trash_icon.offset_bottom = -2
	_trash_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trash_btn.add_child(_trash_icon)
	row2.add_child(_trash_btn)
	_drag = SlotDrag.new()
	add_child(_drag)
	_drag.on_lift = func(pl: Dictionary) -> void: _hold(str(pl["grid"]), int(pl["i"]))
	if key.begins_with("p:"):
		row2.add_child(_btn("Pick up", _pick_up))
	# C10a P3: decor never stacks in chests or the bag: it lives in the decor box.
	var dbx := _btn("Decor box", func() -> void: DecorCatalogue.open(self, "box"))
	dbx.set_meta("pc_key", "decor_box")
	row2.add_child(dbx)
	# Long-press an item: pick it up to place it, or lock / trash / move half.
	_acts = HBoxContainer.new()
	_acts.add_theme_constant_override("separation", 2)
	_acts.custom_minimum_size = Vector2(0, 22)  # the row appearing never moves the grids
	_bot = _scroll_grid(v, 158)  # keeps the panel and its tip line on the 480 screen
	(_bot.get_parent() as ScrollContainer).size_flags_vertical = Control.SIZE_EXPAND_FILL  # bag fills the panel, no dead band
	v.add_child(_acts)  # under the bag, so its empty band isn't between the label and the grid
	_tip = _label(_tip_text(), 7, TIP_COL)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_tip)
	_trash_btn.set_meta("pc_key", "trash")
	_cur = ScreenCursor.make(self, _root)
	_cur.on_alt = _pad_pick
	_cur.on_tool = func(_c: Control) -> void: _amt = (_amt + 1) % 4; _refresh()
	_refresh()
	_cur.select_key("b:0")


var _tip: Label
var _msg_t := 0.0
const TIP_COL := Color(0.8, 0.75, 0.65)
const MSG_SECS := 3.0  # a message in the tip line stays this long


func _tip_text() -> String:
	return TIP_TOUCH if TouchControls.visible_controls else TIP_PAD


## C9 P3: the chest's own feedback goes in its tip line (Hud toasts wait while
## the chest is open: they'd cover the grids).
func _say(t: String, col := Color(1, 0.9, 0.7)) -> void:
	if _tip == null:
		return
	_tip.text = t
	_tip.add_theme_color_override("font_color", col)
	_msg_t = MSG_SECS


const TIP_TOUCH := "Tap: move across.  Hold: pick up or drag (slot, other side, trash)."
const TIP_PAD := "A: move across.  X (Action): pick up, then put down on a slot or the trash."


## C9 P3: the pad's "pick up / put down" on the slot under the cursor.
func _pad_pick(c: Control) -> void:
	if c == null:
		return
	var k := _cur.key_of(c)
	if k == "trash":
		_trash_pressed()
		return
	var parts := k.split(":")
	if parts.size() != 2 or not (parts[0] in ["c", "b"]):
		return
	if _pick.is_empty():
		_hold(parts[0], int(parts[1]))
	else:
		_tap_now(parts[0], int(parts[1]), Callable())


func _scroll_grid(v: VBoxContainer, h: float) -> GridContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(250, h)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.scroll_deadzone = 8  # a shaky tap stays a tap; a real drag scrolls
	v.add_child(sc)
	var g := GridContainer.new()
	g.columns = 8
	g.add_theme_constant_override("h_separation", 1)
	g.add_theme_constant_override("v_separation", 1)
	sc.add_child(g)
	return g


func _process(_d: float) -> void:
	_arm += 1
	if _msg_t > 0.0:
		_msg_t -= _d
		if _msg_t <= 0.0 and _tip:
			_tip.text = _tip_text()
			_tip.add_theme_color_override("font_color", TIP_COL)
	# A finger that moves is scrolling, not holding.
	if not _press.is_empty() and get_viewport().get_mouse_position().distance_to(_press["at"]) > 6.0:
		_press = {}
	if not _press.is_empty() and Time.get_ticks_msec() - int(_press["t"]) > 450:
		var pr := _press
		_press = {}
		# The refresh frees the button under the finger, so its release never
		# arrives: swallow only a tap that comes within the next moment.
		_swallow_until = Time.get_ticks_msec() + 120
		_hold(str(pr["grid"]), int(pr["i"]))
	if _arm < 8:
		return
	for ch in get_children():
		if ch is DecorCatalogue:
			return  # the decor box screen on top owns B/MENU
	if Input.is_action_just_pressed("b") or Input.is_action_just_pressed("menu"):
		if not _pick.is_empty():
			_pick = {}
			_refresh()
		else:
			close()


func close() -> void:
	if not is_inside_tree():
		return
	get_tree().paused = _was_paused and Hud.keep_paused(get_tree(), self)
	Music.instance(get_tree()).sfx("chest_close", "menu_close")
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
	b.custom_minimum_size = Vector2(0, 22)  # finger-sized
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _full_msg(id: String) -> String:
	if str(GameState.items.get(id, {}).get("type", "")) in ["key", "quest"]:
		return "Keys and quest items stay in your bag."
	return "The chest is full."


func _fail(t: String) -> void:
	Music.instance(get_tree()).sfx("nope", "thud")
	_say(t)


func _note(n: int, verb: String) -> void:
	_pick = {}
	_trash_arm = ""
	Music.instance(get_tree()).sfx("pickup" if n > 0 else "nope", "thud")
	_say("%d stack%s %s." % [n, "" if n == 1 else "s", verb] if n > 0 else "Nothing to move.")
	_refresh()


func _n(have: int) -> int:
	match _amt:
		1:
			return int(ceil(have / 2.0))
		2:
			return mini(have, 10)
		3:
			return mini(have, 1)
	return have


var _swallow_until := 0


func _slot(id: String, count: int, cb: Callable, q: Dictionary = {}, grid := "", idx := -1) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(SLOT, SLOT)
	b.focus_mode = Control.FOCUS_NONE
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE  # a drag to scroll never moves an item
	b.mouse_filter = Control.MOUSE_FILTER_PASS  # a drag that starts on a slot scrolls the grid
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.17, 0.1) if id != "" else Color(0.19, 0.13, 0.08)
	var picked := not _pick.is_empty() and str(_pick["grid"]) == grid and int(_pick["i"]) == idx
	sb.border_color = Color(1, 0.85, 0.3) if picked else (DecorCatalogue.rarity_col(id).darkened(0.3) if id != "" else Color(0.1, 0.07, 0.04))
	sb.set_border_width_all(2 if picked else 1)
	sb.set_corner_radius_all(2)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	if grid != "" and _drag:
		# Long press lifts (SlotDrag): drop on a slot here or across, or the trash.
		_drag.add(b, {"grid": grid, "i": idx, "id": id} if id != "" else {}, _drop_on.bind(grid, idx), "%s:%d" % [grid, idx])
	b.pressed.connect(_tap.bind(grid, idx, cb))
	if grid != "":
		b.set_meta("pc_key", "%s:%d" % [grid, idx])
	if id != "":
		if grid == "b" and GameState.is_locked(id):
			var lk := _label("•", 9, Color(1, 0.85, 0.3))
			lk.position = Vector2(SLOT - 9, -2)
			lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(lk)
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
		_rarity_dots(b, id)
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


## Rarity said by count too, not colour alone (c9_07): one shared helper for every slot drawer
## (C10a P3: mythic 5 dots, unique a star; DecorCatalogue.rarity_dots).
func _rarity_dots(b: Control, id: String) -> void:
	DecorCatalogue.rarity_dots(b, id, SLOT)


func _refresh() -> void:
	if _drag:
		_drag.clear()
		_drag.add(_trash_btn, {}, _drop_trash, "trash")
	_trash_btn.modulate = Color(1, 0.55, 0.5) if _trash_arm != "" else Color.WHITE
	_trash_icon.texture = Art.tex("ui", "trash_can_open" if (_trash_arm != "" or str(_pick.get("grid", "")) == "b") else "trash_can")
	for g in [_top, _bot]:
		for c in (g as Node).get_children():
			c.queue_free()
	_ttl.text = "%s  %d/%d" % [head, Storage.slots_used(key), Storage.cap(key)]
	_amt_btn.text = ["Move: all", "Move: half", "Move: 10", "Move: 1"][_amt]
	var b := Storage.box(key)
	var cs := Storage.slots(key)
	var left := {}
	for i in cs.size():
		var id := str(cs[i])
		if id == "":
			_top.add_child(_slot("", 0, Callable(), {}, "c", i))
			continue
		if not left.has(id):
			left[id] = int(b["items"].get(id, 0))
		var stack := mini(int(left[id]), Storage.STACK)
		left[id] = int(left[id]) - stack
		_top.add_child(_slot(id, stack, _take.bind(id, stack), b["q"].get(id, {}), "c", i))
	_draw_acts()
	_btl.text = "Bag %d/%d" % [GameState.bag_used(), GameState.bag_size()] + ("  · %s" % _last if _last != "" else "")
	var bs := GameState.bag_slots()
	for i in bs.size():
		var id := str(bs[i])
		if id == "":
			_bot.add_child(_slot("", 0, Callable(), {}, "b", i))
		else:
			_bot.add_child(_slot(id, GameState.count(id), _put.bind(id), GameState.quality_of(id), "b", i))


var _last := ""


func _take(id: String, have := 0) -> void:
	_last = GameState.item_name(id)
	# One slot's stack (up to 999), not every stack of that item in the chest.
	if Storage.withdraw(key, id, _n(have if have > 0 else Storage.amount(key, id))) == 0:
		Music.instance(get_tree()).sfx("nope", "thud")
		_say("Your bag is full.")
	else:
		Music.instance(get_tree()).sfx("pickup")
	_refresh()


func _put(id: String) -> void:
	_last = GameState.item_name(id)
	if Storage.deposit(key, id, _n(GameState.count(id))) == 0:
		Music.instance(get_tree()).sfx("nope", "thud")
		_say(_full_msg(id))
	else:
		Music.instance(get_tree()).sfx("ui_tap", "pickup")
	_refresh()


func _pick_up() -> void:
	if not Storage.is_empty(key):
		_say("Empty the chest first.")
		return
	var xy := key.substr(2).split(",")
	var c := Vector2i(int(xy[0]), int(xy[1]))
	(GameState.run["chests"] as Dictionary).erase(key)
	close()
	if m and m.has_method("pickup_placed"):
		m.call("pickup_placed", c)


## A tap: place a picked item, else the slot's own action (quick move across).
func _tap(grid: String, i: int, cb: Callable) -> void:
	if Time.get_ticks_msec() < _swallow_until or (_drag and _drag.eat_tap()):
		return
	_tap_now(grid, i, cb)


## C6 P7: an item dragged from (grid, i) and let go over slot (grid2, i2).
func _drop_on(pl: Dictionary, grid2: String, i2: int) -> void:
	_pick = pl
	_tap_now(grid2, i2, Callable())


func _drop_trash(pl: Dictionary) -> void:
	_pick = pl
	_trash_pressed()


func _trash_pressed() -> void:
	if _drag and _drag.eat_tap() and _pick.is_empty():
		return
	if _pick.is_empty():
		_fail("Pick up an item from your bag (hold it, or drag it here) to trash it.")
		return
	var id := str(_pick["id"])
	if str(_pick["grid"]) != "b":
		_fail("Take it into your bag first to trash it.")
		_pick = {}
		_refresh()
		return
	if not GameState.can_trash(id):
		_fail("Locked: unlock it first." if GameState.is_locked(id) else "%s can't go in the trash." % GameState.item_name(id))
		_pick = {}
		_refresh()
		return
	if _trash_arm != id and GameState.trash_needs_confirm(id):
		_trash_arm = id
		_say("Throw away %d %s? Trash it again to confirm." % [GameState.count(id), GameState.item_name(id)], Color(1, 0.8, 0.6))
		_refresh()
		return
	GameState.trash(id, GameState.count(id))
	Music.instance(get_tree()).sfx("thud", "nope")
	_pick = {}
	_trash_arm = ""
	_refresh()


func _tap_now(grid: String, i: int, cb: Callable) -> void:
	if not _pick.is_empty():
		var pg := str(_pick["grid"])
		var pid := str(_pick["id"])
		if pg == grid:
			if grid == "b":
				GameState.bag_move(int(_pick["i"]), i)
			else:
				Storage.move_slot(key, int(_pick["i"]), i)
		elif pg == "b":
			# Into this chest slot: claim it for the stack, then move the lot across.
			var sl := Storage.slots(key)
			if i < sl.size() and str(sl[i]) == "":
				sl[i] = pid
			if Storage.deposit(key, pid, GameState.count(pid)) == 0:
				_fail(_full_msg(pid))
				_pick = {}
				_refresh()
				return
		else:
			var bs := GameState.bag_slots()
			if not GameState.run["inventory"].has(pid) and i < bs.size() and str(bs[i]) == "":
				bs[i] = pid
			if Storage.withdraw(key, pid, mini(Storage.amount(key, pid), Storage.STACK)) == 0:  # the picked slot's stack, like a tap
				_fail("Your bag is full.")
				_pick = {}
				_refresh()
				return
		Music.instance(get_tree()).sfx("ui_tap", "pickup")
		_pick = {}
		_refresh()
		return
	if cb.is_valid():
		cb.call()


## A long press: pick the item up and show what you can do with it.
func _hold(grid: String, i: int) -> void:
	var arr := GameState.bag_slots() if grid == "b" else Storage.slots(key)
	if i < 0 or i >= arr.size() or str(arr[i]) == "":
		return
	_pick = {"grid": grid, "i": i, "id": str(arr[i])}
	_trash_arm = ""
	_last = GameState.item_name(str(arr[i]))
	Music.instance(get_tree()).sfx("ui_tap", "pickup")
	_refresh()


func _draw_acts() -> void:
	for c in _acts.get_children():
		c.queue_free()
	if _pick.is_empty():
		return
	var id := str(_pick["id"])
	var in_bag := str(_pick["grid"]) == "b"
	_acts.add_child(_label("Place:", 7, Color(1, 0.85, 0.3)))
	_acts.add_child(_btn("Half →" if in_bag else "Half ←", func() -> void:
		if in_bag:
			if Storage.deposit(key, id, int(ceil(GameState.count(id) / 2.0))) == 0:
				_fail(_full_msg(id))
		else:
			if Storage.withdraw(key, id, int(ceil(Storage.amount(key, id) / 2.0))) == 0:
				_fail("Your bag is full.")
		_pick = {}
		_refresh()))
	if in_bag:
		_acts.add_child(_btn("Unlock" if GameState.is_locked(id) else "Lock", func() -> void:
			GameState.toggle_lock(id)
			_refresh()))
		if GameState.can_trash(id):
			var armed := _trash_arm == id
			var tb := _btn("Sure? Trash %d" % GameState.count(id) if armed else "Trash", func() -> void:
				if _trash_arm == id:
					GameState.trash(id, GameState.count(id))
					Music.instance(get_tree()).sfx("thud", "nope")
					_pick = {}
					_trash_arm = ""
				else:
					_trash_arm = id
				_refresh())
			if armed:
				tb.add_theme_color_override("font_color", Color(1, 0.45, 0.4))
			_acts.add_child(tb)
	_acts.add_child(_btn("✕", func() -> void:
		_pick = {}
		_refresh()))

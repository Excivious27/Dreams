class_name GameMenu
extends CanvasLayer
## The pause menu, laid out like Stardew's: tabs for Items, Skills, Social,
## Map, Quests and Options. Items shows the 12-slot toolbar plus the backpack;
## tap a backpack item to swap it into the selected toolbar slot.
## Pauses the game while open.

const TABS := ["Items", "Hero", "Skills", "Pup", "Party", "Social", "Map", "Quests", "Book", "Options"]
const SLOT := 34

var _panel: PanelContainer
var _body: VBoxContainer
var _tabs: HBoxContainer
var _open := false
var _tab := "Items"
var _skill_open := ""
var _tab_buttons := {}
const SkillGlow := preload("res://scripts/skill_glow.gd")
var _scroll_key := ""  # tab (and skill tree) last shown: a new one opens at the top


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.position = Vector2(6, 30)
	_panel.size = Vector2(258, 320)
	_panel.visible = false
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_panel.add_theme_stylebox_override("panel", Hud.panel_stylebox("panel_wood"))
	Hud.skin_buttons(_panel)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_panel.add_child(v)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 1)
	v.add_child(_tabs)
	for t: String in TABS:
		var b := Button.new()
		var tab_icon := "tab_" + t.to_lower()
		var tab_group := "ui"
		if t == "Party" and not Art.has("ui", tab_icon):
			tab_icon = "crew_badge_dice" if not GameState.is_penguins() else "icon_party_merry"  # no tab_party art yet
		if t == "Book" and not Art.has("ui", tab_icon):
			tab_icon = "medal_collector"  # Collections (C8 P3)
		if t == "Hero" and not Art.has("ui", tab_icon):
			tab_group = "items"  # no tab_hero art yet: a helmet
			tab_icon = Hud.icon_for("iron_helm")
		var has_icon := Art.has(tab_group, tab_icon)
		if has_icon:
			# A fixed icon box: wide banners and round faces sit at the same height,
			# so every tab name lines up underneath.
			var ir := TextureRect.new()
			ir.texture = Art.tex(tab_group, tab_icon)
			ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ir.set_anchors_preset(Control.PRESET_TOP_WIDE)
			ir.offset_top = 2
			ir.offset_bottom = 16
			ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(ir)
			b.tooltip_text = t
			# Phones never show tooltips: print the name under the icon.
			b.text = t
			b.add_theme_font_size_override("font_size", 7)
			b.custom_minimum_size = Vector2(0, 30)
			b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		else:
			b.text = t
			b.add_theme_font_size_override("font_size", 7)
			b.custom_minimum_size = Vector2(0, 18)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		b.pressed.connect(func() -> void: _switch_tab(t))
		_tabs.add_child(b)
		_tab_buttons[t] = b
		if has_icon:
			for st_name: String in ["normal", "hover", "pressed", "focus"]:
				var sbx: StyleBox = b.get_theme_stylebox(st_name)
				if sbx:
					sbx = sbx.duplicate()
					sbx.content_margin_top = 16
					sbx.content_margin_bottom = 1
					sbx.content_margin_left = 1  # nine tabs share 246 px
					sbx.content_margin_right = 1
					b.add_theme_stylebox_override(st_name, sbx)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 246)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 8  # a shaky tap stays a tap; a real drag scrolls
	v.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 3)
	scroll.add_child(_body)
	var close := Button.new()
	close.text = "Close" if DisplayServer.is_touchscreen_available() else "Close  (MENU / E)"
	close.add_theme_font_size_override("font_size", 8)
	close.custom_minimum_size = Vector2(0, 22)
	close.pressed.connect(toggle)
	v.add_child(close)


var _rebinding := ""


func _input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if _rebinding == "":
		# A finger or the mouse takes over: the pad/keyboard cursor hides (C9).
		if (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
			_hide_cursor()
		return
	if _tab == "Pad":
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
			var jb := event as InputEventJoypadButton
			var why := pad_rebind(_rebinding, int(jb.button_index))
			if why != "":
				_toast(why)
			_rebinding = ""
			get_viewport().set_input_as_handled()
			_refresh()
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var k := event as InputEventKey
		get_viewport().set_input_as_handled()
		if k.physical_keycode == KEY_ESCAPE:
			_rebinding = ""
			_steal_warn = {}
			_refresh()
			return
		# C9 c9_07: a key another action uses is not taken silently. The first
		# press names what would lose it; the same key again confirms.
		var other := key_owner(_rebinding, k.physical_keycode)
		if other != "" and _steal_warn.get("key", -1) != int(k.physical_keycode):
			_steal_warn = {"key": int(k.physical_keycode), "from": other}
			_refresh()
			return
		InputSetup.rebind(_rebinding, k.physical_keycode)
		_rebinding = ""
		_steal_warn = {}
		_refresh()


func _process(_delta: float) -> void:
	if Dialogue.instance(get_tree()).active:
		return
	if _rebinding != "":
		# Touch buttons press actions with no key event: B or MENU there cancels the rebind
		# (a real key press is caught by _input first and becomes the new binding).
		if Input.is_action_just_pressed("b") or Input.is_action_just_pressed("menu"):
			_rebinding = ""
			_refresh()
		return
	# Stardew hotkeys: E/Esc toggles the menu (Items tab when opening), M opens
	# straight to the Map, F to the Journal; pressing the same key again closes.
	if _open and _bag_pick != "" and (Input.is_action_just_pressed("menu") or Input.is_action_just_pressed("b")):
		_bag_pick = ""  # B / MENU first drops what you picked up
		_trash_arm = ""
		_refresh()
		return
	if _open and Input.is_action_just_pressed("b") and Engine.get_process_frames() - _opened_frame > 6 and Hud.modal_rect.size == Vector2.ZERO:
		if back_one():
			return  # a sub-page steps back first (C9 c9_02)
		toggle()  # B backs out of the menu too (phones: no hunting for the MENU key)
		return
	if _open and Hud.modal_rect.size != Vector2.ZERO:
		return  # a screen opened from the menu sits on top: MENU/B are its own (closing under it unpaused the game)
	if _open and _cursor_input(_delta):
		return
	if Input.is_action_just_pressed("menu"):
		if not _open:
			_tab = "Items"
		toggle()
		return
	for pair in [["map", "Map"], ["journal", "Quests"]]:
		if Input.is_action_just_pressed(str(pair[0])):
			if _open and _tab == str(pair[1]):
				toggle()
			elif _open:
				_tab = str(pair[1])
				_refresh()
			else:
				_tab = str(pair[1])
				toggle()


var _was_paused := false
var _opened_frame := 0
static var _book_run := ""


## A story beat is playing (its player is held). A beat that broke off and left
## the flag behind doesn't count, so the menu is never locked for good.
## Opens the menu on a tab (and a Book page) from gameplay code, e.g. the museum tray.
## Call it once the dialogue has closed (toggle refuses while paused or in a story beat).
static func open_page(tree: SceneTree, tab: String, page := "") -> void:
	if tree.current_scene == null:
		return
	for ch in tree.current_scene.get_children():
		if ch is GameMenu:
			var gm := ch as GameMenu
			gm._tab = tab
			if tab == "Book":
				CollectionScreen.open(page)
			if not gm._open:
				gm.toggle()
			else:
				gm._refresh()
			return


static func story_busy(tree: SceneTree) -> bool:
	if GameState.run.is_empty():
		return false
	if Story.is_playing() or Dialogue.instance(tree).skippable:
		return true  # a beat between its dialogue batches, or a skippable scene's fades (C7)
	if not GameState.run.has("story_pending"):
		return false
	var gm := tree.current_scene as GameMap
	return Dialogue.instance(tree).active or (gm != null and gm.player != null and gm.player.frozen)


func toggle() -> void:
	if not is_inside_tree():
		return  # mid scene change
	# Don't open over another paused screen (wardrobe, shop); closing then
	# would unpause the game under it.
	if not _open and get_tree().paused:
		return
	# Nor in the middle of a story beat (between its lines the tree runs).
	if not _open and story_busy(get_tree()):
		return
	# Nor during a map change: the fade's old map is freed with the menu, and the
	# new map would arrive paused with no owner (C9 c9_10).
	if not _open and changing_map(get_tree()):
		return
	_open = not _open
	_rebinding = ""
	_panel.visible = _open
	Music.instance(get_tree()).sfx("menu_open" if _open else "menu_close")
	if _open:
		var rk := "%s|%s|%s" % [GameState.save_key(), str(GameState.run.get("arc", "")), str(GameState.run.get("hero", ""))]
		if rk != _book_run:
			_book_run = rk
			CollectionScreen.reset()  # C10a P3: another slot/arc opens the Book on its hub
		_opened_frame = Engine.get_process_frames()
		_bag_pick = ""
		_pick_bar = -1
		_trash_arm = ""
		_reset_arm = ""
		_was_paused = get_tree().paused
		Hud.pause(get_tree(), "GameMenu")
		# Toasts still on screen would sit over the tab rows: clear them (new ones still show).
		var gm0 := get_tree().current_scene as GameMap
		if gm0 and gm0.hud and gm0.hud._toasts:
			for c in gm0.hud._toasts.get_children():
				c.queue_free()
		_refresh()
	else:
		# Only back to a pause something still needs (C4 P6); the menu's last press is done.
		get_tree().paused = _was_paused and (Hud.keep_paused(get_tree(), self) or Hud.modal_rect.size != Vector2.ZERO)
		last_press = ""
		Dialogue.block_input()


func _line(text: String, size := 9, color := Color(1, 0.96, 0.85)) -> Label:
	var l := Label.new()
	l.text = PadInput.words(text)  # S1 s1_08-06: no touch words on a pad
	l.add_theme_font_size_override("font_size", Settings.font(size))  # Options > Text size (C9)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(l)
	return l


## The last menu button pressed (Hud names it when a pause is left with no owner).
static var last_press := ""


static func _has_static(sc: Script, fn: String) -> bool:
	for md in sc.get_script_method_list():
		if str(md.get("name", "")) == fn:
			return true
	return false


var _centre_rows := false  # Options rows are centred like the shared sound rows


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.pressed.connect(func() -> void: last_press = "%s > %s" % [_tab, text])
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER if _centre_rows else HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", Settings.font(9))
	# Release mode: a finger that lands on a button to scroll the list must not
	# fire it (press mode fired "Save & back to title" when you scrolled Options).
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	b.pressed.connect(func() -> void: Music.instance(get_tree()).sfx("ui_tap"))
	# A greyed-out row answers a tap with a soft refusal instead of silence.
	b.gui_input.connect(func(ev: InputEvent) -> void:
		if b.disabled and TapInput.is_release(ev):
			Music.instance(get_tree()).sfx("nope", "thud"))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 22)  # finger-sized rows (18 was under 5 mm on a phone)
	b.pressed.connect(cb)
	_body.add_child(b)
	return b


func _slot_button(id: String, selected: bool, cb: Callable) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(SLOT, SLOT)
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE  # scrolling the tab never picks or places
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: last_press = "%s > slot %s" % [_tab, id])
	b.pressed.connect(cb)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.42, 0.2) if selected else Color(0.25, 0.17, 0.1)
	sb.border_color = Color(1, 0.9, 0.5) if selected else Color(0.1, 0.07, 0.04)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	if id != "":
		var icon := Art.tex("items", Hud.icon_for(id))
		if icon:
			var tr := TextureRect.new()
			tr.texture = icon
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
		DecorCatalogue.rarity_dots(b, id, SLOT)  # C10a P3: the Items tab shows rarity like chests (c10_07)
		if DecorCatalogue.rarity_of(id) != "common":
			sb.border_color = Color(1, 0.9, 0.5) if selected else DecorCatalogue.rarity_col(id).darkened(0.3)
		if GameState.run["inventory"].has(id):
			var n := Label.new()
			n.text = str(int(GameState.run["inventory"][id]))
			n.add_theme_font_size_override("font_size", 7)
			n.add_theme_constant_override("outline_size", 2)
			n.add_theme_color_override("font_outline_color", Color.BLACK)
			n.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			n.offset_left = -22
			n.offset_top = -11
			n.offset_right = -2
			n.offset_bottom = -1
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(n)
			var q := GameState.quality_of(id)
			if int(q.get("g", 0)) + int(q.get("s", 0)) > 0:
				var st := Label.new()
				st.text = "★" if int(q.get("g", 0)) > 0 else "☆"
				st.add_theme_font_size_override("font_size", 8)
				st.add_theme_color_override("font_color", Color(1, 0.85, 0.3) if int(q.get("g", 0)) > 0 else Color(0.85, 0.9, 1.0))
				st.add_theme_constant_override("outline_size", 2)
				st.add_theme_color_override("font_outline_color", Color.BLACK)
				st.position = Vector2(3, 1)
				st.mouse_filter = Control.MOUSE_FILTER_IGNORE
				b.add_child(st)
	return b


func _stack_nearby() -> void:
	var here := get_tree().current_scene as GameMap
	if here == null:
		return
	var res := Storage.quick_stack_nearby(here)
	if here.hud:
		here.hud.toast("Stacked %d item%s into %d chest%s." % [res[0], "" if int(res[0]) == 1 else "s", res[1], "" if int(res[1]) == 1 else "s"] if int(res[0]) > 0 else "Nothing here matches what the chests hold.")
	_refresh()


func _grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 2)
	g.add_theme_constant_override("v_separation", 2)
	_body.add_child(g)
	return g


func _refresh() -> void:
	if not is_inside_tree():
		return
	_centre_rows = false
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var skey := _tab + ("|" + _skill_open if _tab == "Skills" else "")
	if skey != _scroll_key:
		_scroll_key = skey
		var sc0 := _body.get_parent() as ScrollContainer
		if sc0:
			sc0.scroll_vertical = 0
	# Long rows used to stretch the panel off the right edge; pin it.
	_panel.size = Vector2(258, 320)
	_panel.call_deferred("set_size", Vector2(258, 320))
	for t in _tab_buttons:
		(_tab_buttons[t] as Button).modulate = Color(1, 0.9, 0.5) if t == _tab or (t == "Options" and _tab == "Keys") or (t == "Quests" and _tab in ["FieldLog", "Workshop", "Foes", "Messages", "Mail"]) or (t == "Party" and _tab in ["Animals", "Chores"]) else Color(0.85, 0.85, 0.85)
	if _tab_buttons.has("Skills"):
		SkillGlow.set_glow(_tab_buttons["Skills"] as Control, SkillGlow.total_free())
	if _tab_buttons.has("Book"):
		SkillGlow.set_glow(_tab_buttons["Book"] as Control, Collections.new_count() + DecorCatalogue.new_count())  # new log entries + new decor kinds
	var r := GameState.run
	match _tab:
		"Book":
			CollectionScreen.build(self)
		"Items":
			BattleDrill.menu_row(self)  # C11b P7: the training drill's way out on a pad/keys
			var slot := int(r["slot"])
			var tb: Array = r["toolbar"]
			var sel := str(tb[slot])
			if _bag_pick != "" and GameState.count(_bag_pick) <= 0 and int(r["inventory"].get(_bag_pick, 0)) <= 0 and not GameState.has_tool(_bag_pick):
				_bag_pick = ""
			_line(("Picked: %s  (tap a slot to place it)" % GameState.item_name(_bag_pick)) if _bag_pick != "" else ("Toolbar  ·  in hand: %s  (tap it again, then a slot, to move it)" % GameState.item_name(sel) if sel != "" else "In hand: nothing"), 9, Color(1, 0.85, 0.4) if _bag_pick != "" else Color(1, 0.96, 0.85))
			var dr := _items_drag()
			var g := _grid(6)
			for i in 12:
				var id := str(tb[i])
				var tsb := _slot_button(id, i == slot, _toolbar_tap.bind(i))
				dr.add(tsb, {"id": id, "bar": i} if id != "" else {}, _drop_on_bar.bind(i), "bar:%d" % i)
				g.add_child(tsb)
			var bh := HBoxContainer.new()
			bh.add_theme_constant_override("separation", 3)
			_body.add_child(bh)
			var bl := _line("Bag %d/%d" % [GameState.bag_used(), GameState.bag_size()], 8, Color(1, 0.6, 0.5) if GameState.bag_free() <= 0 else Color(0.9, 0.85, 0.7))
			bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bl.reparent(bh)
			var sb1 := _button("Organise", func() -> void: GameState.sort_bag(); _refresh())
			sb1.reparent(bh)
			sb1.size_flags_horizontal = Control.SIZE_SHRINK_END
			sb1.autowrap_mode = TextServer.AUTOWRAP_OFF
			var here := get_tree().current_scene as GameMap
			if here and not Storage.nearby(here).is_empty():
				var sb2 := _button("Stack to chests", _stack_nearby)
				sb2.reparent(bh)
				sb2.size_flags_horizontal = Control.SIZE_SHRINK_END
				sb2.autowrap_mode = TextServer.AUTOWRAP_OFF
			var trs := _trash_slot()
			bh.add_child(trs)
			dr.add(trs, {}, _drop_trash, "trash")
			_line("Bag: tap one, then a slot. Hold and drag to move or trash.", 8, Color(0.9, 0.85, 0.7))
			var bs := GameState.bag_slots()
			var g2 := _grid(6)
			for i in bs.size():
				var bid := str(bs[i])
				var bb := _slot_button(bid, bid != "" and bid == _bag_pick, _bag_tap.bind(i))
				dr.add(bb, {"id": bid, "bar": -1} if bid != "" else {}, _drop_on_bag.bind(i), "bag:%d" % i)
				if bid != "" and bid != _bag_pick and tb.has(bid):
					bb.modulate = Color(1, 1, 1, 0.55)  # also on the toolbar above
				if bid != "" and GameState.is_locked(bid):
					var lk := Label.new()
					lk.text = "•"
					lk.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
					lk.position = Vector2(SLOT - 8, -3)
					lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
					bb.add_child(lk)
				g2.add_child(bb)
			var lt := GameState.loose_tools()
			if not lt.is_empty():
				_line("Tools", 8, Color(0.9, 0.85, 0.7))
				var g3 := _grid(6)
				for t: String in lt:
					var tlb := _slot_button(t, t == _bag_pick, _tool_tap.bind(t))
					dr.add(tlb, {"id": t, "bar": -1}, func(_p: Dictionary) -> void: pass, "tool:" + t)
					g3.add_child(tlb)
			# C10a P3: decor and wearables never stack in the bag; they live in the decor box.
			var dbn := DecorCatalogue._box_total()
			var dbb := _button("Decor box: %d piece%s ›" % [dbn, "" if dbn == 1 else "s"] if dbn > 0 else "Decor box & catalogue ›", func() -> void: CollectionScreen.open_catalogue(self, "box"))
			dbb.set_meta("pc_key", "items:decor_box")
			if _bag_pick != "" and not GameState.has_tool(_bag_pick):
				var ah := HBoxContainer.new()
				ah.add_theme_constant_override("separation", 3)
				_body.add_child(ah)
				var p := _bag_pick
				for pair in [["To hand", func() -> void: _assign_toolbar(p, int(GameState.run["slot"]))],
						[("Unlock" if GameState.is_locked(p) else "Lock"), func() -> void: GameState.toggle_lock(p); _refresh()],
						[("Sure? Trash %d" % GameState.count(p)) if _trash_arm == p else "Trash", func() -> void: _trash_tap(p)],
						["✕", func() -> void: _bag_pick = ""; _trash_arm = ""; _refresh()]]:
					if str(pair[0]).begins_with("Trash") or str(pair[0]).begins_with("Sure"):
						if not GameState.can_trash(p):
							continue
					var ab := _button(str(pair[0]), pair[1])
					ab.reparent(ah)
					ab.autowrap_mode = TextServer.AUTOWRAP_OFF
				sel = p
			if sel != "":
				var itd: Dictionary = GameState.items.get(sel, {})
				var rar := str(itd.get("rarity", "common"))
				var worth := ("◆%d" % GameState.item_value(sel)) if GameState.item_value(sel) > 0 else "keepsake"
				_line("%s  ·  %s  ·  tier %d  ·  %s" % [GameState.item_name(sel), rar, int(itd.get("tier", 1)), worth], 8, DecorCatalogue.rarity_col(sel))
				if Collections.museum_needs(sel):
					_line("Museum wants this: donate it before selling.", 8, Color(1, 0.85, 0.5))
				if Decor.is_decor(sel) and int(GameState.run["inventory"].get(sel, 0)) > 0 and not GameState.visiting():
					# C10a P3: a decor piece still in the bag (old saves) moves to the decor box.
					var dsel := sel
					_button("Put in the decor box ›", func() -> void:
						var before := Decor.owned(dsel)
						var inv: Dictionary = GameState.run["inventory"]
						Decor.give(dsel, int(inv.get(dsel, 0)), "bag")
						var took := Decor.owned(dsel) - before  # a unique already held is refused: it stays in the bag
						if took <= 0:
							_toast("You already have this one-of-a-kind piece.")
							return
						inv[dsel] = int(inv.get(dsel, 0)) - took  # raw bag (add_item routes decor to the box)
						if int(inv[dsel]) <= 0:
							inv.erase(dsel)
						_bag_pick = ""
						_toast("%s is in your decor box now." % DecorCatalogue.name_of(dsel))
						_refresh())
				if itd.has("desc"):
					_line(str(itd["desc"]), 8, Color(0.8, 0.8, 0.8))
				if itd.has("heal") or itd.has("energy") or itd.has("mana") or itd.has("grow"):
					var what := "Drink" if str(itd.get("type", "")) == "tonic" else "Eat"
					_button("%s %s" % [what, GameState.item_name(sel)], func() -> void: _eat(sel))
				if str(itd.get("type", "")) == "equip":
					var st: Dictionary = itd.get("stats", {})
					_line("  " + ", ".join(st.keys().map(func(k: String) -> String: return "%s +%d" % [k, int(st[k])])), 8, Color(0.8, 0.9, 1.0))
					_button("Equip (%s)" % str(itd.get("slot", "")), func() -> void: GameState.equip(sel); _refresh_player(); _refresh())
			_button("Character, stats & gear ›", func() -> void: _tab = "Hero"; _refresh())
			_line("Wearing", 8, Color(0.9, 0.85, 0.7))
			for eslot: String in GameState.SLOTS:
				var eid := GameState.equipped(eslot)
				if eid != "":
					_button("  %s: %s  (take off)" % [eslot, GameState.item_name(eid)], func() -> void: GameState.unequip(eslot); _refresh())
			if GameState.SLOTS.all(func(s2: String) -> bool: return GameState.equipped(s2) == ""):
				_line("  nothing yet: armour, rings and charms go here.", 8, Color(0.6, 0.6, 0.6))
			var gs := "def %d  spd %d  luck %d  dmg %d  energy +%d" % [GameState.gear_stat("defense"), GameState.gear_stat("speed"), GameState.gear_stat("luck"), GameState.gear_stat("damage"), GameState.gear_stat("energy")]
			_line("  " + gs, 8, Color(0.8, 0.9, 1.0))
			_line("Tools: " + ", ".join(r["tools"].map(func(t: String) -> String: return GameState.item_name(t))), 8, Color(0.8, 0.8, 0.8))
		"Hero":
			CharSheet.build(self, _body)
		"Skills":
			_skills_tab()
		"Pup":
			_pup_tab()
		"Animals":
			TeamAnimals.build_page(self)  # C11a P4: roster, hearts, lessons, rename, rehome, team toggle
		"Chores":
			Chores.build_page(self)  # C11a P4: overnight farm chores for the pup, team animals, crew, partners
		"Party":
			var pt := Companion.party()
			var act := Companion.active_id()
			var anb := _button("Animals: %d on the ranch, %d on the team ›" % [Ranch.animals().size(), TeamAnimals.team().size()], func() -> void: _tab = "Animals"; _refresh())
			anb.set_meta("pc_key", "party:animals")
			var chb := _button("Chores: %d helper%s working ›" % [Chores.st()["assign"].size(), "" if Chores.st()["assign"].size() == 1 else "s"] if Chores.unlocked() else "Chores (after your first week) ›", func() -> void: _tab = "Chores"; _refresh())
			chb.set_meta("pc_key", "party:chores")
			if not GameState.is_penguins():
				_crew_tab()
			_line("Party", 10, Color(1, 0.95, 0.8))
			if (pt["known"] as Array).is_empty():
				_line("  Nobody yet. Partners find you as the story goes; some wait at the farm gate.", 8, Color(0.7, 0.7, 0.7))
			for cid in pt["known"]:
				var cd: Dictionary = Companion.defs().get(cid, {})
				var card := "party_card_" + str(cd.get("sprite", cid)) + ("_sel" if cid == act else "")
				var pick := func() -> void:
					pt["active"] = "" if act == cid else cid
					var m := get_tree().current_scene
					if m is GameMap and (m as GameMap).has_method("_refresh_party"):
						(m as GameMap).call("_refresh_party")
					elif m is GameMap:
						toggle()
						GameMap.next_spawn = (m as GameMap).player.position - (m as GameMap).offset()
						get_tree().reload_current_scene()
						return
					_refresh()
				if Art.has("ui", card):
					# Prompts-12C partner card: the card is the button; name and ability beside it.
					var h := HBoxContainer.new()
					h.add_theme_constant_override("separation", 4)
					_body.add_child(h)
					var tb := TextureButton.new()
					tb.texture_normal = Art.tex("ui", card)
					tb.ignore_texture_size = true
					tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
					tb.custom_minimum_size = Vector2(104, 34)
					tb.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
					tb.pressed.connect(func() -> void: last_press = "%s > card" % _tab)
					tb.pressed.connect(pick)
					h.add_child(tb)
					var plate := Label.new()  # the name on the card's plate (c11b_08-08)
					plate.text = str(cd.get("name", cid))
					plate.add_theme_font_size_override("font_size", 7)
					plate.add_theme_color_override("font_outline_color", Color(0, 0, 0))
					plate.add_theme_constant_override("outline_size", 2)
					plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					plate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
					plate.set_anchors_preset(Control.PRESET_FULL_RECT)
					plate.anchor_top = 0.62
					tb.add_child(plate)
					var col := VBoxContainer.new()
					col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					h.add_child(col)
					var nm := Label.new()
					nm.text = ("▶ Bringing along" if cid == act else "Staying home") + " · " + Companion.ability_name(cid)
					nm.add_theme_font_size_override("font_size", 8)
					col.add_child(nm)
					var ab := Label.new()
					ab.text = Companion.ability_desc(cid)
					ab.add_theme_font_size_override("font_size", 7)
					ab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					ab.modulate = Color(0.85, 0.85, 0.8)
					col.add_child(ab)
					continue
				var b := _button("%s %s — %s: %s" % ["▶" if cid == act else "  ", str(cd.get("name", cid)), Companion.ability_name(cid), Companion.ability_desc(cid)], pick)
				b.add_theme_font_size_override("font_size", 7)
			if act != "":
				_line("  %s: use the active partner's ability." % InputSetup.prompt("ability"), 8, Color(0.8, 0.8, 0.8))
			if not (pt["known"] as Array).is_empty():
				_line("  Tap a partner to bring them along; tap them again to leave them home.", 7, Color(0.75, 0.75, 0.75))
			if not (pt["bitter"] as Array).is_empty():
				_line("Bitter", 9, Color(1, 0.7, 0.7))
				for cid in pt["bitter"]:
					_line("  %s hasn't been seen since you turned them away." % str(Companion.defs().get(cid, {}).get("name", cid)), 8, Color(0.9, 0.7, 0.7))
		"Social":
			var fr: Dictionary = r["friendship"]
			var full := Art.tex("ui", "pheart_full") if Art.has("ui", "pheart_full") else Art.tex("ui", "heart_full")
			var empty := Art.tex("ui", "pheart_empty") if Art.has("ui", "pheart_empty") else Art.tex("ui", "heart_empty")
			var hearts_def: Dictionary = GameState.load_json("res://data/hearts.json").get("villagers", {})
			for id in GameState.npcs:
				var d: Dictionary = GameState.npcs[id]
				# Only people you can actually befriend in this arc (a heart arc with "arc" belongs to that arc only).
				if (not hearts_def.has(str(id)) and not Crew.members().has(str(id)) and not Perks.data().has(str(id))) or str((hearts_def.get(str(id), {}) as Dictionary).get("arc", "")) not in ["", str(GameState.run.get("arc", ""))]:
					continue
				var pts := int(fr.get(id, 0))
				var h := HBoxContainer.new()
				_body.add_child(h)
				var ppid := Dialogue.portrait_for(str(d.get("name", id)))
				var pt := Dialogue.one_face(Art.tex("portraits/" + (ppid if ppid != "" else str(d.get("portrait", id))), "neutral"))  # no twin faces
				if pt:
					var tr := TextureRect.new()
					tr.texture = pt
					tr.custom_minimum_size = Vector2(22, 22)
					tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					h.add_child(tr)
				var l := Label.new()
				l.text = "%s\n%s" % [d["name"], d["role"]]
				l.add_theme_font_size_override("font_size", 8)
				l.custom_minimum_size = Vector2(70, 0)
				h.add_child(l)
				var hearts := HBoxContainer.new()
				hearts.add_theme_constant_override("separation", 0)
				hearts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				h.add_child(hearts)
				for i in 10:
					var tr := TextureRect.new()
					tr.custom_minimum_size = Vector2(11, 11)
					tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					tr.texture = full if i < pts / 25 else empty
					hearts.add_child(tr)
				var pl := Label.new()
				pl.text = " %d" % pts
				pl.add_theme_font_size_override("font_size", 7)
				h.add_child(pl)
				# Birthday, what you've learned they love, and the next heart perk.
				var bd := GameState.birthday_of(str(id))
				var seen: Dictionary = (r.get("gift_seen", {}) as Dictionary).get(id, {})
				var loves: Array = []
				var likes: Array = []
				var hates: Array = []
				for gi: String in seen:
					if int(seen[gi]) >= 20:
						loves.append(GameState.item_name(gi))
					elif int(seen[gi]) >= 12:
						likes.append(GameState.item_name(gi))
					elif int(seen[gi]) < 0:
						hates.append(GameState.item_name(gi))
				var nxt := ""
				for hh in [2, 4, 6, 8, 10]:
					if GameState.friend_hearts(str(id)) < hh and GameState.friend_perk_at(str(id), hh) != "":
						nxt = "♥%d: %s" % [hh, Money.t(GameState.friend_perk_at(str(id), hh))]
						break
				# C12 P4: no "Birthday ? 0" for crew; loves (20+) and likes (12-19) apart.
				var bd_txt := ("Birthday %s %d%s · " % [str(bd[0]).capitalize(), int(bd[1]), " (TODAY!)" if GameState.is_birthday(str(id)) else ""]) if bd.size() == 2 else ""
				var info := "   %sloves: %s%s%s%s" % [bd_txt, ", ".join(loves) if not loves.is_empty() else ("? (give gifts to find out)" if likes.is_empty() else "?"), ("  · likes: " + ", ".join(likes)) if not likes.is_empty() else "", ("  · dislikes: " + ", ".join(hates)) if not hates.is_empty() else "", ("\n   next " + nxt) if nxt != "" else ""]
				# A heart scene waiting, and (after ♥10) what they'd do for you (C7 P4).
				info += ("\n   ♥%d scene waiting: go and talk to them" % Hearts.due(str(id))) if Hearts.due(str(id)) > 0 else ("\n   If the town fell: " + str(Hearts.data()[str(id)].get("fall", ""))) if Hearts.seen_level(str(id)) >= 10 and str(Hearts.data().get(str(id), {}).get("fall", "")) != "" else ""
				_line(info, 8, Color(1, 0.9, 0.55) if GameState.is_birthday(str(id)) or Hearts.due(str(id)) > 0 else Color(0.8, 0.8, 0.75))
				if Romance.social_line(str(id)) != "": _line(Romance.social_line(str(id)), 8, Color(1, 0.7, 0.85))
		"Map":
			# Mega region tabs (MegaMap): Valley + one per unlocked region; hidden until unlocked.
			# The map sits right under the tab strip; the Campaign button and blurb go below it (c4_02).
			MegaRegion.check_unlocks()
			var mtab := MegaMap.tab_row(_body, _refresh)
			if mtab != "valley":
				_body.add_child(MegaMap.make_map(mtab, _refresh))
				if MegaMap.sel != "":
					var last_l: Label = null
					for cl: Array in MegaMap.pin_card(mtab, MegaMap.sel):
						last_l = _line(str(cl[0]), int(cl[1]), cl[2])
					# Scroll the card into view under the map (a tap that changes nothing looks broken).
					var scr := _body.get_parent() as ScrollContainer
					if last_l and scr:
						(func() -> void:
							await get_tree().process_frame
							if is_instance_valid(scr) and is_instance_valid(last_l):
								scr.ensure_control_visible(last_l)).call()
				else:
					_line("Tap a place on the map for its card.", 8, Color(0.75, 0.75, 0.7))
				_line(MegaMap.where_line(), 8)
				_line(str(MegaRegion.get_r(mtab).get("blurb", "")), 8, Color(0.85, 0.85, 0.8))
			else:
				var m := Control.new()
				m.custom_minimum_size = Vector2(228, 246 if Art.has("ui", "world_map") else 190)
				m.mouse_filter = Control.MOUSE_FILTER_PASS
				m.draw.connect(func() -> void: _draw_map(m))
				_body.add_child(m)
				_line(MegaMap.where_line(), 8)
			# Region campaigns: the board that opens new regions (locked pins show a padlock).
			var ready_c := 0
			for cid: String in Campaign.for_arc():
				if not Campaign.is_won(cid) and Campaign.why_locked(cid) == "":
					ready_c += 1
			var ctag := (" (%d ready)" % ready_c) if ready_c > 0 else ""
			var c_locked := not CampaignGate.story_ok()
			if c_locked:
				ctag = " (locked)"
			elif not CampaignGate.trained():
				ctag = " (training ready)"
			if not (c_locked and mtab != "valley"):  # no "locked" button on a region tab
				_button("Campaign map%s" % ctag, func() -> void:
					var gm := get_tree().current_scene as GameMap
					if gm == null or gm.scene_id().begins_with("bf_"):
						return
					toggle()  # close the menu (unpauses), then the board pauses again
					CampaignScreen.open(gm))
		"Quests":
			if r["quests"].is_empty():
				_line("No quests yet.")
			# The same next step the HUD goal line shows, so the two never disagree.
			var now := GameState.next_step()
			if now != "":
				_line("▸ Now: " + now, 9, Color(1, 0.92, 0.6))
			# The quest tracker (QuestTracker): tick the quest the corner compass follows.
			var trk: String = QuestTracker.tracked()
			_line("Tick a quest: the compass by the clock points the way.", 8, Color(0.85, 0.85, 0.8))
			_line("Story", 9, Color(1, 0.9, 0.5))
			var any := false
			# One radio row for the story (c4_18 #4: a tick on every story line read as several choices).
			_body.add_child(QuestTracker.checkbox_row("Follow the story", trk == "", false, "", func() -> void:
				r["pinned_quest"] = ""
				_refresh()))
			for oq: Dictionary in QuestTracker.open_quests():
				if oq["main"] or str(oq["giver"]) == "":
					var gq := str(oq["id"])
					if not oq["main"] and not QuestTracker.job_place(gq).is_empty():
						# C7: a giverless job with a place (Rec Center, community farm, colony, grotto) can be followed.
						_body.add_child(QuestTracker.checkbox_row(str(oq["text"]), trk == gq, false, QuestTracker.progress(gq), func() -> void:
							QuestTracker.track(gq)
							_refresh()))
					else:
						_line("   • " + str(oq["text"]), 8, Color(0.92, 0.88, 0.75))
			_line("Townsfolk", 9, Color(0.7, 0.9, 1.0))
			for oq: Dictionary in QuestTracker.open_quests():
				if not (oq["main"] or str(oq["giver"]) == ""):
					any = true
					var qid := str(oq["id"])
					var who := str(GameState.npcs.get(str(oq["giver"]), {}).get("name", ""))
					var sub := "ready" if bool(oq["ready"]) else QuestTracker.progress(qid)
					var at := QuestTracker.npc_scene(str(oq["giver"]))  # C7: where an out-of-town giver lives
					if at != "":
						sub = PlaceNames.for_id(at) + ("" if sub == "" else " · " + sub)
					_body.add_child(QuestTracker.checkbox_row(("%s: " % who if who != "" and not str(oq["text"]).begins_with(who) else "") + str(oq["text"]), trk == qid, false, sub, func() -> void:
						QuestTracker.track(qid)
						_refresh()))
			if not any:
				_line("  Talk to people in town; they'll ask for help. The plaza board has daily jobs.", 8, Color(0.7, 0.7, 0.7))
			var fin: Array = r["quests"].filter(func(q: Dictionary) -> bool: return bool(q["done"]))
			if not fin.is_empty():
				_line("Finished (%d)" % fin.size(), 9, Color(0.7, 0.9, 0.7))
				for q: Dictionary in fin.slice(maxi(0, fin.size() - 8)):
					_line("✓ " + str(q["text"]), 8, Color(0.7, 0.9, 0.7))
			var ws := Crafting.summary()
			var busy := 0
			for w in ws:
				busy += (w["jobs"] as Array).size()
			_button("Workshop: %d station%s, %d job%s running ›" % [ws.size(), "" if ws.size() == 1 else "s", busy, "" if busy == 1 else "s"], func() -> void: _tab = "Workshop"; _refresh())
			_button("Field log: %d of %d crops grown ›" % [(r.get("grown", {}) as Dictionary).size(), GameState.crops.size()], func() -> void: _tab = "FieldLog"; _refresh())
			_button("Foes & Gifts: %s met ›" % ItemWords.count("kind", (r.get("kill_counts", {}) as Dictionary).size()), func() -> void: _tab = "Foes"; _refresh())
			_button("Mail: %d unread ›" % Mail.unread(), func() -> void: _tab = "Mail"; _refresh())
			_button("Recent messages ›", func() -> void: _tab = "Messages"; _refresh())
			var hints: Array = r.get("hints", [])
			if not hints.is_empty():
				_line("Things people said (newest first)", 9, Color(0.95, 0.85, 1.0))
				var hs := hints.duplicate()
				hs.reverse()
				for hnt in hs.slice(0, 12):
					_line("  ✎ " + str(hnt), 8, Color(0.9, 0.85, 0.95))
		"Options":
			_centre_rows = true
			var arc_title: String = GameState.arcs.get(r["arc"], {}).get("title", "")
			_line("%s of %s · Pet: %s\n%s\nDay %d" % [r["names"]["character"], r["names"]["town"], r["names"]["pet"], arc_title, int(r["day"])])
			# Grouped (C9 c9_07): Sound, Display and controls, This farm, then the way out.
			Settings.header(_body, "Sound")
			Settings.audio_rows(_body, get_tree(), _refresh)
			Settings.header(_body, "Display and controls")
			Settings.general_rows(_body, get_tree(), _refresh)
			if not DisplayMode.is_phone():
				Settings.row_button(_body, get_tree(), "Key bindings…", func() -> void: _tab = "Keys"; _refresh())
			Settings.row_button(_body, get_tree(), "Controller buttons…", func() -> void: _tab = "Pad"; _refresh())
			Settings.header(_body, "This farm")
			Difficulty.settings_rows(self)  # C4: difficulty + day length (this save slot)
			_backup_row()
			if r["flags"].has("epilogue_done"):
				_button("Replay the ending", func() -> void:
					toggle()
					var mp := get_tree().current_scene as GameMap
					if mp:
						Epilogue.play(mp))
			if quit_offered():
				_button("Save and quit", func() -> void:
					_save_now()
					get_tree().paused = false
					get_tree().quit())
			_button("Save & back to title", func() -> void:
				_save_now()
				get_tree().paused = false
				get_tree().change_scene_to_file("res://scenes/title.tscn"))
			_line(help_text(), 8, Color(0.8, 0.8, 0.8))
		"Workshop":
			var ws2 := Crafting.summary()
			_line("Workshop · %d pieces made so far" % int(r.get("made", 0)), 9, Color(1, 0.9, 0.6))
			if Racket.on():
				_line("Heat %d/5 · %d bill%s passed%s" % [Racket.heat(), int(r.get("passed", 0)), "" if int(r.get("passed", 0)) == 1 else "s", " · collectors are looking" if Racket.heat() >= 3 else ""], 8, Color(1, 0.6, 0.45) if Racket.heat() >= 3 else Color(0.9, 0.85, 0.7))
			if Sanctuary.on():
				var waiting := 0
				for gk in (r.get("gifts", {}) as Dictionary):
					for gi in r["gifts"][gk]:
						waiting += int(r["gifts"][gk][gi])
				if Builds.is_built("pool") or Builds.is_built("burrow") or Builds.is_built("shrine"):
					_line("Sanctuary · %d gift%s waiting · Meow Pow Wow +%d rank%s from the shrine" % [waiting, "" if waiting == 1 else "s", Sanctuary.meow_bonus(), "" if Sanctuary.meow_bonus() == 1 else "s"], 8, Color(0.8, 0.95, 1.0))
			if ws2.is_empty():
				_line("No stations yet. The Plans board by your house lists every station: build each from materials or buy it ready-made.", 8, Color(0.8, 0.8, 0.8))
			for w in ws2:
				_line(str(w["head"]), 8, Color(1, 0.96, 0.85))
				for jl in w["jobs"]:
					_line("   ◷ " + str(jl), 8, Color(0.75, 0.95, 0.75) if str(jl).ends_with("READY") else Color(0.8, 0.85, 0.95))
			var nxt: Array = []
			for bid in Builds.data():
				if Crafting.is_station(str(bid)) and not Builds.next_def(str(bid)).is_empty() and Builds.gate(str(bid)) == "" and nxt.size() < 4:
					nxt.append(str(Builds.next_def(str(bid))["name"]))
			if not nxt.is_empty():
				_line("Open to build now: " + ", ".join(nxt), 8, Color(0.8, 1, 0.7))
			_line("A better station runs more jobs at once, works faster, opens higher recipes, and sometimes turns out a bonus piece.", 8, Color(0.7, 0.7, 0.7))
			_button("← Back to Quests", func() -> void: _tab = "Quests"; _refresh())
		"Foes":
			var kc: Dictionary = r.get("kill_counts", {})
			var known: Dictionary = r.get("gifts_known", {})
			_line("Foes & Gifts · %d kinds beaten · %d Gifts read" % [kc.size(), known.size()], 9, Color(1, 0.85, 0.75))
			if not known.is_empty():
				_line("Gifts you've learned to beat", 8, Color(1, 0.95, 0.7))
				for gid in known:
					var g := Gift.def(str(gid))
					_line("  ✦ %s: %s" % [str(g.get("name", gid)), str(g.get("tip", ""))], 8, Color(1, 0.95, 0.85))
			if GameState.run.get("arc", "") == "gangsters":
				_line("The Marked", 8, Color(1, 0.9, 0.7))
				for mid in Marked.all():
					var md: Dictionary = Marked.all()[mid]
					var st := Marked.state(str(mid))
					var who := "%s \"%s\", %d" % [str(md["name"]), str(md["epithet"]), int(md["age"])] if st != "" else "??? (%s)" % str(md["scene"]).replace("_", " ")
					_line("  %s  %s" % [who, {"crew": "· in your crew", "free": "· went home"}.get(st, "")], 8, Color(0.95, 0.9, 1.0))
			_line("Beaten", 8, Color(0.9, 0.85, 1.0))
			var ks := kc.keys()
			ks.sort_custom(func(a: Variant, b: Variant) -> bool: return int(kc[a]) > int(kc[b]))
			for k in ks:
				var ed: Dictionary = GameState.enemy_data.get("enemies", {}).get(str(k), {})
				var nm := str(ed.get("name", str(k).replace("thug_", "").replace("marked_", "").replace("_", " ").capitalize()))
				_line("  %s ×%d · tier %d%s" % [nm, int(kc[k]), int(ed.get("tier", 0)), ("  · " + str(Gift.def(str(ed["gift"])).get("name", ""))) if ed.has("gift") else ""], 8, Color(0.85, 0.85, 0.9))
			_button("← Back to Quests", func() -> void: _tab = "Quests"; _refresh())
		"Mail":
			_line("Letters (newest first)", 9, Color(1, 0.9, 0.7))
			var ml: Array = Mail.list().duplicate()
			ml.reverse()
			if ml.is_empty():
				_line("  No letters yet. Folks write once they know you.", 8, Color(0.7, 0.7, 0.7))
			for m: Dictionary in ml:
				m["read"] = true
				_line("Day %d · %s" % [int(m.get("day", 0)), str(m["from"])], 8, Color(1, 0.95, 0.8))
				_line("  " + str(m["text"]), 8, Color(0.9, 0.9, 0.85))
				var mm := m
				if str(m.get("kind", "")) == "gift" and not bool(m.get("got", false)):
					_button("  Take the %s" % GameState.item_name(str(m["item"])), func() -> void:
						Mail.act(mm)
						_refresh())
				elif str(m.get("kind", "")) == "favour" and not bool(m.get("done", false)):
					_button("  Send %s for ◆%d (have %d)" % [ItemWords.count_id(str(m["item"]), int(m["n"])), int(m["pay"]), GameState.count(str(m["item"]))], func() -> void:
						var err := Mail.act(mm)
						var mp := get_tree().current_scene as GameMap
						if mp and err != "":
							mp.hud.toast(err, Color(1, 0.8, 0.6))
						_refresh())
			_button("← Back to Quests", func() -> void: _tab = "Quests"; _refresh())
		"Messages":
			_line("Recent messages (newest first)", 9, Color(0.85, 0.9, 1.0))
			var tl: Array = (r.get("toast_log", []) as Array).duplicate()
			tl.reverse()
			for t in tl:
				_line("  " + str(t), 8, Color(0.9, 0.9, 0.9))
			_button("← Back to Quests", func() -> void: _tab = "Quests"; _refresh())
		"FieldLog":
			# Every crop by family: grown ones with counts, in-season ones hinted, the rest as ???.
			var grown: Dictionary = r.get("grown", {})
			_line("Field log · %d / %d · in season now: %s" % [grown.size(), GameState.crops.size(), GameState.season().capitalize()], 9, Color(0.8, 1, 0.7))
			var by_fam := {}
			for cid in GameState.crops:
				var f := str(GameState.crops[cid].get("family", "veg"))
				if not by_fam.has(f):
					by_fam[f] = []
				by_fam[f].append(str(cid))
			for f in GameState.FAMILY_NAMES:
				if not by_fam.has(f):
					continue
				var ids: Array = by_fam[f]
				var got := 0
				var parts: Array = []
				for cid: String in ids:
					var cd: Dictionary = GameState.crops[cid]
					if grown.has(cid):
						got += 1
						parts.append("%s ×%d" % [str(cd["name"]), int(grown[cid])])
					elif str(cd.get("season", "any")) in [GameState.season(), "any"] and int(cd.get("tier", 1)) <= GameState.progress_tier() + 1:
						parts.append("(%s)" % str(cd["name"]))
					else:
						parts.append("???")
				_line("%s  %d/%d" % [GameState.family_name(f), got, ids.size()], 8, Color(1, 0.9, 0.6))
				_line("  " + ", ".join(parts), 8, Color(0.85, 0.85, 0.8))
			_line("(Names in brackets grow this season; look for their seeds at Maple's, Tam's, Old Moss's, Sel's%s.)" % (" and Catkins's" if GameState.is_penguins() else ""), 8, Color(0.7, 0.7, 0.7))
			_button("← Back to Quests", func() -> void: _tab = "Quests"; _refresh())
		"Keys":
			_line("Key bindings (Stardew defaults). Pick a row, then press the new key. Esc cancels.", 8, Color(0.8, 0.8, 0.8))
			for pair in InputSetup.SHOWN:
				var action: String = pair[0]
				var label: String = pair[1]
				var txt := "%-18s %s" % [label, InputSetup.key_label(action)]
				if _rebinding == action:
					txt = "%-18s [press a key]" % label
				_button(txt, func() -> void: _rebinding = action; _steal_warn = {}; _refresh())
				if _rebinding == action and not _steal_warn.is_empty():
					_line("  That key is %s's. Press it again to move it here (%s loses it), or Esc to cancel." % [action_label(str(_steal_warn["from"])), action_label(str(_steal_warn["from"]))], 8, Color(1, 0.75, 0.5))
			_button("Reset to defaults", func() -> void: InputSetup.reset_bindings(); _rebinding = ""; _steal_warn = {}; _refresh())
			_button("← Back to Options", func() -> void: _tab = "Options"; _rebinding = ""; _steal_warn = {}; _refresh())
		"Pad":
			_pad_page()
	_pass_drags(_body)


## Buttons hand drags on to the ScrollContainer, so a finger on a slot or a row still scrolls the tab.
func _pass_drags(n: Node) -> void:
	for c in n.get_children():
		if c is BaseButton:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		_pass_drags(c)


## Sun Haven-style skills page: a tab per skill, the level / points / EXP panel,
## and the tree as a grid of 4 branches x 10 tiers (I-X). Column N opens after
## 2N points spent in that skill. Tap a node to read it, then Learn.
const SKILL_ORDER := ["farming", "ranching", "mining", "foraging", "fishing", "combat", "magic", "pup", "bartering", "building", "leadership", "strategist", "harmony", "hustle"]
const BRANCH_COL := [Color(0.32, 0.55, 0.25), Color(0.25, 0.42, 0.62), Color(0.6, 0.38, 0.22), Color(0.48, 0.3, 0.58)]
var _node_sel := ""
var _reset_arm := ""
## Item icons that stand in for node art until the node icon sheets arrive.
const KEY_ICON := {"extra_crop": "turnip", "double_harvest": "wheat", "farm_energy": "can", "extra_day": "hoe", "animal_yield": "egg", "crop_value": "gold",
	"star_chance": "sunflower", "seed_back": "seeds", "growth": "sunflower", "stone_bonus": "stone", "mine_energy": "pickaxe", "ore_bonus": "copper",
	"double_hit": "iron", "gem_chance": "diamond", "shard_bonus": "shard", "deeper": "torch", "smelt_discount": "iron", "forage_bonus": "berry",
	"rare_forage": "mushroom", "wood_bonus": "wood", "chop_bonus": "axe", "sap_chance": "sap", "bite_speed": "rod", "escape_less": "bait",
	"double_fish": "fish", "rare_fish": "fish", "fish_value": "pearl", "chest_chance": "chest", "damage": "sword", "crit": "ruby", "block": "iron",
	"damage_reduction": "iron", "hp": "potion", "energy": "energy_tea", "kill_energy": "energy_tea", "sell_bonus": "gold", "interest": "gold",
	"gift_bonus": "gift_pie", "buy_discount": "gold", "wood_discount": "plank", "stone_discount": "brick", "craft_speed": "hammer", "build_discount": "hammer",
	"spark_damage": "crystal", "spell_power": "big_crystal", "mana": "mana_potion", "mana_regen": "mana_potion", "spell_discount": "amethyst",
	"pet_hp": "bone", "pet_dmg": "bone", "pet_speed": "bone", "pet_def": "bone", "pass_risk": "map", "heat_cool": "key", "wash_bonus": "gold",
	"job_pay": "gold", "capture_speed": "map", "start_supply": "chest", "spawner_discount": "brick", "helper_damage": "crystal", "ticket_bleed": "ruby", "ticket_guard": "copper_ring", "gun_damage": "six_shooter", "supply_rate": "chest", "helper_hp": "emerald", "ability_cooldown": "paw_charm",
	"colony_discount": "pearl", "team_damage": "sword", "team_defense": "copper_ring", "team_heal": "greater_potion", "friend_gain": "cake",
	"pet_bond": "bone", "team_xp": "luck_potion", "xp_gain": "book", "status_guard": "potion", "last_stand": "greater_potion", "free_cast": "mana_potion", "regrowth": "seeds",
	"wide_water": "can", "timber": "axe", "tremor": "pickaxe", "tidecall": "rod", "jackpot": "gold", "quick_build": "hammer",
	"big_goods": "egg", "animal_quality": "milk", "ranch_value": "gold", "breed_chance": "feather", "grow_speed": "hay", "animal_friend": "brush", "hand_work": "milk_pail", "hand_slot": "milk_pail", "feeder": "feed_bag", "care_grace": "brush", "hatch_fast": "egg"}  # C11a P3 hook (Ranching)


func _skills_tab() -> void:
	var shown: Array = []
	for sk in SKILL_ORDER:
		if GameState.skills_data.has(sk) and GameState.skill_in_arc(sk):
			shown.append(sk)
	if _skill_open == "" or not _skill_open in shown:
		_skill_open = str(shown[0])
	var sk := _skill_open
	var sd: Dictionary = GameState.skills_data[sk]
	# Skill tabs
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 2)
	tabs.add_theme_constant_override("v_separation", 2)
	_body.add_child(tabs)
	for k in shown:
		var tb := Button.new()
		var pf := SkillGlow.usable(str(k))  # P5 hook: maxed trees stop glowing
		tb.text = str(GameState.skills_data[k]["name"]) + ("  +%d" % pf if pf > 0 else "")
		tb.add_theme_font_size_override("font_size", 7)
		tb.custom_minimum_size = Vector2(0, 20)
		tb.focus_mode = Control.FOCUS_NONE
		tb.modulate = Color(1, 0.88, 0.45) if k == sk else (Color(1, 0.97, 0.85) if pf > 0 else Color(0.78, 0.78, 0.78))
		var kk := str(k)
		tb.pressed.connect(func() -> void: last_press = "%s > skill %s" % [_tab, kk])
		tb.pressed.connect(func() -> void: _skill_open = kk; _node_sel = ""; _reset_arm = ""; _refresh())
		tabs.add_child(tb)
		SkillGlow.set_glow(tb, pf, false)
	# Level / points / EXP panel
	var lvl := GameState.skill_level(sk)
	var xp := int(GameState.run["skills"].get(sk, {}).get("xp", 0))
	var need := GameState.xp_for_next(lvl)
	var free := SkillGlow.usable(sk)  # P5 hook: maxed trees stop glowing
	var spent := GameState.points_spent(sk)
	var head := HBoxContainer.new()
	_body.add_child(head)
	var big := ""
	for cand in ["skillbig_", "skill2_", "skill3_", "skill_"]:
		if Art.has("ui", cand + sk):
			big = cand + sk
			break
	var ic := Art.tex("ui", big) if big != "" else Art.tex("items", str({"farming": "hoe", "mining": "pickaxe", "foraging": "axe", "fishing": "rod", "combat": "sword", "magic": "crystal", "pup": "bone", "bartering": "gold", "building": "hammer", "leadership": "paw_charm", "strategist": "map", "harmony": "big_crystal", "hustle": "six_shooter", "ranching": "egg"}.get(sk, "map")))
	if ic:
		var tr := TextureRect.new()
		tr.texture = ic
		tr.custom_minimum_size = Vector2(28, 28)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		head.add_child(tr)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_theme_constant_override("separation", 0)
	head.add_child(hv)
	var l1 := Label.new()
	l1.text = "Level %d  %s" % [lvl, str(sd["name"])]
	l1.add_theme_font_size_override("font_size", 10)
	hv.add_child(l1)
	var l2 := Label.new()
	l2.text = "%d skill point%s · %d spent" % [free, "" if free == 1 else "s", spent]
	l2.add_theme_font_size_override("font_size", 8)
	l2.add_theme_color_override("font_color", Color(1, 0.9, 0.45) if free > 0 else Color(0.8, 0.8, 0.8))
	hv.add_child(l2)
	var bar := ProgressBar.new()
	bar.max_value = need
	bar.value = xp
	bar.custom_minimum_size = Vector2(0, 6)
	bar.show_percentage = false
	hv.add_child(bar)
	var l3 := Label.new()
	l3.text = "%s EXP %d / %d" % [str(sd["name"]), xp, need]
	l3.add_theme_font_size_override("font_size", 7)
	hv.add_child(l3)
	if free > 0:
		SkillGlow.points_banner(_body, free, str(sd["name"]))
	var sel_at := _body.get_child_count()
	# The grid
	var by_cell := {}
	for n in GameState.nodes_of(sk):
		by_cell[Vector2i(int(n.get("tier", 0)), int(n.get("row", 0)))] = n
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	_body.add_child(grid)
	if _node_sel != "":
		# Keep the grid (and the node just tapped) on screen once the info block is above it.
		var sc := _body.get_parent() as ScrollContainer
		if sc:
			var show_grid := func() -> void:
				if is_instance_valid(grid) and is_instance_valid(sc):
					sc.ensure_control_visible(grid)
			get_tree().process_frame.connect(show_grid, CONNECT_ONE_SHOT)
	var romans := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
	for c in 10:
		var open := spent >= c * GameState.TIER_POINTS
		var hp := PanelContainer.new()
		var hs := StyleBoxFlat.new()
		hs.bg_color = Color(0.36, 0.62, 0.28) if open else Color(0.25, 0.22, 0.2)
		hs.set_corner_radius_all(2)
		hp.add_theme_stylebox_override("panel", hs)
		hp.custom_minimum_size = Vector2(22, 12)
		var hl := Label.new()
		hl.text = romans[c]
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hl.add_theme_font_size_override("font_size", 7)
		hp.add_child(hl)
		grid.add_child(hp)
	for r in 4:
		for c in 10:
			var n: Dictionary = by_cell.get(Vector2i(c, r), {})
			grid.add_child(_node_cell(sk, n, r, spent >= c * GameState.TIER_POINTS))
	# Branch names
	var br: Dictionary = sd.get("branches", {})
	var names: Array = []
	for r in 4:
		names.append(str(br.get(str(r), "")))
	_line("Rows: " + " · ".join(names), 8, Color(0.8, 0.78, 0.7))
	# The picked node: shown ABOVE the grid so Learn is on screen without scrolling.
	var sel_from := _body.get_child_count()
	var sel := GameState.node(sk, _node_sel) if _node_sel != "" else {}
	if sel.is_empty():
		_line(str(sd.get("desc", "")), 8, Color(0.85, 0.8, 0.7))
		_line("Level up to earn points (1 per level). Tap a node to read it. Violet frame = unlocks something new. A column opens after 2 more points here.", 8, Color(0.75, 0.75, 0.75))
	else:
		var rank := GameState.node_rank(sk, _node_sel)
		var ranks := int(sel.get("ranks", 1))
		var why := GameState.node_locked(sk, _node_sel)
		_line("%s  ·  %s, tier %s  ·  %d/%d" % [str(sel["name"]), str(br.get(str(int(sel.get("row", 0))), "")), romans[int(sel.get("tier", 0))], rank, ranks], 9, Color(1, 0.92, 0.6))
		_line(str(sel["desc"]), 8, Color(0.95, 0.95, 0.9))
		var nid := _node_sel
		var lb := _button("Learn (1 point)" if why == "" else ("Maxed" if why == "maxed" else "Locked: " + why), func() -> void:
			if GameState.buy_node(sk, nid):
				Music.instance(get_tree()).sfx("craft_done", "levelup")
				GameState.notify("Learned %s." % str(sel["name"]))
			_refresh())
		lb.disabled = why != ""
		lb.set_meta("skill_buy", nid)
	var moved := 0
	for i in (range(sel_from, _body.get_child_count()) if not sel.is_empty() else []):
		_body.move_child(_body.get_child(i), sel_at + moved)
		moved += 1
	if sk == "magic":
		_magic_casts()
	if spent > 0:
		var rb := _button("Sure? Tap again to reset %s" % str(sd["name"]) if _reset_arm == sk else ("Reset this tree (refund all points; colony spells stay)" if sk == "magic" and not (GameState.run.get("gift_nodes", {}) as Dictionary).is_empty() else "Reset this tree (refund all points)"), func() -> void:
			if _reset_arm == sk:
				GameState.reset_tree(sk); _node_sel = ""; _reset_arm = ""
			else:
				_reset_arm = sk
			_refresh())
		if _reset_arm == sk:
			rb.add_theme_color_override("font_color", Color(1, 0.45, 0.4))


func _node_cell(sk: String, n: Dictionary, r: int, col_open: bool) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(22, 22)
	b.focus_mode = Control.FOCUS_NONE
	var st := StyleBoxFlat.new()
	var bc: Color = BRANCH_COL[r]
	if n.is_empty():
		st.bg_color = Color(0, 0, 0, 0.2)
		for k in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(k, st)
		b.disabled = true
		return b
	var id := str(n["id"])
	var rank := GameState.node_rank(sk, id)
	var ranks := int(n.get("ranks", 1))
	st.bg_color = bc.darkened(0.25) if col_open else Color(0.18, 0.16, 0.15)
	st.border_color = Color(1, 0.84, 0.35) if rank > 0 else (Color(0.95, 0.9, 0.75) if id == _node_sel else Color(0.08, 0.06, 0.04))
	st.set_border_width_all(2 if (rank > 0 or id == _node_sel) else 1)
	st.set_corner_radius_all(3)
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, st)
	var nic := "node_%s_%s" % [sk, id]
	var tex: Texture2D = Art.tex("ui", nic) if Art.has("ui", nic) else null
	if bool(n.get("unlock", false)):
		# Unlock nodes show what they unlock, framed in violet.
		st.border_color = Color(1, 0.84, 0.35) if rank > 0 else Color(0.75, 0.55, 1.0)
		st.set_border_width_all(2)
		var e: Dictionary = n.get("effect", {})
		var cands: Array = []
		if e.has("blueprint"):
			var bd: Dictionary = Builds.all().get(str(e["blueprint"]), {})
			var t1: Dictionary = (bd.get("tiers", [{}]) as Array)[0] if not (bd.get("tiers", []) as Array).is_empty() else {}
			cands = [[str(t1.get("group", bd.get("group", "props"))), str(t1.get("sprite", bd.get("sprite", "")))], ["items", "hammer"]]
		elif e.has("spell"):
			cands = [["ui", "spell_" + str(e["spell"])], ["items", "crystal"]]
		elif e.has("move_speed"):
			cands = [["items", "boots_leather"], ["items", "boots"]]
		elif e.has("chop_power"):
			cands = [["items", "axe"]]
		elif e.has("mine_power"):
			cands = [["items", "pickaxe"]]
		elif e.has("damage"):
			cands = [["items", "sword"]]
		for cd in cands:
			if Art.has(str(cd[0]), str(cd[1])):
				tex = Art.tex(str(cd[0]), str(cd[1]))
				break
	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.offset_left = 3
	tr.offset_top = 2
	tr.offset_right = -3
	tr.offset_bottom = -5
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex:
		tr.texture = tex
	else:
		var ik := ""
		for ek in (n.get("effect", {}) as Dictionary):
			ik = str(KEY_ICON.get(ek, ""))
			break
		if ik == "":
			ik = {"farming": "hoe", "mining": "pickaxe", "foraging": "axe", "fishing": "rod", "combat": "sword", "magic": "crystal", "pup": "bone", "bartering": "gold", "building": "hammer", "leadership": "paw_charm", "strategist": "map", "harmony": "big_crystal", "hustle": "six_shooter", "ranching": "egg"}.get(sk, "map")
		tr.texture = Art.tex("items", ik)
	if not col_open:
		tr.modulate = Color(0.4, 0.4, 0.4, 0.6)
	b.add_child(tr)
	var rl := Label.new()
	rl.text = "%d/%d" % [rank, ranks]
	rl.add_theme_font_size_override("font_size", 7)
	rl.add_theme_color_override("font_color", Color(0.6, 1, 0.6) if rank >= ranks else Color(1, 1, 1))
	rl.add_theme_constant_override("outline_size", 2)
	rl.add_theme_color_override("font_outline_color", Color.BLACK)
	rl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	rl.offset_left = -16
	rl.offset_top = -9
	rl.offset_right = -1
	rl.offset_bottom = 0
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(rl)
	b.pressed.connect(func() -> void: _node_sel = id; _refresh())
	b.set_meta("skill_node", id)
	return b


func _magic_casts() -> void:
	var kn := Spells.known()
	if kn.is_empty():
		_line("Learn Spark or Deep Well to start casting.", 8, Color(0.8, 0.8, 0.8))
		return
	_line("Cast  (mana %d / %d)" % [int(GameState.run.get("mana", 0)), int(GameState.run.get("max_mana", 0))], 8, Color(0.6, 0.8, 1.0))
	for id in kn:
		var sp: Dictionary = Spells.SPELLS[id]
		var cb := _button("✦ %s  (%d mana) — %s" % [str(sp["name"]), Spells.cost_of(id), str(sp["desc"])], func() -> void:
			var m := get_tree().current_scene
			if m is GameMap:
				toggle()
				Spells.cast(m as GameMap, id))  # a failed cast plays "nope" itself
		cb.add_theme_font_size_override("font_size", 7)


func _refresh_player() -> void:
	var m := get_tree().current_scene
	if m is GameMap and (m as GameMap).player:
		(m as GameMap).player.refresh_doll()


var _bag_pick := ""
var _pick_bar := -1  # toolbar slot the picked item came from (-1: bag / Tools row)
var _trash_arm := ""


## Bag slot tapped: pick it, or place/swap the picked item there.
func _bag_tap(i: int) -> void:
	if _drag and _drag.eat_tap():
		return
	_bag_tap_now(i)


func _bag_tap_now(i: int) -> void:
	var bs := GameState.bag_slots()
	var id := str(bs[i]) if i < bs.size() else ""
	if _bag_pick == "":
		if id != "":
			_bag_pick = id
			_pick_bar = -1
			_trash_arm = ""
		_refresh()
		return
	if _pick_bar >= 0:
		# Picked off the toolbar and placed in the bag: it leaves the bar
		# (a tool goes back to the Tools row; nothing is lost).
		var tb: Array = GameState.run["toolbar"]
		if _pick_bar < tb.size() and str(tb[_pick_bar]) == _bag_pick:
			tb[_pick_bar] = ""
			GameState.sync_selected()
		_pick_bar = -1
	var from := bs.find(_bag_pick)
	if from >= 0:
		GameState.bag_move(from, i)
	elif GameState.has_tool(_bag_pick) and id != "":
		pass  # a tool can't go into the bag
	_bag_pick = ""
	_refresh()


## Toolbar slot tapped: select it, or put the picked item on it. A second tap
## on the selected slot picks its item up (place it on another slot to swap,
## or on a bag slot to take it off the bar).
func _toolbar_tap(i: int) -> void:
	if _drag and _drag.eat_tap():
		return
	if _bag_pick != "":
		_assign_toolbar(_bag_pick, i)
		return
	var tb: Array = GameState.run["toolbar"]
	if i == int(GameState.run["slot"]) and str(tb[i]) != "":
		_bag_pick = str(tb[i])
		_pick_bar = i
		_trash_arm = ""
		_refresh()
		return
	GameState.select_slot(i)
	_refresh()


func _tool_tap(t: String) -> void:
	if _drag and _drag.eat_tap():
		return
	_bag_pick = "" if _bag_pick == t else t
	_pick_bar = -1
	_refresh()


func _trash_tap(id: String) -> void:
	if _trash_arm == id or not GameState.trash_needs_confirm(id):
		GameState.trash(id, GameState.count(id))
		Music.instance(get_tree()).sfx("thud", "nope")
		_bag_pick = ""
		_trash_arm = ""
	else:
		_trash_arm = id
		var gm := get_tree().current_scene as GameMap
		if gm and gm.hud:
			gm.hud.toast("Throw away %s? Tap the trash again to confirm." % ItemWords.count_id(id, GameState.count(id)), Color(1, 0.8, 0.6))
	_refresh()


## ---- C6 P7: drag and drop + trash can slot (Items tab) ----------------------
var _drag: SlotDrag


func _items_drag() -> SlotDrag:
	if _drag == null or not is_instance_valid(_drag):
		_drag = SlotDrag.new()
		add_child(_drag)
		# Lifting doesn't rebuild the tab (nothing moves under the finger); a
		# drop back on the slot or outside any slot leaves it picked (actions shown).
		_drag.on_lift = func(pl: Dictionary) -> void:
			_bag_pick = str(pl.get("id", ""))
			_pick_bar = int(pl.get("bar", -1))
			_trash_arm = ""
		_drag.on_drop_nowhere = func(_pl: Dictionary) -> void: _refresh()
	_drag.clear()
	return _drag


func _drop_on_bar(pl: Dictionary, i: int) -> void:
	_bag_pick = str(pl.get("id", ""))
	_pick_bar = int(pl.get("bar", -1))
	_assign_toolbar(_bag_pick, i)


func _drop_on_bag(pl: Dictionary, i: int) -> void:
	var id := str(pl.get("id", ""))
	if GameState.has_tool(id) and int(pl.get("bar", -1)) < 0:
		_bag_pick = ""
		_refresh()
		return  # a tool from the Tools row has no bag slot
	_bag_pick = id
	_pick_bar = int(pl.get("bar", -1))
	_bag_tap_now(i)


func _drop_trash(pl: Dictionary) -> void:
	var id := str(pl.get("id", ""))
	_bag_pick = id
	if not GameState.can_trash(id):
		var gm := get_tree().current_scene as GameMap
		if gm and gm.hud:
			gm.hud.toast("%s can't go in the trash." % GameState.item_name(id) if not GameState.is_locked(id) else "Locked: unlock it first to trash it.", Color(1, 0.8, 0.6))
		Music.instance(get_tree()).sfx("nope", "thud")
		_refresh()
		return
	_trash_tap(id)


## The trash can: tap it with an item picked (or drop one on it). Cheap stacks go
## at once; valuable ones (GameState.trash_needs_confirm) ask once: the can
## opens and turns red, tap it again to throw them away.
func _trash_slot() -> Control:
	var armed := _trash_arm != "" and _trash_arm == _bag_pick
	var b := Button.new()
	b.custom_minimum_size = Vector2(26, 26)
	b.focus_mode = Control.FOCUS_NONE
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	b.tooltip_text = "Trash"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.15, 0.12) if armed else Color(0.25, 0.17, 0.1)
	sb.border_color = Color(1, 0.5, 0.4) if armed else Color(0.1, 0.07, 0.04)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var tex := Art.tex("ui", "trash_can_open" if (armed or _bag_pick != "") else "trash_can")
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 3
		tr.offset_top = 2
		tr.offset_right = -3
		tr.offset_bottom = -2
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tr)
	else:
		b.text = "Bin"
	b.pressed.connect(func() -> void:
		if _drag and _drag.eat_tap():
			return
		if _bag_pick == "" or GameState.has_tool(_bag_pick):
			var gm := get_tree().current_scene as GameMap
			if gm and gm.hud:
				gm.hud.toast("Pick an item (or drag one here) to trash it.", Color(0.95, 0.9, 0.8))
			return
		_drop_trash({"id": _bag_pick}))
	if armed:
		var q := Label.new()
		q.text = "?"
		q.add_theme_font_size_override("font_size", 9)
		q.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
		q.add_theme_constant_override("outline_size", 2)
		q.add_theme_color_override("font_outline_color", Color.BLACK)
		q.position = Vector2(17, -1)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(q)
	return b


## Put id on toolbar slot i. If it's on another slot they swap; a tool that gets
## bumped moves to a free slot or back to the Tools row (never lost).
func _assign_toolbar(id: String, i: int) -> void:
	var tb: Array = GameState.run["toolbar"]
	var was := str(tb[i])
	var other := tb.find(id)
	if other >= 0 and other != i:
		tb[other] = was
	elif GameState.has_tool(was) and was != id:
		var free := tb.find("")
		if free >= 0 and free != i:
			tb[free] = was
	tb[i] = id
	GameState.run["slot"] = i
	GameState.sync_selected()
	_bag_pick = ""
	_pick_bar = -1
	_refresh()


## Animals detail (TeamAnimals._detail calls this): born day and generation, parents and kids (tap a
## living one to open it), expecting status and the species' habitat needs (c11b_11-07, 11-08, 02-02).
func ranch_family_lines(uid: String) -> void:
	var fam := Ranch.family(uid)
	var born := int(fam["born_day"])
	_line("  Born %s %d · gen %d" % [GameState.season_of(maxi(1, born)).capitalize(), (maxi(1, born) - 1) % GameState.DAYS_PER_SEASON + 1, int(fam["gen"])], 8, Color(0.8, 0.85, 0.9))
	for grp: String in ["parents", "kids"]:
		var kin: Array = fam[grp]
		if kin.is_empty():
			continue
		_line("  %s:" % grp.capitalize(), 8, Color(0.85, 0.9, 0.8))
		for k: Dictionary in kin:
			var kid := str(k["uid"])
			var rare := Ranch.is_rare(kid) if not bool(k["rehomed"]) else false
			var label := "    %s%s%s" % [str(k["name"]), " ✦" if rare else "", (" (lives at %s)" % str(k["where"])) if bool(k["rehomed"]) else ""]
			if bool(k["rehomed"]):
				_line(label, 8, Color(0.7, 0.7, 0.7))
			else:
				_button(label + " ›", func() -> void:
					TeamAnimals._sel = kid
					_refresh())
	var ex := Ranch.expecting_text(uid)
	if ex != "":
		_line("  " + ex, 8, Color(1, 0.85, 0.75))
	var hab := Ranch.habitat_text(uid)
	if hab != "":
		_line("  " + hab, 8, Color(0.8, 0.9, 1))


## When a resting pup is back, as a clock time ("about 8am" / "tomorrow about 6am").
static func pup_back_text() -> String:
	var st := Pet.state()
	if not st.has("rest_until_abs"):
		return "tomorrow"
	var at := int(st["rest_until_abs"])
	var now := GameState.now_abs()
	var t := at % 1440
	var h := t / 60
	var clock := "%d%s" % [12 if h % 12 == 0 else h % 12, "am" if h < 12 else "pm"]
	return ("about %s" % clock) if at / 1440 == now / 1440 else ("tomorrow about %s" % clock)


## Why a command can't reach the pup right now.
func _pup_away_text(pname: String) -> String:
	if Pet.resting():
		return "%s is resting at home. Back %s." % [pname, pup_back_text()]
	return "%s isn't here. Recall first." % pname


## The pup: health, level, commands, gear, pack, treats.
func _pup_tab() -> void:
	var st := Pet.state()
	var pname := Pet.name_of()
	var lvl := GameState.skill_level("pup")
	var sk: Dictionary = GameState.run["skills"].get("pup", {"level": 1, "xp": 0})
	var m: Node = get_tree().current_scene if is_inside_tree() else null
	var pt: Pet = (m as GameMap).pet as Pet if m is GameMap and (m as GameMap).pet is Pet else null
	if Pet.resting():
		_line("%s is resting at home after a rough day. Back %s." % [pname, pup_back_text()], 9, Color(1, 0.85, 0.7))
	_line("%s  ·  Lv %d  (%d / %d xp)" % [pname, lvl, int(sk["xp"]), GameState.xp_for_next(lvl)], 10, Color(1, 0.95, 0.8))
	_line("Health %d / %d   ·   bite %d   ·   speed ×%.1f" % [int(st["hp"]), Pet.max_hp(), Pet.bite_damage(), Pet.speed_mult()] + ("   ·   pack %d" % Pet.pack_size() if Pet.pack_size() > 0 else ""), 8, Color(0.85, 1.0, 0.85))
	var here := pt != null and pt.visible
	var mode_word := str({"follow": "HEEL", "attack": "ATTACK", "wait": "STAY", "guard": "GUARD"}.get(str(st.get("mode", "follow")), str(st.get("mode", "follow")).to_upper()))
	_line("Mode: %s" % (mode_word if here else ("resting" if Pet.resting() else "away (not on this map)")), 9, Color(1, 0.9, 0.5))
	var cmds := [["Heel (follow)", "follow"], ["Attack", "attack"], ["Guard here", "guard"], ["Stay", "wait"]]
	for c in cmds:
		var mode: String = c[1]
		var locked := (mode == "guard" and GameState.bonus("pup", "guard") <= 0.0)
		var b := _button(("  " if str(st.get("mode", "")) != mode else "▶ ") + str(c[0]) + ("   [needs Guard Dog]" if locked else ""), func() -> void:
			if locked:
				return
			if not here:
				_toast(_pup_away_text(pname))
				return
			toggle()
			pt.set_mode(mode))
		var ic_name: String = {"follow": "cmd_heel", "attack": "cmd_attack", "guard": "cmd_guard", "wait": "cmd_stay"}.get(mode, "")
		if Art.has("ui", ic_name):
			b.icon = Art.tex("ui", ic_name)
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 16)
		if locked or not here:
			b.modulate = Color(0.6, 0.6, 0.6)
	var rb := _button("  Recall %s (from anywhere)" % pname + ("   [resting]" if Pet.resting() else ""), func() -> void:
		if pt == null:
			_toast(_pup_away_text(pname))
			return
		toggle()
		pt.recall())
	if pt == null:
		rb.modulate = Color(0.6, 0.6, 0.6)
	_line("Gear", 9, Color(0.9, 0.85, 0.7))
	for slot: String in ["collar", "pack", "boots"]:
		var gid := str(st["gear"].get(slot, ""))
		if gid == "":
			_line("  %s: -" % slot, 8, Color(0.6, 0.6, 0.6))
		else:
			_button("  %s: %s  (take off)" % [slot, GameState.item_name(gid)], func() -> void:
				if slot == "pack" and not (st.get("pack", {}) as Dictionary).is_empty():
					_toast("Empty the pack first: take what %s carries." % pname)
					return
				st["gear"][slot] = ""
				GameState.add_item(gid, 1)
				if pt:
					pt.refresh_gear()
				_refresh())
	var any_gear := false
	for id in GameState.run["inventory"].keys():
		var it: Dictionary = GameState.items.get(id, {})
		if str(it.get("type", "")) == "petgear":
			any_gear = true
			var slot2 := str(it.get("slot", "collar"))
			_button("  Put on %s (%s)" % [GameState.item_name(id), slot2], func() -> void:
				var old := str(st["gear"].get(slot2, ""))
				GameState.add_item(id, -1)  # first, so the old piece can use the freed slot
				if old != "":
					GameState.add_item(old, 1)
				st["gear"][slot2] = id
				if pt:
					pt.refresh_gear()
				_refresh())
		elif it.has("pet_heal"):
			_button("  Give %s (+%d health)" % [GameState.item_name(id), int(it["pet_heal"])], func() -> void:
				GameState.add_item(id, -1)
				if pt:
					pt.revive_with(int(it["pet_heal"]))  # also gets a downed pup back up
					pt._hp_bar.queue_redraw()
				else:
					st["hp"] = mini(Pet.max_hp(), int(st["hp"]) + int(it["pet_heal"]))
				_refresh())
	if not any_gear:
		_line("  Collars and packs come from the workbench and the smithy (shed fur, rope, bars).", 8, Color(0.7, 0.7, 0.7))
	var cap := Pet.pack_size()
	if cap > 0 or not (st.get("pack", {}) as Dictionary).is_empty():
		var pack: Dictionary = st["pack"]
		var used := 0
		for k in pack:
			used += 1
		_line("Pack  (%d / %d stacks)" % [used, cap], 9, Color(0.9, 0.85, 0.7))
		for id in pack.keys():
			_button("  Take %s x%d" % [GameState.item_name(id), int(pack[id])], func() -> void:
				GameState.add_item(id, int(pack[id]))
				var bq: Dictionary = (st.get("pack_q", {}) as Dictionary).get(id, {})
				for g in ["g", "s"]:
					if int(bq.get(g, 0)) > 0:
						GameState.add_quality(str(id), g, int(bq[g]))
				(st.get("pack_q", {}) as Dictionary).erase(id)
				pack.erase(id)
				_refresh())
		var sel := str(GameState.run["selected"])
		# Keys, quest items and locked stacks stay in the bag (doors and quests look there).
		if sel != "" and GameState.count(sel) > 0 and used < cap and not str(GameState.items.get(sel, {}).get("type", "")) in ["tool", "key", "quest", "vehicle"] and not GameState.is_locked(sel):
			_button("  Give %s x%d to carry" % [GameState.item_name(sel), GameState.count(sel)], func() -> void:
				pack[sel] = int(pack.get(sel, 0)) + GameState.count(sel)
				var pq: Dictionary = st.get("pack_q", {})
				var tq := GameState.take_quality(sel, GameState.count(sel))
				var oq: Dictionary = pq.get(sel, {})
				oq["g"] = int(oq.get("g", 0)) + int(tq["g"])
				oq["s"] = int(oq.get("s", 0)) + int(tq["s"])
				pq[sel] = oq
				st["pack_q"] = pq
				GameState.add_item(sel, -GameState.count(sel))
				_refresh())
	if GameState.bonus("pup", "bedroll") > 0.0 and int(st.get("bedroll_day", 0)) != int(GameState.run["day"]) and pt and pt.visible:
		_button("  Rest by %s's bedroll (+20 energy, once a day)" % pname, func() -> void:
			var gm := get_tree().current_scene as GameMap
			if int(GameState.run["energy"]) >= int(GameState.run["max_energy"]):
				if gm and gm.hud:
					gm.hud.toast("You're fully rested. Come back when you're tired.", Color(1, 0.9, 0.7))
				return  # keep today's rest for later
			st["bedroll_day"] = int(GameState.run["day"])
			var got := GameState.extra_energy(20)
			if gm and gm.hud and got <= 0:
				gm.hud.toast("Too full for more energy today.", Color(1, 0.8, 0.6))
			_refresh())
	_line("Skill tree: see Skills → Pup.", 8, Color(0.7, 0.7, 0.7))


func _eat(id: String) -> void:
	# In a fight the menu doesn't stop the clock for snacks: one bite every 3
	# seconds, and the menu closes so you're back in it.
	var mp := get_tree().current_scene as GameMap
	var in_fight := false
	if mp and mp.player:
		for e in mp.enemies:
			if is_instance_valid(e) and e.position.distance_to(mp.player.position) < 120.0:
				var now := Time.get_ticks_msec()
				if now < _food_ready:
					mp.hud.toast("Still chewing. (%.0fs)" % ((_food_ready - now) / 1000.0), Color(1, 0.85, 0.7))
					return
				in_fight = true
				break
	var fx_out := GameState.consume(id)
	var m := get_tree().current_scene
	if fx_out.keys() == ["full"]:
		if m is GameMap and (m as GameMap).hud:
			(m as GameMap).hud.toast(GameState.full_text(), Color(1, 0.8, 0.6))
		return  # nothing eaten: the food stays in the bag (and no chewing lock)
	if in_fight:
		_food_ready = Time.get_ticks_msec() + 3000
		toggle()
	if m is GameMap and (m as GameMap).player:
		(m as GameMap).effect_text((m as GameMap).player.position, fx_out)
	Music.instance(get_tree()).sfx("eat", "pickup")
	if _open:
		_refresh()


var _food_ready := 0


const PINS := {"farm": Vector2(0.44, 0.47), "house": Vector2(0.40, 0.44), "town": Vector2(0.52, 0.70), "forest": Vector2(0.30, 0.24), "lake": Vector2(0.14, 0.40),
	"meadow": Vector2(0.66, 0.46), "crystal_meadow": Vector2(0.86, 0.40), "mine": Vector2(0.72, 0.20), "mountain": Vector2(0.74, 0.70), "beach": Vector2(0.40, 0.90), "moon": Vector2(0.90, 0.08),
	"wastes": Vector2(0.95, 0.26), "hideout": Vector2(0.95, 0.52), "docks": Vector2(0.86, 0.84), "neon": Vector2(0.72, 0.92), "uptown": Vector2(0.58, 0.96), "underground": Vector2(0.70, 0.98), "countryside": Vector2(0.98, 0.66),
	"sky": Vector2(0.28, 0.06), "station": Vector2(0.80, 0.03), "jungle": Vector2(0.66, 0.04),
	"orchard_hills": Vector2(0.24, 0.12), "highlands": Vector2(0.50, 0.12), "ruins": Vector2(0.60, 0.30), "quarry": Vector2(0.58, 0.84), "marsh": Vector2(0.22, 0.86), "riverlands": Vector2(0.08, 0.62), "community_farm": Vector2(0.36, 0.72)}
const PIN_ICON := {"farm": "pin_farm", "house": "pin_farm", "town": "pin_town", "forest": "pin_forest", "lake": "pin_lake", "meadow": "pin_meadow", "crystal_meadow": "pin_meadow", "mine": "pin_mine", "mountain": "pin_mountain", "beach": "pin_beach", "moon": "pin_moon",
	"wastes": "pin_wastes", "hideout": "pin_docks", "docks": "pin_docks", "neon": "pin_tower", "uptown": "pin_tower", "underground": "pin_mine", "countryside": "pin_farm", "sky": "pin_mountain", "station": "pin_moon", "jungle": "pin_forest",
	"orchard_hills": "pin_farm", "highlands": "pin_mountain", "ruins": "pin_wastes", "quarry": "pin_mine", "marsh": "pin_lake", "riverlands": "pin_lake", "community_farm": "pin_farm"}
const SEEN_FLAG := {"crystal_meadow": "cm_seen"}


func _draw_map(m: Control) -> void:
	var font := ThemeDB.fallback_font
	if Art.has("ui", "world_map"):
		_draw_painted_map(m, font)
		return
	var boxes := {
		"forest": Rect2(60, 6, 70, 40), "lake": Rect2(4, 50, 50, 50), "farm": Rect2(70, 50, 60, 50), "meadow": Rect2(140, 55, 50, 40),
		"crystal_meadow": Rect2(195, 55, 42, 40), "mine": Rect2(165, 10, 40, 36), "moon": Rect2(205, 2, 32, 28),
		"town": Rect2(70, 110, 60, 45), "mountain": Rect2(140, 105, 60, 45), "beach": Rect2(60, 162, 80, 26), "house": Rect2(74, 54, 14, 10),
	}
	var cols := {"forest": Color(0.25, 0.5, 0.3), "lake": Color(0.3, 0.55, 0.8), "farm": Color(0.45, 0.7, 0.35), "meadow": Color(0.55, 0.75, 0.4),
		"crystal_meadow": Color(0.6, 0.7, 0.9), "mine": Color(0.4, 0.38, 0.45), "moon": Color(0.6, 0.55, 0.75), "town": Color(0.75, 0.65, 0.45),
		"mountain": Color(0.55, 0.55, 0.6), "beach": Color(0.9, 0.8, 0.5), "house": Color(0.7, 0.45, 0.3)}
	var names := {"crystal_meadow": "East" if GameState.is_penguins() else "Outskirts"}
	m.draw_rect(Rect2(0, 0, 240, 190), Color(0.85, 0.78, 0.6))
	var road := Color(0.4, 0.3, 0.2)
	for pair in [["forest", "farm"], ["lake", "farm"], ["farm", "meadow"], ["meadow", "crystal_meadow"], ["meadow", "mine"], ["farm", "town"], ["town", "mountain"], ["town", "beach"], ["mountain", "moon"]]:
		m.draw_line((boxes[pair[0]] as Rect2).get_center(), (boxes[pair[1]] as Rect2).get_center(), road, 2)
	var here := str(GameState.run["scene"])
	var seen: Dictionary = GameState.run["flags"]
	for k: String in boxes:
		var b: Rect2 = boxes[k]
		var visited := k in ["farm", "house", "town", "meadow"] or seen.has(k + "_seen") or seen.has("cm_seen") and k == "crystal_meadow" or seen.has("moon_seen") and k == "moon" or seen.has("mine_seen") and k == "mine"
		m.draw_rect(b, cols[k] if visited else Color(0.6, 0.58, 0.5))
		m.draw_rect(b, Color(0.3, 0.2, 0.1), false, 1.5 if k != here else 3.0)
		var nm := str(names.get(k, k.capitalize()))
		if not visited:
			nm = "?"
		m.draw_string(font, Vector2(b.position.x, b.position.y + b.size.y / 2 + 3), nm, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, DisplayMode.df(7), Color(0.1, 0.1, 0.1))
	if boxes.has(here):
		var scene := get_tree().current_scene
		var b: Rect2 = boxes[here]
		var p := b.get_center()
		if scene is GameMap and (scene as GameMap).player:
			var gm := scene as GameMap
			var f := gm.player.position / Vector2(gm.cols * GameMap.TILE, gm.rows * GameMap.TILE)
			p = b.position + Vector2(f.x * b.size.x, f.y * b.size.y)
		m.draw_circle(p, 4.0, Color(0.9, 0.2, 0.2))
		m.draw_arc(p, 4.0, 0, TAU, 16, Color.WHITE, 1.0)


func _draw_painted_map(m: Control, font: Font) -> void:
	var tex := Art.tex("ui", "world_map")
	var area := Rect2(Vector2.ZERO, m.custom_minimum_size)
	# Fit the portrait painting into the panel, centred.
	var sc := minf(area.size.x / tex.get_width(), area.size.y / tex.get_height())
	var sz := Vector2(tex.get_width(), tex.get_height()) * sc
	var org := area.position + (area.size - sz) / 2.0
	m.draw_rect(area, Color(0.36, 0.25, 0.14))  # the panel's wood, not a black void
	m.draw_rect(Rect2(org - Vector2(2, 2), sz + Vector2(4, 4)), Color(0.2, 0.12, 0.06))
	m.draw_texture_rect(tex, Rect2(org, sz), false)
	var here := str(GameState.run["scene"])
	var seen: Dictionary = GameState.run["flags"]
	var names := {"crystal_meadow": "East" if GameState.is_penguins() else "Outskirts", "underground": "Pit", "countryside": "Highway", "community_farm": "Commons" if GameState.is_penguins() else "Lot Garden"}
	for k: String in PINS:
		if MegaRegion.region_of(k) != "":
			continue  # a mega region's areas live on its own map tab
		var visited := k in ["farm", "house", "town", "meadow"] or seen.has(k + "_seen") or seen.has(str(SEEN_FLAG.get(k, "-")))
		if k == "house" and here != "house":
			continue  # sits on the Farm pin; only shown while you're inside
		var held := Campaign.gate_of(k) != "" and not Campaign.region_open(k)
		if not visited and not (held and Campaign.plan_lock(Campaign.gate_of(k)) == ""):
			continue
		var p: Vector2 = org + (PINS[k] as Vector2) * sz
		if held:
			_draw_lock(m, p + Vector2(0, -5))
			if not visited:
				var cn := str(Campaign.get_c(Campaign.gate_of(k)).get("region_name", k.capitalize()))
				m.draw_string_outline(font, p + Vector2(-24, 7), cn, HORIZONTAL_ALIGNMENT_CENTER, 48, DisplayMode.df(6), 3, Color(1, 0.95, 0.8, 0.8))
				m.draw_string(font, p + Vector2(-24, 7), cn, HORIZONTAL_ALIGNMENT_CENTER, 48, DisplayMode.df(6), Color(0.35, 0.1, 0.05))
				continue
		var icon := str(PIN_ICON.get(k, ""))
		if icon != "" and Art.has("ui", icon):
			var it := Art.tex("ui", icon)
			var isz := Vector2(10, 12)
			m.draw_texture_rect(it, Rect2(p - Vector2(isz.x / 2, isz.y), isz), false, Color(1, 1, 1, 1.0 if k == here else 0.85))
		else:
			m.draw_circle(p, 3.0, Color(0.9, 0.3, 0.2))
		var nm := str(names.get(k, k.capitalize()))
		m.draw_string_outline(font, p + Vector2(-20, 9), nm, HORIZONTAL_ALIGNMENT_CENTER, 40, DisplayMode.df(6), 3, Color(1, 0.95, 0.8, 0.9))
		m.draw_string(font, p + Vector2(-20, 9), nm, HORIZONTAL_ALIGNMENT_CENTER, 40, DisplayMode.df(6), Color(0.1, 0.08, 0.05))
	MegaMap.valley_gates(m, font, PINS, org, sz)
	if PINS.has(here) and MegaRegion.region_of(here) == "":
		var p: Vector2 = org + (PINS[here] as Vector2) * sz
		m.draw_circle(p + Vector2(0, -6), 3.0, Color(1, 0.2, 0.2))
		m.draw_arc(p + Vector2(0, -6), 4.5, 0, TAU, 16, Color.WHITE, 1.0)


## A small padlock over a map pin: the region is held until its campaign is won.
func _draw_lock(m: Control, c: Vector2) -> void:
	m.draw_arc(c + Vector2(0, -2), 2.2, PI, TAU, 8, Color(0.15, 0.1, 0.05), 1.6)
	m.draw_rect(Rect2(c + Vector2(-3.5, -1.5), Vector2(7, 5.5)), Color(0.15, 0.1, 0.05))
	m.draw_rect(Rect2(c + Vector2(-2.5, -0.5), Vector2(5, 3.5)), Color(0.95, 0.75, 0.3))
	m.draw_rect(Rect2(c + Vector2(-0.5, 0.3), Vector2(1, 1.6)), Color(0.15, 0.1, 0.05))


## The crew roster (Gangster's Paradise): everyone recruited, their loyalty
## hearts, rank chevron, badge and perk, on the roster panel art.
func _crew_tab() -> void:
	_line("Crew", 10, Color(1, 0.85, 0.7))
	var ids := Crew.all_recruited()
	if ids.is_empty():
		_line("  Nobody yet. People in the hideout and the districts want something before they'll join.", 8, Color(0.7, 0.7, 0.7))
		return
	for id in ids:
		var lv := Crew.loyalty(id)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		_body.add_child(h)
		var pt := Dialogue.one_face(Art.tex("portraits/" + id, "neutral"))
		if pt:
			var tr := TextureRect.new()
			tr.texture = pt
			tr.custom_minimum_size = Vector2(24, 24)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			h.add_child(tr)
		if Art.has("ui", "crew_badge_" + id):
			var bd := TextureRect.new()
			bd.texture = Art.tex("ui", "crew_badge_" + id)
			bd.custom_minimum_size = Vector2(14, 14)
			bd.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bd.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			h.add_child(bd)
		var l := Label.new()
		l.text = Crew.roster_text(id)  # perk incl. Training Center drill (C7 P5)
		l.add_theme_font_size_override("font_size", 7)
		l.custom_minimum_size = Vector2(120, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.add_child(l)
		var hearts := HBoxContainer.new()
		hearts.add_theme_constant_override("separation", 0)
		h.add_child(hearts)
		for i in 3:
			var nm := "loyalty_4" if i < lv else "loyalty_0"
			if Art.has("ui", nm):
				var hr := TextureRect.new()
				hr.texture = Art.tex("ui", nm)
				hr.custom_minimum_size = Vector2(11, 11)
				hr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				hearts.add_child(hr)
		var rlv := Crew.member_level(id)  # the drilled level the perk text uses (c11b_08-13)
		if not Art.has("ui", "rank_%d" % (rlv + 1)):
			rlv = lv
		if Art.has("ui", "rank_%d" % (rlv + 1)):
			var rk := TextureRect.new()
			rk.texture = Art.tex("ui", "rank_%d" % (rlv + 1))
			rk.custom_minimum_size = Vector2(14, 12)
			rk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			h.add_child(rk)
	for t: String in Crew.also_with_you():  # joined Marked / lieutenants (C7 P5)
		_line("  Also with you: " + t, 7, Color(0.85, 0.85, 1))
	_line("")


# --- C9 P2: sub-page back, options helpers, pad/keyboard cursor ---------------

var _steal_warn := {}  # Keys page: {key, from} while a stolen key waits for its confirm press

const SUB_PARENT := {"Keys": "Options", "Pad": "Options", "FieldLog": "Quests", "Workshop": "Quests", "Foes": "Quests", "Messages": "Quests", "Mail": "Quests", "Animals": "Party", "Chores": "Party"}
## Cursor key repeat: first delay, then every step (seconds, real time).
const REPEAT_FIRST := 0.35
const REPEAT_STEP := 0.09
## Highlight frame around the cursor's row.
const CURSOR_COL := Color(1, 0.85, 0.3)


## True while the current map is fading out to another (menus must not open then).
static func changing_map(tree: SceneTree) -> bool:
	var gm := tree.current_scene as GameMap
	return gm != null and gm._changing


func _switch_tab(t: String) -> void:
	if not is_inside_tree():
		return  # a body button changed scene; this menu is on its way out (C9 c9_10/c9_18)
	_tab = t
	_rebinding = ""
	_steal_warn = {}
	Music.instance(get_tree()).sfx("tab", "ui_tap")
	_refresh()


## B on a sub-page goes back one level; true when it did (the menu stays open).
func back_one() -> bool:
	if _rebinding != "":
		return false
	if SUB_PARENT.has(_tab):
		_switch_tab(str(SUB_PARENT[_tab]))
		return true
	if _tab == "Book" and CollectionScreen.back():
		Music.instance(get_tree()).sfx("tab", "ui_tap")
		_refresh()
		return true
	if _tab == "Skills" and _node_sel != "":
		_node_sel = ""
		_refresh()
		return true
	return false


func _exit_tree() -> void:
	# Freed while open (a scene change from a body row): never leave the next scene paused.
	if _open and get_tree():
		_open = false
		get_tree().paused = false


func _toast(text: String) -> void:
	var gm := get_tree().current_scene as GameMap
	if gm and gm.hud:
		gm.hud.toast(text, Color(1, 0.85, 0.6))


func _save_now() -> void:
	var gm := get_tree().current_scene as GameMap
	if gm and not gm._changing:
		gm.save_here()
	else:
		GameState.save()


## "Save and quit" only where quitting means something: native desktop/Deck builds.
static func quit_offered() -> bool:
	return not OS.has_feature("web") and not DisplayMode.is_phone()


## Options > This farm: a backup code of this farm (P5's GameState.export_code).
func _backup_row() -> void:
	if Net.visiting() or not _has_static(_sc("game_state"), "export_code"):
		return
	_button("Back up this farm (copy code)", func() -> void:
		_save_now()
		var code := str(_call_export())
		if code == "":
			_toast("Couldn't make a backup code.")
			return
		DisplayServer.clipboard_set(code)
		_toast("Backup code copied. Paste it somewhere safe; Save slots on the title screen restores it."))
	if _has_static(_sc("game_state"), "export_file"):
		_button("Back up this farm (save a file)", func() -> void:
			_save_now()
			_sc("game_state").call("export_file", GameState.slot()))


func _call_export() -> Variant:
	var sc := _sc("game_state")
	for md in sc.get_script_method_list():
		if str(md.get("name", "")) == "export_code":
			if (md.get("args", []) as Array).size() > 0:
				return sc.call("export_code", GameState.slot())
			return sc.call("export_code")
	return ""


## A script by name, so optional static API from other packages is called without
## a parse-time dependency.
static func _sc(name: String) -> Script:
	return load("res://scripts/%s.gd" % name) as Script


## The Options how-to line, per input: touch, mouse, keyboard, controller (C9 c9_02/c9_07).
static func help_text() -> String:
	var out: Array = []
	if DisplayMode.is_phone() or DisplayServer.is_touchscreen_available():
		out.append("Touch: joystick (drag anywhere) or tap where to go · USE = use your tool · CHECK = talk/pick up · ♥ = partner power · ROLL = dodge (near enemies) · tap the toolbar to pick an item")
	if not DisplayMode.is_phone():
		out.append("Mouse: left click = use tool toward the cursor · right click = check/talk · wheel = next item")
		out.append("Keys: %s move · %s use · %s check · %s confirm · %s run/back · %s menu · %s next item" % [
			"/".join([_k1("up"), _k1("left"), _k1("down"), _k1("right")]), _k1("tool"), _k1("action"), _k1("a"), _k1("b"), _k1("menu"), _k1("cycle_tool")])
	out.append("Controller: %s confirm · %s back · %s menu · %s/%s change tab · stick or d-pad moves the cursor" % [pad_name("a"), pad_name("b"), pad_name("menu"), pad_name("tab_prev"), pad_name("tab_next")])
	return "\n".join(out)


static func _k1(action: String) -> String:
	return InputSetup.key_label(action).split(" / ")[0]


static func action_label(action: String) -> String:
	for pair in InputSetup.SHOWN:
		if str(pair[0]) == action:
			return str(pair[1])
	return action.capitalize()


## The action (other than `action`) that already uses this key, or "".
static func key_owner(action: String, key: int) -> String:
	var map := InputSetup.keys()
	for other: String in map:
		if other != action and int(key) in (map[other] as Array):
			return other
	return ""


## Pad button name for an action through P1's InputSetup.pad_label when it exists.
static func pad_name(action: String) -> String:
	if _has_static(_sc("input_setup"), "pad_label"):
		return str(_sc("input_setup").call("pad_label", action))
	return {"a": "A", "b": "B", "menu": "Start", "tab_prev": "LB", "tab_next": "RB", "tool": "X", "action": "Y", "map": "View", "journal": "—", "cycle_tool": "RB", "dodge": "RT"}.get(action, "—")


## Pad rebind through P1's API; "" when done, else why it was refused.
## Back and Menu keep at least one button so a player can always get out.
static func pad_rebind(action: String, button: int) -> String:
	if not _has_static(_sc("input_setup"), "rebind_pad"):
		return "Controller buttons can't be changed in this build yet."
	for keep: String in ["b", "menu"]:
		if keep != action and _pad_only_button(keep, button):
			return "That button is the only one for %s; it stays there so you can always back out." % action_label(keep)
	_sc("input_setup").call("rebind_pad", action, button)
	return ""


static func _pad_only_button(action: String, button: int) -> bool:
	var n := 0
	var has := false
	for ev in InputMap.action_get_events(action) if InputMap.has_action(action) else []:
		if ev is InputEventJoypadButton:
			n += 1
			if int((ev as InputEventJoypadButton).button_index) == button:
				has = true
	return has and n <= 1


## Options > Controller buttons: every shown action with its pad button, rebind by pressing one.
func _pad_page() -> void:
	var have_pad := not Input.get_connected_joypads().is_empty()
	_line("Controller buttons. Pick a row, then press the new button on your controller. B or Menu on screen cancels." if have_pad else "No controller connected. Plug one in or pair it, then pick a row and press the new button.", 8, Color(0.8, 0.8, 0.8))
	var can := _has_static(_sc("input_setup"), "rebind_pad")
	for pair in InputSetup.SHOWN:
		var action: String = pair[0]
		if action in ["up", "down", "left", "right"]:
			continue  # movement stays on the stick and d-pad (nobody can lose it)
		var label: String = pair[1]
		var txt := "%-18s %s" % [label, pad_name(action)]
		if _rebinding == action:
			txt = "%-18s [press a button]" % label
		var b := _button(txt, func() -> void: _rebinding = action; _refresh())
		b.disabled = not can or not have_pad
	_line("Move: left stick or d-pad (fixed).", 8, Color(0.75, 0.75, 0.75))
	if can and _has_static(_sc("input_setup"), "reset_pad"):
		_button("Reset controller to defaults", func() -> void: _sc("input_setup").call("reset_pad"); _rebinding = ""; _refresh())
	_button("← Back to Options", func() -> void: _tab = "Options"; _rebinding = ""; _refresh())


# Cursor: a gold frame over one row/slot/tab. Hidden until a direction is pressed;
# a touch hides it again. A presses the framed button.
var _cur := -1  # index into _cursor_list(); -1 hidden
var _cur_tabs := false  # the frame is on the tab row
var _hold_dir := ""
var _hold_t := 0.0
var _hi: Control


func _ensure_tab_actions() -> void:
	# LB/RB (and [ ]) change tabs. P1 owns pad bindings; these are created only when missing.
	for pair in [["tab_prev", KEY_BRACKETLEFT, JOY_BUTTON_LEFT_SHOULDER], ["tab_next", KEY_BRACKETRIGHT, JOY_BUTTON_RIGHT_SHOULDER]]:
		if InputMap.has_action(str(pair[0])):
			continue
		InputMap.add_action(str(pair[0]), 0.5)
		var k := InputEventKey.new()
		k.physical_keycode = int(pair[1]) as Key
		InputMap.action_add_event(str(pair[0]), k)
		var j := InputEventJoypadButton.new()
		j.button_index = int(pair[2]) as JoyButton
		InputMap.action_add_event(str(pair[0]), j)


func _cursor_list() -> Array:
	var out: Array = []
	_collect(_body, out)
	return out


func _collect(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is BaseButton:
			var b := c as BaseButton
			if b.is_visible_in_tree() and not b.disabled and not b.is_queued_for_deletion():
				out.append(b)
			continue
		if c is Control and (c as Control).visible:
			_collect(c, out)


func _hide_cursor() -> void:
	_cur = -1
	_cur_tabs = false
	if _hi:
		_hi.queue_redraw()


func cursor_control() -> Control:
	if _cur_tabs:
		return _tab_buttons.get(_tab) as Control
	if _cur < 0:
		return null
	var l := _cursor_list()
	if l.is_empty():
		return null
	return l[clampi(_cur, 0, l.size() - 1)]


func _dir_pressed(delta: float) -> String:
	for d: String in ["up", "down", "left", "right"]:
		if Input.is_action_just_pressed(d):
			_hold_dir = d
			_hold_t = REPEAT_FIRST
			return d
	if _hold_dir != "" and Input.is_action_pressed(_hold_dir):
		_hold_t -= delta
		if _hold_t <= 0.0:
			_hold_t = REPEAT_STEP
			return _hold_dir
	elif _hold_dir != "" :
		_hold_dir = ""
	return ""


## Pad/keyboard menu play (C9 c9_02). True when it used this frame's input.
func _cursor_input(delta: float) -> bool:
	if _rebinding != "" or Engine.get_process_frames() - _opened_frame <= 2:
		return false
	if _hi == null:
		_ensure_tab_actions()
		_hi = Control.new()
		_hi.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hi.set_anchors_preset(Control.PRESET_FULL_RECT)
		_hi.draw.connect(_draw_cursor)
		add_child(_hi)
	_hi.queue_redraw()
	for pair in [["tab_prev", -1], ["tab_next", 1]]:
		if InputMap.has_action(str(pair[0])) and Input.is_action_just_pressed(str(pair[0])):
			step_tab(int(pair[1]))
			return true
	var d := _dir_pressed(delta)
	if d != "":
		move_cursor(d)
		return true
	if (_cur >= 0 or _cur_tabs) and InputSetup.confirm_pressed():
		press_cursor()
		return true
	# C10a P3: a control may offer a second press on TOOL (meta "menu_alt": Callable).
	if _cur >= 0 and not _cur_tabs and InputMap.has_action("tool") and Input.is_action_just_pressed("tool"):
		var c := cursor_control()
		if c and c.has_meta("menu_alt") and (c.get_meta("menu_alt") as Callable).is_valid():
			(c.get_meta("menu_alt") as Callable).call()
			return true
	return false


## LB/RB (or left/right on the tab row): the next or previous tab.
func step_tab(dir: int) -> void:
	var i := TABS.find(str(SUB_PARENT.get(_tab, _tab)))
	if i < 0:
		i = 0
	if not _cur_tabs and _cur >= 0:
		_cur = 0
	_switch_tab(str(TABS[(i + dir + TABS.size()) % TABS.size()]))


func move_cursor(d: String) -> void:
	if _cur_tabs:
		if d == "left" or d == "right":
			step_tab(-1 if d == "left" else 1)
		elif d == "down" and not _cursor_list().is_empty():
			_cur_tabs = false
			_cur = 0
		_after_move()
		return
	var l := _cursor_list()
	if _cur < 0:
		if l.is_empty():
			_cur_tabs = true
		else:
			_cur = 0
		_after_move()
		return
	_cur = clampi(_cur, 0, l.size() - 1)
	var nxt := _nearest(l, _cur, d)
	if nxt >= 0:
		_cur = nxt
	elif d == "up":
		_cur_tabs = true  # past the top row: onto the tabs
	_after_move()


func _after_move() -> void:
	var c := cursor_control()
	if c and not _cur_tabs:
		var sc := _body.get_parent() as ScrollContainer
		if sc:
			sc.ensure_control_visible(c)
	Music.instance(get_tree()).sfx("ui_tap", "pickup")
	if _hi:
		_hi.queue_redraw()


## The nearest control from l[from] in direction d (by rect centres), or -1.
## Rows of a list are walked one by one; grids (slots, skill trees) move spatially.
static func _nearest(l: Array, from: int, d: String) -> int:
	var a: Rect2 = (l[from] as Control).get_global_rect()
	var ac := a.get_center()
	var dv := {"up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}[d] as Vector2
	var best := -1
	var best_s := INF
	for i in l.size():
		if i == from:
			continue
		var r: Rect2 = (l[i] as Control).get_global_rect()
		var off := r.get_center() - ac
		var along := off.dot(dv)
		if along < 2.0:
			continue
		# Cross-axis gap between the two rects (0 when they overlap), so a wide row
		# reaches the small buttons right under it before a far row in line with it.
		var side := 0.0
		if dv.x == 0.0:
			side = maxf(0.0, maxf(r.position.x - a.end.x, a.position.x - r.end.x))
		else:
			side = maxf(0.0, maxf(r.position.y - a.end.y, a.position.y - r.end.y))
		var s := along + side * 2.5 + absf(off.dot(Vector2(dv.y, dv.x))) * 0.1
		if s < best_s:
			best_s = s
			best = i
	return best


func press_cursor() -> void:
	var c := cursor_control()
	if c == null:
		return
	if _cur_tabs:
		_cur_tabs = false
		_cur = 0 if not _cursor_list().is_empty() else -1
		if _cur < 0:
			_cur_tabs = true
		_after_move()
		return
	var b := c as BaseButton
	# Skills: A on the selected node learns a rank (same as its Learn button).
	if b.has_meta("skill_node") and str(b.get_meta("skill_node")) == _node_sel:
		for o in _cursor_list():
			if (o as BaseButton).has_meta("skill_buy"):
				(o as BaseButton).pressed.emit()
				return
		Music.instance(get_tree()).sfx("nope", "thud")
		return
	var pk := str(b.get_meta("pc_key", "")) if b.has_meta("pc_key") else ""
	b.pressed.emit()
	if pk != "":
		_cursor_to_key(pk)


## C10a P3: after a press rebuilt the page, put the cursor back on the control with that key
## (a Book group header adding a whole grid used to leave it on an unrelated cell).
func _cursor_to_key(pk: String) -> void:
	var l := _cursor_list()
	for i in l.size():
		var c := l[i] as Control
		if not c.is_queued_for_deletion() and c.has_meta("pc_key") and str(c.get_meta("pc_key")) == pk:
			_cur = i
			var sc := _body.get_parent() as ScrollContainer
			if sc:
				sc.ensure_control_visible.call_deferred(c)
			return


func _draw_cursor() -> void:
	var c := cursor_control()
	if c == null or not _panel.visible or not c.is_inside_tree():
		return
	var r := c.get_global_rect()
	# The overlay shares the layer's transform: global rects line up directly.
	r = Rect2(r.position - _hi.get_global_rect().position, r.size).grow(1)
	var a := 1.0 if Settings.reduced_motion() else 0.7 + 0.3 * sin(float(Time.get_ticks_msec()) * 0.008)
	_hi.draw_rect(r, Color(CURSOR_COL, a), false, 2.0)

class_name GameMenu
extends CanvasLayer
## The pause menu, laid out like Stardew's: tabs for Items, Skills, Social,
## Map, Quests and Options. Items shows the 12-slot toolbar plus the backpack;
## tap a backpack item to swap it into the selected toolbar slot.
## Pauses the game while open.

const TABS := ["Items", "Skills", "Pup", "Party", "Social", "Map", "Quests", "Options"]
const SLOT := 34

var _panel: PanelContainer
var _body: VBoxContainer
var _tabs: HBoxContainer
var _open := false
var _tab := "Items"
var _skill_open := ""
var _tab_buttons := {}


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
		if Art.has("ui", tab_icon):
			b.icon = Art.tex("ui", tab_icon)
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.tooltip_text = t
			b.custom_minimum_size = Vector2(0, 22)
			b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		else:
			b.text = t
			b.add_theme_font_size_override("font_size", 7)
			b.custom_minimum_size = Vector2(0, 18)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		b.pressed.connect(func() -> void: _tab = t; _rebinding = ""; _refresh())
		_tabs.add_child(b)
		_tab_buttons[t] = b
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 246)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 3)
	scroll.add_child(_body)
	var close := Button.new()
	close.text = "Close  (MENU / E)"
	close.add_theme_font_size_override("font_size", 8)
	close.pressed.connect(toggle)
	v.add_child(close)


var _rebinding := ""


func _input(event: InputEvent) -> void:
	if _rebinding == "" or not _panel.visible:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var k := event as InputEventKey
		if k.physical_keycode != KEY_ESCAPE:
			InputSetup.rebind(_rebinding, k.physical_keycode)
		_rebinding = ""
		get_viewport().set_input_as_handled()
		_refresh()


func _process(_delta: float) -> void:
	if Dialogue.instance(get_tree()).active:
		return
	if _rebinding != "":
		return
	# Stardew hotkeys: E/Esc toggles the menu (Items tab when opening), M opens
	# straight to the Map, F to the Journal; pressing the same key again closes.
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


func toggle() -> void:
	# Don't open over another paused screen (wardrobe, shop); closing then
	# would unpause the game under it.
	if not _open and get_tree().paused:
		return
	_open = not _open
	_rebinding = ""
	_panel.visible = _open
	if _open:
		_was_paused = get_tree().paused
		get_tree().paused = true
		_refresh()
	else:
		get_tree().paused = _was_paused
		Dialogue.block_input()


func _line(text: String, size := 9, color := Color(1, 0.96, 0.85)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(l)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 9)
	# Release mode: a finger that lands on a button to scroll the list must not
	# fire it (press mode fired "Save & back to title" when you scrolled Options).
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 18)
	b.pressed.connect(cb)
	_body.add_child(b)
	return b


func _slot_button(id: String, selected: bool, cb: Callable) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(SLOT, SLOT)
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
			tr.stretch_mode = TextureRect.STRETCH_SCALE
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
		if GameState.run["inventory"].has(id):
			var n := Label.new()
			n.text = str(int(GameState.run["inventory"][id]))
			n.add_theme_font_size_override("font_size", 7)
			n.add_theme_constant_override("outline_size", 2)
			n.add_theme_color_override("font_outline_color", Color.BLACK)
			n.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			n.offset_left = -14
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


func _grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 2)
	g.add_theme_constant_override("v_separation", 2)
	_body.add_child(g)
	return g


func _refresh() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	# Long rows used to stretch the panel off the right edge; pin it.
	_panel.size = Vector2(258, 320)
	_panel.call_deferred("set_size", Vector2(258, 320))
	for t in _tab_buttons:
		(_tab_buttons[t] as Button).modulate = Color(1, 0.9, 0.5) if t == _tab or (t == "Options" and _tab == "Keys") or (t == "Quests" and _tab in ["FieldLog", "Workshop", "Foes", "Messages", "Mail"]) else Color(0.85, 0.85, 0.85)
	var r := GameState.run
	match _tab:
		"Items":
			var slot := int(r["slot"])
			var tb: Array = r["toolbar"]
			var sel := str(tb[slot])
			_line("In hand: %s" % (GameState.item_name(sel) if sel != "" else "nothing"), 9)
			var g := _grid(6)
			for i in 12:
				var id := str(tb[i])
				g.add_child(_slot_button(id, i == slot, func() -> void: GameState.select_slot(i); _refresh()))
			_line("Backpack (tap to put in the selected slot)", 8, Color(0.9, 0.85, 0.7))
			var pack := GameState.backpack()
			var g2 := _grid(6)
			for id: String in pack:
				g2.add_child(_slot_button(id, false, func() -> void: _swap_into_toolbar(id)))
			for i in maxi(0, 12 - pack.size()):
				g2.add_child(_slot_button("", false, func() -> void: pass))
			if sel != "":
				var itd: Dictionary = GameState.items.get(sel, {})
				var rar := str(itd.get("rarity", "common"))
				_line("%s  ·  %s  ·  tier %d  ·  ◆%d" % [GameState.item_name(sel), rar, int(itd.get("tier", 1)), GameState.item_value(sel)], 8, GameState.rarity_color(sel))
				if itd.has("desc"):
					_line(str(itd["desc"]), 7, Color(0.8, 0.8, 0.8))
				if itd.has("heal") or itd.has("energy") or itd.has("mana") or itd.has("grow"):
					var what := "Drink" if str(itd.get("type", "")) == "tonic" else "Eat"
					_button("%s %s" % [what, GameState.item_name(sel)], func() -> void: _eat(sel))
				if str(itd.get("type", "")) == "equip":
					var st: Dictionary = itd.get("stats", {})
					_line("  " + ", ".join(st.keys().map(func(k: String) -> String: return "%s +%d" % [k, int(st[k])])), 7, Color(0.8, 0.9, 1.0))
					_button("Equip (%s)" % str(itd.get("slot", "")), func() -> void: GameState.equip(sel); _refresh_player(); _refresh())
			_line("Wearing", 8, Color(0.9, 0.85, 0.7))
			for eslot: String in GameState.SLOTS:
				var eid := GameState.equipped(eslot)
				if eid == "":
					_line("  %s: -" % eslot, 7, Color(0.6, 0.6, 0.6))
				else:
					_button("  %s: %s  (take off)" % [eslot, GameState.item_name(eid)], func() -> void: GameState.unequip(eslot); _refresh())
			var gs := "def %d  spd %d  luck %d  dmg %d  energy +%d" % [GameState.gear_stat("defense"), GameState.gear_stat("speed"), GameState.gear_stat("luck"), GameState.gear_stat("damage"), GameState.gear_stat("energy")]
			_line("  " + gs, 7, Color(0.8, 0.9, 1.0))
			_line("Tools: " + ", ".join(r["tools"].map(func(t: String) -> String: return GameState.item_name(t))), 7, Color(0.8, 0.8, 0.8))
		"Skills":
			_skills_tab()
		"Pup":
			_pup_tab()
		"Party":
			var pt := Companion.party()
			var act := Companion.active_id()
			if not GameState.is_penguins():
				_crew_tab()
			_line("Party", 10, Color(1, 0.95, 0.8))
			if (pt["known"] as Array).is_empty():
				_line("  Nobody yet. Partners find you as the story goes; some wait at the farm gate.", 7, Color(0.7, 0.7, 0.7))
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
					tb.pressed.connect(pick)
					h.add_child(tb)
					var col := VBoxContainer.new()
					col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					h.add_child(col)
					var nm := Label.new()
					nm.text = ("▶ " if cid == act else "") + str(cd.get("name", cid))
					nm.add_theme_font_size_override("font_size", 8)
					col.add_child(nm)
					var ab := Label.new()
					ab.text = "%s: %s" % [str(cd.get("ability_name", "")), str(cd.get("ability_desc", ""))]
					ab.add_theme_font_size_override("font_size", 6)
					ab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					ab.modulate = Color(0.85, 0.85, 0.8)
					col.add_child(ab)
					continue
				var b := _button("%s %s — %s: %s" % ["▶" if cid == act else "  ", str(cd.get("name", cid)), str(cd.get("ability_name", "")), str(cd.get("ability_desc", ""))], pick)
				b.add_theme_font_size_override("font_size", 7)
			if act != "":
				_line("  Tap the ♥ button to use the active partner's ability.", 7, Color(0.8, 0.8, 0.8))
			if not (pt["bitter"] as Array).is_empty():
				_line("Bitter", 9, Color(1, 0.7, 0.7))
				for cid in pt["bitter"]:
					_line("  %s hasn't been seen since you turned them away." % str(Companion.defs().get(cid, {}).get("name", cid)), 7, Color(0.9, 0.7, 0.7))
		"Social":
			var fr: Dictionary = r["friendship"]
			var full := Art.tex("ui", "pheart_full") if Art.has("ui", "pheart_full") else Art.tex("ui", "heart_full")
			var empty := Art.tex("ui", "pheart_empty") if Art.has("ui", "pheart_empty") else Art.tex("ui", "heart_empty")
			for id in GameState.npcs:
				var d: Dictionary = GameState.npcs[id]
				var pts := int(fr.get(id, 0))
				var h := HBoxContainer.new()
				_body.add_child(h)
				var pt := Art.tex("portraits/" + str(d.get("portrait", id)), "neutral")
				if pt:
					var tr := TextureRect.new()
					tr.texture = pt
					tr.custom_minimum_size = Vector2(22, 22)
					tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					h.add_child(tr)
				var l := Label.new()
				l.text = "%s\n%s" % [d["name"], d["role"]]
				l.add_theme_font_size_override("font_size", 8)
				l.custom_minimum_size = Vector2(70, 0)
				h.add_child(l)
				var hearts := HBoxContainer.new()
				hearts.add_theme_constant_override("separation", 0)
				h.add_child(hearts)
				for i in 10:
					var tr := TextureRect.new()
					tr.custom_minimum_size = Vector2(11, 11)
					tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
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
				var hates: Array = []
				for gi: String in seen:
					if int(seen[gi]) >= 12:
						loves.append(GameState.item_name(gi))
					elif int(seen[gi]) < 0:
						hates.append(GameState.item_name(gi))
				var nxt := ""
				for hh in [2, 4, 6, 8, 10]:
					if GameState.friend_hearts(str(id)) < hh and GameState.friend_perk_at(str(id), hh) != "":
						nxt = "♥%d: %s" % [hh, GameState.friend_perk_at(str(id), hh)]
						break
				var info := "   Birthday %s %d%s · loves: %s%s%s" % [str(bd[0]).capitalize() if bd.size() == 2 else "?", int(bd[1]) if bd.size() == 2 else 0, " (TODAY!)" if GameState.is_birthday(str(id)) else "", ", ".join(loves) if not loves.is_empty() else "? (give gifts to find out)", ("  · dislikes: " + ", ".join(hates)) if not hates.is_empty() else "", ("\n   next " + nxt) if nxt != "" else ""]
				_line(info, 6, Color(1, 0.9, 0.55) if GameState.is_birthday(str(id)) else Color(0.8, 0.8, 0.75))
		"Map":
			var m := Control.new()
			m.custom_minimum_size = Vector2(240, 300 if Art.has("ui", "world_map") else 190)
			m.draw.connect(func() -> void: _draw_map(m))
			_body.add_child(m)
			_line("You are in: %s" % str(r["scene"]).capitalize(), 8)
		"Quests":
			if r["quests"].is_empty():
				_line("No quests yet.")
			var mains: Array = GameState.quests_data.get("main", []).map(func(q: Dictionary) -> String: return str(q["id"]))
			_line("Story", 9, Color(1, 0.9, 0.5))
			for q in r["quests"]:
				if str(q["id"]) in mains or not GameState._quest_def(str(q["id"])).has("giver"):
					_line(("✓ " if q["done"] else "• ") + str(q["text"]), 9, Color(0.7, 0.9, 0.7) if q["done"] else Color(1, 0.96, 0.85))
			_line("Townsfolk", 9, Color(0.7, 0.9, 1.0))
			var any := false
			for q in r["quests"]:
				var dq := GameState._quest_def(str(q["id"]))
				if dq.has("giver"):
					any = true
					_line(("✓ " if q["done"] else "• ") + str(q["text"]), 9, Color(0.7, 0.9, 0.7) if q["done"] else Color(1, 0.96, 0.85))
			if not any:
				_line("  Talk to people in town; they'll ask for help. The plaza board has daily jobs.", 7, Color(0.7, 0.7, 0.7))
			var ws := Crafting.summary()
			var busy := 0
			for w in ws:
				busy += (w["jobs"] as Array).size()
			_button("Workshop: %d station%s, %d job%s running ›" % [ws.size(), "" if ws.size() == 1 else "s", busy, "" if busy == 1 else "s"], func() -> void: _tab = "Workshop"; _refresh())
			_button("Field log: %d of %d crops grown ›" % [(r.get("grown", {}) as Dictionary).size(), GameState.crops.size()], func() -> void: _tab = "FieldLog"; _refresh())
			_button("Foes & Gifts: %d kinds met ›" % (r.get("kill_counts", {}) as Dictionary).size(), func() -> void: _tab = "Foes"; _refresh())
			_button("Mail: %d unread ›" % Mail.unread(), func() -> void: _tab = "Mail"; _refresh())
			_button("Recent messages ›", func() -> void: _tab = "Messages"; _refresh())
			var hints: Array = r.get("hints", [])
			if not hints.is_empty():
				_line("Things people said (newest first)", 9, Color(0.95, 0.85, 1.0))
				var hs := hints.duplicate()
				hs.reverse()
				for hnt in hs.slice(0, 12):
					_line("  ✎ " + str(hnt), 7, Color(0.9, 0.85, 0.95))
		"Options":
			var arc_title: String = GameState.arcs.get(r["arc"], {}).get("title", "")
			_line("%s of %s · Pet: %s\n%s\nDay %d" % [r["names"]["character"], r["names"]["town"], r["names"]["pet"], arc_title, int(r["day"])])
			_button("All sound: %s" % ("off" if bool(SaveGame.get_value("muted", false)) else "on"), func() -> void: Music.instance(get_tree()).toggle_mute(); _refresh())
			for vk: String in ["music_vol", "sfx_vol", "amb_vol"]:
				var row := HBoxContainer.new()
				_body.add_child(row)
				var vl := Label.new()
				vl.text = "%s volume  %d/10" % [{"music_vol": "Music", "sfx_vol": "Sound", "amb_vol": "Nature"}[vk], int(Settings.get_v(vk))]
				vl.add_theme_font_size_override("font_size", 8)
				vl.custom_minimum_size = Vector2(110, 0)
				row.add_child(vl)
				for step: int in [-1, 1]:
					var bt := Button.new()
					bt.text = " − " if step < 0 else " + "
					bt.custom_minimum_size = Vector2(34, 22)
					bt.pressed.connect(func() -> void: Settings.set_v(vk, clampi(int(Settings.get_v(vk)) + step, 0, 10)); Music.instance(get_tree()).sfx("pickup"); _refresh())
					row.add_child(bt)
			_button("Night darkness: %s" % Settings.NIGHT_NAMES[clampi(int(Settings.get_v("night")), 0, 2)], func() -> void: Settings.set_v("night", (int(Settings.get_v("night")) + 1) % 3); _refresh())
			_button("Button size: %s" % Settings.BTN_NAMES[clampi(int(Settings.get_v("btn_size")), 0, 2)], func() -> void: Settings.set_v("btn_size", (int(Settings.get_v("btn_size")) + 1) % 3); _refresh())
			_button("Controls: %s-handed" % ("left" if Settings.left_handed() else "right"), func() -> void: Settings.set_v("left_handed", not Settings.left_handed()); _refresh())
			_button("Easy mode: %s" % ("on (foes hit softer, no fee when you faint)" if Settings.easy() else "off"), func() -> void: Settings.set_v("easy", not Settings.easy()); _refresh())
			_button("On-screen controls: %s" % ("shown" if TouchControls.visible_controls else "hidden"), func() -> void: TouchControls.visible_controls = not TouchControls.visible_controls; _refresh())
			_button("Key bindings…", func() -> void: _tab = "Keys"; _refresh())
			if r["flags"].has("epilogue_done"):
				_button("Replay the ending", func() -> void:
					toggle()
					var mp := get_tree().current_scene as GameMap
					if mp:
						Epilogue.play(mp))
			_button("Save & back to title", func() -> void:
				GameState.save()
				get_tree().paused = false
				get_tree().change_scene_to_file("res://scenes/title.tscn"))
			_line("Touch: joystick (drag anywhere on the left) or tap where to go · USE = use your tool · CHECK = talk/pick up · ♥ = partner power · ROLL = dodge (near enemies) · tap the toolbar to pick an item\nMouse: left click = use tool toward the cursor · right click = check/talk · wheel = next item", 7, Color(0.8, 0.8, 0.8))
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
				_line("No stations yet. The Plans board by your house lists every station: build each from materials or buy it ready-made.", 7, Color(0.8, 0.8, 0.8))
			for w in ws2:
				_line(str(w["head"]), 8, Color(1, 0.96, 0.85))
				for jl in w["jobs"]:
					_line("   ⏱ " + str(jl), 7, Color(0.75, 0.95, 0.75) if str(jl).ends_with("READY") else Color(0.8, 0.85, 0.95))
			var nxt: Array = []
			for bid in Builds.data():
				if Crafting.is_station(str(bid)) and not Builds.next_def(str(bid)).is_empty() and Builds.gate(str(bid)) == "" and nxt.size() < 4:
					nxt.append(str(Builds.next_def(str(bid))["name"]))
			if not nxt.is_empty():
				_line("Open to build now: " + ", ".join(nxt), 7, Color(0.8, 1, 0.7))
			_line("A better station runs more jobs at once, works faster, opens higher recipes, and sometimes turns out a bonus piece.", 7, Color(0.7, 0.7, 0.7))
			_button("← Back to Quests", func() -> void: _tab = "Quests"; _refresh())
		"Foes":
			var kc: Dictionary = r.get("kill_counts", {})
			var known: Dictionary = r.get("gifts_known", {})
			_line("Foes & Gifts · %d kinds beaten · %d Gifts read" % [kc.size(), known.size()], 9, Color(1, 0.85, 0.75))
			if not known.is_empty():
				_line("Gifts you've learned to beat", 8, Color(1, 0.95, 0.7))
				for gid in known:
					var g := Gift.def(str(gid))
					_line("  ✦ %s: %s" % [str(g.get("name", gid)), str(g.get("tip", ""))], 7, Color(1, 0.95, 0.85))
			if GameState.run.get("arc", "") == "gangsters":
				_line("The Marked", 8, Color(1, 0.9, 0.7))
				for mid in Marked.all():
					var md: Dictionary = Marked.all()[mid]
					var st := Marked.state(str(mid))
					var who := "%s \"%s\", %d" % [str(md["name"]), str(md["epithet"]), int(md["age"])] if st != "" else "??? (%s)" % str(md["scene"]).replace("_", " ")
					_line("  %s  %s" % [who, {"crew": "· in your crew", "free": "· went home"}.get(st, "")], 7, Color(0.95, 0.9, 1.0))
			_line("Beaten", 8, Color(0.9, 0.85, 1.0))
			var ks := kc.keys()
			ks.sort_custom(func(a: Variant, b: Variant) -> bool: return int(kc[a]) > int(kc[b]))
			for k in ks:
				var ed: Dictionary = GameState.enemy_data.get("enemies", {}).get(str(k), {})
				var nm := str(ed.get("name", str(k).replace("thug_", "").replace("marked_", "").replace("_", " ").capitalize()))
				_line("  %s ×%d · tier %d%s" % [nm, int(kc[k]), int(ed.get("tier", 0)), ("  · " + str(Gift.def(str(ed["gift"])).get("name", ""))) if ed.has("gift") else ""], 7, Color(0.85, 0.85, 0.9))
			_button("← Back to Quests", func() -> void: _tab = "Quests"; _refresh())
		"Mail":
			_line("Letters (newest first)", 9, Color(1, 0.9, 0.7))
			var ml: Array = Mail.list().duplicate()
			ml.reverse()
			if ml.is_empty():
				_line("  No letters yet. Folks write once they know you.", 7, Color(0.7, 0.7, 0.7))
			for m: Dictionary in ml:
				m["read"] = true
				_line("Day %d · %s" % [int(m.get("day", 0)), str(m["from"])], 8, Color(1, 0.95, 0.8))
				_line("  " + str(m["text"]), 7, Color(0.9, 0.9, 0.85))
				var mm := m
				if str(m.get("kind", "")) == "gift" and not bool(m.get("got", false)):
					_button("  Take the %s" % GameState.item_name(str(m["item"])), func() -> void:
						Mail.act(mm)
						_refresh())
				elif str(m.get("kind", "")) == "favour" and not bool(m.get("done", false)):
					_button("  Send %d %s for ◆%d (have %d)" % [int(m["n"]), GameState.item_name(str(m["item"])), int(m["pay"]), GameState.count(str(m["item"]))], func() -> void:
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
				_line("  " + str(t), 7, Color(0.9, 0.9, 0.9))
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
				_line("  " + ", ".join(parts), 7, Color(0.85, 0.85, 0.8))
			_line("(Names in brackets grow this season; look for their seeds at Maple's, Tam's, Old Moss's, Sel's%s.)" % (" and Catkins's" if GameState.is_penguins() else ""), 7, Color(0.7, 0.7, 0.7))
			_button("← Back to Quests", func() -> void: _tab = "Quests"; _refresh())
		"Keys":
			_line("Key bindings (Stardew defaults). Tap a row, then press the new key. Esc cancels.", 7, Color(0.8, 0.8, 0.8))
			for pair in InputSetup.SHOWN:
				var action: String = pair[0]
				var label: String = pair[1]
				var txt := "%-18s %s" % [label, InputSetup.key_label(action)]
				if _rebinding == action:
					txt = "%-18s [press a key]" % label
				_button(txt, func() -> void: _rebinding = action; _refresh())
			_button("Reset to defaults", func() -> void: InputSetup.reset_bindings(); _rebinding = ""; _refresh())
			_button("← Back to Options", func() -> void: _tab = "Options"; _rebinding = ""; _refresh())


## Sun Haven-style tree: tiers as rows, nodes as buttons you spend points on.
## Tier t opens after 3t points in the tree; branches need a parent rank.
func _skill_tree(sk: String) -> void:
	var free := GameState.points_free(sk)
	var spent := GameState.points_spent(sk)
	_line("  " + str(GameState.skills_data.get(sk, {}).get("desc", "")), 7, Color(0.85, 0.8, 0.7))
	_line("  Skill points: %d free · %d spent  (1 per level)" % [free, spent], 8, Color(1, 0.9, 0.5) if free > 0 else Color(0.8, 0.8, 0.8))
	var by_tier := {}
	for n in GameState.nodes_of(sk):
		var t := int(n.get("tier", 0))
		if not by_tier.has(t):
			by_tier[t] = []
		by_tier[t].append(n)
	var tiers := by_tier.keys()
	tiers.sort()
	for t in tiers:
		var open := spent >= int(t) * GameState.TIER_POINTS
		_line("  — Tier %d %s —" % [int(t) + 1, "" if open else "(locked: %d points in tree)" % (int(t) * GameState.TIER_POINTS)], 7, Color(0.9, 0.8, 0.5) if open else Color(0.5, 0.5, 0.5))
		var branches: Dictionary = GameState.skills_data.get(sk, {}).get("branches", {})
		for n in by_tier[t]:
			var id := str(n["id"])
			var rank := GameState.node_rank(sk, id)
			var br := str(branches.get(str(n.get("branch", "")), ""))
			if br != "":
				_line("    ◦ %s path" % br, 6, {"Light": Color(1, 0.95, 0.6), "Dream": Color(0.8, 0.85, 1.0), "Crystal": Color(0.7, 1.0, 0.9)}.get(br, Color(0.8, 0.8, 0.8)))
			var ranks := int(n.get("ranks", 1))
			var why := GameState.node_locked(sk, id)
			var mark := "★" if rank >= ranks else ("◆" if rank > 0 else ("+" if why == "" else "·"))
			var req := ""
			if n.has("requires"):
				var names: Array = []
				for r in n["requires"]:
					names.append(str(GameState.node(sk, str(r)).get("name", r)))
				req = "  ← " + " / ".join(names)
			var txt := "%s %s  %d/%d%s\n     %s%s" % [mark, str(n["name"]), rank, ranks, req, str(n["desc"]), ("" if why == "" or why == "maxed" else "   [%s]" % why)]
			var b := _button(txt, func() -> void:
				if GameState.buy_node(sk, id):
					Music.instance(get_tree()).sfx("levelup")
				_refresh())
			b.add_theme_font_size_override("font_size", 7)
			var nic := "node_%s_%s" % [sk, id]
			if Art.has("ui", nic):
				b.icon = Art.tex("ui", nic)
				b.expand_icon = true
				b.add_theme_constant_override("icon_max_width", 18)
			b.modulate = Color(1, 0.92, 0.6) if rank > 0 else (Color(1, 1, 1) if why == "" else Color(0.6, 0.6, 0.6))
	if sk == "magic":
		var kn := Spells.known()
		if kn.is_empty():
			_line("  Learn Spark or Deep Well to start casting.", 7, Color(0.8, 0.8, 0.8))
		else:
			_line("  Cast  (mana %d / %d)" % [int(GameState.run.get("mana", 0)), int(GameState.run.get("max_mana", 0))], 8, Color(0.6, 0.8, 1.0))
			for id in kn:
				var sp: Dictionary = Spells.SPELLS[id]
				var cb := _button("  ✦ %s  (%d mana) — %s" % [str(sp["name"]), Spells.cost_of(id), str(sp["desc"])], func() -> void:
					var m := get_tree().current_scene
					if m is GameMap:
						toggle()
						Spells.cast(m as GameMap, id))
				cb.add_theme_font_size_override("font_size", 7)
				if Art.has("ui", "spell_" + id):
					cb.icon = Art.tex("ui", "spell_" + id)
					cb.expand_icon = true
					cb.add_theme_constant_override("icon_max_width", 16)
	if spent > 0:
		_button("Reset this tree (refund all points)", func() -> void: GameState.reset_tree(sk); _refresh())


## Sun Haven-style skills page: a tab per skill, the level / points / EXP panel,
## and the tree as a grid of 4 branches x 10 tiers (I-X). Column N opens after
## 2N points spent in that skill. Tap a node to read it, then Learn.
const SKILL_ORDER := ["farming", "mining", "foraging", "fishing", "combat", "magic", "pup", "bartering", "building", "leadership", "strategist", "harmony", "hustle"]
const BRANCH_COL := [Color(0.32, 0.55, 0.25), Color(0.25, 0.42, 0.62), Color(0.6, 0.38, 0.22), Color(0.48, 0.3, 0.58)]
var _node_sel := ""
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
	"pet_bond": "bone", "team_xp": "luck_potion"}


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
		tb.text = str(GameState.skills_data[k]["name"])
		tb.add_theme_font_size_override("font_size", 7)
		tb.custom_minimum_size = Vector2(0, 16)
		tb.focus_mode = Control.FOCUS_NONE
		tb.modulate = Color(1, 0.88, 0.45) if k == sk else Color(0.78, 0.78, 0.78)
		var kk := str(k)
		tb.pressed.connect(func() -> void: _skill_open = kk; _node_sel = ""; _refresh())
		tabs.add_child(tb)
	# Level / points / EXP panel
	var lvl := GameState.skill_level(sk)
	var xp := int(GameState.run["skills"].get(sk, {}).get("xp", 0))
	var need := GameState.xp_for_next(lvl)
	var free := GameState.points_free(sk)
	var spent := GameState.points_spent(sk)
	var head := HBoxContainer.new()
	_body.add_child(head)
	var ic := Art.tex("ui", "skillbig_" + sk) if Art.has("ui", "skillbig_" + sk) else Art.tex("items", str({"farming": "hoe", "mining": "pickaxe", "foraging": "axe", "fishing": "rod", "combat": "sword", "magic": "crystal", "pup": "bone", "bartering": "gold", "building": "hammer", "leadership": "paw_charm", "strategist": "map", "harmony": "big_crystal", "hustle": "six_shooter"}.get(sk, "map")))
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
	l3.add_theme_font_size_override("font_size", 6)
	hv.add_child(l3)
	# The grid
	var by_cell := {}
	for n in GameState.nodes_of(sk):
		by_cell[Vector2i(int(n.get("tier", 0)), int(n.get("row", 0)))] = n
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	_body.add_child(grid)
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
	_line("Rows: " + " · ".join(names), 6, Color(0.8, 0.78, 0.7))
	# The picked node
	var sel := GameState.node(sk, _node_sel) if _node_sel != "" else {}
	if sel.is_empty():
		_line(str(sd.get("desc", "")), 7, Color(0.85, 0.8, 0.7))
		_line("Tap a node. Each tier column opens after 2 more points in this skill. 1 point per level.", 7, Color(0.75, 0.75, 0.75))
	else:
		var rank := GameState.node_rank(sk, _node_sel)
		var ranks := int(sel.get("ranks", 1))
		var why := GameState.node_locked(sk, _node_sel)
		_line("%s  ·  %s, tier %s  ·  %d/%d" % [str(sel["name"]), str(br.get(str(int(sel.get("row", 0))), "")), romans[int(sel.get("tier", 0))], rank, ranks], 9, Color(1, 0.92, 0.6))
		_line(str(sel["desc"]), 8, Color(0.95, 0.95, 0.9))
		var nid := _node_sel
		var lb := _button("Learn (1 point)" if why == "" else ("Maxed" if why == "maxed" else "Locked: " + why), func() -> void:
			if GameState.buy_node(sk, nid):
				Music.instance(get_tree()).sfx("levelup")
			_refresh())
		lb.disabled = why != ""
	if sk == "magic":
		_magic_casts()
	if spent > 0:
		_button("Reset this tree (refund all points)", func() -> void: GameState.reset_tree(sk); _node_sel = ""; _refresh())


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
			ik = {"farming": "hoe", "mining": "pickaxe", "foraging": "axe", "fishing": "rod", "combat": "sword", "magic": "crystal", "pup": "bone", "bartering": "gold", "building": "hammer", "leadership": "paw_charm", "strategist": "map", "harmony": "big_crystal", "hustle": "six_shooter"}.get(sk, "map")
		tr.texture = Art.tex("items", ik)
	if not col_open:
		tr.modulate = Color(0.4, 0.4, 0.4, 0.6)
	b.add_child(tr)
	var rl := Label.new()
	rl.text = "%d/%d" % [rank, ranks]
	rl.add_theme_font_size_override("font_size", 6)
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
	return b


func _magic_casts() -> void:
	var kn := Spells.known()
	if kn.is_empty():
		_line("Learn Spark or Deep Well to start casting.", 7, Color(0.8, 0.8, 0.8))
		return
	_line("Cast  (mana %d / %d)" % [int(GameState.run.get("mana", 0)), int(GameState.run.get("max_mana", 0))], 8, Color(0.6, 0.8, 1.0))
	for id in kn:
		var sp: Dictionary = Spells.SPELLS[id]
		var cb := _button("✦ %s  (%d mana) — %s" % [str(sp["name"]), Spells.cost_of(id), str(sp["desc"])], func() -> void:
			var m := get_tree().current_scene
			if m is GameMap:
				toggle()
				Spells.cast(m as GameMap, id))
		cb.add_theme_font_size_override("font_size", 7)


func _refresh_player() -> void:
	var m := get_tree().current_scene
	if m is GameMap and (m as GameMap).player:
		(m as GameMap).player.refresh_doll()


func _swap_into_toolbar(id: String) -> void:
	var r := GameState.run
	var tb: Array = r["toolbar"]
	var slot := int(r["slot"])
	var was := str(tb[slot])
	if GameState.has_tool(was):
		# Don't bump a tool; use the first free slot instead.
		var free := tb.find("")
		if free >= 0:
			tb[free] = id
			r["slot"] = free
		else:
			tb[slot] = id
	else:
		tb[slot] = id
	GameState.sync_selected()
	_refresh()


## The pup: health, level, commands, gear, pack, treats.
func _pup_tab() -> void:
	var st := Pet.state()
	var pname := Pet.name_of()
	var lvl := GameState.skill_level("pup")
	var sk: Dictionary = GameState.run["skills"].get("pup", {"level": 1, "xp": 0})
	var m := get_tree().current_scene
	var pt: Pet = (m as GameMap).pet as Pet if m is GameMap and (m as GameMap).pet is Pet else null
	if Pet.resting():
		_line("%s is resting at home after a rough day. Back %s." % [pname, "this afternoon" if GameState.bonus("pup", "best") > 0.0 else "tomorrow"], 9, Color(1, 0.85, 0.7))
	_line("%s  ·  Lv %d  (%d / %d xp)" % [pname, lvl, int(sk["xp"]), GameState.xp_for_next(lvl)], 10, Color(1, 0.95, 0.8))
	_line("Health %d / %d   ·   bite %d   ·   speed ×%.1f   ·   pack %d" % [int(st["hp"]), Pet.max_hp(), Pet.bite_damage(), Pet.speed_mult(), Pet.pack_size()], 8, Color(0.85, 1.0, 0.85))
	_line("Mode: %s" % str(st.get("mode", "follow")).to_upper(), 9, Color(1, 0.9, 0.5))
	var cmds := [["Heel (follow)", "follow"], ["Attack", "attack"], ["Guard here", "guard"], ["Stay", "wait"]]
	for c in cmds:
		var mode: String = c[1]
		var locked := (mode == "guard" and GameState.bonus("pup", "guard") <= 0.0)
		var b := _button(("  " if str(st.get("mode", "")) != mode else "▶ ") + str(c[0]) + ("   [needs Guard Dog]" if locked else ""), func() -> void:
			if locked or pt == null:
				return
			toggle()
			pt.set_mode(mode))
		var ic_name: String = {"follow": "cmd_heel", "attack": "cmd_attack", "guard": "cmd_guard", "wait": "cmd_stay"}.get(mode, "")
		if Art.has("ui", ic_name):
			b.icon = Art.tex("ui", ic_name)
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 16)
		if locked or pt == null:
			b.modulate = Color(0.6, 0.6, 0.6)
	_button("  Recall %s (from anywhere)" % pname, func() -> void:
		if pt == null:
			return
		toggle()
		pt.recall())
	_line("Gear", 9, Color(0.9, 0.85, 0.7))
	for slot: String in ["collar", "pack", "boots"]:
		var gid := str(st["gear"].get(slot, ""))
		if gid == "":
			_line("  %s: -" % slot, 7, Color(0.6, 0.6, 0.6))
		else:
			_button("  %s: %s  (take off)" % [slot, GameState.item_name(gid)], func() -> void:
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
				if old != "":
					GameState.add_item(old, 1)
				st["gear"][slot2] = id
				GameState.add_item(id, -1)
				if pt:
					pt.refresh_gear()
				_refresh())
		elif it.has("pet_heal"):
			_button("  Give %s (+%d health)" % [GameState.item_name(id), int(it["pet_heal"])], func() -> void:
				GameState.add_item(id, -1)
				st["hp"] = mini(Pet.max_hp(), int(st["hp"]) + int(it["pet_heal"]))
				if pt:
					pt._hp_bar.queue_redraw()
				_refresh())
	if not any_gear:
		_line("  Collars and packs come from the workbench and the smithy (pelts, rope, bars).", 7, Color(0.7, 0.7, 0.7))
	var cap := Pet.pack_size()
	if cap > 0:
		var pack: Dictionary = st["pack"]
		var used := 0
		for k in pack:
			used += 1
		_line("Pack  (%d / %d stacks)" % [used, cap], 9, Color(0.9, 0.85, 0.7))
		for id in pack.keys():
			_button("  Take %s x%d" % [GameState.item_name(id), int(pack[id])], func() -> void:
				GameState.add_item(id, int(pack[id]))
				pack.erase(id)
				_refresh())
		var sel := str(GameState.run["selected"])
		if sel != "" and GameState.count(sel) > 0 and used < cap and str(GameState.items.get(sel, {}).get("type", "")) != "tool":
			_button("  Give %s x%d to carry" % [GameState.item_name(sel), GameState.count(sel)], func() -> void:
				pack[sel] = int(pack.get(sel, 0)) + GameState.count(sel)
				GameState.add_item(sel, -GameState.count(sel))
				_refresh())
	if GameState.bonus("pup", "bedroll") > 0.0 and int(st.get("bedroll_day", 0)) != int(GameState.run["day"]) and pt and pt.visible:
		_button("  Rest by %s's bedroll (+20 energy, once a day)" % pname, func() -> void:
			st["bedroll_day"] = int(GameState.run["day"])
			GameState.restore_energy(20)
			_refresh())
	_line("Skill tree: see Skills → Pup.", 7, Color(0.7, 0.7, 0.7))


func _eat(id: String) -> void:
	# In a fight the menu doesn't stop the clock for snacks: one bite every 3
	# seconds, and the menu closes so you're back in it.
	var mp := get_tree().current_scene as GameMap
	if mp and mp.player:
		for e in mp.enemies:
			if is_instance_valid(e) and e.position.distance_to(mp.player.position) < 120.0:
				var now := Time.get_ticks_msec()
				if now < _food_ready:
					mp.hud.toast("Still chewing. (%.0fs)" % ((_food_ready - now) / 1000.0), Color(1, 0.85, 0.7))
					return
				_food_ready = now + 3000
				toggle()
				break
	var fx_out := GameState.consume(id)
	var m := get_tree().current_scene
	if m is GameMap and (m as GameMap).player:
		(m as GameMap).effect_text((m as GameMap).player.position, fx_out)
	Music.instance(get_tree()).sfx("eat", "pickup")
	if visible:
		_refresh()


var _food_ready := 0


const PINS := {"farm": Vector2(0.44, 0.47), "house": Vector2(0.40, 0.44), "town": Vector2(0.52, 0.70), "forest": Vector2(0.30, 0.24), "lake": Vector2(0.14, 0.40),
	"meadow": Vector2(0.66, 0.46), "crystal_meadow": Vector2(0.86, 0.40), "mine": Vector2(0.72, 0.20), "mountain": Vector2(0.74, 0.70), "beach": Vector2(0.40, 0.90), "moon": Vector2(0.90, 0.08),
	"wastes": Vector2(0.95, 0.26), "hideout": Vector2(0.95, 0.52), "docks": Vector2(0.86, 0.84), "neon": Vector2(0.72, 0.92), "uptown": Vector2(0.58, 0.96), "underground": Vector2(0.70, 0.98), "countryside": Vector2(0.98, 0.66),
	"sky": Vector2(0.28, 0.06), "station": Vector2(0.80, 0.03), "jungle": Vector2(0.66, 0.04),
	"orchard_hills": Vector2(0.24, 0.12), "highlands": Vector2(0.50, 0.12), "ruins": Vector2(0.60, 0.30), "quarry": Vector2(0.58, 0.84), "marsh": Vector2(0.22, 0.86), "riverlands": Vector2(0.08, 0.62)}
const PIN_ICON := {"farm": "pin_farm", "house": "pin_farm", "town": "pin_town", "forest": "pin_forest", "lake": "pin_lake", "meadow": "pin_meadow", "crystal_meadow": "pin_meadow", "mine": "pin_mine", "mountain": "pin_mountain", "beach": "pin_beach", "moon": "pin_moon",
	"wastes": "pin_wastes", "hideout": "pin_docks", "docks": "pin_docks", "neon": "pin_tower", "uptown": "pin_tower", "underground": "pin_mine", "countryside": "pin_farm", "sky": "pin_mountain", "station": "pin_moon", "jungle": "pin_forest",
	"orchard_hills": "pin_farm", "highlands": "pin_mountain", "ruins": "pin_wastes", "quarry": "pin_mine", "marsh": "pin_lake", "riverlands": "pin_lake"}
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
		m.draw_string(font, Vector2(b.position.x, b.position.y + b.size.y / 2 + 3), nm, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 7, Color(0.1, 0.1, 0.1))
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
	var area := Rect2(0, 0, 240, 300)
	# Fit the portrait painting into the panel, centred.
	var sc := minf(area.size.x / tex.get_width(), area.size.y / tex.get_height())
	var sz := Vector2(tex.get_width(), tex.get_height()) * sc
	var org := area.position + (area.size - sz) / 2.0
	m.draw_rect(area, Color(0.12, 0.1, 0.08))
	m.draw_texture_rect(tex, Rect2(org, sz), false)
	var here := str(GameState.run["scene"])
	var seen: Dictionary = GameState.run["flags"]
	var names := {"crystal_meadow": "East" if GameState.is_penguins() else "Outskirts", "underground": "Pit", "countryside": "Highway"}
	for k: String in PINS:
		var visited := k in ["farm", "house", "town", "meadow"] or seen.has(k + "_seen") or seen.has(str(SEEN_FLAG.get(k, "-")))
		if not visited:
			continue
		var p: Vector2 = org + (PINS[k] as Vector2) * sz
		var icon := str(PIN_ICON.get(k, ""))
		if icon != "" and Art.has("ui", icon):
			var it := Art.tex("ui", icon)
			var isz := Vector2(10, 12)
			m.draw_texture_rect(it, Rect2(p - Vector2(isz.x / 2, isz.y), isz), false, Color(1, 1, 1, 1.0 if k == here else 0.85))
		else:
			m.draw_circle(p, 3.0, Color(0.9, 0.3, 0.2))
		var nm := str(names.get(k, k.capitalize()))
		m.draw_string(font, p + Vector2(-20, 7), nm, HORIZONTAL_ALIGNMENT_CENTER, 40, 6, Color(0.1, 0.08, 0.05))
	if PINS.has(here):
		var p: Vector2 = org + (PINS[here] as Vector2) * sz
		m.draw_circle(p + Vector2(0, -6), 3.0, Color(1, 0.2, 0.2))
		m.draw_arc(p + Vector2(0, -6), 4.5, 0, TAU, 16, Color.WHITE, 1.0)


## The crew roster (Gangster's Paradise): everyone recruited, their loyalty
## hearts, rank chevron, badge and perk, on the roster panel art.
func _crew_tab() -> void:
	_line("Crew", 10, Color(1, 0.85, 0.7))
	var ids := Crew.all_recruited()
	if ids.is_empty():
		_line("  Nobody yet. People in the hideout and the districts want something before they'll join.", 7, Color(0.7, 0.7, 0.7))
		return
	for id in ids:
		var mdef: Dictionary = Crew.members()[id]
		var lv := Crew.loyalty(id)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		_body.add_child(h)
		var pt := Art.tex("portraits/" + id, "neutral")
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
		var perks: Array = mdef.get("perks", [])
		l.text = "%s — %s\n%s" % [str(mdef["name"]), str(mdef.get("role", "")), str(perks[lv - 1]) if lv > 0 and lv <= perks.size() else "no perk yet: talk at the hideout"]
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
		if Art.has("ui", "rank_%d" % (lv + 1)):
			var rk := TextureRect.new()
			rk.texture = Art.tex("ui", "rank_%d" % (lv + 1))
			rk.custom_minimum_size = Vector2(14, 12)
			rk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			h.add_child(rk)
	_line("")

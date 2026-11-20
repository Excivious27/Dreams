extends Control
## Title + new game flow: pick an arc, pick a character, name character/town/pet.
## Built from plain Controls so it works with touch and keyboard on the web build.

const FARM_SCENE := "res://scenes/farm.tscn"

var _arc := ""
var _playable := ""
var _arcs: Dictionary
var _playables: Dictionary
var _page: VBoxContainer
var _preview_holder: Control
var _scroll: ScrollContainer
var _preview: Node2D
var _name_edit: LineEdit
var _next_btn: Button
var _town_edit: LineEdit
var _pet_edit: LineEdit


func _ready() -> void:
	var nn := Net.i()
	if nn and (nn.online() or nn.room != "" or not nn._solo_backup.is_empty()):
		nn.leave()  # back at the title: put our own world back before any slot/new/restore
	Hud.skin_buttons(self)
	InputSetup.ensure_actions()
	_arcs = GameState.load_json("res://data/arcs.json")
	_playables = GameState.load_json("res://data/playable.json")
	var bg := Art.tex("ui", "title_keyart") if DisplayMode.wide() and Art.has("ui", "title_keyart") else Art.tex("ui", "title_portrait") if Art.has("ui", "title_portrait") else (Art.tex("ui", "title_keyart") if Art.has("ui", "title_keyart") else Art.tex("ui", "title_bg"))
	if bg:
		var tr := TextureRect.new()
		tr.texture = bg
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tr.set_anchors_preset(PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)
	else:
		var sky := Scenery.new()
		sky.overhead = false
		add_child(sky)
	Music.instance(get_tree()).play("title")
	Music.instance(get_tree()).set_duck(0.0)  # night/storm duck from the map
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.set_anchors_preset(PRESET_FULL_RECT)
	# Wide (desktop) view: the page stays a phone-width column in the middle.
	scroll.anchor_left = 0.5
	scroll.anchor_right = 0.5
	scroll.offset_left = -DisplayMode.BASE.x / 2.0
	scroll.offset_right = DisplayMode.BASE.x / 2.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	scroll.add_child(margin)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 8)
	_page.size_flags_horizontal = SIZE_EXPAND_FILL
	margin.add_child(_page)
	_show_title()


func _clear() -> void:
	for c in _page.get_children():
		c.queue_free()
	_preview = null


func _label(text: String, size: int = 10, center := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 4 if size > 14 else 2)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.15, 0.9))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	l.size_flags_horizontal = SIZE_EXPAND_FILL
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return l


func _button(text: String, on_press: Callable, big := false) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 11 if big else 9)
	b.add_theme_stylebox_override("normal", Hud.panel_stylebox("panel_wood"))
	b.add_theme_stylebox_override("hover", Hud.panel_stylebox("panel_wood"))
	b.add_theme_stylebox_override("pressed", Hud.panel_stylebox("panel_parchment"))
	b.custom_minimum_size = Vector2(0, 30 if big else 24)
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	b.pressed.connect(func() -> void: Music.instance(get_tree()).sfx("ui_tap"))
	b.pressed.connect(on_press)
	return b


func _show_title() -> void:
	_clear()
	if is_inside_tree():
		_mood(false)
		Music.instance(get_tree()).play("title")  # back from the save slots / sound page
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 150 if not Art.has("ui", "wordmark_glow") else 30)
	_page.add_child(spacer)
	if Art.has("ui", "wordmark_glow"):
		# The key art already carries the wordmark in the sky; add the glowing one as a crisp overlay.
		var wm := TextureRect.new()
		wm.texture = Art.tex("ui", "wordmark_glow")
		wm.custom_minimum_size = Vector2(0, 56)
		wm.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		wm.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		wm.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_page.add_child(wm)
	else:
		_page.add_child(_label("DREAMS", 36))
	_page.add_child(_label("a mystical farming adventure", 9))
	_page.add_child(_label("Two paths. One world. Every choice counts.", 8))
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 230 if not GameState.has_run() else 150)
	_page.add_child(spacer2)
	if GameState.has_run():
		var n: String = GameState.run["names"]["character"]
		_page.add_child(_button("Continue as %s" % n, _start_game, true))
	_page.add_child(_button("New game", _confirm_new if GameState.has_run() else _show_arcs, true))
	if GameState.has_run():
		_page.add_child(_button("Play together", _show_net))
	var prev: Variant = SaveGame.get_value(GameState.prev_key(), null)
	if prev is Dictionary and not (prev as Dictionary).is_empty():
		var pn := str((prev as Dictionary).get("names", {}).get("character", "?"))
		_page.add_child(_button("Restore %s (day %d)" % [pn, int((prev as Dictionary).get("day", 1))], _restore_prev))
	_page.add_child(_button("Save slots (slot %d)" % GameState.slot(), _show_slots))
	_page.add_child(_button("Sound", _show_sound))
	if OS.is_debug_build():
		_page.add_child(_button("Character test map", func() -> void: get_tree().change_scene_to_file("res://scenes/test_map.tscn")))


## Volumes and mute before any save is loaded (the title song plays first).
func _show_sound() -> void:
	_clear()
	_page.add_child(_label("Sound", 16))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	_page.add_child(box)
	Settings.audio_rows(box, get_tree(), _show_sound)
	_page.add_child(_button("Back", _show_title))


func _show_slots(msg := "") -> void:
	_clear()
	if is_inside_tree():
		Music.instance(get_tree()).play("title_musicbox" if Music.has_track("title_musicbox") else "title")
	_page.add_child(_label("Save slots", 16))
	_page.add_child(_label("Three farms side by side. Tap one to play it.", 8, false))
	for n in SaveTransfer.SLOTS:
		var here: bool = int(n) == GameState.slot()
		_page.add_child(_button("%s%d: %s" % ["▶ " if here else "", n, GameState.slot_info(n)], func() -> void:
			GameState.use_slot(n)
			_show_title(), here))
		if GameState.slot_info(n) != "Empty":
			_page.add_child(_pair("Copy slot %d's code" % n, func() -> void: _export_code(n),
				"Save to a file", func() -> void: _export_file(SaveTransfer.encode_slot(n))))
	_page.add_child(_label("Move or back up a farm", 11))
	_page.add_child(_label("Keep a code or file somewhere safe, then load it here or on another phone or computer. Loading goes into slot %d (you'll be asked first)." % GameState.slot(), 8, false))
	if OS.has_feature("web"):
		_page.add_child(_button("Paste a save code", func() -> void:
			SaveTransfer.web_paste(func(txt: String) -> void:
				if txt.strip_edges() != "":
					_try_load(txt))))
	else:
		_slot_code = TextEdit.new()
		_slot_code.placeholder_text = "Paste a save code here"
		_slot_code.custom_minimum_size = Vector2(220, 46)
		_slot_code.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		_slot_code.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		_slot_code.add_theme_font_size_override("font_size", 7)
		_field_style(_slot_code)
		_page.add_child(_slot_code)
		_slot_code.text_changed.connect(func() -> void:
			var t := _slot_code.text
			if t.strip_edges() == "":
				_slot_msg.text = ""
				return
			var d := SaveTransfer.decode(t)
			_slot_msg.text = ("Looks good: " + _code_summary(d)) if bool(d["ok"]) else str(d["why"]))
		_page.add_child(_pair("Load the code", func() -> void: _try_load(_slot_code.text),
			"Clear", func() -> void:
				_slot_code.text = ""
				_slot_msg.text = ""))
	_page.add_child(_button("Load from a file", func() -> void:
		SaveTransfer.open_file(self, func(txt: String) -> void:
			if txt.strip_edges() != "":
				_try_load(txt))))
	_page.add_child(_button("Back up all farms to a file", func() -> void:
		var all := SaveTransfer.encode_all()
		if all == "":
			_slot_msg.text = "There are no farms to back up yet."
		else:
			_export_file(all)))
	if SaveTransfer.ios_tab():
		_page.add_child(_label("On iPhone, add Dreams to your Home Screen (Share > Add to Home Screen): Safari can clear a tab's farms after a week away. Keep a backup file too.", 8, false))
	_slot_msg = _label(msg, 8, false)
	_page.add_child(_slot_msg)
	_page.add_child(_button("Back", _show_title))


var _slot_code: TextEdit
var _slot_msg: Label


## Two buttons side by side (per-slot export, load/clear).
func _pair(t1: String, f1: Callable, t2: String, f2: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(_button(t1, f1))
	row.add_child(_button(t2, f2))
	return row


func _code_summary(d: Dictionary) -> String:
	if str(d.get("kind", "")) == "all":
		var data: Dictionary = d["data"]
		return "a backup of %d farm%s" % [(data["slots"] as Dictionary).size(), "" if (data["slots"] as Dictionary).size() == 1 else "s"]
	return SaveTransfer.summary(d["data"])


func _export_code(n: int) -> void:
	var code := SaveTransfer.encode_slot(n)
	if code == "":
		_slot_msg.text = str(SaveTransfer.WHY["no_farm"])
		return
	if OS.has_feature("web"):
		# Phones only allow copying from the tap itself: show the code in a
		# real page box with the phone's own Copy / Share / Save file.
		SaveTransfer.web_code_box(code)
		_slot_msg.text = "Your code is on screen: Copy, Share or Save it somewhere safe."
	else:
		DisplayServer.clipboard_set(code)
		_slot_msg.text = "Copied slot %d's code. Paste it somewhere safe (a note or a message to yourself)." % n


func _export_file(code: String) -> void:
	if code == "":
		_slot_msg.text = str(SaveTransfer.WHY["no_farm"])
		return
	SaveTransfer.save_file(self, code, func(ok: bool, where: String) -> void:
		if is_instance_valid(_slot_msg):
			_slot_msg.text = ("Saved %s. Keep it somewhere safe." % where) if ok else ("" if where == "" else "That file couldn't be written."))


## A pasted/loaded code: check it, then ask before anything is replaced.
func _try_load(text: String) -> void:
	var d := SaveTransfer.decode(text)
	if not bool(d["ok"]):
		_slot_msg.text = str(d["why"])
		return
	if str(d["kind"]) == "all":
		_confirm_all(d["data"])
	else:
		_confirm_one(d["data"], GameState.slot())


func _confirm_one(farm: Dictionary, n: int) -> void:
	var plan := SaveTransfer.plan_one(farm, n)
	if bool(plan["same"]):
		_show_slots(SaveTransfer.confirm_text(farm, n))
		return
	if str(plan["replaces"]) == "":
		_finish_one(farm, n)  # empty slot: nothing to lose, no question
		return
	_clear()
	_page.add_child(_label("Load this farm?", 16))
	_page.add_child(_label(SaveTransfer.confirm_text(farm, n), 8, false))
	_page.add_child(_button("Replace slot %d" % n, func() -> void: _finish_one(farm, n), true))
	for e in SaveTransfer.empty_slots():
		_page.add_child(_button("Put it in empty slot %d instead" % int(e), func() -> void: _finish_one(farm, int(e))))
	_page.add_child(_button("Back", _show_slots))


func _finish_one(farm: Dictionary, n: int) -> void:
	var r := SaveTransfer.apply_one(farm, n)
	_show_slots(SaveTransfer.done_text(r, n))  # rebuilt, so the slot list shows the new farm


func _confirm_all(data: Dictionary) -> void:
	_clear()
	_page.add_child(_label("Load the backup?", 16))
	var lines: Array = []
	for n in SaveTransfer.SLOTS:
		var f: Dictionary = (data["slots"] as Dictionary).get(str(n), {})
		if f.is_empty():
			lines.append("Slot %d: not in the backup, left as it is." % n)
			continue
		var cur := SaveTransfer.farm_of(n)
		if SaveTransfer.same_farm(cur, f):
			lines.append("Slot %d: already holds %s." % [n, SaveTransfer.summary(f)])
		elif cur.is_empty():
			lines.append("Slot %d: %s." % [n, SaveTransfer.summary(f)])
		else:
			lines.append("Slot %d: %s replaces %s (who moves to Restore)." % [n, SaveTransfer.summary(f), SaveTransfer.summary(cur)])
	_page.add_child(_label("\n".join(lines), 8, false))
	_page.add_child(_button("Load the backup", func() -> void:
		var r := SaveTransfer.apply_all(data)
		_show_slots(("Loaded the backup into slot%s %s." % ["" if (r["loaded"] as Array).size() == 1 else "s", ", ".join((r["loaded"] as Array).map(func(x: Variant) -> String: return str(x)))]) if bool(r["ok"]) and not (r["loaded"] as Array).is_empty() else ("Every farm in the backup is already here." if bool(r["ok"]) else str(r["why"]))), true))
	_page.add_child(_button("Back", _show_slots))


## Starting over never loses a farm: the current one is kept to restore.
func _confirm_new() -> void:
	_clear()
	_page.add_child(_label("Start a new game?", 16))
	_page.add_child(_label("%s's farm (day %d) will be kept, and you can bring it back from the title screen with Restore. Only the most recent one is kept." % [str(GameState.run["names"]["character"]), int(GameState.run.get("day", 1))], 8, false))
	_page.add_child(_button("Yes, start fresh", func() -> void:
		_show_arcs(), true))  # the old farm goes to Restore only once the new one really starts (_begin)
	_page.add_child(_button("Back", _show_title))


func _restore_prev() -> void:
	var prev: Variant = SaveGame.get_value(GameState.prev_key(), null)
	if not prev is Dictionary:
		return
	var cur: Dictionary = GameState.run.duplicate(true) if GameState.has_run() else {}
	GameState.run = {}
	SaveGame.set_value(GameState.save_key(), (prev as Dictionary).duplicate(true))
	GameState.has_run()   # loads and migrates it
	if not cur.is_empty():
		SaveGame.set_value(GameState.prev_key(), cur)  # swap, so nothing is ever lost
	_show_title()


var _net_url: LineEdit
var _net_code: LineEdit
var _net_status: Label


func _show_net() -> void:
	_clear()
	_page.add_child(_label("Play together", 16))
	_page.add_child(_label("Up to 8 players. The host's farm is the world; everyone keeps their own character, skills and pack. Different arcs can play together: you'll each see your own story scenes.", 8, false))
	_net_url = _edit("Server (wss://...)", str(SaveGame.get_value("net_url", "")))
	_net_url.max_length = 120
	_net_code = _edit("Room code (to join)", "")
	_net_code.max_length = 4
	_net_status = _label("", 8, false)
	_page.add_child(_button("Host a room", func() -> void:
		_net_status.text = "Connecting..."
		Net.host(_net_url.text), true))
	_page.add_child(_button("Join with code", func() -> void:
		_net_status.text = "Connecting..."
		Net.join(_net_url.text, _net_code.text), true))
	_page.add_child(_button("Back", func() -> void:
		Net.leave()  # a connect that lands after Back must not start a game
		_show_title()))
	if not Net.connected.is_connected(_on_net_connected):
		Net.connected.connect(_on_net_connected)
		Net.disconnected.connect(func(why: String) -> void:
			if is_instance_valid(_net_status):
				_net_status.text = why)


func _on_net_connected(is_host: bool) -> void:
	if not is_instance_valid(_net_status) or not _net_status.is_inside_tree():
		return  # left the page
	if is_instance_valid(_net_status):
		_net_status.text = "Connected. Room %s. %s" % [Net.room, "You're hosting; share the code." if is_host else "Joined."]
	await get_tree().create_timer(0.8).timeout
	if Net.room != "":
		_start_game()


func _show_arcs() -> void:
	_clear()
	_look_full = {}  # a look is made for one arc's outfit; a new arc starts fresh
	_playable = ""
	_mood(false)
	Music.instance(get_tree()).play("title")
	Music.instance(get_tree()).set_duck(0.0)  # night/storm duck from the map
	_page.add_child(_label("Choose your path", 16))
	for arc_id: String in _arcs:
		var arc: Dictionary = _arcs[arc_id]
		var panel := PanelContainer.new()
		var v := VBoxContainer.new()
		panel.add_child(v)
		v.add_child(_label(str(arc["title"]), 12))
		v.add_child(_label(str(arc["tagline"]), 8))
		v.add_child(_arc_faces(arc_id, arc.get("faces", [])))
		if arc.has("feel"):
			var fl := _label(str(arc["feel"]), 8)
			fl.add_theme_color_override("font_color", Color(1, 0.88, 0.55))
			v.add_child(fl)
		for line in arc.get("pitch", []):
			v.add_child(_label("•  " + str(line), 8, false))
		v.add_child(_button("Choose", func() -> void: _arc = arc_id; _show_characters()))
		_page.add_child(panel)
	_page.add_child(_label("Both paths share the farm, the town and its people. Each save slot keeps its own path, so you can play the other one later.", 7))
	_page.add_child(_button("Back", _show_title))


## A row of the path's heroes on the arc card, so the choice shows who you'll be.
func _arc_faces(arc_id: String, pids: Array) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for pid in pids:
		var sprite_id := GameState.sprite_for_playable(str(pid), arc_id)
		if sprite_id == "":
			continue
		var tex: Texture2D = null
		if arc_id == "gangsters" and Art.has("portraits/" + sprite_id, "neutral"):
			tex = Art.tex("portraits/" + sprite_id, "neutral")
		else:
			var sf := CharacterLibrary.frames_for(sprite_id)
			for a in ["view_front", "idle", "walk_down"]:
				if sf.has_animation(a) and sf.get_frame_count(a) > 0:
					tex = sf.get_frame_texture(a, 0)
					break
		if tex == null:
			continue
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(34, 40)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tr)
	return row


## The gangster path is told at night: the picker goes dark with it.
func _mood(dark: bool) -> void:
	if _shade == null:
		_shade = ColorRect.new()
		_shade.set_anchors_preset(PRESET_FULL_RECT)
		_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_shade)
		move_child(_shade, 1)
	_shade.color = Color(0.03, 0.03, 0.07, 0.72) if dark else Color(0, 0, 0, 0)


var _shade: ColorRect


func _show_characters() -> void:
	_clear()
	_mood(_arc == "gangsters")
	# Choosing an arc switches to its theme (crossfades); Back returns to "title".
	var arc_track := "arc_" + _arc
	Music.instance(get_tree()).play(arc_track if Music.has_track(arc_track) else "title")
	_page.add_child(_label("Who are you?", 16))
	_preview_holder = Control.new()
	_preview_holder.custom_minimum_size = Vector2(0, 80)
	_name_lbl = null
	_cards = {}
	_page.add_child(_preview_holder)
	var ids: Array = _arcs[_arc]["playable"]
	var cards := Art.has("ui", "card_hero_dad")
	var grid := GridContainer.new()
	grid.columns = 4 if cards else 2
	grid.size_flags_horizontal = SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	_page.add_child(_label("Tap a card to pick a hero, or build your own (last card).", 8))
	_page.add_child(grid)
	for pid: String in ids:
		var p: Dictionary = _playables.get(pid, {})
		var name := str(p.get("name", pid))
		if bool(p.get("placeholder", false)):
			name += " (art soon)"
		var card_name := "card_hero_" + pid + ("_gang" if _arc == "gangsters" and Art.has("ui", "card_hero_" + pid + "_gang") else "")
		# A hero redrawn for the underworld shows the new art, not the old painted card.
		var gsprite := GameState.sprite_for_playable(pid, _arc)
		var redrawn := _arc == "gangsters" and gsprite.ends_with("_gang") and Art.has("characters/" + gsprite, "swim") and Art.has("characters/" + gsprite, "ride")
		_cards.erase(pid)
		if redrawn or pid in STALE_CARDS:
			grid.add_child(_sprite_card(pid, name))
		elif cards and Art.has("ui", card_name):
			var tb := TextureButton.new()
			tb.texture_normal = Art.tex("ui", card_name)
			tb.ignore_texture_size = true
			tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			tb.custom_minimum_size = Vector2(56, 78)
			tb.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			tb.tooltip_text = name
			tb.pressed.connect(func() -> void: _pick(pid))
			# Name on the card (phones show no tooltips).
			var tl := Label.new()
			tl.text = name.get_slice(" (", 0)
			tl.add_theme_font_size_override("font_size", 8)
			tl.add_theme_constant_override("outline_size", 3)
			tl.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.05))
			tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tl.set_anchors_preset(PRESET_BOTTOM_WIDE)
			tl.offset_top = -13
			tl.offset_bottom = 1
			tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tb.add_child(tl)
			grid.add_child(tb)
			_cards[pid] = tb
		else:
			grid.add_child(_sprite_card(pid, name) if cards else _button(name, func() -> void: _pick(pid)))
	_page.add_child(_button("Back", _show_arcs))
	_pick(_playable if _playable in ids else ids[0])


## A hero with no painted card yet: a parchment card with their own sprite on it.
func _sprite_card(pid: String, name: String) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(56, 78)
	b.tooltip_text = name
	b.clip_contents = true
	for st in ["normal", "hover", "pressed", "focus"]:
		if _arc == "gangsters":
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.09, 0.09, 0.14)
			sb.border_color = Color(0.62, 0.5, 0.26) if st != "pressed" else Color(0.9, 0.75, 0.4)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(3)
			b.add_theme_stylebox_override(st, sb)
		else:
			# Drawn parchment (the painted panel art showed as a flat grey box at this size).
			var ps := StyleBoxFlat.new()
			ps.bg_color = Color("ead2a2") if st != "pressed" else Color("fff1b8")
			ps.border_color = Color("6b4423")
			ps.set_border_width_all(3)
			ps.set_corner_radius_all(4)
			b.add_theme_stylebox_override(st, ps)
	b.pressed.connect(func() -> void: _pick(pid))
	_cards[pid] = b
	var sprite_id := GameState.sprite_for_playable(pid, _arc)
	var tex: Texture2D = null
	if sprite_id != "":
		var sf := CharacterLibrary.frames_for(sprite_id)
		for a in ["view_front", "idle", "walk_down"]:
			if sf.has_animation(a) and sf.get_frame_count(a) > 0:
				tex = sf.get_frame_texture(a, 0)
				break
	if _arc == "gangsters" and Art.has("portraits/" + sprite_id, "neutral"):
		tex = Art.tex("portraits/" + sprite_id, "neutral")
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tr.set_anchors_preset(PRESET_FULL_RECT)
		tr.offset_left = 7; tr.offset_right = -7; tr.offset_top = 9; tr.offset_bottom = -9
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tr)
		if _arc == "gangsters":
			# Name under the portrait (phones show no tooltips).
			tr.offset_bottom = -20
			var nl := Label.new()
			nl.text = name.get_slice(" (", 0)
			nl.add_theme_font_size_override("font_size", 8)  # at 7 "cl" merges ("Unde Rafe")
			nl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
			nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nl.set_anchors_preset(PRESET_BOTTOM_WIDE)
			nl.offset_top = -21
			nl.offset_bottom = -3
			nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(nl)
	else:
		b.text = name
		b.add_theme_font_size_override("font_size", 7)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return b


## Painted cards that no longer match the hero's current look: show a sprite card.
const STALE_CARDS := ["penguin_m", "penguin_f"]
var _cards := {}
var _name_lbl: Label


func _pick(pid: String) -> void:
	var same := pid == _playable and not _look_full.is_empty()
	_playable = pid
	# Phones never show tooltips: say who's picked, and light up their card.
	for k: String in _cards:
		var cc: Control = _cards[k]
		if is_instance_valid(cc):
			cc.modulate = Color(1.15, 1.1, 0.95) if k == pid else Color(0.72, 0.72, 0.78)
		if cc is Button and _arc == "gangsters" and is_instance_valid(cc):
			var nsb := (cc as Button).get_theme_stylebox("normal")
			if nsb is StyleBoxFlat:
				var sb := (nsb as StyleBoxFlat).duplicate() as StyleBoxFlat
				sb.border_color = Color(1, 0.82, 0.35) if k == pid else Color(0.62, 0.5, 0.26)
				sb.set_border_width_all(3 if k == pid else 2)
				(cc as Button).add_theme_stylebox_override("normal", sb)
	if _name_lbl == null or not is_instance_valid(_name_lbl):
		_name_lbl = Label.new()
		_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_lbl.add_theme_font_size_override("font_size", 9)
		_name_lbl.add_theme_constant_override("outline_size", 3)
		_name_lbl.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.05))
		_name_lbl.set_anchors_preset(PRESET_BOTTOM_WIDE)
		_name_lbl.offset_top = -12
		_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_preview_holder.add_child(_name_lbl)
	var pd: Dictionary = _playables.get(pid, {})
	_name_lbl.text = str(pd.get("name", pid)) + ("  ·  " + str(pd.get("role", "")) if str(pd.get("role", "")) != "" else "")
	if _preview:
		_preview.queue_free()
	_preview = Node2D.new()
	_preview.position = Vector2(_preview_holder.size.x / 2.0 if _preview_holder.size.x > 0 else 123, 62)
	_preview_holder.add_child(_preview)
	var sprite_id := GameState.sprite_for_playable(pid, _arc)
	if not same:
		_look_full = {}  # a new pick starts clean; the look is only for penguins and custom heroes
	if bool(_playables[pid].get("custom", false)) and PaperDoll.available():
		# Build-your-own: preview a paper doll (the look you made, coming back).
		var rl := PaperDoll.random_look()
		rl["outfit"] = "outfit_neon" if _arc == "gangsters" else "outfit_farmer"  # the preview matches the game
		var cr := Creator.new(_look_full if _look_full.has("body") else rl, "", false)
		_preview.add_child(cr)
		cr.visible = false
		PaperDoll.preview_bare = true  # a loaded run's armour must not dress the new hero
		var body := AnimatedSprite2D.new()
		body.sprite_frames = PaperDoll.body_frames(cr.look)
		body.centered = true
		body.offset = Vector2(0, -48)
		var h := float(PaperDoll.anchor_of("body", PaperDoll.body_for(cr.look), 0)[4])
		var sc := 1.6 * CharacterLibrary.HERO_H / maxf(40.0, h)
		body.scale = Vector2(sc, sc)
		body.play("walk_down")
		body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_preview.add_child(body)
		# The same hair (and hat) layers as the creator, so the first look isn't bald.
		var lk: Dictionary = cr.look
		var hair := Sprite2D.new()
		hair.material = PaperDoll.hair_material(str(lk.get("hair_color", "brown")))
		hair.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var hat := Sprite2D.new()
		hat.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_preview.add_child(hair)
		_preview.add_child(hat)
		var upd := func() -> void:
			var pose := PaperDoll.pose_index(body.animation, body.frame)
			PaperDoll.preview_bare = true
			PaperDoll.place_layer(hair, "hair", str(lk.get("hair", "")), PaperDoll.body_for(lk), pose, false, sc)
			PaperDoll.place_layer(hat, "hats", str(lk.get("hat", "")), PaperDoll.body_for(lk), pose, false, sc)
			PaperDoll.preview_bare = false
		body.frame_changed.connect(upd)
		upd.call()
		PaperDoll.preview_bare = false
		_look_full = cr.look.duplicate()
	elif sprite_id != "":
		var s := CharacterLibrary.make_sprite(sprite_id)
		s.scale *= 1.6
		s.play("idle")
		_preview.add_child(s)
	else:
		var ph := PlaceholderSprite.new()
		ph.tint = Color(str(_playables[pid].get("color", "888888")))
		ph.scale = Vector2(1.6, 1.6)
		_preview.add_child(ph)
	if is_instance_valid(_next_btn):
		_page.remove_child(_next_btn)
		_next_btn.queue_free()
	var is_custom := bool(_playables[pid].get("custom", false))
	var is_penguin := sprite_id == "penguin"
	_next_btn = _button("Next: your look" if (is_custom or is_penguin) else "Next: names", _show_look if (is_custom or is_penguin) else _show_names, true)
	_next_btn.name = "NextBtn"
	_page.add_child(_next_btn)
	# Right under the preview, so the picked hero, their name and Next are together.
	if is_instance_valid(_preview_holder) and _preview_holder.get_parent() == _page:
		_page.move_child(_next_btn, _preview_holder.get_index() + 1)
		if _scroll:
			_scroll.set_deferred("scroll_vertical", 0)
	else:
		_page.move_child(_next_btn, _page.get_child_count() - 2)


const LOOKS := {
	"skin": [["Fair", "ffffff"], ["Warm", "f3d9c0"], ["Tan", "e2b78f"], ["Deep", "b98a62"]],
	"outfit": [["Blue", "ffffff"], ["Red", "ffb0a0"], ["Green", "b8ffb0"], ["Gold", "ffe9a0"], ["Violet", "e0c0ff"], ["Teal", "a0f0f0"]],
	"hair": [["Brown", ""], ["Black", "c8c8d8"], ["Blonde", "ffe8b0"], ["Red", "ffc0a0"], ["Silver", "e8e8f8"], ["Pink", "ffc8e8"]],
}
var _look := {"skin": 0, "outfit": 0, "hair": 0}
var _look_preview: Node2D


var _look_full := {}


func _show_look() -> void:
	_clear()
	var sprite_id := GameState.sprite_for_playable(_playable, _arc)
	if sprite_id == "penguin":
		if _look_full.is_empty() or not _look_full.has("tint_name"):
			_look_full = {"tint_name": "classic", "tint": "ffffff", "scarf": "red", "hat": "", "pet": ""}
	elif not bool(_playables[_playable].get("custom", false)) or not PaperDoll.available():
		# Precreated heroes are played as drawn: straight to names.
		_show_names()
		return
	elif _look_full.is_empty() or not _look_full.has("body"):
		_look_full = PaperDoll.random_look()
		_look_full["outfit"] = "outfit_neon" if _arc == "gangsters" else "outfit_farmer"  # the preview matches the game
	Music.instance(get_tree()).play("title_musicbox" if Music.has_track("title_musicbox") else "title")
	var cr := Creator.new(_look_full, sprite_id, false)
	cr.done.connect(func(l: Dictionary) -> void: _look_full = l; _show_names())
	_page.add_child(cr)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)  # Back clear of the creator panel's bottom frame
	_page.add_child(gap)
	_page.add_child(_button("Back", _show_characters))


func _show_names() -> void:
	_clear()
	_page.add_child(_label("Name things", 16))
	var pname := "Hero" if bool(_playables[_playable].get("custom", false)) else str(_playables[_playable].get("name", "Hero")).get_slice(" (", 0)
	_name_edit = _edit("Your name", pname)
	_town_edit = _edit("Town name", "Dreamhollow")
	_pet_edit = _edit("Pet name", "Kitty" if str(_look_full.get("pet", "")).begins_with("cat_") else "Pup")
	# C4: difficulty (fights only) and day length, kept with this save slot.
	var diff_btn := _button("Difficulty: " + Difficulty.name_of(_new_diff), func() -> void: pass)
	var diff_note := _label(Difficulty.words(_new_diff), 7, false)
	diff_btn.pressed.connect(func() -> void:
		_new_diff = (_new_diff + 1) % Difficulty.NAMES.size()
		diff_btn.text = "Difficulty: " + Difficulty.name_of(_new_diff)
		diff_note.text = Difficulty.words(_new_diff))
	_page.add_child(diff_btn)
	_page.add_child(diff_note)
	var len_btn := _button("Day length: %d real min" % _new_len, func() -> void: pass)
	len_btn.pressed.connect(func() -> void:
		_new_len = Difficulty.next_day_len(_new_len)
		len_btn.text = "Day length: %d real min" % _new_len)
	_page.add_child(len_btn)
	_page.add_child(_button("Start", _begin, true))
	var made_look := bool(_playables[_playable].get("custom", false)) or GameState.sprite_for_playable(_playable, _arc) == "penguin"
	_page.add_child(_button("Back", _show_look if made_look else _show_characters))  # back to the look you made, not the hero grid


## A visible box for text fields (the default style is see-through over the dark art).
func _field_style(c: Control) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f1e2bd")
	sb.border_color = Color("6b4423")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(4)
	for st in ["normal", "focus", "read_only"]:
		c.add_theme_stylebox_override(st, sb)
	c.add_theme_color_override("font_color", Color("3a2410"))
	c.add_theme_color_override("caret_color", Color("3a2410"))
	c.add_theme_color_override("font_placeholder_color", Color(0.4, 0.3, 0.2, 0.8))


func _edit(label_text: String, default_text: String) -> LineEdit:
	_page.add_child(_label(label_text, 9, false))
	var e := LineEdit.new()
	e.text = default_text
	e.max_length = 16
	e.add_theme_font_size_override("font_size", 11)
	e.custom_minimum_size = Vector2(0, 28)
	_field_style(e)
	e.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_page.add_child(e)
	return e


var _new_diff := Difficulty.DEFAULT   # new-game page choices
var _new_len := GameState.DAY_LEN_DEFAULT


func _begin() -> void:
	var cname := _name_edit.text.strip_edges()
	var town := _town_edit.text.strip_edges()
	var pet := _pet_edit.text.strip_edges()
	if GameState.has_run():
		SaveGame.set_value(GameState.prev_key(), GameState.run.duplicate(true))
	GameState.new_run(_arc, _playable, cname if cname != "" else "Hero", town if town != "" else "Town", pet if pet != "" else "Pup", {"difficulty": _new_diff, "day_len": _new_len})
	var is_custom := bool(_playables[_playable].get("custom", false))
	var is_penguin := GameState.sprite_for_playable(_playable, _arc) == "penguin"
	if is_custom or is_penguin:
		GameState.run["look"] = _look_full.duplicate() if not _look_full.is_empty() else {"tint": "ffffff"}
	else:
		# Precreated hero: keep only the pet choice; no body/outfit so the drawn
		# character is used, not the paper doll.
		GameState.run["look"] = {"pet": str(_look_full.get("pet", ""))}
	if is_custom and not GameState.run["look"].has("outfit"):
		GameState.run["look"]["outfit"] = "outfit_neon" if _arc == "gangsters" else "outfit_farmer"
	GameState.save()  # the look is part of the first save (closing before the first autosave kept none)
	_start_game()


var _starting := false


func _start_game() -> void:
	if _starting or not is_inside_tree():
		return
	_starting = true
	GameMap.next_interior = ""
	var scene := str(GameState.run.get("scene", "farm"))
	if not ResourceLoader.exists("res://scenes/%s.tscn" % scene):
		scene = "farm"
	GameMap.next_spawn = Vector2.ZERO
	# Resume where the last door was taken (saved by go_to); interiors excepted
	# (their spawn comes from the interior data).
	var sp: Variant = GameState.run.get("spawn", [])
	if sp is Array and (sp as Array).size() >= 2 and scene not in ["interior"]:
		GameMap.next_spawn = Vector2(float(sp[0]), float(sp[1]))
		if (sp as Array).size() > 2:
			GameMap.next_facing = str(sp[2])
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % scene)

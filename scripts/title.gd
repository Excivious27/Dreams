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
	var bg := Art.tex("ui", "title_portrait") if Art.has("ui", "title_portrait") else (Art.tex("ui", "title_keyart") if Art.has("ui", "title_keyart") else Art.tex("ui", "title_bg"))
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
	if OS.is_debug_build():
		_page.add_child(_button("Character test map", func() -> void: get_tree().change_scene_to_file("res://scenes/test_map.tscn")))


func _show_slots() -> void:
	_clear()
	_page.add_child(_label("Save slots", 16))
	_page.add_child(_label("Three farms side by side. Tap one to play it.", 8, false))
	for n in [1, 2, 3]:
		var here: bool = int(n) == GameState.slot()
		_page.add_child(_button("%s%d: %s" % ["▶ " if here else "", n, GameState.slot_info(n)], func() -> void:
			GameState.use_slot(n)
			_show_title(), here))
	_page.add_child(_label("Move a farm to another phone: copy its code here, then paste it on the other phone.", 8, false))
	_page.add_child(_button("Copy this slot's save code", func() -> void:
		var code := GameState.export_code()
		if OS.has_feature("web"):
			# Phones only allow copying from the tap itself: show the code in a
			# real page box with the phone's own Share / Copy.
			JavaScriptBridge.eval(_web_code_box(code))
			_slot_msg.text = "Your code is on screen: tap Copy or Share and keep it somewhere safe."
		else:
			DisplayServer.clipboard_set(code)
			_slot_msg.text = "Copied. Paste it somewhere safe (a note or a message to yourself)."))
	_slot_code = TextEdit.new()
	_slot_code.placeholder_text = "Paste a save code here"
	_slot_code.custom_minimum_size = Vector2(220, 46)
	_slot_code.add_theme_font_size_override("font_size", 7)
	_page.add_child(_slot_code)
	_page.add_child(_button("Load the code into slot %d" % GameState.slot(), func() -> void:
		var txt := _slot_code.text
		if OS.has_feature("web") and txt.strip_edges() == "":
			var got: Variant = JavaScriptBridge.eval("prompt('Paste your Dreams save code') || ''")
			txt = str(got) if got != null else ""
		var err := GameState.import_code(txt)
		_slot_msg.text = err if err != "" else "Loaded. The farm that was here can be brought back with Restore."))
	_slot_msg = _label("", 8, false)
	_page.add_child(_slot_msg)
	_page.add_child(_button("Back", _show_title))


var _slot_code: TextEdit
var _slot_msg: Label


## An HTML overlay with the code in a text box and Copy / Share buttons (web).
func _web_code_box(code: String) -> String:
	var js := """(function(){var o=document.createElement('div');o.style.cssText='position:fixed;inset:0;z-index:9999;background:#000c;display:flex;align-items:center;justify-content:center';
var b=document.createElement('div');b.style.cssText='background:#f4e6c4;border-radius:12px;padding:14px;width:86%;max-width:420px;font:15px sans-serif;color:#2a1a10';
b.innerHTML='<b>Your Dreams save code</b><br><small>Keep it in a note or message. Paste it on the other phone.</small>';
var t=document.createElement('textarea');t.readOnly=true;t.value=CODE;t.style.cssText='width:100%;height:120px;margin:8px 0;font:11px monospace';
var row=document.createElement('div');row.style.cssText='display:flex;gap:8px';
function btn(l,f){var x=document.createElement('button');x.textContent=l;x.style.cssText='flex:1;padding:10px;font:bold 15px sans-serif;border-radius:8px;border:0;background:#c98a3a;color:#fff';x.onclick=f;row.appendChild(x);}
btn('Copy',function(){t.select();try{navigator.clipboard.writeText(t.value);}catch(e){document.execCommand('copy');}});
if(navigator.share)btn('Share',function(){navigator.share({text:t.value}).catch(function(){});});
btn('Close',function(){o.remove();});
b.appendChild(t);b.appendChild(row);o.appendChild(b);document.body.appendChild(o);t.focus();t.select();})();"""
	return js.replace("CODE", JSON.stringify(code))


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
		v.add_child(_button("Choose", func() -> void: _arc = arc_id; _show_characters()))
		_page.add_child(panel)
	_page.add_child(_button("Back", _show_title))


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
	Music.instance(get_tree()).play(arc_track if ResourceLoader.exists("res://audio/music/%s.ogg" % arc_track) else "title")
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
	_page.add_child(_label("Tap a card to see who it is, or build your own (last card).", 8))
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
		var cr := Creator.new(_look_full if _look_full.has("body") else PaperDoll.random_look(), "", false)
		_preview.add_child(cr)
		cr.visible = false
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
		hair.modulate = Color(str(PaperDoll.HAIR_COLORS.get(str(lk.get("hair_color", "brown")), "ffffff")))
		hair.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var hat := Sprite2D.new()
		hat.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_preview.add_child(hair)
		_preview.add_child(hat)
		var upd := func() -> void:
			var pose := PaperDoll.pose_index(body.animation, body.frame)
			PaperDoll.place_layer(hair, "hair", str(lk.get("hair", "")), str(lk.get("body", "medium_slim")), pose, false, sc)
			PaperDoll.place_layer(hat, "hats", str(lk.get("hat", "")), str(lk.get("body", "medium_slim")), pose, false, sc)
		body.frame_changed.connect(upd)
		upd.call()
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
	_pet_edit = _edit("Pet name", "Pup")
	_page.add_child(_button("Start", _begin, true))
	_page.add_child(_button("Back", _show_characters))


func _edit(label_text: String, default_text: String) -> LineEdit:
	_page.add_child(_label(label_text, 9, false))
	var e := LineEdit.new()
	e.text = default_text
	e.max_length = 16
	e.add_theme_font_size_override("font_size", 11)
	e.custom_minimum_size = Vector2(0, 28)
	e.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_page.add_child(e)
	return e


func _begin() -> void:
	var cname := _name_edit.text.strip_edges()
	var town := _town_edit.text.strip_edges()
	var pet := _pet_edit.text.strip_edges()
	if GameState.has_run():
		SaveGame.set_value(GameState.prev_key(), GameState.run.duplicate(true))
	GameState.new_run(_arc, _playable, cname if cname != "" else "Hero", town if town != "" else "Town", pet if pet != "" else "Pup")
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

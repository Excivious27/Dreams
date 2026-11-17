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
var _preview: Node2D
var _name_edit: LineEdit
var _next_btn: Button
var _town_edit: LineEdit
var _pet_edit: LineEdit


func _ready() -> void:
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
	var scroll := ScrollContainer.new()
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
	spacer2.custom_minimum_size = Vector2(0, 230)
	_page.add_child(spacer2)
	if GameState.has_run():
		var n: String = GameState.run["names"]["character"]
		_page.add_child(_button("Continue as %s" % n, _start_game, true))
	_page.add_child(_button("New game", _show_arcs, true))
	if GameState.has_run():
		_page.add_child(_button("Play together", _show_net))
	_page.add_child(_button("Character test map", func() -> void: get_tree().change_scene_to_file("res://scenes/test_map.tscn")))


var _net_url: LineEdit
var _net_code: LineEdit
var _net_status: Label


func _show_net() -> void:
	_clear()
	_page.add_child(_label("Play together", 16))
	_page.add_child(_label("Up to 8 players. The host's farm is the world; everyone keeps their own character, skills and pack. Different arcs can play together: you'll each see your own story scenes.", 7, false))
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
	_page.add_child(_label("Who are you?", 16))
	_preview_holder = Control.new()
	_preview_holder.custom_minimum_size = Vector2(0, 70)
	_page.add_child(_preview_holder)
	var ids: Array = _arcs[_arc]["playable"]
	var cards := Art.has("ui", "card_hero_dad")
	var grid := GridContainer.new()
	grid.columns = 4 if cards else 2
	grid.size_flags_horizontal = SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	_page.add_child(grid)
	for pid: String in ids:
		var p: Dictionary = _playables.get(pid, {})
		var name := str(p.get("name", pid))
		if bool(p.get("placeholder", false)):
			name += " (art soon)"
		var card_name := "card_hero_" + pid + ("_gang" if _arc == "gangsters" and Art.has("ui", "card_hero_" + pid + "_gang") else "")
		if cards and Art.has("ui", card_name):
			var tb := TextureButton.new()
			tb.texture_normal = Art.tex("ui", card_name)
			tb.ignore_texture_size = true
			tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			tb.custom_minimum_size = Vector2(56, 78)
			tb.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			tb.tooltip_text = name
			tb.pressed.connect(func() -> void: _pick(pid))
			grid.add_child(tb)
		else:
			grid.add_child(_sprite_card(pid, name) if cards else _button(name, func() -> void: _pick(pid)))
	_page.add_child(_label("Pick a hero and play as them, or build your own.", 7, false))
	_page.add_child(_button("Back", _show_arcs))
	_pick(_playable if _playable in ids else ids[0])


## A hero with no painted card yet: a parchment card with their own sprite on it.
func _sprite_card(pid: String, name: String) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(56, 78)
	b.tooltip_text = name
	b.clip_contents = true
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, Hud.panel_stylebox("panel_parchment"))
	b.pressed.connect(func() -> void: _pick(pid))
	var sprite_id := GameState.sprite_for_playable(pid, _arc)
	var tex: Texture2D = null
	if sprite_id != "":
		var sf := CharacterLibrary.frames_for(sprite_id)
		for a in ["view_front", "idle", "walk_down"]:
			if sf.has_animation(a) and sf.get_frame_count(a) > 0:
				tex = sf.get_frame_texture(a, 0)
				break
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


func _pick(pid: String) -> void:
	var same := pid == _playable and not _look_full.is_empty()
	_playable = pid
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
	_start_game()


func _start_game() -> void:
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

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
var _town_edit: LineEdit
var _pet_edit: LineEdit


func _ready() -> void:
	InputSetup.ensure_actions()
	_arcs = GameState.load_json("res://data/arcs.json")
	_playables = GameState.load_json("res://data/playable.json")
	var bg := Art.tex("ui", "title_bg")
	if bg:
		var tr := TextureRect.new()
		tr.texture = bg
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
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
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 150)
	_page.add_child(spacer)
	_page.add_child(_label("DREAMS", 36))
	_page.add_child(_label("a mystical farming adventure", 9))
	_page.add_child(_label("Two paths. One world. Every choice counts.", 8))
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 120)
	_page.add_child(spacer2)
	if GameState.has_run():
		var n: String = GameState.run["names"]["character"]
		_page.add_child(_button("Continue as %s" % n, _start_game, true))
	_page.add_child(_button("New game", _show_arcs, true))
	_page.add_child(_button("Character test map", func() -> void: get_tree().change_scene_to_file("res://scenes/test_map.tscn")))


func _show_arcs() -> void:
	_clear()
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


func _show_characters() -> void:
	_clear()
	_page.add_child(_label("Who are you?", 16))
	_preview_holder = Control.new()
	_preview_holder.custom_minimum_size = Vector2(0, 70)
	_page.add_child(_preview_holder)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = SIZE_EXPAND_FILL
	_page.add_child(grid)
	var ids: Array = _arcs[_arc]["playable"]
	for pid: String in ids:
		var p: Dictionary = _playables.get(pid, {})
		var name := str(p.get("name", pid))
		if bool(p.get("placeholder", false)):
			name += " (art soon)"
		grid.add_child(_button(name, func() -> void: _pick(pid)))
	_page.add_child(_button("Back", _show_arcs))
	_pick(ids[0])


func _pick(pid: String) -> void:
	_playable = pid
	if _preview:
		_preview.queue_free()
	_preview = Node2D.new()
	_preview.position = Vector2(_preview_holder.size.x / 2.0 if _preview_holder.size.x > 0 else 123, 62)
	_preview_holder.add_child(_preview)
	var sprite_id := GameState.sprite_for_playable(pid)
	if sprite_id != "":
		var s := CharacterLibrary.make_sprite(sprite_id)
		s.scale *= 1.6
		s.play("idle")
		_preview.add_child(s)
	else:
		var ph := PlaceholderSprite.new()
		ph.tint = Color(str(_playables[pid].get("color", "888888")))
		ph.scale = Vector2(1.6, 1.6)
		_preview.add_child(ph)
	var ok := _page.get_children().filter(func(c: Node) -> bool: return c.name == "NextBtn")
	if ok.is_empty():
		var b := _button("Next: names", _show_names, true)
		b.name = "NextBtn"
		_page.add_child(b)
		_page.move_child(b, _page.get_child_count() - 2)


func _show_names() -> void:
	_clear()
	_page.add_child(_label("Name things", 16))
	var pname := str(_playables[_playable].get("name", "Hero"))
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
	_start_game()


func _start_game() -> void:
	var scene := str(GameState.run.get("scene", "farm"))
	if not ResourceLoader.exists("res://scenes/%s.tscn" % scene):
		scene = "farm"
	GameMap.next_spawn = Vector2.ZERO
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % scene)

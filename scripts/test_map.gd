extends Node2D
## Character test map: all five characters idle in a row at the top;
## you control one. MENU switches character (remembered in user://).

const TILE := 16
const MAP_TILES := Vector2i(17, 34)

var player: Player
var _hud: Label
var _map_rect: Rect2


func _ready() -> void:
	InputSetup.ensure_actions()
	_map_rect = Rect2(Vector2.ZERO, Vector2(MAP_TILES * TILE))

	# Line-up of every character, idling, with names.
	var ids := CharacterLibrary.ORDER
	var span := _map_rect.size.x - TILE * 4
	for i in ids.size():
		var x := TILE * 2.0 + span * i / float(ids.size() - 1)
		var s := CharacterLibrary.make_sprite(ids[i])
		s.position = Vector2(x, TILE * 6)
		s.play("idle")
		s.frame = i % 4
		add_child(s)
		var tag := Label.new()
		tag.text = CharacterLibrary.display_name(ids[i])
		tag.add_theme_font_size_override("font_size", 8)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.size = Vector2(48, 12)
		tag.position = Vector2(x - 24, TILE * 6 + 2)
		tag.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(tag)

	player = Player.new()
	player.position = Vector2(_map_rect.size.x / 2.0, TILE * 14)
	add_child(player)
	var start_id := str(SaveGame.get_value("character", ids[0]))
	if not ids.has(start_id):
		start_id = ids[0]
	player.set_character(start_id)

	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(_map_rect.size.x)
	cam.limit_bottom = int(_map_rect.size.y)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	player.add_child(cam)
	cam.make_current()

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)
	_hud = Label.new()
	_hud.position = Vector2(6, 4)
	_hud.size = Vector2(258, 30)
	_hud.add_theme_font_size_override("font_size", 9)
	_hud.add_theme_constant_override("outline_size", 3)
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hud.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	hud_layer.add_child(_hud)

	add_child(Scenery.new())
	add_child(TouchControls.new())
	queue_redraw()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("menu"):
		next_character()
	var hint := "A attack · hold B run · MENU next"
	if player.has_anim("play"):
		hint = "A attack · B run / tap B to play · MENU next"
	_hud.text = "%s — %s\n%s" % [CharacterLibrary.display_name(player.char_id), player.anim_name, hint]


func next_character() -> void:
	var ids := CharacterLibrary.ORDER
	var i := (ids.find(player.char_id) + 1) % ids.size()
	player.set_character(ids[i])
	SaveGame.set_value("character", ids[i])


func draw_map() -> void:
	var g1 := Color("5a9e4b")
	var g2 := Color("67ab55")
	for y in MAP_TILES.y:
		for x in MAP_TILES.x:
			var c := g1 if (x + y) % 2 == 0 else g2
			draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), c)
	# Stage for the line-up, and a dirt path down the middle.
	draw_rect(Rect2(TILE, TILE * 3, _map_rect.size.x - TILE * 2, TILE * 4.5), Color("c9a86b"))
	draw_rect(Rect2(_map_rect.size.x / 2.0 - TILE, TILE * 7.5, TILE * 2, _map_rect.size.y), Color("b8945a"))
	# Some flowers so movement is easy to see.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 60:
		var p := Vector2(rng.randf_range(TILE, _map_rect.size.x - TILE), rng.randf_range(TILE * 8, _map_rect.size.y - TILE))
		if absf(p.x - _map_rect.size.x / 2.0) < TILE * 1.5:
			continue
		var col: Color = [Color("f2e05c"), Color("f5f5f5"), Color("e36d8e")][i % 3]
		draw_rect(Rect2(p.floor(), Vector2(2, 2)), col)
	# Fence border.
	var fence := Color("6b4a2b")
	draw_rect(Rect2(Vector2.ZERO, Vector2(_map_rect.size.x, TILE)), fence)
	draw_rect(Rect2(0, _map_rect.size.y - TILE, _map_rect.size.x, TILE), fence)
	draw_rect(Rect2(Vector2.ZERO, Vector2(TILE, _map_rect.size.y)), fence)
	draw_rect(Rect2(_map_rect.size.x - TILE, 0, TILE, _map_rect.size.y), fence)

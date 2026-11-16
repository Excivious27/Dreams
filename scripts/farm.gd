extends Node2D
## Your plot of land: the first playable map. A house, a pond with living water,
## tilled soil, a sell box, your pet following you, birds and clouds overhead.
## MENU opens a small pause panel (names, arc, back to title).

const TILE := 16
const MAP_TILES := Vector2i(20, 40)

var player: Player
var pet: Node2D
var _pet_anim: AnimatedSprite2D
var _hud: Label
var _map_rect: Rect2
var _pause: PanelContainer


func _ready() -> void:
	InputSetup.ensure_actions()
	if not GameState.has_run():
		GameState.new_run("penguins", "dad", "Hero", "Town", "Pup")
	_map_rect = Rect2(Vector2.ZERO, Vector2(MAP_TILES * TILE))

	add_child(Scenery.new())
	var pond := Scenery.Pond.new()
	pond.rect = Rect2(TILE * 12, TILE * 20, TILE * 6, TILE * 5)
	add_child(pond)

	player = Player.new()
	player.bounds = _map_rect.grow(-TILE * 1.5)
	player.position = Vector2(TILE * 7, TILE * 14)
	add_child(player)
	player.set_character(GameState.sprite_for_playable(str(GameState.run["playable"])))

	pet = Node2D.new()
	_pet_anim = CharacterLibrary.make_sprite("dog")
	pet.add_child(_pet_anim)
	pet.position = player.position + Vector2(-14, 4)
	_pet_anim.play("idle")
	add_child(pet)

	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(_map_rect.size.x)
	cam.limit_bottom = int(_map_rect.size.y)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
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
	_pause = _build_pause()
	hud_layer.add_child(_pause)

	add_child(TouchControls.new())
	queue_redraw()


func _build_pause() -> PanelContainer:
	var p := PanelContainer.new()
	p.visible = false
	p.position = Vector2(30, 120)
	p.size = Vector2(210, 150)
	var v := VBoxContainer.new()
	p.add_child(v)
	var names: Dictionary = GameState.run["names"]
	var arc_title: String = GameState.load_json("res://data/arcs.json").get(GameState.run["arc"], {}).get("title", "")
	var l := Label.new()
	l.text = "%s of %s\nPet: %s\n%s\nCrystals: %d" % [names["character"], names["town"], names["pet"], arc_title, int(GameState.run["crystals"])]
	l.add_theme_font_size_override("font_size", 9)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	v.add_child(l)
	var b := Button.new()
	b.text = "Back to title"
	b.add_theme_font_size_override("font_size", 9)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	b.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/title.tscn"))
	v.add_child(b)
	var c := Button.new()
	c.text = "Close"
	c.add_theme_font_size_override("font_size", 9)
	c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	c.pressed.connect(func() -> void: _pause.visible = false)
	v.add_child(c)
	return p


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("menu"):
		_pause.visible = not _pause.visible
	_hud.text = "%s · %s\nA attack · hold B run · MENU" % [GameState.run["names"]["character"], GameState.run["names"]["town"]]
	_follow_pet(delta)


func _follow_pet(delta: float) -> void:
	var to := player.position - pet.position
	var dist := to.length()
	if dist > 22.0:
		var step := to.normalized() * minf(dist * 4.0, 95.0) * delta
		pet.position += step
		_pet_anim.flip_h = to.x < 0
		var a := "run" if dist > 40.0 else "walk"
		if _pet_anim.animation != a:
			_pet_anim.play(a)
	elif _pet_anim.animation != "idle":
		_pet_anim.play("idle")


func _draw() -> void:
	var g1 := Color("5a9e4b")
	var g2 := Color("67ab55")
	for y in MAP_TILES.y:
		for x in MAP_TILES.x:
			draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), g1 if (x + y) % 2 == 0 else g2)
	# House (placeholder block until art arrives).
	draw_rect(Rect2(TILE * 3, TILE * 4, TILE * 6, TILE * 5), Color("8b5a2b"))
	draw_rect(Rect2(TILE * 2.5, TILE * 3, TILE * 7, TILE * 2), Color("b03a2e"))
	draw_rect(Rect2(TILE * 5.5, TILE * 7, TILE, TILE * 2), Color("4a2e14"))
	# Tilled rows.
	for r in 4:
		draw_rect(Rect2(TILE * 11, TILE * (5 + r * 2), TILE * 7, TILE), Color("7a5230"))
	# Sell box.
	draw_rect(Rect2(TILE * 3, TILE * 11, TILE * 1.5, TILE), Color("c9a86b"))
	draw_rect(Rect2(TILE * 3, TILE * 10.5, TILE * 1.5, 3), Color("a8884f"))
	# Path to town (south).
	draw_rect(Rect2(_map_rect.size.x / 2.0 - TILE, TILE * 9, TILE * 2, _map_rect.size.y), Color("b8945a"))
	# Trees as simple blobs around the edge.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 26:
		var p := Vector2(rng.randf_range(TILE, _map_rect.size.x - TILE), rng.randf_range(TILE * 13, _map_rect.size.y - TILE))
		if absf(p.x - _map_rect.size.x / 2.0) < TILE * 2 or Rect2(TILE * 11, TILE * 19, TILE * 8, TILE * 7).has_point(p):
			continue
		draw_rect(Rect2(p.x - 2, p.y - 4, 4, 6), Color("5a3a1a"))
		draw_circle(Vector2(p.x, p.y - 10), 8.0, Color("2f7a3a"))
		draw_circle(Vector2(p.x - 3, p.y - 13), 5.0, Color("3f9a48"))
	var fence := Color("6b4a2b")
	draw_rect(Rect2(Vector2.ZERO, Vector2(_map_rect.size.x, TILE)), fence)
	draw_rect(Rect2(0, _map_rect.size.y - TILE, _map_rect.size.x, TILE), fence)
	draw_rect(Rect2(Vector2.ZERO, Vector2(TILE, _map_rect.size.y)), fence)
	draw_rect(Rect2(_map_rect.size.x - TILE, 0, TILE, _map_rect.size.y), fence)

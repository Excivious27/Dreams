class_name Npc
extends Node2D
## A townsperson: placeholder figure with a name tag and an idle wander.
## Dialogue lives in town.gd so the two arcs can say different things.

var id := ""
var home := Vector2.ZERO
var _t := 0.0
var _target := Vector2.ZERO
var _label: Label
var _figure: PlaceholderSprite
var _anim: AnimatedSprite2D
var map: GameMap


func setup(npc_id: String, data: Dictionary, at: Vector2) -> void:
	id = npc_id
	home = at
	position = at
	_target = at
	var sprite_id := str(data.get("sprite", ""))
	if sprite_id != "" and CharacterLibrary.has_character(sprite_id):
		_anim = CharacterLibrary.make_sprite(sprite_id)
		_anim.play("idle")
		add_child(_anim)
	else:
		_figure = PlaceholderSprite.new()
		_figure.tint = Color(str(data.get("color", "888888")))
		add_child(_figure)
	_label = Label.new()
	_label.text = str(data.get("name", id))
	_label.add_theme_font_size_override("font_size", 7)
	_label.add_theme_constant_override("outline_size", 2)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(60, 10)
	_label.position = Vector2(-30, -42)
	_label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_label)


func cell() -> Vector2i:
	return Vector2i(floori(position.x / GameMap.TILE), floori((position.y - 2) / GameMap.TILE))


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = randf_range(2.0, 5.0)
		if randf() < 0.5:
			_target = home + Vector2(randf_range(-20, 20), randf_range(-10, 10))
	var to := _target - position
	if to.length() > 2.0:
		var step := to.normalized() * 18.0 * delta
		var np := position + step
		if map == null or not map.rect_blocked(Rect2(np + Vector2(-3, -3), Vector2(6, 3))):
			position = np
		if _figure:
			_figure.scale.x = -1.0 if to.x < 0 else 1.0
		elif _anim:
			_anim.flip_h = to.x < 0
			if _anim.animation != "walk":
				_anim.play("walk")
	elif _anim and _anim.animation != "idle":
		_anim.play("idle")

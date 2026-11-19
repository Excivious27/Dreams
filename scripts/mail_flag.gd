class_name MailFlag
extends Node2D
## A sealed letter bobbing over the farm mailbox while anything is waiting in
## it (Mail.waiting(): story letters, unread letters, gifts to take, favours
## still open), Stardew-style. Farm.after_ready adds one at the mailbox.

var _spr: Sprite2D
var _t := 0.0
var _check := 0.0


static func attach(m: GameMap, cell: Vector2i) -> MailFlag:
	if not Art.has("items", "letter_sealed"):
		return null
	var f := MailFlag.new()
	f.position = m.cell_center(cell) + Vector2(0, -30)
	f.z_index = 20
	m.add_child(f)
	return f


func _ready() -> void:
	_spr = Sprite2D.new()
	_spr.texture = Art.tex("items", "letter_sealed")
	_spr.scale = Vector2(0.5, 0.5)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_spr)
	_refresh()


func _refresh() -> void:
	visible = Mail.waiting() > 0


func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		_refresh()
	if visible:
		_t += delta
		_spr.position.y = sin(_t * 3.0) * 2.0

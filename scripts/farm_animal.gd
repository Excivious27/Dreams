class_name FarmAnimal
extends AnimatedSprite2D
## A farm animal from art/gen/animals/<kind>: idle, walk, eat (and baby) strips.
## Wanders slowly inside its pen, grazes, and can be petted (A) for friendship.

var kind := ""
var map: GameMap
var pen := Rect2i()
var _target := Vector2.ZERO
var _wait := 1.0
var _state := "idle"
var _rng := RandomNumberGenerator.new()


var baby := false
var _at := Vector2i(-999, -999)  # the cell that holds this animal's interact thing


func setup(m: GameMap, k: String, c: Vector2i, p: Rect2i, is_baby := false) -> void:
	map = m
	kind = k
	baby = is_baby
	name = "%s_%d_%d" % [k, c.x, c.y]  # stable: petting is once per animal per day
	pen = p if p.size != Vector2i.ZERO else Rect2i(c.x - 1, c.y - 1, 3, 3)
	var g := "animals/" + k
	var anims := {"idle": "baby" if is_baby and Art.has(g, "baby") and not Art.has(g, "idle") else "idle"}
	var fps := {"idle": 3.0}
	for a in (["walk"] if is_baby else ["walk", "eat"]):
		if Art.has(g, a):
			anims[a] = a
			fps[a] = 6.0 if a == "walk" else 3.0
	sprite_frames = Art.frames(g, anims, fps)
	animation = "idle"
	scale = Vector2(0.5, 0.5)
	position = m.cell_center(c)
	offset = Vector2(0, -float(Art.info(g, "idle").get("cell_h", 36)) / 2.0 + 2.0)
	_rng.seed = hash(k) + c.x * 31 + c.y
	_target = position
	z_index = 0
	play("idle")
	m.set_thing(c.x, c.y, {"type": "pet_animal", "hint": "A: pet the %s" % k.split("_")[0].rstrip("0123456789"), "animal": self}, false)


func _process(delta: float) -> void:
	if map == null or map.player == null:
		return
	# Y-sort like props: z by feet.
	z_index = 0
	_wait -= delta
	if _state == "walk":
		var d := _target - position
		if d.length() < 1.5:
			_state = "idle"
			_wait = _rng.randf_range(1.5, 4.0)
			_play("idle")
		else:
			position += d.normalized() * 10.0 * delta
			flip_h = d.x < 0
	elif _wait <= 0.0:
		var r := _rng.randf()
		if r < 0.45:
			_state = "walk"
			var c := Vector2i(_rng.randi_range(pen.position.x, pen.end.x - 1), _rng.randi_range(pen.position.y, pen.end.y - 1))
			# At night, in rain and in winter they huddle at the back of the pen, by the barn.
			if GameState.is_night() or GameState.is_wet() or GameState.season() == "winter":
				c.y = pen.position.y
			if map.blocked.has(c):
				_wait = 0.5
				_state = "idle"
			else:
				_target = map.cell_center(c)
				_play("walk")
		elif r < 0.75 and sprite_frames.has_animation("eat"):
			_state = "eat"
			_wait = _rng.randf_range(2.0, 4.0)
			_play("eat")
		else:
			_state = "idle"
			_wait = _rng.randf_range(1.0, 3.0)
			_play("idle")
	# Keep the interact thing under the animal.
	var cell := map.world_to_cell(position - Vector2(0, 2))
	if cell == _at:
		return  # still on the same cell: nothing to move
	if map.things.has(cell) and map.things[cell].get("animal", null) != self:
		return  # never sit on (or erase) a crop, rock or another animal's spot
	if map.things.has(_at) and map.things[_at].get("animal", null) == self:
		var t: Dictionary = map.things[_at]
		map.things.erase(_at)
		map.things[cell] = t
		_at = cell
	else:
		for c: Vector2i in map.things.keys():
			var t2: Dictionary = map.things[c]
			if t2.get("animal", null) == self:
				map.things.erase(c)
				map.things[cell] = t2
				_at = cell
				break


func _play(a: String) -> void:
	if sprite_frames.has_animation(a) and animation != a:
		animation = a
		play(a)

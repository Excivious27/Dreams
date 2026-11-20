class_name SpouseFarm
extends Node
## The spouse out on the farm in the morning (CONDUCT 7 P1): 6-11am on a dry day
## that isn't one of their job days they stand on the porch beside the farmhouse
## door (doing the morning's chore, see Romance.overnight), then go inside.
## A in front of them: Romance.talk. farm.gd after_ready calls SpouseFarm.place(self).

var map: GameMap
var npc: Npc
var cell := Vector2i(-1, -1)


static func wanted() -> bool:
	if not Romance.is_married() or GameState.is_wet() or Romance.is_job_time():
		return false
	var h := int(GameState.run["time"]) / 60
	return h >= 6 and h < 11


static func place(m: GameMap) -> void:
	if not Romance.is_married() or GameState.visiting():
		return
	var s := SpouseFarm.new()
	s.map = m
	s.name = "SpouseFarm"
	m.add_child(s)


func _ready() -> void:
	set_process(true)


func _spot() -> Vector2i:
	var door: Vector2i = map.get("door_c") if map.get("door_c") is Vector2i else Vector2i(8, 8)
	for off: Vector2i in [Vector2i(2, 1), Vector2i(-2, 1), Vector2i(2, 2), Vector2i(-2, 2), Vector2i(3, 1), Vector2i(-3, 1), Vector2i(1, 2), Vector2i(-1, 2)]:
		var c := door + off
		if map.in_content(c) and not map.blocked.has(c) and not map.things.has(c) and not GameState.run["farm"].has("%d,%d" % [c.x, c.y]):
			return c
	return Vector2i(-1, -1)


func _show(on: bool) -> void:
	if on and npc == null:
		cell = _spot()
		if cell.x < 0:
			return
		var id := Romance.spouse()
		npc = Npc.new()
		npc.map = map
		npc.setup(id, GameState.npcs.get(id, {}), map.cell_center(cell))
		npc.routine = []
		npc.hold = true
		npc.wander = 0.0
		map.add_child(npc)
		map.set_thing(cell.x, cell.y, {"type": "spouse", "hint": "A: talk to %s" % Romance.spouse_name()})
	elif not on and npc != null:
		map.things.erase(cell)
		npc.queue_free()
		npc = null


var _t := 0.0


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = 1.0
		_show(wanted())
	if npc == null or map.player == null or map.player.frozen or map.get_tree().paused:
		return
	if Dialogue.input_blocked() or Dialogue.instance(map.get_tree()).active:
		return
	if Input.is_action_just_pressed("a") and map.player.facing_cell() == cell:
		_talk()


func _talk() -> void:
	map.player.frozen = true
	npc.face(map.player.position)
	map.emote(npc, "heart", 1.2)
	await Romance.talk(map, Romance.spouse())
	if is_instance_valid(map) and map.player:
		map.player.frozen = false

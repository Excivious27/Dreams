class_name Npc
extends Node2D
## A townsperson with a name tag, a daily routine and an idle wander.
## Dialogue lives in town.gd so the two arcs can say different things.
##
## Routine (npcs.json "routine"): a list of [hour, place]. The place is a key
## of the map's `spots` (an outdoor spot), or one of the indoor words
## "home" / "work" / "inn" / "chapel" / "school" / "clinic", where the villager
## is out of sight (and the matching interior shows them at the counter).
## Rain keeps everyone but the fisherman and the hunter indoors; on the 7th
## day of each week everyone who's not working is at the chapel in the morning.

var id := ""
var home := Vector2.ZERO
var routine: Array = []
var spots: Dictionary = {}
var wander := 20.0
var _t := 0.0
var _target := Vector2.ZERO
var _label: Label
var _figure: PlaceholderSprite
var _anim: AnimatedSprite2D
var _place := ""
var _stuck := 0.0
var _base_sprite := ""
var _pose := ""
var _idle_t := 0.0
var map: GameMap


## Life poses (w156-158): a single-frame strip under characters/<base>/<pose>.
func set_pose(pose: String) -> void:
	if _anim == null or _base_sprite == "":
		return
	if pose == "":
		if _pose != "":
			_pose = ""
			_anim.play("idle")
		return
	if not Art.has("characters/" + _base_sprite, pose):
		return
	if not _anim.sprite_frames.has_animation("pose_" + pose):
		_anim.sprite_frames.add_animation("pose_" + pose)
		_anim.sprite_frames.add_frame("pose_" + pose, Art.tex("characters/" + _base_sprite, pose))
	_pose = pose
	_anim.play("pose_" + pose)


func setup(npc_id: String, data: Dictionary, at: Vector2) -> void:
	id = npc_id
	home = at
	position = at
	_target = at
	var sprite_id := str(data.get("sprite", ""))
	# Seasonal outfit sheet when one exists for this villager (Prompts 09 w159/160).
	var se := GameState.season()
	var seasonal := "%s_%s" % [sprite_id, "fall" if se == "fall" else se]
	if se == "winter" and CharacterLibrary.has_character(sprite_id + "_winter"):
		sprite_id = sprite_id + "_winter"
	elif se == "summer" and CharacterLibrary.has_character(sprite_id + "_summer"):
		sprite_id = sprite_id + "_summer"
	elif se == "fall" and CharacterLibrary.has_character(sprite_id + "_fall"):
		sprite_id = sprite_id + "_fall"
	elif int(GameState.run.get("day", 1)) % 28 in [13, 27] and CharacterLibrary.has_character(sprite_id + "_festival"):
		sprite_id = sprite_id + "_festival"
	_base_sprite = str(data.get("sprite", ""))
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
	_label.position = Vector2(-30, -34)
	_label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_label)
	_apply_routine(true)


func cell() -> Vector2i:
	if map:
		return map.world_to_cell(position - Vector2(0, 2))
	return Vector2i(floori(position.x / GameMap.TILE), floori((position.y - 2) / GameMap.TILE))


func face(toward: Vector2) -> void:
	if _anim:
		var to := toward - position
		if absf(to.x) >= absf(to.y):
			_anim.flip_h = to.x < 0
	elif _figure:
		_figure.scale.x = -1.0 if toward.x < position.x else 1.0


## Where this villager should be right now ("" = no routine, stay home).
static func place_now(routine_list: Array, npc_id: String) -> String:
	if routine_list.is_empty():
		return ""
	var t := int(GameState.run["time"])
	var hour := t / 60.0
	var day := int(GameState.run["day"])
	var raining := GameState.is_wet() or GameState.weather_today() == "blizzard"
	var place := str(routine_list[0][1])
	for entry in routine_list:
		if hour >= float(entry[0]):
			place = str(entry[1])
	if day % 7 == 0 and hour >= 9.0 and hour < 12.0 and place != "work":
		place = "chapel_front"
	if raining and not npc_id in ["finn", "rook", "sal"] and not place in ["home", "work", "inn", "chapel", "school", "clinic"]:
		place = "home"
	return place


static func is_indoors(place: String) -> bool:
	return place in ["", "home", "work", "inn", "chapel", "school", "clinic", "library", "hall"]


func _apply_routine(snap := false) -> void:
	var place := place_now(routine, id)
	if place == _place and not snap:
		return
	_place = place
	if is_indoors(place) and not routine.is_empty():
		visible = false
		return
	var spot: Vector2i = spots.get(place, Vector2i(-1, -1))
	if spot == Vector2i(-1, -1) or map == null:
		visible = true
		return
	var at := map.cell_center(spot)
	home = at
	_target = at
	visible = true
	if snap or (map.player and map.player.position.distance_to(position) > 200.0):
		position = at  # out of sight: just be there


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = randf_range(2.0, 5.0)
		_apply_routine()
		if visible and randf() < 0.5 and position.distance_to(home) < 40.0:
			_target = home + Vector2(randf_range(-wander, wander), randf_range(-wander / 2.0, wander / 2.0))
	if not visible:
		return
	var to := _target - position
	if to.length() > 2.0:
		var speed := 18.0 if position.distance_to(home) < 48.0 else 34.0
		var step := to.normalized() * speed * delta
		var np := position + step
		var moved := false
		if map == null or not map.rect_blocked(Rect2(np + Vector2(-3, -3), Vector2(6, 3))):
			position = np
			moved = true
		elif map:
			# Slide along the wall on one axis.
			for alt: Vector2 in [Vector2(step.x, 0), Vector2(0, step.y)]:
				var p2 := position + alt
				if alt != Vector2.ZERO and not map.rect_blocked(Rect2(p2 + Vector2(-3, -3), Vector2(6, 3))):
					position = p2
					moved = true
					break
		if not moved:
			_stuck += delta
			if _stuck > 2.0 and map and map.player and map.player.position.distance_to(position) > 160.0:
				position = home  # nobody's looking: skip the walk
				_stuck = 0.0
			elif _stuck > 4.0:
				_target = position
				_stuck = 0.0
		else:
			_stuck = 0.0
		if _figure:
			_figure.scale.x = -1.0 if to.x < 0 else 1.0
		elif _anim:
			var a := "walk"
			if absf(to.y) > absf(to.x):
				var want := "walk_up" if to.y < 0 else "walk_down"
				if _anim.sprite_frames.has_animation(want):
					a = want
			_anim.flip_h = a == "walk" and to.x < 0
			if _anim.animation != a:
				_anim.play(a)
	elif _anim and _pose != "":
		pass  # holding a life pose
	elif _anim and _anim.animation != "idle":
		_anim.play("idle")
		_idle_t = 0.0
	if _anim and to.length() <= 2.0:
		_idle_t += delta
		if _idle_t > 1.5 and _pose == "":
			# Standing still outside: pick a pose that fits the place and weather.
			var want := ""
			if GameState.is_wet() and id in ["finn", "rook", "sal"]:
				want = "umbrella"
			elif GameState.weather_today() in ["snow", "blizzard"]:
				want = "shiver"
			elif _place in ["store_front", "smith_front", "bakery_front", "hall_front", "clinic_front", "library_front", "lodge_front", "market"]:
				want = "work"
			elif _place in ["river_n", "river_s", "pond", "bridge"] and id in ["finn", "sal", "marlowe"]:
				want = "fish"
			elif _place in ["plaza", "plaza_e", "fountain", "park", "inn_front"]:
				want = ["sit", "talk", "wave", ""][randi() % 4]
			set_pose(want)
	else:
		_idle_t = 0.0
		if _pose != "":
			set_pose("")

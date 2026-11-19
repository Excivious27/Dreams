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
var _base_scale := Vector2.ZERO
var _idle_t := 0.0
var map: GameMap


## Villagers whose life-pose row (w157/w158) was drawn as a different person from
## their walker: they keep the walker's idle until matching poses are drawn.
const LIFE_SKIP := ["orla", "benno", "tam", "ivy"]


## Life poses (w156-158): a single-frame strip under characters/<base>/<pose>.
func set_pose(pose: String) -> void:
	if _anim == null or _base_sprite == "":
		return
	if pose != "" and pose != "work" and id in LIFE_SKIP:
		return  # their own "work" strip is in the walker's design; the other life poses were cut
	if pose == "":
		if _pose != "":
			_pose = ""
			_anim.scale = _base_scale
			_anim.play("idle")
		return
	# Their own pose sheet (npc_<id>) first, then the job sprite's.
	var g := ""
	for cand in ["characters/npc_" + id, "characters/" + _base_sprite]:
		if Art.has(cand, pose) and int(Art.info(cand, pose).get("h", 0)) >= 16:
			g = cand
			break
	if g == "":
		return
	if _base_scale == Vector2.ZERO:
		_base_scale = _anim.scale
	var key := "pose_%s_%s" % [g.get_file(), pose]
	if not _anim.sprite_frames.has_animation(key):
		_anim.sprite_frames.add_animation(key)
		_anim.sprite_frames.set_animation_loop(key, false)
		_anim.sprite_frames.add_frame(key, Art.tex(g, pose))
	# A pose sheet sliced at another scale than the walk strips is brought to
	# the same size (a real height change, like sitting, stays).
	var idle_tex := _anim.sprite_frames.get_frame_texture("idle", 0) if _anim.sprite_frames.has_animation("idle") else null
	var ph := float(Art.info(g, pose).get("cell_h", Art.info(g, pose).get("h", 0)))
	_anim.scale = _base_scale
	if idle_tex and ph > 0:
		var r := float(idle_tex.get_height()) / ph
		if r > 1.6 or r < 0.6:
			_anim.scale = _base_scale * r
	_pose = pose
	_anim.play(key)


func setup(npc_id: String, data: Dictionary, at: Vector2) -> void:
	id = npc_id
	home = at
	position = at
	_target = at
	var sprite_id := str(data.get("sprite", ""))
	# Seasonal outfit sheet when one exists for this villager (Prompts 09 w159/160).
	var se := GameState.season()
	# Their own seasonal sheet is npc_<id>_<season>, whatever job sprite they wear.
	var own := "npc_%s_%s" % [npc_id, se]
	# Festival day: their festival outfit comes first.
	if GameState.festival_today() != "" and CharacterLibrary.has_character("npc_%s_festival" % npc_id):
		own = "npc_%s_festival" % npc_id
	if CharacterLibrary.has_character(own):
		sprite_id = own
	elif se == "winter" and CharacterLibrary.has_character(sprite_id + "_winter"):
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


var _path: Array = []
var _wander_t := 0.0
var _chat_t := 0.0
var _chat_partner: Npc = null
var _bubble: Label = null
var _bubble_sprite: Sprite2D = null
var _bubble_i := 0
var activity := ""  # what the current spot is for: "work" | "sit" | "fish" | "garden" | "talk" | ""

## What people do at each kind of spot (drives poses and chatter).
const SPOT_ACTIVITY := {"store_front": "work", "smith_front": "work", "bakery_front": "work", "hall_front": "work", "clinic_front": "work", "library_front": "work", "lodge_front": "work", "inn_front": "work", "market": "work", "stable": "work", "mansion_front": "garden", "wren_garden": "garden", "finn_garden": "garden", "lumi_garden": "garden", "hazel_yard": "garden", "orchard": "garden", "river_n": "fish", "river_s": "fish", "pond": "fish", "bridge": "look", "fountain": "sit", "plaza": "talk", "plaza_e": "talk", "park": "sit", "bench_nw": "sit", "bench_ne": "sit", "bench_sw": "sit", "bench_se": "sit", "well": "work", "school_yard": "play", "chapel_front": "talk", "beach_road": "look", "gate_n": "look", "gate_s": "look", "bandstand": "sit", "clock": "look"}


func _apply_routine(snap := false) -> void:
	var place := place_now(routine, id)
	if place == _place and not snap:
		return
	_place = place
	_pose = ""
	if is_indoors(place) and not routine.is_empty():
		visible = false
		_path.clear()
		return
	var spot: Vector2i = spots.get(place, Vector2i(-1, -1))
	if spot == Vector2i(-1, -1) or map == null:
		visible = true
		return
	activity = str(SPOT_ACTIVITY.get(place, ""))
	var at := map.cell_center(spot)
	home = at
	_target = at
	var was_visible := visible
	visible = true
	if snap or not was_visible or (map.player and map.player.position.distance_to(position) > 260.0):
		# Out of sight (or just stepped outside a door): simply be there.
		position = at
		_path.clear()
	else:
		_path = map.find_path(cell(), spot)
		if _path.is_empty():
			position = at


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = randf_range(2.0, 5.0)
		_apply_routine()
	if not visible:
		return
	_wander_t -= delta
	# Follow the planned path; when it's done, idle near the spot with small wanders.
	if not _path.is_empty():
		var wp: Vector2 = map.cell_center(_path[0])
		_target = wp
		if position.distance_to(wp) < 3.0:
			_path.pop_front()
			if _path.is_empty():
				_target = home
	elif _wander_t <= 0.0 and position.distance_to(home) < 48.0 and _chat_partner == null:
		_wander_t = randf_range(4.0, 11.0)
		if randf() < 0.6 and activity in ["talk", "garden", "work", "play", "look"]:
			var wc := map.world_to_cell(home + Vector2(randf_range(-wander, wander), randf_range(-wander / 2.0, wander / 2.0)))
			if map.in_content(wc) and not map.blocked.has(wc):
				_target = map.cell_center(wc)
				_pose = ""
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
			for alt: Vector2 in [Vector2(step.x, 0), Vector2(0, step.y)]:
				var p2 := position + alt
				if alt != Vector2.ZERO and not map.rect_blocked(Rect2(p2 + Vector2(-3, -3), Vector2(6, 3))):
					position = p2
					moved = true
					break
		if not moved:
			_stuck += delta
			if _stuck > 1.5 and not _path.is_empty():
				_path = map.find_path(cell(), map.world_to_cell(home))
				_stuck = 0.0
			elif _stuck > 2.0 and map and map.player and map.player.position.distance_to(position) > 160.0:
				position = home
				_path.clear()
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
			if absf(to.y) >= absf(to.x):
				var want := "walk_up" if to.y < 0 else "walk_down"
				if _anim.sprite_frames.has_animation(want):
					a = want
			_anim.flip_h = a == "walk" and to.x < 0
			if _anim.animation != a:
				_anim.play(a)
	elif _anim and _pose != "":
		pass
	elif _anim and _anim.animation != "idle":
		_anim.play("idle")
		_idle_t = 0.0
	_chat(delta, to)
	if _anim and to.length() <= 2.0:
		_idle_t += delta
		if _idle_t > 1.2 and _pose == "":
			var want := ""
			if GameState.is_wet() and id in ["finn", "rook", "sal"]:
				want = "umbrella"
			elif GameState.weather_today() in ["snow", "blizzard"]:
				want = "shiver"
			elif _chat_partner != null:
				want = "talk"
			else:
				match activity:
					"work": want = "work"
					"fish": want = "fish"
					"garden": want = ["work", "work", "wave", ""][randi() % 4]
					"sit": want = "sit"
					"talk": want = ["talk", "wave", "", ""][randi() % 4]
					"look": want = ["", "wave"][randi() % 2]
					"play": want = ["wave", "dance", ""][randi() % 3]
			set_pose(want)
	else:
		_idle_t = 0.0
		if _pose != "":
			set_pose("")


## Two villagers who end up near each other stop, face one another and chat for
## a bit (speech dots over their heads), then carry on. Keeps the plaza alive.
func _chat(delta: float, to: Vector2) -> void:
	if map == null or _anim == null:
		return
	if _chat_partner != null:
		_chat_t -= delta
		if not is_instance_valid(_chat_partner) or _chat_t <= 0.0 or not _chat_partner.visible:
			_end_chat()
		else:
			_target = position
			_anim.flip_h = _chat_partner.position.x < position.x
			if _bubble:
				_bubble.text = ["...", "..", ".", "!", "?", "..."][int(Time.get_ticks_msec() / 500) % 6]
			if _bubble_sprite and int(Time.get_ticks_msec() / 1400) != _bubble_i:
				_bubble_i = int(Time.get_ticks_msec() / 1400)
				var pick: String = ["bubble_dots", "bubble_bang", "bubble_question", "bubble_laugh", "bubble_music", "bubble_idea", "bubble_heart", "bubble_dots"][(_bubble_i + hash(id)) % 8]
				if Art.has("emotes", pick):
					_bubble_sprite.texture = Art.tex("emotes", pick)
		return
	if to.length() > 2.0 or _wander_t > 2.0:
		return
	for other in map.get_children():
		if other == self or not other is Npc:
			continue
		var o := other as Npc
		if not o.visible or o._chat_partner != null or o.position.distance_to(position) > 30.0 or o.position.distance_to(position) < 8.0:
			continue
		if randf() < 0.004:
			_start_chat(o)
			o._start_chat(self)
			return


func _start_chat(o: Npc) -> void:
	_chat_partner = o
	_chat_t = randf_range(4.0, 9.0)
	_target = position
	_path.clear()
	set_pose("talk")
	if _bubble_sprite == null and Art.has("emotes", "bubble_dots"):
		_bubble_sprite = Sprite2D.new()
		_bubble_sprite.texture = Art.tex("emotes", "bubble_dots")
		_bubble_sprite.scale = Vector2(0.5, 0.5)
		_bubble_sprite.position = Vector2(0, -30)
		_bubble_sprite.z_index = 30
		_bubble_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_bubble_sprite)
	if _bubble_sprite:
		_bubble_sprite.visible = true
	if _bubble == null:
		_bubble = Label.new()
		_bubble.add_theme_font_size_override("font_size", 8)
		_bubble.add_theme_color_override("font_color", Color(1, 1, 0.9))
		_bubble.add_theme_constant_override("outline_size", 2)
		_bubble.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.05))
		_bubble.position = Vector2(-10, -34)
		_bubble.size = Vector2(20, 10)
		_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_bubble)
	_bubble.visible = _bubble_sprite == null


func _end_chat() -> void:
	if _bubble_sprite:
		_bubble_sprite.visible = false
	_chat_partner = null
	_wander_t = randf_range(3.0, 6.0)
	set_pose("")
	if _bubble:
		_bubble.visible = false

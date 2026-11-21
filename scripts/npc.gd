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
var _walker := ""  # the character sheet they walk in (CharacterLibrary id)
var _dir := "down"  # last way they walked or turned: "down" | "up" | "side"
var _walk_h := {}  # walker anim -> source height (per-animation scale normalise)


## Cells cut through by the slice or drawn as someone else (c5_08 #2): a pose
## here is skipped; a walker idle here borrows frame 0 of the matching walk.
## (Mabel's idle, Bram's festival idle_up, Juniper's winter idle_side and
## Benno/Marlowe's poses were redrawn/resliced in C5: tools/slice_c5_p5.py.)
const BAD_CELLS := {
	"npc_bram_festival": ["idle"],
}
const IDLE_FROM := {"idle": "walk_down", "idle_up": "walk_up", "idle_side": "walk"}


static func bad_cell(sheet: String, anim: String) -> bool:
	return anim in (BAD_CELLS.get(sheet, []) as Array)


## Grown-ups are NPC_H (24 px) tall; children are drawn shorter.
const KID_H := 18.0
## The pose sheets drawn for each villager (npc_<id>): a kid's are this short.
const KID_SHEET_H := 80
## Outfit sheets npc_<id>_<outfit>, the first that exists stands in for the
## base walker while the job-sprite walker is a different person (C5 c5_08).
const OUTFITS := ["base", "spring", "summer", "fall", "winter", "festival", "all"]
## Short gestures a seasonal outfit skips (their pose rows wear the base
## outfit); longer activity poses still play so nobody stands frozen.
const OUTFIT_SKIP := ["wave", "talk", "talk_2", "laugh", "dance", "dance_2", "eat"]


## The walker sheet for this villager: the outfit chosen for the day, unless
## that is still the old job chibi while a newer design exists (their pose
## sheet npc_<id>): then their own base walker, else any outfit of theirs.
static func walker_for(npc_id: String, chosen: String, job_sprite: String) -> String:
	if chosen != job_sprite or not Art.manifest().has("characters/npc_" + npc_id):
		return chosen
	if CharacterLibrary.has_character("npc_" + npc_id):
		return "npc_" + npc_id  # their own sheet carries idle/walk too (mabel, tam...)
	for o: String in OUTFITS:
		var cand := "npc_%s_%s" % [npc_id, o]
		if CharacterLibrary.has_character(cand):
			return cand
	return chosen


## True for the short villagers (pip, wren_jr, tobin, mabel...): judged by the
## height their own pose sheet was drawn at.
static func is_kid(npc_id: String) -> bool:
	var g := "characters/npc_" + npc_id
	for p: String in ["talk", "wave", "idle"]:
		if Art.has(g, p):
			return int(Art.info(g, p).get("cell_h", 99)) < KID_SHEET_H
	return npc_id in ["pip", "wren_jr", "tobin", "mabel"]


## Wearing a seasonal/festival outfit (not their base design).
func in_outfit() -> bool:
	return _walker.begins_with("npc_%s_" % id) and not _walker.ends_with("_base")


func pose_ok(pose: String) -> bool:
	return not (in_outfit() and pose in OUTFIT_SKIP)


## Leg speed for a walk at `speed` px/s (the strips were drawn for ~52 px/s).
static func walk_speed_scale(speed: float) -> float:
	return clampf(speed / 52.0, 0.45, 1.0)


## Idle facing the way they last walked or turned.
func idle_anim() -> String:
	if _anim == null:
		return "idle"
	var want := "idle_up" if _dir == "up" else ("idle_side" if _dir == "side" else "idle")
	if want != "idle" and _anim.sprite_frames.has_animation(want) and not CharacterLibrary.is_alias(_anim.sprite_frames, want):
		return want
	return "idle"


## Kid height and per-animation size (strips cut at other heights don't pop).
func _fit_walker() -> void:
	var sf := _anim.sprite_frames
	for a: String in IDLE_FROM:
		if bad_cell(_walker, a) and sf.has_animation(IDLE_FROM[a]):
			# (SpriteFrames are shared per character: fix the shared copy once.)
			if sf.get_frame_count(a) > 0 and sf.get_frame_texture(a, 0) != sf.get_frame_texture(IDLE_FROM[a], 0):
				sf.clear(a)
				sf.add_frame(a, sf.get_frame_texture(IDLE_FROM[a], 0))
	if is_kid(id):
		_anim.scale *= KID_H / CharacterLibrary.NPC_H
	_base_scale = _anim.scale
	for a in _anim.sprite_frames.get_animation_names():
		var t := _anim.sprite_frames.get_frame_texture(a, 0)
		if t:
			_walk_h[str(a)] = float(t.get_height())


func _idle_h() -> float:
	return float(_walk_h.get("idle", 0.0))


## Play a walker animation at the size of their idle (catkins/mabel/tam strips
## were cut at different heights than their idle and popped in size).
func _play_walker(a: String) -> void:
	if _anim == null:
		return
	if not _anim.sprite_frames.has_animation(a):
		a = "idle"
	var r := 1.0
	var ih := _idle_h()
	var ah := float(_walk_h.get(a, 0.0))
	if ih > 0.0 and ah > 0.0 and absf(ah / ih - 1.0) > 0.04 and (a.begins_with("walk") or a.begins_with("idle")):
		r = ih / ah
	if _base_scale != Vector2.ZERO:
		_anim.scale = _base_scale * r
	if _anim.animation != a:
		_anim.play(a)


## Frame 0 of a pose strip (a multi-frame strip would draw whole otherwise).
static func first_frame(g: String, pose: String) -> Texture2D:
	var t := Art.tex(g, pose)
	var inf := Art.info(g, pose)
	var n := int(inf.get("frames", 1))
	if t == null or n <= 1:
		return t
	var at := AtlasTexture.new()
	at.atlas = t
	at.region = Rect2(0, 0, float(inf.get("cell_w", t.get_width() / n)), float(inf.get("cell_h", t.get_height())))
	return at


## Scale factor (vs their walker scale) for a pose: one ratio per pose sheet,
## from its standing poses against the walker idle, so a sitting pose is
## really shorter. A sit drawn with its stool at full height is brought down.
static func pose_ratio(g: String, pose: String, idle_h: float) -> float:
	var hs: Array[float] = []
	for p: String in ["talk", "wave", "talk_2", "laugh", "idle"]:
		if Art.has(g, p):
			hs.append(float(Art.info(g, p).get("cell_h", 0)))
	hs.sort()
	var stand := hs[hs.size() / 2] if not hs.is_empty() else 0.0
	if stand <= 0.0 or idle_h <= 0.0:
		return 1.0
	var r := idle_h / stand
	if pose == "sit":
		var sh := float(Art.info(g, pose).get("cell_h", stand))
		if sh > stand * SIT_RATIO:
			r *= stand * SIT_RATIO / sh
	return r


## A seated villager (with their stool) stands this share of their height.
const SIT_RATIO := 0.8


## Villagers whose life-pose row was drawn as a different person from their
## walker: they keep the walker's idle until matching poses are drawn
## (ivy, tam and benno were redrawn in Round 12, w486/w490).
const LIFE_SKIP: Array[String] = []


## Life poses (w156-158): a single-frame strip under characters/<base>/<pose>.
func set_pose(pose: String) -> void:
	if _anim == null or _base_sprite == "":
		return
	if pose != "" and pose != "work" and id in LIFE_SKIP:
		return  # their own "work" strip is in the walker's design; the other life poses were cut
	if pose == "":
		if _pose != "":
			_pose = ""
			_play_walker(idle_anim())
		return
	if not pose_ok(pose):
		return
	# Their own pose sheet (npc_<id>) first, then the job sprite's (only while
	# they still wear the job sprite: it's a different person from the new design).
	var g := ""
	var cands := ["characters/npc_" + id]
	if _walker == _base_sprite:
		cands.append("characters/" + _base_sprite)
	for cand: String in cands:
		if bad_cell(cand.get_file(), pose):
			continue
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
		_anim.sprite_frames.add_frame(key, first_frame(g, pose))
	_anim.scale = _base_scale * pose_ratio(g, pose, _idle_h())
	_pose = pose
	_anim.speed_scale = 1.0
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
	sprite_id = walker_for(npc_id, sprite_id, _base_sprite)
	_walker = sprite_id
	if sprite_id != "" and CharacterLibrary.has_character(sprite_id):
		_anim = CharacterLibrary.make_sprite(sprite_id)
		_anim.play("idle")
		add_child(_anim)
		_fit_walker()
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
			_dir = "side"
		else:
			_dir = "up" if to.y < 0 else "down"
		if _pose == "" and str(_anim.animation).begins_with("idle"):
			_play_walker(idle_anim())
	elif _figure:
		_figure.scale.x = -1.0 if toward.x < position.x else 1.0


## Where this villager should be right now ("" = no routine, stay home).
static func place_now(routine_list: Array, npc_id: String) -> String:
	if routine_list.is_empty():
		return ""
	var sp := Romance.spouse_place(npc_id)  # married: at home on the farm (or at work on job days)
	if sp != "":
		return sp
	var t := int(GameState.run["time"])
	var hour := t / 60.0
	var day := int(GameState.run["day"])
	var raining := GameState.is_wet() or GameState.weather_today() == "blizzard"
	var place := str(routine_list[0][1])
	for entry in routine_list:
		if hour >= float(entry[0]):
			place = str(entry[1])
	if day % 7 == 0 and hour >= 9.0 and hour < 12.0 and place != "work" and not Commons.market_slot(npc_id, hour):
		place = "chapel_front"  # (the community farm's market day beats the chapel morning)
	elif place != "work":
		# Volunteering at the community farm (Commons): there, not in town.
		var cf := Commons.slot(npc_id, hour)
		if cf != "":
			place = cf
	var fp := festival_place(npc_id, hour)  # C12 P3: festival day, everyone's on the plaza
	if fp != "":
		return fp
	if raining and not rain_walker(npc_id) and not place in ["home", "work", "inn", "chapel", "school", "clinic"] and not place in Commons.rain_spots():
		place = "home"
	return RecCenter.visit(npc_id, place)  # an evening at the Rec Center


## C12 P3 (c12_11-14): on a festival day (festival_hours) the town is on the plaza: shops
## and school are shut and every sign says so. Juniper stays on call at the clinic;
## the mayor runs the fountain stage. Storms and blizzards keep the old routine.
const FEST_ON_CALL := ["juniper"]
const FEST_SPOTS := ["plaza", "plaza_e", "bench_nw", "bench_ne", "bench_sw", "bench_se"]


## C14 P2 (c14_03-08): festival hours. Egg and Harvest run 9 to 6; Lantern and Star are
## evening festivals on the sunset clock: from 4 hours before sunset until 3.5 after
## (at most 23:30), so the plaza is full when the lanterns light. Vector2(0, 0) = none.
static func festival_hours(fest: String = "") -> Vector2:
	if fest == "":
		fest = GameState.festival_today()
	if fest == "":
		return Vector2.ZERO
	if fest in ["lantern", "star"]:
		var ss := GameState.sunset() / 60.0
		return Vector2(ss - 4.0, minf(23.5, ss + 3.5))
	return Vector2(9.0, 18.0)


static func in_festival(hour: float) -> bool:
	var fh := festival_hours()
	return fh.y > 0.0 and hour >= fh.x and hour < fh.y


static func festival_place(npc_id: String, hour: float) -> String:
	if not in_festival(hour) or npc_id in FEST_ON_CALL:
		return ""
	if GameState.weather_today() in ["storm", "blizzard"] or not GameState.npcs.has(npc_id):
		return ""
	if str(GameState.npcs[npc_id].get("home_scene", "")) not in ["", "town"]:
		return ""
	if npc_id == "alder":
		return "fountain"
	return FEST_SPOTS[absi(hash(npc_id)) % FEST_SPOTS.size()]


## Who keeps their outdoor plans in the wet: Finn, Rook and Sal always; in a
## plain shower (not a storm or blizzard) a different few grown-ups each day
## go out under an umbrella, so a rainy town still has people in it (the
## gangster arc's first day is always rain). Kids stay in.
static func rain_walker(npc_id: String) -> bool:
	if npc_id in ["finn", "rook", "sal"]:
		return true
	if GameState.weather_today() != "rain" or npc_id in ["pip", "wren_jr", "tobin", "mabel"]:
		return false
	return absi(hash(npc_id + ":" + str(GameState.run.get("day", 1)))) % 5 < 2


static func is_indoors(place: String) -> bool:
	return place in ["", "home", "work", "inn", "chapel", "school", "clinic", "library", "hall", "rec"]


var _path: Array = []
var _wander_t := 0.0
var _chat_t := 0.0
var _chat_partner: Npc = null
var _bubble: Label = null
var _bubble_sprite: Sprite2D = null
var _bubble_i := 0
var activity := ""  # what the current spot is for: "work" | "sit" | "fish" | "garden" | "talk" | "farm" | "haul" | "market" | "picnic" | ""
var spots_only := false  # only ever seen at one of `spots` (the community farm map); hidden otherwise

## What people do at each kind of spot (drives poses and chatter).
const SPOT_ACTIVITY := {"store_front": "work", "smith_front": "work", "bakery_front": "work", "hall_front": "work", "clinic_front": "work", "library_front": "work", "lodge_front": "work", "inn_front": "work", "market": "work", "stable": "work", "mansion_front": "garden", "wren_garden": "garden", "finn_garden": "garden", "lumi_garden": "garden", "hazel_yard": "garden", "orchard": "garden", "river_n": "fish", "river_s": "fish", "pond": "fish", "bridge": "look", "fountain": "sit", "plaza": "talk", "plaza_e": "talk", "park": "sit", "bench_nw": "sit", "bench_ne": "sit", "bench_sw": "sit", "bench_se": "sit", "well": "work", "school_yard": "play", "chapel_front": "talk", "beach_road": "look", "gate_n": "look", "gate_s": "look", "bandstand": "sit", "clock": "look"}


## A scene has them (the town tour walks the speaker up to you): the routine waits.
var hold := false
var _leaving := false


## Walk in from `from` to stand at `to` (a scene's speaker). The routine waits until walk_off().
func step_in(from: Vector2, to: Vector2) -> void:
	hold = true
	_leaving = false
	if _chat_partner != null:
		_end_chat()
	visible = true
	position = from
	home = to
	_target = to
	_wander_t = 999.0
	_path = map.find_path(cell(), map.world_to_cell(to)) if map else []


## After the scene: head for wherever the routine wants them (their door if
## they're due indoors), and only then go back to the routine.
func walk_off() -> void:
	if map == null:
		hold = false
		return
	var place := place_now(routine, id)
	var goal := Vector2i(-1, -1)
	if spots.has(place):
		goal = spots[place]
	else:
		var d: Dictionary = GameState.npcs.get(id, {})
		var want := str(d.get("work", "")) if place == "work" else (str(d.get("home", "")) if place == "home" else place)
		for c: Vector2i in map.things:
			var t: Dictionary = map.things[c]
			if str(t.get("type", "")) in ["door", "shop", "hall"] and str(t.get("interior", "")) == want:
				goal = c + Vector2i(0, 1)
				break
	_wander_t = randf_range(3.0, 6.0)
	if goal == Vector2i(-1, -1):
		hold = false
		return
	_leaving = true
	home = map.cell_center(goal)
	_target = home
	_path = map.find_path(cell(), goal)


func _apply_routine(snap := false) -> void:
	if hold:
		return
	var place := place_now(routine, id)
	if place == _place and not snap:
		return
	_place = place
	_pose = ""
	if (is_indoors(place) and not routine.is_empty()) or (place.begins_with("cf_") != spots_only and not spots.has(place)) or (spots_only and not spots.has(place)):
		if visible and not snap and map and map.has_method("npc_leave") and map.npc_leave(self):
			return  # the map walks them off (community farm: out along the road) and hides them
		visible = false  # indoors, away at the community farm, or (on the farm map) not volunteering now
		_path.clear()
		return
	var spot: Vector2i = spots.get(place, Vector2i(-1, -1))
	if spot == Vector2i(-1, -1) or map == null:
		visible = true
		return
	activity = str(SPOT_ACTIVITY.get(place, Commons.spot_activity(place)))
	if map.has_method("stand_cell"):
		spot = map.stand_cell(self, place, spot)  # each person their own patch of a shared spot
	var at := map.cell_center(spot)
	home = at
	_target = at
	var was_visible := visible
	visible = true
	if not snap and not was_visible and map.has_method("npc_arrive"):
		var from: Vector2 = map.npc_arrive(self)  # walk in from the map's entrance
		if from != Vector2.INF:
			position = from
			_path = map.find_path(cell(), spot)
			if not _path.is_empty():
				return
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
	if _leaving and _path.is_empty() and (position.distance_to(_target) < 3.0 or _stuck > 3.0):
		_leaving = false
		hold = false
		_place = "~"  # re-apply now: indoors hides them at their door, outdoors walks on
		_apply_routine()
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
		if randf() < 0.6 and activity in ["talk", "garden", "work", "play", "look", "farm", "haul"]:
			var wc := map.world_to_cell(home + Vector2(randf_range(-wander, wander), randf_range(-wander / 2.0, wander / 2.0)))
			if map.in_content(wc) and not map.blocked.has(wc) and not map.keep_off.has(wc):
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
			_dir = "side"
			if absf(to.y) >= absf(to.x):
				_dir = "up" if to.y < 0 else "down"
				var want := "walk_up" if to.y < 0 else "walk_down"
				if _anim.sprite_frames.has_animation(want):
					a = want
			if absf(to.x) > 0.5 or a == "walk":
				_anim.flip_h = to.x < 0 if a == "walk" else false
			if not moved:
				a = idle_anim()  # blocked: stand, don't run on the spot
			if _pose != "":
				set_pose("")
			_play_walker(a)
			# Legs keep pace with the feet: a slow drift near home steps slowly.
			_anim.speed_scale = walk_speed_scale(speed) if moved else 1.0
	elif _anim and _pose != "":
		_anim.speed_scale = 1.0
	elif _anim and _anim.animation != idle_anim():
		_play_walker(idle_anim())
		_anim.speed_scale = 1.0
		_idle_t = 0.0
	_chat(delta, to)
	if _anim and to.length() <= 2.0:
		_idle_t += delta
		if _idle_t > 1.2 and _pose == "":
			var want := ""
			if GameState.is_wet() and activity != "fish" and map and map.scene_id() != "interior":
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
					"farm": want = ["work", "work_2", "work", "carry", "wave"][randi() % 5]
					"haul": want = ["carry", "carry", "work_2", ""][randi() % 4]
					"market": want = ["talk", "talk_2", "wave", "laugh", "counter"][randi() % 5]
					"picnic": want = ["eat", "sit", "laugh", "talk"][randi() % 4]
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
				_bubble_icon(BUBBLE_ICONS[(_bubble_i + absi(hash(id))) % BUBBLE_ICONS.size()])
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


## emotes/bubble_dots is a sheet of 12 speech icons in a row (dots, !, ?, heart,
## music, swirl, sweat, zzz, idea, swords, fish, coins): show one at a time.
const BUBBLE_ICONS := [0, 1, 2, 0, 3, 4, 8, 0]


func _bubble_icon(i: int) -> void:
	var t := _bubble_sprite.texture
	if t == null:
		return
	var w := t.get_width() / 12.0
	_bubble_sprite.region_enabled = true
	_bubble_sprite.region_rect = Rect2(w * i, 0, w, t.get_height())


func _start_chat(o: Npc) -> void:
	_chat_partner = o
	_chat_t = randf_range(4.0, 9.0)
	_target = position
	_path.clear()
	_dir = "side"
	set_pose("talk")
	if _bubble_sprite == null and Art.has("emotes", "bubble_dots"):
		_bubble_sprite = Sprite2D.new()
		_bubble_sprite.texture = Art.tex("emotes", "bubble_dots")
		_bubble_sprite.scale = Vector2(0.5, 0.5)
		_bubble_sprite.position = Vector2(0, -30)
		_bubble_sprite.z_index = 30
		_bubble_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_bubble_sprite)
		_bubble_icon(0)
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

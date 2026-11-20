class_name TeamBeast
extends Node2D
## A team animal walking with you (CONDUCT 11a P4). GameMap spawns one per TeamAnimals.out()
## outdoors (TeamBeast.spawn_all, not in the house/interiors/moon or while visiting).
## Follows in a formation slot behind you (kept apart from the pup/partner), joins fights by its
## lessons: Charge (attack) butts the nearest unclaimed foe near you; Guard plants itself between
## you and the closest foe (foes already turn on close allies). In group "allies": foes hit it via
## take_damage; a downed animal goes home to rest until morning (Ranch animal "rest_day"), never hurt
## for real. heal(n) for battle Mend/healers. Fetch/Carry work on the farm as Chores.

const FOLLOW_GAP := 22.0
const SEP := 12.0
const HIT_CD := 1.1
const REACH := 14.0
const LOOK := 80.0

var map: GameMap
var uid := ""
var slot := 0
var hp := 10
var max_hp := 10
var dmg := 1
var spd := 1.0
var _spr: AnimatedSprite2D
var _cd := 0.0
var _target: Node2D = null


## Animals on the team that can walk with you today (not resting).
static func out_today() -> Array:
	var day := int(GameState.run.get("day", 1))
	return TeamAnimals.team().filter(func(u: String) -> bool: return int(Ranch.animal(u).get("rest_day", -1)) != day and TeamAnimals.sprite_group(u) != "")


static func spawn_all(m: GameMap) -> Array:
	var out: Array = []
	if GameState.run.is_empty() or GameState.visiting() or m.player == null:
		return out
	if m.scene_id() in ["house", "interior", "moon"] or m.scene_id().begins_with("in_") or m.scene_id().begins_with("bf_"):  # battles muster it as a HelperUnit
		return out
	var i := 0
	for u: String in out_today():
		var b := TeamBeast.new()
		b.setup(m, u, i)
		b.position = m.player.position + b._slot_offset()
		m.add_child(b)
		out.append(b)
		i += 1
	return out


func setup(m: GameMap, u: String, s: int) -> void:
	map = m
	uid = u
	slot = s
	name = "team_" + u
	var st := TeamAnimals.stats(u)
	max_hp = int(st["hp"])
	var a := Ranch.animal(u)
	var today := int(a.get("hp_day", -1)) == int(GameState.run.get("day", 1))
	hp = clampi(int(a.get("hp", max_hp)), 1, max_hp) if today else max_hp  # a night's rest heals
	dmg = int(st["dmg"])
	spd = float(st["speed"])
	_spr = HelperUnit.animal_sprite(TeamAnimals.sprite_group(u))
	add_child(_spr)
	z_index = 1
	add_to_group("allies")


func _slot_offset() -> Vector2:
	return [Vector2(-6, 20), Vector2(10, 22), Vector2(-20, 14)][slot % 3]


func _process(delta: float) -> void:
	if map == null or map.player == null or get_tree().paused:
		return
	_cd = maxf(0.0, _cd - delta)
	var goal: Vector2 = map.player.position + _slot_offset()
	var fight := _pick_target()
	if fight != null:
		var guard_only := TeamAnimals.rank(uid, "attack") == 0
		if guard_only:
			goal = map.player.position + (fight.position - map.player.position).normalized() * 16.0
		else:
			goal = fight.position
			if position.distance_to(fight.position) < REACH and _cd <= 0.0:
				_hit(fight as Enemy)
	var to := goal - position
	var moving := to.length() > 3.0
	if moving:
		var sp := 52.0 * spd * (1.6 if to.length() > 60.0 else 1.0)
		position += to.normalized() * minf(to.length(), sp * delta)
		_spr.flip_h = to.x > 0.0
	# Keep apart from the other followers (pup, partner, other animals).
	for a: Node2D in map.allies():
		if a == self or not is_instance_valid(a):
			continue
		var d := position - a.position
		if d.length() < SEP and d.length() > 0.01:
			position += d.normalized() * (SEP - d.length()) * 0.5
	if position.distance_to(map.player.position) > 260.0:
		position = map.player.position + _slot_offset()  # left behind (door, cliff): catch up
	var want := "walk" if moving and _spr.sprite_frames.has_animation("walk") else "idle"
	if _spr.animation != want:
		_spr.play(want)


func _pick_target() -> Node2D:
	if is_instance_valid(_target) and _target is Enemy and (_target as Enemy).hp > 0 and _target.position.distance_to(map.player.position) < LOOK * 1.4:
		return _target
	_target = null
	if TeamAnimals.rank(uid, "attack") == 0 and TeamAnimals.rank(uid, "guard") == 0:
		return null
	var best: Node2D = null
	var bd := LOOK
	for e in map.enemies:
		if not is_instance_valid(e) or not (e is Enemy) or (e as Enemy).hp <= 0:
			continue
		var claim := int((e as Node).get_meta("claimed_by", 0))
		if claim != 0 and claim != get_instance_id() and is_instance_id_valid(claim):
			continue  # another follower has it: spread out
		var d: float = (e as Node2D).position.distance_to(map.player.position)
		if d < bd:
			bd = d
			best = e
	if best != null:
		best.set_meta("claimed_by", get_instance_id())
		_target = best
	return best


func _hit(e: Enemy) -> void:
	_cd = HIT_CD
	e.provoke(self)
	e.hit(dmg, position, false, true)
	map.fx("hit_spark", e.position + Vector2(0, -8), 14.0, 0.4)
	var voice := str(TeamAnimals.spec(uid).get("voice", "bleat"))
	if randf() < 0.3 and position.distance_to(map.player.position) < 170.0:
		Music.instance(get_tree()).sfx(voice, "bleat")


func take_damage(n: int, _from: Vector2) -> void:
	if hp <= 0:
		return
	hp = maxi(0, hp - n)
	Ranch.animal(uid)["hp"] = hp
	Ranch.animal(uid)["hp_day"] = int(GameState.run.get("day", 1))
	modulate = Color(1, 0.6, 0.6)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.25)
	if hp <= 0:
		var a := Ranch.animal(uid)
		a["rest_day"] = int(GameState.run.get("day", 1))
		a.erase("hp")  # back to full after a night's rest
		if map.hud:
			map.hud.toast("%s ran home to the pen to rest." % TeamAnimals.name_of(uid), Color(1, 0.85, 0.6))
		remove_from_group("allies")
		queue_free()


func heal(n: int) -> void:
	hp = mini(max_hp, hp + n)
	Ranch.animal(uid)["hp"] = hp
	Ranch.animal(uid)["hp_day"] = int(GameState.run.get("day", 1))

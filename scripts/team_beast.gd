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
var _fetch_c := Vector2i(-1, -1)   # forage cell it is fetching (Fetch lesson)
var _fetch_t := 0.0
var _carry := ""                   # c11b_09-15: the forage it is bringing back to you
var _carry_n := 0
var _guard_cd := 0.0
const FETCH_EVERY := [0.0, 14.0, 10.0, 7.0]  # seconds between fetches by rank (game time)
static var _fetch_claims := {}  # cell -> beast instance id, so two fetchers split the forage


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
	_spr.modulate = TeamAnimals.tint(u)  # c11b_09-06: rare tints show on the walk too
	add_child(_spr)
	z_index = 1
	add_to_group("allies")


func _slot_offset() -> Vector2:
	return [Vector2(-6, 20), Vector2(10, 22), Vector2(-20, 14)][slot % 3]


func _process(delta: float) -> void:
	if map == null or map.player == null or get_tree().paused:
		return
	_cd = maxf(0.0, _cd - delta)
	_guard_cd = maxf(0.0, _guard_cd - delta)
	var goal: Vector2 = map.player.position + _slot_offset()
	var fight := _pick_target()
	if _carry != "":
		goal = map.player.position
		if position.distance_to(map.player.position) < 16.0:
			_deliver()
	elif fight == null and _fetch(delta):
		goal = map.cell_center(_fetch_c)
	elif fight != null:
		var guard_only := TeamAnimals.rank(uid, "attack") == 0
		if TeamAnimals.rank(uid, "guard") > 0 and position.distance_to(fight.position) < REACH + 4.0 and _guard_cd <= 0.0:
			_shove(fight as Enemy)
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
		if to.length() > FOLLOW_GAP:
			sp = maxf(sp, map.player.velocity.length() * 1.15)  # c11b_09-09: keep up like the pup
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
		position = map.player.position + _slot_offset()  # left behind (door, cliff): catch up (off-screen by then)
	var want := "walk" if moving and _spr.sprite_frames.has_animation("walk") else "idle"
	if PlayClock.now() < _hurt_until and _spr.sprite_frames.has_animation("hurt"):
		want = "hurt"  # C11b integ: the hurt pose when the strip has one
	elif moving and to.length() > 60.0 and _spr.sprite_frames.has_animation("run"):
		want = "run"
	elif _cd > HIT_CD - 0.3 and _spr.sprite_frames.has_animation("attack"):
		want = "attack"  # a butt just landed
	elif not moving and fight != null and _spr.sprite_frames.has_animation("guard"):
		want = "guard"
	if _spr.animation != want:
		_spr.play(want)


## Fetch lesson: now and then trot to a forage spot near you and bring it back (the pick is the
## map's own forage pick, so flags, xp and the bag all work as if you picked it). True while busy.
func _fetch(delta: float) -> bool:
	var r := TeamAnimals.rank(uid, "fetch")
	if r <= 0:
		return false
	if _fetch_c.x >= 0:
		var th: Dictionary = map.things.get(_fetch_c, {})
		if str(th.get("type", "")) != "forage":
			_drop_fetch()
			return false
		if position.distance_to(map.cell_center(_fetch_c)) < 10.0:
			var c := _fetch_c
			_drop_fetch()
			_pick_up(c, th)
			return false
		return true
	_fetch_t += delta
	if _fetch_t < float(FETCH_EVERY[mini(r, 3)]):
		return false
	_fetch_t = 0.0
	var pc := map.world_to_cell(map.player.position)
	var reach := 3 + r
	var best := Vector2i(-1, -1)
	var bd := 9999
	for c: Vector2i in map.things:
		if str((map.things[c] as Dictionary).get("type", "")) != "forage":
			continue
		var d := absi(c.x - pc.x) + absi(c.y - pc.y)
		if d > reach or d >= bd:
			continue
		var cl := int(_fetch_claims.get(c, 0))
		if cl != 0 and cl != get_instance_id() and is_instance_id_valid(cl):
			continue
		bd = d
		best = c
	if best.x < 0:
		return false
	_fetch_c = best
	_fetch_claims[best] = get_instance_id()
	return true


## Take the forage off the ground (the map's forage rules: flag, double-pick chance, foraging xp)
## and carry it back; it is handed over at your feet (c11b_09-15).
func _pick_up(c: Vector2i, th: Dictionary) -> void:
	var item := str(th.get("item", "mushroom"))
	GameState.run["flags"][str(th.get("key", ""))] = int(GameState.run["day"])
	map.things.erase(c)
	map.blocked.erase(c)
	map.hard.erase(c)
	var fsp: Node2D = map.props.get(c, null)
	map.props.erase(c)
	if fsp:
		fsp.queue_free()
	_carry = item
	_carry_n = 1 + (1 if randf() < GameState.bonus("foraging", "forage_bonus") * 0.06 else 0)
	map.xp("foraging", 2 + int(GameState.items.get(item, {}).get("tier", 1)))


func _deliver() -> void:
	if _carry == "":
		return
	map.pop_items(map.player.position + Vector2(0, 4), _carry, _carry_n)
	RanchVoice.say(get_tree(), uid, "happy")
	if map.hud and randf() < 0.5:
		map.hud.toast("%s brought you %s." % [TeamAnimals.name_of(uid), ItemWords.count_id(_carry, _carry_n)], Color(0.8, 1, 0.8))
	_carry = ""
	_carry_n = 0


## Guard lesson (c11b_09-11): shove a close foe back and draw its attention; stronger by rank.
func _shove(e: Enemy) -> void:
	if e == null or not is_instance_valid(e):
		return
	var r := TeamAnimals.rank(uid, "guard")
	_guard_cd = HIT_CD * 1.5 / (1.0 + 0.2 * (r - 1))
	e.provoke(self)
	e.hit(maxi(1, r - 1), position, false, true)
	map.fx("hit_spark", e.position + Vector2(0, -8), 12.0, 0.3)
	RanchVoice.say(get_tree(), uid, "attack")


func _drop_fetch() -> void:
	_fetch_claims.erase(_fetch_c)
	_fetch_c = Vector2i(-1, -1)


func _exit_tree() -> void:
	if _fetch_c.x >= 0:
		_drop_fetch()
	if _carry != "":
		GameState.add_item(_carry, _carry_n)  # never lose a fetched find (map change, rest)
		_carry = ""


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
	if randf() < 0.5 and position.distance_to(map.player.position) < 170.0:
		RanchVoice.say(get_tree(), uid, "attack", "bleat")  # c11b_14-07/-08: the species voice from ranch.json


var _hurt_until := -1.0  # PlayClock time the hurt pose ends


func take_damage(n: int, _from: Vector2) -> void:
	if hp <= 0:
		return
	hp = maxi(0, hp - n)
	Ranch.animal(uid)["hp"] = hp
	Ranch.animal(uid)["hp_day"] = int(GameState.run.get("day", 1))
	_hurt_until = PlayClock.now() + 0.3
	modulate = Color(1, 0.6, 0.6)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.25)
	if hp > 0 and position.distance_to(map.player.position) < 170.0:
		RanchVoice.say(get_tree(), uid, "hurt", "bleat")  # soft and rate-capped (c11b_14-08)
	if hp <= 0:
		RanchVoice.say(get_tree(), uid, "down")
		var a := Ranch.animal(uid)
		a["rest_day"] = int(GameState.run.get("day", 1))
		a.erase("hp")  # back to full after a night's rest
		if map.hud:
			map.hud.toast("%s ran home to the pen to rest." % TeamAnimals.name_of(uid), Color(1, 0.85, 0.6))
		remove_from_group("allies")
		queue_free()


func heal(n: int) -> void:
	if hp < max_hp:
		RanchVoice.say(get_tree(), uid, "happy")
	hp = mini(max_hp, hp + n)
	Ranch.animal(uid)["hp"] = hp
	Ranch.animal(uid)["hp_day"] = int(GameState.run.get("day", 1))

class_name HelperUnit
extends Node2D
## A battlefield helper made at a spawner you built on a control point:
## crystals in the penguin arc, drones in the gangster arc. Not strong alone;
## each kind does one job well.
##   striker  zaps the nearest foe           healer  mends you, the pup and other helpers
##   warden   shields you (less damage)      shade   veils you: foes lose track
## Helpers hold their point, or follow you when the point is safe.
## Extra kinds come from data/battles.json "_helper_kinds" ({id: {crystal, drone,
## hp, colour, act}}; `act` is one of the four jobs above, default striker):
## kinds() merges them, so new helper kinds need no code.
## Team members (make_team): the allies you mustered (CampaignGate.team) take
## the field as named helpers drawn with their own character sprite. They walk
## with you unless sent somewhere, and fall back to camp instead of dying.

const KINDS := {
	"striker": {"crystal": "Spark Crystal", "drone": "Striker Drone", "hp": 24, "colour": "ff8a5a"},
	"healer": {"crystal": "Healer Crystal", "drone": "Medic Drone", "hp": 20, "colour": "7af0a0"},
	"warden": {"crystal": "Ward Crystal", "drone": "Shield Drone", "hp": 34, "colour": "8ab8ff"},
	"shade": {"crystal": "Veil Crystal", "drone": "Ghost Drone", "hp": 16, "colour": "c49aff"},
}
const ACTS := ["striker", "healer", "warden", "shade"]
const WALK := 52.0
const CATCH_UP := 100.0     # follow speed cap when left behind (player run 96 x 1.1)
const WARP_D := 400.0       # further than this from you while following: poof back beside you
const SEP := 8.0            # helpers keep this far apart

static var _kinds: Dictionary = {}
## Game-time clock for veils (shade): advanced once per frame by whoever runs first.
static var _clock := 0.0
static var _clock_frame := -1


## Every helper kind: the four built-ins plus data/battles.json "_helper_kinds".
static func kinds() -> Dictionary:
	if _kinds.is_empty():
		_kinds = KINDS.duplicate(true)
		var extra: Dictionary = GameState.load_json("res://data/battles.json").get("_helper_kinds", {})
		for k: String in extra:
			var kd: Dictionary = (extra[k] as Dictionary).duplicate()
			kd["act"] = str(kd.get("act", "striker")) if str(kd.get("act", "striker")) in ACTS else "striker"
			_kinds[k] = kd
	return _kinds


static func act_of(k: String) -> String:
	if k in ACTS:
		return k
	return str(kinds().get(k, {}).get("act", "striker"))


static func tick_clock(delta: float) -> void:
	var f := Engine.get_process_frames()
	if f != _clock_frame:
		_clock_frame = f
		_clock += delta


static func now() -> float:
	return _clock


## A Shade's veil is up: foes can't pick the player out (game time, not the wall clock).
static func veiled(m: Node) -> bool:
	return m.has_meta("stealth_until") and _clock < float(m.get_meta("stealth_until"))


## The nearest walkable, dry cell centre to `at` (helpers never spawn inside a
## cliff, a building or the water).
static func free_spot(m: GameMap, at: Vector2, r := 6) -> Vector2:
	var c0 := m.world_to_cell(at)
	if not m.blocked.has(c0) and not m.is_water_cell(c0):
		return at
	for rr in range(1, r + 1):
		var best := Vector2.INF
		for dy in range(-rr, rr + 1):
			for dx in range(-rr, rr + 1):
				if maxi(absi(dx), absi(dy)) != rr:
					continue
				var c := c0 + Vector2i(dx, dy)
				if m.blocked.has(c) or m.is_water_cell(c):
					continue
				var w := m.cell_pos(c.x + 0.5, c.y + 0.5)
				if best == Vector2.INF or w.distance_to(at) < best.distance_to(at):
					best = w
		if best != Vector2.INF:
			return best
	return at


var map: GameMap
var kind := "striker"
var style := "crystal"     # or "drone"
var hp := 20
var max_hp := 20
var home := Vector2.ZERO   # the point it guards
var _cd := 0.6
var _bob := 0.0
var _zap_to := Vector2.INF
var _zap_t := 0.0
var _hurt := 0.0
var _rd_acc := 0.0
var _act_t := 0.0   # the action pose plays for a moment after each zap / heal / shield
var act := "striker"       # the job it does (kinds()[kind].act)
var team_id := ""          # a mustered ally (make_team): their id, else ""
var team_name := ""
var team_dmg := 0          # a team animal's own bite (TeamAnimals.stats dmg: lesson ranks count), 0 = people
var team_spd := 1.0
var tag_row := 0           # team name tags alternate rows so neighbours never overlap
var _spr: AnimatedSprite2D = null
var _last_pos := Vector2.ZERO


static func make(m: GameMap, k: String, at: Vector2, home_at: Vector2) -> HelperUnit:
	var h := HelperUnit.new()
	h.map = m
	h.kind = k if kinds().has(k) else "striker"
	h.act = act_of(h.kind)
	h.style = "crystal" if GameState.is_penguins() else "drone"
	h.max_hp = int(kinds()[h.kind].get("hp", 20)) + 4 * GameState.progress_tier() + int(GameState.bonus(GameState.arc_skill(), "helper_hp")) + int(GameState.bonus("strategist", "helper_hp"))
	h.hp = h.max_hp
	h.position = free_spot(m, at)
	h._last_pos = h.position
	h.home = home_at
	h.z_index = 1
	h.add_to_group("allies")
	m.add_child(h)
	return h


## A mustered ally on the field: [id, name, kind] from CampaignGate.team(); `a`
## is their job. Tougher than a spawned helper, drawn as themselves.
static func make_team(m: GameMap, member: Array, a: String, at: Vector2, sprite := "") -> HelperUnit:
	var h := make(m, a if a in ACTS else "striker", at, at)
	h.team_id = str(member[0])
	h.team_name = str(member[1])
	h.max_hp = 36 + 8 * GameState.progress_tier() + int(GameState.bonus("strategist", "helper_hp"))
	h.hp = h.max_hp
	if sprite.begins_with("animals/") and member.size() > 2 and str(member[2]) == "animal":
		# C11a P4: a trained team animal, drawn from its own farm strip at the pen's size.
		var st := TeamAnimals.stats(str(member[0]).trim_prefix("animal:"))
		h.max_hp = int(st["hp"]) + int(GameState.bonus("strategist", "helper_hp"))  # stats() already counts the tier
		h.team_dmg = int(st.get("dmg", 1))
		h.team_spd = float(st.get("speed", 1.0))
		h.hp = h.max_hp
		h._spr = animal_sprite(sprite)
		h.add_child(h._spr)
	elif sprite != "" and CharacterLibrary.has_character(sprite):
		h._spr = CharacterLibrary.make_sprite(sprite)
		h._spr.scale *= 0.85
		h._spr.play("idle")
		CreatureMotion.random_start(h._spr, CreatureMotion.rng_for(h._spr), 0.1)  # c14b_12-12
		h.add_child(h._spr)
	h._bob = CreatureMotion.phase(h) * 10.0
	return h


## An AnimatedSprite2D for an animals/<strip> group with idle (+ walk when drawn) at ~TEAM_ANIMAL_H px.
const TEAM_ANIMAL_H := 22.0


static func animal_sprite(group: String) -> AnimatedSprite2D:
	var anims := {"idle": "idle"}
	var fps := {"idle": 3.0}
	for a: String in ["walk", "run", "attack", "guard", "fetch", "downed", "sit", "cheer", "hurt", "happy", "walk_down", "walk_up", "idle_down", "idle_up"]:  # P6 team poses when drawn (+ toward/away, c14b_09-10)
		if Art.has(group, a):
			anims[a] = a
			fps[a] = 8.0 if a in ["run", "attack"] else (3.0 if a.begins_with("idle") else 6.0)
	if not anims.has("attack"):  # farm strips: spit / butt / happy stand in for an attack pose
		for alt: String in ["spit", "butt", "happy"]:
			if Art.has(group, alt):
				anims["attack"] = alt
				fps["attack"] = 8.0
				break
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = Art.frames(group, anims, fps)
	var tex := spr.sprite_frames.get_frame_texture("idle", 0) if spr.sprite_frames.get_frame_count("idle") > 0 else null
	var sc := 0.5
	if tex != null and tex.get_height() > 0:
		sc = TEAM_ANIMAL_H / float(tex.get_height())
	spr.scale = Vector2(sc, sc)
	spr.offset = Vector2(0, -float(tex.get_height()) * 0.5) if tex != null else Vector2.ZERO
	# c14b_11-05 / 11-14: held idle (rest pose long, the flick short), feet on the ground for
	# every strip (no pop between idle / walk cells), random start so a team never syncs.
	for ia: String in ["idle", "idle_down", "idle_up"]:
		spr.sprite_frames = CreatureMotion.held_idle(spr.sprite_frames, ia, 3.2, 0.18)
	var fit := func() -> void:
		var t2 := spr.sprite_frames.get_frame_texture(spr.animation, spr.frame) if spr.sprite_frames.has_animation(spr.animation) else null
		if t2:
			spr.offset = Vector2(0, -t2.get_height() * 0.5)
	spr.frame_changed.connect(fit)
	spr.animation_changed.connect(fit)
	spr.play("idle")
	CreatureMotion.random_start(spr, CreatureMotion.rng_for(spr), 0.12)
	return spr


## One striker hit. People: 3 + tier; spawned helpers 2 + tier; team animals their own bite
## (lesson ranks) + half the tier, kept under a crew member's hit at the same tier.
func strike_damage() -> int:
	var bonus := int(GameState.bonus("strategist", "helper_damage"))
	if team_dmg > 0:
		return mini(team_dmg + GameState.progress_tier() / 2, 2 + GameState.progress_tier()) + bonus
	return (2 if team_id == "" else 3) + GameState.progress_tier() + bonus


func label() -> String:
	if team_id != "":
		return team_name
	return str(kinds()[kind].get(style, kind.capitalize()))


func take_damage(n: int, _from: Vector2) -> void:
	hp -= maxi(1, n / 2)
	_hurt = 0.2
	if hp <= 0:
		map.fx("poof", position + Vector2(0, -6), 12.0, 0.4)
		if team_id.begins_with("animal:"):
			# A team animal trots home to rest, never knocked out like a person (c11b_09-14).
			var voice := str(TeamAnimals.spec(team_id.trim_prefix("animal:")).get("voice", ""))
			Music.instance(get_tree()).sfx(voice if voice != "" else "pop", "pop")
			map.hud.toast("%s trots back to camp to rest." % team_name, Color(1, 0.85, 0.6))
		elif team_id != "":
			# A person, not a machine: knocked out, falls back (always heard: they're yours).
			Music.instance(get_tree()).sfx("knockout", "thud")
			map.hud.toast("%s falls back to camp." % team_name, Color(1, 0.8, 0.6))
		elif map.player and position.distance_to(map.player.position) < 220.0:
			Music.instance(get_tree()).sfx("power_off" if style == "drone" else "glass", "pop")
		queue_free()


func provoke(_by: Node2D) -> void:
	pass


func _process(delta: float) -> void:
	tick_clock(delta)
	if get_tree().paused or map == null or map.player == null:
		return
	_bob += delta
	_cd -= delta
	_zap_t = maxf(0.0, _zap_t - delta)
	_hurt = maxf(0.0, _hurt - delta)
	_act_t = maxf(0.0, _act_t - delta)
	# Move: guard home; drift toward the player when no foe is near home.
	var foe := map.nearest_enemy_to(position, 120.0)
	if foe and not foe._alive:
		foe = null
	var want := home
	# Early fights: with no order given, the team pushes on its own (Battle sets team_push).
	var pushing := team_id != "" and map.has_meta("team_push") and not map.has_meta("rally_pos") and not map.has_meta("follow_me")
	var following := not pushing and (map.has_meta("follow_me") or (team_id != "" and not map.has_meta("rally_pos")))
	if following:
		# Following you means following you, fight or no fight (team members always
		# walk with you unless sent to a point: they have no post of their own).
		want = map.player.position + Vector2(cos(get_instance_id() % 7), sin(get_instance_id() % 5)) * 22.0
		if position.distance_to(map.player.position) > WARP_D:
			_warp_to(map.player.position)
			return
	if map.has_meta("rally_pos"):
		var rp: Vector2 = map.get_meta("rally_pos")
		want = rp + Vector2(cos(get_instance_id() % 11), sin(get_instance_id() % 13)) * 20.0
		if foe and foe.position.distance_to(position) > 70.0:
			foe = map.nearest_enemy_to(position, 70.0)
			if foe and not foe._alive:
				foe = null
	if pushing:
		var tp: Vector2 = map.get_meta("team_push")
		want = tp + Vector2(cos(get_instance_id() % 11), sin(get_instance_id() % 13)) * 20.0
	if foe and act == "striker":
		want = foe.position + (position - foe.position).normalized() * 40.0
	var step := (want - position)
	if step.length() > 4.0:
		# Walk around cliffs and water toward fixed spots (home, rally point).
		var dir := step.normalized()
		# One shared goal per rally point / per your cell, so the flow-field cache stays small.
		if step.length() > 24.0:
			if foe and act == "striker" and not map.line_clear(position, foe.position):
				# A wall or cliff edge between us and the foe: walk round it to get a line.
				dir = map.flow_dir(position, (foe.position - map.offset()).snapped(Vector2(32, 32)) + map.offset(), 14)
			elif want == home:
				dir = map.flow_dir(position, home)
			elif map.has_meta("rally_pos"):
				dir = map.flow_dir(position, map.get_meta("rally_pos"))
			elif pushing and not map.line_clear(position, want):
				dir = map.flow_dir(position, (want - map.offset()).snapped(Vector2(32, 32)) + map.offset())
			elif following and (not map.line_clear(position, want) or not _can_step(position + step.normalized() * 8.0)):
				# Near you: the bounded chase field. Left far behind (outside its 14-cell
				# window): a coarse unbounded field, so it still walks round cliffs/water.
				if position.distance_to(map.player.position) < 200.0:
					dir = map.flow_dir(position, (map.player.position - map.offset()).snapped(Vector2(32, 32)) + map.offset(), 14)
				else:
					dir = map.flow_dir(position, (map.player.position - map.offset()).snapped(Vector2(128, 128)) + map.offset())
		# Left behind while following: catch up at a run (a touch quicker than you).
		var spd := WALK
		if following and step.length() > 60.0:
			spd = minf(RUN_SPEED * 1.1, CATCH_UP)
		elif step.length() > 120.0:
			spd = WALK * 1.4  # a long way to a rally point / home
		_move(dir * minf(step.length(), spd * delta), dir, spd * delta)
	_separate(delta)
	if _spr:
		var moved := position.distance_to(_last_pos) > 0.05
		var an := "walk" if moved and _spr.sprite_frames.has_animation("walk") else "idle"
		if _hurt > 0.0 and _spr.sprite_frames.has_animation("hurt"):
			an = "hurt"
		elif _act_t > 0.0 and _spr.sprite_frames.has_animation("attack"):
			an = "attack"
		if _spr.animation != an:
			_spr.play(an)
			if an == "idle":
				CreatureMotion.random_start(_spr, CreatureMotion.rng_for(self), 0.1)
		if absf(position.x - _last_pos.x) > 0.05:
			_spr.flip_h = position.x < _last_pos.x
	_last_pos = position
	if _cd > 0.0:
		_rd()
		return
	match act:
		"striker":
			if foe and foe._alive and foe.position.distance_to(position) < 90.0 and map.line_clear(position, foe.position):
				_cd = 1.1
				_act_t = 0.5
				_zap_to = foe.position + Vector2(0, -8)
				_zap_t = 0.12
				foe.provoke(self)
				foe.hit(strike_damage(), position, true, true)
				if team_id != "":
					# Mustered people swing or shoot like people (c6_11).
					_sfx("swing" if GameState.is_penguins() else "shot", 0.35)
				else:
					_sfx("laser" if style == "drone" else "spell_lightning", 0.35)
			else:
				_cd = 0.3
		"healer":
			_cd = 0.5
			var healed := false
			if map.player.position.distance_to(position) < 70.0 and int(GameState.run["hp"]) < int(GameState.run["max_hp"]):
				GameState.run["hp"] = mini(int(GameState.run["max_hp"]), int(GameState.run["hp"]) + 4 + GameState.progress_tier())
				map.fx("sparkle", map.player.position + Vector2(0, -12), 10.0, 0.4)
				healed = true
			for o in get_tree().get_nodes_in_group("allies"):
				if o is HelperUnit and o != self and o.position.distance_to(position) < 70.0 and o.hp < o.max_hp:
					o.hp = mini(o.max_hp, o.hp + 4)
					healed = true
				elif o is TeamBeast and o.position.distance_to(position) < 70.0 and (o as TeamBeast).hp < (o as TeamBeast).max_hp:
					(o as TeamBeast).heal(4)  # C11a P4: team animals out with you
					healed = true
			# The pup too (it fights beside you and has its own health).
			var pet: Variant = map.get("pet")
			if pet != null and is_instance_valid(pet) and (pet as Node2D).visible and (pet as Node2D).position.distance_to(position) < 70.0:
				var st: Dictionary = Pet.state()
				if not st.has("down_until") and int(st.get("hp", 0)) > 0 and int(st.get("hp", 0)) < Pet.max_hp():
					st["hp"] = mini(Pet.max_hp(), int(st["hp"]) + 4)
					healed = true
			if healed:
				_cd = 3.0
				_act_t = 0.5
				_sfx("heal", 0.3)
		"warden":
			_cd = 0.5
			if map.player.position.distance_to(position) < 70.0 and foe != null:
				GameState.run["buffs"] = GameState.run.get("buffs", {})
				var db: Dictionary = GameState.run["buffs"].get("defense", {})
				if db.is_empty() or int(db.get("until", 0)) <= GameState.now_abs() or float(db.get("amount", 0.0)) <= 2.0:
					var fresh := db.is_empty() or int(db.get("until", 0)) <= GameState.now_abs()
					GameState.run["buffs"]["defense"] = {"until": GameState.now_abs() + GameState.real_min(2.1), "amount": 2.0}
					_cd = 2.0
					_act_t = 0.5
					if fresh:
						_sfx("block", 0.25)
		"shade":
			_cd = 0.5
			# One veil at a time for the whole team: 2.5 s on, then at least 3.5 s off.
			if foe and map.player.position.distance_to(position) < 80.0 and now() >= float(map.get_meta("shade_next", 0.0)):
				_cd = 6.0
				_act_t = 0.5
				map.set_meta("shade_next", now() + 6.0)
				map.set_meta("stealth_until", now() + 2.5)
				map.fx("poof", map.player.position + Vector2(0, -8), 12.0, 0.4)
				_sfx("spirit", 0.3)
	_rd()


func _sfx(n: String, chance := 1.0) -> void:
	# A field can hold a dozen helpers: only some of them speak each time.
	if randf() < chance and position.distance_to(map.player.position) < 200.0:
		Music.instance(get_tree()).sfx(n, "pop")


func _move(mv: Vector2, dir: Vector2, room: float) -> void:
	var np := position + mv
	if _can_step(np):
		position = np
		return
	for alt: Vector2 in [Vector2(dir.x, 0), Vector2(0, dir.y)]:
		var ap := position + alt * room
		if alt != Vector2.ZERO and _can_step(ap):
			position = ap
			return


## Keep a little room from the other helpers (no stacks on one pixel).
func _separate(delta: float) -> void:
	var push := Vector2.ZERO
	for o in get_tree().get_nodes_in_group("allies"):
		if o == self or not (o is HelperUnit):
			continue
		var dv: Vector2 = position - (o as Node2D).position
		var dl := dv.length()
		if dl < SEP:
			push += (dv / dl if dl > 0.01 else Vector2.from_angle(float(get_instance_id() % 628) / 100.0)) * (SEP - dl)
	if push != Vector2.ZERO:
		var np := position + push.limit_length(SEP) * minf(1.0, 6.0 * delta)
		if _can_step(np):
			position = np


## Left far behind: vanish in a puff and step out beside you.
func _warp_to(at: Vector2) -> void:
	map.fx("poof", position + Vector2(0, -6), 12.0, 0.4)
	position = free_spot(map, at + Vector2(randf_range(-20, 20), randf_range(10, 20)))
	_last_pos = position
	map.fx("poof", position + Vector2(0, -6), 12.0, 0.4)
	_sfx("teleport", 0.5)


const RUN_SPEED := 96.0


## Redraw at ~20 Hz while standing (only the bob and the 8 fps frame change; moving needs no redraw).
func _rd() -> void:
	_rd_acc += get_process_delta_time()
	if _rd_acc >= 0.05 or _hurt > 0.0 or _zap_t > 0.0:
		_rd_acc = 0.0
		queue_redraw()


func _can_step(at: Vector2) -> bool:
	var c := map.world_to_cell(at)
	var here := map.world_to_cell(position)
	if map.blocked.has(c):
		# Stuck inside a blocked cell (spawned or pushed there): any step that isn't
		# deeper in is fine, so it can walk out.
		return map.blocked.has(here)
	# Keep off water, unless already standing in it (then any way out is fine).
	return not map.is_water_cell(c) or map.is_water_cell(map.world_to_cell(position))


func _draw() -> void:
	var c := Color(str(kinds()[kind].get("colour", "ffffff")))
	var y := -10.0 + sin(_bob * 3.0) * 2.0
	draw_circle(Vector2(0, 0), 4.0, Color(0, 0, 0, 0.2))
	if _hurt > 0.0:
		c = Color.WHITE
	if _spr:
		_draw_team(c)
		return
	var anim := "hurt" if _hurt > 0.0 else ("act" if _act_t > 0.0 else "idle")
	var nfr := 2 if anim == "hurt" else 4
	var fr := int(_bob * 8.0) % nfr
	# Its own frames, else its own single picture (data kinds), else its job's frames.
	var tex := Art.tex("helpers", "%s_%s_%s_%d" % [kind, style, anim, fr])
	if tex == null and not (kind in ACTS):
		tex = Art.tex("helpers", "%s_%s_%d" % [kind, anim, fr])
		if tex == null:
			tex = Art.tex("helpers", kind)
		if tex == null:
			tex = Art.tex("helpers", "%s_%s_%s_%d" % [act, style, anim, fr])
	if tex:
		var hh := 18.0
		var ww := hh * tex.get_width() / tex.get_height()
		draw_texture_rect(tex, Rect2(Vector2(-ww / 2.0, y - hh + 6.0), Vector2(ww, hh)), false)
	elif style == "crystal":
		var pts := PackedVector2Array([Vector2(0, y - 8), Vector2(5, y), Vector2(0, y + 6), Vector2(-5, y)])
		draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.9))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1, 0.8), 1.0)
		draw_circle(Vector2(0, y - 1), 1.5, Color(1, 1, 1, 0.9))
	else:
		draw_rect(Rect2(-5, y - 3, 10, 6), Color(0.3, 0.32, 0.38))
		draw_rect(Rect2(-5, y - 3, 10, 6), Color(0.1, 0.1, 0.14), false, 1.0)
		for sx in [-7.0, 7.0]:
			draw_line(Vector2(sx - 3, y - 5), Vector2(sx + 3, y - 5), Color(0.8, 0.85, 0.9, 0.7), 1.0)
		draw_circle(Vector2(0, y), 1.6, c)
	if hp < max_hp:
		_ally_bar(Rect2(-6, y - 13, 12, 1.5))
	if _zap_t > 0.0 and _zap_to != Vector2.INF:
		var to := _zap_to - position
		draw_line(Vector2(0, y), to, Color(1, 1, 1, 0.9), 1.5)
		draw_line(Vector2(0, y), to, c, 0.8)


## A mustered ally: their sprite (a child) plus a name tag and a health bar.
func _draw_team(c: Color) -> void:
	if _spr:
		_spr.modulate = Color(1.6, 1.6, 1.6) if _hurt > 0.0 else Color.WHITE
	var f := ThemeDB.fallback_font
	var top := -30.0 - 7.0 * tag_row
	draw_string_outline(f, Vector2(-30, top - 2), team_name, HORIZONTAL_ALIGNMENT_CENTER, 60, DisplayMode.df(6), 3, Color(0, 0, 0, 0.8))
	draw_string(f, Vector2(-30, top - 2), team_name, HORIZONTAL_ALIGNMENT_CENTER, 60, DisplayMode.df(6), Color(0.75, 0.95, 1.0))
	if hp < max_hp:
		_ally_bar(Rect2(-7, top, 14, 1.5))
	if _zap_t > 0.0 and _zap_to != Vector2.INF:
		var to := _zap_to - position
		draw_line(Vector2(0, -12), to, Color(1, 1, 1, 0.9), 1.5)
		draw_line(Vector2(0, -12), to, c, 0.8)


## Ally health: the battle's "us" cyan inside a light frame, so it never reads as a
## foe's red bar for colour-blind players (shape and hue both differ, C9 c9_07).
const ALLY_BAR := Color(0.5, 0.9, 1.0)
const ALLY_FRAME := Color(0.9, 0.97, 1.0, 0.85)


func _ally_bar(r: Rect2) -> void:
	draw_rect(r.grow(1.0), ALLY_FRAME, false, 1.0)
	draw_rect(r, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(r.position, Vector2(r.size.x * float(hp) / float(max_hp), r.size.y)), ALLY_BAR)

class_name Pet
extends Node2D
## Your dog. Follows, guards, fights, waits, carries, digs, and levels up
## (run["skills"]["pup"] is its tree; run["pet"] its state). Modes:
##   follow  - at your heel; fights what attacks you
##   attack  - engages any enemy it sees; "action" on an enemy aims it
##   guard   - holds a spot, drives off anything that comes close
##   wait    - sits where left (remembered across maps: run["pet"]["wait"])
## At 0 health it limps home to rest until the next morning (or half a day
## with Best Friend). Recall brings it from anywhere.

var map: GameMap
var anim: AnimatedSprite2D
var busy := false
var _idle := 0.0
var _target: Enemy = null
var _bite_cd := 0.0
var _hurt_t := 0.0
var _aura_t := 0.0
var _bark_t := 0.0
var _carry_item := ""
var _carry_from := Vector2.ZERO
var _carry_find := ""     # mines: "mine" while running to dig, then the item it carries back (PupMine)
var _howled := false
var _hp_bar: Node2D
var _down_t := -1.0       # seconds left to revive a downed pup (-1: not down)
var _moving := false
var _axis_h := true       # facing sideways (vs up/down); kept until the other axis clearly wins
var _vel := Vector2.ZERO
var _paddle: Paddle       # in water the pup swims (Paddle): legs under, bob, slow paddle
var swimming := false
const DOWN_WINDOW := 120.0


static func state() -> Dictionary:
	var p: Dictionary = GameState.run.get("pet", {})
	if p.is_empty():
		p = {"mode": "follow", "hp": 30, "wait": [], "gear": {"collar": "", "pack": "", "boots": ""}, "pack": {}, "rest_until": 0, "rescued_day": 0, "bedroll_day": 0}
		GameState.run["pet"] = p
	return p


static func max_hp() -> int:
	var hp := 30 + int(GameState.bonus("pup", "pet_hp")) + int(GameState.bonus("leadership", "pet_bond")) + 4 * (GameState.skill_level("pup") - 1)
	for slot in ["collar", "pack", "boots"]:
		var g := str(state()["gear"].get(slot, ""))
		hp += int(GameState.items.get(g, {}).get("pet_hp", 0))
	return hp


static func bite_damage() -> int:
	var d := 1 + int(GameState.bonus("pup", "pet_dmg")) + int(GameState.bonus("pup", "pet_magic"))
	for slot in ["collar", "pack", "boots"]:
		d += int(GameState.items.get(str(state()["gear"].get(slot, "")), {}).get("pet_dmg", 0))
	return d


static func speed_mult() -> float:
	var m := 1.0 + GameState.bonus("pup", "pet_speed")
	m += float(GameState.items.get(str(state()["gear"].get("boots", "")), {}).get("pet_speed", 0.0))
	return m


static func pack_size() -> int:
	var n := 0
	var g := str(state()["gear"].get("pack", ""))
	if g != "":
		n = int(GameState.items.get(g, {}).get("pack", 0)) + int(GameState.bonus("pup", "pack"))
	return n


static func resting() -> bool:
	# rest_until_abs: absolute minutes (day*1440+time) when the pup is back.
	var st := state()
	if st.has("rest_until_abs"):
		return GameState.now_abs() < int(st["rest_until_abs"])
	return int(st.get("rest_until", 0)) > int(GameState.run["day"])


static func name_of() -> String:
	return str(GameState.names().get("pet", "Pup"))


## Cats (look pet cat_* / cat2_*) meow and purr; every other look is a dog.
static func is_cat() -> bool:
	return str(GameState.look_d().get("pet", "")).begins_with("cat")


## "pup" or "cat", for lines that talk about the pet.
static func kind_word() -> String:
	return "cat" if is_cat() else "pup"


## The pet's voice for a moment: "call" (alert, answer, fight), "happy" (petted,
## back up) or "hurt" (knocked down, going home). Cats meow/purr, dogs bark/whimper.
static func voice(moment := "call") -> String:
	if is_cat():
		return {"happy": "purr", "hurt": "meow"}.get(moment, "meow")
	return {"hurt": "whimper"}.get(moment, "bark")


## Play the pet's voice (falls back to the dog's sound if a cat take is missing).
static func say(tree: SceneTree, moment := "call") -> void:
	if tree == null:
		return
	var dog: String = {"hurt": "whimper"}.get(moment, "bark")
	Music.instance(tree).sfx(voice(moment), dog)


const GEAR_OVERLAYS := false


func _ready() -> void:
	y_sort_enabled = true
	state()
	# A pup knocked down on another map is still down here (the 2-minute window
	# keeps counting across doors); after it runs out it has gone home.
	var until := float(state().get("down_until", -1.0))
	if until > 0.0:
		var left := minf(until - Time.get_ticks_msec() / 1000.0, DOWN_WINDOW)  # a restarted app resets the clock
		if left > 0.0:
			state()["hp"] = 0
			_down_t = left
			call_deferred("_show_down")
		else:
			state().erase("down_until")
			call_deferred("_go_home")
	elif int(state()["hp"]) <= 0:
		state()["hp"] = max_hp()
	_hp_bar = Node2D.new()
	_hp_bar.position = Vector2(0, -22)
	_hp_bar.draw.connect(_draw_hp)
	add_child(_hp_bar)
	call_deferred("refresh_gear")


## Gear drawn on the pup (Prompts 10 w194): collar / pack / boots / bandana as
## overlays that follow the body's facing. Only the "side" view exists in
## motion so the overlay hides when the body faces up/down.
var _gear_sprites := {}


func refresh_gear() -> void:
	for k in _gear_sprites:
		(_gear_sprites[k] as Node).queue_free()
	_gear_sprites.clear()
	# The gear art is whole dogs wearing the gear, not overlays: drawing it stacked
	# dogs on the pup. Gear shows in the Pup tab and as icons until overlays exist.
	if not GEAR_OVERLAYS:
		return
	var who := "cat" if str(GameState.look_d().get("pet", "")).begins_with("cat") else "dog"
	var st := state()
	var map_names := {"collar": {"pup_collar_leather": "collar_leather", "pup_collar_iron": "collar_iron", "pup_collar_crystal": "collar_crystal"}, "pack": {"pup_pack_small": "pack_small", "pup_pack_large": "pack_large"}, "boots": {"pup_boots": "boots"}}
	if GameState.bonus("pup", "bedroll") > 0.0 and str(st["gear"].get("pack", "")) == "pup_pack_large":
		map_names["pack"]["pup_pack_large"] = "pack_trail"
	for slot in map_names:
		var gid := str(st["gear"].get(slot, ""))
		var nm := str(map_names[slot].get(gid, ""))
		if nm == "" or not Art.has("animals/pet_gear", "%s_%s_side" % [who, nm]):
			continue
		var sp := Sprite2D.new()
		sp.texture = Art.tex("animals/pet_gear", "%s_%s_side" % [who, nm])
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sp.z_index = 1
		add_child(sp)
		_gear_sprites[slot] = sp


func _sync_gear() -> void:
	if _gear_sprites.is_empty() or anim == null:
		return
	var side := anim.animation in ["walk", "run", "idle", "bite", "limp", "guard", "sit", "fetch"]
	var tex := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame) if anim.sprite_frames.has_animation(anim.animation) else null
	for k in _gear_sprites:
		var sp := _gear_sprites[k] as Sprite2D
		sp.visible = side and tex != null
		if tex:
			# The gear sheet draws the whole dog; scale it to the body's drawn height.
			var body_h := tex.get_height() * anim.scale.y
			var sc := body_h / float(sp.texture.get_height())
			sp.scale = Vector2(sc, sc)
			sp.position = anim.position
			sp.offset = Vector2(0, -sp.texture.get_height() / 2.0)
			sp.flip_h = anim.flip_h


func _draw_hp() -> void:
	var hp := int(state()["hp"])
	var mx := max_hp()
	if hp >= mx or hp <= 0:
		return
	_hp_bar.draw_rect(Rect2(-8, 0, 16, 2), Color(0, 0, 0, 0.6))
	_hp_bar.draw_rect(Rect2(-8, 0, 16.0 * hp / mx, 2), Color(0.9, 0.3, 0.3))


func set_mode(mode: String) -> void:
	if is_down():
		map.hud.toast("%s can't hear commands right now. Food or a potion first." % name_of(), Color(1, 0.8, 0.7))
		return
	var st := state()
	st["mode"] = mode
	_target = null
	_howled = false
	if _carry_item != "digging":
		_carry_item = ""
		_carry_find = ""
	if mode == "wait":
		st["wait"] = [map.scene_id(), position.x, position.y]
		GameState.run["flags"]["pup_stay_used"] = true
	elif mode == "guard":
		st["wait"] = [map.scene_id(), position.x, position.y]
	else:
		st["wait"] = []
	# A whistle, then the pet answers (c6_10-24).
	Music.instance(get_tree()).sfx("whistle", "ui_tap")
	get_tree().create_timer(0.25, false).timeout.connect(func() -> void:
		if is_inside_tree():
			Pet.say(get_tree(), "call"))
	if map and map.hud:
		map.hud.toast("%s: %s." % [name_of(), {"follow": "heel", "attack": "attack!", "guard": "guard this spot", "wait": "stay"}.get(mode, mode)], Color(0.85, 1.0, 0.85))
	if anim and mode == "wait" and anim.sprite_frames.has_animation("sit"):
		anim.play("sit")


## Recall from anywhere: the pup appears beside you (Best Friend: instantly;
## otherwise it takes a game hour to find you if it was on another map).
func recall() -> void:
	if is_down():
		map.hud.toast("%s is down. Tap the pup and give food or a potion." % name_of(), Color(1, 0.8, 0.7))
		return
	var st := state()
	if Pet.resting():
		map.hud.toast("%s is resting at home." % name_of(), Color(1, 0.85, 0.75))
		return
	var far := not (st["wait"] as Array).is_empty() and str(st["wait"][0]) != map.scene_id()
	var from_where := str(st["wait"][0]) if not (st["wait"] as Array).is_empty() else "far away"
	st["mode"] = "follow"
	st["wait"] = []
	if int(st.get("hp", 0)) <= 0:
		st["hp"] = max_hp()
	if not visible:
		position = map.player.position + Vector2(-12, 6)
	busy = false
	_target = null
	visible = true
	if far and GameState.bonus("pup", "best") <= 0.0:
		GameState.run["time"] = int(GameState.run["time"]) + 60
		map.hud.toast("%s came running from %s. (an hour passed)" % [name_of(), from_where], Color(0.85, 1.0, 0.85))
	else:
		map.hud.toast("%s is here." % name_of(), Color(0.85, 1.0, 0.85))
	Music.instance(get_tree()).sfx("whistle", "ui_tap")
	Pet.say(get_tree(), "call")
	position = map.player.position + Vector2(-14, 4)
	map.fx("sparkle", position + Vector2(0, -8), 14.0, 0.5)


func take_damage(n: int, from: Vector2) -> void:
	if _hurt_t > 0.0 or _down_t >= 0.0:
		return
	var st := state()
	var reduce := int(GameState.bonus("pup", "pet_def"))
	for slot in ["collar", "pack", "boots"]:
		reduce += int(GameState.items.get(str(st["gear"].get(slot, "")), {}).get("pet_def", 0))
	n = maxi(1, n - reduce)
	st["hp"] = int(st["hp"]) - n
	_hurt_t = 0.5
	if anim.sprite_frames.has_animation("hurt"):
		anim.play("hurt")
	position += (position - from).normalized() * 10.0
	map.damage_number(position + Vector2(0, -16), n, Color(1, 0.6, 0.4))
	_hp_bar.queue_redraw()
	if int(st["hp"]) <= 0:
		_knock_down()


## Out of health: the pup lies down where it is. You have two minutes to feed it
## or give it a potion (tap it, or face it and press CHECK); after that it goes
## home to its dog house on the farm until tomorrow.
func _show_down() -> void:
	if anim and anim.sprite_frames.has_animation("sleep"):
		anim.play("sleep")


func _knock_down() -> void:
	Pet.say(get_tree(), "hurt")
	state()["hp"] = 0
	_down_t = DOWN_WINDOW
	state()["down_until"] = Time.get_ticks_msec() / 1000.0 + DOWN_WINDOW
	_target = null
	if anim.sprite_frames.has_animation("sleep"):
		anim.play("sleep")
	elif anim.sprite_frames.has_animation("limp"):
		anim.play("limp")
	map.hud.toast("%s is down! Feed %s or give a potion within 2 minutes (tap the pup)." % [name_of(), "it"], Color(1, 0.6, 0.5))
	map.emote(self, "sleep", 2.0)


func is_down() -> bool:
	return _down_t >= 0.0


## Food or a potion brings a downed pup back up (or just heals it).
func revive_with(n: int) -> void:
	var st := state()
	st.erase("down_until")
	st["hp"] = mini(max_hp(), maxi(int(st["hp"]), 0) + n)
	if _down_t >= 0.0:
		_down_t = -1.0
		st["hp"] = maxi(int(st["hp"]), max_hp() / 3)
		map.hud.toast("%s is back on its feet!" % name_of(), Color(0.8, 1, 0.8))
		Music.instance(get_tree()).sfx("heal", "sparkle")
		Pet.say(get_tree(), "happy")
		map.emote(self, "heart", 1.2)
		anim.play("idle")
	_hp_bar.queue_redraw()


func _go_home() -> void:
	_down_t = -1.0
	var st := state()
	st.erase("down_until")
	st["hp"] = 0
	# Back next morning; Best Friend: back in half a day.
	var best := GameState.bonus("pup", "best") > 0.0
	st["rest_until_abs"] = GameState.now_abs() + 720 if best else (int(GameState.run["day"]) + 1) * 1440 + GameState.DAY_START
	st["rest_until"] = int(GameState.run["day"]) + 1
	st["mode"] = "follow"
	st["wait"] = []
	Pet.say(get_tree(), "hurt")
	map.hud.toast("%s has gone back to the dog house on your farm to rest%s." % [name_of(), " for a few hours" if best else " until tomorrow"], Color(1, 0.8, 0.7))
	GameState.notify("%s is resting in the dog house on the farm. Back %s." % [name_of(), "in a few hours" if best else "tomorrow morning"])
	map.emote(self, "sleep", 1.5)
	visible = false
	busy = true


func heal(n: int) -> void:
	var st := state()
	st["hp"] = mini(max_hp(), int(st["hp"]) + n)
	_hp_bar.queue_redraw()


func _process(delta: float) -> void:
	if busy or map == null or map.player == null or anim == null or not visible:
		return
	if map.get_tree().paused:
		return
	if _down_t >= 0.0:
		_down_t -= delta
		modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 200.0)
		if int(_down_t) % 30 == 0 and int(_down_t + delta) % 30 != 0 and _down_t > 1.0:
			map.hud.toast("%s needs food or a potion: %d seconds left." % [name_of(), int(_down_t)], Color(1, 0.7, 0.6))
		if _down_t <= 0.0:
			modulate.a = 1.0
			_go_home()
		return
	modulate.a = 1.0
	_hurt_t = maxf(0.0, _hurt_t - delta)
	_bite_cd = maxf(0.0, _bite_cd - delta)
	_sync_gear()
	if _paddle == null:
		_paddle = Paddle.attach(self, anim, map, 6.5, 6.0)
	swimming = _paddle.update(delta)
	var st := state()
	var mode := str(st.get("mode", "follow"))
	var player := map.player
	# Dream Hound aura: a slow heal for you when the pup is near.
	if GameState.bonus("pup", "aura") > 0.0 and position.distance_to(player.position) < 40.0:
		_aura_t += delta
		if _aura_t >= 10.0:
			_aura_t = 0.0
			GameState.heal_points(1)
	# Tracker: bark at hidden ore/forage nearby.
	if GameState.bonus("pup", "tracker") > 0.0:
		_bark_t -= delta
		if _bark_t <= 0.0:
			_bark_t = 6.0
			var pc := map.world_to_cell(position)
			for c in map.things:
				var t := str(map.things[c].get("type", ""))
				if t in ["mrock", "forage", "rock"] and (c as Vector2i).distance_to(pc) <= 8.0 and (t == "forage" or str(map.things[c].get("ore", "")) in ["silver", "gold", "ruby", "crystal", "mithril"]):
					map.emote(self, "surprise", 0.8)
					Pet.say(get_tree(), "call")
					if anim.sprite_frames.has_animation("bark"):
						anim.play("bark")
					break
	# Fetch: pick up drops and carry them to the player.
	if _carry_item == "" and GameState.bonus("pup", "fetch") > 0.0 and mode != "wait":
		for d in map.get_tree().get_nodes_in_group("drops"):
			if d is Node2D and (d as Node2D).position.distance_to(position) < 60.0 and (d as Node2D).position.distance_to(player.position) > 24.0:
				_carry_from = (d as Node2D).position
				_carry_item = "fetch"
				break
	# Mines: dig runs between fights (PupMine).
	if mode == "follow" and PupMine.active(map):
		PupMine.tick(self, delta)
	# Pick a target.
	if mode in ["attack", "follow", "guard"]:
		if _target != null and (not is_instance_valid(_target) or not _target._alive):
			_target = null
		if _target == null:
			var reach := 110.0 if mode == "attack" else (64.0 if mode == "guard" else 40.0)
			var anchor := position if mode != "follow" else player.position
			_target = map.nearest_enemy_to(anchor, reach)
			if mode == "follow" and _target != null and GameState.bonus("pup", "hunter") > 0.0 and player._last_hit_enemy != null and is_instance_valid(player._last_hit_enemy):
				_target = player._last_hit_enemy
			if _target != null and mode == "attack" and GameState.bonus("pup", "howl") > 0.0 and not _howled:
				_howled = true
				for e in map.enemies:
					if is_instance_valid(e) and e.position.distance_to(position) < 90.0:
						e._stun = maxf(e._stun, 1.2)
				map.emote(self, "angry", 1.0)
				anim.play("howl" if anim.sprite_frames.has_animation("howl") else "bark")
				map.shake(2.0)
	# Heel spot: behind you and a little to the side (never on the cell you face),
	# further back while a fight is on so a tap on the foe never lands on the pup.
	var fd: Vector2 = player.facing_dir()
	var fighting := map.nearest_enemy_to(player.position, 5.0 * GameMap.TILE) != null
	var back := 22.0 if fighting else 16.0
	var goal: Vector2 = player.position - fd * back + fd.orthogonal() * (8.0 if fighting else 6.0)
	var stop := 10.0 if fighting else 14.0
	if _target != null:
		# Flank the foe: come at it from the side, not between you and it.
		var axis: Vector2 = (_target.position - player.position)
		var side := axis.normalized().orthogonal() if axis.length() > 1.0 else Vector2.RIGHT
		if side.dot(position - _target.position) < 0.0:
			side = -side
		goal = _target.position + side * 10.0
		stop = 6.0
	elif mode == "wait" or mode == "guard":
		var w: Array = st.get("wait", [])
		if w.size() >= 3:
			goal = Vector2(float(w[1]), float(w[2]))
		else:
			goal = position
		stop = 4.0
	elif _carry_item != "":
		goal = _carry_from if _carry_item == "fetch" else player.position
		stop = 6.0 if _carry_item == "fetch" else 12.0  # bringing: _keep_clear holds it ~9 px off you
	var to := goal - position
	var dist := to.length()
	# Start moving a little past the stop distance, stop at it: no flicker
	# between walking and standing when you take a small step.
	if _moving:
		_moving = dist > stop
	else:
		_moving = dist > stop + 10.0
	if _moving:
		# Keep up with a running player instead of falling behind and clipping.
		var cap := maxf(95.0 * speed_mult(), player.velocity.length() * 1.15)
		var sp := minf(dist * 3.0, cap)
		if _target == null and mode == "follow" and player.mounted:
			sp = maxf(150.0 * speed_mult(), player.velocity.length() * 1.15)  # P5 hook (c8_10): keep up with a fast ride
		if _target == null and mode == "follow" and dist > 140.0:
			# Far behind (doors, cliffs): pop back to heel rather than walk through walls.
			position = player.position + Vector2(-14, 4)
			map.fx("sparkle", position + Vector2(0, -8), 10.0, 0.4)
			_vel = Vector2.ZERO
			return
		_vel = _vel.lerp(to.normalized() * sp, minf(1.0, delta * 8.0))
		var step := _vel * delta
		var np := position + step
		if not map.rect_blocked_player(Rect2(np + Vector2(-3, -2), Vector2(6, 2)), self):
			position = np
		else:
			for alt: Vector2 in [Vector2(step.x, 0), Vector2(0, step.y)]:
				if alt != Vector2.ZERO and not map.rect_blocked_player(Rect2(position + alt + Vector2(-3, -2), Vector2(6, 2)), self):
					position += alt
					break
		_keep_clear(delta)
		var running := dist > (34.0 if anim.animation.begins_with("run") else 48.0) or _target != null
		var a: String
		# Vertical wins ties (diagonals face toward / away), with a small lead
		# needed to switch so it doesn't flicker on a near-perfect diagonal.
		if _axis_h and absf(_vel.y) >= absf(_vel.x):
			_axis_h = false
		elif not _axis_h and absf(_vel.x) > absf(_vel.y) * 1.15:
			_axis_h = true
		if _axis_h:
			a = "run" if running else "walk"
			if absf(_vel.x) > 6.0:
				anim.flip_h = _vel.x < 0
		else:
			var vert := ("run_" if running else "walk_") + ("up" if _vel.y < 0 else "down")
			a = vert if anim.sprite_frames.has_animation(vert) else ("run" if running else "walk")
			anim.flip_h = false
		if swimming:
			a = "walk"  # paddling: the walk, slowed, under the water band
		if anim.animation != a:
			anim.play(a)
		anim.speed_scale = 0.6 if swimming else 1.0
		_idle = 0.0
		if _carry_item == "fetch" and dist < 10.0:
			_carry_item = "bring"
			if _carry_find == "mine":
				_carry_item = "digging"
				PupMine.dig_find(self)
				return
		if _carry_item == "bring" and anim.sprite_frames.has_animation("fetch") and a != "fetch":
			anim.play("fetch")
	else:
		_vel = Vector2.ZERO
		if _target == null:
			_keep_clear(delta)
		if _target != null:
			_bite(_target)
		elif _carry_item == "bring":
			_carry_item = ""
			map.emote(self, "heart", 0.8)
			PupMine.deliver(self)
		elif _carry_item == "fetch" and _carry_find == "mine" and dist <= stop + 10.0:
			_carry_item = "digging"  # stopped just short of the spot: dig here
			PupMine.dig_find(self)
		_idle += delta
		var want := "idle"
		if mode == "guard" and anim.sprite_frames.has_animation("guard"):
			want = "guard"
		elif mode == "wait" and anim.sprite_frames.has_animation("sit"):
			want = "sit"
		elif _idle > 3.0 and anim.sprite_frames.has_animation("sit"):
			want = "sit"
		if swimming:
			want = "walk"  # treading water: never sits or lies on the surface
		var one_shot := anim.animation in ["dig", "bark", "bite", "hurt", "howl", "play", "fetch", "beg"]
		if anim.animation != want and not (one_shot and anim.is_playing()):
			anim.play(want)
		anim.speed_scale = 0.35 if swimming else 1.0
		if _idle > 14.0 and mode != "wait" and not swimming:
			_idle = randf_range(-6.0, 0.0)
			_dig()


func _bite(e: Enemy) -> void:
	if _bite_cd > 0.0:
		return
	_bite_cd = 0.9
	var dmg := bite_damage()
	if GameState.bonus("pup", "hunter") > 0.0 and e.hp < e.max_hp:
		dmg *= 2
	anim.play("bite" if anim.sprite_frames.has_animation("bite") else "bark")
	anim.flip_h = e.position.x < position.x
	e.provoke(self)  # it turns to fight back
	if randf() < 0.35:
		Pet.say(get_tree(), "call")
	var landed := e.hit(dmg, position, false, true)
	# The bite itself (c6_08_26): only when the player is near enough to hear it.
	if landed and map.player and position.distance_to(map.player.position) < 170.0:
		Music.instance(get_tree()).sfx("bite", "hit")
	map.fx("sparkle" if GameState.bonus("pup", "pet_magic") > 0.0 else "hit_spark", e.position + Vector2(0, -8), 14.0, 0.4)
	GameState.add_xp("pup", 2)
	if landed:
		pass  # the enemy answers with its own swing now (Enemy.provoke)


func _dig() -> void:
	busy = true
	anim.play("dig" if anim.sprite_frames.has_animation("dig") else "play")
	if map and map.player and position.distance_to(map.player.position) < 170.0:
		Music.instance(get_tree()).sfx("dig", "step_dirt")
	await get_tree().create_timer(1.6, false).timeout
	if not is_inside_tree() or not is_instance_valid(anim):
		return
	busy = false
	anim.play("idle")
	var chance := 0.35 + 0.1 * GameState.bonus("pup", "dig")
	if randf() < chance:
		var pool: Array = ["fiber", "berry", "stone", "mushroom", "wood", "clay"]
		if GameState.bonus("pup", "dig") >= 2:
			pool += ["copper", "wild_herb", "bone"]
		if GameState.bonus("pup", "dig_rare") > 0.0 and randf() < 0.25:
			pool = ["truffle", "old_coin", "ruby", "shard", "fossil"]
		if PupMine.active(map):
			pool = PupMine.dig_pool(map)
			if pool.is_empty():
				pool = ["stone"]
		var found: String = pool[randi() % pool.size()]
		if not GameState.items.has(found):
			found = "fiber"
		GameState.add_item(found)
		GameState.add_xp("pup", 3)
		map.hud.toast("%s dug up a %s!" % [name_of(), GameState.item_name(found)], Color(0.8, 1, 0.8))
		Music.instance(get_tree()).sfx("pickup")
		map.fx("dust_puff", position, 12.0, 0.4)


## Stay out from under the player's feet in a fight: off the cell they face and
## a pace away, so USE / taps on a foe never land on the pup.
func _keep_clear(delta: float) -> void:
	if map == null or map.player == null:
		return
	var player: Player = map.player
	var fc := map.cell_center(player.cell() + Vector2i(player.facing_dir()))
	var push := Vector2.ZERO
	if position.distance_to(fc) < 10.0:
		push += (position - fc).normalized() if position != fc else player.facing_dir().orthogonal()
	if position.distance_to(player.position) < 9.0:
		push += (position - player.position).normalized() if position != player.position else -player.facing_dir()
	if push == Vector2.ZERO:
		return
	var np := position + push.normalized() * 70.0 * delta
	if not map.rect_blocked_player(Rect2(np + Vector2(-3, -2), Vector2(6, 2)), self):
		position = np

class_name Enemy
extends Node2D
## A Grump (or bigger), slime, bat, golem or corrupted shard: wanders, chases when
## you're close, hurts on touch. Uses Tom's sprites from art/gen/enemies when
## present, otherwise a procedural drawing.

var hp := 3
var max_hp := 3
var base_hp := 3        # HP before any scaling: size checks (bars, stun, boss) use this
var _flash_sent := -1.0
var _draw_sig := -1
var hp_scale := 1.0     # how much the home-tier scaling multiplied HP (allies hit harder by the same)
## Home-tier toughness: an enemy at home takes several swings at every stage.
const PACK_KINDS := ["hill_wolf", "ash_hound"]
const NATIVE_HP := [1.5, 2.2, 2.8, 3.5, 4.0, 5.0]
const BOSS_HP := [2.0, 2.0, 2.5, 3.0, 3.0, 3.5]
var speed := 34.0
var damage := 1
var reward := 3
var kind := "grump"   # grump, big_grump, slime, bat, golem, shard
var map: GameMap
var _t := 0.0
var _dir := Vector2.ZERO
var _hit_flash := 0.0
var _anim_t := 0.0
var _knock := Vector2.ZERO
var _alive := true
var _attacking := 0.0
var _sprite: AnimatedSprite2D
var _shadow_r := 5.0
var _stun := 0.0        # staggered after a hit: no AI, no attacks
var _windup := 0.0      # attack telegraph in progress
var _cooldown := 0.0    # time until it can attack again
var _flash_mat: ShaderMaterial
var _flash := 0.0
var reach := 16.0
var _squash := 0.0
var _stomp_tele := 0.0
var last_applied := 0   # damage the last hit really did (after armor), for the number
var _noticed := false
var _gift: Gift            # the power a Marked or a boss fights with (scripts/gift.gd)

# ---- unified tier (data/tiers.json) -----------------------------------------
var tier := 0                 # effective tier (native, or the floor's in the mine)
var _boosted := false         # scaled above its native tier: shows the tier aura
var abilities: Array = []     # lunge, enrage, ranged, shield, summon, stomp, blink, regen
var inflicts := ""            # status put on the player when it lands a hit
var armor := 0                # flat damage soaked per hit (spells soak half)
var kb_resist := 0.0          # 0..1, how little it slides when hit
var is_guardian := false      # mine floor guardian: its death opens the way down
var bossy := false            # a real boss kind (not just a tier-boosted foe): boss HP scale, boss send-off
var _kb_hits := 0             # knockbacks taken recently (anti-kiting)
var _kb_t := 0.0
var _lunge := 0.0             # >0: dashing at the player
var _lunge_dir := Vector2.ZERO
var _lunge_cd := 0.0
var _lunge_tele := 0.0        # telegraph before a lunge
var _range_tele := 0.0        # telegraph before a shot
var _range_aim := Vector2.ZERO
var _shield := 0.0            # >0: invulnerable
var _shield_cd := 0.0
var _range_cd := 0.0
var _stomp_cd := 0.0
var _regen_t := 0.0
var _since_hit := 0.0
var _enraged := false
var _summoned := {}
var _tele_flash := 0.0   # a short telegraph icon after blink / summon
var _tele_name := ""
var _aura: AnimatedSprite2D = null   # shield / enrage overlay from fx
var _los_t := 0.0
var _los_ok := true
var _chase_t := 0.0    # still hunting you a moment after a detour round a wall


func _set_aura(name: String) -> void:
	if _aura and _aura.name == name:
		return
	if _aura:
		_aura.queue_free()
		_aura = null
	if name == "" or not Art.has("fx", name):
		return
	_aura = AnimatedSprite2D.new()
	_aura.name = name
	_aura.sprite_frames = Art.frames("fx", {"a": name}, {"a": 10.0})
	_aura.animation = "a"
	_aura.scale = Vector2(0.5, 0.5)
	_aura.position = Vector2(0, -12)
	# Tier auras are drawn behind the body (their centre is blank).
	_aura.z_index = -1 if name.begins_with("tier_aura") else 1
	_aura.modulate.a = 0.85
	add_child(_aura)
	_aura.play("a")


func setup(k: String, tier_override := -1) -> void:
	kind = k
	match k:
		"grump":
			hp = 3; speed = 34.0; damage = 1; reward = 3
		"big_grump":
			hp = 16; speed = 26.0; damage = 2; reward = 40
		"slime":
			hp = 2; speed = 22.0; damage = 1; reward = 2
		"bat":
			hp = 2; speed = 48.0; damage = 1; reward = 3
		"golem":
			hp = 8; speed = 18.0; damage = 2; reward = 12
		"shard":
			hp = 4; speed = 30.0; damage = 1; reward = 8
		"soldier":
			hp = 5; speed = 36.0; damage = 1; reward = 6
		"archer":
			hp = 4; speed = 30.0; damage = 1; reward = 7
		"knight":
			hp = 12; speed = 28.0; damage = 2; reward = 25
		"wisp":
			hp = 3; speed = 44.0; damage = 1; reward = 5
		"commander":
			hp = 40; speed = 24.0; damage = 3; reward = 150
		"dark_crystal":
			hp = 80; speed = 20.0; damage = 3; reward = 500
		# Gangster arc (sprites live in characters/, not enemies/)
		"thug_cyber":
			hp = 10; speed = 34.0; damage = 2; reward = 20
		"thug_brute":
			hp = 18; speed = 22.0; damage = 3; reward = 35
		"thug_flame":
			hp = 12; speed = 30.0; damage = 2; reward = 30
		"thug_speedster":
			hp = 8; speed = 60.0; damage = 1; reward = 25
		"thug_gambler":
			hp = 10; speed = 32.0; damage = 2; reward = 30
		"thug_enforcer":
			hp = 24; speed = 20.0; damage = 3; reward = 45
		"president":
			hp = 120; speed = 26.0; damage = 4; reward = 1000
	var ed: Dictionary = GameState.enemy_data.get("enemies", {}).get(k, {})
	if not ed.is_empty():
		hp = int(ed.get("hp", hp)); damage = int(ed.get("dmg", damage)); speed = float(ed.get("speed", speed))
	# Tier weights: native tier from enemies.json, or the tier the map asked for
	# (deep mine floors run meadow kinds at Deep/Crystal weights).
	var native := GameState.enemy_tier(k)
	tier = native if tier_override < 0 else tier_override
	_boosted = tier > native
	var tw := GameState.tier(tier)
	if tier != native:
		hp = int(round(hp * GameState.tier_scale(k, tier, "hp")))
		damage = maxi(1, int(round(damage * GameState.tier_scale(k, tier, "dmg"))))
		speed = speed * GameState.tier_scale(k, tier, "speed")
		reward = int(round(reward * GameState.tier_scale(k, tier, "loot")))
	if ed.has("reward"):
		reward = int(round(int(ed["reward"]) * (GameState.tier_scale(k, tier, "loot") if tier != native else 1.0)))
	abilities = (ed.get("abilities", []) as Array).duplicate()
	for a in tw.get("abilities", []):
		if a == "ranged" and ((ed.get("abilities", []) as Array).has("lunge") or (ed.get("abilities", []) as Array).has("stomp") or PACK_KINDS.has(k)):
			continue  # bruisers stay bruisers
		if tier > native and not abilities.has(a):
			abilities.append(a)
	inflicts = str(ed.get("status", ""))
	# Armor and knockback resistance are what a tier adds ABOVE the enemy's own
	# tier: a golem at home is a golem, not a golem in plate.
	var nw := GameState.tier(native)
	armor = maxi(0, int(tw.get("armor", 0)) - int(nw.get("armor", 0)))
	kb_resist = maxf(0.0, float(tw.get("kb_resist", 0.0)) - float(nw.get("kb_resist", 0.0)))
	base_hp = hp
	bossy = ed.has("gift") or k.begins_with("marked_") or k.begins_with("lt_") or k.begins_with("cboss_") or k in ["big_grump", "president", "golem_king", "ruin_warden", "dark_crystal", "marsh_witch"]
	hp_scale = float((BOSS_HP if bossy else NATIVE_HP)[clampi(mini(native, tier), 0, 5)])  # run below home: scale for the tier you meet it at
	if Settings.easy():
		hp_scale = maxf(1.0, hp_scale * 0.6)
	hp = int(round(hp * hp_scale))
	max_hp = hp
	var art_kind := str(ed.get("art", k if k != "big_grump" or Art.has("enemies/big_grump", "idle") else "grump"))
	var group := "enemies/" + art_kind
	if ed.has("char"):
		group = "characters/" + str(ed["char"])
	elif k.begins_with("thug_"):
		group = "characters/" + k.trim_prefix("thug_")
	elif k == "president":
		group = "characters/president"
	if Art.has(group, "idle"):
		_sprite = AnimatedSprite2D.new()
		var anims := {"idle": "idle", "hurt": "hurt"}
		anims["walk"] = "walk" if Art.has(group, "walk") else "idle"
		if Art.has(group, "attack"):
			anims["attack"] = "attack"
		elif Art.has(group, "special"):
			anims["attack"] = "special"
		if Art.has(group, "die"):
			anims["die"] = "die"
		_sprite.sprite_frames = Art.frames(group, anims, {"idle": 5.0, "walk": 8.0, "hurt": 8.0, "attack": 10.0, "die": 10.0}, {"attack": false, "hurt": false, "die": false})
		_sprite.animation = "idle"
		var s := 1.1 if group == "enemies/grump" and k == "big_grump" else 0.5  # the old stand-in was the little grump scaled up
		_sprite.scale = Vector2(s, s)
		# Feet on the node: offset by half the frame height. Set now too (not only
		# on frame_changed), or the first frame drew centred on the feet with its
		# top half poking up past the hp bar and crest.
		_sprite.frame_changed.connect(_fit_sprite)
		_sprite.animation_changed.connect(_fit_sprite)
		_sprite.play("idle")
		_fit_sprite()
		add_child(_sprite)
		_shadow_r = 6.0 * s * 2.0
		var sh := load("res://shaders/flash.gdshader")
		if sh:
			_flash_mat = ShaderMaterial.new()
			_flash_mat.shader = sh
			_sprite.material = _flash_mat
	reach = 22.0 if base_hp >= 16 else 19.0
	if ed.has("gift") and not Gift.def(str(ed["gift"])).is_empty():
		_gift = Gift.new()
		_gift.setup(self, str(ed["gift"]))
		add_child(_gift)


var _burn_t := 0.0
var _sprite_h := 0.0   # drawn height of the current frame (px), for the hp bar / crest


func _fit_sprite() -> void:
	if _sprite == null or _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(_sprite.animation):
		return
	var tex := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	if tex:
		_sprite.offset = Vector2(0, -tex.get_height() / 2.0)
		var h := tex.get_height() * absf(_sprite.scale.y)
		if absf(h - _sprite_h) > 0.5:
			_sprite_h = maxf(_sprite_h, h)   # never shrink: the bar would jitter between anims
			queue_redraw()


## Where the hp bar sits: above the sprite's head (a tall keeper's crest and
## bar used to sit on its forehead).
func _bar_top() -> float:
	var top := -30.0 if base_hp < 30 else -60.0
	if _sprite_h > 0.0:
		top = minf(top, -_sprite_h - 4.0)
	return top


func _process(delta: float) -> void:
	if not _alive:
		return
	if map.hitstop > 0.0:
		return
	# Sorcery status: asleep (Lull) holds the enemy still; burn (Ember) ticks damage.
	if has_meta("asleep_until") and Time.get_ticks_msec() < int(get_meta("asleep_until")):
		_stun = maxf(_stun, 0.2); _shield = maxf(0.0, _shield - delta)
		return
	if has_meta("burn") and int(get_meta("burn")) > 0:
		_burn_t += delta
		if _burn_t >= 1.0:
			_burn_t = 0.0
			set_meta("burn", int(get_meta("burn")) - 1)
			hit(maxi(1, int(round(hp_scale))), position, true, false, true)  # a tick: no knockback/stun; scales like a hit
			if not _alive:
				return
			map.fx("impact_fire" if Art.has("fx", "impact_fire") else "sparkle", position + Vector2(0, -6), 14.0, 0.4)
	_anim_t += delta
	_hit_flash = maxf(0.0, _hit_flash - delta)
	_tele_flash = maxf(0.0, _tele_flash - delta)
	_flash = maxf(0.0, _flash - delta * 7.0)
	_stun = maxf(0.0, _stun - delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	_squash = maxf(0.0, _squash - delta * 5.0)
	if _flash_mat and _flash != _flash_sent:
		_flash_sent = _flash  # only touch the material when the flash changes
		_flash_mat.set_shader_parameter("flash", _flash)
	var player := map.player
	# Who am I fighting? Whoever hurt me last, or an ally of yours that is much
	# closer than you are. Enemies defend themselves against the pup and friends.
	_aggro_t = maxf(0.0, _aggro_t - delta)
	var tgt: Node2D = player
	var pd_player := position.distance_to(player.position)
	for ally: Node2D in map.allies():
		var ad := position.distance_to(ally.position)
		if ad > 110.0:
			continue
		if (_aggro == ally and _aggro_t > 0.0) or (ad + 18.0 < pd_player and ad < 80.0 and not (_aggro == player and _aggro_t > 0.0)):
			if tgt == player or ad < position.distance_to(tgt.position):
				tgt = ally
	var to := tgt.position - position
	var dist := to.length()
	# A veiled player (Shade crystal / stealth drone) can't be picked out.
	if tgt == player and map.has_meta("stealth_until") and Time.get_ticks_msec() < int(map.get_meta("stealth_until")):
		dist = 9999.0
	_t -= delta
	_since_hit += delta
	_kb_t = maxf(0.0, _kb_t - delta)
	if _kb_t <= 0.0:
		_kb_hits = 0
	_lunge_cd = maxf(0.0, _lunge_cd - delta)
	_shield_cd = maxf(0.0, _shield_cd - delta)
	_range_cd = maxf(0.0, _range_cd - delta)
	_stomp_cd = maxf(0.0, _stomp_cd - delta)
	_shield = maxf(0.0, _shield - delta)
	if _tick_abilities(delta, player, to, dist, tgt):
		queue_redraw()
		return
	var stunned := _stun > 0.0
	if not stunned and _windup <= 0.0:
		var sight := 80.0
		# Something solid between us: path round it, and don't lose interest on the detour.
		_los_t -= delta
		if _los_t <= 0.0:
			_los_t = 0.25
			_los_ok = map.line_clear(position, tgt.position) if abilities.has("ranged") and tgt == player else (dist > 150.0 or _walk_clear(position, tgt.position))
		if _noticed and (not _los_ok or _chase_t > 0.0):
			sight = 140.0
		_chase_t = 3.0 if (_noticed and not _los_ok) else maxf(0.0, _chase_t - delta)
		if tgt == player and Perks.flag("quiet_steps"):
			sight = 58.0
		if tgt == player and kind.contains("wisp") and Perks.flag("wisp_safe") and hp >= max_hp:
			sight = 0.0
		if dist < sight and abilities.has("ranged") and tgt == player:
			# Shooters keep their distance: back off when you close in, hold at range.
			if not _noticed:
				_noticed = true
				map.emote(self, "surprise", 0.8, -26.0)
				Music.instance(get_tree()).sfx("alert")
			_dir = -to.normalized() * 0.8 if dist < 48.0 and _los_ok else (to.normalized() if dist > 90.0 else Vector2.ZERO)
			# No clear shot (a wall or tree line between): walk round it to find one.
			if not _los_ok:
				_dir = map.flow_dir(position, (tgt.position - map.offset()).snapped(Vector2(32, 32)) + map.offset(), 14)
		elif dist < sight and dist > reach * 0.6:
			if not _noticed:
				_noticed = true
				map.emote(self, "surprise", 0.8, -26.0)
				if tgt == player or position.distance_to(player.position) < 170.0:
					Music.instance(get_tree()).sfx("alert")
			_dir = to.normalized()
			# A wall between us: walk round it on the flow field instead of pressing into it.
			if not _los_ok:
				_dir = map.flow_dir(position, (tgt.position - map.offset()).snapped(Vector2(32, 32)) + map.offset(), 14)
			# Wolves and hounds circle you before they lunge, instead of walking into your sword.
			if kind in PACK_KINDS and dist < 48.0 and dist > reach and _lunge_cd > 0.0:
				_dir = to.normalized().orthogonal() * (1.0 if get_instance_id() % 2 == 0 else -1.0)
		elif dist <= reach * 0.6:
			_dir = Vector2.ZERO
		elif has_meta("goal"):
			# Battlefield orders: march on the objective.
			var g: Vector2 = get_meta("goal")
			_dir = map.flow_dir(position, g) if position.distance_to(g) > 20.0 else Vector2.ZERO
		elif _t <= 0.0:
			_t = randf_range(1.0, 3.0)
			_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() if randf() < 0.7 else Vector2.ZERO
	# Keep a little distance from other enemies so they don't stack.
	var sep := Vector2.ZERO
	for o in map.enemies:
		if o != self and is_instance_valid(o):
			var d: Vector2 = position - o.position
			if d.length() < 12.0 and d.length() > 0.01:
				sep += d.normalized() * (12.0 - d.length())
	var move := (Vector2.ZERO if stunned or _windup > 0.0 else _dir * speed) + _knock + sep * 4.0
	_knock = _knock.move_toward(Vector2.ZERO, 520.0 * delta)
	_slide(move * delta)
	# Attacks telegraph: wind up, then strike if you're still in reach.
	if _windup > 0.0:
		_windup -= delta
		if _windup <= 0.0:
			if tgt != player:
				if dist < reach + 6.0 and tgt.has_method("take_damage"):
					tgt.call("take_damage", maxi(1, damage + int(tier / 2)), position)
			elif dist < reach + 4.0 and player.invuln <= 0.0:
				player.take_damage(GameState.enemy_damage(damage), position)
				if inflicts != "":
					GameState.status_apply(inflicts, tier)
			_cooldown = 1.1
	elif not stunned and dist < reach and _cooldown <= 0.0:
		_windup = (0.32 + 0.04 * clampi(damage - 2, 0, 10)) * (1.35 if kind.begins_with("thug_") and Crew.perk_level("doors") >= 1 else 1.0)
		if _sprite and _sprite.sprite_frames.has_animation("attack"):
			_sprite.play("attack")
		_attacking = 0.45
	_attacking = maxf(0.0, _attacking - delta)
	if _sprite:
		var want := "hurt" if _hit_flash > 0.0 else ("attack" if _attacking > 0.0 else ("walk" if _dir != Vector2.ZERO and not stunned else "idle"))
		if not _sprite.sprite_frames.has_animation(want):
			want = "idle" if want != "attack" or not _sprite.sprite_frames.has_animation("walk") else "walk"
		if _sprite.animation != want:
			_sprite.play(want)
		if _dir.x != 0.0:
			_sprite.flip_h = _dir.x < 0
		elif to.x != 0.0 and dist < 80.0:
			_sprite.flip_h = to.x < 0
		var tint := Color(1, 1, 1)
		if _windup > 0.0 or _lunge_tele > 0.0:
			tint = Color(1.0, 0.75, 0.7)
		if _shield > 0.0:
			tint = Color(0.6, 0.8, 1.0)
		elif _enraged:
			tint = Color(1.0, 0.55, 0.5)
		_sprite.modulate = tint
		var bs := 1.1 if kind == "big_grump" and not Art.has("enemies/big_grump", "idle") else 0.5
		_sprite.scale = Vector2(bs * (1.0 + _squash * 0.25), bs * (1.0 - _squash * 0.3)) if kind != "big_grump" else Vector2(bs, bs)
	# Redraw (hp bar, shadow, telegraph icon) only when what it shows changes.
	# Packed into one int (no per-frame string format): hp, max_hp, 8 flags, tier, shadow, telegraph/regen.
	var flags := int(_shield > 0.0) | int(_lunge_tele > 0.0 or _lunge > 0.0) << 1 | int(_range_tele > 0.0) << 2 | int(_stomp_tele > 0.0) << 3 \
		| int(_enraged) << 4 | int(_hit_flash > 0.0) << 5 | int(_since_hit < 0.3) << 6 | int(is_guardian) << 7
	var sig := (clampi(hp, 0, 0xFFFF)) | (clampi(max_hp, 0, 0xFFFF) << 16) | (flags << 32) | (clampi(tier, 0, 15) << 40) \
		| (clampi(int(round(_shadow_r * 10.0)), 0, 255) << 44) | ((int(_tele_flash > 0.0) * 2 + int(abilities.has("regen") and _since_hit > 3.0 and hp < max_hp)) << 52)
	if _sprite == null or sig != _draw_sig:
		_draw_sig = sig
		queue_redraw()


var _aggro: Node2D
var _aggro_t := 0.0


## Called by whoever just hit me: I turn on them for a few seconds.
func provoke(by: Node2D) -> void:
	_aggro = by
	_aggro_t = 4.0
	_noticed = true


## Move with wall sliding (x then y) so knockback never cancels outright.
func _slide(step: Vector2) -> void:
	var feet := Rect2(Vector2(-4, -3), Vector2(8, 3))
	var nx := position + Vector2(step.x, 0)
	if not map.rect_blocked(Rect2(nx + feet.position, feet.size)):
		position = nx
	else:
		_knock.x = 0
		if _dir.x != 0.0 and _stun <= 0.0:
			_dir.x = -_dir.x
	var ny := position + Vector2(0, step.y)
	if not map.rect_blocked(Rect2(ny + feet.position, feet.size)):
		position = ny
	else:
		_knock.y = 0
		if _dir.y != 0.0 and _stun <= 0.0:
			_dir.y = -_dir.y


## `magic`: spells pierce half the armour and don't feed the anti-kite counter.
func hit(n: int, from: Vector2, magic := false, ally := false, tick := false) -> bool:
	if not _alive:
		return false
	if _shield > 0.0:
		map.fx("sparkle", position + Vector2(0, -10), 14.0, 0.4)
		map.damage_number(position + Vector2(0, -20), 0, Color(0.6, 0.8, 1.0))
		return false
	if _gift:
		var mult := _gift.vuln(from, magic)
		if mult <= 0.0:
			if not tick:
				_gift.on_blocked()  # a burn tick bouncing off isn't a swing to answer
			return false
		n = maxi(1, int(round(n * mult)))
		if not tick: _gift.on_hit(mult)
	if ally:
		n = int(round(n * hp_scale))
	var soak := armor / 2 if magic else armor
	n = maxi(1, n - soak)
	last_applied = n
	hp -= n
	_since_hit = 0.0
	_hit_flash = 0.22
	_flash = 1.0
	_squash = 1.0
	# Only the weakest pests flinch out of an attack; anything tougher finishes
	# its swing (the red wind-up tint tells you to step back).
	if tick:
		pass  # a burn tick: no flinch, no knockback, no stun
	elif tier == 0 and _kb_hits < 1:
		_windup = 0.0
	# Knockback: lighter for heavy kinds, cut by the tier's resistance, and it
	# decays with every quick repeat so you can't juggle something forever.
	if not magic:
		_kb_hits += 1
		_kb_t = 1.6
	var combo := maxf(0.25, 1.0 - 0.3 * maxi(0, _kb_hits - 1))
	if not tick:
		_stun = maxf(_stun, (0.32 if base_hp < 30 else 0.15) * combo * (1.0 - kb_resist * 0.6))
	var heavy := 1.0 if base_hp < 16 else (0.55 if base_hp < 40 else 0.3)
	_knock = (position - from).normalized() * (230.0 if tier == 0 else 150.0) * heavy * combo * (1.0 - kb_resist) * (1.3 if GameState.has_perk("combat", "Acrobat") else 1.0)
	# Juggled three times: answer with a lunge the moment the stun ends.
	if _kb_hits >= 3 and abilities.has("lunge") and _lunge_cd <= 0.0 and not (_gift and _gift.open_t > 0.0):
		_lunge_tele = 0.18
		_lunge_cd = 2.5
	# Hit one of a pack and the rest come running.
	if kind in PACK_KINDS and not magic:
		for o in map.enemies:
			if o != self and is_instance_valid(o) and o.kind == kind and o.position.distance_to(position) < 70.0:
				o._noticed = true
				o.provoke(map.player)
	if not tick and abilities.has("blink") and hp > 0 and randf() < 0.5:
		_blink()
	if abilities.has("summon") and hp > 0:
		for frac in [0.6, 0.3]:
			if float(hp) / max_hp <= frac and not _summoned.has(frac):
				_summoned[frac] = true
				_summon()
	if hp <= 0:
		if has_meta("marked") and not has_meta("decoy"):
			hp = 1
			Marked.yield_to(map, self)
			return true
		_die()
	return true


# ---- abilities ---------------------------------------------------------------
## Returns true when the ability took the whole frame (lunging / stomping).
func _tick_abilities(delta: float, player: Player, to: Vector2, dist: float, tgt: Node2D = null) -> bool:
	if tgt == null:
		tgt = player
	if abilities.has("enrage") and not _enraged and float(hp) / max_hp < 0.35:
		_enraged = true
		speed *= 1.35
		damage += 1
		map.emote(self, "angry", 1.0, -26.0)
		map.fx("enrage", position + Vector2(0, -10), 12.0, 0.6)
	if _shield > 0.0:
		_set_aura("aura_shield")
	elif _enraged:
		_set_aura("aura_enraged")
	elif _boosted:
		_set_aura("tier_aura_%d" % clampi(tier, 0, 5))
	elif _aura:
		_set_aura("")
	if abilities.has("regen") and _since_hit > 3.0 and hp < max_hp:
		_regen_t += delta
		if _regen_t >= 2.0:
			_regen_t = 0.0
			hp = mini(max_hp, hp + maxi(1, max_hp / 25))
			map.fx("regen", position + Vector2(0, -8), 12.0, 0.5)
	if abilities.has("shield") and _shield <= 0.0 and _shield_cd <= 0.0 and dist < 60.0 and _stun <= 0.0 and not (_gift and _gift.open_t > 0.0):
		_shield = 1.4
		_shield_cd = 6.0
		map.fx("shield_up" if Art.has("fx", "shield_up") else "sparkle", position + Vector2(0, -12), 14.0, 0.5)
	if _lunge_tele > 0.0:
		_lunge_tele -= delta
		if _lunge_tele <= 0.0 and _stun > 0.05:
			_lunge_tele = 0.05  # still stunned: the lunge waits for the stun to end
		elif _lunge_tele <= 0.0:
			_lunge = 0.28
			_lunge_dir = to.normalized()
			map.fx("lunge_trail" if Art.has("fx", "lunge_trail") else "poof", position, 16.0, 0.5, to.x < 0)
		return true
	if _lunge > 0.0:
		_lunge -= delta
		_slide(_lunge_dir * speed * 3.4 * delta)
		var pd := position.distance_to(player.position)
		if tgt != player and is_instance_valid(tgt) and position.distance_to(tgt.position) < reach + 2.0 and tgt.has_method("take_damage"):
			tgt.call("take_damage", maxi(1, damage + int(tier / 2)), position)
			_lunge = 0.0
		elif pd < reach + 2.0 and player.invuln <= 0.0:
			player.take_damage(GameState.enemy_damage(damage), position)
			if inflicts != "":
				GameState.status_apply(inflicts, tier)
			_lunge = 0.0
		return true
	if abilities.has("lunge") and _lunge_cd <= 0.0 and _stun <= 0.0 and dist > 28.0 and dist < 70.0 and randf() < 0.6 * delta and map.line_clear(position, position + to):
		_lunge_tele = 0.25
		_lunge_cd = 3.0
		map.fx("lunge_tele" if Art.has("fx", "lunge_tele") else "poof", position + Vector2(0, -4), 20.0, 0.5, to.x < 0)
	if _stomp_tele > 0.0:
		# Telegraphed: it rears up (tint) for a moment, then lands.
		_stomp_tele -= get_process_delta_time()
		modulate = Color(1.4, 1.1, 0.8)
		if _stomp_tele <= 0.0:
			modulate = Color.WHITE
			map.fx("stomp" if Art.has("fx", "stomp") else "ripple_ring", position, 16.0, 0.7)
			map.shake(2.0)
			if player.invuln <= 0.0 and position.distance_to(player.position) < 30.0:
				player.take_damage(GameState.enemy_damage(damage + 1), position)
			for ally: Node2D in map.allies():
				if position.distance_to(ally.position) < 30.0 and ally.has_method("take_damage"):
					ally.call("take_damage", damage + 1, position)
		return true
	if abilities.has("stomp") and _stomp_cd <= 0.0 and dist < 26.0 and _stun <= 0.0:
		_stomp_cd = 3.5
		_windup = 0.0
		_stomp_tele = 0.45
		return true
	if _range_tele > 0.0:
		_range_tele -= delta
		if _range_tele <= 0.0 and _stun <= 0.0:
			_shoot(_range_aim)
	elif abilities.has("ranged") and _range_cd <= 0.0 and _stun <= 0.0 and dist > 34.0 and dist < 110.0 and tgt == player and map.line_clear(position, position + to):
		_range_cd = 2.2 - 0.2 * tier
		_range_tele = 0.35  # a beat to see it coming
		_range_aim = to.normalized()
	return false


func _shoot(dir: Vector2) -> void:
	var sh := Shot.new()
	sh.map = map
	sh.dir = dir
	sh.damage = maxi(1, damage - 1)
	sh.tier = tier
	sh.inflicts = inflicts
	sh.position = position + Vector2(0, -8)
	sh.colour = Color("c8ff70") if inflicts == "poison" else (Color("ff9a40") if inflicts == "burn" else (Color("9fe0ff") if inflicts == "chill" else Color("e0c0ff")))
	sh.flavour = {"poison": "poison", "burn": "fire", "chill": "ice", "slow": "ice"}.get(inflicts, "dark")
	map.add_child(sh)
	if _sprite and _sprite.sprite_frames.has_animation("attack"):
		_sprite.play("attack")
		_attacking = 0.4
	if map.player and position.distance_to(map.player.position) < 170.0:
		Music.instance(get_tree()).sfx("shot" if sh.flavour == "dark" and Racket.on() else "zap", "thud")


func _blink() -> void:
	for tries in 8:
		var c := position + Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(36.0, 56.0)
		var feet := Rect2(c + Vector2(-4, -3), Vector2(8, 3))
		if map.in_content(map.world_to_cell(c)) and not map.rect_blocked(feet):
			map.fx("blink" if Art.has("fx", "blink") else "poof", position + Vector2(0, -8), 16.0, 0.5)
			position = c
			_knock = Vector2.ZERO
			map.fx("blink" if Art.has("fx", "blink") else "poof", position + Vector2(0, -8), 16.0, 0.5)
			_tele_flash = 0.5
			_tele_name = "blink"
			return


func _summon() -> void:
	var minion: String = {"commander": "soldier", "dark_crystal": "shard", "president": "thug_cyber", "marsh_witch": "mud_slime", "golem_king": "golem", "ruin_warden": "wisp", "prism_wisp": "shard", "light_eater": "dark_crystal_shard", "finargle_elder": "finargle"}.get(kind, "")
	if minion == "":
		# Not in the table: ordinary foes call their own kind; big ones call arc grunts.
		minion = kind if base_hp < 60 and _gift == null and not has_meta("story_flag") and not has_meta("boss_name") and not is_guardian else ("slime" if GameState.is_penguins() else "thug_cyber")
	if minion == "shard" and not GameState.is_penguins():
		minion = "thug_cyber"
	map.fx("summon" if Art.has("fx", "summon") else "poof", position, 12.0, 0.7)
	for i in 2:
		var at := position + Vector2(randf_range(-24, 24), randf_range(-16, 16))
		var e := map.spawn_enemy(str(minion), at, maxi(0, tier - 1))
		if e:
			# Summoned help pays nothing, can't summon again and never carries a Gift.
			e.reward = 0
			e.abilities.erase("summon")
			e.set_meta("minion", true)
			if e._gift:
				e._gift.queue_free()
				e._gift = null
		map.fx("poof", at + Vector2(0, -8), 14.0, 0.5)
	_tele_flash = 0.6
	_tele_name = "summon"
	map.hud.toast("It calls for help!", Color(1, 0.8, 0.7))


## A slow spit/bolt from a ranged enemy. Hits the player on contact, dies on walls.
class Shot extends Node2D:
	var map: GameMap
	var dir := Vector2.RIGHT
	var speed := 95.0
	var damage := 1
	var tier := 0
	var inflicts := ""
	var life := 1.6
	var colour := Color.WHITE
	var flavour := "dark"
	var _spr: AnimatedSprite2D = null

	func _ready() -> void:
		if Art.has("fx", "shot_" + flavour):
			_spr = AnimatedSprite2D.new()
			_spr.sprite_frames = Art.frames("fx", {"a": "shot_" + flavour}, {"a": 14.0})
			_spr.animation = "a"
			_spr.scale = Vector2(0.5, 0.5)
			add_child(_spr)
			_spr.play("a")

	func _process(delta: float) -> void:
		life -= delta
		position += dir * speed * delta
		var p := map.player
		if p and p.position.distance_to(position + Vector2(0, 6)) < 10.0 and p.invuln <= 0.0:
			p.take_damage(GameState.enemy_damage(damage), position)
			if inflicts != "":
				GameState.status_apply(inflicts, tier)
			life = 0.0
		if life <= 0.0 or map.rect_blocked(Rect2(position + Vector2(-2, -1), Vector2(4, 2))):
			var hn := "shot_%s_hit" % flavour
			if not Art.has("fx", hn):
				hn = ("impact_" + flavour) if Art.has("fx", "impact_" + flavour) else "poof"
			map.fx(hn, position, 14.0, 0.4)
			queue_free()
		# No queue_redraw: _draw is fixed relative to the shot, so moving it is enough.

	func _draw() -> void:
		if _spr:
			return
		draw_circle(Vector2.ZERO, 3.0, colour)
		draw_circle(Vector2.ZERO, 1.5, Color(1, 1, 1, 0.8))


func _die() -> void:
	_alive = false
	map.enemies.erase(self)
	if has_meta("decoy"):
		map.fx("blink" if Art.has("fx", "blink") else "poof", position + Vector2(0, -8), 14.0, 0.4)
		queue_free()
		return
	if _gift and not _gift.d.get("clones", {}).is_empty():
		for o in map.enemies.duplicate():
			if is_instance_valid(o) and o.has_meta("decoy"):
				o._die()
	map.on_enemy_died(self)
	# A puff where it stood and a thud; bosses get a bigger send-off.
	var big := bossy or is_guardian or has_meta("boss_name")
	map.fx("poof" if Art.has("fx", "poof") else "spark", position + Vector2(0, -8), 32.0 if big else 20.0, 0.6)
	if big or (map.player and position.distance_to(map.player.position) < 200.0):
		Music.instance(get_tree()).sfx("boss_down" if big else _death_sound(), "thud")
	if big:
		map.shake(5.0)
	# Sheets with a "die" strip play it, then fade; the rest get the squash.
	if _sprite and _sprite.sprite_frames.has_animation("die"):
		_sprite.play("die")
		queue_redraw()  # drop the HP bar while the die strip plays
		var sf := _sprite.sprite_frames
		var dur := clampf(sf.get_frame_count("die") / maxf(1.0, sf.get_animation_speed("die")), 0.3, 1.2)
		var tw2 := create_tween()
		tw2.tween_property(self, "position", position + _knock.normalized() * 6.0, 0.15)
		tw2.tween_interval(maxf(0.0, dur - 0.15))
		tw2.tween_property(self, "modulate:a", 0.0, 0.25)
		tw2.tween_callback(queue_free)
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", position + _knock.normalized() * 10.0, 0.2)
	tw.tween_property(self, "scale", Vector2(1.4, 0.1), 0.2)
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(queue_free)


## Nothing a walker bumps into between a and b (water counts, unlike line_clear).
func _walk_clear(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var steps := int(d.length() / 4.0)
	for i in range(1, steps):
		# The feet box, not a thin line: a body that clips a wall corner can't walk straight.
		if map.rect_blocked(Rect2(a + d * (float(i) / steps) + Vector2(-4, -3), Vector2(8, 3))):
			return false
	return true


func _draw() -> void:
	draw_circle(Vector2(0, 0), _shadow_r, Color(0, 0, 0, 0.2))
	if max_hp > 3 and _alive:
		var top := _bar_top()
		draw_rect(Rect2(-10, top, 20, 3), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-10, top, 20.0 * hp / max_hp, 3), Color(0.9, 0.2, 0.2) if _shield <= 0.0 else Color(0.5, 0.7, 1.0))
		if tier > 0 and Art.has("ui", "tier_pip_%d" % tier):
			var pt := Art.tex("ui", "tier_pip_%d" % tier)
			draw_texture(pt, Vector2(-pt.get_width() / 2.0, top - 4 - pt.get_height()))
		else:
			for i in tier:
				draw_rect(Rect2(-10 + i * 4, top - 4, 3, 2), Color(1.0, 0.85, 0.3))
	var tele := ""
	if _lunge_tele > 0.0 or _lunge > 0.0:
		tele = "lunge"
	elif _shield > 0.0:
		tele = "shield"
	elif _range_tele > 0.0:
		tele = "ranged"
	elif _stomp_tele > 0.0:
		tele = "stomp"
	elif _tele_flash > 0.0:
		tele = _tele_name
	elif abilities.has("regen") and _since_hit > 3.0 and hp < max_hp:
		tele = "regen"
	elif _enraged and _since_hit < 0.3:
		tele = "enrage"
	if tele != "" and Art.has("ui", "tele_" + tele):
		var tt := Art.tex("ui", "tele_" + tele)
		draw_texture(tt, Vector2(-tt.get_width() / 2.0, _bar_top() - 4.0 - tt.get_height()))
	if is_guardian and Art.has("ui", "guardian_crown"):
		var cr := Art.tex("ui", "guardian_crown")
		draw_texture_rect(cr, Rect2(-6, _bar_top() - 40, 12, 10), false)
	if is_guardian and Art.has("ui", "keeper_crest_0"):
		var kc := Art.tex("ui", "keeper_crest_%d" % clampi(tier, 0, 5))
		draw_texture_rect(kc, Rect2(-8, _bar_top() - 22, 16, 16), false)
	if _sprite:
		return
	# Procedural fallback: a stormy little cloud.
	var s := 1.0 if kind != "big_grump" else 1.9
	var col := Color("6a6a7a") if _hit_flash <= 0.0 else Color(1, 1, 1)
	var bob := sin(_anim_t * 6.0) * 1.5
	draw_circle(Vector2(-4 * s, -8 * s + bob), 5 * s, col)
	draw_circle(Vector2(3 * s, -9 * s + bob), 6 * s, col)
	draw_circle(Vector2(0, -5 * s + bob), 5.5 * s, col)
	draw_rect(Rect2(-3 * s, -9 * s + bob, 2 * s, 2 * s), Color(1, 0.9, 0.3))
	draw_rect(Rect2(1.5 * s, -9 * s + bob, 2 * s, 2 * s), Color(1, 0.9, 0.3))


## The name shown on the boss bar.
func display_name() -> String:
	if has_meta("marked"):
		var d: Dictionary = Marked.all().get(str(get_meta("marked")), {})
		return "%s \"%s\"" % [str(d.get("name", "")), str(d.get("epithet", ""))]
	if has_meta("boss_name"):
		return str(get_meta("boss_name"))
	var ed: Dictionary = GameState.enemy_data.get("enemies", {}).get(kind, {})
	if ed.has("name"):
		return str(ed["name"])
	return kind.replace("thug_", "").replace("_", " ").capitalize()


## A small foe's send-off, by what it is.
func _death_sound() -> String:
	var k := kind.to_lower()
	if "slime" in k or "blob" in k or "ooze" in k:
		return "slime"
	if "bat" in k:
		return "bat"
	if "golem" in k or "rock" in k or "stone" in k or "crystal" in k:
		return "rock_break"
	if "bot" in k or "drone" in k or "robot" in k or "cyber" in k:
		return "power_off"
	if "spirit" in k or "ghost" in k or "wisp" in k or "shade" in k:
		return "spirit"
	if "bug" in k or "beetle" in k or "wasp" in k or "spider" in k:
		return "bug"
	return "die"

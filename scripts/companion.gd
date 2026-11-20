class_name Companion
extends Node2D
## A party member who walks with you (data/companions.json). One active at a
## time (run["party"]["active"]); recruited ones live in run["party"]["known"].
## Abilities apply only while active (see GameState.party_has()).

var id := ""
var map: GameMap
var anim: AnimatedSprite2D
var _idle := 0.0


static var _data := {}


## Sal never fences things quests ask for.
## Partner ability cues (others play "spell"). Meow Pow Wow meows (the cat's own voice).
const ABILITY_SFX := {"meow_pow_wow": "meow", "powerup": "power_up", "haul": "pickup", "scout": "whistle",
	"tinker": "tools", "bee_bop": "stun"}

const FENCE_KEEP := ["fossil", "old_coin", "pearl", "knight_shard", "sacred_key", "manifest", "brass_locket", "old_collar"]
static var _fence_t := 0
static var _fence_pick := ""

static func data() -> Dictionary:
	if _data.is_empty():
		_data = GameState.load_json("res://data/companions.json")
	return _data


static func defs() -> Dictionary:
	return data().get("companions", {})


static func party() -> Dictionary:
	var p: Dictionary = GameState.run.get("party", {})
	if p.is_empty():
		p = {"active": "", "known": [], "bitter": [], "refused": {}}
		GameState.run["party"] = p
	for k in ["known", "bitter"]:
		if not p.has(k):
			p[k] = []
	if not p.has("refused"):
		p["refused"] = {}
	return p


static func active_id() -> String:
	return str(party().get("active", ""))


static func active_name() -> String:
	var id := active_id()
	if id == "":
		return ""
	return str(defs().get(id, {}).get("name", id.capitalize()))


static func has_ability(ab: String) -> bool:
	# The merkitties' gift: once sung over, anyone grows a tail in water.
	if ab == "tail" and GameState.run["flags"].has("mermaid_gift"):
		return true
	var a := active_id()
	if a == "":
		return false
	return str(defs().get(a, {}).get("ability", "")) == ab


## Meow Pow Wow turns the Dark Crystal's work back; rank (from Nova's friendship
## hearts / 2, min 1) decides how big a foe it reaches. Grumps were crystals of
## Crystopia that listened to him: they shake off the grey and float home as a
## little crystal ("@crystal"). Crystal babies calm down and toddle back to their
## caves ("@calm"); finargles blink and slip away into the shadows ("@vanish").
## Other creatures he squeezed turn back into the animal they were (C7 c7_01).
const REVERT := {"crystal_baby": ["@calm", 1], "finargle": ["@vanish", 3], "finargle_elder": ["@vanish", 4], "grump": ["@crystal", 1], "mud_slime": ["frog", 1], "slime": ["frog", 1], "bat": ["sparrow", 1], "wisp": ["firefly", 2], "ice_wisp": ["firefly", 2], "shard": ["@crystal", 2], "hill_wolf": ["fox", 3], "rock_crab": ["crab", 2], "golem": ["goat", 3], "quarry_golem": ["goat", 4], "big_grump": ["@crystal", 4], "bog_hag": ["heron", 4], "river_serpent": ["otter", 4]}


## What a reverted foe leaves behind for the "@" outcomes: a floating crystal, or
## a copy of the foe that walks off / fades into shadow.
static func revert_show(m: GameMap, e: Node2D, how: String) -> void:
	if how == "@crystal":
		var sp := Sprite2D.new()
		sp.texture = Art.tex("items", "crystal")
		sp.position = e.position + Vector2(0, -6)
		sp.scale = Vector2(0.6, 0.6)
		sp.z_index = 5
		m.add_child(sp)
		if Art.has("fx", "glow_crystal"):
			m.fx("glow_crystal", sp.position, 8.0, 1.4)
		var tw := sp.create_tween()
		tw.tween_property(sp, "position:y", sp.position.y - 48.0, 1.6).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sp, "modulate:a", 0.0, 1.6).set_delay(0.6)
		tw.tween_callback(sp.queue_free)
		return
	var src: Variant = e.get("_sprite")
	if not (src is AnimatedSprite2D):
		return
	var ghost := (src as AnimatedSprite2D).duplicate() as AnimatedSprite2D
	ghost.position = e.position + (src as AnimatedSprite2D).position
	ghost.z_index = 4
	m.add_child(ghost)
	ghost.modulate = Color(1, 1, 1, 1)
	ghost.play(ghost.animation)
	var tw2 := ghost.create_tween()
	if how == "@calm":
		var away := Vector2(randf_range(-1.0, 1.0), -0.6).normalized() * 40.0
		tw2.tween_property(ghost, "position", ghost.position + away, 2.2)
		tw2.parallel().tween_property(ghost, "modulate:a", 0.0, 0.8).set_delay(1.4)
	else:
		tw2.tween_property(ghost, "modulate", Color(0.2, 0.15, 0.3, 0.0), 0.9)
	tw2.tween_callback(ghost.queue_free)


static func meow_rank() -> int:
	# Grows with Nova's friendship and with how far the story has gone (each
	# chapter's spark makes it reach bigger things).
	var base := maxi(GameState.friend_hearts("penguin_f") / 2 + 1, GameState.progress_tier() + 1)
	return maxi(1, base + int(GameState.bonus("magic", "spell_power") * 2)) + Sanctuary.meow_bonus()


## Once Catkins has taught it, the Meow Pow Wow is the player's own: hold B near
## something it can turn back. Otherwise B-hold uses the active partner's ability.
static func ability_for(m: GameMap, p: Player) -> String:
	var partner := str(defs().get(active_id(), {}).get("ability", ""))
	if partner == "meow_pow_wow" and not meow_known():
		return "meow_wait"
	if GameState.is_penguins() and meow_known():
		for e in m.enemies.duplicate():
			if is_instance_valid(e) and e.position.distance_to(p.position) <= 70.0 and (REVERT.has(e.kind) or e.kind == "knight"):
				return "meow_pow_wow"
		if partner == "":
			return "meow_pow_wow"
	return partner


## The Meow Pow Wow is earned in the story: Catkins teaches it in Cat-topia
## (flag meow_taught, story beat p2_catkins). Until then Nova feels it but can't
## let it out, and her ability says so.
static func meow_known() -> bool:
	return not GameState.run.is_empty() and GameState.run.get("flags", {}).has("meow_taught")


## Ability name/description as shown for `cid` right now (Nova's waits for Catkins).
static func ability_name(cid: String) -> String:
	var cd: Dictionary = defs().get(cid, {})
	if str(cd.get("ability", "")) == "meow_pow_wow" and not meow_known():
		return str(cd.get("ability_name_wait", "Meow Pow Wow (not yet)"))
	return str(cd.get("ability_name", ""))


static func ability_desc(cid: String) -> String:
	var cd: Dictionary = defs().get(cid, {})
	if str(cd.get("ability", "")) == "meow_pow_wow" and not meow_known():
		return str(cd.get("ability_desc_wait", cd.get("ability_desc", "")))
	return str(cd.get("ability_desc", ""))


## What Nova says when you ask for the Meow Pow Wow before Catkins has taught it.
static func meow_wait_line() -> String:
	var cd: Dictionary = defs().get("penguin_f", {})
	var fl: Dictionary = GameState.run.get("flags", {})
	if int(fl.get("reverted", 0)) > 0:
		return str(cd.get("wait_line_old", cd.get("wait_line", "")))
	return str(cd.get("wait_line", ""))


## Seconds between uses of each partner ability (gifts cost mana instead).
const COOLDOWN := {"mend": 20.0, "powerup": 12.0, "bee_bop": 10.0, "meow_pow_wow": 6.0}
const DEFAULT_COOLDOWN := 8.0
static var _ready_at := {}


## Seconds left before `ab` can be used again (0 when ready).
static func cooldown_left(ab: String) -> float:
	return maxf(0.0, float(_ready_at.get(ab, 0.0)) - Time.get_ticks_msec() / 1000.0)


static func use_ability(m: GameMap, p: Player) -> void:
	var ab := ability_for(m, p)
	if ab == "":
		return
	if ab.begins_with("gift:"):
		# Gift powers rest too (8 s), so a lent guard can't be held forever.
		var gl := cooldown_left(ab)
		if gl > 0.0:
			m.hud.toast("Ready in %ds." % int(ceil(gl)), Color(0.8, 0.85, 1.0))
			Music.instance(m.get_tree()).sfx("nope", "thud")
			return
		# Check mana first (same rule as GameState.spend_mana), so a short cast costs no cooldown.
		var cost := int(Gift.def(ab.trim_prefix("gift:")).get("mana", 8))
		var mana := int(GameState.run.get("mana", 0))
		var floor_m := 10 if GameState.bonus("magic", "awakened") > 0.0 else 0
		if mana < cost and not (floor_m > 0 and mana <= floor_m and cost <= floor_m):
			m.hud.toast("Not enough mana.", Color(0.7, 0.8, 1.0))
			Music.instance(m.get_tree()).sfx("nope", "thud")
			return
		_ready_at[ab] = Time.get_ticks_msec() / 1000.0 + 8.0
	if ab == "meow_wait":
		# Not earned yet: Nova explains, and points at Catkins (no cooldown, no XP).
		m.hud.toast(meow_wait_line(), Color(0.95, 0.85, 1.0))
		if not GameState.run["flags"].has("meow_wait_hint"):
			GameState.run["flags"]["meow_wait_hint"] = true
			GameState.add_hint("Nova's Meow Pow Wow must be taught first: find Catkins in the crystal meadow (past the east meadow).")
		return
	if ab in ["haul", "tail"]:
		# Passive helpers: the button only reminds you (no XP, no heal, no cooldown).
		m.hud.toast("Dad: 'Just point at the tree.' (Trees fall twice as fast and give 2 more wood while he's with you.)" if ab == "haul" else "Mer: 'The water's right there.'", Color(0.9, 0.95, 1.0))
		return
	if not ab.begins_with("gift:") and ab != "fence":
		var left := cooldown_left(ab)
		if left > 0.0:
			m.hud.toast("Ready in %ds." % int(ceil(left)), Color(0.8, 0.85, 1.0))
			Music.instance(m.get_tree()).sfx("nope", "thud")
			return
		GameState.add_arc_xp(3)
		GameState.add_xp("leadership", 4)
		_ready_at[ab] = Time.get_ticks_msec() / 1000.0 + float(COOLDOWN.get(ab, DEFAULT_COOLDOWN)) * maxf(0.3, 1.0 - GameState.bonus("harmony", "ability_cooldown") - GameState.bonus("leadership", "ability_cooldown"))
		var th := int(GameState.bonus("leadership", "team_heal"))
		if th > 0:
			GameState.run["hp"] = mini(int(GameState.run["max_hp"]), int(GameState.run["hp"]) + th)
	# Each ability its own cue (c6_08_18): lent Gifts by family, partners by ability.
	var cue := "spell"
	if ab.begins_with("gift:"):
		cue = Gift.sfx_for(ab.trim_prefix("gift:"))
	else:
		cue = str(ABILITY_SFX.get(ab, "spell"))
	Music.instance(m.get_tree()).sfx(cue, "spell")
	# Prompts-12 partner art: cast pose + the partner's own effect strip.
	var sprite_id := str(defs().get(active_id(), {}).get("sprite", active_id()))
	if Art.has("fx", "ability_" + sprite_id):
		m.fx("ability_" + sprite_id, p.position + Vector2(0, -10), 10.0, 0.6)
	if ab.begins_with("gift:"):
		if m.companion:
			m.companion.play_power()
		Gift.cast(m, p, ab.trim_prefix("gift:"))
		return
	match ab:
		"meow_pow_wow":
			var rank := meow_rank()
			var n := 0
			for e in m.enemies.duplicate():
				if not is_instance_valid(e) or not e._alive or e.position.distance_to(p.position) > 70.0:
					continue
				var rv: Array = REVERT.get(e.kind, [])
				if e.kind == "knight" and GameState.run["flags"].has("knight_mercy_try") and not GameState.run["flags"].has("boss_sky") and not GameState.run["flags"].has("knight_reverted") and m.scene_id() == "sky" and float(e.hp) / e.max_hp < 0.34:
					rv = ["penguin", 1]
					GameState.run["flags"]["knight_reverted"] = true
				# Fennimore: only turned back once she doubts him (the prison talk), and
				# then she's freed, not made into an owl.
				if str(e.get_meta("story_flag", "")) == "boss_fennimore":
					if not GameState.run["flags"].has("fennimore_turnable"):
						m.emote(e, "confused", 0.8)
						m.hud.toast("The purple light holds. She isn't ready to listen.", Color(0.9, 0.8, 1.0))
						continue
					GameState.run["flags"]["fennimore_free"] = true
					m.fx("meow_pow_wow" if Art.has("fx", "meow_pow_wow") else "sparkle", e.position + Vector2(0, -8), 12.0, 0.6)
					m.hud.toast("Fennimore's crown goes out. She blinks, and she's herself.", Color(0.85, 0.95, 1.0))
					e.set_meta("reverted", true)
					e._die()
					n += 1
					continue
				if rv.is_empty() or int(rv[1]) > rank:
					m.emote(e, "confused", 0.8)
					continue
				m.fx("meow_pow_wow" if Art.has("fx", "meow_pow_wow") else "sparkle", e.position + Vector2(0, -8), 12.0, 0.6)
				if str(rv[0]) == "penguin":
					# Grandfather Auk, himself again: a penguin where the Knight stood.
					var pg := CharacterLibrary.make_sprite("penguin")
					if pg:
						pg.position = e.position
						pg.play("idle")
						m.add_child(pg)
				elif str(rv[0]).begins_with("@"):
					revert_show(m, e, str(rv[0]))
				else:
					WorldGen.add_critters(m, Rect2i(m.world_to_cell(e.position) - Vector2i(2, 2), Vector2i(5, 5)), int(Time.get_ticks_msec()), 1, [str(rv[0])])
				e.set_meta("reverted", true)
				e._die()
				n += 1
			GameState.run["flags"]["reverted"] = int(GameState.run["flags"].get("reverted", 0)) + n
			m.hud.toast("Meow Pow Wow! %d turned back." % n if n > 0 else "Meow Pow Wow... nothing here to turn back (rank %d)." % rank, Color(1, 0.85, 0.95))
			m.shake(2.0)
			m.xp("magic", 3 * n)
		"powerup":
			for e in m.enemies.duplicate():
				if is_instance_valid(e) and e._alive and e.position.distance_to(p.position) < 70.0:
					e._stun = maxf(e._stun, 2.0)
			GameState.restore_mana(5)
			m.fx("pawring", p.position + Vector2(0, -6), 12.0, 0.8)
			if p.has_anim("powerup"):
				p._busy = true
				p._apply("powerup", false, true)
			m.hud.toast("Power Pose! +5 mana, grumps stunned.", Color(0.85, 0.9, 1.0))
		"haul":
			m.hud.toast("Dad: 'Just point at the tree.' (Trees fall twice as fast and give 2 more wood while he's with you.)", Color(0.9, 0.9, 0.9))
		"scout":
			var n := 0
			var pc := p.cell()
			for c in m.things:
				var t := str(m.things[c].get("type", ""))
				if t in ["forage", "mrock", "fruit"] and (c as Vector2i).distance_to(pc) <= 10.0:
					m.fx("sparkle", m.cell_center(c) + Vector2(0, -6), 10.0, 0.5)
					n += 1
			m.hud.toast("Pax: '%d things worth grabbing round here.'" % n, Color(0.9, 1.0, 0.9))
		"tinker":
			m.hud.toast("Kairi: 'Bag's open. Don't ask how.'", Color(0.9, 1.0, 0.9))
			for ch in m.get_children():
				if ch is GameMenu:
					(ch as GameMenu).toggle()
					break
		"bee_bop":
			Music.instance(m.get_tree()).sfx("stun")
			# Coldy stamps: a ring that cracks the ground; grumps in it stagger.
			m.fx("stomp" if Art.has("fx", "stomp") else "ripple_ring", p.position, 16.0, 0.8)
			m.shake(3.0)
			var hits := 0
			for e in m.enemies.duplicate():
				if is_instance_valid(e) and e._alive and e.position.distance_to(p.position) < 44.0:
					e.hit(2 + meow_rank(), p.position, false, true)
					e._stun = maxf(e._stun, 0.8)
					hits += 1
			m.hud.toast("Coldy: 'BEE BOP BOO BABY.'" if hits > 0 else "Coldy: 'Bee bop boo... nobody.'", Color(0.8, 0.9, 1.0))
		"muscle":
			var fc: Vector2i = p.facing_cell()
			var th: Dictionary = m.things.get(fc, {})
			var tt := str(th.get("type", ""))
			if tt in ["rock", "mrock"] and GameState.ore_block(str(th.get("ore", "stone"))) != "":
				m.hud.toast("Big Jim: 'That one's too tough even for me. Get a better pickaxe.'", Color(1, 0.9, 0.8))
				Music.instance(m.get_tree()).sfx("nope", "thud")
			elif tt in ["rock", "mrock", "stump", "log"]:
				# He breaks it himself: no tool, no energy.
				m.clear_cell(fc)
				var in_mine: bool = m.scene_id() == "mine"
				if not in_mine:
					m._mark_cleared(fc)  # the mine rebuilds its floors and never reads this
				if m.has_method("_try_more"):
					m.call("_try_more", 1)  # mine: counts toward the way down
				if m.has_method("redraw_cell"):
					m.call("redraw_cell", fc)  # chunked mine: redraw the rock's chunk
				if tt in ["rock", "mrock"]:
					m.give("stone", 2 if in_mine else 3)
					var ore := str(th.get("ore", ""))
					if ore != "" and ore != "stone":
						m.give(ore, 1)
					if in_mine:
						m.xp("mining", 3 if ore in ["", "stone"] else 6)
				else:
					m.give("wood", 3)
				m.fx("stone_chips" if tt in ["rock", "mrock"] else "wood_chips", m.cell_center(fc) + Vector2(0, -8), 16.0, 0.5)
				m.shake(3.0)
				Music.instance(m.get_tree()).sfx("rock_break" if tt in ["rock", "mrock"] else "timber", "thud")
				m.hud.toast("Big Jim: 'Next.'", Color(1, 0.9, 0.8))
			else:
				m.hud.toast("Big Jim: 'Point me at something.'", Color(1, 0.9, 0.8))
				Music.instance(m.get_tree()).sfx("nope", "thud")
		"fence":
			var best := ""
			var bv := 0
			for id in GameState.run["inventory"].keys():
				var v := GameState.item_value(str(id))
				# Only loot: enemy drops, junk, ore and treasure. Never gear, food or keys.
				if v > bv and str(GameState.items.get(id, {}).get("type", "")) in ["drop", "junk", "treasure", "ore"] and not str(id) in FENCE_KEEP and not GameState.is_locked(str(id)) and not DecorSources.keeps(str(id)) and not (Collections.in_log("museum", str(id)) and not (Collections.st()["donated"] as Dictionary).has(str(id))):  # C10a P4: never fence a one-of-a-kind or an undonated museum piece
					bv = v
					best = str(id)
			# One tap names the deal, a second tap within 5 seconds makes it.
			var now := Time.get_ticks_msec()
			if best != "" and (_fence_pick != best or now - int(_fence_t) > 5000):
				_fence_pick = best
				_fence_t = now
				m.hud.toast("Sal: 'All %d %s for ◆%d? Ask again and it's done.'" % [GameState.count(best), GameState.item_name(best), GameState.sell_price(best, GameState.count(best))], Color(1, 0.9, 0.6))
			elif best != "" and cooldown_left("fence") > 0.0:
				m.hud.toast("Sal: 'Give me %ds to find a buyer.'" % int(ceil(cooldown_left("fence"))), Color(1, 0.9, 0.6))
			elif best != "":
				_fence_pick = ""
				_ready_at["fence"] = Time.get_ticks_msec() / 1000.0 + float(COOLDOWN.get("fence", DEFAULT_COOLDOWN))
				var n := GameState.count(best)
				GameState.add_item(best, -n)
				Collections.record_ship(best, n)  # shipping log (C8 P3)
				var pay := GameState.sell_price(best, n)
				var sold: Dictionary = GameState.run.get("sold_today", {})
				sold[best] = int(sold.get(best, 0)) + n
				GameState.run["sold_today"] = sold
				GameState.add_money(pay, "sales")
				m.hud.toast("Sal moved %d %s for ◆%d. No questions." % [n, GameState.item_name(best), pay], Color(1, 0.9, 0.6))
				Music.instance(m.get_tree()).sfx("coin", "pickup")
				m.fx("sparkle", p.position + Vector2(0, -12), 10.0, 0.5)
			else:
				m.hud.toast("Sal: 'Nothing worth moving. Bring me loot.'", Color(1, 0.9, 0.6))
				Music.instance(m.get_tree()).sfx("nope", "thud")
		"tail":
			m.hud.toast("Mer: 'The water's right there.'", Color(0.8, 0.95, 1.0))
		"mend":
			GameState.heal_points(10)
			m.fx("heal", p.position + Vector2(0, -10), 10.0, 0.6)
			m.hud.toast("Mom: 'Hold still.' +10 health.", Color(1, 0.8, 0.8))


static func recruit(cid: String, make_active := true) -> void:
	# You can't recruit yourself (playing as Coldy, Mer or Big Jim).
	if cid == str(GameState.run.get("playable", "")):
		return
	var p := party()
	if not cid in p["known"]:
		p["known"].append(cid)
	p["bitter"].erase(cid)
	# Back with you: nobody is bitter about leaving any more.
	if GameState.run["flags"].has("gone_east_" + cid):
		GameState.run["flags"].erase("gone_east_" + cid)
		if not GameState.run["flags"].keys().any(func(k: Variant) -> bool: return str(k).begins_with("gone_east_")):
			GameState.run["flags"].erase("bitter_left")
	p["refused"].erase(cid)
	if make_active:
		p["active"] = cid
	GameState.run["flags"]["party_" + cid] = true


static func refuse(cid: String) -> void:
	var p := party()
	if cid in p["known"]:
		return
	p["refused"][cid] = int(p["refused"].get(cid, 0)) + 1
	if int(p["refused"][cid]) >= 2 and not cid in p["bitter"]:
		p["bitter"].append(cid)
		GameState.add_hint("%s took that hard. People who feel unwanted go looking for somewhere they're wanted." % str(defs().get(cid, {}).get("name", cid)))


var _mend_t := 0.0


func setup(cid: String, m: GameMap) -> void:
	id = cid
	map = m
	var d: Dictionary = defs().get(cid, {})
	var sprite := str(d.get("sprite", "man"))
	if sprite.begins_with("cat_") or sprite.begins_with("dog_"):
		anim = AnimatedSprite2D.new()
		anim.sprite_frames = Art.frames("animals/" + sprite, {"idle": "idle", "walk": "walk", "run": "run"}, {"idle": 2.0, "walk": 8.0, "run": 12.0})
		anim.scale = Vector2(0.5, 0.5)
		anim.frame_changed.connect(_fit_offset)
		anim.animation_changed.connect(_fit_offset)
	elif CharacterLibrary.has_character(sprite):
		anim = CharacterLibrary.make_sprite(sprite)
	else:
		anim = CharacterLibrary.make_sprite("man")
	if d.has("tint"):
		anim.modulate = Color(str(d["tint"]))
	add_child(anim)
	anim.play("idle")
	if sprite.begins_with("cat_") or sprite.begins_with("dog_"):
		_fit_offset()  # the first frame too, not only from the next frame change
	y_sort_enabled = true


## Cat/dog partner strips are bottom-anchored by hand: lift by half the frame height.
func _fit_offset() -> void:
	if anim == null or anim.sprite_frames == null:
		return
	var tex := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	if tex:
		anim.offset = Vector2(0, -tex.get_height() / 2.0)


var _moving := false
var _vert := false
var _power_t := 0.0  # the power pose is playing: walk/idle wait for it


## A Marked partner strikes their power pose (their "power" strip) once.
func play_power() -> void:
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("power"):
		_power_t = anim.sprite_frames.get_frame_count("power") / maxf(1.0, anim.sprite_frames.get_animation_speed("power"))
		anim.flip_h = map != null and map.player != null and map.player.position.x < position.x
		anim.play("power")
var _rest_face := "down"
var _paddle: Paddle  # in water a partner swims too (legs under a water band)


func _process(delta: float) -> void:
	if map == null or map.player == null or anim == null or map.get_tree().paused:
		return
	_power_t = maxf(0.0, _power_t - delta)
	if _paddle == null:
		var spr := str(defs().get(id, {}).get("sprite", ""))
		var beast := spr.begins_with("cat_") or spr.begins_with("dog_")
		_paddle = Paddle.attach(self, anim, map, 6.5 if beast else 6.0, 6.0 if beast else 9.0)
	var wet := _paddle.update(delta)
	var goal := map.player.position + Vector2(14, 6)
	if map.pet and map.pet.visible:
		goal = map.player.position + Vector2(16, -4)
	var to := goal - position
	var dist := to.length()
	# Hysteresis: start walking a bit past the stop distance (no walk/idle flicker).
	if _moving:
		_moving = dist > 18.0
	else:
		_moving = dist > 30.0
	if dist > 140.0:
		position = goal
		map.fx("sparkle", position + Vector2(0, -8), 10.0, 0.4)
		return
	if _moving:
		var sp := minf(dist * 3.0, maxf(100.0, map.player.velocity.length() * 1.15))
		if map.player.mounted:
			sp = 150.0
		var step := to.normalized() * sp * delta
		var np := position + step
		if not map.rect_blocked_player(Rect2(np + Vector2(-3, -2), Vector2(6, 2)), self):
			position = np
		else:
			for alt: Vector2 in [Vector2(step.x, 0), Vector2(0, step.y)]:
				if alt != Vector2.ZERO and not map.rect_blocked_player(Rect2(position + alt + Vector2(-3, -2), Vector2(6, 2)), self):
					position += alt
					break
		var a := "walk" if dist < 48.0 or wet else "run"
		if wet and anim.sprite_frames.has_animation("swim"):
			a = "swim"
		if not anim.sprite_frames.has_animation(a):
			a = "walk"
		# Axis stickiness: only switch between side and up/down views on a clear lead.
		var vertical := absf(to.y) >= absf(to.x) * (0.87 if _vert else 1.0)
		_vert = vertical
		if vertical and anim.sprite_frames.has_animation(a + ("_up" if to.y < 0 else "_down")):
			a = a + ("_up" if to.y < 0 else "_down")
			anim.flip_h = false
		else:
			anim.flip_h = to.x < 0
		if anim.animation != a and _power_t <= 0.0:
			anim.play(a)
		anim.speed_scale = 0.6 if wet and a.begins_with("walk") else 1.0
		_rest_face = ("up" if to.y < 0 else "down") if vertical else "side"
		_idle = 0.0
	else:
		_idle += delta
		# Rest facing the way we last walked (side views keep their flip).
		var want := "idle"
		if _rest_face == "side" and anim.sprite_frames.has_animation("view_right"):
			want = "view_right"
		elif _rest_face == "up" and anim.sprite_frames.has_animation("view_back"):
			want = "view_back"
			anim.flip_h = false
		elif _rest_face != "side" and anim.sprite_frames.has_animation("idle_down"):
			anim.flip_h = false  # a front idle: no mirror
		if wet:
			want = "float" if anim.sprite_frames.has_animation("float") else ("swim" if anim.sprite_frames.has_animation("swim") else "walk")
			anim.speed_scale = 0.35 if want == "walk" else 1.0
		else:
			anim.speed_scale = 1.0
		if anim.animation != want and anim.sprite_frames.has_animation(want) and _power_t <= 0.0:
			anim.play(want)
		# Mend (Mom): 1 health every 10 s while she's close.
		if Companion.has_ability("mend"):
			_mend_t += delta
			if _mend_t >= 10.0:
				_mend_t -= 10.0
				GameState.heal_points(1)

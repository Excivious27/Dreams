class_name Companion
extends Node2D
## A party member who walks with you (data/companions.json). One active at a
## time (run["party"]["active"]); recruited ones live in run["party"]["known"].
## Abilities apply only while active (see GameState.party_has()).

var id := ""
var map: GameMap
var anim: AnimatedSprite2D
var _idle := 0.0


static func data() -> Dictionary:
	return GameState.load_json("res://data/companions.json")


static func defs() -> Dictionary:
	return data().get("companions", {})


static func party() -> Dictionary:
	var p: Dictionary = GameState.run.get("party", {})
	if p.is_empty():
		p = {"active": "", "known": [], "bitter": [], "refused": {}}
		GameState.run["party"] = p
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


## Grumps were villagers' animals once. Meow Pow Wow turns them back; rank
## (from Nova's friendship hearts / 2, min 1) decides how big a grump it reaches.
const REVERT := {"crystal_baby": ["moon_rabbit", 1], "finargle": ["owl", 3], "finargle_elder": ["owl", 4], "grump": ["rabbit", 1], "mud_slime": ["frog", 1], "slime": ["frog", 1], "bat": ["sparrow", 1], "wisp": ["firefly", 2], "ice_wisp": ["firefly", 2], "shard": ["crystal_fish", 2], "hill_wolf": ["fox", 3], "rock_crab": ["crab", 2], "golem": ["goat", 3], "quarry_golem": ["goat", 4], "big_grump": ["deer", 4], "bog_hag": ["heron", 4], "river_serpent": ["otter", 4]}


static func meow_rank() -> int:
	# Grows with Nova's friendship and with how far the story has gone (each
	# chapter's spark makes it reach bigger things).
	var base := maxi(GameState.friend_hearts("penguin_f") / 2 + 1, GameState.progress_tier() + 1)
	return maxi(1, base + int(GameState.bonus("magic", "spell_power") * 2)) + Sanctuary.meow_bonus()


## Once Catkins has taught it, the Meow Pow Wow is the player's own: hold B near
## something it can turn back. Otherwise B-hold uses the active partner's ability.
static func ability_for(m: GameMap, p: Player) -> String:
	var partner := str(defs().get(active_id(), {}).get("ability", ""))
	if GameState.is_penguins() and (GameState.run["flags"].has("meow_taught") or partner == "meow_pow_wow"):
		for e in m.enemies.duplicate():
			if is_instance_valid(e) and e.position.distance_to(p.position) <= 70.0 and (REVERT.has(e.kind) or e.kind == "knight"):
				return "meow_pow_wow"
		if partner == "":
			return "meow_pow_wow"
	return partner


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
	if not ab.begins_with("gift:"):
		var left := cooldown_left(ab)
		if left > 0.0:
			m.hud.toast("Ready in %ds." % int(ceil(left)), Color(0.8, 0.85, 1.0))
			return
		GameState.add_arc_xp(3)
		GameState.add_xp("leadership", 4)
		_ready_at[ab] = Time.get_ticks_msec() / 1000.0 + float(COOLDOWN.get(ab, DEFAULT_COOLDOWN)) * maxf(0.3, 1.0 - GameState.bonus("harmony", "ability_cooldown") - GameState.bonus("leadership", "ability_cooldown"))
		var th := int(GameState.bonus("leadership", "team_heal"))
		if th > 0:
			GameState.run["hp"] = mini(int(GameState.run["max_hp"]), int(GameState.run["hp"]) + th)
	# Prompts-12 partner art: cast pose + the partner's own effect strip.
	var sprite_id := str(defs().get(active_id(), {}).get("sprite", active_id()))
	if Art.has("fx", "ability_" + sprite_id):
		m.fx("ability_" + sprite_id, p.position + Vector2(0, -10), 10.0, 0.6)
	if ab.begins_with("gift:"):
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
				if e.kind == "knight" and GameState.run["flags"].has("knight_mercy_try") and float(e.hp) / e.max_hp < 0.34:
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
					m.fx("sparkle", e.position + Vector2(0, -8), 18.0, 0.8)
					m.hud.toast("Fennimore's crown goes out. She blinks, and she's herself.", Color(0.85, 0.95, 1.0))
					e.set_meta("reverted", true)
					e._die()
					n += 1
					continue
				if rv.is_empty() or int(rv[1]) > rank:
					m.emote(e, "confused", 0.8)
					continue
				m.fx("sparkle", e.position + Vector2(0, -8), 14.0, 0.6)
				if str(rv[0]) == "penguin":
					# Grandfather Auk, himself again: a penguin where the Knight stood.
					var pg := CharacterLibrary.make_sprite("penguin")
					if pg:
						pg.position = e.position
						pg.play("idle")
						m.add_child(pg)
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
				if is_instance_valid(e) and e.position.distance_to(p.position) < 70.0:
					e._stun = maxf(e._stun, 2.0)
			GameState.restore_mana(5)
			m.fx("pawring", p.position + Vector2(0, -6), 12.0, 0.8)
			if p.has_anim("powerup"):
				p._busy = true
				p._apply("powerup", false, true)
			m.hud.toast("Power Pose! +5 mana, grumps stunned.", Color(0.85, 0.9, 1.0))
		"haul":
			m.hud.toast("Dad: 'Just point at the tree.' (Trees fall in one swing while he's with you.)", Color(0.9, 0.9, 0.9))
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
			var gm := m.get_node_or_null("GameMenu")
			if gm:
				(gm as GameMenu).toggle()
		"bee_bop":
			Music.instance(m.get_tree()).sfx("stun")
			# Coldy stamps: a ring that cracks the ground; grumps in it stagger.
			m.fx("stomp" if Art.has("fx", "stomp") else "ripple_ring", p.position, 16.0, 0.8)
			m.shake(3.0)
			var hits := 0
			for e in m.enemies.duplicate():
				if is_instance_valid(e) and e.position.distance_to(p.position) < 44.0:
					e.hit(2 + meow_rank(), p.position, false, true)
					e._stun = maxf(e._stun, 0.8)
					hits += 1
			m.hud.toast("Coldy: 'BEE BOP BOO BABY.'" if hits > 0 else "Coldy: 'Bee bop boo... nobody.'", Color(0.8, 0.9, 1.0))
		"muscle":
			var fc: Vector2i = p.facing_cell()
			var th: Dictionary = m.things.get(fc, {})
			var tt := str(th.get("type", ""))
			if tt in ["rock", "mrock", "stump", "log"]:
				# He breaks it himself: no tool, no energy.
				m.things.erase(fc)
				m.blocked.erase(fc)
				if m.props.has(fc):
					(m.props[fc] as Node).queue_free()
					m.props.erase(fc)
				m._mark_cleared(fc)
				if tt in ["rock", "mrock"]:
					m.give("stone", 3)
					var ore := str(th.get("ore", ""))
					if ore != "" and ore != "stone":
						m.give(ore, 1)
				else:
					m.give("wood", 3)
				m.fx("stone_chips" if tt in ["rock", "mrock"] else "wood_chips", m.cell_center(fc) + Vector2(0, -8), 16.0, 0.5)
				m.shake(3.0)
				m.hud.toast("Big Jim: 'Next.'", Color(1, 0.9, 0.8))
			else:
				m.hud.toast("Big Jim: 'Point me at something.'", Color(1, 0.9, 0.8))
		"fence":
			var best := ""
			var bv := 0
			for id in GameState.run["inventory"].keys():
				var v := GameState.item_value(str(id))
				# Only loot: enemy drops, junk, ore and treasure. Never gear, food or keys.
				if v > bv and str(GameState.items.get(id, {}).get("type", "")) in ["drop", "junk", "treasure", "ore"]:
					bv = v
					best = str(id)
			if best != "":
				var n := GameState.count(best)
				GameState.add_item(best, -n)
				var pay := GameState.sell_price(best, n)
				var sold: Dictionary = GameState.run.get("sold_today", {})
				sold[best] = int(sold.get(best, 0)) + n
				GameState.run["sold_today"] = sold
				GameState.run["crystals"] = int(GameState.run["crystals"]) + pay
				m.hud.toast("Sal moved %d %s for ◆%d. No questions." % [n, GameState.item_name(best), pay], Color(1, 0.9, 0.6))
			else:
				m.hud.toast("Sal: 'Nothing worth moving. Bring me loot.'", Color(1, 0.9, 0.6))
		"tail":
			m.hud.toast("Mer: 'The water's right there.'", Color(0.8, 0.95, 1.0))
		"mend":
			GameState.heal_points(10)
			m.hud.toast("Mom: 'Hold still.' +10 health.", Color(1, 0.8, 0.8))


static func recruit(cid: String, make_active := true) -> void:
	# You can't recruit yourself (playing as Coldy, Mer or Big Jim).
	if cid == str(GameState.run.get("playable", "")):
		return
	var p := party()
	if not cid in p["known"]:
		p["known"].append(cid)
	p["bitter"].erase(cid)
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
		GameState.add_hint("%s took that hard. People who feel unwanted go looking for somewhere they're wanted." % str(defs()[cid]["name"]))


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
		anim.frame_changed.connect(func() -> void:
			var tex := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
			if tex:
				anim.offset = Vector2(0, -tex.get_height() / 2.0))
	elif CharacterLibrary.has_character(sprite):
		anim = CharacterLibrary.make_sprite(sprite)
	else:
		anim = CharacterLibrary.make_sprite("man")
	if d.has("tint"):
		anim.modulate = Color(str(d["tint"]))
	add_child(anim)
	anim.play("idle")
	y_sort_enabled = true


var _moving := false
var _vert := false


func _process(delta: float) -> void:
	if map == null or map.player == null or anim == null or map.get_tree().paused:
		return
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
		var a := "walk" if dist < 48.0 else "run"
		if not anim.sprite_frames.has_animation(a):
			a = "walk"
		# Axis stickiness: only switch between side and up/down views on a clear lead.
		var vertical := absf(to.y) > absf(to.x) * (0.7 if _vert else 1.4)
		_vert = vertical
		if vertical and anim.sprite_frames.has_animation(a + ("_up" if to.y < 0 else "_down")):
			a = a + ("_up" if to.y < 0 else "_down")
			anim.flip_h = false
		else:
			anim.flip_h = to.x < 0
		if anim.animation != a:
			anim.play(a)
		_idle = 0.0
	else:
		_idle += delta
		var want := "idle"
		if map.player.swimming and anim.sprite_frames.has_animation("swim"):
			want = "swim"
		if anim.animation != want and anim.sprite_frames.has_animation(want):
			anim.play(want)
		# Mend (Mom): 1 health every 10 s while she's close.
		if Companion.has_ability("mend"):
			_mend_t += delta
			if _mend_t >= 10.0:
				_mend_t -= 10.0
				GameState.heal_points(1)

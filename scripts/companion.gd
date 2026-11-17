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
	var a := active_id()
	if a == "":
		return false
	return str(defs().get(a, {}).get("ability", "")) == ab


## Grumps were villagers' animals once. Meow Pow Wow turns them back; rank
## (from Nova's friendship hearts / 2, min 1) decides how big a grump it reaches.
const REVERT := {"grump": ["rabbit", 1], "mud_slime": ["frog", 1], "slime": ["frog", 1], "bat": ["sparrow", 1], "wisp": ["firefly", 2], "ice_wisp": ["firefly", 2], "shard": ["crystal_fish", 2], "hill_wolf": ["fox", 3], "rock_crab": ["crab", 2], "golem": ["goat", 3], "quarry_golem": ["goat", 4], "big_grump": ["deer", 4], "bog_hag": ["heron", 4], "river_serpent": ["otter", 4]}


static func meow_rank() -> int:
	return maxi(1, GameState.friend_hearts("penguin_f") / 2 + 1 + int(GameState.bonus("magic", "spell_power") * 2))


static func use_ability(m: GameMap, p: Player) -> void:
	var ab := str(defs().get(active_id(), {}).get("ability", ""))
	match ab:
		"meow_pow_wow":
			var rank := meow_rank()
			var n := 0
			for e in m.enemies:
				if not is_instance_valid(e) or e.position.distance_to(p.position) > 70.0:
					continue
				var rv: Array = REVERT.get(e.kind, [])
				if e.kind == "knight" and GameState.run["flags"].has("knight_mercy_try") and float(e.hp) / e.max_hp < 0.34:
					rv = ["penguin", 1]
					GameState.run["flags"]["knight_reverted"] = true
				if rv.is_empty() or int(rv[1]) > rank:
					m.emote(e, "confused", 0.8)
					continue
				m.fx("sparkle", e.position + Vector2(0, -8), 14.0, 0.6)
				WorldGen.add_critters(m, Rect2i(m.world_to_cell(e.position) - Vector2i(1, 1), Vector2i(3, 3)), int(Time.get_ticks_msec()), 1, [str(rv[0])])
				e.set_meta("reverted", true)
				e._die()
				n += 1
			GameState.run["flags"]["reverted"] = int(GameState.run["flags"].get("reverted", 0)) + n
			m.hud.toast("Meow Pow Wow! %d turned back." % n if n > 0 else "Meow Pow Wow... nothing here to turn back (rank %d)." % rank, Color(1, 0.85, 0.95))
			m.shake(2.0)
			m.xp("magic", 3 * n)
		"powerup":
			for e in m.enemies:
				if is_instance_valid(e) and e.position.distance_to(p.position) < 70.0:
					e._stun = maxf(e._stun, 2.0)
			GameState.restore_mana(5)
			m.fx("pawring", p.position + Vector2(0, -6), 12.0, 0.8)
			if p.has_anim("powerup"):
				p._busy = true
				p._apply("powerup", false, true)
			m.hud.toast("Power Pose! +5 mana, grumps stunned.", Color(0.85, 0.9, 1.0))
		"haul":
			m.hud.toast("Dad: 'Just point at the tree.'", Color(0.9, 0.9, 0.9))
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
			m.hud.toast("Kairi: 'Chest's open. Don't ask how.'", Color(0.9, 1.0, 0.9))
			var gm := m.get_node_or_null("GameMenu")
			if gm:
				(gm as GameMenu).toggle()
		"muscle":
			var fc: Vector2i = p.facing_cell()
			var th: Dictionary = m.things.get(fc, {})
			if str(th.get("type", "")) in ["rock", "mrock", "stump", "log"]:
				th["hp"] = 0
				m.interact_common(fc, th)
				m.shake(3.0)
				m.hud.toast("Big Jim: 'Next.'", Color(1, 0.9, 0.8))
			else:
				m.hud.toast("Big Jim: 'Point me at something.'", Color(1, 0.9, 0.8))
		"fence":
			var best := ""
			var bv := 0
			for id in GameState.run["inventory"].keys():
				var v := GameState.item_value(str(id))
				if v > bv and str(GameState.items.get(id, {}).get("type", "")) not in ["tool", "seed", "petgear"]:
					bv = v
					best = str(id)
			if best != "":
				var n := GameState.count(best)
				GameState.add_item(best, -n)
				var pay := int(bv * n * 1.2)
				GameState.run["crystals"] = int(GameState.run["crystals"]) + pay
				m.hud.toast("Sal moved %d %s for ◆%d. No questions." % [n, GameState.item_name(best), pay], Color(1, 0.9, 0.6))
		"tail":
			m.hud.toast("Mer: 'The water's right there.'", Color(0.8, 0.95, 1.0))
		"mend":
			GameState.heal_points(10)
			m.hud.toast("Mom: 'Hold still.' +10 health.", Color(1, 0.8, 0.8))


static func recruit(cid: String) -> void:
	var p := party()
	if not cid in p["known"]:
		p["known"].append(cid)
	p["active"] = cid
	GameState.run["flags"]["party_" + cid] = true


static func refuse(cid: String) -> void:
	var p := party()
	p["refused"][cid] = int(p["refused"].get(cid, 0)) + 1
	if int(p["refused"][cid]) >= 2 and not cid in p["bitter"]:
		p["bitter"].append(cid)
		GameState.add_hint("%s took that hard. People who feel unwanted go looking for somewhere they're wanted." % str(defs()[cid]["name"]))


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


func _process(delta: float) -> void:
	if map == null or map.player == null or anim == null or map.get_tree().paused:
		return
	var goal := map.player.position + Vector2(14, 6)
	if map.pet and map.pet.visible:
		goal = map.player.position + Vector2(16, -4)
	var to := goal - position
	var dist := to.length()
	if dist > 20.0:
		var sp := minf(dist * 4.0, 100.0)
		if map.player.mounted:
			sp = 150.0
		var step := to.normalized() * sp * delta
		var np := position + step
		if not map.rect_blocked_player(Rect2(np + Vector2(-3, -2), Vector2(6, 2)), self) or dist > 80.0:
			position = np
		var a := "walk" if dist < 48.0 else "run"
		if not anim.sprite_frames.has_animation(a):
			a = "walk"
		if absf(to.y) > absf(to.x) and anim.sprite_frames.has_animation(a + ("_up" if to.y < 0 else "_down")):
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
		# Mend (Mom): slow heal while near.
		if Companion.has_ability("mend") and _idle > 0.0 and int(_idle * 10) % 100 == 0:
			GameState.heal_points(1)

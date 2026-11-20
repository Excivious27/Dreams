class_name Spells
extends RefCounted
## Magic: spells unlock from the Magic skill tree and cost mana (see
## GameState vitals). Cast from the menu's Skills → Magic page, or Spark with
## the sword slot held (the "a" button casts when nothing is in front of you).

const SPELLS := {
	"spark": {"name": "Spark", "cost": 5, "desc": "A bolt of light at the nearest enemy."},
	"glow": {"name": "Glow", "cost": 8, "desc": "Light the night and the mine until you sleep."},
	"haste": {"name": "Haste", "cost": 10, "desc": "Run 30% faster for a game hour."},
	"rain_call": {"name": "Rain Call", "cost": 15, "desc": "Water every crop on the farm."},
	"growth": {"name": "Growth", "cost": 12, "desc": "The crop in front of you grows a day."},
	"crystal_shield": {"name": "Crystal Shield", "cost": 15, "desc": "Absorb the next 3 hits."},
	"warp_home": {"name": "Warp Home", "cost": 20, "desc": "Blink back to your bed."},
	"radiance": {"name": "Radiance", "cost": 14, "desc": "A ring of light hits everything near you."},
	"lull": {"name": "Lull", "cost": 12, "desc": "Enemies nearby fall asleep for a few seconds."},
	"bloom": {"name": "Bloom", "cost": 25, "desc": "Every ripe crop on the farm goes to the sell box."},
	"resonance": {"name": "Resonance", "cost": 18, "desc": "Charge the resonator; +1 ore from rocks today."},
	"dreamwalk": {"name": "Dreamwalk", "cost": 30, "desc": "Step through the Dream to a region you know."},
}


static func cost_of(id: String) -> int:
	return maxi(1, int(ceil(int(SPELLS[id]["cost"]) * (1.0 - GameState.bonus("magic", "spell_discount")))))


static func power() -> float:
	# Spell weight grows with the Sorcery skill on the same curve as the tier table.
	return (1.0 + GameState.bonus("magic", "spell_power")) * (1.0 + 0.08 * GameState.skill_level("magic"))


static func known() -> Array:
	var out: Array = []
	for id in SPELLS:
		if GameState.node_rank("magic", id) > 0 or GameState.spell_from_tree(id):
			out.append(id)
	return out


static func can_cast(id: String) -> String:
	if GameState.node_rank("magic", id) <= 0 and not GameState.spell_from_tree(id):
		return "not learned"
	if int(GameState.run.get("mana", 0)) < cost_of(id):
		return "not enough mana"
	return ""


## Returns true if the spell fired. `m` is the current map (may be an interior).
static func cast(m: GameMap, id: String) -> bool:
	var ok := _cast(m, id)
	if not ok and m and m.is_inside_tree():
		Music.instance(m.get_tree()).sfx("nope", "thud")  # a cast that did nothing sounds like it
	return ok


static func _cast(m: GameMap, id: String) -> bool:
	var why := can_cast(id)
	if why != "":
		if m and m.hud:
			m.hud.toast(why.capitalize() + ".", Color(1, 0.7, 0.7))
		return false
	var p := m.player
	var fired := true
	match id:
		"spark":
			var e: Enemy = m.nearest_enemy_to(p.position, 72.0)
			if e == null:
				m.hud.toast("Nothing to hit.", Color(1, 0.8, 0.6))
				return false
			var dmg := int((3 + int(GameState.bonus("magic", "spark_damage")) - 1) * power())
			var pierce := int(GameState.bonus("magic", "spark_pierce"))
			var burn := int(GameState.bonus("magic", "spark_burn"))
			if GameState.has_perk("magic", "Moonbeam"):
				for e2 in m.enemies.duplicate():
					if is_instance_valid(e2) and e2.position.distance_to(p.position) < 72.0:
						e2.hit(dmg, p.position, true, true)
						m.fx("sparkle", e2.position + Vector2(0, -8), 14.0, 0.6)
			elif pierce > 0:
				# Light Lance: everything along the line to the target and beyond it.
				var dir := (e.position - p.position).normalized()
				for e2 in m.enemies.duplicate():
					if not is_instance_valid(e2):
						continue
					var rel: Vector2 = e2.position - p.position
					var along := rel.dot(dir)
					if along > 0.0 and along < 72.0 + 32.0 * pierce and absf(rel.cross(dir)) < 14.0:
						e2.hit(dmg, p.position, true, true)
						if burn > 0:
							e2.set_meta("burn", burn * 3)
						m.fx("sparkle", e2.position + Vector2(0, -8), 14.0, 0.6)
			else:
				e.hit(dmg, p.position, true, true)
				if burn > 0:
					e.set_meta("burn", burn * 3)
				m.fx("sparkle", e.position + Vector2(0, -8), 14.0, 0.6)
			m.fx("sparkle", p.position + Vector2(0, -14), 14.0, 0.5)
		"radiance":
			var hit_any := false
			var rdmg := int(4 * power())
			for e2 in m.enemies.duplicate():
				if is_instance_valid(e2) and e2.position.distance_to(p.position) < 56.0:
					e2.hit(rdmg, p.position, true, true)
					hit_any = true
			if GameState.bonus("magic", "sunder") > 0.0:
				var pc := p.cell()
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						var c := pc + Vector2i(dx, dy)
						var th: Dictionary = m.things.get(c, {})
						if str(th.get("type", "")) in ["rock", "stump", "log", "weeds"] and GameState.ore_block(str(th.get("ore", "stone"))) == "":
							th["hp"] = 0
							m.interact_common(c, th)
							hit_any = true
			m.fx("pawring", p.position + Vector2(0, -6), 12.0, 0.8)
			m.shake(3.0)
			if not hit_any:
				m.hud.toast("The light finds nothing.", Color(1, 0.8, 0.6))
		"lull":
			var n := 0
			for e2 in m.enemies.duplicate():
				if is_instance_valid(e2) and e2.position.distance_to(p.position) < 80.0:
					e2.set_meta("asleep_until", Time.get_ticks_msec() + (2000 if e2.base_hp >= 10 else 6000))
					m.emote(e2, "sleep", 1.5)
					n += 1
			m.hud.toast("%d fall asleep." % n if n > 0 else "Nothing here to lull.", Color(0.85, 0.8, 1.0))
			if n == 0:
				return false
		"bloom":
			if m.scene_id() != "farm":
				m.hud.toast("Bloom only works on your farm.", Color(1, 0.8, 0.6))
				return false
			var n := 0
			for key in GameState.run["farm"].keys():
				var tile: Dictionary = GameState.run["farm"][key]
				var cid := str(tile.get("crop", ""))
				if cid != "" and GameState.crops.has(cid) and int(tile.get("days", 0)) >= int(GameState.crops[cid]["days"]):
					var yid := str(GameState.crops[cid]["yield"])
					GameState.run["sellbox"][yid] = int(GameState.run["sellbox"].get(yid, 0)) + 1
					if GameState.crops[cid].has("regrow"):
						tile["days"] = int(GameState.crops[cid]["days"]) - int(GameState.crops[cid]["regrow"])
					else:
						tile["crop"] = ""
						tile["days"] = 0
					m.net_act({"a": "farm_tile", "key": key, "tile": tile})
					n += 1
			m.hud.toast("Bloom: %d crops to the sell box." % n, Color(1, 0.9, 0.6))
			_redraw_soil(m)
			if n == 0:
				return false
		"resonance":
			GameState.run["flags"]["resonator_charge"] = 100
			GameState.run["flags"]["ore_bonus_day"] = int(GameState.run["day"])
			m.hud.toast("The ground hums. +1 ore from every rock today.", Color(0.8, 0.9, 1.0))
		"dreamwalk":
			var seen: Array = []
			for k in GameState.run["flags"]:
				if str(k).ends_with("_seen") and ResourceLoader.exists("res://scenes/%s.tscn" % str(k).trim_suffix("_seen")):
					seen.append(str(k).trim_suffix("_seen"))
			if seen.is_empty():
				m.hud.toast("You haven't seen anywhere to walk to.", Color(1, 0.8, 0.6))
				return false
			# The picker waits on a dialogue, so it runs on its own and pays for the cast
			# only when a place is picked ("Stay" costs nothing). cast() itself never waits.
			_dreamwalk(m, seen)
			return true
		"glow":
			GameState.run["flags"]["glow_day"] = int(GameState.run["day"])
			m.hud.toast("The dark pulls back.", Color(0.9, 0.95, 1.0))
		"haste":
			GameState.run["flags"]["haste_abs"] = GameState.now_abs() + GameState.real_min(42.0)  # 42 real s on any day length (survives sleep)
			m.hud.toast("Haste!", Color(0.8, 1.0, 0.8))
		"rain_call":
			var n := 0
			for key in GameState.run["farm"].keys():
				var tile: Dictionary = GameState.run["farm"][key]
				if tile.get("crop", "") != "" and not bool(tile.get("watered", false)):
					tile["watered"] = true
					m.net_act({"a": "farm_tile", "key": key, "tile": tile})
					n += 1
			m.hud.toast("Rain falls on %d crops." % n, Color(0.7, 0.85, 1.0))
			_redraw_soil(m)
		"growth":
			var fc: Vector2i = p.facing_cell()
			var key := "%d,%d" % [fc.x, fc.y]
			if m.scene_id() == "farm" and GameState.run["farm"].has(key) and GameState.run["farm"][key].get("crop", "") != "":
				var gt: Dictionary = GameState.run["farm"][key]
				var cdays := int(GameState.crops.get(str(gt["crop"]), {}).get("days", 99))
				if int(gt.get("days", 0)) >= cdays:
					m.hud.toast("Already ripe.", Color(1, 0.9, 0.6))
					return false
				gt["days"] = int(gt.get("days", 0)) + 1
				m.net_act({"a": "farm_tile", "key": key, "tile": gt})
				m.fx("sparkle", m.cell_center(fc) + Vector2(0, -6), 14.0, 0.5)
				_redraw_soil(m)
			else:
				m.hud.toast("Face a planted crop.", Color(1, 0.8, 0.6))
				return false
		"crystal_shield":
			GameState.run["flags"]["shield"] = 3
			m.hud.toast("Crystal Shield: 3 hits.", Color(0.8, 0.9, 1.0))
		"warp_home":
			if m._transitioning or m._changing:
				return false
			m.fx("sparkle", p.position + Vector2(0, -14), 14.0, 0.6)
			m.go_to("house", Vector2(5 * GameMap.TILE + 8, 5 * GameMap.TILE))
		_:
			fired = false
	if fired:
		_pay(m, id)
	return fired


## Mana (or a Twin Cast), magic XP and the cast sound for a spell that fired.
static func _pay(m: GameMap, id: String) -> void:
	var p := m.player
	if int(GameState.run.get("mana", 0)) > (10 if GameState.bonus("magic", "awakened") > 0.0 else 0) and randf() < GameState.bonus("magic", "free_cast"):
		# Twin Cast (Magic): now and then a spell costs nothing.
		m.hud.toast("Twin Cast: free!", Color(0.85, 0.75, 1.0))
		m.fx("sparkle", p.position + Vector2(0, -14), 12.0, 0.5)
	else:
		GameState.spend_mana(cost_of(id))
	m.xp("magic", 2 + int(SPELLS[id]["cost"]) / 5)
	Music.instance(m.get_tree()).sfx(spell_sound(id), "spell")


static func _dreamwalk(m: GameMap, seen: Array) -> void:
	var d := Dialogue.instance(m.get_tree())
	var ch: Array = seen.map(func(x: String) -> String: return x.replace("_", " ").capitalize())
	ch.append("Stay")
	d.say([{"who": "", "text": "The Dream opens. Where?", "choice": ch, "key": ""}])
	await d.finished
	if not is_instance_valid(m) or not m.is_inside_tree():
		return
	if d.last_choice < 0 or d.last_choice >= seen.size():
		return
	if m._transitioning or m._changing or can_cast("dreamwalk") != "":
		return
	_pay(m, "dreamwalk")
	m.fx("sparkle", m.player.position + Vector2(0, -14), 14.0, 0.8)
	m.go_to(seen[d.last_choice], Vector2.ZERO)


## Farm soil and crops draw on their own layer (farm.gd _soil); the map itself too.
static func _redraw_soil(m: GameMap) -> void:
	var soil = m.get("_soil")
	if soil is CanvasItem:
		(soil as CanvasItem).queue_redraw()
	elif m.scene_id() == "farm":
		m.queue_redraw()
	# Elsewhere no farm soil is drawn: a full map redraw would re-bake every
	# ground chunk for nothing (c3_16 #6).


## The sound for a spell, from its id/element words (fire, ice, heal...).
static func spell_sound(id: String) -> String:
	var d: Dictionary = SPELLS.get(id, {})
	var words := (id + " " + str(d.get("element", "")) + " " + str(d.get("name", ""))).to_lower()
	for pair: Array in [["heal", "heal"], ["mend", "heal"], ["cure", "heal"], ["fire", "spell_fire"], ["flame", "spell_fire"], ["ember", "spell_fire"],
			["ice", "spell_ice"], ["frost", "spell_ice"], ["snow", "spell_ice"], ["bolt", "spell_lightning"], ["storm", "spell_lightning"], ["shock", "spell_lightning"],
			["thorn", "spell_nature"], ["vine", "spell_nature"], ["grow", "spell_nature"], ["leaf", "spell_nature"], ["quake", "spell_earth"], ["stone", "spell_earth"],
			["tremor", "spell_earth"], ["shadow", "spell_dark"], ["dark", "spell_dark"], ["void", "spell_dark"], ["blink", "teleport"], ["warp", "teleport"], ["tide", "bubble"], ["water", "bubble"]]:
		if str(pair[0]) in words:
			return str(pair[1])
	return "spell"

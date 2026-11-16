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
}


static func known() -> Array:
	var out: Array = []
	for id in SPELLS:
		if GameState.node_rank("magic", id) > 0:
			out.append(id)
	return out


static func can_cast(id: String) -> String:
	if GameState.node_rank("magic", id) <= 0:
		return "not learned"
	if int(GameState.run.get("mana", 0)) < int(SPELLS[id]["cost"]):
		return "not enough mana"
	return ""


## Returns true if the spell fired. `m` is the current map (may be an interior).
static func cast(m: GameMap, id: String) -> bool:
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
			var dmg := 3 + int(GameState.bonus("magic", "spark_damage")) - 1
			if GameState.has_perk("magic", "Moonbeam"):
				for e2 in m.enemies:
					if is_instance_valid(e2) and e2.position.distance_to(p.position) < 72.0:
						e2.hit(dmg, p.position)
						m.fx("sparkle", e2.position + Vector2(0, -8), 14.0, 0.6)
			else:
				e.hit(dmg, p.position)
				m.fx("sparkle", e.position + Vector2(0, -8), 14.0, 0.6)
			m.fx("sparkle", p.position + Vector2(0, -14), 14.0, 0.5)
		"glow":
			GameState.run["flags"]["glow_day"] = int(GameState.run["day"])
			m.hud.toast("The dark pulls back.", Color(0.9, 0.95, 1.0))
		"haste":
			GameState.run["flags"]["haste_until"] = int(GameState.run["time"]) + 60
			m.hud.toast("Haste!", Color(0.8, 1.0, 0.8))
		"rain_call":
			var n := 0
			for key in GameState.run["farm"].keys():
				var tile: Dictionary = GameState.run["farm"][key]
				if tile.get("crop", "") != "" and not bool(tile.get("watered", false)):
					tile["watered"] = true
					n += 1
			m.hud.toast("Rain falls on %d crops." % n, Color(0.7, 0.85, 1.0))
			if m.has_method("queue_redraw"):
				m.queue_redraw()
		"growth":
			var fc: Vector2i = p.facing_cell()
			var key := "%d,%d" % [fc.x, fc.y]
			if m.scene_id() == "farm" and GameState.run["farm"].has(key) and GameState.run["farm"][key].get("crop", "") != "":
				GameState.run["farm"][key]["days"] = int(GameState.run["farm"][key].get("days", 0)) + 1
				m.fx("sparkle", m.cell_center(fc) + Vector2(0, -6), 14.0, 0.5)
				m.queue_redraw()
			else:
				m.hud.toast("Face a planted crop.", Color(1, 0.8, 0.6))
				return false
		"crystal_shield":
			GameState.run["flags"]["shield"] = 3
			m.hud.toast("Crystal Shield: 3 hits.", Color(0.8, 0.9, 1.0))
		"warp_home":
			m.fx("sparkle", p.position + Vector2(0, -14), 14.0, 0.6)
			m.go_to("house", Vector2(5 * GameMap.TILE + 8, 5 * GameMap.TILE))
		_:
			fired = false
	if fired:
		GameState.spend_mana(int(SPELLS[id]["cost"]))
		m.xp("magic", 2 + int(SPELLS[id]["cost"]) / 5)
		Music.instance(m.get_tree()).sfx("levelup")
	return fired

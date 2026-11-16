class_name Crafting
extends RefCounted
## Generic crafting menu over data/recipes.json: station = workbench | smith | kitchen | alchemy.
## Recipes show when their tier is reached (building/mining/farming/foraging level gates)
## and the skill gate (if any) is met. Craft gives items or tools.

const STATION_SKILL := {"workbench": "building", "smith": "mining", "kitchen": "farming", "alchemy": "foraging"}


static func tier_unlocked(station: String) -> int:
	var sk := str(STATION_SKILL.get(station, "building"))
	var lvl := GameState.skill_level(sk)
	return 1 + int(lvl / 2)  # Lv1-2: tier 1, Lv3-4: tier 2, Lv5-6: tier 3, Lv7-8: tier 4, Lv9+: tier 5


static func available(station: String) -> Array:
	var out: Array = []
	var t := tier_unlocked(station)
	for rc in GameState.recipes.get(station, []):
		if int(rc.get("tier", 1)) > t:
			continue
		if rc.has("skill") and GameState.skill_level(str(rc["skill"][0])) < int(rc["skill"][1]):
			continue
		out.append(rc)
	return out


static func can_make(rc: Dictionary) -> bool:
	for id in rc["need"]:
		if GameState.count(str(id)) < int(rc["need"][id]):
			return false
	return true


static func run(m: GameMap, station: String, title := "") -> void:
	var sk := str(STATION_SKILL.get(station, "building"))
	while true:
		var list := available(station)
		var opts: Array = []
		for rc in list:
			var need: Array = []
			for id in rc["need"]:
				need.append("%d %s" % [int(rc["need"][id]), GameState.item_name(str(id))])
			opts.append("%s%s  [%s]" % ["" if can_make(rc) else "✗ ", str(rc["name"]), ", ".join(need)])
		var next_t := tier_unlocked(station) + 1
		var locked := 0
		for rc in GameState.recipes.get(station, []):
			if int(rc.get("tier", 1)) >= next_t:
				locked += 1
		opts.append("Leave")
		var d := Dialogue.instance(m.get_tree())
		var head := title if title != "" else station.capitalize()
		d.say([{"who": head, "text": "Tier %d recipes (%s Lv %d).  %d more unlock at higher %s levels." % [tier_unlocked(station), sk.capitalize(), GameState.skill_level(sk), locked, sk], "choice": opts, "key": ""}])
		await d.finished
		var i := d.last_choice
		if i < 0 or i >= list.size():
			return
		var rc: Dictionary = list[i]
		if not can_make(rc):
			m.hud.toast("Missing ingredients.", Color(1, 0.7, 0.7))
			continue
		for id in rc["need"]:
			GameState.add_item(str(id), -int(rc["need"][id]))
		var give_id := str(rc["give"])
		if bool(rc.get("tool", false)) or GameState.items.get(give_id, {}).get("type", "") == "tool":
			GameState.add_tool(give_id)
			m.hud.toast("Made the %s!" % GameState.item_name(give_id), Color(1, 0.9, 0.4))
		else:
			m.give(give_id, int(rc.get("n", 1)))
		m.xp(sk, 4 + 3 * int(rc.get("tier", 1)))
		Music.instance(m.get_tree()).sfx("levelup")

class_name Crafting
extends RefCounted
## Generic crafting menu over data/recipes.json: station = workbench | smith | kitchen | alchemy.
## Recipes show when their tier is reached (building/mining/farming/foraging level gates)
## and the skill gate (if any) is met. Craft gives items or tools.

const STATION_SKILL := {"workbench": "building", "smith": "mining", "kitchen": "farming", "alchemy": "foraging", "mill": "farming"}


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


# ---- timed crafting (Sun Haven style) ----------------------------------------
# A recipe takes game minutes: base by tier, scaled by station and by how many
# pieces it makes. The station holds ONE job (run["jobs"][station]); you put
# the ingredients in, walk away, and come back when the clock says it's done.
# Collecting early isn't possible; the Building tree shortens times.

const BASE_MINUTES := {1: 20, 2: 45, 3: 90, 4: 180, 5: 360}
const STATION_SPEED := {"workbench": 1.0, "smith": 1.4, "kitchen": 0.6, "alchemy": 1.2, "mill": 0.8, "keg": 3.0, "loom": 1.5, "kiln": 2.0}


static func minutes_for(station: String, rc: Dictionary) -> int:
	var base := int(BASE_MINUTES.get(int(rc.get("tier", 1)), 60))
	var m := base * float(STATION_SPEED.get(station, 1.0))
	if rc.has("minutes"):
		m = float(rc["minutes"])
	m *= 1.0 - GameState.bonus("building", "craft_speed")
	if Companion.has_ability("tinker"):
		m *= 0.7
	if bool(rc.get("tool", false)):
		m *= 1.5
	return maxi(5, int(round(m / 5.0) * 5))


static func job(station: String) -> Dictionary:
	return GameState.run.get("jobs", {}).get(station, {})


## Absolute game minute (day*1440 + time) so jobs survive sleeping.
static func now_abs() -> int:
	return int(GameState.run["day"]) * 1440 + int(GameState.run["time"])


static func job_left(station: String) -> int:
	var j := job(station)
	if j.is_empty():
		return 0
	return maxi(0, int(j["done_at"]) - now_abs())


static func fmt_minutes(mn: int) -> String:
	if mn >= 60:
		return "%dh %02dm" % [mn / 60, mn % 60]
	return "%dm" % mn


static func run(m: GameMap, station: String, title := "") -> void:
	var sk := str(STATION_SKILL.get(station, "building"))
	var head := title if title != "" else station.capitalize()
	# A job in progress: collect it or wait.
	var j := job(station)
	if not j.is_empty():
		var left := job_left(station)
		var rc_name := str(j.get("name", "something"))
		if left <= 0:
			var give_id := str(j["give"])
			if bool(j.get("tool", false)) or GameState.items.get(give_id, {}).get("type", "") == "tool":
				GameState.add_tool(give_id)
				m.hud.toast("Made the %s!" % GameState.item_name(give_id), Color(1, 0.9, 0.4))
			else:
				m.give(give_id, int(j.get("n", 1)))
			m.xp(sk, 4 + 3 * int(j.get("tier", 1)))
			Music.instance(m.get_tree()).sfx("levelup")
			GameState.run["jobs"].erase(station)
			# fall through to the menu so you can queue the next one
		else:
			var d0 := Dialogue.instance(m.get_tree())
			d0.say([{"who": head, "text": "%s: %s left." % [rc_name, fmt_minutes(left)], "choice": ["Wait here", "Leave"], "key": ""}])
			await d0.finished
			if d0.last_choice == 0:
				# Pass the time at the station (Sun Haven: you can wait).
				GameState.run["time"] = int(GameState.run["time"]) + left
				m.hud.toast("You wait. %s." % fmt_minutes(left))
				await run(m, station, title)
			return
	while true:
		var list := available(station)
		var opts: Array = []
		for rc in list:
			var need: Array = []
			for id in rc["need"]:
				need.append("%d %s" % [int(rc["need"][id]), GameState.item_name(str(id))])
			opts.append("%s%s  [%s]  ⏱%s" % ["" if can_make(rc) else "✗ ", str(rc["name"]), ", ".join(need), fmt_minutes(minutes_for(station, rc))])
		var next_t := tier_unlocked(station) + 1
		var locked := 0
		for rc in GameState.recipes.get(station, []):
			if int(rc.get("tier", 1)) >= next_t:
				locked += 1
		opts.append("Leave")
		var d := Dialogue.instance(m.get_tree())
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
		var mins := minutes_for(station, rc)
		GameState.run["jobs"] = GameState.run.get("jobs", {})
		GameState.run["jobs"][station] = {"id": str(rc["id"]), "name": str(rc["name"]), "give": str(rc["give"]), "n": int(rc.get("n", 1)), "tier": int(rc.get("tier", 1)), "tool": bool(rc.get("tool", false)), "done_at": now_abs() + mins}
		m.hud.toast("%s: ready in %s." % [str(rc["name"]), fmt_minutes(mins)], Color(1, 0.9, 0.4))
		Music.instance(m.get_tree()).sfx("plant")
		return

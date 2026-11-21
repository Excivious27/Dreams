extends SceneTree
## C16b P3: battles never block a cozy player. Both arcs, a new game with real
## locks (Campaign.bypass = false), no training, no team, ZERO battle wins: every
## main-story region and every campaign-held region opens by the long way, the
## goal line names the long way, and the main story walks to its end. The long
## way gives no win (is_won false, no stars, wins 0) and costs its toll. Also:
## the retry flow (easier retry lowers the foe, never the save's Difficulty; the
## loss card offers Retry / Easier / Long way / way out) and co-op guards.
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _pay_and_take(arc: String, cid: String) -> void:
	var lw := Campaign.long_way(cid)
	check(not lw.is_empty() and str(lw.get("words", "")) != "", "%s: %s has a long way (%s)" % [arc, cid, str(lw.get("kind", ""))])
	if str(Campaign.long_way_lock(cid)).begins_with("Try the campaign"):
		Campaign.cs(cid)["losses"] = int(Campaign.cs(cid)["losses"]) + 1  # an 'after a loss' long way
	var cost: Dictionary = lw.get("cost", {})
	GameState.run["crystals"] = int(GameState.run.get("crystals", 0)) + int(cost.get("money", 0))
	for it: String in cost.get("items", {}):
		GameState.add_item(it, int(cost["items"][it]))
	var before := int(GameState.run.get("crystals", 0))
	check(Campaign.can_take_long_way(cid), "%s: %s long way can be taken (%s)" % [arc, cid, Campaign.long_way_lock(cid)])
	var lines := Campaign.take_long_way(cid)
	check(not lines.is_empty(), "%s: %s take_long_way says something" % [arc, cid])
	var reg0 := str(Campaign.get_c(cid)["region"])
	if reg0 in Campaign.STORY_REGION.values() or reg0 == "countryside":
		check(not lines.is_empty() and str(lines[0].get("pic", "")) != "" and Art.has("ui", str(lines[0]["pic"])), "%s: %s long way has its story panel" % [arc, cid])
	check(int(GameState.run.get("crystals", 0)) == before - int(cost.get("money", 0)), "%s: %s toll paid" % [arc, cid])
	var reg := str(Campaign.get_c(cid)["region"])
	if int(lw.get("days", 1)) > 0:
		check(not Campaign.region_open(reg), "%s: %s not open the same day (the long way is slower)" % [arc, reg])
		check(not Campaign.can_take_long_way(cid), "%s: %s can't be paid twice" % [arc, cid])
		GameState.run["day"] = int(GameState.run.get("day", 1)) + int(lw.get("days", 1))
	check(Campaign.region_open(reg), "%s: %s open after the long way" % [arc, reg])
	check(not Campaign.is_won(cid), "%s: %s is not 'won' by the long way" % [arc, cid])
	check(Campaign.long_way_taken(cid), "%s: %s long way recorded" % [arc, cid])
	check(GameState.run["flags"].has("campaign_" + reg), "%s: %s story flag set like a win" % [arc, reg])


func _initialize() -> void:
	seed(16)
	Campaign.bypass = false
	var orders := {
		"penguins": ["meet_town", "first_harvest", "clear_meadow", "cattopia", "spark", "wastes_gate", "commander", "sky_stair", "knight", "teleporter", "finale"],
		"gangsters": ["meet_town", "first_harvest", "clear_meadow", "hideout", "gang", "docks", "neon", "pit", "uptown", "tower"],
	}
	for arc: String in orders:
		GameState.new_run(arc, "kairi" if arc == "penguins" else "pax", "Hero", "Dreamhollow", "Biscuit")
		GameState.run["quests"] = []
		GameState.run["party"] = {}
		# --- the main story, zero wins ---
		for qid: String in orders[arc]:
			var def := GameState._quest_def(qid)
			if def.is_empty():
				continue
			GameState.add_quest(qid, str(def.get("text", qid)))
			var reg := str(Campaign.STORY_REGION.get(qid, ""))
			if reg != "" and not Campaign.region_open(reg):
				var ptr := Campaign.story_pointer(qid)
				check(ptr.length() <= 112, "%s/%s: goal line fits (%d)" % [arc, qid, ptr.length()])
				var guard := 0
				while not Campaign.region_open(reg) and guard < 8:
					guard += 1
					var cid := Campaign.first_in_chain(Campaign.gate_of(reg))
					var p2 := Campaign.story_pointer(qid)
					check(p2.contains("long way") or p2.contains("Get further"), "%s/%s: goal line names the long way: %s" % [arc, qid, p2])
					_pay_and_take(arc, cid)
				check(Campaign.region_open(reg), "%s/%s: %s open with zero wins" % [arc, qid, reg])
				check(Campaign.story_pointer(qid) == "", "%s/%s: goal line back to the story" % [arc, qid])
				var m := GameMap.new()
				check(not Campaign.blocks(m, reg), "%s/%s: border no longer blocks %s" % [arc, qid, reg])
				m.free()
			if reg != "":
				GameState.run["pinned_quest"] = ""
				check(str(GoalLine.story_place(qid)[0]) != "", "%s/%s: the compass has a place" % [arc, qid])
			for q in GameState.run["quests"]:
				if str(q["id"]) == qid:
					q["done"] = true
			if qid == "cattopia":
				GameState.run["flags"]["meow_taught"] = true
			if qid == "hideout":
				GameState.run["flags"]["hideout_seen"] = true
			if qid == "clear_meadow" and arc == "gangsters":
				GameState.run["flags"]["sal_recruited"] = true
		var ids: Array = Story.beats().map(func(b: Dictionary) -> String: return str(b.get("id", "")))
		for r2 in (["wastes", "sky"] if arc == "penguins" else ["countryside", "docks", "neon", "underground", "uptown"]):
			check(("c16b_long_" + r2) in ids and ("c16b_won_" + r2) in ids, "%s: the story notices %s opening (win and long-way beats)" % [arc, r2])
			check(GameState.run["flags"].has("long_way_" + r2), "%s: long_way_%s flag set for the morning beat" % [arc, r2])
		check(GameState.progress_tier() >= 4, "%s: progress tier reaches 4 with zero wins (%d)" % [arc, GameState.progress_tier()])
		# --- every other campaign-held region too ---
		for cid: String in Campaign.for_arc():
			var reg := str(Campaign.get_c(cid)["region"])
			var guard := 0
			while not Campaign.region_open(reg) and guard < 8:
				guard += 1
				_pay_and_take(arc, Campaign.first_in_chain(cid))
			check(Campaign.region_open(reg), "%s: %s open with zero wins" % [arc, reg])
		var wins := 0
		for cid: String in Campaign.for_arc():
			wins += int(Campaign.cs(cid).get("wins", 0))
		check(wins == 0 and (Campaign.st()["won"] as Dictionary).is_empty(), "%s: zero wins, nothing marked won" % arc)
		# The campaign is still playable for its prizes after the long way.
		var c0: String = Campaign.for_arc()[0]
		check(Campaign.why_locked(c0) != "No such campaign." and not Campaign.is_won(c0), "%s: %s board still there for its rewards" % [arc, c0])

	# --- retry flow (both arcs) ---
	for arc: String in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi" if arc == "penguins" else "pax", "Hero", "Dreamhollow", "Biscuit")
		var cid: String = Campaign.for_arc()[0]
		var cs := Campaign.cs(cid)
		cs["mustered"] = true
		var nid := ""
		for l in Campaign.node(cid, "n0").get("links", []):
			if not str(Campaign.node(cid, str(l)).get("type", "")) in Campaign.NONBATTLE:
				nid = str(l)
		check(nid != "", "%s: a battle node next to camp" % arc)
		if nid == "":
			continue
		var fld := str(Campaign.cfg(cid, nid).get("field", ""))
		var base: Dictionary = GameState.load_json("res://data/battles.json").get(fld, {})
		var f := {"cid": cid, "nid": nid, "field": fld}
		var d0 := Campaign.battle_data(base, f)
		var diff0 := Difficulty.level()
		var m0 := int(cs["morale"])
		Campaign.st()["fight"] = f.duplicate()
		Campaign.finish(false, 20)
		check(int(cs["morale"]) == m0 - Difficulty.add("morale_loss") / 2, "%s: first loss on a node costs half morale (%d -> %d)" % [arc, m0, int(cs["morale"])])
		check(str(Campaign.st().get("after_loss", "")) == cid, "%s: the loss card is queued" % arc)
		var keys: Array = Campaign.loss_choices(cid).map(func(x: Array) -> String: return str(x[0]))
		check(keys == ["retry", "easier", "long", "board", "leave"], "%s: loss card offers retry/easier/long way/board/way out: %s" % [arc, str(keys)])
		check(Campaign.retry(cid, true), "%s: easier retry accepted" % arc)
		check(Campaign.assist(cid, nid) == 1, "%s: assist step 1 for that node" % arc)
		var d1 := Campaign.battle_data(base, f)
		check(int(d1["enemy_tickets"]) < int(d0["enemy_tickets"]) or int(d0["enemy_tickets"]) <= 10, "%s: easier retry has fewer foe tickets (%d < %d)" % [arc, int(d1["enemy_tickets"]), int(d0["enemy_tickets"])])
		check(int(d1["tickets"]) >= int(d0["tickets"]) * 9 / 10, "%s: easier retry starts no worse (%d vs %d)" % [arc, int(d1["tickets"]), int(d0["tickets"])])
		check(float(d1["wave_every"]) > float(d0["wave_every"]), "%s: easier retry has slower waves" % arc)
		var diff1 := Difficulty.level()
		check(diff0 == diff1, "%s: the save's Difficulty is unchanged" % arc)
		Campaign.retry(cid, true)
		Campaign.retry(cid, true)
		check(Campaign.assist(cid, nid) == 2, "%s: assist caps at 2" % arc)
		for i in 6:
			Campaign.st()["fight"] = f.duplicate()
			Campaign.finish(false, 0)
			check(int(cs["morale"]) > 0 and int(cs["supply"]) >= 0, "%s: loss %d keeps morale > 0 (%d)" % [arc, i + 2, int(cs["morale"])])
		Campaign.st()["fight"] = f.duplicate()
		Campaign.finish(true, 20)
		check(Campaign.assist(cid, nid) == 0, "%s: assist cleared once the node is taken" % arc)
		check(Campaign.flavour(cid, nid, true) != "" and Campaign.flavour(cid, nid, false) != "", "%s: fights have a story voice" % arc)
		# Retreat is never worse than a loss.
		var m1 := int(cs["morale"])
		Campaign.st()["fight"] = {"cid": cid, "nid": "n0", "field": fld}
		Campaign.retreat(30)
		check(m1 - int(cs["morale"]) <= Difficulty.add("morale_loss"), "%s: retreat costs no more than a loss" % arc)
		check(int(cs["supply"]) >= 10, "%s: retreat leaves enough supply for a helper" % arc)
		Campaign.st().erase("after_loss")

	print("zero_win_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)

extends SceneTree
## C16a P1: the unlock timeline guard (docs/PROGRESSION.md -> data/progression.json).
##   - every enforced row matches the game data (mega_travel.json unlock.when day/year);
##   - a "rusher" (every story step done, every skill maxed, a full purse, many hearts) cannot
##     open a mega region the day before its row, and can on the day (both arcs);
##   - each region's non-combat road (unlock.alt) opens it with no story, never before its day;
##   - T4 hub links, the airship/airstrip and T5 hops wait for year 2 (day 113) even for a rusher;
##   - at day 30 with tier 3, Windward / Gilt City and every T4 link stay shut.
var fails := 0
const STORY := ["clear_meadow", "spark", "wastes_gate", "docks", "sky_stair", "neon", "teleporter", "uptown"]
const SKILLS := ["foraging", "fishing", "mining", "ranching", "farming", "combat", "crafting", "cooking"]


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _complete(qid: String) -> void:
	if not GameState.has_quest(qid) and not GameState.quest_done(qid):
		GameState.add_quest(qid, qid)
	for q in GameState.run["quests"]:
		if str(q["id"]) == qid:
			q["done"] = true


func _fresh(arc: String, story: bool) -> void:
	GameState.new_run(arc, "kairi" if arc == "penguins" else "pax", "Hero", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["crystals"] = 9999999
	for s: String in SKILLS:
		GameState.run["skills"][s] = {"level": 30, "xp": 0}
	for i in 10:
		GameState.run["friendship"]["p1_friend_%d" % i] = GameState.HEART_POINTS * 10
	if story:
		for q: String in STORY:
			_complete(q)


func _when_day(u: Dictionary) -> int:
	var w: Dictionary = u.get("when", {})
	var d := int(w.get("day", 1))
	if w.has("year"):
		d = maxi(d, (int(w["year"]) - 1) * 112 + 1)
	return d


func _initialize() -> void:
	seed(16)
	Campaign.bypass = false
	check(not Progression.data().is_empty(), "data/progression.json loads")
	check(Progression.unlock_day("mega_windward") == 113 and Progression.unlock_day("nope") == -1, "unlock_day reads the table")
	check(Calendar.year(112) == 1 and Calendar.year(113) == 2 and Calendar.year(225) == 3, "year boundaries (day 113 / 225)")
	for arc: String in ["penguins", "gangsters"]:
		print("== ", arc)
		# --- the rusher: story done, skills maxed --------------------------------------
		_fresh(arc, true)
		check(GameState.progress_tier() == 4, "rusher at story tier 4")
		for id: String in MegaTravel.data():
			var r: Dictionary = MegaTravel.reg(id)
			if not MegaTravel.arc_ok(r):
				continue
			var pid := "mega_" + id
			var day := Progression.unlock_day(pid)
			check(day > 0 and Progression.enforced().has(pid), "%s is an enforced row (day %d)" % [pid, day])
			check(_when_day(r.get("unlock", {})) == day, "%s: mega_travel.json floor %d == table %d" % [id, _when_day(r.get("unlock", {})), day])
			GameState.run["day"] = day - 1
			check(not MegaTravel.can_start(r), "%s shut for a rusher on day %d" % [id, day - 1])
			check(MegaTravel.gate_words(r) != "", "%s says why (%s)" % [id, MegaTravel.gate_words(r)])
			GameState.run["day"] = day
			check(MegaTravel.can_start(r), "%s opens on day %d" % [id, day])
		# --- the non-combat roads: no story at all, skills/hearts maxed -----------------
		_fresh(arc, false)
		check(GameState.progress_tier() == 0, "no-story run at tier 0")
		for id: String in MegaTravel.data():
			var r: Dictionary = MegaTravel.reg(id)
			if not MegaTravel.arc_ok(r):
				continue
			var u: Dictionary = r.get("unlock", {})
			var day := _when_day(u)
			GameState.run["day"] = day - 1
			check(not MegaTravel.can_start(r), "%s: the other road can't beat the calendar (day %d)" % [id, day - 1])
			GameState.run["day"] = day
			if u.has("alt"):
				check(MegaTravel.can_start(r), "%s opens by its non-combat road (%s)" % [id, str(u.get("alt_words", ""))])
			else:
				check(not MegaTravel.can_start(r) and MegaTravel.gate_words(r).begins_with("Opens after"), "%s (no other road) waits for the story: %s" % [id, MegaTravel.gate_words(r)])
		# --- day 30 at tier 3: the year-2 regions and links stay shut -------------------
		_fresh(arc, false)
		for q: String in ["clear_meadow", "spark", "docks", "sky_stair", "neon"]:
			_complete(q)
		GameState.run["day"] = 30
		check(GameState.progress_tier() == 3, "tier 3 run")
		for id in ["windward", "giltcity"]:
			if MegaTravel.arc_ok(MegaTravel.reg(id)):
				check(not MegaTravel.can_start(MegaTravel.reg(id)), "%s shut at day 30 / tier 3" % id)
		# --- T4 / T5 travel: year 2 even for a rusher with every region and job done -----
		_fresh(arc, true)
		for id: String in MegaTravel.data():
			GameState.run["flags"]["mega_%s_open" % id] = true
			_complete("mega_%s_job" % id)
		var n4 := 0
		var n5 := 0
		for l: Dictionary in TravelNet.data().get("links", []):
			var t := int(l.get("tier", 0))
			if t < 4 or not TravelNet.link_arc_ok(l) or bool(l.get("marina", false)):
				continue
			GameState.run["day"] = 112
			var shut := not TravelNet.cond_ok(l.get("unlock", {}), l, true)
			GameState.run["day"] = 113
			var open := TravelNet.cond_ok(l.get("unlock", {}), l, true)
			check(shut and open, "%s: shut on day 112, open on day 113" % str(l["id"]))
			if t == 4:
				n4 += 1
			else:
				n5 += 1
		check(n4 > 0 and n5 > 0, "%s has T4 (%d) and T5 (%d) lines" % [arc, n4, n5])
		var tl: Dictionary = TravelNet.link("t4_gloamwood_frostpeak")
		if not tl.is_empty() and TravelNet.link_arc_ok(tl):
			_complete("mega_gloamwood_job")
			for q in GameState.run["quests"]:
				if str(q["id"]) == "mega_frostpeak_job":
					q["done"] = false
			check(not TravelNet.cond_ok(tl.get("unlock", {}), tl, true), "a T4 link waits for both regions' hub jobs")
	print("progression_test: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)

extends SceneTree
## New game, both arcs: every main-story quest whose region is held by a
## campaign gets a goal-line pointer to that campaign, the campaign (and the
## chain before it) can be fought at that point in the story, and winning it
## opens the region. Locks are real here (Campaign.bypass stays false).
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	Campaign.bypass = false
	var orders := {
		"penguins": ["meet_town", "first_harvest", "clear_meadow", "cattopia", "spark", "wastes_gate", "commander", "sky_stair", "knight", "teleporter", "finale"],
		"gangsters": ["meet_town", "first_harvest", "clear_meadow", "hideout", "gang", "docks", "neon", "pit", "uptown", "tower"],
	}
	for arc: String in orders:
		GameState.new_run(arc, "kairi" if arc == "penguins" else "pax", "Hero", "Dreamhollow", "Biscuit")
		GameState.run["quests"] = []
		check(not Campaign.region_open("wastes"), "%s: a new game starts with the Wastes held" % arc)
		for qid: String in orders[arc]:
			var def := GameState._quest_def(qid)
			if def.is_empty():
				continue
			GameState.add_quest(qid, str(def.get("text", qid)))
			var reg := str(Campaign.STORY_REGION.get(qid, ""))
			if reg != "" and not Campaign.region_open(reg):
				if qid == "sky_stair":
					GameState.run["flags"]["campfire_done"] = true
					GameState.run["flags"]["babies_done"] = true
				var ptr := GameState.next_step()
				check(ptr.contains("campaign map"), "%s/%s: goal line points at the campaign: %s" % [arc, qid, ptr])
				# Win the chain, first campaign first, as the pointer leads.
				var guard := 0
				while not Campaign.region_open(reg) and guard < 6:
					guard += 1
					var named := ""
					for cid: String in Campaign.for_arc():
						if ptr.contains("\"%s\"" % str(Campaign.get_c(cid)["title"])):
							named = cid
					check(named != "", "%s/%s: pointer names a campaign of this arc" % [arc, qid])
					if named == "":
						break
					check(Campaign.why_locked(named) == "", "%s/%s: %s can be fought now (%s)" % [arc, qid, named, Campaign.why_locked(named)])
					Campaign._unlock(named)
					ptr = GameState.next_step()
				check(Campaign.region_open(reg), "%s/%s: %s is open after its campaign" % [arc, qid, reg])
				check(not GameState.next_step().contains("campaign map"), "%s/%s: goal line goes back to the story" % [arc, qid])
			for q in GameState.run["quests"]:
				if str(q["id"]) == qid:
					q["done"] = true
		# Region locks never trap a finished story: every story region is open.
		for qid: String in Campaign.STORY_REGION:
			var r := str(Campaign.STORY_REGION[qid])
			if Campaign.gate_of(r) != "" and qid in orders[arc]:
				check(Campaign.region_open(r), "%s: %s open at the end" % [arc, r])
	print("campaign_story_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)

extends SceneTree
## New game, both arcs: every main-story quest whose region is held by a
## campaign gets a goal-line pointer to that campaign, the campaign (and the
## chain before it) can be fought at that point in the story, and winning it
## opens the region. Locks are real here (Campaign.bypass stays false).
## The lead-in is simulated as a player would meet it: chapter 2 comes before
## the first held story region, then training, a team and provisions.
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(7)
	Campaign.bypass = false
	var orders := {
		"penguins": ["meet_town", "first_harvest", "clear_meadow", "cattopia", "spark", "wastes_gate", "commander", "sky_stair", "knight", "teleporter", "finale"],
		"gangsters": ["meet_town", "first_harvest", "clear_meadow", "hideout", "gang", "docks", "neon", "pit", "uptown", "tower"],
	}
	for arc: String in orders:
		GameState.new_run(arc, "kairi" if arc == "penguins" else "pax", "Hero", "Dreamhollow", "Biscuit")
		GameState.run["quests"] = []
		check(Campaign.region_open("wastes") == (arc == "gangsters"), "%s: a new game starts with the Wastes held (penguin-only campaign)" % arc)
		GameState.run["party"] = {}
		for cid0: String in Campaign.for_arc():
			check(Campaign.why_locked(cid0) != "", "%s: %s can't be fought on day one" % [arc, cid0])
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
				check(Campaign.story_pointer(qid).length() <= 112, "%s/%s: goal line fits (%d chars)" % [arc, qid, Campaign.story_pointer(qid).length()])
				check(CampaignGate.story_ok(), "%s/%s: chapter 2 comes before the first held story region" % [arc, qid])
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
					# The lead-in, as the goal line asks for it: train, gather a team, bring provisions.
					if not CampaignGate.trained():
						check(ptr.to_lower().contains("train"), "%s/%s: the goal line sends you to training first: %s" % [arc, qid, ptr])
						GameState.run["flags"][CampaignGate.TRAINED] = true
					var tries := 0
					while CampaignGate.team_short(named) > 0 and tries < 12:
						tries += 1
						var pool: Array = ["dad", "mom", "pax", "mer", "penguin_f", "coldy"] if arc == "penguins" else ["sal", "dad", "mom", "pax", "mer", "big_jim"]
						for cc: String in pool:
							if not cc in (Companion.party()["known"] as Array) and cc != str(GameState.run.get("playable", "")):
								Companion.recruit(cc, false)
								break
					check(CampaignGate.team_short(named) == 0, "%s/%s: a team can be gathered for %s" % [arc, qid, named])
					var nd: Dictionary = CampaignGate.need(named)
					for it: String in nd.get("items", {}):
						GameState.add_item(it, int(nd["items"][it]))
					GameState.run["crystals"] = int(GameState.run.get("crystals", 0)) + int(nd.get("crystals", 0))
					check(Campaign.why_locked(named) == "", "%s/%s: %s can be fought now (%s)" % [arc, qid, named, Campaign.why_locked(named)])
					check(CampaignGate.muster(named) != "", "%s/%s: %s musters" % [arc, qid, named])
					Campaign._unlock(named)
					ptr = GameState.next_step()
				check(Campaign.region_open(reg), "%s/%s: %s is open after its campaign" % [arc, qid, reg])
				check(not GameState.next_step().contains("campaign map"), "%s/%s: goal line goes back to the story" % [arc, qid])
			for q in GameState.run["quests"]:
				if str(q["id"]) == qid:
					q["done"] = true
			# Story flags that finishing these quests sets in play.
			if qid == "cattopia":
				GameState.run["flags"]["meow_taught"] = true
			if qid == "hideout":
				GameState.run["flags"]["hideout_seen"] = true
			if qid == "clear_meadow" and arc == "gangsters":
				GameState.run["flags"]["sal_recruited"] = true  # the gang quest only opens once Sal is in
		# Region locks never trap a finished story: every story region is open.
		for qid: String in Campaign.STORY_REGION:
			var r := str(Campaign.STORY_REGION[qid])
			if Campaign.gate_of(r) != "" and qid in orders[arc]:
				check(Campaign.region_open(r), "%s: %s open at the end" % [arc, r])
	print("campaign_story_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)

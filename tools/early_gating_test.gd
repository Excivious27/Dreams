extends SceneTree
## Early-game gating, both arcs (CONDUCT 1 line 06): a brand-new game is not
## flooded on day 1, and every later system has a lead-in and a clear locked message.
##   - Rec Center / Rec Hall (and its arcade): shut on day 1 with a banner that says
##     when; villagers talk about the works from day 3; the opening letter and quest
##     come on day 7 once the town intro is done (never before, never without it).
##   - Community farm: Hazel's letter after day 3, signed with her name, plus its quest.
##   - Campaigns: none can be fought on day 1, the lock says what to do, and the
##     trainer's invite beat exists for chapter 2.
##   - Mega regions: none open in the first two weeks without story; every travel
##     keeper has a locked line; no region tab shows.
##   - Plans board: no tier is gated by a bare "story first".
## Prints the unlock day of each system.
var fails := 0


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


func _sleep() -> void:
	GameState.run["time"] = 22 * 60
	GameState.sleep()


func _initialize() -> void:
	Campaign.bypass = false
	for arc: String in ["penguins", "gangsters"]:
		print("== ", arc)
		GameState.new_run(arc, "kairi" if arc == "penguins" else "pax", "Hero", "Dreamhollow", "Biscuit")
		# Day 1.
		check(not RecCenter.is_open(), "%s: the %s is shut on day 1" % [arc, RecCenter.name()])
		check(RecCenter.soon_lines().is_empty(), "%s: nobody talks about the works on day 1" % arc)
		check(not Commons.known(), "%s: the community farm is not announced on day 1" % arc)
		check(MegaRegion.unlocked().is_empty(), "%s: no mega region tab on day 1" % arc)
		for cid: String in Campaign.for_arc():
			var why := Campaign.why_locked(cid)
			check(why != "", "%s: %s locked on day 1 (%s)" % [arc, cid, why])
		for id: String in MegaTravel.data():
			var r: Dictionary = MegaTravel.reg(id)
			if not MegaTravel.arc_ok(r):
				continue
			check(not MegaTravel.can_start(r), "%s: %s keeper not ready on day 1" % [arc, id])
			check(str(r.get("lines", {}).get("locked", "")) != "", "%s: %s keeper has a locked line" % [arc, id])
		for id: String in Builds.all():
			for t in Builds.all()[id].get("tiers", []):
				var ul: Dictionary = t.get("unlock", {})
				for k in ["flag", "quest"]:
					if ul.has(k) and not ul.has("progress"):
						check(Builds.STORY_WORDS.has(str(ul[k])), "plans: %s tier %d says which story step (%s)" % [id, int(t["tier"]), str(ul[k])])
		var open_now := 0
		for id: String in Builds.data():
			if Builds.gate(id) == "":
				open_now += 1
		print("  day 1 plans with no gate: %d of %d" % [open_now, Builds.data().size()])
		# Days 2-14, the town intro done on day 2.
		var first := {}
		var mail_seen := Mail.list().size()
		for d in range(2, 15):
			if d == 2:
				_complete("meet_town")
			_sleep()
			var day := int(GameState.run["day"])
			if not first.has("rec_talk") and not RecCenter.soon_lines().is_empty():
				first["rec_talk"] = day
			if not first.has("rec") and RecCenter.is_open():
				first["rec"] = day
			if not first.has("cf") and Commons.known():
				first["cf"] = day
			var ml: Array = Mail.list()
			for i in range(mail_seen, ml.size()):
				var from := str(ml[i]["from"])
				check(from != "" and from.left(1) == from.left(1).to_upper(), "%s: day %d letter signed with a name (%s)" % [arc, day, from])
			mail_seen = ml.size()
		print("  unlock days: ", first)
		check(int(first.get("rec_talk", 99)) == 3, "%s: villagers mention the works from day 3" % arc)
		check(int(first.get("rec", 99)) == 7, "%s: the %s opens on day 7" % [arc, RecCenter.name()])
		check(GameState.has_quest("rec_visit"), "%s: the opening brings a visit quest" % arc)
		check(RecCenter.soon_lines().is_empty(), "%s: works chatter stops once it's open" % arc)
		check(int(first.get("cf", 99)) == 4, "%s: Hazel's letter arrives on day 4" % arc)
		check(GameState.has_quest("cf_main"), "%s: the letter brings the community farm quest" % arc)
		check(MegaRegion.unlocked().is_empty(), "%s: still no mega region after two weeks without story" % arc)
		# Without the town intro the Rec Center waits.
		GameState.new_run(arc, "kairi" if arc == "penguins" else "pax", "Hero", "Dreamhollow", "Biscuit")
		for d in range(1, 9):
			_sleep()
		check(not RecCenter.is_open(), "%s: no grand opening before the town intro" % arc)
		_complete("meet_town")
		_sleep()
		check(RecCenter.is_open(), "%s: it opens the morning after the town intro" % arc)
	# The campaign trainer's invite exists for chapter 2 in both arcs.
	var ids: Array = []
	for ch in Story.data().get("both", []):
		for b in ch.get("beats", []):
			ids.append(str(b.get("id", "")))
	check("bt_invite_p" in ids and "bt_invite_g" in ids, "campaign invite beats exist for both arcs")
	print("early_gating_test: %s (%d fails)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)

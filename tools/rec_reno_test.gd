extends SceneTree
## Rec renovations (CONDUCT 3 P5, Tom Guide 26 #3): after the grand opening the rec keeps
## growing for more than a year's first three seasons: start letter, a few days taped off,
## open letter; cabinets/Skee-Ball/jukebox/top prize shelf wait for their phase; then the
## seasonal Rec Cup. Also the community farm's multi-day builds' words (Guide 26 #2).
##   godot --headless --path . -s res://tools/rec_reno_test.gd
var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	Campaign.bypass = true
	seed(7)
	_run.call_deferred()


func _mail_last() -> String:
	var ml: Array = GameState.run.get("mail", [])
	return "" if ml.is_empty() else str(ml[-1].get("id", "")) + str(ml[-1].get("text", ""))


func _run() -> void:
	for arc: String in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi", "T", "Town", "Pup")
		GameState.run["intro_done"] = true
		GameState.run["day"] = 7
		RecCenter.open_now()
		var opened := 7
		ok(RecReno.blocked({"act": "cabinet", "game": "whack"}) != "", "[%s] whack covered at the opening" % arc)
		ok(RecReno.blocked({"act": "cabinet", "game": "stack"}) == "", "[%s] stack open at the opening" % arc)
		ok(RecReno.blocked({"act": "skee"}) != "" and RecReno.blocked({"act": "jukebox"}) != "", "[%s] skee and jukebox wait" % arc)
		ok(Tickets.lock_text("rp_trophy_gold").begins_with("Waits for"), "[%s] the top shelf waits for the prize gallery (%s)" % [arc, Tickets.lock_text("rp_trophy_gold")])
		var log := []
		var last := ""
		for d in range(8, 8 + 200):
			GameState.run["day"] = d
			var before := _mail_last()
			RecReno.morning()
			if _mail_last() != before:
				var mm: Dictionary = GameState.run["mail"][-1]
				log.append([d, str(mm.get("text", ""))])
			for ph: Dictionary in RecReno.phases():
				var id := str(ph["id"])
				if GameState.run["flags"].has("rec_reno_" + id) and last.find(id) < 0:
					last += id + " "
		var all_open := true
		for ph: Dictionary in RecReno.phases():
			all_open = all_open and GameState.run["flags"].has("rec_reno_" + str(ph["id"]))
		ok(all_open, "[%s] every renovation opened in 200 days (%s)" % [arc, last])
		var final := int(GameState.run["flags"].get("rec_reno_trophy_hall", 0))
		ok(final - opened > 84, "[%s] the rec takes longer than three months to finish (day %d)" % [arc, final])
		ok(log.size() >= RecReno.phases().size() * 2, "[%s] a start and an open letter per phase (%d letters)" % [arc, log.size()])
		ok(RecReno.blocked({"act": "cabinet", "game": "whack"}) == "" and RecReno.blocked({"act": "skee"}) == "", "[%s] everything open at the end" % arc)
		ok(Tickets.lock_text("rp_trophy_gold") == "" or not Tickets.lock_text("rp_trophy_gold").begins_with("Waits for"), "[%s] top shelf open" % arc)
		var cup_mail := false
		for e: Array in log:
			cup_mail = cup_mail or str(e[1]).contains("Rec Cup:")
			if arc == "gangsters":
				ok(not str(e[1]).to_lower().contains("crystal") and not str(e[1]).contains("Rec Center"), "[gangsters] letter fits the arc: %s" % e[1])
		ok(cup_mail, "[%s] the Rec Cup letter arrives" % arc)
		var c := RecReno.cup()
		ok(not c.is_empty(), "[%s] a cup this season" % arc)
		var t0 := Tickets.count()
		Tickets.set_best(str(c["game"]), int(c["score"]) + 1)
		ok(Tickets.count() == t0 + int(c["tickets"]), "[%s] beating the cup score pays its tickets" % arc)
		Tickets.set_best(str(c["game"]), int(c["score"]) + 5)
		ok(Tickets.count() == t0 + int(c["tickets"]), "[%s] the cup pays once a season" % arc)
		# Working days: a phase in progress says when it opens.
		GameState.run["flags"]["rec_reno"] = {"arcade_wing": [10, 13]}
		GameState.run["flags"].erase("rec_reno_arcade_wing")
		GameState.run["day"] = 11
		ok(RecReno.blocked({"act": "cabinet", "game": "gallery"}).contains("Open in 2 days"), "[%s] taped-off corner gives its days (%s)" % [arc, RecReno.blocked({"act": "cabinet", "game": "gallery"})])
		ok(RecReno.board_lines().size() >= 1, "[%s] the desk board lists the work" % arc)

	# Community farm: every build stage takes a few nights and words them.
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	for i in Commons.stages().size():
		if Commons.is_build(i):
			ok(Commons.build_days(i) >= 2, "build stage %s takes %d nights" % [Commons.stages()[i]["id"], Commons.build_days(i)])
	print("rec_reno_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

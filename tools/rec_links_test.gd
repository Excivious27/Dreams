extends SceneTree
## Rec Center / arcade integration (CONDUCT 2, c2_14): the games feed quests
## (arcade_ms / rec_best / tickets_won conditions, ticket rewards), heart perks
## (#tickets weekly), mail (league invite, prize-counter news), festivals (ticket
## bonus), the town board's notes, the high score board's milestone line, prize
## locks on milestones and old-save migration.
##   godot --headless --path . -s res://tools/rec_links_test.gd
var fails := 0


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("  FAIL ", what)


func _fresh(arc: String) -> void:
	GameState.new_run(arc, "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.add_quest("meet_town", "x")
	GameState.complete_quest("meet_town")


func _mail_from(who: String) -> int:
	var n := 0
	for m: Dictionary in Mail.list():
		if str(m.get("from", "")).begins_with(who):
			n += 1
	return n


func _run() -> void:
	InputSetup.ensure_actions()
	# --- old save: no arcade blocks at all -> both made on load ---
	_fresh("penguins")
	GameState.run.erase("arcade")
	GameState.run.erase("arcade_hub")
	GameState.run["tickets"] = 7  # a pre-block save kept tickets at the top level
	GameState._migrate()
	ok(GameState.run.get("arcade") is Dictionary and GameState.run.get("arcade_hub") is Dictionary, "migration makes run.arcade and run.arcade_hub")
	ok(Tickets.count() == 7 and not GameState.run.has("tickets"), "loose tickets moved into the block")

	# --- quest data: every rec quest has a known giver, lines, and an arc-safe wording ---
	var rec_q := 0
	for q: Dictionary in GameState.quests_data.get("side", []):
		var id := str(q["id"])
		if not id.begins_with("rec_"):
			continue
		rec_q += 1
		ok(GameState.npcs.has(str(q.get("giver", ""))), id + ": giver exists")
		var ql := Quests.lines(id)
		ok(ql.has("offer") and ql.has("done"), id + ": offer and done lines")
	ok(rec_q >= 8, "rec side quests (got %d)" % rec_q)

	# --- conditions ---
	ok(not GameState._cond_ok({"arcade_ms": "jumper_3"}), "arcade_ms false before")
	ArcadeHub.set_milestone("jumper_3")
	ok(GameState._cond_ok({"arcade_ms": "jumper_3"}) and GameState._cond_ok({"arcade_ms": ["jumper_3"]}), "arcade_ms true after")
	ok(not GameState._cond_ok({"rec_best": ["stack", 3000]}), "rec_best false before")
	Tickets.set_best("stack", 3200)
	ok(GameState._cond_ok({"rec_best": ["stack", 3000]}), "rec_best true after")
	ok(not GameState._cond_ok({"tickets_won": 50}), "tickets_won false before")
	Tickets.add(60, "quest")  # one whack play is capped at 34 (c2_05 payout)
	ok(GameState._cond_ok({"tickets_won": 50}), "tickets_won true after")
	ok(GameState._cond_ok({"day": 1}), "other keys unaffected")

	# --- offers wait for a first visit, then pay tickets ---
	_fresh("penguins")
	GameState.run["day"] = 12
	var offer := GameState._quest_def("rec_pip_jumper")
	ok(not GameState._cond_ok(offer.get("when", {})), "Pip's arcade quest waits for the rec")
	RecCenter.open_now()
	GameState.run["flags"]["rec_visited"] = true
	ok(GameState._cond_ok(offer.get("when", {})), "Pip can offer the Block Jumper quest after a visit")
	GameState.add_quest("rec_pip_jumper", str(offer.get("text", "")))
	ok(not Quests._done(GameState._quest_def("rec_pip_jumper")), "not done before level 3")
	ArcadeHub.set_milestone("jumper_3")
	ok(Quests._done(GameState._quest_def("rec_pip_jumper")), "done after level 3")
	var t0 := Tickets.count()
	ok(GameState.complete_quest("rec_pip_jumper") and Tickets.count() == t0 + 40, "reward pays 40 tickets (%d -> %d)" % [t0, Tickets.count()])
	ok(GameMap.quest_done_text("rec_pip_jumper").contains("40 tickets"), "quest toast names the tickets: " + GameMap.quest_done_text("rec_pip_jumper"))
	# Maple's league dare follows Tobin's bet.
	GameState.run["day"] = 20
	ok(str(GameState.side_quest_for("maple").get("id", "")) != "rec_maple_league", "Maple's dare waits for Tobin's bet")
	GameState.add_quest("rec_bowl_120", "x")
	GameState.complete_quest("rec_bowl_120")
	var mq := ""
	for q: Dictionary in GameState.quests_data["side"]:
		if str(q.get("giver", "")) == "maple" and str(q["id"]) == "rec_maple_league":
			mq = "rec_maple_league" if GameState._cond_ok(q.get("when", {})) else "locked"
	ok(mq == "rec_maple_league", "Maple's dare opens after the bet")

	# --- gangster arc wording ---
	_fresh("gangsters")
	ok(str(Quests.lines("rec_sal_whack")["offer"][1]).contains("worth your while") and str(Quests.lines("rec_sal_whack")["offer"][0]).contains("crew"), "Sal's gangster wording")
	ok(str(Quests.lines("rec_alder_cabinets")["offer"][0]).contains("Rec Hall"), "Alder's gangster wording")

	# --- heart perks: weekly tickets only once the rec is open ---
	_fresh("penguins")
	GameState.run["friendship"]["tobin"] = GameState.HEART_POINTS * 2
	GameState.run["day"] = 8  # day % 7 == 1: weekly gifts
	var tk := Tickets.count()
	var shells := GameState.count("seashell")
	Perks.morning()
	ok(Tickets.count() == tk and GameState.count("seashell") == shells + 3, "before opening: shells, no tickets")
	RecCenter.open_now()
	GameState.run["day"] = 15
	var lines := Perks.morning()
	ok(Tickets.count() == tk + 5, "after opening: Tobin's 5 tickets (%d -> %d)" % [tk, Tickets.count()])
	ok(str(lines).contains("5 tickets"), "morning line names the tickets: %s" % str(lines))

	# --- mail: league invite once; prize news once per prize, none for open prizes ---
	_fresh("penguins")
	GameState.run["day"] = 8
	RecCenter.open_now()
	GameState.run["flags"]["rec_visited"] = true
	RecCenter.news()
	ok(_mail_from("Maple") == 0, "no league letter on opening day")
	GameState.run["day"] = 11
	RecCenter.news()
	RecCenter.news()
	ok(_mail_from("Maple") == 1, "one league letter three days in")
	var desk := RecCenter.name() + " front desk"
	ok(_mail_from(desk) == 0, "no prize news for prizes anyone can buy")
	Tickets.set_best("bowling", 105)
	RecCenter.news()
	ok(_mail_from(desk) == 1, "prize news after a 105 game")
	var last: Dictionary = Mail.list()[-1]
	ok(str(last["text"]).contains(GameState.item_name("rp_trophy_bronze")), "names the bronze trophy: " + str(last["text"]))
	RecCenter.news()
	ok(_mail_from(desk) == 1, "the same prize isn't announced twice")
	Mail.morning()  # the real morning path runs news() without errors
	# --- festivals ---
	GameState.run["flags"]["fest_egg_14"] = true
	var tf := Tickets.count()
	ok(RecCenter.festival_bonus(null, "fest_egg_14") == 15 and Tickets.count() == tf + 15, "festival pays 15 tickets")
	ok(RecCenter.festival_bonus(null, "fest_egg_14") == 0, "...once")
	ok(RecCenter.festival_bonus(null, "fest_harvest_42") == 0, "no bonus without joining in")
	# --- town board notes ---
	GameState.run["day"] = 10  # league night
	ok(RecCenter.board_notes().contains("League night"), "board: league night")
	GameState.run["day"] = 11
	ok(RecCenter.board_notes().contains(RecCenter.name()), "board: the rec is open")
	_fresh("penguins")
	GameState.run["day"] = 5
	ok(RecCenter.board_notes().contains("opening"), "board: opening soon (day 5): " + RecCenter.board_notes())
	GameState.run["day"] = 2
	ok(RecCenter.board_notes() == "", "board: nothing on day 2")

	# --- milestones: the high score line and prize locks ---
	_fresh("penguins")
	ok(RecCenter.milestone_line().begins_with("Arcade milestones: 0/%d" % ArcadeHub.MILESTONES.size()), "milestone line at zero: " + RecCenter.milestone_line())
	ArcadeHub.set_milestone("jumper_1")
	ok(RecCenter.milestone_line().begins_with("Arcade milestones: 1/") and RecCenter.milestone_line().contains("level 2"), "next milestone named: " + RecCenter.milestone_line())
	Tickets.prizes()["prizes"]["_t_ms"] = {"item": "candy", "cost": 1, "need": {"ms": ["stack_tetra"]}}
	ok(Tickets.lock_text("_t_ms") == str(ArcadeHub.MILESTONES["stack_tetra"]), "prize locked on a milestone: " + Tickets.lock_text("_t_ms"))
	ArcadeHub.set_milestone("stack_tetra")
	ok(Tickets.unlocked("_t_ms"), "...and unlocked by it")
	Tickets.prizes()["prizes"].erase("_t_ms")

	print("rec_links_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

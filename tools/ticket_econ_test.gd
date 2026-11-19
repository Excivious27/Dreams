extends SceneTree
## Ticket economy (CONDUCT 2, c2_05): the fees match tools/gen_rec.py, payouts follow
## their soft cap and cap, no play or prize can turn tickets back into more crystals than
## they cost, the claw pool, weekly and milestone-locked prizes, and every shelf fits.
##   godot --headless --path . -s res://tools/ticket_econ_test.gd
var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
		print("FAIL: " + what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	var pz := Tickets.prizes()
	var fees: Dictionary = pz.get("fees", {})
	var pay: Dictionary = pz.get("payout", {})
	var resale := float(pz.get("resale", 8))
	var max_sell := float(pz.get("max_sell", 2.15))
	ok(not fees.is_empty() and not pay.is_empty(), "prizes.json carries fees and payouts")
	# Fees the games really charge match the economy's table.
	ok(int(fees.get("bowling", -1)) == RecCenter.fee(), "bowling fee %d matches gen_rec" % RecCenter.fee())
	for g in ArcadeHub.game_ids():
		var gm := ArcadeHub.make(str(g))
		ok(gm != null and int(fees.get(str(g), -1)) == gm.fee, "%s fee %d matches gen_rec FEES (%s)" % [g, gm.fee if gm else -1, str(fees.get(str(g)))])
		if gm:
			gm.free()
	# No play's best payout sells back for its fee.
	for g in fees:
		var cap := int((pay.get(g, {}) as Dictionary).get("cap", 0))
		ok(cap > 0, "%s has a payout cap" % g)
		ok(cap * max_sell / resale < float(fees[g]), "%s: %d tickets resell under its %d fee" % [g, cap, int(fees[g])])
	# Soft cap and cap.
	ok(Tickets.payout("whack", 10) == 10, "under the soft mark pays in full")
	ok(Tickets.payout("whack", 30) == 27, "above it pays half (24 + 6/2)")
	ok(Tickets.payout("stack", 90) == 34, "never past the cap")
	ok(Tickets.payout("quest", 500) == 500, "non-game sources pay as given")
	var perfect := Tickets.payout("bowling", RecCenter.tickets_for(300, 12, 0))
	ok(perfect <= int(pay["bowling"]["cap"]) and perfect > Tickets.payout("bowling", RecCenter.tickets_for(150, 4, 3)), "a perfect game pays most, within the cap (%d)" % perfect)
	ok(RecCenter.tickets_for(60, 0, 1) >= 10, "even a poor bowling game pays a handful")
	var t0 := Tickets.count()
	Tickets.add(999, "gallery")
	ok(Tickets.count() - t0 == int(pay["gallery"]["cap"]), "add() holds a game source to its cap")
	# Prizes resell for a sliver.
	for id in pz.get("prizes", {}):
		var p := Tickets.prize(str(id))
		var item := str(p.get("item", id))
		ok(item.begins_with("rp_"), "counter prize %s is an rp_ item" % item)
		ok(GameState.item_value(item) * max_sell < maxf(float(p["cost"]), 2.0 * resale) * max_sell / resale + 0.01, "%s resells for at most 1/%d of its cost" % [item, int(resale)])
		ok(Art.has("items", Hud.icon_for(item)), "prize icon: " + item)
	# Claw pool: real items with icons; the best-case go is worth less than its fee.
	var pool := Tickets.claw_pool([])
	ok(pool.size() >= 5, "claw pool from gen_rec")
	for e: Array in pool:
		ok(GameState.items.has(str(e[0])) and Art.has("items", Hud.icon_for(str(e[0]))), "claw prize %s exists with art" % str(e[0]))
	ok(float((pz.get("check", {}) as Dictionary).get("claw_ev_best", 99)) < float(fees["claw"]), "claw expected value under its fee")
	# Locks show progress.
	ok(Tickets.lock_text("rp_bowling_cap").contains("(0/2)"), "plays lock shows progress: " + Tickets.lock_text("rp_bowling_cap"))
	Tickets.set_best("bowling", 132)
	ok(Tickets.lock_text("rp_top_hat").contains("best 132"), "score lock shows your best: " + Tickets.lock_text("rp_top_hat"))
	# Milestone lock: the medal wants every cabinet.
	Tickets.add(5000, "test")
	ok(Tickets.buy("rp_arcade_medal") != "", "medal locked before every cabinet")
	for g in ArcadeHub.game_ids():
		ArcadeHub.mark_played(str(g))
	ok(Tickets.buy("rp_arcade_medal") == "", "medal opens with all_games")
	# Weekly: Sprout Fizz once a week.
	GameState.run["day"] = 9
	Tickets.add(200, "welcome")
	ok(Tickets.buy("rp_sprout_fizz") == "" and GameState.count("rp_sprout_fizz") == 1, "Sprout Fizz bought")
	ok(Tickets.buy("rp_sprout_fizz").begins_with("Sold out"), "...once a week: " + Tickets.lock_text("rp_sprout_fizz"))
	ok(Tickets.lock_text("rp_sprout_fizz").contains("6 days"), "sold-out says when it's back")
	GameState.run["day"] = 15
	ok(Tickets.buy("rp_sprout_fizz") == "", "back next week")
	ok(str(GameState.items["rp_sprout_fizz"].get("effect", "")) == "growth", "Sprout Fizz grows crops")
	# Every shelf fits above the detail panel.
	for t in PrizeScreen.TIERS.size():
		var n := 0
		for id in pz.get("prizes", {}):
			if int(Tickets.prize(str(id)).get("tier", 1)) == t + 1:
				n += 1
		ok(PrizeScreen.LIST_Y + n * PrizeScreen.ROW_H <= 342.0, "shelf %d fits (%d prizes)" % [t, n])
	ok(PrizeScreen.row_note("rp_arcade_medal").begins_with("Yours"), "owned row says so")
	Tickets.spend(Tickets.count())
	ok(PrizeScreen.row_note("rp_teddy") == "80 more tickets", "short row says how many: " + PrizeScreen.row_note("rp_teddy"))
	print("ticket_econ_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

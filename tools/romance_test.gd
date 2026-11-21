extends SceneTree
## Dating and marriage (CONDUCT 7 P1), both arcs and two hero bodies:
## bouquet gates (♥7 no / ♥8 yes, consumed only on yes, one partner at a time, ex
## cooldown), dates (invite, scene on the right map + hours, count), locket gates
## (house tier, dates, ♥10), wedding day (never festival/Sunday, runs from the house
## morning, moves if slept through), spouse place (home / work on job days), overnight
## chores (water waters every planted tile), Social/Hero lines, old save migration.
##   godot --headless --path . --fixed-fps 60 -s res://tools/romance_test.gd
var fails := 0


func _initialize() -> void:
	seed(7)
	Campaign.bypass = true
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what, "  @", Time.get_ticks_msec() / 1000)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _advance_all() -> void:
	var d := Dialogue.instance(self)
	for k in 120:
		if not d.active:
			break
		if d._in_choice:
			var btns := d._choices.get_children()
			if not btns.is_empty():
				(btns[0] as Button).pressed.emit()
		else:
			d._advance()
		await process_frame
		await process_frame


func _hold(item: String) -> void:
	GameState.add_item(item, 1, true)
	var tb: Array = GameState.run["toolbar"]
	if not item in tb:
		tb[tb.size() - 1] = item
	GameState.run["slot"] = tb.find(item)


func _talk(m: GameMap, id: String) -> void:
	m.later(func() -> void: await Romance.talk(m, id))
	await frames(2)
	await _advance_all()
	await frames(2)


func _run() -> void:
	InputSetup.ensure_actions()
	for pass_ in [["penguins", "kairi"], ["gangsters", "big_jim"], ["penguins", "mom"]]:
		await _flow(str(pass_[0]), str(pass_[1]))
	_migration()
	_partner_guard()
	print("ROMANCE DONE, failures: %d" % fails)
	quit(1 if fails > 0 else 0)


func _flow(arc: String, body: String) -> void:
	print("-- ", arc, " / ", body)
	GameState.new_run(arc, body, "Robin", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["time"] = 8 * 60
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/house.tscn")
	await frames(12)
	var m := current_scene as GameMap
	await _advance_all()
	var c := Romance.candidates()
	check(c.size() >= 8, "%d candidates in %s" % [c.size(), arc])
	check(not "pip" in c and not "alder" in c, "no kids, no mayor")
	var a := "lumi" if "lumi" in c else str(c[0])
	var b := "theo" if "theo" in c else str(c[1])
	var fr: Dictionary = GameState.run["friendship"]
	# (1) bouquet at ♥7: refused, kept
	fr[a] = 7 * 25
	_hold("bouquet")
	check(not Romance.can_bouquet(a), "bouquet refused at ♥7")
	await _talk(m, a)
	check(GameState.count("bouquet") == 1 and Romance.status(a) == "", "bouquet kept after a no")
	check(not ("bouquet" in Shops.offers("store")), "no bouquet in the store before anyone's ♥8")
	fr[a] = 8 * 25
	check("bouquet" in Shops.offers("store"), "bouquet sold at Maple's once someone's ♥8")
	await _talk(m, a)
	check(Romance.status(a) == "dating" and GameState.count("bouquet") == 0, "♥8 bouquet: dating, item used")
	# (2) one partner at a time
	fr[b] = 9 * 25
	_hold("bouquet")
	check(Romance.bouquet_why(b) == "taken", "second candidate refuses while dating")
	# (3) stay friends -> cooldown
	Romance.stay_friends(a)
	check(Romance.status(a) == "ex" and Romance.bouquet_why(a) == "ex", "stay friends: ex with cooldown")
	check(int(fr[a]) == 8 * 25, "breaking up costs no friendship")
	GameState.run["day"] = int(GameState.run["day"]) + 15
	check(Romance.bouquet_why(a) == "", "cooldown over after 14 days")
	await _talk(m, a)
	check(Romance.status(a) == "dating", "dating again")
	# dates
	GameState.run["time"] = 10 * 60
	check(Dates.can_invite(a), "invite possible in the morning")
	var d := Dates.invite(a)
	check(not Dates.pending().is_empty() and str(d["scene"]) != "", "date tonight at %s" % str(d.get("place", "")))
	check(not Romance.tracker_rows().is_empty(), "date shows in the quest rows")
	Romance.skip_scenes = true
	await Dates.play(m, d)
	check(int(Romance.st()["dates"][a]) == 1 and Dates.pending().is_empty(), "date counted")
	# (4) locket gates
	fr[a] = 10 * 25
	_hold("sea_locket")
	check(Romance.propose_why(a) == "not_yet_dates", "locket refused with 1 date")
	GameState.run["day"] = int(GameState.run["day"]) + 3
	await Dates.play(m, Dates.invite(a))
	check(Romance.propose_why(a) == "not_yet_house", "locket refused in the one-room house")
	check(not Romance.social_line(a).is_empty(), "social line says what's missing")
	if not GameState.run.get("builds") is Dictionary:
		GameState.run["builds"] = {}
	GameState.run["builds"]["house"] = 2
	check(Romance.propose_why(a) == "", "locket accepted: ♥10, 2 dates, Farmhouse")
	check("sea_locket" in Shops.offers("marlowe" if arc == "penguins" else "store"), "locket for sale")
	Romance.skip_scenes = false
	await _talk(m, a)
	check(Romance.status(a) == "engaged" and GameState.count("sea_locket") == 0, "engaged, locket given")
	var wd := int(Romance.st()["wedding_day"])
	check(wd % 7 != 0 and Romance.dos(wd) != GameState.FESTIVAL_DAY, "wedding day %d is no Sunday/festival" % wd)
	for day in range(1, 120):
		var w := Romance.pick_wedding_day(day)
		if w % 7 == 0 or Romance.dos(w) == GameState.FESTIVAL_DAY:
			check(false, "pick_wedding_day(%d) = %d" % [day, w])
			break
	# (5) wedding morning
	Romance.skip_scenes = true
	GameState.run["day"] = wd
	GameState.run["time"] = 13 * 60
	await Wedding.check_morning(m)
	check(Romance.status(a) == "engaged" and int(Romance.st()["wedding_day"]) == wd + 1, "slept past noon: wedding moved to tomorrow")
	GameState.run["day"] = wd + 1
	GameState.run["time"] = 7 * 60
	await Wedding.check_morning(m)
	check(Romance.status(a) == "spouse" and Romance.is_married(), "married")
	check(Romance.hero_line().begins_with("Married to"), "hero tab line")
	# routine: home on a non-job day, work on a job day 9-17
	var jd: Array = Romance.cand(a).get("job_days", [])
	var home_day := int(GameState.run["day"])
	while Romance.is_job_day(home_day):
		home_day += 1
	GameState.run["day"] = home_day
	GameState.run["time"] = 11 * 60
	var rt: Array = GameState.npcs[a].get("routine", [[0, "home"]])
	check(Npc.place_now(rt, a) == "farm_home", "spouse at home on a day off")
	if not jd.is_empty():
		var wday := home_day
		while not Romance.is_job_day(wday):
			wday += 1
		GameState.run["day"] = wday
		check(Npc.place_now(rt, a) == "work", "spouse at work on a job day")
		GameState.run["time"] = 19 * 60
		check(Npc.place_now(rt, a) == "farm_home", "spouse home in the evening")
	# spouse in the house
	GameState.run["day"] = home_day
	GameState.run["time"] = 11 * 60
	(m as Variant).spouse_refresh()
	var sp: Npc = (m as Variant)._spouse
	check(sp != null and sp.visible and sp.id == a, "spouse stands in the house")
	Romance.skip_scenes = false
	var f0 := int(fr[a])
	GameState.run["slot"] = 0
	await _talk(m, a)
	check(int(Romance.st()["talk_day"]) == int(GameState.run["day"]) and int(fr[a]) >= f0, "daily spouse talk")
	# (6) chores over a week; the water chore waters every planted tile
	var got := {}
	var watered_ok := true
	var saw_water := false
	for i in 80:
		if i >= 7 and saw_water and got.size() >= 2:
			break
		seed(1000 + i)  # each night's chore roll is fixed (other systems also draw randf)
		# a crop that lives through tonight (a season change would wither a turnip)
		var crop_now := "turnip"
		for cid: String in GameState.crops:
			var cdd: Dictionary = GameState.crops[cid]
			if not bool(cdd.get("tree", false)) and GameState.crop_fits_season(cdd, GameState.season()) and GameState.crop_fits_season(cdd, GameState.season_of(int(GameState.run["day"]) + 1)):
				crop_now = cid
				break
		GameState.run["farm"]["9,9"] = {"crop": crop_now, "days": 0, "watered": false}
		var rep := GameState.sleep()
		if rep.has("spouse"):
			var ch := str(rep["spouse"]["chore"])
			got[ch] = true
			if Romance.chore_line(rep) == "":
				check(false, "chore line for %s" % ch)
			if ch == "water":
				saw_water = true
				if not bool(GameState.run["farm"]["9,9"].get("watered", false)):
					watered_ok = false
	check(got.size() >= 2, "a week of chores: %s" % str(got.keys()))
	check(watered_ok and saw_water, "water chore waters planted tiles (seen: %s)" % str(saw_water))
	m.queue_free()
	await frames(2)


func _migration() -> void:
	print("-- old save")
	GameState.new_run("penguins", "kairi", "Robin", "Dreamhollow", "Biscuit")
	GameState.run.erase("romance")
	GameState.run["friendship"]["lumi"] = 123
	GameState._migrate()
	check(GameState.run.get("romance") is Dictionary and str(GameState.run["romance"]["spouse"]) == "", "old save gets the default")
	check(int(GameState.run["friendship"]["lumi"]) == 123, "friendship untouched")
	check("romance" in GameState.NO_GIFT_TYPES, "romance items never take the gift path")


## C12 c12_17-15: a gangster shop deal never sends away the player's own partner.
func _partner_guard() -> void:
	var l := {"effects_by_choice": {"0": {"flags": ["shop_3", "juniper_gone"]}, "1": {"flags": ["shop_3_refused"]}}}
	var rs: Dictionary = Romance.st()
	var keep := {"spouse": rs["spouse"], "engaged": rs["engaged"], "dating": rs["dating"]}
	rs["spouse"] = ""; rs["engaged"] = ""; rs["dating"] = "juniper"
	check(Story.partner_guard(l, "0") == "1", "deal on the partner's clinic turns into the refusal")
	check(Story.partner_guard(l, "1") == "", "refusal choice untouched")
	rs["dating"] = "lumi"
	check(Story.partner_guard(l, "0") == "", "deal goes ahead when the clinic isn't the partner's")
	for k in keep:
		rs[k] = keep[k]

extends SceneTree
## Co-op save paths without a relay: a guest's own timers (crafting jobs, tool
## upgrade, haste, buffs) keep their time left through join, a save while
## visiting (save_view) and leaving (_restore_solo). Drives NetSvc directly.
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	_run.call_deferred()


func _join(n: Variant, d: Dictionary) -> void:
	n._host = false
	n.my_id = 2
	for k in n.WORLD_KEYS:
		n._solo_backup[k] = ((GameState.run[k].duplicate(true) if GameState.run[k] is Dictionary or GameState.run[k] is Array else GameState.run[k]) if GameState.run.has(k) else null)
	n._apply_world(d)


func _snap(n: Variant) -> void:
	for k in n.WORLD_KEYS:
		n._solo_backup[k] = ((GameState.run[k].duplicate(true) if GameState.run[k] is Dictionary or GameState.run[k] is Array else GameState.run[k]) if GameState.run.has(k) else null)


func _reset(n: Variant) -> void:
	n.my_id = -1
	n._host = false
	n._last_world = {}
	n._solo_backup = {}
	n._last_room = ""
	n._retries = 0
	n._retry_t = 0.0
	n.tr = null


func _host_world(day: int, builds: Dictionary) -> Dictionary:
	return {"day": day, "time": 600, "farm": {"10,10": {"crop": "turnip", "days": 1}}, "builds": builds, "weather": "sunny", "construction": {}, "permits": {}, "cleared": {}, "placed": {}}


## Reconnect, long visit, both arcs, day stamps and an app kill mid-visit.
func _more(n: Variant) -> void:
	print("A: day stamps follow us home")
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["day"] = 5
	GameState.run["time"] = 600
	n._host = false
	n.my_id = 2
	_snap(n)
	n._apply_world(_host_world(40, {"pool": 3}))
	GameState.run["quests"].append({"id": "board_40_0", "text": "x", "done": false})  # pinned at the host's board
	for k in ["forage_forest_3_4", "well_day", "heal_clinic", "loot_quarry_3_3", "forage_cm_4_4"]:
		GameState.run["flags"][k] = int(GameState.run["day"])
	GameState.run["flags"]["met_x"] = true
	n._restore_solo()
	check(int(GameState.run["day"]) == 5, "home day 5")
	check(int(GameState.run["flags"]["forage_forest_3_4"]) == 5, "forage picked at the host counts as picked today at home")
	check(GameState.respawned("forage_forest_3_4", 1) == false, "...and is back tomorrow, not in 35 days")
	check(int(GameState.run["flags"]["well_day"]) == 5 and int(GameState.run["flags"]["heal_clinic"]) == 5 and int(GameState.run["flags"]["loot_quarry_3_3"]) == 5, "well/heal/loot stamps shifted")
	check(GameState.run["flags"]["met_x"] == true, "boolean flags untouched")
	var bq: Dictionary = (GameState.run["quests"] as Array).filter(func(q: Dictionary) -> bool: return q["id"] == "board_40_0")[0]
	check(int(bq.get("pin_day", -1)) == 5, "board job pinned at the host keeps its age at home (pin_day %d)" % int(bq.get("pin_day", -1)))
	_reset(n)

	print("B: guest morning uses our own builds")
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["day"] = 5
	n._host = false
	n.my_id = 2
	_snap(n)
	n._apply_world(_host_world(40, {"pool": 3, "burrow": 3}))
	n._apply_world(_host_world(41, {"pool": 3, "burrow": 3}))
	var g: Dictionary = GameState.run.get("gifts", {})
	check(g.get("pool", {}).is_empty() and g.get("burrow", {}).is_empty(), "no pool/burrow gifts from the host's builds")
	check((GameState.run.get("builds", {}) as Dictionary).has("pool"), "host's builds still loaded after the morning")
	n._restore_solo()
	_reset(n)

	print("C: reconnect")
	GameState.new_run("gangsters", "kairi", "T", "Town", "Pup")
	GameState.run["day"] = 5
	GameState.run["time"] = 600
	GameState.run["builds"] = {"chest": 1}
	n._host = false
	n.my_id = 2
	n._last_room = "ABCD"
	_snap(n)
	n._apply_world(_host_world(40, {"barn": 2}))
	n.my_id = -1
	n.tr = null
	n._retry_t = 2.0
	check(Net.visiting() and not Net.online(), "visiting during reconnect")
	GameState.save()
	var sv: Dictionary = SaveGame.get_value(GameState.save_key())
	check(int(sv["day"]) == 5 and sv["builds"].has("chest") and not sv["builds"].has("barn"), "save during reconnect writes our own world")
	n._on_msg({"t": "joined", "id": 3, "room": "ABCD", "host": false, "peers": []})
	check(n._solo_backup.get("builds", {}).has("chest"), "backup kept on rejoin")
	GameState.run["sellbox"] = {"turnip": 1}
	n._apply_world(_host_world(40, {"barn": 2}))
	check(int(GameState.run["sellbox"].get("turnip", 0)) == 1, "same-day world after rejoin is not a morning")
	n._apply_world(_host_world(41, {"barn": 2}))
	check(GameState.run["sellbox"].is_empty(), "next host day after rejoin is a morning")
	n.my_id = 3
	n._on_msg({"t": "you_are_host"})
	check(int(GameState.run["day"]) == 5 and not Net.visiting() and (GameState.run["builds"] as Dictionary).has("chest"), "host left for good: we go home, not take over their farm")
	_reset(n)
	GameState.new_run("gangsters", "kairi", "T", "Town", "Pup")
	GameState.run["day"] = 5
	n._host = false
	n.my_id = 2
	n._last_room = "ABCD"
	n.url = ""
	_snap(n)
	n._apply_world(_host_world(40, {}))
	n.my_id = -1
	n.tr = null
	n._retries = 2
	n._retry_t = 0.01
	n._process(0.1)
	check(int(GameState.run["day"]) == 5 and not Net.visiting(), "give up after the last retry: back home")
	_reset(n)

	print("D: long visit")
	GameState.new_run("gangsters", "kairi", "T", "Town", "Pup")
	GameState.run["day"] = 5
	GameState.run["time"] = 600
	n._host = false
	n.my_id = 2
	_snap(n)
	n._apply_world(_host_world(40, {}))
	for d in range(41, 61):
		n._apply_world(_host_world(d, {}))
	GameState.run["buffs"] = {"luck": {"until": GameState.now_abs() + 120, "amount": 1.0}}
	n._restore_solo()
	check(int(GameState.run["day"]) == 5, "home still day 5 after a 20-day visit")
	check(int(GameState.run["buffs"]["luck"]["until"]) - GameState.now_abs() == 120, "buff keeps 120 min after a long visit")
	_reset(n)

	print("E: app kill mid-visit")
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["day"] = 5
	GameState.run["time"] = 600
	GameState.run["builds"] = {"chest": 1}
	n._host = false
	n.my_id = 2
	_snap(n)
	n._apply_world(_host_world(40, {"barn": 2}))
	GameState.run["flags"]["forage_forest_9_9"] = int(GameState.run["day"])
	GameState.run["scene"] = "farm"
	GameState.save()
	_reset(n)
	GameState.run = {}
	SaveGame.reset_cache()
	check(GameState.has_run(), "reload after kill")
	check(int(GameState.run["day"]) == 5 and (GameState.run["builds"] as Dictionary).has("chest") and not (GameState.run["builds"] as Dictionary).has("barn"), "reloaded our own world")
	check(int(GameState.run["flags"].get("forage_forest_9_9", 0)) == 5, "forage picked before the kill is on our own day")


## C9 P6: a guest never takes the host's progress home, and world sync sends deltas.
func _c9(n: Variant) -> void:
	print("C9: guest guards and world deltas")
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["day"] = 5
	GameState.run["time"] = 600
	var mega0: Dictionary = (GameState.run.get("mega", {}) as Dictionary).duplicate(true)
	var rom0: Dictionary = Romance.st().duplicate(true)
	_join(n, _host_world(40, {"launchpad": 4, "kitchen": 3, "house": 3, "shed": 2}))
	check(Builds.built_tier("launchpad") == 4 and NetNode.own_tier("launchpad") == 0, "own_tier reads our builds, not the host's")
	check(Crafting.own_tier("kitchen") == 0, "a guest crafts at its own station tier")
	MegaRegion.check_unlocks()
	var un: Dictionary = (GameState.run.get("mega", {}) as Dictionary).get("unlocked", {})
	var space_ok := true
	for id in un:
		var u: Variant = MegaRegion.get_r(str(id)).get("unlock", {})
		if u is Dictionary and (u as Dictionary).has("built"):
			space_ok = false
	check(space_ok, "host's builds unlock no region for the guest (%s)" % str(un.keys()))
	var wk := "rp_sprout_fizz"  # a weekly prize (gen_rec.py)
	check(not (Tickets.prize(wk).get("need", {}) as Dictionary).has("weekly") or Tickets.lock_text(wk) != "", "weekly prizes wait for the guest's own Rec (%s)" % wk)
	check(not Romance.can_bouquet("x") and not Romance.can_propose("x"), "no bouquet/proposal while visiting")
	check(Commons.guest_blocked(null), "commons are read-only for a guest")
	n._restore_solo()
	check(not Commons.guest_blocked(null), "commons open again at home")
	check(Romance.st() == rom0, "run.romance unchanged after the visit")
	var mega1: Dictionary = GameState.run.get("mega", {})
	check((mega1.get("unlocked", {}) as Dictionary).size() <= (mega0.get("unlocked", {}) as Dictionary).size() + 1, "run.mega gained no build-earned region")
	# World deltas: only what changed travels; a guest merges them.
	var old := {"day": 3, "time": 600, "farm": {"1,1": {"crop": "a"}, "2,2": {"crop": "b"}}, "placed": {"3,3": "x"}}
	var now := {"day": 3, "time": 610, "farm": {"1,1": {"crop": "a"}, "4,4": {"crop": "c"}}}
	var d: Dictionary = NetNode.world_delta(old, now)
	check(d.has("time") and not d.has("day") and not d.has("farm"), "delta carries changed keys only")
	check((d["farm_d"] as Dictionary).size() == 2 and d["farm_d"]["2,2"] == null, "farm delta per tile, removed tiles null")
	check((d["_gone"] as Array) == ["placed"], "removed keys listed")
	var run := old.duplicate(true)
	NetNode.merge_delta(run, d)
	check(run == now, "merge_delta rebuilds the host's world")
	var big := {}
	for i in 3000:
		big["%d,%d" % [i % 60, i / 60]] = {"crop": "turnip", "days": i % 7, "w": true}
	var w0 := {"day": 3, "time": 600, "farm": big}
	var w1 := w0.duplicate(true)
	w1["time"] = 620
	(w1["farm"] as Dictionary)["5,5"] = {"crop": "beet"}
	var full_len := JSON.stringify(w1).length()
	var delta_len := JSON.stringify(NetNode.world_delta(w0, w1)).length()
	check(full_len > 65536 and delta_len < 400, "a late farm's delta is tiny (%d bytes vs full %d)" % [delta_len, full_len])
	# A guest ignores a delta before its first full world, and world/toast from a non-host.
	_reset(n)
	n._host = false
	n.my_id = 2
	_snap(n)
	n._apply_world({"_delta": true, "_gone": [], "day": 99})
	check(int(GameState.run["day"]) != 99, "a delta before the first full world is ignored")
	n._on_msg({"t": "msg", "from": 7, "host": false, "d": {"k": "world", "d": _host_world(77, {})}})
	check(int(GameState.run["day"]) != 77, "a world from a non-host peer is ignored")
	n._on_msg({"t": "msg", "from": 1, "host": true, "d": {"k": "world", "d": _host_world(41, {})}})
	check(int(GameState.run["day"]) == 41, "the host's world applies")
	n._on_msg({"t": "msg", "from": 1, "host": true, "d": {"k": "world", "d": {"_delta": true, "_gone": [], "time": 700, "farm_d": {"10,10": null, "9,9": {"crop": "beet"}}}}})
	check(int(GameState.run["time"]) == 700 and (GameState.run["farm"] as Dictionary).has("9,9") and not (GameState.run["farm"] as Dictionary).has("10,10"), "the host's delta merges")
	n._restore_solo()


## C13 P6: the guest clock waits while the host is paused and never steps back a few
## minutes; ranch names in a delta are filtered; a guest rollover plays the morning cues.
func _c13(n: Variant) -> void:
	print("C13: guest clock, delta names, guest morning")
	Music.instance(self)
	await process_frame
	await process_frame
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	_join(n, {"day": 40, "time": 600, "farm": {}})
	check(not NetNode.guest_hold(), "a guest's clock runs normally")
	n._apply_world({"_delta": true, "_gone": [], "time": 600, "_paused": true})
	check(NetNode.guest_hold(), "host paused: the guest clock waits")
	n._apply_world({"_delta": true, "_gone": [], "time": 600, "_paused": false})
	check(not NetNode.guest_hold(), "host unpaused: it runs again")
	GameState.run["time"] = 606
	n._apply_world({"_delta": true, "_gone": [], "time": 602, "_paused": false})
	check(int(GameState.run["time"]) == 606 and NetNode.guest_hold(), "a guest a few minutes ahead holds instead of rewinding")
	n._apply_world({"_delta": true, "_gone": [], "time": 607, "_paused": false})
	check(int(GameState.run["time"]) == 607 and not NetNode.guest_hold(), "the host catches up: back in step")
	var bad := {"animals": {"a1": {"kind": "cow", "name": "fuck"}}}
	n._apply_world({"_delta": true, "_gone": [], "time": 608, "ranch": bad})
	var nm := str(((GameState.run.get("ranch", {}) as Dictionary).get("animals", {}) as Dictionary).get("a1", {}).get("name", ""))
	check(nm != "fuck", "a host-typed animal name in a delta is filtered (%s)" % nm)
	var mu := Music.instance(self)
	OS.delay_msec(80)
	mu._last_sfx.clear()
	n._apply_world({"_delta": true, "_gone": [], "day": 41, "time": 360})
	check(mu._last_sfx.has("j_morning") or mu._last_sfx.has("snore"), "a guest rollover plays the wake cue")
	n._restore_solo()
	_reset(n)


func _run() -> void:
	var n: Variant = Net.i()
	if n == null:
		print("coop_test: no NetSvc autoload")
		print("coop_test: 1 failures")
		quit(1)
		return
	GameState.new_run("gangsters", "kairi", "T", "Town", "Pup")
	GameState.run["day"] = 5
	GameState.run["time"] = 600
	GameState.run["jobs"] = {"kitchen": [{"id": "x", "name": "X", "give": "berry", "n": 1, "done_at": GameState.now_abs() + 600}], "smith_upgrade": {"kind": "hoe", "done_at": GameState.now_abs() + 2880}}
	GameState.run["flags"]["haste_abs"] = GameState.now_abs() + 60
	check(n.visiting() == false and Net.visiting() == false, "not visiting at home")
	_join(n, {"day": 40, "time": 600, "farm": {}})
	check(Net.visiting(), "Net.visiting() while a guest")
	# C16b P3: battle/campaign guest guards (bypass off so the real checks run).
	var bp0 := Campaign.bypass
	Campaign.bypass = false
	check(CampaignGate.drill_lock().contains("visiting"), "C16b: no training drill while visiting")
	check(Campaign.long_way_lock(Campaign.for_arc()[0]).contains("visiting") or Campaign.region_open(str(Campaign.get_c(Campaign.for_arc()[0])["region"])), "C16b: no long way while visiting")
	check(Campaign.take_long_way(Campaign.for_arc()[0]).is_empty(), "C16b: take_long_way refused while visiting")
	check(not Campaign.loss_choices(Campaign.for_arc()[0]).any(func(x: Array) -> bool: return str(x[0]) in ["retry", "easier"]), "C16b: no retry launch while visiting")
	check(Campaign.settle(Campaign.for_arc()[0], "n0", "rest").contains("visiting"), "C16b: board camps read-only while visiting")
	check(not Campaign.march(Campaign.for_arc()[0], "n0"), "C16b: no march while visiting")
	Campaign.bypass = bp0
	check(Collections.can_donate("coal") != "", "guests can't donate to the host's museum (C8 P3)")
	check(int(GameState.run["day"]) == 40, "on the host's day")
	check(Crafting.job_left("kitchen") == 600, "kitchen job keeps 600 min after join (%d)" % Crafting.job_left("kitchen"))
	check(int(GameState.run["jobs"]["smith_upgrade"]["done_at"]) - GameState.now_abs() == 2880, "smith upgrade keeps 2 days after join")
	check(int(GameState.run["flags"]["haste_abs"]) - GameState.now_abs() == 60, "haste keeps 60 min after join")
	# A buff eaten on the host, then a save while visiting (the phone hides the app).
	GameState.run["buffs"] = {"luck": {"until": GameState.now_abs() + 120, "amount": 1.0}}
	GameState.save()
	var saved: Dictionary = SaveGame.get_value(GameState.save_key())
	var sabs := int(saved["day"]) * 1440 + int(saved["time"])
	check(int(saved["day"]) == 5, "save while visiting writes our own day")
	check(int(saved["buffs"]["luck"]["until"]) - sabs == 120, "saved buff keeps 120 min on our own clock")
	check(int(saved["jobs"]["kitchen"][0]["done_at"]) - sabs == 600, "saved job keeps 600 min on our own clock")
	check(Crafting.job_left("kitchen") == 600, "live run untouched by the save")
	n._restore_solo()
	check(int(GameState.run["day"]) == 5, "back home on day 5")
	check(GameState.run.get("coll") is Dictionary, "run.coll comes home with the guest (not a world key)")
	check(Crafting.job_left("kitchen") == 600, "job keeps 600 min after leaving")
	check(int(GameState.run["buffs"]["luck"]["until"]) - GameState.now_abs() == 120, "buff keeps 120 min after leaving")
	_reset(n)
	# C4: the guest plays at the host's difficulty and day length, then goes home with its own.
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup", {"difficulty": 3, "day_len": 20})
	_join(n, {"day": 9, "time": 600, "farm": {}, "opts": {"difficulty": 0}, "day_len": 40})
	check(Difficulty.level() == 0 and GameState.day_len() == 40, "guest uses the host's difficulty and day length")
	n._restore_solo()
	check(Difficulty.level() == 3 and GameState.day_len() == 20, "home again: our own difficulty and day length")
	_reset(n)
	_more(n)
	_reset(n)
	_c9(n)
	_reset(n)
	await _c13(n)
	n.my_id = -1
	n._host = false
	n._last_world = {}
	n._solo_backup = {}
	print("coop_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

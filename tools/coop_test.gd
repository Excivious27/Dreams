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
	n.ws = null


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
	n.ws = null
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
	n.ws = null
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
	check(Crafting.job_left("kitchen") == 600, "job keeps 600 min after leaving")
	check(int(GameState.run["buffs"]["luck"]["until"]) - GameState.now_abs() == 120, "buff keeps 120 min after leaving")
	_reset(n)
	_more(n)
	n.my_id = -1
	n._host = false
	n._last_world = {}
	n._solo_backup = {}
	print("coop_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

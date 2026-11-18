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
	_run.call_deferred()


func _join(n: Variant, d: Dictionary) -> void:
	n._host = false
	n.my_id = 2
	for k in n.WORLD_KEYS:
		n._solo_backup[k] = ((GameState.run[k].duplicate(true) if GameState.run[k] is Dictionary or GameState.run[k] is Array else GameState.run[k]) if GameState.run.has(k) else null)
	n._apply_world(d)


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
	n.my_id = -1
	n._host = false
	n._last_world = {}
	n._solo_backup = {}
	print("coop_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

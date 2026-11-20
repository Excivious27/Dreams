extends SceneTree
## Day length (CONDUCT 4 P1): 15/20/30/40 real minutes for the 6am-2am day,
## per save slot (run.day_len, default 15). The clock runs at the chosen pace
## on a real map; real-time timers (mana, gift buffs, haste, warden) last the
## same real seconds on every length; old saves get 15; the Settings row is
## locked for a co-op guest. Game time only (never the wall clock).
## Run: godot --headless --path . --fixed-fps 60 -s res://tools/day_length_test.gd
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(5)
	Campaign.bypass = true
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kai", "Town", "Pup")
	check(GameState.day_len() == 15, "default day length 15 min")
	check(absf(GameState.minutes_per_second() - 1200.0 / 900.0) < 0.001, "15 min: 1.33 game min per second")
	for L: int in GameState.DAY_LENGTHS:
		GameState.run["day_len"] = L
		check(absf(1200.0 / GameState.minutes_per_second() / 60.0 - L) < 0.001, "%d-min day: the 6am-2am day lasts %d real minutes" % [L, L])
		# Real-time durations stay put: 21 s of gift buff / 42 s haste / 2.1 s warden.
		for sec: float in [21.0, 42.0, 2.1]:
			var gm := GameState.real_min(sec)
			var real := gm / GameState.minutes_per_second()
			check(real >= sec - 0.01 and real <= sec + 1.0 / GameState.minutes_per_second() + 0.01, "%d-min day: a %.1f s timer lasts %.1f s" % [L, sec, real])
	GameState.run["day_len"] = 17
	check(GameState.day_len() == 15, "an odd value falls back to 15")
	check(is_equal_approx(GameState.mana_regen_secs(), 14.0), "mana: one point every 14 real seconds")
	# On a real map: 6 s of game time per length.
	for L: int in [15, 40]:
		GameState.new_run("penguins", "kairi", "Kai", "Town", "Pup", {"day_len": L})
		GameState.run["intro_done"] = true
		GameState.run["time"] = 9 * 60
		GameState.run["mana"] = 0
		GameMap.next_spawn = Vector2.ZERO
		change_scene_to_file("res://scenes/farm.tscn")
		await frames(4)
		var m := current_scene as GameMap
		var t0 := int(GameState.run["time"])
		var mana0 := int(GameState.run["mana"])
		var gt := 0.0
		while gt < 30.0:
			await process_frame
			gt += root.get_process_delta_time()
		var adv := int(GameState.run["time"]) - t0
		var want := 30.0 * 1200.0 / (L * 60.0)
		check(absf(adv - want) <= 2.0, "%d-min day: 30 s moves the clock %d min (want ~%d)" % [L, adv, roundi(want)])
		var got := int(GameState.run["mana"]) - mana0
		check(got == 2, "%d-min day: 30 s gives 2 mana on any day length (%d)" % [L, got])
		check(m != null, "farm loaded")
	# Migration and per-slot storage.
	GameState.run.erase("day_len")
	GameState._migrate()
	check(GameState.day_len() == 15 and int(GameState.run["day_len"]) == 15, "old save: day length 15")
	check(Difficulty.next_day_len(15) == 20 and Difficulty.next_day_len(40) == 15, "the Settings button cycles 15 -> 20 -> 30 -> 40 -> 15")
	print("day_length_test: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)

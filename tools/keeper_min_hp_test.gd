extends SceneTree
## Keeper encounters always carry real hp: a floor-1 bat swarm (1-hp kin) is
## topped up to Mine.KEEPER_MIN_HP in total. Forces each pack encounter on floor 1.

var fails := 0


func _initialize() -> void:
	Campaign.bypass = true
	seed(77)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _run() -> void:
	InputSetup.ensure_actions()
	var mine_s: Variant = load("res://scripts/mine.gd")
	for id in ["bat_swarm", "grump_gang", "slime_court"]:
		GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
		GameState.run["intro_done"] = true
		GameState.run["flags"]["mine_seen"] = true
		GameMap.next_spawn = Vector2.ZERO
		mine_s.force_seed = 4242
		mine_s.force_encounter = id
		change_scene_to_file("res://scenes/mine.tscn")
		for i in 15:
			await process_frame
		var m := current_scene as GameMap
		await m.call("_summon_guardian")
		var tot := 0
		for k: Enemy in m.call("keepers_left"):
			tot += k.max_hp
		check(tot >= int(mine_s.KEEPER_MIN_HP), "%s on floor 1 has real hp (total %d, %d units)" % [id, tot, m.call("keepers_left").size()])
	mine_s.force_encounter = ""
	mine_s.force_seed = 0
	print("keeper_min_hp_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

extends SceneTree
## Difficulty modes (CONDUCT 4 P1): Very easy / Easy / Default / Hard change
## combat and battle campaigns only, per save slot. Checks the table, foe HP
## (separate from hp_scale, so ally hits are untouched), foe damage (VE floor
## 3), ally damage, status, wind-up, battle numbers, mine keeper packs, clinic
## fee for combat faints only, legacy Easy migration and the host's mode for
## co-op guests.
## Run: godot --headless --path . --fixed-fps 60 -s res://tools/difficulty_test.gd
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(4)
	Campaign.bypass = true
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _fresh(diff: int) -> void:
	GameState.new_run("penguins", "kairi", "Kai", "Town", "Pup", {"difficulty": diff})
	GameState.run["intro_done"] = true
	GameState.run["flags"]["meadow_seen"] = true


func _run() -> void:
	InputSetup.ensure_actions()
	# Table shape and the default row.
	for k: String in Difficulty.TABLE:
		check((Difficulty.TABLE[k] as Array).size() == 4, "table row %s has four modes" % k)
		var dv := float(Difficulty.TABLE[k][2])
		check(dv == (0.0 if k in ["enemy_cap", "convoy", "hold", "keeper_n"] else (20.0 if k == "morale_loss" else 1.0)), "Default leaves %s as it was" % k)
	GameState.new_run("penguins", "kairi", "Kai", "Town", "Pup")
	check(Difficulty.level() == 2 and GameState.day_len() == 15, "a new game is Default with 15-minute days")
	check(not Settings.DEFAULTS.has("easy"), "the global Easy switch is gone")
	# Foe HP / damage / status / wind-up per mode, on a real map.
	var hp := []
	var scale := []
	for dn in 4:
		_fresh(dn)
		GameMap.next_spawn = Vector2.ZERO
		change_scene_to_file("res://scenes/meadow.tscn")
		await frames(10)
		var m := current_scene as GameMap
		var e := m.spawn_enemy("slime", m.player.position + Vector2(60, 0), 2)
		hp.append(e.max_hp)
		scale.append(e.hp_scale)
		check(is_equal_approx(e.diff_hp, Difficulty.mul("foe_hp")), "%s: foe diff_hp %.2f" % [Difficulty.name_of(), e.diff_hp])
		check(Enemy.ally_damage(10) == maxi(1, roundi(10 * float(Difficulty.TABLE["ally_dmg"][dn]))), "%s: foe hit on an ally %d" % [Difficulty.name_of(), Enemy.ally_damage(10)])
		GameState.status_clear()
		GameState.status_apply("poison", 1)
		var secs := float(GameState.run["status"]["poison"]["secs"])
		var base_secs := float(GameState.tier(1).get("status_secs", 3.0))
		check(is_equal_approx(secs, base_secs * float(Difficulty.TABLE["status"][dn])), "%s: poison lasts %.2f s" % [Difficulty.name_of(), secs])
		GameState.status_clear()
		e.position = m.player.position + Vector2(8, 0)
		e._cooldown = 0.0
		e._windup = 0.0
		var w := 0.0
		for i in 30:
			await process_frame
			if e._windup > 0.0:
				w = e._windup
				break
		if w > 0.0:
			var expect := (0.32 + 0.04 * clampi(e.damage - 2, 0, 10)) * Difficulty.mul("windup")
			check(absf(w - expect) < 0.05, "%s: wind-up %.2f s (want ~%.2f)" % [Difficulty.name_of(), w, expect])
		e.queue_free()
		m.enemies.erase(e)
		# Clinic fee: combat faints only.
		GameState.run["day"] = 20
		GameState.run["crystals"] = 1000
		GameState.run["flags"]["clinic_used"] = 1
		var hurt := Faint.fee(true, 0, "hurt")
		var tired := Faint.fee(true, 0, "tired")
		check(hurt == roundi(minf(750.0, 80.0 + 20.0) * float(Difficulty.TABLE["clinic_fee"][dn])), "%s: clinic fee after a fight %d" % [Difficulty.name_of(), hurt])
		check(tired == 100 and Faint.fee(false, 0, "late") == 50, "%s: tired/late faints cost the same in every mode (%d)" % [Difficulty.name_of(), tired])
	check(scale[0] == scale[2] and scale[3] == scale[2], "hp_scale (ally hit scaling) is the same in every mode")
	check(int(hp[0]) < int(hp[1]) and int(hp[1]) < int(hp[2]) and int(hp[2]) < int(hp[3]), "foe health climbs VE < E < D < H (%s)" % str(hp))
	check(absf(float(hp[0]) / float(hp[2]) - 0.5) < 0.1, "Very easy foes have about half the health (%d vs %d)" % [int(hp[0]), int(hp[2])])
	# Foe damage to you (GameState.enemy_damage), Very easy floor 3.
	var dm := []
	for dn in 4:
		Difficulty.set_level(dn)
		dm.append(GameState.enemy_damage(3))
	check(dm[2] == 36 and dm[0] == roundi(36 * 0.45) and dm[1] == roundi(36 * 0.7) and dm[3] == roundi(36 * 1.3), "foe damage per mode %s" % str(dm))
	Difficulty.set_level(0)
	check(GameState.enemy_damage(0) == 3, "Very easy: the smallest hit is 3 (%d)" % GameState.enemy_damage(0))
	Difficulty.set_level(2)
	check(GameState.enemy_damage(0) == 5, "Default: the smallest hit stays 5")
	# Battle boss HP: the mode once, inside Battle.boss_hp.
	check(Battle.boss_hp(40, 1, 0) == Battle.boss_hp(40, 1, 0, 1.0), "boss_hp default multiplier 1")
	check(Battle.boss_hp(200, 3, 3, 0.55) == maxi(20, int(Battle.boss_hp(200, 3, 3) * 0.55)) or absf(Battle.boss_hp(200, 3, 3, 0.55) - Battle.boss_hp(200, 3, 3) * 0.55) <= 1.0, "boss_hp scales by the mode")
	# Campaign battle numbers.
	var cid := ""
	var nid := ""
	for c: String in Campaign.all():
		var cd: Dictionary = Campaign.all()[c]
		if str(cd.get("arc", "both")) in ["both", "penguins"]:
			cid = c
			break
	if cid != "":
		Campaign.st()["fight"] = {}
		nid = str(Campaign.cs(cid).get("at", "n0"))
		var nums := []
		for dn in 4:
			Difficulty.set_level(dn)
			var d := Campaign.battle_data({}, {"cid": cid, "nid": nid})
			nums.append(d)
		check(int(nums[0]["enemy_cap"]) == maxi(3, int(nums[2]["enemy_cap"]) - 5) and int(nums[3]["enemy_cap"]) == int(nums[2]["enemy_cap"]) + 3, "enemy cap -5/+3 (%d/%d/%d)" % [int(nums[0]["enemy_cap"]), int(nums[2]["enemy_cap"]), int(nums[3]["enemy_cap"])])
		check(int(nums[0]["tickets"]) > int(nums[2]["tickets"]) and int(nums[3]["tickets"]) < int(nums[2]["tickets"]), "your tickets: more on Very easy, fewer on Hard")
		check(float(nums[0]["wave_every"]) > float(nums[2]["wave_every"]) and float(nums[3]["wave_every"]) < float(nums[2]["wave_every"]), "waves come slower on Very easy, faster on Hard")
		check(float(nums[0]["foe_capture"]) == 0.6 and float(nums[2]["foe_capture"]) == 1.0 and float(nums[0]["supply_mul"]) == 1.3, "capture/supply multipliers ride in the battle data")
		Difficulty.set_level(2)
	else:
		check(false, "a penguin campaign to test with")
	# Morale lost on a lost battle per mode.
	check(Difficulty.add("morale_loss", 0) == 10 and Difficulty.add("morale_loss", 3) == 25, "morale loss 10..25")
	# Mine keepers: pack size moves with the mode, never below 1.
	var tot := [0, 0, 0, 0]
	for dn in 4:
		Difficulty.set_level(dn)
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in 40:
			var enc := MineKeepers.pick(20, 2, 0, rng, [])
			tot[dn] += (enc.get("units", []) as Array).size()
			if (enc.get("units", []) as Array).is_empty():
				check(false, "keeper encounter with no units")
	check(tot[0] < tot[2] and tot[3] > tot[2], "mine keeper packs: smaller on Very easy, bigger on Hard %s" % str(tot))
	Difficulty.set_level(2)
	# C16a P1: roaming foes per map move with the mode (combat only); Default unchanged.
	for q: String in ["clear_meadow", "spark", "sky_stair", "teleporter"]:
		GameState.add_quest(q, q)
		for qq in GameState.run["quests"]:
			if str(qq["id"]) == q:
				qq["done"] = true
	var ec := []
	for dn in 4:
		Difficulty.set_level(dn)
		ec.append(GameState.enemy_count(4))
	Difficulty.set_level(2)
	check(ec == [4, 5, 6, 7], "enemy_count(4) at tier 4 is 4/5/6/7 by mode %s" % str(ec))
	check(GameState.enemy_count(1) >= 1 and GameState.enemy_count(0) == 0, "a map with foes keeps at least one; none stays none")
	check(Difficulty.add("keeper_n", 0) == -1, "Very easy keeper packs -1 (C16a P1, was -2)")
	for dl in GameState.DAY_LENGTHS:
		check(Difficulty.day_words(int(dl)).contains("hours a year"), "day length %d has its words" % int(dl))
	# Campaign card words.
	check(Difficulty.DANGER_WORDS == ["light", "fair", "tough", "fierce"], "campaign danger words light/fair/tough/fierce")
	# Legacy migration: the old global Easy switch -> Easy for a slot without opts.
	GameState.new_run("penguins", "kairi", "Kai", "Town", "Pup")
	GameState.run.erase("opts")
	GameState.run.erase("day_len")
	SaveGame.set_value("set_easy", true)
	GameState._migrate()
	check(Difficulty.level() == 1 and GameState.day_len() == 15, "old slot with the global Easy switch on -> Easy, 15-min days")
	GameState.run.erase("opts")
	SaveGame.set_value("set_easy", false)
	GameState._migrate()
	check(Difficulty.level() == 2, "old slot without it -> Default")
	# Co-op: a guest plays at the host's mode and goes home with their own.
	check("opts" in NetNode.WORLD_KEYS and "day_len" in NetNode.WORLD_KEYS, "difficulty and day length are world keys (host -> guest)")
	var n: Variant = Net.i()
	if n:
		Difficulty.set_level(3)
		GameState.run["day_len"] = 20
		n._host = false
		n.my_id = 2
		for k in n.WORLD_KEYS:
			n._solo_backup[k] = ((GameState.run[k].duplicate(true) if GameState.run[k] is Dictionary or GameState.run[k] is Array else GameState.run[k]) if GameState.run.has(k) else null)
		n._apply_world({"day": GameState.run["day"], "time": 600, "opts": {"difficulty": 0}, "day_len": 40})
		check(Difficulty.level() == 0 and GameState.day_len() == 40, "guest follows the host: Very easy, 40-min days")
		var v: Dictionary = n.save_view(GameState.run)
		check(int(v["opts"]["difficulty"]) == 3 and int(v["day_len"]) == 20, "a save while visiting keeps the guest's own mode and day length")
		n._host = false
		n.my_id = -1
		n._solo_backup = {}
		n._last_world = {}
	# Money routing (c4_20 #5): earnings go through GameState.add_money (earned_by).
	var rx := RegEx.create_from_string("run\\[\"crystals\"\\] = int\\(GameState\\.run(\\[\"crystals\"\\]|\\.get\\(\"crystals\", 0\\))\\) \\+")
	for f: String in ["campaign", "campaign_gate", "battle", "game_map", "mine", "mail", "ops", "town", "community_farm", "craft_screen", "farm", "region"]:
		var txt := FileAccess.get_file_as_string("res://scripts/%s.gd" % f)
		check(rx.search(txt) == null, "%s.gd adds money only through GameState.add_money" % f)
	# Mega ores have a pickaxe tier and Mining level.
	for ore: String in ["tin", "sunstone", "sapphire", "frost", "star_dust", "storm_glass", "platinum"]:
		check(GameState.ORE_TIER.has(ore) and GameState.ORE_SKILL.has(ore), "mega ore %s has ORE_TIER/ORE_SKILL" % ore)
	print("difficulty_test: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)

extends SceneTree
## C7 P5: colony stories (elder steps, kits' side quests, foe counting, tracker,
## reveal/lore, done flag) and the crew/Marked/lieutenant side (waiting lines,
## Marlene after the sale, flag lines, the joined at the hideout, refusals).
##   godot --headless --path . --fixed-fps 60 -s res://tools/c7_colony_crew_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	Campaign.bypass = true
	seed(7)
	_run.call_deferred()


func _drain(n := 400) -> void:
	var d := Dialogue.instance(self)
	for i in n:
		if d.active:
			if d._in_choice:
				d._choose("", 0)
			else:
				Input.action_press("a"); await process_frame; Input.action_release("a")
		elif i > 20:
			return
		await process_frame


func _go(scene: String, at: Vector2) -> GameMap:
	GameMap.next_spawn = at
	change_scene_to_file("res://scenes/%s.tscn" % scene)
	for i in 12:
		await process_frame
	await _drain(200)
	return current_scene as GameMap


func _thing(m: GameMap, typ: String, key := "") -> Dictionary:
	for c: Vector2i in m.things:
		var t: Dictionary = m.things[c]
		if str(t.get("type", "")) == typ and (key == "" or str(t.get("key", "")) == key):
			return t
	return {}


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "penguin_f", "T", "Town", "Pup")
	var en: Dictionary = GameState.load_json("res://data/enemies.json")["enemies"]
	print("stage 1: data")
	# ---- data -------------------------------------------------------------
	var cd := Colony.data()
	var verses := 0
	for id: String in cd:
		var c: Dictionary = cd[id]
		check((c.get("kits", []) as Array).size() == 3, id + " has three kits")
		check((c.get("beacon_lines", []) as Array).size() == int(c["beacons"]), id + " has a verse per beacon")
		check((c.get("reveal", []) as Array).size() >= 2 and (c.get("lore", []) as Array).size() >= 3, id + " has a reveal and lore")
		for k: String in c.get("foe_kinds", []):
			check(en.has(k), id + " foe kind exists: " + k)
		var kq := 0
		for k: Dictionary in c["kits"]:
			if k.has("quest"):
				kq += 1
				for it: String in k["quest"]["need"]:
					check(it.begins_with("#") or GameState.items.has(it), id + " side need item " + it)
				for it: String in k["quest"].get("reward", {}):
					check(it == "crystals" or GameState.items.has(it), id + " reward item " + it)
		check(kq == 2, id + " has two side quests")
		verses += (c["beacon_lines"] as Array).size()
		var R: Dictionary = RegionData.region(id)
		check(str(R["intro"][0]) != str(c["intro"][1]) and str(R["intro"][0]).length() > 20, id + " arrival is its own narration")
	check(verses == 14, "fourteen verses in all (%d)" % verses)
	check(Companion.REVERT["grump"][0] == "@crystal" and Companion.REVERT["big_grump"][0] == "@crystal", "Grumps float home as crystals")
	check(Companion.REVERT["crystal_baby"][0] == "@calm" and Companion.REVERT["finargle"][0] == "@vanish", "babies calm, finargles vanish")

	print("stage 2: a colony played through")
	# ---- a colony played through ------------------------------------------
	GameState.new_run("penguins", "penguin_f", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	var m := await _go("colony_coral", Vector2(40 * 16, 50 * 16))
	check(m != null and m.scene_id() == "colony_coral", "Coral Reach loads")
	m.player.invuln = 9999.0
	var id := "colony_coral"
	check(not _thing(m, "colony_kit", "k0").is_empty() and not _thing(m, "colony_kit", "k2").is_empty(), "the kits are talkable things")
	print("stage 3: A kit before the elder: points you at her.")
	# A kit before the elder: points you at her.
	Colony.interact(m, id, _thing(m, "colony_kit", "k0"))
	await _drain()
	check(not (Colony.st(id).get("sides", {}) as Dictionary).has("shells"), "kit waits until the elder is met")
	Colony.interact(m, id, _thing(m, "elder"))
	await _drain()
	check(bool(Colony.st(id)["met"]) and GameState.has_quest("colony_" + id), "elder met, quest added")
	check(Colony.progress("colony_" + id) == "Bring the supplies.", "progress: supplies (%s)" % Colony.progress("colony_" + id))
	var row_ok := false
	for oq: Dictionary in QuestTracker.open_quests():
		if str(oq["id"]) == "colony_" + id and str(oq["giver"]) != "" and not bool(oq["main"]):
			row_ok = true
	check(row_ok, "colony quest is a tickable row")
	QuestTracker.track("colony_" + id)
	check(QuestTracker.target(m) != Vector2.ZERO, "tracker points somewhere on the island")
	GameState.add_item("sunfish", 6)
	Colony.interact(m, id, _thing(m, "elder"))
	await _drain()
	check(bool(Colony.st(id)["gave"]), "supplies given")
	check(Colony.progress("colony_" + id).begins_with("Foes 0/"), "progress: foes and beacons (%s)" % Colony.progress("colony_" + id))
	var tp := QuestTracker.target(m)
	check(tp != Vector2.ZERO, "tracker points at a beacon")
	print("stage 4: Side quest from Shelly.")
	# Side quest from Shelly.
	Colony.interact(m, id, _thing(m, "colony_kit", "k0"))
	await _drain()
	check(str(Colony.st(id)["sides"].get("shells", "")) == "open", "Shelly's side quest opens")
	var sq := "colony_side_%s:k0" % id
	check(GameState.has_quest(sq), "side quest in the journal")
	check(Colony.progress(sq) == "0/5", "side progress 0/5 (%s)" % Colony.progress(sq))
	GameState.add_item("seashell", 5)
	var pearls := GameState.count("pearl")
	Colony.interact(m, id, _thing(m, "colony_kit", "k0"))
	await _drain()
	check(str(Colony.st(id)["sides"].get("shells", "")) == "done" and GameState.quest_done(sq), "side quest done")
	check(GameState.count("pearl") == pearls + 1 and GameState.count("seashell") == 0, "shells taken, pearl given")
	print("stage 5: Chatter kit.")
	# Chatter kit.
	Colony.interact(m, id, _thing(m, "colony_kit", "k2"))
	await _drain()
	print("stage 6: Only the named foes count.")
	# Only the named foes count.
	var k0 := int(Colony.st(id)["kills"])
	var bat := m.spawn_enemy("bat", m.player.position + Vector2(60, 0))
	if bat:
		await Colony.on_kill(m, bat)
	check(int(Colony.st(id)["kills"]) == k0, "a bat doesn't count")
	var g := m.spawn_enemy("grump_coral", m.player.position + Vector2(60, 0))
	if g:
		await Colony.on_kill(m, g)
	check(int(Colony.st(id)["kills"]) == k0 + 1, "a Coral Grump counts")
	print("stage 7: Beacons, with a verse each.")
	# Beacons, with a verse each.
	GameState.add_item("crystal_refined", 5)
	for c: Vector2i in m.things.keys():
		if str(m.things[c].get("type", "")) == "beacon":
			Colony.interact(m, id, m.things[c])
			await _drain()
	check((Colony.st(id)["beacons"] as Dictionary).size() == 3, "three beacons lit")
	Colony.st(id)["kills"] = 99
	check(Colony.progress("colony_" + id) == "Wake the star crystal.", "progress: wake")
	print("stage 8: Restore: reveal + done flag + Star Crystal count l")
	# Restore: reveal + done flag + Star Crystal count line.
	var mm := m
	mm.later(func() -> void: await Colony._restore(mm, id))
	await _drain()
	for i in 20:
		await process_frame
	await _drain()
	check(GameState.run["flags"].has("colony_coral_done") and GameState.run["flags"].has("colony_coral_ward"), "done + ability flags")
	m = current_scene as GameMap
	Colony.interact(m, id, _thing(m, "elder"))
	await _drain()
	check(GameState.run["flags"].has(id + "_lore"), "lore talk after the save")
	print("stage 9: Old save: done without the new flag gets it.")
	# Old save: done without the new flag gets it.
	GameState.run["flags"].erase("colony_coral_done")
	Colony.st(id)
	check(GameState.run["flags"].has("colony_coral_done"), "migration sets the done flag")

	print("stage 10: gangster crew")
	# ---- gangster crew ----------------------------------------------------
	GameState.new_run("gangsters", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	GameState.run["flags"]["docks_seen"] = true
	m = await _go("docks", Vector2(20 * 16, 20 * 16))
	check(m != null, "docks load")
	Crew.data()
	m.later(func() -> void: await Crew.talk(m, "ladder"))
	await _drain()
	check(GameState.run["flags"].has("crew_hint_ladder"), "Ladder's hint once")
	GameState.run["flags"]["letter_sold"] = true
	m.later(func() -> void: await Crew.talk(m, "marlene"))
	await _drain()
	check(GameState.run["flags"].has("marlene_refused"), "Marlene walks after the sale")
	GameState.run["flags"]["deuce_thumb"] = true
	check(not Crew.flag_lines("deuce").is_empty(), "Deuce remembers the thumb")
	GameState.run["flags"]["crew_vic"] = true
	check(Crew.roster_text("vic").contains("melee") or Crew.roster_text("vic").contains("no perk"), "Vic's roster text")
	check(str(Crew.members()["vic"]["perks"][0]).contains("melee"), "Vic's perk says melee")
	print("stage 11: The joined at the hideout.")
	# The joined at the hideout.
	GameState.run["flags"]["marked_kit"] = "crew"
	GameState.run["flags"]["lt_joined_brock"] = true
	GameState.run["flags"]["hideout_seen"] = true
	check(Crew.also_with_you().size() == 2, "roster lists Kit and Brock (%d)" % Crew.also_with_you().size())
	m = await _go("hideout", Vector2(20 * 16, 20 * 16))
	var seen := {}
	for ch in m.get_children():
		if ch is Npc:
			seen[(ch as Npc).id] = true
	check(seen.has("mk_kit") and seen.has("lt_brock"), "Kit and Brock stand in the hideout (%s)" % str(seen.keys()))
	var said := [false]
	m.later(func() -> void: said[0] = await Crew.talk(m, "mk_kit"))
	await _drain()
	check(said[0], "Kit talks at the hideout")
	check(seen.has("partner_big_jim"), "Big Jim waits at the hideout for a second ask")
	m.later(func() -> void: await Crew.talk(m, "partner_big_jim"))
	await _drain()
	check("big_jim" in Companion.party()["known"], "asked again, Big Jim joins")
	var lts: Dictionary = Gift.data()["lieutenants"]
	var refuse := 0
	for lid: String in lts:
		if (lts[lid] as Dictionary).has("refuse"):
			refuse += 1
	check(refuse == 6, "six lieutenants have their own refusal (%d)" % refuse)
	for mid: String in Marked.all():
		check(str(Marked.all()[mid].get("join_line", "")) != "" and str(Marked.all()[mid].get("home_line", "")) != "", mid + " join/home lines")
	print("c7_colony_crew_test: %s (%d fails)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)

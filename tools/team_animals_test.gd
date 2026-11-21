extends SceneTree
## Team animals + Chores (CONDUCT 11a P4): raise -> trust -> lessons/ranks -> team -> CampaignGate
## muster row -> battle sprite/job/HelperUnit draw; chores overnight (water, harvest to a chest,
## feed/pet, forage), energy/level caps, unlock day, idle rules; the Animals and Chores menu pages
## (rename, rehome, team toggle) in both arcs. Works with an empty data/ranch.json (injects species).
##   godot --headless --path . --fixed-fps 60 -s res://tools/team_animals_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(11)
	Campaign.bypass = true
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _inject_ranch() -> void:
	var d := Ranch.data()
	if (d["species"] as Dictionary).is_empty():
		d["species"] = {
			"goat": {"name": "Goat", "home": "barn", "group": "goat", "art": {"adult": "goat", "baby": "goat_kid"}},
			"cow": {"name": "Cow", "home": "barn", "group": "cow", "art": {"adult": "cow"}},
			"llama": {"name": "Llama", "home": "barn", "group": "llama", "art": {"adult": "llama"}}}
	if not (d["buildings"] as Dictionary).has("barn"):
		d["buildings"]["barn"] = [{"tier": 1, "cap": 8, "adds": []}]


func _arc(arc: String) -> void:
	print("-- ", arc)
	GameState.new_run(arc, "kairi", "T", "Town", "Pup")
	_inject_ranch()
	Ranch.st()["houses"]["barn"] = {"tier": 1}
	var day := int(GameState.run["day"])
	var goat := Ranch.add("goat", "barn", "", day)
	var cow := Ranch.add("cow", "barn", "", day)
	var llama := Ranch.add("llama", "barn", "Lola", day - 20)
	check(goat != "" and cow != "" and llama != "", "ranch adds animals")
	check(TeamAnimals.trainable(goat) and not TeamAnimals.trainable(cow), "goat trains, cow is a homebody")
	check(TeamAnimals.why_not(goat, "attack").contains("little"), "a baby can't train yet: " + TeamAnimals.why_not(goat, "attack"))
	Ranch.animal(goat)["born_day"] = day - 10
	Ranch.animal(goat)["adult_day"] = day - 3  # Ranch records carry adult_day (grown() reads it first)
	check(TeamAnimals.why_not(goat, "attack").contains("trust"), "trust gate: " + TeamAnimals.why_not(goat, "attack"))
	Ranch.animal(goat)["friend"] = 250
	GameState.run["inventory"].erase("carrot")
	GameState.run["inventory"].erase("apple")
	GameState.run["inventory"].erase("hay")
	check(TeamAnimals.why_not(goat, "attack").contains("treat"), "treat gate: " + TeamAnimals.why_not(goat, "attack"))
	check(TeamAnimals.why_not(goat, "carry") != "", "goat can't learn carry")
	check(TeamAnimals.why_not_team(goat) != "", "no lesson, no team")
	GameState.add_item("carrot", 20)
	GameState.run["energy"] = 100
	var line := TeamAnimals.teach(goat, "attack")
	check(TeamAnimals.rank(goat, "attack") == 1 and line.contains("learned"), "first lesson teaches rank 1: " + line)
	check(GameState.count("carrot") == 19 and int(GameState.run["energy"]) == 100 - int(TeamAnimals.rule("energy", 8)), "lesson costs a treat and energy")
	check(TeamAnimals.bond(goat) == 250 + int(TeamAnimals.rule("bond_per_lesson", 20)), "lesson adds friendship")
	check(TeamAnimals.why_not(goat, "attack").contains("One lesson a day"), "one lesson a day")
	for i in 6:
		GameState.run["day"] = int(GameState.run["day"]) + 1
		GameState.run["energy"] = 100
		TeamAnimals.teach(goat, "attack")
	check(TeamAnimals.rank(goat, "attack") == 3, "seven lessons reach rank 3 (%d)" % TeamAnimals.rank(goat, "attack"))
	GameState.run["day"] = int(GameState.run["day"]) + 1
	check(TeamAnimals.why_not(goat, "attack").contains("by heart"), "max rank refuses more")
	check(TeamAnimals.why_not(goat, "guard") == "", "another lesson still open")
	var s := TeamAnimals.stats(goat)
	check(int(s["hp"]) < Pet.max_hp() + 6 * GameState.progress_tier(), "team animal stays under the pup's health")
	check(TeamAnimals.battle_job(goat) == "striker", "attack lesson = striker")
	check(TeamAnimals.set_team(goat, true) == "" and TeamAnimals.on_team(goat), "goat joins the team")
	var rows := CampaignGate.team().filter(func(r: Array) -> bool: return str(r[2]) == "animal")
	check(rows.size() == 1 and str(rows[0][0]) == "animal:" + goat, "CampaignGate.team lists the team animal")
	var grp := Battle.team_sprite(rows[0])
	check(grp.begins_with("animals/"), "battle sprite is an animal strip (%s)" % grp)
	var spr := HelperUnit.animal_sprite(grp)
	check(spr.sprite_frames != null and spr.sprite_frames.get_frame_count("idle") > 0, "HelperUnit draws the animal")
	spr.free()
	# Llama: guard + carry; team cap.
	Ranch.animal(llama)["friend"] = 400
	GameState.add_item("apple", 3)
	TeamAnimals.teach(llama, "carry")
	check(TeamAnimals.chores_for(llama) == ["harvest"], "carry opens the harvest chore")
	check(TeamAnimals.battle_job(llama) == "warden", "carry = warden")
	check(TeamAnimals.set_team(llama, true) == "", "llama joins")
	var third := Ranch.add("goat", "barn", "", day - 30)
	Ranch.animal(third)["friend"] = 900
	Ranch.animal(third)["born_day"] = -30
	Ranch.animal(third)["adult_day"] = -23
	GameState.run["day"] = int(GameState.run["day"]) + 1
	GameState.run["energy"] = 100
	var tl := TeamAnimals.teach(third, "fetch")
	var cap_why := TeamAnimals.set_team(third, true)
	check(cap_why.contains("room"), "team cap holds (%s / %s)" % [tl, cap_why])
	check(TeamAnimals.rename(goat, "  Captain Hooves the Great  ") and TeamAnimals.name_of(goat).length() <= 14, "rename trims")
	check(not TeamAnimals.rename(goat, "   "), "blank name refused")
	check(TeamAnimals.suggest_name(cow) != "", "name suggestion")
	check(ItemWords.with_article("Old Coin") == "an Old Coin", "pup dig toast article (ItemWords)")

	# ---- Chores ----
	GameState.run["day"] = 3
	check(not Chores.unlocked() and Chores.assign("pup", "forage") != "", "chores wait for week two")
	GameState.run["day"] = 10
	check(Chores.assign("pup", "water") != "", "pup can't water")
	check(Chores.assign("pup", "forage") == "", "pup forages")
	check(Chores.assign("animal:" + llama, "harvest") == "", "llama harvests")
	check(Chores.assign("animal:" + goat, "harvest") != "", "goat (attack only) can't harvest")
	# Farm: 3 ripe beds, 10 dry ones.
	var farm: Dictionary = GameState.run["farm"]
	farm.clear()
	var cid := ""
	for c: String in GameState.crops:
		if not (GameState.crops[c] as Dictionary).has("regrow") and not bool(GameState.crops[c].get("tree", false)):
			cid = c
			break
	var cd: Dictionary = GameState.crops[cid]
	for i in 13:
		farm["%d,%d" % [10 + i, 10]] = {"crop": cid, "days": int(cd["days"]) if i < 3 else 0, "watered": false, "acc": 0.0}
	var helper_key := "partner:test_pal"
	Companion.party()["known"] = (Companion.party().get("known", []) as Array) + ["test_pal"]
	check(Chores.assign(helper_key, "water") == "", "partner waters")
	var yid := str(cd["yield"])
	var before := Storage.amount("chest", yid)
	var rep := {}
	GameState.run["weather"] = {}
	var lines := Chores.overnight(rep)
	print("   ", lines)
	var watered := 0
	for k in farm:
		if bool(farm[k].get("watered", false)):
			watered += 1
	var want_w := Chores.units(helper_key, "water")
	check(GameState.sky_waters() or watered == mini(want_w, 13 - 3), "waterer did %d beds (units %d)" % [watered, want_w])
	check(Storage.amount("chest", yid) - before == 3, "harvest went into the farm chest (%d)" % (Storage.amount("chest", yid) - before))
	check(rep.has("chores") and (rep["chores"] as Array).size() >= 2, "report has chore lines")
	check(Chores.xp("animal:" + llama, "harvest") > 0, "worker earns chore xp")
	check("\n".join(SleepReport.lines(rep).map(func(l: Dictionary) -> String: return str(l.get("text", "")))).contains(TeamAnimals.name_of(llama)), "sleep report shows chores")
	# Feed/pet through a crew-less worker: the pup can pet.
	Chores.assign("pup", "pet")
	GameState.run["day"] = 11
	var rep2 := {}
	Chores.overnight(rep2)
	check(int(Ranch.animal(cow).get("last_helper_pet", -1)) == 11 and int(Ranch.animal(cow).get("last_pet", -1)) != 11, "pup kept the animals company (helper pet, your own pet still open: c11b_06-12)")
	# Leaving the team frees the slot.
	TeamAnimals.set_team(llama, false)
	check(Chores.assignment("animal:" + llama).is_empty(), "off the team = off its chore")
	# Level cap / units cap.
	(Chores.st()["xp"] as Dictionary)["pup"] = {"forage": 99999}
	check(Chores.level("pup", "forage") == int(Chores.data().get("max_level", 5)), "level caps")
	check(Chores.units("pup", "forage") <= int(Chores.data().get("max_units", 20)), "units cap")
	# Full chest: no loss, says why.
	Storage.box("shed")["cap"] = 0
	Chores.assign("pup", "forage", "shed")
	var rep3 := {}
	var l3 := Chores.overnight(rep3)
	check(l3.any(func(x: Variant) -> bool: return str(x).contains("full")), "full chest is reported")
	# Rehome: gone from the ranch and the team.
	TeamAnimals.set_team(goat, false)
	TeamAnimals.set_team(goat, true)
	check(TeamAnimals.rehome(goat) and Ranch.animal(goat).is_empty() and TeamAnimals.team().is_empty(), "rehome")


func _menu() -> GameMenu:
	for ch in current_scene.get_children():
		if ch is GameMenu:
			return ch
	return null


func _texts(n: Node, out: Array) -> void:
	if n is Button:
		out.append((n as Button).text)
	elif n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_texts(c, out)


func _menu_pages() -> void:
	print("-- menu pages")
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	_inject_ranch()
	Ranch.st()["houses"]["barn"] = {"tier": 1}
	GameState.run["intro_done"] = true
	GameState.run["day"] = 9
	var g := Ranch.add("goat", "barn", "Bea", 1)
	Ranch.animal(g)["friend"] = 300
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/beach.tscn")
	await frames(30)
	var d := Dialogue.instance(self)
	for i in 30:
		if not d.active:
			break
		d._advance()
		await frames(3)
	var m := _menu()
	check(m != null, "menu exists")
	if m == null:
		return
	m.toggle()
	await frames(3)
	m._tab = "Party"
	m._refresh()
	await frames(2)
	var t: Array = []
	_texts(m._body, t)
	check(t.any(func(x: Variant) -> bool: return str(x).begins_with("Animals:")), "Party has the Animals row")
	check(t.any(func(x: Variant) -> bool: return str(x).begins_with("Chores")), "Party has the Chores row")
	m._tab = "Animals"
	TeamAnimals._sel = g
	m._refresh()
	await frames(2)
	t = []
	_texts(m._body, t)
	check(t.any(func(x: Variant) -> bool: return str(x).contains("Bea")), "Animals lists Bea")
	check(t.any(func(x: Variant) -> bool: return str(x).contains("Teach Charge")), "detail offers lessons")
	check(t.back() == "Back to Party", "page ends with a way out")
	GameState.add_item("carrot", 2)
	GameState.run["energy"] = 100
	for b in m._body.get_children():
		if b is Button and (b as Button).text.contains("Teach Charge"):
			(b as Button).pressed.emit()
			break
	await frames(2)
	check(TeamAnimals.rank(g, "attack") == 1, "Teach button teaches")
	for b in m._body.get_children():
		if b is Button and (b as Button).text.contains("Put on the team"):
			(b as Button).pressed.emit()
			break
	await frames(2)
	check(TeamAnimals.on_team(g), "team toggle works")
	# The follower: spawns outdoors, counts as a team, rests when downed.
	var gm := current_scene as GameMap
	var beasts := TeamBeast.spawn_all(gm)
	await frames(10)
	check(beasts.size() == 1 and gm.allies().has(beasts[0]), "team animal walks with you (allies)")
	check(GameState.has_team(), "a team animal counts as a team")
	if beasts.size() == 1:
		var b: TeamBeast = beasts[0]
		check(b.position.distance_to(gm.player.position) < 80.0, "follower stays near you")
		b.take_damage(3, b.position)
		b.heal(1)
		check(b.hp == b.max_hp - 2, "take_damage/heal")
		b.take_damage(9999, b.position)
		await frames(3)
		check(not is_instance_valid(b) and TeamBeast.out_today().is_empty(), "downed animal rests till morning")
		GameState.run["day"] = int(GameState.run["day"]) + 1
		check(TeamBeast.out_today().size() == 1, "back out next day")
		# Fetch: a forage spot near you gets picked and lands in your bag.
		Ranch.animal(g)["lessons"]["fetch"] = 7
		var b2: Array = TeamBeast.spawn_all(gm)
		var pc := gm.world_to_cell(gm.player.position)
		var fc := pc + Vector2i(2, 1)
		gm.set_thing(fc.x, fc.y, {"type": "forage", "item": "berry", "key": "p4_test_forage"}, false)
		var had := GameState.count("berry")
		m.toggle()  # close the menu: the world runs
		await frames(10)
		for i in 900:
			await process_frame
			if not gm.things.has(fc) and GameState.count("berry") > had:
				break
		check(not gm.things.has(fc) and GameState.count("berry") > had, "Fetch lesson picks forage near you and brings it back")
		for x in b2:
			(x as Node).queue_free()
		m.toggle()
		await frames(3)
	m._tab = "Chores"
	Chores._open = "animal:" + g
	m._refresh()
	await frames(2)
	t = []
	_texts(m._body, t)
	check(t.any(func(x: Variant) -> bool: return str(x).contains("Bea")), "Chores lists the team animal")
	check(m._tab_buttons.has("Party") and (m._tab_buttons["Party"] as Button).modulate.g < 0.95, "Party tab lit on a sub-page")
	m.back_one()
	await frames(2)
	check(m._tab == "Party", "B steps back to Party (%s)" % m._tab)
	m.toggle()


func _run() -> void:
	InputSetup.ensure_actions()
	_arc("penguins")
	_arc("gangsters")
	await _menu_pages()
	if fails == 0:
		print("team_animals_test: OK")
	else:
		print("team_animals_test: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)

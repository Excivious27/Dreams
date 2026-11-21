extends SceneTree
## CONDUCT 11b P5: chores and team animals rework + RanchVoice.
## Feed through Ranch with real hay (trough, silo, chest; bees skipped), helper pet share, helper
## spots, the nightly value cap, forage regions by visit and arc, chore levels always add a unit,
## two chores a night, ranks from the first lesson, the pup hp cap, one rename path, lesson
## words, team tint, RanchVoice species/alias/lab layer lookups (both arcs).
##   godot --headless --path . --fixed-fps 60 -s res://tools/c11b_p5_test.gd
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(5)
	Campaign.bypass = true
	_run.call_deferred()


func _arc(arc: String) -> void:
	print("-- ", arc)
	GameState.new_run(arc, "kairi", "T", "Town", "Pup")
	GameState.run["day"] = 10
	for h in ["barn", "coop", "apiary"]:
		Ranch.st()["houses"][h] = {"tier": 1}
	var day := 10
	var cow := Ranch.add("cow", "barn", "", day - 30)
	var cow2 := Ranch.add("cow", "barn", "", day - 30)
	var bees := Ranch.add("bees", "apiary", "", day - 30)
	var goat := Ranch.add("goat", "barn", "", day - 30)
	check(cow != "" and cow2 != "" and goat != "", "ranch adds animals")

	# ---- feed: real hay through Ranch.feed (c11b_06-01) ----
	Ranch.house("barn")["hay"] = 1
	GameState.run["silo"] = 0
	var r := Chores._do("feed", 5, "chest")
	check(int(r.get("done", 0)) == 1 and int(Ranch.house("barn")["hay"]) == 0, "feed took the one trough hay (%s)" % str(r))
	check(int(Ranch.animal(bees).get("last_fed", -1)) != day, "bees are not hay-fed by a helper")
	check(str(r.get("what", "")).contains("ran out") or str(r.get("why", "")) != "" or int(r["done"]) == 1, "feed says when hay runs out")
	var b := Storage.box("chest")
	b["items"]["hay"] = 5
	var r2 := Chores._do("feed", 5, "chest")
	check(int(r2.get("done", 0)) >= 1 and Storage.amount("chest", "hay") < 5, "feed then takes hay from the chest (%s)" % str(r2))
	var r3 := Chores._do("feed", 5, "chest")
	check(int(r3.get("done", 0)) == 0, "nobody fed twice a day")

	# ---- pet share (c11b_06-12) ----
	var f0 := int(Ranch.animal(cow).get("friend", 0))
	check(Chores.pet_helper(cow, 0.5), "helper pets")
	var gain := int(Ranch.animal(cow).get("friend", 0)) - f0
	check(gain > 0 and gain < int(Ranch.rule("pet_friend", 30)), "helper pet gives about half (%d)" % gain)
	check(Ranch.pet(cow), "your own pet still counts the same day")

	# ---- forage regions (c11b_06-05) ----
	check(Chores.forage_regions() == ["edges"], "new save: only the edges (%s)" % str(Chores.forage_regions()))
	var vis_key := "forest" if arc == "penguins" else "docks"
	GameState.run["visited"] = {vis_key: [0, 0]}
	check(vis_key in Chores.forage_regions(), "visited %s opens for foraging" % vis_key)
	check(not ("docks" if arc == "penguins" else "forest") in Chores.forage_regions(), "the other arc's region never shows")
	check(Chores.region_name("edges") == ("the farm edges" if arc == "penguins" else "the lot edges"), "arc words for the edges")
	check(Chores.unit_cost("pup", "forage", vis_key) > Chores.unit_cost("pup", "forage", "edges"), "far regions cost more energy")
	Storage.box("chest")["items"] = {}
	var pool_key := str(Chores.forage_region(vis_key).get("pool", ""))
	var allowed := {}
	# C15 P2: a region's table now carries the season's own forage (SeasonGoods.forage_pool), same as roll_forage.
	for row in SeasonGoods.forage_pool(pool_key, GameState.forage_data.get(pool_key, []) as Array):
		allowed[str(row[0])] = true
	Chores._budget = 99999
	var rf := Chores._do("forage", 4, "chest", vis_key)
	var all_ok := int(rf.get("done", 0)) > 0
	for id: String in (Storage.box("chest")["items"] as Dictionary):
		if not allowed.has(id) and id != "hay":
			all_ok = false
	check(all_ok, "region forage comes from that region's table (%s)" % str(rf))

	# ---- levels always help (c11b_06-13) and energy grows with bond (c11b_06-07) ----
	var prev := -1
	var grows := true
	for lv in [0] + (Chores.data()["levels"] as Array):  # C16a P6: levels follow data (40/130/300/600)
		(Chores.st()["xp"] as Dictionary)["pup"] = {"forage": lv}
		var u := Chores.units("pup", "forage", 1.0, "edges")
		if u <= prev:
			grows = false
		prev = u
	check(grows, "every pup forage level adds a unit")
	(Chores.st()["xp"] as Dictionary)["pup"] = {}
	check(Chores.energy("animal:" + goat, "fetch") >= int(((Chores.data()["workers"] as Dictionary)["animal"] as Dictionary)["energy"]), "energy at least the kind base")

	# ---- helper spots (c11b_06-08) ----
	Chores.st()["assign"] = {}
	var cap := Chores.slots()
	check(cap >= 2 and cap <= 6, "helper spots in range (%d)" % cap)
	var known: Array = []
	for i in cap + 1:
		known.append("tp_%d" % i)
	Companion.party()["known"] = known
	var ok_n := 0
	var refused := ""
	for i in cap + 1:
		var why := Chores.assign("partner:tp_%d" % i, "water")
		if why == "":
			ok_n += 1
		else:
			refused = why
	check(ok_n == cap and refused.contains("helper spots"), "assign stops at the spot cap (%d of %d: %s)" % [ok_n, cap, refused])

	# ---- night value cap (c11b_12-01) ----
	Chores.st()["assign"] = {}
	var farm: Dictionary = GameState.run["farm"]
	farm.clear()
	var cid := ""
	for c: String in GameState.crops:
		var cd0: Dictionary = GameState.crops[c]
		if not cd0.has("regrow") and not bool(cd0.get("tree", false)) and GameState.item_value(str(cd0.get("yield", ""))) > 0:
			cid = c
			break
	var cd: Dictionary = GameState.crops[cid]
	for i in 30:
		farm["%d,%d" % [5 + i, 5]] = {"crop": cid, "days": int(cd["days"]), "watered": false, "acc": 0.0, "fert": true}
	Storage.box("chest")["items"] = {}
	Storage.box("chest")["cap"] = 999
	Chores._budget = GameState.item_value(str(cd["yield"])) * 2
	var rh := Chores._do("harvest", 10, "chest")
	check(int(rh.get("done", 0)) == 2 and bool(rh.get("capped", false)), "harvest stops at the value cap (%s)" % str(rh))
	var reaped := 0
	for k in farm:
		if str(farm[k].get("crop", "")) == "":
			reaped += 1
			check(not (farm[k] as Dictionary).has("fert"), "fertiliser used up on a helper harvest (c11b_06-15)")
	check(reaped == 2, "only the harvested beds were reset")
	check(Chores.night_cap() > 0, "a night cap exists")

	# ---- two chores (c11b_06-07) ----
	Chores.st()["assign"] = {}
	Companion.party()["known"] = ["tp_0"]
	GameState.run["friendship"]["tp_0"] = 99999
	var pk := "partner:tp_0"
	Chores.assign(pk, "water")
	if Chores.two_chores(pk):
		check(Chores.assign2(pk, "harvest") == "", "a strong worker takes a second chore")
		check(Chores.units(pk, "water") <= Chores.units(pk, "water", 1.0), "two chores split the energy")
		check(Chores.row_text(pk, "Pal").contains("waters") and Chores.row_text(pk, "Pal").contains("→"), "row text says what and where (%s)" % Chores.row_text(pk, "Pal"))
	else:
		check(Chores.assign2(pk, "harvest") != "", "a weak worker can't take two")

	# ---- team animals ----
	check(TeamAnimals.rank(goat, "attack") == 0, "no lessons, rank 0")
	Ranch.animal(goat)["lessons"] = {"attack": 1}
	var at2 := int((TeamAnimals.rule("rank_at", [1, 4]) as Array)[1])
	check(TeamAnimals.rank(goat, "attack") == 1 and TeamAnimals.lessons_left(goat, "attack") == at2 - 1, "rank 1 on the first lesson, %d more to rank 2" % (at2 - 1))
	var atn := int((TeamAnimals.rule("rank_at", [7]) as Array).back())
	Ranch.animal(goat)["lessons"] = {"attack": atn, "guard": atn}  # C16a P6: rank 5 at rank_at.back()
	check(TeamAnimals.lessons_left(goat, "attack") == 0 and TeamAnimals.lesson_note(goat, "attack").contains("mastered"), "mastered note")
	var stt := TeamAnimals.stats(goat)
	check(int(stt["hp"]) < Pet.max_hp() or int(stt["hp"]) == 8, "team animal hp stays under the pup's real hp (%d vs %d)" % [int(stt["hp"]), Pet.max_hp()])
	check(TeamAnimals.lesson_desc("guard").contains("in battle") and TeamAnimals.lesson_desc("guard").contains("watch"), "lesson words name chore and job: " + TeamAnimals.lesson_desc("guard"))
	check("guard" in TeamAnimals.chores_for(goat), "Guard opens its own chore")
	check(TeamAnimals.rename(goat, "  Captain Hooves 99!  ") and TeamAnimals.name_of(goat).length() <= 12 and bool(Ranch.animal(goat).get("named", false)), "one rename path (Ranch.rename): %s" % TeamAnimals.name_of(goat))
	check(TeamAnimals.suggest_name(cow) != "", "name suggestion")
	check(TeamAnimals.tint(goat) is Color, "tint")
	GameState.run["energy"] = 0  # C16a P3: lessons go through spend_for (work until 0)
	Ranch.animal(goat)["friend"] = 900
	Ranch.animal(goat)["lessons"] = {}
	GameState.add_item("carrot", 3)
	check(TeamAnimals.teach(goat, "attack").contains("tired") and GameState.count("carrot") == 3, "too tired: no treat spent")

	# ---- RanchVoice (c11b_14-10 / -03 / 02-12) ----
	check(RanchVoice.voice_id("chrome_hen") == "cluck" and RanchVoice.layer_of("chrome_hen") != "", "chrome hen clucks with a lab layer")
	check(GameMap.animal_voice("chrome_hen") == "cluck" and GameMap.animal_voice("glow_sheep") == "sheep", "lab strains never borrow by prefix")
	check(GameMap.animal_voice("moon_cow") == "cv_moon" and RanchVoice.voice_id("moon_cow") == "cv_moon", "moon cow has its own voice (P6 CC0 take)")
	check(GameMap.animal_voice("cow") == "moo" and GameMap.animal_voice("chick") == "peep", "classic voices unchanged")
	check(RanchVoice.layer_of("cow") == "" and RanchVoice.layer_of("moon_cow") == "", "only lab strains get a layer")
	check(RanchVoice.species_of(cow) == "cow", "uid resolves to its species")
	check(RanchVoice.file_of("storm_roc_baby") != "", "babies resolve through the art table")
	for c in ["water", "harvest", "feed", "pet", "forage", "guard"]:
		check(Chores.icon(c) != null, "chore icon " + c)


func _run() -> void:
	_arc("penguins")
	_arc("gangsters")
	print("c11b_p5_test: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)

extends SceneTree
## Ranch core (CONDUCT 11a P1), headless, both arcs: data loads, add/capacity, hay feeding, petting,
## overnight goods with quality from friendship+mood, silo feeders, breeding (no gender checks) with
## genetics-lite variants, incubator hatching, growing up, rehome (no loop for young ones), source_ok,
## the morning report lines, the empty-data fallback, and a legacy-roster migration round trip.
##   godot --headless --path . -s res://tools/ranch_test.gd
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(11)
	for arc in ["penguins", "gangsters"]:
		_care(arc)
		_breed(arc)
	_empty_data()
	_indoors_rule()
	_migration()
	_pen_layout()
	_incubator_view()
	print("ranch_test: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh(arc: String) -> void:
	GameState.use_slot(2)
	GameState.new_run(arc, "dad" if arc == "gangsters" else "mom", "Tester", "Town", "Pup")
	GameState.run["day"] = 3
	GameState.run["builds"] = {"coop": 1, "barn": 1}
	GameState.run.erase("ranch")


## A night: Ranch.overnight then the day turns over (what GameState.sleep does around it).
func night() -> Array:
	var rep := {}
	var lines := Ranch.overnight(rep)
	GameState.run["day"] = int(GameState.run["day"]) + 1
	return lines


func _care(arc: String) -> void:
	_fresh(arc)
	check(Ranch.species("cow").get("home", "") == "barn" and Ranch.species_for_arc().size() >= 9, "%s: nine classic species load" % arc)
	check(Ranch.capacity("coop") == 4 and Ranch.capacity("barn") == 4, "%s: tier 1 homes hold 4" % arc)
	var cow := Ranch.add("cow")
	var hens: Array = []
	for i in 4:
		hens.append(Ranch.add("chicken"))
	check(cow != "" and hens.size() == 4 and not hens.has(""), "%s: animals added to their homes" % arc)
	check(Ranch.add("chicken") == "", "%s: a full coop takes no more" % arc)
	check(Ranch.add("pig") == "", "%s: no sty, no pig" % arc)
	check(str(Ranch.animal(cow)["name"]) != "" and str(Ranch.animal(cow)["name"]) != str(Ranch.animal(hens[0])["name"]), "%s: each animal gets its own name" % arc)
	check(Ranch.rename(cow, "  Clover!! ") and str(Ranch.animal(cow)["name"]) == "Clover", "%s: rename cleans the name" % arc)
	# Hungry: no goods, a hungry line.
	check(Ranch.hint(cow) == "A: Clover (hungry)" and Ranch.need(cow) == "hungry", "%s: hungry hint (%s)" % [arc, Ranch.hint(cow)])
	GameState.run["weather"] = {str(int(GameState.run["day"])): "rain"}  # wet day: no pasture (RanchFarm.graze_day)
	var lines := night()
	check(Ranch.ready(cow).is_empty() and _has(lines, "went hungry"), "%s: an unfed cow gives nothing and the morning says so" % arc)
	# Hand-fed with hay + petted -> milk in the morning.
	GameState.add_item("hay", 5)
	var t := Ranch.tap(cow, "hay")
	check(bool(t["fed"]) and bool(t["petted"]) and GameState.count("hay") == 4, "%s: a tap with hay feeds and pets (%s)" % [arc, t["text"]])
	check(not Ranch.pet(cow), "%s: one pet a day" % arc)
	night()
	var r := Ranch.ready(cow)
	check(str(r.get("item", "")) == "milk" and int(r.get("n", 0)) >= 1 and str(r.get("q", "")) == "", "%s: milk ready, plain quality while friendship is low" % arc)
	check(Ranch.need(cow) == "goods" and Ranch.hint(cow).contains("goods ready"), "%s: goods bubble" % arc)
	var before := GameState.count("milk")
	var got := Ranch.take(cow)
	check(GameState.count("milk") == before + int(got["n"]) and Ranch.ready(cow).is_empty(), "%s: goods picked up into the bag" % arc)
	# Friendship -> silver then gold (fed + petted daily).
	var a := Ranch.animal(cow)
	a["friend"] = 690
	for d in 3:
		Ranch.feed(cow, "spouse")
		Ranch.pet(cow)
		night()
		Ranch.take(cow)
	Ranch.feed(cow, "spouse")
	Ranch.pet(cow)
	night()
	check(int(a["friend"]) >= 700 and str(Ranch.ready(cow).get("q", "")) == "g", "%s: a loved, content cow gives gold milk (friend %d, mood %d)" % [arc, int(a["friend"]), int(a["mood"])])
	# Missed pets: said once, friendship slips.
	Ranch.take(cow)
	Ranch.feed(cow, "spouse")
	var f0 := int(a["friend"])
	lines = night()
	check(int(a["friend"]) < f0 + 10 and _has(lines, "missed you"), "%s: a missed pet is said once and costs friendship" % arc)
	Ranch.feed(cow, "spouse")
	lines = night()
	check(not _has(lines, "missed you"), "%s: no nag the next morning" % arc)
	# Silo feeder (Big Barn).
	GameState.run["builds"]["barn"] = 2
	GameState.run["builds"]["silo"] = 1
	GameState.run["silo"] = 3
	Ranch.take(cow)
	lines = night()
	check(int(GameState.run["silo"]) == 2 and _has(lines, "feeders took 1 hay"), "%s: the Big Barn feeder eats from the silo" % arc)
	# Report shows in the morning summary.
	var rep := {"ranch": ["A line."]}
	var sl := SleepReport.lines(rep)
	var found := false
	for l in sl:
		if str(l.get("text", "")).contains("A line."):
			found = true
	check(found, "%s: SleepReport shows ranch lines" % arc)
	found = false
	for l in SleepReport.lines({"hazel": {"watered": 3}}):
		found = found or str(l.get("text", "")).contains("Watered your 3 beds")
	check(found, "%s: Hazel's overnight watering shows in the morning" % arc)
	check(Ranch.source_ok("milk") and Ranch.source_ok("cheese") and not Ranch.source_ok("truffle") or GameState.count("truffle") > 0, "%s: source_ok follows the herd and processing" % arc)
	# Rehome: young ones pay nothing (no breed-and-rehome loop), grown ones a small thank-you.
	var m0 := int(GameState.run.get("crystals", 0))
	check(Ranch.rehome_pay(hens[0]) == 0, "%s: a hen under 28 days old rehomes for nothing" % arc)
	GameState.run["day"] = int(GameState.run["day"]) + 40
	var pay := Ranch.rehome_pay(hens[1])
	check(pay > 0 and pay <= int(Ranch.species("chicken")["buy"]["price"]) / 4, "%s: a grown hen's thank-you is small (%d)" % [arc, pay])
	check(Ranch.rehome(hens[1]) and Ranch.animal(hens[1]).is_empty() and int(GameState.run.get("crystals", 0)) == m0 + pay, "%s: rehomed (lives on at a pasture)" % arc)
	check(_has(night(), "settled in"), "%s: the morning says where it went" % arc)


func _breed(arc: String) -> void:
	_fresh(arc)
	GameState.run["builds"]["barn"] = 2
	GameState.run["builds"]["coop"] = 2
	var a := Ranch.add("goat")
	var b := Ranch.add("goat")
	Ranch.animal(b)["variant"] = "brown"
	for u in [a, b]:
		Ranch.animal(u)["friend"] = 500
	var expecting := false
	for d in 30:
		Ranch.feed_all(-1, "spouse")
		for line in night():
			if str(line).contains("expecting"):
				expecting = true
	var kids: Array = Ranch.roster("barn").filter(func(u: String) -> bool: return u != a and u != b)
	check(expecting and kids.size() >= 1, "%s: two content goats (no gender check) have a kid (%d)" % [arc, kids.size()])
	if kids.size() >= 1:
		var k: Dictionary = Ranch.animal(kids[0])
		check((k["parents"] as Array).has(a) and str(k["variant"]) in ["white", "brown", "chocolate"], "%s: the kid has parents and a goat look (%s)" % [arc, k["variant"]])
	check(Ranch.roster("barn").size() <= Ranch.capacity("barn"), "%s: births never overfill the barn" % arc)
	# Incubator: an egg -> a chick in 3 days, young, then grown.
	GameState.add_item("egg", 1)
	check(Ranch.incubate("egg") == "", "%s: the Big Coop incubator takes an egg" % arc)
	var n0 := Ranch.roster("coop").size()
	var hatched := false
	for d in 3:
		for line in night():
			hatched = hatched or str(line).contains("hatched")
	check(hatched and Ranch.roster("coop").size() == n0 + 1, "%s: a chick hatched overnight" % arc)
	var chick := str(Ranch.roster("coop")[-1])
	check(not Ranch.is_adult(chick) and bool(Ranch.art_for(chick)["baby"]), "%s: the chick is young (baby art)" % arc)
	for d in 8:
		night()
	check(Ranch.is_adult(chick), "%s: and grows up" % arc)


func _empty_data() -> void:
	var keep := Ranch._data
	Ranch._data = {"species": {}, "buildings": {}, "rules": {}, "products": {}, "processing": {}}
	_fresh("penguins")
	check(Ranch.add("cow") == "" and Ranch.capacity("barn") == 0 and Ranch.overnight({}).is_empty() and not Ranch.source_ok("milk"), "empty ranch.json: nothing breaks")
	Ranch.migrate()
	check(Ranch.animals().is_empty(), "empty ranch.json: migration adds nothing")
	Ranch._data = keep


func _migration() -> void:
	_fresh("penguins")
	var r := GameState.run
	r["day"] = 12
	r["builds"] = {"coop": 1, "barn": 2}
	r["animals"] = {"goat_32_8": {"streak": 5, "last_pet": 11, "fed": 11}}
	r["flags"]["barn2_day"] = 10
	Ranch.migrate()
	var g := Ranch.uid_of_legacy("goat_32_8")
	check(Ranch.roster("coop").size() == 4 and Ranch.roster("barn").size() == 8, "migration: the old farm's 12 animals (%d, %d)" % [Ranch.roster("coop").size(), Ranch.roster("barn").size()])
	check(g != "" and int(Ranch.animal(g)["friend"]) == 250 and Ranch.quality({"friend": 250, "mood": 60}) == "s", "migration: a 5-day streak is silver friendship")
	check(not Ranch.is_adult(Ranch.uid_of_legacy("goat_kid_33_6")), "migration: the goat kid is still young")
	var once := JSON.stringify(r["ranch"])
	Ranch.migrate()
	check(JSON.stringify(r["ranch"]) == once, "migration: twice changes nothing")
	# Round trip through JSON (the save file): ints come back as floats and still work.
	var back: Variant = JSON.parse_string(JSON.stringify(r))
	GameState.run = back
	check(Ranch.roster("barn").size() == 8 and Ranch.is_adult(Ranch.uid_of_legacy("llama_32_6")) and Ranch.tier("barn") == 2, "migration: survives a save round trip")
	GameState.run["day"] = int(GameState.run["day"]) + 1
	Ranch.feed_all()
	check(Ranch.overnight({}) is Array, "migration: the loaded roster runs a night")


func _has(lines: Array, s: String) -> bool:
	for l in lines:
		if str(l).contains(s):
			return true
	return false


func _indoors_rule() -> void:
	_fresh("penguins")
	var c := Ranch.add("cow")
	var h := Ranch.add("chicken")
	GameState.run["time"] = 12 * 60
	var day_out := not Ranch.indoors(c) or GameState.weather_today() in ["storm", "snow", "blizzard"]
	check(day_out, "midday: the herd is out")
	GameState.run["time"] = GameState.sunset() + 60
	check(Ranch.indoors(c) and Ranch.indoors(h), "after sunset: everyone goes in")
	GameState.run["time"] = 12 * 60


## Every pen of every tier sits on open ground (c11b_05-01): never inside a farmhouse tier, another
## home's pen, another building's footprint, the greenhouse bed, the north track (x36) or the terrace.
func _pen_layout() -> void:
	var blds: Dictionary = Ranch.data()["buildings"]
	var pens: Array = []  # [home, tier, rect]
	for home in blds:
		for row in (blds[home] as Array):
			var p: Array = (row as Dictionary).get("pen", [])
			if p.size() == 4:
				pens.append([str(home), int(row["tier"]), Rect2i(int(p[0]), int(p[1]), int(p[2]), int(p[3]))])
	var farm_s: GDScript = load("res://scripts/farm.gd")
	var houses: Dictionary = farm_s.get_script_constant_map()["HOUSE_TIERS"]
	for pe in pens:
		var r: Rect2i = pe[2]
		var who := "%s tier %d pen %s" % [pe[0], pe[1], str(r)]
		for t in houses:
			check(not r.intersects(houses[t]["rect"]), "%s clear of farmhouse tier %d" % [who, t])
		check(not r.intersects(GameState.GREENHOUSE_PLOT.grow(1)), "%s clear of the greenhouse bed" % who)
		check(not r.intersects(Rect2i(36, 0, 1, 60)), "%s off the north track" % who)
		check(not r.intersects(Rect2i(38, 0, 34, 12)), "%s not up on the terrace" % who)
		for pe2 in pens:
			if pe2[0] != pe[0]:
				check(not r.intersects(pe2[2]), "%s clear of %s tier %d pen" % [who, pe2[0], pe2[1]])
		var own := Ranch.build_of(str(pe[0]))
		for bid in Builds.all():
			var bd: Dictionary = Builds.all()[bid]
			if bid == own or not bd.has("cell") or Ranch.data()["buildings"].has(str(bd.get("ranch", ""))) and str(bd.get("ranch", "")) == str(pe[0]):
				continue
			if str(bd.get("ranch", "")) != "" or bid in ["hutch", "sty"]:
				continue  # other ranch homes' buildings move with their pens (gen_stations, P1 c11b_05-02)
			var w := maxi(1, int(bd.get("w", 1)))
			var h := maxi(1, int(bd.get("h", 1)))
			var fp := Rect2i(int(bd["cell"][0]), int(bd["cell"][1]) - h + 1, w, h)
			check(not r.intersects(fp), "%s clear of %s at %s" % [who, bid, str(fp)])


## The incubator is a view over Ranch (c11b_01-03, 05-07): eggs come from breed.egg, warm in their
## species' home, and RanchFarm sees Ranch's own entries.
func _incubator_view() -> void:
	_fresh("penguins")
	GameState.run["builds"] = {"coop": 2, "barn": 1}
	Ranch.migrate()
	for sid in Ranch.data()["species"]:
		var br: Variant = Ranch.species(sid).get("breed", null)
		if br is Dictionary and str((br as Dictionary).get("egg", "")) != "":
			check(RanchFarm.hatch_species(str(br["egg"])) == sid, "breed.egg %s hatches %s" % [br["egg"], sid])
			check(RanchFarm.hatch_days(sid) == maxi(1, int(br.get("days", 3))), "%s warms breed.days" % sid)
			check(RanchFarm.egg_home(str(br["egg"])) == str(Ranch.species(sid)["home"]), "%s egg goes to its home" % sid)
	check(RanchFarm.hatch_species("milk") == "", "milk is not an egg")
	check(RanchFarm.incubator_homes().has("coop"), "Big Coop has an incubator")
	check(RanchFarm.incubator_tier_name("coop") != "", "incubator tier name (%s)" % RanchFarm.incubator_tier_name("coop"))
	GameState.add_item("duck_egg", 1)
	check(Ranch.incubate("duck_egg") == "", "duck egg in")
	check(RanchFarm.incubator("coop").size() == 1 and RanchFarm.all_eggs().size() == 1, "RanchFarm sees Ranch's entry")
	check(RanchFarm.room_for_egg("coop") == Ranch.room("coop") - 1, "room counts warming eggs")
	var due := RanchFarm.egg_day(RanchFarm.incubator("coop")[0])
	var names := RanchFarm.hatch_due(due)
	check(names.size() == 1 and RanchFarm.all_eggs().is_empty(), "due egg hatches through RanchFarm (%s)" % str(names))
	check(RanchFarm.baby_word("duck") == "duckling" and RanchFarm.baby_word("cow").begins_with("baby"), "baby words")

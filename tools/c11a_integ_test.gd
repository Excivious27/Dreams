extends SceneTree
## C11a integration checks (one care path across P1 Ranch, P2 RanchFarm, P3 skills, P4 chores, P6 art), headless:
## pasture nights feed the roster (no false "went hungry"), the incubator has one entry shape (Ranch.incubate
## "due", old "day" still hatches), Ranching effect keys are the canonical ones every reader uses, Farm Hand
## workers come from hand_slot, FarmAnimal reads P6 heights, and bee_swarm has an idle strip.
##   godot --headless --path . -s res://tools/c11a_integ_test.gd
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(7)
	for arc in ["penguins", "gangsters"]:
		_pasture(arc)
		_incubator(arc)
		_hands(arc)
	_keys()
	_art()
	print("c11a_integ_test: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh(arc: String) -> void:
	GameState.use_slot(2)
	GameState.new_run(arc, "dad" if arc == "gangsters" else "mom", "Tester", "Town", "Pup")
	GameState.run["day"] = 3
	GameState.run["builds"] = {"coop": 2, "barn": 1}
	GameState.run.erase("ranch")


func _night() -> Array:
	var lines := Ranch.overnight({})
	GameState.run["day"] = int(GameState.run["day"]) + 1
	return lines


func _has(lines: Array, bit: String) -> bool:
	for l in lines:
		if str(l).contains(bit):
			return true
	return false


func _pasture(arc: String) -> void:
	_fresh(arc)
	var cow := Ranch.add("cow", "barn", "Clover", 1)
	Ranch.animal(cow)["adult_day"] = 1
	var d := int(GameState.run["day"])
	GameState.run["weather"] = {str(d): "sunny"}
	var dry := RanchFarm.graze_day()
	var lines := _night()
	check(not dry or (not _has(lines, "went hungry") and int(Ranch.animal(cow).get("last_fed", -1)) == d), "%s: a dry day's pasture feeds the roster overnight (%s)" % [arc, str(lines)])
	d = int(GameState.run["day"])
	GameState.run["weather"] = {str(d): "rain"}
	lines = _night()
	check(_has(lines, "went hungry"), "%s: a wet day with no hay still says hungry" % arc)


func _incubator(arc: String) -> void:
	_fresh(arc)
	Ranch.add("chicken", "coop", "Pip", 1)
	GameState.add_item("egg", 2)
	var why := Ranch.incubate("egg")
	var inc := RanchFarm.incubator()
	check(why == "" and inc.size() == 1 and (inc[0] as Dictionary).has("due"), "%s: Ranch.incubate fills the coop incubator RanchFarm reads (%s)" % [arc, why])
	check(RanchFarm.egg_day(inc[0]) > int(GameState.run["day"]), "%s: egg_day reads Ranch's due" % arc)
	inc.append({"species": "chicken", "day": int(GameState.run["day"])})  # an old-shape entry
	var lines := _night()
	check(_has(lines, "hatched") and RanchFarm.incubator().size() == 1, "%s: an old 'day' entry hatches overnight, the new one keeps warming (%s)" % [arc, str(lines)])


func _hands(arc: String) -> void:
	_fresh(arc)
	var before := Chores.workers().size()
	GameState.run["skills"]["ranching"] = {"farm_hand": 1} if GameState.run.get("skills", null) is Dictionary else {}
	var has_hand := false
	for w: Array in Chores.workers():
		has_hand = has_hand or str(w[2]) == "hand"
	check(GameState.ranch_bonus("hand_slot") < 1.0 or has_hand, "%s: a Farm Hand node adds a worker" % arc)
	check(not has_hand or Chores.workers().size() > before, "%s: workers grow with hand_slot" % arc)
	check(((Chores.data()["workers"] as Dictionary).get("hand", {}) as Dictionary).get("chores", []) == ["feed", "pet"], "%s: farm hands do ranch chores only" % arc)


func _keys() -> void:
	var f := FileAccess.open("res://data/skills.json", FileAccess.READ)
	var txt := f.get_as_text() if f else ""
	for old in ["ani_double", "ani_quality", "grow_fast", "ani_friend"]:
		check(not txt.contains("\"%s\"" % old), "skills.json has no old key %s" % old)
	for key in ["animal_yield", "animal_quality", "animal_friend", "grow_speed", "big_goods", "breed_chance", "ranch_value"]:
		check(txt.contains("\"%s\"" % key), "skills.json uses the read key %s" % key)
		check(GameState.BONUS_CAPS.has(key), "BONUS_CAPS caps %s" % key)
	var r := FileAccess.open("res://data/recipes.json", FileAccess.READ)
	var rt := r.get_as_text() if r else ""
	for g in ["\"feather\"", "\"rabbit_fur\"", "\"beeswax\""]:
		check(rt.contains(g), "a recipe uses %s" % g)


func _art() -> void:
	check(Art.has("animals/bee_swarm", "idle"), "bee_swarm has an idle strip")
	check(is_equal_approx(FarmAnimal.target_h("chick"), 7.0), "FarmAnimal reads P6 heights (chick %s)" % FarmAnimal.target_h("chick"))
	check(is_equal_approx(FarmAnimal.target_h("horse3"), 32.0), "FarmAnimal falls back to TARGET_H")
	var b: Dictionary = Builds.data().get("mayo", {}) if Builds.data() is Dictionary else {}
	var t: Array = b.get("tiers", [])
	check(t.size() >= 1 and str((t[0] as Dictionary).get("sprite", "")) == "mayo_machine_1", "Mayo Machine uses P6 station art")

extends SceneTree
## CONDUCT 11a P5: villagers, mail, festivals and ranch sound.
## Favour sources (wool/goat milk/duck eggs from the right building tier, Ranch.source_ok once
## ranch.json has species), the storm letter only with animals, the ranch lead-in and welcome
## letters (both arcs), Tam's lamb Bramble (waits for barn room, then a keepsake in the barn),
## Tam's highland letters, spouse chores only with work to do, the crop contest (crops only,
## quality read before the entry is taken), the Animal Show scoring, the egg/milk quests gated on
## the coop/barn, heart perk texts, and pen spots driven by the animals on the map.
##   godot --headless --path . -s res://tools/ranch_villagers_test.gd
var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	seed(11)
	_run.call_deferred()

func _texts() -> String:
	var t := ""
	for m: Dictionary in Mail.list():
		t += str(m.get("from", "")) + ": " + str(m.get("text", "")) + "\n"
	return t

func _fresh(arc: String) -> void:
	GameState.new_run(arc, "kairi", "T", "Town", "Pup")
	for k in ["builds", "quality", "farm", "flags"]:
		if not (GameState.run.get(k, null) is Dictionary):
			GameState.run[k] = {}

func _empty_ranch() -> void:
	Ranch._data = {"species": {}, "buildings": {}, "rules": {}, "products": {}, "processing": {}}

func _run() -> void:
	Mail._morning_post = true  # no toasts outside a map
	for arc: String in ["penguins", "gangsters"]:
		await _arc(arc)
	_romance()
	_town()
	_quests_perks()
	_ambience()
	print("ranch_villagers_test: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

func _arc(arc: String) -> void:
	_fresh(arc)
	_empty_ranch()
	var fl: Dictionary = GameState.run["flags"]
	# --- sources (legacy tiers while ranch.json is empty) ---
	check(not Mail.ranch_source_ok("sheep_wool") and not Mail.ranch_source_ok("egg"), arc + ": no animals, no wool/eggs")
	check(Mail.needs_source("goat_milk") and Mail.needs_source("duck_egg") and not Mail.needs_source("turnip"), arc + ": animal goods need a source")
	GameState.run["builds"]["barn"] = 1
	check(Mail.ranch_source_ok("sheep_wool") and Mail.ranch_source_ok("milk") and not Mail.ranch_source_ok("goat_milk"), arc + ": barn 1 = milk + wool, not goat milk")
	GameState.run["builds"]["barn"] = 2
	GameState.run["builds"]["coop"] = 2
	check(Mail.ranch_source_ok("goat_milk") and Mail.ranch_source_ok("duck_egg"), arc + ": Big Barn goat milk, Big Coop duck eggs")
	check(not Mail.ranch_source_ok("truffle"), arc + ": truffles have no source yet")
	# Tam (likes sheep_wool) can ask for wool once there's a barn.
	var asked_wool := false
	var rng := RandomNumberGenerator.new()
	for i in 200:
		rng.seed = i
		if Mail._favour_item("tam", rng) == "sheep_wool":
			asked_wool = true
			break
	check(asked_wool, arc + ": Tam's favour can be wool with a barn")
	GameState.run["builds"].erase("barn")
	GameState.run["builds"].erase("coop")
	for i in 200:
		rng.seed = i
		var it := Mail._favour_item("tam", rng)
		if it in ["sheep_wool", "cheese"] and GameState.count(it) == 0:
			check(false, arc + ": no barn, yet Tam asks for " + it)
			break
	# With ranch.json species, Ranch.source_ok decides.
	Ranch._data = {"species": {"sheep": {"name": "Sheep", "home": "barn", "product": {"id": "sheep_wool"}}},
		"buildings": {"barn": [{"tier": 1, "cap": 4}]}, "rules": {}, "products": {}, "processing": {}}
	GameState.run["builds"]["barn"] = 1
	check(Mail.ranch_source_ok("sheep_wool") == Ranch.source_ok("sheep_wool"), arc + ": ranch data -> Ranch.source_ok")
	GameState.run["builds"].erase("barn")
	_empty_ranch()
	# --- storm letter ---
	Mail.list().clear()
	check(not Mail.has_animals(), arc + ": no animals yet")
	check(Mail._storm_animals() == "", arc + ": storm letter says nothing about animals without any")
	GameState.run["builds"]["coop"] = 1
	check("coop" in Mail._storm_animals() and not ("barn" in Mail._storm_animals()), arc + ": storm letter names only the coop with a coop (c12_09-10)")
	GameState.run["builds"].erase("coop")
	# --- lead-in ---
	Mail.list().clear()
	Mail._ranch_mail(5)
	check(not fl.has("rmail_lead"), arc + ": no ranch lead-in before day 6")
	GameState.run["day"] = 6
	Mail._ranch_mail(6)
	check(fl.has("rmail_lead") and "coop" in _texts().to_lower(), arc + ": day 6 ranch lead-in mentions the coop")
	var n := Mail.list().size()
	Mail._ranch_mail(7)
	check(Mail.list().size() == n, arc + ": lead-in once")
	# --- welcome letters (one a morning) ---
	GameState.run["builds"]["coop"] = 1
	GameState.run["builds"]["barn"] = 1
	Mail.list().clear()
	Mail._ranch_mail(8)
	check(fl.has("rmail_coop_1") and not fl.has("rmail_barn_1") and Mail.list().size() == 1, arc + ": coop welcome first, alone")
	check(str(Mail.list()[0].get("item", "")) == "hay", arc + ": coop welcome brings hay")
	Mail._ranch_mail(9)
	check(fl.has("rmail_barn_1"), arc + ": barn welcome next morning")
	# First goods: holding an egg with the coop built.
	GameState.add_item("egg", 1)
	Mail.list().clear()
	Mail._ranch_mail(10)
	check(fl.has("rmail_first_egg") and "egg" in _texts().to_lower(), arc + ": first-egg letter")
	# --- Tam's lamb ---
	fl["hv_tam_8"] = true
	Mail.list().clear()
	Mail._ranch_mail(11)
	check(fl.has("tam_lamb_wait") and not fl.has("tam_lamb_home") and "Bramble" in _texts(), arc + ": no barn room -> Bramble waits (letter)")
	Mail.list().clear()
	Mail._ranch_mail(12)
	check(Mail.list().is_empty(), arc + ": the waiting letter is sent once")
	Ranch._data = {"species": {"sheep": {"name": "Sheep", "home": "barn", "product": {"id": "sheep_wool"}}},
		"buildings": {"barn": [{"tier": 1, "cap": 4}]}, "rules": {}, "products": {}, "processing": {}}
	Ranch.st()["houses"]["barn"] = {"tier": 1}
	Mail._ranch_mail(13)
	var uid := str(fl.get("tam_lamb_home", ""))
	check(uid != "" and str(Ranch.animal(uid).get("species", "")) == "sheep" and bool(Ranch.animal(uid).get("keepsake", false)), arc + ": Bramble moves into the barn as a keepsake")
	check(str(Ranch.animal(uid).get("name", "")) == "Bramble" and Mail.lamb_name() == "Bramble", arc + ": she's called Bramble until renamed")
	Ranch.animal(uid)["name"] = "Clover"
	# --- Tam's highland letters ---
	fl["hv_tam_10"] = true
	Mail.list().clear()
	Mail._tam_highlands(20)
	check(Mail.list().is_empty(), arc + ": Tam's first letter waits a week")
	Mail._tam_highlands(27)
	Mail._tam_highlands(30)
	Mail._tam_highlands(34)
	check(Mail.list().size() == 2 and "Clover" in _texts(), arc + ": weekly letters, the second asks after the lamb by her name")
	Mail._tam_highlands(41)
	check(Mail.list().size() == 3 and Mail.tam_away(), arc + ": three letters, Tam still away")
	for d in range(48, 63):
		Mail._tam_highlands(d)
	check(Mail.list().size() == 3, arc + ": the last letter waits for the week before a fall/winter festival (c12_09-06)")
	for d in range(63, 120):
		Mail._tam_highlands(d)
	check(Mail.list().size() == Mail.TAM_LETTERS.size() and "Harvest Fair" in _texts() and not Mail.tam_away(), arc + ": four highland letters in all, the last before the Harvest Fair")
	_empty_ranch()

func _romance() -> void:
	_fresh("penguins")
	_empty_ranch()
	var s := Romance.st()
	s["spouse"] = "benno"
	s["married_day"] = 1
	s["chore_day"] = 0
	GameState.run["day"] = 5
	GameState.run["farm"] = {}
	var saw := {}
	for i in 120:
		seed(500 + i)
		var rep := {}
		Romance.overnight(rep)
		if rep.has("spouse"):
			saw[str(rep["spouse"]["chore"])] = true
	check(not saw.has("animals"), "spouse never feeds animals the farm doesn't have: %s" % str(saw.keys()))
	check(not saw.has("water"), "spouse never waters an empty field: %s" % str(saw.keys()))
	GameState.run["builds"]["barn"] = 1
	GameState.run["farm"] = {"3,3": {"crop": "turnip", "days": 0, "watered": false}}
	saw.clear()
	for i in 200:
		seed(900 + i)
		var rep2 := {}
		Romance.overnight(rep2)
		if rep2.has("spouse"):
			saw[str(rep2["spouse"]["chore"])] = true
	check(saw.has("animals") and saw.has("water"), "with a barn and a crop both chores come up: %s" % str(saw.keys()))
	# feed_all covers the roster, not only petted animals.
	Ranch._data = {"species": {"cow": {"name": "Cow", "home": "barn"}}, "buildings": {"barn": [{"tier": 1, "cap": 4}]}, "rules": {}, "products": {}, "processing": {}}
	Ranch.st()["houses"]["barn"] = {"tier": 1}
	var u := Ranch.add("cow")
	check(u != "" and Romance.feed_all(5) >= 1 and int(Ranch.animal(u)["last_fed"]) == 6, "spouse feeds every roster animal for tomorrow")
	_empty_ranch()

func _town() -> void:
	_fresh("penguins")
	var town: GDScript = load("res://scripts/town.gd")
	check(not town.contest_crop("egg") and not town.contest_crop("milk") and not town.contest_crop("sheep_wool"), "crop contest takes no animal goods")
	check(town.contest_crop("turnip"), "crop contest takes crops")
	# A lone gold egg scores its star (read before the count drops).
	GameState.add_item("egg", 1)
	GameState.run["quality"]["egg"] = {"g": 1, "s": 0}
	var qb: int = town.entry_quality("egg")
	check(qb == 20, "a lone gold egg scores the gold bonus (%d)" % qb)
	GameState.add_item("egg", 2)
	GameState.run["quality"]["egg"] = {"s": 1}
	check(int(town.entry_quality("egg")) == 10 and int(GameState.quality_of("egg").get("s", 0)) == 0, "the silver piece is the one entered")
	check(int(town.show_score_good("egg", 20)) > int(town.show_score_good("egg", 0)), "a starred egg scores higher at the show")
	# Animal Show scoring: a loved, happy animal beats a new one.
	_empty_ranch()
	Ranch._data = {"species": {"cow": {"name": "Cow", "home": "barn", "buy": {"price": 1500}}}, "buildings": {"barn": [{"tier": 1, "cap": 4}]}, "rules": {}, "products": {}, "processing": {}}
	Ranch.st()["houses"]["barn"] = {"tier": 1}
	var a := Ranch.add("cow")
	var b := Ranch.add("cow")
	Ranch.animal(a)["friend"] = 900
	Ranch.animal(a)["mood"] = 90
	check(int(town.show_score_animal(a)) > int(town.show_score_animal(b)) and int(town.show_score_animal(a)) > 100, "show score follows friendship and mood")
	check(town.SHOW.has("harvest") and town.SHOW.has("egg"), "Animal Show at the Harvest Fair, Best Egg at the Egg Festival")
	check(town.market_open("benno", 9 * 60 + 30) and not town.market_open("benno", 12 * 60) and town.market_open("hazel", 8 * 60), "market stalls open in the morning only")
	for ms: String in town.MARKET_STALLS:
		for it: Array in town.MARKET_STALLS[ms][5]:
			check(GameState.items.has(str(it[0])) and GameState.shop_price(str(it[0]), int(it[1])) >= GameState.item_value(str(it[0])), "%s stall: %s exists and never sells under its value" % [ms, it[0]])
	GameState.run["arc"] = "gangsters"
	check(str(town.show_title("harvest")) != "Animal Show", "gangster arc words the show its own way")
	_empty_ranch()

func _quests_perks() -> void:
	var q: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
	var need := {"hazel_eggs": "rmail_coop_1", "posy_eggs": "rmail_coop_1", "hazel_milk": "rmail_barn_1"}
	for x: Dictionary in q["side"]:
		if need.has(str(x["id"])):
			check(str((x["when"] as Dictionary).get("flag", "")) == str(need[str(x["id"])]), "%s waits for its building" % x["id"])
	var p: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/heart_perks.json"))
	check(str(p["tam"]["8"].get("flag", "")) == "tam_lamb", "Tam ♥8 perk is the lamb")
	check("2 Tea" in str(p["tam"]["4"]["text"]), "Tam ♥4 text matches its 2 tea leaves")
	check(not "llama" in str(p["benno"]["10"]["text"]).to_lower(), "Benno ♥10 no longer promises llama wool")
	var h: Dictionary = Hearts.data()["tam"]["milestones"]
	var t8 := ""
	for l: Dictionary in h["8"]:
		t8 += str(l.get("text", ""))
	check("barn" in t8 and "Animals page" in t8, "Tam ♥8 says where Bramble goes and how to name her")

func _ambience() -> void:
	check(Ambience.species_of("cow_brown_32_8") == "cow" and Ambience.species_of("calf") == "cow", "cow kinds")
	check(Ambience.species_of("kid_goat") == "goat" and Ambience.species_of("piglet") == "pig" and Ambience.species_of("rooster") == "rooster", "baby/rooster kinds")
	check(Ambience.species_of("chicken_white") == "chicken" and Ambience.species_of("biscuit") == "", "hens, and non-stock is skipped")
	var n1 := Node2D.new()
	var n2 := Node2D.new()
	var herd := {"cow": [n1], "goat": [n2, n2], "rooster": [n1]}
	var day := Ambience.pen_rules_for("farm", true, true, "day", "", herd)
	var sp := []
	for r: Array in day:
		sp.append(str(r[4]))
	check("cow" in sp and "goat" in sp and not "sheep" in sp, "pen spots follow the herd on the map: %s" % str(sp))
	check(Ambience.pen_rules_for("farm", true, true, "night", "", herd).is_empty(), "no pen calls outdoors at night")
	check(Ambience.pen_rules_for("farm", true, false, "day", "", herd).is_empty(), "no pen calls in a storm")
	check(Ambience.pen_rules_for("farm", true, true, "day", "", {}).is_empty(), "an empty farm is silent")
	var st := Ambience.pen_rules_for("interior", false, true, "night", "stable", {"horse": [n1]})
	check(st.size() == 1 and float(st[0][3]) < float(Ambience.PEN_SPOTS["horse"][3]), "the stable has a horse, quieter at night")
	check(Ambience.herd_on(Node2D.new()).is_empty(), "no animals on a bare map: no rooster")
	for k: String in Ambience.VOICE_FALLBACK:
		var v := str(Ambience.VOICE_FALLBACK[k])
		if v in ["oink", "buzz"]:
			continue  # recorded when a CC0 take is found (P5 report)
		check(ResourceLoader.exists("res://audio/sfx/%s.ogg" % v), "voice fallback %s -> %s exists" % [k, v])
	n1.free()
	n2.free()

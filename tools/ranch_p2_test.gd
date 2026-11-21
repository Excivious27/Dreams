extends SceneTree
## CONDUCT 11b P2: ranch care additions (headless, Ranch API only).
## Themed feeds (feed_item / feeds_on: hand-fed, never auto-fed, never resting all winter like bees),
## habitat comfort (classic species keep 20/5), variant names, lineage after a rehome, the hen's line
## through the incubator, expecting text, a show bump that isn't a pet, add-on installs, gift names,
## rare goods quality step and the pup's back time.
##   godot --headless --path . -s res://tools/ranch_p2_test.gd

var fails := 0


func _ok(cond: bool, what: String) -> void:
	if not cond:
		print("  FAIL ", what)
		fails += 1


func _initialize() -> void:
	seed(5)
	GameState.load_data()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["day"] = 3
	var D := Ranch.data()
	# A test creature that eats a themed feed and hates the heater.
	var sp: Dictionary = (Ranch.species("cow") as Dictionary).duplicate(true)
	sp["feed"] = ["moonberry_t", "#kelp"]
	sp["habitat"] = {"likes_season": ["winter"], "hates_heater": true, "needs_add": "tide_pool"}
	sp["names"] = ["Bramble", "Lumen", "Tidal"]
	D["species"]["test_moon"] = sp
	GameState.items["moonberry_t"] = {"name": "Moonberry", "type": "material", "value": 5}
	Ranch.house("barn")["tier"] = 3
	Ranch.house("coop")["tier"] = 2

	# Feeds.
	var u := Ranch.add("test_moon", "barn")
	_ok(u != "", "test creature added")
	_ok(str(Ranch.animal(u)["name"]) != "Bramble", "random names skip the gift name Bramble")
	_ok(Ranch.feed_item(u) == "moonberry_t", "feed_item is the themed feed (%s)" % Ranch.feed_item(u))
	_ok(Ranch.feeds_on(u, "moonberry_t") and Ranch.feeds_on(u, "sea_kelp") and not Ranch.feeds_on(u, "hay"), "feeds_on: list, tag, not hay")
	_ok(not Ranch.fed_today(u), "a themed eater is not auto-fed like bees")
	_ok(not Ranch.feed(u, "silo"), "the silo serves hay eaters only")
	_ok(Ranch.hint(u).contains("Moonberry"), "hungry hint names the feed (%s)" % Ranch.hint(u))
	GameState.add_item("moonberry_t", 2)
	var t := Ranch.tap(u, "moonberry_t")
	_ok(bool(t["fed"]) and Ranch.fed_today(u) and GameState.count("moonberry_t") == 1, "hand-fed with the held feed")
	var bee := Ranch.add("bees", "apiary") if Ranch.capacity("apiary") > 0 else ""
	if bee != "":
		_ok(Ranch.feed_item(bee) == "flowers" and not Ranch.eats(bee), "bees keep the flowers rule")

	# Comfort: classic numbers unchanged; habitat rules.
	var cow := Ranch.add("cow", "barn")
	_ok(Ranch.comfort(cow, false) == int(Ranch.rule("mood_comfort", 20)), "classic comfort unchanged")
	_ok(Ranch.comfort(u, false) == int(Ranch.rule("mood_comfort", 20)) - int(Ranch.rule("mood_comfort", 20)) + int(Ranch.rule("mood_winter_no_heater", 5)), "hates_heater with a heater: low comfort")
	_ok(Ranch.habitat_block(u) != "", "needs a tide pool: no goods (%s)" % Ranch.habitat_block(u))
	_ok(Ranch.habitat_text(u).contains("Tide Pool"), "habitat text")

	# Add-on install.
	GameState.items["tide_pool_kit"] = {"name": "Tide Pool Kit", "type": "material", "value": 5}
	GameState.add_item("tide_pool_kit", 1)
	_ok(Ranch.install("barn", "tide_pool_kit") == "", "install a tide pool")
	_ok(Ranch.has_add("barn", "tide_pool") and Ranch.habitat_block(u) == "", "installed add counts")

	# Variant names and rare quality.
	var h := Ranch.add("chicken", "coop")
	Ranch.animal(h)["variant"] = "golden"
	_ok(Ranch.is_rare(h) and Ranch.variant_name(h).to_lower().contains("golden"), "variant name (%s)" % Ranch.variant_name(h))
	_ok(Ranch.variant_name(cow) == Ranch.display_name("cow"), "common look is the species name")

	# The hen's line through the incubator.
	Ranch.animal(h)["ready"] = {"item": "egg", "n": 1, "q": ""}
	Ranch.take(h)
	_ok(Ranch.incubate("egg") == "", "egg into the incubator")
	var inc: Array = Ranch.house("coop")["incubator"]
	_ok(not inc.is_empty() and str(inc[-1].get("hen", "")) == h, "incubator row remembers the hen")
	inc[-1]["due"] = 3
	var before := Ranch.animals().size()
	Ranch.overnight({})
	_ok(Ranch.animals().size() == before + 1, "chick hatched")
	var chick := ""
	for k in Ranch.animals():
		if (Ranch.animal(str(k)).get("parents", []) as Array).has(h):
			chick = str(k)
	_ok(chick != "", "chick has the hen as parent")
	_ok(int(Ranch.family(chick)["gen"]) == 2, "gen 2")

	# Lineage survives a rehome.
	Ranch.animal(h)["born_day"] = -100
	_ok(Ranch.rehome(h), "rehome the hen")
	var fam := Ranch.family(chick)
	_ok(fam["parents"].size() == 1 and bool(fam["parents"][0]["rehomed"]) and str(fam["parents"][0]["name"]) != "?", "parent still listed after rehome")

	# Expecting text and the night-before line.
	var cow2 := Ranch.add("cow", "barn")
	Ranch.animal(cow)["expecting"] = {"due": int(GameState.run["day"]) + 2, "with": cow2}
	_ok(Ranch.expecting_text(cow).begins_with("Expecting with"), "expecting text (%s)" % Ranch.expecting_text(cow))
	_ok(Ranch.hint(cow).contains("expecting"), "hint shows expecting (%s)" % Ranch.hint(cow))
	var lines := Ranch.overnight({})
	var said := false
	for l in lines:
		said = said or str(l).contains("comes tonight")
	_ok(said, "night-before line")

	# Show bump is not a pet.
	Ranch.animal(cow2)["last_pet"] = -1
	var f0 := int(Ranch.animal(cow2)["friend"])
	_ok(Ranch.shown(cow2, 1).contains("proud"), "show line")
	_ok(int(Ranch.animal(cow2)["last_pet"]) == -1 and int(Ranch.animal(cow2)["friend"]) > f0, "show bumps friendship, leaves the pet")

	# Gift name clash.
	Ranch.rename(cow2, "Bramble")
	var g := Ranch.add("sheep", "barn", "Bramble")
	_ok(str(Ranch.animal(g)["name"]) == "Bramble II", "gift name clash adds II")

	# Egg lookup shared by every incubator.
	_ok(Ranch.egg_species("egg") == "chicken" and Ranch.egg_species("duck_egg") == "duck" and Ranch.egg_species("milk") == "", "egg_species")

	# Pup back time reads as a clock.
	var ps := Pet.state()
	ps["rest_until_abs"] = GameState.now_abs() + 720
	_ok(GameMenu.pup_back_text().contains("about"), "pup back text (%s)" % GameMenu.pup_back_text())

	print("ranch_p2_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

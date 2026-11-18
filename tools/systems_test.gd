extends SceneTree
## Settings, save slots and codes, quality crops, recipe discovery, heart perks,
## birthdays.   godot --headless --path . -s res://tools/systems_test.gd
var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	SaveGame.reset_cache()
	InputSetup.ensure_actions()
	# Settings
	Settings.set_v("btn_size", 2)
	Settings.set_v("left_handed", true)
	var br := Settings.button_at(Vector2(232, 398), 24.0)
	check(is_equal_approx(float(br[1]), 28.8) and is_equal_approx((br[0] as Vector2).x, 38.0), "button size and left-handed mirror")
	Settings.set_v("left_handed", false)
	Settings.set_v("btn_size", 1)
	Settings.set_v("music_vol", 3)
	check(AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) < -5.0, "music bus follows the volume setting")
	# Slots (clear 2 and 3 first: check.sh shares one user:// between runs)
	SaveGame.set_value(GameState.slot_key(2), {})
	SaveGame.set_value(GameState.slot_key(3), {})
	GameState.use_slot(1)
	GameState.new_run("penguins", "kairi", "Ann", "Town", "Pup")
	GameState.save()
	var code := GameState.export_code()
	GameState.use_slot(2)
	check(not GameState.has_run(), "slot 2 starts empty")
	check(GameState.import_code("nonsense") != "", "a bad code is refused")
	check(GameState.import_code(code) == "" and GameState.run["names"]["character"] == "Ann", "a save code loads into slot 2")
	GameState.run["names"]["character"] = "Bea"
	GameState.save()
	GameState.use_slot(1)
	check(GameState.has_run() and GameState.run["names"]["character"] == "Ann", "slot 1 kept its own farm")
	check(GameState.slot_info(2).begins_with("Bea"), "slot list shows slot 2 (%s)" % GameState.slot_info(2))
	check(GameState.slot_info(3) == "Empty", "slot 3 empty")
	# Quality
	GameState.add_item("turnip", 5)
	GameState.add_quality("turnip", "g", 2)
	GameState.add_quality("turnip", "s", 2)
	GameState.add_item("turnip", -2)
	var q := GameState.quality_of("turnip")
	check(int(q.get("g", 0)) == 2 and int(q.get("s", 0)) == 1, "using plain crops trims silver first (%s)" % str(q))
	var tq := GameState.take_quality("turnip", 3)
	check(int(tq["g"]) == 2 and int(tq["s"]) == 1, "selling takes gold first")
	check(GameState.quality_bonus_value({"turnip": {"g": 2, "s": 0}}) > 0, "quality pays a bonus")
	# Discovery
	var rc := {"id": "t_rc", "name": "T", "need": {"moon_shard": 1}, "give": "copper_bar", "tier": 3}
	check(not Crafting.discovered(rc), "unseen ingredient hides a tier-3 recipe")
	GameState.add_item("moon_shard", 1)
	GameState.add_item("moon_shard", -1)
	check(Crafting.discovered(rc), "holding the ingredient once reveals it")
	# Heart perks
	var before := GameState.count("copper_ring")
	GameState.add_friend("gideon", 160)
	check(GameState.count("copper_ring") == before + 1, "Gideon's ♥6 ring arrives once")
	GameState.add_friend("gideon", 5)
	check(GameState.count("copper_ring") == before + 1, "...and only once")
	var mana0 := int(GameState.run["max_mana"])
	GameState.add_friend("sel", 100)
	check(int(GameState.run["max_mana"]) >= mana0 + 10, "Sel's ♥4 mana bonus")
	GameState.add_friend("ivy", 200)
	check(Perks.flag("no_clinic_fee"), "Ivy's insurance flag")
	GameState.add_friend("wren", 100)
	GameState.run["day"] = 8
	var tea := GameState.count("energy_tea")
	Perks.morning()
	check(GameState.count("energy_tea") == tea + 2, "weekly delivery on day 8")
	# Birthdays
	var bd := GameState.birthday_of("maple")
	check(bd.size() == 2, "Maple has a birthday")
	var plain := GameState.gift_value("maple", "strawberry")
	var si := ["spring", "summer", "fall", "winter"].find(str(bd[0]))
	GameState.run["day"] = si * 28 + int(bd[1])
	check(GameState.is_birthday("maple") and GameState.gift_value("maple", "strawberry") == plain * 3, "birthday gifts count triple")
	# Endings slideshow, both arcs
	GameState.run["ending"] = "revert"
	GameState.run["decisions"]["tell_town"] = 0
	var sl := Epilogue.build()
	check(sl.size() >= 5 and str(sl[0][0]).contains("Two Crystals"), "penguin epilogue slides (%d)" % sl.size())
	GameState.new_run("gangsters", "dad", "Cal", "Town", "Pup")
	GameState.run["ending"] = "free"
	GameState.run["flags"]["crew_specs"] = true
	GameState.run["flags"]["lt_vance"] = true
	GameState.run["flags"]["lt_spared_vance"] = true
	var sg := Epilogue.build()
	var all_txt := ""
	for x in sg:
		all_txt += str(x[1])
	check(str(sg[0][0]).contains("A Tired Man") and all_txt.contains("Harbourmaster Vance walked away"), "gangster epilogue covers crew and lieutenants")
	# Ops: heists need their crew and chapter; missions gate the last loyalty step.
	check(not Ops.heist_ready("vault"), "vault waits for the chapter")
	GameState.run["flags"]["crew_sasha"] = true
	check(Ops.heist_ready("vault"), "vault ready with Specs and Sasha")
	GameState.run["crew"] = {"doc": 2}
	GameState.run["flags"]["crew_doc"] = true
	check(Ops.mission_open("doc"), "Doc's favour opens at loyalty 2")
	GameState.run["turf"] = {"docks": 1, "neon": 2}
	var g0 := int(GameState.run["crystals"])
	check(Ops.morning() == 80 and int(GameState.run["crystals"]) == g0 + 80, "two blocks pay every morning")
	check(Ops.holds("docks") and not Ops.holds("uptown"), "turf held per block")
	# Sun Haven trees: 4 x 10 per skill, the arc's own tree, leadership
	for sk in ["farming", "leadership", "strategist", "hustle", "harmony"]:
		check(GameState.nodes_of(sk).size() == 40, "%s has a 4x10 grid" % sk)
	check(GameState.skill_in_arc("hustle") and not GameState.skill_in_arc("harmony"), "gangster run shows Hustle, not Harmony")
	GameState.run["skills"]["leadership"]["level"] = 12
	check(GameState.node_locked("leadership", "leadership_3_2") != "", "tier III waits for 4 points")
	for i in 4:
		GameState.buy_node("leadership", "leadership_0_0" if i < 3 else "leadership_1_0")
	check(GameState.node_locked("leadership", "leadership_3_2") == "", "tier III opens after 4 points")
	check(GameState.bonus("combat", "block") <= 0.45, "stacking caps hold")
	# Mail: letters arrive, gifts and favours work
	GameState.new_run("penguins", "kairi", "Mo", "Town", "Pup")
	GameState.add_friend("maple", 60)
	var got := 0
	for dd in range(2, 30):
		GameState.run["day"] = dd
		got += Mail.morning()
	check(got >= 5, "mail arrives over a month (%d letters)" % got)
	var fav := {}
	var gif := {}
	for m: Dictionary in Mail.list():
		if str(m.get("kind", "")) == "favour" and fav.is_empty():
			fav = m
		if str(m.get("kind", "")) == "gift" and gif.is_empty():
			gif = m
	if not fav.is_empty():
		fav["until"] = 99
		fav["done"] = false
		GameState.add_item(str(fav["item"]), int(fav["n"]))
		var g1 := int(GameState.run["crystals"])
		check(Mail.act(fav) == "" and int(GameState.run["crystals"]) > g1, "a favour pays when you send the items")
	if not gif.is_empty():
		var c0 := GameState.count(str(gif["item"]))
		gif["got"] = false
		check(Mail.act(gif) == "" and GameState.count(str(gif["item"])) == c0 + 1, "a gift letter gives its item")
	Settings.set_v("music_vol", 8)
	print("systems_test: %d failures" % fails)
	quit()

extends SceneTree
## CONDUCT 12 P6: item, decor, ranch and UI words agree with the game state they
## describe, in both arcs. Every item has a line; plurals and Eat/Drink read right;
## menu paths and button words name the device's own buttons; decor lines are no
## longer shared boilerplate and the catalogue names real sources; creatures say
## where they come from in the arc's own words; the drill brief matches its steps.
##   godot --headless --fixed-fps 60 --path . -s res://tools/c12_items_ui_text_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		print("  FAIL " + what)
		fails += 1


func _initialize() -> void:
	seed(12)
	for arc: String in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi" if arc == "penguins" else "pax", "Hero", "Dreamhollow", "Biscuit")
		_items(arc)
		_words(arc)
		_decor(arc)
		_ranch(arc)
	print("c12_items_ui_text_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)


func _items(arc: String) -> void:
	var missing := 0
	for id: String in GameState.items:
		if str((GameState.items[id] as Dictionary).get("desc", "")).strip_edges() == "":
			missing += 1
	check(missing == 0, "%s: every item has a description (%d without)" % [arc, missing])
	check(ItemWords.count("Catfish", 3) == "3 Catfish", "fish keep their name: %s" % ItemWords.count("Catfish", 3))
	check(ItemWords.count("Spiced Loaf", 2) == "2 Spiced Loaves", "loaf -> loaves: %s" % ItemWords.count("Spiced Loaf", 2))
	check(ItemWords.count("Moon Fluff", 4) == "4 Moon Fluff", "fluff is a mass noun: %s" % ItemWords.count("Moon Fluff", 4))
	check(ItemWords.count("Barley", 3) == "3 Barley", "barley is a mass noun")
	check(ItemWords.count("Turnip", 3) == "3 Turnips", "plain plural still works")
	for id: String in ["milk", "potion", "coffee"]:
		if GameState.items.has(id):
			check(ItemWords.consume_verb(id) == "Drink", "%s is drunk, not eaten" % id)
	if GameState.items.has("bread"):
		check(ItemWords.consume_verb("bread") == "Eat", "bread is eaten")
	for id: String in GameState.items:
		var it: Dictionary = GameState.items[id]
		var ws := str(it.get("name", "")).to_lower().split(" ")
		if "wine" in ws or "ale" in ws or "mead" in ws or "cider" in ws:
			check(not (it.has("heal") or it.has("energy")), "%s: alcohol is never consumable" % id)
			check(str(it.get("desc", "")).contains("never drunk") or it.get("decor", false), "%s: trade-good line says never drunk (%s)" % [id, it.get("desc", "")])


func _words(arc: String) -> void:
	TouchControls.visible_controls = true
	check(PadInput.words("Spend them in Menu > Skills.") == "Spend them in MENU > Skills.", "%s: menu paths read one way on the phone" % arc)
	check(BattleBrief.controls_text().contains("USE on your banner") and BattleBrief.controls_text().contains("Tap HELPERS"), "%s: touch brief controls (%s)" % [arc, BattleBrief.controls_text()])
	TouchControls.visible_controls = false
	var menu_key := InputSetup.prompt("menu")
	check(PadInput.words("put it on your toolbar (MENU > Items).").contains("(%s > Items)" % menu_key), "%s: '(MENU' names the menu key on keys (%s)" % [arc, PadInput.words("(MENU > Items)")])
	check(PadInput.words("Spend them in Menu > Skills.").contains(menu_key + " > Skills"), "%s: 'Menu >' names the menu key on keys" % arc)
	check(not BattleBrief.controls_text().contains("USE ") and not BattleBrief.controls_text().contains("HELPERS (top left)"), "%s: keys brief controls name keys (%s)" % [arc, BattleBrief.controls_text()])
	check(not CasinoGame.howto_words("{A} hits, {X} stands, {Y} doubles your bet.").contains("{"), "casino how-to fills its buttons")
	check(CasinoGame.howto_words("{A} spins.").begins_with(InputSetup.prompt("a")), "casino {A} is the A key on keys")
	TouchControls.visible_controls = true
	check(CasinoGame.howto_words("{A} spins.") == "The gold button spins.", "casino {A} is the gold button on the phone")
	# The drill brief never names a step count the drill doesn't have.
	var win := str(BattleBrief.WIN["drill"])
	for w: String in ["two", "three", "four", "five", "six", "seven", "nine", "ten"]:
		check(not (" " + win + " ").contains(" " + w + " "), "drill brief has no wrong step count (%s)" % win)
	check(str(BattleDrill.SAY[6]).begins_with("One more order"), "drill: only the last step says 'Last'")
	# Achievements: hidden ones each tease their own secret.
	var hints := {}
	for a: Dictionary in GameState.load_json("res://data/achievements.json").get("list", []):
		if bool(a.get("hidden", false)):
			check(not hints.has(str(a["hint"])), "achievement %s: its own hint" % a["id"])
			hints[str(a["hint"])] = true


func _decor(arc: String) -> void:
	var boiler := ["Furniture for your house.", "A piece for the yard outside.", "Flooring for one room.", "Wallpaper for one room.",
		"One of a kind. There is only one in the whole valley.", "A keepsake from the museum and your collections.", "A hat. Looks only, no stats."]
	var counts := {}
	var gang_valley := 0
	for id: String in (Decor.data()["items"] as Dictionary):
		var e: Dictionary = Decor.entry(id)
		var d := str(e.get("desc", ""))
		check(not (d in boiler) and not d.begins_with("Part of the "), "%s: %s has its own line (%s)" % [arc, id, d])
		counts[d] = int(counts.get(d, 0)) + 1
		if str(e.get("arc", "")) == "gangsters" and d.to_lower().contains("valley"):
			gang_valley += 1
	check(counts.size() >= 400, "%s: decor lines are varied (%d distinct)" % [arc, counts.size()])
	check(gang_valley == 0, "%s: no gangster piece talks about the valley" % arc)
	for s: Dictionary in (Decor.data()["sets"] as Dictionary).values():
		check(str(s.get("name", "")).ends_with(" Set"), "set names read one way: %s" % s.get("name", ""))
	# Wardrobe flavour shows on the catalogue piece.
	var wr: Dictionary = GameState.load_json("res://data/wardrobe.json").get("items", {})
	for id: String in ["wr_beanie", "wr_farmer_clothes"]:
		if wr.has(id) and (Decor.data()["items"] as Dictionary).has(id):
			check(str(Decor.entry(id)["desc"]).begins_with(str(wr[id]["desc"]).strip_edges()), "%s: wardrobe line shows (%s)" % [id, Decor.entry(id)["desc"]])
	for id: String in (Decor.data()["items"] as Dictionary):
		check(not str(Decor.entry(id).get("name", "")).contains("(Look)"), "no (Look) tag: " + id)
	# Owned pieces say where they came from, in the arc's words.
	var id0 := "dc_u_lighthouse_lamp"
	if (Decor.data()["items"] as Dictionary).has(id0):
		DecorCatalogue.mark_seen(id0)
		check(DecorCatalogue.hint(id0) != "" and not DecorCatalogue.hint(id0).contains("Nobody knows"), "%s: a seen one-of-a-kind names its source (%s)" % [arc, DecorCatalogue.hint(id0)])


func _ranch(arc: String) -> void:
	var sp: Dictionary = Ranch.data().get("species", {})
	for sid: String in sp:
		var s: Dictionary = sp[sid]
		var src := str(s.get("source", ""))
		if src == "":
			continue
		check(not src.contains("(penguins)") and not src.contains("(gangsters)") and not src.contains("one per save"), "%s: source reads like a sentence (%s)" % [sid, src])
	if sp.has("komodo"):
		check(str(sp["komodo"].get("source_gang", "")).contains("Komodo") and not str(sp["komodo"].get("source_gang", "")).contains("Drake"), "komodo has its own gangster source line")
	for home: String in ["tide_pool", "star_dome", "barn", "coop"]:
		var w := TeamAnimals.home_word(home)
		check(w != "" and not w.contains("_"), "%s: home %s reads as a name (%s)" % [arc, home, w])
	check(not GameState.items.get("shed_scale", {}).get("desc", "").contains("drake"), "shed scale is arc-neutral")
	var tam: Dictionary = Ranch.data().get("sellers", {}).get("tam", {})
	if not tam.is_empty():
		check(str(tam.get("greet", "")) != str(tam.get("greet_gang", "")), "Tam has a gangster counter greeting")

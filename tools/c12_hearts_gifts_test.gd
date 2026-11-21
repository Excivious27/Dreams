extends SceneTree
## CONDUCT 12 P4: hearts, romance and gift words match the game state.
## Heart scenes pick the right variant (arc, partner), retold beats wait for the
## scene they retell, Juniper (engaged to Gideon in her arc) is not a candidate,
## locket/house refusals say the right thing, gift reactions follow tastes,
## story flags, arcs and birthdays, nobody takes ammo or counterfeit cash,
## crew have their own tastes and voices, and item words read as English.
##   godot --headless --fixed-fps 60 --path . -s res://tools/c12_hearts_gifts_test.gd
var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	seed(12)
	_run.call_deferred()

func _txt(lines: Array) -> String:
	var out := ""
	for l: Dictionary in lines:
		out += str(l.get("text", "")) + " | "
	return out

func _give_to(id: String, it: String) -> String:
	return GameState.gift_line(id, it, GameState.gift_value(id, it))

func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	var F: Dictionary = GameState.run["flags"]
	# --- heart scenes: one story, right arc, right state ---
	var H := Hearts.data()
	var all := JSON.stringify(H)
	check(not ("coast to mend" in all), "Mabel's father: one story (no coast)")
	check(not ("Theo doesn't count" in all), "Lumi: Alder looks at the corners")
	check(not ("tapping her pencil" in all), "Sel is 'they' in the heart narration")
	check(not ("into the chapel" in all), "Theo's fall line has no chapel (gangster arc has none)")
	check(H.has("tess") and (H["tess"]["milestones"] as Dictionary).size() == 5, "Tess has a heart arc")
	# Sel: penguin words in the penguin arc, a stranger on the road in the gangster arc.
	check("light came" in _txt(Hearts.scene_lines("sel", 8)), "Sel ♥8 penguin: the light came")
	# Tam/Sel ♥10: leaving town, unless you're their sweetheart.
	check("Going up" in _txt(Hearts.scene_lines("tam", 10)), "Tam ♥10 leaves when single")
	Romance.st()["dating"] = "tam"
	var tam := _txt(Hearts.scene_lines("tam", 10))
	check(not ("Going up" in tam) and "reason down here" in tam, "Tam ♥10 stays for his sweetheart")
	Romance.st()["dating"] = ""
	Romance.st()["spouse"] = "sel"
	check("not going anywhere" in _txt(Hearts.scene_lines("sel", 10)), "Sel ♥10 stays for their spouse")
	Romance.st()["spouse"] = ""
	# Granite ♥10 retells Mabel singing at the stone: it waits for Mabel ♥8.
	GameState.run["friendship"]["granite"] = 250
	for n in [2, 4, 6, 8]:
		F["hv_granite_%d" % n] = true
	check(Hearts.due("granite") == 0, "Granite ♥10 waits for Mabel ♥8")
	F["hv_mabel_8"] = true
	check(Hearts.due("granite") == 10, "Granite ♥10 plays after Mabel ♥8")
	# Ivy ♥8 retells Theo's miners' log: it waits for Theo ♥8.
	GameState.run["friendship"]["ivy"] = 210
	for n in [2, 4, 6]:
		F["hv_ivy_%d" % n] = true
	var iq := Hearts.quest6("ivy")
	F.erase("hv_theo_8")
	check(not Hearts._ready_for("ivy", 8), "Ivy ♥8 waits for Theo ♥8")
	F["hv_theo_8"] = true
	check(Hearts._ready_for("ivy", 8) or (iq != "" and not GameState.quest_done(iq)), "Ivy ♥8 ready after Theo ♥8")
	# --- romance ---
	check(not ("juniper" in Romance.candidates()), "Juniper is not a romance candidate (engaged to Gideon)")
	check(Romance.candidates().size() >= 8, "8+ candidates remain")
	var sh: Dictionary = Romance.data()["shared"]
	check(not ("Gideon" in str(sh["not_yet_house"])) and "Plans board" in str(sh["not_yet_house"]), "no Farmhouse from Gideon")
	check(not ("spring" in str(sh["wedding_intro"])), "the wedding fits any season")
	check((sh["too_soon"] as Array).size() == 1 and sh.has("too_soon_locket"), "bouquet/locket refusals apart")
	Romance.st()["dating"] = "lumi"
	GameState.run["friendship"]["lumi"] = 210
	check(Romance.propose_why("lumi") == "too_soon_locket", "locket below ♥10: the locket's words")
	Romance.st()["dating"] = ""
	for cid: String in Romance.data()["candidates"]:
		var c: Dictionary = Romance.cand(cid)
		check("Wood" in str(c["spouse"]["chore"]["fence"]), "%s fence chore names the Wood" % cid)
		check(str(c["spouse"].get("birthday", "")) != "", "%s has a spouse birthday line" % cid)
	# --- gift tastes ---
	check(GameState.gift_value("juniper", "coffee") < 0, "Juniper dislikes Coffee though she likes herbs")
	for id: String in ["tess", "catkins"]:
		check((GameState._gift_data()["lines"] as Dictionary).has(id), "%s has gift lines" % id)
	var bad_taste := 0
	for id: String in GameState.npcs:
		for k in ["likes", "dislikes"]:
			for e in GameState.npcs[id].get(k, []):
				var s := str(e)
				if s.begins_with("#") or GameState.items.has(s):
					continue
				var hit := false
				for it: String in GameState.items:
					if str(GameState.items[it].get("type", "")) == s:
						hit = true
						break
				if not hit:
					bad_taste += 1
					print("    taste points at nothing: ", id, " ", k, " ", s)
	check(bad_taste == 0, "every taste entry is an item, a type or a family (%d)" % bad_taste)
	check(GameState.gift_value("hazel", "goat_milk") >= 12 if GameState.items.has("goat_milk") else true, "Hazel likes goat milk")
	check(GameState.gift_value("tam", "yarn") >= 12, "Tam likes yarn")
	check(GameState.gift_value("benno", "horseshoe") >= 12, "Benno swears by horseshoes")
	check(GameState.gift_value("theo", "meat") >= 0, "Theo doesn't hate a bean ration")
	# --- gift lines follow the story ---
	check(not ("boss" in GameState.gift_line("sal", "apple", 25)), "Sal says no 'boss' in the penguin arc")
	F["museum_open"] = true
	check("glass case" in GameState.gift_line("pip", "apple", 25), "Pip's museum line after the museum opens")
	check(not ("There isn't one yet" in GameState.gift_line("pip", "apple", 25)), "no 'no museum yet'")
	F["hv_maple_6"] = true
	check(not ("fit right in" in GameState.gift_line("maple", "apple", 25)), "Maple isn't welcoming a friend of six hearts")
	# Birthdays: a neutral gift doesn't get the rapturous line.
	var found := false
	for d in range(1, 113):
		GameState.run["day"] = d
		if GameState.is_birthday("maple"):
			found = true
			break
	check(found, "found Maple's birthday")
	var plain := GameState.gift_line("maple", "stone", GameState.gift_value("maple", "stone"))
	check(plain.contains("it's the thought"), "Stone on Maple's birthday is the plain line: %s" % plain)
	GameState.run["day"] = 1
	# Wine is a trade good: no villager cooks or drinks it.
	var drink := RegEx.new()
	drink.compile("(?i)\\b(stew|cook|drink|sip|toast|cheers|glass of)\\b")
	var bad_drink := 0
	for wi in ["wine", "fine_wine", "fruit_wine", "harvest_ale", "corn_ale", "flower_mead", "cider", "starlight_wine", "strawberry_wine"]:
		if not GameState.items.has(wi):
			continue
		for id: String in GameState.npcs:
			var l := _give_to(id, wi)
			if drink.search(l) != null:
				bad_drink += 1
				print("    ", id, " + ", wi, ": ", l)
	check(bad_drink == 0, "no gift line cooks or drinks alcohol (%d)" % bad_drink)
	# --- item words ---
	check(ItemWords.with_article("Jar of Honey") == "a Jar of Honey", "a Jar of Honey")
	check(ItemWords.count("Pot of Chili", 3) == "3 Pots of Chili", "3 Pots of Chili")
	check(ItemWords.with_article("Fine Wine") == "some Fine Wine", "some Fine Wine")
	check(ItemWords.count("Yarn", 3) == "3 Yarn", "3 Yarn")
	check(GameState.with_article("Lotus", true) == "A Lotus", "A Lotus (one rule)")
	check(GameState.articled("A Crystal Lens! Thanks.", "Crystal Lens") == "A Crystal Lens! Thanks.", "no 'Some Crystal Lens'")
	# --- who can take a gift ---
	GameState.add_item("apple", 1)
	check(not GameState.can_gift("mg_liesl", "apple"), "a mega-region local just chats")
	check(GameState.can_gift("maple", "apple"), "Maple can take an apple")
	check(Hearts.scene_lines("tess", 2).size() >= 2, "Tess ♥2 scene")
	# --- gangster arc ---
	GameState.new_run("gangsters", "kairi", "T", "Town", "Pup")
	F = GameState.run["flags"]
	Crew._data = {}
	Crew.data()
	check("stranger" in _txt(Hearts.scene_lines("sel", 8)), "Sel ♥8 gangster: a stranger came")
	check(not ("your field" in Hearts.daily("sel") if Hearts.seen_level("sel") >= 6 else false), "Sel daily line in the gangster arc")
	if GameState.items.has("rounds"):
		GameState.add_item("rounds", 5)
		check(not GameState.can_gift("pip", "rounds"), "nobody takes ammo")
	if GameState.npcs.has("mama_rosa"):
		check(GameState.gift_value("mama_rosa", "turnip") > 0, "Mama Rosa (a cook) likes vegetables")
		check(not ("favourite thing" in _give_to("deuce", "coffee")), "Deuce answers in his own voice")
		check(_give_to("mama_rosa", "turnip").begins_with("A Turnip"), "Mama Rosa's line: %s" % _give_to("mama_rosa", "turnip"))
	F["sal_recruited"] = true
	check("boss" in GameState.gift_line("sal", "apple", 25), "Sal says 'boss' once he's crew")
	var gem := 0
	for id: String in GameState.npcs:
		for h: String in GameState.npcs[id].get("perks", {}):
			if "◆" in Money.t(GameState.friend_perk_at(id, int(h))):
				gem += 1
	check(gem == 0, "perk texts show cash in the gangster arc (%d)" % gem)
	check(not ("_" in RanchGift._home_word("tide_pool")), "home words, not ids: %s" % RanchGift._home_word("tide_pool"))
	print("c12_hearts_gifts_test: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

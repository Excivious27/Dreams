extends SceneTree
## CONDUCT 12 P5: mail, side stories and quest text match the game state they talk about.
## Favour letters (money words per arc, item words, kids' own template), festival-eve lines
## only for farms with animals (Bram's egg table once Posy has gone), the collectors letter
## (Sal until Ladder is crew, laundromat only once built, once per heat spike), the storm
## letter naming only homes that exist, Posy-gone ranch/collection letters, Tam away in the
## highlands (not in town, no favours, the lamb letter), gangster note pools, decor notes,
## side-story done hints / journal pruning / Quests-tab lines, quest log texts (where items
## really come from) and no real-world calendar words in quest/side-story/commons text.
##   godot --headless --fixed-fps 60 --path . -s res://tools/c12_mail_quests_test.gd
var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	seed(12)
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
	Ranch._data = {"species": {}, "buildings": {}, "rules": {}, "products": {}, "processing": {}}
	Mail.list().clear()

func _run() -> void:
	Mail._morning_post = true  # no toasts outside a map
	for arc: String in ["penguins", "gangsters"]:
		_mail(arc)
		_tam(arc)
	_heat()
	_side_stories()
	_quest_text()
	print("c12_mail_quests_test: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

func _mail(arc: String) -> void:
	_fresh(arc)
	var pen := arc == "penguins"
	var fl: Dictionary = GameState.run["flags"]
	# Favours: no ◆ in the gangster arc, item words, kids ask in their own words.
	var ft := Mail.favour_text("maple", "egg", 3, 52, 4)
	check(("$52" in ft) if not pen else ("52 crystals" in ft), arc + ": favour pay through Money.amount: " + ft)
	check(not ("◆" in ft) and "3 Eggs" in ft, arc + ": favour text has item words, no raw symbol: " + ft)
	var kt := Mail.favour_text("pip", "egg", 2, 25, 4)
	check(kt.begins_with("Can you get me") and "saved up" in kt, arc + ": kids write their own favour letter: " + kt)
	# Festival eve: no animal lines without animals; Bram's egg table once Posy's gone.
	check(Mail.show_line("harvest") == "" and Mail.show_line("egg") == "", arc + ": no show lines without animals")
	GameState.run["builds"]["coop"] = 1
	check("Benno" in Mail.show_line("harvest") and not ("Block Fair" in Mail.show_line("harvest")), arc + ": harvest show line, no invented fair name")
	check("Posy" in Mail.show_line("egg"), arc + ": Posy's egg table")
	fl["posy_gone"] = true
	check("Bram" in Mail.show_line("egg") and not ("Posy" in Mail.show_line("egg")), arc + ": Bram runs the egg table once Posy has gone")
	# Storm letter names only the coop.
	var sa := Mail._storm_animals()
	check("coop" in sa and not ("barn" in sa), arc + ": storm letter, coop only: " + sa)
	# Ranch letters with Posy gone: the Big Coop letter and the first egg come from someone in town.
	GameState.run["builds"]["coop"] = 2
	fl["rmail_coop_1"] = 1
	Mail._ranch_mail(20)
	check(fl.has("rmail_coop_2") and not ("Posy" == str(Mail.list()[-1].get("from", ""))), arc + ": Big Coop letter not from the departed Posy: " + _texts())
	Mail.list().clear()
	GameState.add_item("egg", 1)
	Mail._ranch_mail(21)
	check(fl.has("rmail_first_egg") and not ("Posy" in _texts().split(":")[0]) and not ("bakery" in _texts()), arc + ": first-egg letter not from Posy: " + _texts())
	# Gangster coop letter: no "Told you" without Benno's lead letter.
	if not pen:
		_fresh(arc)
		GameState.run["builds"]["coop"] = 1
		Mail._ranch_mail(4)
		check(not ("Told you" in _texts()) and "hens" in _texts(), "gangsters: coop letter without the lead letter: " + _texts())
	# Collections: cooking milestones from Bram once Posy's gone; forage from a real villager.
	for m: Dictionary in Collections.data().get("milestones", []):
		if str(m.get("cat", "")) == "cooking":
			check(str(m.get("from_alt", "")) == "bram", arc + ": cooking milestone %s has Bram's fallback" % str(m["id"]))
		check(GameState.npcs.has(str(m.get("from", "theo"))) or str(m.get("from", "")) in ["sel", "marlowe", "granite", "catkins", "old_moss", "rook", "orla"], arc + ": milestone sender %s is a villager" % str(m.get("from", "")))
	# Note pools: the gangster arc never gets the cosy penguin chatter; decor gifts get decor notes.
	_fresh(arc)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var seen := ""
	for i in 60:
		seen += Mail._pick_line("maple", Mail.CHAT_NOTES, rng) + "|" + Mail._pick_line("hazel", Mail.GIFT_NOTES, rng) + "|"
	if not pen:
		check(not ("kettle" in seen) and not ("bent turnip" in seen) and not ("made me think of your farm" in seen), "gangsters: no cosy penguin notes")
	else:
		check("kettle" in seen or "flowers on the fountain" in seen, "penguins: the town pool still runs")
	check(not ("cow is purple" in str(Mail.CHAT_NOTES["#kid"])), arc + ": kids don't draw a cow the farm may not have")
	var dn := Mail._decor_note(rng)
	check(dn in (Mail.DECOR_NOTES if pen else Mail.DECOR_NOTES_GANG), arc + ": decor gift note from the decor pool")
	# Season-end letter is signed and tagged.
	GameState.run["day"] = 25
	Mail._news(rng)
	var hz := ""
	for m: Dictionary in Mail.list():
		if str(m.get("from", "")) == "Hazel":
			hz = str(m["text"]) + "#" + str(m.get("npc", ""))
	check(hz.contains("- Hazel#hazel"), arc + ": season-end letter signed by Hazel: " + hz)

func _tam(arc: String) -> void:
	_fresh(arc)
	var fl: Dictionary = GameState.run["flags"]
	GameState.run["friendship"]["tam"] = 500
	check(GameState.npc_present("tam") and "tam" in Mail._known(), arc + ": Tam in town before ♥10")
	fl["hv_tam_8"] = true
	fl["hv_tam_10"] = true
	check(Mail.tam_away() and not GameState.npc_present("tam") and not ("tam" in Mail._known()), arc + ": Tam away in the highlands: not in town, no favours")
	Mail._tam_highlands(10)
	Mail._tam_highlands(17)
	Mail._tam_highlands(24)
	check("Benno's watching her" in _texts(), arc + ": letter 2 knows Bramble is still at the hut: " + _texts())
	# The lamb arrives while he's away: Benno walked her up.
	Ranch._data = {"species": {"sheep": {"name": "Sheep", "home": "barn", "product": {"id": "sheep_wool"}}},
		"buildings": {"barn": [{"tier": 1, "cap": 4}]}, "rules": {}, "products": {}, "processing": {}}
	Ranch.st()["houses"]["barn"] = {"tier": 1}
	Mail.list().clear()
	Mail._tam_lamb(25)
	check("Benno" in _texts() and not ("first light" in _texts()), arc + ": Bramble walked up by Benno while Tam's away: " + _texts())

func _heat() -> void:
	_fresh("gangsters")
	var fl: Dictionary = GameState.run["flags"]
	var rng := RandomNumberGenerator.new()
	Racket.set_heat(4)
	for i in 10:
		rng.seed = i
		Mail._heat_letter(rng)
	check(Mail.list().size() == 1 and str(Mail.list()[0]["from"]) == "Sal", "collectors letter from Sal before Ladder is crew, once per spike: " + _texts())
	Racket.set_heat(1)
	Mail._heat_letter(rng)
	check(not fl.has("heat_mail"), "heat dropped: the spike flag clears")
	Mail.list().clear()
	fl["crew_ladder"] = true
	Mail.send_heat_letter()
	check("Ladder" in _texts() and not ("laundromat" in _texts()), "Ladder doesn't send you to a laundromat you haven't built")
	_fresh("penguins")
	Mail._heat_letter(rng)
	check(Mail.list().is_empty(), "no collectors in the penguin arc")

func _side_stories() -> void:
	for c: Dictionary in SideStory.chains():
		var steps: Array = c["steps"]
		for i in steps.size():
			var st: Dictionary = steps[i]
			if st.has("need") and i < steps.size() - 1:
				var nxt := str(steps[i + 1].get("giver", ""))
				var who := str(GameState.npcs.get(nxt, {}).get("name", Crew.members().get(nxt, {}).get("name", "")))
				check(str(st.get("done_hint", "")) != "" and (who == "" or who in str(st["done_hint"])), "%s step %d: done_hint names the next giver %s" % [c["id"], i, who])
		var all := JSON.stringify(c)
		for bad in ["Maple keeps it", "Ivy at the bank", "Saturday", "at the workshop", "stand with you now", "By the stone", "the stone chose"]:
			check(not (bad in all), "%s: no stale/false line '%s'" % [c["id"], bad])
	# Journal: a chain keeps one line; after the hand-in the ask is replaced.
	_fresh("penguins")
	var coldy: Dictionary = {}
	for c: Dictionary in SideStory.chains():
		if str(c["id"]) == "coldy_key":
			coldy = c
	GameState.add_hint("Some other tip.")
	SideStory._hint(coldy, coldy["steps"][0])
	SideStory._hint(coldy, coldy["steps"][1])
	var hs: Array = GameState.run["hints"]
	var n := 0
	for h in hs:
		if str(h).begins_with("Coldy's key: "):
			n += 1
	check(n == 1 and str(hs[-1]).contains("Old Coins") and "Some other tip." in hs, "one journal line per chain, other tips kept: %s" % str(hs))
	SideStory._hint(coldy, {"hint": str(coldy["steps"][1]["done_hint"])})
	check(str(GameState.run["hints"][-1]).contains("Alder") and not str(GameState.run["hints"]).contains("Bring Theo"), "after the hand-in the journal names Alder, not the coins")
	# Quests tab lines: only started, unfinished chains; a need step says what to bring.
	check(SideStory.open_lines().is_empty(), "no side-story lines before any chain starts")
	var fl: Dictionary = GameState.run["flags"]
	fl["st_p3_coldy"] = true
	fl["ss_coldy_key_0"] = true
	var ol := SideStory.open_lines()
	var row: Dictionary = {}
	for r: Dictionary in ol:
		if str(r["id"]) == "coldy_key":
			row = r
	check(not row.is_empty() and str(row["giver"]) == "theo" and "Theo" in str(row["text"]), "Quests tab: Coldy's key points at Theo: %s" % str(row))
	fl["ss_coldy_key_1_asked"] = true
	row = SideStory.open_lines().filter(func(r: Dictionary) -> bool: return str(r["id"]) == "coldy_key")[0]
	check(str(row["text"]) == "Bring Theo 2 Old Coins.", "Quests tab: the ask with item words: %s" % str(row["text"]))
	fl["ss_coldy_key_1"] = true
	fl["ss_coldy_key_2"] = true
	fl["ss_coldy_key_done"] = true
	check(SideStory.open_lines().filter(func(r: Dictionary) -> bool: return str(r["id"]) == "coldy_key").is_empty(), "a finished chain leaves the Quests tab")

func _quest_text() -> void:
	_fresh("penguins")
	var need := Quests._still_need({"done_when": {"item": ["old_coin", 3]}})
	check(need == "3 Old Coins", "quest reminder uses item words: " + need)
	var q := GameState.load_json("res://data/quests.json")
	var by := {}
	for k in q:
		if q[k] is Array:
			for d in q[k]:
				if d is Dictionary:
					by[str(d.get("id", ""))] = d
	check(not ("lake" in str(by.get("finn_pearl", {}).get("text", ""))), "pearl quest doesn't send you to the lake")
	check(not ("from the mine" in str(by.get("rook_bones", {}).get("text", ""))) and "pup" in str(by.get("granite_bones", {}).get("text", "")), "bone quests point at the pup's digging")
	check("2 jars" in str(by.get("juniper_honey", {}).get("text", "")), "Juniper's honey log has the count")
	for id in ["rec_bowl_120", "rec_pip_jumper", "rec_maple_league", "rec_alder_cabinets"]:
		check("Rec Hall" in str(by.get(id, {}).get("text_gangsters", "")), "%s has a Rec Hall text for the gangster arc" % id)
	check(not ("ribbon twice" in str(by.get("rec_alder_cabinets", {}))), "Alder's cabinet quest reads cleanly")
	var ql := GameState.load_json("res://data/quest_lines.json")
	check(str(ql.get("rec_wren_jr_duck@gangsters", {}).get("yes", "")).contains("targets"), "gangster Neon Range tip says targets, not ducks")
	# No weekdays, months or real years in quest, side-story or commons text.
	var re := RegEx.create_from_string("\\b(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|January|February|March|June|July|August|September|October|November|December|1[89][0-9][0-9])\\b")
	for f in ["res://data/quest_lines.json", "res://data/side_stories.json", "res://data/community_farm.json"]:
		var txt := FileAccess.get_file_as_string(f)
		var hit := re.search(txt)
		check(hit == null, "%s has no calendar words (%s)" % [f, hit.get_string() if hit else ""])
	# Emberclaw kit asks for what the quest needs.
	var cols := FileAccess.get_file_as_string("res://data/colonies.json")
	check(cols.contains("two ember glass and six coal") and not cols.contains("ten stone and three coal"), "Cooling Stones asks for what it needs")

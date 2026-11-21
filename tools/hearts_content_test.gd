extends SceneTree
## CONDUCT 7 P4: villager hearts, letters, board and talk text.
## Heart scenes are staged (♥8/♥10 have an opening and a close), Catkins has a
## penguin-only arc, items read as English ("3 Turnips", "an Apple"), favour
## letters ask for things you can get, mid-day letters say so, the mailbox cap
## never eats an unread letter or untaken gift, and the drink/coin/bell slips stay fixed.
##   godot --headless --path . -s res://tools/hearts_content_test.gd
var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	seed(7)
	_run.call_deferred()

func _texts(l: Array) -> String:
	var out := ""
	for x: Dictionary in l:
		out += str(x.get("text", "")) + " | " + str(x.get("text_gangsters", "")) + " | "
	return out

func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	# --- heart scenes ---
	var H := Hearts.data()
	check(H.size() == 27, "27 heart arcs (%d)" % H.size())
	for id: String in H:
		var ms: Dictionary = H[id]["milestones"]
		for n in ["2", "4", "6", "8", "10"]:
			check(ms.has(n) and (ms[n] as Array).size() >= 2, "%s ♥%s has a scene" % [id, n])
			check(ms.has(n) and str((ms[n] as Array)[0].get("who", "x")) == "", "%s ♥%s opens with narration" % [id, n])
		for n in ["8", "10"]:
			check((ms[n] as Array).size() >= 4, "%s ♥%s is staged (%d lines)" % [id, n, (ms[n] as Array).size()])
		for n in ms:
			for l: Dictionary in ms[n]:
				check(str(l.get("text", "")).length() <= 300, "%s ♥%s line fits the box" % [id, n])
		check(GameState.npcs.has(id), "%s is a villager" % id)
	check(H.has("catkins") and str(H["catkins"].get("arc", "")) == "penguins", "Catkins has a penguin heart arc")
	# Wine is a trade good: nobody drinks it in a heart scene.
	var all := ""
	for id: String in H:
		for n in H[id]["milestones"]:
			all += _texts(H[id]["milestones"][n])
	var bram8 := ""
	for l: Dictionary in H["bram"]["milestones"]["8"]:
		bram8 += str(l.get("text", ""))
	check(not ("Two wine" in all) and not ("glass" in bram8), "Bram's penguin ♥6/♥8 keep the wine unopened")
	check(not ("never told her mother" in all), "Wren is Wren jr's mother (♥8)")
	check(not ("in the other way" in all), "Juniper ♥2 reads cleanly")
	check("dark lamp" in _texts(H["ivy"]["milestones"]["8"]), "Ivy ♥8 has a gangster line")
	# Gideon/Bram ♥10 'if_gone' lines still sit on the right lines.
	check((H["gideon"]["milestones"]["10"][1] as Dictionary).has("if_gone") and (H["bram"]["milestones"]["10"][1] as Dictionary).has("if_gone"), "if_gone lines on the spoken lines")
	# One scene per talk, and Catkins' plays in her arc.
	GameState.run["friendship"]["catkins"] = 250
	check(Hearts.due("catkins") == 2, "Catkins ♥2 due at 10 hearts")
	# --- item words ---
	check(ItemWords.with_article("Apple") == "an Apple", "an Apple")
	check(ItemWords.with_article("Carrot") == "a Carrot", "a Carrot")
	check(ItemWords.with_article("Turnip Seeds") == "some Turnip Seeds", "some Turnip Seeds")
	check(ItemWords.with_article("Honey") == "some Honey", "some Honey")
	check(ItemWords.with_article("Crystal Lens") == "a Crystal Lens", "a Crystal Lens")
	check(ItemWords.count("Turnip", 3) == "3 Turnips", "3 Turnips")
	check(ItemWords.count("Turnip", 1) == "1 Turnip", "1 Turnip")
	check(ItemWords.count("Strawberry", 4) == "4 Strawberries", "4 Strawberries")
	check(ItemWords.count("Wood", 4) == "4 Wood", "4 Wood")
	check(ItemWords.count("Potato", 2) == "2 Potatoes", "2 Potatoes")
	check(ItemWords.count("Bass", 2) == "2 Bass", "2 Bass")
	check(ItemWords.fill("A {item}! You remembered!", "Apple") == "An Apple! You remembered!", "gift line article")
	check(ItemWords.fill("Oh. A {item}.", "Turnip Seeds") == "Oh. Some Turnip Seeds.", "gift line plural")
	for id: String in ["maple", "gideon", "marlowe", "pip"]:
		for g in [25, 14, 5, -5]:
			var line := GameState.gift_line(id, "apple", g)
			check(not ("A Apple" in line) and not ("a Apple" in line), "%s gift line says an Apple: %s" % [id, line])
	# --- talk / intros ---
	var talk: Dictionary = GameState.load_json("res://data/talk.json")
	var ts := JSON.stringify(talk)
	check(not ("cider" in ts.to_lower()) and not ("at my bar" in ts), "no drinks served in talk")
	check(not ("coins in my sleep" in ts), "Ivy counts the arc's money")
	check(not ("rang the town bell" in ts), "Pip never rang the silent bell")
	check(not ("forty years" in ts.to_lower()), "Marlowe's thirty years")
	GameState.run["arc"] = "gangsters"
	var gl: Array = Intros.LINES["gideon"].get("gang", [])
	check(not gl.is_empty() and not ("crystals" in str(gl)), "Gideon's gangster intro pays cash")
	GameState.run["arc"] = "penguins"
	# --- mail ---
	GameState.run["day"] = 3 * GameState.DAYS_PER_SEASON + 5
	check(GameState.season() == "winter", "test day is winter (%s)" % GameState.season())
	var rng := RandomNumberGenerator.new()
	var asked := {}
	for who: String in GameState.npcs:
		for i in 25:
			rng.seed = i * 31 + who.hash()
			var it := Mail._favour_item(who, rng)
			if it != "":
				asked[it] = true
	for it: String in asked:
		check(GameState.crop_in_season(it), "winter favour asks for in-season %s" % it)
	check(not asked.has("sheep_wool") and not asked.has("honey"), "no wool/honey asked for without sheep or hive")
	# Mid-day letters announce themselves; morning post doesn't add notes.
	GameState.run["notes"] = []
	Mail.send("Granite", "Floor 100!")
	check((GameState.run["notes"] as Array).size() == 1, "mid-day letter shows a note")
	GameState.run["notes"] = []
	Mail.morning()
	check((GameState.run["notes"] as Array).is_empty(), "morning post adds no notes")
	# Cap: an unread letter and an untaken gift survive a full box.
	GameState.run["mail"] = []
	Mail.send("Posy", "keep me", "gift", {"item": "bread", "n": 1, "read": true}, false)
	Mail.send("Maple", "unread", "chat", {}, false)
	for i in 40:
		Mail.send("Alder", "read %d" % i, "news", {"read": true}, false)
	var texts: Array = []
	for m: Dictionary in Mail.list():
		texts.append(str(m["text"]))
	check("keep me" in texts and "unread" in texts, "cap keeps the untaken gift and the unread letter")
	check(Mail.list().size() == Mail.MAX_KEEP, "cap holds at %d (%d)" % [Mail.MAX_KEEP, Mail.list().size()])
	# Story letters spell neighbour; birthday tips come from someone you know.
	var sd := JSON.stringify(Mail.story_due())
	check(not ("neighbor," in sd), "neighbour spelling")
	GameState.run["friendship"] = {"maple": 30}
	check(Mail._birthday_tipster("gideon") == "maple" or Mail._birthday_tipster("gideon") == "", "birthday tip from a known villager")
	check(Mail._birthday_tipster("maple") != "maple", "nobody tips you off about themselves")
	# --- side stories ---
	_side_stories()
	print("hearts_content_test: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)


func _side_stories() -> void:
	var cs := SideStory.chains()
	check(cs.size() == 11, "7 story side stories + 4 seasonal (C15 P3) (%d)" % cs.size())
	var story: Dictionary = GameState.load_json("res://data/story.json")
	var beat_flags := {"boss_wastes": true}
	for arc in ["penguins", "gangsters"]:
		for ch: Dictionary in story.get(arc, []):
			for b: Dictionary in ch.get("beats", []):
				beat_flags["st_" + str(b.get("id", ""))] = true
	for c: Dictionary in cs:
		if c["when"].has("season"):  # C15 P3 seasonal chains: both arcs, 2 scenes in their season
			check(str(c.get("arc", "")) == "" and (c["steps"] as Array).size() >= 2, "%s seasonal chain: both arcs, 2+ scenes" % c["id"])
		else:
			check(beat_flags.has(str(c["when"].get("flag", ""))), "%s starts on a real flag" % c["id"])
			check((c["steps"] as Array).size() >= 3, "%s has 3+ scenes" % c["id"])
		for st: Dictionary in c["steps"]:
			var g := str(st["giver"])
			check(GameState.npcs.has(g) or Crew.members().has(g), "%s giver %s exists" % [c["id"], g])
			for k in ["need", "give"]:
				if st.has(k):
					check(GameState.items.has(str(st[k][0])), "%s %s item %s exists" % [c["id"], k, st[k][0]])
			if st.has("choice"):
				var o: Array = st["choice"]["options"]
				check(Dialogue.is_way_out(str(o[o.size() - 1])), "%s choice has a way out" % c["id"])
	# Gating: penguin chains wait for their story flag, one step a day, givers in order.
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	check(SideStory.due("granite").is_empty(), "Big Jim's brother waits for the campfire")
	GameState.run["flags"]["st_p3_campfire"] = true
	var d := SideStory.due("granite")
	check(not d.is_empty() and str(d[0]["id"]) == "jim_brother" and int(d[1]) == 0, "Granite starts Big Jim's brother")
	check(SideStory.due("sel").is_empty(), "Sel's step waits for Granite's")
	GameState.run["flags"]["ss_jim_brother_0"] = true
	GameState.run["flags"]["ss_jim_brother_day"] = int(GameState.run["day"])
	check(SideStory.due("sel").is_empty(), "next scene waits for tomorrow")
	GameState.run["day"] = int(GameState.run["day"]) + 1
	check(not SideStory.due("sel").is_empty(), "Sel's step is due the next day")
	check(SideStory.due("mama_rosa").is_empty(), "gangster chains stay out of the penguin arc")
	check(SideStory.progress()[1] == 8, "4 penguin side stories + 4 seasonal (%d)" % SideStory.progress()[1])

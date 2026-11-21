extends SceneTree
## CONDUCT 12 P2: gangster main story text matches game state. Story line key
## "if_loyalty" (finale crew payoffs only after their loyalty scene), crew
## everyday lines gated on loyalty and the ending, joined Marked/lieutenant lines
## after the tower, bill-caught lines by place (no town shopkeeper at the docks,
## no "$0"), cash-arc choice labels and toasts without the crystal sign, ending
## slides that agree with the ending (crew threads, Hale, The Chair), and the
## story wording fixes (no "Mr President", no indoor lobby, the photo payoff).
## Run: godot --headless --fixed-fps 60 --path . -s res://tools/c12_gang_story_test.gd
var fails := 0


func _initialize() -> void:
	seed(12)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _beat(id: String) -> Dictionary:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/story_gang.json"))
	for ch in d["gangsters"]:
		for b in ch["beats"]:
			if str(b["id"]) == id:
				return b
	return {}


func _texts(lines: Array) -> String:
	var out := PackedStringArray()
	for l in lines:
		out.append(str(l.get("text", "")))
		for k in (l as Dictionary).get("branches", {}):
			out.append(_texts(l["branches"][k]))
	return "\n".join(out)


func _branch(beat: String, key: String) -> Array:
	for l in _beat(beat)["lines"]:
		if (l as Dictionary).has("branches"):
			return l["branches"].get(key, [])
	return []


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("gangsters", "june", "Hero", "Dreamhollow", "Biscuit")
	var fl: Dictionary = GameState.run["flags"]

	# --- if_loyalty: finale payoffs wait for the scene that set them up ----------
	var b0 := _branch("g5_win", "0")
	fl["crew_the_kid"] = true
	fl["crew_val"] = true
	fl["crew_specs"] = true
	var t := _texts(Story._fill(b0))
	check(t.find("cleaner's uniform") < 0, "The Kid's sister stays out at loyalty 0")
	check(t.find("Our brother") < 0, "Val's brother stays out at loyalty 0")
	check(t.find("go for the wire") < 0, "Specs' wire stays out at loyalty 0")
	Crew._set_loyalty("the_kid", 2)
	Crew._set_loyalty("val", 2)
	Crew._set_loyalty("specs", 3)
	t = _texts(Story._fill(b0))
	check(t.find("cleaner's uniform") >= 0 and t.find("Our brother") >= 0 and t.find("go for the wire") >= 0, "payoffs play once their loyalty scenes were seen")
	check(not Story.loyalty_ok(["dice", 0]), "if_loyalty needs the member recruited")
	var clean := _texts(_branch("g5_win_clean", "2"))
	check(clean.find("cleaner's uniform") >= 0 and clean.find("bus shelter") >= 0, "Clean Break carries the crew payoffs too")
	check(clean.find("sent home") >= 0, "Clean Break names the Marked condition")
	check(_texts(_beat("g4_hale")["lines"]).find("Send them home") >= 0, "Hale asks for the Marked to be sent home before the end")
	# The voice the player heard: "good, count it" only after taking Lumi's studio.
	var intro: Array = _beat("g5_win")["lines"].slice(0, 4)
	t = _texts(Story._fill(intro))
	check(t.find("good, count it") < 0 and t.find("counted every step") < 0, "no 'count it' voice for a player who never took a shop")
	fl["dark_shop_2"] = true
	fl["dark_shop_1"] = true
	t = _texts(Story._fill(intro))
	check(t.find("good, count it") >= 0 and t.find("counted every step") >= 0, "the counting voice comes back for a shop-taker")
	fl.erase("dark_shop_2")
	fl.erase("dark_shop_1")

	# --- story wording -------------------------------------------------------
	var all_gang := FileAccess.get_file_as_string("res://data/story_gang.json")
	check(all_gang.find("Mr President") < 0, "no 'Mr President' (June, Nia, Marisol can win)")
	check(all_gang.find("cold floor") < 0, "freed President is on the wet carpet, not a floor")
	check(all_gang.find("So were the young") < 0, "President's reveal grammar fixed")
	check(all_gang.find("signed himself M.") < 0, "a voice doesn't sign")
	check(all_gang.find("hold that bat") < 0, "Doc doesn't assume the Street Bat")
	var man := _texts(_beat("g1_man")["lines"])
	check(man.find("In the coat's pocket") >= 0, "the photo is in the coat's pocket")
	check(man.find("in a hand with hard loops") < 0, "narration doesn't give away the handwriting")
	var shop := _beat("g2_shop1")
	check(str(shop["lines"][1]["choice"][0]).begins_with("Do it"), "bakery choice doesn't say 'Fund' when you're paid")
	check(_texts(shop["lines"]).find("Six hundred, up front") >= 0, "Deuce says you were paid")
	var crew_raw := FileAccess.get_file_as_string("res://data/crew.json")
	check(crew_raw.find("lobby") < 0 and crew_raw.find("up there") < 0, "no loyalty promise points at a tower lobby")
	check(crew_raw.find("story_gang.json recruit") >= 0, "crew.json note names story_gang.json")

	# --- cash arc: choice labels and gate toasts without the crystal sign --------
	for ch in JSON.parse_string(all_gang)["gangsters"]:
		for b in ch["beats"]:
			for l in b["lines"]:
				for o in (l as Dictionary).get("choice", []):
					if str(o).contains("◆"):
						check(not Money.t(str(o)).contains("◆"), "%s choice '%s' shows $" % [b["id"], Money.t(str(o))])
	check(Money.amount(300).begins_with("$"), "gate toast amount is cash")

	# --- crew everyday lines: loyalty and ending ------------------------------
	for id in Crew.members():
		fl["crew_" + str(id)] = true
		Crew._set_loyalty(str(id), 0)
	var early := "\n".join(Crew.everyday_lines("vic") + Crew.everyday_lines("val") + Crew.everyday_lines("specs"))
	check(early.find("Left side") < 0 and early.find("Right side") < 0, "no lobby-plan line at loyalty 0")
	check(early.find("stone") < 0 and early.find("Its own wire") < 0, "no stone / wire line before those scenes")
	Crew._set_loyalty("vic", 3)
	check("Left side's yours. Remember." in Crew.everyday_lines("vic"), "Vic's plan line after his loyalty-2 scene")
	fl["final_done"] = true
	fl["president_freed"] = true
	GameState.run["ending"] = "free"
	var after := "\n".join(Crew.everyday_lines("vic") + Crew.everyday_lines("halo"))
	check(after.find("We're ready") < 0 and after.find("Nowhere we have to be") >= 0, "after the tower the crew stops talking about it ahead")
	for id in Crew.members():
		check(not Crew.everyday_lines(str(id)).is_empty(), "%s has after-tower lines" % id)
	check(Crew.joined_line("mk_sable", ["x"], 2) == "I have a shadow again. I keep checking.", "Sable gets her shadow back only after the stone is out")
	fl.erase("president_freed")
	fl["city_taken"] = true
	GameState.run["ending"] = "take"
	check(Crew.everyday_lines("doc")[0].find("tower basement") >= 0, "The Chair: Doc's line knows you took the tower")
	check(Crew.joined_line("mk_rio", ["x"], 4).find("slower than it used to be") >= 0, "The Chair: Rio feels it")
	check(Crew.joined_line("lt_mags", ["x"], 2).find("listen to you") >= 0, "The Chair: Mags' hideout line")
	check(Crew.joined_line("mk_kit", ["pre"], 1) == "pre", "odd days keep the everyday hideout line")
	fl.erase("final_done")
	fl.erase("city_taken")
	GameState.run.erase("ending")
	check(str(Marked.all()["sable"]["hideout"][0]).find("I have a shadow again") < 0, "Sable's pre-ending hideout line doesn't contradict her Gift")

	# --- bill caught: who and how much ----------------------------------------
	var dl := Racket.caught_line("docks", 40)
	check(dl.begins_with("A dockhand") and dl.find("$40") >= 0, "docks: a dockhand, cash amount (%s)" % dl)
	var names := ["Maple", "Gideon", "Posy", "Wren", "Ivy"]
	for sc in ["docks", "neon", "uptown", "hideout", "beach", "quarry"]:
		var ln := Racket.caught_line(sc, 10)
		check(names.all(func(n: String) -> bool: return not ln.begins_with(n)), "%s: no town shopkeeper (%s)" % [sc, ln])
	var broke := Racket.caught_line("neon", 0)
	check(broke.find("$0") < 0 and broke.find("nothing to smooth") >= 0, "broke: no '$0' line")
	var town := Racket.caught_line("town", 10)
	check(names.any(func(n: String) -> bool: return town.begins_with(n)), "town: a shopkeeper notices (%s)" % town)

	# --- ending slides agree with the ending ----------------------------------
	var ep: Dictionary = Epilogue.data()
	var th: Dictionary = ep["crew_threads"]
	check(int(th["vic"][0]) == 2 and int(th["specs"][0]) == 3 and int(th["marlene"][0]) == 3 and int(th["the_kid"][0]) == 2, "crew threads wait for the scene that planted them")
	check(str(th["vic"][1]).find("stone broke") < 0, "brother thread holds in Clean Break (stone sealed, not broken)")
	check(str(ep["choices"]["shop_2"]["0"]).find("Lumi") >= 0, "shop 2 slide names Lumi's studio")
	GameState.new_run("gangsters", "june", "Hero", "Dreamhollow", "Biscuit")
	fl = GameState.run["flags"]
	for id in Crew.members():
		fl["crew_" + str(id)] = true
		Crew._set_loyalty(str(id), 3)
	fl["hale_outrun"] = true
	fl["hale_has_stone"] = true
	fl["clean_break"] = true
	fl["president_freed"] = true
	fl["ending_clean"] = true
	GameState.run["ending"] = "clean"
	var all := "\n".join(Epilogue.build().map(func(s: Array) -> String: return str(s[1])))
	check(all.find("never did catch you") < 0 and all.find("walked right up to her") >= 0, "Clean Break after outrunning Hale: the slide knows you handed it over")
	GameState.new_run("gangsters", "june", "Hero", "Dreamhollow", "Biscuit")
	fl = GameState.run["flags"]
	for id in Crew.members():
		fl["crew_" + str(id)] = true
		Crew._set_loyalty(str(id), 3)
	fl["hale_friend"] = true
	fl["city_taken"] = true
	fl["ending_take"] = true
	fl["shop_1"] = true
	GameState.run["ending"] = "take"
	all = "\n".join(Epilogue.build().map(func(s: Array) -> String: return str(s[1])))
	check(all.find("still clean?") < 0 and all.find("last one was blank") >= 0, "The Chair: Hale stops writing 'still clean?'")
	check(all.find("parked outside your farm") < 0 and all.find("long black car") >= 0, "The Chair: Halo drives for the tower")
	check(all.find("free clinic") < 0, "The Chair: no free clinic for Doc")
	check(all.find("warn the bakery") < 0, "Ladder doesn't warn a bakery that's an arcade")
	print("c12_gang_story_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)

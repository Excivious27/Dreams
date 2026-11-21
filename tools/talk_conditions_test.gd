extends SceneTree
## CONDUCT 12 P3: villager chatter follows game state. Talk pool keys
## (q:/!q:/f:/!f:/if:/not:, morning..night, festival_<id>, "a&b"), story-gated
## lines (nobody names the President, Coldy, Big Jim or a merkitty before the
## story does), gangster arc never hears penguin lines, Benno follows the horse /
## Halo's garage, indoor lines only at work, festival hosts who left town are
## replaced, everyone's on the plaza on festival day, region folk follow the arc,
## the boss and their job.
##   godot --headless --path . -s res://tools/talk_conditions_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(1212)
	_run.call_deferred()


func _setup(arc: String, day: int, hour: int, weather := "clear") -> void:
	GameState.new_run(arc, "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["day"] = day
	GameState.run["time"] = hour * 60
	GameState.run["weather"] = {str(day): weather, str(day + 1): weather}


func _done(qid: String) -> void:
	for q in GameState.run["quests"]:
		if q["id"] == qid:
			q["done"] = true
			return
	GameState.run["quests"].append({"id": qid, "done": true, "text": ""})


func _all_pools() -> String:
	var out := ""
	for id: String in Talk.data():
		out += "\n" + "\n".join(PackedStringArray(Talk.own_pool(id)))
	return out


func _run() -> void:
	# --- key grammar ---
	_setup("penguins", 3, 9)
	check(Talk.phase() == "morning", "9am is morning (%s)" % Talk.phase())
	check(Talk.key_ok("always") and Talk.key_ok("spring") and Talk.key_ok("penguins") and not Talk.key_ok("gangsters"), "basic keys")
	check(Talk.key_ok("morning") and not Talk.key_ok("evening") and not Talk.key_ok("winter&morning"), "time keys")
	check(not Talk.key_ok("q:clear_meadow") and Talk.key_ok("!q:clear_meadow"), "quest keys before")
	_done("clear_meadow")
	check(Talk.key_ok("q:clear_meadow") and Talk.key_ok("penguins&q:clear_meadow"), "quest keys after")
	GameState.run["flags"]["posy_gone"] = true
	check(Talk.key_ok("f:posy_gone") and Talk.key_ok("if:posy_gone") and not Talk.key_ok("!f:posy_gone") and not Talk.key_ok("not:posy_gone"), "flag keys")
	check(not Talk.key_ok("bogus_key"), "unknown keys never hold")
	GameState.run["time"] = 19 * 60
	check(Talk.phase() == "evening", "7pm is evening")
	GameState.run["time"] = 23 * 60
	check(Talk.phase() == "night", "11pm is night")
	# Every key in talk.json is one the grammar knows (a typo would silently mute lines).
	var known := ["always", "spring", "summer", "fall", "winter", "penguins", "gangsters", "rain", "clear", "storm", "fog", "wind", "petals", "blizzard", "heat", "festival", "morning", "afternoon", "evening", "night"]
	for id: String in Talk.data():
		for key: String in Talk.data()[id]:
			for part in key.split("&"):
				var ok := part in known or part.begins_with("festival_") or part.begins_with("q:") or part.begins_with("!q:") or part.begins_with("f:") or part.begins_with("!f:") or part.begins_with("if:") or part.begins_with("not:")
				check(ok, "talk.json %s key part '%s' is known" % [id, part])
			for l in Talk.data()[id][key]:
				check(str(l).length() <= 170, "talk.json %s/%s line fits the phone box: %s" % [id, key, str(l).left(60)])
	# --- gangster day 1: no President, no crew, no penguin words ---
	for hour in [8, 13, 18, 22]:
		for w in ["clear", "rain", "storm", "fog"]:
			_setup("gangsters", 2, hour, w)
			var all := _all_pools()
			check(not ("President" in all), "gangster day 2 %dh %s: nobody names the President yet" % [hour, w])
			check(not ("Your crew" in all), "gangster day 2: Benno doesn't welcome a crew you don't have")
			check(not ("penguin" in all.to_lower()) and not ("Star Crystal" in all) and not ("◆" in all), "gangster arc pools carry no penguin lines (%dh %s)" % [hour, w])
	for se in [0, 28, 56, 84]:
		_setup("gangsters", se + 5, 12)
		check(not ("penguin" in _all_pools().to_lower()), "gangster season %d: no penguin lines" % se)
	_setup("gangsters", 20, 12)
	_done("clear_meadow")
	check("President" in "\n".join(PackedStringArray(Talk.own_pool("gideon"))), "Gideon names the President after the meadow")
	# --- penguin early: story characters wait for their chapter ---
	for hour in [8, 13, 19, 23]:
		_setup("penguins", 2, hour)
		var all2 := _all_pools()
		for nm in ["Coldy", "Big Jim", "merkitty"]:
			check(not (nm in all2), "penguin day 2: nobody mentions %s yet" % nm)
	_setup("penguins", 40, 12)
	for f in ["babies_done", "merkitty_done", "meow_taught"]:
		GameState.run["flags"][f] = true
	var later := _all_pools()
	check("Coldy" in later and "Big Jim" in later and "merkitty" in later, "story characters show up once met")
	# --- Benno: horse, Halo, time ---
	_setup("penguins", 3, 9)
	var bp := "\n".join(PackedStringArray(Talk.own_pool("benno")))
	check("Four in the stalls" in bp, "Benno offers a horse before you have one")
	check(not ("tonight" in bp), "Benno says nothing about tonight at 9am")
	GameState.run["flags"]["horse"] = true
	GameState.run["names"]["horse"] = "Biscuit"
	bp = "\n".join(PackedStringArray(Talk.own_pool("benno")))
	check(not ("Four in the stalls" in bp) and "{horse}" in bp, "Benno asks after your horse once you own one")
	check("Biscuit" in Talk.fill("How's {horse} doing?"), "{horse} is filled")
	_setup("gangsters", 3, 12)
	GameState.run["flags"]["crew_halo"] = true
	bp = "\n".join(PackedStringArray(Talk.own_pool("benno")))
	check(not ("Four in the stalls" in bp) and "Halo" in bp, "Halo's garage: Benno talks about the bikes, not an open stable")
	_setup("penguins", 3 * 28 + 5, 20)
	check("Blankets on every horse tonight" in "\n".join(PackedStringArray(Talk.own_pool("benno"))), "winter evening blankets line")
	# --- Posy / Juniper leaving and coming back ---
	_setup("gangsters", 30, 12)
	check(not ("Posy left" in "\n".join(PackedStringArray(Talk.own_pool("maple")))), "Maple only mentions Posy leaving after she does")
	GameState.run["flags"]["posy_gone"] = true
	GameState.run["flags"]["juniper_gone"] = true
	var mp := "\n".join(PackedStringArray(Talk.own_pool("maple")))
	check("Posy left" in mp and "clinic" in mp, "Maple notices Posy and Juniper gone")
	GameState.run["flags"].erase("posy_gone")
	GameState.run["flags"]["shop_1_returned"] = true
	check("I'm back" in "\n".join(PackedStringArray(Talk.own_pool("posy"))), "Posy says she's back")
	# --- Marlowe and the lamp ---
	_setup("penguins", 10, 12)
	check("I'd light it anyway" in "\n".join(PackedStringArray(Talk.own_pool("marlowe"))), "Marlowe: dark lamp line before")
	GameState.run["flags"]["lighthouse_lit"] = true
	var ml := "\n".join(PackedStringArray(Talk.own_pool("marlowe")))
	check(not ("I'd light it anyway" in ml) and "Lamp's lit" in ml, "Marlowe: lit lamp lines after")
	# --- no hunting, no weekdays, no drinks ---
	var ts := JSON.stringify(Talk.data()).to_lower()
	for w in ["i hunt", "hunter", "tuesday", "thursday", "friday", "cider"]:
		check(not (w in ts), "talk.json says no '%s'" % w)
	check(not ("Hunter" in str(Intros.LINES["rook"])) and str(GameState.npcs["rook"]["role"]) == "Tracker", "Rook is a tracker")
	for id in ["marlowe", "orla", "old_moss", "granite", "sel"]:
		check(Intros.LINES.has(id), "%s has a first meeting" % id)
	_setup("gangsters", 3, 12)
	check("don't write down why" in str(Intros.lines_for("juniper")), "Juniper's gangster intro")
	# --- indoor lines: only at work, arc and progress aware ---
	_setup("gangsters", 3, 12)
	check(Talk.inside_pool("maple", "inn").is_empty(), "Maple at the inn doesn't talk about her glass case")
	check(not Talk.inside_pool("maple", str(GameState.npcs["maple"]["work"])).is_empty(), "Maple at work has her shop lines")
	var wr := "\n".join(PackedStringArray(Talk.inside_pool("wren", str(GameState.npcs["wren"]["work"]))))
	check(not ("crystal" in wr.to_lower()), "gangster Wren indoors: no crystal")
	var jn := "\n".join(PackedStringArray(Talk.inside_pool("juniper", str(GameState.npcs["juniper"]["work"]))))
	check("that bat" in jn and not ("{weapon}" in jn), "gangster Juniper: the bat")
	var pw := str(GameState.npcs["posy"]["work"])
	check("clearing that old field" in "\n".join(PackedStringArray(Talk.inside_pool("posy", pw))), "Posy: clearing the field before the meadow")
	_done("clear_meadow")
	var pp := "\n".join(PackedStringArray(Talk.inside_pool("posy", pw)))
	check(not ("clearing that old field" in pp) and "fields look better" in pp, "Posy: fields line after the meadow")
	GameState.run["flags"]["lumi_gone"] = true
	check(not ("Lumi draws" in "\n".join(PackedStringArray(Talk.inside_pool("theo", str(GameState.npcs["theo"]["work"]))))), "Theo stops mentioning Lumi's margins once she's gone")
	# --- festivals ---
	_setup("penguins", 14, 10)
	check(GameState.festival_today() == "egg", "day 14 is the Egg Festival")
	check(Npc.festival_place("maple", 10.0) in Npc.FEST_SPOTS, "Maple's on the plaza on festival day")
	check(Npc.festival_place("pip", 10.0) in Npc.FEST_SPOTS, "Pip's not at school on festival day")
	check(Npc.festival_place("alder", 10.0) == "fountain", "the mayor runs the fountain stage")
	check(Npc.festival_place("juniper", 10.0) == "", "Juniper stays on call")
	check(Npc.festival_place("maple", 20.0) == "", "after six the routine is back")
	check(Npc.place_now(GameState.npcs["gideon"]["routine"], "gideon") in Npc.FEST_SPOTS, "place_now uses the plaza on festival day")
	check(not Talk.festival_pool("benno").is_empty() and not ("ribbons" in str(Talk.festival_pool("benno"))), "Benno's egg-day lines are not the horse ribbons")
	check(FestivalWords.fest_host("Posy") == "Posy", "Posy hosts while she's here")
	check("◆" in FestivalWords.egg_prize_text(), "penguin egg prize in crystals")
	_setup("gangsters", 14, 10)
	GameState.run["flags"]["posy_gone"] = true
	GameState.run["flags"]["lumi_gone"] = true
	check(FestivalWords.fest_host("Posy") == "Hazel" and FestivalWords.fest_host("Lumi") == "Theo", "hosts who left are replaced (%s, %s)" % [FestivalWords.fest_host("Posy"), FestivalWords.fest_host("Lumi")])
	check("$" in FestivalWords.egg_prize_text() and not ("◆" in FestivalWords.egg_prize_text()), "gangster egg prize in cash: %s" % FestivalWords.egg_prize_text())
	check(not ("magic" in FestivalWords.star_call()), "gangster star wish words")
	GameState.run["time"] = 10 * 60
	check(not ("tonight" in FestivalWords.lantern_tail()) or not GameState.is_night(), "no night sky at 10am")
	# --- region folk ---
	var regions: Dictionary = GameState.load_json("res://data/regions.json")
	var liesl: Dictionary = {}
	for nd in regions.get("gloam_lanternfall", {}).get("npcs", []):
		if str(nd["id"]) == "mg_liesl":
			liesl = nd
	check(not liesl.is_empty(), "Liesl in regions.json")
	_setup("gangsters", 5, 12)
	check(not ("Thornmother" in str(Talk.region_lines(liesl))), "gangster Liesl doesn't name the Thornmother")
	GameState.run["flags"]["boss_gloam_moonpool"] = true
	check("Gerald's moved into the roses" in str(Talk.region_lines(liesl)), "Liesl after the boss (gangster)")
	_setup("penguins", 5, 12)
	check("Thornmother" in str(Talk.region_lines(liesl)), "penguin Liesl keeps her line")
	for rid in ["gloam_lanternfall", "desert_mirage_post", "frost_hearthhold"]:
		_setup("gangsters", 5, 12)
		for nd in regions.get(rid, {}).get("npcs", []):
			var s := str(Talk.region_lines(nd))
			for boss in ["Thornmother", "Colossus", "Wyrm"]:
				check(not (boss in s), "gangster %s %s doesn't name the %s" % [rid, nd["id"], boss])
	var tam_lines := str(regions.get("orchard_hills", {}).get("npcs", []))
	check(not ("cider" in tam_lines.to_lower()), "Tam offers no cider")
	# --- Rec Center lead-in doesn't swamp chatter ---
	_setup("penguins", 5, 12)
	if not RecCenter.is_open() and not RecCenter.soon_lines().is_empty():
		check(RecCenter.talk_pool("alder").size() == 1 and not ("Mayor Alder" in str(RecCenter.talk_pool("alder"))), "Alder has his own lead-in line, not the third person")
		check(RecCenter.talk_pool("maple").size() <= 1, "one shared lead-in line a day per villager")
		check(not ("Grandma Hazel" in JSON.stringify(RecCenter.data())), "Mabel calls Hazel Mum")
	print("talk_conditions_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

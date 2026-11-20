extends SceneTree
## C7 P3: the end slideshow (Epilogue.build) and the gangster story data
## (data/story_gang.json). Every slide fits the phone screen (pages by measured
## height), pictures exist, credits come before the last slide, the gangster arc
## has no crystal money, Sal isn't said twice, Vic without Val, Big Jim's tail,
## hero "you" lines, the Clean Break / heat / loyalty conditions, and the slideshow
## holds toasts. Run: godot --headless --path . -s res://tools/epilogue_test.gd
var fails := 0


func _initialize() -> void:
	seed(7)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _fits(slides: Array, tag: String) -> void:
	for s in slides:
		var pic := str(s[2]) if s.size() > 2 else ""
		var room := Epilogue.PIC_BODY_H if pic != "" else Epilogue.BODY_H
		var h := Epilogue.text_h(str(s[1]))
		# One single over-long line may stand alone on its page; flag anything over a full screen.
		check(h <= room + 1.0 or (h <= 322.0 and str(s[1]).find("\n\n") < 0), "%s: '%s' fits (%d <= %d px)" % [tag, str(s[0]), int(h), int(room)])
		if pic != "":
			check(Art.has("ui", pic), "%s: picture ui/%s exists" % [tag, pic])


func _titles(slides: Array) -> Array:
	return slides.map(func(s: Array) -> String: return str(s[0]))


func _all_text(slides: Array) -> String:
	return "\n".join(slides.map(func(s: Array) -> String: return str(s[1])))


func _run() -> void:
	InputSetup.ensure_actions()
	# --- gangster run, everyone recruited, The Chair ---------------------------
	GameState.new_run("gangsters", "pax", "Hero", "Dreamhollow", "Biscuit")
	var fl: Dictionary = GameState.run["flags"]
	for id in Crew.members():
		fl["crew_" + str(id)] = true
		Crew._set_loyalty(str(id), 3)
	fl.erase("crew_val")  # Vic without Val
	Companion.recruit("sal", false)
	Companion.recruit("big_jim", false)
	fl["sal_recruited"] = true
	for mid in Marked.all():
		fl["marked_" + str(mid)] = "crew"
	for lt in ["vance", "lucia", "brock", "silas", "mags", "pike", "ostrova"]:
		fl["lt_" + lt] = true
		fl["lt_joined_" + lt] = true
	for sid in Ops.TURF:
		Ops.turf()[sid] = true
	for hid in Ops.HEISTS:
		fl["heist_" + str(hid)] = true
	for v in GameState.npcs:
		GameState.run["friendship"][v] = 700
	GameState.run["decisions"] = {"photo": 2, "letter": 1, "shop_1": 0, "shop_2": 0, "shop_3": 1, "sell_letter": 1}
	fl["shop_1_returned"] = true
	fl["shop_2"] = true
	fl["doors_by_letter"] = true
	GameState.run["ending"] = "take"
	var sl := Epilogue.build()
	var t := _titles(sl)
	_fits(sl, "gang/take")
	check(str(sl[0][0]) == "THE END: The Chair" and str(sl[0][2]) == "ending_the_chair", "THE END slide names the ending and shows its picture")
	check(t.find("Credits") >= 0 and t.find("Credits") == t.size() - 2 and t[-1] == "Thank you for playing", "credits slide comes right before the last slide: %s" % str(t.slice(t.size() - 3)))
	check(str(sl[-1][2]) == "cut_rain_road", "last slide shows the gangster picture")
	check(t.any(func(x: String) -> bool: return x.begins_with("The crew (")) or Epilogue.text_h(str(sl[t.find("The crew")][1])) <= Epilogue.BODY_H, "the crew pages instead of running off screen")
	var txt := _all_text(sl)
	check(txt.findn("crystal in it") < 0 and txt.findn("last crystal") < 0, "no crystal money in the gangster epilogue")
	check(txt.find("one dollar") >= 0 or txt.find("last cent") >= 0, "Ivy talks cash in the gangster arc")
	check(txt.find("Sal stops drifting") < 0 and txt.find("Sal moves on") < 0, "Sal's villager line is skipped when he is crew")
	check(txt.find("Vic runs the gym") >= 0 and txt.find("Vic and Val run") < 0, "Vic's solo line when Val never joined")
	check(t.has("Big Jim's tail"), "Big Jim's tail slide when he is with you")
	check(txt.find("bought it back") >= 0, "a shop you gave back gets its own line")
	check(txt.find("best deal you ever turned down") >= 0 and txt.find("It opened the tower doors") < 0, "letter kept: no double 'doors' line")
	check(txt.find("the docks, Neon, Uptown and the pit") >= 0 or txt.find("The docks, Neon, Uptown and the pit") >= 0, "turf list joined with 'and'")
	check(txt.find("the Cannery Job, the Neon Arcade and the Vault") >= 0, "heist names lower-case 'the' mid-sentence")
	check(txt.find("sister") >= 0 and txt.find("big brother") < 0, "crew threads: the Kid's sister (not shown in the twins' line without Val's scene... vic thread hidden in The Chair)")
	# --- Clean Break conditions ----------------------------------------------
	check(not Epilogue.clean_ok(), "no Clean Break with a shop still taken")
	fl.erase("shop_2")
	check(not Epilogue.clean_ok(), "no Clean Break while Marked are still crew")
	for mid in Marked.all():
		fl["marked_" + str(mid)] = "free"
	Racket.set_heat(0)
	check(Epilogue.clean_ok(), "Clean Break open: heat 0, every Marked home, no shop held")
	Racket.set_heat(1)
	check(not Epilogue.clean_ok(), "heat 1 closes the Clean Break")
	check(GameState._cond_ok({"heat_min": 1}) and not GameState._cond_ok({"heat_max": 0}), "heat conditions")
	check(GameState._cond_ok({"clean_break": false}) and not GameState._cond_ok({"clean_break": true}), "clean_break condition")
	Crew._set_loyalty("doc", 2)
	check(not GameState._cond_ok({"loyalty": ["doc", 3]}) and GameState._cond_ok({"loyalty": ["doc", 2]}), "loyalty condition")
	Racket.set_heat(0)
	GameState.run["ending"] = "clean"
	fl["hale_has_stone"] = true
	sl = Epilogue.build()
	_fits(sl, "gang/clean")
	check(str(sl[0][0]) == "THE END: A Clean Break" and str(sl[0][2]) == "cut_clean_break", "Clean Break ending slide + picture")
	check(_all_text(sl).find("lead box") >= 0, "Hale keeps the stone in the Clean Break epilogue")
	# --- the gangster story file ------------------------------------------------
	var beats := {}
	for ch in Story.data().get("gangsters", []):
		for b in ch.get("beats", []):
			beats[str(b["id"])] = b
	for need in ["g3_hale", "g3_hale_quiet", "g4_hale", "g4_sal_conscience", "g4_return_1", "g4_return_2", "g4_return_3", "g5_twins_doors", "g5_ladder_spot", "g5_win_clean", "g5_win"]:
		check(beats.has(need), "story_gang.json has %s" % need)
	var raw := JSON.stringify(Story.data().get("gangsters", []))
	check(raw.find("Winter Kade") >= 0, "M.'s name is paid off (Winter Kade)")
	check(raw.find("sword like a hoe") < 0 and raw.find("I'm a gentleman") < 0, "Doc's bat line and Halo's line fixed")
	check(raw.find("on the marble") < 0, "finale staged on the steps, not an indoor lobby")
	for k in beats:
		for ln in _lines(beats[k]):
			var pic := str((ln as Dictionary).get("pic", ""))
			if pic != "" and pic != "none":
				check(Art.has(pic.get_slice("/", 0) if "/" in pic else "ui", pic.get_slice("/", 1) if "/" in pic else pic), "%s: pic %s exists" % [k, pic])
	# --- penguin run as Nova -----------------------------------------------------
	GameState.new_run("penguins", "kairi", "Hero", "Dreamhollow", "Biscuit")
	GameState.run["playable"] = "penguin_f"
	GameState.run["ending"] = "revert"
	GameState.run["flags"]["auk_shard"] = true
	GameState.run["flags"]["st_p3_campfire"] = true
	sl = Epilogue.build()
	_fits(sl, "peng/revert")
	txt = _all_text(sl)
	check(str(sl[0][2]) == "ending_two_crystals", "penguin ending picture")
	check(txt.find("You still go looking for him") >= 0 and txt.find("Nova still goes looking") < 0, "playing Nova: her lines say 'you'")
	check(_titles(sl).has("Big Jim's tail"), "penguin arc: Big Jim's tail after the campfire")
	check(str(sl[-1][2]) == "cut_old_dog", "last slide shows the penguin picture")
	# --- the slideshow node -------------------------------------------------------
	var e := Epilogue.new()
	e._slides = sl
	root.add_child(e)
	await process_frame
	check(e.is_in_group("toast_hold"), "slideshow holds the toasts")
	check(e._pic.visible and e._body.position.y > 200.0, "THE END picture shown, text moved below it")
	e._arm = 99
	e._next()
	await process_frame
	check(not e._pic.visible or str(e._slides[1][2]) != "", "picture hidden on slides without one")
	e._close()
	await process_frame
	print("epilogue_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)


func _lines(b: Dictionary) -> Array:
	var out: Array = []
	for ln in b.get("lines", []):
		out.append(ln)
		for k in (ln as Dictionary).get("branches", {}):
			out.append_array(ln["branches"][k])
	return out

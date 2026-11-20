extends SceneTree
## Collections (CONDUCT 8 P3): catalog per arc (every entry has art and a source), shipping log from
## the sell box at sleep (+ SleepReport line), fish log, cookbook/crafting log via Crafting.collect,
## donations + milestones (claimed once, letter in the morning post), quest conditions, co-op refusal,
## old-save backfill, the museum room (opens, cases and tray reachable, icons drawn), the Book tab.
##   godot --headless --path . --fixed-fps 60 -s res://tools/collections_test.gd
var fails := 0


func _initialize() -> void:
	Campaign.bypass = true
	seed(8)
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("  FAIL ", what)


func _fresh(arc: String) -> void:
	GameState.new_run(arc, "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true


func _mail_with(key: String) -> int:
	var n := 0
	for m: Dictionary in Mail.list():
		if str(m.get("coll", "")) == key:
			n += 1
	return n


func _run() -> void:
	InputSetup.ensure_actions()
	for arc in ["penguins", "gangsters"]:
		_fresh(arc)
		var c := Collections.st()
		ok(c.has("donated") and c.has("shipped"), arc + ": run.coll made")
		# --- catalog ---
		for cat in ["museum", "shipping", "fish", "cooking", "crafting", "forage"]:
			ok(Collections.total(cat) > 0, "%s: %s has entries" % [arc, cat])
			ok(Collections.count(cat) == 0 or cat == "forage", "%s: %s starts empty" % [arc, cat])
		ok(Collections.total("museum") == 59, arc + ": museum 59 pieces (got %d)" % Collections.total("museum"))
		for e: Dictionary in Collections.entries("museum"):
			ok(Art.has("items", Hud.icon_for(str(e["item"]))), "museum icon " + str(e["item"]))
			ok(str(e.get("where", "")) != "", "museum where-hint " + str(e["item"]))
		ok(not Collections.in_log("fish", "tuna") and Collections.in_log("museum", "tuna"), arc + ": tuna is museum-only")

		# --- shipping log at sleep (the sell-box hook lives in P1's GameState.ship_log; before that merge, record directly) ---
		if GameMenu._has_static(load("res://scripts/game_state.gd"), "ship_log"):
			GameState.run["sellbox"] = {"turnip": 3, "stone": 2}
			var rep := GameState.sleep()
			ok(Collections.amount_of("shipping", "turnip") == 3, arc + ": 3 turnips in the shipping log")
			ok((rep.get("ship_new", []) as Array).has("turnip"), arc + ": report carries ship_new")
			var has_line := false
			for l: Dictionary in SleepReport.lines(rep):
				if str(l.get("who", "")) == "Shipping log":
					has_line = true
			ok(has_line, arc + ": SleepReport shows the shipping-log line")
		else:
			ok(Collections.record_ship("turnip", 3, true), arc + ": first turnip shipped")
			ok(Collections.amount_of("shipping", "turnip") == 3, arc + ": 3 turnips in the shipping log")
		ok(not Collections.record_ship("turnip", 1, true), arc + ": second turnip is not a first")

		# --- fish log ---
		ok(Collections.record_catch("bass", 1, true, false), arc + ": first bass")
		ok(not Collections.record_catch("bass", 2), arc + ": second bass no first")
		ok(Collections.amount_of("fish", "bass") == 3 and bool(c["caught"]["bass"]["night"]), arc + ": bass count 3, night noted")
		ok(not Collections.record_catch("boot"), arc + ": boot isn't logged")

		# --- cooking / crafting via Crafting.collect ---
		var rid := str((Collections.entries("cooking")[0] as Dictionary)["recipe"])
		var st := str((Collections.entries("cooking")[0] as Dictionary)["station"])
		ok(Collections.never_made(rid), arc + ": recipe marked new before the first cook")
		ok(Collections.record_make(st, rid, 1), arc + ": first cook")
		ok(not Collections.never_made(rid), arc + ": no longer new")
		var crid := str((Collections.entries("crafting")[0] as Dictionary)["recipe"])
		Collections.record_make("x", crid, 2)
		ok(Collections.amount_of("crafting", crid) == 2 and Collections.count("cooking") == 1, arc + ": crafting/cookbook counts")

		# --- donations + milestones ---
		var want := ["coal", "copper", "iron", "fossil", "old_coin", "minnow"]
		for id in want:
			GameState.add_item(id, 1, true)
		ok(Collections.donate("coal") == "", arc + ": donate coal")
		ok(GameState.count("coal") == 0, arc + ": coal left the bag")
		ok(Collections.donate("coal") != "", arc + ": coal refused twice")
		ok(Collections.donate("turnip") != "", arc + ": turnip refused (not a museum piece)")
		for id in want.slice(1):
			Collections.donate(id)
		ok(Collections.count("museum") == 6, arc + ": 6 donated")
		ok(c["claimed"].has("mus_5") and (c["pending"] as Array).has("mus_5"), arc + ": mus_5 claimed + pending")
		ok(Collections.check_milestones().is_empty(), arc + ": nothing claimed twice")
		var before := int(GameState.run["crystals"])
		GameState.run["day"] = 5
		Collections.morning()
		ok(_mail_with("mus_5") == 1, arc + ": milestone letter sent")
		ok(_mail_with("thanks") == 1, arc + ": donation thanks letter")
		ok(_mail_with("open") == 1 and Collections.museum_open(), arc + ": opening letter + museum_open (day >= 4, piece seen)")
		ok(int(GameState.run["crystals"]) == before + 300, arc + ": milestone money paid once")
		Collections.morning()
		ok(_mail_with("mus_5") == 1 and _mail_with("thanks") == 1, arc + ": no repeat letters")
		if arc == "gangsters":
			for m: Dictionary in Mail.list():
				if str(m.get("coll", "")) != "":
					for word in ["crystal", "penguin", "wine", "gambl"]:
						ok(not str(m["text"]).to_lower().contains(word), "gang letter word " + word)

		# --- conditions ---
		ok(GameState._cond_ok({"donated": "fossil"}), arc + ": donated fossil cond")
		ok(not GameState._cond_ok({"museum_wing": ["fish", 5]}), arc + ": fish wing 5 not yet")
		ok(GameState._cond_ok({"museum_n": 6}) and not GameState._cond_ok({"museum_n": 7}), arc + ": museum_n")
		ok(GameState._cond_ok({"logged": ["fish", 1]}), arc + ": logged fish 1")

		# --- wing complete -> decor ---
		for e: Dictionary in Collections.entries("museum", "curios"):
			GameState.add_item(str(e["item"]), 1, true)
			Collections.donate(str(e["item"]))
		ok(c["decor"].has("curio_jar"), arc + ": curios wing gives the curio jar decor")

	# --- old save backfill ---
	_fresh("penguins")
	GameState.run["seen"] = {"trout": true, "salmon": true}
	GameState.run.erase("coll")
	GameState._migrate()
	ok(Collections.have("fish", "trout") and Collections.have("fish", "salmon"), "old save: seen fish backfilled")
	ok(Collections.count("shipping") == 0, "old save: shipping starts empty")

	# --- legend roll never fires off its scene ---
	ok(Collections.legend_roll("farm", "carp", true) == "carp", "legend only at its scene")

	# --- museum room + library doorway ---
	_fresh("penguins")
	GameState.run["flags"]["museum_open"] = true
	GameState.add_item("ruby", 1, true)
	Collections.donate("ruby")
	GameMap.next_interior = "library"
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/interior.tscn")
	for i in 8:
		await process_frame
	var lib := current_scene as GameMap
	ok(lib != null and str(lib.things.get(Vector2i(10, 2), {}).get("type", "")) == "museum", "library has the museum doorway")
	GameMap.next_interior = "museum"
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/interior.tscn")
	for i in 10:
		await process_frame
	var mu := current_scene as GameMap
	ok(mu != null and str(mu.get("interior_id")) == "museum", "museum room loads")
	if mu:
		var mn := mu.get_node_or_null("Museum") as Museum
		ok(mn != null and mn._icons.has("ruby"), "donated ruby drawn in its case")
		var counters := 0
		var cases := 0
		for cc in mu.things:
			var t: Dictionary = mu.things[cc]
			if str(t.get("type", "")) == "museum":
				if str(t.get("act", "")) == "counter":
					counters += 1
				elif str(t.get("act", "")) == "case":
					cases += 1
		ok(counters == 2 and cases == 59, "museum things: tray + 59 cases (got %d/%d)" % [counters, cases])
		ok(Collections.room_name() == "Valley Museum", "room name (penguins)")
		# --- the Book tab builds every page ---
		var gm: GameMenu = null
		for ch in mu.get_children():
			if ch is GameMenu:
				gm = ch
		ok(gm != null, "menu present")
		if gm:
			gm._tab = "Book"
			CollectionScreen.open("")
			gm._refresh()
			ok(gm._body.get_child_count() > 6, "Book hub rows")
			for cat in ["museum", "shipping", "fish", "cooking", "crafting", "forage"]:
				CollectionScreen.open(cat)
				gm._refresh()
				var cells := 0
				for ch2 in gm._body.get_children():
					if ch2 is GridContainer:
						cells += ch2.get_child_count()
				ok(cells > 0 and cells <= 60, "Book %s grid cells %d" % [cat, cells])
			CollectionScreen.open("")
	print("collections_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

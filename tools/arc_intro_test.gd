extends SceneTree
## The arc choice and each arc's own early systems explain themselves:
## the path cards say how each arc plays, locked sanctuary plans say what opens
## them, first use of an arc building has its intro, the morning report names
## what was left where, and "Heat 0/5" never shows before heat means anything.
##   godot --headless --path . -s res://tools/arc_intro_test.gd
var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()

func _texts(n: Node) -> String:
	var out := ""
	for l in n.find_children("*", "Label", true, false):
		out += (l as Label).text + "\n"
	for b in n.find_children("*", "Button", true, false):
		out += (b as Button).text + "\n"
	return out

func _run() -> void:
	InputSetup.ensure_actions()
	# --- the path cards -------------------------------------------------------
	for arc_id in GameState.arcs:
		var a: Dictionary = GameState.arcs[arc_id]
		check((a.get("pitch", []) as Array).size() >= 2, "%s card has a how-it-plays list" % arc_id)
		check(str(a.get("feel", "")) != "", "%s card has a tone line" % arc_id)
		for pid in a.get("faces", []):
			check(str(pid) in a["playable"], "%s face %s is a playable hero" % [arc_id, pid])
	change_scene_to_file("res://scenes/title.tscn")
	for i in 6:
		await process_frame
	var t := current_scene
	t.call("_show_arcs")
	for i in 3:
		await process_frame
	var txt := _texts(t)
	for arc_id in GameState.arcs:
		for line in GameState.arcs[arc_id]["pitch"]:
			check(txt.contains(str(line)), "arc picker shows: %s" % line)
	var faces := 0
	for tr in t.find_children("*", "TextureRect", true, false):
		if (tr as TextureRect).texture != null and (tr as TextureRect).custom_minimum_size == Vector2(34, 40):
			faces += 1
	check(faces >= 5, "arc cards show hero faces (%d)" % faces)
	check(txt.contains("Each save slot keeps its own path"), "picker says the other path stays playable")

	# --- penguins: locked sanctuary plans say what opens them ----------------
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["quests"].append({"id": "clear_meadow", "text": "", "done": true})
	GameState.run["quests"].append({"id": "spark", "text": "", "done": true})
	GameState.run["quests"].append({"id": "sky_stair", "text": "", "done": true})
	check(Builds.gate("pool").contains("merkitties"), "pool lock names the merkitties (%s)" % Builds.gate("pool"))
	check(Builds.gate("burrow").contains("crystal babies"), "burrow lock names the babies (%s)" % Builds.gate("burrow"))
	check(Builds.gate("shrine").contains("Catkins"), "shrine lock names Catkins (%s)" % Builds.gate("shrine"))
	GameState.run["flags"]["meow_taught"] = true
	check(Builds.gate("shrine") == "", "shrine opens once the Meow Pow Wow is taught (%s)" % Builds.gate("shrine"))
	# Morning line names only what holds something.
	GameState.run["gifts"] = {"pool": {"trout": 1}, "burrow": {}}
	var ml := Sanctuary.morning_line()
	check(ml.contains("pool") and not ml.contains("burrow"), "morning line names only the pool (%s)" % ml)
	GameState.run["gifts"] = {"pool": {"trout": 1}, "burrow": {"coal": 2}}
	ml = Sanctuary.morning_line()
	check(ml.contains("pool") and ml.contains("burrow"), "morning line names both (%s)" % ml)
	# Intros: every sanctuary building has one, played once.
	for id in ["pool", "burrow", "shrine", "litter", "campfire"]:
		check(ArcIntro.has_intro(id), "%s has a first-use intro" % id)
		check(ArcIntro.script_for(id).size() >= 1, "%s intro has lines" % id)
	check(str(ArcIntro.script_for("pool")[0]["who"]) == "Mer", "Mer explains the pool")

	# --- gangsters: intros, heat line, laundromat ---------------------------
	GameState.new_run("gangsters", "dad", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	for id in ["print_shop", "laundromat", "training", "soda"]:
		check(ArcIntro.has_intro(id), "%s has a first-use intro" % id)
	var s: Array = ArcIntro.script_for("laundromat")
	check(str(s[0]["who"]) == "" and str(s[1]["who"]) == "Note", "an unrecruited Deuce leaves a note")
	GameState.run["flags"]["crew_deuce"] = true
	s = ArcIntro.script_for("laundromat")
	check(str(s[0]["who"]) == "Deuce", "a recruited Deuce says it himself")
	var press_txt := ""
	for l in ArcIntro.script_for("print_shop"):
		press_txt += str(l["text"])
	check(press_txt.contains("USE") and press_txt.contains("heat") and press_txt.contains("laundromat"), "press intro covers passing, heat and washing")
	check(str(Builds.next_def("print_shop").get("desc", "")).contains("USE"), "press plan says how bills are used")
	check(str(GameState.items["thug_cash"]["desc"]).contains("safe to sell"), "rolled bills read as real cash, not printed ones")
	# Play the first use on the farm: the intro runs once, then the building's own menu.
	GameMap.next_spawn = Vector2.ZERO
	GameState.run["scene"] = "farm"
	if not GameState.run.has("builds"):
		GameState.run["builds"] = {}
	GameState.run["builds"]["laundromat"] = 1
	change_scene_to_file("res://scenes/farm.tscn")
	for i in 8:
		await process_frame
	var m := current_scene as GameMap
	var d := Dialogue.instance(self)
	m.call("_station", "laundromat")
	for i in 3:
		await process_frame
	check(GameState.run["flags"].has("arc_intro_laundromat"), "first laundromat use plays its intro")
	check(not ArcIntro.has_intro("laundromat"), "the intro plays only once")
	var seen := ""
	for k in 60:
		if d.active:
			seen += (d._text.text if d._in_choice else d._full) + "\n"
			if d._in_choice:
				d._choose("", d._choices.get_child_count() - 1)
			else:
				d._advance()
		await process_frame
	check(seen.contains("coin flip"), "Deuce's intro plays first (%s)" % seen.left(80))
	check(seen.contains("No bills on you"), "an empty-handed laundromat visit says where bills come from")
	# Heat only reports once it matters.
	check(Racket.heat() == 0 and not GameState.run["flags"].has("heat_told"), "a fresh gangster run has no heat yet")
	print("arc_intro_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

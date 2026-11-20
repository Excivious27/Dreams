extends SceneTree
## Quest tracker (QuestTracker): the checkbox list, tracking a townsfolk job, the
## corner compass target (story / townsfolk giver / the way down in the mines),
## finished quests letting go, and the menu tab rows.
##   godot --headless --path . -s res://tools/quest_tracker_test.gd [-- /tmp/shots]
var fails := 0
var out := ""
var n := 0


func _initialize() -> void:
	seed(7)
	Campaign.bypass = true
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func frames(k: int) -> void:
	for i in k:
		await process_frame


func shot(tag: String) -> void:
	if out == "":
		return
	n += 1
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/qt_%02d_%s.png" % [out, n, tag])


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
		DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	GameState.tick_quests()
	for q in GameState.run["quests"]:
		if str(q["id"]) == "first_harvest":
			q["done"] = true
	GameState.tick_quests()
	check(QuestTracker.tracked() == "", "a new game follows the story")
	var open := QuestTracker.open_quests()
	check(not open.is_empty() and bool(open[0]["main"]), "story steps come first in the list (%s)" % str(open.map(func(q: Dictionary) -> String: return str(q["id"]))))
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/farm.tscn")
	await frames(30)
	var farm := current_scene as GameMap
	var t := QuestTracker.target(farm)
	check(t == GoalLine.target(farm), "story: the compass follows the goal line's place")
	check(t != Vector2.ZERO, "meet_town: the compass points at the town road from the farm")
	await shot("farm_story")
	# A townsfolk job: track it, the compass heads for town (the giver lives there).
	var sq: Dictionary = GameState.side_quest_for("maple")
	if sq.is_empty():
		sq = GameState.quests_data["side"][0]
	GameState.add_quest(str(sq["id"]), str(sq["text"]))
	QuestTracker.track(str(sq["id"]))
	check(QuestTracker.tracked() == str(sq["id"]), "ticking a townsfolk job tracks it")
	check(GameState.next_step() == str(sq["text"]), "the goal line shows the tracked job")
	var tt := QuestTracker.target(farm)
	check(tt != Vector2.ZERO and tt == GoalLine.exit_toward(farm, "town"), "tracked job: the compass points to the town exit")
	var cap := QuestTracker.caption(farm, tt)
	check(cap.contains("/") or (cap.ends_with("m") and cap.trim_suffix("m").is_valid_int()), "caption shows the job count or distance (%s)" % cap)
	await shot("farm_job")
	QuestTracker.track(str(sq["id"]))
	check(QuestTracker.tracked() == "", "ticking it again goes back to the story")
	QuestTracker.track(str(sq["id"]))
	GameState.complete_quest(str(sq["id"]))
	check(QuestTracker.tracked() == "", "a finished job lets go of the compass")
	# Tracking a main quest keeps the story arrow (it IS the story).
	GameState.run["pinned_quest"] = "meet_town"
	check(GoalLine.goal_place()[0] == "town", "a ticked story step keeps the goal place")
	GameState.run["pinned_quest"] = ""
	# Menu tab: one checkbox row per open quest, a tick on the tracked one.
	var menu: GameMenu = null
	for ch in farm.get_children():
		if ch is GameMenu:
			menu = ch
	check(menu != null, "the map has a menu")
	if menu:
		menu.toggle()
		menu.set("_tab", "Quests")
		menu.call("_refresh")
		await frames(3)
		var rows := 0
		for b in menu.find_children("*", "Button", true, false):
			if (b as Button).draw.get_connections().size() > 0 and (b as Button).custom_minimum_size.y == 24:
				rows += 1
		var want := 1  # one "Follow the story" row (C4), then one per townsfolk job
		for oq: Dictionary in QuestTracker.open_quests():
			if not (oq["main"] or str(oq["giver"]) == ""):
				want += 1
		check(rows >= want, "story row + every townsfolk job has a checkbox row (%d rows, want %d)" % [rows, want])
		await shot("menu_quests")
		menu.toggle()
		await frames(3)
	await _c7(farm)
	# A long choice list pins its way-out row below the scroll (c3_03 #2).
	var dl := Dialogue.instance(self)
	var opts: Array = []
	for i in 16:
		opts.append("Option number %d with a few words" % i)
	opts.append("Leave")
	dl.say([{"text": "Pick one.", "choice": opts}])
	await frames(4)
	check(dl._pin.get_child_count() == 1 and (dl._pin.get_child(0) as Button).text == "Leave", "long list: the way out is pinned in view")
	await shot("pinned_way_out")
	(dl._pin.get_child(0) as Button).pressed.emit()
	await frames(4)
	check(not dl.active and dl.last_choice == opts.size() - 1, "the pinned row picks the way out (%d)" % dl.last_choice)
	# The mines: the compass always points to the way down.
	GameState.run["flags"]["mine_seen"] = true
	(load("res://scripts/mine.gd") as Variant).force_seed = 3
	change_scene_to_file("res://scenes/mine.tscn")
	await frames(30)
	var mine := current_scene as GameMap
	if mine and mine.has_method("pointer_target"):
		var pt: Vector2 = mine.call("pointer_target")
		check(QuestTracker.target(mine) == (pt if pt != Vector2.ZERO else mine.cell_center(mine.get("_ladder"))), "mines: the compass follows the way down")
		check(QuestTracker.target(mine) != Vector2.ZERO, "mines: the compass always has a way down to point at")
		await shot("mine")
	else:
		check(false, "mine scene loads")
	print("quest_tracker_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)


## C7 (c7_06): outer regions in the route graph, out-of-town givers, giverless and
## place-of-work jobs, and a compass place for every later main step.
func _c7(farm: GameMap) -> void:
	for reg in ["orchard_hills", "highlands", "quarry", "marsh", "riverlands", "hollow_heart"]:
		check(GoalLine.next_hop("farm", reg) != "", "route farm -> %s (%s)" % [reg, GoalLine.next_hop("farm", reg)])
	check(GoalLine.next_hop("farm", "sky") == "forest", "route farm -> sky goes by the forest's great tree (%s)" % GoalLine.next_hop("farm", "sky"))
	check(GoalLine.next_hop("town", "moon") == "mountain", "route town -> moon goes by the mountain pad")
	check(GoalLine.next_hop("farm", "wastes") == "meadow", "route farm -> wastes (penguins) through the meadow")
	check(QuestTracker.npc_scene("marlowe") == "lake" and QuestTracker.npc_scene("orla") == "lake", "Marlowe and Orla live at the lake")
	check(QuestTracker.npc_scene("tam") == "orchard_hills", "Tam lives in Orchard Hills")
	# Marlowe's job: from the farm the compass heads for the lake, not town.
	for q in GameState.quests_data.get("side", []):
		if str(q.get("giver", "")) == "marlowe":
			GameState.add_quest(str(q["id"]), str(q["text"]))
			GameState.run["pinned_quest"] = str(q["id"])
			check(QuestTracker.target(farm) != Vector2.ZERO and QuestTracker.target(farm) == GoalLine.exit_toward(farm, "lake"), "Marlowe's job -> the lake exit")
			GameState.complete_quest(str(q["id"]))
			break
	# Tam's job: the forest exit (Orchard Hills is north of the forest).
	for q in GameState.quests_data.get("side", []):
		if str(q.get("giver", "")) == "tam":
			GameState.add_quest(str(q["id"]), str(q["text"]))
			GameState.run["pinned_quest"] = str(q["id"])
			check(QuestTracker.target(farm) != Vector2.ZERO and QuestTracker.target(farm) == GoalLine.exit_toward(farm, "forest"), "Tam's job -> the forest exit")
			GameState.complete_quest(str(q["id"]))
			break
	# A giverless job with a place: the Rec Center visit.
	GameState.add_quest("rec_visit", "Visit the new Rec Center south-east of the library.")
	check(not QuestTracker.job_place("rec_visit").is_empty(), "rec_visit has a place")
	GameState.run["pinned_quest"] = "rec_visit"
	check(QuestTracker.target(farm) == GoalLine.exit_toward(farm, "town") and QuestTracker.target(farm) != Vector2.ZERO, "rec_visit -> the town road")
	GameState.complete_quest("rec_visit")
	GameState.run["pinned_quest"] = ""
	# A rec_best job points at the Rec Center while not done.
	var rb := ""
	for q in GameState.quests_data.get("side", []):
		if (q.get("done_when", {}) as Dictionary).has("rec_best"):
			rb = str(q["id"])
			break
	if rb != "":
		check(str(QuestTracker.job_place(rb).get("what", "")) == "door:rec", "%s points at the Rec Center first" % rb)
		check(QuestTracker.progress(rb).begins_with("best "), "%s caption shows the best score (%s)" % [rb, QuestTracker.progress(rb)])
	check(str(QuestTracker.job_place("mer_crystals").get("scene", "")) == "meadow", "mer_crystals points at the meadow mine")
	# Skill progress caption.
	var save_q: Array = (GameState.run["quests"] as Array).duplicate(true)
	var save_f: Dictionary = (GameState.run["flags"] as Dictionary).duplicate(true)
	# Later main steps: every one gets a place (regions open: Campaign.bypass).
	var want := {"commander": ["wastes", "thing:boss"], "knight": ["sky", "thing:boss"], "teleporter": ["moon", "thing:tele"], "finale": ["moon", "thing:spire"]}
	for qid: String in want:
		GameState.run["quests"] = [{"id": qid, "text": qid, "done": false}]
		check(GoalLine.goal_place() == want[qid], "%s -> %s (%s)" % [qid, str(want[qid]), str(GoalLine.goal_place())])
	GameState.run["quests"] = [{"id": "sky_stair", "text": "", "done": false}]
	check(GoalLine.goal_place()[0] == "mountain", "sky_stair before the babies -> the mountain pass")
	GameState.run["flags"]["babies_done"] = true
	GameState.run["flags"]["campfire_done"] = true
	check(GoalLine.goal_place() == ["forest", "thing:great_tree"], "sky_stair after the camp -> the great tree")
	GameState.run["quests"] = [{"id": "knight", "text": "", "done": false}]
	check(GoalLine.text("knight").contains("great tree"), "knight goal line says how to reach the sky islands")
	var f := farm.scene_id()
	check(f == "farm" and GoalLine.target(farm) == GoalLine.exit_toward(farm, "forest") and GoalLine.target(farm) != Vector2.ZERO, "knight: from the farm the arrow points at the forest")
	GameState.run["quests"] = save_q
	GameState.run["flags"] = save_f
	# Gangster arc: later steps have places and words.
	var keep: Dictionary = GameState.run.duplicate(true)
	GameState.run["arc"] = "gangsters"
	if GameState.is_penguins():
		check(false, "arc switch for the gang checks")
	else:
		var gw := {"docks": "docks", "neon": "neon", "pit": "underground", "uptown": "uptown"}
		for qid: String in gw:
			GameState.run["quests"] = [{"id": qid, "text": qid, "done": false}]
			check(GoalLine.goal_place() == [gw[qid], "thing:boss"], "gang %s -> %s boss (%s)" % [qid, gw[qid], str(GoalLine.goal_place())])
			check(GoalLine.text(qid) != "" and GoalLine.text(qid).length() <= 112, "gang %s goal line: %s" % [qid, GoalLine.text(qid)])
		check(GoalLine.next_hop("farm", "docks") == "meadow", "gang route farm -> docks through the meadow (%s)" % GoalLine.next_hop("farm", "docks"))
		check(GoalLine.next_hop("farm", "wastes") == "", "the Wastes aren't on the gangster map")
		GameState.run["quests"] = [{"id": "gang", "text": "", "done": false}]
		GameState.run["flags"]["hideout_seen"] = true
		check(GoalLine.goal_place() == ["hideout", "npc:deuce"], "gang crew step in Hideout -> Deuce")
	GameState.run = keep

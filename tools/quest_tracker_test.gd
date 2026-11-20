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
	check(cap.contains("/") or cap.is_valid_int(), "caption shows the job count or distance (%s)" % cap)
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

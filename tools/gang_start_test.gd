extends SceneTree
## CONDUCT 1: a new gangster run as a new player meets it: farm intro, town,
## days 1-2 (mornings, mail), then the meadow, Sal, the outskirts and the
## Hideout with its first crew. Logs every line/choice/toast/goal and checks
## the order and wording fixes. With a dir after "--" (under xvfb) it also
## saves a screenshot per dialogue line.
##   godot --headless --path . -s res://tools/gang_start_test.gd
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/gang_start_test.gd -- /tmp/gd
var out := ""
var n_shot := 0
var _seen_toasts := 0
var fails := 0
var lines_seen: Array = []


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func qtext(id: String) -> String:
	for q in GameState.run["quests"]:
		if str(q["id"]) == id:
			return str(q["text"])
	return ""


func seen(part: String) -> bool:
	for l in lines_seen:
		if str(l).contains(part):
			return true
	return false


func _initialize() -> void:
	seed(7)
	Campaign.bypass = true
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func press(action: String, hold := 2) -> void:
	Input.action_press(action)
	await frames(hold)
	Input.action_release(action)
	await frames(1)


func shot(name: String) -> void:
	if out == "":
		return
	await frames(2)
	n_shot += 1
	root.get_texture().get_image().save_png("%s/%03d_%s.png" % [out, n_shot, name])


func log_toasts() -> void:
	var tl: Array = GameState.run.get("toast_log", [])
	# toast_log is capped at 40; good enough for two days
	for i in range(_seen_toasts, tl.size()):
		print("  TOAST: ", tl[i])
	_seen_toasts = tl.size()
	for nt in GameState.run.get("notes", []):
		print("  NOTE: ", nt)


func goal() -> void:
	var m := current_scene as GameMap
	if m and m.hud:
		print("  GOAL: ", GameState.next_step())


## Read every line of the open dialogue, picking `pick` at each choice.
func drain(tag: String, pick := 0, max_lines := 60) -> void:
	var d := Dialogue.instance(self)
	for w in 40:
		if d.active:
			break
		await frames(3)
	var last := ""
	for i in max_lines:
		if not d.active:
			break
		if d._in_choice:
			var opts: Array = []
			for c in d._choices.get_children():
				if c is Button:
					opts.append((c as Button).text)
			print("  CHOICE: ", opts)
			await shot(tag + "_choice")
			for k in pick:
				await press("down")
			await press("a")
			await frames(6)
			continue
		# finish typing
		if d._typing:
			await press("a")
			await frames(2)
		var line := "%s: %s" % [d._who.text if d._who.visible else "", d._full]
		if line != last:
			print("  LINE ", line)
			lines_seen.append(line)
			await shot(tag)
			last = line
		await press("a")
		await frames(6)
	log_toasts()


func go(scene: String, spawn := Vector2.ZERO) -> GameMap:
	GameMap.next_spawn = spawn
	change_scene_to_file("res://scenes/%s.tscn" % scene)
	await frames(40)
	return current_scene as GameMap


func _run() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		out = OS.get_cmdline_user_args()[0]
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	GameState.new_run(OS.get_environment("ARC") if OS.get_environment("ARC") != "" else "gangsters", "pax", "Pax", "Dreamhollow", "Rex")
	print("== DAY 1 farm intro")
	var farm := await go("farm")
	for k in 12:
		await drain("intro")
		if bool(GameState.run["intro_done"]):
			break
		await frames(30)
	await frames(20)
	log_toasts()
	goal()
	print("  QUESTS: ", GameState.run["quests"])
	check(bool(GameState.run["intro_done"]), "intro finished")
	check(qtext("meet_town").contains("bought"), "meet_town carries the gangster wording: " + qtext("meet_town"))
	await shot("after_intro")
	var seeds0 := GameState.count("strawberry_seed")
	farm._mailbox()
	await drain("mail1")
	check(not seen("A second envelope") and GameState.count("strawberry_seed") == seeds0, "day 1: no second letter from M. yet")
	print("== town")
	var town := await go("town")
	for k in 6:
		await drain("town_%d" % k)
		await frames(30)
	await frames(30)
	goal()
	check(seen("Sal: Sal. I sit on this bench"), "Sal introduces himself on the town tour")
	check(seen("A man with a bad knee"), "the arrival names Sal as a man (his portrait)")
	await shot("town_free")
	for id in ["sal", "maple", "gideon", "alder", "bram"]:
		for n in town.npcs:
			if n.id == id:
				print("== talk ", id)
				town._talk(n)
				await drain("talk_" + id)
	goal()
	print("  HINTS: ", GameState.run.get("hints", []))
	print("== sleep -> day 2")
	var house := await go("house")
	await drain("house_enter")
	house._sleep()
	await frames(80)
	await drain("morning2")
	await frames(30)
	await drain("morning2b")
	goal()
	check(seen("Day 2."), "the day 2 morning summary played")
	check(not seen("Heat 0/5"), "no unexplained 'Heat 0/5' line before any heat")
	await shot("day2_house")
	farm = await go("farm")
	await drain("farm2")
	print("== mailbox")
	var seeds1 := GameState.count("strawberry_seed")
	farm._mailbox()
	await drain("mail2")
	goal()
	check(seen("A second envelope"), "day 2: M.'s second letter (not the intro letter again)")
	check(not seen("The plot is yours under the name on the deed"), "the intro's letter isn't delivered twice")
	check(GameState.count("strawberry_seed") == seeds1 + 3, "M.'s letter brings 3 strawberry seeds")
	check(Mail.unread() == 0, "one tap on the box also read the waiting mail")
	await shot("day2_farm")
	town = await go("town")
	await drain("town2")
	for id in ["sal", "maple"]:
		for n in town.npcs:
			if n.id == id:
				print("== talk ", id, " day2")
				town._talk(n)
				await drain("talk2_" + id)
	print("== sleep -> day 3")
	house = await go("house")
	house._sleep()
	await frames(80)
	await drain("morning3")
	goal()
	print("  QUESTS: ", GameState.run["quests"])
	await _phase2()
	print("gang_start_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


## Day 3+: the meadow, the President's man, Sal, the Hideout and its first two crew.
func _phase2() -> void:
	print("== meadow")
	var meadow := await go("meadow")
	await drain("meadow")
	goal()
	meadow._summon_boss()
	await drain("boss")
	await frames(20)
	meadow._boss.hit(9999, meadow.player.position)
	await frames(60)
	for k in 4:
		await drain("boss_down_%d" % k)
		await frames(30)
	goal()
	print("  QUESTS: ", GameState.run["quests"])
	check(not seen("sixty crystals"), "the boss-down scene and the coat scene agree")
	check(seen("leaving his coat behind"), "the coat scene played")
	# C7 (c7_12): the coat scene's choice and gifts.
	check(GameState.run["decisions"].has("photo"), "the photo choice was recorded (%s)" % str(GameState.run["decisions"].get("photo", "-")))
	check(GameState.count("burner_phone") >= 1, "the coat held a burner phone")
	check(GameState.has_quest("hideout"), "the Hideout step is in the log")
	var town := await go("town")
	await drain("town3")
	for n in town.npcs:
		if n.id == "sal":
			print("== talk sal after meadow")
			town._talk(n)
			await drain("sal3")
			await frames(30)
			await drain("sal3b")
	goal()
	check(GameState.run["flags"].has("sal_recruited"), "telling Sal sets sal_recruited")
	var cm := await go("crystal_meadow")
	await drain("outskirts")
	var marked_out := false
	for e in cm.enemies:
		if is_instance_valid(e) and e.has_meta("marked"):
			marked_out = true
	check(not marked_out, "no Marked ambush on the way to the Hideout the first time")
	print("== hideout")
	var hide := await go("hideout")
	for k in 4:
		await drain("hideout_%d" % k)
		await frames(30)
	goal()
	check(seen("Up close it smells"), "the Hideout's story arrival played")
	check(not GameState.run["flags"].has("bt_invited"), "the drill invite waits until the first crew member")
	check(GameState.has_quest("gang") and not GameState.has_quest("docks"), "goal is the first crew, not the docks yet")
	check(GameState.next_step().contains("Deuce"), "goal line names Deuce: " + GameState.next_step())
	await shot("hideout_free")
	for id in ["deuce", "mama_rosa"]:
		for n in hide.npcs:
			if n.id == id:
				print("== talk ", id)
				hide._talk_npc(n)
				await drain("h_" + id, 1)
				await frames(30)
				await drain("h2_" + id)
	goal()
	print("  QUESTS: ", GameState.run["quests"])
	print("  FLAGS: ", GameState.run["flags"].keys())
	check(GameState.run["flags"].has("crew_deuce"), "Deuce joined")
	check(seen("Your first crew member"), "the first recruit explains what crew is for")
	check(GameState.run["flags"].has("bt_invited"), "Sal's drill invite came after the first crew member")
	check(GameState.has_quest("docks"), "the docks open once the crew has started")

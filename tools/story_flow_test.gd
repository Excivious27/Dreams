extends SceneTree
## C7 P2: story beat flow. One beat at a time, quest-done backstop, beats wait
## for full-screen UIs, gated choices re-arm without effects, skippable beats,
## story_busy (a Callable bug left the freeze-safety release dead), hero line
## filters, "pre" effects, painted panels that exist, penguin canon lines.
## Run: godot --headless --fixed-fps 60 --path . -s res://tools/story_flow_test.gd
var fails := 0


func _initialize() -> void:
	seed(7)
	Campaign.bypass = true
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


## Wait game time (never the wall clock).
func game_wait(sec: float) -> void:
	var gt := 0.0
	while gt < sec:
		await process_frame
		gt += root.get_process_delta_time()


func _advance_all() -> void:
	var d := Dialogue.instance(self)
	for k in 120:
		if not d.active and not Story.is_playing():
			break
		if d.active:
			if d._in_choice:
				var btns := d._choices.get_children()
				if not btns.is_empty():
					(btns[0] as Button).pressed.emit()
			else:
				d._advance()
		await process_frame
		await process_frame


func _beat(id: String) -> Dictionary:
	for b in Story.beats():
		if str(b["id"]) == id:
			return b
	return {}


func _load(scene: String) -> GameMap:
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/%s.tscn" % scene)
	await frames(12)
	await _advance_all()
	return current_scene as GameMap


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Hero", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	for f in ["town_seen", "meadow_seen", "cm_seen", "mountain_seen", "sky_seen"]:
		GameState.run["flags"][f] = true
	var m: GameMap = await _load("farm")
	check(m != null, "farm loaded")
	var d := Dialogue.instance(self)

	# 1) story_busy is a function now (player.gd called the Callable: always truthy).
	check(not GameMenu.story_busy(self), "story_busy false with nothing playing")
	d.begin_skippable(m)
	check(GameMenu.story_busy(self), "story_busy true during a skippable scene (opening fades)")
	d.end_skippable()
	# Freeze safety: a hero frozen with nothing on screen is released after FREEZE_SAFETY.
	m.player.frozen = true
	GameState.run["story_pending"] = "nothing"  # a hung beat (pending, nothing playing) must not block the release
	await game_wait(float(m.player.FREEZE_SAFETY) + 1.0)
	check(not m.player.frozen, "frozen hero with nothing on screen is released")
	GameState.run.erase("story_pending")

	# 2) Quest-done backstop: the spark quest finished while no map heard it.
	GameState.add_quest("spark", "spark")
	for q in GameState.run["quests"]:
		if q["id"] == "spark":
			q["done"] = true
	GameState.run["flags"]["meow_taught"] = true
	check(not Story.fired("p2_spark"), "p2_spark not fired yet")
	await game_wait(2.0)
	await _advance_all()
	check(Story.fired("p2_spark"), "missed quest-done beat p2_spark plays from Story.tick")
	check(GameState.run["flags"].has("catship_done") and GameState.run["flags"].has("catkins_sent"), "its effects ran (catship_done, catkins_sent)")
	await game_wait(0.6)
	await _advance_all()

	# 3) A beat waits while a full-screen UI pauses the tree.
	GameState.add_quest("commander", "commander")
	get_root().get_tree().paused = true
	Hud.modal_rect = Rect2(0, 0, 270, 480)
	for q in GameState.run["quests"]:
		if q["id"] == "commander":
			q["done"] = true
	Story.on_quest_done(m, "commander")
	await frames(30)
	check(not Story.fired("p2_locket") and not d.active, "quest-done beat waits under a paused full-screen UI")
	get_root().get_tree().paused = false
	Hud.modal_rect = Rect2()
	await frames(10)
	await _advance_all()
	check(Story.fired("p2_locket"), "it plays once the screen closes")
	await game_wait(0.6)
	await _advance_all()

	# 4) One beat at a time: while a beat plays, talk/tick/morning don't start another.
	Story._playing = 1
	check(GameMenu.story_busy(self), "story_busy while a beat is playing")
	var talked: bool = await Story.talk(m, "finn")
	check(not talked, "Story.talk yields while a beat plays")
	Story._playing = 0

	# 5) Gated choice: the beat is re-armed and its effects don't run.
	var gated := {"id": "t_gate", "lines": [{"who": "", "text": "Pay?", "choice": ["Pay.", "No."], "key": "t_gate", "gates": {"0": {"crystals": 999999}}}], "effects": {"flags": ["t_gate_fx"]}}
	m.later(func() -> void: await Story.play(m, gated))
	await frames(3)
	await _advance_all()
	await frames(5)
	check(not Story.fired("t_gate"), "gated beat re-armed (st_ flag erased)")
	check(not GameState.run["flags"].has("t_gate_fx"), "gated beat's effects did not run")
	check(not GameState.run.has("story_pending") and not m.player.frozen, "gated beat leaves no pending scene and a free hero")

	# 6) Every story beat is skippable up to its choice.
	var long := {"id": "t_skip", "lines": [{"who": "", "text": "one"}, {"who": "", "text": "two"}, {"who": "", "text": "three"}], "effects": {"flags": ["t_skip_fx"]}}
	m.later(func() -> void: await Story.play(m, long))
	await frames(3)
	check(d.skippable, "a playing beat offers Skip")
	d.skip()
	await frames(10)
	await _advance_all()
	check(GameState.run["flags"].has("t_skip_fx") and not d.skippable, "skipped beat still applies its effects; Skip ends")

	# 7) Hero filters and "pre" effects.
	GameState.run["playable"] = "big_jim"
	var lines: Array = Story._fill([{"who": "", "text": "a", "not_hero": "big_jim"}, {"who": "", "text": "b", "only_hero": "big_jim"}, {"who": "", "text": "c", "only_hero": ["penguin_f", "penguin_m"]}])
	check(lines.size() == 1 and str(lines[0]["text"]) == "b", "only_hero/not_hero filter lines (%d)" % lines.size())
	GameState.run["playable"] = "kairi"
	check((_beat("p5_win").get("pre", {}) as Dictionary).has("clear_kind"), "p5_win clears the boss and adds before its lines")

	# 8) Data: every pic exists; the penguin canon lines are in.
	var missing := []
	var all := (Story.data().get("penguins", []) as Array) + (Story.data().get("gangsters", []) as Array)
	var stack: Array = all.duplicate()
	while not stack.is_empty():
		var x: Variant = stack.pop_back()
		if x is Dictionary:
			var p := str((x as Dictionary).get("pic", ""))
			if p != "" and p != "none":
				var path := "res://art/gen/" + (p if "/" in p else "ui/" + p) + ".png"
				if not ResourceLoader.exists(path):
					missing.append(p)
			stack.append_array((x as Dictionary).values())
		elif x is Array:
			stack.append_array(x)
	check(missing.is_empty(), "every story pic exists %s" % str(missing))
	var txt := JSON.stringify(Story.data().get("penguins", []))
	for w in ["Crystopia", "Celestica", "Mount Prismatica", "Teacher.", "kingdoms", "I am Fennimore", "C-O-L-D-Y", "That bell broke for me", "twenty-one years"]:
		check(w in txt, "penguin story says '%s'" % w)
	check(not ("somebody's dog. It still is" in txt) and not ("C-O-L-D-I-E" in txt), "old contradictions gone")
	for id in ["p2_nova_dream", "p3_whisper", "p5_elder_coral", "p5_elder_kelp", "p5_elder_ice", "p5_elder_ember"]:
		check(not _beat(id).is_empty(), "beat %s exists" % id)
	# Each elder beat keys on the flag colony.gd really sets.
	for pair in [["coral", "colony_coral_ward"], ["kelp", "colony_tideswim"], ["ice", "colony_frost_step"], ["ember", "colony_starfire"]]:
		check(str(_beat("p5_elder_" + pair[0]).get("when", {}).get("flags", [])).contains(pair[1]), "p5_elder_%s waits for %s" % pair)

	print("STORY FLOW DONE, failures: %d" % fails)
	quit(1 if fails > 0 else 0)

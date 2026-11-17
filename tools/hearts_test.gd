extends SceneTree
## Heart arcs: every villager's five milestones play in order when talked to,
## the ♥6 quest is offered, daily lines change.
var fails := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1
func frames(n: int) -> void:
	for i in n: await process_frame
func _advance_all() -> void:
	var d := Dialogue.instance(self)
	for k in 60:
		if not d.active: break
		if d._in_choice:
			var btns := d._choices.get_children()
			if not btns.is_empty(): (btns[0] as Button).pressed.emit()
		else: d._advance()
		await process_frame; await process_frame
func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Hero", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["town_seen"] = true
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/town.tscn")
	await frames(12)
	var m := current_scene as GameMap
	await _advance_all()
	var vill := Hearts.data().keys()
	check(vill.size() == 25, "25 villagers with arcs")
	for id in vill:
		var fr: Dictionary = GameState.run["friendship"]
		for n in [2, 4, 6, 8, 10]:
			fr[id] = n * 25
			check(Hearts.due(id) == n, "%s: ♥%d due" % [id, n])
			m.later(func() -> void: await Hearts.talk(m, id))
			await frames(2)
			await _advance_all()
			check(Hearts.seen_level(id) == n, "%s: ♥%d played" % [id, n])
			check(Hearts.daily(id) != "", "%s: daily line after ♥%d" % [id, n])
		var q6 := str(Hearts.data()[id]["quest6"])
		var qd := GameState._quest_def(q6)
		if qd.is_empty() or GameState._cond_ok(qd.get("when", {})):
			check(GameState.has_quest(q6), "%s: ♥6 quest %s offered" % [id, q6])
		else:
			check(not GameState.has_quest(q6), "%s: ♥6 quest %s waits for its own gate %s" % [id, q6, str(qd.get("when"))])
	check(Hearts.standing_with_you().size() == 25, "all 25 standing with you at ♥10")
	print("HEARTS DONE, failures: %d" % fails)
	quit(1 if fails > 0 else 0)

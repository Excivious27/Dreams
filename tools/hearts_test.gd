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
	# ♥8 can wait on another villager's ♥8 (Hearts.NEEDS_FLAG): those go first.
	var first := ["granite", "bram", "gideon"]
	vill.sort_custom(func(a: String, b: String) -> bool: return a in first and not (b in first))
	for id in vill:
		var fr: Dictionary = GameState.run["friendship"]
		var offered := false
		for n in [2, 4, 6, 8, 10]:
			fr[id] = n * 25
			if n == 8:
				# ♥8 waits for the ♥6 quest (Hearts.AFTER_Q6) or a flag: settle them first.
				var q8 := Hearts.quest6(id)
				offered = q8 != "" and GameState.has_quest(q8)
				if q8 != "" and not GameState._quest_def(q8).is_empty():
					if not GameState.has_quest(q8):
						GameState.add_quest(q8, "x")
					for qq in GameState.run["quests"]:
						if qq["id"] == q8:
							qq["done"] = true
				if Hearts.NEEDS_FLAG.has(id) and not str(Hearts.NEEDS_FLAG[id]).begins_with("hv_"):
					GameState.run["flags"][Hearts.NEEDS_FLAG[id]] = true
			check(Hearts.due(id) == n, "%s: ♥%d due" % [id, n])
			m.later(func() -> void: await Hearts.talk(m, id))
			await frames(2)
			await _advance_all()
			check(Hearts.seen_level(id) == n, "%s: ♥%d played" % [id, n])
			check(Hearts.daily(id) != "", "%s: daily line after ♥%d" % [id, n])
		var q6 := Hearts.quest6(id)
		var qd := GameState._quest_def(q6)
		if qd.is_empty() or GameState._cond_ok(qd.get("when", {})):
			check(offered, "%s: ♥6 quest %s offered" % [id, q6])
		else:
			check(not offered, "%s: ♥6 quest %s waits for its own gate %s" % [id, q6, str(qd.get("when"))])
	check(Hearts.standing_with_you().size() == 25, "all 25 standing with you at ♥10")
	print("HEARTS DONE, failures: %d" % fails)
	quit(1 if fails > 0 else 0)

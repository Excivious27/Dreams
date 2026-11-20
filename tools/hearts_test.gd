extends SceneTree
## Heart arcs: every villager's five milestones play in order when talked to,
## the ♥6 quest is offered, daily lines change.
var fails := 0
func _initialize() -> void:
	seed(7)
	Campaign.bypass = true  # tests walk into every region
	_run.call_deferred()
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
	for arc in ["penguins", "gangsters"]:
		await _pass(arc)
		await _settle()
	print("HEARTS DONE, failures: %d" % fails)
	# C9 (rc134 flake): quit with no live map (bake SubViewports, audio players
	# mid-free) so engine work never touches /root while the tree goes down.
	unload_current_scene()
	await _settle()
	quit(1 if fails > 0 else 0)
## Let deferred frees, bakes and finished-audio frees run out before a scene change or quit.
func _settle() -> void:
	await frames(5)
## One arc's walk through every villager's five milestones (C7: both arcs).
func _pass(arc: String) -> void:
	GameState.new_run(arc, "kairi" if arc == "penguins" else "pax", "Hero", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["town_seen"] = true
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/town.tscn")
	await frames(12)
	var m := current_scene as GameMap
	await _advance_all()
	var vill := Hearts.data().keys().filter(func(x: String) -> bool: return Hearts.in_arc(x))  # Catkins: penguins only
	check(vill.size() >= 25, "%s: %d villagers with arcs" % [arc, vill.size()])
	# ♥8 can wait on another villager's ♥8 (Hearts.NEEDS_FLAG): those go first.
	var first := ["granite", "bram", "gideon", "hazel"]
	var rank := func(x: String) -> int: return first.find(x) if x in first else 99
	vill.sort_custom(func(a: String, b: String) -> bool: return rank.call(a) < rank.call(b))
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
			check(Hearts.due(id) == n, "%s %s: ♥%d due" % [arc, id, n])
			m.later(func() -> void: await Hearts.talk(m, id))
			await frames(2)
			await _advance_all()
			check(Hearts.seen_level(id) == n, "%s %s: ♥%d played" % [arc, id, n])
			check(Hearts.daily(id) != "", "%s %s: daily line after ♥%d" % [arc, id, n])
			# Heart perks (data/heart_perks.json) are handed out once, never twice.
			Perks.check(id)
			check(Perks.check(id).is_empty(), "%s %s: ♥%d perk not given twice" % [arc, id, n])
		var q6 := Hearts.quest6(id)
		var qd := GameState._quest_def(q6)
		if qd.is_empty() or GameState._cond_ok(qd.get("when", {})):
			check(offered, "%s %s: ♥6 quest %s offered" % [arc, id, q6])
		else:
			check(not offered, "%s %s: ♥6 quest %s waits for its own gate %s" % [arc, id, q6, str(qd.get("when"))])
	check(Hearts.standing_with_you().size() == vill.size(), "%s: all %d standing with you at ♥10" % [arc, vill.size()])

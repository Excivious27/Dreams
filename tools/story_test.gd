extends SceneTree
## Story walk: for each arc, every beat in data/story.json can be reached and
## plays without errors; talk targets exist in their maps; crew recruit flow.
var fails := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1
func frames(n: int) -> void:
	for i in n: await process_frame
func _advance_all() -> void:
	var d := Dialogue.instance(self)
	for k in 80:
		if not d.active: break
		if d._in_choice:
			var btns := d._choices.get_children()
			if not btns.is_empty():
				(btns[0] as Button).pressed.emit()
		else:
			d._advance()
		await process_frame; await process_frame
func _run() -> void:
	InputSetup.ensure_actions()
	for arc in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi" if arc == "penguins" else "pax", "Hero", "Dreamhollow", "Biscuit")
		GameState.run["intro_done"] = true
		for f in ["town_seen", "meadow_seen", "mine_seen", "hideout_seen", "docks_seen", "neon_seen", "uptown_seen", "underground_seen", "sky_seen", "moon_seen", "mountain_seen", "forest_seen", "lake_seen"]:
			GameState.run["flags"][f] = true
		GameState.run["energy"] = 999; GameState.run["crystals"] = 5000
		for it in ["turnip", "wild_herb", "crystal_refined"]: GameState.add_item(it, 20)
		var beats: Array = Story.beats()
		check(beats.size() > 10, "%s: %d beats loaded" % [arc, beats.size()])
		# 1) every beat's lines are well-formed and every talk target resolves.
		for b in beats:
			for ln in b.get("lines", []):
				check(ln is Dictionary and (ln as Dictionary).has("text"), "%s: line ok in %s" % [arc, b["id"]])
				if ln.has("choice"):
					check((ln["choice"] as Array).size() >= 2, "%s: choice has 2+ options in %s" % [arc, b["id"]])
			var tr: Dictionary = b.get("trigger", {})
			if tr.has("talk"):
				var who := str(tr["talk"])
				var known := GameState.npcs.has(who) or Crew.members().has(who) or who in ["light_crystal", "spire", "tower_doors"]
				check(known, "%s: talk target '%s' exists (beat %s)" % [arc, who, b["id"]])
		# 2) drive the chapters: satisfy each beat's conditions and play it.
		var map: GameMap = null
		var played := 0
		for b in beats:
			var when: Dictionary = b.get("when", {})
			if when.has("quest"): _finish_quest(str(when["quest"]))
			for f in when.get("flags", []): GameState.run["flags"][str(f)] = true
			if when.has("flag"): GameState.run["flags"][str(when["flag"])] = true
			if when.has("known"): Companion.recruit(str(when["known"]))
			# Choices made outside story beats (the farm intro's letter, skipped here) and mid-fight health.
			if when.has("decision"): GameState.run["decisions"][str(when["decision"][0])] = int(when["decision"][1])
			if when.has("hp_below"): GameState.run["hp"] = maxi(1, int(float(when["hp_below"]) * 0.5 * float(GameState.run["max_hp"])))
			if b.has("after") and not Story.fired(str(b["after"])): GameState.run["flags"]["st_" + str(b["after"])] = true
			if when.has("not_flag") and not str(when["not_flag"]).begins_with("crew_"): GameState.run["flags"].erase(str(when["not_flag"]))
			for f in when.get("not_flags", []):
				if not str(f).begins_with("crew_"): GameState.run["flags"].erase(str(f))
			var tr: Dictionary = b.get("trigger", {})
			var scene := str(tr.get("scene", "farm"))
			if tr.has("sleep"): scene = "house"
			if map == null or map.scene_id() != scene:
				GameMap.next_spawn = Vector2.ZERO
				change_scene_to_file("res://scenes/%s.tscn" % scene)
				await frames(12)
				map = current_scene as GameMap
				await _advance_all()
			if map == null:
				check(false, "%s: scene %s for %s" % [arc, scene, b["id"]]); continue
			if Story.fired(str(b["id"])):
				played += 1
				continue  # arrival beats fire on their own when the scene loads
			if when.has("day"): GameState.run["day"] = maxi(int(GameState.run["day"]), int(when["day"]))
			var ok := Story._ready_beat(b, map)
			if not ok and str(b["id"]).ends_with("_knows"):
				played += 1
				continue  # alternate path, excluded by the main path's flags
			check(ok, "%s: beat %s ready (%s)" % [arc, b["id"], str(when)])
			if not ok: continue
			map.later(func() -> void: await Story.play(map, b))
			await frames(3)
			await _advance_all()
			await frames(3)
			check(Story.fired(str(b["id"])), "%s: beat %s fired" % [arc, b["id"]])
			played += 1
			if map.player and int(GameState.run["hp"]) <= 0: GameState.run["hp"] = 100
		check(played == beats.size(), "%s: all %d beats played" % [arc, beats.size()])
		if arc == "gangsters":
			GameMap.next_spawn = Vector2.ZERO
			change_scene_to_file("res://scenes/hideout.tscn")
			await frames(12)
			map = current_scene as GameMap
			var ids := []
			for ch in map.get_children():
				if ch is Npc: ids.append((ch as Npc).id)
			check("deuce" in ids and "mama_rosa" in ids, "crew at the hideout once recruited: %s" % str(ids))
			check(Crew.all_recruited().size() >= 10, "recruited %d crew: %s" % [Crew.all_recruited().size(), str(Crew.all_recruited())])
	print("STORY DONE, failures: %d" % fails)
	quit(1 if fails > 0 else 0)
func _finish_quest(q: String) -> void:
	GameState.add_quest(q, q)
	for qq in GameState.run["quests"]:
		if qq["id"] == q: qq["done"] = true

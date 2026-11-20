extends SceneTree
## Decorate mode (C10a P2): place / turn / move / store / undo in the house, reserved
## cells and the walk-through check, wall and rug layers, wallpaper/flooring swaps,
## uniques never lost, starter furniture seeded once, house tier relayout, glow from
## the entry, guests refused, save round trip. Works with an empty data/decor.json:
## the catalogue entries are injected into Decor._data.
##   godot --headless --path . -s res://tools/decor_mode_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	Campaign.bypass = true
	seed(7)
	_run.call_deferred()


func _ent(name: String, layer: String, size: Array, art: String, extra := {}) -> Dictionary:
	var e := {"name": name, "cat": "furniture", "rarity": "common", "arc": "", "layer": layer, "size": size, "rot": 1,
		"glow": false, "art": art, "icon": art, "price": 100, "sell": 25, "sources": ["test"], "set": ""}
	e.merge(extra, true)
	return e


func _enter_house() -> GameMap:
	change_scene_to_file("res://scenes/house.tscn")
	await frames(14)
	var d := Dialogue.instance(self)
	for k in 60:
		if not d.active:
			break
		d._advance()
		await frames(2)
	return current_scene as GameMap


func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["time"] = 12 * 60
	# 1. Empty catalogue: the house looks as before and nothing breaks.
	var items: Dictionary = Decor.data()["items"]
	var saved := items.duplicate(true)
	items.clear()
	var m := await _enter_house()
	check(m != null and DecorMode.can_decorate(m), "the house answers decor_bounds")
	check(DecorMode.placed("house").is_empty(), "empty catalogue: nothing seeded")
	check(m.props.size() > 3, "empty catalogue: the starting furniture is still drawn (%d props)" % m.props.size())
	# 2. A catalogue (entries injected): the floor lamp is a known piece -> seeded as your decor.
	items["t_lamp"] = _ent("Floor Lamp", "floor", [1, 1], "furniture/lamp_floor", {"glow": true})
	items["t_chair"] = _ent("Chair", "floor", [1, 1], "furniture/chair2_a_down")
	items["t_sofa"] = _ent("Armchair", "floor", [2, 1], "furniture/armchair_a", {"rot": 4})
	items["t_rug"] = _ent("Rug", "under", [3, 2], "furniture/rug_rect_red")
	items["t_paint"] = _ent("Painting", "wall", [1, 1], "furniture/painting_a")
	items["t_wall"] = _ent("Striped Paper", "wallpaper", [1, 1], "tiles/wl_striped")
	items["t_floor"] = _ent("Dark Boards", "flooring", [1, 1], "tiles/fl_wood_dark")
	items["t_star"] = _ent("Star Clock", "floor", [1, 1], "furniture/armchair_b", {"rarity": "unique"})
	m = await _enter_house()
	var pl := DecorMode.placed("house")
	check(pl.size() == 2, "starters seeded: lamp and rug (%d)" % pl.size())
	check(((Decor.st().get("seeded", {}) as Dictionary).get("house", {}) as Dictionary).size() == 2, "each starter marked seeded")
	var lamp_cell := Vector2i(1, 2)
	check(m.blocked.has(lamp_cell), "the seeded lamp blocks its cell")
	var lamp_lit := false
	if m.glow:
		for l: Array in m.glow.lights:
			if is_instance_valid(l[0]) and (l[0] as Node).get_meta("decor_id", "") == "t_lamp":
				lamp_lit = true
		check(lamp_lit, "a glow entry registers a NightGlow light (entry field, not its name)")
	m = await _enter_house()
	check(DecorMode.placed("house").size() == 2, "re-entering does not seed twice")
	# 3. Place / reserved / fixed / outside / doorway.
	Decor.give("t_chair", 2)
	check(DecorMode.place(m, "t_chair", Vector2i(5, 9)) == "", "a chair fits on open floor")
	check(Decor.owned("t_chair") == 1 and m.blocked.has(Vector2i(5, 9)), "placing takes it from the box and blocks the cell")
	check(DecorMode.place(m, "t_chair", Vector2i(12, 3)) != "", "not in front of the dresser")
	check(DecorMode.place(m, "t_chair", Vector2i(3, 2)) != "", "not on the bed")
	check(DecorMode.place(m, "t_chair", Vector2i(0, 5)) != "", "not outside the room")
	check(DecorMode.place(m, "t_chair", Vector2i(8, 10)) != "", "not in the doorway")
	check(DecorMode.place(m, "t_chair", Vector2i(5, 9)) != "", "not on another piece")
	# 4. The walk-through check: a wall of furniture across the room fails.
	var line := {}
	for x in range(1, 15):
		line[Vector2i(x, 8)] = true
	check(not DecorMode.reach_ok(m, line), "a row of furniture that cuts the bed off is refused")
	check(DecorMode.reach_ok(m), "the room as it is stays walkable")
	# 5. Move + undo.
	var i := DecorMode.piece_at(m, Vector2i(5, 9))
	check(i >= 0, "piece_at finds the chair")
	check(DecorMode.move(m, i, Vector2i(6, 9)) == "", "move the chair")
	check(m.blocked.has(Vector2i(6, 9)) and not m.blocked.has(Vector2i(5, 9)), "blocking follows the move")
	check(DecorMode.undo(m) and m.blocked.has(Vector2i(5, 9)), "undo puts it back")
	# 6. Turning a 4-way piece swaps its footprint.
	check(DecorMode.size_of("t_sofa", 0) == Vector2i(2, 1) and DecorMode.size_of("t_sofa", 1) == Vector2i(1, 2), "side facing swaps w/h")
	check(DecorMode.rot_count("t_chair") == 1, "front-only art has one facing")
	# 7. Store + undo.
	var n0 := Decor.owned("t_chair")
	check(DecorMode.pick(m, DecorMode.piece_at(m, Vector2i(5, 9))) == "t_chair" and Decor.owned("t_chair") == n0 + 1, "store returns it to the box")
	check(DecorMode.undo(m) and DecorMode.piece_at(m, Vector2i(5, 9)) >= 0 and Decor.owned("t_chair") == n0, "undo the store")
	# 8. Wall pieces hang on the back wall, never over a window.
	Decor.give("t_paint", 2)
	check(DecorMode.place(m, "t_paint", Vector2i(2, 1)) == "", "a painting on the wall")
	check(DecorMode.place(m, "t_paint", Vector2i(6, 1)) != "", "not over a window")
	check(DecorMode.place(m, "t_paint", Vector2i(3, 6)) != "", "not on the floor")
	check(DecorMode.place(m, "t_paint", Vector2i(2, 1)) != "", "one piece per wall column")
	# 9. Rugs lie under and never block.
	Decor.give("t_rug", 1)
	check(DecorMode.place(m, "t_rug", Vector2i(10, 11)) == "", "a rug in the corner")
	check(not m.blocked.has(Vector2i(11, 11)), "rugs don't block")
	check(DecorMode.piece_at(m, Vector2i(5, 9)) >= 0, "a piece standing on nothing still answers first")
	# 10. Wallpaper / flooring per room, old one back to the box, undo.
	Decor.give("t_wall", 1)
	Decor.give("t_floor", 1)
	check(DecorMode.set_surface(m, "main", "t_wall") == "" and DecorMode.surface_of("wall", "main") == "t_wall", "wallpaper on the main room")
	check(Decor.owned("t_wall") == 0, "the roll left the box")
	check(DecorMode.set_surface(m, "main", "t_floor") == "" and DecorMode.surface_of("floor", "main") == "t_floor", "flooring on the main room")
	check(DecorMode.undo(m) and DecorMode.surface_of("floor", "main") == "" and Decor.owned("t_floor") == 1, "undo the flooring")
	items["t_marble"] = _ent("Marble", "flooring", [1, 1], "tiles/fl_marble")
	Decor.give("t_marble", 1)
	DecorMode.set_surface(m, "main", "t_marble")
	check(Footsteps.word(m, Vector2i(5, 6)) == "stone", "footsteps follow the room's flooring (%s)" % Footsteps.word(m, Vector2i(5, 6)))
	DecorMode.undo(m)
	check(Footsteps.word(m, Vector2i(5, 6)) == "wood", "and back to wood")
	await frames(3)
	# 11. Uniques are never lost by storing.
	Decor.give("t_star", 1)
	check(DecorMode.place(m, "t_star", Vector2i(9, 5)) == "", "a unique piece placed")
	check(Decor.owned("t_star") == 0 and Decor.placed_count("t_star") == 1, "unique counted as placed")
	DecorMode.pick(m, DecorMode.piece_at(m, Vector2i(9, 5)))
	check(Decor.owned("t_star") == 1 and Decor.placed_count("t_star") == 0, "unique back in the box, not lost")
	# 12. Save round trip (JSON like the save file) keeps every piece and the looks.
	var before: Array = DecorMode.placed("house").duplicate(true)
	var js := JSON.stringify(GameState.run["decor"])
	GameState.run["decor"] = JSON.parse_string(js)
	m = await _enter_house()
	check(DecorMode.placed("house").size() == before.size(), "placed survives the save (%d)" % before.size())
	var standing := before.filter(func(p: Dictionary) -> bool: return not DecorMode.is_flat(str(p["id"]))).size()
	check((m.get_meta("decor_nodes", []) as Array).size() == standing and standing < before.size(), "standing pieces are nodes, rugs/wall art are baked (%d of %d)" % [standing, before.size()])
	check(m.blocked.has(Vector2i(5, 9)), "blocking restored after reload")
	check(DecorMode.surface_of("wall", "main") == "t_wall", "wallpaper survives the save")
	# 13. The house grows: tier 2 adds the pantry; a piece on the Manor's study desk spot goes back to the box.
	if not (GameState.run.get("builds", null) is Dictionary):
		GameState.run["builds"] = {}
	GameState.run["builds"]["house"] = 2
	m = await _enter_house()
	Decor.give("t_chair", 1)
	check(DecorMode.place(m, "t_chair", Vector2i(18, 3)) == "", "a chair in the Farmhouse pantry")
	for sc: Vector2i in [Vector2i(5, 3), Vector2i(11, 9), Vector2i(17, 6), Vector2i(4, 9)]:
		check(not m.blocked.has(sc), "the Farmhouse spouse spot %s is free floor" % str(sc))
	GameState.run["builds"]["house"] = 3
	var boxed := Decor.owned("t_chair")
	m = await _enter_house()
	check(DecorMode.piece_at(m, Vector2i(18, 3)) < 0 and Decor.owned("t_chair") == boxed + 1, "the Manor's study desk spot sends the chair to the box")
	check(DecorMode.reach_ok(m), "the Manor stays walkable with decor")
	for sc: Vector2i in [Vector2i(5, 3), Vector2i(11, 9), Vector2i(23, 10), Vector2i(4, 9)]:
		check(not m.blocked.has(sc), "the Manor's spouse spot %s is free floor" % str(sc))
	check((DecorMode.placed("house") as Array).all(func(p: Dictionary) -> bool: return DecorMode.why_not(m, str(p["id"]), Vector2i(int(p["cell"][0]), int(p["cell"][1])), int(p.get("rot", 0)), DecorMode.placed("house").find(p)) == ""), "every placed piece is valid in the Manor")
	# 13b. Starting layout: the starters you own go back to their first spots (no new copies).
	var lamp_n := Decor.owned("t_lamp") + Decor.placed_count("t_lamp")
	var back := DecorMode.reset_layout(m)
	check(back >= 1 and DecorMode.piece_at(m, Vector2i(1, 2)) >= 0, "starting layout puts the lamp back (%d)" % back)
	check(Decor.owned("t_lamp") + Decor.placed_count("t_lamp") == lamp_n, "starting layout makes no new copies")
	check(DecorMode.surface_of("wall", "main") == "", "starting layout clears the wallpaper (back in the box)")
	# 14. The screen: opens, pauses, places with A, closes.
	var dm := DecorMode.open(m)
	await frames(2)
	check(dm != null and paused, "decorate mode opens and pauses")
	dm.held = "t_chair"
	dm.cursor = Vector2i(5, 10)
	var had := Decor.owned("t_chair")
	dm._confirm()
	check(Decor.owned("t_chair") == had - 1 and DecorMode.piece_at(m, Vector2i(5, 10)) >= 0, "Place from the screen")
	# Touch: the first tap aims, the second tap on the same cell places (no one-tap actions).
	Decor.give("t_chair", 1)
	dm.held = "t_chair"
	var tc := Vector2i(7, 6)
	var sp := m.get_viewport().get_canvas_transform() * (m.cell_pos(tc.x, tc.y) + Vector2(8, 8))
	var had2 := Decor.owned("t_chair")
	for k in 2:
		var tev := InputEventScreenTouch.new()
		tev.position = sp
		tev.pressed = true
		dm._input(tev)
		var rel := InputEventScreenTouch.new()
		rel.position = sp
		rel.pressed = false
		dm._input(rel)
		if k == 0:
			check(dm.cursor == tc and Decor.owned("t_chair") == had2, "first tap only aims (%s)" % str(dm.cursor))
	check(Decor.owned("t_chair") == had2 - 1 and DecorMode.piece_at(m, tc) >= 0, "second tap places")
	dm._toggle_list()
	await frames(2)
	check(dm._list_box.get_child_count() >= 2, "the box list lists pieces")
	dm._toggle_list()
	dm.close()
	await frames(2)
	check(not paused and Hud.modal_rect == Rect2(), "closing unpauses and frees the touch area")
	# 15. Guests: the host's look, no editing.
	var home := DecorMode.home_view()
	check(not home.has("box") and not home.has("wear") and home.has("placed"), "guests get only the house look")
	check("decor_home" in NetNode.WORLD_KEYS, "the house look rides the world sync")
	# The world delta sends only the rooms that changed, and merges back whole.
	var w0 := {"decor_home": {"placed": {"house": [{"id": "a", "cell": [1, 2], "rot": 0}], "barn": [{"id": "b", "cell": [3, 4], "rot": 0}]}, "wall": {}, "floor": {}}}
	var w1 := {"decor_home": {"placed": {"house": [{"id": "a", "cell": [2, 2], "rot": 0}], "barn": [{"id": "b", "cell": [3, 4], "rot": 0}]}, "wall": {"main": "w"}, "floor": {}}}
	var dl := NetNode.world_delta(w0, w1)
	check(dl.has("decor_home_d") and not dl.has("decor_home") and ((dl["decor_home_d"] as Dictionary)["placed"] as Dictionary).keys() == ["house"], "decor delta carries only the changed room")
	var guest := {"decor_home": w0["decor_home"].duplicate(true)}
	NetNode.merge_delta(guest, dl)
	check(guest["decor_home"] == w1["decor_home"], "decor delta merges to the host's house")
	var nn := Net.i()
	nn._solo_backup = {"day": 1}
	GameState.run["decor_home"] = {"placed": {"house": []}, "wall": {}, "floor": {}}
	check(DecorMode.view() == GameState.run["decor_home"], "a guest sees the host's house")
	check(DecorMode.place(m, "t_chair", Vector2i(6, 10)) != "", "a guest can't place in the host's house")
	check(DecorMode.open(m) == null, "a guest can't open decorate mode")
	nn._solo_backup = {}
	GameState.run.erase("decor_home")
	# 16. Decor stays out of chests.
	GameState.add_item("t_chair", 1)
	check(Storage.deposit("chest", "t_chair", 1) == 0, "decor never goes in a chest")
	items.clear()
	items.merge(saved)
	print("decor_mode_test: %s (%d fails)" % ["OK" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)

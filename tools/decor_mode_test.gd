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
	await _c10b(items)
	items.clear()
	items.merge(saved)
	print("decor_mode_test: %s (%d fails)" % ["OK" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)


## CONDUCT 10b P2: catalogue surfaces, occupancy, undoable bulk, bar rect, paging,
## and decorating the yard on the farm.
func _c10b(items: Dictionary) -> void:
	items["t_cwall"] = _ent("Catalogue Paper", "wall", [1, 1], "tiles/wl_striped_l", {"cat": "wallpaper", "style": "wl_striped"})
	items["t_cfloor"] = _ent("Catalogue Floor", "under", [1, 1], "decor/dc_fl_blue_tile", {"cat": "flooring", "style": "decor/dc_fl_blue_tile"})
	items["t_statue"] = _ent("Yard Statue", "outdoor", [1, 1], "props/birdbath")
	items["t_path"] = _ent("Cobble Path", "outdoor", [1, 1], "props/birdbath", {"seam": "cobble_warm", "sub": "path"})
	items["t_both"] = _ent("Bench", "floor", [2, 1], "props/bench_wood", {"where": "both"})
	check(DecorMode.is_surface("t_cwall") and DecorMode.layer_of("t_cwall") == "wallpaper", "catalogue wallpaper (cat wallpaper, layer wall) is a room surface")
	check(DecorMode.is_surface("t_cfloor") and DecorMode.layer_of("t_cfloor") == "flooring", "catalogue flooring is a room surface")
	check(DecorMode.surface_art("t_cwall") == ["tiles", "wl_striped", false], "surfaces draw from their style kit")
	check(DecorMode.layer_of("t_statue") == "floor" and DecorMode.layer_of("t_path") == "under", "yard pieces stand / lie by kind")
	check(DecorMode.where_of("t_statue") == "out" and DecorMode.where_of("t_chair") == "in", "where: yard vs house")
	var m := await _enter_house()
	check(not DecorMode.fits_map(m, "t_statue") and DecorMode.fits_map(m, "t_both"), "yard pieces stay out of the house")
	Decor.give("t_statue", 1)
	check(DecorMode.place(m, "t_statue", Vector2i(5, 8)).contains("yard"), "a yard piece indoors: told where it goes")
	# Nothing drops on the player's own cell.
	Decor.give("t_chair", 1)
	var pc: Vector2i = m.player.cell()
	if DecorMode.bounds(m).has_point(pc):
		check(DecorMode.why_not(m, "t_chair", pc) != "", "no furniture on the cell you stand on")
	# Store all can be undone.
	var before := DecorMode.placed("house").size()
	DecorMode.undo_stack.clear()
	DecorMode.store_all(m)
	check(DecorMode.placed("house").is_empty(), "store all empties the house")
	check(DecorMode.undo(m) and DecorMode.placed("house").size() == before, "undo brings every piece back (%d)" % before)
	# The bar rect is freed on close (no dead strip at the bottom).
	var rects := Hud.extra_rects.size()
	var dm := DecorMode.open(m)
	await frames(3)
	dm._list_panel.visible = false
	dm.close()
	await frames(3)
	check(Hud.extra_rects.size() == rects, "decorate mode leaves Hud.extra_rects as it found them (%d -> %d)" % [rects, Hud.extra_rects.size()])
	# Catalogue Box "Place": decorate mode opens paused, with the piece in hand (c10b_09-33).
	var cat: Variant = DecorCatalogue.open(m)
	await frames(4)
	if cat:
		cat._place("t_chair")
		await frames(6)
		var dmc: DecorMode = null
		for ch in m.get_children():
			if ch is DecorMode:
				dmc = ch
		check(dmc != null and dmc.held == "t_chair", "catalogue Place opens decorate mode holding the piece")
		check(paused and Hud.modal_rect == Rect2(0, 0, 270, 480), "... paused, the screen owned by decorate mode")
		if dmc:
			dmc.close()
			await frames(3)
	# The box list pages (a full catalogue never builds 700 rows).
	for k in 70:
		items["t_many_%d" % k] = _ent("Many %02d" % k, "floor", [1, 1], "furniture/chair2_a_down")
		Decor.give("t_many_%d" % k, 1)
	dm = DecorMode.open(m)
	await frames(3)
	DecorMode.list_filter = "all"
	DecorMode.list_search = ""
	DecorMode.list_page = 0
	dm._toggle_list()
	await frames(2)
	check(dm._list_box.get_child_count() <= DecorMode.PAGE_ROWS, "one page of rows (%d)" % dm._list_box.get_child_count())
	DecorMode.list_search = "many 0"
	dm._fill_list()
	await frames(2)
	check(dm.box_ids().size() == 10, "search filters by name (%d)" % dm.box_ids().size())
	DecorMode.list_search = ""
	dm.close()
	await frames(2)
	for k in 70:
		items.erase("t_many_%d" % k)
		(Decor.st()["box"] as Dictionary).erase("t_many_%d" % k)
	# ---- the yard ----
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	change_scene_to_file("res://scenes/farm.tscn")
	await frames(16)
	var f := current_scene as GameMap
	check(DecorMode.can_decorate(f) and DecorMode.outdoor(f), "the farm answers the decor hooks (outdoor)")
	check(not DecorMode.fits_map(f, "t_chair") and DecorMode.fits_map(f, "t_statue"), "house pieces stay indoors")
	# An open grass cell near the house, clear of everything.
	var spot := Vector2i(-1, -1)
	for y in range(16, 28):
		for x in range(18, 30):
			var c := Vector2i(x, y)
			if spot.x < 0 and DecorMode.why_not(f, "t_statue", c) == "" and DecorMode.why_not(f, "t_statue", c + Vector2i(1, 0)) == "" and f.can_till(c + Vector2i(1, 0)):
				spot = c
	check(spot.x >= 0, "an open yard cell exists (%s)" % str(spot))
	if spot.x >= 0:
		Decor.give("t_statue", 1)
		Decor.give("t_path", 3)
		check(DecorMode.place(f, "t_statue", spot) == "", "a statue in the yard")
		check(f.blocked.has(spot), "it blocks its cell")
		check(not f.can_till(spot), "no soil under yard decor")
		var pth := spot + Vector2i(1, 0)
		check(DecorMode.place(f, "t_path", pth) == "", "a path tile in the yard")
		check(not f.blocked.has(pth) and not f.can_till(pth), "a path is walkable and never tilled")
		check(f.step_word.get(pth, "") == "stone", "a yard path is a path for footsteps / weather (%s)" % str(f.step_word.get(pth, "")))
		# Fields and debris refuse decor.
		var soil := Vector2i(-1, -1)
		for y in range(16, 28):
			for x in range(18, 30):
				if soil.x < 0 and f.can_till(Vector2i(x, y)) and Vector2i(x, y) != pth:
					soil = Vector2i(x, y)
		if soil.x >= 0:
			GameState.run["farm"]["%d,%d" % [soil.x, soil.y]] = {"crop": ""}
			check(DecorMode.why_not(f, "t_statue", soil) == "That's your field.", "no decor on a field")
			(GameState.run["farm"] as Dictionary).erase("%d,%d" % [soil.x, soil.y])
		var deb := Vector2i(-1, -1)
		for c: Vector2i in f.things:
			if str(f.things[c].get("type", "")) in ["rock", "weeds"] and DecorMode.bounds(f).has_point(c):
				deb = c
				break
		if deb.x >= 0:
			check(DecorMode.why_not(f, "t_statue", deb) == "Clear it first.", "debris must be cleared first")
		check(DecorMode.why_not(f, "t_statue", (f as Variant).mail_c + Vector2i(0, 1)) != "", "the mailbox front stays clear")
		check(DecorMode.why_not(f, "t_statue", (f as Variant).door_c + Vector2i(0, 1)) != "", "the doorway stays clear")
		# Live blocking outdoors: a sprinkler placed after opening is seen (c10b_02_03).
		var sp := Vector2i(-1, -1)
		for y in range(16, 28):
			for x in range(18, 30):
				if sp.x < 0 and f.can_till(Vector2i(x, y)) and DecorMode.why_not(f, "t_statue", Vector2i(x, y)) == "":
					sp = Vector2i(x, y)
		if sp.x >= 0:
			if not GameState.run.has("placed"):
				GameState.run["placed"] = {}
			GameState.run["placed"]["%d,%d" % [sp.x, sp.y]] = "sprinkler"
			f._show_placed(sp, "sprinkler")
			check(DecorMode.why_not(f, "t_statue", sp) != "", "a sprinkler placed later blocks yard decor")
			DecorMode.dress(f)
			check(f.blocked.has(sp), "redressing the yard keeps the sprinkler solid")
		# Reload: the statue is still there, no debris grew under it or the sprinkler.
		change_scene_to_file("res://scenes/farm.tscn")
		await frames(16)
		f = current_scene as GameMap
		check(f.blocked.has(spot) and not f.things.has(spot), "after reload the statue stands, nothing grew under it")
		if sp.x >= 0:
			check((GameState.run["placed"] as Dictionary).has("%d,%d" % [sp.x, sp.y]), "the sprinkler kept its cell")
		# Decorate mode opens on the farm, pans both ways, and closes clean.
		for k in 60:
			if DecorMode.busy_why(f) == "":
				break
			if Dialogue.instance(self).active:
				Dialogue.instance(self)._advance()
			await frames(2)
		dm = DecorMode.open(f)
		await frames(3)
		check(dm != null, "decorate mode opens in the yard (%s)" % DecorMode.busy_why(f))
		if dm:
			dm.cursor = DecorMode.bounds(f).end - Vector2i(20, 3)
			dm._refresh()
			var cam := f.get_viewport().get_camera_2d()
			check(cam == null or cam.offset.y != 0.0, "the camera pans vertically for far yard cells (%s, player %s, zoom %s, view %s)" % [str(cam.offset if cam else Vector2.ZERO), str(f.player.position), str(cam.zoom if cam else Vector2.ONE), str(f.get_viewport().get_visible_rect().size)])
			dm.close()
			await frames(2)
			check(cam == null or cam.offset == Vector2.ZERO, "closing resets the camera")
	# Heavy yard: 120 paths + 30 statues, then one more piece: incremental dress, no re-bake.
	Decor.give("t_path", 200)
	Decor.give("t_statue", 40)
	var laid := 0
	var stood := 0
	for y in range(30, 56):
		for x in range(3, 34):
			var c := Vector2i(x, y)
			if laid < 120 and (x + y) % 2 == 0 and DecorMode.place(f, "t_path", c) == "":
				laid += 1
			elif stood < 30 and (x * 3 + y) % 7 == 0 and DecorMode.place(f, "t_statue", c) == "":
				stood += 1
	var nodes0: Array = f.get_meta("decor_nodes", [])
	var keep_node: Variant = nodes0[0] if not nodes0.is_empty() else null
	var free_c := Vector2i(-1, -1)
	for y in range(20, 30):
		for x in range(40, 60):
			if free_c.x < 0 and DecorMode.why_not(f, "t_statue", Vector2i(x, y)) == "":
				free_c = Vector2i(x, y)
	var t0 := Time.get_ticks_usec()
	DecorMode.why_not(f, "t_statue", free_c)
	var why_ms := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	DecorMode.place(f, "t_statue", free_c)
	var one_ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("  why_not (ghost check) %.1f ms" % why_ms)
	print("  yard perf: %d paths + %d statues; one more piece %.1f ms (dress + walk check)" % [laid, stood, one_ms])
	check(keep_node == null or is_instance_valid(keep_node) and not (keep_node as Node).is_queued_for_deletion(), "unchanged pieces keep their nodes")
	t0 = Time.get_ticks_usec()
	DecorMode.relayout(f)
	var r1 := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	DecorMode.relayout(f)
	var r2 := (Time.get_ticks_usec() - t0) / 1000.0
	print("  relayout %.1f ms, again (nothing changed) %.1f ms" % [r1, r2])
	check(r2 < r1 or r2 < 5.0, "an unchanged layout skips the full check")
	var jd := JSON.stringify(Decor.st()["placed"].get("farm", []))
	print("  yard save: %d pieces, %d bytes" % [DecorMode.placed("farm").size(), jd.length()])
	# Built pens and service fronts are never tilled.
	var farm_v: Variant = f
	check(not f.can_till((farm_v.mail_c as Vector2i) + Vector2i(0, 1)), "no soil in front of the mailbox")

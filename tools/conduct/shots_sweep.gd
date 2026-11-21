extends SceneTree
## CONDUCT shared shots (R4): one session per arc, every scene, interior and key screen
## at 540x960, so auditors view PNGs instead of running godot. Driven by shots_sweep.sh.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/conduct/shots_sweep.gd -- <out_dir> <arc> [sections]
## sections (comma list, default all): title,maps,interiors,screens,shops,npcs,festival,night,battle
## Writes <out_dir>/<name>.png and <out_dir>/index.tsv (name, section, what) as it goes,
## so a crash part-way still leaves a usable partial index.

var out := ""
var arc := "penguins"
var gt := 0.0  # game time only
var _index: FileAccess
var n_shots := 0


func _initialize() -> void:
	Campaign.bypass = true
	seed(4)
	_run.call_deferred()


func _frames(n: int) -> void:
	for k in n:
		await process_frame
		gt += root.get_process_delta_time()


func _shot(name: String, section: String, what: String) -> void:
	_no_toasts()
	await _frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	_index.store_line("%s\t%s\t%s" % [name, section, what])
	_index.flush()
	n_shots += 1


func _fresh(day := 8, minutes := 600) -> void:
	GameState.new_run(arc, "kairi" if arc == "penguins" else "dad", "Kairi", "Dreamhollow", "Biscuit")
	var r := GameState.run
	r["intro_done"] = true
	r["day"] = day
	r["time"] = minutes
	for f in ["town_seen", "town_tour", "partner_scene", "interior_seen", "store_first", "cm_seen", "mine_open_1", "meow_taught", "moon_seen", "mine_seen", "gangsters_intro", "rec_visited"]:
		r["flags"][f] = true
	for k in ToolHint.TIPS:
		r["flags"]["tip_" + str(k)] = true
	r["builds"] = {"furnace": 2, "workbench": 2}
	for id in ["turnip", "potato", "carrot", "stone", "wood", "copper", "coal", "fiber", "sap", "bread"]:
		GameState.add_item(id, 12)
	r["crystals"] = 123456
	GameState.add_friend("maple", 300)
	Tickets.add(900, "sweep")


func _clear_dialogue() -> void:
	var d := Dialogue.instance(self)
	for k in 60:
		if not d.active:
			break
		if d._in_choice:
			d._choose("", d._choices.get_child_count() - 1)
		else:
			d._advance()
		await _frames(2)


## Close story scenes that start a little after a map loads (several rounds).
func _settle() -> void:
	var d := Dialogue.instance(self)
	var calm := 0
	for k in 40:
		if d.active:
			calm = 0
			await _clear_dialogue()
		else:
			calm += 1
			if calm >= 3:
				break
		await _frames(5)
	_unpause()


func _no_toasts() -> void:
	var m := current_scene as GameMap
	if m and m.hud and m.hud.get("_toasts"):
		for c in m.hud._toasts.get_children():
			c.queue_free()


func _unpause() -> void:
	paused = false
	Hud.modal_rect = Rect2()


func _shut(n: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	for meth in ["close", "_close", "_finish"]:
		if n.has_method(meth):
			n.call(meth)
			break
	if is_instance_valid(n) and n.is_inside_tree():
		n.queue_free()
	await _frames(3)
	_unpause()
	await _clear_dialogue()


func _child(m: Node, cls: String) -> Node:
	for c in m.get_children():
		if c.get_script() and (c.get_script() as Script).get_global_name() == cls:
			return c
	return null


func _load(scene: String, cell := Vector2i(-1, -1)) -> GameMap:
	var sc := scene
	if sc.begins_with("in_"):
		GameMap.next_interior = sc.trim_prefix("in_")
		sc = "interior"
	GameState.run["flags"][sc + "_seen"] = true
	GameState.run["flags"][scene + "_seen"] = true
	GameMap.next_spawn = Vector2(cell.x * 16 + 8, cell.y * 16 + 8) if cell.x >= 0 else Vector2.ZERO
	_unpause()
	change_scene_to_file("res://scenes/%s.tscn" % sc)
	await _frames(20)
	await _settle()
	var m := current_scene as GameMap
	if m:
		for e in m.enemies:
			if is_instance_valid(e):
				e.queue_free()
		m.enemies.clear()
		GameState.run["hp"] = int(GameState.run["max_hp"])
		GameState.run["energy"] = int(GameState.run["max_energy"])
	await _frames(6)
	return m


func _want(sec: String, secs: PackedStringArray) -> bool:
	return secs.is_empty() or sec in secs


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "/tmp/shots_sweep"
	arc = args[1] if args.size() > 1 else "penguins"
	var secs := PackedStringArray()
	if args.size() > 2 and args[2] != "" and args[2] != "all":
		secs = args[2].split(",")
	DirAccess.make_dir_recursive_absolute(out)
	_index = FileAccess.open(out + "/index.tsv", FileAccess.WRITE)
	InputSetup.ensure_actions()
	var df := ThemeDB.fallback_font
	if df is FontFile:
		(df as FontFile).allow_system_fallback = false  # like the web build
	var t0 := Time.get_ticks_msec()  # wall time for the report only, never gameplay
	if arc == "penguins" and _want("title", secs):
		await _title_pass()
	if _want("screens", secs):
		await _screens_pass()
	if _want("shops", secs):
		await _shops_pass()
	if _want("npcs", secs):
		await _npc_pass()
	if _want("festival", secs):
		await _festival_pass()
	if _want("night", secs):
		await _night_pass()
	if _want("battle", secs):
		await _battle_pass()
	if _want("interiors", secs):
		await _interiors_pass()
	if _want("maps", secs):
		await _maps_pass()
	print("shots_sweep %s: %d shots in %.1f s" % [arc, n_shots, (Time.get_ticks_msec() - t0) / 1000.0])
	_index.close()
	quit(0)


func _title_pass() -> void:
	_fresh()
	GameState.save()
	change_scene_to_file("res://scenes/title.tscn")
	await _frames(12)
	var t := current_scene
	await _shot("title", "title", "title screen")
	t.set("_arc", "penguins")
	t.set("_playable", "kairi")
	for pg in [["_show_slots", "title_slots", "save slots"], ["_show_sound", "title_sound", "title sound/options page"], ["_show_net", "title_play_together", "Play together (relay)"], ["_show_arcs", "title_arcs", "new game: arc pick"], ["_show_characters", "title_characters", "new game: characters"]]:
		if t.has_method(pg[0]):
			t.call(pg[0])
			await _shot(pg[1], "title", pg[2])
	t.set("_arc", "penguins")
	t.set("_playable", "kairi")
	if t.has_method("_show_names"):
		t.call("_show_names")
		await _shot("title_names", "title", "new game: names, difficulty, day length")
	if t.has_method("_clear"):
		t.call("_clear")
		AchievementScreen.fill(t.get("_page"), Callable(t, "_label"), t.call("_button", "Back", Callable(t, "_show_title")))
		await _shot("title_achievements", "title", "achievements")


func _screens_pass() -> void:
	_fresh()
	var m := await _load("farm")
	await _shot("hud_farm", "screens", "farm HUD, day 8 morning")
	var menu: GameMenu = null
	for c in m.get_children():
		if c is GameMenu:
			menu = c
	if menu:
		menu.toggle()
		for t: String in GameMenu.TABS + ["Animals", "Chores", "Keys", "FieldLog", "Workshop", "Foes", "Messages", "Mail"]:
			if Dialogue.instance(self).active:
				await _settle()
			if not menu._open:
				menu.toggle()
				await _frames(3)
			menu._tab = t
			menu._refresh()
			await _shot("menu_" + t.to_lower(), "screens", "game menu tab " + t)
		menu.toggle()
		await _frames(4)
		_unpause()
	ChestScreen.open(m, "chest", "Chest")
	await _frames(8)
	var cs := _child(m, "ChestScreen")
	await _shot("chest", "screens", "chest screen")
	await _shut(cs)
	for st in ["furnace", "workbench"]:
		Crafting.run(m, st)
		await _frames(8)
		var cr := _child(m, "CraftScreen") as CraftScreen
		if cr:
			await _shot("craft_" + st, "screens", "craft screen " + st)
			var rcs: Array = Crafting.available(st, 2)
			if not rcs.is_empty():
				cr._sel = rcs[0]
				cr._refresh()
				await _shot("craft_%s_picked" % st, "screens", "craft screen %s, recipe picked" % st)
		await _shut(cr)
	for v in ["grid", "sets", "box"]:
		var dc := DecorCatalogue.open(m, v)
		await _frames(8)
		await _shot("decor_catalogue_" + v, "screens", "decor catalogue: " + v)
		await _shut(dc)
	GameState.run["time"] = 12 * 60
	PrizeScreen.open(m)
	await _frames(8)
	await _shot("prizes", "screens", "prize counter")
	await _shut(_child(m, "PrizeScreen"))
	CampaignScreen.open(m)
	await _frames(10)
	await _shot("campaign_map", "screens", "campaign map/board")
	await _shut(_child(m, "CampaignScreen"))
	var hub := ArcadeHub.make("")
	hub.manual = true
	root.add_child(hub)
	for i in 20:
		hub.t += 1.0 / 60.0
		hub.frame()
	if hub._canvas:
		hub._canvas.queue_redraw()
	await _shot("arcade_picker", "screens", "arcade picker")
	hub.close()
	await _frames(4)
	_unpause()


func _shops_pass() -> void:
	_fresh(8, 12 * 60)
	var m := await _load("town")
	var shops: Array = ["store", "smith", "potions", "carpenter", "lumi"] if arc == "penguins" else ["store", "smith", "crew_marlene", "crew_deuce", "crew_specs", "crew_halo"]
	for s: String in shops:
		Shops.run(m, s)
		await _frames(24)
		await _shot("shop_" + s, "shops", "shop " + s + " (opening view)")
		for c in m.get_children():
			if c.get_script() and (c.get_script() as Script).get_global_name() in ["DecorShopScreen", "ShopScreen"]:
				await _shut(c)
		_unpause()
		await _clear_dialogue()
	for seller: String in ["tam", "hazel", "posy"]:
		Shops.animal_counter(m, seller, seller.capitalize())
		await _frames(24)
		await _shot("animal_counter_" + seller, "shops", "animal counter " + seller)
		_unpause()
		await _clear_dialogue()
		await _frames(4)


func _npc_pass() -> void:
	_fresh(8, 11 * 60)
	await _load("town")
	var d := Dialogue.instance(self)
	for id: String in GameState.npcs:
		var lines: Array = Talk.line(id)
		if lines.is_empty():
			continue
		d.say([lines[0]])
		await _frames(6)
		d._advance()  # finish the typewriter
		await _shot("talk_" + id, "npcs", "dialogue sample: " + id)
		await _clear_dialogue()


func _festival_pass() -> void:
	# Day 14 of each season is festival day on the town plaza.
	for f in [[14, 11 * 60, "egg"], [42, 20 * 60, "lantern"], [70, 13 * 60, "harvest"], [98, 19 * 60, "star"]]:
		_fresh(int(f[0]), int(f[1]))
		await _load("town", Vector2i(40, 52))  # just south of the fountain (Town.PLAZA_C)
		await _frames(10)
		await _shot("festival_" + str(f[2]), "festival", "town plaza on festival day (%s, day %d, %02d:00)" % [GameState.festival_today(), f[0], int(f[1]) / 60])


func _night_pass() -> void:
	for sc in ["farm", "town", "beach", "forest"]:
		_fresh(8, 22 * 60)
		await _load(sc)
		await _shot("night_" + sc, "night", "night look (22:00) " + sc)


func _battle_pass() -> void:
	_fresh()
	GameState.run["flags"]["bt_trained"] = false
	var dd := CampaignGate.drill_def()
	var fid := str(dd.get("field", "bf_orchard_line"))
	Campaign.st()["fight"] = {"drill": true, "field": fid, "day": 8, "back": ["farm", 160.0, 160.0]}
	var p0: Array = ((dd.get("points", [{}]) as Array)[0] as Dictionary).get("cell", [52, 74])
	GameMap.next_spawn = Vector2(float(p0[0]) * 16 + 8, float(p0[1] + 3) * 16 + 8)
	change_scene_to_file("res://scenes/%s.tscn" % fid)
	await _frames(40)
	var m := current_scene
	var bb := _child(m, "BattleBrief") if m else null
	await _shot("battle_brief", "battle", "battle brief card (training drill)")
	if bb:
		bb.set("_min_t", 0.0)
		bb.set("_arm", 99.0)
		bb.call("_close")
	await _frames(30)
	_unpause()
	await _clear_dialogue()
	await _shot("battle_drill_step", "battle", "training drill, first step card")
	Campaign.st()["fight"] = {}


func _interiors_pass() -> void:
	_fresh(8, 12 * 60)
	await _load("house")
	await _shot("in_house", "interiors", "player house")
	var ids: Array = GameState.load_json("res://data/interiors.json").keys()
	for id: String in ids:
		await _load("in_" + id)
		await _shot("in_" + id, "interiors", "interior " + id)


func _maps_pass() -> void:
	_fresh(8, 11 * 60)
	var names: Array = []
	var dir := DirAccess.open("res://scenes")
	for f in dir.get_files():
		if f.ends_with(".tscn") and f.get_basename() not in ["title", "test_map", "interior", "house"]:
			names.append(f.get_basename())
	names.sort()
	if OS.get_environment("SWEEP_MAPS") != "":
		names = Array(OS.get_environment("SWEEP_MAPS").split(","))
	for sc: String in names:
		var m := await _load(sc)
		if m == null:
			print("shots_sweep: %s is not a map" % sc)
			continue
		await _shot("map_" + sc, "maps", "map %s at its default spawn, 11:00" % sc)

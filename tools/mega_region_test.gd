extends SceneTree
## Mega regions (MegaRegion / MegaMap): data sanity, tabs hidden until unlocked,
## unlocking shows them, travel into converted regions (rocket to the moon, the
## colony ferry, the city bus) opens them with a banner, old saves migrate.
##   godot --headless --path . -s res://tools/mega_region_test.gd
## With an output folder (and a renderer) it also saves screenshots of the map tabs:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/mega_region_test.gd -- /tmp/shots
var fails := 0
var out := ""


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	_run.call_deferred()


func _drain(frames := 60) -> void:
	for i in frames:
		var d := Dialogue.instance(self)
		if d.active:
			if d._in_choice:
				d._choose("", d._choices.get_child_count() - 1)
			else:
				d._advance()
		await process_frame


func _go(sc: String) -> GameMap:
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/%s.tscn" % sc)
	for i in 14:
		await process_frame
	await _drain(20)
	return current_scene as GameMap


func _arrive(sc: String, limit := 400) -> GameMap:
	for i in limit:
		var gm := current_scene as GameMap
		if gm != null and gm.scene_id() == sc and gm.player != null and not gm._changing:
			for k in 6:
				await process_frame
			return gm
		var d := Dialogue.instance(self)
		if d.active:
			if d._in_choice:
				d._choose("", d._choices.get_child_count() - 1)
			else:
				d._advance()
		await process_frame
	return current_scene as GameMap


func _shot(name: String) -> void:
	if out == "":
		return
	for k in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _tabs_shown() -> Array:
	var box := VBoxContainer.new()
	MegaMap.tab_row(box, func() -> void: pass)
	var names: Array = []
	for b in box.find_children("MapTab_*", "Button", true, false):  # inside the sideways strip (C4)
		names.append(str(b.name).trim_prefix("MapTab_"))
	box.free()
	return names


func _banner(m: GameMap) -> bool:
	for c in m.get_children():
		if c is CanvasLayer and str(c.name).begins_with("MegaBanner"):
			return true
	return false


## The banner's text (all its labels), "" when none is up.
func _banner_text(m: GameMap) -> String:
	var t := ""
	for c in m.get_children():
		if c is CanvasLayer and str(c.name).begins_with("MegaBanner"):
			for l in c.find_children("*", "Label", true, false):
				t += (l as Label).text + " "
	return t


func _menu(m: GameMap) -> GameMenu:
	for c in m.get_children():
		if c is GameMenu:
			return c
	return null


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
		DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	Campaign.bypass = true
	# ---- data ------------------------------------------------------------------------
	var ids := MegaRegion.ids()
	check(ids.size() == 10, "ten mega regions (%d)" % ids.size())
	var built := 0
	for id: String in ids:
		var r := MegaRegion.get_r(id)
		check(str(r.get("name", "")) != "" and str(r.get("short", "")).length() <= 9, "%s has a name and a short tab label" % id)
		check(not (r.get("areas", []) as Array).is_empty() and not (r.get("entries", []) as Array).is_empty(), "%s has areas and a way in" % id)
		if str(r.get("status", "")) == "built":
			built += 1
			for a in r["areas"]:
				check(MegaRegion.scene_exists(str(a["id"])), "%s: area %s has a scene" % [id, a["id"]])
		for e in r["entries"]:
			check(MegaRegion.region_of(str(e["from"])) != id and ResourceLoader.exists("res://scenes/%s.tscn" % str(e["from"])), "%s: entry from %s is outside the region" % [id, e["from"]])
	check(built >= 5, "the existing big areas are converted (%d)" % built)
	check(MegaRegion.region_of("moon") == "space" and MegaRegion.region_of("colony_ice") == "colonies" and MegaRegion.region_of("neon") == "cities" and MegaRegion.region_of("hollow_heart") == "hollow", "converted areas map to their regions")
	check(MegaRegion.region_of("farm") == "" and MegaRegion.region_of("hideout") == "", "home areas are in the Valley")
	# ---- penguins: hidden until unlocked -----------------------------------------------
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["hp"] = 999
	GameState.run["max_hp"] = 999
	check(MegaRegion.unlocked().is_empty(), "a fresh run has no mega region open")
	check(_tabs_shown().is_empty(), "no tab row at all on a fresh run (no spoilers)")
	check(not MegaRegion.available("cities"), "penguin run: the lieutenant cities don't exist")
	GameState.run["flags"]["moon_unlocked"] = true
	var got := MegaRegion.check_unlocks()
	check(got.has("space") and MegaRegion.is_unlocked("space"), "launching from the pad opens Space")
	check(not MegaRegion.is_unlocked("colonies") and not MegaRegion.is_unlocked("hollow"), "the rest stay hidden")
	var t := _tabs_shown()
	check(t == ["valley", "space"], "tabs: Valley + Space (%s)" % str(t))
	for id: String in ids:
		if str(MegaRegion.get_r(id).get("status")) == "planned":
			GameState.run["flags"][str(MegaRegion.get_r(id)["areas"][0]["id"]) + "_seen"] = true
			MegaRegion.check_unlocks()
			check(MegaRegion.is_unlocked(id) == MegaRegion.available(id), "%s stays hidden until its areas are built" % id)
			GameState.run["flags"].erase(str(MegaRegion.get_r(id)["areas"][0]["id"]) + "_seen")
	# ---- travel: rocket to the moon ------------------------------------------------------
	var m := await _go("mountain")
	check(m != null and m.scene_id() == "mountain", "mountain loads")
	check(str(MegaRegion.st()["last"]) == "", "standing in the Valley")
	m.go_to("moon", Vector2(12 * GameMap.TILE, 18 * GameMap.TILE), "down")
	m = await _arrive("moon")
	check(m != null and m.scene_id() == "moon", "the pad takes you to the moon")
	await process_frame
	check(_banner(m), "crossing into Space shows the region banner")
	check(MegaMap.tab == "space" and str(MegaRegion.st()["last"]) == "space", "the map opens on the Space tab")
	if out != "":
		for k in 40:
			await process_frame
	await _shot("mega_banner_space")
	var menu := _menu(m)
	check(menu != null, "the menu exists")
	if menu:
		menu._tab = "Map"
		paused = false
		menu.toggle()
		await process_frame
		check(menu._body.find_child("MegaMap_space", true, false) != null, "the Space tab draws its own map")
		check(menu._body.find_child("MapTab_valley", true, false) != null and menu._body.find_child("MapTab_colonies", true, false) == null, "tab row: Valley shown, locked Colonies hidden")
		await _shot("mega_tab_space")
		MegaMap.tab = "valley"
		menu._refresh()
		await process_frame
		check(menu._body.find_child("MegaMap_space", true, false) == null, "tapping Valley shows the home map")
		await _shot("mega_tab_valley")
		menu.toggle()
	# ---- the colony ferry ---------------------------------------------------------------
	GameState.run["flags"]["beach_seen"] = true
	GameState.run["quests"] = [{"id": "clear_meadow", "text": "x", "done": true}]
	m.go_to("colony_coral", Vector2(38 * GameMap.TILE, 60 * GameMap.TILE), "up")
	m = await _arrive("colony_coral")
	check(m != null and m.scene_id() == "colony_coral", "the ferry reaches Coral Reach")
	await process_frame
	check(MegaRegion.is_unlocked("colonies") and _banner(m), "arriving opens the Colonies with a banner")
	menu = _menu(m)
	if menu:
		menu._tab = "Map"
		paused = false
		menu.toggle()
		await process_frame
		await _shot("mega_tab_colonies")
		menu.toggle()
	# Within one region: no second banner.
	m.go_to("colony_kelp", Vector2(38 * GameMap.TILE, 60 * GameMap.TILE), "up")
	m = await _arrive("colony_kelp")
	await process_frame
	check(m != null and not _banner(m), "moving within a region shows no new banner")
	m.go_to("beach", Vector2(12 * GameMap.TILE, 22 * GameMap.TILE), "down")
	m = await _arrive("beach")
	await process_frame
	check(m != null and _banner(m) and str(MegaRegion.st()["last"]) == "", "back to the Valley: a welcome-home banner")
	check(MegaMap.tab == "valley", "the map opens on the Valley again")
	# ---- save round trip -------------------------------------------------------------------
	GameState.save()
	var back: Dictionary = JSON.parse_string(JSON.stringify(SaveGame.get_value(GameState.save_key())))
	GameState.run = back
	check(MegaRegion.is_unlocked("space") and MegaRegion.is_unlocked("colonies") and not MegaRegion.is_unlocked("hollow"), "unlocks survive a save")
	# ---- gangsters: the city bus -------------------------------------------------------------
	GameState.new_run("gangsters", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["hp"] = 999
	GameState.run["max_hp"] = 999
	check(not MegaRegion.available("colonies") and not MegaRegion.available("sky") and MegaRegion.available("cities"), "gangster run: cities yes, colonies/sky no")
	Campaign.bypass = false
	check(not MegaRegion.is_unlocked("cities"), "the cities start hidden")
	Campaign.bypass = true
	m = await _go("hideout")
	check(m != null and m.scene_id() == "hideout", "hideout loads")
	m.go_to("docks", Vector2(2 * GameMap.TILE, 8 * GameMap.TILE), "right")
	m = await _arrive("docks")
	await process_frame
	check(m != null and m.scene_id() == "docks" and MegaRegion.is_unlocked("cities") and _banner(m), "the city bus opens the Lieutenant Cities")
	check(m != null and "bus" in _banner_text(m), "the docks arrival rides the city bus (%s)" % (_banner_text(m) if m else ""))
	# The Ironline (Cities tab) rides the night train from town, both ways (C2).
	m = await _go("town")
	check(m != null and "bus" in _banner_text(m), "leaving the docks: the last bus home")
	m = await _go("iron_junction")
	check(m != null and "night train" in _banner_text(m) and not ("bus" in _banner_text(m)), "Junction City arrival says night train, not bus (%s)" % (_banner_text(m) if m else ""))
	m = await _go("town")
	check(m != null and "night train" in _banner_text(m) and not ("bus" in _banner_text(m)), "back from the Ironline: the night train home (%s)" % (_banner_text(m) if m else ""))
	m = await _go("hideout")
	m.go_to("docks", Vector2(2 * GameMap.TILE, 8 * GameMap.TILE), "right")
	m = await _arrive("docks")
	await process_frame
	menu = _menu(m)
	if menu:
		menu._tab = "Map"
		paused = false
		menu.toggle()
		await process_frame
		check(menu._body.find_child("MegaMap_cities", true, false) != null, "the Cities tab draws its map")
		await _shot("mega_tab_cities")
		menu.toggle()
	# ---- old saves migrate quietly -------------------------------------------------------------
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run.erase("mega")
	GameState.run["flags"]["hollow_heart_seen"] = true
	GameState.run["flags"]["sky_seen"] = true
	GameState.run["visited"] = {"farm": [1, 1]}
	check(MegaRegion.is_unlocked("hollow") and MegaRegion.is_unlocked("sky"), "an old save opens the regions it has seen")
	check(not MegaRegion.is_unlocked("space") and not MegaRegion.is_unlocked("colonies"), "but not the ones it hasn't")
	GameState.new_run("gangsters", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run.erase("mega")
	GameState.run["scene"] = "neon"
	check(MegaRegion.is_unlocked("cities") and str(MegaRegion.st()["last"]) == "cities", "an old save standing in Neon has the Cities open")
	if out != "":
		await _shot_all_regions()
	print("mega_region_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


## Every built region's tab, for a look (screenshots only).
func _shot_all_regions() -> void:
	for arc in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi", "Kairi", "Dreamhollow", "Biscuit")
		GameState.run["intro_done"] = true
		var m := await _go("farm")
		for id: String in MegaRegion.ids():
			if MegaRegion.available(id):
				MegaRegion.unlock(id)
				for a in MegaRegion.areas(id).slice(0, 2):
					GameState.run["flags"][str(a["id"]) + "_seen"] = true
		var menu := _menu(m)
		if menu == null:
			continue
		menu._tab = "Map"
		paused = false
		menu.toggle()
		for id: String in MegaRegion.unlocked():
			MegaMap.tab = id
			menu._refresh()
			await _shot("mega_all_%s_%s" % [arc, id])
		MegaMap.tab = "valley"
		menu._refresh()
		await _shot("mega_all_%s_valley" % arc)
		menu.toggle()

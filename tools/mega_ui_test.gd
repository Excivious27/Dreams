extends SceneTree
## CONDUCT 4 P4: mega UI, travel, quests and audio.
##  - travel points wait for the keeper's letter (Tom: no "locked" limo from day 1);
##  - gate words name the real story step per arc (no "chapter N");
##  - item-list quest progress, mega quests at their area ("Next here:"), GoalLine.adj for mega areas;
##  - Map tab: one sideways tab strip, the map right under it, drag passes through,
##    a pin tap opens its card (name, how to get there), Campaign button below the map;
##  - mega bosses get their own themes (by kind, then by region), caves are cave-quiet.
##   godot --headless --path . -s res://tools/mega_ui_test.gd [-- /tmp/shots]
var fails := 0
var out := ""
var n := 0


func _initialize() -> void:
	seed(11)
	Campaign.bypass = true
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func frames(k: int) -> void:
	for i in k:
		await process_frame


func shot(tag: String) -> void:
	if out == "":
		return
	n += 1
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/mu_%02d_%s.png" % [out, n, tag])


func _clear_dialogue() -> void:
	var d := Dialogue.instance(self)
	for i in 60:
		if not d.active:
			break
		if d._in_choice:
			d._choose("", d._choices.get_child_count() - 1)
		else:
			d._advance()
		await frames(3)


func _menu(m: Node) -> GameMenu:
	for ch in m.get_children():
		if ch is GameMenu:
			return ch
	return null


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
		DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	# --- travel points and gate words (gangsters) ---
	GameState.new_run("gangsters", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	var gilt := MegaTravel.reg("giltcity")
	check(not gilt.is_empty(), "Gilt City travel data exists")
	check(not MegaTravel.shows("giltcity", gilt), "day 1: no limo in the farm field before the keeper's letter")
	GameState.run["flags"]["mega_giltcity_mail"] = true
	check(MegaTravel.shows("giltcity", gilt), "the limo shows once the letter has come")
	GameState.run["flags"].erase("mega_giltcity_mail")
	var iron := MegaTravel.reg("ironline")
	var w0 := MegaTravel.gate_words(iron)
	check(w0.contains("east meadow") and not w0.contains("chapter"), "gangster gate words name the first step (%s)" % w0)
	GameState.run["quests"].append({"id": "clear_meadow", "text": "", "done": true})
	var w1 := MegaTravel.gate_words(iron)
	check(w1.contains("dock boss"), "after the meadow the Ironline waits for the dock boss (%s)" % w1)
	# --- quests ---
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.add_quest("mega_gloamwood_job", "Liesl wants 5 Wisp Thread to mend the lantern nets.")
	check(QuestTracker.progress("mega_gloamwood_job") == "0/5", "items quest progress (%s)" % QuestTracker.progress("mega_gloamwood_job"))
	GameState.add_quest("mega_gloamwood_hook", "Liesl needs flowers and herbs.")
	var ph := QuestTracker.progress("mega_gloamwood_hook")
	check(ph.contains("/") and ph.length() > 3, "two-item hook names the first short item (%s)" % ph)
	var at: Array = QuestTracker.quests_at(QuestTracker.npc_scene("mg_liesl"))
	check(at.any(func(q: Dictionary) -> bool: return str(q["id"]) == "mega_gloamwood_job"), "Liesl's job is 'next here' at her area")
	var hook_at: Array = QuestTracker.quests_at(str(MegaTravel.reg("gloamwood")["entry"]["scene"]))
	check(hook_at.any(func(q: Dictionary) -> bool: return str(q["id"]) == "mega_gloamwood_hook"), "the keeper's hook is 'next here' at the travel point's scene")
	check(not GoalLine.adj("gloam_moonpool").is_empty(), "GoalLine knows the mega areas' exits")
	check(GoalLine.next_hop("gloam_moonpool", "gloam_lanternfall") == "gloam_violet_glade", "next hop through Gloamwood (%s)" % GoalLine.next_hop("gloam_moonpool", "gloam_lanternfall"))
	# --- map pins ---
	MegaRegion.unlock("gloamwood")
	check(MegaMap.how_to("gloamwood", "gloam_moonpool").contains("fairy ring"), "how to reach the Moonpool: %s" % MegaMap.how_to("gloamwood", "gloam_moonpool"))
	var spots := MegaMap.pin_spots("gloamwood")
	check(MegaMap.pin_at("gloamwood", spots["gloam_moonpool"]) == "gloam_moonpool", "tapping a pin's spot picks it")
	var card := MegaMap.pin_card("gloamwood", "gloam_lanternfall")
	check(card.size() >= 2, "a pin card has lines (%d)" % card.size())
	# --- in a mega area: map tab, boss music, ambience ---
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/gloam_lanternfall.tscn")
	await frames(30)
	await _clear_dialogue()
	await frames(150)  # the arrival banner fades
	var gm := current_scene as GameMap
	check(gm != null and gm.scene_id() == "gloam_lanternfall", "Lanternfall loads")
	if gm:
		check(gm.boss_track("thornmother") == "boss_thornmother", "Thornmother has her own theme")
		check(gm.boss_track("garden_boss_x") == "boss_thornmother", "any boss in Gloamwood falls back to the region theme")
		check(gm.boss_track("mk_test") == "marked", "the Marked keep their own theme")
		check(not Ambience.is_cave(gm), "Lanternfall is not a cave")
		var menu := _menu(gm)
		check(menu != null, "menu present")
		if menu:
			MegaMap.tab = "gloamwood"
			MegaMap.sel = ""
			menu.toggle()
			menu.set("_tab", "Map")
			menu.call("_refresh")
			await frames(4)
			var body: VBoxContainer = menu.get("_body")
			var strip := body.find_child("MapTabs", true, false)
			check(strip is ScrollContainer, "one sideways tab strip")
			var mp := body.find_child("MegaMap_gloamwood", true, false) as Control
			check(mp != null and mp.mouse_filter == Control.MOUSE_FILTER_PASS, "the map passes drags to the scroll")
			var camp_i := -1
			for i in body.get_child_count():
				var c := body.get_child(i)
				if c is Button and (c as Button).text.begins_with("Campaign map"):
					camp_i = i
			check(mp != null and (camp_i == -1 or camp_i > mp.get_index()), "the map comes before the Campaign button")
			check(mp != null and mp.get_index() <= 1, "the map sits right under the tabs (index %d)" % (mp.get_index() if mp else -1))
			await shot("map_tab")
			if mp:
				var p: Vector2 = spots["gloam_moonpool"]
				for down in [true, false]:
					var ev := InputEventMouseButton.new()
					ev.button_index = MOUSE_BUTTON_LEFT
					ev.pressed = down
					ev.position = p
					mp.gui_input.emit(ev)
				await frames(3)
				check(MegaMap.sel == "gloam_moonpool", "a tap on a pin picks it (%s)" % MegaMap.sel)
				var txt := ""
				for l in menu.get("_body").find_children("*", "Label", true, false):
					txt += (l as Label).text + "\n"
				check(txt.contains("Getting there") or txt.contains("unexplored"), "the pin card shows under the map")
				await shot("pin_card")
			menu.toggle()
			await frames(3)
	change_scene_to_file("res://scenes/frost_caverns.tscn")
	await frames(30)
	var fc := current_scene as GameMap
	if fc:
		check(Ambience.is_cave(fc) and Ambience.is_quiet(fc), "Frost Caverns are a quiet cave (no birds, drips on)")
		check(fc.boss_track("rime_wyrm") == "boss_wyrm", "the Rime Wyrm has its own theme")
	print("mega_ui_test: %s (%d fails)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)

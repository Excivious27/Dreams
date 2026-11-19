extends SceneTree
## Character tab: asserts + screenshots at several states (new game, mid-game
## with gear and buffs, a slot open, a stat opened, scrolled, gangster arc).
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/char_sheet_test.gd -- /tmp/shots
## Headless (no shots): godot --headless --path . -s res://tools/char_sheet_test.gd
var _out := ""
var _fail := 0


func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fail += 1
		print("FAIL ", what)


func _shot(name: String) -> void:
	for i in 5:
		await process_frame
	if _out == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/cs_%s.png" % [_out, name])


func _menu(m: Node) -> GameMenu:
	for c in m.get_children():
		if c is GameMenu:
			return c
	return null


func _scroll(menu: GameMenu, px: int) -> void:
	var sc := menu._body.get_parent() as ScrollContainer
	sc.scroll_vertical = px
	await process_frame


## Scroll so the label starting with `text` sits near the top of the tab.
func _scroll_to(menu: GameMenu, text: String) -> void:
	await process_frame
	var stack: Array = [menu._body]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label and (n as Label).text.contains(text):
			var sc := menu._body.get_parent() as ScrollContainer
			sc.scroll_vertical = int((n as Control).global_position.y - menu._body.global_position.y) - 20
			await process_frame
			return
		for c in n.get_children():
			stack.append(c)
	_check(false, "label to scroll to: " + text)


func _start(arc: String, pid: String) -> GameMap:
	GameState.new_run(arc, pid, "Robin", "Frostvale" if arc == "penguins" else "Bricktown", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	change_scene_to_file("res://scenes/farm.tscn")
	for i in 30:
		await process_frame
	var d := Dialogue.instance(self)
	for i in 40:
		if d.active:
			Input.action_press("a"); await process_frame; Input.action_release("a")
		await process_frame
	return current_scene as GameMap


func _run() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		_out = OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(_out)
	InputSetup.ensure_actions()
	# 1) New game
	print("cs: start"); var m := await _start("penguins", "kairi")
	var menu := _menu(m)
	_check(menu != null, "menu exists")
	menu.toggle()
	menu._tab = "Hero"
	menu._refresh()
	print("cs: menu open"); await _shot("1_new")
	_check(menu._body.get_child_count() > 6, "hero tab builds")
	var st := CharSheet.stats()
	var ids := st.map(func(s: Dictionary) -> String: return str(s["id"]))
	for k in ["hp", "energy", "melee", "defense", "crit", "speed", "luck", "chop", "mine", "fish", "regen"]:
		_check(ids.has(k), "stat " + k)
	for s: Dictionary in st:
		if (s["parts"] as Array).any(func(p: Array) -> bool: return str(p[0]) == "Other effects"):
			print("NOTE breakdown has an unexplained part: ", s["id"], " ", s["parts"])
	await _scroll(menu, 400)
	await _shot("2_new_scrolled")
	menu.toggle()
	# 2) Mid-game: levels, gear, a set, buffs, a status, tool tiers
	for sk in ["combat", "farming", "mining", "fishing", "foraging", "magic"]:
		GameState.run["skills"][sk]["level"] = 6
	GameState.run["skills"]["combat"]["xp"] = 70
	GameState.buy_node("combat", str(GameState.nodes_of("combat")[0]["id"]))
	GameState.run["tool_tier"] = {"hoe": 2, "can": 2, "axe": 3, "pickaxe": 2, "sword": 2, "rod": 1}
	GameState.add_tool("iron_sword")
	for id in ["iron_helm", "iron_chest", "iron_legs", "iron_boots_plus", "iron_gloves", "copper_ring", "paw_charm", "iron_shield", "leather_cape", "copper_helm_plus", "crystal_helm"]:
		if GameState.items.has(id):
			GameState.add_item(id, 1)
	for id in ["iron_chest", "iron_legs", "iron_boots_plus", "iron_gloves", "iron_shield", "copper_ring"]:
		if GameState.items.has(id):
			GameState.equip(id)
	_check(GameState.equipped("body") == "iron_chest", "equip body")
	_check(CharSheet.set_counts().get("iron", 0) == 5, "iron set count 5, got %s" % str(CharSheet.set_counts()))
	GameState.run["day"] = 31
	var def0 := GameState.gear_stat("defense")
	GameState.add_item("luck_potion", 1)
	GameState.consume("luck_potion")
	GameState.status_apply("poison", 1)
	GameState.run["flags"]["mine_deepest"] = 12
	GameState.add_friend("maple", 120)
	GameState.run["hp"] = 60
	GameState.refresh_stats()
	_check(CharSheet.effects().size() >= 2, "buff + status listed")
	menu.toggle()
	menu._tab = "Hero"
	menu._refresh()
	await _shot("3_mid")
	# Tap the head slot: the panel lists bag pieces with comparisons.
	CharSheet.sel_slot = "head"
	menu._refresh()
	await _scroll_to(menu, "Equipment")
	await _shot("4_slot_head")
	await _scroll_to(menu, "Head slot")
	await _shot("4b_slot_list")
	var before := GameState.count("crystal_helm")
	var cands := CharSheet.candidates("head")
	_check(cands.size() >= 2 and str(cands[0]) == "crystal_helm", "head candidates sorted best first: %s" % str(cands))
	GameState.equip("crystal_helm")
	_check(GameState.equipped("head") == "crystal_helm" and GameState.count("crystal_helm") == before - 1, "equip from sheet")
	_check(CharSheet.compare("iron_helm", "crystal_helm").size() > 0, "compare")
	GameState.unequip("head")
	_check(GameState.count("crystal_helm") == before, "unequip returns it")
	GameState.equip("crystal_helm")
	_check(GameState.gear_stat("defense") > def0, "helm adds defense")
	CharSheet.sel_slot = ""
	CharSheet.open_stat = "defense"
	menu._refresh()
	await _scroll_to(menu, "Max energy")
	var sc := menu._body.get_parent() as ScrollContainer
	var keep := sc.scroll_vertical
	CharSheet.open_stat = "luck"
	menu._refresh()
	for i in 4:
		await process_frame
	_check(absi(sc.scroll_vertical - keep) <= 2, "a tap keeps the scroll (%d -> %d)" % [keep, sc.scroll_vertical])
	CharSheet.open_stat = "defense"
	menu._refresh()
	await _shot("5_stat_defense")
	CharSheet.open_stat = "melee"
	CharSheet.sel_tool = "axe"
	menu._refresh()
	await _scroll(menu, 9999)
	await _shot("6_bottom")
	await _scroll_to(menu, "Buffs & statuses")
	await _shot("7_skills")
	# Release-mode: every button on the sheet ignores scroll drags.
	var press := 0
	var stack: Array = [menu._body]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
			if c is BaseButton and (c as BaseButton).action_mode == BaseButton.ACTION_MODE_BUTTON_PRESS:
				press += 1
	_check(press == 0, "no press-mode buttons (%d)" % press)
	menu.toggle()
	CharSheet.open_stat = ""
	CharSheet.sel_tool = ""
	# 3) Gangster arc
	m = await _start("gangsters", "rafe")
	menu = _menu(m)
	GameState.add_tool("six_shooter")
	GameState.add_item("rounds", 24)
	GameState.add_item("pinstripe_suit", 1)
	menu.toggle()
	menu._tab = "Hero"
	menu._refresh()
	_check(CharSheet.stats().any(func(s: Dictionary) -> bool: return str(s["id"]) == "ranged"), "ranged stat with a gun")
	await _shot("8_gang")
	CharSheet.open_stat = "ranged"
	menu._refresh()
	await _scroll_to(menu, "Melee attack")
	await _shot("9_gang_ranged")
	menu.toggle()
	print("char_sheet_test: %s (%d failed)" % ["OK" if _fail == 0 else "FAILED", _fail])
	quit(1 if _fail > 0 else 0)

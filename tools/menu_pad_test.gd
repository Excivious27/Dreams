extends SceneTree
## Menu with a pad/keyboard only (CONDUCT 9 P2): every tab reachable by tab_next,
## the cursor walks rows with up/down and presses with A, B steps back a sub-page
## before closing, the menu refuses to open during a map change, Text size reaches
## menu rows, Text speed "instant" shows the whole line.
##   godot --headless --path . --fixed-fps 60 -s res://tools/menu_pad_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(9)
	Campaign.bypass = true
	_run.call_deferred()


func press(action: String, hold := 2) -> void:
	Input.action_press(action)
	for i in hold:
		await process_frame
	Input.action_release(action)
	await process_frame


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _menu() -> GameMenu:
	for ch in current_scene.get_children():
		if ch is GameMenu:
			return ch
	return null


func _run() -> void:
	InputSetup.ensure_actions()
	for k: String in Settings.DEFAULTS:
		Settings.set_v(k, Settings.DEFAULTS[k])
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	for f in ["town_seen", "meow_taught", "tip_hoe", "tip_can", "tip_axe", "tip_pickaxe", "tip_scythe", "tip_sword", "tip_seed", "tip_rod"]:
		GameState.run["flags"][f] = true
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/beach.tscn")
	await frames(30)
	var d := Dialogue.instance(self)
	for i in 30:
		if not d.active:
			break
		d._advance()
		await frames(3)
	var m := _menu()
	check(m != null, "menu exists")
	if m == null:
		return _end()
	await press("menu")
	await frames(4)
	check(m._open, "MENU opens the menu")
	# tab_next walks all ten tabs and wraps.
	var seen := {}
	for i in GameMenu.TABS.size():
		seen[m._tab] = true
		await press("tab_next")
		await frames(2)
	check(seen.size() == GameMenu.TABS.size(), "tab_next reaches every tab (%d)" % seen.size())
	check(m._tab == "Items", "tab_next wraps to Items (on %s)" % m._tab)
	await press("tab_prev")
	await frames(2)
	check(m._tab == "Options", "tab_prev goes back to Options")
	# Cursor: a direction shows it on the first row; down moves on.
	check(m.cursor_control() == null, "cursor hidden until a direction is pressed")
	await press("down")
	await frames(2)
	var c0 := m.cursor_control()
	check(c0 != null, "down shows the cursor")
	await press("down")
	await frames(2)
	check(m.cursor_control() != c0 and m.cursor_control() != null, "down moves the cursor")
	# Options: down from "All sound" goes to the volume buttons right under it.
	m._hide_cursor()
	await press("down")
	var first := m.cursor_control()
	await press("down")
	var nxt := m.cursor_control()
	if first is Button and str((first as Button).text).begins_with("All sound"):
		check(nxt is Button and str((nxt as Button).text).strip_edges() in ["−", "+"], "down from All sound reaches the volume buttons (got %s)" % (str((nxt as Button).text) if nxt is Button else "none"))
	# Up from the top row lands on the tab row; left/right there switch tabs.
	for i in 60:
		await press("up")
		if m._cur_tabs:
			break
	check(m._cur_tabs, "up past the top reaches the tab row")
	await press("right")
	await frames(2)
	check(m._tab == "Items", "right on the tab row switches tab (on %s)" % m._tab)
	await press("left")
	await frames(2)
	check(m._tab == "Options", "left on the tab row switches back")
	# A on a row presses it: find Text size and press it with the cursor.
	await press("down")
	var hit := false
	for i in 40:
		var c := m.cursor_control()
		if c is Button and str((c as Button).text).begins_with("Text size"):
			hit = true
			break
		await press("down")
	check(hit, "cursor reaches the Text size row")
	if hit:
		var before := Settings.text_step()
		await press("a")
		await frames(3)
		check(Settings.text_step() == (before + 1) % Settings.TEXT_NAMES.size(), "A presses the row under the cursor")
		# Text size reaches menu rows (+2 px per step).
		var l := m._line("probe")
		check(l.get_theme_font_size("font_size") == 9 + Settings.TEXT_STEP * Settings.text_step(), "menu lines follow Text size")
		Settings.set_v("text_size", 0)
	# B on a sub-page steps back, B on a tab closes.
	m._tab = "Keys" if not DisplayMode.is_phone() else "Pad"
	m._refresh()
	await frames(10)
	await press("b")
	await frames(3)
	check(m._open and m._tab == "Options", "B on a sub-page goes back to Options")
	m._tab = "Quests"
	m._refresh()
	m._tab = "Mail"
	m._refresh()
	await frames(10)
	await press("b")
	await frames(3)
	check(m._open and m._tab == "Quests", "B on Mail goes back to Quests")
	# Items with the cursor: A on a bag slot holding something picks it, A on an
	# empty bag slot puts it down there, and B drops a pick before anything else.
	GameState.add_item("berry", 3)
	m._tab = "Items"
	m._refresh()
	await frames(3)
	var bag := GameState.bag_slots()
	var bi := bag.find("berry")
	var empty := bag.find("")
	var slots: Array = []
	for b in m._cursor_list():
		if (b as Control).custom_minimum_size == Vector2(GameMenu.SLOT, GameMenu.SLOT):
			slots.append(b)
	if bi >= 0 and empty >= 0:
		# Bag slots are the last 30 square buttons, in bag order.
		var bag_btns := slots.slice(slots.size() - bag.size())
		m._cur = m._cursor_list().find(bag_btns[bi])
		await press("a")
		await frames(2)
		check(m._bag_pick == "berry", "A on a bag slot picks it (picked '%s')" % m._bag_pick)
		var l2 := m._cursor_list()
		var sq: Array = []
		for b in l2:
			if (b as Control).custom_minimum_size == Vector2(GameMenu.SLOT, GameMenu.SLOT):
				sq.append(b)
		m._cur = l2.find(sq[sq.size() - bag.size() + empty])
		await press("a")
		await frames(2)
		check(m._bag_pick == "" and GameState.bag_slots()[empty] == "berry", "A on an empty bag slot puts it there")
	else:
		check(false, "bag has berries and a free slot")
	# C10a P3: Book with the cursor: the Decor catalogue row opens its screen over the menu
	# (B closes it, the menu stays); a museum group header keeps the cursor on itself.
	m._tab = "Book"
	CollectionScreen.open("")
	m._refresh()
	await frames(3)
	var drow := -1
	var bl := m._cursor_list()
	for i in bl.size():
		if (bl[i] as Control).has_meta("pc_key") and str((bl[i] as Control).get_meta("pc_key")) == "book:decor":
			drow = i
	check(drow >= 0, "Book hub has the Decor catalogue row")
	if drow >= 0:
		m._cur = drow
		await press("a")
		await frames(12)
		var cat: DecorCatalogue = null
		for ch in m.get_parent().get_children():
			if ch is DecorCatalogue:
				cat = ch
		check(cat != null, "A on the row opens the Decor catalogue")
		await press("b")
		await frames(4)
		check(not is_instance_valid(cat) or cat.is_queued_for_deletion(), "B closes the catalogue")
		check(m._open and m._tab == "Book", "the menu stays open on the Book after the catalogue")
		check(Hud.modal_rect.size == Vector2.ZERO, "catalogue gives the modal back")
	CollectionScreen.open("museum")
	m._refresh()
	await frames(3)
	var hdrs: Array = []
	for b in m._cursor_list():
		if (b as Control).has_meta("pc_key") and str((b as Control).get_meta("pc_key")).begins_with("grp:"):
			hdrs.append(b)
	check(hdrs.size() >= 2, "museum page has group headers (%d)" % hdrs.size())
	if hdrs.size() >= 2:
		var key2 := str((hdrs[1] as Control).get_meta("pc_key"))
		m._cur = m._cursor_list().find(hdrs[1])
		await press("a")
		await frames(3)
		var cc := m.cursor_control()
		check(cc != null and cc.has_meta("pc_key") and str(cc.get_meta("pc_key")) == key2, "cursor stays on the opened group header")
		check(CollectionScreen.sub == key2.trim_prefix("grp:"), "A opened that group")
	CollectionScreen.sub = "no_such_group"
	m._refresh()
	await frames(2)
	check(CollectionScreen.sub != "no_such_group", "a stale group falls back to the first")
	await press("b")
	await frames(3)
	check(m._open and CollectionScreen.page == "", "B on a Book page goes back to the hub")
	m._tab = "Items"
	m._refresh()
	await frames(2)
	# Skills: the cursor list never holds disabled (empty) node cells.
	m._tab = "Skills"
	m._refresh()
	await frames(3)
	var dis := 0
	for b in m._cursor_list():
		if (b as BaseButton).disabled:
			dis += 1
	check(dis == 0, "cursor skips disabled cells")
	await press("b")
	await frames(3)
	check(not m._open, "B on a top tab closes the menu")
	# Rebinding a key another action uses asks first.
	if not DisplayMode.is_phone():
		check(GameMenu.key_owner("tool", KEY_X) == "action", "key_owner finds the action using X")
	# During a map change the menu stays shut.
	var gm := current_scene as GameMap
	gm._changing = true
	m.toggle()
	check(not m._open, "menu refuses to open during a map change")
	gm._changing = false
	# Text speed instant: the whole line shows at once.
	Settings.set_v("text_speed", 3)
	d.say([{"who": "T", "text": "A line long enough to need typing out on screen."}])
	await frames(3)
	check(not d._typing, "instant text speed shows the whole line")
	d._advance()
	await frames(3)
	Settings.set_v("text_speed", 1)
	# Held down in a choice list repeats and stops at the last option.
	d.say([{"who": "T", "text": "Pick", "choice": ["One", "Two", "Three", "Four", "Leave"]}])
	await frames(15)
	Input.action_press("down")
	await frames(90)
	Input.action_release("down")
	await frames(2)
	check(d._choice_focus == 4, "held down repeats to the last choice (at %d)" % d._choice_focus)
	await press("b")
	await frames(5)
	check(not d.active, "B leaves the choice")
	# Reduced motion setting reads the old shake key.
	Settings.set_v("shake", false)
	check(Settings.reduced_motion(), "reduced motion follows the shake key")
	Settings.set_v("shake", true)
	check(Settings.timing_factor() == 1.0, "timing help off by default")
	var w0 := Fishing.window_for("minnow")
	Settings.set_v("timing_help", true)
	check(is_equal_approx(Fishing.window_for("minnow"), w0 * Settings.TIMING_HELP_WINDOW), "timing help widens the bite window")
	Settings.set_v("timing_help", false)
	# Rarity reads by dot count, not colour alone: all seven levels (C10a: mythic 5 dots, unique a star).
	var saved := Decor._data.duplicate(true)
	Decor._data = {"items": {}, "sets": {}, "shops": {}, "pools": {}}
	for rn in Decor.RARITIES:
		Decor._data["items"]["t_" + rn] = {"name": rn, "cat": "decor", "rarity": rn}
	var want := {"common": 0, "uncommon": 1, "rare": 2, "epic": 3, "legendary": 4, "mythic": 5}
	for rn in Decor.RARITIES:
		var probe := Control.new()
		DecorCatalogue.rarity_dots(probe, "t_" + rn, 30)
		var dots := 0
		var stars := 0
		for ch in probe.get_children():
			if ch is ColorRect:
				dots += 1
			elif ch is Label:
				stars += 1
		if rn == "unique":
			check(stars == 1 and dots == 0, "unique shows a star plate")
		else:
			check(dots == int(want[rn]), "rarity %s has %d dots (got %d)" % [rn, int(want[rn]), dots])
		check(DecorCatalogue.rarity_col("t_" + rn) == Decor.rarity_color(rn), "rarity %s colour from the one table" % rn)
		probe.free()
	var colors := {}
	for rn in Decor.RARITIES:
		colors[Decor.rarity_color(rn).to_html()] = true
	check(colors.size() == Decor.RARITIES.size(), "every rarity has its own colour")
	Decor._data = saved
	for id in GameState.items:
		var rr := str(GameState.items[id].get("rarity", "common"))
		if rr in ["uncommon", "rare", "epic", "legendary"]:
			var probe2 := Control.new()
			DecorCatalogue.rarity_dots(probe2, str(id), 30)
			check(probe2.get_child_count() == int(want[rr]), "item %s (%s) dots" % [id, rr])
			probe2.free()
			break
	# Fullscreen row: never on iOS; the help text names keys and the controller.
	check("Controller:" in GameMenu.help_text(), "help names the controller buttons")
	_end()


func _end() -> void:
	for k: String in Settings.DEFAULTS:
		Settings.set_v(k, Settings.DEFAULTS[k])
	print("menu_pad_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

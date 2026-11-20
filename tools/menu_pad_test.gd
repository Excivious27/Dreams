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
	# Rarity reads by dot count, not colour alone.
	var ranks := {}
	for id in GameState.items:
		ranks[str(GameState.items[id].get("rarity", "common"))] = CharSheet.rarity_rank(str(id))
	for rn in ["uncommon", "rare", "epic", "legendary"]:
		if ranks.has(rn):
			check(int(ranks[rn]) == int(CharSheet.RARITY_RANK[rn]), "rarity %s has %d dots" % [rn, int(CharSheet.RARITY_RANK[rn])])
	# Fullscreen row: never on iOS; the help text names keys and the controller.
	check("Controller:" in GameMenu.help_text(), "help names the controller buttons")
	_end()


func _end() -> void:
	for k: String in Settings.DEFAULTS:
		Settings.set_v(k, Settings.DEFAULTS[k])
	print("menu_pad_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

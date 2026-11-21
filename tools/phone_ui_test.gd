extends SceneTree
## Phone UI audit (270x480): opens every menu tab and sub-tab, dialogue (plain,
## portrait, long text, long choice list, a shop), toasts, the chest, a craft
## screen, the prize counter, the arcade picker, bowling and the campaign board,
## every arcade cabinet (title + play), jumper select, bowling aim/power, every
## prize shelf, the hack terminal, chest and craft inside the Rec Center,
## in both arcs, and runs UiAudit on each (off-screen, spills out of a panel,
## buttons too small to tap, cut-off text, tiny fonts). Fails on any issue.
##   godot --headless --path . -s res://tools/phone_ui_test.gd
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/phone_ui_test.gd -- /tmp/phone   (also screenshots)
const UiAudit := preload("res://tools/ui_audit.gd")
var out := ""
var issues: Array = []
var arc := ""


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


## deck_text_test.gd extends this walk and reports under its own name.
func _test_name() -> String:
	return "phone_ui_test"


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(name: String, node: Node = null) -> void:
	await _frames(4)
	var nm := arc.left(1) + "_" + name
	var found: Array = UiAudit.audit(node if node else root, nm)
	for f: String in found:
		print("ISSUE ", f)
	issues.append_array(found)
	if out != "":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, nm])


func _clear_dialogue() -> void:
	var d := Dialogue.instance(self)
	for k in 40:
		if not d.active:
			break
		if d._in_choice:
			d._choose("", d._choices.get_child_count() - 1)
		else:
			d._advance()
		await _frames(2)


func _menu(m: GameMap) -> GameMenu:
	for c in m.get_children():
		if c is GameMenu:
			return c
	return null


func _child(m: Node, cls: String) -> Node:
	for c in m.get_children():
		if c.get_script() and (c.get_script() as Script).get_global_name() == cls:
			return c
	return null


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
		DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	# The web build has no system fonts: shots and checks run without them too.
	var df := ThemeDB.fallback_font
	if df is FontFile:
		(df as FontFile).allow_system_fallback = false
	_glyphs(df)
	await _title_pass()
	for a: String in ["penguins", "gangsters"]:
		arc = a
		await _arc_pass()
	print("%s: %d issue(s)" % [_test_name(), issues.size()])
	quit(1 if issues.size() > 0 else 0)


## C4: the new-game page with its Difficulty / Day length buttons, and the
## save slots page (two-line slot info with mode and day length).
func _title_pass() -> void:
	arc = "title"
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit", {"difficulty": 0, "day_len": 40})
	GameState.save()
	change_scene_to_file("res://scenes/title.tscn")
	await _frames(10)
	var t := current_scene
	t.set("_arc", "penguins")
	t.set("_playable", "kairi")
	t.call("_show_names")
	await _check("newgame_names", t)
	for i in 1:  # Default -> Hard: the longest description
		for b in t.find_children("*", "Button", true, false):
			if (b as Button).text.begins_with("Difficulty"):
				(b as Button).pressed.emit()
				break
	await _check("newgame_names_hard", t)
	t.call("_show_slots")
	await _check("slots", t)
	t.call("_show_sound")  # C6 P1: title sound page (volumes before a save loads)
	await _check("title_sound", t)
	t.call("_show_net")  # relay: Play together (server field + Reset to default)
	await _check("play_together", t)
	GameState.run = {}


## Every non-ASCII character the game prints has a glyph (Open Sans + fonts/symbols.ttf).
func _glyphs(f: Font) -> void:
	var seen := {}
	var files: Array = []
	for dir: String in ["res://scripts", "res://data"]:
		for fn in DirAccess.get_files_at(dir):
			if fn.ends_with(".gd") or fn.ends_with(".json"):
				files.append(dir.path_join(fn))
	for p: String in files:
		var txt := FileAccess.get_file_as_string(p)
		for i in txt.length():
			var ch := txt.unicode_at(i)
			if ch > 127 and not seen.has(ch):
				seen[ch] = p
	var miss := ""
	for ch: int in seen:
		if ch == 0xFE0F or ch == 0x200B:
			continue  # variation selector / zero-width space draw nothing anyway
		if not f.has_char(ch):
			miss += "%s (U+%04X, %s) " % [String.chr(ch), ch, str(seen[ch]).get_file()]
	if miss != "":
		issues.append("glyph|all|no glyph on the web build: " + miss + "-> run tools/make_symbol_font.py or pick another symbol")
		print("ISSUE glyph ", miss)
	else:
		print("glyphs ok: ", seen.size(), " non-ASCII characters")


func _arc_pass() -> void:
	GameState.new_run(arc, "kairi" if arc == "penguins" else "dad", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	for f in ["town_seen", "town_tour", "partner_scene", "interior_seen", "store_first"]:
		GameState.run["flags"][f] = true
	GameState.run["builds"] = {"furnace": 2, "workbench": 2}
	for id in ["turnip", "potato", "carrot", "stone", "wood", "copper", "coal", "fiber", "sap", "bread"]:
		GameState.add_item(id, 12)
	GameState.add_quality("turnip", "g", 2)
	GameState.run["crystals"] = 123456
	GameState.add_friend("maple", 300)
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/farm.tscn")
	await _frames(30)
	await _clear_dialogue()
	var m := current_scene as GameMap
	await _check("hud")
	# Toasts: the longest kinds stack three high.
	m.hud.toast("You're too tired to keep working. Eat something or head home to sleep before midnight.", Color(1, 0.7, 0.7))
	m.hud.toast("+1 Wood")
	m.hud.toast("Got the Copper Watering Can! It waters three tiles in a row.", Color(1, 0.9, 0.4))
	await _check("toasts")
	for c in m.hud._toasts.get_children():
		c.queue_free()
	# Dialogue.
	var d := Dialogue.instance(self)
	d.say([{"who": "Maple", "text": "You're the one who took the old plot! Here, first-timer's bundle. Don't tell Gideon I give things away. Seeds, snacks, and whatever fell off the cart, plenty for a whole season of turnips."}])
	await _frames(6)
	d._advance()  # finish the typewriter: the box grows to the whole text
	await _check("dialogue_long")
	await _clear_dialogue()
	d.say([{"who": "Maple", "text": "Seeds, snacks, and whatever fell off the cart. What'll it be?  (you have ◆123456)", "choice": ["Turnip Seeds  ◆20  · 4 days", "Potato Seeds  ◆50  · 6 days", "Cauliflower Seeds  ◆80  · 12 days", "Strawberry Seeds  ◆100  · 8 days", "Blueberry Seeds  ◆80  · 13 days", "Energy Tea  ◆40", "Backpack Upgrade  ◆2000", "Leave"], "key": ""}])
	await _frames(20)
	await _check("dialogue_choice")
	await _clear_dialogue()
	# Menu: every tab and sub-tab.
	var menu := _menu(m)
	if menu:
		menu.toggle()
		for t: String in GameMenu.TABS + ["Keys", "Coop", "FieldLog", "Workshop", "Foes", "Messages", "Mail"]:
			menu._tab = t
			menu._refresh()
			await _check("menu_" + t.to_lower(), menu)
		menu.toggle()
		await _frames(4)
	# Chest.
	ChestScreen.open(m, "chest", "Chest")
	await _frames(10)
	var cs := _child(m, "ChestScreen")
	await _check("chest", cs)
	if cs:
		cs.close()
	await _frames(4)
	# Craft.
	Crafting.run(m, "furnace")
	await _frames(10)
	var cr := _child(m, "CraftScreen") as CraftScreen
	await _check("craft", cr)
	if cr:
		var rcs: Array = Crafting.available("furnace", 2)
		if not rcs.is_empty():
			cr._sel = rcs[0]
			cr._refresh()
			await _check("craft_picked", cr)
		cr.close()
	await _frames(4)
	await _clear_dialogue()
	# Prize counter.
	Tickets.add(900, "test")
	GameState.run["time"] = 12 * 60  # counter hours
	PrizeScreen.open(m)
	await _frames(10)
	var ps := _child(m, "PrizeScreen")
	await _check("prizes", ps)
	if ps:
		ps._close()
	await _frames(4)
	get_root().get_tree().paused = false
	# Campaign board.
	CampaignScreen.open(m)
	await _frames(10)
	var cb := _child(m, "CampaignScreen")
	await _check("campaign", cb)
	if cb:
		if cb.has_method("close"):
			cb.close()
		else:
			cb.queue_free()
	await _frames(4)
	paused = false
	await _clear_dialogue()
	# Arcade picker (custom drawn: the shot is the check) and bowling.
	var hub := ArcadeHub.make("")
	hub.manual = true
	root.add_child(hub)
	for i in 20:
		hub.t += 1.0 / 60.0
		hub.frame()
	if hub._canvas:
		hub._canvas.queue_redraw()
	await _check("arcade_picker", hub)
	hub.close()
	await _frames(4)
	var bw := Bowling.new()
	bw.lane = 2
	m.add_child(bw)
	await _frames(12)
	await _check("bowling", bw)
	bw.rolls = [10, 7, 3, 9, 0, 10, 0, 8, 8, 2, 0, 6, 10, 10, 10, 8, 1]
	bw._game_over()
	await _check("bowling_over", bw)
	bw._finish()
	await _frames(6)
	paused = false
	await _clear_dialogue()
	await _fullscreen_pass(m)


## CONDUCT 2 (c2_12): every drawn full-screen screen — each cabinet's title card and
## a round in play, the jumper level select, bowling's aim/power, every prize shelf,
## the hack terminal — plus the chest and a craft screen inside the Rec Center (HUD
## at the bottom there). Drawn screens get a tap-target audit of their own buttons
## (inside the screen, >= 20 px, no two overlapping); the shots are the visual check.
func _fullscreen_pass(m: GameMap) -> void:
	for id: String in ArcadeHub.game_ids():
		var g := ArcadeHub.make(id)
		g.manual = true
		m.add_child(g)
		for i in 10:
			g.t += 1.0 / 60.0
			g.frame()
		_taps("arcade_" + id, g._deck.map(func(b: Dictionary) -> Rect2: return b["rect"]))
		g._canvas.queue_redraw()
		await _check("arcade_%s_title" % id, g)
		if id == "jumper":
			g.state = "select"
			g._canvas.queue_redraw()
			await _check("arcade_jumper_select", g)
			(g as BlockJumper).play_tile(0)
		else:
			g.start()
		for i in 90:
			g.t += 1.0 / 60.0
			g.frame()
		g._canvas.queue_redraw()
		await _check("arcade_%s_play" % id, g)
		g.close()
		await _frames(3)
	# Wardrobe at every text size (C10b P5, c10b_11-21): nothing runs off the panel.
	for ts in [0, 2]:
		Settings.set_v("text_size", ts)
		var wsc := WardrobeScreen.open(m)
		await _frames(4)
		await _check("wardrobe_t%d" % ts, wsc)
		wsc._close()
		await _frames(3)
	Settings.set_v("text_size", 0)
	paused = false
	var bw := Bowling.new()
	bw.lane = 1
	m.add_child(bw)
	await _frames(10)
	_taps("bowling", bw._rects())
	for ph in ["aim", "power"]:
		bw.phase = ph
		await _check("bowling_" + ph, bw)
	bw._finish()
	await _frames(4)
	paused = false
	GameState.run["time"] = 12 * 60
	PrizeScreen.open(m)
	await _frames(6)
	var ps := _child(m, "PrizeScreen") as PrizeScreen
	if ps:
		var tabs: Array = []
		for i in PrizeScreen.TIERS.size():
			tabs.append(ps._tab_rect(i))
		_taps("prizes", tabs + [PrizeScreen.BTN_BUY, PrizeScreen.BTN_CLOSE])
		for i in PrizeScreen.TIERS.size():
			ps._tier(i)
			var rows_end := PrizeScreen.LIST_Y + ps._rows.size() * PrizeScreen.ROW_H
			if rows_end > 342.0:
				issues.append("off|%s_prizes_%d|%d prizes run under the detail box (rows end at %d)" % [arc.left(1), i, ps._rows.size(), rows_end])
			await _check("prizes_%s" % str(PrizeScreen.TIERS[i]).to_lower(), ps)
		ps._close()
	await _frames(4)
	paused = false
	HackGame.play(m, 1)
	await _frames(6)
	var hg := _child(m, "HackGame") as HackGame
	if hg:
		var arrows: Array = []
		for d: String in HackGame.DIRS:
			arrows.append(Rect2(HackGame.POS[d] - Vector2(22, 22), Vector2(44, 44)))
		_taps("hack", arrows + [HackGame.BTN_UNPLUG])
		await _check("hack", hg)
		hg._finish()
	await _frames(4)
	paused = false
	await _clear_dialogue()
	# Chest and craft inside the Rec Center (indoors the HUD sits at the bottom).
	GameState.run["flags"]["rec_open"] = 1
	GameState.run["flags"]["rec_visited"] = true
	GameMap.next_interior = "rec"
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/interior.tscn")
	await _frames(30)
	await _clear_dialogue()
	var r := current_scene as GameMap
	if r == null:
		issues.append("load|%s_rec|the rec interior didn't load" % arc.left(1))
		return
	await _check("rec_hud")
	ChestScreen.open(r, "chest", "Chest")
	await _frames(10)
	var cs := _child(r, "ChestScreen")
	await _check("rec_chest", cs)
	if cs:
		cs.close()
	await _frames(4)
	Crafting.run(r, "workbench")
	await _frames(10)
	var cr := _child(r, "CraftScreen") as CraftScreen
	await _check("rec_craft", cr)
	if cr:
		cr.close()
	await _frames(4)
	paused = false
	await _clear_dialogue()


## Tap targets of a drawn screen: on screen, finger-sized, not on top of each other.
func _taps(screen: String, rects: Array) -> void:
	var nm := arc.left(1) + "_" + screen
	for i in rects.size():
		var a: Rect2 = rects[i]
		if a.position.x < 0 or a.position.y < 0 or a.end.x > 270 or a.end.y > 480:
			issues.append("off|%s|button %s leaves the screen" % [nm, a])
		if minf(a.size.x, a.size.y) < UiAudit.MIN_TAP:
			issues.append("tap|%s|button %s is under %d px" % [nm, a, UiAudit.MIN_TAP])
		for j in range(i + 1, rects.size()):
			var b: Rect2 = rects[j]
			if a.intersects(b):
				issues.append("overlap|%s|buttons %s and %s overlap" % [nm, a, b])

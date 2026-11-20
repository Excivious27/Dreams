extends SceneTree
## Menu sweep (CONDUCT 2 / 16): open the game menu, visit every tab, press every
## button in it one at a time, then leave with B (MENU last). Whatever the button
## opened (a sub-dialogue, a full-screen UI, a rebind wait) must let you out.
##   godot --headless --path . -s res://tools/menu_sweep_test.gd -- [penguins|gangsters] [-v]
var fails := 0
var verbose := false
const SKIP := ["title", "Replay the ending", "Travel", "Warp", "quit"]  # these leave the map (or the game) on purpose
var _saved_globals := {}  # every Settings global (and keys/mute) as found, put back at the end (C9 c9_12)


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
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
	if current_scene == null:
		return null
	for ch in current_scene.get_children():
		if ch is GameMenu:
			return ch
	return null


func _buttons(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is BaseButton and (c as CanvasItem).is_visible_in_tree() and not (c as BaseButton).disabled:
			out.append(c)
		_buttons(c, out)


## Back out of whatever is up: B through dialogues and screens, MENU last.
func _leave() -> bool:
	var d := Dialogue.instance(self)
	for i in 30:
		if not paused and not d.active:
			return true
		if d.active:
			d._advance() if not d._in_choice else await press("b")
			await frames(4)
			continue
		await press("b" if i % 4 != 3 else "menu")
		await frames(8)
	return not paused and not d.active


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var arc := "gangsters" if a.has("gangsters") else "penguins"
	verbose = a.has("-v")
	for k: String in Settings.DEFAULTS:
		_saved_globals["set_" + k] = SaveGame.get_value("set_" + k, null)
	for k: String in ["keys", "muted"]:
		_saved_globals[k] = SaveGame.get_value(k, null)
	InputSetup.ensure_actions()
	Dialogue.audit = true
	Dialogue.audit_log.clear()
	GameState.new_run(arc, "kairi" if arc == "penguins" else "pax", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	for f in ["town_seen", "meow_taught", "mine_open_1", "mountain_seen", "tip_hoe", "tip_can", "tip_axe", "tip_pickaxe", "tip_scythe", "tip_sword", "tip_seed", "tip_rod"]:
		GameState.run["flags"][f] = true
	GameState.run["crystals"] = int(GameState.run["crystals"]) + 2000
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/beach.tscn")
	await frames(30)
	await _leave()
	var start_scene := current_scene
	var menu := _menu()
	check(menu != null, "menu on the beach")
	if menu == null:
		print("menu_sweep_test: %d failures" % fails)
		quit(1)
		return
	var tabs: Array = menu._tab_buttons.keys()
	var presses := 0
	for t in tabs:
		# How many buttons the tab has (it is rebuilt after every press).
		await press("menu")
		await frames(4)
		if not menu._open:
			check(false, "menu opens (before tab %s)" % t)
			await _leave()
			continue
		(menu._tab_buttons[t] as Button).pressed.emit()
		await frames(3)
		var first: Array = []
		_buttons(menu._body, first)
		var n := mini(first.size(), 40)
		await _leave()
		for i in n:
			await press("menu")
			await frames(4)
			if not is_instance_valid(menu) or not menu._open:
				check(false, "menu opens (tab %s #%d)" % [t, i])
				await _leave()
				continue
			(menu._tab_buttons[t] as Button).pressed.emit()
			await frames(3)
			var bs: Array = []
			_buttons(menu._body, bs)
			if i >= bs.size():
				await _leave()
				continue
			var b: BaseButton = bs[i]
			var txt := str(b.get("text")) if b.get("text") != null else ""
			var skip := false
			for s in SKIP:
				if s in txt:
					skip = true
			if skip:
				await _leave()
				continue
			if verbose:
				print("  %s #%d %s" % [t, i, txt.left(40)])
			b.pressed.emit()
			presses += 1
			await frames(5)
			# A tab button may have moved us to another tab; press one more there too.
			var ok := await _leave()
			check(ok, "stuck after %s > '%s' (open: %s)" % [t, txt.left(40), _open_names()])
			if not ok:
				paused = false
				Hud.modal_rect = Rect2()
			if current_scene != start_scene:
				check(false, "%s > '%s' left the map" % [t, txt.left(40)])
				return _finish(presses)
	_finish(presses)


func _open_names() -> String:
	var out: Array = []
	_names(root, out)
	return ", ".join(out)


func _names(n: Node, out: Array) -> void:
	for c in n.get_children():
		var sc: Script = c.get_script()
		var shown: bool = (c as CanvasLayer).visible if c is CanvasLayer else ((c as CanvasItem).visible if c is CanvasItem else true)
		if sc and shown and (c is CanvasLayer or c is Control):
			var nm := str(sc.get_global_name())
			if nm != "" and nm not in ["Hud", "TouchControls", "Dialogue"]:
				out.append(nm)
		if out.size() < 8:
			_names(c, out)


func _restore_globals() -> void:
	# The sweep toggles every Options row (left-handed, text size, ...): later tests
	# in a serial check.sh share user://, so leave the globals as they were.
	for k: String in _saved_globals:
		if _saved_globals[k] == null:
			SaveGame.set_value(k, Settings.DEFAULTS.get(k.trim_prefix("set_"), {} if k == "keys" else false))
		else:
			SaveGame.set_value(k, _saved_globals[k])
	InputSetup.reset_bindings() if _saved_globals.get("keys") == null else InputSetup.apply(InputSetup.keys())


func _finish(presses: int) -> void:
	_restore_globals()
	for t in Dialogue.audit_log:
		check(false, "menu B can't leave: " + str(t))
	print("menu_sweep_test: %d buttons pressed, %d failures" % [presses, fails])
	quit(1 if fails > 0 else 0)

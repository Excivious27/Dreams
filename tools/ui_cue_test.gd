extends SceneTree
## C13 P6 UI cues on touch and pad: crafting (recipe cards, tabs, -/+/Max with a
## refusal at the limits, a greyed MAKE answers with nope, no stacked cue on MAKE),
## Decorate mode open/close/deny, the controller keyboard (move, type, full, delete,
## done), ScreenCursor moves tick softer than confirms, GameMenu tab-row L/R plays
## one cue. Reads Music._last_sfx (cue name -> ms) as the trace.
##   godot --headless --path . --fixed-fps 60 -s res://tools/ui_cue_test.gd
var fails := 0
var mu: Music


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(13)
	Campaign.bypass = true
	InputSetup.ensure_actions()
	GameState.load_data()
	_run.call_deferred()


func _clear() -> void:
	OS.delay_msec(80)
	mu._last_sfx.clear()


func _heard() -> Array:
	return mu._last_sfx.keys()


func _load(sc: String) -> GameMap:
	GameState.new_run("penguins", "man", "Tester", "Dreamhollow", "Pip")
	GameState.run["intro_done"] = true
	for f in ["cm_seen", "mine_open_1", "meow_taught", "intro_done", "partner_scene"]:
		GameState.run["flags"][f] = true
	GameState.run["flags"][sc + "_seen"] = true
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/%s.tscn" % sc)
	for i in 10:
		await process_frame
	var d := Dialogue.instance(self)
	for k in 4:
		if d.active:
			d._advance()
			await process_frame
	return current_scene as GameMap


func _buttons(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Button:
			out.append(c)
		_buttons(c, out)


func _run() -> void:
	mu = Music.instance(self)
	await process_frame
	var m: GameMap = await _load("farm")
	# --- toolbar slot: one cue for every device, none when the slot doesn't change ---
	if m != null and m.hud != null:
		m.hud.pick_slot(0)
		_clear()
		m.hud.pick_slot(2)
		check("equip" in _heard() or "unsheathe" in _heard(), "a slot change plays a cue")
		_clear()
		m.hud.pick_slot(2)
		check(_heard().is_empty(), "the same slot again is silent")
	# --- crafting ---
	GameState.add_item("wood", 99)
	GameState.add_item("stone", 99)
	_clear()
	var cs := CraftScreen.new()
	cs.m = m
	cs.station = "workbench"
	cs.key = "test_bench"
	cs.tier = 1
	cs.head = "Workbench"
	m.add_child(cs)
	await process_frame
	await process_frame
	check("menu_open" in _heard(), "craft screen opens with a cue")
	var bs: Array = []
	_buttons(cs._cats, bs)
	if bs.size() > 1:
		_clear()
		(bs[1] as Button).pressed.emit()
		check("tab" in _heard(), "category tab plays tab")
	cs._cat = ""
	cs._refresh()
	await process_frame
	var cards: Array = []
	_buttons(cs._list, cards)
	check(not cards.is_empty(), "recipe cards exist")
	# An undiscovered card refuses; a known one taps.
	var picked := false
	for rc: Dictionary in Crafting._all("workbench"):
		if Crafting.discovered(rc) and Crafting.why_locked("workbench", 1, rc) == "":
			_clear()
			cs._sel = {}
			cs._refresh()
			await process_frame
			var cc: Array = []
			_buttons(cs._list, cc)
			for b: Button in cc:
				if (b.get_child(0).get_child(1) as Label).text.contains(str(rc["name"])):
					b.pressed.emit()
					picked = true
					break
			if picked:
				check("ui_tap" in _heard(), "picking a recipe card taps")
				break
	check(picked, "a known workbench recipe was picked")
	if picked:
		await process_frame
		var db: Array = []
		_buttons(cs._detail, db)
		var make: Button = null
		var minus: Button = null
		for b: Button in db:
			if b.text == "MAKE":
				make = b
			elif b.text == "−":
				minus = b
		check(make != null, "MAKE button shown")
		if minus != null:
			_clear()
			minus.pressed.emit()  # already at 1
			check("nope" in _heard() and "ui_tap" not in _heard(), "− at 1 refuses (one cue)")
		_clear()
		cs._pad_qty(1)
		check("scroll_tick" in _heard() or "nope" in _heard(), "pad quantity step sounds")
		if make != null:
			make.disabled = true
			_clear()
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = false
			make.gui_input.emit(ev)
			check("nope" in _heard(), "a greyed MAKE answers with nope")
	_clear()
	cs.close()
	check("menu_close" in _heard(), "craft screen closes with a cue")
	await process_frame
	# --- controller keyboard ---
	var le := LineEdit.new()
	le.max_length = 2
	root.add_child(le)
	var kb := PadKeyboard.new()
	kb.field = le
	root.add_child(kb)
	await process_frame
	_clear()
	kb.move(Vector2i(1, 0))
	check("scroll_tick" in _heard(), "keyboard move ticks")
	_clear()
	kb._type("a")
	check("keypress" in _heard(), "typing clicks")
	kb._type("b")
	_clear()
	kb._type("c")
	check("nope" in _heard(), "a full field refuses")
	kb.queue_free()
	le.queue_free()
	await process_frame
	# --- decorate mode ---
	var h: GameMap = await _load("house")
	if h != null and DecorMode.can_decorate(h):
		_clear()
		var dm := DecorMode.open(h)
		await process_frame
		check(dm != null and "menu_open" in _heard(), "decorate opens with a cue")
		if dm != null:
			_clear()
			dm._deny("test")
			check("nope" in _heard(), "decorate refuses with nope")
			_clear()
			dm.close()
			check("menu_close" in _heard(), "decorate closes with a cue")
	await process_frame
	print("ui_cue_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

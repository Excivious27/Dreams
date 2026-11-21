extends SceneTree
## S1 P3 (Steam Deck readiness): controller typing, Deck glyphs and desktop
## display rules, headless:
##  - Deck button family (L1/R1/L2/R2), "Steam Deck" pad name, SteamService
##    input type override (a PS pad under Steam Input reads Cross);
##  - Deck trackpad clicks and keys typed into an open keyboard keep pad prompts;
##  - TextEntry: pad A on a focused LineEdit opens PadKeyboard (the screen below
##    never sees the press), keys type, B deletes then closes, MENU/Done writes
##    the text back; Steam's floating keyboard is used first when it accepts;
##  - ScreenCursor reaches a LineEdit and A on it opens typing;
##  - Deck text floor: deck_min_font 8 at 1280x800, DisplayMode.df, Control clamp,
##    off the Deck nothing changes;
##  - is_deck no longer guessed from a small screen; Alt+Enter releases "a";
##  - focus pause is its own setting (pause_unfocused), not bg_sound;
##  - dialogue Skip names the MENU button on a pad.
##   godot --headless --path . --fixed-fps 60 -s res://tools/deck_input_test.gd
var fails := 0


func _initialize() -> void:
	Campaign.bypass = true
	seed(31)
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("  FAIL ", what)


func _frames(n := 2) -> void:
	for i in n:
		await process_frame


func _btn(b: int, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = b as JoyButton
	e.pressed = down
	e.pressure = 1.0 if down else 0.0
	Input.parse_input_event(e)
	await _frames(1)


func _tap_btn(b: int) -> void:
	await _btn(b, true)
	await _btn(b, false)


func _run() -> void:
	InputSetup.ensure_actions()
	await _frames(3)
	# --- glyphs
	ok(InputSetup.pad_code_label(JOY_BUTTON_LEFT_SHOULDER, "deck") == "L1", "deck LB is L1")
	ok(InputSetup.pad_code_label(InputSetup.AXIS_BASE + JOY_AXIS_TRIGGER_RIGHT * 2 + 1, "deck") == "R2", "deck RT is R2")
	DisplayMode.deck_force = 1
	ok(PadInput.kind_of("Steam Deck") == "deck", "Steam Deck name -> deck")
	ok(PadInput.kind_of("Steam Virtual Gamepad") == "deck", "virtual pad on the Deck -> deck")
	DisplayMode.deck_force = 0
	ok(PadInput.kind_of("Steam Virtual Gamepad") == "xbox", "virtual pad off the Deck -> xbox")
	PadInput.steam_kind_force = "ps"
	ok(PadInput.kind_of("Steam Virtual Gamepad") == "ps", "Steam Input type wins (PS pad)")
	PadInput.steam_kind_force = ""
	# --- device switching on the Deck
	await _tap_btn(JOY_BUTTON_A)
	ok(PadInput.using_pad(), "pad active after A")
	DisplayMode.deck_force = 1
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.device = 0
	PadInput.note_event(mb)
	ok(PadInput.using_pad(), "Deck trackpad click keeps pad prompts")
	DisplayMode.deck_force = 0
	PadInput.note_event(mb)
	ok(not PadInput.using_pad(), "a real mouse click on a PC switches to keys")
	await _tap_btn(JOY_BUTTON_A)
	# --- TextEntry + PadKeyboard
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var box := VBoxContainer.new()
	box.size = Vector2(270, 200)
	layer.add_child(box)
	var le := LineEdit.new()
	le.text = "AB"
	le.custom_minimum_size = Vector2(120, 24)
	box.add_child(le)
	var other := Button.new()
	other.text = "Join"
	box.add_child(other)
	var pressed_below := [0]
	other.pressed.connect(func() -> void: pressed_below[0] += 1)
	await _frames(2)
	le.grab_focus()
	await _frames(1)
	TextEntry.steam_force = 0
	await _tap_btn(JOY_BUTTON_A)
	await _frames(2)
	ok(TextEntry.is_open(), "pad A on a focused LineEdit opens the keyboard")
	var kb: PadKeyboard = null
	for c in root.get_children():
		if c is PadKeyboard:
			kb = c
	ok(kb != null and kb.buf == "AB", "keyboard starts with the field's text")
	if kb:
		await _frames(3)
		kb.row = 1
		kb.col = 0
		await _tap_btn(JOY_BUTTON_A)  # Q
		ok(kb.buf == "ABQ", "A types the key under the cursor (got %s)" % kb.buf)
		await _btn(JOY_BUTTON_DPAD_RIGHT, true)
		await _btn(JOY_BUTTON_DPAD_RIGHT, false)
		ok(kb.col == 1, "d-pad right moves the key cursor")
		await _tap_btn(JOY_BUTTON_B)
		ok(kb.buf == "AB", "B deletes the last letter")
		kb.hit(4, 0)  # shift
		kb.hit(2, 0)  # a
		ok(kb.buf == "ABa", "shift types lower case")
		ok(pressed_below[0] == 0, "the screen below never saw the presses")
		kb.hit(4, 3)  # Done
		await _frames(2)
		ok(le.text == "ABa", "Done writes the text back (got %s)" % le.text)
		ok(not TextEntry.is_open(), "Done closes the keyboard")
	# B on empty text cancels
	le.text = ""
	ok(TextEntry.open(le) == "pad", "open() picks the built-in keyboard without Steam")
	await _frames(4)
	await _tap_btn(JOY_BUTTON_B)
	await _frames(2)
	ok(not TextEntry.is_open(), "B on empty text closes the keyboard")
	TextEntry.steam_force = 1
	ok(TextEntry.open(le) == "steam", "Steam's floating keyboard is tried first")
	ok(TextEntry.is_open() and le.has_focus(), "Steam keyboard: field focused and owning input")
	TextEntry.steam_dismissed()
	ok(not TextEntry.is_open(), "steam_dismissed closes it")
	TextEntry.steam_force = 0
	# keys typed while a keyboard is open keep pad prompts
	await _tap_btn(JOY_BUTTON_A)
	TextEntry.open(le)
	await _frames(3)
	var k := InputEventKey.new()
	k.keycode = KEY_X
	k.pressed = true
	PadInput.note_event(k)
	ok(PadInput.using_pad(), "keys typed into an open keyboard keep pad prompts")
	for c in root.get_children():
		if c is PadKeyboard:
			(c as PadKeyboard).finish(false)
	await _frames(2)
	# --- ScreenCursor reaches text fields
	var sc := ScreenCursor.make(layer, box)
	await _frames(2)
	ok(sc.items().has(le), "ScreenCursor lists the LineEdit")
	sc.cur = le
	sc.press()
	await _frames(2)
	ok(TextEntry.is_open(), "ScreenCursor A on a LineEdit opens typing")
	for c in root.get_children():
		if c is PadKeyboard:
			(c as PadKeyboard).finish(false)
	await _frames(2)
	# --- Deck text floor
	DisplayMode.deck_force = 0
	ok(DisplayMode.deck_min_font() == 0 and DisplayMode.df(7) == 7, "off the Deck sizes are unchanged")
	DisplayMode.deck_force = 1
	DisplayMode.test_size = Vector2i(1280, 800)
	ok(DisplayMode.deck_min_font() == 8, "Deck floor at 1280x800 is size 8 (got %d)" % DisplayMode.deck_min_font())
	ok(DisplayMode.df(5) == 8 and DisplayMode.df(10) == 10, "df raises small drawn text only")
	ok(float(DisplayMode.df(7)) * (800.0 / 480.0) * DisplayMode.CAP_RATIO >= 9.0, "df(7) meets 9 px cap at 1280x800")
	ok(Settings.font(6) >= 8, "Settings.font honours the Deck floor")
	var lab := Label.new()
	lab.text = "tiny"
	lab.add_theme_font_size_override("font_size", 6)
	layer.add_child(lab)
	await _frames(2)
	ok(lab.get_theme_font_size("font_size") == 8, "a size-6 Label is clamped to 8 on the Deck")
	DisplayMode.deck_force = 0
	DisplayMode.test_size = Vector2i.ZERO
	var lab2 := Label.new()
	lab2.add_theme_font_size_override("font_size", 6)
	layer.add_child(lab2)
	await _frames(2)
	ok(lab2.get_theme_font_size("font_size") == 6, "off the Deck Labels keep their size")
	# --- desktop display rules
	DisplayMode.deck_force = -1
	ok(not DisplayMode.is_deck(), "no Deck guess in a plain headless run")
	ok(bool(Settings.get_v("pause_unfocused")), "pause when inactive defaults on")
	Settings.set_v("bg_sound", true)
	ok(DisplayMode.focus_pauses(), "background sound no longer turns the focus pause off")
	Settings.set_v("bg_sound", false)
	Settings.set_v("pause_unfocused", false)
	ok(not DisplayMode.focus_pauses(), "pause when inactive can be turned off")
	Settings.set_v("pause_unfocused", true)
	var ae := InputEventKey.new()
	ae.keycode = KEY_ENTER
	ae.physical_keycode = KEY_ENTER
	ae.alt_pressed = true
	ae.pressed = true
	Input.parse_input_event(ae)
	DisplayMode.release_actions_for(ae)
	ok(not Input.is_action_just_pressed("a") and not Input.is_action_pressed("a"), "Alt+Enter does not press A")
	var ar := ae.duplicate() as InputEventKey
	ar.pressed = false
	Input.parse_input_event(ar)
	await _frames(1)
	ok(DisplayMode.MIN_WIN.x >= 540 and DisplayMode.MIN_WIN.y >= 480, "minimum window keeps the 270 column at 1x")
	ok(not Settings.fullscreen_key_hint() or PadInput.device_kind() == "keys", "F11 hint only for keyboard players")
	await _tap_btn(JOY_BUTTON_A)
	ok(not Settings.fullscreen_key_hint(), "no F11 hint while a pad is used")
	# --- pad words (s1_08-06)
	ok(PadInput.device_kind() == "pad", "pad is the device for the word checks")
	var w := PadInput.words("Tap a slot to see what fits it.")
	ok(not w.contains("Tap") and w.begins_with("Pick a slot"), "menu 'Tap a' reads 'Pick a' on a pad (%s)" % w)
	w = PadInput.words("Tap the arrows (or arrow keys) · B to unplug")
	ok(not w.to_lower().contains("arrow") and w.contains("D-pad"), "no arrow keys on a pad (%s)" % w)
	w = PadInput.words("Hold BOP, then RALLY")
	ok(not w.contains("BOP") and not w.contains("RALLY"), "BOP/RALLY become pad buttons (%s)" % w)
	# --- pad-friendly backups (s1_08-07)
	SaveTransfer.pad_files_force = 1
	var res := [false, ""]
	SaveTransfer.save_file(layer, "DREAMS-TEST-CODE", func(okk: bool, where: String) -> void:
		res[0] = okk
		res[1] = where)
	ok(bool(res[0]) and str(res[1]).begins_with("backups/"), "pad save writes into user://backups (%s)" % str(res[1]))
	ok(BackupPicker.list_files().size() >= 1, "the backup is listed")
	var got := ["unset"]
	SaveTransfer.open_file(layer, func(t: String) -> void: got[0] = t)
	await _frames(4)
	var picker: BackupPicker = null
	for c in root.get_children():
		if c is BackupPicker:
			picker = c
	ok(picker != null, "pad open shows the in-game backup list, no OS dialog")
	await _tap_btn(JOY_BUTTON_A)
	await _frames(2)
	ok(got[0] == "DREAMS-TEST-CODE", "A loads the newest backup (got %s)" % got[0])
	SaveTransfer.open_file(layer, func(t: String) -> void: got[0] = t)
	await _frames(4)
	await _tap_btn(JOY_BUTTON_B)
	await _frames(2)
	ok(got[0] == "", "B cancels with an empty text")
	SaveTransfer.pad_files_force = -1
	print("deck_input_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

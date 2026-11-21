extends SceneTree
## Controller core (C9 P1), with synthetic InputEventJoypad* events:
##  - every PAD_DEFAULTS binding presses its action and releases it;
##  - stick deadzone / analog walk curve (PadInput.shape) and full-tilt run;
##  - PadInput device switching: a pad hides the touch pad (auto), a touch
##    brings it back, Options always/never stick (TouchControls.mode);
##  - held d-pad auto-repeat (PadInput.nav_pressed) on game time;
##  - pad and key rebinding never leave an action without a button;
##  - prompts per device (touch USE, pad A / Cross), PadInput.words;
##  - LB/RB toolbar both ways, skipping empty slots on a pad;
##  - HackGame stick latch direction, toast reading time, goal-line wrap;
##  - TouchControls wide-view placement and pup strip button size;
##  - PadFocus: focus enters the first button, d-pad moves it, pad A presses;
##  - PadCursor: the virtual pointer clicks a FOCUS_NONE button once.
##   godot --headless --path . --fixed-fps 60 -s res://tools/pad_test.gd
var fails := 0


func _initialize() -> void:
	Campaign.bypass = true
	seed(9)
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
	await _frames()


func _axis(a: int, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = a as JoyAxis
	e.axis_value = v
	Input.parse_input_event(e)
	await _frames()


func _touch(down: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = Vector2(40, 40)
	t.pressed = down
	Input.parse_input_event(t)
	await _frames()


func _key(k: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = down
	Input.parse_input_event(e)
	await _frames()


func _run() -> void:
	SaveGame.set_value("keys", {})
	SaveGame.set_value("pads", {})
	InputSetup.ensure_actions()
	var tc := TouchControls.new()
	root.add_child(tc)
	await _frames(3)
	ok(PadInput.instance() != null, "PadInput installed by ensure_actions")
	ok(PadCursor.instance() != null, "PadCursor installed")

	# 1. Every pad binding presses its action.
	for action: String in InputSetup.PAD_DEFAULTS:
		for code in InputSetup.PAD_DEFAULTS[action]:
			var c := int(code)
			if c >= InputSetup.AXIS_BASE:
				var ax := (c - InputSetup.AXIS_BASE) / 2
				var v := 1.0 if (c - InputSetup.AXIS_BASE) % 2 == 1 else -1.0
				await _axis(ax, v)
				ok(Input.is_action_pressed(action), "axis %d %+.0f presses %s" % [ax, v, action])
				await _axis(ax, 0.0)
			else:
				await _btn(c, true)
				ok(Input.is_action_pressed(action), "button %d presses %s" % [c, action])
				await _btn(c, false)
			ok(not Input.is_action_pressed(action), "%s released" % action)
	ok(InputMap.event_is_action(InputSetup.pad_event(JOY_BUTTON_A), "ui_accept"), "pad A is ui_accept")
	ok(InputMap.event_is_action(InputSetup.pad_event(JOY_BUTTON_B), "ui_cancel"), "pad B is ui_cancel")

	# 2. Device switching + touch pad hide/return (Options auto).
	Settings.set_v("touch_ui", 0)
	TouchControls.visible_controls = true
	await _btn(JOY_BUTTON_A, true)
	await _btn(JOY_BUTTON_A, false)
	ok(PadInput.using_pad(), "pad press -> using pad")
	ok(not TouchControls.visible_controls, "pad hides the touch pad (auto)")
	ok(PadInput.device_kind() == "pad", "device kind pad")
	await _touch(true)
	await _touch(false)
	ok(not PadInput.using_pad(), "touch -> not pad")
	ok(TouchControls.visible_controls, "touch brings the touch pad back")
	# Options never / always stick.
	Settings.set_v("touch_ui", 2)
	TouchControls.visible_controls = false
	await _touch(true)
	await _touch(false)
	ok(not TouchControls.visible_controls, "touch_ui never: a touch keeps it hidden")
	Settings.set_v("touch_ui", 1)
	TouchControls.visible_controls = true
	await _key(KEY_K, true)
	await _key(KEY_K, false)
	ok(TouchControls.visible_controls, "touch_ui always: a key keeps it shown")
	await _btn(JOY_BUTTON_A, true)
	await _btn(JOY_BUTTON_A, false)
	ok(TouchControls.visible_controls, "touch_ui always: a pad keeps it shown")
	Settings.set_v("touch_ui", 0)

	# 3. Analog walk: deadzone, curve, full-tilt run.
	await _btn(JOY_BUTTON_A, true)
	await _btn(JOY_BUTTON_A, false)
	ok(PadInput.using_pad(), "pad active for the stick checks")
	await _axis(JOY_AXIS_LEFT_X, 0.15)
	var v := PadInput.shape(Input.get_vector("left", "right", "up", "down"))
	ok(v == Vector2.ZERO, "0.15 tilt: no move (got %s)" % v)
	await _axis(JOY_AXIS_LEFT_X, 0.6)
	var raw := Input.get_vector("left", "right", "up", "down")
	v = PadInput.shape(raw)
	ok(v.length() >= PadInput.WALK_MIN and v.length() < 1.0, "0.6 tilt walks between WALK_MIN and full (%.2f)" % v.length())
	ok(not PadInput.wants_run(raw), "0.6 tilt doesn't run")
	await _axis(JOY_AXIS_LEFT_X, 1.0)
	raw = Input.get_vector("left", "right", "up", "down")
	ok(PadInput.shape(raw).length() > 0.99 and PadInput.wants_run(raw), "full tilt: full speed and runs")
	await _axis(JOY_AXIS_LEFT_X, 0.0)
	ok(PadInput.shape(Vector2(0.1, 0)) == Vector2.ZERO, "shape: tiny vector -> zero")

	# 4. Held d-pad auto-repeat on game time.
	var hits := 0
	await _btn(JOY_BUTTON_DPAD_DOWN, true)
	var gt := 0.0
	var first := true
	while gt < 0.7:
		if first or PadInput.nav_pressed("down"):
			hits += 1
		first = false
		await process_frame
		gt += root.get_process_delta_time()
	await _btn(JOY_BUTTON_DPAD_DOWN, false)
	ok(hits >= 3 and hits <= 8, "held down repeats a few times in 0.7 s (got %d)" % hits)

	# 5. Rebinding never strands an action.
	var moved := InputSetup.rebind_pad("tool", JOY_BUTTON_Y)
	ok(moved == "action", "pad Y moved from action (%s)" % moved)
	ok(int(InputSetup.pads()["action"][0]) == JOY_BUTTON_X, "action got the tool's old X")
	ok(InputSetup.rebind_pad("tool", JOY_BUTTON_DPAD_UP) == "fixed", "d-pad can't be taken from movement")
	ok(InputSetup.rebind_pad("up", JOY_BUTTON_A) == "fixed", "movement can't be rebound")
	InputSetup.reset_pad()
	ok(int(InputSetup.pads()["tool"][0]) == JOY_BUTTON_X, "reset_pad restores X")
	var km := InputSetup.rebind("tool", KEY_X)
	ok(km == "action" and int(InputSetup.keys()["action"][0]) == KEY_C, "key X taken from Action gives it C (%s)" % km)
	InputSetup.reset_bindings()
	ok(int(InputSetup.keys()["action"][0]) == KEY_X, "reset_bindings")
	var shown: Array = []
	for row: Array in InputSetup.SHOWN:
		shown.append(str(row[0]))
	ok("dodge" in shown and "cycle_back" in shown, "Dodge and Toolbar Back on the bindings page")

	# 6. Prompts per device.
	await _btn(JOY_BUTTON_A, true)
	await _btn(JOY_BUTTON_A, false)
	PadInput.kind = "xbox"
	ok(InputSetup.prompt("a") == "A", "xbox a -> A (%s)" % InputSetup.prompt("a"))
	ok(InputSetup.prompt("dodge") == "LT", "xbox dodge -> LT")
	PadInput.kind = "ps"
	ok(InputSetup.prompt("a") == "Cross", "ps a -> Cross")
	PadInput.kind = "switch"
	ok(InputSetup.prompt("a") == "B", "switch bottom button -> B")
	PadInput.kind = "xbox"
	ok(PadInput.words("Sword: tap USE to swing at foes.") == "Sword: press A to swing at foes.", "words on a pad: %s" % PadInput.words("Sword: tap USE to swing at foes."))
	ok(PadInput.words("!!!  Tap USE!") == "!!!  Press A!", "fishing bite words on a pad")
	ok(PadInput.words("Swing your pickaxe at rocks (tap USE): stone") == "Swing your pickaxe at rocks (press A): stone", "words in brackets")
	ok(PadInput.kind_of("Sony DualSense Wireless Controller") == "ps" and PadInput.kind_of("Xbox Series Controller") == "xbox" and PadInput.kind_of("Nintendo Switch Pro Controller") == "switch", "kind_of")
	await _touch(true)
	await _touch(false)
	ok(InputSetup.prompt("a") == "USE" and PadInput.words("tap USE") == "tap USE", "touch prompts stay USE")

	# 7. LB/RB toolbar, skipping empty slots on a pad.
	var keep_run := GameState.run
	GameState.run = {"slot": 0, "toolbar": ["hoe", "", "", "axe", "", "", "", "", "", "", "", "can"]}
	ok(Hud.next_slot(1) == 1 and Hud.next_slot(-1) == 11, "touch/keys: plain steps")
	await _btn(JOY_BUTTON_A, true)
	await _btn(JOY_BUTTON_A, false)
	ok(Hud.next_slot(1) == 3, "pad RB skips empty slots (%d)" % Hud.next_slot(1))
	ok(Hud.next_slot(-1) == 11, "pad LB goes back")
	GameState.run = keep_run

	# 8. Small pieces.
	ok(HackGame.pad_dir(Vector2(0.7, 0.6)) == "right" and HackGame.pad_dir(Vector2(0.2, -0.9)) == "up" and HackGame.pad_dir(Vector2(0.2, 0.2)) == "", "hack pad_dir")
	ok(Hud.toast_hold("+1 Wood") <= 4.0, "pickup toasts stay short")
	var long := "The ferryman shakes his head and points at the far shore, where the lanterns are already lit for the evening crossing, and says you must wait."
	ok(Hud.toast_hold(long) >= 6.9, "long toast held ~7 s (%.1f)" % Hud.toast_hold(long))
	var f := ThemeDB.fallback_font
	var gl := Hud.wrap_goal(f, "Go to the crystal meadow and talk to Catkins by the cat statue near the old pond", 228.0, 7)
	ok(gl.size() <= Hud.GOAL_LINES and str(gl[gl.size() - 1]).ends_with("pond"), "goal wraps without cutting the end: %s" % str(gl))
	var keep_view := DisplayMode.view
	DisplayMode.view = Vector2(768, 480)
	var bp := TouchControls.button_place(TouchControls.BUTTONS["a"])
	ok(absf((bp[0] as Vector2).x - (232.0 + 498.0)) < 0.5, "wide view: USE at the right edge (%s)" % str(bp[0]))
	var sp := TouchControls.button_place({"pos": Vector2(58, 412), "r": 10.0})
	ok(absf((sp[0] as Vector2).x - 58.0) < 0.5, "wide view: left pieces stay left")
	DisplayMode.view = keep_view
	Settings.set_v("btn_size", 2)
	ok(TouchControls.pup_r() > TouchControls.PUP_R and TouchControls.stick_r() > TouchControls.STICK_R, "large buttons reach the pup strip and stick")
	ok(TouchControls.pup_step() >= TouchControls.pup_r() * 2.0, "pup strip buttons don't overlap at large")
	Settings.set_v("btn_size", 1)

	# 9. PadFocus over FOCUS_NONE buttons.
	await _btn(JOY_BUTTON_A, true)
	await _btn(JOY_BUTTON_A, false)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(60, 100)
	layer.add_child(box)
	var presses := [0, 0, 0]
	for i in 3:
		var b := Button.new()
		b.text = "Row %d" % i
		b.custom_minimum_size = Vector2(120, 24)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void: presses[i] += 1)
		box.add_child(b)
	await _frames()
	PadFocus.enter(box)
	await _frames()
	var b0 := box.get_child(0) as Button
	var b1 := box.get_child(1) as Button
	ok(b0.has_focus(), "PadFocus focuses the first button")
	await _btn(JOY_BUTTON_DPAD_DOWN, true)
	await _btn(JOY_BUTTON_DPAD_DOWN, false)
	ok(b1.has_focus(), "d-pad down moves focus to the second")
	await _btn(JOY_BUTTON_A, true)
	await _btn(JOY_BUTTON_A, false)
	ok(presses[1] == 1 and presses[0] == 0, "pad A presses the focused button once (%s)" % str(presses))
	PadFocus.refresh(box)
	ok(b1.has_focus(), "refresh keeps the place")
	PadFocus.leave(box)
	ok(b0.focus_mode == Control.FOCUS_NONE and not b1.has_focus(), "leave restores FOCUS_NONE")

	# 10. PadCursor clicks a FOCUS_NONE button (screen opted in by group).
	presses.fill(0)  # the lambdas hold this array: reset it in place
	box.add_to_group(PadCursor.GROUP)
	await _frames(3)
	ok(PadCursor.shown(), "cursor shows on a pad over an opted-in screen")
	PadCursor.pos = box.get_child(2).get_global_rect().get_center()
	await _btn(JOY_BUTTON_A, true)
	await _btn(JOY_BUTTON_A, false)
	await _frames()
	ok(presses[2] == 1 and presses[0] + presses[1] == 0, "cursor A clicks the button under it once (%s)" % str(presses))
	ok(not PadCursor.sending, "sending flag cleared")
	box.remove_from_group(PadCursor.GROUP)
	await _frames(2)
	ok(not PadCursor.shown(), "cursor hides when the screen leaves the group")
	layer.queue_free()

	# 10b. Look creator row cursor: right steps the first row's choice, down to
	# the bottom row and A presses Done.
	await _btn(JOY_BUTTON_A, true)
	await _btn(JOY_BUTTON_A, false)
	var cl := CanvasLayer.new()
	root.add_child(cl)
	var cr := Creator.new({}, "", true)
	cl.add_child(cr)
	var got := []
	cr.done.connect(func(lk: Dictionary) -> void: got.append(lk))
	await _frames(10)
	if cr._rows_cb.size() > 0:
		var key0: Dictionary = cr.look.duplicate()
		await _btn(JOY_BUTTON_DPAD_RIGHT, true)
		await _btn(JOY_BUTTON_DPAD_RIGHT, false)
		await _frames(2)
		ok(cr.look != key0, "creator: right changes the first row's choice")
		for i in cr._rows_cb.size():
			await _btn(JOY_BUTTON_DPAD_DOWN, true)
			await _btn(JOY_BUTTON_DPAD_DOWN, false)
		ok(cr._row == cr._rows_cb.size() and cr._col == 1, "creator: down reaches the bottom row on Done")
		await _btn(JOY_BUTTON_A, true)
		await _btn(JOY_BUTTON_A, false)
		ok(got.size() == 1, "creator: A presses Done once (%d)" % got.size())
	else:
		print("  (creator has no picker rows here: body sheets missing)")
	cl.queue_free()

	# 11. Battle rally on the pad (L3): a tap or a hold opens the list (C16b P1);
	# a penguin-only speaker narrates a gangster run's field brief.
	GameState.new_run("gangsters", "mom", "T", "Town", "Pup")
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/bf_bog_crossing.tscn")
	await _frames(14)
	var m := current_scene as GameMap
	var bt: Variant = m.get("battle") if m != null else null
	ok(bt != null, "bf_bog_crossing starts a battle")
	if bt != null:
		var b: Battle = bt
		ok(b._who() == "", "gangster run: no Catkins on the field brief (%s)" % b._who())
		for c in get_nodes_in_group("toast_hold"):
			if c.has_method("_close"):
				c.set("_arm", 99)
				c.call("_close")
		await _frames(4)
		var d0 := Dialogue.instance(self)
		for i in 60:
			if not d0.active:
				break
			d0._advance()
			await _frames(1)
		b._briefing = false
		await _frames(2)
		Dialogue.block_until_ms = 0  # the after-dialogue block is wall-clock: clear it (game time only here)
		var r0 := b._rally
		await _btn(JOY_BUTTON_LEFT_STICK, true)
		await _btn(JOY_BUTTON_LEFT_STICK, false)
		await _frames(2)
		# C16b P1 (c16b_06-06): a tap opens the same orders list as touch (no silent cycling).
		ok(Dialogue.instance(self).active and b._rally == r0, "tap L3 opens the orders list (rally %d -> %d)" % [r0, b._rally])
		ok(b.count_hint().contains("L3"), "the count line names L3 off touch: %s" % b.count_hint())
		var dl1 := Dialogue.instance(self)
		for i in 30:
			if not dl1.active:
				break
			if dl1._in_choice:
				dl1._choose("", dl1._choices.get_child_count() - 1)
			else:
				dl1._advance()
			await _frames(1)
		await _frames(2)
		Dialogue.block_until_ms = 0
		await _btn(JOY_BUTTON_LEFT_STICK, true)
		var ht := 0.0
		while ht < Battle.RALLY_HOLD + 0.2:
			await process_frame
			ht += root.get_process_delta_time()
		await _btn(JOY_BUTTON_LEFT_STICK, false)
		await _frames(4)
		ok(Dialogue.instance(self).active, "hold L3 opens the rally list")

	print("pad_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

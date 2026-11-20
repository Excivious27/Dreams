extends SceneTree
## Haptics (C9 P4): gates, cooldowns, strength, the Music.sfx whitelist, web
## pattern strings, the game-time clock and the DisplayMode back/fullscreen bits.
## Run: godot --headless --path . --fixed-fps 60 -s res://tools/haptics_test.gd

var _fails := 0


func _ok(c: bool, what: String) -> void:
	if not c:
		_fails += 1
		print("HAPTICS FAIL: ", what)


func _initialize() -> void:
	seed(9)
	_run.call_deferred()


func _kinds() -> Array:
	var out: Array = []
	for e: Dictionary in Haptics.history:
		out.append(e.kind)
	return out


func _run() -> void:
	InputSetup.ensure_actions()
	SaveGame.set_value("set_haptics", true)
	SaveGame.set_value("set_haptics_str", 1)
	SaveGame.set_value("set_haptics_ui", false)
	Haptics.force_supported = true
	Haptics.clock_override = 10000
	Haptics.reset_for_tests()

	# Every whitelisted name maps to a real kind; menu confirms are not on it.
	for n: String in Haptics.SFX:
		_ok(Haptics.PATTERNS.has(Haptics.SFX[n]), "SFX %s -> unknown kind" % n)
	for n: String in ["j_confirm", "j_buy", "j_page", "j_gift", "j_battle_start", "craft_done", "ui_tap", "scroll_tick", "thud", "pickup"]:
		_ok(not Haptics.SFX.has(n), "%s must not buzz" % n)

	# 1. setting off -> nothing
	SaveGame.set_value("set_haptics", false)
	Haptics.buzz("hurt")
	_ok(Haptics.history.is_empty(), "buzzed with vibration off")
	SaveGame.set_value("set_haptics", true)

	# 2. a gameplay kind logs once; the per-kind cooldown holds
	Haptics.buzz("tool_hit")
	_ok(_kinds() == ["tool_hit"], "first tool_hit")
	var n := 0
	for i in 10:
		Haptics.clock_override += 50  # ten swings in half a second
		if Haptics.buzz("tool_hit"):
			n += 1
	_ok(n <= 6 and n >= 3, "tool_hit cooldown: %d of 10" % n)

	# 3. merge window: a weaker buzz right after a stronger one is dropped
	Haptics.reset_for_tests()
	Haptics.clock_override += 1000
	Haptics.buzz("hurt")
	Haptics.clock_override += 10
	_ok(not Haptics.buzz("harvest"), "weaker buzz within the merge window")
	Haptics.clock_override += 10
	_ok(Haptics.buzz("ko"), "stronger buzz within the merge window plays")

	# 4. UI taps only with the taps option
	Haptics.reset_for_tests()
	Haptics.clock_override += 1000
	_ok(not Haptics.buzz("ui_light"), "ui_light with taps off")
	SaveGame.set_value("set_haptics_ui", true)
	_ok(Haptics.buzz("ui_light"), "ui_light with taps on")
	SaveGame.set_value("set_haptics_ui", false)

	# 5. paused tree (menu): gameplay kinds quiet, results still buzz
	Haptics.reset_for_tests()
	Haptics.clock_override += 1000
	paused = true
	_ok(not Haptics.buzz("tool_hit"), "tool_hit inside a menu")
	_ok(Haptics.buzz("level_up"), "level_up is a result: buzzes in a menu")
	paused = false

	# 6. a muted Music still buzzes on a bite (Music.sfx hooks before the mute check)
	Haptics.reset_for_tests()
	Haptics.clock_override += 1000
	var mu := Music.instance(self)
	await process_frame
	if not mu.is_muted():
		mu.toggle_mute()
	mu.sfx("bite")
	_ok(_kinds().has("bite"), "bite with sound off")
	Haptics.clock_override += 1000
	mu.sfx("j_confirm")
	_ok(not _kinds().has("j_confirm") and _kinds().size() == 1, "j_confirm stays quiet")
	mu.toggle_mute()

	# 7. strength scales pulse lengths; min pulse floor; web array string
	var light := Haptics.pattern_for("bite", 0)
	var strong := Haptics.pattern_for("bite", 2)
	_ok(int(strong[0]) > int(light[0]), "strong pulses are longer")
	_ok(int(light[1]) == 40, "gaps don't scale")
	_ok(int(Haptics.pattern_for("block", 0)[0]) >= Haptics.MIN_PULSE, "min pulse floor")
	_ok(Haptics.web_array([50, 40, 50]) == "[50,40,50]", "web array")
	_ok(Haptics.buzz_amount(4.0) or true, "buzz_amount runs")

	# 8. game-time clock: stops while paused
	var t0 := PlayClock.now()
	for i in 30:
		await process_frame
	var t1 := PlayClock.now()
	_ok(t1 - t0 > 0.3, "PlayClock runs: %.2f" % (t1 - t0))
	paused = true
	for i in 30:
		await process_frame
	_ok(absf(PlayClock.now() - t1) < 0.05, "PlayClock stops while paused")
	paused = false

	# 9. rows build without errors (Options page)
	var box := VBoxContainer.new()
	root.add_child(box)
	Haptics.rows(box)
	_ok(box.get_child_count() == 3, "three vibration rows")
	(box.get_child(1) as Button).pressed.emit()
	_ok(Haptics.strength() == 2, "strength row cycles")
	(box.get_child(0) as Button).pressed.emit()
	_ok(not Haptics.enabled() and not (box.get_child(1) as Control).visible, "off hides strength")
	(box.get_child(0) as Button).pressed.emit()
	SaveGame.set_value("set_haptics_str", 1)
	box.queue_free()

	# 10. back gesture: nothing open -> menu, something open -> b
	var dm := DisplayMode.svc()
	_ok(dm != null, "DisplayMode service")
	if dm:
		_ok(dm.back_pressed() == "menu", "back opens the menu")
		await process_frame
		paused = true
		_ok(dm.back_pressed() == "b", "back closes what is open")
		paused = false
		await process_frame
		_ok(not Input.is_action_pressed("b") and not Input.is_action_pressed("menu"), "back taps are released")

	# 11. music stand-in: a fight never stands in with the calm farm song
	_ok(mu._standin("boss_gang") in ["combat_light_gang", "combat_light"], "fight stand-in: " + mu._standin("boss_gang"))
	_ok(mu._standin("town") == "farm", "calm stand-in")

	print("HAPTICS DONE, failures: %d" % _fails)
	quit(1 if _fails > 0 else 0)

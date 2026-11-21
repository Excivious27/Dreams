extends SceneTree
## C15 P1: the calendar screen (scripts/calendar_screen.gd), both arcs.
##   godot --headless --fixed-fps 60 --path . -s res://tools/calendar_screen_test.gd [-- /tmp/shots]
## - opens over a running town, pauses the tree, 28 day cells + Prev/Next/Close (Close last)
## - today's cell is selected; cells of festival days carry a mark; tapping a day lists it
## - paging moves the season (and never before year 1 spring); B closes and unpauses
## - every button >= 20 px tall; with a shots dir, saves calendar_<arc>.png (needs a display)
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	seed(15)
	Campaign.bypass = true
	InputSetup.ensure_actions()
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		PlayClock.advance(1.0 / 60.0)
		await process_frame


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shots := str(args[0]) if args.size() > 0 else ""
	for ar in ["penguins", "gangsters"]:
		GameState.new_run(ar, "penguin_m" if ar == "penguins" else "pax", "Test", "Testville", "Pup")
		GameState.run["day"] = 12  # spring 12: the festival (14) is two days off
		GameState.run["friendship"]["maple"] = 10
		Calendar.reload()
		var cs := CalendarScreen.open(self)
		await _frames(12)
		check(paused, "%s: calendar pauses the tree" % ar)
		check(cs.view_season() == "spring" and cs.view_year() == 1 and cs.sel == 12, "%s: opens on today (%s y%d sel %d)" % [ar, cs.view_season(), cs.view_year(), cs.sel])
		var btns: Array = cs.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return not b.is_queued_for_deletion())
		var days := btns.filter(func(b: Button) -> bool: return b.name.begins_with("day_"))
		check(days.size() == 28, "%s: 28 day cells (%d)" % [ar, days.size()])
		check(btns.size() == 31 and (btns[-1] as Button).text == "Close", "%s: Close is the last button" % ar)
		for b: Button in btns:
			check(b.size.y >= 20.0, "%s: button %s >= 20 px tall" % [ar, b.name])
		var fest := Calendar.festival_on("spring", 14, 1, ar)
		check(not fest.is_empty() and cs.marks(14).size() >= 1, "%s: spring 14 shows its festival" % ar)
		check(cs.marks(15).any(func(e: Dictionary) -> bool: return str(e["id"]) == "bday_maple"), "%s: maple's birthday on spring 15" % ar)
		cs._pick(14)
		await _frames(2)
		var labels: Array = cs.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
		check(labels.any(func(t: String) -> bool: return t.begins_with(str(fest.get("name", "?")))), "%s: tapping spring 14 lists %s" % [ar, fest.get("name", "")])
		if shots != "":
			cs._pick(12)
			await _frames(3)
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png(shots.path_join("calendar_%s.png" % ar))
		cs._page(1)
		check(cs.view_season() == "summer", "%s: Next pages to summer" % ar)
		cs._page(-1)
		cs._page(-1)
		check(cs.view_season() == "spring" and cs.view_year() == 1, "%s: never before year 1 spring" % ar)
		cs._close()
		await _frames(4)
		check(not paused, "%s: closing unpauses" % ar)
		check(get_nodes_in_group("calendar_screen").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).is_empty(), "%s: screen gone" % ar)
	print("calendar_screen_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

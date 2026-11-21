extends SceneTree
## S1 P4 (09-07): on a 1280x800 screen with no window manager, the Deck startup
## path must end with the window covering the screen, not a 540x960 portrait
## window. Needs a display: xvfb-run -a -s "-screen 0 1280x800x24" godot ...
## with SteamDeck=1 in the environment.
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("deck_window_test: skipped (headless), 0 failures")
		quit(0)
		return
	var dm := root.get_node("DisplayModeSvc") as DisplayMode
	var w := root.get_window()
	var scr := DisplayServer.screen_get_size(w.current_screen)
	check(DisplayMode.is_deck(), "SteamDeck=1 -> is_deck")
	dm._desktop_window(true)
	for i in 20:
		await process_frame
	check(w.mode == Window.MODE_FULLSCREEN or w.borderless, "fullscreen (or borderless full-screen when the WM ignores it)")
	check(w.size == scr, "window covers the screen %s (got %s)" % [scr, w.size])
	for i in 5:
		await process_frame
	check(DisplayMode.view.x > DisplayMode.view.y, "wide view at 1280x800 (%s)" % DisplayMode.view)
	print("deck_window_test: %d failures" % fails)
	quit(1 if fails else 0)

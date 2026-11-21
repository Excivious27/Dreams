extends SceneTree
## S1 P1: Steam absent = safe no-ops (the web/CI/phone path), the app-id gate
## (480 only for debug/test), and backend routing through a fake GodotSteam
## object. Run: godot --headless --path . --fixed-fps 60 -s res://tools/steam_service_test.gd

var _fails := 0


class FakeGodotSteam extends Object:
	signal overlay_toggled(active: bool, user_initiated: bool, app_id: int)
	signal gamepad_text_input_dismissed(submitted: bool, entered_text: String, app_id: int)
	var calls: Array = []
	var ach := {}
	func steamInitEx(app_id: int, _embed: bool) -> Dictionary:
		calls.append(["steamInitEx", app_id])
		return {"status": 0, "verbal": "ok"}
	func run_callbacks() -> void:
		calls.append(["run_callbacks"])
	func setAchievement(n: String) -> bool:
		ach[n] = true; calls.append(["setAchievement", n]); return true
	func getAchievement(n: String) -> Dictionary:
		return {"ret": true, "achieved": ach.get(n, false)}
	func storeStats() -> bool:
		calls.append(["storeStats"]); return true
	func setStatInt(n: String, v: int) -> bool:
		calls.append(["setStatInt", n, v]); return true
	func getStatInt(_n: String) -> int:
		return 7
	func setRichPresence(k: String, v: String) -> bool:
		calls.append(["setRichPresence", k, v]); return true
	func getPersonaName() -> String:
		return "Tester"
	func isSteamRunningOnSteamDeck() -> bool:
		return true
	signal join_requested(lobby_id: int, steam_id: int)
	func isOverlayEnabled() -> bool:
		return true
	func getControllerForGamepadIndex(i: int) -> int:
		return 77 if i == 0 else 0
	func getInputTypeForHandle(_h: int) -> int:
		return 14
	func getFriendPersonaName(_id: int) -> String:
		return "Pal"
	func showFloatingGamepadTextInput(m: int, _x: int, _y: int, _w: int, _h: int) -> bool:
		calls.append(["showFloatingGamepadTextInput", m]); return true
	func showGamepadTextInput(_m: int, _l: int, d: String, mx: int, p: String) -> bool:
		calls.append(["showGamepadTextInput", d, mx, p]); return true


func _initialize() -> void:
	seed(1)
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		print("FAIL: ", msg)


func _run() -> void:
	# Pure gates.
	_check(not SteamService.available_on("Web", true), "web never runs Steam")
	_check(not SteamService.available_on("Android", true), "phones never run Steam")
	_check(not SteamService.available_on("macOS", false), "no mac build")
	_check(SteamService.available_on("Windows", false) and SteamService.available_on("Linux", false), "desktop may run Steam")
	_check(SteamService.pick_app_id(0, false, false) == 0, "release build without App ID stays local")
	_check(SteamService.pick_app_id(0, true, false) == 480, "debug build uses test app 480")
	_check(SteamService.pick_app_id(0, false, true) == 480, "test flag uses 480")
	_check(SteamService.pick_app_id(123456, true, true) == 123456, "a real App ID always wins")

	# Absent: the autoload (or a fresh one) is local and every call a no-op.
	var svc: SteamService = root.get_node_or_null("SteamSvc")
	if svc == null:
		svc = SteamService.new()
		svc.name = "SteamSvc"
		root.add_child(svc)
	await process_frame
	_check(svc.backend() == "local", "headless run is local, got " + svc.backend())
	_check(svc.reason != "", "absent reason recorded")
	_check(not SteamApi.active(), "SteamApi inactive")
	_check(SteamApi.backend() == "local", "facade backend local")
	_check(not SteamApi.unlock_achievement("first_harvest"), "unlock no-op")
	_check(not SteamApi.is_achievement_unlocked("first_harvest"), "unlocked false")
	_check(not SteamApi.indicate_progress("a", 1, 2), "progress no-op")
	_check(not SteamApi.set_stat("crops", 3) and SteamApi.get_stat("crops") == 0, "stats no-op")
	_check(not SteamApi.store_stats(), "store no-op")
	_check(not SteamApi.set_rich_presence("steam_display", "#Farming"), "presence no-op")
	_check(not SteamApi.clear_rich_presence(), "clear presence no-op")
	_check(SteamApi.persona_name() == "" and not SteamApi.is_on_deck(), "user no-op")
	_check(not SteamApi.show_floating_text_input(0, Rect2i(0, 0, 10, 10)), "floating kb no-op")
	_check(not SteamApi.show_gamepad_text_input("Name", "", 16), "gamepad kb no-op")
	_check(SteamApi.call_steam("createLobby", [2, 4]) == null, "passthrough no-op")
	_check(not SteamApi.connect_steam("lobby_created", func(_a, _b) -> void: pass), "connect no-op")

	# Routed: a fake GodotSteam object gets the calls.
	var fake := FakeGodotSteam.new()
	svc._start(fake, 480)
	_check(svc.backend() == "steam" and SteamApi.active(), "fake init turns the backend on")
	_check(fake.calls[0] == ["steamInitEx", 480], "init with app 480")
	_check(SteamApi.unlock_achievement("first_harvest"), "unlock routed")
	_check(SteamApi.is_achievement_unlocked("first_harvest"), "achievement read back")
	_check(SteamApi.set_stat("crops", 3) and SteamApi.get_stat("crops") == 7, "stats routed")
	_check(SteamApi.set_rich_presence("steam_display", "#Farming"), "presence routed")
	_check(SteamApi.persona_name() == "Tester" and SteamApi.is_on_deck(), "user routed")
	_check(SteamApi.show_gamepad_text_input("Name", "Pip", 16), "gamepad kb routed")
	var got := []
	svc.text_input_done.connect(func(ok: bool, t: String) -> void: got.append([ok, t]))
	fake.gamepad_text_input_dismissed.emit(true, "Nova", 480)
	_check(got == [[true, "Nova"]], "text input result relayed: %s" % [got])
	await process_frame
	await process_frame
	var stores := fake.calls.filter(func(c: Array) -> bool: return c[0] == "storeStats").size()
	_check(stores == 1, "dirty stats stored once per frame, got %d" % stores)
	# Integration hooks other packages call duck-typed (S1 integ).
	_check(svc.is_live() and svc.steam_object() == fake and svc.overlay_enabled(), "is_live/steam_object/overlay_enabled")
	_check(svc.set_achievement("first_harvest"), "set_achievement alias")
	_check(svc.input_type(0) == "deck" and svc.input_type(3) == "", "input_type via Steam Input handle")
	_check(SteamService.input_kind(13) == "ps" and SteamService.input_kind(10) == "switch" and SteamService.input_kind(3) == "xbox" and SteamService.input_kind(0) == "", "input_kind table")
	_check(svc.show_floating_keyboard(true, Rect2i(1, 2, 3, 4)), "floating keyboard routed")
	_check(fake.calls.back() == ["showFloatingGamepadTextInput", 1], "multiline mode passed")
	_check(not svc.is_live() or root.get_node_or_null("SteamSvc") != null, "achievements/net find the service at /root/SteamSvc")
	svc.inject(null)
	_check(not svc.show_floating_keyboard(false, Rect2i()) and svc.input_type(0) == "" and not svc.overlay_enabled(), "hooks no-op when local")
	_check(not SteamApi.active() and SteamApi.backend() == "local", "back to local")
	fake.free()

	print("STEAM SERVICE TEST DONE, failures: ", _fails)
	quit(1 if _fails > 0 else 0)

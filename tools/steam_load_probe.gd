extends SceneTree
## S1 P1, CI only (.github/workflows/steam-builds.yml, after tools/stage_godotsteam.sh
## and --import): proves the GodotSteam GDExtension loads on Linux and that init
## without a Steam client fails cleanly (no crash) so SteamSvc stays "local".
## Never run in the sandbox (auto-mode blocks loading downloaded libraries).
## Prints "STEAM LOAD: ok ..." and exits 0, or "STEAM LOAD: FAIL ..." and exits 1.


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	if not Engine.has_singleton("Steam"):
		print("STEAM LOAD: FAIL singleton missing (addon not staged or library did not load)")
		quit(1)
		return
	var s: Object = Engine.get_singleton("Steam")
	var ver: Variant = s.call("get_godotsteam_version") if s.has_method("get_godotsteam_version") else "?"
	var running: Variant = s.call("isSteamRunning") if s.has_method("isSteamRunning") else "?"
	var res: Variant = s.call("steamInitEx", 480, false) if s.has_method("steamInitEx") else null
	var ms := Time.get_ticks_msec() - t0
	if not res is Dictionary:
		print("STEAM LOAD: FAIL steamInitEx returned %s" % [res])
		quit(1)
		return
	# No Steam client on CI: a non-zero status is the expected, safe outcome.
	print("STEAM LOAD: ok godotsteam=%s steam_running=%s init_status=%s (%s) %d ms" % [ver, running, (res as Dictionary).get("status"), (res as Dictionary).get("verbal", ""), ms])
	quit(0)

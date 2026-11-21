extends Node
## BootProbe (autoload; S1 P1): does nothing unless the game is started with
## `-- --boot-probe` (or `--boot-probe=gangsters`). Then it measures the first
## launch of an exported desktop build for CI (.github/workflows/steam-builds.yml,
## tools/desktop_build_report.py): prints
##   DREAMS BOOT steam backend=<local|steam> reason=<...>
##   DREAMS BOOT title ms=<ms since start>
##   DREAMS BOOT farm ms=<ms>   (a new game on the farm, 600 frames played)
##   DREAMS BOOT OK
## and quits 0; a missing title/farm quits 2, the watchdog (90 s of frames) quits 3.
## Run it with a scratch XDG_DATA_HOME / APPDATA: it starts a new game (never saved by
## the probe itself, but the farm may autosave into that scratch user dir).

const FARM_FRAMES := 600
const WATCHDOG_S := 90.0

var _on := false
var _arc := "penguins"
var _stage := "title"
var _frames := 0
var _t := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--boot-probe" or a.begins_with("--boot-probe="):
			_on = true
			if a.ends_with("=gangsters"):
				_arc = "gangsters"
	set_process(_on)
	if not _on:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	var svc := get_node_or_null("/root/SteamSvc")
	var backend: String = svc.backend() if svc else "none"
	var why: String = svc.reason if svc else "no_service"
	print("DREAMS BOOT steam backend=%s reason=%s" % [backend, why])
	print("DREAMS BOOT version=%s" % str(ProjectSettings.get_setting("application/config/version", "")))


func _process(dt: float) -> void:
	_t += dt
	_frames += 1
	if _t > WATCHDOG_S:
		print("DREAMS BOOT FAIL watchdog at stage ", _stage)
		get_tree().quit(3)
		set_process(false)
		return
	var cs := get_tree().current_scene
	var scene := cs.scene_file_path if cs else ""
	if _stage == "title":
		if scene.ends_with("title.tscn") and _frames > 2:
			print("DREAMS BOOT title ms=%d" % Time.get_ticks_msec())
			_stage = "start"
	elif _stage == "start":
		GameState.new_run(_arc, "kairi" if _arc == "penguins" else "man", "Probe", "Town", "Pup")
		get_tree().change_scene_to_file("res://scenes/farm.tscn")
		_stage = "farm"
		_frames = 0
	elif _stage == "farm":
		if scene.ends_with("farm.tscn") and _frames >= FARM_FRAMES:
			print("DREAMS BOOT farm ms=%d" % Time.get_ticks_msec())
			print("DREAMS BOOT OK")
			set_process(false)
			get_tree().quit(0)
		elif _frames > FARM_FRAMES * 4:
			print("DREAMS BOOT FAIL farm not reached (scene=%s)" % scene)
			set_process(false)
			get_tree().quit(2)

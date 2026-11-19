extends SceneTree
## Startup cost probe: what the first scene pays for before the title shows.
##   godot --headless --path . -s res://tools/startup_probe.gd
func _initialize() -> void:
	_run.call_deferred()

func _t(label: String, t0: int) -> int:
	var now := Time.get_ticks_usec()
	print("startup_probe: %-28s %7.1f ms" % [label, (now - t0) / 1000.0])
	return now

func _run() -> void:
	print("startup_probe: engine up at %d ms" % Time.get_ticks_msec())
	var t := Time.get_ticks_usec()
	Art.manifest()
	t = _t("Art.manifest()", t)
	GameState.load_data()
	t = _t("GameState.load_data()", t)
	var ps: PackedScene = load("res://scenes/title.tscn")
	t = _t("load title.tscn", t)
	root.add_child(ps.instantiate())
	t = _t("title instantiate+ready", t)
	await process_frame
	t = _t("first frame", t)
	print("startup_probe: static mem %.0f MB" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0))
	quit()

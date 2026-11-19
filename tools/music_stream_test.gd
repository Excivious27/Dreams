extends SceneTree
## The web build's streamed music, offline: a local HTTP server stands in for
## GitHub Pages and Music acts as if streamed songs aren't packed.
##   godot --headless --path . -s res://tools/music_stream_test.gd
## Checks: a packed stand-in plays at once while a song downloads, the real
## song takes over when it arrives, it is cached, failures retry and keep the
## music going, and a cached song plays with the server gone.
var fails := 0
var pid := -1


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	_run.call_deferred()


func _wait_for(m: Music, track: String, secs: float) -> bool:
	var t := 0.0
	while t < secs:
		if m.now_playing() == track:
			return true
		await create_timer(0.1).timeout
		t += 0.1
	return m.now_playing() == track


func _run() -> void:
	var port := 18000 + randi() % 2000
	var dir := ProjectSettings.globalize_path("res://audio/music")
	pid = OS.create_process("python3", ["-m", "http.server", str(port), "--bind", "127.0.0.1", "--directory", dir])
	check(pid > 0, "start the local music server")
	await create_timer(1.5).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://mcache/neon.ogg"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://mcache/docks.ogg"))
	Music.force_stream = true
	Music.retry_delays = [0.3, 0.5]
	Music.stream_base = "http://127.0.0.1:%d/" % port
	var m := Music.instance(self)
	await process_frame
	await process_frame
	check(m.get_parent() != null, "Music is in the tree")
	# Arc start: the theme streams in; the title (packed) keeps playing meanwhile.
	m.play("title")
	check(m.now_playing() == "title", "packed title plays at once (%s)" % m.now_playing())
	m.play("neon")
	check(m.wanted() == "neon", "neon wanted")
	check(m.now_playing() == "title", "title keeps playing while neon downloads (%s)" % m.now_playing())
	check(await _wait_for(m, "neon", 15.0), "neon arrives and takes over (%s)" % m.now_playing())
	check(FileAccess.file_exists("user://mcache/neon.ogg"), "neon cached")
	# From silence (after stop): a stand-in starts right away.
	m.stop_all()
	m.play("inn")
	check(m.now_playing() == "house", "silence -> house stand-in while the inn song downloads (%s)" % m.now_playing())
	check(await _wait_for(m, "inn", 15.0), "inn arrives (%s)" % m.now_playing())
	# Server gone: retries, music never stops; cached songs still play.
	OS.kill(pid)
	pid = -1
	await create_timer(0.5).timeout
	Music.stream_base = "http://127.0.0.1:%d/" % (port + 1)
	m.stop_all()
	m.play("docks")
	check(m.now_playing() == "farm", "farm stand-in while docks can't download (%s)" % m.now_playing())
	await create_timer(3.0).timeout
	check(m.tries("docks") >= 2, "failed download retried (%d tries)" % m.tries("docks"))
	check(m.now_playing() == "farm", "stand-in still playing after failures")
	m._streamed.erase("neon")
	m.play("neon")
	check(m.now_playing() == "neon", "cached neon plays with no server (%s)" % m.now_playing())
	# Relative addresses are refused by HTTPRequest (the bug that silenced the web build).
	Music.stream_base = ""
	check(Music._base_url() == "" or Music._base_url().begins_with("http"), "base url is absolute or empty")
	print("music_stream_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


func _finalize() -> void:
	if pid > 0:
		OS.kill(pid)

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
	for t: String in ["neon", "docks", "boss", "keeper"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Music._cache_path(t)))
	# A stale cached copy (an older version of the song) must be ignored and replaced.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://mcache"))
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://audio/music/title.ogg"), ProjectSettings.globalize_path("user://mcache/neon.00000000.ogg"))
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
	check(m.now_playing() == "farm", "title never carries over an area song: farm stand-in while neon downloads (%s)" % m.now_playing())
	check(await _wait_for(m, "neon", 15.0), "neon arrives and takes over (%s)" % m.now_playing())
	# On the title screen the title song does carry the arc theme's download.
	m.play("title")
	m.play("arc_penguins")
	check(m.now_playing() == "title", "title keeps playing while an arc theme downloads (%s)" % m.now_playing())
	check(FileAccess.file_exists(Music._cache_path("neon")), "neon cached under its version (%s)" % Music._cache_path("neon"))
	check(Music.stream_ver("neon").length() == 8, "music_stream.json carries a version per song")
	check(not FileAccess.file_exists("user://mcache/neon.00000000.ogg"), "the stale cached version was deleted")
	# Prefetch API: a boss song queued ahead lands in the cache and then starts at once.
	m.prefetch(["boss", "keeper"])
	check(m.prefetch_queue().has("boss") or m._fetching.has("boss"), "prefetch(['boss']) queues the boss song first")
	var pt := 0.0
	while pt < 20.0 and not (FileAccess.file_exists(Music._cache_path("boss")) and FileAccess.file_exists(Music._cache_path("keeper"))):
		await create_timer(0.2).timeout
		pt += 0.2
	check(FileAccess.file_exists(Music._cache_path("boss")), "prefetched boss song cached")
	m.play("boss")
	check(m.now_playing() == "boss", "a prefetched boss song starts at once (%s)" % m.now_playing())
	# A fight is over and the calm song downloads: the boss song must not linger.
	m._streamed.erase("farm_fall")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Music._cache_path("farm_fall")))
	m.play("farm_fall")
	check(m.now_playing() == "farm", "boss -> downloading calm song: the farm stand-in, not the boss song (%s)" % m.now_playing())
	# The title theme never carries over a loaded save.
	m.play("title")
	m._streamed.erase("winter")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Music._cache_path("winter")))
	m.play("winter")
	check(m.now_playing() == "farm", "title -> downloading area song: farm stand-in (%s)" % m.now_playing())
	# Asking for the stand-in itself does not restart it. Hold the winter download
	# first: if it lands during the wait, winter takes over and the check races it.
	if m._fetching.has("winter"):
		var wrq: HTTPRequest = m._fetching["winter"]
		m._fetching.erase("winter")
		m._fetch_prog.erase("winter")
		wrq.cancel_request()
		wrq.queue_free()
	await create_timer(0.6).timeout
	check(m.now_playing() == "farm", "the stand-in is still playing before the re-ask (%s)" % m.now_playing())
	var pos0: float = m._player.get_playback_position()
	m.play("farm")
	check(m.now_playing() == "farm" and m._player.get_playback_position() >= pos0, "asking for the playing stand-in keeps it going (%.2f >= %.2f)" % [m._player.get_playback_position(), pos0])
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
	# A prefetch that fails while it is the wanted song must not stall the queue.
	m._prefetching = "rain"
	m._current = "rain"
	m._failed("rain")
	check(m._prefetching == "", "a failed prefetch lets go even when it is wanted")
	# Stalled downloads are dropped (no whole-file timeout).
	check(Music.stall_secs > 0.0, "stall watch on")
	# Muted: nothing downloads.
	m.toggle_mute()
	m._fetching.clear()
	m.play("forest")
	check(m._fetching.is_empty(), "muted: no download for a wanted song")
	m.toggle_mute()
	# Memory: downloaded songs kept in memory stay bounded.
	for t: String in ["night", "rain", "town", "meadow", "forest", "lake", "beach", "mountain"]:
		m._got(t, FileAccess.get_file_as_bytes("res://audio/music/%s.ogg" % t), false)
	check(m.streamed_count() <= Music.STREAMED_KEEP + 2, "streamed songs in memory stay bounded (%d)" % m.streamed_count())
	# Cache cap: least recently used songs go first.
	Music.cache_cap = 2 * 1024 * 1024
	for t: String in ["night", "rain", "town", "meadow"]:
		m._got(t, FileAccess.get_file_as_bytes("res://audio/music/%s.ogg" % t), true)
	var total := 0
	var da := DirAccess.open("user://mcache")
	for fn: String in da.get_files():
		if fn.ends_with(".ogg"):
			total += FileAccess.open("user://mcache/" + fn, FileAccess.READ).get_length()
	check(total <= Music.cache_cap + 3 * 1024 * 1024, "the song cache is trimmed near its cap (%d KB)" % (total / 1024))
	# c13_16-10: a prefetch set bigger than the cache never loops (each song fetched ahead
	# at most once a session; the background lists stop at PREFETCH_SHARE of the cap).
	var da2 := DirAccess.open("user://mcache")
	for fn: String in da2.get_files():
		da2.remove(fn)
	m._cindex = {}
	m._prefetched = {}
	m._prefetch_bytes = 0
	m.prefetch_fetches = 0
	m.prefetch_count = {}
	m._streamed.clear()
	m._streamed_order.clear()
	m._tries.clear()
	Music.cache_cap = 6 * 1024 * 1024
	GameState.run = {"arc": "gangsters", "day": 1, "time": 600, "flags": {}}
	var lst: Array = []
	for t: String in Music.PREFETCH_GANG + Music.PREFETCH:
		if t in Music._stream_list() and not lst.has(t):
			lst.append(t)
	m._prefetch_next()
	var pw := 0.0
	while pw < 20.0:
		await create_timer(0.25).timeout
		pw += 0.25
	var twice := 0
	for t: String in m.prefetch_count:
		if int(m.prefetch_count[t]) > 1:
			twice += 1
	check(m.prefetch_fetches > 0, "the prefetcher fetched something (%d)" % m.prefetch_fetches)
	check(m.prefetch_fetches <= lst.size(), "prefetch fetches %d <= list %d (no endless loop)" % [m.prefetch_fetches, lst.size()])
	check(twice == 0, "no song prefetched twice (%s)" % m.prefetch_count)
	var budget := 0
	for t: String in m.prefetch_count:
		budget += int(Music._stream_size.get(t, 0))
	check(budget <= int(Music.cache_cap * Music.PREFETCH_SHARE) + 1, "background prefetch stays inside its cache share (%d KB)" % (budget / 1024))
	check(m._prefetching == "", "the prefetcher settles (%s)" % m._prefetching)
	GameState.run = {}
	# The web URL builder (absolute address next to the page).
	check(Music.base_from_page("https://x.github.io/dreams/") == "https://x.github.io/dreams/music/", "url: folder page")
	check(Music.base_from_page("https://x.github.io/dreams/index.html?v=2#a") == "https://x.github.io/dreams/music/", "url: index.html with query")
	check(Music.base_from_page("https://x.io") == "https://x.io/music/", "url: bare host")
	check(Music.base_from_page("dreams/index.html") == "", "url: relative page refused")
	print("music_stream_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


func _finalize() -> void:
	if pid > 0:
		OS.kill(pid)

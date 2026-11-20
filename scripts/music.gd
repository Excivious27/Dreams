class_name Music
extends Node
## Plays looping music per area and short sound effects. Tracks live in
## audio/music/<name>.ogg (ACE Music renders, see audio/ACE_LOG.json). Effects are
## audio/sfx/<name>.ogg (ACE kits and CC0 recordings) with up to two variations
## <name>_2/_3 picked at random; generated .wav placeholders fill any gap.

static var _inst: Music
var _player: AudioStreamPlayer
var _fading: AudioStreamPlayer   # the outgoing track while a crossfade runs
var _sfx: Array[AudioStreamPlayer] = []
## Base song level (dB). C6: raised from -8 with the even-dB volume curve
## (Settings._db), so the default music level sits near -21 LUFS on a phone.
const MUSIC_DB := -2.0
const FADE := 0.9
var _current := ""
var _muted := false
var _tw_out: Tween
var _tw_in: Tween
var _sfx_cache := {}
var _steps: AudioStreamPlayer
var _blip: AudioStreamPlayer     # talk blips have their own voice: they never cut a jingle
var _duck := 0.0                 # the environment duck (Ambience: night/storm), dB
var _next_voice := 0
## Crossfade gains (dB, 0 = full) for the incoming and outgoing players; the
## duck is added on top every frame, so a duck never fights a fade.
var _gain_in := 0.0
var _gain_out := -40.0
var _duck_now := 0.0
var _last_release := 2.0
var _clock := 0.0                 # Music's own clock (runs paused too): duck layer timing
## Extra duck layers by owner: {owner: {db, until (ms, -1 = until cleared), attack, release}}.
## The environment duck is skipped while combat/boss music plays (night fights
## are as loud as day fights); jingles, the battle-end card and dialogue each
## dip on their own layer, and the deepest layer wins.
var _layers := {}
const JINGLE_DUCK := -10.0
const TALK_DUCK := -3.0
## Sound in the background: muted when the app/page is hidden (Settings bg_sound).
var _bg_muted := false
var _voice_t: Array = []          # ms each sfx voice started (oldest-first stealing)
var _voice_long: Array = []       # the voice plays a jingle/long sound (never stolen first)


static func instance(tree: SceneTree) -> Music:
	if _inst == null or not is_instance_valid(_inst):
		_inst = Music.new()
		_inst.name = "Music"
		# At startup the root is still adding the first scene, and add_child()
		# fails then (the web build lost all music to this). Defer it; play()
		# remembers the track until the player exists.
		tree.root.add_child.call_deferred(_inst)
	return _inst


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveGame.web_hook()
	Settings.apply_audio()
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	_player.volume_db = MUSIC_DB
	add_child(_player)
	_fading = AudioStreamPlayer.new()
	_fading.bus = "Music"
	_fading.volume_db = -60.0
	add_child(_fading)
	_player.finished.connect(_on_finished.bind(_player))
	_fading.finished.connect(_on_finished.bind(_fading))
	# Web: songs play as streams, not Web Audio samples (a sample is the whole
	# song decoded to PCM in page memory, ~50 MB each, and skips the Music bus
	# limiter). Short sfx stay samples (C9 P4).
	if OS.has_feature("web"):
		_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		_fading.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		cache_cap = WEB_CACHE_CAP
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -4.0
		p.bus = "SFX"
		add_child(p)
		_sfx.append(p)
		_voice_t.append(0)
		_voice_long.append(false)
	_steps = AudioStreamPlayer.new()
	_steps.bus = "SFX"
	_steps.volume_db = STEP_DB
	add_child(_steps)
	_blip = AudioStreamPlayer.new()
	_blip.bus = "SFX"
	add_child(_blip)
	_muted = bool(SaveGame.get_value("muted", false))
	_apply_master_mute()
	_web_visibility_hook()
	get_tree().create_timer(4.0, true).timeout.connect(_prefetch_next)
	if _pending != "":
		var t := _pending
		_pending = ""
		play(t)


var _pending := ""
## Tracks that play once (endings, credits, the lullaby scene) instead of looping.
const ONCE := ["ending_penguin", "ending_gangster", "credits", "merkitty_song"]
## Loudness by kind of effect, on top of each file's own level (dB). Files are
## levelled by tools/sfx_soften.py (UI and steps already sit lower), so these are small.
## EXACT names win over prefixes (GROUP_DB, first match in order).
const GROUP_EXACT := {"j_buy": 0.0, "j_confirm": 0.0, "scroll_tick": -8.0, "tab": -6.0, "nope": -4.0}
const GROUP_DB := {"ui_": -5.0, "menu_": -4.5, "page": -3.5, "equip": -5.0, "talk_blip": -5.5, "keypress": -10.0,
	"step_": 0.0, "coin": -3.0, "cash_": -3.0, "pickup": -3.0, "j_": -2.0, "levelup": -1.0, "quest_done": -1.0}
## Never pitch-drifted: UI clicks, money and every musical cue stay in key.
const NO_DRIFT := ["ui_", "menu_", "page", "equip", "keypress", "talk_blip", "scroll_tick", "tab", "nope",
	"coin", "cash_", "j_", "craft_done", "mail", "levelup", "quest_done", "boss_down"]
## Musical cues that dip the song while they play (music ducks under jingles).
const JINGLE_NAMES := ["levelup", "quest_done", "craft_done", "boss_down"]
## How long a left song is remembered so it resumes where it was (ms).
const RESUME_MS := 90000


## `fade`: crossfade seconds (DangerMusic cuts in quicker and fades out slower).
func play(track: String, fade := FADE) -> void:
	if _player == null:
		_pending = track
		return
	if not (track in ONCE) and track != "":
		_after = []  # an ending's queued credits never start after the game moved on
	if track == _current:
		return
	if track != _hold:
		_hold = ""
	_current = track
	_fade = fade
	if track == _now and _player.playing:
		return  # already heard as the stand-in: no restart
	var stream := _stream_for(track)
	if stream != null:
		_start(stream, track)
		return
	# Not in the pack (web build streams most songs): fetch it, and keep music
	# going meanwhile. A calm song already playing carries on; title themes,
	# play-once tracks and a finished fight's song hand over to a packed stand-in
	# at once (a boss song must not linger over a calm walk, the title over a save).
	if track in _stream_list():
		_fetch(track)
	if _now == "" or not _player.playing or not _carry_ok(_now, track):
		var s := _standin(track)
		var st := _stream_for(s)
		if st != null and s != _now:
			_start(st, s)
		elif st != null and not _player.playing:
			_start(st, s)


## Play a song for a story scene and hold it: DangerMusic's calm re-ask leaves it
## alone while it is wanted (until another song is asked for or the map changes).
func play_held(track: String, fade := FADE) -> void:
	play(track, fade)
	_hold = track


var _hold := ""


func held() -> String:
	return _hold if _hold == _current else ""


func release_hold() -> void:
	_hold = ""


## May the song now heard carry on while `wanted` downloads?
func _carry_ok(now_t: String, wanted_t: String) -> bool:
	var title_now := now_t in ["title", "title_musicbox"] or now_t.begins_with("arc_")
	if title_now and (wanted_t in ["title", "title_musicbox"] or wanted_t.begins_with("arc_")):
		return true  # the title screen: the title song carries the arc theme's download
	if title_now or now_t in ONCE:
		return false
	if wanted_t in ONCE:
		return false  # an ending opens on its own stand-in, never the last fight's song
	if _is_fight_song(now_t) and not _is_fight_song(wanted_t):
		return false  # a fight is over: its song must not linger over the calm
	return true  # a calm song carries a fight's first seconds until its song lands


static func _is_fight_song(t: String) -> bool:
	if t.begins_with("combat_") or t.begins_with("danger") or t.begins_with("boss") or t == "raid":
		return true
	return t in GameMap.BOSS_TRACKS or t in ["keeper", "marked", "finargle"] or t.begins_with("battle")


## The song actually heard (a stand-in while the wanted one downloads).
func now_playing() -> String:
	return _now


## The song the game asked for.
func wanted() -> String:
	return _current


var _fade := FADE
## {track: [position s, ticks ms]}: where a looping song was left.
var _resume := {}


func _start(stream: AudioStream, name: String) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = not (name in ONCE)
		(stream as AudioStreamOggVorbis).loop_offset = loop_point(name)  # C6 P2: data/music_loops.json
	# Remember where the outgoing song was, so it resumes there if asked again soon.
	if _player.playing and _now != "" and not (_now in ONCE):
		_resume[_now] = [_player.get_playback_position(), Time.get_ticks_msec()]
	_now = name
	# Crossfade: the old track fades out on the spare player while the new one fades in.
	# A second change mid-fade must not let the first fade's stop() land on the
	# new track: kill both tweens first.
	if _tw_out and _tw_out.is_valid():
		_tw_out.kill()
	if _tw_in and _tw_in.is_valid():
		_tw_in.kill()
	if _player.playing:
		_fading.stop()
		var old := _player
		_player = _fading
		_fading = old
		_gain_out = _gain_in
		_tw_out = create_tween()
		_tw_out.tween_property(self, "_gain_out", -40.0, maxf(0.05, _fade))
		_tw_out.tween_callback(old.stop)
	_player.stream = stream
	_gain_in = -30.0
	_apply_volumes()
	var from := 0.0
	if _resume.has(name) and not (name in ONCE) and not _is_boss_intro(name):
		var r: Array = _resume[name]
		if Time.get_ticks_msec() - int(r[1]) < RESUME_MS:
			from = float(r[0])
			var ln := stream.get_length()
			if ln > 1.0:
				from = fmod(from, ln)
		_resume.erase(name)
	# The Master bus mute silences a muted game; the song still runs so unmute
	# picks it up where it is instead of restarting it.
	_player.play(from)
	_tw_in = create_tween()
	_tw_in.tween_property(self, "_gain_in", 0.0, maxf(0.05, _fade))
	_trim_streamed()


## Boss intros are the cue: they start from the top.
static func _is_boss_intro(t: String) -> bool:
	return t.begins_with("boss") or t in ["keeper", "marked", "finargle"]


## Where a song would resume (tests): -1 when it would start from the top.
func resume_pos(track: String) -> float:
	if not _resume.has(track):
		return -1.0
	return float(_resume[track][0])


func _process(_delta: float) -> void:
	if _player == null:
		return
	# Expire timed duck layers, pick the deepest, glide the duck there.
	_clock += _delta
	var now := Time.get_ticks_msec()
	var nowc := int(_clock * 1000.0)
	var target := 0.0 if _fight_now() else _duck
	var attack := 2.0
	var release := 2.0  # the environment duck glides slowly both ways
	for k: String in _layers.keys():
		var L: Dictionary = _layers[k]
		if int(L["until"]) >= 0 and nowc > int(L["until"]):
			_layers.erase(k)
			continue
		if float(L["db"]) < target:
			target = float(L["db"])
			attack = float(L["attack"])
			release = float(L["release"])
	# Dialogue dip: a story line sits a touch above the song.
	var dl := get_tree().root.get_node_or_null("Dialogue")
	if dl != null and bool(dl.get("active")) and TALK_DUCK < target:
		target = TALK_DUCK
		attack = 0.3
		release = 0.6
	if target < 0.0 and target <= _duck_now:
		_last_release = release
	var dt := get_process_delta_time()
	if _duck_now > target:
		_duck_now = maxf(target, _duck_now - dt * 10.0 / maxf(0.05, attack))
	elif _duck_now < target:
		_duck_now = minf(target, _duck_now + dt * 10.0 / maxf(0.05, _last_release))
	_apply_volumes()
	_stall_check(now)
	if get_tree().paused:
		DangerMusic.paused_tick(get_tree(), _delta)


func _apply_volumes() -> void:
	if _player == null:
		return
	_player.volume_db = MUSIC_DB + _gain_in + _duck_now
	_fading.volume_db = MUSIC_DB + _gain_out + _duck_now


## Combat or boss music is the song: the night/storm duck stays off.
func _fight_now() -> bool:
	return DangerMusic.tier > 0 or _is_fight_song(_now)


## The music's total duck right now (dB, tests).
func duck_level() -> float:
	return _duck_now


## Dip the music on its own layer. `hold` seconds (-1 = until clear_duck_layer).
func set_duck_layer(owner: String, db: float, attack := 0.12, release := 0.8, hold := -1.0) -> void:
	_layers[owner] = {"db": db, "attack": attack, "release": release,
		"until": -1 if hold < 0.0 else int(_clock * 1000.0) + int(hold * 1000.0)}


func clear_duck_layer(owner: String) -> void:
	_layers.erase(owner)


## A song we can play right now: packed, already downloaded, or in the cache.
func _stream_for(track: String) -> AudioStream:
	if track == "":
		return null
	if not (force_stream and track in _stream_list()):
		var path := "res://audio/music/%s.ogg" % track
		if ResourceLoader.exists(path):
			var st := load(path) as AudioStream
			if st != null:
				return st
	if _streamed.has(track):
		_touch_streamed(track)
		return _streamed[track]
	var cache := _cache_path(track)
	if FileAccess.file_exists(cache):
		var st2 := AudioStreamOggVorbis.load_from_buffer(FileAccess.get_file_as_bytes(cache))
		if st2 != null:
			_streamed[track] = st2
			_touch_streamed(track)
			_cache_used(track)
			return st2
		DirAccess.remove_absolute(cache)  # broken download: fetch it again
	return null


## A packed song that suits the wanted one, to play until it arrives.
func _standin(track: String) -> String:
	var t := track
	# A fight never sounds calm: each arc's fight loop is packed (music_stream.py EMBED).
	if _is_fight_song(t):
		var fight := "combat_light_gang" if (t.ends_with("_gang") or str(GameState.run.get("arc", "")) == "gangsters") else "combat_light"
		for c: String in [fight, "combat_light", "combat_light_gang"]:
			if _stream_for(c) != null:
				return c
	if t in ["house", "shop", "shop_gang", "inn", "chapel", "clinic", "hideout", "merkitty_song", "credits"] or t.begins_with("ending"):
		t = "house"
	else:
		t = "farm"
	for c: String in [t, "farm", "house", "title"]:
		if _stream_for(c) != null:
			return c
	return ""


# ---- streamed music (web): data/music_stream.json lists songs kept outside the pack ----
var _streamed := {}
var _streamed_order: Array = []   # least recently used first
var _fetching := {}
var _fetch_prog := {}             # track -> [bytes, ms of the last progress]
var _tries := {}
var _now := ""
var _queue: Array = []            # Music.prefetch: songs to fetch ahead, before the PREFETCH lists
static var _stream_names: Array = []
static var _stream_ver := {}
static var _stream_size := {}
## Tests: treat streamed songs as missing from the pack (acts like the web build).
static var force_stream := false
## Where streamed songs live ("<base><name>.ogg"). The web build works it out
## from the page address; tests point it at a local server.
static var stream_base := ""
## Seconds before each retry of a failed download (the last one repeats).
static var retry_delays: Array = [2.0, 5.0, 12.0, 30.0, 60.0]
## A download with no new bytes for this long is dropped and retried (no
## whole-file limit: big songs on slow phone data still land).
static var stall_secs := 20.0
## Downloaded songs kept in memory (current, fading and a couple more).
const STREAMED_KEEP := 4
## user://mcache size cap (bytes); least recently used songs go first.
static var cache_cap := 40 * 1024 * 1024
## On the web user:// is held in page memory (IDBFS), so the cache stays small there.
const WEB_CACHE_CAP := 16 * 1024 * 1024
## Songs heard often, fetched quietly one by one once the first song is in.
const PREFETCH := ["night", "rain", "town", "meadow", "forest", "lake", "winter", "farm_fall"]
const PREFETCH_GANG := ["combat_light_gang", "raid", "countryside", "boss_gang", "hideout", "neon", "docks", "combat_elite_gang"]
const PREFETCH_PENGUIN := ["combat_light", "danger", "cattopia", "boss_penguin", "beach", "mountain", "combat_elite"]
## Before a run exists (the title screen) the arc themes come first.
const PREFETCH_TITLE := ["arc_penguins", "arc_gangsters"]


static func _load_stream_json() -> void:
	if _stream_names.is_empty() and FileAccess.file_exists("res://data/music_stream.json"):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/music_stream.json"))
		if d is Dictionary:
			_stream_names = (d as Dictionary).get("stream", [])
			_stream_ver = (d as Dictionary).get("ver", {})
			_stream_size = (d as Dictionary).get("size", {})


static func _stream_list() -> Array:
	_load_stream_json()
	return _stream_names


## Content version of a streamed song ("" when the list has none).
static func stream_ver(t: String) -> String:
	_load_stream_json()
	return str(_stream_ver.get(t, ""))


static func _cache_path(t: String) -> String:
	var v := stream_ver(t)
	return "user://mcache/%s.%s.ogg" % [t, v] if v != "" else "user://mcache/%s.ogg" % t


## A song exists: in the pack, or streamed on the web build.
static func has_track(t: String) -> bool:
	return ResourceLoader.exists("res://audio/music/%s.ogg" % t) or t in _stream_list()


## Absolute address of the streamed songs. HTTPRequest refuses relative URLs
## ("Invalid URL scheme"), which silenced every streamed song on the web build.
static func _base_url() -> String:
	if stream_base != "":
		return stream_base
	var env := OS.get_environment("DREAMS_MUSIC_URL")
	if env != "":
		stream_base = env if env.ends_with("/") else env + "/"
		return stream_base
	if OS.has_feature("web"):
		var bu: Variant = JavaScriptBridge.eval("document.baseURI", true)
		stream_base = base_from_page(str(bu) if bu != null else "")
	return stream_base


## The music folder for a page address (the web build's URL builder, testable):
## "https://x.io/dreams/index.html?a=1" -> "https://x.io/dreams/music/".
static func base_from_page(page: String) -> String:
	if not (page.begins_with("http://") or page.begins_with("https://")):
		return ""
	var p := page.split("#")[0].split("?")[0]
	var cut := p.rfind("/")
	if cut < p.find("//") + 2:
		return p + "/music/"
	return p.substr(0, cut + 1) + "music/"


## Songs the player will hear soon (boss, next areas, endings): fetched ahead of
## the PREFETCH lists. Only streamed songs not yet cached are queued.
func prefetch(tracks: Array, front := true) -> void:
	var add: Array = []
	for t: Variant in tracks:
		var s := str(t)
		if s == "" or not (s in _stream_list()) or _streamed.has(s) or s in _queue or _fetching.has(s):
			continue
		if FileAccess.file_exists(_cache_path(s)):
			continue
		add.append(s)
	if front:
		_queue = add + _queue
	else:
		_queue.append_array(add)
	if _player != null:
		_prefetch_next.call_deferred()


## Songs waiting to be prefetched (tests).
func prefetch_queue() -> Array:
	return _queue


## No downloads while the music can't be heard (all sound off or music at 0).
func _silent() -> bool:
	return _muted or int(Settings.get_v("music_vol")) <= 0


## Settings/mute changed: fetch the wanted song if it is now audible.
func audio_changed() -> void:
	if _player == null or _silent():
		return
	if _current != "" and _now != _current and _current in _stream_list():
		_fetch(_current)
	_prefetch_next.call_deferred()


func _fetch(track: String) -> void:
	if _fetching.has(track) or _streamed.has(track) or _silent():
		return
	var base := _base_url()
	if base == "":
		return
	if track == _current:
		# The song the player is waiting for goes first: drop a background prefetch.
		for other: String in _fetching.keys():
			if other != track and other == _prefetching:
				var orq: HTTPRequest = _fetching[other]
				orq.cancel_request()
				orq.queue_free()
				_fetching.erase(other)
				_fetch_prog.erase(other)
				_prefetching = ""
	var rq := HTTPRequest.new()
	rq.timeout = 0.0  # no whole-file limit; _stall_check drops a stalled download
	add_child(rq)
	_fetching[track] = rq
	_fetch_prog[track] = [0, Time.get_ticks_msec()]
	rq.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		if _fetching.get(track) != rq:
			return  # cancelled
		_fetching.erase(track)
		_fetch_prog.erase(track)
		rq.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200 and body.size() > 1000 and _got(track, body, true):
			return
		_failed(track))
	var v := stream_ver(track)
	var url := base + track + ".ogg" + ("?v=" + v if v != "" else "")
	if rq.request(url) != OK:
		_fetching.erase(track)
		_fetch_prog.erase(track)
		rq.queue_free()
		_failed(track)


## Drop downloads that made no progress for stall_secs.
var _stall_t := 0


func _stall_check(now: int) -> void:
	if _fetching.is_empty() or now - _stall_t < 500:
		return
	_stall_t = now
	for t: String in _fetching.keys():
		var rq: HTTPRequest = _fetching[t]
		var pr: Array = _fetch_prog.get(t, [0, now])
		var b := rq.get_downloaded_bytes()
		if b != int(pr[0]):
			_fetch_prog[t] = [b, now]
		elif now - int(pr[1]) > int(stall_secs * 1000.0):
			rq.cancel_request()
			rq.queue_free()
			_fetching.erase(t)
			_fetch_prog.erase(t)
			_failed(t)


func _failed(track: String) -> void:
	var n := int(_tries.get(track, 0))
	_tries[track] = n + 1
	var d: float = float(retry_delays[mini(n, retry_delays.size() - 1)])
	if track == _prefetching:
		# A prefetch always lets go, even when the song became the wanted one,
		# so a failure can never stall the queue; the wanted song retries below.
		_prefetching = ""
		get_tree().create_timer(d, true).timeout.connect(_prefetch_next)
		if track != _current:
			return
	get_tree().create_timer(d, true).timeout.connect(func() -> void:
		# Keep trying while the song is still wanted.
		if track == _current:
			_fetch(track))


## How many times a song's download failed (tests).
func tries(track: String) -> int:
	return int(_tries.get(track, 0))


func _got(track: String, bytes: PackedByteArray, save: bool) -> bool:
	var st := AudioStreamOggVorbis.load_from_buffer(bytes)
	if st == null:
		return false
	_streamed[track] = st
	_touch_streamed(track)
	if save:
		DirAccess.make_dir_recursive_absolute("user://mcache")
		_drop_old_versions(track)
		var f := FileAccess.open(_cache_path(track), FileAccess.WRITE)
		if f:
			f.store_buffer(bytes)
			f.close()
		_cache_used(track)
		_trim_cache()
	if _prefetching == track:
		_prefetching = ""
	_queue.erase(track)
	if _current == track and _now != track:
		_start(st, track)
	_trim_streamed()
	_prefetch_next.call_deferred()
	return true


func _touch_streamed(t: String) -> void:
	_streamed_order.erase(t)
	_streamed_order.append(t)


## Keep only a few downloaded songs in memory (phones kill big tabs).
func _trim_streamed() -> void:
	var fading_name := ""
	if _fading != null and _fading.playing:
		for k: String in _streamed:
			if _streamed[k] == _fading.stream:
				fading_name = k
	var i := 0
	while _streamed.size() > STREAMED_KEEP and i < _streamed_order.size():
		var t: String = _streamed_order[i]
		if t == _now or t == _current or t == fading_name:
			i += 1
			continue
		_streamed.erase(t)
		_streamed_order.remove_at(i)
	for t2: String in _streamed_order.duplicate():
		if not _streamed.has(t2):
			_streamed_order.erase(t2)


## Downloaded songs held in memory (tests).
func streamed_count() -> int:
	return _streamed.size()


# ---- the song cache: user://mcache/<name>.<ver>.ogg, LRU-capped ----
const CACHE_INDEX := "user://mcache/index.json"
var _cindex := {}
var _cindex_loaded := false


func _cache_index() -> Dictionary:
	if not _cindex_loaded:
		_cindex_loaded = true
		if FileAccess.file_exists(CACHE_INDEX):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(CACHE_INDEX))
			if d is Dictionary:
				_cindex = d
	return _cindex


func _cache_used(t: String) -> void:
	_cache_index()[t] = Time.get_unix_time_from_system()
	DirAccess.make_dir_recursive_absolute("user://mcache")
	var f := FileAccess.open(CACHE_INDEX, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_cindex))


## Other versions of a song (and the old unversioned file) go when a new one lands.
func _drop_old_versions(t: String) -> void:
	var keep := _cache_path(t).get_file()
	var da := DirAccess.open("user://mcache")
	if da == null:
		return
	for fn: String in da.get_files():
		if fn == keep or not fn.ends_with(".ogg"):
			continue
		var base := fn.trim_suffix(".ogg")
		var dot := base.rfind(".")
		var nm := base.substr(0, dot) if dot > 0 and base.substr(dot + 1).length() == 8 else base
		if nm == t:
			da.remove(fn)


## Keep the cache under cache_cap: the least recently used songs go first, the
## current arc's prefetch songs and the song playing last.
func _trim_cache() -> void:
	var da := DirAccess.open("user://mcache")
	if da == null:
		return
	var files: Array = []
	var total := 0
	for fn: String in da.get_files():
		if not fn.ends_with(".ogg"):
			continue
		var f := FileAccess.open("user://mcache/" + fn, FileAccess.READ)
		var sz := f.get_length() if f else 0
		total += sz
		var base := fn.trim_suffix(".ogg")
		var dot := base.rfind(".")
		var nm := base.substr(0, dot) if dot > 0 and base.substr(dot + 1).length() == 8 else base
		files.append([nm, fn, sz])
	if total <= cache_cap:
		return
	var idx := _cache_index()
	var arc_list: Array = []
	if not GameState.run.is_empty():
		arc_list = PREFETCH_PENGUIN if GameState.is_penguins() else PREFETCH_GANG
	files.sort_custom(func(a: Array, b: Array) -> bool:
		var ka: float = float(idx.get(a[0], 0.0)) + (1e12 if a[0] in arc_list else 0.0)
		var kb: float = float(idx.get(b[0], 0.0)) + (1e12 if b[0] in arc_list else 0.0)
		return ka < kb)
	for e: Array in files:
		if total <= cache_cap:
			break
		if e[0] == _now or e[0] == _current:
			continue
		da.remove(str(e[1]))
		idx.erase(e[0])
		total -= int(e[2])


var _prefetching := ""


func _prefetch_next() -> void:
	if _prefetching != "" or not _fetching.is_empty() or _base_url() == "" or _silent():
		return
	var list: Array = _queue.duplicate()
	if GameState.run.is_empty():
		list.append_array(PREFETCH_TITLE)
	else:
		list.append_array(PREFETCH_PENGUIN if GameState.is_penguins() else PREFETCH_GANG)
	list.append_array(PREFETCH)
	for t: String in list:
		if t in _stream_list() and not _streamed.has(t) and int(_tries.get(t, 0)) < 2:
			if FileAccess.file_exists(_cache_path(t)):
				_queue.erase(t)
				continue  # cached from an earlier visit
			_prefetching = t
			_fetch(t)
			return
		_queue.erase(t)


func _load_sfx(name: String) -> AudioStream:
	if not _sfx_cache.has(name):
		# A real recording/ACE sound (.ogg, plus _2/_3 takes) wins over the generated placeholder (.wav).
		var takes: Array = []
		for suf: String in ["", "_2", "_3"]:
			var real := "res://audio/sfx/%s%s.ogg" % [name, suf]
			if ResourceLoader.exists(real):
				takes.append(load(real))
		if takes.is_empty():
			var path := "res://audio/sfx/%s.wav" % name
			if ResourceLoader.exists(path):
				takes.append(load(path))
		_sfx_cache[name] = takes
	var t: Array = _sfx_cache[name]
	if t.is_empty():
		return null
	return t[randi() % t.size()]


## True when a sound of this name exists (any take).
func has_sfx(name: String) -> bool:
	return _load_sfx(name) != null


func _group_db(name: String) -> float:
	if GROUP_EXACT.has(name):
		return float(GROUP_EXACT[name])
	for k: String in GROUP_DB:
		if name.begins_with(k):
			return float(GROUP_DB[k])
	return 0.0


## Play a sound effect. If it doesn't exist yet, `fallback` plays instead.
var _last_sfx := {}


func sfx(name: String, fallback := "") -> void:
	# Big moments buzz even with the sound off (Haptics.JINGLES whitelist, C9 P4).
	Haptics.from_sfx(name)
	if _muted or _sfx.is_empty():
		return
	# Gangster arc: money is cash, so coin clinks become bills (Money.SFX).
	name = Money.sfx_name(name)
	# The same sound twice within 70 ms is one sound (a burst of pickups mustn't eat every voice).
	var now := Time.get_ticks_msec()
	if now - int(_last_sfx.get(name, -1000)) < 70:
		return
	_last_sfx[name] = now
	var st := _load_sfx(name)
	if st == null and fallback != "":
		st = _load_sfx(fallback)
	if st == null:
		return
	var ln := st.get_length()
	var jingle := _is_jingle(name)
	var pick := _voice_for()
	var vi := _sfx.find(pick)
	pick.stream = st
	pick.volume_db = -4.0 + _group_db(name)
	# A little pitch drift so repeated swings and steps don't sound stamped out;
	# UI clicks, money and musical cues stay in key.
	pick.pitch_scale = 1.0 if (ln > 0.55 or _no_drift(name)) else randf_range(0.93, 1.07)
	pick.play()
	_voice_t[vi] = now
	_voice_long[vi] = jingle or ln > 1.0
	if jingle and ln > 0.8:
		# The song dips under a jingle (two pieces of music at once clash).
		set_duck_layer("jingle", JINGLE_DUCK, 0.12, 0.8, ln)


## A free voice, else the oldest one playing a short sound, else the oldest.
func _voice_for() -> AudioStreamPlayer:
	for p in _sfx:
		if not p.playing:
			return p
	var best := -1
	for i in _sfx.size():
		if _voice_long[i]:
			continue
		if best < 0 or int(_voice_t[i]) < int(_voice_t[best]):
			best = i
	if best < 0:
		for i in _sfx.size():
			if best < 0 or int(_voice_t[i]) < int(_voice_t[best]):
				best = i
	return _sfx[best]


static func _is_jingle(name: String) -> bool:
	if name in ["j_buy", "j_confirm"]:
		return false
	return name.begins_with("j_") or name in JINGLE_NAMES


static func _no_drift(name: String) -> bool:
	for k: String in NO_DRIFT:
		if name.begins_with(k):
			return true
	return false


## Footstep level, and per ground on top: grass and leaves are a soft swish.
const STEP_DB := -10.0  # footsteps were ~-41 LUFS, under every bed (c6_06)
const STEP_GROUND_DB := {"grass": -4.0, "leaves": -3.0, "sand": -2.0, "snow": -2.0, "gravel": -2.0, "mud": -2.0, "dirt": -1.0, "stone": -1.0, "wood": -1.5, "water": -1.0}
## A step may cut the previous one's tail after this long (long gravel/leaf takes
## used to swallow every other step).
const STEP_MIN := 0.18


## Footsteps get their own voice so they never block hits.
func step(ground: String) -> void:
	if _muted or _steps == null:
		return
	if _steps.playing and _steps.get_playback_position() < STEP_MIN:
		return
	var st := _load_sfx("step_" + ground)
	if st == null:
		st = _load_sfx("step_grass")
	if st == null:
		return
	_steps.stream = st
	# Small drift only: wide pitch swings made some steps boom like boots.
	_steps.pitch_scale = randf_range(0.95, 1.05)
	_steps.volume_db = STEP_DB + float(STEP_GROUND_DB.get(ground, 0.0)) + randf_range(-0.8, 0.8)
	_steps.play()


## The environment duck (Ambience: night sounds and storms come through). It is
## one layer: jingles, the battle card and dialogue dip on their own layers, and
## combat/boss songs ignore it.
func set_duck(db: float) -> void:
	_duck = db


## After a play-once track (an ending) finishes, play these in order.
var _after: Array = []


## `track` "" clears the queue; `append` adds after what is already queued.
func queue_after(track: String, append := false) -> void:
	if track == "":
		_after = []
	elif append:
		_after.append(track)
	else:
		_after = [track]


func _on_finished(pl: AudioStreamPlayer) -> void:
	if pl != _player or not (_current in ONCE):
		return
	if not _after.is_empty():
		var nx: String = _after.pop_front()
		var rest := _after.duplicate()
		play(nx)
		_after = rest
		return
	# Nothing queued: hand back (DangerMusic plays the area song at once).
	_current = ""
	_now = ""
	_hold = ""


func stop_all() -> void:
	if _player:
		_player.stop()
		_fading.stop()
	_current = ""
	_now = ""
	_hold = ""


func toggle_mute() -> bool:
	_muted = not _muted
	SaveGame.set_value("muted", _muted)
	if _player == null:
		return _muted
	# The Master bus mute silences everything; songs keep their place (no restart).
	_apply_master_mute()
	if not _muted:
		if _player.stream and not _player.playing and not (_now in ONCE):
			_player.play()
		audio_changed()
	return _muted


func is_muted() -> bool:
	return _muted


func _apply_master_mute() -> void:
	var mi := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(mi, _muted or _bg_muted)


## A dialogue blip on its own voice: every speaker keeps their own pitch (from
## their name), so voices are told apart without words, and a blip never cuts a
## jingle or a hit.
func blip(who: String) -> void:
	if _muted or _blip == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_sfx.get("talk_blip", -1000)) < 70:
		return
	_last_sfx["talk_blip"] = now
	var st := _load_sfx("talk_blip")
	if st == null:
		return
	_blip.stream = st
	_blip.volume_db = -4.0 + _group_db("talk_blip")
	var h := absi(who.hash()) % 1000
	_blip.pitch_scale = 0.8 + 0.5 * float(h) / 1000.0 if who != "" else 1.0
	_blip.play()


# ---- background: the app or page hidden -> silent (unless Sound in background is on) ----
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			set_background(true)
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			set_background(false)


func set_background(hidden: bool) -> void:
	_bg_muted = hidden and not bool(Settings.get_v("bg_sound"))
	if _player != null:
		_apply_master_mute()


var _vis_cb: JavaScriptObject


func _web_visibility_hook() -> void:
	if not OS.has_feature("web"):
		return
	_vis_cb = JavaScriptBridge.create_callback(func(_args: Array) -> void:
		var hid: Variant = JavaScriptBridge.eval("document.hidden", true)
		set_background(bool(hid)))
	var doc := JavaScriptBridge.get_interface("document")
	if doc != null:
		doc.addEventListener("visibilitychange", _vis_cb)


## Where a song loops back to (s): the end of its quiet intro, written by
## tools/ace_import.py into data/music_loops.json ({"track": seconds}; absent = 0).
## The file's tail is crossfaded into that point, so it must be applied.
static var _loops: Dictionary = {}
static var _loops_read := false


static func loop_point(track: String) -> float:
	if not _loops_read:
		_loops_read = true
		var f := FileAccess.open("res://data/music_loops.json", FileAccess.READ)
		if f:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_loops = d
	return float(_loops.get(track, 0.0))

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
const MUSIC_DB := -8.0
const FADE := 0.9
var _current := ""
var _muted := false
var _tw_out: Tween
var _tw_in: Tween
var _sfx_cache := {}
var _steps: AudioStreamPlayer
var _duck := 0.0
var _next_voice := 0


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
	_fading.volume_db = MUSIC_DB
	add_child(_fading)
	_player.finished.connect(_on_finished.bind(_player))
	_fading.finished.connect(_on_finished.bind(_fading))
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -4.0
		p.bus = "SFX"
		add_child(p)
		_sfx.append(p)
	_steps = AudioStreamPlayer.new()
	_steps.bus = "SFX"
	_steps.volume_db = -14.0
	add_child(_steps)
	_muted = bool(SaveGame.get_value("muted", false))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), _muted)
	if _pending != "":
		var t := _pending
		_pending = ""
		play(t)


var _pending := ""
## Tracks that play once (endings, credits, the lullaby scene) instead of looping.
const ONCE := ["ending_penguin", "ending_gangster", "credits", "merkitty_song"]
## Loudness by kind of effect, on top of each file's own level (dB).
const GROUP_DB := {"ui_": -9.0, "menu_": -8.0, "page": -6.0, "equip": -6.0, "talk_blip": -10.0, "keypress": -10.0,
	"step_": 0.0, "coin": -3.0, "pickup": -3.0, "j_": 0.0, "levelup": 0.0, "quest_done": 0.0}


func play(track: String) -> void:
	if _player == null:
		_pending = track
		return
	if track == _current:
		return
	_current = track
	var path := "res://audio/music/%s.ogg" % track
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	elif _streamed.has(track):
		stream = _streamed[track]
	elif track in _stream_list():
		# Web build: this song isn't in the download; fetch it (or read our cached copy), then play.
		_player.stop()
		_fetch(track)
		return
	if stream == null:
		_player.stop()
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = not (track in ONCE)
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
		_tw_out = create_tween()
		_tw_out.tween_property(old, "volume_db", -40.0, FADE)
		_tw_out.tween_callback(old.stop)
	_player.stream = stream
	_player.volume_db = -30.0
	if not _muted:
		_player.play()
		_tw_in = create_tween()
		_tw_in.tween_property(_player, "volume_db", MUSIC_DB + _duck, FADE)


# ---- streamed music (web): data/music_stream.json lists songs kept outside the pack ----
var _streamed := {}
var _fetching := {}
static var _stream_names: Array = []


static func _stream_list() -> Array:
	if _stream_names.is_empty() and FileAccess.file_exists("res://data/music_stream.json"):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/music_stream.json"))
		if d is Dictionary:
			_stream_names = (d as Dictionary).get("stream", [])
	return _stream_names


## A song exists: in the pack, or streamed on the web build.
static func has_track(t: String) -> bool:
	return ResourceLoader.exists("res://audio/music/%s.ogg" % t) or t in _stream_list()


func _fetch(track: String) -> void:
	var cache := "user://mcache/%s.ogg" % track
	if FileAccess.file_exists(cache):
		_got(track, FileAccess.get_file_as_bytes(cache), false)
		return
	if _fetching.has(track):
		return
	var rq := HTTPRequest.new()
	add_child(rq)
	_fetching[track] = rq
	rq.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		_fetching.erase(track)
		rq.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200 and body.size() > 1000:
			_got(track, body, true))
	if rq.request("music/%s.ogg" % track) != OK:
		_fetching.erase(track)
		rq.queue_free()


func _got(track: String, bytes: PackedByteArray, save: bool) -> void:
	var st := AudioStreamOggVorbis.load_from_buffer(bytes)
	if st == null:
		return
	_streamed[track] = st
	if save:
		DirAccess.make_dir_recursive_absolute("user://mcache")
		var f := FileAccess.open("user://mcache/%s.ogg" % track, FileAccess.WRITE)
		if f:
			f.store_buffer(bytes)
	if _current == track:
		_current = ""
		play(track)


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
	for k: String in GROUP_DB:
		if name.begins_with(k):
			return float(GROUP_DB[k])
	return 0.0


## Play a sound effect. If it doesn't exist yet, `fallback` plays instead.
var _last_sfx := {}


func sfx(name: String, fallback := "") -> void:
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
	var pick: AudioStreamPlayer = null
	for p in _sfx:
		if not p.playing:
			pick = p
			break
	if pick == null:
		# All voices busy: take over the oldest one rather than dropping the sound.
		pick = _sfx[_next_voice % _sfx.size()]
		_next_voice += 1
	pick.stream = st
	pick.volume_db = -4.0 + _group_db(name)
	# A little pitch drift so repeated swings and steps don't sound stamped out.
	pick.pitch_scale = 1.0 if (st.get_length() > 0.45 or name.begins_with("j_") or name in ["craft_done", "mail", "coin", "levelup", "quest_done"]) else randf_range(0.93, 1.07)  # jingles stay in key
	pick.play()


## Footsteps get their own voice so they never block hits.
func step(ground: String) -> void:
	if _muted or _steps == null or _steps.playing:
		return
	var st := _load_sfx("step_" + ground)
	if st == null:
		st = _load_sfx("step_grass")
	if st == null:
		return
	_steps.stream = st
	_steps.pitch_scale = randf_range(0.85, 1.15)
	_steps.play()


## Dip the music (dB below normal) so night sounds and storms come through.
func set_duck(db: float) -> void:
	if is_equal_approx(db, _duck) or _player == null:
		return
	_duck = db
	if _tw_in and _tw_in.is_valid():
		_tw_in.kill()
	create_tween().tween_property(_player, "volume_db", MUSIC_DB + _duck, 2.0)


## After a play-once track (an ending) finishes, play this one.
var _after := ""


func queue_after(track: String) -> void:
	_after = track


func _on_finished(pl: AudioStreamPlayer) -> void:
	if pl == _player and _current in ONCE and _after != "":
		var nx := _after
		_after = ""
		play(nx)


func stop_all() -> void:
	if _player:
		_player.stop()
		_fading.stop()
	_current = ""


func toggle_mute() -> bool:
	_muted = not _muted
	if _player == null:
		SaveGame.set_value("muted", _muted)
		return _muted
	SaveGame.set_value("muted", _muted)
	var mi := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(mi, _muted)
	if _muted:
		_player.stop()
		_fading.stop()
	elif _player.stream:
		_player.volume_db = MUSIC_DB + _duck
		_player.play()
	return _muted


## A dialogue blip: every speaker keeps their own pitch (from their name), so
## voices are told apart without words.
func blip(who: String) -> void:
	if _muted or _sfx.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_sfx.get("talk_blip", -1000)) < 70:
		return
	_last_sfx["talk_blip"] = now
	var st := _load_sfx("talk_blip")
	if st == null:
		return
	var pick: AudioStreamPlayer = _sfx[_next_voice % _sfx.size()]
	_next_voice += 1
	pick.stream = st
	pick.volume_db = -4.0 + _group_db("talk_blip")
	var h := absi(who.hash()) % 1000
	pick.pitch_scale = 0.8 + 0.5 * float(h) / 1000.0 if who != "" else 1.0
	pick.play()

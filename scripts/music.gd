class_name Music
extends Node
## Plays looping music per area and short sound effects. Tracks live in
## audio/music/<name>.ogg and audio/sfx/<name>.wav (generated placeholders for now;
## real tracks drop in with the same names).

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
	Settings.apply_audio()
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	_player.volume_db = MUSIC_DB
	add_child(_player)
	_fading = AudioStreamPlayer.new()
	_fading.bus = "Music"
	_fading.volume_db = MUSIC_DB
	add_child(_fading)
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


func play(track: String) -> void:
	if _player == null:
		_pending = track
		return
	if track == _current:
		return
	_current = track
	var path := "res://audio/music/%s.ogg" % track
	if not ResourceLoader.exists(path):
		_player.stop()
		return
	var stream := load(path) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
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


func _load_sfx(name: String) -> AudioStream:
	if not _sfx_cache.has(name):
		var path := "res://audio/sfx/%s.wav" % name
		_sfx_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _sfx_cache[name]


## Play a sound effect. If it doesn't exist yet, `fallback` plays instead.
func sfx(name: String, fallback := "") -> void:
	if _muted or _sfx.is_empty():
		return
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
	# A little pitch drift so repeated swings and steps don't sound stamped out.
	pick.pitch_scale = randf_range(0.93, 1.07)
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
		return
	create_tween().tween_property(_player, "volume_db", MUSIC_DB + _duck, 2.0)


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
		_player.volume_db = MUSIC_DB
		_player.play()
	return _muted

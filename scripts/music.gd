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


static func instance(tree: SceneTree) -> Music:
	if _inst == null or not is_instance_valid(_inst):
		_inst = Music.new()
		_inst.name = "Music"
		tree.root.add_child(_inst)
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
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.volume_db = -4.0
		p.bus = "SFX"
		add_child(p)
		_sfx.append(p)
	_muted = bool(SaveGame.get_value("muted", false))


func play(track: String) -> void:
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
		_tw_in.tween_property(_player, "volume_db", MUSIC_DB, FADE)


func sfx(name: String) -> void:
	if _muted:
		return
	var path := "res://audio/sfx/%s.wav" % name
	if not ResourceLoader.exists(path):
		return
	if not _sfx_cache.has(name):
		_sfx_cache[name] = load(path)
	for p in _sfx:
		if not p.playing:
			p.stream = _sfx_cache[name]
			# A little pitch drift so repeated swings and steps don't sound stamped out.
			p.pitch_scale = randf_range(0.93, 1.07)
			p.play()
			return


func toggle_mute() -> bool:
	_muted = not _muted
	SaveGame.set_value("muted", _muted)
	if _muted:
		_player.stop()
		_fading.stop()
	elif _player.stream:
		_player.volume_db = MUSIC_DB
		_player.play()
	return _muted

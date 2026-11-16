class_name Music
extends Node
## Plays looping music per area and short sound effects. Tracks live in
## audio/music/<name>.ogg and audio/sfx/<name>.wav (generated placeholders for now;
## real tracks drop in with the same names).

static var _inst: Music
var _player: AudioStreamPlayer
var _sfx: Array[AudioStreamPlayer] = []
var _current := ""
var _muted := false


static func instance(tree: SceneTree) -> Music:
	if _inst == null or not is_instance_valid(_inst):
		_inst = Music.new()
		_inst.name = "Music"
		tree.root.add_child(_inst)
	return _inst


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.volume_db = -8.0
	add_child(_player)
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.volume_db = -4.0
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
	_player.stream = stream
	if not _muted:
		_player.play()


func sfx(name: String) -> void:
	if _muted:
		return
	var path := "res://audio/sfx/%s.wav" % name
	if not ResourceLoader.exists(path):
		return
	for p in _sfx:
		if not p.playing:
			p.stream = load(path)
			p.play()
			return


func toggle_mute() -> bool:
	_muted = not _muted
	SaveGame.set_value("muted", _muted)
	if _muted:
		_player.stop()
	elif _player.stream:
		_player.play()
	return _muted

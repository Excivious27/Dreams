class_name RecAudio
extends Node
## Rec Center sound (CONDUCT 2, c2_08): the bowling lane's rolling ball, pin
## clatter graded by how many pins go down, the pit and the ball return; the
## rooms' ambience beds and spot sounds; the jukebox's records and their names.
## Sounds come from tools/make_rec_audio.py (CC0 recordings) and ACE songs.
##
##   RecAudio.attach_bowling(game)   Bowling._ready: follows game.phase / game.sim
##   RecAudio.beds(kind)             Ambience: {bed: dB} for "rec" / "rec_up"
##   RecAudio.spots(kind)            Ambience: [[spot, min_s, max_s, dB], ...]
##   RecAudio.record_name(track)     the jukebox label for a song

## Ambience beds per room. Downstairs is the arcade (cabinets in attract mode,
## coins, chatter) with the lanes muffled through the ceiling; upstairs the lanes
## are all around and the arcade is a murmur from the stairwell.
const BEDS := {
	"rec": {"arcade_floor": -19.0, "rec_alley": -22.0},
	"rec_up": {"rec_alley": -10.0, "arcade_floor": -27.0},
}
## Spot sounds per room: [spot, min seconds, max seconds, dB].
const SPOTS := {
	"rec": [["pins_far", 12.0, 30.0, -14.0], ["cabinet_win", 20.0, 45.0, -16.0]],
	"rec_up": [["pins_near", 9.0, 24.0, -15.0], ["cabinet_win", 40.0, 90.0, -26.0]],
}
## The jukebox's records (track -> label). Order = the order A steps through.
const RECORDS := {
	"rec_center": "House Groove",
	"jukebox_oldie": "Nickel Record",
	"bowling_alley": "Ten Pin Strut",
	"arcade_hall": "High Score Hall",
	"neon": "Neon Avenue",
	"festival": "Festival Lights",
	"inn": "Hearthside Waltz",
	"town": "Main Street",
	"beach": "Low Tide",
	"uptown": "Uptown Strut",
	"countryside": "Country Mile",
}


## Beds follow the lanes (CONDUCT 6): the rolling-ball bed is near silent with every
## lane empty and full with two or more bowlers.
static func beds(kind: String) -> Dictionary:
	var out := (BEDS.get(kind, {}) as Dictionary).duplicate()
	if out.has("rec_alley"):
		out["rec_alley"] = float(out["rec_alley"]) + alley_trim(RecCenter.lanes_taken().size())
	return out


## dB added to the rec_alley bed for n villager lanes in use.
static func alley_trim(n: int) -> float:
	return -12.0 if n <= 0 else (-5.0 if n == 1 else 0.0)


## Pin crashes only when somebody is actually bowling.
static func spots(kind: String) -> Array:
	var out := (SPOTS.get(kind, []) as Array).duplicate(true)
	if RecCenter.lanes_taken().is_empty():
		out = out.filter(func(s: Array) -> bool: return not str(s[0]).begins_with("pins_"))
	return out


static func record_name(track: String) -> String:
	return str(RECORDS.get(track, track.capitalize()))


static func records() -> Array:
	return RECORDS.keys()


## A villager's ball on a lane in the room (RecDecor): the roll, then the pins,
## heard from where the lane is (quieter across the room, panned).
## what: "roll" or "hit" (hits = pins knocked, 10 = strike). Returns the sound name.
static func lane_sound(at: Node2D, pos: Vector2, what: String, hits := 0) -> String:
	var nm := "bowl_rumble" if what == "roll" else ("pin_strike" if hits >= 10 else ("pin_crash" if hits >= 3 else "pin_tap"))
	var m := Music._inst
	if m == null or not is_instance_valid(m) or m._muted or not at.is_inside_tree():
		return nm
	var takes: Array = []
	for suf: String in ["", "_2", "_3"]:
		if ResourceLoader.exists("res://audio/sfx/%s%s.ogg" % [nm, suf]):
			takes.append("res://audio/sfx/%s%s.ogg" % [nm, suf])
	if takes.is_empty():
		return nm
	var p := AudioStreamPlayer2D.new()
	p.stream = load(str(takes[randi() % takes.size()]))
	p.bus = "SFX"
	p.volume_db = -12.0 if what == "roll" else -7.0
	p.panning_strength = Settings.pan()  # c13_17-01 mono audio
	p.max_distance = 360.0
	p.attenuation = 1.5
	p.position = pos
	at.add_child(p)
	p.finished.connect(p.queue_free)
	if what == "roll":
		# Capture a weakref, never the player: a lambda whose captured node was freed
		# (map changed, sound ended) errors "Lambda capture ... was freed" (c3_17 #2).
		var wr: WeakRef = weakref(p)
		at.get_tree().create_timer(1.55, false).timeout.connect(func() -> void:
			var pp := wr.get_ref() as AudioStreamPlayer2D
			if pp != null and is_instance_valid(pp) and pp.is_inside_tree():
				create_fade(pp))
	p.play()
	return nm


## The next lane's villager ball, graded like the player's own: tap (1-2),
## crash (3-9), strike (10), gutter (0).
static func opp_roll(v: int) -> String:
	if v >= 10:
		return "pin_strike"
	if v >= 3:
		return "pin_crash"
	if v > 0:
		return "pin_tap"
	return "bowl_gutter"


## Fade a lane rumble out as the ball reaches the pins.
static func create_fade(p: AudioStreamPlayer2D) -> void:
	var tw := p.create_tween()
	tw.tween_property(p, "volume_db", -40.0, 0.2)
	tw.tween_callback(p.queue_free)


# --- bowling ----------------------------------------------------------------------

## Levels (dB) on top of each file's softened level.
const ROLL_DB := -6.0
const GUTTER_DB := -5.0
const PIT_DB := -10.0
const RETURN_DB := -12.0

var game: Node = null
var _roll: AudioStreamPlayer
var _shots: Array[AudioStreamPlayer] = []
var _phase := ""
var _down := 0          # pins down (or gone) at the last look
var _start_up := 10     # pins standing when this ball was thrown
var _pend := 0          # pins fallen in the current little window
var _pend_t := 0.0
var _struck := false
var _first_done := false
var _gutter := false
var _hit := false
var _pit := false
var _roll_fade := 0.0   # > 0 while the rumble fades out
## Test hook: every sound this node played, in order.
var heard: Array[String] = []


static func attach_bowling(g: Node) -> RecAudio:
	var r := RecAudio.new()
	r.name = "RecAudio"
	r.game = g
	g.add_child(r)
	return r


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the bowling screen pauses the tree
	_roll = AudioStreamPlayer.new()
	_roll.bus = "SFX"
	add_child(_roll)
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_shots.append(p)


func _muted() -> bool:
	var m := Music._inst
	return m != null and is_instance_valid(m) and m._muted


func _stream(name: String) -> AudioStream:
	var takes: Array = []
	for suf: String in ["", "_2", "_3"]:
		var p := "res://audio/sfx/%s%s.ogg" % [name, suf]
		if ResourceLoader.exists(p):
			takes.append(p)
	return load(str(takes[randi() % takes.size()])) if not takes.is_empty() else null


## A one-shot on our own voices (the shared Music voices stay free for UI).
func shot(name: String, db: float, pitch := 1.0) -> void:
	heard.append(name)
	if _muted():
		return
	var st := _stream(name)
	if st == null:
		return
	var pick: AudioStreamPlayer = _shots[0]
	for p in _shots:
		if not p.playing:
			pick = p
			break
	pick.stream = st
	pick.volume_db = db
	pick.pitch_scale = pitch
	pick.play()


func _count_down() -> int:
	var n := 0
	for p: Dictionary in game.sim.pins:
		if bool(p["down"]) or bool(p["gone"]):
			n += 1
	return n


func _process(delta: float) -> void:
	if game == null or not is_instance_valid(game):
		return
	var ph := str(game.phase)
	if ph != _phase:
		_phase_changed(_phase, ph)
		_phase = ph
	if ph == "roll":
		_follow_roll(delta)
	if _roll_fade > 0.0:
		_roll_fade -= delta
		_roll.volume_db -= delta * 60.0
		if _roll_fade <= 0.0:
			_roll.stop()


func _phase_changed(from: String, to: String) -> void:
	if to == "roll":
		_down = _count_down()
		_start_up = 10 - _down
		_pend = 0
		_pend_t = 0.0
		_struck = false
		_first_done = false
		_gutter = false
		_hit = false
		_pit = false
		_start_roll()
	elif from == "roll":
		_flush()
		_fade_roll(0.2)
	if to == "line" and from in ["result", "sweep", "opp"] and not (game.rolls as Array).is_empty():
		shot("ball_return", RETURN_DB)  # the ball rumbles back up the return


func _start_roll() -> void:
	heard.append("bowl_rumble")
	_roll_fade = 0.0
	if _muted():
		return
	var st := _stream("bowl_rumble")
	if st == null:
		return
	if st is AudioStreamOggVorbis:
		st = (st as AudioStreamOggVorbis).duplicate()
		(st as AudioStreamOggVorbis).loop = true
		(st as AudioStreamOggVorbis).loop_offset = 0.5  # skip the release thump on the way round
	_roll.stream = st
	_roll.volume_db = ROLL_DB
	_roll.pitch_scale = 1.0
	_roll.play()


func _fade_roll(secs: float) -> void:
	if _roll.playing and _roll_fade <= 0.0:
		_roll_fade = secs


func _follow_roll(delta: float) -> void:
	# The file ends in a fade: wrap before it (a slow ball heard a dropout at the loop).
	if _roll.playing and _roll.stream and _roll.get_playback_position() > _roll.stream.get_length() - 0.35:
		_roll.seek(0.5)
	var sim: Variant = game.sim
	var spd: float = (sim.ball_v as Vector2).length()
	if _roll.playing and _roll_fade <= 0.0:
		# Faster balls are louder and brighter; the slow-motion finish drops the pitch.
		var slow: float = float(game.get("_slowmo")) if game.get("_slowmo") != null else 1.0
		_roll.pitch_scale = clampf(0.82 + spd / 1400.0, 0.8, 1.15) * (0.86 if slow < 1.0 else 1.0)
		_roll.volume_db = ROLL_DB + clampf((spd - 300.0) / 40.0, -4.0, 2.0) - (6.0 if bool(sim.gutter) else 0.0)
	if bool(sim.gutter) and not _gutter:
		_gutter = true
		shot("bowl_gutter", GUTTER_DB)
	if bool(sim.hit_any) and not _hit:
		_hit = true
		_fade_roll(0.25)
	if not _pit and (sim.ball_p as Vector2).y >= Bowling.Sim.PIT_Y:
		_pit = true
		shot("bowl_pit", PIT_DB - (4.0 if bool(sim.hit_any) else 0.0))
		_fade_roll(0.15)
	# Pins: gather falls over a few hundredths of a second, then one sound sized to them.
	var d := _count_down()
	if d > _down:
		_pend += d - _down
		_down = d
		if _pend_t <= 0.0:
			# The first burst gets a longer window: a rack goes down over a fifth of a second.
			_pend_t = 0.07 if _first_done else 0.18
	if _pend_t > 0.0:
		_pend_t -= delta
		if _pend_t <= 0.0:
			_flush()


func _flush() -> void:
	if _pend <= 0:
		return
	var n := _pend
	_pend = 0
	_pend_t = 0.0
	var all_down := _down >= 10
	_first_done = true
	if not _struck and _start_up == 10 and n >= 7:
		_struck = true  # the ball ploughing into a full rack: the big crash
		shot("pin_strike", -3.0)
	elif n >= 3 or (all_down and n >= 2):
		shot("pin_crash", -3.0)
	else:
		shot("pin_tap", -4.0 + float(n - 1) * 1.5, randf_range(0.94, 1.06))

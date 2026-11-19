extends SceneTree
## Rec Center audio (c2_08): room beds/spots and jukebox records all exist, the
## jukebox steps to a new named record, rooms get their songs, and the bowling
## lane plays roll -> pins (sized to the fall) -> pit, the gutter rumble and the
## ball return.
##   godot --headless --path . -s res://tools/rec_audio_test.gd
var fails := 0

const FAKE := """extends Node
var phase := "line"
var sim = null
var rolls: Array = []
var _slowmo := 1.0
"""


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("  FAIL ", what)


func _has_amb(n: String) -> bool:
	return ResourceLoader.exists("res://audio/amb/%s.ogg" % n)


func _run() -> void:
	InputSetup.ensure_actions()
	# --- data: every bed, spot, record and lane sound exists ---
	for kind in ["rec", "rec_up"]:
		ok(not RecAudio.beds(kind).is_empty(), "%s has beds" % kind)
		for b: String in RecAudio.beds(kind):
			ok(_has_amb(b), "bed %s exists" % b)
		for s: Array in RecAudio.spots(kind):
			ok(_has_amb("spot_" + str(s[0])), "spot %s exists" % s[0])
	ok(float(RecAudio.beds("rec")["arcade_floor"]) > float(RecAudio.beds("rec")["rec_alley"]), "downstairs: cabinets over the muffled lanes")
	ok(float(RecAudio.beds("rec_up")["rec_alley"]) > float(RecAudio.beds("rec_up")["arcade_floor"]), "upstairs: lanes over the arcade murmur")
	for t: String in RecAudio.records():
		ok(FileAccess.file_exists("res://audio/music/%s.ogg" % t), "record %s exists" % t)
		ok(RecAudio.record_name(t) != "" and RecAudio.record_name(t) != t, "record %s has a label" % t)
	ok(RecAudio.records().size() >= 10, "jukebox has 10+ records (%d)" % RecAudio.records().size())
	ok("bowling_alley" in RecAudio.records() and "jukebox_oldie" in RecAudio.records(), "new rec songs on the jukebox")
	for n in ["bowl_rumble", "bowl_gutter", "bowl_pit", "ball_return", "pin_tap", "pin_crash", "pin_strike", "juke_needle"]:
		ok(ResourceLoader.exists("res://audio/sfx/%s.ogg" % n), "sfx %s exists" % n)
	# --- rooms' songs ---
	var I: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/interiors.json"))
	ok(str(I["rec_up"]["music"]) == "bowling_alley", "bowling floor has its own song")
	ok(str(I["rec_up"]["gangsters"]["music"]) == "bowling_alley", "bowling floor song in the gangster arc too")
	ok(str(I["rec"]["music"]) == "rec_center", "arcade floor keeps the house song")
	# --- the lane: a good ball ---
	var heard := _bowl(0.0, 0.0, 370.0)
	ok(heard.size() > 0 and str(heard[0]) == "bowl_rumble", "roll starts with the rumble (%s)" % str(heard))
	ok("pin_strike" in heard or "pin_crash" in heard, "a full-power pocket ball crashes the rack (%s)" % str(heard))
	ok("bowl_pit" in heard, "the ball drops into the pit (%s)" % str(heard))
	ok(not ("bowl_gutter" in heard), "no gutter on a straight ball")
	ok(heard.count("pin_strike") <= 1, "one big crash per ball")
	# --- a strike: search a few pocket balls for one that clears the rack ---
	var strike: Array = []
	for x in [0.0, 2.0, -2.0, 3.0, -3.0, 1.0, -1.0, 4.0, -4.0]:
		for a in [0.0, 0.3, -0.3, 0.6, -0.6]:
			if strike.is_empty():
				var h := _bowl(x, a, 370.0)
				if int(h.back()) == 10:
					strike = h
	ok(not strike.is_empty(), "some pocket ball strikes")
	if not strike.is_empty():
		ok(strike.count("pin_strike") == 1, "a strike plays the big crash once (%s)" % str(strike))
		ok(strike.find("pin_strike") < strike.find("bowl_pit"), "the crash comes before the pit")
	# --- a gutter ball ---
	heard = _bowl(-16.0, -1.7, 300.0)
	ok("bowl_gutter" in heard, "gutter ball rumbles in the gutter (%s)" % str(heard))
	ok(not ("pin_strike" in heard or "pin_crash" in heard or "pin_tap" in heard), "gutter ball hits no pins")
	# --- a light touch on one corner pin ---
	var light := _bowl(14.0, 0.0, 240.0)
	ok(not ("pin_strike" in light), "a corner ball is no strike (%s)" % str(light))
	# --- villager lanes return the right sound ---
	var n2 := Node2D.new()
	root.add_child(n2)
	ok(RecAudio.lane_sound(n2, Vector2.ZERO, "hit", 10) == "pin_strike", "villager strike")
	ok(RecAudio.lane_sound(n2, Vector2.ZERO, "hit", 6) == "pin_crash", "villager 6 pins")
	ok(RecAudio.lane_sound(n2, Vector2.ZERO, "hit", 1) == "pin_tap", "villager 1 pin")
	ok(RecAudio.lane_sound(n2, Vector2.ZERO, "roll") == "bowl_rumble", "villager roll")
	print("rec_audio_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


## Throw one ball on a fresh rack and return what RecAudio played (incl. the return).
func _bowl(x0: float, aim: float, speed: float) -> Array:
	var sc := GDScript.new()
	sc.source_code = FAKE
	sc.reload()
	var g = Node.new()
	g.set_script(sc)
	g.sim = Bowling.Sim.new()
	g.sim.rng.seed = 7
	g.sim.rack()
	root.add_child(g)
	var r := RecAudio.attach_bowling(g)
	r._process(0.016)
	g.phase = "roll"
	g.sim.throw(x0, aim, speed, 0.0)
	r._process(0.016)
	var t := 0.0
	while not g.sim.done and t < 12.0:
		for i in 4:
			g.sim.step(1.0 / 240.0)
		r._process(1.0 / 60.0)
		t += 1.0 / 60.0
	for i in 10:
		r._process(1.0 / 60.0)
	g.rolls.append(10 - g.sim.standing())
	g.phase = "result"
	r._process(0.016)
	g.phase = "line"
	r._process(0.016)
	var out: Array = []
	out.append_array(r.heard)
	if OS.get_environment("V") != "":
		print("  ball x0=%.0f aim=%.1f v=%.0f -> %d down: %s" % [x0, aim, speed, 10 - g.sim.standing(), str(out)])
	ok(out.back() == "ball_return", "ball comes back up the return (%s)" % str(out))
	out.append(10 - g.sim.standing())  # last entry: pins down
	g.queue_free()
	return out

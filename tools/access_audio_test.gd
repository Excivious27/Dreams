extends SceneTree
## C13 P6 hearing accessibility: Voices/UI/Steps buses (send to SFX, default
## 0 dB), data/sfx_buses.json routing, Mono audio (Master StereoEnhance +
## positional panning 0), Loud sounds: softer (-6 dB on the LOUD list in code),
## Sound captions (Captions.for_sfx table, off by default, de-duped), and the
## Options rows exist in Settings.audio_rows.
##   godot --headless --path . --fixed-fps 60 -s res://tools/access_audio_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(13)
	_run.call_deferred()


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.load_data()
	for k: String in Settings.AUDIO_KEYS + Settings.AUDIO_FLAGS:
		Settings.set_v(k, Settings.DEFAULTS[k])
	var m := Music.instance(self)
	await process_frame
	await process_frame
	Settings.apply_audio()
	# Buses.
	for bn: String in ["Voices", "UI", "Steps"]:
		var bi := AudioServer.get_bus_index(bn)
		check(bi >= 0, "bus %s exists" % bn)
		check(AudioServer.get_bus_send(bi) == &"SFX", "bus %s sends to SFX" % bn)
		check(is_equal_approx(AudioServer.get_bus_volume_db(bi), 0.0), "bus %s at 0 dB by default" % bn)
	Settings.set_v("voice_vol", 5)
	check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Voices")) < -8.0, "Voices slider lowers its bus")
	Settings.set_v("ui_vol", 0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("UI")), "UI 0 mutes its bus")
	Settings.reset_audio(self)
	check(int(Settings.get_v("voice_vol")) == 8 and not AudioServer.is_bus_mute(AudioServer.get_bus_index("UI")), "reset puts the new sliders back")
	# Routing.
	check(Settings.sfx_bus("ui_tap") == "UI" and Settings.sfx_bus("scroll_tick") == "UI", "UI clicks route to UI")
	check(Settings.sfx_bus("step_grass") == "Steps" and Settings.sfx_bus("talk_blip") == "Voices" and Settings.sfx_bus("cv_merkitty") == "Voices", "steps/voices routing")
	check(Settings.sfx_bus("chop") == "SFX", "everything else stays on SFX")
	check(m._steps.bus == &"Steps" and m._blip.bus == &"Voices", "Music step/blip voices on their buses")
	m.sfx("ui_tap")
	var on_ui := false
	for p: AudioStreamPlayer in m._sfx:
		if p.stream != null and p.bus == &"UI":
			on_ui = true
	check(on_ui, "Music.sfx plays ui_tap on the UI bus")
	# Mono.
	var mi := AudioServer.get_bus_index("Master")
	var se := -1
	for i in AudioServer.get_bus_effect_count(mi):
		if AudioServer.get_bus_effect(mi, i) is AudioEffectStereoEnhance:
			se = i
	check(se >= 0 and not AudioServer.is_bus_effect_enabled(mi, se), "mono fold exists, off by default")
	check(is_equal_approx(Settings.pan(), 1.0), "full panning by default")
	Settings.set_v("mono", true)
	check(AudioServer.is_bus_effect_enabled(mi, se) and is_equal_approx(Settings.pan(), 0.0), "Mono audio on: fold enabled, panning 0")
	Settings.set_v("mono", false)
	# Loud sounds.
	check(Settings.loud_db("boom") == 0.0, "loud sounds normal by default")
	Settings.set_v("reduce_loud", true)
	check(Settings.loud_db("boom") == Settings.LOUD_DB and Settings.loud_db("shot_rifle") == Settings.LOUD_DB and Settings.loud_db("thunder") == Settings.LOUD_DB, "softer: boom, shots, thunder -6 dB")
	check(Settings.loud_db("ui_tap") == 0.0 and Settings.loud_db("chop") == 0.0, "softer leaves ordinary sounds alone")
	OS.delay_msec(90)  # Music.sfx de-dupes the same name within 70 real ms
	m.sfx("boom")
	var boom_db := 99.0
	for p: AudioStreamPlayer in m._sfx:
		if p.playing and p.stream != null and p.stream.resource_path.get_file().begins_with("boom"):
			boom_db = p.volume_db
	check(boom_db < -4.0 + m._group_db("boom") - 5.0, "Music.sfx applies the softer offset (%.1f)" % boom_db)
	Settings.set_v("reduce_loud", false)
	# Captions.
	Captions.log.clear()
	m.sfx("roar")
	check(Captions.log.is_empty(), "no captions while off")
	Settings.set_v("captions", true)
	OS.delay_msec(90)  # Music.sfx de-dupes the same name within 70 real ms
	m.sfx("roar")
	check(Captions.log.size() == 1 and str(Captions.log[0].text) == "Roar", "caption for roar")
	Captions.for_sfx("roar")
	check(Captions.log.size() == 1, "same caption within the gap is one line")
	Captions.for_sfx("ui_tap")
	Captions.for_sfx("step_grass")
	check(Captions.log.size() == 1, "UI clicks and steps never caption")
	Captions.for_sfx("siren_gang")
	check(Captions.log.size() == 2 and str(Captions.log[1].text) == "Siren", "gang take captions as its base")
	await process_frame
	var cap := Captions._layer()
	check(cap != null and cap.is_inside_tree() and cap._box.get_child_count() >= 1, "caption layer shows lines")
	for n: String in Captions.TABLE:
		check(m.has_sfx(n) or ResourceLoader.exists("res://audio/amb/spot_%s.ogg" % n) or ResourceLoader.exists("res://audio/amb/spot_%s.wav" % n) or n in ["knock", "howl_far", "ach_unlock", "energy_low", "war_horn", "war_drum", "j_morning", "j_heart", "j_victory", "j_battle_won", "j_battle_lost"], "caption name %s is a real sound" % n)
	Settings.set_v("captions", false)
	# Options rows.
	var box := VBoxContainer.new()
	root.add_child(box)
	Settings.audio_rows(box, self, func() -> void: pass)
	var words := []
	for c in box.get_children():
		if c is Button:
			words.append((c as Button).text)
		elif c is HBoxContainer:
			words.append(((c as HBoxContainer).get_child(0) as Label).text)
	var joined := " | ".join(words)
	for w: String in ["Mono audio", "Loud sounds", "Sound captions", "Voices volume", "Menu clicks volume", "Footsteps volume", "Effects volume"]:
		check(joined.contains(w), "Options row: %s" % w)
	box.queue_free()
	print("access_audio_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

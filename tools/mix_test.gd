extends SceneTree
## The music engine's mix (CONDUCT 6 P1): volume curve, limiter, duck layers
## (environment / jingle / dialogue), blips on their own voice, voice stealing,
## group levels and pitch locks, resume positions, mute without restart,
## play-once hand-back, queue_after clearing, background mute, DangerMusic's
## boss-song rules.
##   godot --headless --path . --fixed-fps 60 -s res://tools/mix_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(6)
	_run.call_deferred()


func wait(secs: float) -> void:
	var gt := 0.0
	while gt < secs:
		await process_frame
		gt += root.get_process_delta_time()


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.load_data()
	var m := Music.instance(self)
	await process_frame
	await process_frame
	# Volume curve: even 3 dB steps over the whole 0-10 control.
	check(Settings._db(10) == 0.0 and Settings._db(9) == -3.0 and Settings._db(5) == -15.0 and Settings._db(1) == -27.0, "even dB curve")
	check(Settings._db(0) <= -79.0, "0 is silent")
	Settings.apply_audio()
	var mi := AudioServer.get_bus_index("Master")
	var lim := false
	for i in AudioServer.get_bus_effect_count(mi):
		lim = lim or AudioServer.get_bus_effect(mi, i) is AudioEffectHardLimiter
	check(lim, "a limiter guards the Master bus")
	Settings.ensure_limiter()
	Settings.ensure_buses()
	var nlim := 0
	for i in AudioServer.get_bus_effect_count(mi):
		nlim += 1 if AudioServer.get_bus_effect(mi, i) is AudioEffectHardLimiter else 0
	check(nlim == 1 and AudioServer.get_bus_effect_count(mi) == 2, "only one limiter (+ the C13 mono fold) after a second ensure")
	# Group levels and pitch locks (gangster cash is trimmed like the coin and stays in key).
	check(m._group_db("cash_pickup") == m._group_db("coin"), "cash_pickup gets the coin trim (%.1f)" % m._group_db("cash_pickup"))
	check(m._group_db("scroll_tick") < m._group_db("hit") - 4.0 and m._group_db("tab") < -4.0 and m._group_db("nope") < 0.0, "scroll_tick/tab/nope sit low")
	check(m._group_db("j_buy") == 0.0 and m._group_db("j_heart") < 0.0, "jingles trimmed, j_buy left alone")
	for n: String in ["cash_pickup", "coin", "ui_tap", "menu_open", "tab", "scroll_tick", "page", "j_heart"]:
		check(Music._no_drift(n), "%s is never pitch-drifted" % n)
	check(not Music._no_drift("swing") and not Music._no_drift("hit"), "swings and hits still drift")
	# Blips have their own voice and never cut a jingle.
	m.sfx("quest_done")
	var jv: AudioStreamPlayer = null
	for p in m._sfx:
		if p.playing:
			jv = p
	check(jv != null, "quest_done plays")
	var js := jv.stream if jv else null
	for i in 12:
		m.blip("Rio")
		await wait(0.08)
	check(jv != null and jv.playing and jv.stream == js, "12 talk blips leave the jingle playing")
	# All six voices busy with short sounds + the jingle: a new sound steals a short one.
	for i in 6:
		m._last_sfx.clear()
		m.sfx("hit")
	check(jv != null and jv.stream == js and jv.playing, "voice stealing spares the jingle")
	# Jingle duck: the song dips under a jingle, then comes back.
	await wait(0.3)
	check(m.duck_level() <= -5.0, "music ducks under a jingle (%.1f dB)" % m.duck_level())
	await wait(js.get_length() + 1.6 if js else 3.0)
	check(m.duck_level() > -1.0, "music comes back after the jingle (%.1f dB)" % m.duck_level())
	# Environment duck: on when calm, off while a fight plays.
	m.set_duck(-4.0)
	await wait(2.5)
	check(m.duck_level() <= -3.5, "night duck applies when calm (%.1f)" % m.duck_level())
	DangerMusic.tier = 2
	await wait(2.5)
	check(m.duck_level() > -0.5, "night duck off during a fight (%.1f)" % m.duck_level())
	DangerMusic.tier = 0
	m.set_duck(0.0)
	await wait(2.5)
	# A battle-card layer is not undone by the environment re-sending its duck.
	m.set_duck_layer("battle", -9.0, 0.12, 0.8, 2.0)
	for i in 6:
		m.set_duck(0.0)
		await wait(0.1)
	check(m.duck_level() <= -7.0, "a duck layer survives Ambience's set_duck (%.1f)" % m.duck_level())
	await wait(3.5)
	check(m.duck_level() > -1.0, "the timed layer expires (%.1f)" % m.duck_level())
	# Dialogue dip.
	var dl := Dialogue.instance(self)
	await process_frame
	dl.active = true
	await wait(0.8)
	check(m.duck_level() <= -2.5, "a small dip while a dialogue box is open (%.1f)" % m.duck_level())
	dl.active = false
	await wait(1.2)
	# Resume: an area song left and asked for again picks up where it was.
	m.play("farm", 0.1)
	await wait(0.2)
	OS.delay_msec(1500)  # audio playback runs on the wall clock
	await wait(0.2)
	m.play("house", 0.1)
	await wait(0.4)
	var rp := m.resume_pos("farm")
	check(rp > 0.5, "farm's place remembered (%.2f s)" % rp)
	m.play("farm", 0.1)
	await wait(0.1)
	check(m._player.get_playback_position() >= rp - 0.05 and rp > 0.5, "farm resumes where it was (%.2f s)" % m._player.get_playback_position())
	# Mute / unmute: no restart.
	await wait(0.5)
	var p0: float = m._player.get_playback_position()
	m.toggle_mute()
	check(AudioServer.is_bus_mute(mi), "all sound off mutes Master")
	await wait(0.3)
	m.toggle_mute()
	check(not AudioServer.is_bus_mute(mi), "all sound on")
	check(m._player.playing and m._player.get_playback_position() >= p0, "unmute keeps the song's place (%.2f >= %.2f)" % [m._player.get_playback_position(), p0])
	# Background: muted while hidden unless Sound in background is on.
	m.set_background(true)
	check(AudioServer.is_bus_mute(mi), "hidden app: silent")
	m.set_background(false)
	check(not AudioServer.is_bus_mute(mi), "back: sound again")
	Settings.set_v("bg_sound", true)
	m.set_background(true)
	check(not AudioServer.is_bus_mute(mi), "Sound in background on: keeps playing")
	m.set_background(false)
	Settings.reset_audio(self)
	check(not bool(Settings.get_v("bg_sound")) and int(Settings.get_v("music_vol")) == int(Settings.DEFAULTS["music_vol"]), "reset sound to defaults")
	# queue_after: cleared by any calm song; a finished play-once with nothing queued hands back.
	m.queue_after("credits")
	m.play("house")
	check(m._after.is_empty(), "a calm song clears the queued credits")
	m._current = "merkitty_song"
	m._on_finished(m._player)
	check(m.wanted() == "", "a finished play-once track hands back (wanted '%s')" % m.wanted())
	m.queue_after("credits")
	m.queue_after("title", true)
	check(m._after == ["credits", "title"], "queue_after appends")
	m.queue_after("")
	# Story hold.
	m.play_held("farm")
	check(m.held() == "farm", "play_held holds")
	m.play("house")
	check(m.held() == "", "another song releases the hold")
	# DangerMusic: raid is never a boss song; boss themes are.
	check(not DangerMusic.is_boss_song("raid"), "raid is not a boss song")
	check(DangerMusic.is_boss_song("boss_gang") and DangerMusic.is_boss_song("finargle"), "boss_gang / finargle are boss songs")
	check(DangerMusic._is_tier_track("combat_light") and not DangerMusic._is_tier_track("boss_penguin"), "tier tracks known")
	# Footsteps: a long take doesn't swallow the next step.
	m.step("gravel")
	await wait(0.05)
	OS.delay_msec(400)
	await wait(0.05)
	var st0 := m._steps.get_playback_position()
	m.step("gravel")
	check(m._steps.get_playback_position() < st0 or st0 == 0.0, "a step after 0.25 s restarts the step voice (%.2f -> %.2f)" % [st0, m._steps.get_playback_position()])
	print("mix_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

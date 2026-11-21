extends SceneTree
## CONDUCT 6 P6: UI, arcade, rec and story audio cues.
##   godot --headless --path . -s res://tools/ui_audio_test.gd
## Checks: final boss beats keep the arc themes (no generic "music" beside a
## boss_card); every story cue (line sfx/music, effects sfx/music) exists or has a
## fallback that does; paper speakers don't blip; arcade results use three tiers;
## bowling plays one fitting sting; villager rolls are graded; the rec's lane bed and
## pin spots follow the lanes; home Music Box / Jukebox pick the house song; crystal
## arc buys never play banknotes; campaign settle cues exist.
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(6)
	Campaign.bypass = true
	_run.call_deferred()


func _sfx_ok(n: String) -> bool:
	for suf in ["", "_2", "_3"]:
		for ext in [".ogg", ".wav"]:
			if FileAccess.file_exists("res://audio/sfx/%s%s%s" % [n, suf, ext]):
				return true
	return false


func _song_ok(t: String) -> bool:
	return t == "area" or t == "stop" or FileAccess.file_exists("res://audio/music/%s.ogg" % t)


func _lines_of(b: Dictionary) -> Array:
	var out: Array = []
	for l in b.get("lines", []):
		out.append(l)
		for k in (l as Dictionary).get("branches", {}):
			out.append_array(l["branches"][k])
	return out


func _run() -> void:
	# --- story data --------------------------------------------------------------
	var sd: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
	var bad_cues: Array = []
	var boss_music: Array = []
	var n_line_cues := 0
	for arc in ["penguins", "gangsters"]:
		for ch: Dictionary in sd[arc]:
			for b: Dictionary in ch["beats"]:
				var fx: Dictionary = b.get("effects", {})
				if fx.has("boss_card") and fx.has("music"):
					boss_music.append(b["id"])
				if fx.has("sfx"):
					var n := Story.beat_sfx(str(fx["sfx"]))
					if not _sfx_ok(n) and not _sfx_ok(str(fx.get("sfx_fallback", "levelup"))):
						bad_cues.append("%s fx sfx %s" % [b["id"], n])
				if fx.has("music") and not _song_ok(str(fx["music"])):
					bad_cues.append("%s fx music %s" % [b["id"], fx["music"]])
				for l: Dictionary in _lines_of(b):
					if l.has("sfx"):
						n_line_cues += 1
						if not _sfx_ok(str(l["sfx"])) and not _sfx_ok(str(l.get("sfx_fallback", "pickup"))):
							bad_cues.append("%s line sfx %s" % [b["id"], l["sfx"]])
					if l.has("music"):
						n_line_cues += 1
						if not _song_ok(str(l["music"])) and not _song_ok(str(l.get("music_fallback", ""))):  # C13 P4: songs may land later
							bad_cues.append("%s line music %s" % [b["id"], l["music"]])
	check(boss_music.is_empty(), "no beat sets a generic song beside its boss_card %s" % str(boss_music))
	check(bad_cues.is_empty(), "every story cue exists or falls back to one that does %s" % str(bad_cues))
	check(n_line_cues >= 10, "story lines carry their own cues (%d)" % n_line_cues)
	check(Story.beat_sfx("levelup") == "quest_done" and Story.beat_sfx("j_heart") == "j_heart", "beat sfx: levelup -> quest_done, others as written")
	var soft := 0
	for arc in ["penguins", "gangsters"]:
		for ch: Dictionary in sd[arc]:
			for b: Dictionary in ch["beats"]:
				if str(b["id"]) in ["p2_finn_locket", "p4_bell_rung", "p5_bell_help", "g4_kid", "g4_sasha"] and str(b.get("effects", {}).get("sfx", "")) != "levelup":
					soft += 1
	check(soft == 5, "tender/ominous beats no longer end on the quest fanfare (%d/5)" % soft)
	# --- dialogue ----------------------------------------------------------------
	check(Dialogue.is_paper("Letter from Maple") and Dialogue.is_paper("Note") and not Dialogue.is_paper("Maple") and not Dialogue.is_paper(""), "letters/notes are paper (no talk blip), people aren't")
	# --- arcade ------------------------------------------------------------------
	check(ArcadeGame.result_cue(20, 10, false) == "j_victory", "arcade: a good round -> fanfare")
	check(ArcadeGame.result_cue(3, 10, true) == "j_victory", "arcade: a new best -> fanfare")
	check(ArcadeGame.result_cue(4, 10, false) == "j_confirm", "arcade: some tickets -> ticket cue, not the defeat sting")
	check(ArcadeGame.result_cue(0, 10, false) == "menu_close", "arcade: nothing won -> soft round-over cue")
	var arcade_src := ""
	for f in ["arcade_game", "arcade_claw", "arcade_skee", "arcade_stack", "arcade_whack", "arcade_gallery", "block_jumper"]:
		arcade_src += FileAccess.get_file_as_string("res://scripts/%s.gd" % f)
	check(not arcade_src.contains("j_battle_lost"), "no arcade game plays the campaign-defeat sting")
	var in_game_coin := 0
	for f in ["arcade_skee", "arcade_whack", "arcade_gallery", "block_jumper"]:
		in_game_coin += FileAccess.get_file_as_string("res://scripts/%s.gd" % f).count("sfx(\"coin\")")
	check(in_game_coin == 0, "in-game arcade points never use the (gangster: banknote) coin cue")
	var claw := ArcadeClaw.new()
	var skee := ArcadeSkee.new()
	check(claw.has_method("_start_music") and FileAccess.get_file_as_string("res://scripts/arcade_claw.gd").contains("result_cue_done = true"), "claw: one win jingle, room song kept")
	claw.free()
	skee.free()
	# --- bowling / rec -----------------------------------------------------------
	check(Bowling.end_cue({"score": 22}, false) == "sparkle", "solo gutter game: no victory fanfare")
	check(Bowling.end_cue({"score": 140}, false) == "j_victory", "solo 140: fanfare")
	check(Bowling.end_cue({"score": 40}, true) == "j_victory", "solo new best: fanfare")
	check(Bowling.end_cue({"opponent": "maple", "won": false, "score": 150}, false) == "j_page", "versus loss: soft cue")
	check(RecAudio.opp_roll(10) == "pin_strike" and RecAudio.opp_roll(5) == "pin_crash" and RecAudio.opp_roll(1) == "pin_tap" and RecAudio.opp_roll(0) == "bowl_gutter", "villager rolls graded tap/crash/strike/gutter")
	for n in ["pin_strike", "pin_crash", "pin_tap", "bowl_gutter"]:
		check(_sfx_ok(n), "rec sound %s exists" % n)
	check(RecAudio.alley_trim(0) < -10.0 and RecAudio.alley_trim(2) == 0.0, "lanes bed: near silent when empty, full with bowlers")
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["time"] = 6 * 60  # before opening: no villager lanes
	RecCenter._lt_key = ""
	if RecCenter.lanes_taken().is_empty():
		var sp := RecAudio.spots("rec_up")
		check(sp.all(func(s: Array) -> bool: return not str(s[0]).begins_with("pins_")), "no pin crashes upstairs with every lane empty")
	# Home prizes: the Music Box picks the house song.
	var house: GameMap = (load("res://scripts/house.gd") as GDScript).new()
	check(RecCenter.music_for(house, "house") == "house", "house song by default")
	GameState.run["flags"]["home_juke"] = "title_musicbox"
	check(RecCenter.music_for(house, "house") == "title_musicbox", "home Music Box plays its tune as the house song")
	GameState.run["flags"].erase("home_juke")
	house.free()
	check(RecCenter.HOME_USE.has("rp_arcade_cab") and RecCenter.HOME_USE.has("rp_jukebox") and RecCenter.HOME_USE.has("rp_music_box"), "home cabinet, jukebox and music box are usable")
	# Money words: crystals never rustle banknotes.
	check(Money.sfx_name("cash") == "coin" and Money.sfx_name("cash_register") == "coin", "crystal arc: buy/sell cues are the coin chime")
	GameState.new_run("gangsters", "kairi", "T", "Town", "Pup")
	check(Money.sfx_name("coin") == "cash_pickup" and Money.sfx_name("cash") == "cash", "gangster arc keeps cash sounds")
	# Campaign board cues exist.
	for k in CampaignScreen.SETTLE_SFX:
		check(_sfx_ok(str(CampaignScreen.SETTLE_SFX[k])), "settle '%s' cue exists" % k)
	print("ui_audio_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

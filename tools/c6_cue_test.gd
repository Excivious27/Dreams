extends SceneTree
## CONDUCT 6 P5: gameplay cues pick the right sound (pet voice by look, enemy
## send-offs by family, the Tommy Gun's short cue, spells/Gifts/partners by kind,
## rocks shatter as rock, no bicycle horn on a battlefield, the convoy and mega
## rides). Static checks plus a scan of the cue lines in the owned scripts.
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _src(p: String) -> String:
	return FileAccess.get_file_as_string("res://scripts/%s.gd" % p)


func _death(kind: String) -> String:
	var e := Enemy.new()
	e.kind = kind
	var s := e._death_sound()
	e.free()
	return s


func _initialize() -> void:
	seed(6)
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	if not (GameState.run.get("look") is Dictionary):
		GameState.run["look"] = {}
	GameState.run["look"]["pet"] = "dog_1"
	check(Pet.voice("call") == "bark" and Pet.voice("hurt") == "whimper" and not Pet.is_cat(), "a dog barks and whimpers")
	GameState.run["look"]["pet"] = "cat_2"
	check(Pet.is_cat() and Pet.voice("call") == "meow" and Pet.voice("happy") == "purr" and Pet.kind_word() == "cat", "a cat meows and purrs (c6_11)")
	check(FileAccess.file_exists("res://audio/sfx/meow.ogg") and FileAccess.file_exists("res://audio/sfx/purr.ogg"), "meow/purr files exist")
	# Enemy send-offs by family (c6_08_06): the bubble pop is the last resort.
	check(_death("lantern_moth") == "bug", "moths die as bugs")
	check(_death("gilded_mirror") == "glass", "mirrors shatter as glass")
	check(_death("obsidian_sentinel") == "rock_break", "stone guardians crumble as rock")
	check(_death("thug_cyber") == "zap", "the cyber summon is a short zap, not the 1.9 s power-down")
	check(_death("thug_lookout") in ["knockout", "thud"], "thugs are knocked out, never popped (%s)" % _death("thug_lookout"))
	check(_death("slime") == "slime", "slimes still splat")
	# Guns (c6_08_17).
	check(Player.gun_sound("tommy_gun") != "shot_rifle", "the Tommy Gun no longer fires 1 s rifle samples")
	# Spells / Gifts / partners (c6_08_08/09/18).
	check(Spells.spell_sound("spark") == "spell_lightning" and Spells.spell_sound("radiance") != Spells.spell_sound("lull"), "spells have their own cues")
	check(Gift.sfx_for("cinder") == "spell_fire" and Gift.sfx_for("lt_grid") == "spell_lightning" and Gift.sfx_for("b_mirror") == "glass", "Gift blasts sound by family")
	var cs := _src("companion")
	check("Gift.sfx_for(ab.trim_prefix" in cs and "ABILITY_SFX" in cs, "lent Gifts and partner abilities pick their cue")
	# Rocks shatter as rock (c6_10-12 / c6_11): no crate_break on a rock kill in owned maps.
	for f in ["mine", "moon", "mountain"]:
		var s := _src(f)
		check(s.contains('sfx("rock_break", "crate_break")'), "%s: rock kill plays rock_break" % f)
	var ha := _src("hidden_area")
	check(not ha.contains('"crate_break"'), "hidden pockets: no wooden crack on stone")
	# No bicycle horn on the battlefield or the convoy (c6_08_05 / c6_11).
	check(not _src("battle").contains('sfx("horn"'), "the commander's entrance isn't a bike horn")
	check(not _src("campaign_convoy").contains('"horn"'), "the convoy arrives without a bike horn")
	check(not _src("battle").contains('sfx("craft_done", "pop")'), "helper spawns don't play the craft jingle")
	# Mega rides (c6_11): the fairy ring has its own cue (teleport until imported).
	check(str(MegaTravel.TRAVEL_SFX["gloamwood"][0]) == "fairy_ring", "Gloamwood rides the fairy ring cue")
	# Money in through add_money (c6_11 notes).
	check(not _src("commons").contains('run["crystals"] = int(GameState.run["crystals"]) +'), "commons earnings go through add_money")
	check(not _src("secrets").contains('run["crystals"] = int(GameState.run["crystals"]) +'), "secret gold goes through add_money")
	# Morning cues (c6_10-02/-14): one helper for bed and pass-out nights.
	check(_src("house").contains("morning_cues(get_tree(), kept_rep") and _src("house").contains('"crop_ready"'), "pass-out mornings get cues; ripe crops chime")
	print("c6_cue_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)

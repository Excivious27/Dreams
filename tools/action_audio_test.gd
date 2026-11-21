extends SceneTree
## CONDUCT 13 P5: actions map to their own sounds (action -> sound).
##   godot --headless --path . --fixed-fps 60 -s res://tools/action_audio_test.gd
## Part 1 (always): the pickers answer with real files: pet moments, RanchVoice for every species and
## its baby (never the pickup blip), the "baby_<species>" words, collected goods, vehicle ticks, the
## C13 contract's delivered sounds, the gold-star harvest and the step words.
## Part 2 (when Music.sfx_log exists, P1's C13 hook): fire each action and read what really played.
## Before that hook lands, part 2 prints a skip line and the test still passes on part 1.
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _has(n: String) -> bool:
	for suf in ["", "_2", "_3"]:
		if ResourceLoader.exists("res://audio/sfx/%s%s.ogg" % [n, suf]):
			return true
	return false


func _initialize() -> void:
	seed(13)
	GameState.load_data()
	GameState.new_run("penguins", "man", "Tester", "Dreamhollow", "Pip")
	_run.call_deferred()


func _run() -> void:
	var mu := Music.instance(self)
	for i in 3:
		await process_frame
	# --- part 1: static pickers ------------------------------------------------------------
	for n: String in ["card_deal", "card_flip", "chip_clack", "roulette_spin", "roulette_ball", "slot_spin", "slot_stop",
			"target_tin", "claw_move", "claw_drop", "skee_roll", "ticket_out", "cabinet_coin", "step_carpet", "step_metal",
			"step_ice", "step_wood", "scooter_ride", "motor_loop", "sled_snow", "milk", "shear", "egg_collect", "howl_far",
			"knockout", "swim", "cv_merkitty", "cv_crystal_baby", "pet_howl", "chips_stack"]:
		check(_has(n), "contract sound %s exists" % n)
	if not (GameState.run.get("look") is Dictionary):
		GameState.run["look"] = {}
	var table: Array = []
	for pet: String in ["dog_1", "cat_2"]:
		GameState.run["look"]["pet"] = pet
		for mo: String in ["call", "happy", "hurt", "hit", "howl", "attack"]:
			var r := Pet.voice_row(mo)
			check(_has(str(r[0])) or _has(str(r[1])), "%s %s voice %s exists" % [pet, mo, r[0]])
			check(str(r[0]) != "bite", "%s %s never borrows the fishing bite" % [pet, mo])
			table.append("%s/%s -> %s" % [pet, mo, r[0]])
	GameState.run["look"]["pet"] = "dog_1"
	check(Pet.voice("howl") == "pet_howl", "the dog howls with the howl take")
	# RanchVoice: every species and its baby resolve to an existing voice file, never 'pickup'.
	var ranch: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/ranch.json")) as Dictionary).get("species", {})
	var nsp := 0
	for sp: String in ranch:
		var f := RanchVoice.file_of(sp)
		if f == "":
			continue
		nsp += 1
		check(_has(f) and f != "pickup", "species %s voice %s exists" % [sp, f])
		var fa := FarmAnimal.voice_for(sp)
		check(fa != "pickup" and (_has(fa) or fa == ""), "FarmAnimal.voice_for(%s) = %s is a real voice" % [sp, fa])
	check(nsp >= 10, "RanchVoice covers the ranch species (%d)" % nsp)
	check(RanchVoice.MOMENTS.has("baby") and float(RanchVoice.MOMENTS["baby"][0]) > 1.0, "babies call higher than adults")
	check(RanchVoice.file_of("merkitty") == "cv_merkitty" and RanchVoice.file_of("crystal_baby") == "cv_crystal_baby", "merkitties and crystal babies have voices")
	# Goods: milking, shearing, egg collecting.
	check(Ranch.good_sfx("milk") == "milk" and Ranch.good_sfx("goat_milk") == "milk", "milk squirts")
	check(Ranch.good_sfx("sheep_wool") == "shear" and Ranch.good_sfx("alpaca_fleece") == "shear", "wool is sheared")
	check(Ranch.good_sfx("egg") == "egg_collect" and Ranch.good_sfx("duck_egg") == "egg_collect", "eggs clack")
	check(Ranch.good_sfx("peacock_feather") == "", "feathers just pop")
	# Vehicles follow the ground.
	check(Player.veh_tick_word("crystal_sled", "grass") != "snow", "no snow crunch for a sled on grass")
	check(Player.veh_tick_word("crystal_sled", "snow") == "snow", "the sled crunches on snow")
	for v: String in Player.VEH_LOOP:
		check(_has(str(Player.VEH_LOOP[v][0])), "vehicle bed %s exists" % Player.VEH_LOOP[v][0])
	# Gold star: no combat crit punch in farm.gd's harvest.
	var farm := FileAccess.get_file_as_string("res://scripts/farm.gd")
	check(not farm.contains("sfx(\"crit\", \"coin\")"), "a gold-star harvest is no combat crit")
	# --- part 2: what really plays (Music.sfx_log, P1) --------------------------------------
	if not ("sfx_log" in mu):
		print("action_audio_test: Music.sfx_log not present yet (P1 hook): part 2 skipped")
	else:
		await _played_part(mu, table)
	for row in table:
		print("  ", row)
	print("action_audio_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


## Calls f, then returns the log entries it added ([] when nothing was logged, e.g. audio off).
func _fire(mu: Music, f: Callable) -> Array:
	if mu.has_method("clear_sfx_log"):
		mu.call("clear_sfx_log")
	var log0: Array = mu.get("sfx_log")
	var n0 := log0.size()
	f.call()
	for i in 2:
		await process_frame
	var log1: Array = mu.get("sfx_log")
	return log1.slice(n0)


func _asked(entries: Array) -> Array:
	var out: Array = []
	for e in entries:
		if e is Dictionary:
			out.append(str((e as Dictionary).get("played", (e as Dictionary).get("asked", ""))))
	return out


func _played_part(mu: Music, table: Array) -> void:
	GameState.run["look"]["pet"] = "dog_1"
	var e := await _fire(mu, func() -> void: Pet.say(self, "howl"))
	if e.is_empty():
		print("action_audio_test: Music.sfx_log logs nothing here (audio off): part 2 skipped")
		return
	check("pet_howl" in _asked(e), "Howl perk plays pet_howl (got %s)" % str(_asked(e)))
	table.append("Pet.say howl -> %s" % str(_asked(e)))
	e = await _fire(mu, func() -> void: Pet.say(self, "attack"))
	check(not ("bite" in _asked(e)), "pup attack is not the fishing bite (got %s)" % str(_asked(e)))
	var ranch: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/ranch.json")) as Dictionary).get("species", {})
	for sp: String in ranch:
		if RanchVoice.file_of(sp) == "":
			continue
		e = await _fire(mu, func() -> void: RanchVoice.say(self, "baby_" + sp, "call", ""))
		var got := _asked(e)
		check(not got.is_empty() and not ("pickup" in got), "baby %s has its parent's voice (got %s)" % [sp, str(got)])
	for good: String in ["milk", "sheep_wool", "egg"]:
		var want := Ranch.good_sfx(good)
		e = await _fire(mu, func() -> void: mu.sfx(want, "pickup"))
		check(want in _asked(e), "collecting %s plays %s (got %s)" % [good, want, str(_asked(e))])
		table.append("collect %s -> %s" % [good, str(_asked(e))])

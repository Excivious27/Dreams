extends SceneTree
## CONDUCT 11b P6: C11b creature voices and ranch sound (scripts/ranch_voices.gd, ambience.gd).
## Every C11b kind has a voice whose file exists, none uses an effect's name ("boom"), babies and
## variants share it, GameMap.animal_voice asks it first, night kinds call after dark (day kinds
## don't), and the new homes' room tones and the egg/feeder cues exist.
##   godot --headless --fixed-fps 60 --path . -s res://tools/ranch_audio_c11b_test.gd
const RV := preload("res://scripts/ranch_voices.gd")
var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	seed(6)
	_run.call_deferred()

func _run() -> void:
	var tbl: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/gen/animals/_ranch_art_c11b.json"))
	var sp_tbl: Dictionary = tbl.get("species", tbl)
	for sp: String in sp_tbl:
		if sp.begins_with("_"):
			continue
		var v := RV.voice(sp)
		check(v != "", "%s has a voice" % sp)
		check(ResourceLoader.exists("res://audio/sfx/%s.ogg" % v), "%s voice file %s exists" % [sp, v])
		check(not v in ["boom", "laser", "zap", "shot", "cannon"], "%s never sounds like an effect" % sp)
		check(RV.voice(sp + "_baby") == v, "%s baby shares the voice" % sp)
	check(RV.voice("cow") == "" and RV.voice("chicken2") == "", "classic kinds keep their own voices")
	check(GameMap.animal_voice("ostrich_tawny") == "cv_ostrich" and GameMap.animal_voice("moon_cow_baby") == "cv_moon", "animal_voice asks the C11b table")
	check(GameMap.animal_voice("cow_brown") == "moo", "classic voices unchanged")
	# Night kinds speak after dark; day kinds only by day.
	var n := Node2D.new()
	var herd := {"moon_cow": [n], "ostrich": [n]}
	var night: Array = Ambience.pen_rules_for("farm", true, true, "night", "", herd)
	check(night.size() == 1 and str(night[0][4]) == "moon_cow", "only the night kind calls at night")
	var day: Array = Ambience.pen_rules_for("farm", true, true, "day", "", herd)
	check(day.size() == 1 and str(day[0][4]) == "ostrich", "day kinds call by day")
	check(Ambience.species_of("glow_gecko_aqua") == "glow_gecko", "variant strips count with their species")
	n.free()
	for f in ["res://audio/amb/aviary_room.ogg", "res://audio/amb/terrarium_room.ogg", "res://audio/sfx/egg_crack.ogg", "res://audio/sfx/feeder_fill.ogg"]:
		check(ResourceLoader.exists(f), "%s exists" % f)
	print("ranch_audio_c11b_test: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

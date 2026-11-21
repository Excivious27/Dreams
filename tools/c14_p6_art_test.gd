extends SceneTree
## C14 P6 art + light checks: mega villagers walk 4 ways with 4-frame side/back strips,
## the dune scatter set and the redrawn icons are isolated pieces (clear corners), hearths
## and forges glow, neon/crystal lamps are coloured, the gangster lamps cool.
##   godot --headless --fixed-fps 60 --path . -s res://tools/c14_p6_art_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(14)
	for id in ["mg_liesl", "mg_fenn", "mg_bramble", "mg_sefa", "mg_rahim", "mg_nadia", "mg_hollis", "mg_dot", "mg_skip", "mg_brannoch", "mg_ingrid", "mg_tove", "mg_zephyr", "mg_gull", "mg_nimbus", "mg_pell", "mg_odette", "mg_cass", "mg_aurum", "mg_coalbrook"]:
		var sf := CharacterLibrary.frames_for(id)
		check(sf != null and sf.has_animation("walk_up") and sf.get_frame_count("walk_up") == 4, "%s walks away with its back turned (4 frames)" % id)
		check(sf != null and sf.has_animation("walk") and sf.get_frame_count("walk") == 4, "%s side walk has 4 steps" % id)
	for n in ["dune_0", "dune_3", "dune_5", "dune_9", "hedge", "grass_tuft_winter"]:
		check(_clear_corners("nature", n), "nature/%s is an isolated piece (clear corners)" % n)
	for n in ["flame_core", "luck_potion", "harvest_potion", "golem_core"]:
		check(_clear_corners("items", n), "items/%s has no card or sliver in its corners" % n)
	for n in ["fr_hearth", "fireplace", "forge_2", "candle_set", "oven"]:
		check(GameMap.glows(n), "%s glows after dark" % n)
	check(not GameMap.glows("oven_off"), "an unlit oven stays dark")
	check(NightGlow.tint_of("neon_sign_3").size() == 1, "neon signs cast a coloured light")
	check(NightGlow.tint_of("ice_crystal_lit").size() == 1, "crystal lamps cast their crystal colour")
	check(NightGlow.tint_of("lamp2_tall_0").is_empty(), "penguin/no-save lamps keep the warm amber")
	print("c14_p6_art_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


func _clear_corners(group: String, name: String) -> bool:
	var t := Art.tex(group, name)
	if t == null:
		return false
	var im := t.get_image()
	if im.is_compressed():
		im.decompress()
	var w := im.get_width() - 1
	var h := im.get_height() - 1
	return im.get_pixel(0, 0).a < 0.1 and im.get_pixel(w, 0).a < 0.1 and im.get_pixel(0, h).a < 0.1 and im.get_pixel(w, h).a < 0.1

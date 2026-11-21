extends SceneTree
## CONDUCT 5 P2 lighting (c5_02 #1, c5_10 #1-#5, c5_04 #3):
## - town buildings register window masks (NightGlow.windows); homes go dark late
## - festival bonfires/lanterns and animated fires count as lights (GameMap.glows)
## - underground regions keep a fixed dimness and no weather; mines glow steadily
##   godot --headless --path . --fixed-fps 60 -s res://tools/night_light_test.gd
var fails := 0

func _initialize() -> void:
	seed(3)
	Campaign.bypass = true
	(load("res://scripts/mine.gd") as Variant).force_seed = 7
	_run.call_deferred()

func _ok(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("NIGHT LIGHT FAIL: ", msg)

func _go(scene: String) -> GameMap:
	GameState.run["flags"][scene + "_seen"] = true
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/%s.tscn" % scene)
	for k in 12:
		await process_frame
	return current_scene as GameMap

func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	# rules
	_ok(NightGlow.window_level("home", 21.0) == 1.0 and NightGlow.window_level("home", 23.5) == 0.0, "homes lit in the evening, dark after 23")
	_ok(NightGlow.window_level("shop", 22.5) < 0.5 and NightGlow.window_level("late", 2.0) == 1.0, "shops dim after closing, the inn stays lit")
	_ok(GameMap.glows("fest_ss_80") and GameMap.glows("bonfire") and GameMap.glows("campfire_cook") and GameMap.glows("neon_open"), "festival bonfire, campfire, neon glow")
	_ok(not GameMap.glows("lamp_unlit") and not GameMap.glows("fest_ss_02") and not GameMap.glows("lighthouse_broken"), "unlit/plain props don't glow")
	# town at night: windows registered and drawn
	GameState.run["time"] = 22 * 60 + 30
	var t := await _go("town")
	_ok(t != null and t.glow != null and t.glow.windows.size() >= 10, "town buildings have window masks (%d)" % (t.glow.windows.size() if t and t.glow else -1))
	_ok(t.glow_dark() > 0.3, "town is dark at 22:30 (%.2f)" % t.glow_dark())
	_ok(t.fixed_dark < 0.0, "town follows the sky clock")
	# underground: fixed dim, no weather, same at noon and midnight
	GameState.run["time"] = 12 * 60
	var u := await _go("iron_tunnels")
	_ok(u != null and u.fixed_dark > 0.2, "iron tunnels have a fixed dimness (%.2f)" % (u.fixed_dark if u else -1.0))
	if u:
		var noon := u.sky_tint(12 * 60)
		_ok(noon.is_equal_approx(u.sky_tint(0)) and noon.v < 0.95, "underground tint steady and dim (noon %s)" % noon)
		u.set_weather("rain")
		_ok(u.sky == null or u.sky.weather == "clear", "no rain underground")
		_ok(u.glow_dark() > 0.2, "underground lamps glow at noon")
	# mines: steady lamp glow, no tint
	var m := await _go("mine")
	_ok(m != null and m.glow_dark() > 0.2 and m.sky_tint(12 * 60).v < 0.85 and m.sky_tint(12 * 60).is_equal_approx(m.sky_tint(0)), "mine lamps glow at noon under a steady cave shade (c14_16-13)")
	print("night_light_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

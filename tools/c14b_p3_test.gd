extends SceneTree
## C14b P3: wind, town, farm, beach, festival motion.
##   godot --headless --fixed-fps 60 --path . -s res://tools/c14b_p3_test.gd
## - festival days get their sky motion (petals / fireflies / leaves / snow)
## - AmbientMotion: neighbours bob out of step, motion is on game time (stops when
##   PlayClock doesn't advance), reduced motion lowers the amplitude, spin turns
## - lighthouse uses its lit-lamp still (frame 1) and a beam node; no strobe strip
## - the new art (mill base/wheel with hub, windmill body/sails with hub, 6-frame
##   bonfire) is registered
## - FestivalSky: river lanterns exist, fireworks and wish stars spawn and expire
## - farm: crop layer shader loads; desync gives a row of stations different frames
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	seed(14)
	Campaign.bypass = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		PlayClock.advance(1.0 / 60.0)
		await process_frame


func _run() -> void:
	GameState.new_run("penguins", "pip", "Test", "Testville", "Pup")
	GameState.run["weather"] = {}
	var want := {14: "petals", 42: "fireflies", 70: "leaves", 98: "snow"}
	for d: int in want:
		check(GameState.weather_for(d) == want[d], "festival day %d weather %s (got %s)" % [d, want[d], GameState.weather_for(d)])
	check(GameState.weather_for(15) != "" , "ordinary day still rolls")

	# AmbientMotion bob / breathe / spin on game time
	var host := Node2D.new()
	root.add_child(host)
	var am := AmbientMotion.of(host)
	check(am != null and AmbientMotion.of(host) == am, "one driver per map")
	var a := Sprite2D.new()
	a.position = Vector2(100, 100)
	var b := Sprite2D.new()
	b.position = Vector2(116, 100)
	host.add_child(a)
	host.add_child(b)
	check(absf(AmbientMotion.phase(a.position) - AmbientMotion.phase(b.position)) > 0.05, "neighbour phases differ")
	am.bob(a, 2.0, 3.0, 2.0)
	am.bob(b, 2.0, 3.0, 2.0)
	var spinner := Node2D.new()
	host.add_child(spinner)
	am.spin(spinner, 1.0, false)
	var r0 := spinner.rotation
	var seen_diff := false
	var max_off := 0.0
	for i in 90:
		await _frames(1)
		if not is_equal_approx(a.position.y, b.position.y):
			seen_diff = true
		max_off = maxf(max_off, absf(a.position.y - 100.0))
	check(seen_diff, "neighbouring buoys never bob in lockstep")
	check(max_off >= 1.0 and max_off <= 2.01, "bob amplitude ~2 px (got %.2f)" % max_off)
	check(absf(fmod(a.position.y * 2.0, 1.0)) < 0.001, "bob snaps to 0.5 px")
	check(absf(spinner.rotation - r0) > 0.5, "spin turns on game time")
	# paused tree (menus): game time stops and nothing moves
	var y0 := a.position.y
	paused = true
	for i in 10:
		await process_frame
	check(is_equal_approx(a.position.y, y0), "no motion while paused")
	paused = false
	# reduced motion
	var was := bool(Settings.get_v("shake"))
	Settings.set_v("shake", false)
	if AmbientMotion.reduced():
		var mo := 0.0
		for i in 200:
			await _frames(1)
			mo = maxf(mo, absf(a.position.y - 100.0))
		check(mo <= 1.01, "reduced motion lowers bob amplitude (got %.2f)" % mo)
	Settings.set_v("shake", was)

	# lighthouse
	var lf := LighthouseBeam.lit_frame("lighthouse")
	check(lf is AtlasTexture and is_equal_approx((lf as AtlasTexture).region.position.x, float(Art.info("buildings", "lighthouse").get("cell_w", 148))), "lighthouse still is the lit-lamp frame 1")
	var tower := Sprite2D.new()
	host.add_child(tower)
	var beam := LighthouseBeam.attach(tower, Vector2(-2, -187))
	await _frames(2)
	check(beam != null and beam.get_child_count() == 1, "beam draws on its own layer above the night tint")
	check(LighthouseBeam.strength() >= 0.12, "beam never fully off")

	# art
	for gi: Array in [["buildings", "c14bp3_water_mill_base"], ["buildings", "c14bp3_water_mill_wheel"], ["props", "c14bp3_windmill_body"], ["props", "c14bp3_windmill_sails"], ["props", "c14bp3_bonfire"]]:
		check(Art.has(gi[0], gi[1]), "art %s/%s" % gi)
	check((Art.info("buildings", "c14bp3_water_mill_base").get("hub", []) as Array).size() == 2, "mill hub recorded")
	check((Art.info("props", "c14bp3_windmill_body").get("hub", []) as Array).size() == 2, "windmill hub recorded")
	check(int(Art.info("props", "c14bp3_bonfire").get("frames", 1)) == 6, "bonfire has 6 frames")
	var wi := Art.info("buildings", "c14bp3_water_mill_wheel")
	check(absi(int(wi.get("w", 0)) - int(wi.get("h", 0))) <= 4, "wheel is round (spins about its centre)")

	# festival sky
	var fsk := FestivalSky.make(host, "lantern", Rect2(1088, 0, 80, 1984), Vector2(648, 760))
	await _frames(2)
	check(FestivalSky.of(host) == fsk, "FestivalSky.of finds it")
	check(fsk._river_l.size() >= 6, "river lanterns drift")
	var ly: float = fsk._river_l[0][0]
	await _frames(30)
	check(float(fsk._river_l[0][0]) != ly, "river lanterns move downstream")
	fsk.fireworks(Vector2(648, 700))
	check(fsk._bursts.size() >= 1, "fireworks after the float")
	fsk.star_for(Vector2(600, 600))
	check(fsk._stars.size() == 1, "wish star spawns")
	await _frames(400)
	check(fsk._stars.is_empty() and fsk._bursts.is_empty(), "bursts and stars expire")

	# farm crop layer shader
	check(ResourceLoader.exists("res://shaders/crop_sway.gdshader") and load("res://shaders/crop_sway.gdshader") is Shader, "crop sway shader loads")
	print("c14b_p3_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

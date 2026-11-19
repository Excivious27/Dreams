extends SceneTree
## Screenshots of every arcade cabinet mid-game (and the picker, level select,
## results card).
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/arcade_shot.gd -- /tmp/arcade
var out := "/tmp/arcade"


func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("shot ", name)


func _open(id: String) -> ArcadeGame:
	var g := ArcadeHub.make(id)
	g.manual = true
	root.add_child(g)
	return g


func _frames(g: ArcadeGame, n: int, input := {}) -> void:
	for i in n:
		if not is_instance_valid(g) or not g.is_inside_tree():
			return
		g.bot = input
		g.t += 1.0 / 60.0
		g.frame()
	if is_instance_valid(g) and g._canvas:
		g._canvas.queue_redraw()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["crystals"] = 5000
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(270, 480)
	root.add_child(bg)

	var hub := _open("")
	_frames(hub, 30)
	await _shot("00_picker")
	hub.close()

	# Unlock a few jumper levels so the select screen shows progress.
	for n in [1, 2, 3, 4, 5]:
		BlockJumper._jd()["clear"][str(n)] = true
		BlockJumper._jd()["best"][str(n)] = 100
		BlockJumper._jd()["coins"][str(n)] = 20 + n
	BlockJumper._jd()["best"]["6"] = 47
	var j := _open("jumper") as BlockJumper
	_frames(j, 30)
	await _shot("01_jumper_select")
	var acts := [{}, {"a": true}, {"down": true}]
	for n in [1, 3, 4, 5, 7]:
		j.state = "select"
		BlockJumper._jd()["clear"][str(n - 1)] = true
		j.play_tile(n - 1)
		j.lv["dbl"] = false  # the stored plans are made without the double jump
		var plan: Array = JumperLevels.stored_plan(n)
		while j.intro_t - 1.0 / 60.0 > 0.5:
			_frames(j, 1)
		var stop := int(plan.size() * (0.3 + 0.1 * (n % 3)))
		for k in mini(stop, plan.size()):
			_frames(j, 1, acts[int(plan[k])])
		await _shot("02_jumper_level%d" % n)
	j.state = "select"
	j.play_tile(8)
	for k in 60 * 8:
		_frames(j, 1, {"a": k % 70 < 10})
		if j.dead_t > 0.0:
			break
	await _shot("03_jumper_endless")
	j.state = "select"
	j.play_tile(0)
	j._end_run(true)
	_frames(j, 50)
	await _shot("04_jumper_results")
	j.close()

	var s := _open("stack")
	_frames(s, 10)
	await _shot("10_stack_title")
	_frames(s, 1, {"a": true})
	for i in 1500:
		var inp := {}
		if i % 25 == 3:
			inp["a"] = true
		if i % 11 < 3:
			inp["left" if (i / 90) % 2 == 0 else "right"] = true
		_frames(s, 1, inp)
		if s.state != "play":
			break
	await _shot("11_stack_play")
	s.close()

	var w := _open("whack") as ArcadeWhack
	_frames(w, 10)
	await _shot("20_whack_title")
	_frames(w, 1, {"a": true})
	_frames(w, 1)
	for i in 60 * 14:
		if i % 20 == 0:
			for h in 9:
				if str(w.holes[h]["kind"]) == "grump" and float(w.holes[h]["up"]) > 0.8:
					w.whack(h)
					break
		_frames(w, 1)
	await _shot("21_whack_play")
	w.close()

	var c := _open("claw") as ArcadeClaw
	c.rng.seed = 3
	_frames(c, 10)
	await _shot("30_claw_title")
	_frames(c, 1, {"a": true})
	_frames(c, 1)
	_frames(c, 40, {"left": true})
	await _shot("31_claw_aim")
	_frames(c, 1, {"a": true})
	_frames(c, 110)
	await _shot("32_claw_lift")
	c.close()

	var g := _open("gallery") as ArcadeGallery
	_frames(g, 10)
	await _shot("40_gallery_title")
	_frames(g, 1, {"a": true})
	_frames(g, 1)
	for i in 60 * 10:
		if i % 30 == 0 and not g.ducks.is_empty():
			var d: Dictionary = g.ducks[i / 30 % g.ducks.size()]
			g.sight = Vector2(float(d["x"]), ArcadeGallery.LANES[int(d["lane"])] - 10.0)
			g.shoot()
		_frames(g, 1)
	g.sight = Vector2(150, 170)
	await _shot("41_gallery_play")
	g.close()
	quit()

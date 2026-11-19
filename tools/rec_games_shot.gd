extends SceneTree
## Screenshots of the rec chance games (c2_04): Skee-Ball title / aim / roll /
## results, a claw win card.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/rec_games_shot.gd -- /tmp/recgames
var out := "/tmp/recgames"


func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
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
	GameState.new_run(OS.get_environment("ARC") if OS.get_environment("ARC") != "" else "penguins", "kairi", "T", "Town", "Pup")
	GameState.run["crystals"] = 500
	var sk := _open("skee_ball") as ArcadeSkee
	sk.rng.seed = 2
	_frames(sk, 40)
	await _shot("50_skee_title")
	_frames(sk, 1, {"a": true})
	_frames(sk, 1)
	_frames(sk, 20, {"right": true})
	_frames(sk, 30, {"a": true})
	await _shot("51_skee_charge")
	_frames(sk, 1)
	_frames(sk, 34)
	await _shot("52_skee_air")
	_frames(sk, 30)
	await _shot("53_skee_score")
	for i in 60 * 60:
		if sk.state != "play":
			break
		if sk.phase == "aim":
			sk.throw([0.0, 0.82, -0.82][i % 3], ArcadeSkee.p_for(268.0 if i % 3 == 0 else 181.0))
		_frames(sk, 1)
	_frames(sk, 50)
	await _shot("54_skee_over")
	sk.close()
	var cl := _open("claw") as ArcadeClaw
	_frames(cl, 8)
	_frames(cl, 1, {"a": true})
	_frames(cl, 1)
	_frames(cl, 30, {"left": true})
	await _shot("56_claw_aim")
	ArcadeClaw.pile[0]["item"] = "candy"
	cl._win(0)
	_frames(cl, 50)
	await _shot("55_claw_win")
	cl.close()
	quit()

extends SceneTree
## Screenshots of every casino table: how-to card, bet card, mid-hand, result.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/casino_shot.gd -- /tmp/casino
var out := "/tmp/casino"


func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("shot ", name)


func _frames(g: CasinoGame, n: int, input := {}) -> void:
	for i in n:
		if not is_instance_valid(g) or g.is_queued_for_deletion():
			return
		g.bot = input
		g.t += 1.0 / 60.0
		g.frame()
	if is_instance_valid(g) and g._canvas:
		g._canvas.queue_redraw()


func _tap(g: CasinoGame, a: String) -> void:
	_frames(g, 1, {a: true})
	_frames(g, 1, {"_": false})


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	GameState.new_run("gangsters", "kairi", "T", "Town", "Pup")
	GameState.run["crystals"] = 5000
	GameState.run["time"] = 21 * 60
	Casino.skip_save = true
	Casino._st()["seen"] = {"slots": true, "roulette": true, "blackjack": true, "dice": true, "poker": true}
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(270, 480)
	root.add_child(bg)
	for id in ["slots", "roulette", "blackjack", "dice", "poker"]:
		var g := Casino.make(id)
		g.manual = true
		root.add_child(g)
		_frames(g, 8)
		await _shot(id + "_0title")
		_tap(g, "a")
		_tap(g, "right")
		_tap(g, "down")
		await _shot(id + "_1bet")
		_tap(g, "a")
		_frames(g, 20)
		await _shot(id + "_2hand")
		for k in 300:
			if g.state == "result":
				break
			_frames(g, 1, {"tool": true} if g.state == "play" and id == "blackjack" and k % 2 == 0 else ({"a": true} if g.state == "play" and k % 2 == 0 else {"_": false}))
		_frames(g, 30)
		await _shot(id + "_3result")
		g.close()
		await process_frame
	quit()

extends SceneTree
## Screens of Crystal Stack and Whack-a-Grump in every state (title, play,
## danger, level banner, pause, top-out, results; READY, mid-round, countdown).
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/stack_whack_shot.gd -- /tmp/sw
var out := "/tmp/sw"


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
	g.rng.seed = 7
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
	GameState.run["crystals"] = 5000
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(270, 480)
	root.add_child(bg)

	var s := _open("stack") as ArcadeStack
	_frames(s, 10)
	await _shot("s0_title")
	_frames(s, 1, {"a": true})
	_frames(s, 2)
	# A mid-game board: ragged stack, a piece falling, ghost visible.
	var ks := ArcadeStack.SHAPES.keys()
	for r in range(9, ArcadeStack.ROWS):
		for cx in ArcadeStack.COLS:
			if (cx * 7 + r * 3) % 10 != 0 and not (r < 12 and cx > 5):
				s.board[r][cx] = str(ks[(cx + r) % ks.size()])
	s.lines = 13
	s.lvl = 2
	s.score = 2350
	_frames(s, 50, {"left": true})
	await _shot("s1_play")
	s.lines = 15
	s._remove_rows()
	s.clearing = []
	s.lines = 16
	s.lvl = 2
	s.clearing = [17]
	s._remove_rows()
	_frames(s, 20)
	await _shot("s2_level_banner")
	# Danger: stack near the top.
	for r in range(3, ArcadeStack.ROWS):
		for cx in ArcadeStack.COLS:
			if s.board[r][cx] == "" and (cx + r) % 4 != 0:
				s.board[r][cx] = str(ks[(cx * 3 + r) % ks.size()])
	_frames(s, 7)
	await _shot("s3_danger")
	_frames(s, 1, {"b": true})
	_frames(s, 4)
	await _shot("s4_paused")
	_frames(s, 1, {"a": true})
	_frames(s, 1)
	for r in ArcadeStack.ROWS:
		for cx in ArcadeStack.COLS:
			s.board[r][cx] = "S" if (cx + r) % 5 else ""
	s._spawn()
	_frames(s, 40)
	await _shot("s5_topout")
	_frames(s, 80)
	await _shot("s6_results")
	s.close()

	var w := _open("whack") as ArcadeWhack
	_frames(w, 10)
	await _shot("w0_title")
	_frames(w, 1, {"a": true})
	_frames(w, 30)
	await _shot("w1_ready")
	_frames(w, 60)
	for i in 60 * 12:
		for h in 9:
			var hd: Dictionary = w.holes[h]
			if str(hd["kind"]) not in ["", "bunny"] and bool(hd["out"]) and float(hd["up"]) > 0.9:
				w.whack(h)
				break
		_frames(w, 1)
	# Dress the field: one of each critter up, one just bopped (dizzy).
	w.holes[0] = {"kind": "gold", "life": 2.0, "up": 1.0, "hp": 1, "hit": 0.0, "out": true}
	w.holes[4] = {"kind": "bunny", "life": 2.0, "up": 1.0, "hp": 1, "hit": 0.0, "out": true}
	w.holes[6] = {"kind": "helmet", "life": 2.0, "up": 1.0, "hp": 2, "hit": 0.0, "out": true}
	w.holes[2] = {"kind": "grump", "life": 2.0, "up": 1.0, "hp": 1, "hit": 0.0, "out": true}
	w.combo = 4
	w.whack(2)
	_frames(w, 6)
	await _shot("w2_play")
	w.play_t = ArcadeWhack.LEAD + ArcadeWhack.ROUND - 3.4
	_frames(w, 2)
	await _shot("w3_countdown")
	_frames(w, 1, {"b": true})
	_frames(w, 3)
	await _shot("w4_paused")
	_frames(w, 1, {"a": true})
	_frames(w, 60 * 4)
	_frames(w, 60)
	await _shot("w5_results")
	w.close()
	quit()

extends SceneTree
## Prize counter screenshots, one per shelf, mid-game (some owned, some locked, some
## short of tickets): checks the counter reads at a glance.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/prize_shot.gd -- /tmp/prz
var out := "/tmp/prz"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	GameState.new_run(OS.get_environment("ARC") if OS.get_environment("ARC") != "" else "penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["day"] = 12
	GameState.run["time"] = 15 * 60
	Tickets.add(400, "test")
	Tickets.set_best("bowling", 132)
	Tickets.set_best("bowling", 90)
	Tickets.set_best("whack", 210)
	Tickets.buy("rp_music_box")
	Tickets.buy("rp_sprout_fizz")
	Tickets.spend(Tickets.count() - 95)
	var ps := PrizeScreen.new()
	root.add_child(ps)
	for t in 4:
		ps._tier(t)
		ps.sel = 1
		for k in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/shelf_%d.png" % [out, t])
	print("prize_shot: done")
	quit()

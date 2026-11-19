extends SceneTree
## Rec Center screenshots: the town lot, both floors on league night, the bowling
## screen (lining up, mid-roll, game over), the prize counter, prize decor at home.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/rec_shot.gd -- /tmp/out
##   ARC=gangsters for the Rec Hall skin.
var out := "/tmp/rec"


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _shot(name: String) -> void:
	for k in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _go(scene: String, interior: String, spawn: Vector2) -> GameMap:
	GameMap.next_interior = interior
	GameMap.next_spawn = spawn
	change_scene_to_file("res://scenes/%s.tscn" % scene)
	for k in 25:
		await process_frame
	var d := Dialogue.instance(self)
	for k in 8:
		if d.active:
			d._advance()
			await process_frame
			await process_frame
	return current_scene as GameMap


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	var arc := OS.get_environment("ARC") if OS.get_environment("ARC") != "" else "penguins"
	var a := arc.left(1)
	GameState.new_run(arc, "kairi" if arc == "penguins" else "dad", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	for f in ["town_seen", "town_tour", "partner_scene", "rec_visited", "interior_seen", "int_rec", "int_rec_up"]:
		GameState.run["flags"][f] = true
	GameState.run["quests"] = [{"id": "clear_meadow", "text": "x", "done": true}, {"id": "meet_town", "text": "x", "done": true}]
	GameState.run["day"] = 10
	GameState.run["time"] = 16 * 60
	if OS.get_environment("CLOSED") == "":
		GameState.run["flags"]["rec_open"] = 1
	var m := await _go("town", "", Vector2(54 * 16 + 8, 89 * 16 + 8))
	await _shot(a + "_town_lot")
	GameState.run["flags"]["rec_open"] = 1
	GameState.run["time"] = 19 * 60 + 30
	Tickets.add(260, "test")
	Tickets.set_best("bowling", 168)
	m = await _go("interior", "rec", Vector2(8 * 16 + 8, 11 * 16 + 8))
	await _shot(a + "_rec_ground")
	m = await _go("interior", "rec_up", Vector2(8 * 16 + 8, 13 * 16 + 8))
	for k in 200:
		await process_frame
	await _shot(a + "_rec_up")
	# Bowling: line up, aim, mid-roll, the pin deck, game over.
	var b := Bowling.new()
	b.lane = 2
	m.add_child(b)
	for k in 12:
		await process_frame
	b.x0 = 2.0
	await _shot(a + "_bowl_line")
	b.phase = "aim"
	b.aim = 0.3
	b._osc = 0.0
	await process_frame
	b.phase = "power"
	b.power = 0.65
	b._throw()
	b.sim.throw(2.0, 0.3, 320.0, 0.66)
	for k in 70:
		await process_frame
	await _shot(a + "_bowl_roll")
	for k in 200:
		await process_frame
		if b.phase == "result":
			break
	await _shot(a + "_bowl_hit")
	b._start_sweep()
	for k in 14:
		await process_frame
	await _shot(a + "_bowl_sweep")
	b.rolls = [10, 7, 3, 9, 0, 10, 0, 8, 8, 2, 0, 6, 10, 10, 10, 8, 1]
	b._game_over()
	await _shot(a + "_bowl_over")
	b._finish()
	for k in 5:
		await process_frame
	# Versus a villager: their frame card, then the result.
	var bv := Bowling.new()
	bv.lane = 3
	bv.opp_id = "gideon"
	m.add_child(bv)
	for k in 12:
		await process_frame
	bv.rolls = [10, 7, 3, 9, 0, 10]
	bv.opp_rolls = [9, 1, 10, 8, 1, 7, 3]
	bv._opp_from = 5
	bv._opp_show = 2
	bv._phase_t = 3.0
	bv.phase = "opp"
	bv.manual = true
	await _shot(a + "_bowl_vs_card")
	bv.rolls = [10, 7, 3, 9, 0, 10, 0, 8, 8, 2, 0, 6, 10, 10, 10, 8, 1]
	bv.opp_rolls = [9, 1, 10, 8, 1, 7, 3, 10, 9, 0, 8, 2, 7, 2, 10, 9, 1, 8]
	bv._game_over()
	await _shot(a + "_bowl_vs_over")
	bv._finish()
	for k in 5:
		await process_frame
	var ps := PrizeScreen.new()
	ps.map = m
	ps.tier = 2
	m.add_child(ps)
	for k in 3:
		await process_frame
	ps._fill()
	await _shot(a + "_prizes")
	ps._close()
	for id in ["rp_trophy_bronze", "rp_trophy_silver", "rp_music_box", "rp_jukebox", "rp_arcade_cab", "rp_painting", "rp_arcade_medal"]:
		GameState.add_item(id, 1)
	m = await _go("house", "", Vector2(8 * 16 + 8, 9 * 16 + 8))
	await _shot(a + "_house_decor")
	quit()

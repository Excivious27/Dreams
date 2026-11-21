extends SceneTree
## C16b integ: screenshots of the campaign board (a started campaign) and the loss card, both arcs.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/c16b_loss_shot.gd -- /tmp/out


func _initialize() -> void:
	seed(16)
	_run.call_deferred()


func _shot(name: String) -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		return
	for k in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [args[0], name])


func _run() -> void:
	InputSetup.ensure_actions()
	Campaign.bypass = true
	for arc: String in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi", "Kairi", "Dreamhollow", "Biscuit")
		GameState.run["intro_done"] = true
		GameState.run["party"] = {}
		GameMap.next_spawn = Vector2.ZERO
		change_scene_to_file("res://scenes/town.tscn")
		for i in 40:
			await process_frame
		var m := current_scene as GameMap
		var cid: String = Campaign.for_arc()[0]
		Campaign.st()["started"] = Campaign.st().get("started", {})
		var nid := ""
		for n: Dictionary in Campaign.get_c(cid)["nodes"]:
			if str(n.get("type", "")) not in Campaign.NONBATTLE:
				nid = str(n["id"])
				break
		# a lost fight on nid: finish(false) then the loss card
		Campaign.st()["fight"] = {"cid": cid, "nid": nid, "field": "x", "day": 1}
		Campaign.finish(false, 10)
		CampaignScreen.open(m, cid)
		for i in 4:
			await process_frame
		for n in current_scene.get_children():
			if n is CampaignScreen:
				(n as CampaignScreen)._brief.visible = false
				(n as CampaignScreen)._refresh()
		await _shot(arc + "_board")
		# the loss card over a quiet scene (town would play its chapter intro first)
		change_scene_to_file("res://scenes/farm.tscn")
		for i in 40:
			await process_frame
		var d0 := Dialogue.instance(self)
		if d0 and d0.active:
			d0.queue_free()
			for i in 3:
				await process_frame
		m = current_scene as GameMap
		Campaign.loss_card(m, cid)
		for i in 30:
			await process_frame
		await _shot(arc + "_loss_card")
		var dl := Dialogue.instance(self)
		if dl:
			dl.queue_free()
		for i in 4:
			await process_frame
	quit(0)

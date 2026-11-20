extends SceneTree
## Close-up of penguin-hero accessories in every view (C10a P5):
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/wardrobe_shot.gd -- /tmp/shots
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	GameState.load_data()
	GameState.new_run("penguins", "penguin_m", "Robin", "Frostvale", "Pup")
	Wardrobe.register()
	Decor.give("wr_goggles_brass")
	Decor.give("wr_bowtie_blue")
	Wardrobe.put_on("wr_scarf_red")
	Wardrobe.put_on("wr_goggles_brass")
	var bg := ColorRect.new()
	bg.color = Color(0.45, 0.6, 0.45)
	bg.size = Vector2(1000, 1000)
	root.add_child(bg)
	var x := 50.0
	for spr in ["penguin_king", "penguin_wizard"]:
		for an in ["walk_down", "walk", "walk_up"]:
			var holder := Node2D.new()
			holder.position = Vector2(x, 200 if spr == "penguin_king" else 380)
			root.add_child(holder)
			var sp := CharacterLibrary.make_sprite(spr)
			sp.scale *= 5.0
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			holder.add_child(sp)
			sp.play(an)
			Wardrobe.dress_penguin_hero(holder, sp, spr)
			x += 85.0
		x = 50.0
	# Skin tones on painted outfits (light / medium / dark), build-your-own hero
	var bx := 30.0
	for o in ["outfit_neon", "outfit_farmer", "outfit_scholar"]:
		for tone in ["light_slim", "medium_slim", "dark_broad"]:
			var h := Node2D.new()
			h.position = Vector2(bx, 470)
			root.add_child(h)
			PaperDoll.build_preview(h, {"body": tone, "hair": PaperDoll.hair_styles()[3], "hair_color": "black", "hat": "", "outfit": o}, 3.0, "idle", true)
			bx += 56.0
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/wr_penguin_views.png")
	quit()

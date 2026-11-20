extends SceneTree
## Probe (C10b P5): wardrobe pins on drawn + penguin heroes across animations.
func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _row(y: float, arc: String, pid: String, ids: Array, anims: Array) -> void:
	GameState.new_run(arc, pid, "Robin", "X", "Pup")
	for id in ids:
		Decor.give(id)
		Wardrobe.put_on(id)
	var spr := GameState.sprite_for_playable(pid)
	var x := 30.0
	for an in anims:
		var h := Node2D.new()
		h.position = Vector2(x, y)
		root.add_child(h)
		var sp := CharacterLibrary.make_sprite(spr)
		sp.scale *= 2.0
		h.add_child(sp)
		if sp.sprite_frames.has_animation(an):
			sp.play(an)
			sp.pause()
			sp.frame = mini(1, sp.sprite_frames.get_frame_count(an) - 1)
		if an == "walk_left":
			sp.play("walk"); sp.flip_h = true
		Wardrobe.dress_hero(h, sp, spr)
		x += 58.0


func _run() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.45, 0.6, 0.45)
	bg.size = Vector2(1000, 1000)
	root.add_child(bg)
	var A := ["idle", "walk_down", "walk_up", "walk", "walk_left", "attack", "hoe_down", "ride", "faint"]
	var only := OS.get_environment("ROWS")
	if only == "b":
		_row(110, "penguins", "penguin_f", ["wr_cape_red"], A)
		_row(220, "penguins", "big_jim", ["wr_beanie", "wr_cape_green"], A)
	else:
		_row(110, "gangsters", "june", ["wr_fedora", "wr_shades"], A)
		_row(220, "gangsters", "rafe", ["wr_cowboy"], A)
		_row(330, "gangsters", "june", ["wr_cape_blue"], A)
		_row(440, "penguins", "penguin_m", ["wr_scarf_red", "wr_goggles_brass"], A)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/p5/pins.png")
	quit()

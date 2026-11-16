extends SceneTree
## Dev helper: renders scenes and saves PNGs to the path given after "--".
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	await _shoot("res://scenes/title.tscn", out + "/title.png", 30)
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	var farm: Node = (load("res://scenes/farm.tscn") as PackedScene).instantiate()
	root.add_child(farm)
	for i in 40: await process_frame
	root.get_texture().get_image().save_png(out + "/farm_idle.png")
	Input.action_press("down"); Input.action_press("b")
	for i in 70: await process_frame
	root.get_texture().get_image().save_png(out + "/farm_run.png")
	Input.action_release("down"); Input.action_release("b")
	farm.queue_free()
	quit()
func _shoot(scene: String, path: String, frames: int) -> void:
	var n: Node = (load(scene) as PackedScene).instantiate()
	root.add_child(n)
	for i in frames: await process_frame
	root.get_texture().get_image().save_png(path)
	n.queue_free()
	await process_frame

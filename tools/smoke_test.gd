extends SceneTree
## Loads every scene in res://scenes, runs it for a few frames while pressing
## each game action, and builds every character's SpriteFrames.
## Run: godot --headless --path . -s res://tools/smoke_test.gd

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	InputSetup.ensure_actions()
	for id in CharacterLibrary.ORDER:
		var sf := CharacterLibrary.frames_for(id)
		for a in ["idle", "walk", "run", "attack", "view_front", "view_right", "view_back", "view_left"]:
			if not sf.has_animation(a) or sf.get_frame_count(a) == 0:
				_fail("%s missing animation %s" % [id, a])
	if not CharacterLibrary.frames_for("dog").has_animation("play"):
		_fail("dog missing play")

	for path in _find_scenes("res://scenes"):
		var ps := load(path) as PackedScene
		if ps == null:
			_fail("can't load " + path)
			continue
		var node := ps.instantiate()
		if node == null:
			_fail("can't instantiate " + path)
			continue
		root.add_child(node)
		await _frames(3)
		for action in ["right", "left", "up", "down", "b", "a", "menu"]:
			Input.action_press(action)
			await _frames(4)
			Input.action_release(action)
			await _frames(2)
		await _frames(20)
		node.queue_free()
		await _frames(2)
		print("SMOKE OK ", path)

	print("SMOKE DONE, failures: ", _fails)
	# Release static caches and helper singletons so nothing leaks at exit.
	for n in ["Dialogue", "Music"]:
		var node := root.get_node_or_null(n)
		if node:
			node.free()
	CharacterLibrary._frames_cache.clear()
	CharacterLibrary._data.clear()
	GameState.run = {}
	await _frames(2)
	quit(1 if _fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _fail(msg: String) -> void:
	_fails += 1
	printerr("SMOKE FAIL: ", msg)


func _find_scenes(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".tscn"):
			out.append(dir_path.path_join(f))
	for d in dir.get_directories():
		out.append_array(_find_scenes(dir_path.path_join(d)))
	return out

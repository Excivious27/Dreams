extends SceneTree
class P extends Node:
	var hits := 0
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _process(_d: float) -> void:
		if Input.is_action_just_pressed("b"):
			hits += 1
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	InputSetup.ensure_actions()
	var p := P.new()
	root.add_child(p)
	await process_frame
	await process_frame
	Input.action_press("b")
	await process_frame
	await process_frame
	Input.action_release("b")
	await process_frame
	print("hits after press-in-signal: ", p.hits, " frames ", Engine.get_process_frames())
	paused = true
	await process_frame
	Input.action_press("b")
	await process_frame
	Input.action_release("b")
	await process_frame
	print("hits paused: ", p.hits)
	quit()

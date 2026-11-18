extends SceneTree
func _initialize() -> void:
	var bad := 0
	for f in DirAccess.get_files_at("res://scripts"):
		if f.ends_with(".gd"):
			var s: Script = load("res://scripts/" + f)
			if s == null or not s.can_instantiate():
				print("BAD ", f); bad += 1
	print("compile_all: %d bad" % bad)
	quit()

extends SceneTree
## Loads every script named on the command line (after --) and fails on a parse error.
func _initialize() -> void:
	var bad := 0
	for p in OS.get_cmdline_user_args():
		var s = load(p)
		if s == null or (s is GDScript and not (s as GDScript).can_instantiate() and not (s as GDScript).is_abstract()):
			print("FAIL ", p)
			bad += 1
	print("p6_load_check: %d bad" % bad)
	quit(1 if bad > 0 else 0)

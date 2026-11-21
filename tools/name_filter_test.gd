extends SceneTree
## NameFilter (s1_13-03 / s1_13-10): blocked words refused (also leetspeak, spacing, doubled letters),
## ordinary and pet names pass, clean() falls back. Run: godot --headless --path . -s res://tools/name_filter_test.gd

const NF := preload("res://scripts/name_filter.gd")

func _initialize() -> void:
	seed(1)
	var fails := 0
	for bad in ["fuck", "F.u_C k", "fuuuuck", "sh1t", "b1tch", "$hit", "Big Ass", "kill", "a55hole", "n4zi", "Mr Sexy", "Mr. Dick"]:
		if NF.is_ok(bad):
			print("FAIL: should block %s" % bad); fails += 1
	for good in ["Pip", "Nova", "Grape", "Peacock", "Prickles", "Skillet", "Cucumber", "Essex", "Dickens", "Booboo",
			"Clover", "Hassan", "Cassie", "Glassford", "Analise", "Titus", "Mossy Hollow", "Bassett", "Sal", "Maple Town"]:
		if not NF.is_ok(good):
			print("FAIL: should allow %s" % good); fails += 1
	if NF.clean("sh1t", "Daisy") != "Daisy" or NF.clean("Daisy", "x") != "Daisy":
		print("FAIL: clean fallback"); fails += 1
	print("NAME FILTER DONE, failures: %d" % fails)
	quit(1 if fails > 0 else 0)

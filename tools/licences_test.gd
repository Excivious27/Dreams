extends SceneTree
## Credits and licences (s1_13-09): Godot MIT notice present, credits present and free of family names,
## embedded font notice equals fonts/LICENSE-symbols.txt. Run: godot --headless --path . -s res://tools/licences_test.gd

const L := preload("res://scripts/licences.gd")

func _initialize() -> void:
	seed(1)
	var fails := 0
	var t: String = L.text()
	for need in ["Permission is hereby granted", "Godot Engine", "FreeType", "Bitstream", "ACE Music", "Claude", "OpenAI image models"]:
		if not t.contains(need):
			print("FAIL: licences text lacks %s" % need); fails += 1
	var rx := RegEx.new()
	rx.compile("\\b(Tom|Thomas|Barany|Kelsie|Miles|Bruce)\\b")
	if rx.search(L.credits()) != null:
		print("FAIL: credits name a family member"); fails += 1
	var f := FileAccess.get_file_as_string("res://fonts/LICENSE-symbols.txt").strip_edges()
	if f != L.FONT_NOTICE:
		print("FAIL: Licences.FONT_NOTICE differs from fonts/LICENSE-symbols.txt (re-embed it)"); fails += 1
	print("LICENCES DONE, failures: %d" % fails)
	quit(1 if fails > 0 else 0)

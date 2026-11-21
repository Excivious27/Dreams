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
	# C17 P5 (c17_17-06 / c17_17-13): compounds, accents, look-alikes, short forms, drug words; and innocent hosts.
	for bad in ["BigDick", "SexyGirl", "KillYou", "CumLord", "RapeU", "A S S", "fuk", "phuck", "fück", "fυck", "Weed420", "Cocaine", "bigdick", "xXcumXx", "Meth Head"]:
		if NF.is_ok(bad):
			print("FAIL: should block %s" % bad); fails += 1
	for good in ["Shitake", "Shitake Farm", "Scunthorpe", "Ignazio", "Cockatoo", "Grape Vine", "Skillet", "Cucumber Kid", "Dickens", "Sussex", "Tweed", "BigDipper", "MossyRock", "Jo", "Ana Lise"]:
		if not NF.is_ok(good):
			print("FAIL: should allow %s" % good); fails += 1
	# Name tags: zero-width / RTL / emoji dropped, long names clamped, host marked.
	var tg: String = Puppet.tag_text("Pi\u200bp\u202e🙂", false)
	if tg != "Pip":
		print("FAIL: tag text cleaned %s" % tg); fails += 1
	if Puppet.tag_text("Bartholomew Longname", true).length() > 18 or not Puppet.tag_text("Pip", true).begins_with("Host "):
		print("FAIL: tag clamp/host mark"); fails += 1
	if NF.clean("sh1t", "Daisy") != "Daisy" or NF.clean("Daisy", "x") != "Daisy":
		print("FAIL: clean fallback"); fails += 1
	# Co-op guests clean animal names from the host's ranch delta (net.gd, S1 integ).
	var r := {"animals": {"a1": {"species": "hen", "name": "sh1t"}, "a2": {"species": "hen", "name": "Daisy"}}, "houses": {}}
	var c: Dictionary = NetNode.clean_ranch_names(r)
	if str(c["animals"]["a1"]["name"]) == "sh1t" or str(c["animals"]["a1"]["name"]) == "" or str(c["animals"]["a2"]["name"]) != "Daisy":
		print("FAIL: ranch names cleaned for guests %s" % [c]); fails += 1
	if str(r["animals"]["a1"]["name"]) != "sh1t":
		print("FAIL: clean_ranch_names must not touch the host's dictionary"); fails += 1
	print("NAME FILTER DONE, failures: %d" % fails)
	quit(1 if fails > 0 else 0)

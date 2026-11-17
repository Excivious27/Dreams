extends SceneTree
## Title flow: precreated heroes play as drawn (gang versions in the gangster
## arc), "Build your own" uses the paper doll, penguins get the penguin creator.
var fails := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1
func frames(n: int) -> void:
	for i in n: await process_frame
func _run() -> void:
	InputSetup.ensure_actions()
	for pick in [["gangsters", "dad", "man_gang", false], ["gangsters", "nia", "nia_gang", false], ["penguins", "bo", "bo", false], ["penguins", "june", "june", false], ["gangsters", "pax", "son_gang", false], ["penguins", "kairi", "girl", false], ["penguins", "custom", "", true], ["penguins", "penguin_m", "penguin", false]]:
		var t: Node = (load("res://scenes/title.tscn") as PackedScene).instantiate()
		root.add_child(t)
		current_scene = t
		await frames(5)
		t._arc = str(pick[0])
		t._show_characters()
		await frames(3)
		t._pick(str(pick[1]))
		await frames(3)
		var nxt: Button = null
		for c in t._page.get_children():
			if c.name == "NextBtn": nxt = c
		check(nxt != null, "%s/%s: next button present (%s)" % [pick[0], pick[1], nxt.text if nxt else "-"])
		if nxt: nxt.pressed.emit()
		await frames(3)
		if bool(pick[3]) or str(pick[2]) == "penguin":
			# creator shown: press Done
			var cr: Creator = null
			for c in t._page.get_children():
				if c is Creator: cr = c
			check(cr != null, "%s: creator shown" % pick[1])
			if cr: cr.done.emit(cr.look)
			await frames(3)
		check(t._name_edit != null, "%s: names screen reached" % pick[1])
		t._begin()
		await frames(30)
		var m := current_scene as GameMap
		check(m != null and m.player != null, "%s: game started" % pick[1])
		if m and m.player:
			check(m.player.char_id == str(pick[2]), "%s: hero sprite %s (want %s)" % [pick[1], m.player.char_id, pick[2]])
			check(bool(m.player._doll) == bool(pick[3]), "%s: paper doll=%s" % [pick[1], str(m.player._doll)])
		if m: m.queue_free()
		await frames(2)
	print("CREATOR DONE, failures: %d" % fails)
	quit(1 if fails > 0 else 0)

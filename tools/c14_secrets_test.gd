extends SceneTree
## C14 P4 exploration: the classic outdoor regions (HiddenArea.CLASSIC) hide a pocket
## and a secret way like the mega areas do (c14_13-02, 12-25), each with its own lore
## page; unfound ways are drawn opaque (c14_13-07); totals count them per arc.
##   godot --headless --path . --fixed-fps 60 -s res://tools/c14_secrets_test.gd
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	Campaign.bypass = true
	seed(21)
	_run.call_deferred()


func _load(scene: String) -> GameMap:
	GameMap.next_spawn = Vector2.ZERO
	GameState.run["scene"] = scene
	change_scene_to_file("res://scenes/%s.tscn" % scene)
	for i in 10:
		await process_frame
	var d := Dialogue.instance(self)
	for k in 8:
		if d.active:
			d._advance()
			await process_frame
	return current_scene as GameMap


func _run() -> void:
	InputSetup.ensure_actions()
	for arc in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi", "T", "Town", "Pup")
		GameState.run["intro_done"] = true
		var p0 := Secrets.pages_total()
		for rid: String in HiddenArea.CLASSIC:
			check(Secrets.POCKET_PAGES.has(rid), "%s has a pocket page" % rid)
			if not Secrets._area_here(rid) or not ResourceLoader.exists("res://scenes/%s.tscn" % rid):
				continue
			var m := await _load(rid)
			if m == null:
				check(false, "%s loads" % rid)
				continue
			var ha := m.get_node_or_null("HiddenArea") as HiddenArea
			check(ha != null, "%s (%s): a HiddenArea" % [rid, arc])
			var mouths := 0
			var ways := 0
			for c: Vector2i in m.things:
				var t := str(m.things[c].get("type", ""))
				if t == "hidden_mouth":
					mouths += 1
				elif t == "secret_way":
					ways += 1
					if m.props.has(c) and m.props[c] is CanvasItem:
						check((m.props[c] as CanvasItem).modulate.a >= 0.99, "%s: unfound way drawn opaque" % rid)
			check(mouths >= 1, "%s (%s): a pocket mouth (%d)" % [rid, arc, mouths])
			check(ways == 0 or ways == 2, "%s (%s): a secret way has two ends (%d)" % [rid, arc, ways])
		check(Secrets.pages_total() == p0, "%s pages total stable" % arc)
		print("%s: pages_total %d chests_total %d" % [arc, Secrets.pages_total(), Secrets.chests_total()])
	print("c14_secrets_test: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

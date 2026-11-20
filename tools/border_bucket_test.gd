extends SceneTree
## C9 P6: the forest's border trees are a few bucket canvas items in the bake
## painter (not ~1000 Sprite2Ds held for the whole visit), the map stays light
## at rest and while walking, and every border tree is still drawn once.
var fails := 0

func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1

func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()

func _count(n: Node) -> int:
	var t := 1
	for c in n.get_children():
		t += _count(c)
	return t

func _run() -> void:
	InputSetup.ensure_actions()
	for arc in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi", "Kairi", "D", "B")
		GameState.run["intro_done"] = true
		GameState.run["flags"]["partner_scene"] = true
		GameState.run["flags"]["forest_seen"] = true
		GameMap.next_spawn = Vector2.ZERO
		GameMap.exits_off = true
		change_scene_to_file("res://scenes/forest.tscn")
		for i in 40:
			await process_frame
		var m := current_scene as GameMap
		check(m != null and m.scene_id() == "forest", "%s: forest loaded" % arc)
		if m == null:
			continue
		var painter: GameMap = m.get("_painter")
		var holder: Node2D = painter._bake_stripes.get("trees") if painter != null else null
		var trees: int = m._border_draw.size()
		var buckets := holder.get_child_count() if holder != null else -1
		var drawn := 0
		if holder != null:
			for b in holder.get_children():
				drawn += (b as GameMap.BorderBucket).items.size()
		check(trees > 300, "%s: the forest has a border band (%d trees)" % [arc, trees])
		check(buckets > 0 and buckets * 3 < trees, "%s: border trees bucketed (%d buckets for %d trees)" % [arc, buckets, trees])
		check(drawn == trees, "%s: every border tree drawn once (%d/%d)" % [arc, drawn, trees])
		var ok_order := true
		var last := -1
		if holder != null:
			for b in holder.get_children():
				var y := int(((b as GameMap.BorderBucket).items[0][1] as Rect2).end.y)
				ok_order = ok_order and y >= last
				last = y
		check(ok_order, "%s: buckets in top-to-bottom order" % arc)
		var n0 := _count(root)
		for i in 240:
			for d in ["right", "down", "left", "up"]:
				Input.action_release(d)
			Input.action_press(["right", "down", "left", "up"][(i / 60) % 4])
			await process_frame
		for d in ["right", "down", "left", "up"]:
			Input.action_release(d)
		var n1 := _count(root)
		check(current_scene == m, "%s: exits_off keeps the walk on the map" % arc)
		check(n0 < BUDGET, "%s: forest at rest under %d nodes (%d; C8 had ~1300)" % [arc, BUDGET, n0])
		check(n1 - n0 < 60, "%s: walking adds no node pile-up (%d -> %d)" % [arc, n0, n1])
	GameMap.exits_off = false
	print("border_bucket_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

const BUDGET := 800

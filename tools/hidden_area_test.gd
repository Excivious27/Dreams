extends SceneTree
## Tom's exploration rule (CONDUCT 4): every mega area region hides a pocket and a
## secret way. Checks, per area (both arcs where reachable): the HiddenArea node
## exists, the pocket mouth can be stood at from the spawn, opening it lets you
## walk to the chest, the walls cut nothing else off, the secret way's two ends are
## reachable and carry you across, and the journal/chest totals add up.
##   godot --headless --path . -s res://tools/hidden_area_test.gd [-- shots_dir] [-- only=<scene,...>]
var fails := 0


func _initialize() -> void:
	Campaign.bypass = true
	seed(7)
	_run.call_deferred()


func fail(msg: String) -> void:
	print("  FAIL ", msg)
	fails += 1


func _load(scene: String) -> GameMap:
	GameMap.next_spawn = Vector2.ZERO
	GameMap.next_facing = "down"
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


func _flood(m: GameMap, start: Vector2i) -> Dictionary:
	var seen := {}
	if m.blocked.has(start):
		return seen
	var q: Array[Vector2i] = [start]
	seen[start] = true
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var n := c + d
			if seen.has(n) or m.blocked.has(n) or m.is_water_cell(n) or not m.in_content(n):
				continue
			seen[n] = true
			q.append(n)
	return seen


func _near(seen: Dictionary, c: Vector2i) -> bool:
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if seen.has(c + d):
			return true
	return false


func _run() -> void:
	InputSetup.ensure_actions()
	var shots := ""
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.trim_prefix("only=").split(",")
		else:
			shots = a
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	var md: Dictionary = MegaRegion.data()
	var pockets := 0
	var ways := 0
	var areas_n := 0
	for arc in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi", "T", "Town", "Pup")
		GameState.run["intro_done"] = true
		GameState.run["tools"] = ["hoe", "water", "axe", "pickaxe", "sword", "rod"]
		for rid: String in md.get("order", []):
			for a in md["list"][rid].get("areas", []):
				var scene := str(a["id"])
				if not only.is_empty() and not scene in only:
					continue
				if not MegaRegion.area_in_arc(rid, a) or not MegaRegion.scene_exists(scene) or RegionData.region(scene).is_empty():
					continue
				if arc == "gangsters" and str(a.get("arc", md["list"][rid].get("arc", "both"))) == "both" and only.is_empty() and areas_n > 0 and scene.hash() % 3 != 0:
					continue  # both-arc areas: a third again in the second arc keeps it quick
				GameState.run["flags"]["%s_seen" % scene] = true
				var m := await _load(scene)
				if m == null:
					fail("%s did not load" % scene)
					continue
				areas_n += 1
				var ha := m.get_node_or_null("HiddenArea") as HiddenArea
				if ha == null:
					fail("%s (%s): no HiddenArea" % [scene, arc])
					continue
				var start := m.world_to_cell(m.default_spawn() - Vector2(0, 2))
				var seen := _flood(m, start)
				# Access (CONDUCT 4): foes, doors/locked reasons and villagers can be reached.
				var seen_sw := HiddenArea._reach(m, start)  # (swimmable water counts as reachable for foes)
				for e in m.enemies:
					if is_instance_valid(e) and not (e as Node2D).has_meta("boss"):
						var ec := m.world_to_cell((e as Node2D).position - Vector2(0, 2))
						if not seen_sw.has(ec) and not _near(seen_sw, ec):
							fail("%s (%s): foe %s stuck at %s" % [scene, arc, (e as Enemy).kind, ec])
				for c: Vector2i in m.things:
					if str(m.things[c].get("type", "")) in ["locked", "door", "idoor"] and not _near(seen_sw, c) and not seen_sw.has(c):
						fail("%s (%s): %s at %s can't be reached" % [scene, arc, m.things[c]["type"], c])
				for n in m.get("npcs"):
					var nc: Vector2i = (n as Npc).cell()
					if not seen_sw.has(nc) and not _near(seen_sw, nc):
						fail("%s (%s): villager %s stands in a wall at %s" % [scene, arc, (n as Npc).id, nc])
				var mouths: Array = []
				var wayc: Array = []
				var chests := {}
				for c: Vector2i in m.things:
					match str(m.things[c].get("type", "")):
						"hidden_mouth": mouths.append(c)
						"secret_way": wayc.append(c)
						"secret_chest":
							var ck := str(m.things[c].get("key", ""))
							if ck.begins_with("hidden_chest_"):
								chests[ck.trim_prefix("hidden_chest_")] = c
				var line := "%-24s %s pockets=%s way=%d" % [scene, arc[0], str(mouths), wayc.size()]
				if mouths.is_empty():
					fail("%s (%s): no pocket placed" % [scene, arc])
				if HiddenArea.SANCTUMS.has(scene) and mouths.size() < 2:
					fail("%s: no sanctum" % scene)
				for mouth: Vector2i in mouths:
					pockets += 1
					var tagk := str(m.things[mouth]["key"]).trim_prefix("hidden_open_")
					var chest: Vector2i = chests.get(tagk, Vector2i(-1, -1))
					if not _near(seen, mouth):
						fail("%s: pocket mouth %s not reachable" % [scene, mouth])
					if chest.x < 0:
						fail("%s: pocket %s has no chest" % [scene, tagk])
					elif _near(seen, chest):
						fail("%s: chest %s reachable before opening (pocket not closed)" % [scene, chest])
					if shots != "":
						m.player.position = m.cell_center(ha.stand_of(mouth))
						for cam in m.find_children("*", "Camera2D", true, false):
							(cam as Camera2D).reset_smoothing()
						for i in 20:
							await process_frame
						get_root().get_texture().get_image().save_png("%s/%s_%s.png" % [shots, scene, "sanctum" if tagk.ends_with("_sanctum") else "pocket"])
					var tb: Array = GameState.run["toolbar"]
					if not "pickaxe" in tb:
						tb[0] = "pickaxe"
					GameState.run["slot"] = tb.find("pickaxe")
					var need := str(m.things[mouth].get("need", ""))
					if need != "":
						HiddenArea.interact(m, mouth, m.things[mouth])
						if not m.things.has(mouth):
							fail("%s: sanctum opened before %s" % [scene, need])
						var dlg := Dialogue.instance(self)
						for k in 8:
							if dlg.active:
								dlg._advance()
								await process_frame
						GameState.run["flags"][need] = true
					HiddenArea.interact(m, mouth, m.things[mouth])
					var after := _flood(m, start)
					if chest.x >= 0 and not _near(after, chest):
						fail("%s: chest %s still unreachable after opening" % [scene, chest])
					for c: Vector2i in seen:
						if not after.has(c):
							fail("%s: opening lost cell %s" % [scene, c])
							break
					seen = after
				if wayc.size() == 2:
					ways += 1
					for c: Vector2i in wayc:
						if not seen.has(c) and not _near(seen, c):
							fail("%s: secret way end %s not reachable" % [scene, c])
					m.player.position = m.cell_center(wayc[0])
					HiddenArea.interact(m, wayc[0], m.things[wayc[0]])
					if m.player.position.distance_to(m.cell_center(wayc[1])) > 24.0:
						fail("%s: secret way did not carry you to %s" % [scene, wayc[1]])
					if not GameState.run["flags"].has("hidden_way_" + scene):
						fail("%s: way not marked found" % scene)
					if shots != "":
						for cam in m.find_children("*", "Camera2D", true, false):
							(cam as Camera2D).reset_smoothing()
						for i in 20:
							await process_frame
						get_root().get_texture().get_image().save_png("%s/%s_way.png" % [shots, scene])
				else:
					fail("%s (%s): secret way has %d ends" % [scene, arc, wayc.size()])
				print(line)
		var pt := Secrets.pages_total()
		var ct := Secrets.chests_total()
		print("%s: pages_total %d chests_total %d" % [arc, pt, ct])
		if pt < 30 or ct < 40:
			fail("%s totals too small (pages %d chests %d)" % [arc, pt, ct])
	print("areas %d, pockets %d, ways %d" % [areas_n, pockets, ways])
	print("hidden_area_test: %s (%d fails)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)

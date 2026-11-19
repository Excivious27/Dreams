extends SceneTree
## Exit direction audit (round 13): leave a map by its top edge and you must
## arrive by the bottom edge of the next one, facing inward (up), and so on for
## every side. Also checks the exit's label arrow matches its edge.
##   godot --headless --path . -s res://tools/exit_edge_check.gd
const SCENES := ["farm", "town", "forest", "lake", "meadow", "crystal_meadow", "mountain", "beach", "moon",
	"countryside", "docks", "hideout", "neon", "uptown", "underground", "highlands", "jungle", "marsh",
	"orchard_hills", "quarry", "riverlands", "ruins", "sky", "station", "wastes",
	"bf_dockside", "bf_frostfield", "bf_rail_yards", "bf_shattered_vale", "colony_coral", "colony_ember", "colony_ice", "colony_kelp", "hollow_heart"]
const OPP := {"left": "right", "right": "left", "top": "bottom", "bottom": "top"}
const INWARD := {"left": "right", "right": "left", "top": "down", "bottom": "up"}
const ARROW := {"left": "◀", "right": "▶", "top": "▲", "bottom": "▼"}
const NEAR := 6  # cells from the edge the spawn may sit
var fails := 0


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


static func edge_of(r: Rect2i, cols: int, rows: int) -> String:
	if r.position.x <= 0:
		return "left"
	if r.end.x >= cols:
		return "right"
	if r.position.y <= 0:
		return "top"
	if r.end.y >= rows:
		return "bottom"
	return ""


static func dist_to(edge: String, c: Vector2i, cols: int, rows: int) -> int:
	match edge:
		"left": return c.x
		"right": return cols - 1 - c.x
		"top": return c.y
		_: return rows - 1 - c.y


func _run() -> void:
	InputSetup.ensure_actions()
	for arc in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi", "T", "Town", "Pup")
		GameState.run["intro_done"] = true
		for f in ["cm_seen", "mine_open_1", "meow_taught", "moon_seen", "mine_seen"]:
			GameState.run["flags"][f] = true
		for s in SCENES:
			GameState.run["flags"][s + "_seen"] = true
		var info := {}
		for s in SCENES:
			GameMap.next_spawn = Vector2.ZERO
			GameState.run["scene"] = s
			change_scene_to_file("res://scenes/%s.tscn" % s)
			for i in 5:
				await process_frame
			var m := current_scene as GameMap
			if m == null:
				continue
			m.set_process(false)
			var ex := []
			for e in m.exits:
				ex.append({"rect": e["rect"], "scene": str(e["scene"]), "spawn": e["spawn"], "facing": str(e["facing"]), "label": str(e.get("label", ""))})
			info[s] = {"cols": m.cols, "rows": m.rows, "exits": ex}
		var n := 0
		for s: String in info:
			var a: Dictionary = info[s]
			for e: Dictionary in a["exits"]:
				var edge := edge_of(e["rect"], a["cols"], a["rows"])
				if edge == "":
					continue  # a door or pad inside the map: no direction to match
				var lbl: String = e["label"]
				for k: String in ARROW:
					if k != edge and lbl.contains(ARROW[k]):
						print("  FAIL %s: %s exit to %s is on the %s edge but labelled '%s'" % [arc, s, e["scene"], edge, lbl]); fails += 1
				if not info.has(e["scene"]):
					continue
				var b: Dictionary = info[e["scene"]]
				var any_back := false
				for be: Dictionary in b["exits"]:
					if be["scene"] == s:
						any_back = true
				if not any_back:
					continue  # a one-way return (battlefield, lift, gate thing): no road to line up
				n += 1
				var want: String = OPP[edge]
				var c := Vector2i(int(floor(e["spawn"].x / 16.0)), int(floor(e["spawn"].y / 16.0)))
				var d := dist_to(want, c, b["cols"], b["rows"])
				var best := want
				for k: String in OPP:
					if dist_to(k, c, b["cols"], b["rows"]) < dist_to(best, c, b["cols"], b["rows"]):
						best = k
				if d > NEAR or best != want:
					print("  FAIL %s: %s -> %s leaves by the %s edge but lands at %s, nearest the %s edge (want %s, %d cells)" % [arc, s, e["scene"], edge, str(c), best, want, d]); fails += 1
				if e["facing"] != INWARD[want]:
					print("  FAIL %s: %s -> %s lands facing %s (want %s)" % [arc, s, e["scene"], e["facing"], INWARD[want]]); fails += 1
				# The way back should be on that same edge of the target map.
				var back := false
				for be: Dictionary in b["exits"]:
					if be["scene"] == s and edge_of(be["rect"], b["cols"], b["rows"]) == want:
						back = true
				if not back:
					print("  FAIL %s: %s -> %s: no way back to %s on %s's %s edge" % [arc, s, e["scene"], s, e["scene"], want]); fails += 1
		print("%s: %d edge links checked" % [arc, n])
	print("exit_edge_check: %d failures" % fails)
	quit(1 if fails > 0 else 0)

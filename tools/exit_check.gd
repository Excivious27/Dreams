extends SceneTree
## Loads every outdoor map, follows every exit, and checks where you land:
## not blocked, not water, not standing in an exit (you'd bounce straight
## back), and with room to walk. Run:
##   godot --headless --path . -s res://tools/exit_check.gd
var fails := 0
const SCENES := ["farm", "town", "forest", "lake", "meadow", "crystal_meadow", "mine", "mountain", "beach", "moon",
	"countryside", "docks", "hideout", "neon", "uptown", "underground", "highlands", "jungle", "marsh",
	"orchard_hills", "quarry", "riverlands", "ruins", "sky", "station", "wastes", "house",
	"bf_dockside", "bf_frostfield", "bf_rail_yards", "bf_shattered_vale", "colony_coral", "colony_ember", "colony_ice", "colony_kelp", "hollow_heart"]

func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	_run.call_deferred()

func _load(scene: String, spawn: Vector2) -> GameMap:
	GameMap.next_spawn = spawn
	GameMap.next_facing = "down"
	GameState.run["scene"] = scene
	change_scene_to_file("res://scenes/%s.tscn" % scene)
	for i in 6:
		await process_frame
	return current_scene as GameMap

func _run() -> void:
	InputSetup.ensure_actions()
	for arc in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi", "T", "Town", "Pup")
		GameState.run["intro_done"] = true
		for f in ["cm_seen", "mine_open_1", "meow_taught", "moon_seen", "mine_seen"]:
			GameState.run["flags"][f] = true
		var links := []
		for s in SCENES:
			var m: GameMap = await _load(s, Vector2.ZERO)
			if m == null:
				continue
			for e in m.exits:
				if str(e["scene"]) in SCENES:
					links.append([s, str(e["scene"]), e["spawn"]])
		# Scripted jumps (story scene_to, go_to calls in map scripts) land too.
		var rx := RegEx.create_from_string("go_to\\(\"(\\w+)\", Vector2\\((\\d+) \\* TILE(?: \\+ (\\d+))?, (\\d+) \\* TILE(?: \\+ (\\d+))?\\)")
		var dir := DirAccess.open("res://scripts")
		for f in dir.get_files():
			if not f.ends_with(".gd"):
				continue
			var src := FileAccess.get_file_as_string("res://scripts/" + f)
			for mt in rx.search_all(src):
				var dst := mt.get_string(1)
				if dst in SCENES:
					var sp := Vector2(int(mt.get_string(2)) * 16 + int("0" + mt.get_string(3)), int(mt.get_string(4)) * 16 + int("0" + mt.get_string(5)))
					links.append(["(script " + f + ")", dst, sp])
		for ch in GameState.load_json("res://data/story.json").get(arc, []):
			for b in ch.get("beats", []):
				var st: Array = b.get("effects", {}).get("scene_to", [])
				if st.size() >= 3:
					links.append(["(story " + str(b.get("id", "")) + ")", str(st[0]), Vector2(float(st[1]) * 16, float(st[2]) * 16)])
		print("%s: %d links" % [arc, links.size()])
		for l in links:
			var m: GameMap = await _load(l[1], l[2])
			if m == null:
				print("  FAIL %s: %s -> %s didn't load" % [arc, l[0], l[1]]); fails += 1
				continue
			var c := m.player.cell()
			var why := ""
			if c.x < 0 or c.y < 0 or c.x >= m.cols or c.y >= m.rows:
				why = "off the map"
			elif m.blocked.has(c):
				why = "blocked"
			elif m.is_water_cell(c):
				why = "water"
			else:
				for e in m.exits:
					if (e["rect"] as Rect2i).has_point(c):
						why = "inside the exit to " + str(e["scene"])
				if why == "":
					var seen := {c: true}
					var q := [c]
					while not q.is_empty() and seen.size() < 40:
						var a: Vector2i = q.pop_front()
						for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
							var n: Vector2i = a + o
							if seen.has(n) or n.x < 0 or n.y < 0 or n.x >= m.cols or n.y >= m.rows or m.blocked.has(n):
								continue
							seen[n] = true
							q.append(n)
					if seen.size() < 40:
						why = "boxed in (%d cells)" % seen.size()
			if why == "":
				# You should arrive by the way back, not across the map from it.
				var best := 9999
				for e in m.exits:
					if str(e["scene"]) == str(l[0]):
						var r: Rect2i = e["rect"]
						var dx := maxi(0, maxi(r.position.x - c.x, c.x - (r.end.x - 1)))
						var dy := maxi(0, maxi(r.position.y - c.y, c.y - (r.end.y - 1)))
						best = mini(best, dx + dy)
				if best != 9999 and best > 5:
					var rs := []
					for e in m.exits:
						if str(e["scene"]) == str(l[0]):
							rs.append(e["rect"])
					why = "%d cells from the way back %s (map %dx%d)" % [best, str(rs), m.cols, m.rows]
			if why != "":
				print("  FAIL %s: %s -> %s at %s: %s" % [arc, l[0], l[1], str(c), why]); fails += 1
	print("exit_check: %d failures" % fails)
	quit(1 if fails > 0 else 0)

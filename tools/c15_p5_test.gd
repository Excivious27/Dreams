extends SceneTree
## C15 P5: seasonal look, FX and music hooks (both arcs).
##  - SeasonLook: every TWINS entry resolves to existing art per season; summer keeps
##    the base; foliage/cloth plaza props have a winter twin (c15_18-20, c15_13-01..06);
##  - the town plaza built in each look season uses the twins (sprite textures);
##  - InteriorSeason: store and inn get a seasonal wall piece in spring/fall/winter,
##    none in summer, never on a window or a thing (c15_13-04);
##  - Scenery sprinkle: per-season kind, none over iron/gilt/desert/frost maps (c15_17-04, c15_14-22);
##  - MusicResolve: festival songs per arc (gang never a penguin fair tune, harvest has its
##    stand-in), region look season drives the music season (c15_18-16, c15_17-07);
##    prints the season x home-map x arc matrix (report only).
## Run: godot --headless --path . --fixed-fps 60 -s res://tools/c15_p5_test.gd
var fails := 0

const FOLIAGE := ["c14p2_tree_planter", "c14p2_rose_arbour", "c14p2_flower_kiosk", "c14p2_cafe_umbrella", "c14p2_bench_curved", "c14p2_bench_iron",
	"planter2_0", "planter2_1", "planter2_2", "planter2_3", "flowerbed_pink", "topiary_a", "topiary_b", "hedge2_h", "hedge2_ball", "hedge2_tree", "hedge2_tree_s", "hedge2_pot", "topiary_c", "city_street_tree"]
## Foliage with no winter twin yet (art queue): reported, not failed.
const WINTER_ALLOW := []


func _initialize() -> void:
	Campaign.bypass = true
	seed(15)
	_run.call_deferred()


func check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _load(s: String) -> GameMap:
	GameMap.next_spawn = Vector2.ZERO
	GameState.run["scene"] = s
	GameState.run["flags"][s + "_seen"] = true
	change_scene_to_file("res://scenes/%s.tscn" % s)
	var gt := 0.0
	for i in 12:
		await process_frame
		gt += root.get_process_delta_time()
	return current_scene as GameMap


func _uses(m: GameMap, group: String, name: String) -> bool:
	var t := Art.tex(group, name)
	if t == null:
		return false
	for c in m.props:
		var n: Variant = m.props[c]
		if n is Sprite2D and is_instance_valid(n):
			var tx := (n as Sprite2D).texture
			if tx == t or (tx is AtlasTexture and (tx as AtlasTexture).atlas == t):
				return true
	return false


func _run() -> void:
	InputSetup.ensure_actions()
	# --- SeasonLook table ---
	for base: String in SeasonLook.TWINS:
		var row: Dictionary = SeasonLook.TWINS[base]
		for se: String in row:
			var g := "nature" if Art.has("nature", str(row[se])) else "props"
			check(Art.has(g, str(row[se])), "twin art exists: %s/%s" % [g, row[se]])
			check(SeasonLook.pick(g, base, se) == str(row[se]), "pick %s %s -> %s" % [base, se, row[se]])
		var g0 := "nature" if Art.has("nature", base) else "props"
		check(SeasonLook.pick(g0, base, "summer") == base or Art.has(g0, base + "_summer"), "summer keeps %s" % base)
	check(SeasonLook.pick("buildings", "house", "winter") == "house", "buildings keep their own snow path")
	check(SeasonLook.pick("props", "no_such_prop_x", "winter") == "no_such_prop_x", "missing twin keeps the base")
	for f: String in FOLIAGE:
		if not Art.has("props", f):
			continue
		var tw := SeasonLook.pick("props", f, "winter")
		if f in WINTER_ALLOW:
			print("c15_p5 report: no winter twin for ", f)
			continue
		check(tw != f, "foliage prop %s has a winter twin" % f)
	# --- town plaza in each look season, both arcs ---
	for arc: String in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi", "T", "Town", "Pup")
		GameState.run["intro_done"] = true
		for fl in ["cm_seen", "meow_taught", "town_seen", "gangsters_intro"]:
			GameState.run["flags"][fl] = true
		for si in 4:
			var se: String = MusicResolve.SEASONS[si]
			GameState.run["day"] = si * GameState.DAYS_PER_SEASON + 5
			GameState.run["time"] = 10 * 60
			var m: GameMap = await _load("town")
			var want := SeasonLook.pick("props", "c14p2_tree_planter", se)
			check(_uses(m, "props", want), "%s %s: plaza tree planter is %s" % [arc, se, want])
			if se != "summer":
				check(not _uses(m, "props", "c14p2_tree_planter"), "%s %s: no summer-leaf planter left" % [arc, se])
	# --- interiors ---
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	for iid: String in ["store", "inn"]:
		for si in 4:
			var se: String = MusicResolve.SEASONS[si]
			GameState.run["day"] = si * GameState.DAYS_PER_SEASON + 5
			GameState.run["time"] = 10 * 60
			GameMap.next_interior = iid
			var m: GameMap = await _load("interior")
			var pk := InteriorSeason.picks(m, se)
			var wins: Array = m.call("window_cols")
			if se == "summer":
				check(pk.is_empty(), "%s summer: room as drawn" % iid)
			else:
				check(not pk.is_empty(), "%s %s: a seasonal wall piece" % [iid, se])
				for p: Array in pk:
					var c: Vector2i = p[1]
					check(not (c.x in wins) and not m.things.has(c), "%s %s: piece off windows/things at %s" % [iid, se, c])
					check(_uses(m, "decor", str(p[0])), "%s %s: %s hung" % [iid, se, p[0]])
			var wp: Array = m.get("_win_props")
			if se == "winter" and not wp.is_empty():
				check((wp[0][0] as Sprite2D).modulate == InteriorSeason.WINDOW_TINT["winter"], "%s winter: frosted windows" % iid)
	# --- rain splashes (c15_14-06) ---
	GameState.run["day"] = 5
	var fm: GameMap = await _load("farm")
	var sk = fm.get("sky")
	check(sk != null, "farm has a weather layer")
	if sk != null:
		paused = false  # an arrival dialogue may hold the tree
		sk.weather = "rain"
		var gt := 0.0
		var most := 0
		for i in 60:
			await process_frame
			paused = false
			gt += root.get_process_delta_time()
			most = maxi(most, (sk._splashes as Array).size())
		check(most >= 1 and most <= 16, "rain: a few ground splashes (%d)" % most)
		sk.weather = "clear"
		for i in 30:
			await process_frame
		check((sk._splashes as Array).is_empty(), "clear: splashes gone")
	# --- sprinkle ---
	check(Scenery.sprinkle_kind("spring") == "petal_pink" and Scenery.sprinkle_kind("fall") == "leaf_orange", "spring petals, fall leaves")
	check(Scenery.sprinkle_kind("summer") == "leaf_green" and Scenery.sprinkle_kind("winter") == "snowflake", "summer leaves, winter flurries")
	for id: String in ["iron_freight_yards", "gilt_grand_plaza", "desert_dune_sea", "frost_glacier", "colony_coral", "neon", "uptown"]:
		check(not Scenery.sprinkle_ok(id), "no sprinkle over " + id)
	for id: String in ["farm", "town", "forest", "meadow", "gloam_violet_glade"]:
		check(Scenery.sprinkle_ok(id), "sprinkle over " + id)
	# --- festival music ---
	for fid: String in ["egg", "lantern", "harvest", "star"]:
		for night: bool in [false, true]:
			var p := MusicResolve.festival_track(fid, night, "penguins")
			var g := MusicResolve.festival_track(fid, night, "gangsters")
			check(p != "" and not p.ends_with("_gang"), "penguin festival %s night=%s -> %s" % [fid, night, p])
			check(g != "" and not (g.begins_with("festival") and not g.ends_with("_gang")), "gang festival %s night=%s never a penguin fair tune -> %s" % [fid, night, g])
	check(MusicResolve.festival_track("harvest", false, "penguins") != "festival" or Music.has_track("festival_harvest"), "harvest fair has its own stand-in")
	check(MusicResolve.festival_track("", false, "penguins") == "", "no festival, no song")
	# region look season drives the music season
	GameState.run["day"] = GameState.DAYS_PER_SEASON + 5  # summer
	GameState.look_season = "winter"
	check(str(MusicResolve.context()["season"]) == "winter", "a winter-look region hears winter (not the summer calendar)")
	check(MusicResolve.sky_weather("snow", "summer") == "clear" and MusicResolve.sky_weather("snow", "winter") == "snow", "snow music only where it looks like winter")
	check(MusicResolve.sky_weather("blizzard", "winter") == "storm", "blizzard plays the storm takes")
	GameState.look_season = ""
	# report: season x home map x arc
	for arc: String in ["penguins", "gangsters"]:
		for base: String in ["farm", "town", "forest", "lake", "meadow", "mountain", "beach"]:
			var row := []
			for se: String in MusicResolve.SEASONS:
				row.append(MusicResolve.pick(base, {"arc": arc, "season": se, "phase": "day", "weather": "clear", "stage": 0, "day": 3, "weekday": 1, "evening": false}))
			print("c15_p5 matrix %s %s: %s" % [arc, base, " | ".join(row)])
	print("c15_p5_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

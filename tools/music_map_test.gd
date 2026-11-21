extends SceneTree
## Every map, region, battle, colony and interior asks for a song that exists:
## packed in the web download, or in data/music_stream.json with its file on
## disk (the deploy copies those next to index.html). Checked for both arcs,
## by day and by night, with the conditional songs (rain, winter, festival,
## danger, raid, bosses, battle moods, endings) too.
##   godot --headless --path . -s res://tools/music_map_test.gd
var fails := 0
var checked := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	InputSetup.ensure_actions()
	GameState.load_data()
	_run.call_deferred()


## A song is playable on the web build: packed (not streamed) or streamed with a file to copy.
func _playable(t: String) -> bool:
	if t == "":
		return false
	var on_disk := FileAccess.file_exists("res://audio/music/%s.ogg" % t)
	return on_disk and (t in Music._stream_list() or ResourceLoader.exists("res://audio/music/%s.ogg" % t))


func _check_track(where: String, t: String) -> void:
	checked += 1
	check(_playable(t), "%s -> '%s' has no song" % [where, t])


## C13 place x state grid: maps walked through every season, day/dusk/night, clear/rain/storm/snow,
## a festival day and the epilogue, both arcs. Asserts the RIGHT song family, not just a song.
const C13_OPTIONAL := ["boss_dark_crystal", "boss_president"]
const GRID_MAPS := ["farm", "town", "beach", "forest", "meadow", "lake", "mountain", "countryside", "community_farm",
	"orchard_hills", "riverlands", "highlands", "crystal_meadow", "uptown", "docks", "neon", "hideout", "moon", "sky",
	"iron_freight_yards", "gilt_vaults", "colony_coral"]
## Penguin pastoral songs the gang arc must never get by day when the map has a _gang song.
const PASTORAL := ["farm", "town", "farm_fall", "winter", "beach", "forest", "meadow", "orchard", "lake", "mountain"]
## Shared penguin-toned songs the gang arc never gets at all.
const PENGUIN_SHARED := ["winter", "farm_fall", "morning", "evening_valley", "night_summer", "night_winter", "night_spring", "night_fall", "sanctuary"]


func _grid(m: GameMap, arc: String, label: String) -> void:
	var saved_day := int(GameState.run.get("day", 1))
	var saved_w: Variant = GameState.run.get("weather", {})
	for si in 4:
		for w: String in ["clear", "rain", "storm", "snow"]:
			for tm: int in [400, 600, 1080, 1380]:
				var day := 1 + si * GameState.DAYS_PER_SEASON + 3
				GameState.run["day"] = day
				GameState.run["weather"] = {str(day): w}
				GameState.run["time"] = tm
				var a := m.area_track()
				var lab := "%s %s/%s/%d" % [label, GameState.season(), w, tm]
				_check_track(lab, a)
				check(a == m.area_track(), lab + " re-ask gives the same song")
				if arc == "penguins":
					check(not a.ends_with("_gang") or a in ["shop_gang"], lab + " penguin arc plays a gang song '%s'" % a)
				else:
					check(not (a in PENGUIN_SHARED), lab + " gang arc plays penguin '%s'" % a)
					if a in PASTORAL and Music.has_track(a + "_gang"):
						check(false, lab + " gang arc plays pastoral '%s' while '%s_gang' exists" % [a, a])
	# Epilogue: still a playable song (the _after takes drop in when made).
	GameState.run["flags"]["epilogue_done"] = true
	_check_track(label + " epilogue", m.area_track())
	GameState.run["flags"].erase("epilogue_done")
	GameState.run["day"] = saved_day
	GameState.run["weather"] = saved_w
	GameState.run["time"] = 600


## Gang crew venues play their own song (interiors.json gangsters if_flag arc_music, c13_03-11).
func _crew_venues() -> void:
	GameState.new_run("gangsters", "man", "Tester", "Dreamhollow", "Pip")
	GameState.run["intro_done"] = true
	var rooms := {"inn": "crew_mama_rosa", "bakery": "shop_1", "clinic": "shop_3", "chapel": "crew_marlene", "cottage_c": "shop_2", "stable": "crew_halo"}
	var all: Dictionary = GameState.load_json("res://data/interiors.json")
	for iid: String in rooms:
		var f: String = rooms[iid]
		GameState.run["flags"][f] = true
		GameState.run["time"] = 600
		GameMap.next_spawn = Vector2.ZERO
		GameMap.next_interior = iid
		change_scene_to_file("res://scenes/interior.tscn")
		for i in 4:
			await process_frame
		var m := current_scene as GameMap
		if m == null:
			check(false, "crew venue %s did not load" % iid)
			continue
		var want_list: Array = all[iid]["gangsters"]["if_flag"][f].get("arc_music", [])
		check(not want_list.is_empty(), "crew venue %s has arc_music" % iid)
		var first := GameMap.first_track(want_list)
		var a := m.area_track()
		_check_track("crew venue " + iid, a)
		if first != "":
			check(a.begins_with(first), "crew venue %s plays its own song '%s' (got '%s')" % [iid, first, a])


func _scene_ids() -> Array:
	var ids: Array = []
	for f in DirAccess.get_files_at("res://scenes"):
		var n := f.trim_suffix(".remap").trim_suffix(".tscn")
		if f.ends_with(".tscn") or f.ends_with(".tscn.remap"):
			if n not in ["title", "test_map", "interior"] and not ids.has(n):
				ids.append(n)
	ids.sort()
	return ids


func _run() -> void:
	# Streamed list: every entry has its file; the packed set holds the stand-ins.
	for t: String in Music._stream_list():
		check(FileAccess.file_exists("res://audio/music/%s.ogg" % t), "streamed '%s' has no file to deploy" % t)
	for t: String in ["farm", "house", "title"]:
		check(t not in Music._stream_list() and ResourceLoader.exists("res://audio/music/%s.ogg" % t), "stand-in '%s' must be packed" % t)
	# Stream list, export excludes and audio/music agree (C6 c6_03 #9): an excluded
	# song not in the stream list would be silent on the site; a song neither
	# streamed nor embedded means tools/music_stream.py wasn't rerun.
	var sj: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/music_stream.json"))
	var embed: Array = (sj as Dictionary).get("embed", []) if sj is Dictionary else []
	check(not embed.is_empty(), "music_stream.json lists its embedded songs")
	var cfg := FileAccess.get_file_as_string("res://export_presets.cfg")
	var excl: Array = []
	var rx := RegEx.create_from_string('exclude_filter="([^"]*)"')
	var mt := rx.search(cfg)
	if mt:
		for part: String in mt.get_string(1).split(","):
			var pp := part.strip_edges()
			if pp.begins_with("audio/music/") and pp.ends_with(".ogg"):
				excl.append(pp.trim_prefix("audio/music/").trim_suffix(".ogg"))
	var sl: Array = Music._stream_list().duplicate()
	excl.sort()
	sl.sort()
	check(excl == sl, "export excludes == stream list (%d excluded, %d streamed)" % [excl.size(), sl.size()])
	for f: String in DirAccess.get_files_at("res://audio/music"):
		if f.ends_with(".ogg"):
			var nm := f.trim_suffix(".ogg")
			check(nm in sl or nm in embed, "audio/music/%s is neither streamed nor embedded: rerun tools/music_stream.py" % f)
			if nm in sl:
				check(Music.stream_ver(nm) != "", "%s has a cache version in music_stream.json" % nm)
	# Songs the game picks by situation.
	for t: String in ["night", "rain", "winter", "farm_fall", "festival", "danger", "raid", "mine_deep", "battle",
			"battle_siege", "battle_escort", "campaign_map", "title", "title_musicbox", "arc_gangsters", "arc_penguins",
			"ending_gangster", "ending_penguin", "credits", "merkitty_song", "shop", "shop_gang",
			"combat_light", "combat_light_gang", "combat_elite", "combat_elite_gang"] + GameMap.BOSS_TRACKS + DangerMusic.PER_BOSS.values():
		if t in C13_OPTIONAL and not Music.has_track(t):
			continue  # C13 songs (P3) that boss_track only asks for once they exist
		_check_track("situation", t)
	for k: String in GameMap.AREA_MUSIC:
		_check_track("AREA_MUSIC[%s]" % k, str(GameMap.AREA_MUSIC[k]))
	for k: String in GameMap.INTERIOR_MUSIC:
		_check_track("INTERIOR_MUSIC[%s]" % k, str(GameMap.INTERIOR_MUSIC[k]))
	var regions := GameState.load_json("res://data/regions.json")
	for k: String in regions:
		if regions[k] is Dictionary:
			_check_track("regions.json[%s].music" % k, str(regions[k].get("music", "meadow")))
	var interiors := GameState.load_json("res://data/interiors.json")
	for arc: String in ["penguins", "gangsters"]:
		GameState.new_run(arc, "man", "Tester", "Dreamhollow", "Pip")
		GameState.run["intro_done"] = true
		for f in ["cm_seen", "mine_open_1", "meow_taught", "moon_seen", "mine_seen", "intro_done", "gangsters_intro"]:
			GameState.run["flags"][f] = true
		var maps := _scene_ids()
		for id: String in maps:
			GameState.run["flags"][id + "_seen"] = true
		var jobs: Array = []
		for id: String in maps:
			jobs.append([id, ""])
		for iid: String in interiors:
			if interiors[iid] is Dictionary:
				jobs.append(["interior", iid])
		for j: Array in jobs:
			GameMap.next_spawn = Vector2.ZERO
			GameMap.next_interior = str(j[1])
			GameState.run["time"] = 600
			change_scene_to_file("res://scenes/%s.tscn" % j[0])
			for i in 4:
				await process_frame
			var m := current_scene as GameMap
			var label := "[%s] %s%s" % [arc, j[0], (":" + str(j[1])) if str(j[1]) != "" else ""]
			if m == null:
				check(false, label + " did not load as a map")
				continue
			_check_track(label + " day", m.area_track())
			GameState.run["time"] = 23 * 60
			_check_track(label + " night", m.area_track())
			GameState.run["time"] = 600
			if j[0] in GRID_MAPS or j[0] == "interior":
				_grid(m, arc, label)
	await _crew_venues()
	print("music_map_test: %d songs checked, %d failures" % [checked, fails])
	quit(1 if fails > 0 else 0)

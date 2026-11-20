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
	print("music_map_test: %d songs checked, %d failures" % [checked, fails])
	quit(1 if fails > 0 else 0)

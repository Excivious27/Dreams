extends SceneTree
## CONDUCT 13 P4: story, scene and minigame audio cues, over the LIVE beats
## (Story.data(): story.json penguins + story_gang.json gangsters + campaign_story.json).
##   godot --headless --path . -s res://tools/story_audio_test.gd
## Checks: every cue resolves (file, fallback, or a contract song that falls back safely);
## endings start their music on the first line of each branch (not after); final
## confrontations open on a tense song; dream beats open on mystery and hand back;
## every chapter has a title card; no gangster beat plays a penguin-only song; crew
## joins have their own jingle; key scenes (5+ lines) carry a cue; scene_song never
## plays the other arc's take and never a missing file; drill/capture/shot/hack/epilogue picks.
var fails := 0

## Songs from other C13 packages (contract section 3): fine to name before they land,
## because Dialogue.scene_song drops a missing one (the current song carries on).
const CONTRACT_SONGS := ["mood_sad", "mood_tense", "mood_mystery", "mood_triumph", "mood_comic", "mood_tender"]
const CONTRACT_SFX := ["howl_far", "locket_hum", "star_fall", "radio_static", "thunder_far", "crowd_cheer", "quake", "j_recruit", "j_heart_gang"]
## Key scenes allowed to stay without a cue (quiet on purpose).
const QUIET := ["p1_grump_truth_x"]
const PENGUIN_ONLY := ["finargle", "merkitty_song", "title_musicbox", "cattopia"]


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(13)
	_run.call_deferred()


func _sfx_ok(n: String) -> bool:
	for suf in ["", "_2", "_3"]:
		for ext in [".ogg", ".wav"]:
			if FileAccess.file_exists("res://audio/sfx/%s%s%s" % [n, suf, ext]):
				return true
	return false


func _song_ok(t: String) -> bool:
	return t == "area" or t == "stop" or Music.has_track(t) or t in CONTRACT_SONGS


func _lines_of(b: Dictionary) -> Array:
	var out: Array = []
	for l in b.get("lines", []):
		out.append(l)
		for k in (l as Dictionary).get("branches", {}):
			out.append_array(l["branches"][k])
	return out


func _has_cue(b: Dictionary) -> bool:
	var fx: Dictionary = b.get("effects", {})
	if fx.has("sfx") or fx.has("music") or b.has("pre") and (b["pre"] as Dictionary).has("music") or bool(b.get("title_card", false)):
		return true
	for l: Dictionary in _lines_of(b):
		if l.has("sfx") or l.has("music"):
			return true
	return false


func _run() -> void:
	var sd := Story.data()
	var all: Dictionary = {}
	var arc_of: Dictionary = {}
	var bad: Array = []
	var uncued: Array = []
	for arc in ["penguins", "gangsters", "both"]:
		for ch: Dictionary in sd.get(arc, []):
			var has_card := false
			for b: Dictionary in ch["beats"]:
				all[str(b["id"])] = b
				arc_of[str(b["id"])] = arc
				has_card = has_card or bool(b.get("title_card", false))
				var fx: Dictionary = b.get("effects", {})
				var pre: Dictionary = b.get("pre", {})
				if fx.has("sfx"):
					var n := Story.beat_sfx(str(fx["sfx"]))
					if not _sfx_ok(n) and not _sfx_ok(str(fx.get("sfx_fallback", "levelup"))):
						bad.append("%s fx sfx %s" % [b["id"], n])
				for src: Dictionary in [fx, pre]:
					if src.has("music") and not _song_ok(str(src["music"])) and not _song_ok(str(src.get("music_fallback", ""))):
						bad.append("%s music %s" % [b["id"], src["music"]])
				for l: Dictionary in _lines_of(b):
					if l.has("sfx") and not _sfx_ok(str(l["sfx"])) and not _sfx_ok(str(l.get("sfx_fallback", "pickup"))):
						bad.append("%s line sfx %s" % [b["id"], l["sfx"]])
					if l.has("sfx") and str(l["sfx"]) in CONTRACT_SFX and not _sfx_ok(str(l.get("sfx_fallback", "pickup"))):
						bad.append("%s new sfx %s has no real fallback" % [b["id"], l["sfx"]])
					if l.has("music") and not _song_ok(str(l["music"])) and not _song_ok(str(l.get("music_fallback", ""))):
						bad.append("%s line music %s" % [b["id"], l["music"]])
				if _lines_of(b).size() >= 5 and not _has_cue(b) and not (str(b["id"]) in QUIET):
					uncued.append(b["id"])
			if arc != "both":
				check(has_card, "chapter %s opens with a title card" % ch["id"])
	check(bad.is_empty(), "every live story cue exists, falls back, or is a contract song %s" % str(bad))
	check(uncued.is_empty(), "every key scene (5+ lines) carries a cue %s" % str(uncued))

	# Endings: music on the first line of every ending branch; no closing title_musicbox override.
	for id in ["p5_win", "g5_win", "g5_win_clean"]:
		var b: Dictionary = all[id]
		check(not (b.get("effects", {}) as Dictionary).has("music"), "%s: no shared closing song over the per-ending songs" % id)
		check((b.get("pre", {}) as Dictionary).has("music"), "%s: the aftermath song starts before the first line" % id)
		for l: Dictionary in b["lines"]:
			if l.has("branches"):
				for k in l["branches"]:
					var first: Dictionary = l["branches"][k][0]
					check(first.has("music"), "%s branch %s starts its own song on line 0" % [id, k])
	var shatter: Dictionary = (all["p5_win"]["lines"] as Array).filter(func(x: Dictionary) -> bool: return x.has("branches"))[0]["branches"]["1"][0]
	check(str(shatter.get("music", "")) != "title_musicbox", "The Quiet Mountain does not get the sweet music box")
	for id in ["p5_spire", "g5_president", "p5_bitter"]:
		check(str((all[id].get("pre", {}) as Dictionary).get("music", "")) == "mood_tense", "%s opens on the tense song" % id)
	for id in ["p2_dream", "p3_whisper", "p4_old_one", "p3_campfire"]:
		check(str((all[id].get("pre", {}) as Dictionary).get("music", "")) == "mood_mystery" and str(all[id]["effects"].get("music", "")) == "area", "%s: dream song held, map song after" % id)
	for id in ["g3_hale", "g3_hale_quiet", "g4_hale"]:
		check(str((all[id].get("pre", {}) as Dictionary).get("music", "")) == "mood_mystery", "%s: Hale has her motif" % id)
	var ep: Dictionary = all["g5_epilogue"]
	check(str(ep["effects"].get("toast", "")) != "" and not (ep["effects"] as Dictionary).has("sfx"), "gangster epilogue: thank-you toast back, closing cue per ending line")
	# Gangster beats never play a penguin-only song.
	var pen: Array = []
	for id: String in all:
		if arc_of[id] != "gangsters":
			continue
		var b: Dictionary = all[id]
		var songs: Array = [str(b.get("effects", {}).get("music", "")), str(b.get("pre", {}).get("music", ""))]
		for l: Dictionary in _lines_of(b):
			songs.append(str(l.get("music", "")))
		for s: String in songs:
			if s in PENGUIN_ONLY:
				pen.append("%s:%s" % [id, s])
	check(pen.is_empty(), "no gangster beat plays a penguin-only song %s" % str(pen))
	# Crew joins: their own jingle, never the quest fanfare twice.
	for id in ["g3_specs", "g3_ladder", "g3_halo", "g3_marlene_burned", "g3_marlene_late", "g4_twins"]:
		check(str(all[id]["effects"].get("sfx", "")) == "j_recruit", "%s: crew join plays j_recruit" % id)
	check(not Story.end_effects({"trigger": {"quest_done": "x"}, "effects": {"sfx": "levelup"}}).has("sfx"), "a quest-done beat drops a second fanfare")
	check(Story.end_effects({"trigger": {"scene": "x"}, "effects": {"sfx": "levelup"}}).has("sfx"), "other beats keep their effect sound")
	check(Story.scene_song_of(all["p5_spire"]) == "mood_tense" and Story.scene_song_of(all["g1_sal"]) == "", "scene_song_of reads pre/line-0 music")

	# Dialogue.scene_song: arc takes, safe fallbacks.
	GameState.run["arc"] = "penguins"
	check(Dialogue.scene_song("wedding") == "wedding", "penguins: wedding plays the penguin take")
	check(Dialogue.scene_song("wedding_gang") == "wedding", "penguins never play a _gang take")
	check(Dialogue.scene_song("no_such_song_xyz") == "", "a missing song plays nothing (current song carries on)")
	check(Dialogue.scene_song("no_such_song_xyz", "night") == "night", "a missing song uses the line's fallback")
	check(Dialogue.scene_song("area") == "area", "area passes through")
	GameState.run["arc"] = "gangsters"
	check(Dialogue.scene_song("wedding") == "wedding_gang", "gangsters: the _gang take first")
	check(Dialogue.scene_song("night") == "night_gang", "gangsters: night -> night_gang")
	for m in CONTRACT_SONGS:
		var got := Dialogue.scene_song(m)
		check(got == "" or Music.has_track(got), "%s resolves to a real file or nothing (%s)" % [m, got])
	GameState.run["arc"] = "penguins"
	# Narration with its own sound: no blip on top.
	check(not Dialogue.wants_blip({"who": "", "text": "x", "sfx": "glass"}) and Dialogue.wants_blip({"who": "", "text": "x"}) and Dialogue.wants_blip({"who": "Maple", "text": "x", "sfx": "pop"}), "narration with an sfx plays no blip")
	check(not Dialogue.creature_voice("Star Crystal").is_empty() and Dialogue.creature_voice("Maple").is_empty(), "crystals chime, villagers blip")

	# Hearts / epilogue / battle / foes / hack.
	check(Hearts.heart_mood(2) == "comic" and Hearts.heart_mood(10) == "tender", "heart scenes: light early, tender later")
	check(Epilogue.ending_track(false, "take").ends_with("_gang") or Epilogue.ending_track(false, "take") == "ending_gangster", "The Chair: a gang dark track or the gang ending")
	check(not Epilogue.ending_track(true, "shatter").ends_with("_gang"), "the penguin ending never takes a _gang track")
	check(Epilogue.ending_track(true, "revert") == "ending_penguin", "revert keeps the penguin ending theme")
	check(Battle.drill_end_cue(false, false) != "j_battle_lost" and Battle.drill_end_cue(false, true) != "j_battle_lost" and Battle.drill_end_cue(true, false) == "j_battle_won", "the drill never plays the defeat jingle")
	GameState.run["arc"] = "gangsters"
	check(not ("coin" in Battle.capture_cues() or "cash_pickup" in Battle.capture_cues()), "capturing a point never plays money")
	GameState.run["arc"] = "penguins"
	check(Enemy.shot_for("wisp", "dark", true, false) != "shot", "gang arc: a wisp does not fire a gun")
	check(Enemy.shot_for("thug", "dark", true, true) == "shot", "gang arc: a thug fires a gun")
	check(Enemy.shot_for("drone", "", true, false) == "laser" and Enemy.shot_for("eel", "", true, false) == "bubble", "drones fire lasers, eels spit bubbles")
	check(Enemy.shot_for("grump_archer", "", false, true) == "bow", "archers loose arrows")
	check(Enemy.summon_sound("president", true) == "whistle" and Enemy.summon_sound("commander", false) == "war_horn" and Enemy.summon_sound("dark_crystal", false) == "spell_dark", "summons sound like who calls")
	check(HackGame.TONE.size() == 4 and HackGame.TONE["up"] != HackGame.TONE["left"], "hack terminal: four pitched wire tones")
	var gal := FileAccess.get_file_as_string("res://scripts/arcade_gallery.gd")
	check(gal.contains("sfx(\"frog\"") and not gal.contains("croak"), "shooting-gallery frog croaks with the real frog take")
	print("story_audio_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)

class_name Achievements
## Achievements (CONDUCT S1 P2). Data: data/achievements.json (tools/gen_achievements.py).
## Every achievement is state-derived: scan() re-checks the live run, so old saves
## unlock retroactively and nothing is scattered through the big files. scan() runs
## from GameState.save() (before the flush) and from the title screen.
##
## Storage is ACCOUNT-WIDE (per device), never per save: SaveGame global "ach" =
## {"u": {id: day_unlocked}, "s": {stat: value}, "end": bits, "arcs": bits, "co_day": [..]}.
## Writes go into SaveGame's cache only (no flush per event, s1_03-14); the save that
## called scan() flushes them.
##
## Backends: local always; Steam when the SteamService autoload (P1) is present and
## live: SteamService.set_achievement(api) / set_stat(name, v) / store_stats() /
## set_rich_presence(key, value) (each called only if the method exists).
## Guards (s1_04-16, s1_05-13): nothing unlocks while Campaign.bypass, in the test
## map, or in a run flagged "test". Steam is never fed from headless or
## DREAMS_NO_STEAM=1 runs (CI, bots, playtest), even though the local list records.

const PATH := "res://data/achievements.json"
const KEY := "ach"
const _SHOW := preload("res://scripts/animal_show.gd")

static var _data: Dictionary = {}
static var _pending: Array = []      # ids waiting for a toast (a map with a free screen top)
static var silent := false           # tests: no toasts or sounds


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var v: Variant = JSON.parse_string(f.get_as_text())
			if v is Dictionary:
				_data = v
	return _data


static func list() -> Array:
	return data().get("list", [])


static func def(id: String) -> Dictionary:
	for a: Dictionary in list():
		if str(a["id"]) == id:
			return a
	return {}


static func total() -> int:
	return list().size()


static func store() -> Dictionary:
	var all := SaveGame.load_all()
	if not (all.get(KEY) is Dictionary):
		all[KEY] = {}
	var s: Dictionary = all[KEY]
	for k in ["u", "s"]:
		if not (s.get(k) is Dictionary):
			s[k] = {}
	return s


static func is_unlocked(id: String) -> bool:
	return (store()["u"] as Dictionary).has(id)


static func count_unlocked() -> int:
	var n := 0
	for a: Dictionary in list():
		if is_unlocked(str(a["id"])):
			n += 1
	return n


static func stat(name: String) -> int:
	return int((store()["s"] as Dictionary).get(name, 0))


## Steam-style stat: only ever raised (a newer save with less progress never lowers it).
static func set_stat(name: String, v: int) -> void:
	if not data().get("stats", {}).has(name):
		return
	v = clampi(v, 0, int(data()["stats"][name].get("max", v)))
	var s: Dictionary = store()["s"]
	if v <= int(s.get(name, 0)):
		return
	s[name] = v
	_steam("set_stat", [name, v])


static func enabled() -> bool:
	if Campaign.bypass:
		return false
	if GameState.run.is_empty() or bool(GameState.run.get("test", false)):
		return false
	if not (GameState.run.get("inventory") is Dictionary):
		return false  # a half-built run (tests, slot switches): nothing to judge yet
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene and str(tree.current_scene.scene_file_path).contains("test_map"):
		return false
	return true


static func unlock(id: String) -> bool:
	if is_unlocked(id) or def(id).is_empty() or not enabled():
		return false
	(store()["u"] as Dictionary)[id] = int(GameState.run.get("day", 0))
	_steam("set_achievement", [str(def(id)["api"])])
	_pending.append(id)
	return true


## Re-checks every achievement against the live run; returns the ids newly unlocked.
static func scan() -> Array:
	var got: Array = []
	if not enabled():
		return got
	_globals()
	var visiting := Net.visiting()
	var arc := str(GameState.run.get("arc", ""))
	for a: Dictionary in list():
		var id := str(a["id"])
		var aa := str(a.get("arc", "both"))
		var src := str(a.get("src", "own"))
		if src != "net" and src != "global" and aa != "both" and aa != arc:
			continue
		if visiting and src != "net":
			continue  # a guest's run holds the host's world (s1_04-18): only co-op ones count
		var r := _check(a["check"])
		if str(a.get("stat", "")) != "":
			set_stat(str(a["stat"]), int(r[1]))
		if bool(r[0]) and unlock(id):
			got.append(id)
	if not got.is_empty():
		_steam("store_stats", [])
	Presence.push()
	flush_toasts()
	return got


## Endings seen and arcs finished across every save (global bits, s1_04-08).
static func _globals() -> void:
	var s := store()
	var flags: Dictionary = GameState.run.get("flags", {})
	var ends: Array = data().get("endings", [])
	var eb := int(s.get("end", 0))
	var any := false
	for i in ends.size():
		if flags.has("ending_" + str(ends[i])):
			eb |= 1 << i
			any = true
	s["end"] = eb
	if any or flags.has("epilogue_done"):
		s["arcs"] = int(s.get("arcs", 0)) | (1 if GameState.run.get("arc", "") == "penguins" else 2)


static func _bits(n: int) -> int:
	var c := 0
	while n > 0:
		c += n & 1
		n >>= 1
	return c


static func _flags() -> Dictionary:
	return GameState.run.get("flags", {})


## [done, progress] for one check dict (kinds: tools/gen_achievements.py CHECK_KINDS).
static func _check(c: Dictionary) -> Array:
	var n := int(c.get("n", 1))
	var flags := _flags()
	var v := 0
	match str(c.get("k", "")):
		"grown":
			for k in (GameState.run.get("grown", {}) as Dictionary).values():
				v += int(k)
		"gold":
			for q in (GameState.run.get("quality", {}) as Dictionary).values():
				if q is Dictionary and int((q as Dictionary).get("g", 0)) > 0:
					v = 1
			n = 1
		"hearts":
			var h := int(c.get("h", 5)) * 25
			for npc in (GameState.run.get("friendship", {}) as Dictionary):
				if int(GameState.run["friendship"][npc]) >= h and (GameState.npcs.is_empty() or GameState.npcs.has(npc)):
					v += 1
		"flag":
			v = 1 if flags.has(str(c["f"])) and bool(flags[str(c["f"])]) else 0
			n = 1
		"flag_any":
			for f in c["f"]:
				if flags.has(str(f)):
					v = 1
			n = 1
		"flag_prefix":
			var only: Array = c.get("only", [])
			for k: String in flags:
				if not bool(flags[k]):
					continue
				if only.is_empty():
					if k.begins_with(str(c["p"])) or (c.has("or") and k.begins_with(str(c["or"]))):
						v += 1
				elif k in only:
					v += 1
		"wins":
			for cd in (Campaign.st().get("c", {}) as Dictionary).values():
				if cd is Dictionary:
					v += int((cd as Dictionary).get("wins", 0))
		"won":
			var won: Dictionary = Campaign.st().get("won", {})
			for cid in c["ids"]:
				if won.has(str(cid)):
					v += 1
		"arcade":
			v = 1 if ArcadeHub.milestone(str(c["ms"])) else 0
			n = 1
		"cf_stage":
			v = Commons.stage()
		"claimed":
			v = 1 if (Collections.st()["claimed"] as Dictionary).has(str(c["id"])) else 0
			n = 1
		"caught_legend":
			var leg: Dictionary = Collections.data().get("legends", {}) if Collections.data().get("legends") is Dictionary else {}
			for k in leg:
				if (Collections.st()["caught"] as Dictionary).has(str(k)):
					v = 1
			n = 1
		"secrets":
			for p in c["p"]:
				v += Secrets.found(str(p))
		"ranch_any":
			var past: Variant = Ranch.st().get("past", [])
			v = 1 if not Ranch.animals().is_empty() or ((past is Dictionary or past is Array) and not past.is_empty()) else 0
			n = 1
		"ranch_baby":
			for a in Ranch.animals().values():
				if a is Dictionary and not ((a as Dictionary).get("parents", []) as Array).is_empty():
					v = 1
			v = maxi(v, 1 if flags.has("ach_ranch_baby") else 0)
			n = 1
		"ranch_rare":
			for uid in Ranch.animals():
				if Ranch.is_rare(str(uid)):
					v = 1
			n = 1
		"show_blue":
			v = int(flags.get("show_blue", 0))
			n = 1
		"decor":
			v = int(DecorCatalogue.progress()[0])
		"sets":
			v = (Decor.st().get("sets_done", {}) as Dictionary).size() if Decor.st().get("sets_done") is Dictionary else 0
		"colonies":
			v = Colony.saved()
		"ranch_gift":
			v = 1 if RanchGift.given(str(c["key"])) else 0
			n = 1
		"crew":
			v = Crew.all_recruited().size()
		"turf":
			v = (GameState.run.get("turf", {}) as Dictionary).size() if GameState.run.get("turf") is Dictionary else 0
		"washed":
			v = int(GameState.run.get("racket_washed", 0))
		"shops_clean":
			var decided := 0
			var bad := false
			for i in range(1, 4):
				var k := "shop_%d" % i
				if flags.has(k + "_decided"):
					decided += 1
					if not (flags.has(k + "_refused") or flags.has(k + "_returned")) or (flags.has(k) and not flags.has(k + "_returned")):
						bad = true
			v = 1 if decided >= 2 and not bad else 0
			n = 1
		"marked_free":
			for id: String in Marked.all():
				if Marked.state(id) == "free":
					v += 1
		"built":
			var t := int(c.get("t", 1))
			var all_ok := true
			for id in c["ids"]:
				if Crafting.own_tier(str(id)) >= t:
					v += 1
				else:
					all_ok = false
			v = 1 if all_ok else 0
			n = 1
		"regions":
			var ids: Array = c.get("ids", [])
			if ids.is_empty():
				ids = c.get("ids_gang" if GameState.run.get("arc", "") == "gangsters" else "ids_peng", [])
			if n <= 0:
				n = ids.size()
			for id in ids:
				if flags.has("mseen_" + str(id)):
					v += 1
		"year":
			v = (int(GameState.run.get("day", 1)) - 1) / _SHOW.YEAR_DAYS + 1
		"earned":
			v = int(GameState.run.get("earned_total", 0))
		"endings":
			v = _bits(int(store().get("end", 0)))
		"arcs":
			v = _bits(int(store().get("arcs", 0)))
		"net_online":
			v = 1 if Net.online() else 0
			n = 1
		"net_host":
			v = Net.i().peers.size() if Net.online() and Net.is_host() and Net.i() else 0
		"net_peers":
			v = Net.i().peers.size() if Net.online() and Net.i() else 0
		"net_mixed":
			if Net.online() and Net.i():
				for p in Net.i().peers.values():
					if p is Dictionary and str((p as Dictionary).get("arc", "")) not in ["", str(GameState.run.get("arc", ""))]:
						v = 1
			n = 1
	return [v >= n, v]


## Shows queued unlocks on the current map's HUD when the screen top is free.
static func flush_toasts() -> void:
	if _pending.is_empty() or silent or DisplayServer.get_name() == "headless":
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var m := tree.current_scene
	var hud: Variant = m.get("hud") if "hud" in m else null
	if hud == null or not is_instance_valid(hud) or Dialogue.instance(tree).active:
		return
	if _steam_live() and not _steam_toasts():
		_pending.clear()  # Steam's own overlay popup shows it
		return
	var names: Array = []
	for id: String in _pending:
		names.append(str(def(id).get("name", id)))
	_pending.clear()
	(hud as Object).call("toast", "Achievement: " + ", ".join(names), Color(1.0, 0.86, 0.4))
	if Music.instance(tree):
		Music.instance(tree).sfx("ach_unlock", "levelup")


## The title list's row text: hidden ones stay "???" while locked (s1_04-13 case 7).
static func row_text(id: String) -> Array:
	var a := def(id)
	if is_unlocked(id) or not bool(a.get("hidden", false)):
		return [str(a.get("name", id)), str(a.get("desc", ""))]
	return ["???", str(a.get("hint", "A secret."))]


static func progress_text(id: String) -> String:
	var a := def(id)
	var st := str(a.get("stat", ""))
	if st == "" or is_unlocked(id) or bool(a.get("hidden", false)):
		return ""
	return "%d/%d" % [mini(stat(st), int(a["goal"])), int(a["goal"])]


# --- save-code transfer (s1_04-15, s1_05-09) ---

static func export_dict() -> Dictionary:
	return store().duplicate(true)


## Union of unlocks, max of every stat and bit set (never lowers).
static func merge(d: Variant) -> void:
	if not d is Dictionary:
		return
	var s := store()
	for id in (d as Dictionary).get("u", {}):
		if not (s["u"] as Dictionary).has(id):
			s["u"][id] = int(d["u"][id])
	for k in (d as Dictionary).get("s", {}):
		s["s"][k] = maxi(int(s["s"].get(k, 0)), int(d["s"][k]))
	for k in ["end", "arcs"]:
		s[k] = int(s.get(k, 0)) | int((d as Dictionary).get(k, 0))


# --- Steam bridge (P1 owns SteamService) ---

static func _service() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("SteamSvc")


static func _steam_live() -> bool:
	if OS.has_feature("web") or OS.get_environment("DREAMS_NO_STEAM") == "1" or DisplayServer.get_name() == "headless":
		return false
	var s := _service()
	if s == null:
		return false
	if s.has_method("is_live"):
		return bool(s.call("is_live"))
	return bool(s.get("live")) if "live" in s else false


static func _steam_toasts() -> bool:
	var s := _service()
	return s != null and s.has_method("overlay_enabled") and not bool(s.call("overlay_enabled"))


static func _steam(method: String, args: Array) -> void:
	if not _steam_live():
		return
	var s := _service()
	if s.has_method(method):
		s.callv(method, args)


## Pushes every local unlock and stat to Steam (first launch on Steam after a save code).
static func replay_to_steam() -> void:
	if not _steam_live():
		return
	for id in store()["u"]:
		if not def(str(id)).is_empty():
			_steam("set_achievement", [str(def(str(id))["api"])])
	for k in store()["s"]:
		_steam("set_stat", [str(k), int(store()["s"][k])])
	_steam("store_stats", [])

class_name MegaRegion
extends RefCounted
## Mega regions: the big separate worlds you unlock later in the game (Space, the
## Merkitty Colonies, the Lieutenant Cities, the Hollow Heart, the Sky Isles and
## the new ones). Data: data/mega_regions.json from tools/gen_mega_regions.py
## (edit that). Every scene not listed in a region belongs to the Valley.
## A region shows (its own tab in Menu > Map, drawn by MegaMap) once it is
## unlocked: its unlock condition holds or you arrive in one of its areas.
## Regions whose areas have no scene yet stay hidden whatever the save says.
## Crossing into / out of a region shows its name banner and travel line.
## Save: run["mega"] = {"v": 1, "unlocked": {id: day}, "last": region of the last
## outdoor scene ("" = Valley)}. Old saves are migrated from what you've seen.

const VALLEY := ""
const SKIP_SCENES := ["interior", "house", "title", "test_map"]

static var _d: Dictionary = {}
static var _scene_ok: Dictionary = {}


static func data() -> Dictionary:
	if _d.is_empty():
		_d = GameState.load_json("res://data/mega_regions.json")
	return _d


static func get_r(id: String) -> Dictionary:
	return data().get("list", {}).get(id, {})


## Every region id, in map-tab order (all arcs).
static func ids() -> Array:
	return data().get("order", [])


## The mega region `scene` belongs to ("" = the Valley).
static func region_of(scene: String) -> String:
	return str(data().get("area_of", {}).get(scene, VALLEY))


static func area(id: String, scene: String) -> Dictionary:
	for a in get_r(id).get("areas", []):
		if str(a["id"]) == scene:
			return a
	return {}


static func area_name(scene: String) -> String:
	var a := area(region_of(scene), scene)
	return str(a.get("name", scene.replace("_", " ").capitalize()))


static func _arc() -> String:
	return "penguins" if GameState.is_penguins() else "gangsters"


static func in_arc(id: String) -> bool:
	return str(get_r(id).get("arc", "both")) in ["both", _arc()]


static func area_in_arc(id: String, a: Dictionary) -> bool:
	return str(a.get("arc", get_r(id).get("arc", "both"))) in ["both", _arc()]


static func scene_exists(scene: String) -> bool:
	if not _scene_ok.has(scene):
		_scene_ok[scene] = ResourceLoader.exists("res://scenes/%s.tscn" % scene)
	return bool(_scene_ok[scene])


## This run's areas of a region that exist as scenes.
static func areas(id: String) -> Array:
	var out: Array = []
	for a in get_r(id).get("areas", []):
		if area_in_arc(id, a) and scene_exists(str(a["id"])):
			out.append(a)
	return out


## The region can exist in this run: right arc and at least one area built.
static func available(id: String) -> bool:
	return not get_r(id).is_empty() and in_arc(id) and not areas(id).is_empty()


# ---- save ----------------------------------------------------------------------

static func st() -> Dictionary:
	var r := GameState.run
	if r.is_empty():
		return {"v": 1, "unlocked": {}, "last": VALLEY}
	if not (r.get("mega") is Dictionary):
		r["mega"] = {"v": 1, "unlocked": {}, "last": region_of(str(r.get("scene", "")))}
		_migrate(r["mega"])
	var s: Dictionary = r["mega"]
	if not (s.get("unlocked") is Dictionary):
		s["unlocked"] = {}
	if not s.has("last"):
		s["last"] = VALLEY
	return s


## Older saves: every region whose condition already holds (or that you've stood
## in) is open, quietly: no toasts for things you did before the update.
static func _migrate(s: Dictionary) -> void:
	for id: String in ids():
		if available(id) and (condition_met(id) or _any_seen(id) or region_of(str(GameState.run.get("scene", ""))) == id):
			s["unlocked"][id] = int(GameState.run.get("day", 1))


static func is_unlocked(id: String) -> bool:
	return available(id) and (st()["unlocked"] as Dictionary).has(id)


## Unlocked regions of this run, in tab order.
static func unlocked() -> Array:
	var out: Array = []
	for id: String in ids():
		if is_unlocked(id):
			out.append(id)
	return out


## Open a region (true if it was newly opened).
static func unlock(id: String) -> bool:
	if not available(id) or (st()["unlocked"] as Dictionary).has(id):
		return false
	st()["unlocked"][id] = int(GameState.run.get("day", 1))
	return true


## Opens every region whose condition holds now; returns the ids newly opened.
static func check_unlocks() -> Array:
	var got: Array = []
	if GameState.run.is_empty():
		return got
	for id: String in ids():
		if not (st()["unlocked"] as Dictionary).has(id) and available(id) and (condition_met(id) or _any_seen(id)):
			if unlock(id):
				got.append(id)
	return got


# ---- conditions ------------------------------------------------------------------

static func seen(scene: String) -> bool:
	var r := GameState.run
	return (r.get("visited", {}) as Dictionary).has(scene) or (r.get("flags", {}) as Dictionary).has(scene + "_seen")


static func _any_seen(id: String) -> bool:
	for a in areas(id):
		if seen(str(a["id"])):
			return true
	return false


static func condition_met(id: String) -> bool:
	var u: Variant = get_r(id).get("unlock", {})
	return u is Dictionary and not (u as Dictionary).is_empty() and cond(u)


static func cond(c: Dictionary) -> bool:
	var fl: Dictionary = GameState.run.get("flags", {})
	if c.has("any"):
		for x in c["any"]:
			if x is Dictionary and cond(x):
				return true
		return false
	if c.has("all"):
		for x in c["all"]:
			if not (x is Dictionary and cond(x)):
				return false
		return true
	if c.has("seen"):
		return seen(str(c["seen"]))
	if c.has("flag"):
		return fl.has(str(c["flag"]))
	if c.has("quest"):
		return GameState.has_quest(str(c["quest"])) or GameState.quest_done(str(c["quest"]))
	if c.has("quest_done"):
		return GameState.quest_done(str(c["quest_done"]))
	if c.has("tier"):
		return GameState.progress_tier() >= int(c["tier"])
	if c.has("built"):
		return Builds.built_tier(str(c["built"][0])) >= int(c["built"][1])
	if c.has("campaign_ready"):
		var cid := str(c["campaign_ready"])
		if Campaign.get_c(cid).is_empty() or str(Campaign.get_c(cid).get("arc", "both")) not in ["both", _arc()]:
			return false
		return Campaign.is_won(cid) or Campaign.started(cid) or Campaign.why_locked(cid) == ""
	if c.has("campaign_won"):
		return Campaign.is_won(str(c["campaign_won"]))
	if c.has("arc"):
		return str(c["arc"]) == _arc()
	return false


# ---- arriving ------------------------------------------------------------------

## Hooked from GameMap._ready: unlock what is due, and when you crossed into
## (or out of) a mega region, show its banner and travel line.
static func on_enter(m: GameMap) -> void:
	if GameState.run.is_empty() or m == null:
		return
	var sid := m.scene_id()
	if sid in SKIP_SCENES or sid.begins_with("bf_"):
		return
	var s := st()
	var here := region_of(sid)
	var fresh: Array = check_unlocks()
	if here != VALLEY and unlock(here):
		fresh.append(here)
	var last := str(s.get("last", VALLEY))
	s["last"] = here
	MegaMap.tab = here if here != VALLEY else "valley"
	if here != last:
		var line := ""
		if here != VALLEY:
			line = str(get_r(here).get("travel", ""))
		elif last != "" and not get_r(last).is_empty():
			line = str(get_r(last).get("leave", ""))
		banner(m, here, sid, line)
	for id in fresh:
		if id != here:
			m.hud.toast("New map tab: %s (Menu > Map)" % str(get_r(str(id))["name"]), Color(0.85, 0.95, 1.0))
	if here != VALLEY and fresh.has(here):
		m.hud.toast("%s has its own map tab now (Menu > Map)." % str(get_r(here)["name"]), Color(0.85, 0.95, 1.0))


## The name card: region name big, area name and the travel line under it.
static func banner(m: GameMap, id: String, sid: String, line: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 8
	layer.name = "MegaBanner"
	layer.process_mode = Node.PROCESS_MODE_ALWAYS  # an arrival intro pauses the tree; the card still fades
	m.add_child(layer)
	var r := get_r(id)
	var th: Dictionary = r.get("theme", {})
	var acc := _col(th.get("accent", [1, 0.9, 0.6]))
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.08, 0.78)
	sb.border_color = acc
	sb.set_border_width_all(1)
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 5
	sb.content_margin_bottom = 6
	box.add_theme_stylebox_override("panel", sb)
	box.position = Vector2(20, 70)
	box.size = Vector2(230, 0)
	box.custom_minimum_size = Vector2(230, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(v)
	var title := Label.new()
	title.text = str(r.get("name", "The Valley")) if id != VALLEY else "%s Valley" % str(GameState.run.get("names", {}).get("town", "Home"))
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", acc if id != VALLEY else Color(0.75, 1.0, 0.65))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := Label.new()
	sub.text = area_name(sid) if id != VALLEY else sid.replace("_", " ").capitalize()
	sub.add_theme_font_size_override("font_size", 9)
	sub.add_theme_color_override("font_color", Color(1, 0.96, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	if line != "":
		var t := Label.new()
		t.text = line
		t.add_theme_font_size_override("font_size", 8)
		t.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(box, "modulate:a", 1.0, 0.5)
	tw.tween_interval(clampf(2.4 + line.length() * 0.03, 2.6, 5.5))
	tw.tween_property(box, "modulate:a", 0.0, 0.8)
	tw.tween_callback(layer.queue_free)
	Music.instance(m.get_tree()).sfx("j_region", "levelup")


static func _col(v: Variant) -> Color:
	if v is Array and (v as Array).size() >= 3:
		return Color(float(v[0]), float(v[1]), float(v[2]))
	return Color.WHITE


static func color(id: String, key: String) -> Color:
	return _col(get_r(id).get("theme", {}).get(key, [1, 1, 1]))

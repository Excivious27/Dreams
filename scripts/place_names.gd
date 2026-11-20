class_name PlaceNames
## The name of the place you're standing in, for the HUD's region label:
## outdoor maps by id (arc-aware), battlefields and colonies from their data,
## interiors by the door you came in through (its hint), the mine with its floor.

const NAMES := {
	"farm": "Your Farm", "house": "Farmhouse", "forest": "The Forest", "lake": "The Lake",
	"meadow": "The Meadow", "mountain": "The Mountain", "beach": "The Beach", "moon": "The Moon",
	"wastes": "The Wastes", "hideout": "Hideout", "docks": "The Docks", "neon": "Neon District",
	"uptown": "Uptown", "underground": "The Underground", "countryside": "The Highway", "sky": "Sky Islands",
	"station": "Sky Station", "jungle": "The Jungle", "orchard_hills": "Orchard Hills", "highlands": "The Highlands",
	"ruins": "The Ruins", "quarry": "The Quarry", "marsh": "The Marsh", "riverlands": "Riverlands",
	"hollow_heart": "The Hollow Heart", "test_map": "Test Map",
}
## Interiors entered without a door hint (the clinic after a faint, a reload).
const INTERIORS := {
	"store": "General Store", "smith": "Blacksmith", "potions": "Potion Shop", "hall": "Town Hall", "inn": "The Inn",
	"bakery": "Bakery", "clinic": "Clinic", "library": "Library", "chapel": "Chapel", "cottage_a": "Wren's Cottage",
	"cottage_b": "Finn's Cottage", "cottage_c": "Lumi & Theo's Cottage", "hazel_house": "Hazel's Farmhouse",
	"stable": "Stable", "lodge": "Rook's Lodge", "bank": "Bank", "mansion": "Mayor's House", "school": "School",
	"fishing_hut": "Bait Shop", "water_mill": "Water Mill", "lighthouse": "Lighthouse", "quarry_office": "Quarry Office",
	"sel_camp": "Sel's Camp", "tam_hut": "Tam's Hut", "moss_hut": "Moss's Hut", "river_hut": "River Hut",
}


static func of(m: GameMap) -> String:
	if m == null:
		return ""
	return for_id(m.scene_id(), m)


## The label for scene `id` (m, if given, supplies the mine floor).
static func for_id(id: String, m: GameMap = null) -> String:
	var r := GameState.run
	match id:
		"title":
			return ""
		"interior":
			var iid := str(r.get("interior", ""))
			if str(r.get("interior_name_for", "")) == iid and str(r.get("interior_name", "")) != "":
				return str(r["interior_name"])
			var sk: String = load("res://scripts/interior.gd").skin_name(iid)  # crew shop moved in (C5 P2 hook)
			if sk != "":
				return sk
			if iid == "rec":
				return RecCenter.name()
			if iid == "rec_up":
				return RecCenter.name() + " · Lanes"
			return str(INTERIORS.get(iid, iid.capitalize()))
		"town":
			var tn := str(r.get("names", {}).get("town", ""))
			return tn if tn != "" else "Town"
		"community_farm":
			return Commons.place_name()
		"crystal_meadow":
			return "Crystal Meadow" if GameState.is_penguins() else "The Outskirts"
		"mine":
			var f = m.get("floor_no") if m != null else null
			return "The Mine · Floor %d" % int(f) if f != null else "The Mine"
	if id.begins_with("bf_"):
		var b: Dictionary = GameState.load_json("res://data/battles.json").get(id, {})
		if b.has("title"):
			return str(b["title"])
	if id.begins_with("colony_"):
		var c: Dictionary = GameState.load_json("res://data/colonies.json").get(id, {})
		if c.has("name"):
			return str(c["name"])
	# Mega-region areas ("wind_breezehaven") carry their own names ("Breezehaven"),
	# the same words as the Map tab and the banner (CONDUCT 4: moon/station/sky too).
	if MegaRegion.region_of(id) != MegaRegion.VALLEY:
		var a := MegaRegion.area(MegaRegion.region_of(id), id)
		if a.has("name"):
			var an = a.get("name_" + ("penguins" if GameState.is_penguins() else "gangsters"), a["name"])
			return str(an)
	if NAMES.has(id):
		return str(NAMES[id])
	return id.replace("_", " ").capitalize()


## Called as you go through a door: remember the name on it ("A: Deuce's arcade"
## -> "Deuce's Arcade") so the room is labelled the way the sign read.
static func entering(m: GameMap) -> void:
	var r := GameState.run
	r.erase("interior_name")
	r.erase("interior_name_for")
	if m == null or m.player == null or GameMap.next_interior == "":
		return
	var pc := m.player.cell()
	for c: Vector2i in [pc + Vector2i(m.player.facing_dir().round()), pc, pc + Vector2i(0, -1), pc + Vector2i(0, 1)]:
		var t: Dictionary = m.things.get(c, {})
		if str(t.get("type", "")) in ["door", "shop", "hall", "idoor"] and str(t.get("interior", t.get("shop", ""))) == GameMap.next_interior:
			var h := str(t.get("hint", "")).trim_prefix("A: ").strip_edges()
			if h != "":
				r["interior_name"] = _title(h)
				r["interior_name_for"] = GameMap.next_interior
			return


static func _title(s: String) -> String:
	if s.begins_with("the "):
		s = "The " + s.substr(4)
	var out := []
	for w: String in s.split(" "):
		out.append(w if w.length() <= 2 and w != w.to_upper() and out.size() > 0 else w.left(1).to_upper() + w.substr(1))
	return " ".join(out)

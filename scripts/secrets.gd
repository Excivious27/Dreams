class_name Secrets
extends RefCounted
## Hidden things in every outdoor region, placed beside the paths so they can
## always be reached: one old chest (opens once, ever), two buried caches you
## find with the hoe (once each), and one page of the Wayfarer's Journal.
## Find every page for the journal's last secret.

const GANG_ONLY := ["hideout", "docks", "neon", "uptown", "underground", "countryside"]
const PENG_ONLY := ["wastes", "sky", "station", "jungle"]


## Pages this arc can actually reach: the journal is finishable in either arc.
## (POCKET_PAGES lie in the newer mega areas' hidden nooks: HiddenArea.)
static func pages_total() -> int:
	var n := 0
	for rid: String in PAGES:
		if (rid in GANG_ONLY and GameState.is_penguins()) or (rid in PENG_ONLY and not GameState.is_penguins()):
			continue
		n += 1
	for rid: String in POCKET_PAGES:
		if _area_here(rid):
			n += 1
	return n


## Hidden chests this arc can find: one per outdoor region with roads, plus one in
## every mega area's hidden nook.
static func chests_total() -> int:
	var n := 0
	for rid: String in RegionData.all():
		var r: Dictionary = RegionData.region(rid)
		if rid.begins_with("bf_") or r.get("paths", []).is_empty():
			continue
		if (rid in GANG_ONLY and GameState.is_penguins()) or (rid in PENG_ONLY and not GameState.is_penguins()):
			continue
		var mr := MegaRegion.region_of(rid)
		if mr != "" and not _area_here(rid):
			continue
		n += 1
		if mr != "" and int(r.get("hidden", {}).get("pockets", 1)) > 0:
			n += 1
		if HiddenArea.SANCTUMS.has(rid):
			n += 1
	return n


## A mega area this run can reach (right arc, scene built).
static func _area_here(rid: String) -> bool:
	var mr := MegaRegion.region_of(rid)
	if mr == "":
		return true
	if not MegaRegion.in_arc(mr):
		return false
	var a := MegaRegion.area(mr, rid)
	return (a.is_empty() or MegaRegion.area_in_arc(mr, a)) and MegaRegion.scene_exists(rid)


## Lore pages tucked in the hidden nooks of the newer areas (HiddenArea places them).
const POCKET_PAGES := {
	"iron_junction": "Page: The first train through the Junction carried no cargo at all. Just one lantern, lit, on an empty flatcar.",
	"iron_freight_yards": "Page: Every crate in the yards is numbered except one. Nobody will say who ships it, but it goes out every spring.",
	"iron_mill_district": "Page: The mill wheel turned for forty years after the river moved. The workers say it learned to.",
	"iron_tunnels": "Page: Tap the tunnel walls and they ring like bells. The diggers tuned them, one note per mile.",
	"hollow_deeps": "Page: Below the heart the stone is warm and soft as bread. I pressed my hand in it. It pressed back, gently.",
	"sky_reaches": "Page: The far islands drift a hand's width every year. In a thousand years they'll all have touched once.",
	"gloam_lanternfall": "Page: Every lantern here was hung by someone lost. They light them so the next lost one finds the road.",
	"gloam_violet_glade": "Page: The violet flowers close when you lie. I tested it. I don't recommend testing it.",
	"gloam_crystal_thicket": "Page: The thicket's crystals grow toward sound. Hum, and by morning they'll lean your way.",
	"gloam_moonpool": "Page: The moonpool shows the sky of the night you were born. Mine had a comet in it.",
	"desert_mirage_post": "Page: The post's well is never dry. The keepers swear it fills from a sea that isn't there any more.",
	"desert_dune_sea": "Page: The dunes walk east a step each day. Somewhere under them is the town they buried, still walking too.",
	"desert_glass_canyon": "Page: The glass walls were sand once, melted in one bright moment. You can still see footprints in it.",
	"desert_sunken_temple": "Page: The Colossus wasn't made to keep people out. It was made to keep the sun's last spark in.",
	"frost_hearthhold": "Page: The hearth at Hearthhold has burned through every winter for three hundred years. Each family feeds it one log.",
	"frost_glacier": "Page: There are flowers frozen deep in the glacier, still blue. Summer flowers from a summer nobody remembers.",
	"frost_caverns": "Page: The ice caves sing when the wind is right. The old songs of the valley, a little out of tune.",
	"frost_falls": "Page: The falls freeze solid every year on the same night. People come to hear the last splash.",
	"frost_summit": "Page: From the summit on a clear day you can see the whole valley, and the farm, and someone waving.",
	"wind_breezehaven": "Page: Breezehaven's kites never come down. The oldest has flown since the town was founded.",
	"wind_sunrise_shelf": "Page: The sun rises here a minute before anywhere else. The shelf folk use the minute to make a wish.",
	"wind_storm_shelf": "Page: The storms here aren't angry. They're shy. They only rumble when someone's watching.",
	"wind_starfall_garden": "Page: The garden grows where the star's dust settled. Some of the flowers glow only for children.",
	"gilt_grand_plaza": "Page: The plaza's fountain coins are never collected. The city says it's saving them for a rainy century.",
	"gilt_casino_row": "Page: Every sign on the Row lights in the same order each night. Read the first letters and it spells a name.",
	"gilt_gardens": "Page: The hedges in the gardens are trimmed at night by somebody nobody has ever seen.",
	"gilt_vaults": "Page: The deepest vault holds no gold. Just a little crystal, the first one ever found, wrapped in a scarf.",
}


const PAGES := {
	"orchard_hills": "Page: The orchards were planted by people who couldn't stay. Every tree is someone's goodbye, and the fruit is the sweetest in the valley.",
	"countryside": "Page: The old road east was paved with stones from the star field. Walk it at night and your shadow looks a little too bright.",
	"wastes": "Page: Nothing grows here, they say. That's wrong. Something grows here. It just isn't green.",
	"hideout": "Page: Every crew in the city started in a room like this one, with one lamp and too many plans.",
	"docks": "Page: Warehouse Three has never once been opened in the daytime. I counted for a month.",
	"neon": "Page: The signs hum a tune if you stand still enough. The same tune on every street. Somebody wrote it.",
	"uptown": "Page: The bridge rises at midnight for a boat that never comes. The bridge keeper still salutes it.",
	"underground": "Page: The tunnels are older than the city. The city was built on top of them on purpose.",
	"quarry": "Page: The golems weren't built to guard the stone. They were built to guard what's under it.",
	"marsh": "Page: The witch didn't make the bog. The bog made the witch. Be kind to the frogs.",
	"riverlands": "Page: All three rivers meet at the falls and argue about which way to go. Only the fish know.",
	"highlands": "Page: The hot spring never cools, even in the deepest winter. Something down there is still warm.",
	"ruins": "Page: The arch faces exactly where the star fell. The builders knew before it happened.",
	"jungle": "Page: The giant flowers turn to follow you. Not the sun. You.",
	"sky": "Page: The whale has been circling the same island for three hundred years. It's waiting for someone.",
	"station": "Page: The station's logbook ends mid-sentence. 'We found the source. It's not a crystal, it's a'",
	"colony_coral": "Page: The merkits say the reef sings when the star crystal is happy. I heard it once. I cried.",
	"colony_kelp": "Page: The kelp grows in spirals that match the old star maps. Nobody planted them that way.",
	"colony_ice": "Page: Under the ice there are lights moving. Slowly. Like they're looking for a way out.",
	"colony_ember": "Page: The ember colony keeps one fire that has never gone out. They say it was lit from the falling star.",
	"hollow_heart": "Page: Here is where the star came down, and here it still beats. I'll stop writing now. Some things you should see for yourself.",
}

const LOOT := [
	{"#gold": 120, "potion": 2, "copper_bar": 2},
	{"#gold": 300, "iron_bar": 3, "greater_potion": 1},
	{"#gold": 600, "gold_bar": 2, "sapphire": 1},
	{"#gold": 1000, "crystal_refined": 2, "ruby": 1},
	{"#gold": 1600, "crystal_refined": 3, "relic_orb": 1},
	{"#gold": 2500, "moon_shard": 2, "wonder_elixir": 1},
]
const CACHE := [["copper", 4], ["iron", 3], ["gold", 2], ["fossil", 1], ["amethyst", 1], ["shard", 2], ["relic_mask", 1]]


static func place(m: GameMap, rid: String, tier: int) -> void:
	if rid.begins_with("bf_"):
		return
	# C5 c5_17 #1: the first placement in a run is remembered (HiddenArea.recall), so the
	# chest and caches don't move when the day's forage/ore change the path-side cells.
	var picks: Array = []
	var mem := HiddenArea.recall("secrets_" + rid)
	for a: Variant in mem.get("picks", []):
		var mc := HiddenArea.v2(a)
		if mc.x < 0 or not HiddenArea.free_cell(m, mc):
			picks.clear()
			break
		picks.append(mc)
	if not picks.is_empty():
		_put(m, rid, tier, picks)
		return
	var cands := _path_side_cells(m)
	if cands.size() < 6:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(rid + "_secrets")
	# The chest likes a tucked-away spot: walled in on most sides (behind a rock,
	# in a hedge corner, at a dead end), not in plain view by the road.
	var tucked: Array = cands.filter(func(c: Vector2i) -> bool: return _walls(m, c) >= 4)
	if not tucked.is_empty():
		picks.append(tucked[rng.randi() % tucked.size()])
	var tries := 0
	while picks.size() < 4 and tries < 400:
		tries += 1
		var c: Vector2i = cands[rng.randi() % cands.size()]
		var ok := true
		for p: Vector2i in picks:
			if p.distance_to(c) < 10.0:
				ok = false
		if ok:
			picks.append(c)
	if picks.is_empty():
		return
	HiddenArea.remember("secrets_" + rid, {"picks": picks.map(func(c: Vector2i) -> Array: return [c.x, c.y])})
	_put(m, rid, tier, picks)


static func _put(m: GameMap, rid: String, tier: int, picks: Array) -> void:
	var t := clampi(tier, 0, 5)
	# The chest.
	var ck := "secret_chest_" + rid
	var c0: Vector2i = picks[0]
	var opened: bool = GameState.run["flags"].has(ck)
	m.set_thing(c0.x, c0.y, {"type": "secret_chest", "key": ck, "give": LOOT[t], "hint": "" if opened else "A: an old chest"}, true)
	m.prop("props", "chest_open" if opened else "chest_closed", c0)
	# Two buried caches: nothing to see, but the hoe finds them.
	for i in range(1, mini(3, picks.size())):
		var cc: Vector2i = picks[i]
		var key := "secret_dig_%s_%d" % [rid, i]
		if not GameState.run["flags"].has(key):
			var cache: Array = CACHE[(hash(key) % CACHE.size() + t) % CACHE.size()]
			m.set_thing(cc.x, cc.y, {"type": "secret_dig", "key": key, "item": cache[0], "n": int(cache[1]) + t, "hint": ""}, false)
	# A journal page.
	if PAGES.has(rid) and picks.size() >= 4:
		var pc: Vector2i = picks[3]
		var pk := "page_" + rid
		if not GameState.run["flags"].has(pk):
			m.set_thing(pc.x, pc.y, {"type": "page", "key": pk, "text": PAGES[rid], "hint": "A: a torn page"}, false)
			m.prop("props", "signpost" if Art.has("props", "signpost") else "chest_closed", pc, 0, 0.0, false, 0.25)


static func _walls(m: GameMap, c: Vector2i) -> int:
	var n := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dy != 0) and m.blocked.has(c + Vector2i(dx, dy)):
				n += 1
	return n


## Buried caches not dug yet (HiddenArea sparkles over them at dawn and dusk).
static func undug(m: GameMap) -> Array:
	var out: Array = []
	for c: Vector2i in m.things:
		if str(m.things[c].get("type", "")) == "secret_dig":
			out.append(c)
	return out


## Open, walkable cells one or two steps off a path.
static func _path_side_cells(m: GameMap) -> Array:
	var out: Array = []
	var R: Dictionary = m.get("R") if m.get("R") is Dictionary else {}
	var rects: Array = []
	for p in R.get("paths", []):
		rects.append(Rect2i(int(p[0]), int(p[1]), int(p[2]), int(p[3])))
	for r: Rect2i in rects:
		for y in range(r.position.y - 2, r.end.y + 2):
			for x in range(r.position.x - 2, r.end.x + 2):
				var c := Vector2i(x, y)
				# Not on this path or any other (a chest on a crossing road plugs it).
				if rects.any(func(q: Rect2i) -> bool: return q.has_point(c)) or x < 2 or y < 2 or x >= m.cols - 2 or y >= m.rows - 2:
					continue
				if m.blocked.has(c) or m.things.has(c) or m.is_water_cell(c):
					continue
				out.append(c)
	return out


## Handles the secret thing types. Returns true if it was one.
static func interact(m: GameMap, c: Vector2i, thing: Dictionary) -> bool:
	match str(thing.get("type", "")):
		"secret_chest":
			var key := str(thing["key"])
			if GameState.run["flags"].has(key):
				m.hud.toast("Empty. You already found what was in it.")
				return true
			GameState.run["flags"][key] = true
			thing["hint"] = ""
			if m.props.has(c):
				(m.props[c] as Node).queue_free()
				m.props.erase(c)
			m.prop("props", "chest_open", c)
			Music.instance(m.get_tree()).sfx("j_treasure", "coin")
			var g: Dictionary = thing["give"]
			for id: String in g:
				if id == "#gold":
					GameState.run["crystals"] = int(GameState.run["crystals"]) + int(g[id])
					m.hud.toast("+◆%d" % int(g[id]), Color(1, 0.9, 0.5))
				else:
					m.give(id, int(g[id]))
			GameState.notify("Hidden chest found (%d/%d)." % [found("secret_chest_") + found("hidden_chest_"), chests_total()])
			return true
		"secret_dig":
			if GameState.held_tool() != "hoe":
				return false
			var key := str(thing["key"])
			GameState.run["flags"][key] = true
			m.things.erase(c)
			var ha := m.get_node_or_null("HiddenArea") as HiddenArea
			if ha:
				ha.found_spot(c)
			m.player.play_tool("hoe")
			m.fx("dust_puff" if Art.has("fx", "dust_puff") else "poof", m.cell_center(c), 12.0, 0.4)
			Music.instance(m.get_tree()).sfx("dig")
			m.hud.toast("Something was buried here!", Color(1, 0.95, 0.6))
			m.give(str(thing["item"]), int(thing["n"]))
			return true
		"page":
			var key := str(thing["key"])
			GameState.run["flags"][key] = true
			Music.instance(m.get_tree()).sfx("j_page", "page")
			m.things.erase(c)
			if m.props.has(c):
				(m.props[c] as Node).queue_free()
				m.props.erase(c)
			var n := found("page_")
			m.tell([{"who": "", "text": str(thing["text"])}, {"who": "", "text": "The Wayfarer's Journal: %d of %d pages." % [n, pages_total()]}])
			if n >= pages_total() and not GameState.run["flags"].has("journal_done"):
				GameState.run["flags"]["journal_done"] = true
				m.give("relic_crown", 1)
				GameState.run["crystals"] = int(GameState.run["crystals"]) + 5000
				GameState.notify("The journal is whole. Tucked in its spine: a map to a crown, and ◆5000.")
			return true
	return false


static func found(prefix: String) -> int:
	var n := 0
	for k: String in GameState.run["flags"]:
		if k.begins_with(prefix):
			n += 1
	return n

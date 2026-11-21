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
		if (rid in GANG_ONLY and GameState.is_penguins()) or (rid in PENG_ONLY and not GameState.is_penguins()) or not _area_here(rid):
			continue
		n += 1
	for rid: String in POCKET_PAGES:
		if _area_here(rid):
			n += 1
	for rid: String in HiddenArea.SANCTUMS:  # sanctum pages behind bosses count too
		if _area_here(rid) and str(HiddenArea.SANCTUMS[rid].get("page", "")) != "":
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
		elif mr == "" and rid in HiddenArea.CLASSIC and int(r.get("hidden", {}).get("pockets", 1)) > 0:
			n += 1  # C14: the classic regions' hidden nooks
		if HiddenArea.SANCTUMS.has(rid):
			n += 1
	return n


## A mega area this run can reach (right arc, scene built).
static func _area_here(rid: String) -> bool:
	var mr := MegaRegion.region_of(rid)
	if mr == "":
		return not ((rid in GANG_ONLY and GameState.is_penguins()) or (rid in PENG_ONLY and not GameState.is_penguins()))  # C14: classic pockets per arc
	if not MegaRegion.in_arc(mr):
		return false
	var a := MegaRegion.area(mr, rid)
	return (a.is_empty() or MegaRegion.area_in_arc(mr, a)) and MegaRegion.scene_exists(rid)


## Lore pages tucked in the hidden nooks of the newer areas (HiddenArea places them).
const POCKET_PAGES := {
	"orchard_hills": "Page: The oldest tree on the hill was planted upside down, roots to the sky. It fruits anyway, every other spring.",
	"highlands": "Page: Shepherds stack one stone on the cairn each time they get home safe. The cairn is taller than the shepherds now.",
	"quarry": "Page: The old miners cut this adit to follow a single silver thread. It ran out after nine steps. They kept the door anyway.",
	"marsh": "Page: The herons stand on one leg to keep a secret: the other foot is holding the marsh together.",
	"riverlands": "Page: The river forgot its old bed one wet fall. The fish still swim the old way, through the grass, in their dreams.",
	"ruins": "Page: Behind the collapsed door the crypt holds no bones, only shelves of seed jars, labelled in a hand nobody can read.",
	"countryside": "Page: Every barn out here has one plank painted on the inside. Line them up on a map and they point to the same hill.",
	"wastes": "Page: The ash fields bloom for one night a year. The flowers are grey, and they smell like warm bread.",
	"jungle": "Page: The vines here grow toward voices. Sing to one long enough and it will lead you somewhere quiet.",
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
	{"#gold": 2500, "storm_glass": 2, "wonder_elixir": 1},  # C8 P4: moon shards stay a moon find
]
## Buried caches: one item kind per dig (hash), count = the tier's value budget / its value.
const CACHE := ["copper", "iron", "gold", "fossil", "amethyst", "shard", "relic_mask", "ancient_urn"]
const CACHE_BUDGET := [80, 150, 250, 400, 600, 900]
const CACHE_SINGLE := {"relic_mask": 4, "ancient_urn": 2}  # one at a time, from this tier (museum relics)
const HUB_TIER_DROP := 2        # areas with no foes (hubs) hide loot this many tiers lower
const PAGE_SPACING := [10.0, 6.0, 3.0]  # path-side picks keep apart; looser until the page fits


## Decor pool a chest of loot tier t rolls ("chest_t1".."chest_t5" in decor.json pools).
static func decor_pool(t: int) -> String:
	return "chest_t%d" % clampi(t + 1, 1, 5)


## Loot tier for an area's chest/pocket: safe hubs pay less than the dangerous areas.
static func loot_tier(area_tier: int, has_foes: bool) -> int:
	return area_tier if has_foes else maxi(0, area_tier - HUB_TIER_DROP)


## [item, n] for one buried cache: a kind worth between 1/8 and all of the tier's
## budget (CACHE_SINGLE relics one at a time from their tier), n = budget / value.
static func cache_for(key: String, tier: int) -> Array:
	var t := clampi(tier, 0, CACHE_BUDGET.size() - 1)
	var b := int(CACHE_BUDGET[t])
	var kinds: Array = []
	for it: String in CACHE:
		if not GameState.items.has(it):
			continue
		var v := GameState.item_value(it)
		if CACHE_SINGLE.has(it):
			if t >= int(CACHE_SINGLE[it]) and v <= b:
				kinds.append(it)
		elif v * 8 >= b and v <= b:
			kinds.append(it)
	if kinds.is_empty():
		kinds = ["copper"]
	var item: String = kinds[(hash(key) % kinds.size() + kinds.size()) % kinds.size()]
	if CACHE_SINGLE.has(item):
		return [item, 1]
	return [item, maxi(1, int(round(float(b) / float(maxi(1, GameState.item_value(item))))))]


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
	if picks.size() < 4 and PAGES.has(rid) and not GameState.run["flags"].has("page_" + rid):
		picks.clear()  # remembered before the page fitted (C8 P4): place again so it lands
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
	if tucked.is_empty():  # C14 c14_13-12: else at least half walled in, never out in plain view when a nook exists
		tucked = cands.filter(func(c: Vector2i) -> bool: return _walls(m, c) >= 3)
	if not tucked.is_empty():
		picks.append(tucked[rng.randi() % tucked.size()])
	for spacing: float in PAGE_SPACING:  # C8 P4: loosen the spacing so the page always lands
		var tries := 0
		while picks.size() < 4 and tries < 400:
			tries += 1
			var c: Vector2i = cands[rng.randi() % cands.size()]
			var ok := true
			for p: Vector2i in picks:
				if p.distance_to(c) < spacing:
					ok = false
			if ok:
				picks.append(c)
		if picks.size() >= 4:
			break
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
	m.set_thing(c0.x, c0.y, {"type": "secret_chest", "key": ck, "give": LOOT[t], "decor_pool": decor_pool(t), "hint": "" if opened else "A: an old chest"}, true)
	m.prop("props", "chest_open" if opened else "chest_closed", c0)
	# Two buried caches: nothing to see, but the hoe finds them.
	for i in range(1, mini(3, picks.size())):
		var cc: Vector2i = picks[i]
		var key := "secret_dig_%s_%d" % [rid, i]
		if not GameState.run["flags"].has(key):
			var cache := cache_for(key, t)
			m.set_thing(cc.x, cc.y, {"type": "secret_dig", "key": key, "item": cache[0], "n": int(cache[1]), "hint": ""}, false)
	# A journal page.
	if PAGES.has(rid) and picks.size() >= 4:
		var pc: Vector2i = picks[3]
		var pk := "page_" + rid
		if not GameState.run["flags"].has(pk):
			m.set_thing(pc.x, pc.y, {"type": "page", "key": pk, "text": PAGES[rid], "hint": "A: a torn page"}, false)
			# C14 c14_13-12: a page you can read as a page (pinned under a stone, tied to a
			# stake, or in a bottle), not a quarter-size signpost.
			var pv: String = ["c14p4_page_stone", "c14p4_page_stake", "c14p4_page_bottle"][absi(hash(rid)) % 3]
			if Art.has("c14p4", pv):
				m.prop("c14p4", pv, pc, 0, 0.0, false, 0.5)
			else:
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
				Music.instance(m.get_tree()).sfx("chest_open", "thud")
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
					GameState.add_money(int(g[id]), "secret")
					m.hud.toast("+" + Money.amount(int(g[id])), Color(1, 0.9, 0.5))  # C16a P4: the arc's own money
				else:
					m.give(id, int(g[id]))
			# C10a P4: once-per-game chests also hold a home piece (a fixed grant
			# "chest:<key>" from decor.json wins over the tier pool roll).
			if randf() < float(DecorSources.T["chest_p"]) and DecorSources.grant_key(m, "chest:" + key) == "":
				DecorSources.roll_grant(m, str(thing.get("decor_pool", "")), Fishing.luck(), "chest")
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
				DecorSources.grant_key(m, "secret:journal")  # the Wayfarer's keepsake (unique, decor.json grants)
				GameState.add_money(5000, "secret")
				GameState.notify("The journal is whole. Tucked in its spine: a map to a crown, and %s." % Money.amount(5000))
			return true
	return false


static func found(prefix: String) -> int:
	var n := 0
	for k: String in GameState.run["flags"]:
		if k.begins_with(prefix):
			n += 1
	return n

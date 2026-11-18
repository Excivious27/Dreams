class_name Secrets
extends RefCounted
## Hidden things in every outdoor region, placed beside the paths so they can
## always be reached: one old chest (opens once, ever), two buried caches you
## find with the hoe (once each), and one page of the Wayfarer's Journal.
## Find every page for the journal's last secret.

const GANG_ONLY := ["hideout", "docks", "neon", "uptown", "underground", "countryside"]
const PENG_ONLY := ["wastes", "sky", "station", "jungle"]


## Pages this arc can actually reach: the journal is finishable in either arc.
static func pages_total() -> int:
	var n := 0
	for rid: String in PAGES:
		if (rid in GANG_ONLY and GameState.is_penguins()) or (rid in PENG_ONLY and not GameState.is_penguins()):
			continue
		n += 1
	return n


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
	var cands := _path_side_cells(m)
	if cands.size() < 6:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(rid + "_secrets")
	var picks: Array = []
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


## Open, walkable cells one or two steps off a path.
static func _path_side_cells(m: GameMap) -> Array:
	var out: Array = []
	var R: Dictionary = m.get("R") if m.get("R") is Dictionary else {}
	for p in R.get("paths", []):
		var r := Rect2i(int(p[0]), int(p[1]), int(p[2]), int(p[3]))
		for y in range(r.position.y - 2, r.end.y + 2):
			for x in range(r.position.x - 2, r.end.x + 2):
				var c := Vector2i(x, y)
				if r.has_point(c) or x < 2 or y < 2 or x >= m.cols - 2 or y >= m.rows - 2:
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
			Music.instance(m.get_tree()).sfx("coin", "pickup")
			var g: Dictionary = thing["give"]
			for id: String in g:
				if id == "#gold":
					GameState.run["crystals"] = int(GameState.run["crystals"]) + int(g[id])
					m.hud.toast("+◆%d" % int(g[id]), Color(1, 0.9, 0.5))
				else:
					m.give(id, int(g[id]))
			GameState.notify("Hidden chest found (%d/%d)." % [found("secret_chest_"), pages_total()])
			return true
		"secret_dig":
			if GameState.held_tool() != "hoe":
				return false
			var key := str(thing["key"])
			GameState.run["flags"][key] = true
			m.things.erase(c)
			m.player.play_tool("hoe")
			m.fx("dirt_puff" if Art.has("fx", "dirt_puff") else "poof", m.cell_center(c), 12.0, 0.4)
			Music.instance(m.get_tree()).sfx("dig")
			m.hud.toast("Something was buried here!", Color(1, 0.95, 0.6))
			m.give(str(thing["item"]), int(thing["n"]))
			return true
		"page":
			var key := str(thing["key"])
			GameState.run["flags"][key] = true
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

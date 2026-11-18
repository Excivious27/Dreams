extends GameMap
## The mine: a floor of rock to break with the pickaxe (stone, copper, iron,
## crystal shards), slimes and bats, and a ladder down to a harder floor.
## The layout is generated from the floor number so it's the same each visit.

var floor_no := 1
var _grotto := false
var _ladder := Vector2i.ZERO
var mine_tier := 0           # unified tier for this floor (GameState.mine_tier)
var _guardian: Enemy = null  # the floor's gatekeeper, once it has shown up
var _summoning := false
var _way_open := false       # shaft revealed (flag mine_open_<floor>)
var theme: Dictionary = {}
var _gsmash_t := 3.0
var _lava := {}
var _chasm := {}

## 150 floors. Every 10 floors the cave changes look (15 themes); every floor's
## layout is re-carved each day; every 5th floor is a lift stop you keep; every
## 10th floor has a prize chest; floor 150's shaft opens the Hollow Heart.
const MAX_FLOOR := 150
const THEMES := [
	{"cave": "earth", "name": "Earthen Tunnels", "var": "earth", "ts": "", "rock": "2a2018", "fa": "4a3a2c", "fb": "52412f", "tint": [1.0, 1.0, 1.0], "feat": [], "forage": ["cave_mushroom", "mushroom"]},
	{"cave": "earth", "name": "Mossy Hollows", "var": "earth", "ts": "", "rock": "1f2a1c", "fa": "3e4a34", "fb": "44503a", "tint": [0.85, 1.0, 0.85], "feat": ["water"], "forage": ["cave_mushroom", "cave_fig", "mushroom_spore"]},
	{"cave": "stone", "name": "Grey Stone Deeps", "var": "stone", "ts": "deep", "rock": "24222c", "fa": "4a4152", "fb": "50475a", "tint": [1.0, 1.0, 1.0], "feat": [], "forage": ["cave_fig", "cave_mushroom"]},
	{"cave": "stone", "name": "Flooded Galleries", "var": "stone", "ts": "deep", "rock": "1c2430", "fa": "3a4656", "fb": "40506a", "tint": [0.8, 0.9, 1.05], "feat": ["water"], "forage": ["cave_fig", "mushroom_spore"]},
	{"cave": "earth", "name": "Fungal Caverns", "var": "earth", "ts": "", "rock": "241c2c", "fa": "3c3048", "fb": "42354e", "tint": [1.0, 0.85, 1.0], "feat": ["glow"], "forage": ["cave_bloom", "mushroom_spore", "cave_mushroom"]},
	{"cave": "crystal", "name": "Crystal Veins", "var": "stone", "ts": "crystal", "rock": "1c1c34", "fa": "3c3c64", "fb": "42426c", "tint": [0.85, 0.9, 1.1], "feat": ["crystals"], "forage": ["shard", "cave_bloom"]},
	{"cave": "ice", "name": "Frost Caves", "var": "ice", "ts": "", "rock": "1c2634", "fa": "4a5c6c", "fb": "52667a", "tint": [0.85, 0.95, 1.1], "feat": ["water"], "forage": ["cave_fig", "shard"]},
	{"cave": "crystal", "name": "Amethyst Grotto", "var": "ice", "ts": "crystal", "rock": "241434", "fa": "4a2e5c", "fb": "523466", "tint": [1.0, 0.8, 1.1], "feat": ["crystals"], "forage": ["amethyst", "shard", "cave_bloom"]},
	{"cave": "earth", "name": "Sandstone Ruins", "var": "earth", "ts": "", "rock": "3a2c1c", "fa": "6a5638", "fb": "72603e", "tint": [1.1, 1.0, 0.85], "feat": [], "forage": ["fossil", "cave_fig"]},
	{"cave": "stone", "name": "Gold Seams", "var": "stone", "ts": "deep", "rock": "2c2418", "fa": "5a4a30", "fb": "62523a", "tint": [1.1, 1.0, 0.8], "feat": [], "forage": ["gold", "cave_bloom"]},
	{"cave": "lava", "name": "Magma Rifts", "var": "lava", "ts": "", "rock": "2c1814", "fa": "4a2a22", "fb": "52302a", "tint": [1.1, 0.85, 0.8], "feat": ["lava"], "forage": ["dark", "cave_fig"]},
	{"cave": "lava", "name": "Obsidian Halls", "var": "lava", "ts": "dark", "rock": "120e16", "fa": "2a2432", "fb": "302a3a", "tint": [0.8, 0.8, 0.95], "feat": ["lava"], "forage": ["dark", "shard"]},
	{"cave": "stone", "name": "Drowned Dark", "var": "stone", "ts": "dark", "rock": "0e1620", "fa": "22303c", "fb": "283846", "tint": [0.8, 0.9, 1.0], "feat": ["water", "glow"], "forage": ["cave_bloom", "dark"]},
	{"cave": "crystal", "name": "The Void Reach", "var": "stone", "ts": "dark", "rock": "0c0a14", "fa": "1e1a2c", "fb": "241f34", "tint": [0.9, 0.8, 1.1], "feat": ["chasm"], "forage": ["dark", "crystal_refined"]},
	{"cave": "lava", "name": "The Heart's Edge", "var": "lava", "ts": "heart", "rock": "1a0c18", "fa": "3a1c34", "fb": "42223c", "tint": [1.1, 0.85, 1.0], "feat": ["crystals", "glow"], "forage": ["crystal_refined", "shard", "cave_bloom"]},
]


static func theme_for(f: int) -> Dictionary:
	return THEMES[clampi((f - 1) / 10, 0, THEMES.size() - 1)]


## How much you've "tried" this floor: rocks broken count 1, kills count 3.
## Past the threshold the guardian shows up; beat it and the way down opens.
func _tried() -> int:
	return int(GameState.run.get("mine_tried", {}).get("%d_%d" % [floor_no, int(GameState.run["day"])], 0))


func _try_more(n: int) -> void:
	var k := "%d_%d" % [floor_no, int(GameState.run["day"])]
	var d: Dictionary = GameState.run.get("mine_tried", {})
	if not d.has(k):
		for ok in d.keys():
			if not str(ok).ends_with("_%d" % int(GameState.run["day"])):
				d.erase(ok)   # a new day: yesterday's counts go
	d[k] = int(d.get(k, 0)) + n
	GameState.run["mine_tried"] = d
	if not _way_open and _guardian == null and not _summoning and _tried() >= _threshold():
		_summoning = true
		call_deferred("_summon_guardian")
	elif not _way_open and _guardian == null and _tried() == _threshold() / 2:
		hud.toast("Something below is listening.", Color(0.8, 0.75, 0.9))


## How much digging and fighting wakes the keeper: random per floor and day.
## Usually a good while; now and then it comes up almost at once.
func _threshold() -> int:
	var day := int(GameState.run["day"])
	var key := "%d_%d" % [floor_no, day]
	var old: Dictionary = GameState.run.get("mine_thresh", {})
	if not old.has(key):
		var base := 14.0 + minf(60.0, floor_no * 0.4)
		var r := randf()
		var mult := randf_range(0.3, 0.5) if r < 0.15 else (randf_range(0.75, 1.0) if r < 0.4 else randf_range(1.0, 1.7))
		var d := {key: int(round(base * mult))}
		for k in old:
			if str(k).ends_with("_%d" % day):
				d[k] = old[k]
		GameState.run["mine_thresh"] = d
		old = d
	return maxi(4, int(old[key]))


func scene_id() -> String:
	return "mine"


func default_spawn() -> Vector2:
	return cell_center(_nearest_open(_entry + Vector2i(1, 1)))


func build() -> void:
	# Big organic caverns: a floor grows with depth, carved by cellular automata
	# so the edges read as natural rock, not a box.
	floor_no = clampi(int(GameState.run.get("mine_floor", 1)), 1, MAX_FLOOR)
	theme = theme_for(floor_no)
	has_sky = false
	has_pet = false
	music_track = "mine"
	# A fresh layout every day, different on every floor.
	var rng := RandomNumberGenerator.new()
	rng.seed = floor_no * 7919 + int(GameState.run["day"]) * 104729
	cols = 40 + mini(floor_no, 40) / 2 + rng.randi_range(0, 18)
	rows = 32 + mini(floor_no, 40) / 3 + rng.randi_range(0, 12)
	mine_tier = GameState.mine_tier(floor_no)
	_carve(rng)
	# Some days the dice carve a cramped cave: re-carve fuller until it's roomy.
	var tries := 0
	while _open.size() < int(cols * rows * 0.32) and tries < 6:
		tries += 1
		_carve(rng, 0.03 * tries)
	# Way in: the open cell nearest the top-left; way down: the farthest open cell from it.
	_entry = _nearest_open(Vector2i(3, 3))
	_ladder = _farthest_open(_entry)
	for c in range(0, cols * rows):
		var cc := Vector2i(c % cols, c / cols)
		if not _open.has(cc):
			blocked[cc] = true
	set_thing(_entry.x, _entry.y, {"type": "up", "hint": "A: climb out"})
	_way_open = GameState.run["flags"].has("mine_open_%d" % floor_no)
	if _way_open:
		things[_ladder] = {"type": "down", "hint": "A: climb down to floor %d" % (floor_no + 1)}
	# The lift: once you've opened floor 5, Granite's cart takes you straight to
	# any floor you've opened the way to (every 5th).
	if (floor_no == 1 or floor_no % 5 == 0) and _deepest() >= 5:
		var lc := _nearest_open(_entry + Vector2i(3, 0))
		set_thing(lc.x, lc.y, {"type": "lift", "hint": "A: the mine lift"})
	# Floor 5: the flooded grotto. Much of the cave is black water; crystals sit
	# under it. Mer the mercat lives here; with her you can swim and dive.
	_grotto = floor_no == 5
	if _grotto:
		for c: Vector2i in _open:
			if c.distance_to(_entry) > 6 and c.distance_to(_ladder) > 3 and WorldGen.fbm(float(c.x), float(c.y), 55, 7.0) > -0.05 and not things.has(c):
				set_thing(c.x, c.y, {"type": "water", "hint": ""}, true)
		swim_ok = true
		var mc := _nearest_open(_entry + Vector2i(3, 3))
		set_thing(mc.x, mc.y, {"type": "mer", "hint": "A: ...a cat?"}, false)
		# Mer has to be visible: she gates the grotto. Hidden while she follows you.
		if Companion.active_id() != "mer" and str(GameState.run.get("playable", "")) != "mer":
			var ms := CharacterLibrary.make_sprite("mer")
			if ms:
				ms.position = cell_center(mc)
				ms.play("idle")
				ms.flip_h = true
				add_child(ms)
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = 5555
		var placed := 0
		var wl: Array = []
		for c in things:
			if is_water_cell(c):
				wl.append(c)
		for i in 200:
			if wl.is_empty():
				break
			var c: Vector2i = wl[rng2.randi() % wl.size()]
			if not things[c].has("crystal"):
				things[c] = {"type": "water", "crystal": true, "key": "grotto_%d" % placed, "hint": "A: dive for the crystal"}
				placed += 1
				if placed >= 6:
					break
	# Rock: about one open cell in seven, more on deeper floors.
	var open_list: Array = _open.keys()
	var count := int(open_list.size() * (0.08 + 0.0004 * mini(floor_no, 100)))
	for i in count:
		if _grotto and i > count / 2:
			break
		var c: Vector2i = open_list[rng.randi() % open_list.size()]
		if c.distance_to(_entry) < 3 or c.distance_to(_ladder) < 2 or things.has(c):
			continue
		var roll := rng.randf()
		var ore := "stone"
		var pool: Array = (GameState.tier_data.get("mine", {}).get("ores", []) as Array)
		var ores: Array = pool[mini(mine_tier, pool.size() - 1)] if not pool.is_empty() else ["stone", "copper"]
		# Half stone, the rest spread over the tier's ores (rarest last, least common).
		if roll > 0.62 and ores.size() > 1:
			var r2 := (roll - 0.62) / 0.38
			var idx := 1
			var acc := 0.0
			var weights: Array = []
			for oi in range(1, ores.size()):
				weights.append(1.0 / (oi + 0.5))
			var total := 0.0
			for w in weights:
				total += float(w)
			for wi in weights.size():
				acc += float(weights[wi]) / total
				if r2 <= acc:
					idx = wi + 1
					break
			ore = str(ores[idx])
		# Ore gathers in veins: rich rocks pull neighbours toward the same ore.
		var hard := (3 if ore == "stone" else 4 + ores.find(ore)) + floor_no / 15
		set_thing(c.x, c.y, {"type": "rock", "ore": ore, "hp": hard, "hint": "A: mine"})
	_features(rng)
	_findables(rng)


var _open := {}          # walkable cave floor
var _entry := Vector2i(2, 2)


## Cellular-automata cave: random fill, smoothed, then only the biggest connected
## cavern is kept so every part of the floor can be reached.
var _fill := 0.56


func _carve(rng: RandomNumberGenerator, boost := 0.0) -> void:
	_fill = rng.randf_range(0.52, 0.6) + boost
	var passes := rng.randi_range(4, 6)
	var g := {}
	for y in range(1, rows - 1):
		for x in range(1, cols - 1):
			# Bias toward open in the middle, rock at the rim: no straight edges.
			var edge := minf(minf(x, cols - 1 - x), minf(y, rows - 1 - y))
			var p := _fill if edge > 4 else (0.42 if edge > 2 else 0.2)
			if rng.randf() < p:
				g[Vector2i(x, y)] = true
	for pass_i in passes:
		var nxt := {}
		for y in range(1, rows - 1):
			for x in range(1, cols - 1):
				var n := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if (dx != 0 or dy != 0) and g.has(Vector2i(x + dx, y + dy)):
							n += 1
				var here := g.has(Vector2i(x, y))
				if (here and n >= 4) or (not here and n >= 5):
					nxt[Vector2i(x, y)] = true
		g = nxt
	# Keep the largest connected region.
	var seen := {}
	var best := {}
	for c: Vector2i in g:
		if seen.has(c):
			continue
		var region := {}
		var stack: Array = [c]
		while not stack.is_empty():
			var q: Vector2i = stack.pop_back()
			if seen.has(q) or not g.has(q):
				continue
			seen[q] = true
			region[q] = true
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				stack.append(q + d)
		if region.size() > best.size():
			best = region
	_open = best


## Theme hazards: pools, lava and chasms on open floor away from the paths in
## and out. They block walking (Tideswim / a mercat lets you swim pools).
func _features(rng: RandomNumberGenerator) -> void:
	var feat: Array = theme.get("feat", [])
	var seed := floor_no * 13 + int(GameState.run["day"])
	for c: Vector2i in _open:
		if things.has(c) or c.distance_to(_entry) < 6 or c.distance_to(_ladder) < 4:
			continue
		var n := WorldGen.fbm(float(c.x), float(c.y), seed, 6.0)
		if "water" in feat and not _grotto and n > 0.38:
			set_thing(c.x, c.y, {"type": "water", "hint": ""}, true)
		elif "lava" in feat and n > 0.42:
			_lava[c] = true
			blocked[c] = true
		elif "chasm" in feat and n > 0.4:
			_chasm[c] = true
			blocked[c] = true
	if "water" in feat and not _grotto:
		swim_ok = Colony.has_ability("tideswim") or Companion.has_ability("tail")
	# Keep the way down reachable: clear any hazard that cuts entry from ladder.
	var reach := {_entry: true}
	var q: Array = [_entry]
	while not q.is_empty():
		var a: Vector2i = q.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var b := a + d
			if _open.has(b) and not reach.has(b) and not _lava.has(b) and not _chasm.has(b) and not (things.has(b) and str(things[b].get("type", "")) == "water"):
				reach[b] = true
				q.append(b)
	if not reach.has(_ladder):
		for c: Vector2i in _lava.keys() + _chasm.keys():
			blocked.erase(c)
			hard.erase(c)
		_lava.clear()
		_chasm.clear()
		for c in things.keys():
			if str(things[c].get("type", "")) == "water" and not _grotto:
				things.erase(c)
				blocked.erase(c)
				hard.erase(c)
## Things to find: glowing forage, crates and barrels, a hidden chest now and
## then, a fossil or relic in the ruins, and the prize chest every 10th floor.
func _findables(rng: RandomNumberGenerator) -> void:
	var free: Array = []
	for c: Vector2i in _open:
		if not things.has(c) and not blocked.has(c) and c.distance_to(_entry) > 3:
			free.append(c)
	if free.is_empty():
		return
	var day := int(GameState.run["day"])
	var forage: Array = theme.get("forage", ["cave_mushroom"])
	var nf := 4 + rng.randi_range(0, 4) + (3 if "glow" in theme.get("feat", []) else 0)
	for i in nf:
		var c: Vector2i = free[rng.randi() % free.size()]
		if things.has(c):
			continue
		var key := "mfor_%d_%d_%d" % [floor_no, i, day]
		if GameState.run["flags"].has(key):
			continue
		var item := str(forage[rng.randi() % forage.size()])
		set_thing(c.x, c.y, {"type": "forage", "item": item, "key": key, "hint": "A: pick up %s" % GameState.item_name(item)}, false)
	for i in rng.randi_range(2, 5):
		var c: Vector2i = free[rng.randi() % free.size()]
		var ck := "mcrate_%d_%d_%d" % [floor_no, i, day]
		if not things.has(c) and not GameState.run["flags"].has(ck):
			set_thing(c.x, c.y, {"type": "crate", "key": ck, "kind": "barrel_a" if rng.randf() < 0.4 else "crates_a", "hp": 2 + floor_no / 30, "hint": "A: smash it open"}, true)
	if rng.randf() < 0.3 + 0.002 * mini(floor_no, 100):
		var c: Vector2i = free[rng.randi() % free.size()]
		var key := "mchest_%d_%d" % [floor_no, day]
		if not things.has(c) and not GameState.run["flags"].has(key):
			set_thing(c.x, c.y, {"type": "mchest", "key": key, "hint": "A: a miner's chest"}, true)
	if floor_no % 10 == 0 and not GameState.run["flags"].has("mine_prize_%d" % floor_no):
		var c := _farthest_open(_ladder)
		if things.has(c):
			c = free[rng.randi() % free.size()]
		set_thing(c.x, c.y, {"type": "bigchest", "hint": "A: the floor %d prize chest" % floor_no}, true)


## Loot by depth. Big = the prize chest every 10th floor.
func _loot(big: bool) -> Dictionary:
	var t := clampi(floor_no / 25, 0, 5)
	var gems: Array = [["amethyst"], ["amethyst", "ruby"], ["ruby", "emerald"], ["emerald", "sapphire"], ["sapphire", "ruby"], ["sapphire", "emerald"]][t]
	var out := {}
	if big:
		out["#gold"] = 200 + floor_no * 25
		out[str(gems[randi() % gems.size()])] = 1 + t
		var rare: Array = [["copper_ring", "luck_potion"], ["silver_ring", "greater_potion"], ["ruby_ring", "relic_orb"], ["relic_mask", "wonder_elixir"], ["moon_ring", "relic_blade"], ["crystal_crown", "relic_crown"]][t]
		out[str(rare[(floor_no / 10) % rare.size()])] = 1
		out["crystal_refined"] = 1 + t
		if floor_no >= MAX_FLOOR:
			out["relic_crown"] = 1
			out["wonder_elixir"] = 3
	else:
		out["#gold"] = 10 + int(floor_no * 1.5)
		var opts: Array = ["potion", "energy_tea", str(gems[0]), "shard", "fossil", "cave_bloom", "iron", "gold"]
		var a := str(opts[randi() % opts.size()])
		out[a] = 1 + (1 if a in ["potion", "energy_tea", "shard", "iron"] else 0)
	return out


func _give_loot(c: Vector2i, loot: Dictionary) -> void:
	for id: String in loot:
		if id == "#gold":
			GameState.run["crystals"] = int(GameState.run["crystals"]) + int(loot[id])
			hud.toast("+◆%d" % int(loot[id]), Color(1, 0.9, 0.5))
		else:
			pop_items(cell_center(c), id, int(loot[id]))


func _nearest_open(c: Vector2i) -> Vector2i:
	var bestc := c
	var bd := 1e9
	for o: Vector2i in _open:
		var d := float((o - c).length_squared())
		if d < bd and not things.has(o):
			bd = d
			bestc = o
	return bestc


## Walk distance (BFS) to the farthest open cell: the way down is a real trek.
func _farthest_open(from: Vector2i) -> Vector2i:
	var dist := {from: 0}
	var queue: Array = [from]
	var far := from
	while not queue.is_empty():
		var q: Vector2i = queue.pop_front()
		if int(dist[q]) > int(dist[far]):
			far = q
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := q + d
			if _open.has(n) and not dist.has(n):
				dist[n] = int(dist[q]) + 1
				queue.append(n)
	return far


func after_ready() -> void:
	# Ore Sense (magic): ore and crystals glimmer through rock within 6 cells.
	if GameState.bonus("magic", "ore_sense") > 0.0:
		var t := Timer.new()
		t.wait_time = 1.6
		t.autostart = true
		t.timeout.connect(_ore_glimmer)
		add_child(t)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2000 + floor_no + int(GameState.run["day"])
	_place_props()
	_place_find_props()
	var n := 5 + mini(floor_no, 60) / 4
	var pools: Array = GameState.tier_data.get("mine", {}).get("pools", [])
	var pool: Array = pools[mini(mine_tier, pools.size() - 1)] if not pools.is_empty() else ["slime", "bat"]
	var ol: Array = _open.keys()
	for i in n:
		var c: Vector2i = ol[rng.randi() % ol.size()]
		if blocked.has(c) or things.has(c) or (_grotto and is_water_cell(c)) or c.distance_to(_entry) < 8:
			continue
		var kind := str(pool[rng.randi_range(0, pool.size() - 1)])
		if not GameState.is_penguins() and kind == "shard":
			kind = "thug_cyber"
		if not GameState.is_penguins() and kind == "grump":
			kind = "thug_lookout"  # grumps are the Dark Crystal's army: penguin arc only
		var me := spawn_enemy(kind, cell_center(c), mine_tier)
		_depth_scale(me)
		# Boss kinds wandering the deep floors fight plainly; only keepers have Gifts.
		if me and me._gift:
			me._gift.queue_free()
			me._gift = null
	if not _way_open and _guardian == null and not _summoning and _tried() >= _threshold():
		_summoning = true
		call_deferred("_summon_guardian")
	if not GameState.run["flags"].has("mine_tier_seen_%d" % mine_tier) and floor_no > 1:
		GameState.run["flags"]["mine_tier_seen_%d" % mine_tier] = true
		hud.toast("%s depths. Everything down here hits harder." % GameState.tier_name(mine_tier), Color(0.9, 0.8, 1.0))
	if not GameState.run["flags"].has("mine_seen"):
		GameState.run["flags"]["mine_seen"] = true
		player.frozen = true
		await say([
			{"text": "Cold air, and the smell of wet stone. Something drips. Something else squelches."},
			{"text": "Swing your pickaxe at rocks with A: stone, copper, iron, and now and then a crystal shard."},
			{"text": "There's no ladder down. The old miners said the way opens for whoever digs long enough to wake what guards it. Down is worse, and pays better."},
		])
		player.frozen = false


func interact(c: Vector2i, thing: Dictionary) -> bool:
	match str(thing.get("type", "")):
		"up":
			GameState.run["mine_floor"] = 1
			if str(GameState.run["flags"].get("mine_from", "meadow")) == "mountain":
				go_to("mountain", Vector2(6 * TILE, 5 * TILE), "down")
			else:
				go_to("meadow", Vector2(31 * TILE, 8 * TILE + 8), "down")
			return true
		"mer":
			later(_meet_mer)
			return true
		"water":
			if bool(thing.get("crystal", false)):
				if not Companion.has_ability("tail"):
					hud.toast("Too deep. Something glints down there.", Color(0.8, 0.9, 1.0))
					return true
				if GameState.run["flags"].has(str(thing["key"])):
					hud.toast("Already took that one.")
					return true
				GameState.run["flags"][str(thing["key"])] = true
				thing.erase("crystal")
				thing["hint"] = ""
				player.play_tool("hold")
				fx("splash", player.position, 12.0, 0.6)
				pop_items(cell_center(c), "shard", 2)
				xp("mining", 8)
				var got := 0
				for k in GameState.run["flags"]:
					if str(k).begins_with("grotto_"):
						got += 1
				if got >= 6:
					GameState.run["flags"]["grotto_done"] = true
					hud.toast("That's all six. Mer hums.", Color(0.8, 0.9, 1.0))
				return true
			return false
		"lift":
			later(_use_lift)
			return true
		"down":
			if _grotto and not GameState.run["flags"].has("grotto_done"):
				hud.toast("The ladder is under the water. You'd need to swim like she does.", Color(0.8, 0.9, 1.0))
				return true
			if floor_no >= MAX_FLOOR:
				GameState.run["flags"]["hollow_heart_open"] = true
				go_to("hollow_heart", Vector2.ZERO, "down")
				return true
			GameState.run["mine_floor"] = floor_no + 1
			var newd := floor_no + 1
			if newd > _deepest() and newd % 5 == 0:
				GameState.notify("Floor %d reached: the lift will always stop here now." % newd)
			GameState.run["flags"]["mine_deepest"] = maxi(_deepest(), newd)
			xp("mining", 4)
			go_to("mine", Vector2.ZERO)
			return true
		"crate":
			if not GameState.spend_for("axe"):
				hud.toast("Too tired.", Color(1, 0.7, 0.7))
				return true
			player.play_tool("pickaxe" if GameState.held_tool() == "pickaxe" else "axe")
			thing["hp"] = int(thing["hp"]) - 1
			Music.instance(get_tree()).sfx("crate_break", "chop")
			if int(thing["hp"]) <= 0:
				things.erase(c)
				blocked.erase(c)
				hard.erase(c)
				if props.has(c):
					(props[c] as Node).queue_free()
					props.erase(c)
				fx("poof", cell_center(c), 12.0, 0.4)
				if thing.has("key"):
					GameState.run["flags"][str(thing["key"])] = true
				if randf() < 0.4:
					_give_loot(c, _loot(false))
				else:
					pop_items(cell_center(c), "plank" if GameState.items.has("plank") else "wood", 1)
				_try_more(1)
			return true
		"mchest", "bigchest":
			var big := str(thing["type"]) == "bigchest"
			GameState.run["flags"][str(thing.get("key", "mine_prize_%d" % floor_no))] = true
			if big:
				GameState.run["flags"]["mine_prize_%d" % floor_no] = true
			things.erase(c)
			blocked.erase(c)
			hard.erase(c)
			if props.has(c):
				(props[c] as Node).queue_free()
				props.erase(c)
			prop("props", "chest_open", c)
			Music.instance(get_tree()).sfx("levelup")
			_give_loot(c, _loot(big))
			hud.toast("The floor %d prize!" % floor_no if big else "A miner's stash.", Color(1, 0.9, 0.5))
			return true
		"skeleton":
			if not GameState.run["flags"].has("skel_%d" % floor_no):
				GameState.run["flags"]["skel_%d" % floor_no] = true
				give("gold", 2)
				tell([{"text": "Somebody didn't make it back up. Their pack still has something in it."}])
			return true
		"rock":
			if GameState.held_tool() != "pickaxe":
				if GameState.has_tool("pickaxe"):
					hud.toast("Hold the pickaxe.")
					return true
				return false
			var ob := GameState.ore_block(str(thing.get("ore", "stone")))
			if ob != "":
				player.play_tool("pickaxe")
				hud.toast(ob, Color(1, 0.85, 0.6))
				return true
			if not GameState.spend_for("pickaxe"):
				hud.toast("Too tired.", Color(1, 0.7, 0.7))
				return true
			player.play_tool("pickaxe")
			Music.instance(get_tree()).sfx("pick", "chop")
			thing["hp"] = int(thing["hp"]) - (1 + GameState.tool_tier("pickaxe") / 2)
			if int(thing["hp"]) <= 0:
				var ore := str(thing["ore"])
				things.erase(c)
				blocked.erase(c)
				hard.erase(c)
				if props.has(c):
					(props[c] as Sprite2D).queue_free()
					props.erase(c)
				# Ore rocks give one lump, often two with a better pickaxe or the mining tree.
				var lumps := 2 if ore == "stone" else 1 + (1 if randf() < 0.3 + 0.1 * GameState.tool_tier("pickaxe") + GameState.bonus("mining", "ore_bonus") else 0)
				# Resonance (spell): +1 ore from every rock today.
				if ore != "stone" and int(GameState.run["flags"].get("ore_bonus_day", -1)) == int(GameState.run["day"]):
					lumps += 1
				give(ore, lumps)
				xp("mining", (2 if ore == "stone" else 5) + mine_tier)
				queue_redraw()
				_try_more(1)
			return true
	return false


## Prompts-11 tiered floor set for this floor ("" = use the older variants).
func _tier_set() -> String:
	var ts: String = str(theme.get("ts", ""))
	if ts != "" and Art.has("tiles", "mine_%s_fill_0" % ts):
		return str(ts)
	return ""


func _variant() -> String:
	return str(theme.get("var", "earth"))


## Prompts 16 cave kit: seamless floor and rock, and a painted wall face.
func _draw_cave_kit() -> bool:
	var k := str(theme.get("cave", "earth"))
	if not Art.has("seamless", "cave_%s_floor" % k) or not Art.has("seamless", "cave_%s_rock" % k):
		return false
	var tint: Array = theme.get("tint", [1, 1, 1])
	var tc := Color(float(tint[0]), float(tint[1]), float(tint[2]))
	var dark := tc.darkened(0.38 + 0.002 * mini(floor_no, 100))
	for y in range(-pad, rows + pad):
		for x in range(-pad, cols + pad):
			var c := Vector2i(x, y)
			if _open.has(c):
				seam_cell(self, "cave_%s_floor" % k, c, tc)
			else:
				seam_cell(self, "cave_%s_rock" % k, c, dark)
	var wall := Art.tex("cliffs", "cave_%s_wall" % k)
	if wall:
		var face_h := TILE * 1.5
		var src_w := float(wall.get_height()) * TILE / face_h
		var period := maxi(1, int(wall.get_width() / src_w))
		for c: Vector2i in _open:
			var up := c + Vector2i(0, -1)
			if not _open.has(up):
				var sx := float(posmod(c.x, period)) * src_w
				draw_texture_rect_region(wall, Rect2(up.x * TILE, up.y * TILE - TILE * 0.45, TILE, face_h), Rect2(sx, 0, src_w, wall.get_height()), dark.lightened(0.15))
	# Soft shadow along side and bottom edges so the floor reads as dug out.
	for c: Vector2i in _open:
		var r := Rect2(c * TILE, Vector2i(TILE, TILE))
		if not _open.has(c + Vector2i(0, 1)):
			draw_rect(Rect2(r.position + Vector2(0, TILE - 3), Vector2(TILE, 3)), Color(0, 0, 0, 0.35))
		if not _open.has(c + Vector2i(-1, 0)):
			draw_rect(Rect2(r.position, Vector2(3, TILE)), Color(0, 0, 0, 0.3))
		if not _open.has(c + Vector2i(1, 0)):
			draw_rect(Rect2(r.position + Vector2(TILE - 3, 0), Vector2(3, TILE)), Color(0, 0, 0, 0.3))
	return true


func draw_map() -> void:
	var v := _variant()
	if _grotto:
		var wc := {}
		for c in things:
			if str(things[c].get("type", "")) == "water":
				wc[c] = true
		draw_water(wc, "grass")
	var kit := _draw_cave_kit()
	var ts := "" if kit else _tier_set()
	var nfill := 0
	var nwall := 0
	var ntop := 0
	if ts != "":
		while Art.has("tiles", "mine_%s_fill_%d" % [ts, nfill]):
			nfill += 1
		while Art.has("tiles", "mine_%s_wall_%d" % [ts, nwall]):
			nwall += 1
		while Art.has("tiles", "mine_%s_walltop_%d" % [ts, ntop]):
			ntop += 1
	var rock_col := Color(str(theme.get("rock", "24222c")))
	if not kit:
		# Solid rock everywhere first (with a little grain), padding included.
		draw_rect(Rect2(-pad * TILE, -pad * TILE, (cols + 2 * pad) * TILE, (rows + 2 * pad) * TILE), rock_col)
		for y in range(0, rows):
			for x in range(0, cols):
				var c := Vector2i(x, y)
				if _open.has(c):
					continue
				var n := WorldGen.fbm(float(x), float(y), 900 + floor_no, 4.0)
				if n > 0.15:
					draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), rock_col.lightened(0.06))
				elif n < -0.2:
					draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), rock_col.darkened(0.25))
		# Cave floor.
		for c: Vector2i in _open:
			var h := absi((c.x * 73856093) ^ (c.y * 19349663) ^ floor_no)
			var drawn := false
			if nfill > 0:
				drawn = Art.draw_tile(self, "tiles", "mine_%s_fill_%d" % [ts, h % nfill], Vector2(c * TILE), 0)
			elif Art.has("tiles", "mine_floor"):
				drawn = Art.draw_tile(self, "tiles", "mine_floor", Vector2(c * TILE), h % 4)
			if not drawn:
				draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color(str(theme.get("fa", "4a4152"))) if (c.x + c.y) % 2 == 0 else Color(str(theme.get("fb", "50475a"))))
		# Theme wash: the same tiles read differently every 10 floors.
		if floor_no > 10:
			var wash := Color(str(theme.get("fa", "4a4152")))
			wash.a = 0.38
			for c: Vector2i in _open:
				draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), wash)
		# Rock faces: where the floor meets rock to the north, the wall rises above it.
		for c: Vector2i in _open:
			var up := c + Vector2i(0, -1)
			if not _open.has(up):
				var h2 := absi((c.x * 2654435761) ^ floor_no)
				var t := Art.tex("tiles", "mine_%s_wall_%d" % [ts, h2 % maxi(1, nwall)]) if nwall > 0 else null
				if t:
					draw_texture_rect(t, Rect2(up.x * TILE, (up.y - 1) * TILE, TILE, TILE * 2), false)
				else:
					draw_rect(Rect2(up * TILE, Vector2i(TILE, TILE)), rock_col.lightened(0.18))
					draw_rect(Rect2(Vector2(up.x * TILE, up.y * TILE + TILE - 3), Vector2(TILE, 3)), rock_col.lightened(0.3))
		# A soft dark lip along every floor edge so the cave reads as hollowed rock.
		for c: Vector2i in _open:
			var r := Rect2(c * TILE, Vector2i(TILE, TILE))
			for d: Vector2i in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				if not _open.has(c + d):
					var lip := Color(0, 0, 0, 0.35)
					if d == Vector2i(0, 1):
						draw_rect(Rect2(r.position + Vector2(0, TILE - 3), Vector2(TILE, 3)), lip)
					elif d == Vector2i(-1, 0):
						draw_rect(Rect2(r.position, Vector2(3, TILE)), lip)
					else:
						draw_rect(Rect2(r.position + Vector2(TILE - 3, 0), Vector2(3, TILE)), lip)
	draw_rect(Rect2(-pad * TILE, -pad * TILE, (cols + 2 * pad) * TILE, (rows + 2 * pad) * TILE), Color(0.03, 0.02, 0.08, 0.08 + 0.02 * mini(floor_no, 10)))
	var wc2 := {}
	for c in things:
		if str(things[c].get("type", "")) == "water" and not _grotto:
			wc2[c] = true
	if not wc2.is_empty():
		draw_water(wc2, "cave")
	for c: Vector2i in _chasm:
		draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color(0.01, 0.0, 0.03))
		if not _chasm.has(c + Vector2i(0, -1)):
			draw_rect(Rect2(Vector2(c * TILE), Vector2(TILE, 3)), rock_col.lightened(0.2))
	var lava := _lava
	if not lava.is_empty() and not Art.has("tiles", "lava"):
		for c: Vector2i in lava:
			draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color(0.9, 0.35, 0.1))
	if not lava.is_empty() and Art.has("tiles", "lava"):
		_anim_layer.jobs.append(func(ci: CanvasItem) -> void:
			var frame := int(Time.get_ticks_msec() / 300) % 4
			for c: Vector2i in lava:
				Art.draw_tile(ci, "tiles", "lava", Vector2(c * TILE), frame))
	if not _way_open and Art.has("props", "shaft_hint_0") and not things.has(_ladder):
		Art.draw_prop(self, "props", "shaft_hint_%d" % clampi(mine_tier / 2 + (1 if mine_tier >= 3 else 0), 0, 3), cell_center(_ladder) + Vector2(0, 6))
	for k in things:
		var t: Dictionary = things[k]
		var p := cell_center(k)
		match str(t.get("type", "")):
			"rock":
				if props.has(k):
					continue
				draw_circle(p + Vector2(0, -6), 7.0, Color("7a7a86"))
			"lift":
				if not Art.draw_prop(self, "props", "mine_lift", p + Vector2(0, 2)) and not Art.draw_prop(self, "props", "cart_full", p):
					draw_rect(Rect2(p.x - 7, p.y - 12, 14, 12), Color("5a4a3a"))
			"up", "down":
				var nm := "ladder_up" if str(t["type"]) == "up" else "ladder_down"
				if Art.has("props", "ladder_a"):
					nm = "ladder_a" if str(t["type"]) == "up" else "shaft"
				if str(t["type"]) == "down" and Art.has("props", "shaft_open_0"):
					nm = "shaft_open_%d" % clampi(mine_tier / 2 + (1 if mine_tier >= 3 else 0), 0, 3)
				if not Art.draw_prop(self, "props", nm, p):
					draw_rect(Rect2(p.x - 6, p.y - 14, 12, 14), Color("1a1620"))

		draw_rect(Rect2(0, (rows - 1) * TILE, cols * TILE, TILE), Color("221d28"))
		draw_rect(Rect2(0, 0, TILE, rows * TILE), Color("221d28"))
		draw_rect(Rect2((cols - 1) * TILE, 0, TILE, rows * TILE), Color("221d28"))
	label("floor %d · %s" % [floor_no, str(theme.get("name", ""))], Vector2(2 * TILE, TILE - 3), 10 * TILE)


func _place_props() -> void:
	var ts := _tier_set()
	if ts != "":
		var nrock := 0
		while Art.has("props", "mine_%s_rock_%d" % [ts, nrock]):
			nrock += 1
		var ore_sets := {"deep": {"iron": "a", "gold": "b"}, "crystal": {"shard": "a", "gold": "b"}, "dark": {"dark": "a", "shard": "b"}, "heart": {"shard": "a", "dark": "b"}}
		for k in things:
			var t: Dictionary = things[k]
			if str(t.get("type", "")) != "rock":
				continue
			var ore := str(t["ore"])
			var nm := ""
			var oset: Dictionary = ore_sets.get(ts, {})
			if oset.has(ore) and Art.has("props", "mine_%s_ore_%s_0" % [ts, oset[ore]]):
				nm = "mine_%s_ore_%s_0" % [ts, oset[ore]]
			elif ore != "stone" and Art.has("props", "node_" + ore):
				nm = "node_" + ore
			elif nrock > 0:
				nm = "mine_%s_rock_%d" % [ts, absi((k.x * 7 + k.y * 13)) % maxi(1, mini(nrock, 5))]
			if nm != "":
				prop("props", nm, k)
		var rng := RandomNumberGenerator.new()
		rng.seed = 4100 + floor_no
		var ndec := 0
		while Art.has("props", "mine_%s_decal_%d" % [ts, ndec]):
			ndec += 1
		for i in 8:
			var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(2, rows - 3))
			if not things.has(c) and not blocked.has(c) and ndec > 0:
				var sp := prop("props", "mine_%s_decal_%d" % [ts, rng.randi_range(0, ndec - 1)], c, 0, 0.0, false)
				if sp:
					sp.z_index = -1
		for x in [2, cols - 3]:
			var c := Vector2i(x, 1)
			if not things.has(c) and Art.has("props", "mine_%s_lamp_0" % ts):
				prop("props", "mine_%s_lamp_%d" % [ts, x % 2], c)
		for i in 2:
			var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(2, rows - 3))
			if not things.has(c) and not blocked.has(c) and Art.has("props", "mine_%s_stalag_0" % ts):
				prop("props", "mine_%s_stalag_%d" % [ts, i], c)
		if floor_no % 2 == 0 and Art.has("props", "mine_%s_cart" % ts) and not things.has(Vector2i(2, rows - 3)):
			prop("props", "mine_%s_cart" % ts, Vector2i(2, rows - 3))
			blocked[Vector2i(2, rows - 3)] = true
		if floor_no % 5 == 0 and not things.has(Vector2i(cols - 3, 2)):
			prop("props", "mine_%s_skeleton" % ts if Art.has("props", "mine_%s_skeleton" % ts) else "skeleton", Vector2i(cols - 3, 2))
			blocked[Vector2i(cols - 3, 2)] = true
			set_thing(cols - 3, 2, {"type": "skeleton", "hint": "A: an old miner"})
		if floor_no % 3 == 0 and Art.has("props", "mine_%s_crystal" % ts):
			var c := Vector2i(rng.randi_range(3, cols - 4), rng.randi_range(3, rows - 4))
			if not things.has(c) and not blocked.has(c):
				prop("props", "mine_%s_crystal" % ts, c)
		if ts == "heart" and floor_no >= 21 and Art.has("props", "heart_crystal"):
			anim_prop("props", "heart_crystal", Vector2i(cols / 2, 4), 2, 3.0, true, 0.5)
		return
	if Art.has("props", "ore_copper"):
		var v := _variant()
		var deep := Art.has("props", "node_copper")
		for k in things:
			var t: Dictionary = things[k]
			if str(t.get("type", "")) != "rock":
				continue
			var ore := str(t["ore"])
			var nm: String = {"stone": "mrock_a" if (k.x + k.y) % 3 != 0 else "mrock_b", "copper": "ore_copper", "iron": "ore_iron", "shard": "ore_crystal", "gold": "ore_gold", "dark": "ore_dark"}.get(ore, "mrock_a")
			if deep:
				nm = {"stone": "mrock_%s_%d" % [v, (k.x + k.y) % 2], "copper": "node_copper", "iron": "node_iron", "shard": "node_crystal", "gold": "node_gold", "dark": "node_dark"}.get(ore, nm)
			prop("props", nm, k)
		if deep:
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = 4000 + floor_no
			for i in 3:
				var c := Vector2i(rng2.randi_range(2, cols - 3), rng2.randi_range(2, rows - 3))
				if not things.has(c) and not blocked.has(c):
					prop("props", "stalagmite_a", c)
			for x in [3, cols - 4]:
				var sp := Art.sprite("props", "stalactite_%s" % ["a", "b", "c"][x % 3])
				if sp:
					sp.position = Vector2(x * TILE + 8, TILE + 20)
					add_child(sp)
			prop("props", "beam_lamp", Vector2i(cols / 2 - 1, 1), 1)
			if floor_no % 2 == 0 and not things.has(Vector2i(2, rows - 3)):
				prop("props", "cart_full", Vector2i(2, rows - 3))
				blocked[Vector2i(2, rows - 3)] = true
			if floor_no % 5 == 0 and not things.has(Vector2i(cols - 3, 2)):
				prop("props", "skeleton", Vector2i(cols - 3, 2))
				blocked[Vector2i(cols - 3, 2)] = true
				set_thing(cols - 3, 2, {"type": "skeleton", "hint": "A: an old miner"})
		var rng := RandomNumberGenerator.new()
		rng.seed = 3000 + floor_no
		for i in 4:
			var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(2, rows - 3))
			if not things.has(c) and not blocked.has(c):
				pass  # pickable mushrooms are placed as findables now
		if floor_no % 3 == 0:
			prop("props", "beam", Vector2i(cols / 2 - 1, 1), 1)
		return
	if not Art.has("nature", "rock_m"):
		return
	for k in things:
		var t: Dictionary = things[k]
		if str(t.get("type", "")) != "rock":
			continue
		prop("nature", "rock_m", k)


const FORAGE_PROP := {"cave_mushroom": "cave_mush_orange", "mushroom": "cave_mushroom", "mushroom_spore": "cave_mush_purple", "cave_fig": "cluster_green",
	"cave_bloom": "cave_mush_blue", "shard": "cluster_purple", "amethyst": "cluster_purple", "fossil": "cave_moss", "gold": "cluster_red", "dark": "cluster_purple",
	"crystal_refined": "cluster_blue"}


func _place_find_props() -> void:
	var tint: Array = theme.get("tint", [1, 1, 1])
	for c in things.keys():
		var t: Dictionary = things[c]
		match str(t.get("type", "")):
			"forage":
				var nm := str(FORAGE_PROP.get(str(t["item"]), "gmush_blue"))
				if Art.has("props", nm):
					prop("props", nm, c, 0, 0.0, false, 0.3 if nm.begins_with("cave_mush") else 0.5)
				elif Art.has("items", str(t["item"])):
					var sp := Art.sprite("items", str(t["item"]))
					if sp:
						sp.position = cell_center(c) + Vector2(0, -4)
						sp.scale = Vector2(0.4, 0.4)
						add_child(sp)
						props[c] = sp
			"crate":
				prop("props", "cave_ore_crate" if str(t.get("kind", "")) == "crates_a" and Art.has("props", "cave_ore_crate") else str(t.get("kind", "crates_a")), c, 0, 0.0, true, 0.32)
			"mchest", "bigchest":
				var sp2 := prop("props", "chest_closed", c)
				if sp2 and str(t["type"]) == "bigchest":
					sp2.modulate = Color(1.25, 1.1, 0.7)
	# Theme tint on rocks and props so every 10 floors looks different even
	# before each theme has its own art.
	for c in props:
		var n: Node = props[c]
		if n is CanvasItem and str(things.get(c, {}).get("type", "")) == "rock":
			(n as CanvasItem).modulate = Color(float(tint[0]), float(tint[1]), float(tint[2]))


func _process(delta: float) -> void:
	super(delta)
	# The keeper can't be boxed in: its ground slam breaks every rock around it.
	if _guardian != null and is_instance_valid(_guardian) and _guardian._alive and not get_tree().paused:
		_gsmash_t -= delta
		if _gsmash_t <= 0.0:
			_gsmash_t = randf_range(2.5, 4.0)
			var gc := world_to_cell(_guardian.position)
			var broke := 0
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var cc := gc + Vector2i(dx, dy)
					if things.has(cc) and str(things[cc].get("type", "")) in ["rock", "crate"]:
						things.erase(cc)
						blocked.erase(cc)
						hard.erase(cc)
						if props.has(cc):
							(props[cc] as Node).queue_free()
							props.erase(cc)
						broke += 1
			if broke > 0:
				shake(2.5)
				fx("boss_shockwave" if Art.has("fx", "boss_shockwave") else "poof", _guardian.position, 12.0, 0.5)
				queue_redraw()


func _deepest() -> int:
	return int(GameState.run["flags"].get("mine_deepest", 1))


## Within a 25-floor tier, every floor deeper hits harder and lasts longer.
func _depth_scale(e: Enemy) -> void:
	if e == null:
		return
	var into := (floor_no - 1) % 25
	var m := 1.0 + 0.06 * into + 0.1 * mine_tier
	e.max_hp = int(round(e.max_hp * m))
	e.hp = e.max_hp
	e.damage = e.damage + into / 10


func on_enemy_died(e: Enemy) -> void:
	super(e)
	if e == _guardian:
		_guardian = null
		_open_way()
	else:
		_try_more(3)


## The floor's gatekeeper: the tier's guardian kind, run at this floor's tier,
## one more ability per floor into the tier, and more hp the deeper you are.
func _summon_guardian() -> void:
	if _guardian != null or _way_open:
		return
	var kinds: Array = GameState.tier_data.get("mine", {}).get("guardians", ["golem"])
	var kind := str(kinds[mini(mine_tier, kinds.size() - 1)])
	var at := cell_center(_ladder)
	if _grotto:
		at = cell_center(_nearest_open(Vector2i(cols / 2, rows / 2)))
	shake(3.0)
	fx("keeper_wake" if Art.has("fx", "keeper_wake") else "boss_shockwave", at, 12.0, 0.8)
	await get_tree().create_timer(0.9 if Art.has("fx", "keeper_wake") else 0.4).timeout
	# Never weaker than its native tier; floor 1's golem is still a golem.
	_guardian = spawn_enemy(kind, at, maxi(mine_tier, GameState.enemy_tier(kind)))
	_guardian.is_guardian = true
	_depth_scale(_guardian)
	_guardian.set_meta("boss_name", "Keeper of floor %d" % floor_no)
	var into := mini(5, ((floor_no - 1) % 25) / 5)
	_guardian.max_hp = int(_guardian.max_hp * minf(2.0, 1.3 + 0.08 * into))
	_guardian.hp = _guardian.max_hp
	var extra: Array = ["lunge", "stomp", "ranged", "shield", "summon", "regen"]
	for i in into:
		for a in extra:
			if not _guardian.abilities.has(a):
				_guardian.abilities.append(a)
				break
	_guardian.reward *= 3
	if Art.has("ui", "card_keeper_%d" % mine_tier):
		boss_card("card:card_keeper_%d" % mine_tier, ["The Stone Fist", "The Quarrymaster", "The Cracked Helm", "The Crystal King", "The Dark Warden", "The Heart's Shadow"][mine_tier])
	else:
		boss_card(kind, "Keeper of floor %d" % floor_no)
	hud.toast("The keeper of floor %d wakes!" % floor_no, Color(1, 0.7, 0.7))
	Music.instance(get_tree()).sfx("levelup")


func _open_way() -> void:
	GameState.run["flags"]["mine_open_%d" % floor_no] = true
	_way_open = true
	things[_ladder] = {"type": "down", "hint": "A: climb down to floor %d" % (floor_no + 1)}
	blocked.erase(_ladder)
	hard.erase(_ladder)
	if props.has(_ladder):
		(props[_ladder] as Node).queue_free()
		props.erase(_ladder)
	shake(4.0)
	fx("rock_m_break", cell_center(_ladder), 14.0, 0.8)
	queue_redraw()
	queue_redraw()
	hud.toast("The rock splits. A shaft leads down!", Color(0.8, 1.0, 0.8))
	GameState.add_hint("The way down to floor %d is open." % (floor_no + 1))
	if floor_no % 5 == 0:
		hud.toast("The lift can reach floor %d now." % floor_no, Color(0.8, 0.9, 1.0))



func _use_lift() -> void:
	var floors: Array = []
	var f := 5
	while f <= _deepest():
		floors.append(f)
		f += 5
	# Deep Breath: the cart drops past the last checkpoint.
	var extra := int(GameState.bonus("mining", "deeper"))
	if extra > 0 and not floors.is_empty():
		var deepest_ok := mini(_deepest(), int(floors[-1]) + extra)
		if deepest_ok > int(floors[-1]):
			floors.append(deepest_ok)
	floors.insert(0, 1)
	var labels: Array = []
	for n in floors:
		labels.append("Floor %d · %s" % [n, str(theme_for(int(n))["name"])])
	if GameState.run["flags"].has("hollow_heart_open"):
		floors.append(-1)
		labels.append("The Hollow Heart")
	labels.append("Stay")
	player.frozen = true
	var d := Dialogue.instance(get_tree())
	d.say([{"who": "", "text": "Granite's lift. Rope creaks, lamp swings.", "choice": labels, "key": ""}])
	await d.finished
	player.frozen = false
	if d.last_choice >= 0 and d.last_choice < floors.size():
		if int(floors[d.last_choice]) == -1:
			go_to("hollow_heart", Vector2.ZERO, "down")
			return
		GameState.run["mine_floor"] = int(floors[d.last_choice])
		go_to("mine", Vector2.ZERO)


## Mer, the mercat of the grotto. Join her and the water opens.
func _meet_mer() -> void:
	player.frozen = true
	if Companion.party()["known"].has("mer"):
		var d0 := Dialogue.instance(get_tree())
		d0.say([{"who": "Mer", "text": "Swim with me?" if Companion.active_id() != "mer" else "I'm right here. The ladder's under the deep part, past the six stones.", "choice": ["Mer joins me", "Not now"] if Companion.active_id() != "mer" else ["OK"], "key": ""}])
		await d0.finished
		if d0.last_choice == 0 and Companion.active_id() != "mer":
			Companion.recruit("mer")
			hud.toast("Mer is with you. The water is yours.", Color(0.8, 0.95, 1.0))
			_refresh_party()
		player.frozen = false
		return
	await say([
		{"who": "", "text": "On a dry rock at the water's edge: a cat. Grey, wet, entirely unbothered. Its tail is... not a cat's tail."},
		{"who": "Mer", "text": "You came down the dark stair with a lantern and no fear. That's rarer than crystal."},
		{"who": "Mer", "text": "I'm Mer. I was a cat once, before the water. Now I'm a mercat, which is better in every way but the fur."},
		{"who": "Mer", "text": "The crystals you want are under the black water. Six of them. You can't reach them; your kind sinks."},
		{"who": "Mer", "text": "But if I'm beside you, the water remembers me, and it'll let you borrow a tail. Breathe, dive, the lot. Only while I'm with you, mind."},
	])
	var d := Dialogue.instance(get_tree())
	d.say([{"who": "Mer", "text": "Come on, then. The water's warmer than it looks.", "choice": ["Swim with Mer", "Not yet"], "key": ""}])
	await d.finished
	if d.last_choice == 0:
		Companion.recruit("mer")
		GameState.add_quest("mer_crystals", "Dive with Mer for the six grotto crystals.")
		hud.toast("Mer joined you! Walk into the water.", Color(0.8, 0.95, 1.0))
		Music.instance(get_tree()).sfx("levelup")
		_refresh_party()
	else:
		Companion.refuse("mer")
		await say([{"who": "Mer", "text": "...Suit yourself. I'll be here. I'm always here."}])
	player.frozen = false


func _ore_glimmer() -> void:
	if player == null:
		return
	var pc := world_to_cell(player.position)
	for c in things:
		var t: Dictionary = things[c]
		if str(t.get("type", "")) == "rock" and str(t.get("ore", "stone")) != "stone" and (c - pc).length() <= 6.0:
			fx("sparkle", cell_center(c) + Vector2(0, -8), 8.0, 0.5)

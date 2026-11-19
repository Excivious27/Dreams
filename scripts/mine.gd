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
	{"cave": "earth", "name": "Mossy Hollows", "ores": ["copper"], "var": "earth", "ts": "", "rock": "1f2a1c", "fa": "3e4a34", "fb": "44503a", "tint": [0.85, 1.0, 0.85], "feat": ["water"], "forage": ["cave_mushroom", "cave_fig", "mushroom_spore"]},
	{"cave": "stone", "name": "Grey Stone Deeps", "ores": ["iron"], "var": "stone", "ts": "deep", "rock": "24222c", "fa": "4a4152", "fb": "50475a", "tint": [1.0, 1.0, 1.0], "feat": [], "forage": ["cave_fig", "cave_mushroom"]},
	{"cave": "stone", "name": "Flooded Galleries", "ores": ["copper", "iron"], "var": "stone", "ts": "deep", "rock": "1c2430", "fa": "3a4656", "fb": "40506a", "tint": [0.8, 0.9, 1.05], "feat": ["water"], "forage": ["cave_fig", "mushroom_spore"]},
	{"cave": "earth", "name": "Fungal Caverns", "var": "earth", "ts": "", "rock": "241c2c", "fa": "3c3048", "fb": "42354e", "tint": [1.0, 0.85, 1.0], "feat": ["glow"], "forage": ["cave_bloom", "mushroom_spore", "cave_mushroom"]},
	{"cave": "crystal", "name": "Crystal Veins", "ores": ["shard"], "var": "stone", "ts": "crystal", "rock": "1c1c34", "fa": "3c3c64", "fb": "42426c", "tint": [0.85, 0.9, 1.1], "feat": ["crystals"], "forage": ["shard", "cave_bloom"]},
	{"cave": "ice", "name": "Frost Caves", "ores": ["iron", "silver"], "var": "ice", "ts": "", "rock": "1c2634", "fa": "4a5c6c", "fb": "52667a", "tint": [0.85, 0.95, 1.1], "feat": ["water"], "forage": ["cave_fig", "shard"]},
	{"cave": "crystal", "name": "Amethyst Grotto", "ores": ["amethyst", "shard"], "var": "ice", "ts": "crystal", "rock": "241434", "fa": "4a2e5c", "fb": "523466", "tint": [1.0, 0.8, 1.1], "feat": ["crystals"], "forage": ["amethyst", "shard", "cave_bloom"]},
	{"cave": "earth", "name": "Sandstone Ruins", "ores": ["fossil", "gold"], "var": "earth", "ts": "", "rock": "3a2c1c", "fa": "6a5638", "fb": "72603e", "tint": [1.1, 1.0, 0.85], "feat": [], "forage": ["fossil", "cave_fig"]},
	{"cave": "stone", "name": "Gold Seams", "ores": ["gold"], "var": "stone", "ts": "deep", "rock": "2c2418", "fa": "5a4a30", "fb": "62523a", "tint": [1.1, 1.0, 0.8], "feat": [], "forage": ["gold", "cave_bloom"]},
	{"cave": "stone", "name": "Magma Rifts", "ores": ["dark", "gold"], "var": "lava", "ts": "", "rock": "2c1814", "fa": "4a2a22", "fb": "52302a", "tint": [1.1, 0.85, 0.8], "feat": ["lava"], "forage": ["dark", "cave_fig"]},
	{"cave": "stone", "name": "Obsidian Halls", "ores": ["dark"], "var": "lava", "ts": "dark", "rock": "120e16", "fa": "2a2432", "fb": "302a3a", "tint": [0.8, 0.8, 0.95], "feat": ["lava"], "forage": ["dark", "shard"]},
	{"cave": "stone", "name": "Drowned Dark", "ores": ["dark", "shard"], "var": "stone", "ts": "dark", "rock": "0e1620", "fa": "22303c", "fb": "283846", "tint": [0.8, 0.9, 1.0], "feat": ["water", "glow"], "forage": ["cave_bloom", "dark"]},
	{"cave": "crystal", "name": "The Void Reach", "ores": ["dark", "emerald"], "var": "stone", "ts": "dark", "rock": "0c0a14", "fa": "1e1a2c", "fb": "241f34", "tint": [0.9, 0.8, 1.1], "feat": ["chasm"], "forage": ["dark", "crystal_refined"]},
	{"cave": "stone", "name": "The Heart's Edge", "ores": ["emerald", "shard"], "var": "lava", "ts": "heart", "rock": "1a0c18", "fa": "3a1c34", "fb": "42223c", "tint": [1.1, 0.85, 1.0], "feat": ["crystals", "glow"], "forage": ["crystal_refined", "shard", "cave_bloom"]},
]


static func theme_for(f: int) -> Dictionary:
	return THEMES[clampi((f - 1) / 10, 0, THEMES.size() - 1)]


## How much you've "tried" this floor: rocks broken count 1, kills count 3.
## Past the threshold the guardian shows up; beat it and the way down opens.
var _slam_redraw := false

const MineChunk := preload("res://scripts/mine_chunk.gd")
## The floor is drawn by 16x16-cell MineChunk nodes (off-screen ones are culled;
## a broken rock redraws one chunk). false = the old single-canvas drawing.
const CHUNKED := true
const CHUNK := 16
var _chunks := {}            # Vector2i chunk origin (cells) -> [ground, top]
var _ci: CanvasItem = null   # canvas the floor is being drawn on right now
var _clip := Rect2i()        # cells being drawn
var _clip_px := Rect2()      # the same, in content pixels

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
	if _keeper_due():
		_summoning = true
		call_deferred("_summon_guardian")
	elif not _way_open and _guardian == null and not _summoning:
		var t := _tried()
		var thr := _threshold()
		if t >= thr:
			if t - n < thr:
				hud.toast("The floor trembles... something is coming up. Keep at it.", Color(0.9, 0.75, 0.9))
		elif floor_no <= 3 and (t % 4 == 0 or t - n < thr / 2 and t >= thr / 2):
			hud.toast("The rock shifts (%d/%d)" % [t, thr], Color(0.8, 0.75, 0.9))
		elif t >= thr / 2 and t - n < thr / 2:
			hud.toast("Something below is listening.", Color(0.8, 0.75, 0.9))


## Tom: the floor-1 keeper came up far too easily. It needs real progress now:
## enough digging/fighting (a share of the floor's rocks; kills count 3) AND
## some time spent on the floor. Both are kept per floor and day.
func _keeper_due() -> bool:
	return not _way_open and _guardian == null and not _summoning and _tried() >= _threshold() and _secs() >= _min_secs()


## Seconds spent on this floor today (across visits).
func _secs() -> float:
	return float(GameState.run.get("mine_secs", {}).get("%d_%d" % [floor_no, int(GameState.run["day"])], 0.0)) + _secs_live


var _secs_live := 0.0   # not yet written to the save


func _bank_secs() -> void:
	if _secs_live <= 0.0:
		return
	var day := int(GameState.run["day"])
	var k := "%d_%d" % [floor_no, day]
	var old: Dictionary = GameState.run.get("mine_secs", {})
	var d := {}
	for ok in old:
		if str(ok).ends_with("_%d" % day):
			d[ok] = old[ok]
	d[k] = float(d.get(k, 0.0)) + _secs_live
	_secs_live = 0.0
	GameState.run["mine_secs"] = d


func _min_secs() -> float:
	if floor_no == 1:
		return 100.0
	if floor_no == 2:
		return 75.0
	if floor_no <= 10:
		return 45.0
	return 25.0


## How much digging and fighting wakes the keeper: random per floor and day,
## and on the first floors a real share of the rock on the floor.
func _threshold() -> int:
	var day := int(GameState.run["day"])
	var key := "%d_%d" % [floor_no, day]
	var old: Dictionary = GameState.run.get("mine_thresh", {})
	if floor_no <= 3:
		# A share of this floor's rock (rocks 1, crates 1, kills 3): this layout's.
		var share: float = [0.0, 0.17, 0.15, 0.13][floor_no]
		var lo: int = [0, 22, 20, 18][floor_no]
		lo = mini(lo, int(_rock_total * 0.4) + 6)   # a small, rock-poor layout still opens
		return clampi(int(_rock_total * share), lo, lo + 14)
	if not old.has(key):
		var base := 14.0 + minf(60.0, floor_no * 0.4)
		var r := randf()
		var mult := randf_range(0.5, 0.7) if r < 0.15 else (randf_range(0.8, 1.0) if r < 0.4 else randf_range(1.0, 1.6))
		var v := int(round(base * mult))
		var d := {key: v}
		for k in old:
			if str(k).ends_with("_%d" % day):
				d[k] = old[k]
		GameState.run["mine_thresh"] = d
		old = d
	# Never more than this layout can give (Mer's grotto floods half its rock).
	return mini(maxi(12 if floor_no <= 10 else (8 if floor_no <= 20 else 5), int(old[key])), int(_rock_total * 0.7) + 10)


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
	# Tom: floor 1 should rarely be the same twice. A fresh layout every time you
	# enter or go down: seeded by how many floors you've walked into, the floor
	# and the clock (not the floor alone). The style comes from a big catalogue
	# (scripts/mine_layouts.gd), never one of the last few you saw.
	theme = theme.duplicate(true)
	var rng := RandomNumberGenerator.new()
	_seed = _layout_seed()
	rng.seed = _seed
	var recent: Array = (GameState.run.get("mine_recent", []) as Array).duplicate()
	_style = MineLayouts.pick(floor_no, rng, recent)
	for i in 12:
		if floor_no != 5 or not _style.has("haz"):
			break
		_style = MineLayouts.pick(floor_no, rng, recent)   # Mer's grotto floods its own way
	if floor_no == 5 and _style.has("haz"):
		_style = MineLayouts.style("caverns")
	if force_style != "":
		_style = MineLayouts.style(force_style)   # tools/tests
	_dress = MineLayouts.pick_dress(_style, rng)
	recent.append(str(_style["id"]))
	while recent.size() > 5:
		recent.pop_front()
	GameState.run["mine_recent"] = recent
	# Same cave look, but a nudge of colour each visit.
	var tint: Array = theme.get("tint", [1.0, 1.0, 1.0])
	var tj := rng.randf_range(-0.06, 0.06)
	theme["tint"] = [clampf(float(tint[0]) + tj + rng.randf_range(-0.04, 0.04), 0.7, 1.2), clampf(float(tint[1]) + rng.randf_range(-0.04, 0.04), 0.7, 1.2), clampf(float(tint[2]) - tj + rng.randf_range(-0.04, 0.04), 0.7, 1.2)]
	# Gentle and smaller at the top, bigger the deeper you go.
	var sz := float(_style.get("size", 1.0))
	cols = int((54 + mini(floor_no, 40) * 0.7 + clampi(floor_no - 40, 0, 60) / 4.0 + rng.randi_range(0, 18)) * sz)
	rows = int((46 + mini(floor_no, 40) / 2.5 + clampi(floor_no - 40, 0, 60) / 6.0 + rng.randi_range(0, 14)) * sz)
	mine_tier = GameState.mine_tier(floor_no)
	var lava_ok: bool = "lava" in theme.get("feat", [])
	var lay := {}
	for tries in 4:
		var sid := str(_style["id"]) if tries < 3 else "caverns"
		lay = MineLayouts.carve(sid, cols, rows, rng, floor_no, lava_ok)
		var walk := (lay["open"] as Dictionary).size() - (lay["water"] as Dictionary).size() - (lay["chasm"] as Dictionary).size() - (lay["lava"] as Dictionary).size()
		if walk >= maxi(int(cols * rows * 0.17), 650 + mini(floor_no, 100) * 6):
			break
		if tries == 2:
			_style = MineLayouts.style("caverns")
	_open = lay["open"]
	for c in range(0, cols * rows):
		var cc := Vector2i(c % cols, c / cols)
		if not _open.has(cc):
			blocked[cc] = true
	_layout_hazards(lay)
	# Way in: the walkable cell nearest the top-left; way down: the farthest by walking.
	_entry = _nearest_walk(Vector2i(4, 9))  # a little down from the top, so the toolbar never hides the ladder
	_ladder = _farthest_open(_entry)
	set_thing(_entry.x, _entry.y, {"type": "up", "hint": "A: climb out"})
	_way_open = GameState.run["flags"].has("mine_open_%d" % floor_no)
	if _way_open:
		things[_ladder] = {"type": "down", "hint": ("A: the long lift down to the Hollow Heart" if floor_no >= MAX_FLOOR else "Step in or tap USE: climb down to floor %d" % (floor_no + 1))}
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
		var thr := _roomy_open(mc + Vector2i(2, -1))
		if thr != mc:
			prop("props", "shell_throne", thr, 1)
		var lan := _roomy_open(_entry + Vector2i(-2, 1))
		if lan != mc:
			prop("props", "sunken_lantern", lan, 0)
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
				# A crystal glinting under the water, so you can find them.
				if not GameState.run["flags"].has("grotto_%d" % placed):
					var gnm := "grotto_crystal_a" if placed % 2 == 0 else "grotto_crystal_b"
					if Art.has("props", gnm):
						var gs := prop("props", gnm, c, 0, 0.0, false, 0.28)
						if gs:
							gs.modulate = Color(0.75, 0.9, 1.0, 0.75)
							gs.set_meta("grotto_glint", true)
				placed += 1
				if placed >= 6:
					break
		for pi in 2:
			if wl.size() > 8:
				# Stone-ringed spring pools: they stand on the dry floor beside the lake.
				var pc := _roomy_open(wl[(pi * 7 + 3) % wl.size()])
				if pc != mc and not props.has(pc) and not is_water_cell(pc):
					prop("props", "grotto_pool_" + "ab"[pi], pc, 0, 0.0, true, 0.35)
	# Rock: a share of the walkable floor (the layout style sets how rocky), more deeper.
	var open_list: Array = _open.keys().filter(func(q: Vector2i) -> bool: return not blocked.has(q))
	var count := int(open_list.size() * (0.06 + 0.0003 * mini(floor_no, 100)) * float(_style.get("rocks", 1.0)))
	for i in count:
		if _grotto and i > count / 2:
			break
		var c: Vector2i = open_list[rng.randi() % open_list.size()]
		if c.distance_to(_entry) < 3 or c.distance_to(_ladder) < 2 or things.has(c) or props.has(c) or blocked.has(c) or _bridge.has(c):
			continue
		var roll := rng.randf()
		var ore := "stone"
		var pool: Array = (GameState.tier_data.get("mine", {}).get("ores", []) as Array)
		var ores: Array = pool[mini(mine_tier, pool.size() - 1)] if not pool.is_empty() else ["stone", "copper"]
		# Half stone, the rest spread over the tier's ores (rarest last, least common).
		# Tom: ore was too plentiful; now about one rock in six carries ore.
		if roll > 0.9 and ores.size() > 1:
			var r2 := (roll - 0.9) / 0.1
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
			# Each cave look has its own ore: Gold Seams really has gold, the Grotto amethyst.
			var tb: Array = theme.get("ores", [])
			if not tb.is_empty() and rng.randf() < 0.4:
				ore = str(tb[rng.randi() % tb.size()])
		# Ore gathers in veins: rich rocks pull neighbours toward the same ore.
		var oi := ores.find(ore)
		var hard := (2 if ore == "stone" and floor_no < 15 else (3 if ore == "stone" else 3 + (oi if oi >= 0 else ores.size()) / 2)) + floor_no / 15
		set_thing(c.x, c.y, {"type": "rock", "ore": ore, "hp": hard, "hint": "A: mine"})
		if ore != "stone":
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if rng.randf() < 0.2 and _open.has(c + d) and not blocked.has(c + d) and not things.has(c + d) and not props.has(c + d) and (c + d).distance_to(_entry) >= 3 and (c + d).distance_to(_ladder) >= 2:
					set_thing(c.x + d.x, c.y + d.y, {"type": "rock", "ore": ore, "hp": hard, "hint": "A: mine"})
	_features(rng)
	_findables(rng)
	_rock_total = 0
	for k in things:
		if str(things[k].get("type", "")) == "rock":
			_rock_total += 1


## Ores with no node_<ore> sprite borrow a look-alike, so ore never reads as plain stone.
const NODE_ALIAS := {"shard": "node_crystal", "amethyst": "node_crystal", "fossil": "node_coal", "coal": "node_coal", "silver": "node_silver", "emerald": "node_emerald"}

var _open := {}          # walkable cave floor
var _entry := Vector2i(2, 2)


## Layout state: which catalogue style and dressing this visit rolled.
const MineLayouts := preload("res://scripts/mine_layouts.gd")
var _style: Dictionary = {}
var _dress := "plain"
var _seed := 0
var _layout_haz := false     # the layout brought its own water/chasm/lava
var _bridge := {}            # Vector2i -> "chasm"/"lava"/"water": a crossing cut through a hazard
var _rock_total := 0
static var force_style := ""   # tools/tests: carve this style every time


## A new seed on every build: visits walked into, the floor, the day and the clock.
func _layout_seed() -> int:
	var visits := int(GameState.run.get("mine_visits", 0)) + 1
	GameState.run["mine_visits"] = visits
	var h := hash([visits, floor_no, int(GameState.run["day"]), Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	return h & 0x7fffffff


## Water / chasm / lava from the layout onto the map, then every cut-off pocket
## of floor bigger than a nook gets a crossing (planks over chasms and lava,
## stepping stones through water) so the whole floor can be walked.
func _layout_hazards(lay: Dictionary) -> void:
	for c: Vector2i in lay["water"]:
		set_thing(c.x, c.y, {"type": "water", "hint": ""}, true)
	for c: Vector2i in lay["chasm"]:
		_chasm[c] = true
		blocked[c] = true
	for c: Vector2i in lay["lava"]:
		_lava[c] = true
		blocked[c] = true
	_layout_haz = not ((lay["water"] as Dictionary).is_empty() and (lay["chasm"] as Dictionary).is_empty() and (lay["lava"] as Dictionary).is_empty())
	if _layout_haz:
		_connect_pockets()
		# Nooks left as islands: no entry, ladder or anything else out there.
		var comps := _components()
		if comps.size() > 1:
			_main.clear()
			for c: Vector2i in comps[0]:
				_main[c] = true


func _is_haz(c: Vector2i) -> bool:
	return _chasm.has(c) or _lava.has(c) or (things.has(c) and str(things[c].get("type", "")) == "water")


func _walkable(c: Vector2i) -> bool:
	return _open.has(c) and not _is_haz(c)


const _D4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func _components() -> Array:
	var seen := {}
	var comps: Array = []
	for c: Vector2i in _open:
		if seen.has(c) or not _walkable(c):
			continue
		var comp: Array = []
		var st: Array = [c]
		seen[c] = true
		while not st.is_empty():
			var q: Vector2i = st.pop_back()
			comp.append(q)
			for d in _D4:
				var n := q + d
				if not seen.has(n) and _walkable(n):
					seen[n] = true
					st.append(n)
		comps.append(comp)
	comps.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
	return comps


func _connect_pockets() -> void:
	for round_i in 14:
		var comps := _components()
		if comps.size() <= 1:
			return
		var main := {}
		for c: Vector2i in comps[0]:
			main[c] = true
		# The next pocket worth reaching (nooks under 12 cells stay islands).
		var target: Array = []
		for i in range(1, comps.size()):
			if (comps[i] as Array).size() >= 12:
				target = comps[i]
				break
		if target.is_empty():
			return
		var tset := {}
		for c: Vector2i in target:
			tset[c] = true
		# 0-1 BFS from the pocket across hazard cells (cost 1) and floor (cost 0) to the main cave.
		var dist := {}
		var par := {}
		var dq: Array = []
		for c: Vector2i in target:
			dist[c] = 0
			dq.append(c)
		var hit := Vector2i(-1, -1)
		var head := 0
		var guard := 0
		while head < dq.size() and guard < 200000:
			guard += 1
			var q: Vector2i = dq[head]
			head += 1
			if main.has(q):
				hit = q
				break
			for d in _D4:
				var n := q + d
				if not _open.has(n):
					continue
				var w := 1 if _is_haz(n) else 0
				var nd := int(dist[q]) + w
				if not dist.has(n) or nd < int(dist[n]):
					dist[n] = nd
					par[n] = q
					if w == 0:
						dq.insert(head, n)   # 0-cost edges go to the front
					else:
						dq.append(n)
		if hit.x < 0:
			return
		var c := hit
		while par.has(c):
			if _is_haz(c):
				var kind := "chasm" if _chasm.has(c) else ("lava" if _lava.has(c) else "water")
				_chasm.erase(c)
				_lava.erase(c)
				if things.has(c) and str(things[c].get("type", "")) == "water":
					things.erase(c)
					hard.erase(c)
				blocked.erase(c)
				_bridge[c] = kind
			c = par[c]


var _main := {}   # the main walkable cave when hazards leave islands (empty = all of it)


func _nearest_walk(c: Vector2i) -> Vector2i:
	var bestc := c
	var bd := 1e9
	for o: Vector2i in _open:
		var d := float((o - c).length_squared())
		if d < bd and not things.has(o) and not blocked.has(o) and not _bridge.has(o) and (_main.is_empty() or _main.has(o)):
			bd = d
			bestc = o
	return bestc


## Theme hazards: pools, lava and chasms on open floor away from the paths in
## and out. They block walking (Tideswim / a mercat lets you swim pools).
## Cells you can walk to from the entry (through rock you can mine, never
## through lava, chasms or deep water). Findables only go here.
var _reach := {}


func _features(rng: RandomNumberGenerator) -> void:
	_reach = _open.duplicate()
	var feat: Array = theme.get("feat", [])
	var seed := _seed % 100000 + floor_no * 13
	# A layout with its own water/chasms skips the theme's (no clutter); the first
	# floors get only small pools.
	var bump := 0.08 if floor_no <= 3 else 0.0
	for c: Vector2i in (_open if not _layout_haz else {}):
		# Rocks were placed first: hazards swallow them (no rocks stranded in lava/pools).
		if (things.has(c) and str(things[c].get("type", "")) != "rock") or c.distance_to(_entry) < 6 or c.distance_to(_ladder) < 4 or _bridge.has(c) or blocked.has(c) and not things.has(c):
			continue
		var n := WorldGen.fbm(float(c.x), float(c.y), seed, 10.0 if "lava" in feat else 6.0)
		if "water" in feat and not _grotto and n > 0.38 + bump:
			set_thing(c.x, c.y, {"type": "water", "hint": ""}, true)
		elif "lava" in feat and n > 0.42:
			things.erase(c)
			_lava[c] = true
			blocked[c] = true
		elif "chasm" in feat and n > 0.4:
			things.erase(c)
			_chasm[c] = true
			blocked[c] = true
	# Lava: drop specks under 4 cells (they read as stray orange squares).
	var lseen := {}
	for c: Vector2i in _lava.keys():
		if lseen.has(c):
			continue
		var comp: Array = []
		var st: Array = [c]
		while not st.is_empty():
			var q2: Vector2i = st.pop_back()
			if lseen.has(q2) or not _lava.has(q2):
				continue
			lseen[q2] = true
			comp.append(q2)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				st.append(q2 + d)
		if comp.size() < 4:
			for q2: Vector2i in comp:
				_lava.erase(q2)
				blocked.erase(q2)
	# Water specks too: a 1-3 cell pool draws as a stray teal diamond.
	var wseen := {}
	for c: Vector2i in things.keys():
		if _grotto or wseen.has(c) or not is_water_cell(c):
			continue
		var wcomp: Array = []
		var wst: Array = [c]
		while not wst.is_empty():
			var q3: Vector2i = wst.pop_back()
			if wseen.has(q3) or not is_water_cell(q3):
				continue
			wseen[q3] = true
			wcomp.append(q3)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				wst.append(q3 + d)
		if wcomp.size() < 4:
			for q3: Vector2i in wcomp:
				things.erase(q3)
				blocked.erase(q3)
				hard.erase(q3)
	if ("water" in feat or _layout_haz) and not _grotto:
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
	_reach = reach
	if reach.has(_ladder):
		# Rocks ringed by pools or lava (an island) can't be mined: drop them.
		for c in things.keys():
			if str(things[c].get("type", "")) == "rock" and not reach.has(c):
				var near := false
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if reach.has(c + d):
						near = true
				if not near:
					things.erase(c)
					blocked.erase(c)
	if not reach.has(_ladder):
		_reach = _open.duplicate()
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
		if _reach.has(c) and not things.has(c) and not blocked.has(c) and c.distance_to(_entry) > 3 and c.distance_to(_ladder) >= 2:
			free.append(c)
	if free.is_empty():
		return
	var day := int(GameState.run["day"])
	var forage: Array = theme.get("forage", ["cave_mushroom"])
	# Full forage only on the deepest floor you have reached; old floors refill a little.
	var ak := clampf(_open.size() / 2200.0, 1.0, 2.5)  # bigger caves, a little more to find
	var nf := int(round(((4 + rng.randi_range(0, 4)) if floor_no >= _deepest() else rng.randi_range(1, 3)) * ak)) + (3 if "glow" in theme.get("feat", []) else 0)
	for i in nf:
		var c: Vector2i = free[rng.randi() % free.size()]
		if things.has(c):
			continue
		var key := "mfor_%d_%d_%d" % [floor_no, i, day]
		if GameState.run["flags"].has(key):
			continue
		var item := str(forage[rng.randi() % forage.size()])
		set_thing(c.x, c.y, {"type": "forage", "item": item, "key": key, "hint": "A: pick up %s" % GameState.item_name(item)}, false)
	for i in int(round(rng.randi_range(2, 5) * ak)):
		var c: Vector2i = free[rng.randi() % free.size()]
		var ck := "mcrate_%d_%d_%d" % [floor_no, i, day]
		if not things.has(c) and not GameState.run["flags"].has(ck):
			set_thing(c.x, c.y, {"type": "crate", "key": ck, "kind": "barrel_a" if rng.randf() < 0.4 else "crates_a", "hp": 2 + floor_no / 30, "hint": "A: smash it open"}, true)
	if rng.randf() < 0.15 + 0.001 * mini(floor_no, 100):
		var c: Vector2i = free[rng.randi() % free.size()]
		var key := "mchest_%d_%d" % [floor_no, day]
		if not things.has(c) and not GameState.run["flags"].has(key):
			set_thing(c.x, c.y, {"type": "mchest", "key": key, "hint": "A: a miner's chest"}, true)
	if floor_no % 10 == 0 and not GameState.run["flags"].has("mine_prize_%d" % floor_no):
		# Off to the side: as far as possible from both the way in and the way down.
		var c: Vector2i = free[0]
		var best := -1.0
		for fc: Vector2i in free:
			if things.has(fc):
				continue
			var sc := minf(fc.distance_to(_entry), fc.distance_to(_ladder))
			if sc > best:
				best = sc
				c = fc
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
		if d < bd and not things.has(o) and not blocked.has(o):
			bd = d
			bestc = o
	return bestc


## An open cell near c with open floor all round, so a prop there never plugs a tunnel.
func _roomy_open(c: Vector2i) -> Vector2i:
	var bestc := Vector2i(-1, -1)
	var bd := 1e9
	for o: Vector2i in _open:
		var d := float((o - c).length_squared())
		if d >= bd or things.has(o) or blocked.has(o) or o.distance_to(_entry) < 4 or o.distance_to(_ladder) < 3:
			continue
		var ok := true
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var q := o + Vector2i(dx, dy)
				if not _open.has(q) or blocked.has(q) or (q != o and things.has(q)):
					ok = false
		if ok:
			bd = d
			bestc = o
	return bestc if bestc.x >= 0 else _nearest_open(c)


## Walk distance (BFS) to the farthest open cell: the way down is a real trek.
func _farthest_open(from: Vector2i) -> Vector2i:
	var dist := {from: 0}
	var queue: Array = [from]
	var head := 0
	var far := from
	while head < queue.size():
		var q: Vector2i = queue[head]
		head += 1
		if int(dist[q]) > int(dist[far]):
			far = q
		for d: Vector2i in _D4:
			var n := q + d
			if _open.has(n) and not dist.has(n) and not blocked.has(n) and not _bridge.has(n):
				dist[n] = int(dist[q]) + 1
				queue.append(n)
	# Among the far cells (85%+ of the longest walk), the roomiest: the shaft
	# should sit in open floor you can walk all round, not in a crack.
	var mx := int(dist[far])
	var best := far
	var best_room := -1
	for c: Vector2i in dist:
		if int(dist[c]) < int(mx * 0.85):
			continue
		var room := 0
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var n := c + Vector2i(dx, dy)
				if _open.has(n) and not blocked.has(n):
					room += 1
		if room > best_room or (room == best_room and int(dist[c]) > int(dist[best])):
			best_room = room
			best = c
	return best


## Steps from a to b over floor you can walk or mine, or -1 if more than max_steps.
func _walk_dist(a: Vector2i, b: Vector2i, max_steps: int) -> int:
	var dist := {a: 0}
	var q: Array = [a]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == b:
			return int(dist[c])
		if int(dist[c]) >= max_steps:
			continue
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if _reach.has(n) and not dist.has(n):
				dist[n] = int(dist[c]) + 1
				q.append(n)
	return -1


func after_ready() -> void:
	if CHUNKED:
		_make_chunks()
	hud.toast("Floor %d · %s · %s" % [floor_no, str(theme.get("name", "")), str(_style.get("name", ""))], Color(0.9, 0.85, 1.0))
	# Ore Sense (magic): ore and crystals glimmer through rock within 6 cells.
	if GameState.bonus("magic", "ore_sense") > 0.0:
		var t := Timer.new()
		t.wait_time = 1.6
		t.autostart = true
		t.timeout.connect(_ore_glimmer)
		add_child(t)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed ^ 0x2d2d
	_place_props()
	_place_find_props()
	# Fewer enemies, scaled to cave size (bigger caves no longer mean more crowds);
	# the first floors are gentle.
	var area_k := float(_open.size() - (_open.keys().filter(func(q: Vector2i) -> bool: return is_water_cell(q)).size() if _grotto else 0)) / 900.0  # walkable floor space (Mer's lake isn't)
	var n := int(round((2.0 + mini(floor_no, 60) / 5.0) * area_k))
	if floor_no <= 4:
		n = mini(n, 3 + floor_no)
	n = mini(n, 7 + mini(floor_no, 100) / 20)  # deep floors: bigger caves, not swarms (every roll lands now)
	var pools: Array = GameState.tier_data.get("mine", {}).get("pools", [])
	var pool: Array = pools[mini(mine_tier, pools.size() - 1)] if not pools.is_empty() else ["slime", "bat"]
	# Only cells you can walk to, far enough from the ladder that nothing waits on arrival.
	var ol: Array = _reach.keys().filter(func(q: Vector2i) -> bool: return not blocked.has(q) and not things.has(q) and not (_grotto and is_water_cell(q)) and q.distance_to(_entry) >= 12)
	var guards: Array = GameState.tier_data.get("mine", {}).get("guardians", [])
	for i in mini(n, ol.size()):
		var c: Vector2i = ol.pop_at(rng.randi() % ol.size())
		var kind := str(pool[rng.randi_range(0, pool.size() - 1)])
		if kind in guards and rng.randf() < 0.7:
			kind = str(pool[0])  # keepers are rare as wanderers
		if (floor_no <= 5 and kind in ["rock_crab", "hill_wolf", "shard"]) or (floor_no <= 2 and kind == "grump"):
			kind = "slime" if rng.randf() < 0.6 else "bat"
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
	if _keeper_due():
		_summoning = true
		call_deferred("_summon_guardian")
	_dress_floor()
	_make_down_ui()
	if not GameState.run["flags"].has("mine_tier_seen_%d" % mine_tier) and mine_tier > 0:
		GameState.run["flags"]["mine_tier_seen_%d" % mine_tier] = true
		hud.toast("%s depths. Everything down here hits harder." % GameState.tier_name(mine_tier), Color(0.9, 0.8, 1.0))
	# Arrive with the pickaxe in hand (the hoe only says "Hold the pickaxe").
	var tbar: Array = GameState.run["toolbar"]
	if GameState.held_tool() != "pickaxe" and tbar.has("pickaxe") and GameState.has_tool("pickaxe"):
		GameState.select_slot(tbar.find("pickaxe"))
	if not GameState.run["flags"].has("mine_seen"):
		GameState.run["flags"]["mine_seen"] = true
		player.frozen = true
		await say([
			{"text": "Cold air, and the smell of wet stone. Something drips. Something else squelches."},
			{"text": "Swing your pickaxe at rocks (tap USE): stone, copper, iron, and now and then a crystal shard."},
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
				if props.has(c) and (props[c] as Node).has_meta("grotto_glint"):
					(props[c] as Node).queue_free()
					props.erase(c)
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
			Music.instance(get_tree()).sfx("chest_open", "coin")
			_give_loot(c, _loot(big))
			hud.toast("The floor %d prize!" % floor_no if big else "A miner's stash.", Color(1, 0.9, 0.5))
			return true
		"skeleton":  # an old miner's supply crate (all-ages: no remains)
			if not GameState.run["flags"].has("skel_%d" % floor_no):
				GameState.run["flags"]["skel_%d" % floor_no] = true
				thing["hint"] = ""
				give("gold", 2)
				if GameState.has_quest("theo_book") and not GameState.quest_done("theo_book") and GameState.count("book") == 0:
					give("book", 1)
					tell([{"text": "An old miner's pack, left by his pick when the lift was new. Wrapped in oilcloth inside: a miner's log. Theo's book."}])
				else:
					tell([{"text": "An old miner's pack, left by his pick when the lift was new. There's still something in it."}])
			else:
				hud.toast("Empty now.", Color(0.8, 0.8, 0.85))
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
				Music.instance(get_tree()).sfx("dry_click", "thud")  # clink: the pick is too weak
				return true
			if not GameState.spend_for("pickaxe"):
				hud.toast("Too tired.", Color(1, 0.7, 0.7))
				return true
			player.play_tool("pickaxe")
			Music.instance(get_tree()).sfx("pick", "chop")
			hitstop = maxf(hitstop, 0.025)  # a little weight on each swing
			wobble(c, 0.04)
			fx("stone_chips", cell_center(c) + Vector2(0, -8), 16.0, 0.5)
			var swing := 1 + (GameState.tool_tier("pickaxe") + 1) / 2
			if randf() < GameState.bonus("mining", "double_hit"):
				swing *= 2
			swing += int(GameState.bonus("mining", "mine_power"))
			thing["hp"] = int(thing["hp"]) - swing
			if int(thing["hp"]) <= 0:
				_tremor(c, swing)
				hitstop = maxf(hitstop, 0.05)
				Music.instance(get_tree()).sfx("crate_break", "thud")
				var ore := str(thing["ore"])
				things.erase(c)
				blocked.erase(c)
				hard.erase(c)
				var drawn := not props.has(c)  # rocks without a sprite are part of the floor drawing
				if props.has(c):
					(props[c] as Sprite2D).queue_free()
					props.erase(c)
				# Ore rocks give one lump, often two with a better pickaxe or the mining tree.
				fx("poof", cell_center(c) + Vector2(0, -6), 12.0, 0.4)
				var lumps := (1 + (1 if randf() < 0.5 else 0) + int(GameState.bonus("mining", "stone_bonus") / 3.0)) if ore == "stone" else 1 + (1 if randf() < 0.3 + 0.1 * GameState.tool_tier("pickaxe") + GameState.bonus("mining", "ore_bonus") else 0)
				# Resonance (spell): +1 ore from every rock today.
				if ore != "stone" and int(GameState.run["flags"].get("ore_bonus_day", -1)) == int(GameState.run["day"]):
					lumps += 1
				pop_items(cell_center(c), ore, lumps)
				if randf() < GameState.bonus("mining", "gem_chance") + GameState.bonus("magic", "gem_chance"):
					var gems: Array = [["amethyst"], ["amethyst", "ruby"], ["ruby", "emerald"], ["emerald", "sapphire"], ["sapphire", "ruby"], ["sapphire", "emerald"]][clampi(mine_tier, 0, 5)]
					pop_items(cell_center(c), str(gems[randi() % gems.size()]), 1)
				xp("mining", (3 if ore == "stone" else 6) + mine_tier)
				if drawn:
					redraw_cell(c)
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
## Draws only the cells in _clip (all of them on the legacy path).
func _draw_cave_kit() -> bool:
	var k := str(theme.get("cave", "earth"))
	var floor_nm := "cave_%s_floor" % k
	var rock_nm := "cave_%s_rock" % k
	if not Art.has("seamless", floor_nm) or not Art.has("seamless", rock_nm):
		return false
	var tint: Array = theme.get("tint", [1, 1, 1])
	var tc := Color(float(tint[0]), float(tint[1]), float(tint[2]))
	var dark := tc.darkened((0.58 if k == "crystal" else 0.38) + 0.002 * mini(floor_no, 100))  # crystal walls were as bright as the floor
	var area := _clip.intersection(Rect2i(-pad, -pad, cols + 2 * pad, rows + 2 * pad))
	# Rock cells, then floor cells: each fills only its own cell, and two passes
	# keep the batch (alternating textures along every row broke it per run).
	var floor_cells: Array[Vector2i] = []
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var c := Vector2i(x, y)
			if _open.has(c):
				floor_cells.append(c)
			else:
				seam_cell(_ci, rock_nm, c, dark)
	for c in floor_cells:
		seam_cell(_ci, floor_nm, c, tc)
	var wall := Art.tex("cliffs", "cave_%s_wall" % k)
	if wall:
		var face_h := TILE * 1.5
		var src_w := float(wall.get_height()) * TILE / face_h
		var period := maxi(1, int(wall.get_width() / src_w))
		for c: Vector2i in _cells_in(_open, _face_rows()):
			var up := c + Vector2i(0, -1)
			if not _open.has(up):
				var sx := float(posmod(c.x, period)) * src_w
				_tex_cut(wall, Rect2(up.x * TILE, up.y * TILE - TILE * 0.45, TILE, face_h), Rect2(sx, 0, src_w, wall.get_height()), dark.lightened(0.15))
	# Soft shadow along side and bottom edges so the floor reads as dug out.
	for c: Vector2i in _cells_in(_open, _clip):
		var r := Rect2(c * TILE, Vector2i(TILE, TILE))
		if not _open.has(c + Vector2i(0, 1)):
			_ci.draw_rect(Rect2(r.position + Vector2(0, TILE - 3), Vector2(TILE, 3)), Color(0, 0, 0, 0.35))
		if not _open.has(c + Vector2i(-1, 0)):
			_ci.draw_rect(Rect2(r.position, Vector2(3, TILE)), Color(0, 0, 0, 0.3))
		if not _open.has(c + Vector2i(1, 0)):
			_ci.draw_rect(Rect2(r.position + Vector2(TILE - 3, 0), Vector2(3, TILE)), Color(0, 0, 0, 0.3))
	return true


## Legacy single-canvas path (CHUNKED = false): GameMap._draw cleared the jobs.
func draw_map() -> void:
	_build_layers()
	_draw_part(self, Rect2i(-pad, -pad, cols + 2 * pad, rows + 2 * pad), -1)


## The floor lives in MineChunk nodes; the map's own canvas draws nothing.
func _draw() -> void:
	if CHUNKED:
		return
	super()


## MineChunk._draw lands here.
func draw_chunk(ci: CanvasItem, r: Rect2i, layer: int) -> void:
	ci.draw_set_transform(offset())
	_draw_part(ci, r, layer)
	ci.draw_set_transform(Vector2.ZERO)


## layer 0 = ground, 1 = things + label, -1 = both (legacy).
func _draw_part(ci: CanvasItem, r: Rect2i, layer: int) -> void:
	_ci = ci
	_clip = r
	_clip_px = Rect2(Vector2(r.position * TILE), Vector2(r.size * TILE))
	if layer != 1:
		_draw_ground()
	if layer != 0:
		_draw_things()
	_ci = null


## Water and lava live on their own layers (WaterMask nodes / AnimLayer jobs).
## Chunked: set up once in _make_chunks. Legacy: on every draw, as before.
func _build_layers() -> void:
	var wc := {}
	for c in things:
		if str(things[c].get("type", "")) == "water":
			wc[c] = true
	if not wc.is_empty():
		draw_water(wc, "cave")
	var lava := _lava
	# Soft lava: one curved WaterMask shape (like cave water) instead of 16 px squares;
	# the anim layer then only adds the hot glow along the top edges.
	if not lava.is_empty() and Art.has("seamless", "lava") and soft_ground(lava, "lava", Color(0.12, 0.05, 0.03, 0.55), Color(1.1, 0.95, 0.9)):
		if _anim_layer:
			_anim_layer.jobs.append(func(ci: CanvasItem) -> void:
				var glow := 0.3 + 0.15 * sin(Time.get_ticks_msec() / 400.0)
				for c: Vector2i in _on_screen(lava):
					if not lava.has(c + Vector2i(0, -1)):
						# Soft round glow, not a hard bar (the shore itself is curved).
						var gp := Vector2(c * TILE) + Vector2(TILE / 2.0, 2.0)
						ci.draw_circle(gp, 7.0, Color(1, 0.5, 0.15, glow * 0.18))
						ci.draw_circle(gp, 4.0, Color(1, 0.55, 0.2, glow * 0.22)))
	elif not lava.is_empty() and Art.has("tiles", "lava") and _anim_layer:
		_anim_layer.jobs.append(func(ci: CanvasItem) -> void:
			var frame := int(Time.get_ticks_msec() / 300) % 4
			var vis := _on_screen(lava)
			for c: Vector2i in vis:
				Art.draw_tile(ci, "tiles", "lava", Vector2(c * TILE), frame)
			# A dark rocky lip and a hot glow where lava meets floor, so it reads as a pit.
			var glow := 0.35 + 0.15 * sin(Time.get_ticks_msec() / 400.0)
			for c: Vector2i in vis:
				var o := Vector2(c * TILE)
				if not lava.has(c + Vector2i(0, -1)):
					ci.draw_rect(Rect2(o, Vector2(TILE, 3)), Color(0.12, 0.06, 0.05))
					ci.draw_rect(Rect2(o + Vector2(0, -3), Vector2(TILE, 3)), Color(1, 0.5, 0.15, glow * 0.6))
				if not lava.has(c + Vector2i(0, 1)):
					ci.draw_rect(Rect2(o + Vector2(0, TILE - 2), Vector2(TILE, 2)), Color(0.12, 0.06, 0.05))
				if not lava.has(c + Vector2i(-1, 0)):
					ci.draw_rect(Rect2(o, Vector2(2, TILE)), Color(0.12, 0.06, 0.05))
				if not lava.has(c + Vector2i(1, 0)):
					ci.draw_rect(Rect2(o + Vector2(TILE - 2, 0), Vector2(2, TILE)), Color(0.12, 0.06, 0.05)))


func _draw_ground() -> void:
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
	var full_px := Rect2(-pad * TILE, -pad * TILE, (cols + 2 * pad) * TILE, (rows + 2 * pad) * TILE)
	if not kit:
		# Solid rock everywhere first (with a little grain), padding included.
		_rect_cut(full_px, rock_col)
		var grain := _clip.intersection(Rect2i(0, 0, cols, rows))
		for y in range(grain.position.y, grain.end.y):
			for x in range(grain.position.x, grain.end.x):
				var c := Vector2i(x, y)
				if _open.has(c):
					continue
				var n := WorldGen.fbm(float(x), float(y), 900 + floor_no, 4.0)
				if n > 0.15:
					_ci.draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), rock_col.lightened(0.06))
				elif n < -0.2:
					_ci.draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), rock_col.darkened(0.25))
		var open_here := _cells_in(_open, _clip)
		# Cave floor.
		# Fill variants grouped by texture (each fills only its own cell).
		var by_fill := {}
		for c: Vector2i in open_here:
			var h := absi((c.x * 73856093) ^ (c.y * 19349663) ^ floor_no)
			(by_fill.get_or_add(h % nfill if nfill > 0 else -1 - h % 4, []) as Array).append(c)
		for fi: int in by_fill:
			for c: Vector2i in by_fill[fi]:
				var drawn := false
				if nfill > 0:
					drawn = Art.draw_tile(_ci, "tiles", "mine_%s_fill_%d" % [ts, fi], Vector2(c * TILE), 0)
				elif Art.has("tiles", "mine_floor"):
					drawn = Art.draw_tile(_ci, "tiles", "mine_floor", Vector2(c * TILE), -1 - fi)
				if not drawn:
					_ci.draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color(str(theme.get("fa", "4a4152"))) if (c.x + c.y) % 2 == 0 else Color(str(theme.get("fb", "50475a"))))
		# Theme wash: the same tiles read differently every 10 floors.
		if floor_no > 10:
			var wash := Color(str(theme.get("fa", "4a4152")))
			wash.a = 0.38
			for c: Vector2i in open_here:
				_ci.draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), wash)
		# Rock faces: where the floor meets rock to the north, the wall rises above it.
		for c: Vector2i in _cells_in(_open, _face_rows()):
			var up := c + Vector2i(0, -1)
			if not _open.has(up):
				var h2 := absi((c.x * 2654435761) ^ floor_no)
				var t := Art.tex("tiles", "mine_%s_wall_%d" % [ts, h2 % maxi(1, nwall)]) if nwall > 0 else null
				if t:
					_tex_cut(t, Rect2(up.x * TILE, (up.y - 1) * TILE, TILE, TILE * 2), Rect2())
				else:
					_rect_cut(Rect2(up * TILE, Vector2i(TILE, TILE)), rock_col.lightened(0.18))
					_rect_cut(Rect2(Vector2(up.x * TILE, up.y * TILE + TILE - 3), Vector2(TILE, 3)), rock_col.lightened(0.3))
		# A soft dark lip along every floor edge so the cave reads as hollowed rock.
		for c: Vector2i in open_here:
			var r := Rect2(c * TILE, Vector2i(TILE, TILE))
			for d: Vector2i in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				if not _open.has(c + d):
					var lip := Color(0, 0, 0, 0.35)
					if d == Vector2i(0, 1):
						_ci.draw_rect(Rect2(r.position + Vector2(0, TILE - 3), Vector2(TILE, 3)), lip)
					elif d == Vector2i(-1, 0):
						_ci.draw_rect(Rect2(r.position, Vector2(3, TILE)), lip)
					else:
						_ci.draw_rect(Rect2(r.position + Vector2(TILE - 3, 0), Vector2(3, TILE)), lip)
	_rect_cut(full_px, Color(0.03, 0.02, 0.08, 0.08 + 0.02 * mini(floor_no, 10)))
	for c: Vector2i in _cells_in(_chasm, _clip):
		var o := Vector2(c * TILE)
		_ci.draw_rect(Rect2(o, Vector2(TILE, TILE)), Color(0.01, 0.0, 0.03))
		if not _chasm.has(c + Vector2i(0, -1)):
			# A dim back wall at the far lip gives the hole depth.
			var cts := _tier_set()
			if cts != "" and Art.has("tiles", "mine_%s_wall_0" % cts):
				var wt := Art.tex("tiles", "mine_%s_wall_0" % cts)
				_tex_cut(wt, Rect2(o, Vector2(TILE, TILE)), Rect2(0, wt.get_height() / 2.0, wt.get_width(), wt.get_height() / 2.0), Color(0.4, 0.36, 0.55))
				_ci.draw_rect(Rect2(o + Vector2(0, TILE - 5), Vector2(TILE, 5)), Color(0, 0, 0, 0.6))
			_ci.draw_rect(Rect2(o, Vector2(TILE, 3)), rock_col.lightened(0.2))
			_ci.draw_rect(Rect2(o + Vector2(0, 3), Vector2(TILE, 5)), Color(0.15, 0.1, 0.25, 0.5))
		if not _chasm.has(c + Vector2i(0, 1)):
			_ci.draw_rect(Rect2(o + Vector2(0, TILE - 3), Vector2(TILE, 3)), rock_col.darkened(0.3))
		if not _chasm.has(c + Vector2i(-1, 0)):
			_ci.draw_rect(Rect2(o, Vector2(3, TILE)), rock_col.darkened(0.3))
		if not _chasm.has(c + Vector2i(1, 0)):
			_ci.draw_rect(Rect2(o + Vector2(TILE - 3, 0), Vector2(3, TILE)), rock_col.darkened(0.3))
	if not _lava.is_empty() and not Art.has("tiles", "lava"):
		for c: Vector2i in _cells_in(_lava, _clip):
			_ci.draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color(0.9, 0.35, 0.1))
	_draw_bridges()


## Crossings the layout needed: plank bridges over chasms and lava, stepping
## stones through water. Boards run across the way you walk.
func _draw_bridges() -> void:
	for c: Vector2i in _cells_in(_bridge, _clip):
		var o := Vector2(c * TILE)
		var kind := str(_bridge[c])
		var across := _bridge.has(c + Vector2i(1, 0)) or _bridge.has(c + Vector2i(-1, 0)) or _is_haz(c + Vector2i(0, -1)) or _is_haz(c + Vector2i(0, 1))
		if kind == "water":
			_ci.draw_rect(Rect2(o, Vector2(TILE, TILE)), Color(0.16, 0.3, 0.42, 0.55))
			var h := absi(c.x * 31 + c.y * 17)
			for i in 2:
				var sp := o + Vector2(4 + (h >> i) % 3 + i * 7, 4 + (h >> (i + 2)) % 4 + i * 4)
				_ci.draw_circle(sp + Vector2(0, 1.5), 3.6, Color(0.05, 0.08, 0.1, 0.5))
				_ci.draw_circle(sp, 3.4, Color(0.55, 0.53, 0.5))
				_ci.draw_circle(sp + Vector2(-1, -1), 1.6, Color(0.72, 0.7, 0.66))
			continue
		var under := Color(0.02, 0.0, 0.03) if kind == "chasm" else Color(0.35, 0.08, 0.02)
		_ci.draw_rect(Rect2(o, Vector2(TILE, TILE)), under)
		var wood := Color(0.52, 0.36, 0.2)
		var dark := Color(0.28, 0.18, 0.1)
		if across:
			for i in 4:
				var x := o.x + i * 4
				_ci.draw_rect(Rect2(x, o.y + 1, 3.5, TILE - 2), wood.darkened(0.08 * (i % 2)))
				_ci.draw_rect(Rect2(x + 3, o.y + 1, 0.8, TILE - 2), dark)
			_ci.draw_rect(Rect2(o.x, o.y + 1, TILE, 1.5), dark)
			_ci.draw_rect(Rect2(o.x, o.y + TILE - 2.5, TILE, 1.5), dark)
		else:
			for i in 4:
				var y := o.y + i * 4
				_ci.draw_rect(Rect2(o.x + 1, y, TILE - 2, 3.5), wood.darkened(0.08 * (i % 2)))
				_ci.draw_rect(Rect2(o.x + 1, y + 3, TILE - 2, 0.8), dark)
			_ci.draw_rect(Rect2(o.x + 1, o.y, 1.5, TILE), dark)
			_ci.draw_rect(Rect2(o.x + TILE - 2.5, o.y, 1.5, TILE), dark)


func _draw_things() -> void:
	if not _way_open and Art.has("props", "shaft_hint_0") and not things.has(_ladder) and _clip.has_point(_ladder):
		Art.draw_prop(_ci, "props", "shaft_hint_%d" % clampi(mine_tier / 2 + (1 if mine_tier >= 3 else 0), 0, 3), cell_center(_ladder) + Vector2(0, 6))
	for k: Vector2i in _cells_in(things, _clip):
		var t: Dictionary = things[k]
		var p := cell_center(k)
		match str(t.get("type", "")):
			"rock":
				if props.has(k):
					continue
				_ci.draw_circle(p + Vector2(0, -6), 7.0, Color("7a7a86"))
			"lift":
				if not Art.draw_prop(_ci, "props", "mine_lift", p + Vector2(0, 2)) and not Art.draw_prop(_ci, "props", "cart_full", p):
					_ci.draw_rect(Rect2(p.x - 7, p.y - 12, 14, 12), Color("5a4a3a"))
			"up", "down":
				var nm := "ladder_up" if str(t["type"]) == "up" else "ladder_down"
				if Art.has("props", "ladder_a"):
					nm = "ladder_a" if str(t["type"]) == "up" else "shaft"
				if str(t["type"]) == "down" and Art.has("props", "shaft_open_0"):
					nm = "shaft_open_%d" % clampi(mine_tier / 2 + (1 if mine_tier >= 3 else 0), 0, 3)
				if not Art.draw_prop(_ci, "props", nm, p):
					_ci.draw_rect(Rect2(p.x - 6, p.y - 14, 12, 14), Color("1a1620"))


## The cells of `cells` inside r. A big r keeps dictionary order, so the legacy
## path draws in exactly the old order.
func _cells_in(cells: Dictionary, r: Rect2i) -> Array:
	var out: Array = []
	if r.get_area() >= cells.size():
		for c: Vector2i in cells:
			if r.has_point(c):
				out.append(c)
	else:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if cells.has(c):
					out.append(c)
	return out


## Wall faces hang up to 2 cells above their floor cell: a chunk also looks at
## the 2 rows below it for faces that reach into it.
func _face_rows() -> Rect2i:
	return Rect2i(_clip.position, _clip.size + Vector2i(0, 2))


## A rect cut to the cells being drawn.
func _rect_cut(r: Rect2, col: Color) -> void:
	var d := r.intersection(_clip_px)
	if d.has_area():
		_ci.draw_rect(d, col)


## A texture (src = Rect2() for the whole texture) cut to the cells being drawn,
## so a face that crosses a chunk edge is drawn half by each chunk and joins.
func _tex_cut(t: Texture2D, dst: Rect2, src: Rect2, col := Color.WHITE) -> void:
	var d := dst.intersection(_clip_px)
	if not d.has_area():
		return
	if d == dst:
		if src.has_area():
			_ci.draw_texture_rect_region(t, dst, src, col)
		else:
			_ci.draw_texture_rect(t, dst, false, col)
		return
	if not src.has_area():
		src = Rect2(Vector2.ZERO, t.get_size())
	var k := src.size / dst.size
	_ci.draw_texture_rect_region(t, d, Rect2(src.position + (d.position - dst.position) * k, d.size * k), col)


## Builds the chunk nodes once (from after_ready, once props are placed).
func _make_chunks() -> void:
	var root := Node2D.new()
	root.name = "MineFloor"
	add_child(root)
	move_child(root, 0)  # first child at y = 0: draws where the map's own _draw did
	var full := Rect2i(-pad, -pad, cols + 2 * pad, rows + 2 * pad)
	var tops: Array = []
	for cy in range(-pad, rows + pad, CHUNK):
		for cx in range(-pad, cols + pad, CHUNK):
			var r := Rect2i(cx, cy, CHUNK, CHUNK).intersection(full)
			var pair: Array = []
			for layer in [0, 1]:
				var ch := MineChunk.new()
				ch.map = self
				ch.cells = r
				ch.layer = layer
				pair.append(ch)
			root.add_child(pair[0])
			tops.append(pair[1])
			_chunks[Vector2i(cx, cy)] = pair
	for t in tops:
		root.add_child(t)  # every ground chunk first, then every top chunk
	_build_layers()


func _chunk_key(c: Vector2i) -> Vector2i:
	return Vector2i(floori(float(c.x + pad) / CHUNK) * CHUNK - pad, floori(float(c.y + pad) / CHUNK) * CHUNK - pad)


## Redraw every chunk that owns a cell in r: the things layer, and the ground
## too only when the floor itself changed (rock breaks only touch things).
func redraw_cells(r: Rect2i, ground := false) -> void:
	if not CHUNKED or _chunks.is_empty():
		queue_redraw()
		return
	var k0 := _chunk_key(r.position)
	var k1 := _chunk_key(r.end - Vector2i.ONE)
	for ky in range(k0.y, k1.y + 1, CHUNK):
		for kx in range(k0.x, k1.x + 1, CHUNK):
			if not _chunks.has(Vector2i(kx, ky)):
				continue
			var pair: Array = _chunks[Vector2i(kx, ky)]
			for li in (2 if ground else 1):
				(pair[1 - li] as CanvasItem).queue_redraw()


func redraw_cell(c: Vector2i) -> void:
	redraw_cells(Rect2i(c, Vector2i.ONE))


func redraw_all() -> void:
	if not CHUNKED or _chunks.is_empty():
		queue_redraw()
		return
	for pair in _chunks.values():
		for ch in pair:
			(ch as CanvasItem).queue_redraw()


## Guests: the host changed the world.
func on_world_sync(d: Dictionary) -> void:
	if CHUNKED:
		redraw_all()
	else:
		super(d)


func _place_props() -> void:
	var ts := _tier_set()
	var rs := "deep" if ts == "crystal" and Art.has("props", "mine_deep_rock_0") else ts  # the grotto's plain stone is grey (a modulate can't take the purple out)
	if ts != "":
		var nrock := 0
		while Art.has("props", "mine_%s_rock_%d" % [rs, nrock]):
			nrock += 1
		# Mineable stones: only art 24-49 px wide (the small ones read as floor pebbles).
		var rock_ok: Array = []
		for ri in nrock:
			var rt := Art.tex("props", "mine_%s_rock_%d" % [rs, ri])
			if rt and rt.get_width() >= 24 and rt.get_width() < 50 and not (rs == "deep" and ri == 0):  # deep_rock_0 has gold flecks: it read as gold ore
				rock_ok.append(ri)
		if rock_ok.is_empty():
			rock_ok = range(maxi(1, mini(nrock, 5)))
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
			elif ore != "stone" and Art.has("props", str(NODE_ALIAS.get(ore, ""))):
				nm = str(NODE_ALIAS[ore])
			elif nrock > 0:
				nm = "mine_%s_rock_%d" % [rs, int(rock_ok[absi(k.x * 7 + k.y * 13) % rock_ok.size()])]
			if nm != "":
				var sp := prop("props", nm, k)
				# Tier stone art runs 19-44 px: small ones looked like floor pebbles.
				if sp and sp.texture and ore == "stone":
					sp.scale = Vector2.ONE * clampf(22.0 / sp.texture.get_width(), 0.5, 1.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed ^ 0x4100
		var ndec := 0
		while Art.has("props", "mine_%s_decal_%d" % [ts, ndec]):
			ndec += 1
		var okeys: Array = _open.keys()
		for i in maxi(8, _open.size() / 45):
			var c: Vector2i = okeys[rng.randi() % okeys.size()]
			if not things.has(c) and not blocked.has(c) and ndec > 0:
				var sp := prop("props", "mine_%s_decal_%d" % [ts, rng.randi_range(0, ndec - 1)], c, 0, 0.0, false)
				if sp:
					to_under(sp)
		# Lamps on open floor (the old spots at row 1 sat in the rock rim, never seen).
		if Art.has("props", "mine_%s_lamp_0" % ts):
			var spots: Array = [_entry + Vector2i(3, 1), _ladder + Vector2i(-3, 0)]
			for li in maxi(2, _open.size() / 700):
				spots.append(okeys[rng.randi() % okeys.size()])
			for li in spots.size():
				var c := _roomy_open(spots[li])
				if not things.has(c) and not blocked.has(c):
					prop("props", "mine_%s_lamp_%d" % [ts, li % 2], c)
					blocked[c] = true
		elif Art.has("props", "cave_lamp"):
			# Deep and crystal sets have no lamp art of their own: a lantern post.
			for li in 2 + _open.size() / 1500:
				var c := _roomy_open(_entry + Vector2i(3, 1) if li == 0 else okeys[rng.randi() % okeys.size()])
				if not things.has(c) and not blocked.has(c) and (li == 0 or c.distance_to(_entry) >= 12):
					prop("props", "cave_lamp", c, 0, 0.0, true, 0.35)
					blocked[c] = true
		for i in maxi(2, _open.size() / 400):
			var c := _roomy_open(okeys[rng.randi() % okeys.size()])
			if not things.has(c) and not blocked.has(c) and Art.has("props", "mine_%s_stalag_0" % ts):
				var stp := prop("props", "mine_%s_stalag_%d" % [ts, i % 2], c)
				if stp and stp.texture:
					stp.scale = Vector2.ONE * clampf(30.0 / stp.texture.get_height(), 0.5, 1.0)
				blocked[c] = true
		if floor_no % 2 == 0 and Art.has("props", "mine_%s_cart" % ts):
			var cc := _roomy_open(Vector2i(2, rows - 3))
			prop("props", "mine_%s_cart" % ts, cc)
			blocked[cc] = true
		if floor_no % 5 == 0:
			var sc := _roomy_open(Vector2i(cols - 3, 2))
			prop("props", "cave_pick_rock" if Art.has("props", "cave_pick_rock") else "cave_ore_crate", sc, 0, 0.0, true, 0.3)
			blocked[sc] = true
			set_thing(sc.x, sc.y, {"type": "skeleton", "hint": "A: an old miner's pack"})
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
			var nm: String = {"stone": "mrock_a" if (k.x + k.y) % 3 != 0 else "mrock_b", "copper": "ore_copper", "iron": "ore_iron", "shard": "ore_crystal", "gold": "ore_gold", "dark": "ore_dark", "coal": "ore_iron"}.get(ore, "mrock_a")
			if deep:
				nm = {"stone": "mrock_%s_%d" % [v, (k.x + k.y) % 2], "copper": "node_copper", "iron": "node_iron", "shard": "node_crystal", "gold": "node_gold", "dark": "node_dark"}.get(ore, nm)
				if ore != "stone" and Art.has("props", "node_" + ore):
					nm = "node_" + ore
				elif ore != "stone" and Art.has("props", str(NODE_ALIAS.get(ore, ""))):
					nm = str(NODE_ALIAS[ore])
			prop("props", nm, k)
		if deep:
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = _seed ^ 0x4000
			var okeys2: Array = _open.keys()
			for i in maxi(3, _open.size() / 400):
				var c := _roomy_open(okeys2[rng2.randi() % okeys2.size()])
				if not things.has(c) and not blocked.has(c):
					var sgn := "stalagmite_a" if v == "earth" or not Art.has("props", "cave_stalag_s") else "cave_stalag_s"
					prop("props", sgn, c, 0, 0.0, true, 1.0 if sgn == "stalagmite_a" else 0.45)
					blocked[c] = true
			# Lamp and beam on open floor (row 1 is the rock rim; ceiling stalactites were never seen).
			var bl := _roomy_open(_entry + Vector2i(4, 1))
			if not things.has(bl):
				prop("props", "beam_lamp", bl, 1)
			if Art.has("props", "cave_lamp"):
				for li in range(1, 2 + _open.size() / 1500):
					var lc := _roomy_open(okeys2[rng2.randi() % okeys2.size()])
					if not things.has(lc) and not blocked.has(lc) and lc.distance_to(_entry) >= 12:  # the beam lamp already lights the entry
						prop("props", "cave_lamp", lc, 0, 0.0, true, 0.35)
						blocked[lc] = true
			if floor_no % 2 == 0:
				var cc := _roomy_open(Vector2i(2, rows - 3))
				prop("props", "cart_full", cc)
				blocked[cc] = true
			if floor_no % 5 == 0:
				var sc := _roomy_open(Vector2i(cols - 3, 2))
				prop("props", "cave_pick_rock" if Art.has("props", "cave_pick_rock") else "cave_ore_crate", sc, 0, 0.0, true, 0.3)
				blocked[sc] = true
				set_thing(sc.x, sc.y, {"type": "skeleton", "hint": "A: an old miner's pack"})
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed ^ 0x3000
		for i in 4:
			var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(2, rows - 3))
			if not things.has(c) and not blocked.has(c):
				pass  # pickable mushrooms are placed as findables now
		if floor_no % 3 == 0:
			var bm := _roomy_open(_ladder + Vector2i(-4, 0))
			if not things.has(bm):
				prop("props", "beam", bm, 1)
		return
	if not Art.has("nature", "rock_m"):
		return
	for k in things:
		var t: Dictionary = things[k]
		if str(t.get("type", "")) != "rock":
			continue
		prop("nature", "rock_m", k)


## The visit's dressing (MineLayouts.DRESSINGS): what the floor is decorated
## with, on top of the cave look. Solid pieces only go where floor is open all
## round, never near the ladders.
func _dress_floor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed ^ 0xd5d5
	var cells: Array = _reach.keys().filter(func(q: Vector2i) -> bool: return not blocked.has(q) and not things.has(q) and not props.has(q) and not _bridge.has(q) and q.distance_to(_entry) >= 4 and q.distance_to(_ladder) >= 3)
	if cells.is_empty():
		return
	var n := clampi(cells.size() / 140, 6, 36)
	var put := func(group: String, nm: String, solid: bool, sc: float, glow_r: float) -> void:
		if not Art.has(group, nm):
			return
		var c: Vector2i = cells[rng.randi() % cells.size()]
		if solid:
			c = _roomy_open(c)
		if things.has(c) or props.has(c) or blocked.has(c) or _bridge.has(c) or c.distance_to(_entry) < 4 or c.distance_to(_ladder) < 3:
			return
		var sp := prop(group, nm, c, 0, 0.0, solid, sc)
		if sp == null:
			return
		if not solid:
			props.erase(c)   # decoration: the cell stays free for rocks/findables bookkeeping
		if glow_r > 0.0 and glow:
			glow.lights.append([sp, glow_r, 8.0])
	match _dress:
		"mossy":
			for i in n * 2:
				put.call("props", "ri_mossy_%d" % rng.randi_range(0, 15), false, 0.42, 0.0)
			for i in n:
				put.call("props", "cave_moss", false, 0.5, 0.0)
		"glowshroom":
			for i in maxi(3, n / 2):
				put.call("props", "mushroom_tree_a" if rng.randf() < 0.6 else "mushroom_tree_b", true, 0.42, 40.0)
			for i in n:
				put.call("props", ["gmush_blue", "gmush_purple", "gmush_red"][rng.randi() % 3], false, 0.32, 18.0)
		"crystal":
			for i in n:
				put.call("props", "ri_crystal_" + ["blue", "green", "pink", "purple", "yellow"][rng.randi() % 5], false, 0.45, 20.0)
			for i in maxi(2, n / 3):
				put.call("props", "ccrystal_%d" % rng.randi_range(2, 4), true, 0.4, 30.0)
		"old_works":
			_lay_rails(rng)
			for i in maxi(2, n / 3):
				put.call("props", ["beam_b", "beam_c", "beam_d"][rng.randi() % 3], true, 0.5, 26.0)
			for i in maxi(1, n / 6):
				put.call("props", "abandoned_cart", true, 0.45, 0.0)
		"rockfall":
			for i in maxi(2, n / 3):
				put.call("props", "rockslide", true, 0.42, 0.0)
			for i in n:
				put.call("props", "ri_wet_rock_%d" % rng.randi_range(0, 1), false, 0.38, 0.0)
		"dripstone":
			var before := props.size()
			for i in maxi(3, n / 2):
				put.call("props", ["cave_stalag_s", "cave_stalag_m"][rng.randi() % 2], true, 0.4, 0.0)
			# The dripstone art is icy blue: warm it to the cave's own stone outside ice/crystal caves.
			if str(theme.get("cave", "")) in ["earth", "stone"] and props.size() > before:
				for c in props:
					var sp2 := props[c] as Sprite2D
					if sp2 and sp2.texture and "cave_stalag_" in sp2.texture.resource_path:
						sp2.modulate = Color(0.85, 0.7, 0.58) if str(theme.get("cave", "")) == "earth" else Color(0.7, 0.68, 0.75)
			# Stalactites hang from the rock face above a floor cell.
			var hang := cells.filter(func(q: Vector2i) -> bool: return not _open.has(q + Vector2i(0, -1)))
			for i in mini(n, hang.size()):
				var c: Vector2i = hang[rng.randi() % hang.size()]
				if Art.has("props", "cave_stalactite_b") and not props.has(c):
					var sp := prop("props", "cave_stalactite_b" if rng.randf() < 0.6 else "cave_stalactite_a", c, 0, -10.0, false, 0.3)
					if sp:
						props.erase(c)
		_:
			for i in maxi(2, n / 4):
				put.call("props", "ri_wet_rock_%d" % rng.randi_range(0, 1), false, 0.38, 0.0)


## Old mine-cart rails along a long straight run of open floor.
func _lay_rails(rng: RandomNumberGenerator) -> void:
	if not Art.has("props", "rail_h") or not Art.has("props", "rail_v"):
		return
	var keys: Array = _reach.keys()
	for tries in 40:
		var c: Vector2i = keys[rng.randi() % keys.size()]
		var horiz := rng.randf() < 0.6
		var d := Vector2i(1, 0) if horiz else Vector2i(0, 1)
		var run: Array = []
		var q := c
		while _open.has(q) and not blocked.has(q) and not things.has(q) and not _bridge.has(q) and q.distance_to(_entry) >= 3 and q.distance_to(_ladder) >= 3 and run.size() < 18:
			run.append(q)
			q += d
		if run.size() >= 7:
			for r: Vector2i in run:
				var sp := prop("props", "rail_h" if horiz else "rail_v", r, 0, 0.0, false, 0.5)
				if sp:
					props.erase(r)
					to_under(sp)
			return


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
					prop("props", nm, c, 0, 0.0, false, 0.3 if nm.begins_with("cave_mush_") else 0.5)
				elif Art.has("items", str(t["item"])):
					var sp := Art.sprite("items", str(t["item"]))
					if sp:
						sp.position = cell_center(c) + Vector2(0, -4)
						sp.scale = Vector2(0.4, 0.4)
						add_child(sp)
						props[c] = sp
			"crate":
				var cnm := "cave_ore_crate" if str(t.get("kind", "")) == "crates_a" and Art.has("props", "cave_ore_crate") else str(t.get("kind", "crates_a"))
				prop("props", cnm, c, 0, 0.0, true, 0.32 if cnm == "cave_ore_crate" else 0.65)
			"mchest", "bigchest":
				var sp2 := prop("props", "chest_closed", c)
				if sp2 and str(t["type"]) == "bigchest":
					sp2.modulate = Color(1.25, 1.1, 0.7)
	# Theme tint on rocks and props so every 10 floors looks different even
	# before each theme has its own art.
	for c in props:
		var n: Node = props[c]
		if n is CanvasItem and str(things.get(c, {}).get("type", "")) == "rock" and str(things[c].get("ore", "stone")) == "stone":
			(n as CanvasItem).modulate = Color(1, 1, 1) if _tier_set() == "crystal" else Color(float(tint[0]), float(tint[1]), float(tint[2]))
		elif n is CanvasItem and str(things.get(c, {}).get("ore", "")) == "amethyst":
			(n as CanvasItem).modulate = Color(1.15, 0.7, 1.3)  # amethyst reads purple; the grotto's stone goes grey
		elif n is CanvasItem and str(things.get(c, {}).get("ore", "")) == "copper" and n is Sprite2D and (n as Sprite2D).texture and "node_copper" in (n as Sprite2D).texture.resource_path:
			(n as CanvasItem).modulate = Color(1.15, 0.82, 0.55)  # node_copper art is pink like ruby: warm it to copper


func _process(delta: float) -> void:
	super(delta)
	if player and not get_tree().paused:
		_secs_live += delta
		_bank_t += delta
		if _bank_t >= 5.0:
			_bank_t = 0.0
			_bank_secs()
			if _keeper_due():
				_summoning = true
				call_deferred("_summon_guardian")
		_descend_tick(delta)
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
					if things.has(cc) and str(things[cc].get("type", "")) == "rock":  # crates keep their loot
						things.erase(cc)
						blocked.erase(cc)
						hard.erase(cc)
						if props.has(cc):
							(props[cc] as Node).queue_free()
							props.erase(cc)
						else:
							_slam_redraw = true
						broke += 1
			if broke > 0:
				shake(2.5)
				fx("boss_shockwave" if Art.has("fx", "boss_shockwave") else "poof", _guardian.position, 12.0, 0.5)
				if _slam_redraw:
					_slam_redraw = false
					redraw_cells(Rect2i(gc - Vector2i(2, 2), Vector2i(5, 5)))


var _bank_t := 0.0

# ------------------------------------------------------------ going down
## Tom: after the keeper you had to stand in exactly the right spot to USE the
## shaft. Now: a glowing marker over it; stepping onto the shaft takes you down;
## USE anywhere next to it (diagonals too, whatever you're holding) takes you
## down; tapping the shaft or the big "Climb down" button takes you down.
const DOWN_RECT := Rect2(70, 316, 130, 30)
var _down_layer: CanvasLayer = null
var _down_btn: Button = null
var _marker: Node2D = null
var _marker_t := 0.0
var _last_cell := Vector2i(-99, -99)
var _descending := false


func _make_down_ui() -> void:
	_marker = Node2D.new()
	_marker.name = "ShaftMarker"
	_marker.position = cell_center(_ladder)
	_marker.z_index = 3
	_marker.draw.connect(_draw_marker)
	_marker.visible = _way_open
	add_child(_marker)
	if glow:
		glow.lights.append([_marker, 46.0, 6.0])
	_down_layer = CanvasLayer.new()
	_down_layer.layer = 6
	add_child(_down_layer)
	_down_btn = Button.new()
	_down_btn.position = DOWN_RECT.position
	_down_btn.size = DOWN_RECT.size
	_down_btn.focus_mode = Control.FOCUS_NONE
	_down_btn.add_theme_font_size_override("font_size", 10)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.1, 0.05, 0.88)
	sb.border_color = Color(1.0, 0.82, 0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	_down_btn.add_theme_stylebox_override("normal", sb)
	var sb2 := sb.duplicate() as StyleBoxFlat
	sb2.bg_color = Color(0.3, 0.2, 0.08, 0.95)
	_down_btn.add_theme_stylebox_override("hover", sb2)
	_down_btn.add_theme_stylebox_override("pressed", sb2)
	_down_btn.add_theme_color_override("font_color", Color(1.0, 0.93, 0.7))
	_down_btn.text = _down_label()
	_down_btn.visible = false
	_down_btn.pressed.connect(_descend)
	_down_layer.add_child(_down_btn)


func _down_label() -> String:
	if floor_no >= MAX_FLOOR:
		return "▼ Down to the Hollow Heart"
	return "▼ Climb down to floor %d" % (floor_no + 1)


func _exit_tree() -> void:
	_bank_secs()
	Hud.extra_rects.erase(DOWN_RECT)


func _near_shaft(r := 1.6) -> bool:
	return _way_open and player != null and things.has(_ladder) and player.position.distance_to(cell_center(_ladder)) <= r * TILE


func _descend_tick(delta: float) -> void:
	if _marker:
		_marker.visible = _way_open
		if _way_open:
			_marker_t += delta
			_marker.queue_redraw()
	var show := _way_open and not _descending and player != null and player.position.distance_to(cell_center(_ladder)) <= 7.0 * TILE and not player.frozen
	if _down_btn and _down_btn.visible != show:
		_down_btn.visible = show
		if show:
			if not Hud.extra_rects.has(DOWN_RECT):
				Hud.extra_rects.append(DOWN_RECT)
		else:
			Hud.extra_rects.erase(DOWN_RECT)
	if not _way_open or _descending or player == null or player.frozen or _changing:
		return
	var pc := world_to_cell(player.position)
	# Walked onto the shaft (only on arriving at the cell, so a refusal doesn't repeat).
	if pc == _ladder and _last_cell != _ladder:
		_last_cell = pc
		_descend()
		return
	_last_cell = pc
	if _near_shaft() and Input.is_action_just_pressed("a") and not Dialogue.input_blocked() and not Dialogue.instance(get_tree()).active:
		_descend()


func _descend() -> void:
	if _descending or not _way_open or not things.has(_ladder):
		return
	if _grotto and not GameState.run["flags"].has("grotto_done"):
		interact(_ladder, things[_ladder])   # says why not
		return
	_descending = true
	if _down_btn:
		_down_btn.visible = false
	Hud.extra_rects.erase(DOWN_RECT)
	player.frozen = true
	fx("sparkle", cell_center(_ladder) + Vector2(0, -8), 12.0, 0.6)
	interact(_ladder, things[_ladder])


## USE next to the shaft goes down, whatever you hold (the sword used to swing instead).
func try_interact(c: Vector2i, check := false) -> bool:
	if _near_shaft() and (c == _ladder or c.distance_to(_ladder) <= 1.5):
		_descend()
		return true
	return super(c, check)


func action_word(c: Vector2i) -> String:
	if _near_shaft():
		return "Down"
	return super(c)


## Tapping the shaft (a generous 2-cell target) goes down once you're close.
func handle_tap(pos: Vector2) -> void:
	if _way_open and player and not player.frozen and not get_tree().paused:
		var world := get_canvas_transform().affine_inverse() * pos
		if world.distance_to(cell_center(_ladder) + Vector2(0, -6)) <= 2.0 * TILE and player.position.distance_to(cell_center(_ladder)) <= 7.0 * TILE:
			_descend()
			return
	super(pos)


## A pulsing ring of light round the shaft and a bobbing arrow over it.
func _draw_marker() -> void:
	var t := _marker_t
	var pulse := 0.5 + 0.5 * sin(t * 4.0)
	for i in 3:
		var k := fmod(t * 0.8 + i / 3.0, 1.0)
		_marker.draw_arc(Vector2(0, -2), 10.0 + k * 16.0, 0, TAU, 32, Color(1.0, 0.85, 0.4, (1.0 - k) * 0.55), 2.0)
	_marker.draw_circle(Vector2(0, -2), 9.0, Color(1.0, 0.8, 0.35, 0.12 + 0.1 * pulse))
	var y := -34.0 - 4.0 * sin(t * 5.0)
	var col := Color(1.0, 0.9, 0.45, 0.95)
	var pts := PackedVector2Array([Vector2(-7, y), Vector2(7, y), Vector2(0, y + 9)])
	_marker.draw_colored_polygon(PackedVector2Array([Vector2(-8, y - 1), Vector2(8, y - 1), Vector2(0, y + 10)]), Color(0.15, 0.08, 0.02, 0.9))
	_marker.draw_colored_polygon(pts, col)
	_marker.draw_rect(Rect2(-3, y - 7, 6, 7), Color(0.15, 0.08, 0.02, 0.9))
	_marker.draw_rect(Rect2(-2, y - 6, 4, 6), col)


## The HUD points here: the awake keeper first, then the open way down.
func pointer_target() -> Vector2:
	if _guardian != null and is_instance_valid(_guardian) and _guardian._alive:
		return _guardian.position
	if _way_open:
		return cell_center(_ladder)
	return Vector2.ZERO


func _deepest() -> int:
	return int(GameState.run["flags"].get("mine_deepest", 1))


## Within a 25-floor tier, every floor deeper hits harder and lasts longer.
func _depth_scale(e: Enemy) -> void:
	if e == null:
		return
	var into := (floor_no - 1) % 25
	# Each tier starts about where the last one ended (no easier floor after a boundary).
	var m := 1.0 + 0.045 * into + 0.35 * mine_tier
	if floor_no <= 4 and not e.is_guardian:
		m *= 0.6 + 0.1 * floor_no   # floors 1-4 ease in: 70%, 80%, 90%, 100%
	e.max_hp = maxi(1, int(round(e.max_hp * m)))
	e.hp = e.max_hp
	e.damage = e.damage + mini(1, into / 12)  # no 3x drop at the tier boundary
	if floor_no <= 2 and not e.is_guardian:
		e.damage = maxi(1, e.damage - 1)


func on_enemy_died(e: Enemy) -> void:
	super(e)
	if e.has_meta("minion"):
		return  # summoned helpers don't count toward the guardian
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
	elif player and _walk_dist(world_to_cell(player.position), _ladder, 24) < 0:  # by walking, not as the crow flies (a wall between)
		# Don't make the player cross the whole cave: it surfaces a few cells away.
		var pc := world_to_cell(player.position)
		var aim := pc + Vector2i(randi_range(-6, 6), randi_range(-6, 6))
		var bd := 1e9
		for q: Vector2i in _reach:
			var dd := float((q - aim).length_squared())
			if dd < bd and not things.has(q) and not blocked.has(q) and q.distance_to(pc) >= 4.0:
				bd = dd
				at = cell_center(q)
	shake(3.0)
	fx("keeper_wake" if Art.has("fx", "keeper_wake") else "boss_shockwave", at, 12.0, 0.8)
	await get_tree().create_timer(0.9 if Art.has("fx", "keeper_wake") else 0.4, false).timeout
	if not is_inside_tree():
		return
	# Never weaker than its native tier; floor 1's golem is still a golem.
	# The first floors' keeper meets you at the floor's own tier; deeper ones never go below their home tier.
	_guardian = spawn_enemy(kind, at, mine_tier)
	_guardian.is_guardian = true
	_depth_scale(_guardian)
	_guardian.set_meta("boss_name", "Keeper of floor %d" % floor_no)
	var into := mini(5, ((floor_no - 1) % 25) / 5)
	_guardian.max_hp = int(_guardian.max_hp * minf(2.0, 1.3 + 0.08 * into))
	if floor_no <= 4:
		# Tom: once it's up, the first keeper should be a fight: tougher, quicker
		# on its feet (it was easy to kite), and it lunges as well as stomps.
		_guardian.max_hp = int(_guardian.max_hp * 1.45)
		_guardian.speed = maxf(_guardian.speed, 27.0)
		if not _guardian.abilities.has("lunge"):
			_guardian.abilities.append("lunge")
		if not _guardian.abilities.has("stomp"):
			_guardian.abilities.append("stomp")
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
	Music.instance(get_tree()).sfx("alert", "thud")


func _open_way() -> void:
	GameState.run["flags"]["mine_open_%d" % floor_no] = true
	_way_open = true
	things[_ladder] = {"type": "down", "hint": ("A: the long lift down to the Hollow Heart" if floor_no >= MAX_FLOOR else "Step in or tap USE: climb down to floor %d" % (floor_no + 1))}
	blocked.erase(_ladder)
	hard.erase(_ladder)
	if props.has(_ladder):
		(props[_ladder] as Node).queue_free()
		props.erase(_ladder)
	shake(4.0)
	fx("rock_m_break", cell_center(_ladder), 14.0, 0.8)
	redraw_cell(_ladder)
	hud.toast("The rock splits. A shaft leads down! Step onto it to climb down.", Color(0.8, 1.0, 0.8))
	if _marker:
		_marker.visible = true
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
		Music.instance(get_tree()).sfx("quest_done", "levelup")
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

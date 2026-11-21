extends RefCounted
## Mine floor layouts: a catalogue of cave shapes, each a generator with its own
## random parameters, plus "dressings" (what the floor is decorated with).
## Mine.build() picks a style fresh on every visit (seeded by visit count, floor
## and the clock), so floor 1 is rarely the same twice. Everything here is
## static and works on a PackedByteArray grid (1 = open floor) for speed.
##   var lay := MineLayouts.carve("ring_rooms", cols, rows, rng, floor_no, lava_ok)
##   lay = {"open": {Vector2i: true}, "water": {...}, "chasm": {...}, "lava": {...}}
## Hazard cells are a subset of open; Mine joins cut-off pockets with bridges.

## id, display name, first floor it can show up on, weight, size multiplier,
## rock multiplier, preferred dressing ("" = any), hazards it brings.
const STYLES := [
	{"id": "caverns", "name": "Caverns", "min": 1, "w": 1.0, "size": 1.0, "rocks": 1.0, "dress": ""},
	{"id": "winding_tunnels", "name": "Winding Tunnels", "min": 1, "w": 1.0, "size": 0.95, "rocks": 0.9, "dress": ""},
	{"id": "pillar_hall", "name": "Pillar Hall", "min": 1, "w": 0.9, "size": 0.9, "rocks": 1.1, "dress": "old_works"},
	{"id": "island_lake", "name": "Island Lake", "min": 1, "w": 0.8, "size": 1.05, "rocks": 0.9, "dress": "mossy", "haz": "water"},
	{"id": "chasm_bridges", "name": "Chasm Bridges", "min": 3, "w": 0.8, "size": 1.0, "rocks": 1.0, "dress": "", "haz": "chasm"},
	{"id": "ring_rooms", "name": "Ring of Rooms", "min": 1, "w": 1.0, "size": 1.0, "rocks": 1.0, "dress": ""},
	{"id": "mushroom_grove", "name": "Mushroom Grove", "min": 1, "w": 0.9, "size": 0.95, "rocks": 0.85, "dress": "glowshroom"},
	{"id": "crystal_grotto", "name": "Crystal Grotto", "min": 2, "w": 0.8, "size": 0.95, "rocks": 1.0, "dress": "crystal", "haz": "water"},
	{"id": "rubble_field", "name": "Rubble Field", "min": 1, "w": 0.8, "size": 0.85, "rocks": 2.2, "dress": "rockfall"},
	{"id": "narrow_maze", "name": "Narrow Maze", "min": 2, "w": 0.7, "size": 0.85, "rocks": 0.6, "dress": "old_works"},
	{"id": "open_quarry", "name": "Open Quarry", "min": 1, "w": 0.8, "size": 0.95, "rocks": 1.6, "dress": "old_works"},
	{"id": "flooded_hall", "name": "Flooded Hall", "min": 2, "w": 0.7, "size": 1.0, "rocks": 0.9, "dress": "mossy", "haz": "water"},
	{"id": "rooms_corridors", "name": "Old Workings", "min": 1, "w": 1.0, "size": 1.0, "rocks": 1.0, "dress": "old_works"},
	{"id": "spiral", "name": "Spiral Descent", "min": 3, "w": 0.5, "size": 0.9, "rocks": 0.9, "dress": "dripstone"},
	{"id": "river_cave", "name": "Underground River", "min": 2, "w": 0.8, "size": 1.05, "rocks": 1.0, "dress": "mossy", "haz": "water"},
	{"id": "honeycomb", "name": "Honeycomb", "min": 1, "w": 0.9, "size": 0.95, "rocks": 1.0, "dress": ""},
	{"id": "canyon", "name": "Canyons", "min": 1, "w": 0.9, "size": 1.0, "rocks": 1.0, "dress": "rockfall"},
	{"id": "twin_caverns", "name": "Twin Caverns", "min": 1, "w": 0.9, "size": 1.05, "rocks": 1.0, "dress": ""},
	{"id": "sinkholes", "name": "Sinkholes", "min": 6, "w": 0.6, "size": 1.0, "rocks": 1.0, "dress": "dripstone", "haz": "chasm"},
	{"id": "fissures", "name": "Fissures", "min": 8, "w": 0.6, "size": 1.0, "rocks": 1.0, "dress": "", "haz": "crack"},
	{"id": "stalagmite_forest", "name": "Stalagmite Forest", "min": 1, "w": 0.9, "size": 0.95, "rocks": 0.8, "dress": "dripstone"},
	{"id": "cross_halls", "name": "Crossroads", "min": 1, "w": 0.7, "size": 0.95, "rocks": 1.0, "dress": "old_works"},
	{"id": "ledges", "name": "Ledges", "min": 2, "w": 0.7, "size": 1.0, "rocks": 1.0, "dress": "rockfall"},
	{"id": "archipelago", "name": "Archipelago", "min": 6, "w": 0.5, "size": 1.1, "rocks": 0.8, "dress": "mossy", "haz": "water"},
	{"id": "grand_cavern", "name": "Grand Cavern", "min": 1, "w": 0.8, "size": 1.1, "rocks": 1.1, "dress": ""},
	{"id": "geode", "name": "Geode Chambers", "min": 4, "w": 0.6, "size": 0.95, "rocks": 1.0, "dress": "crystal"},
]

## Floor decoration sets (Mine._dress_floor places the props).
const DRESSINGS := ["plain", "mossy", "glowshroom", "crystal", "old_works", "rockfall", "dripstone"]


static func style(id: String) -> Dictionary:
	for s: Dictionary in STYLES:
		if str(s["id"]) == id:
			return s
	return STYLES[0]


## A style for this floor: weighted, never one of the last few you saw.
static func pick(floor_no: int, rng: RandomNumberGenerator, recent: Array) -> Dictionary:
	var pool: Array = []
	var total := 0.0
	for s: Dictionary in STYLES:
		if floor_no < int(s["min"]) or recent.has(str(s["id"])):
			continue
		var w := float(s["w"])
		if floor_no <= 3 and s.has("haz"):
			w *= 0.6   # gentle first floors: fewer hazard layouts
		pool.append([s, w])
		total += w
	if pool.is_empty():
		return STYLES[0]
	var r := rng.randf() * total
	for p: Array in pool:
		r -= float(p[1])
		if r <= 0.0:
			return p[0]
	return pool[-1][0]


## The depth theme's own dressing (c14_12-14): no old workings at the Heart's Edge, no
## rails and street lamps in the Crystal Veins. Theme first (65%), then the style's.
const THEME_DRESS := {"Mossy Hollows": "mossy", "Flooded Galleries": "mossy", "Fungal Caverns": "glowshroom",
	"Crystal Veins": "crystal", "Amethyst Grotto": "crystal", "The Heart's Edge": "crystal", "The Void Reach": "crystal",
	"Frost Caves": "dripstone", "Drowned Dark": "dripstone", "Gold Seams": "old_works", "Sandstone Ruins": "old_works",
	"Magma Rifts": "rockfall", "Obsidian Halls": "rockfall", "Grey Stone Deeps": "rockfall"}
## Dressings that never fit a theme (old timber and lamps in crystal/void/heart caves...).
const THEME_NEVER := {"crystal": ["old_works"], "glowshroom": ["old_works", "crystal"], "mossy": ["crystal"], "dripstone": ["old_works", "glowshroom"], "rockfall": ["mossy", "glowshroom"]}


static func pick_dress(st: Dictionary, rng: RandomNumberGenerator, theme_name := "") -> String:
	var tpref := str(THEME_DRESS.get(theme_name, ""))
	if tpref != "" and rng.randf() < 0.65:
		return tpref
	var never: Array = THEME_NEVER.get(tpref, [])
	var pref := str(st.get("dress", ""))
	if pref != "" and pref not in never and rng.randf() < 0.7:
		return pref
	var pool := DRESSINGS.filter(func(d): return d not in never)
	return str(pool[rng.randi() % pool.size()])


# ------------------------------------------------------------------ carving

## Carve `id` into a cols x rows grid. lava_ok: cracks become lava (else chasms).
static func carve(id: String, cols: int, rows: int, rng: RandomNumberGenerator, floor_no: int, lava_ok := false) -> Dictionary:
	var g := PackedByteArray()
	g.resize(cols * rows)
	var h := PackedByteArray()   # 0 none, 1 water, 2 chasm, 3 lava
	h.resize(cols * rows)
	var gentle := floor_no <= 3
	match id:
		"winding_tunnels": _winding(g, cols, rows, rng)
		"pillar_hall": _pillar_hall(g, cols, rows, rng)
		"island_lake": _island_lake(g, h, cols, rows, rng, gentle)
		"chasm_bridges": _chasm_bridges(g, h, cols, rows, rng)
		"ring_rooms": _ring_rooms(g, cols, rows, rng)
		"mushroom_grove": _glades(g, cols, rows, rng, rng.randi_range(10, 14), 4.5, 8.0)
		"crystal_grotto": _crystal_grotto(g, h, cols, rows, rng)
		"rubble_field": _big_open(g, cols, rows, rng, 0.42, 0.4)
		"narrow_maze": _maze(g, cols, rows, rng)
		"open_quarry": _quarry(g, cols, rows, rng)
		"flooded_hall": _flooded(g, h, cols, rows, rng, gentle)
		"rooms_corridors": _bsp(g, cols, rows, rng)
		"spiral": _spiral(g, cols, rows, rng)
		"river_cave": _river(g, h, cols, rows, rng, gentle)
		"honeycomb": _honeycomb(g, cols, rows, rng)
		"canyon": _canyon(g, cols, rows, rng)
		"twin_caverns": _twin(g, cols, rows, rng)
		"sinkholes": _sinkholes(g, h, cols, rows, rng)
		"fissures": _fissures(g, h, cols, rows, rng, lava_ok)
		"stalagmite_forest": _stalag_forest(g, cols, rows, rng)
		"cross_halls": _cross(g, cols, rows, rng)
		"ledges": _ledges(g, cols, rows, rng)
		"archipelago": _archipelago(g, h, cols, rows, rng)
		"grand_cavern": _grand(g, cols, rows, rng)
		"geode": _geode(g, cols, rows, rng)
		_: _ca(g, cols, rows, rng, rng.randf_range(0.52, 0.6), rng.randi_range(4, 6), Rect2i(1, 1, cols - 2, rows - 2))
	_rim(g, h, cols, rows)
	_keep_largest(g, h, cols, rows)
	_drop_specks(g, h, cols, rows)
	var out := {"open": {}, "water": {}, "chasm": {}, "lava": {}}
	var names := ["", "water", "chasm", "lava"]
	for i in g.size():
		if g[i] == 0:
			continue
		var c := Vector2i(i % cols, i / cols)
		out["open"][c] = true
		if h[i] > 0:
			out[names[h[i]]][c] = true
	return out


# ---- grid helpers

static func _inb(x: int, y: int, cols: int, rows: int, m := 2) -> bool:
	return x >= m and y >= m and x < cols - m and y < rows - m


static func _put(g: PackedByteArray, cols: int, rows: int, x: int, y: int, v := 1) -> void:
	if _inb(x, y, cols, rows):
		g[y * cols + x] = v


static func _cell(g: PackedByteArray, cols: int, rows: int, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= cols or y >= rows:
		return 0
	return g[y * cols + x]


## A disc of radius r at p (fractional).
static func _paint(g: PackedByteArray, cols: int, rows: int, p: Vector2, r: float, v := 1) -> void:
	var rr := maxf(r, 0.75)
	for y in range(int(floor(p.y - rr)), int(ceil(p.y + rr)) + 1):
		for x in range(int(floor(p.x - rr)), int(ceil(p.x + rr)) + 1):
			if Vector2(x, y).distance_to(p) <= rr:
				_put(g, cols, rows, x, y, v)


## A wobbly-edged blob (ellipse sx, sy around c).
static func _blob(g: PackedByteArray, cols: int, rows: int, c: Vector2, sx: float, sy: float, rng: RandomNumberGenerator, wob := 0.25, v := 1) -> void:
	var k1 := rng.randi_range(2, 5)
	var k2 := k1 + rng.randi_range(1, 3)
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	for y in range(int(c.y - sy * 1.4) - 1, int(c.y + sy * 1.4) + 2):
		for x in range(int(c.x - sx * 1.4) - 1, int(c.x + sx * 1.4) + 2):
			var d := Vector2((x - c.x) / maxf(sx, 0.5), (y - c.y) / maxf(sy, 0.5))
			var a := d.angle()
			var lim := 1.0 + wob * (0.6 * sin(a * k1 + p1) + 0.4 * sin(a * k2 + p2))
			if d.length() <= lim:
				_put(g, cols, rows, x, y, v)


## A wandering tunnel from a to b, w cells wide.
static func _tunnel(g: PackedByteArray, cols: int, rows: int, a: Vector2, b: Vector2, w: float, rng: RandomNumberGenerator, wig := 0.5, v := 1) -> void:
	var p := a
	var dir := (b - a).normalized()
	var steps := 0
	var lim := int(a.distance_to(b) * 4.0) + 40
	while p.distance_to(b) > 1.2 and steps < lim:
		steps += 1
		var want := (b - p).normalized()
		# Pulled harder toward the goal the longer it wanders.
		var pull := 0.45 + 1.5 * float(steps) / lim
		dir = (dir + want * pull + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * wig).normalized()
		p += dir * 0.8
		p = p.clamp(Vector2(2, 2), Vector2(cols - 3, rows - 3))
		_paint(g, cols, rows, p, w * 0.5 + rng.randf_range(-0.1, 0.25), v)
	# Never leave it short: finish in a straight line.
	var rest := p.distance_to(b)
	for i in int(rest / 0.7) + 1:
		_paint(g, cols, rows, p.lerp(b, minf(1.0, i * 0.7 / maxf(rest, 0.01))), w * 0.5, v)
	_paint(g, cols, rows, b, w * 0.5, v)


static func _n8(g: PackedByteArray, cols: int, rows: int, x: int, y: int) -> int:
	var n := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dy != 0) and _cell(g, cols, rows, x + dx, y + dy) != 0:
				n += 1
	return n


## Round off corners: open cells with few open neighbours fill, rock with many opens.
static func _smooth(g: PackedByteArray, cols: int, rows: int, passes := 1, birth := 6, die := 1) -> void:
	for p in passes:
		var nxt := g.duplicate()
		for y in range(2, rows - 2):
			for x in range(2, cols - 2):
				var n := _n8(g, cols, rows, x, y)
				var i := y * cols + x
				if g[i] != 0 and n <= die:
					nxt[i] = 0
				elif g[i] == 0 and n >= birth:
					nxt[i] = 1
		for i in g.size():
			g[i] = nxt[i]


## Classic cellular-automata cave inside region (adds to g).
static func _ca(g: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator, fill: float, passes: int, region: Rect2i) -> void:
	var t := PackedByteArray()
	t.resize(cols * rows)
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var edge := mini(mini(x - region.position.x, region.end.x - 1 - x), mini(y - region.position.y, region.end.y - 1 - y))
			var p := fill if edge > 4 else (0.42 if edge > 2 else 0.2)
			if rng.randf() < p:
				t[y * cols + x] = 1
	for pi in passes:
		var nxt := PackedByteArray()
		nxt.resize(cols * rows)
		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				var n := _n8(t, cols, rows, x, y)
				var here := t[y * cols + x] != 0
				if (here and n >= 4) or (not here and n >= 5):
					nxt[y * cols + x] = 1
		t = nxt
	for i in t.size():
		if t[i] != 0:
			g[i] = 1


static func _rim(g: PackedByteArray, h: PackedByteArray, cols: int, rows: int) -> void:
	for y in rows:
		for x in cols:
			if not _inb(x, y, cols, rows):
				g[y * cols + x] = 0
				h[y * cols + x] = 0
	for i in g.size():
		if g[i] == 0:
			h[i] = 0


## Only the biggest connected cave stays (hazards count as cave here: Mine bridges them).
static func _keep_largest(g: PackedByteArray, h: PackedByteArray, cols: int, rows: int) -> void:
	var lab := PackedInt32Array()
	lab.resize(cols * rows)
	var best := -1
	var best_n := 0
	var cur := 0
	for i in g.size():
		if g[i] == 0 or lab[i] != 0:
			continue
		cur += 1
		var n := 0
		var st := PackedInt32Array([i])
		lab[i] = cur
		while st.size() > 0:
			var q := st[st.size() - 1]
			st.remove_at(st.size() - 1)
			n += 1
			var qx := q % cols
			for nb in [q - 1, q + 1, q - cols, q + cols]:
				if nb < 0 or nb >= g.size() or g[nb] == 0 or lab[nb] != 0:
					continue
				if (nb == q - 1 or nb == q + 1) and absi(nb % cols - qx) != 1:
					continue
				lab[nb] = cur
				st.append(nb)
		if n > best_n:
			best_n = n
			best = cur
	for i in g.size():
		if g[i] != 0 and lab[i] != best:
			g[i] = 0
			h[i] = 0


## Hazard bits under 5 cells read as stray squares: make them floor.
static func _drop_specks(g: PackedByteArray, h: PackedByteArray, cols: int, rows: int) -> void:
	var seen := PackedByteArray()
	seen.resize(cols * rows)
	for i in h.size():
		if h[i] == 0 or seen[i] != 0:
			continue
		var kind := h[i]
		var comp := PackedInt32Array()
		var st := PackedInt32Array([i])
		seen[i] = 1
		while st.size() > 0:
			var q := st[st.size() - 1]
			st.remove_at(st.size() - 1)
			comp.append(q)
			var qx := q % cols
			for nb in [q - 1, q + 1, q - cols, q + cols]:
				if nb < 0 or nb >= h.size() or seen[nb] != 0 or h[nb] != kind:
					continue
				if (nb == q - 1 or nb == q + 1) and absi(nb % cols - qx) != 1:
					continue
				seen[nb] = 1
				st.append(nb)
		if comp.size() < 5:
			for q in comp:
				h[q] = 0


## Feature size grows with the map, so deep (bigger) floors aren't just sparser.
static func _k(cols: int, rows: int) -> float:
	return clampf(sqrt(cols * rows / 3000.0), 1.0, 1.7)


static func _rp(cols: int, rows: int, rng: RandomNumberGenerator, m := 6) -> Vector2:
	return Vector2(rng.randf_range(m, cols - m), rng.randf_range(m, rows - m))


## Join points into one network: a chain in random order plus a few extra links.
static func _link_all(g: PackedByteArray, cols: int, rows: int, pts: Array, rng: RandomNumberGenerator, w: float, extra: float, wig := 0.4) -> void:
	# Nearest-neighbour chain (a tree), then extras.
	var left := pts.duplicate()
	var done: Array = [left.pop_back()]
	while not left.is_empty():
		var bi := 0
		var bj := 0
		var bd := 1e9
		for i in left.size():
			for j in done.size():
				var d: float = (left[i] as Vector2).distance_to(done[j])
				if d < bd:
					bd = d
					bi = i
					bj = j
		_tunnel(g, cols, rows, done[bj], left[bi], w, rng, wig)
		done.append(left.pop_at(bi))
	for k in int(pts.size() * extra):
		var a: Vector2 = pts[rng.randi() % pts.size()]
		var b: Vector2 = pts[rng.randi() % pts.size()]
		if a != b and a.distance_to(b) < (cols + rows) * 0.35:
			_tunnel(g, cols, rows, a, b, w, rng, wig)


# ---- the styles

static func _winding(g: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator) -> void:
	var pts: Array = []
	for i in int(rng.randi_range(11, 16) * _k(cols, rows)):
		pts.append(_rp(cols, rows, rng, 5))
	_link_all(g, cols, rows, pts, rng, rng.randf_range(2.6, 3.6), rng.randf_range(0.35, 0.6), rng.randf_range(0.5, 0.9))
	for p: Vector2 in pts:
		if rng.randf() < 0.8:
			_blob(g, cols, rows, p, rng.randf_range(3.5, 6.0) * _k(cols, rows), rng.randf_range(3.0, 5.0) * _k(cols, rows), rng)
	_smooth(g, cols, rows, 1, 6, 1)


static func _pillar_hall(g: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator) -> void:
	var halls := rng.randi_range(1, 3)
	var ctrs: Array = []
	for i in halls:
		var w := rng.randi_range(int(cols * (0.7 if halls == 1 else 0.42)), int(cols * (0.88 if halls == 1 else 0.58)))
		var hh := rng.randi_range(int(rows * (0.65 if halls == 1 else 0.4)), int(rows * (0.85 if halls == 1 else 0.55)))
		var x0 := rng.randi_range(3, maxi(3, cols - w - 3))
		var y0 := rng.randi_range(3, maxi(3, rows - hh - 3))
		for y in range(y0, y0 + hh):
			for x in range(x0, x0 + w):
				var edge := mini(mini(x - x0, x0 + w - 1 - x), mini(y - y0, y0 + hh - 1 - y))
				if edge > 0 or rng.randf() < 0.55:
					_put(g, cols, rows, x, y)
		ctrs.append(Vector2(x0 + w / 2.0, y0 + hh / 2.0))
		# Pillars: 2x2 rock on a grid, a few missing or crumbled to rubble.
		var step := rng.randi_range(5, 7)
		var ox := rng.randi_range(2, step)
		var oy := rng.randi_range(2, step)
		for py in range(y0 + oy, y0 + hh - 3, step):
			for px in range(x0 + ox, x0 + w - 3, step):
				if rng.randf() < 0.85:
					var big := rng.randf() < 0.3
					for dy in (3 if big else 2):
						for dx in (3 if big else 2):
							_put(g, cols, rows, px + dx, py + dy, 0)
	_link_all(g, cols, rows, ctrs, rng, 3.0, 0.0)
	_smooth(g, cols, rows, 1, 7, 1)


static func _island_lake(g: PackedByteArray, h: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator, gentle: bool) -> void:
	_ca(g, cols, rows, rng, rng.randf_range(0.6, 0.66), 4, Rect2i(1, 1, cols - 2, rows - 2))
	var c := Vector2(cols * rng.randf_range(0.4, 0.6), rows * rng.randf_range(0.42, 0.6))
	var sx := cols * rng.randf_range(0.14, 0.2 if gentle else 0.27)
	var sy := rows * rng.randf_range(0.14, 0.2 if gentle else 0.27)
	var lake := PackedByteArray()
	lake.resize(cols * rows)
	_blob(lake, cols, rows, c, sx, sy, rng, 0.3)
	for i in rng.randi_range(1, 3):
		_blob(lake, cols, rows, c + Vector2(rng.randf_range(-sx, sx), rng.randf_range(-sy, sy)), sx * 0.5, sy * 0.5, rng, 0.3)
	for i in rng.randi_range(2, 5):
		var ip := c + Vector2(rng.randf_range(-sx, sx) * 0.6, rng.randf_range(-sy, sy) * 0.6)
		_blob(lake, cols, rows, ip, rng.randf_range(1.5, 3.2), rng.randf_range(1.5, 3.0), rng, 0.3, 0)
	for i in g.size():
		if lake[i] != 0:
			g[i] = 1
			h[i] = 1


static func _chasm_bridges(g: PackedByteArray, h: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator) -> void:
	_ca(g, cols, rows, rng, rng.randf_range(0.58, 0.64), 4, Rect2i(1, 1, cols - 2, rows - 2))
	var bands := rng.randi_range(1, 3)
	for b in bands:
		var vert := rng.randf() < 0.5
		var a := Vector2(cols * (b + 1.0) / (bands + 1.0) + rng.randf_range(-4, 4), 2) if vert else Vector2(2, rows * (b + 1.0) / (bands + 1.0) + rng.randf_range(-4, 4))
		var e := Vector2(a.x + rng.randf_range(-10, 10), rows - 3) if vert else Vector2(cols - 3, a.y + rng.randf_range(-8, 8))
		var band := PackedByteArray()
		band.resize(cols * rows)
		_tunnel(band, cols, rows, a, e, rng.randf_range(2.0, 3.6), rng, 0.35)
		for i in band.size():
			if band[i] != 0 and g[i] != 0:
				h[i] = 2


static func _ring_rooms(g: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator) -> void:
	var c := Vector2(cols / 2.0, rows / 2.0)
	var rx := cols * rng.randf_range(0.3, 0.38)
	var ry := rows * rng.randf_range(0.3, 0.38)
	var k := rng.randi_range(5, 9)
	var ph := rng.randf() * TAU
	var pts: Array = []
	for i in k:
		var a := ph + TAU * i / k + rng.randf_range(-0.2, 0.2)
		var p := c + Vector2(cos(a) * rx, sin(a) * ry)
		pts.append(p)
		_blob(g, cols, rows, p, rng.randf_range(5.0, 8.0) * _k(cols, rows), rng.randf_range(4.0, 6.5) * _k(cols, rows), rng)
		# An outer pocket off some rooms.
		if rng.randf() < 0.5:
			var po := c + Vector2(cos(a) * rx * 1.35, sin(a) * ry * 1.35)
			_blob(g, cols, rows, po, rng.randf_range(3.0, 5.0), rng.randf_range(2.5, 4.0), rng)
			_tunnel(g, cols, rows, p, po, 2.6, rng, 0.3)
	for i in k:
		if i < k - 1 or rng.randf() < 0.85:   # now and then the ring is broken: a horseshoe
			_tunnel(g, cols, rows, pts[i], pts[(i + 1) % k], rng.randf_range(2.2, 3.2), rng, 0.4)
	_blob(g, cols, rows, c, rng.randf_range(4.0, 7.5), rng.randf_range(3.5, 6.0), rng)
	for i in rng.randi_range(1, 3):
		_tunnel(g, cols, rows, c, pts[rng.randi() % k], 2.4, rng, 0.35)
	_smooth(g, cols, rows, 1)


## Round clearings joined by short paths (groves, chambers).
static func _glades(g: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator, n: int, rmin: float, rmax: float) -> void:
	var pts: Array = []
	for i in n:
		var kk := _k(cols, rows)
		var p := _rp(cols, rows, rng, int(rmax * kk) + 3)
		pts.append(p)
		_blob(g, cols, rows, p, rng.randf_range(rmin, rmax) * kk, rng.randf_range(rmin, rmax) * 0.85 * kk, rng, 0.3)
	_link_all(g, cols, rows, pts, rng, rng.randf_range(2.2, 3.4), 0.3, 0.45)
	_smooth(g, cols, rows, 1)


static func _crystal_grotto(g: PackedByteArray, h: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator) -> void:
	_ca(g, cols, rows, rng, rng.randf_range(0.5, 0.56), 5, Rect2i(1, 1, cols - 2, rows - 2))
	_glades(g, cols, rows, rng, rng.randi_range(3, 5), 3.0, 5.0)
	for i in rng.randi_range(2, 4):
		var p := _rp(cols, rows, rng, 8)
		if _cell(g, cols, rows, int(p.x), int(p.y)) != 0:
			var pool := PackedByteArray()
			pool.resize(cols * rows)
			_blob(pool, cols, rows, p, rng.randf_range(1.8, 3.2), rng.randf_range(1.5, 2.6), rng, 0.3)
			for j in pool.size():
				if pool[j] != 0 and g[j] != 0:
					h[j] = 1


static func _big_open(g: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator, kx: float, ky: float) -> void:
	var c := Vector2(cols / 2.0 + rng.randf_range(-3, 3), rows / 2.0 + rng.randf_range(-3, 3))
	_blob(g, cols, rows, c, cols * kx, rows * ky, rng, 0.18)
	for i in rng.randi_range(3, 6):
		var a := rng.randf() * TAU
		_blob(g, cols, rows, c + Vector2(cos(a) * cols * kx, sin(a) * rows * ky) * 0.85, rng.randf_range(3, 7), rng.randf_range(3, 6), rng)
	_smooth(g, cols, rows, 2, 5, 3)


static func _maze(g: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator) -> void:
	var s := 3 if rng.randf() < 0.5 else 4    # 2-wide halls, 1- or 2-thick walls
	var mw := (cols - 4) / s
	var mh := (rows - 4) / s
	var seen := {}
	var st: Array = [Vector2i(rng.randi() % mw, rng.randi() % mh)]
	seen[st[0]] = true
	var walls: Array = []
	while not st.is_empty():
		var cur: Vector2i = st[-1]
		var opts: Array = []
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := cur + d
			if n.x >= 0 and n.y >= 0 and n.x < mw and n.y < mh and not seen.has(n):
				opts.append(n)
		_cell_open(g, cols, rows, cur, s)
		if opts.is_empty():
			st.pop_back()
			continue
		var nx: Vector2i = opts[rng.randi() % opts.size()]
		seen[nx] = true
		_join(g, cols, rows, cur, nx, s)
		st.append(nx)
	# Knock through some walls for loops, and open a few rooms.
	for i in int(mw * mh * 0.12):
		var a := Vector2i(rng.randi() % mw, rng.randi() % mh)
		var d: Vector2i = [Vector2i(1, 0), Vector2i(0, 1)][rng.randi() % 2]
		if a.x + d.x < mw and a.y + d.y < mh:
			_join(g, cols, rows, a, a + d, s)
	for i in rng.randi_range(2, 4):
		_blob(g, cols, rows, _rp(cols, rows, rng, 8), rng.randf_range(3, 5), rng.randf_range(2.5, 4), rng, 0.2)


static func _cell_open(g: PackedByteArray, cols: int, rows: int, c: Vector2i, s: int) -> void:
	for dy in 2:
		for dx in 2:
			_put(g, cols, rows, 2 + c.x * s + dx, 2 + c.y * s + dy)


static func _join(g: PackedByteArray, cols: int, rows: int, a: Vector2i, b: Vector2i, s: int) -> void:
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var hi := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	for y in range(2 + lo.y * s, 2 + hi.y * s + 2):
		for x in range(2 + lo.x * s, 2 + hi.x * s + 2):
			_put(g, cols, rows, x, y)


static func _quarry(g: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator) -> void:
	_big_open(g, cols, rows, rng, 0.44, 0.42)
	# Terraces: long rock ridges with frequent gaps, like benches cut in a pit.
	var gap := rng.randi_range(6, 9)
	var horiz := rng.randf() < 0.65
	var n := (rows if horiz else cols)
	var m := (cols if horiz else rows)
	var off := rng.randi_range(4, gap)
	var i := off
	while i < n - 4:
		var j := 3
		while j < m - 3:
			var run := rng.randi_range(5, 14)
			for k in run:
				if horiz:
					_put(g, cols, rows, j + k, i, 0)
				else:
					_put(g, cols, rows, i, j + k, 0)
			j += run + rng.randi_range(2, 5)
		i += gap + rng.randi_range(-1, 2)


static func _flooded(g: PackedByteArray, h: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator, gentle: bool) -> void:
	_big_open(g, cols, rows, rng, 0.42, 0.4)
	var seed := rng.randi()
	var thr := 0.42 if gentle else 0.32
	for y in rows:
		for x in cols:
			var i := y * cols + x
			if g[i] != 0 and WorldGen.fbm(float(x), float(y), seed, 5.0) > thr:
				h[i] = 1


static func _bsp(g: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator) -> void:
	var leaves: Array = []
	var stack: Array = [Rect2i(3, 3, cols - 6, rows - 6)]
	while not stack.is_empty():
		var r: Rect2i = stack.pop_back()
		var can_h := r.size.x >= 22
		var can_v := r.size.y >= 18
		if (not can_h and not can_v) or (r.size.x < 30 and r.size.y < 26 and rng.randf() < 0.3):
			leaves.append(r)
			continue
		if can_h and (not can_v or r.size.x * 0.9 > r.size.y and rng.randf() < 0.8 or rng.randf() < 0.5):
			var cut := rng.randi_range(r.size.x * 2 / 5, r.size.x * 3 / 5)
			stack.append(Rect2i(r.position, Vector2i(cut, r.size.y)))
			stack.append(Rect2i(r.position + Vector2i(cut, 0), Vector2i(r.size.x - cut, r.size.y)))
		else:
			var cut := rng.randi_range(r.size.y * 2 / 5, r.size.y * 3 / 5)
			stack.append(Rect2i(r.position, Vector2i(r.size.x, cut)))
			stack.append(Rect2i(r.position + Vector2i(0, cut), Vector2i(r.size.x, r.size.y - cut)))
	var ctrs: Array = []
	for r: Rect2i in leaves:
		var w := rng.randi_range(maxi(5, r.size.x / 2), maxi(6, r.size.x - 3))
		var hh := rng.randi_range(maxi(4, r.size.y / 2), maxi(5, r.size.y - 3))
		var x0 := r.position.x + rng.randi_range(1, maxi(1, r.size.x - w - 1))
		var y0 := r.position.y + rng.randi_range(1, maxi(1, r.size.y - hh - 1))
		if rng.randf() < 0.35:
			_blob(g, cols, rows, Vector2(x0 + w / 2.0, y0 + hh / 2.0), w / 2.0, hh / 2.0, rng, 0.15)
		else:
			for y in range(y0, y0 + hh):
				for x in range(x0, x0 + w):
					var edge := mini(mini(x - x0, x0 + w - 1 - x), mini(y - y0, y0 + hh - 1 - y))
					if edge > 0 or rng.randf() < 0.6:
						_put(g, cols, rows, x, y)
		ctrs.append(Vector2(x0 + w / 2.0, y0 + hh / 2.0))
	# Corridors: L-shaped, mostly straight (old miners dug them).
	ctrs.shuffle()
	_link_all(g, cols, rows, ctrs, rng, rng.randf_range(2.0, 3.0), 0.25, 0.15)
	_smooth(g, cols, rows, 1, 7, 1)


static func _spiral(g: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator) -> void:
	var c := Vector2(cols / 2.0, rows / 2.0)
	var rx := cols * 0.44
	var ry := rows * 0.44
	var turns := clampf(minf(rx, ry) / 7.5, 2.5, 6.0)
	var ph := rng.randf() * TAU
	var dirn := 1.0 if rng.randf() < 0.5 else -1.0
	var steps := int(turns * 220)
	for i in steps:
		var t := float(i) / steps
		var a := ph + dirn * t * turns * TAU
		var r := 1.0 - t * 0.92
		var p := c + Vector2(cos(a) * rx * r, sin(a) * ry * r)
		_paint(g, cols, rows, p, 1.9 + 0.4 * sin(t * 40.0))
	_blob(g, cols, rows, c, rng.randf_range(4, 6), rng.randf_range(3.5, 5), rng)
	# Cut-throughs, so it isn't one long walk.
	for i in rng.randi_range(2, 3):
		var a := rng.randf() * TAU
		_tunnel(g, cols, rows, c, c + Vector2(cos(a) * rx * 0.9, sin(a) * ry * 0.9), 2.2, rng, 0.2)
	_smooth(g, cols, rows, 1)


static func _river(g: PackedByteArray, h: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator, gentle: bool) -> void:
	_ca(g, cols, rows, rng, rng.randf_range(0.6, 0.66), 4, Rect2i(1, 1, cols - 2, rows - 2))
	var horiz := cols >= rows or rng.randf() < 0.3
	var riv := PackedByteArray()
	riv.resize(cols * rows)
	var a := Vector2(2, rows * rng.randf_range(0.3, 0.7)) if horiz else Vector2(cols * rng.randf_range(0.3, 0.7), 2)
	var e := Vector2(cols - 3, rows * rng.randf_range(0.3, 0.7)) if horiz else Vector2(cols * rng.randf_range(0.3, 0.7), rows - 3)
	_tunnel(riv, cols, rows, a, e, rng.randf_range(2.0, 2.8 if gentle else 4.0), rng, 0.55)
	for i in riv.size():
		if riv[i] != 0:
			g[i] = 1   # the river cuts its own bed
			h[i] = 1


static func _honeycomb(g: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator) -> void:
	var sp := rng.randi_range(9, 12)
	var nodes := {}
	var gx := 0
	for x in range(6, cols - 5, sp):
		var gy := 0
		for y in range(6, rows - 5, sp):
			var off := (sp / 2.0) if gx % 2 == 1 else 0.0
			var p := Vector2(x, y + off) + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2))
			if p.y < rows - 5:
				nodes[Vector2i(gx, gy)] = p
				_blob(g, cols, rows, p, rng.randf_range(2.6, 4.4), rng.randf_range(2.4, 4.0), rng, 0.3)
			gy += 1
		gx += 1
	var keys: Array = nodes.keys()
	var seen := {keys[0]: true}
	var st: Array = [keys[0]]
	while not st.is_empty():
		var cur: Vector2i = st[-1]
		var opts: Array = []
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1)]:
			if nodes.has(cur + d) and not seen.has(cur + d):
				opts.append(cur + d)
		if opts.is_empty():
			st.pop_back()
			continue
		var nx: Vector2i = opts[rng.randi() % opts.size()]
		seen[nx] = true
		_tunnel(g, cols, rows, nodes[cur], nodes[nx], 2.2, rng, 0.25)
		st.append(nx)
	for i in int(keys.size() * 0.3):
		var a: Vector2i = keys[rng.randi() % keys.size()]
		var b: Vector2i = a + [Vector2i(1, 0), Vector2i(0, 1)][rng.randi() % 2]
		if nodes.has(b):
			_tunnel(g, cols, rows, nodes[a], nodes[b], 2.2, rng, 0.25)


static func _canyon(g: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator) -> void:
	var horiz := rng.randf() < 0.6
	var n := rng.randi_range(2, 3)
	var L := cols if horiz else rows
	var W := rows if horiz else cols
	var lines: Array = []
	for k in n:
		var base := W * (k + 1.0) / (n + 1.0)
		var amp := rng.randf_range(2.0, 5.0)
		var fr := rng.randf_range(0.05, 0.12)
		var ph := rng.randf() * TAU
		var pts: Array = []
		for t in range(3, L - 3):
			var mid := base + sin(t * fr + ph) * amp
			var hw := (2.0 + 1.6 * (0.5 + 0.5 * sin(t * fr * 2.3 + ph * 2.0))) * _k(cols, rows) + rng.randf_range(-0.2, 0.3)
			pts.append(mid)
			for q in range(int(mid - hw), int(mid + hw) + 1):
				if horiz:
					_put(g, cols, rows, t, q)
				else:
					_put(g, cols, rows, q, t)
		lines.append(pts)
	for k in n - 1:
		for i in rng.randi_range(2, 4):
			var t := rng.randi_range(4, L - 8)
			var a: float = lines[k][t - 3]
			var b: float = lines[k + 1][t - 3]
			var pa := Vector2(t, a) if horiz else Vector2(a, t)
			var pb := Vector2(t, b) if horiz else Vector2(b, t)
			_tunnel(g, cols, rows, pa, pb, rng.randf_range(2.2, 3.4), rng, 0.3)
	# Side pockets.
	for i in rng.randi_range(4, 8):
		var k := rng.randi() % n
		var t := rng.randi_range(4, L - 8)
		var mid: float = lines[k][t - 3]
		var off := rng.randf_range(4, 7) * (1 if rng.randf() < 0.5 else -1)
		var p := Vector2(t, mid + off) if horiz else Vector2(mid + off, t)
		_blob(g, cols, rows, p, rng.randf_range(2.5, 4), rng.randf_range(2.5, 4), rng)
		_tunnel(g, cols, rows, Vector2(t, mid) if horiz else Vector2(mid, t), p, 2.2, rng, 0.2)
	_smooth(g, cols, rows, 1)


static func _twin(g: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator) -> void:
	var vert := rows > cols * 1.1 or rng.randf() < 0.3
	var gapw := rng.randi_range(6, 12)
	if vert:
		var hh := (rows - gapw) / 2
		_ca(g, cols, rows, rng, 0.58, 5, Rect2i(1, 1, cols - 2, hh))
		_ca(g, cols, rows, rng, 0.58, 5, Rect2i(1, hh + gapw, cols - 2, rows - hh - gapw - 1))
	else:
		var ww := (cols - gapw) / 2
		_ca(g, cols, rows, rng, 0.58, 5, Rect2i(1, 1, ww, rows - 2))
		_ca(g, cols, rows, rng, 0.58, 5, Rect2i(ww + gapw, 1, cols - ww - gapw - 1, rows - 2))
	for i in rng.randi_range(1, 2):
		var a := Vector2(cols * 0.25, rng.randf_range(rows * 0.25, rows * 0.75)) if not vert else Vector2(rng.randf_range(cols * 0.25, cols * 0.75), rows * 0.25)
		var b := Vector2(cols * 0.75, rng.randf_range(rows * 0.25, rows * 0.75)) if not vert else Vector2(rng.randf_range(cols * 0.25, cols * 0.75), rows * 0.75)
		_tunnel(g, cols, rows, a, b, rng.randf_range(2.2, 3.0), rng, 0.6)


static func _sinkholes(g: PackedByteArray, h: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator) -> void:
	_big_open(g, cols, rows, rng, 0.43, 0.41)
	for i in rng.randi_range(8, 18):
		var p := _rp(cols, rows, rng, 7)
		var hole := PackedByteArray()
		hole.resize(cols * rows)
		_blob(hole, cols, rows, p, rng.randf_range(1.6, 3.4), rng.randf_range(1.5, 3.0), rng, 0.3)
		for j in hole.size():
			if hole[j] != 0 and g[j] != 0:
				h[j] = 2


static func _fissures(g: PackedByteArray, h: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator, lava_ok: bool) -> void:
	_ca(g, cols, rows, rng, rng.randf_range(0.6, 0.66), 4, Rect2i(1, 1, cols - 2, rows - 2))
	var crack := PackedByteArray()
	crack.resize(cols * rows)
	for i in rng.randi_range(3, 6):
		var a := _rp(cols, rows, rng, 5)
		var b := a + Vector2(rng.randf_range(-25, 25), rng.randf_range(-20, 20))
		_tunnel(crack, cols, rows, a, b.clamp(Vector2(4, 4), Vector2(cols - 5, rows - 5)), rng.randf_range(1.6, 2.4), rng, 0.7)
	for j in crack.size():
		if crack[j] != 0 and g[j] != 0:
			h[j] = 3 if lava_ok else 2


static func _stalag_forest(g: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator) -> void:
	_big_open(g, cols, rows, rng, 0.43, 0.41)
	var dens := rng.randf_range(0.035, 0.07)
	for y in range(3, rows - 3):
		for x in range(3, cols - 3):
			if g[y * cols + x] != 0 and rng.randf() < dens:
				g[y * cols + x] = 0
				if rng.randf() < 0.35:
					_put(g, cols, rows, x + (1 if rng.randf() < 0.5 else 0), y + (1 if rng.randf() < 0.5 else 0), 0)


static func _cross(g: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator) -> void:
	var cx := cols / 2 + rng.randi_range(-5, 5)
	var cy := rows / 2 + rng.randi_range(-4, 4)
	var hw := int(rng.randi_range(3, 5) * _k(cols, rows))
	var vw := int(rng.randi_range(3, 5) * _k(cols, rows))
	_tunnel(g, cols, rows, Vector2(3, cy), Vector2(cols - 4, cy), hw * 2.0, rng, 0.15)
	_tunnel(g, cols, rows, Vector2(cx, 3), Vector2(cx, rows - 4), vw * 2.0, rng, 0.15)
	for q in [Vector2(0.22, 0.22), Vector2(0.78, 0.22), Vector2(0.22, 0.78), Vector2(0.78, 0.78)]:
		if rng.randf() < 0.85:
			var p := Vector2(cols * q.x, rows * q.y) + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
			_blob(g, cols, rows, p, rng.randf_range(4, 7) * _k(cols, rows), rng.randf_range(3.5, 6) * _k(cols, rows), rng)
			_tunnel(g, cols, rows, p, Vector2(cx, p.y) if rng.randf() < 0.5 else Vector2(p.x, cy), 2.4, rng, 0.3)
	_blob(g, cols, rows, Vector2(cx, cy), hw + 3.0, vw + 2.5, rng)
	_smooth(g, cols, rows, 1)


static func _ledges(g: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator) -> void:
	var y := 3
	while y < rows - 6:
		var bh := rng.randi_range(4, 7)
		var x0 := rng.randi_range(3, 8)
		var x1 := cols - rng.randi_range(4, 9)
		for yy in range(y, mini(rows - 3, y + bh)):
			for x in range(x0 + rng.randi_range(0, 1), x1 - rng.randi_range(0, 1)):
				_put(g, cols, rows, x, yy)
		y += bh
		var wall := rng.randi_range(1, 2)
		# Gaps through the ledge wall.
		var x := x0 + rng.randi_range(2, 8)
		while x < x1 - 2:
			var gw := rng.randi_range(2, 4)
			for yy in range(y, y + wall):
				for k in gw:
					_put(g, cols, rows, x + k, yy)
			x += gw + rng.randi_range(6, 14)
		y += wall
	_smooth(g, cols, rows, 1, 7, 2)


static func _archipelago(g: PackedByteArray, h: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator) -> void:
	_big_open(g, cols, rows, rng, 0.44, 0.42)
	var seed := rng.randi()
	for y in rows:
		for x in cols:
			var i := y * cols + x
			if g[i] != 0 and WorldGen.fbm(float(x), float(y), seed, 7.0) < -0.02:
				h[i] = 1


static func _grand(g: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator) -> void:
	_big_open(g, cols, rows, rng, 0.45, 0.43)
	# A great rock formation in the middle (and maybe a couple more).
	for i in rng.randi_range(1, 3):
		var p := Vector2(cols / 2.0, rows / 2.0) + Vector2(rng.randf_range(-cols * 0.2, cols * 0.2), rng.randf_range(-rows * 0.2, rows * 0.2))
		_blob(g, cols, rows, p, rng.randf_range(3, cols * 0.1), rng.randf_range(3, rows * 0.1), rng, 0.35, 0)
	_smooth(g, cols, rows, 1)


static func _geode(g: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator) -> void:
	# Big round chambers with thick shells, linked by narrow throats.
	var pts: Array = []
	for i in 60:
		var p := _rp(cols, rows, rng, 9)
		var ok := true
		for q: Vector2 in pts:
			if q.distance_to(p) < 15:
				ok = false
		if ok:
			pts.append(p)
			_blob(g, cols, rows, p, rng.randf_range(6.0, 9.5) * _k(cols, rows), rng.randf_range(5.0, 8.0) * _k(cols, rows), rng, 0.12)
		if pts.size() >= 9:
			break
	if pts.size() < 2:
		pts.append(Vector2(cols * 0.25, rows * 0.5))
		pts.append(Vector2(cols * 0.75, rows * 0.5))
		for p: Vector2 in pts:
			_blob(g, cols, rows, p, 6, 5, rng, 0.12)
	_link_all(g, cols, rows, pts, rng, 2.0, 0.2, 0.3)

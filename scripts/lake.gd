extends GameMap
## The west lake: a big noise-shaped water body, the best fishing in the valley.
## Three working buildings sit where they belong: Finn's bait hut on stilts at
## the end of the east dock, the water mill on the south outlet where the lake
## drains toward the border water (grinds wheat into flour for Posy), and the
## lighthouse on a rock island off the south-west shore, reached by a plank
## walk (Marlowe the keeper gives the lamp quests). Exits: farm (east), forest
## (north).

const FARM_EXIT := Rect2i(47, 21, 1, 3)
const FOREST_EXIT := Rect2i(44, 0, 3, 1)
const LAKE_C := Vector2(19.0, 19.0)
const LAKE_R := 12.5

var _water := {}
var _lake_rect := Rect2i(4, 5, 30, 28)
var npcs: Array = []


func scene_id() -> String:
	return "lake"


func default_spawn() -> Vector2:
	return Vector2(45 * TILE, 22 * TILE) + offset()


func build() -> void:
	cols = 48
	rows = 40
	pad = 7
	border = {"n": "trees", "s": "water", "w": "trees", "e": "trees"}
	music_track = "lake"
	add_exit(FARM_EXIT, "farm", Vector2(3 * TILE, 30 * TILE + 8), "right", "farm ▶")
	add_exit(FOREST_EXIT, "forest", Vector2(3 * TILE, 21 * TILE + 8), "right", "▲ forest")
	add_exit(Rect2i(0, 4, 1, 3), "riverlands", Vector2(49 * TILE, 22 * TILE + 8), "left", "◀ riverlands")
	# The lake: a wobbly disc plus a northern inlet (the waterfall) and the
	# southern outlet stream that runs to the border water past the mill.
	for y in range(2, rows):
		for x in range(1, cols - 8):
			var p := Vector2(x + 0.5, y + 0.5)
			var n := WorldGen.fbm(float(x), float(y), 909, 6.0)
			var inside := p.distance_to(LAKE_C) + n * 3.5 <= LAKE_R
			if not inside and y >= 2 and y <= 8 and absi(x - 9) <= 1 + int(n > 0.1):
				inside = true  # inlet from the falls
			if not inside and y >= 28 and y <= rows and absi(x - 27) <= 1 + int(n > 0.0):
				inside = true  # outlet stream south
			if inside:
				_water[Vector2i(x, y)] = true
	# No islands: fill holes and nibs so the shoreline reads as one body.
	for pass_i in 3:
		var add := {}
		var drop := {}
		for y in range(2, rows):
			for x in range(1, cols - 8):
				var c := Vector2i(x, y)
				var wn := 0
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if _water.has(c + d):
						wn += 1
				if not _water.has(c) and wn >= 3:
					add[c] = true
				elif _water.has(c) and wn <= 1:
					drop[c] = true
		for c: Vector2i in add:
			_water[c] = true
		for c: Vector2i in drop:
			_water.erase(c)
	for c: Vector2i in _water:
		set_thing(c.x, c.y, {"type": "water", "hint": "A: fish" if GameState.has_tool("rod") else ""})
	# East dock: from the shore at row 21 out into the water.
	# It starts on the first land cell east of the water, so it touches the shore.
	var e := 30
	while _water.has(Vector2i(e, 21)) and e < cols - 1:
		e += 1
	for dx in range(e - 6, e):
		_dock(Vector2i(dx, 21))
		_dock(Vector2i(dx, 22))
	extend(10, 8)
	# The outlet stream runs on through the added rows to the border water.
	# It tapers out of the mill pond and wanders a little, not a ruler-straight ditch.
	for y in range(40, rows):
		var xs := range(25, 30)
		if y >= 42:
			var w := 1 + int(WorldGen.fbm(26.0, float(y), 909, 4.0) > 0.0)
			xs = range(27 - w, 28 + w)
		for sx in xs:
			var c := Vector2i(sx, y)
			if not things.has(c):
				_water[c] = true
				set_thing(sx, y, {"type": "water", "hint": "A: fish" if GameState.has_tool("rod") else ""})
	# The lake, its outlet stream and the water past the map edge: one body
	# (drawn under the docks too, so the planks sit on water, not a hole).
	if Art.has("seamless", "lake_shallow"):
		border_water_extra = _water.duplicate()
		for c: Vector2i in _docked:
			border_water_extra[c] = true
		border_water_shore = "grass"


var _docked := {}


func _dock(c: Vector2i) -> void:
	if _water.has(c):
		_docked[c] = true
	things[c] = {"type": "dock"}
	blocked.erase(c)
	hard.erase(c)
	_water.erase(c)


func after_ready() -> void:
	WorldGen.add_backdrop(self, "mountains")
	if Art.has("props", "waterfall_pool"):
		var wp := AnimatedSprite2D.new()
		wp.sprite_frames = Art.frames("props", {"idle": "waterfall_pool"}, {"idle": 6.0})
		wp.animation = "idle"
		wp.scale = Vector2(0.5, 0.5)
		wp.position = cell_center(Vector2i(9, 2)) + Vector2(0, -4)
		wp.offset = Vector2(0, -48)
		add_child(wp)
		wp.play("idle")
	var dock := DockLayer.new()
	dock.map = self
	dock.position = offset()
	add_child.call_deferred(dock)  # after the water masks, so planks sit on the water
	# Finn's hut: stilts in the water at the end of the dock (door opens onto the planks).
	_shore_building("fishing_hut", Vector2i(26, 13), "fishing_hut", "A: Finn's bait shop", Vector2i(29, 20))
	# The mill straddles the outlet stream on the south shore; its door is on the wheel side.
	_shore_building("water_mill", Vector2i(24, 26), "water_mill", "A: the mill", Vector2i(34, 34), true)
	# The lighthouse stands on its rock at the south-west point; the door faces the shore path.
	_shore_building("lighthouse", Vector2i(1, 24), "lighthouse", "A: the lighthouse", Vector2i(10, 34), true)
	anim_prop("props", "duck", Vector2i(14, 14), 0, 1.5, false, 0.3)
	anim_prop("props", "heron", Vector2i(26, 10), 0, 1.5, false, 0.4)
	prop("props", "beaver_dam", Vector2i(11, 29), 2)
	prop("props", "signpost", Vector2i(36, 24))
	for c: Vector2i in [Vector2i(36, 20), Vector2i(36, 28)]:
		prop("props", "bench_wood", c, 1)
	# The crab pot floats in the shallows: the nearest water cell to the path bend.
	var cp := Vector2i(33, 23)
	var bd := 1e9
	for wc: Vector2i in _water:
		var dd := float((wc - Vector2i(30, 22)).length_squared())
		var shallow := _water.has(wc + Vector2i(0, -1)) and _water.has(wc + Vector2i(1, 0)) and _water.has(wc + Vector2i(-1, 0))
		if dd < bd and shallow and not things.get(wc, {}).has("door"):
			bd = dd
			cp = wc
	prop("props", "crab_pot_water" if Art.has("props", "crab_pot_water") else "barrel_a", cp, 0, 0.0, false)
	# Reeds along the shore, lilies in the shallows.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var n := 0
	for c: Vector2i in _water:
		if rng.randf() > 0.045 or n > 40:
			continue
		var edge := false
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not _water.has(c + d):
				edge = true
		var nm := ("reeds_%d" % rng.randi_range(0, 3)) if edge else ("lily_%d" % rng.randi_range(0, 7))
		var sp := Art.sprite("nature", nm)
		if sp:
			sp.position = cell_center(c)
			add_child(sp)
			n += 1
	var avoid := {}
	for c: Vector2i in _water:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				avoid[c + Vector2i(dx, dy)] = true
	for r: Rect2i in [Rect2i(24, 12, 24, 14), Rect2i(22, 24, 14, 12), Rect2i(0, 22, 12, 14)]:
		for c in cells_of([r]):
			avoid[c] = true
	WorldGen.tree_clumps(self, Rect2i(2, 2, cols - 4, rows - 4), 72, 9, avoid)
	WorldGen.scatter_props(self, Rect2i(2, 2, cols - 4, rows - 4), 74, 22, avoid)
	WorldGen.add_critters(self, Rect2i(2, 2, cols - 4, rows - 4), 75, 12, ["frog", "turtle", "dragonfly", "sparrow", "butterfly_blue", "heron", "fish_jump"])
	# Marlowe keeps the lighthouse; he's out on the rock most days.
	var md: Dictionary = GameState.npcs.get("marlowe", {})
	if not md.is_empty():
		var m := Npc.new()
		m.map = self
		m.setup("marlowe", md, cell_center(Vector2i(11, 31)))
		m.wander = 8.0
		add_child(m)
		npcs.append(m)
	if not GameState.run["flags"].has("lake_seen"):
		GameState.run["flags"]["lake_seen"] = true
		player.frozen = true
		await say([{"text": "The lake is bigger than the whole town. Wind combs the surface silver. Finn's hut sits on stilts at the end of the dock; the mill wheel turns on the far shore, and past it the lighthouse keeps its own counsel."}])
		player.frozen = false


## A building whose sprite has water in it: placed at full scale, the cells
## under it stay water (it's "in" the lake), and the door cell is a dock plank.
func _shore_building(name: String, c: Vector2i, interior: String, hint: String, door: Vector2i, animated := false) -> void:
	if not Art.has("buildings", name):
		return
	var info := Art.info("buildings", name)
	var fw := int(info.get("cell_w", info.get("w", 64)))
	var fh := int(info.get("cell_h", info.get("h", 64)))
	var w_cells := maxi(1, int(round(fw / float(TILE))))
	var h_cells := maxi(1, int(round(fh / float(TILE))))
	var base := Vector2i(c.x, c.y + h_cells - 1)
	if animated and int(info.get("frames", 1)) > 1:
		var a := AnimatedSprite2D.new()
		a.sprite_frames = Art.frames("buildings", {"idle": name}, {"idle": 4.0})
		a.animation = "idle"
		a.position = cell_pos(c.x + w_cells / 2.0, base.y + 1)
		a.offset = Vector2(0, -fh / 2.0)
		add_child(a)
		a.play("idle")
	else:
		prop("buildings", name, base, w_cells - 1, 0.0, false, 1.0)
	for y in range(c.y + h_cells / 3, base.y + 1):
		for x in range(c.x, c.x + w_cells):
			blocked[Vector2i(x, y)] = true
	_dock(door)
	if name != "fishing_hut":
		# The sprite's own water/rock skirt: make those cells water so the shore wraps it.
		# The mill's water is keyed out of its sprite (tools/key_water.py): fill the
		# whole lower half with real water, one cell wider each side, so it reads as a pond.
		# The lighthouse's painted sea is keyed out too: its rock gets a ring of real water.
		var wide := name in ["water_mill", "lighthouse"]
		var y0 := base.y - (h_cells / 2 if name == "water_mill" else 1)
		var x0 := c.x - (1 if wide else 0)
		var x1 := c.x + w_cells + (1 if wide else 0)
		for y in range(y0, base.y + (2 if wide else 1)):
			for x in range(x0, x1):
				var wc := Vector2i(x, y)
				if wc != door and in_content(wc) and not things.has(wc):
					_water[wc] = true
					if not border_water_extra.is_empty():
						border_water_extra[wc] = true
					set_thing(wc.x, wc.y, {"type": "water", "hint": ""})
	things[door] = {"type": "door", "interior": interior, "hint": hint}



func has_npc_at(c: Vector2i) -> bool:
	for n: Npc in npcs:
		if n.visible and n.cell() == c:
			return true
	return false


func interact(c: Vector2i, thing: Dictionary) -> bool:
	for n: Npc in npcs:
		if n.visible and (n.cell() == c or (thing.is_empty() and n.position.distance_to(player.position + player.facing_dir() * 14.0) < 16.0)):
			later(_talk_marlowe)
			return true
	match str(thing.get("type", "")):
		"note":
			tell([{"text": str(thing.get("text", "..."))}])
			return true
		"water":
			if GameState.has_tool("rod"):
				_fish(c)
			return true
		"door":
			GameMap.next_interior = str(thing["interior"])
			go_to("interior", Vector2.ZERO, "up")
			return true
	return false


func _talk_marlowe() -> void:
	player.frozen = true
	var fr: Dictionary = GameState.run["friendship"]
	if not GameState.run["talked_today"].has("marlowe"):
		GameState.run["talked_today"]["marlowe"] = true
		GameState.add_friend("marlowe", 5)
	if await Story.talk(self, "marlowe"):
		player.frozen = false
		return
	if await Hearts.talk(self, "marlowe"):
		player.frozen = false
		return
	if await Quests.talk(self, "marlowe", "Marlowe"):
		player.frozen = false
		return
	if GameState.run["flags"].has("lighthouse_lit"):
		await say([{"who": "Marlowe", "text": "Lamp's lit. Fish come up to look at it after dark, fools that they are. Best night fishing in the valley now, and you did that."}])
	else:
		await say([{"who": "Marlowe", "text": "Forty years I kept that lamp. Oil ran out the winter the crystal fell. Bring me coal and a proper lens and I'll light it again."}])
	player.frozen = false


func _fish(c: Vector2i) -> void:
	fish_at(c, ["carp", "bass", "catfish", "salmon", "eel", "puffer", "goldfish", "starfin", "mooncarp"])


func draw_map() -> void:
	draw_grass(7)
	WorldGen.draw_ground_detail(self, 76, 0.12)
	draw_ground("dirt", cells_of([Rect2i(31, 21, 17, 3), Rect2i(44, 1, 3, 21), Rect2i(34, 23, 2, 12), Rect2i(10, 28, 2, 7), Rect2i(10, 30, 26, 2), FARM_EXIT, FOREST_EXIT]))
	if border_water_extra.is_empty():
		draw_water(_water, "grass")
	draw_exits()
	if pad == 0:
		draw_fence_border()

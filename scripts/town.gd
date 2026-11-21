extends GameMap
## Dreamhollow: a real town. 84×96 cells, a cobbled avenue north–south from the
## farm road to the beach road, a wide east–west avenue to the mountain bridge,
## a flagstone plaza with the fountain where they cross, the river along the
## east side with two bridges, and districts: shops north of the plaza, the
## town hall and mayor's mansion north-east, cottages and the park south-west,
## inn / library / school south-east, clinic / chapel / hunter's lodge across
## the river, an orchard on the far bank. Buildings are drawn at 0.8 scale so a
## house is a house next to a 26 px hero. Villagers follow routines (npcs.json).

const TriBatch := preload("res://scripts/tri_batch.gd")  # the plaza kerb ring: one draw call
const FOUNTAIN_LUCK_MIN := 120  # the plaza fountain's daily luck (C8 P6)
const FARM_EXIT := Rect2i(38, 0, 6, 2)
const BEACH_EXIT := Rect2i(38, 122, 6, 2)  # C14 P2: the town grew south (Harbour Row)
const MOUNTAIN_EXIT := Rect2i(82, 46, 2, 4)
const COMMONS_EXIT := Rect2i(0, 46, 1, 4)  # the west road to the community farm (Commons)
const AVENUE_X := Rect2i(38, 0, 6, 124)
const AVENUE_Y := Rect2i(0, 45, 84, 6)
const PLAZA_C := Vector2(40.5, 47.5)
const PLAZA_R := 9.5
const RIVER_X := Rect2i(68, 0, 5, 124)
const BRIDGES := [Rect2i(68, 45, 5, 6), Rect2i(68, 76, 5, 3)]
const FOUNTAIN_C := Vector2i(38, 46)
## C14 P2 (c14_03-13 #3): the Mayor's public garden north of the mansion: a hedge maze with
## a bench and a keepsake at its heart, the glass conservatory, a rose arbour, lamps on the lane.
const GARDEN := Rect2i(45, 1, 22, 13)
## C14 P2 (c14_03-13 #1): Harbour Row, the beach road's town end: the fish market, the
## chandlery and the ferry & coach office on a quay lane that runs east to a river dock.
const HARBOUR := Rect2i(8, 97, 60, 25)
const QUAY := Rect2i(10, 110, 57, 2)  # cobbled, like the avenues
const MAZE_AT := Vector2i(47, 2)
const MAZE := ["#########", "#...#...#", "#.#.#.#.#", "#.#...#.#", "#.##P##.#", "#....#..#", "###.##.##", "#.....#.#", "####.####"]
## Dirt side lanes to the districts (draw_map paints them; props and lamps keep off them, c14_03-20).
const LANES := [Rect2i(44, 11, 22, 2), Rect2i(10, 29, 28, 2), Rect2i(44, 26, 18, 2), Rect2i(60, 23, 2, 4), Rect2i(44, 62, 20, 2), Rect2i(62, 61, 2, 2), Rect2i(49, 72, 2, 2), Rect2i(60, 71, 2, 2), Rect2i(44, 73, 18, 2), Rect2i(13, 59, 25, 2), Rect2i(23, 66, 2, 2), Rect2i(13, 73, 2, 2), Rect2i(13, 75, 25, 2), Rect2i(24, 84, 14, 2), Rect2i(32, 92, 6, 2), Rect2i(73, 39, 6, 2), Rect2i(78, 39, 2, 6), Rect2i(78, 51, 2, 13), Rect2i(73, 63, 6, 2), Rect2i(78, 63, 2, 15), Rect2i(73, 77, 6, 2), Rect2i(10, 41, 28, 2)]
## The town hall's front steps: stone, not a dirt blob (c14_03-10).
const HALL_STEPS := Rect2i(53, 42, 2, 3)

## Where each villager stands when their routine says "outside" (see npcs.json
## "routine": places map to these spots; "work"/"home" are indoors).
const SPOTS := {
	"store_front": Vector2i(16, 31), "smith_front": Vector2i(30, 31), "bakery_front": Vector2i(49, 28),
	"hall_front": Vector2i(53, 44), "plaza": Vector2i(36, 52), "plaza_e": Vector2i(45, 53),
	"fountain": Vector2i(41, 51), "park": Vector2i(12, 41), "pond": Vector2i(22, 40), "well": Vector2i(31, 58),
	"wren_garden": Vector2i(13, 61), "finn_garden": Vector2i(23, 68), "lumi_garden": Vector2i(13, 76),
	"hazel_yard": Vector2i(24, 86), "inn_front": Vector2i(62, 63), "library_front": Vector2i(50, 74),
	"school_yard": Vector2i(60, 74), "clinic_front": Vector2i(78, 41), "chapel_front": Vector2i(78, 65),
	"lodge_front": Vector2i(79, 79), "orchard": Vector2i(78, 16), "river_n": Vector2i(66, 20), "river_s": Vector2i(66, 84),
	"market": Vector2i(34, 26), "stable": Vector2i(32, 93), "gate_n": Vector2i(41, 6), "gate_s": Vector2i(41, 90),
	"mansion_front": Vector2i(60, 26), "bridge": Vector2i(70, 48), "bank": Vector2i(26, 7), "beach_road": Vector2i(41, 88),
	"bench_nw": Vector2i(32, 44), "bench_ne": Vector2i(48, 44), "bench_sw": Vector2i(32, 54), "bench_se": Vector2i(48, 54),
	"clock": Vector2i(29, 36), "bandstand": Vector2i(10, 38), "workshop_front": Vector2i(11, 10),
}

var npcs: Array = []
var _orchard_watch := false
var _plaza := {}
var _river := {}
## C14 P2 (c14_03-14/-18/-20): visual footprints of placed props (anchor rows c.y-1..c.y,
## sprite width), so festival props, plaza dressing, lamps and shop clutter never stack.
var _occ := {}
## Every guarded placement: [name, Rect2i footprint, festival?] (town_props_test reads it).
var placed: Array = []
var _lane_cells := {}


func scene_id() -> String:
	return "town"


func default_spawn() -> Vector2:
	return Vector2(40 * TILE, 3 * TILE) + offset()


func build() -> void:
	cols = 84
	rows = 124  # C14 P2 (c14_03-13): Harbour Row, y 96-121, nothing north of it moved
	pad = 7
	border = {"n": "trees", "s": "trees", "w": "trees", "e": "cliff"}
	music_track = "town"
	resources_here = false  # the town's trees, rocks and hedges are scenery
	add_exit(FARM_EXIT, "farm", Vector2(36 * TILE, 56 * TILE), "up", "▲ farm")
	add_exit(BEACH_EXIT, "beach", Vector2(32 * TILE, 3 * TILE), "down", "▼ beach")
	add_exit(MOUNTAIN_EXIT, "mountain", Vector2(2 * TILE, 39 * TILE + 8), "right", "mountain ▶")
	add_exit(COMMONS_EXIT, "community_farm", Vector2(49 * TILE, 19 * TILE + 8), "left", "◀ " + Commons.short_name())
	# Plaza and river cells (the river blocks except on the bridges).
	for y in range(36, 60):
		for x in range(29, 53):
			if Vector2(x + 0.5, y + 0.5).distance_to(PLAZA_C) <= PLAZA_R:
				_plaza[Vector2i(x, y)] = true
	# The river is one body, under the bridges too (they draw on top), and it runs
	# on out through the north and south tree bands.
	var rv := river_cells()
	border_water_extra = rv
	border_water_shore = "river" if Art.has("tiles", "river_top_0") else "grass"
	for c: Vector2i in rv:
		var on_bridge := false
		for b: Rect2i in BRIDGES:
			if b.has_point(c):
				on_bridge = true
		if not on_bridge:
			_river[c] = true
			blocked[c] = true
	# Fountain (4 cells) and its things.
	for y in range(FOUNTAIN_C.y, FOUNTAIN_C.y + 3):
		for x in range(FOUNTAIN_C.x, FOUNTAIN_C.x + 5):
			blocked[Vector2i(x, y)] = true
	for x in range(FOUNTAIN_C.x, FOUNTAIN_C.x + 5):
		things[Vector2i(x, FOUNTAIN_C.y + 3)] = {"type": "fountain", "hint": "A: toss a crystal"}
	# Park pond.
	var pond := {}
	for y in range(33, 42):
		for x in range(17, 27):
			var n := WorldGen.fbm(float(x), float(y), 404, 4.0)
			if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(22, 37.5)) + n * 2.0 <= 3.4:
				pond[Vector2i(x, y)] = true
				blocked[Vector2i(x, y)] = true
	_pond = pond


var _pond := {}


func after_ready() -> void:
	WorldGen.add_backdrop(self, "hills")
	_place_buildings()
	_place_props()
	_place_people()
	place_project_site()
	# Rook's quest: grumps (or thugs) have crossed into the orchard.
	if GameState.has_quest("rook_tracks") and not GameState.quest_done("rook_tracks"):
		for i in 3:
			spawn_enemy("grump" if GameState.is_penguins() else "thug_lookout", cell_center(Vector2i(75 + i * 3, 10 + i * 6)))
		_orchard_watch = true
	if not GameState.run["flags"].has("town_seen"):
		# The arc's own town beat (p1_town / g1_town) is the arrival scene; this
		# flag lets it play. (It used to play a second intro here too.)
		GameState.run["flags"]["town_seen"] = true
	elif GameState.festival_today() != "":
		hud.toast("%s today, on the plaza!" % FestivalWords.name_of(GameState.festival_today()), Color(1, 0.9, 0.5))
	if not GameState.run["flags"].has("town_tour"):
		later(_town_tour)


## Story's arrival beat in town: the tour never runs before it (Sal can't talk before he's met).
func _arrival_beat() -> String:
	return "p1_town" if GameState.is_penguins() else "g1_town"


## A crew shop's sign-off look outside opening hours (7am to 9pm), when it has one.
func _gang(n: String) -> String:
	var t := int(GameState.run["time"]) % (24 * 60)
	if (t < 7 * 60 or t >= 21 * 60) and Art.has("buildings", n + "_closed"):
		return n + "_closed"
	return n


## A crew shop in the slot of the building it replaced (c5_02 #2): about as wide
## as that building (0.75-0.95, never a shed), its base row and door kept where
## the old one stood, so lanes and door checks don't move.
func _crew_door(name: String, c: Vector2i, interior: String, hint: String, old_name: String, old_scale: float) -> void:
	var gi := Art.info("buildings", name)
	var oi := Art.info("buildings", old_name)
	var sc := clampf(float(oi.get("w", 112)) * old_scale / maxf(1.0, float(gi.get("w", 160))), 0.75, 0.95)
	var old_h := maxi(1, int(round(float(oi.get("h", 64)) * old_scale / TILE)))
	var new_h := maxi(1, int(round(float(gi.get("h", 64)) * sc / TILE)))
	_door(_gang(name), Vector2i(c.x, c.y + old_h - new_h), interior, hint, sc)


## Crew shop fronts follow opening hours while you're in town, not only at load
## (c5_02 #7): checked every few seconds, swapped when the hour crosses 7am/9pm.
var _front_t := 0.0


func _process(delta: float) -> void:
	super(delta)
	_egg_kids(delta)
	_front_t -= delta
	if _front_t > 0.0:
		return
	_front_t = 2.0
	refresh_fronts()
	_heart_marks()


## A small heart over a nearby villager whose heart scene (or side story) is waiting (C7 P4).
var _mark_t := 0.0
func _heart_marks() -> void:
	_mark_t -= 2.0
	if _mark_t > 0.0 or player == null:
		return
	_mark_t = 6.0
	for n in npcs:
		if is_instance_valid(n) and n.visible and n.position.distance_to(player.position) < 140.0 and (Hearts.due(str(n.id)) > 0 or not SideStory.due(str(n.id)).is_empty()):
			emote(n, "heart", 1.4, -30.0)


func refresh_fronts() -> void:
	for b: Array in _bprops:
		var nm := str(b[0])
		if not nm.begins_with("gang_shop_"):
			continue
		var base := nm.trim_suffix("_closed")
		var want := _gang(base)
		if want == nm or not is_instance_valid(b[3]):
			continue
		var t := Art.tex("buildings", want)
		if t == null:
			continue
		var sp := b[3] as Sprite2D
		sp.texture = t
		sp.offset = Vector2(0, -t.get_height() / 2.0)
		b[0] = want


## The first time you're free in town, someone meets you and explains who's who.
func _town_tour() -> void:
	# Let the arrival scene finish first.
	for i in 600:
		if not is_inside_tree():
			return
		if not Dialogue.instance(get_tree()).active and player and not player.frozen and not _changing and Story.fired(_arrival_beat()):
			break
		await get_tree().process_frame
	if not is_inside_tree() or GameState.run["flags"].has("town_tour") or _changing:
		return
	if not Story.fired(_arrival_beat()):
		return  # nobody's been introduced yet: the tour waits for a later visit
	GameState.run["flags"]["town_tour"] = true
	var pen := GameState.is_penguins()
	var who := "Mayor Alder" if pen else "Sal"
	player.frozen = true
	var guide := await _tour_guide_in("alder" if pen else "sal")
	if not is_inside_tree():
		GameState.run["flags"].erase("town_tour")  # left mid-walk: the tour plays next visit
		return
	await say([
		{"who": who, "text": ("Welcome! I'm Alder, mayor of %s. Maple's store north of the plaza has seeds; Gideon's forge next door fixes tools." if pen else "Sal. I sit on this bench and watch the road, same as you would. Before you go knocking on doors in %s: Maple's store north of the plaza sells seeds and asks no questions; Gideon's forge next door fixes tools.") % GameState.names()["town"]},
		{"who": who, "text": ("The rest of us you'll meet. Your journal keeps a list (MENU > Quests)." if pen else "The rest you'll meet. Your journal keeps a list (MENU > Quests). And keep your hood up. Whoever you're hiding from, people like that have friends who travel.")},
	])
	if not is_inside_tree():
		return
	if GameState.complete_quest("meet_town"):
		hud.toast(GameMap.quest_done_text("meet_town"), Color(1, 0.9, 0.4))
	Intros.mark("alder" if pen else "sal")  # they just introduced themselves
	if guide:
		guide.walk_off()
	player.frozen = false
	for h in ["Maple's store (north of the plaza): seeds, fertiliser, bread.", "Gideon's forge (next to Maple): tool upgrades, smelting, weapons.", "Building: the Plans board by your house; Granite's quarry sells stone and brick; Orla's mill for flour; Benno's stable for horses.", "Wren (potions) and Juniper (clinic) are south and east of the plaza; the plaza board has paid jobs.", "Hazel (south-west lane) knows crops; Bram's inn has hot meals; people write to your mailbox once they know you."] + (["The town hall is where the Crystal Ward gets built."] if pen else []):
		GameState.add_hint(h)
	GameState.notify("Town guide saved: MENU → Quests → Things people said.")


## The tour's speaker walks up the avenue to you (wherever their routine had
## them), so the welcome comes from someone standing there.
func _tour_guide_in(id: String) -> Npc:
	var g: Npc = null
	for n: Npc in npcs:
		if n.id == id:
			g = n
	if g == null or player == null:
		return null
	var pc := world_to_cell(player.position)
	var to := Vector2i(-1, -1)
	var from := Vector2i(-1, -1)
	for off: Vector2i in [Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(0, 2), Vector2i(1, 0), Vector2i(-1, 0)]:
		var c := pc + off
		if in_content(c) and not blocked.has(c) and not things.has(c):
			to = c
			break
	for dy in range(5, 2, -1):  # a few steps away: the player is frozen while they walk up
		var c := pc + Vector2i(0, dy)
		if in_content(c) and not blocked.has(c):
			from = c
			break
	if to == Vector2i(-1, -1) or from == Vector2i(-1, -1):
		return null
	g.step_in(cell_center(from) if not g.visible or g.position.distance_to(player.position) > 90.0 else g.position, cell_center(to))
	var gt := 0.0
	while gt < 2.5:  # up to 2.5 s of game time on foot, then they're simply there (the player is frozen meanwhile)
		if not is_inside_tree():
			return g
		if g.position.distance_to(g.home) < 4.0:
			break
		await get_tree().process_frame
		gt += get_process_delta_time()
	g._path.clear()
	g.position = g.home
	g._target = g.home
	g.face(player.position)
	player.facing = "down" if g.position.y > player.position.y + 4 else ("up" if g.position.y < player.position.y - 4 else player.facing)
	return g


var _doors: Array[Vector2i] = []
var _door_paths := {}


## building() + remember the door so a lane gets carved to it.
## The building just placed (GameMap._bprops lives on the real map, also while baking).
func _clock_on_last() -> void:
	var real: GameMap = AmbientMotion.of(self).get_parent()
	if real._bprops.is_empty():
		return
	var e: Array = real._bprops.back()
	if e[3] is Sprite2D:
		ClockHands.attach(e[3], str(e[0]))


func _door(name: String, c: Vector2i, interior: String, hint: String, scale := 1.0) -> void:
	var d := building(name, c, interior, hint, scale)
	if d != Vector2i(-1, -1):
		_doors.append(d)


## Every door gets a 2-wide dirt lane straight down to the nearest road or lane.
func _carve_door_paths(roads: Dictionary) -> void:
	for d in _doors:
		var y := d.y
		var found := false
		while y < d.y + 14 and y < rows - 1:
			var c := Vector2i(d.x, y)
			if roads.has(c) or roads.has(c + Vector2i(1, 0)) or roads.has(c + Vector2i(-1, 0)):
				found = true
				break
			if blocked.has(c) and not things.has(c):
				break
			y += 1
		if not found:
			continue
		for yy in range(d.y, y + 1):
			_door_paths[Vector2i(d.x, yy)] = true
			_door_paths[Vector2i(d.x - 1, yy)] = true


func _place_buildings() -> void:
	if not Art.has("buildings", "store"):
		return
	# North of the plaza: shops. Scales bring the small painted buildings up to
	# village size (10+ cells wide) so nothing looks like a shed next to the hero.
	_door("store", Vector2i(10, 18), "store", "A: Maple's Mercantile")
	_door("smith", Vector2i(24, 18), "smith", "A: Blacksmith")
	if GameState.run["flags"].has("shop_1") and Art.has("buildings", "gang_shop_deuce"):
		_crew_door("gang_shop_deuce", Vector2i(45, 17), "bakery", "A: Deuce's arcade", "bakery", 1.35)
	else:
		_door("bakery", Vector2i(45, 17), "bakery", "A: Bakery", 1.35)
	_door("mansion", Vector2i(55, 13), "mansion", "A: Mayor Alder's house", 1.15)
	_door("hall", Vector2i(46, 28), "hall", "A: Town Hall")
	_clock_on_last()  # C14b P3 (c14b_13-10): the clock shows the game's time
	building("clock_tower", Vector2i(28, 32))
	_clock_on_last()
	# South-east: potions, inn, library, school.
	_door("potions", Vector2i(45, 53), "potions", "A: Potion Shop", 1.15)
	if GameState.run["flags"].has("crew_mama_rosa") and Art.has("buildings", "gang_shop_mama_rosa"):
		_crew_door("gang_shop_mama_rosa", Vector2i(57, 52), "inn", "A: Mama Rosa's kitchen", "inn", 1.15)
	else:
		_door("inn", Vector2i(57, 52), "inn", "A: the Inn", 1.15)
	_door("library", Vector2i(45, 64), "library", "A: Library", 1.35)
	_door("school", Vector2i(56, 64), "school", "A: School", 1.25)
	# South-west: cottages, Hazel's farmhouse, the stable.
	_door("cottage_a", Vector2i(8, 52), "cottage_a", "A: Wren's cottage", 1.3)
	_door("cottage_b", Vector2i(19, 59), "cottage_b", "A: Finn's cottage", 1.3)
	if GameState.run["flags"].has("shop_2") and Art.has("buildings", "gang_shop_specs"):
		_crew_door("gang_shop_specs", Vector2i(8, 66), "cottage_c", "A: Specs' net cafe", "cottage_a", 1.3)
	else:
		# Lumi & Theo have their own painter's cottage (c5_02 #5), not a copy of Wren's.
		_door("cottage_c" if Art.has("buildings", "cottage_c") else "cottage_a", Vector2i(8, 66), "cottage_c", "A: Lumi & Theo's cottage", 1.05 if Art.has("buildings", "cottage_c") else 1.3)
	_door("house", Vector2i(18, 72), "hazel_house", "A: Hazel's farmhouse")
	if GameState.run["flags"].has("crew_halo") and Art.has("buildings", "gang_shop_halo"):
		_crew_door("gang_shop_halo", Vector2i(27, 85), "stable", "A: Halo's garage", "stable", 1.25)
	else:
		_door("stable", Vector2i(27, 85), "stable", "A: Stable", 1.25)
	building("bandstand", Vector2i(6, 33))
	# South-east, past the library: the Rec Center (Rec Hall in the gangster arc).
	var rd := RecCenter.place_town(self)
	if rd != Vector2i(-1, -1):
		_doors.append(rd)
	# Across the river: clinic, chapel, Rook's lodge.
	if GameState.run["flags"].has("shop_3") and Art.has("buildings", "gang_shop_doc"):
		_crew_door("gang_shop_doc", Vector2i(74, 32), "clinic", "A: Doc's back-room clinic", "clinic", 1.35)
	else:
		_door("clinic", Vector2i(74, 32), "clinic", "A: Clinic", 1.35)
	if GameState.run["flags"].has("crew_marlene") and Art.has("buildings", "gang_shop_marlene"):
		_crew_door("gang_shop_marlene", Vector2i(75, 53), "chapel", "A: Marlene's trading post", "chapel", 1.4)
	else:
		_door("chapel", Vector2i(75, 53), "chapel", "A: Chapel", 1.4)
	_door("woodcutter_hut", Vector2i(72, 70), "lodge", "A: Rook's lodge", 1.25)
	# The working north end: a warehouse by the farm road, the bank by the smith.
	# C10b P1: the old warehouse by the farm road is Tess's workshop (furniture, rugs, yard pieces).
	_door("warehouse_a", Vector2i(7, 4), "workshop", "A: Tess's workshop", 1.25)
	_door("bank", Vector2i(26, 4), "bank", "A: Bank", 1.25)
	if Art.has("props", "town_gate"):
		prop("props", "gate2" if Art.has("props", "gate2") else "town_gate", Vector2i(FARM_EXIT.position.x - 4, 3), 12, 0.0, false, 0.8 if not Art.has("props", "gate2") else 0.5)
	# Bridges over the river (walk-under, drawn on the river).
	for b: Rect2i in BRIDGES:
		var nm := "bridge_stone2" if b.size.y > 3 else "bridge_wood2"
		var big := "bridge3_ew_a" if b.size.y > 3 else "foot3_ew_a"
		if Art.has("props", big):
			# One wide bridge sprite spanning the river (Prompts 09 dock sheet).
			walk_over(prop("props", big, Vector2i(b.position.x - 1, b.end.y - 1), b.size.x + 1, 0.0, false), b.size.y + 1)
			continue
		for y in range(b.position.y, b.end.y, 2):
			walk_over(prop("props", nm if Art.has("props", nm) else "bridge", Vector2i(b.position.x, y + 1), b.size.x - 1, 0.0, false), 3)
	# The fountain itself (animated, 4 frames) over its blocked cells.
	if WorldGen.winter_look("props", "fountain2") != "fountain2":  # frozen in winter (single frame)
		prop("props", WorldGen.winter_look("props", "fountain2"), Vector2i(FOUNTAIN_C.x, FOUNTAIN_C.y + 1), 4)
	elif Art.has("props", "fountain2"):
		WaterFeature.place(self, "props", "fountain2", Vector2i(FOUNTAIN_C.x, FOUNTAIN_C.y + 1), 4, false)  # C14b P2: still basin, flowing water
	elif Art.has("props", "fountain"):
		prop("props", WorldGen.winter_look("props", "fountain"), Vector2i(FOUNTAIN_C.x, FOUNTAIN_C.y + 2), 4)


## Festival day: the plaza fills with the season's decor, the fountain is the
## stage, and a festival stall sells the day's treat. One event per festival.
func _place_festival(fest: String) -> void:
	var P := "props"
	var pf := func(name: String, c: Vector2i, w := 0, solid := true) -> void:
		if Art.has(P, name):
			prop(P, name, c, w, 0.0, solid)
			_claim(_foot(P, name, c, w), name, true)
	var af := func(name: String, c: Vector2i, fps := 5.0) -> void:
		if Art.has(P, name):
			anim_prop(P, name, c, 0, fps)
			_claim(_foot(P, name, c, 0), name, true)
	match fest:
		"egg":
			pf.call("fest_ss_02", Vector2i(40, 38), 1); pf.call("fest_ss_06", Vector2i(39, 58), 2); pf.call("fest_ss_07", Vector2i(44, 36), 3)
			pf.call("fest_ss_09", Vector2i(33, 44)); pf.call("fest_ss_10", Vector2i(47, 44)); pf.call("fest_ss_11", Vector2i(33, 54))
			for c: Vector2i in [Vector2i(34, 48), Vector2i(46, 48), Vector2i(36, 56), Vector2i(44, 56)]:
				pf.call("fest_ss_18", c, 1, false)
			_fest_hunt = true
			if GameState.run["flags"].has("fest_egg_cells_%d" % int(GameState.run["day"])):
				_place_eggs.call_deferred()
		"lantern":
			for i in 4:
				pf.call("fest_ss_%02d" % (31 + i % 3), Vector2i(32 + i * 5, 38), 2, false)
			for c: Vector2i in [Vector2i(32, 44), Vector2i(48, 44), Vector2i(32, 54), Vector2i(48, 54)]:
				pf.call("fest_ss_%02d" % (23 + (c.x + c.y) % 8), c)
			# C14b P3 (c14b_13-11/18-02): a real 6-frame flame loop (fest_ss_80 was one still frame).
			if Art.has(P, "c14bp3_bonfire"):
				var bf := anim_prop(P, "c14bp3_bonfire", Vector2i(40, 56), 0, 8.0, true, 0.5)  # C15 P6: solid, below the stage
				if bf:
					bf.frame = int(AmbientMotion.phase(Vector2(40, 54)) * 6.0)
					bf.speed_scale = 0.95
					_claim(_foot(P, "c14bp3_bonfire", Vector2i(40, 56), 0), "c14bp3_bonfire", true)
					blocked[Vector2i(40, 56)] = true
			else:
				af.call("fest_ss_80", Vector2i(40, 56), 6.0)
			for c: Vector2i in [Vector2i(36, 60), Vector2i(44, 60)]:
				pf.call("fest_ss_72", c, 1)
		"harvest":
			pf.call("fest_fw_00", Vector2i(33, 42)); pf.call("fest_fw_01", Vector2i(47, 42)); pf.call("fest_fw_02", Vector2i(40, 38), 1)
			pf.call("fest_fw_05", Vector2i(35, 56)); pf.call("fest_fw_04", Vector2i(46, 56)); pf.call("fest_fw_13", Vector2i(39, 55), 2)
			pf.call("fest_fw_09", Vector2i(31, 48)); pf.call("fest_fw_10", Vector2i(49, 48)); pf.call("fest_fw_11", Vector2i(32, 59)); pf.call("fest_fw_12", Vector2i(49, 56))
			pf.call("fest_fw_15", Vector2i(44, 60)); pf.call("fest_fw_16", Vector2i(36, 60))
			for c: Vector2i in [Vector2i(34, 36), Vector2i(46, 36)]:
				pf.call("fest_fw_22", c, 1, false)
		"star":
			pf.call("fest_fw_62", Vector2i(40, 36), 1); pf.call("fest_fw_40", Vector2i(33, 44)); pf.call("fest_fw_39", Vector2i(47, 44))
			pf.call("fest_fw_41", Vector2i(32, 54)); pf.call("fest_fw_42", Vector2i(48, 54)); pf.call("fest_fw_43", Vector2i(35, 60)); pf.call("fest_fw_44", Vector2i(45, 60))
			pf.call("fest_fw_58", Vector2i(44, 58), 2); pf.call("fest_fw_57", Vector2i(36, 58), 1); pf.call("fest_fw_68", Vector2i(40, 60), 1, false)
		"founders":  # C15 P6: parade bunting and the harvest stalls' flags
			pf.call("fest_fw_00", Vector2i(33, 42)); pf.call("fest_fw_01", Vector2i(47, 42))
			pf.call("c15p6_parade_float" if Art.has(P, "c15p6_parade_float") else "fest_fw_02", Vector2i(40, 38), 1)
			for c: Vector2i in [Vector2i(34, 36), Vector2i(46, 36)]:
				pf.call("fest_fw_22", c, 1, false)
		"hollow":  # C15 P6: pumpkin lanterns round the plaza (the maze is the walk)
			for c: Vector2i in [Vector2i(33, 44), Vector2i(47, 44), Vector2i(32, 54), Vector2i(48, 54), Vector2i(36, 60), Vector2i(44, 60)]:
				var pk := "c15p6_pumpkin_lantern_%d" % ((c.x + c.y) % 3)
				pf.call(pk if Art.has(P, pk) else "fest_fw_09", c, 0, false)
			pf.call("fest_fw_13", Vector2i(39, 57), 2)
		"winter_market", "gift_swap":  # C15 P6: the star-festival stalls, a tree for the feast
			pf.call("fest_fw_40", Vector2i(33, 44)); pf.call("fest_fw_39", Vector2i(47, 44))
			pf.call("fest_fw_58", Vector2i(44, 58), 2); pf.call("fest_fw_57", Vector2i(36, 58), 1)
			if fest == "gift_swap":
				pf.call("fest_fw_62", Vector2i(40, 36), 1)
				pf.call("c15p6_feast_table" if Art.has(P, "c15p6_feast_table") else "fest_fw_13", Vector2i(39, 56), 2)
		"blossom":
			pf.call("fest_ss_02", Vector2i(40, 38), 1)
			for c: Vector2i in [Vector2i(34, 48), Vector2i(46, 48)]:
				pf.call("fest_ss_18", c, 1, false)
	# C15 P6 (c15_06-04 / 07-08): the crew's version of the day: a food truck, neon strings and
	# sprayed crates round the same plaza (guarded: only where the festival left room).
	if not GameState.is_penguins():
		for g: Array in [["c15p6_food_truck", Vector2i(30, 41), 3], ["c15p6_neon_string", Vector2i(36, 34), 2], ["c15p6_neon_string", Vector2i(44, 34), 2],
				["c15p6_crate_stack", Vector2i(30, 52), 1], ["c15p6_crate_stack", Vector2i(51, 52), 1], ["c15p6_neon_string", Vector2i(39, 63), 2]]:
			if Art.has(P, str(g[0])) and _free(_foot(P, str(g[0]), g[1], int(g[2]))):
				pf.call(str(g[0]), g[1], int(g[2]), str(g[0]) != "c15p6_neon_string")
	if fest in ["lantern", "star", "gift_swap"]:  # C14b P3: floating/sky lanterns and fireworks, or shooting stars (code-drawn)
		FestivalSky.make(AmbientMotion.of(self).get_parent(), "fireworks" if fest == "gift_swap" else fest, Rect2(Vector2(RIVER_X.position * TILE), Vector2(RIVER_X.size * TILE)), PLAZA_C * TILE)
	set_thing(40, 50, {"type": "festival", "fest": fest, "hint": "A: " + FestivalWords.name_of(fest)}, false)
	# C11a P5: the Animal Show (Harvest Fair) and the Best Egg table (Egg Festival).
	var sh: Array = SHOW.get(fest, [])
	if not sh.is_empty():
		var shc: Vector2i = sh[0]
		if Art.has("buildings", "fence_h"):
			for dx in [-1, 1]:
				prop("buildings", "fence_h", shc + Vector2i(dx, 0), 0, 0.0, false)
		# C11b P6 (c11b_10-12): the rivals' animals stand in the show pen behind the fence.
		if fest == "harvest":
			for pa: Array in [["animals/sheep_woolly", Vector2i(-1, -1)], ["animals/goat", Vector2i(1, -1)], ["animals/chicken2", Vector2i(-2, 0)]]:
				anim_prop(str(pa[0]), "idle", shc + (pa[1] as Vector2i), 0, 3.0, false)
		set_thing(shc.x, shc.y, {"type": "animal_show", "fest": fest, "hint": "A: " + show_title(fest)}, false)
	# C10b P1 (c10b_06_02/15): the festival stall sells the day's treat and that season's decor
	# (decor.json "stall:festival_<season>", through Shops.stall). Lantern/harvest get their own stall prop.
	var st: Array = FEST_STALL.get(fest, [])
	if not st.is_empty():
		var sc: Vector2i = st[0]
		if str(st[1]) != "":
			pf.call(str(st[1]), sc, 2)
		set_thing(sc.x, sc.y, {"type": "fest_stall", "fest": fest, "hint": "A: festival stall"}, false)


## Festival stall per festival: [cell, stall prop to place ("" = one is already there), host, season, treats].
const FEST_STALL := {
	"egg": [Vector2i(44, 36), "", "Posy", "spring", [["candy", 15], ["cake", 140]]],
	"lantern": [Vector2i(44, 41), "fest_ss_07", "Lumi", "summer", [["candy", 15], ["gift_pie", 45]]],
	"harvest": [Vector2i(44, 40), "fest_fw_58", "Hazel", "fall", [["spiced_loaf", 95], ["gift_pie", 45]]],
	"star": [Vector2i(44, 58), "", "Bram", "winter", [["hot_cocoa", 180], ["candy", 15]]],
	# C15 P6 (c15_06-11): the new festivals' stalls, each with its own treats.
	"founders": [Vector2i(44, 40), "fest_fw_58", "Maple", "summer", [["gift_pie", 45], ["cake", 140]]],
	"hollow": [Vector2i(44, 40), "fest_fw_58", "Hazel", "fall", [["candy", 15], ["spiced_loaf", 95]]],
	"winter_market": [Vector2i(44, 58), "", "Maple", "winter", [["hot_cocoa", 180], ["spiced_loaf", 95]]],
	"gift_swap": [Vector2i(44, 58), "", "Bram", "winter", [["cake", 140], ["hot_cocoa", 180]]],
}


func _fest_stall(fest: String) -> void:
	var st: Array = FEST_STALL.get(fest, [])
	if st.is_empty():
		return
	player.frozen = true
	var treats: Array = (st[4] as Array).filter(func(t: Variant) -> bool: return GameState.items.has(str((t as Array)[0])))
	var sid := "festival_" + fest if (Decor.data().get("shops", {}) as Dictionary).has("stall:festival_" + fest) else "festival_" + str(st[3])  # C15 P6 (c15_07-13)
	await Shops.stall(self, FestivalWords.fest_host(str(st[2])), "%s treats, and a few things for the house while they last." % FestivalWords.name_of(fest), treats, 0.0, sid)
	player.frozen = false


## Joining a festival's event once earns a keepsake roll from the season's prize pool (place 1 at the crop
## contest rolls with extra luck). decor.json "festival_<season>_prize"; once per festival day.
func _fest_keepsake(fest: String, key: String, luck := 0.0) -> void:
	var pool := _fest_pool(fest)
	if pool == "" or not GameState.run["flags"].has(key) or GameState.run["flags"].has(key + "_dc"):
		return
	GameState.run["flags"][key + "_dc"] = true
	DecorSources.roll_grant(self, pool, luck, "festival")


## C15 P6 (c15_07-13): the festival's own prize pool (festivals.json prize_pool) when decor.json has it,
## else the season's pool, so a second festival in a season can award its own keepsakes.
func _fest_pool(fest: String) -> String:
	var d := FestivalWords.def(fest)
	if d.is_empty():
		return ""
	var own := str(d.get("prize_pool", ""))
	if own != "" and (Decor.data().get("pools", {}) as Dictionary).has(own):
		return own
	return "festival_%s_prize" % str(d["season"])


## C15 P6 (c15_06-12): festival things only work during the festival's hours.
func _fest_open(fest: String) -> bool:
	var fh := FestivalWords.hours_of(fest)
	var h := TownHours._hour()
	if fh.y <= 0.0 or (h >= fh.x and h < fh.y):
		return true
	hud.toast(FestivalWords.not_open_text(fest, fh, h < fh.x), Color(1, 0.9, 0.6))
	return false


## C15 P6 (c15_06-01): the egg hunt's cells, seeded by the day; year 2+ hides 16 (one golden).
func _egg_cells() -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(GameState.run["day"])
	var tries := 0
	var n := FestivalWords.egg_count()
	while out.size() < n and tries < 600:
		tries += 1
		var c := Vector2i(rng.randi_range(30, 50), rng.randi_range(37, 59))
		if blocked.has(c) or things.has(c) or not _plaza.has(c) or [c.x, c.y] in out:
			continue
		out.append([c.x, c.y])
	return out


## Puts back the eggs not yet found (also after leaving the map or a reload).
func _place_eggs() -> void:
	var day := int(GameState.run["day"])
	var cells: Array = GameState.run["flags"].get("fest_egg_cells_%d" % day, [])
	var found: Array = GameState.run["flags"].get("fest_egg_found_%d" % day, [])
	var gold := FestivalWords.egg_count() > FestivalWords.EGG_COUNT
	var gang := not GameState.is_penguins()
	for i in cells.size():
		var c := Vector2i(int(cells[i][0]), int(cells[i][1]))
		if [c.x, c.y] in found or things.has(c):
			continue
		var golden := gold and i == cells.size() - 1
		things[c] = {"type": "egg", "golden": golden, "hint": FestivalWords.egg_hint(golden)}
		var nm := "fest_ss_%02d" % (12 + i % 6)
		if golden and Art.has("props", "c15p6_golden_egg"):
			nm = "c15p6_golden_egg"
		elif gang and Art.has("props", "c15p6_envelope_%d" % (i % 3)):
			nm = "c15p6_envelope_%d" % (i % 3)
		if Art.has("props", nm):
			prop("props", nm, c, 0, 0.0, false)


## C15 P6 (c15_06-02): the kids hunt too. While your hunt is on, a kid grabs one of the eggs still
## hidden every few seconds of game time (faster from year 3); find more than they do for the full prize.
var _kid_t := 0.0
func _egg_kids(delta: float) -> void:
	var fl: Dictionary = GameState.run.get("flags", {})
	var day := int(GameState.run.get("day", 0))
	if not _fest_hunt or int(fl.get("eggs_left", 0)) <= 0 or not fl.has("fest_egg_cells_%d" % day) or fl.has("fest_egg_%d_done" % day) or get_tree().paused:
		return
	_kid_t += delta
	if _kid_t < kid_every():
		return
	_kid_t = 0.0
	var eggs: Array = []
	for c: Vector2i in things:
		if str(things[c].get("type", "")) == "egg" and not bool(things[c].get("golden", false)):
			eggs.append(c)
	if eggs.size() <= 1:
		return  # the last egg is always yours to find
	eggs.sort()
	var c: Vector2i = eggs[(day + int(fl.get("fest_egg_kids_%d" % day, 0))) % eggs.size()]
	things.erase(c)
	if props.has(c):
		(props[c] as Node).queue_free()
		props.erase(c)
	_egg_found(c)
	fl["fest_egg_kids_%d" % day] = int(fl.get("fest_egg_kids_%d" % day, 0)) + 1
	fl["eggs_left"] = int(fl["eggs_left"]) - 1
	hud.toast(FestivalWords.kid_took_text(["Pip", "Wren Jr.", "Tobin", "Mabel"][int(fl["fest_egg_kids_%d" % day]) % 4]), Color(1, 0.85, 0.7))
	Music.instance(get_tree()).sfx("pickup")


static func kid_every() -> float:
	return 14.0 if FestivalWords.year_of(int(GameState.run.get("day", 1))) < 3 else 9.0


func _egg_found(c: Vector2i) -> void:
	var k := "fest_egg_found_%d" % int(GameState.run["day"])
	var found: Array = GameState.run["flags"].get(k, [])
	found.append([c.x, c.y])
	GameState.run["flags"][k] = found


var _fest_hunt := false



func _festival_event(fest: String) -> void:
	var key := "fest_%s_%d" % [fest, int(GameState.run["day"])]
	player.frozen = true
	if GameState.run["flags"].has(key):
		await say([{"who": FestivalWords.host_of(fest), "text": FestivalWords.again_text(fest, int(GameState.run["flags"].get("eggs_left", 0)) if fest == "egg" and not GameState.run["flags"].has(key + "_done") else 0)}])
		player.frozen = false
		return
	if FestivalExtra.handles(fest):  # C15 P6: the new festivals (scripts/festival_extra.gd)
		await FestivalExtra.play(self, fest, key)
		RecCenter.festival_bonus(self, key)
		await _fest_keepsake(fest, key, 4.0 if int(GameState.run["flags"].get(key + "_place", 0)) == 1 else 0.0)
		player.frozen = false
		return
	match fest:
		"egg":
			var d := Dialogue.instance(get_tree())
			d.say([{"who": FestivalWords.host_of("egg"), "text": FestivalWords.egg_call(), "choice": ["Go!", "Not now"], "key": ""}])
			await d.finished
			if d.last_choice == 0:
				var cells := _egg_cells()
				GameState.run["flags"]["fest_egg_cells_%d" % int(GameState.run["day"])] = cells
				GameState.run["flags"]["fest_egg_found_%d" % int(GameState.run["day"])] = []
				_place_eggs()
				GameState.run["flags"]["eggs_left"] = cells.size()
				hud.toast(FestivalWords.egg_go_text(cells.size()), Color(1, 0.9, 0.4))
				GameState.run["flags"][key] = true
		"lantern":
			await _lantern_float(key)
		"harvest":
			await _crop_contest(key)
		"star":
			await _star_wish(key)
	if fest != "egg":  # C15 P6 (c15_06-13): the egg hunt pays when the last egg is found
		RecCenter.festival_bonus(self, key)  # joined in: the rec chips in tickets
		await _fest_keepsake(fest, key, 4.0 if int(GameState.run["flags"].get(key + "_place", 0)) == 1 else 0.0)
	player.frozen = false


## Festival mini-games (C7 P4, Tom's #28 defaults). One try per festival day (key).
## Lantern float: pick a wish, then steer your lantern past two snags on the river.
func _lantern_float(key: String) -> void:
	var d := Dialogue.instance(get_tree())
	var host := FestivalWords.fest_host("Lumi")
	if GameState.is_penguins():
		d.say([{"who": host, "text": "Write a wish, light a lantern, let it go on the river. I won't look. What are you wishing for?", "choice": ["To stay strong (health)", "To keep going (energy)", "To see more magic (mana)", "Not now"], "key": ""}])
	else:
		d.say([{"who": host, "text": "Write it on the paper, light it, let the river take it. Nobody reads them. What's yours?", "choice": ["To stay standing (health)", "To keep moving (energy)", "An edge (mana)", "Not now"], "key": ""}])
	await d.finished
	if d.last_choice < 0 or d.last_choice > 2:
		return
	var wish: String = ["hp", "energy", "mana"][d.last_choice]
	GameState.run["flags"][key] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = int(GameState.run["day"]) * 31 + 7
	var clear := 0
	# C15 P6 (c15_06-02/03): read the water: the ripples tell you the clear side (no more coin flip);
	# from year 2 a third snag, the lantern boats.
	var snags: Array = ["a floating branch", "the old bridge post"]
	if FestivalWords.year_of(int(GameState.run["day"])) >= 2:
		snags.append("the lantern boats moored mid-river")
	var lines := ["Your lantern spins once and drifts on, a little lower.", "Your lantern slips past and sails on with the others.", "Your lantern glides through both and leads the whole river of lights out under the bridge. People clap."]
	if snags.size() == 3:
		lines = [lines[0], lines[1], "Your lantern weaves past two of them and sails on.", "Your lantern threads all three and leads the whole river of lights out under the bridge. People clap."]
	for snag: String in snags:
		var safe := rng.randi() % 2
		var c := Dialogue.instance(get_tree())
		c.say([{"text": "Your lantern bobs toward %s. %s" % [snag, ["Smooth water runs down its left side; the right side churns.", "The left side churns white; there's a smooth run on the right."][safe]], "choice": ["Nudge it left", "Nudge it right", "Let it drift"], "key": ""}])
		await c.finished
		if c.last_choice == safe or (c.last_choice == 2 and rng.randf() < 0.5):
			clear += 1
			hud.toast("Clear!", Color(1, 0.95, 0.6))
		else:
			hud.toast("Bump! It wobbles on.", Color(1, 0.8, 0.6))
	await say([{"text": lines[clear] + FestivalWords.lantern_tail()}])
	if GameState.is_night():
		Music.instance(get_tree()).sfx("fireworks", "levelup")
		if FestivalSky.of(self):
			FestivalSky.of(self).fireworks(player.position)  # C14b P3 (c14b_18-02c)
	else:
		Music.instance(get_tree()).sfx("quest_done", "levelup")
	var gain := mini(5, 3 + clear)
	GameState.grow_vital(wish, gain)
	hud.toast("Max %s +%d" % [{"hp": "health", "energy": "energy", "mana": "mana"}[wish], gain], Color(0.8, 0.9, 1.0))
	fx("sparkle", player.position + Vector2(0, -14), 14.0, 0.6)


## Crop contest: you pick the entry; judges weigh value, quality and how many
## kinds you've grown; two villagers' entries are shown beside yours.
func _crop_contest(key: String) -> void:
	var opts: Array = []
	for id in GameState.run["inventory"].keys():
		if contest_crop(str(id)) and not GameState.is_locked(str(id)) and GameState.count(str(id)) > 0:
			opts.append(str(id))
	if opts.is_empty():
		await say([{"who": "Mayor Alder", "text": "Bring a crop to enter the fair! Biggest, brightest, rarest wins."}])
		return
	# C15 P6 (c15_06-07): ranked by what the judges score (value + best quality), quality star shown.
	opts.sort_custom(func(a: String, b: String) -> bool: return GameState.item_value(a) + _peek_quality(a) > GameState.item_value(b) + _peek_quality(b))
	opts = opts.slice(0, 5)
	var names: Array = []
	for id: String in opts:
		var q := _peek_quality(id)
		names.append(GameState.item_name(id) + (" *" if q >= 20 else (" +" if q >= 10 else "")))
	names.append("Not now")
	var dc := Dialogue.instance(get_tree())
	dc.say([{"who": FestivalWords.host_of("harvest"), "text": "Which crop are you entering? The judges look at size, colour and rarity.", "choice": names, "key": ""}])
	await dc.finished
	if dc.last_choice < 0 or dc.last_choice >= opts.size():
		return
	var best: String = opts[dc.last_choice]
	var qb := entry_quality(best)  # read (and take) the best piece BEFORE the count drops (c11a_04-04)
	GameState.add_item(best, -1)
	var grown := (GameState.run.get("grown", {}) as Dictionary).size()
	var score := GameState.item_value(best) + qb + grown * 4
	# The other entries this year (seeded by the day so they don't change on reload).
	var rivals := [["Hazel", "pumpkin", 95], ["Maple", "turnip", 45], ["Tam", "melon", 120], ["Granite", "potato", 55], ["Orla", "wheat", 70]]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(GameState.run["day"]) * 13
	var a: Array = rivals[rng.randi() % rivals.size()]
	var b: Array = rivals[(rivals.find(a) + 1 + rng.randi() % (rivals.size() - 1)) % rivals.size()]
	var better := int(rival_score(int(a[2]), rng) > score) + int(rival_score(int(b[2]), rng) > score)  # C15 P6: rivals grow each year
	var place := 1 + better
	var art := ItemWords.with_article(GameState.item_name(best))
	var mine := GameState.item_name(best).to_lower()
	var own := "your own %s, a size bigger" % mine if mine in [GameState.item_name(str(a[1])).to_lower(), GameState.item_name(str(b[1])).to_lower()] else "your %s, polished till it shines" % mine
	await say([{"text": "The table is crowded: %s's %s, %s's %s, and %s." % [a[0], GameState.item_name(str(a[1])).to_lower(), b[0], GameState.item_name(str(b[1])).to_lower(), own]},
		{"who": "Mayor Alder", "text": "%s! %s" % [art.substr(0, 1).to_upper() + art.substr(1), ["First prize! The blue ribbon and %s." % Money.amount(300), "Second prize! The red ribbon and %s." % Money.amount(150), "Third prize! The yellow ribbon and %s." % Money.amount(50)][place - 1]]}])
	GameState.add_money([300, 150, 50][place - 1], "festival")
	GameState.run["flags"][key + "_place"] = place  # C10b P1: first place rolls the festival keepsake with luck
	GameState.run["flags"][key] = true
	Music.instance(get_tree()).sfx("quest_done", "coin")
	hud.toast("+%s" % Money.amount([300, 150, 50][place - 1]), Color(0.7, 0.9, 1))
	xp("farming", 40)


## C15 P6 (c15_06-03): a rival's entry grows 20 a year (+ up to 10 seeded), capped below a gold rare crop.
static func rival_score(base: int, rng: RandomNumberGenerator) -> int:
	var y := FestivalWords.year_of(int(GameState.run.get("day", 1)))
	return mini(base + 20 * (y - 1) + rng.randi() % 11, 260)


## Quality points the best piece would score, without taking it.
static func _peek_quality(id: String) -> int:
	var q: Dictionary = GameState.quality_of(id)
	if int(q.get("i", 0)) > 0:
		return 30
	return 20 if int(q.get("g", 0)) > 0 else (10 if int(q.get("s", 0)) > 0 else 0)


## C11a P5: crops and fruit only (animal goods go to the Animal Show / Best Egg table).
const CROP_FAMILIES := ["veg", "fruit", "grain", "berry", "tree", "flower", "herb", "magic", "mushroom"]


static func contest_crop(id: String) -> bool:
	var it: Dictionary = GameState.items.get(id, {})
	var ty := str(it.get("type", ""))
	if ty == "crop":
		return true
	return ty == "fruit" or (ty != "food" and ty != "material" and str(it.get("family", "")) in CROP_FAMILIES)


## Quality points of the piece you hand over: the best one (gold first, as the sell box takes
## them) is taken from the quality record before the item count drops. 30/20/10/0.
static func entry_quality(id: String) -> int:
	var q: Dictionary = GameState.quality_of(id)
	if int(q.get("i", 0)) > 0:
		return 30
	var tq := GameState.take_quality(id, 1)
	return 20 if int(tq.get("g", 0)) > 0 else (10 if int(tq.get("s", 0)) > 0 else 0)


## Animal Show / Ranch Goods (Harvest Fair), Best Egg (Egg Festival), Fleece & Feather (Lantern
## Festival): logic and tables in scripts/animal_show.gd (C11b P6). SHOW = [cell, host] per festival.
const AnimalShowLib := preload("res://scripts/animal_show.gd")
const SHOW := AnimalShowLib.STANDS


static func show_title(fest: String) -> String:
	return AnimalShowLib.stand_title(fest)


static func show_score_animal(uid: String) -> int:
	return AnimalShowLib.score_animal(uid)


static func show_score_good(id: String, quality: int) -> int:
	return AnimalShowLib.score_good(id, quality)


func _animal_show(fest: String) -> void:
	var cs: Array = AnimalShowLib.cats(fest)
	var sh: Array = SHOW.get(fest, [])
	if cs.is_empty() or sh.is_empty():
		return
	var host := FestivalWords.fest_host(str(sh[1]))  # C12 P3: Posy away -> Hazel
	player.frozen = true
	var c: Dictionary = cs[0]
	if cs.size() > 1:
		var names: Array = []
		for cc: Dictionary in cs:
			names.append(AnimalShowLib.title(cc))
		names.append("Not now")
		var d0 := Dialogue.instance(get_tree())
		d0.say([{"who": host, "text": "Two ribbon tables today. Which one?", "choice": names, "key": ""}])
		await d0.finished
		if d0.last_choice < 0 or d0.last_choice >= cs.size():
			player.frozen = false
			return
		c = cs[d0.last_choice]
	var cid := str(c["id"])
	var ttl := AnimalShowLib.title(c)
	if GameState.run["flags"].has(AnimalShowLib.done_key(fest, cid)):
		await say([{"who": host, "text": "You've had your turn at the %s today. The judges are still talking about it." % ttl}])
		player.frozen = false
		return
	var entries: Array = AnimalShowLib.animal_entries() if str(c["kind"]) == "animal" else AnimalShowLib.good_entries(c)
	if entries.is_empty():
		var why := "Bring a grown animal and you're in." if str(c["kind"]) == "animal" else "Bring something from the list and the table's yours. Gold stars win."
		await say([{"who": host, "text": "The %s! %s" % [ttl, why]}])
		player.frozen = false
		return
	var labels: Array = []
	for e: Array in entries:
		labels.append(str(e[0]))
	labels.append("Not now")
	var d := Dialogue.instance(get_tree())
	d.say([{"who": host, "text": str(c.get("ask_gang" if AnimalShowLib.gang() else "ask", "")), "choice": labels, "key": ""}])
	await d.finished
	if d.last_choice < 0 or d.last_choice >= entries.size():
		player.frozen = false
		return
	var pick := str((entries[d.last_choice] as Array)[1])
	var score := 0
	var entry := ""
	if str(c["kind"]) == "animal":
		score = AnimalShowLib.score_animal(pick)
		entry = str(Ranch.animal(pick).get("name", "your animal"))
	else:
		var qb := entry_quality(pick)
		GameState.add_item(pick, -1)
		score = AnimalShowLib.score_good(pick, qb)
		entry = "your %s%s" % ["gold-star " if qb >= 20 else ("silver-star " if qb >= 10 else ""), GameState.item_name(pick)]
	Music.instance(get_tree()).sfx("j_confirm", "pickup")
	var rv: Array = AnimalShowLib.rivals(fest, cid)
	var place: int = AnimalShowLib.place_for(score, rv)
	var amt: int = AnimalShowLib.prize(c, place)
	var lines: Array = AnimalShowLib.show_lines(c, rv, entry, place, amt, host, pick)
	var giver: Array = AnimalShowLib.giver_line(pick) if str(c["kind"]) == "animal" else []
	if not giver.is_empty():
		lines.append({"who": str(giver[1]), "text": str(giver[2])})
		GameState.add_friend(str(giver[0]), 10)
	await say(lines)
	GameState.add_money(amt, "festival")
	AnimalShowLib.record(fest, cid, place)
	DecorSources.show_prize(self, place, pick if str(c["kind"]) == "animal" else "")  # C11b P2: ribbons, trophy, Ranch.shown (own friendship bump; no pet used)
	if place == 1:
		Music.instance(get_tree()).sfx("j_treasure", "levelup")
	else:
		Music.instance(get_tree()).sfx("quest_done", "coin")
	hud.toast("+%s" % Money.amount(amt), Color(0.7, 0.9, 1))
	xp("farming", 20 if place <= 3 else 8)
	player.frozen = false


## C11a P5: the plaza market stalls Hazel and Benno keep in the morning (their routines put them at
## the market then). [stall cell, open hour, close hour, greet pen, greet gang, items [[id, price]]].
const MARKET_STALLS := {
	"benno": [Vector2i(33, 24), 9, 11, "Feed for the barn, straight off the cart.", "Feed and hay. Cash, no receipts.", [["hay", 8], ["wheat_seed", 6], ["carrot_seed", 8]]],
	"hazel": [Vector2i(33, 28), 8, 11, "Fresh from my yard: seed, hay, and good advice for free.", "Seed and hay. Advice is free; the rest isn't.", [["hay", 8], ["fertilizer", 10], ["corn_seed", 18]]],
}


static func market_open(who: String, minutes: int) -> bool:
	var st: Array = MARKET_STALLS.get(who, [])
	return not st.is_empty() and minutes >= int(st[1]) * 60 and minutes < int(st[2]) * 60 and GameState.festival_today() == ""


func _market_stall(who: String) -> void:
	var st: Array = MARKET_STALLS.get(who, [])
	if st.is_empty():
		return
	var nm := str(GameState.npcs.get(who, {}).get("name", who))
	player.frozen = true
	if GameState.festival_today() != "":
		var fn := FestivalWords.name_of(GameState.festival_today())
		await say([{"text": ("%s's stall is packed away for the %s. Find %s on the plaza." % [nm, fn, "her" if who == "hazel" else "him"]) if GameState.is_penguins() else ("Stall's shut for the %s. %s's on the plaza." % [fn, nm])}])
	elif not market_open(who, int(GameState.run["time"])):
		await say([{"text": "%s's stall is shut. %s keeps it from %d to %d in the morning." % [nm, nm, int(st[1]), int(st[2])]}])
	else:
		var items: Array = (st[5] as Array).filter(func(t: Variant) -> bool: return GameState.items.has(str((t as Array)[0])))
		var pick := 0
		if not Shops.animals_for(who).is_empty():  # fix2: Hazel sells her animals from the stall too
			var d := Dialogue.instance(get_tree())
			d.say([{"who": nm, "text": str(st[3] if GameState.is_penguins() else st[4]), "choice": ["Seed and hay", "Animals for your ranch", "Leave"], "key": ""}])
			await d.finished
			pick = d.last_choice
		if pick == 0:
			await Shops.stall(self, nm, str(st[3] if GameState.is_penguins() else st[4]), items)
		elif pick == 1:
			await Shops.animal_counter(self, who, nm)
	player.frozen = false


## Star-wish: a small gift box, a wish for a lasting little boon, and a star sent
## to one villager (a big friendship boost); everyone you know still gets +10.
func _star_wish(key: String) -> void:
	await say([{"who": FestivalWords.fest_host("Posy"), "text": "Star Festival! Everyone gives one gift. Here's yours." if GameState.is_penguins() else "Gift swap. One each, no regifting. Here's yours."}, {"text": "A small box. Inside: something somebody thought you'd like."}])
	var gift: String = ["heart_fruit", "stamina_root", "mana_berry", "cake", "wine", "gold_bar"][int(GameState.run["day"]) % 6]
	give(gift)
	GameState.run["flags"][key] = true
	var d := Dialogue.instance(get_tree())
	d.say([{"who": FestivalWords.host_of("star"), "text": FestivalWords.star_call(), "choice": ["For good health", "For tireless days", "For a little more magic", "No wish this year"] if GameState.is_penguins() else ["To stay standing", "Longer days", "An edge", "No wish this year"], "key": ""}])
	await d.finished
	if d.last_choice >= 0 and d.last_choice <= 2:
		var v: String = ["hp", "energy", "mana"][d.last_choice]
		GameState.grow_vital(v, 5)
		if FestivalSky.of(self) and player:
			FestivalSky.of(self).star_for(player.position)  # C14b P3 (c14b_18-06): the wish has its star
		hud.toast("A star falls for you. Max %s +5" % {"hp": "health", "energy": "energy", "mana": "mana"}[v], Color(0.9, 0.9, 1))
	var known: Array = []
	for id in GameState.npcs:
		if int(GameState.run["friendship"].get(str(id), 0)) > 0 and not GameState.run["flags"].has(str(id) + "_gone") and Hearts.data().has(str(id)) and str(Hearts.data()[str(id)].get("arc", "")) in ["", str(GameState.run.get("arc", ""))]:
			known.append(str(id))
	known.sort_custom(func(a: String, b: String) -> bool: return int(GameState.run["friendship"].get(a, 0)) > int(GameState.run["friendship"].get(b, 0)))
	var page := 0  # C15 P6 (c15_06-08): every villager you know, four at a time (closest first)
	while not known.is_empty():
		var shown: Array = known.slice(page * 4, page * 4 + 4)
		var nm: Array = []
		for id: String in shown:
			nm.append(str(GameState.npcs[id]["name"]))
		var more := known.size() > (page + 1) * 4
		if more:
			nm.append("More...")
		nm.append("Keep it for myself")
		var s2 := Dialogue.instance(get_tree())
		s2.say([{"text": "Your paper star is in your hand. Who should it go to?", "choice": nm, "key": ""}])
		await s2.finished
		if more and s2.last_choice == shown.size():
			page += 1
			continue
		if s2.last_choice >= 0 and s2.last_choice < shown.size():
			var who: String = shown[s2.last_choice]
			GameState.add_friend(who, 30)
			hud.toast("%s +30: they'll keep that star." % str(GameState.npcs[who]["name"]), Color(1, 0.8, 0.9))
		break
	# Everyone you know, who's still here.
	for id in GameState.npcs:
		if int(GameState.run["friendship"].get(str(id), 0)) > 0 and not GameState.run["flags"].has(str(id) + "_gone"):
			GameState.add_friend(str(id), 10)
	hud.toast("Everyone you know +10 friendship", Color(1, 0.8, 0.9))
	var pt := Romance.partner()  # C15 P6 (c15_06-16): your partner watches the sky with you
	if pt != "" and GameState.npcs.has(pt):
		GameState.add_friend(pt, 20)
		hud.toast("%s squeezes your hand under the stars. +20" % str(GameState.npcs[pt]["name"]), Color(1, 0.75, 0.85))


## Tall iron lamps on the avenues (Prompts 09 plaza sheet), the old lamp otherwise.
func _lamp_name(n: int) -> String:
	var nm := "lamp2_tall_%d" % (n % 6)
	return nm if Art.has("props", nm) else "lamp"


## The community board: today's three jobs, who posted them and what they pay.
func _board() -> void:
	player.frozen = true
	var jobs := GameState.board_today()
	var d := Dialogue.instance(get_tree())
	var ch: Array = ["Calendar"]  # C15 P1 (c15_01-01/05): the season calendar first
	for j in jobs:
		var taken := GameState.has_quest(str(j["id"]))
		var poster := str(GameState.npcs[str(j["npc"])]["name"])
		if not Intros.met(str(j["npc"])) and str(GameState.npcs[str(j["npc"])].get("role", "")) != "":
			poster += " (%s)" % str(GameState.npcs[str(j["npc"])]["role"]).to_lower()  # who's that? the board says
		ch.append("%s%s: %s · ◆%d" % ["✓ " if taken else "", poster, ItemWords.count_id(str(j["item"]), int(j["n"])), int(j["crystals"])])
	ch.append("Close")
	var head := "Pinned today (%s %d). Bring the goods to whoever posted it: a week for goods, two for crop orders." % [GameState.season().capitalize(), GameState.day_of_season()]
	if jobs.is_empty():
		head = "Nothing pinned today (%s %d). New jobs go up every morning." % [GameState.season().capitalize(), GameState.day_of_season()]
	var notes := RecCenter.board_notes()  # what's on at the rec / community farm
	if notes != "":
		head += "\nAlso pinned: " + notes
	head += "\n" + Calendar.board_notices(7)  # C15 P1: coming up this week
	d.say([{"who": "Community Board", "text": head, "choice": ch, "key": ""}])
	await d.finished
	if d.last_choice == 0:
		player.frozen = false
		CalendarScreen.open(get_tree())
		return
	if d.last_choice >= 1 and d.last_choice <= jobs.size():
		var j: Dictionary = jobs[d.last_choice - 1]
		if GameState.has_quest(str(j["id"])):
			hud.toast("You already took that one.")
		else:
			GameState.board_accept(j)
			hud.toast("Job taken: %s for %s." % [ItemWords.count_id(str(j["item"]), int(j["n"])), str(GameState.npcs[str(j["npc"])]["name"])], Color(1, 0.9, 0.4))
			Music.instance(get_tree()).sfx("pickup")
	player.frozen = false


## Each home and shop gets a few props that say who lives/works there, placed
## just outside its door line (never on the lane). Names fall back if a sprite
## is missing from the manifest.
func _dress_buildings() -> void:
	var pl := func(name: String, c: Vector2i, w := 0, solid := true) -> void:
		name = WorldGen.winter_look("props", name)  # winter planters
		if Art.has("props", name) and not things.has(c) and not _door_paths.has(c) and not _river.has(c) and not _river.has(c + Vector2i(w, 0)):
			_pp("props", name, c, w, 0.0, solid, 4.0 if int(Art.info("props", name).get("frames", 1)) > 1 else 0.0)
	# Crew shops that moved in dress their own lot (c5_02 #2): a crew flag in the gangster arc.
	var crew := func(flag: String) -> bool:
		return not GameState.is_penguins() and GameState.run["flags"].has(flag)
	# General store (Maple): crates of stock, a flower cart, her red mailbox.
	pl.call("crates2_a", Vector2i(9, 29)); pl.call("flower_cart", Vector2i(21, 28), 1); pl.call("mailbox2_red", Vector2i(23, 29))
	# Smithy (Gideon): anvil, tools, a fire barrel, barrels of coal.
	pl.call("forge_anvil_tools", Vector2i(35, 29), 1); pl.call("fire_barrel_0", Vector2i(24, 29)); pl.call("barrel2_b", Vector2i(36, 28))
	# Bakery (Posy): bread cart and bottle crates.
	if crew.call("shop_1"):  # Deuce's arcade: a vending machine and his scooter
		pl.call("vend_purple", Vector2i(42, 27)); pl.call("veh_scooter_side", Vector2i(55, 27))
	else:
		pl.call("bread_cart", Vector2i(42, 27), 1); pl.call("bottle_crate_a", Vector2i(55, 27))
	# Mansion (Alder): iron fence posts, planters, the founder statue is on the plaza.
	pl.call("planter2_1", Vector2i(55, 25)); pl.call("planter2_2", Vector2i(68, 25)); pl.call("lamp2_short_0", Vector2i(57, 26)); pl.call("lamp2_short_1", Vector2i(66, 26))
	# Town hall: lamps and benches either side of the steps.
	pl.call("bench2_iron_a", Vector2i(44, 43), 1); pl.call("bench2_iron_b", Vector2i(60, 43), 1)
	# Potions (Wren): cauldron, herb planters, preserves.
	pl.call("cauldron2", Vector2i(44, 60)); pl.call("planter2_3", Vector2i(58, 60)); pl.call("preserves_jar", Vector2i(46, 60))  # off the potion lane (c14_03-20)
	# Inn (Bram): barrels, a card table, umbrellas for the terrace.
	pl.call("barrel2_a", Vector2i(56, 61)); pl.call("barrel_a", Vector2i(57, 62)); pl.call("umbrella_red", Vector2i(64, 61), 1); pl.call("card_table", Vector2i(65, 62), 1)
	# Library (Theo): a bench under a lamp.
	pl.call("bench2_wood_a", Vector2i(44, 73), 1); pl.call("lamp2_short_2", Vector2i(57, 73))
	# School: a bell post and a planter; the yard is for the kids.
	pl.call("planter2_1", Vector2i(55, 73)); pl.call("planter2_0", Vector2i(66, 73))
	# Cottages: flower beds and mailboxes in the right colours.
	pl.call("flowerbed_blue", Vector2i(7, 60), 1); pl.call("mailbox2_blue", Vector2i(17, 60))
	pl.call("flowerbed_yellow", Vector2i(18, 67), 1); pl.call("mailbox2_green", Vector2i(28, 67)); pl.call("fish_rack", Vector2i(27, 66), 1)
	if crew.call("shop_2"):  # Specs' net cafe: a drinks machine and the bins out back
		pl.call("vend_blue", Vector2i(7, 74)); pl.call("dumpster2", Vector2i(17, 74), 1)
	else:
		pl.call("flowerbed_pink", Vector2i(7, 74), 1); pl.call("mailbox2_red", Vector2i(17, 74))
	# Hazel's farmhouse: crates, hay, a trough, apple buckets.
	pl.call("haystack", Vector2i(17, 84), 1); pl.call("trough2", Vector2i(26, 84), 1); pl.call("apple_bucket2", Vector2i(28, 84)); pl.call("crates_c", Vector2i(16, 83))
	# Stable: hay feeder, hitching post.
	if crew.call("crew_halo"):  # Halo's garage: a bike waiting for parts, pallets of them
		pl.call("veh_motor_scooter_side", Vector2i(26, 93), 1); pl.call("crates_pallet", Vector2i(38, 93))
	else:
		pl.call("hay_feeder", Vector2i(26, 93), 1); pl.call("hitch_post", Vector2i(36, 93)); pl.call("horseshoe_sign", Vector2i(38, 93))
	# Clinic (Juniper): a bench and a planter of herbs.
	if crew.call("shop_3"):  # Doc's back-room clinic: a snack machine, crates of supplies
		pl.call("vend_red", Vector2i(73, 41)); pl.call("crates2_b", Vector2i(80, 41))
	else:
		pl.call("bench2_green_a", Vector2i(73, 41), 1); pl.call("planter2_3", Vector2i(80, 41))
	# Chapel: flower beds and an iron bench.
	if crew.call("crew_marlene"):  # Marlene's trading post: goods stacked outside
		pl.call("crates_pallet", Vector2i(73, 66), 1); pl.call("cart_covered", Vector2i(82, 66), 1); pl.call("bench2_iron_a", Vector2i(74, 68), 1)
	else:
		pl.call("flowerbed_red", Vector2i(73, 66), 1); pl.call("flowerbed_red", Vector2i(82, 66), 1); pl.call("bench2_iron_a", Vector2i(74, 68), 1)
	# Rook's lodge: shed fur on a tanning rack, traps, a fire barrel.
	pl.call("tanning_rack", Vector2i(75, 79), 1); pl.call("crab_pots2", Vector2i(80, 79)); pl.call("fire_barrel2", Vector2i(76, 80))
	# Bank (Ivy): two short lamps and a hedge ball.
	pl.call("lamp2_short_3", Vector2i(25, 11)); pl.call("lamp2_short_4", Vector2i(37, 11)); pl.call("hedge2_ball", Vector2i(24, 12))
	# Warehouse: crates and a covered cart.
	pl.call("crates2_b", Vector2i(7, 12)); pl.call("cart_covered", Vector2i(18, 12), 1)


func _place_props() -> void:
	_occ.clear()
	placed.clear()
	_lane_cells = cells_of(LANES + [QUAY, HALL_STEPS, RecCenter.lane_rect(), AVENUE_X, AVENUE_Y])
	for c in _plaza:
		_lane_cells.erase(c)
	var fest := GameState.festival_today()
	if fest != "":
		_place_festival(fest)  # first: its props claim their cells, permanent ones step aside (c14_03-14)
	_dress_buildings()
	# Market stalls on the plaza's north-west, a notice board, benches, flowers.
	var i := 0
	var open_hours := int(GameState.run["time"]) >= 8 * 60 and int(GameState.run["time"]) < 18 * 60
	var stalls2 := Art.has("props", "stall2_red")
	for c: Vector2i in [Vector2i(33, 24), Vector2i(33, 28), Vector2i(33, 32), Vector2i(35, 20)]:
		var col: String = ["red", "green", "blue", "yellow"][i % 4]
		if stalls2:
			prop("props", "stall2_" + col + ("" if open_hours else "_closed"), c, 1)
		else:
			prop("props", "stall_" + col, c, 1)
		for ms: String in MARKET_STALLS:  # C11a P5: Benno's feed stall and Hazel's farm stall (mornings)
			if (MARKET_STALLS[ms][0] as Vector2i) == c:
				set_thing(c.x + 1, c.y, {"type": "market_stall", "who": ms, "hint": "A: %s's stall" % str(GameState.npcs.get(ms, {}).get("name", ms))}, false)
		i += 1
	_pp("props", "board2" if Art.has("props", "board2") else ("notice_board" if Art.has("props", "notice_board") else "board"), Vector2i(35, 42), 1)
	for bx in [35, 36]:
		# On the board itself (its cells are solid) and the row in front of it,
		# so it answers whether you face it or stand right at it.
		things[Vector2i(bx, 42)] = {"type": "board", "hint": "A: community board"}
		set_thing(bx, 43, {"type": "board", "hint": "A: community board"}, false)
	_pp("props", "statue2_founder" if Art.has("props", "statue2_founder") else "statue", Vector2i(45, 42), 1)
	if Art.has("props", "statue2_horse"):  # on the park's open lawn, clear of the bandstand (c14_03-18)
		_pp("props", "statue2_horse", Vector2i(16, 41), 1)
	if Art.has("props", "statue2_crystal") and GameState.is_penguins():  # a crystal monument is penguin-arc lore (c5_02 #3)
		_pp("props", "statue2_crystal", Vector2i(58, 60), 1)
	for c: Vector2i in [Vector2i(31, 43), Vector2i(49, 43), Vector2i(31, 53), Vector2i(49, 53)]:
		var bn: String = ["bench2_wood_a", "bench2_green_a", "bench2_iron_a"][(c.x + c.y) % 3]
		_pp("props", bn if Art.has("props", bn) else ["bench_wood", "bench_green"][c.x % 2], c, 1)
	# Planters and bunting around the plaza, a hedge arch into the park.
	if Art.has("props", "planter2_0"):
		i = 0
		for c: Vector2i in [Vector2i(33, 38), Vector2i(47, 38), Vector2i(33, 58), Vector2i(47, 58)]:
			_pp("props", WorldGen.winter_look("props", "planter2_%d" % (i % 4)), c)
			i += 1
	if Art.has("props", "bunting_red"):
		i = 0
		for c: Vector2i in [Vector2i(34, 35), Vector2i(43, 35), Vector2i(34, 61), Vector2i(43, 61)]:
			prop("props", "bunting_" + ["red", "green", "blue", "purple"][i % 4], c, 2, 0.0, false)
			i += 1
	if Art.has("props", "hedge2_arch"):
		prop("props", "hedge2_arch", Vector2i(28, 44), 1, 0.0, false)
	if Art.has("props", "bed2_long_0"):
		for c: Vector2i in [Vector2i(14, 46), Vector2i(14, 49), Vector2i(26, 46), Vector2i(26, 49)]:
			_pp("props", "bed2_long_%d" % ((c.x + c.y) % 8), c, 1)
	var fb := ["flowerbed_red", "flowerbed_blue", "flowerbed_pink", "flowerbed_yellow"]
	i = 0
	for c: Vector2i in [Vector2i(30, 40), Vector2i(50, 40), Vector2i(28, 57), Vector2i(50, 56), Vector2i(36, 36), Vector2i(44, 36), Vector2i(36, 59), Vector2i(44, 59)]:  # (28,57): off the well
		_pp("props", fb[i % 4], c, 1)
		i += 1
	for c: Vector2i in [Vector2i(50, 42), Vector2i(55, 42), Vector2i(60, 25), Vector2i(63, 25)]:
		_pp("props", ["topiary_a", "topiary_b"][c.x % 2], c)
	# Lamps along both avenues.
	for y in range(6, 92, 8):
		if y > 34 and y < 62:  # the plaza lamp ring covers these (c14_03-05)
			continue
		_lamp(Vector2i(36, y), Vector2i(0, 1))
		_lamp(Vector2i(45, y), Vector2i(0, 1))
	for x in range(6, 80, 8):
		if (x > 28 and x < 54) or (x > 66 and x < 74) or x == 78:  # 78: the clinic/chapel lane crosses there
			continue
		if x == 14:
			x = 16  # not in front of the bandstand (c14_03-18)
		_lamp(Vector2i(x, 43), Vector2i(1, 0))
		_lamp(Vector2i(x, 52), Vector2i(1, 0))
	# Across the bridge the east road ran dark and flat at night (c5_02 #10): lamps there too.
	for x in [75, 82]:
		for y in [43, 52]:
			if not things.has(Vector2i(x, y)) and not _river.has(Vector2i(x, y)) and not blocked.has(Vector2i(x, y)):
				_lamp(Vector2i(x, y), Vector2i(1, 0))
	_dress_plaza()
	_garden()
	_harbour()
	# Wells, carts, crates: the working edges of town.
	if prop("buildings", "well", Vector2i(30, 56), 2):
		_claim(_foot("buildings", "well", Vector2i(30, 56), 2), "well", false)
	_pp("props", "well_stone", Vector2i(60, 32), 1)
	_pp("props", "cart_full", Vector2i(23, 31), 1)
	_pp("props", "crates_a", Vector2i(37, 24))  # off the avenue lamp (c14_03-20)
	_pp("props", "crates_b", Vector2i(37, 26))
	_pp("props", "barrel_a", Vector2i(24, 29))
	_pp("props", "hay", Vector2i(35, 89))
	prop("props", "farm_cart" if Art.has("props", "farm_cart") else "cart", Vector2i(26, 90), 1)
	_pp("props", "signpost_cluster" if Art.has("props", "signpost_cluster") else "signpost", Vector2i(44, 4))
	for c: Vector2i in [Vector2i(8, 56), Vector2i(8, 70), Vector2i(76, 68)]:
		_pp("props", "lantern_lit", c)
	# Garden fences and hedges around the cottages' plots.
	_fence_rect(Rect2i(7, 52, 12, 11), Vector2i(13, 62))
	_fence_rect(Rect2i(18, 59, 11, 10), Vector2i(23, 68))
	_fence_rect(Rect2i(7, 66, 12, 11), Vector2i(13, 76))
	_hedge_row(Rect2i(45, 14, 23, 1))
	_hedge_row(Rect2i(44, 44, 1, 0))
	_hedge_row(Rect2i(62, 28, 6, 1))
	# Orchard across the river: fruit trees in rows.
	var fk := ["apple", "cherry", "plum", "orange"]
	for y in range(6, 30, 4):
		for x in range(75, 83, 3):
			WorldGen.fruit_tree(self, Vector2i(x, y), fk[(x / 3 + y / 4) % 4])
	# Allotment flowers south-west, beehive by the orchard.
	i = 0
	for y in range(86, 93, 3):
		for x in range(8, 20, 3):
			prop("props", fb[i % 4], Vector2i(x, y), 1)
			i += 1
	# North yards: hay, crates and a cart by the warehouse; beehives by the orchard.
	prop("props", "hay", Vector2i(18, 11)); prop("props", "hay", Vector2i(19, 11))
	prop("props", "crates_pallet" if Art.has("props", "crates_pallet") else "crates_a", Vector2i(21, 12), 1)
	prop("props", "cart_covered" if Art.has("props", "cart_covered") else "cart", Vector2i(16, 13), 1)
	for c: Vector2i in [Vector2i(75, 30), Vector2i(79, 30)]:
		if Art.has("props", "beehive3_a"):
			prop("props", "beehive3_a", c)
	# The river banks (c14_03-06): reeds, cattails and a willow every few rows.
	for y in range(4, 92, 5):
		if y >= 42 and y <= 53 or y >= 73 and y <= 80:
			continue
		for side in [-1, 1]:
			var xs := 67 if side < 0 else 72
			while xs >= 66 and xs <= 73 and _river.has(Vector2i(xs, y)):
				xs += side
			var c := Vector2i(xs, y)
			if not _river.has(c) and not blocked.has(c) and (y + side * 3) % 3 != 0:
				var nm: String = ["reeds2_0", "cattail_1", "reeds2_2", "cattail_3"][(y / 5 + (side + 1)) % 4]
				if Art.has("nature", nm):
					prop("nature", nm, c, 0, 0.0, false)
	if Art.has("nature", "mid_willow") and not blocked.has(Vector2i(73, 60)):
		prop("nature", "mid_willow", Vector2i(73, 60))
	# A tiny graveyard behind the chapel.
	_fence_rect(Rect2i(74, 65, 8, 5), Vector2i(78, 65))
	# Wild bits: tree clumps and scatter where nothing else is.
	var avoid := {}
	for r: Rect2i in [Rect2i(8, 14, 60, 30), AVENUE_X.grow(2), AVENUE_Y.grow(2), Rect2i(44, 52, 24, 24), Rect2i(6, 50, 26, 44), Rect2i(72, 30, 12, 50), Rect2i(66, 0, 8, 96), Rect2i(5, 31, 24, 12), Rect2i(72, 4, 12, 28), Rect2i(6, 3, 16, 12), Rect2i(24, 3, 14, 12), GARDEN, HARBOUR, RecCenter.lot_rect()]:
		for c in cells_of([r]):
			avoid[c] = true
	for c in _plaza:
		avoid[c] = true
	WorldGen.tree_clumps(self, Rect2i(2, 2, cols - 4, rows - 4), 33, 22, avoid)
	WorldGen.scatter_props(self, Rect2i(2, 2, cols - 4, rows - 4), 34, 30, avoid)
	WorldGen.add_critters(self, Rect2i(2, 2, cols - 4, rows - 4), 35, 18, ["pigeon", "pigeon", "sparrow", "cat_orange", "cat_grey", "butterfly_blue", "butterfly_yellow", "duck"])


## C14 P2: a placed prop's visual footprint: its two bottom rows, as wide as the sprite.
func _foot(group: String, name: String, c: Vector2i, w := 0) -> Rect2i:
	var inf := Art.info(group, name)
	var fr := maxi(1, int(inf.get("frames", 1)))
	var tw := float(inf.get("cell_w", float(inf.get("w", 32)) / fr)) * 0.5
	var wc := maxi(w + 1, int(round(tw / TILE)))
	return Rect2i(c.x + (w + 1) / 2 - wc / 2, c.y - 1, wc, 2)


func _free(r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if _occ.has(Vector2i(x, y)):
				return false
	return true


func _claim(r: Rect2i, name: String, fest: bool) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_occ[Vector2i(x, y)] = true
	placed.append([name, r, fest])


## Guarded prop: skipped when its footprint meets one already placed (festival props
## first) or, if solid, its base row sits on a lane/avenue. True when placed.
func _pp(group: String, name: String, c: Vector2i, w := 0, dy := 0.0, solid := true, fps := 0.0) -> bool:
	if not Art.has(group, name):
		return false
	var r := _foot(group, name, c, w)
	if not _free(r) or things.has(c):
		return false
	if solid:
		for x in range(c.x, c.x + w + 1):
			if _lane_cells.has(Vector2i(x, c.y)):
				return false
	if fps > 0.0:
		anim_prop(group, name, c, w, fps, solid)
	else:
		prop(group, name, c, w, dy, solid)
	_claim(r, name, false)
	return true


## A street lamp: tries the cell, then one step either way along `along` (c14_03-20).
func _lamp(c: Vector2i, along: Vector2i) -> bool:
	for d in [0, 1, -1]:
		var cc: Vector2i = c + along * d
		if not blocked.has(cc) and not _river.has(cc) and _pp("props", _lamp_name(cc.x + cc.y), cc):
			return true
	return false


## C14 P2 (c14_03-04/-05/-19): the plaza is dressed: a lamp ring on the rim (it was the
## darkest place in town at night), shade trees in iron planters, curved benches facing the
## fountain, a flower kiosk and a cafe terrace, a drinking fountain and signposts at the
## avenue mouths. Festival props claim their cells first; the cross of the avenues to the
## fountain stays open (town_props_test walks it).
func _dress_plaza() -> void:
	var lane_mouths := cells_of(LANES)  # the lanes run a cell into the plaza: keep their mouths clear
	for k in 8:
		var a := deg_to_rad([30.0, 60.0, 120.0, 150.0, 210.0, 240.0, 300.0, 330.0][k])
		for rr in [8.2, 7.2, 9.2, 6.4]:  # festival props may hold the rim: step in or out
			var c := Vector2i(floori(PLAZA_C.x + cos(a) * rr), floori(PLAZA_C.y + sin(a) * rr))
			# not solid: WorldGen.clear_paths drops small solid props standing on the paving
			if not _cross(c) and not lane_mouths.has(c) and _pp("props", _lamp_name(k), c, 0, 0.0, false):
				break
	for c: Vector2i in [Vector2i(35, 42), Vector2i(46, 42), Vector2i(35, 53), Vector2i(46, 53)]:
		if not _cross(c):
			_pp("props", "c14p2_tree_planter", c)
	_pp("props", "c14p2_bench_curved", Vector2i(40, 43), 1)
	_pp("props", "c14p2_bench_curved", Vector2i(40, 53), 1)
	_pp("props", "c14p2_flower_kiosk", Vector2i(33, 51), 1)
	_pp("props", "c14p2_cafe_umbrella", Vector2i(47, 51), 1)
	_pp("props", "c14p2_cafe_table", Vector2i(46, 56), 1)
	_pp("props", "c14p2_drink_fountain", Vector2i(34, 40), 0, 0.0, false)
	for c: Vector2i in [Vector2i(37, 34), Vector2i(46, 61), Vector2i(27, 44), Vector2i(53, 53)]:
		if _pp("props", "c14p2_signpost", c):
			set_thing(c.x, c.y, {"type": "sign", "text": _sign_words(c), "hint": "A: read the sign"}, false)
	if not GameState.is_penguins():  # c14_03-09: a light gang-arc layer on the square
		for pr: Array in [["neon_open", Vector2i(52, 58)], ["payphone", Vector2i(30, 50)], ["news_box", Vector2i(51, 46)], ["manhole_closed", Vector2i(22, 18)], ["neon_sign_2", Vector2i(57, 58)]]:
			_pp("props", str(pr[0]), pr[1] as Vector2i)


func _sign_words(c: Vector2i) -> String:
	return "▲ farm   ▼ beach\n◀ %s   mountain ▶" % Commons.short_name()


func _garden() -> void:
	for y in MAZE.size():
		var row: String = MAZE[y]
		for x in row.length():
			var c := MAZE_AT + Vector2i(x, y)
			match row[x]:
				"#":
					blocked[c] = true  # drawn as clipped hedge walls by _draw_maze
				"P":
					_pp("props", "c14p2_bench_iron", c + Vector2i(0, -1), 0, 0.0, false)
					set_thing(c.x, c.y, {"type": "maze_prize", "hint": "A: look under the bench"}, false)
	var gate := MAZE_AT + Vector2i(4, MAZE.size())
	_pp("props", "c14p2_rose_arbour", gate, 0, 0.0, false)
	if Art.has("buildings", "c14p2_greenhouse"):
		building(WorldGen.winter_look("buildings", "c14p2_greenhouse"), Vector2i(59, 3))
		set_thing(62, 10, {"type": "sign", "text": "The Conservatory: the Mayor's glasshouse. Palms, ferns and orchids, open for looking.", "hint": "A: read the sign"}, false)
	for x in [47, 53, 59, 65]:
		_lamp(Vector2i(x, 10), Vector2i(1, 0))
	_pp("props", "c14p2_tree_planter", Vector2i(57, 11))
	_pp("props", "bench2_wood_a", Vector2i(45, 10), 1)


func _harbour() -> void:
	var signs := {
		"c14p2_fish_market": [Vector2i(14, 102), "Harbour Row Fish Market: the morning catch on ice, from Sel's boats and Finn's lines."],
		"c14p2_chandlery": [Vector2i(25, 102), "The Chandlery: rope, sail, lanterns and boat fittings for the marina."],
		"c14p2_ticket_office": [Vector2i(47, 102), "Ferry & Coach Office: the timetable board is still being painted."],
	}
	if not GameState.is_penguins():
		signs["c14p2_fish_market"][1] = "Docks End Fish Market: crates in, crates out, no questions on the quay."
		signs["c14p2_ticket_office"][1] = "Taxi rank office: the dispatcher's out. Back soon, the chalk says."
	for nm: String in signs:
		var at: Vector2i = signs[nm][0]
		if Art.has("buildings", nm):
			var look := nm + "_gang" if not GameState.is_penguins() and Art.has("buildings", nm + "_gang") else nm
			building(WorldGen.winter_look("buildings", look), at)
			var w := int(round(float(Art.info("buildings", nm).get("w", 112)) / TILE))
			set_thing(at.x + w / 2 + 2, 109, {"type": "sign", "text": str(signs[nm][1]), "hint": "A: read the sign"}, false)
	for x in range(12, 66, 8):
		_lamp(Vector2i(x, 112), Vector2i(1, 0))
	_pp("props", "stall2_blue" if Art.has("props", "stall2_blue") else "stall_blue", Vector2i(56, 107), 1)
	for pr: Array in [["crates2_a", Vector2i(22, 109)], ["barrel2_a", Vector2i(33, 109)], ["crab_pots2", Vector2i(34, 113)], ["c14p2_bench_iron", Vector2i(30, 114)], ["fish_rack", Vector2i(11, 109)], ["c14p2_tree_planter", Vector2i(45, 114)], ["c14p2_signpost", Vector2i(37, 113)]]:
		_pp("props", str(pr[0]), pr[1] as Vector2i)
	var sp := Vector2i(37, 113)
	if props.has(sp):
		set_thing(sp.x, sp.y, {"type": "sign", "text": "▲ the plaza   ▼ beach\n▶ river dock", "hint": "A: read the sign"}, false)
	# The river dock at the quay's east end.
	for y in [109, 110, 111, 112]:
		if Art.has("props", "dock2_mid"):
			prop("props", "dock2_mid" if y < 112 else "dock2_end", Vector2i(66, y), 0, 0.0, false)
	if Art.has("props", "buoy2_red"):
		AmbientMotion.of(self).bob(prop("props", "buoy2_red", Vector2i(70, 108), 0, 0.0, false), 1.0, 2.7, 2.5)  # C14b P3 (c14b_13-08)


## The hedge maze's keepsake: a topiary for your yard, once per save.
func _maze_prize() -> void:
	var f: Dictionary = GameState.run["flags"]
	if f.has("c14_maze_prize"):
		Dialogue.instance(get_tree()).say([{"who": "", "text": "A quiet bench in the middle of the maze. The roses smell lovely."}])
		return
	f["c14_maze_prize"] = true
	var id := "dc_y_penguin_topiary" if GameState.is_penguins() else "dc_out_topiary_b"
	DecorSources.grant(self, id, 1, "garden maze")
	Dialogue.instance(get_tree()).say([{"who": "", "text": "Tucked under the bench: a little potted topiary, with a note. \"For whoever finds the middle. Keep it growing!\""}])


## The avenue cross into the fountain (kept walkable).
func _cross(c: Vector2i) -> bool:
	return (c.x >= AVENUE_X.position.x and c.x < AVENUE_X.end.x) or (c.y >= AVENUE_Y.position.y and c.y < AVENUE_Y.end.y)


func _fence_rect(r: Rect2i, gate: Vector2i) -> void:
	if not Art.has("props", "fence2_wood_h"):
		return
	for x in range(r.position.x, r.end.x):
		for y in [r.position.y, r.end.y - 1]:
			var c := Vector2i(x, y)
			if c == gate or things.has(c) or blocked.has(c):
				continue
			prop("props", "fence2_wood_h", c)
	for y in range(r.position.y + 1, r.end.y - 1):
		for x in [r.position.x, r.end.x - 1]:
			var c := Vector2i(x, y)
			if c == gate or things.has(c) or blocked.has(c):
				continue
			prop("props", "fence2_wood_end" if Art.has("props", "fence2_wood_end") else "fence2_wood_h", c)


func _hedge_row(r: Rect2i) -> void:
	if not Art.has("props", "hedge_short"):
		return
	var cells := cells_of([r])
	var long := Art.has("props", "hedge2_h")
	var k := 0
	for c in cells:
		if things.has(c) or blocked.has(c):
			continue
		if long and r.size.x > 2:
			if k % 2 == 0:
				var last: bool = k + 1 >= cells.size()
				prop("props", "hedge2_end" if last else "hedge2_h", c, 0 if last else 1)
			k += 1
		else:
			prop("props", "hedge_short", c)


## SPOTS as placed on today's map: a spot inside a building, in the river or on
## a door (they stand in doorways otherwise) moves to the nearest open cell
## at least two cells from any door.
func _resolved_spots() -> Dictionary:
	var doors: Array = []
	for c in things.keys():
		if str(things[c].get("type", "")) in ["door", "idoor", "exit"]:
			doors.append(c)
	var out := {}
	for k in SPOTS:
		var c0: Vector2i = SPOTS[k]
		var best := c0
		var found := false
		for r in range(0, 7):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if found or maxi(absi(dx), absi(dy)) != r:
						continue
					var c := c0 + Vector2i(dx, dy)
					if c.x < 1 or c.y < 1 or c.x >= cols - 1 or c.y >= rows - 1:
						continue
					if blocked.has(c) or things.has(c) or is_water_cell(c):
						continue
					var near_door := false
					for dc: Vector2i in doors:
						if absi(dc.x - c.x) + absi(dc.y - c.y) < 2:
							near_door = true
							break
					if near_door:
						continue
					best = c
					found = true
		out[k] = best
	return out


func _place_people() -> void:
	var spots := _resolved_spots()
	for id in GameState.npcs:
		var d: Dictionary = GameState.npcs[id]
		if id == "sal" and GameState.is_penguins() and int(GameState.run["day"]) < 4:
			continue
		if (d.get("routine", []) as Array).is_empty():
			continue  # lives out in a region (lighthouse, mill, quarry...), not in town
		if GameState.run["flags"].has(str(id) + "_gone"):
			continue  # moved away when their shop was taken
		var n := Npc.new()
		n.map = self
		var spot := str(d.get("spot_name", "plaza"))
		# Routine and spots first: setup() snaps the villager to where the routine says.
		n.routine = d.get("routine", [])
		n.spots = spots
		n.setup(id, d, cell_center(spots.get(spot, spots["plaza"])))
		add_child(n)
		npcs.append(n)


func update_enemies(delta: float) -> void:
	super(delta)
	if _orchard_watch:
		var alive := 0
		for e in enemies:
			if is_instance_valid(e) and e._alive:
				alive += 1
		if alive == 0:
			_orchard_watch = false
			GameState.run["flags"]["rook_orchard_clear"] = true
			hud.toast("The orchard is clear. Tell Rook.", Color(1, 0.9, 0.4))


func has_npc_at(c: Vector2i) -> bool:
	for n: Npc in npcs:
		if n.visible and n.cell() == c:
			return true
	return false


func interact(c: Vector2i, thing: Dictionary) -> bool:
	for n: Npc in npcs:
		if not n.visible:
			continue
		if n.cell() == c or (thing.is_empty() and n.position.distance_to(player.position + player.facing_dir() * 14.0) < 16.0):
			_talk(n)
			return true
	match str(thing.get("type", "")):
		"maze_prize":
			_maze_prize()
			return true
		"shop", "hall", "door":
			if RecCenter.door_closed(self, thing) or TownHours.door_closed(self, thing):
				return true
			var id := str(thing.get("interior", thing.get("shop", "hall")))
			GameMap.next_interior = id
			go_to("interior", Vector2.ZERO, "up")
			return true
		"festival":
			if not _fest_open(str(thing.get("fest", ""))):  # C15 P6 (c15_06-12): only while it is on
				return true
			later(_festival_event.bind(str(thing.get("fest", ""))))
			return true
		"fest_stall":
			if not _fest_open(str(thing.get("fest", ""))):
				return true
			later(_fest_stall.bind(str(thing.get("fest", ""))))
			return true
		"market_stall":
			later(_market_stall.bind(str(thing.get("who", ""))))
			return true
		"animal_show":
			if not _fest_open(str(thing.get("fest", ""))):
				return true
			later(_animal_show.bind(str(thing.get("fest", ""))))
			return true
		"board":
			later(_board)
			return true
		"egg":
			things.erase(c)
			if props.has(c):
				(props[c] as Node).queue_free()
				props.erase(c)
			var left := int(GameState.run["flags"].get("eggs_left", 1)) - 1
			GameState.run["flags"]["eggs_left"] = left
			_egg_found(c)  # C15 P6 (c15_06-01): the hunt survives leaving the map / reloading
			give("candy", 1)
			if bool(thing.get("golden", false)):
				hud.toast(FestivalWords.golden_egg_text(), Color(1, 0.85, 0.3))
				DecorSources.roll_grant(self, _fest_pool("egg"), 6.0, "festival")
			if left <= 0:
				var ek := "fest_egg_%d" % int(GameState.run["day"])
				var kids := int(GameState.run["flags"].get("fest_egg_kids_%d" % int(GameState.run["day"]), 0))
				var mine := (GameState.run["flags"].get("fest_egg_found_%d" % int(GameState.run["day"]), []) as Array).size() - kids
				if mine > kids:
					hud.toast(FestivalWords.egg_prize_text(), Color(1, 0.9, 0.4))
					GameState.add_money(200, "festival")
					GameState.run["flags"][ek + "_place"] = 1
				else:
					hud.toast(FestivalWords.egg_second_text(mine, kids), Color(1, 0.9, 0.4))
					GameState.add_money(80, "festival")
				xp("foraging", 30)
				GameState.run["flags"][ek + "_done"] = true
				RecCenter.festival_bonus(self, ek)  # C15 P6 (c15_06-13): paid when the hunt is won, not on Go!
				later(_fest_keepsake.bind("egg", ek, 4.0 if mine > kids else 0.0))
			else:
				hud.toast(FestivalWords.egg_left_text(left))
			return true
		"fountain":
			if int(GameState.run["crystals"]) >= 1:
				GameState.run["crystals"] = int(GameState.run["crystals"]) - 1
				GameState.run["flags"]["fountain"] = int(GameState.run["flags"].get("fountain", 0)) + 1
				Music.instance(get_tree()).sfx("pickup")
				# C8 P6 (c8_14_10): the day's first toss really is lucky for a while.
				if int(GameState.run["flags"].get("fountain_day", 0)) != int(GameState.run["day"]):
					GameState.run["flags"]["fountain_day"] = int(GameState.run["day"])
					GameState.run["buffs"] = GameState.run.get("buffs", {})
					if GameState.buff("luck") < 1.0:
						GameState.run["buffs"]["luck"] = {"until": GameState.now_abs() + FOUNTAIN_LUCK_MIN, "amount": 1.0}
					hud.toast("Plink. You feel a little luckier.")
				else:
					hud.toast("Plink. One wish a day, the old folks say.")
			return true
	return false


# ---- talking -----------------------------------------------------------------

func _talk(n: Npc) -> void:
	emote(n, "talk", 1.0, -30.0)
	var r := GameState.run
	var id := n.id
	var name := str(GameState.npcs[id]["name"])
	var fr: Dictionary = r["friendship"]
	var sel := str(r["selected"])
	var it: Dictionary = GameState.items.get(sel, {})
	player.frozen = true
	n.face(player.position)
	if GameState.complete_quest("meet_town"):
		hud.toast(GameMap.quest_done_text("meet_town"), Color(1, 0.9, 0.4))
	var talked0: Dictionary = r["talked_today"]
	if not talked0.has(id):
		talked0[id] = true
		var before0 := GameState.friend_hearts(id)
		GameState.add_friend(id, 5)
		_heart_unlock(id, before0)
	# Main story beats first, then hearts, side quests, and only then a gift.
	if await Story.talk(self, id):
		Intros.mark(id)  # a story beat was the meeting
		player.frozen = false
		return
	if await Intros.talk(self, id):
		player.frozen = false
		return
	if await Hearts.talk(self, id):
		if GameState.can_gift(id, sel):
			hud.toast("Talk to %s again to give the %s." % [name, GameState.item_name(sel)], Color(1, 0.85, 0.9))
		player.frozen = false
		return
	if await SideStory.talk(self, id):  # C7 P4 side stories
		player.frozen = false
		return
	if await Romance.talk(self, id):
		player.frozen = false
		return
	if await Quests.talk(self, id, name):
		player.frozen = false
		return
	if GameState.can_gift(id, sel) and await confirm_gift(name, sel):
		var gain := GameState.give_gift(id, sel)  # plays the gift sound (the heart jingle on a new heart) itself
		await say([{"who": name, "text": GameState.articled(_gift_line(id, sel, gain), GameState.item_name(sel))}])
		hud.toast("%s %s%d" % [name, "+" if gain >= 0 else "", gain], Color(1, 0.8, 0.9) if gain > 0 else Color(1, 0.7, 0.7))
		player.frozen = false
		return
	gift_block_toast(id, name, sel)
	var hl := Hearts.daily(id)
	# Sal's recruitment is story, not chatter: it always comes first once the meadow is clear.
	if id == "sal" and not GameState.is_penguins() and GameState.quest_done("clear_meadow") and not r["flags"].has("sal_recruited"):
		await say(_lines(id, int(fr.get(id, 0))))
	elif hl != "" and (int(r["day"]) + GameState.friend_hearts(id)) % 2 == 0:
		await say([{"who": name, "text": hl}])
	elif Talk.data().has(id) and (id in ["pip", "wren_jr", "tobin", "mabel"] or randf() < 0.6):
		# Everyday chatter that changes with the season, weather and arc.
		await say(Talk.line(id))
	else:
		await say(_lines(id, int(fr.get(id, 0))))
	player.frozen = false


## A new heart just opened: tell the player what it unlocks (npcs.json "perks").
func _heart_unlock(id: String, before: int) -> void:
	# GameState.add_friend announces new heart perks now; just the jingle here.
	if GameState.friend_hearts(id) > before:
		Music.instance(get_tree()).sfx("levelup")


func _gift_line(id: String, item: String, gain: int) -> String:
	var own := GameState.gift_line(id, item, gain)
	if own != "":
		return own
	return "Thanks for the %s." % GameState.item_name(item)  # gift_line answers for every villager (C12 c12_08-18)


func _lines(id: String, friend: int) -> Array:
	var r := GameState.run
	var who: String = r["names"]["character"]
	var pet: String = r["names"]["pet"]
	var peng := GameState.is_penguins()
	var meadow_done := GameState.quest_done("clear_meadow")
	var season := GameState.season()
	var hearts := GameState.friend_hearts(id)
	match id:
		"maple":
			if peng:
				if hearts >= 6:
					return [{"who": "Maple", "text": "You know, %s, I saw that light land in your field. I didn't tell anyone. Some things you keep for the people who earn them." % who}]
				if season == "fall":
					return [{"who": "Maple", "text": "Pumpkin seeds are in. Nine days to fill out, so get them in before the 20th or the frost wins."}]
				return [{"who": "Maple", "text": "Morning! Turnips grow fast, strawberries pay better. And bring %s by sometime, I've got a bone with their name on it." % pet}]
			if hearts >= 6:
				return [{"who": "Maple", "text": "I had a brother who ran from something once. He never said what. I never asked. He's a baker in the capital now. Just... saying."}]
			return [{"who": "Maple", "text": "New face, old plot. Seeds are on the left. Pay when you can. I mean that."}]
		"gideon":
			if GameState.tool_tier("axe") >= 2 or GameState.tool_tier("pickaxe") >= 2:
				return [{"who": "Gideon", "text": "Iron holds. Steel holds better. Bring me bars and I'll show you what a real edge is."}]
			if GameState.has_tool("iron_sword") or (not peng and GameState.has_tool("crowbar")):
				return [{"who": "Gideon", "text": "Keep the edge dry. Iron remembers rust the way people remember insults."}]
			if peng and meadow_done:
				return [{"who": "Gideon", "text": "Wooden sword cleared a meadow. Fine. It won't clear a mountain. Copper bars, and we'll talk."}]
			if peng:
				return [{"who": "Gideon", "text": "Wooden sword. Hm. It'll do for whatever's bleating in that meadow. For now. Bring me copper bars and we'll talk."}]
			if meadow_done:
				return [{"who": "Gideon", "text": "That bat's been somewhere. Copper bars and cash, and I'll band it so it rings."}]
			return [{"who": "Gideon", "text": "Street bat, huh. I don't ask what a farmer needs a harder swing for. Copper bars and cash, and I'll band that bat so it rings."}]
		"wren":
			if meadow_done:
				return [{"who": "Wren", "text": "The howling stopped. You did that. The bottles on the left shelf are half price for you. Don't tell Alder, he'll want it in the records."}]
			if peng:
				return [{"who": "Wren", "text": "Something fell out of the sky when you arrived, and the town's pretending it didn't. I'm not pretending. If it talks to you, tell it I said hello."}]
			return [{"who": "Wren", "text": "You've got the look of someone who sleeps with a chair under the doorknob. Red potion's on the left. The tea's for the nights."}]
		"alder":
			if hearts >= 4:
				return [{"who": "Mayor Alder", "text": "The river used to flood the south lane every spring until my grandmother had the bridges rebuilt. Towns are mostly maintenance, %s. And a little luck." % who}]
			if peng:
				return [{"who": "Mayor Alder", "text": "A good year for turnips, I'm told. Odd year for the sky. We'll take the turnips."}]
			return [{"who": "Mayor Alder", "text": "Taxes are low, questions are lower. Welcome to %s." % r["names"]["town"]}]
		"finn":
			if GameState.skill_level("fishing") >= 3:
				return [{"who": "Finn", "text": "Level three already? Try the lake at dusk. The starfin only bites when the light goes blue."}]
			return [{"who": "Finn", "text": "Cast with USE, wait for the splash, tap USE again. Patience catches more than tackle. My hut's up at the lake if you want bait."}]
		"lumi":
			return [{"who": "Lumi", "text": "The sky over your farm has the strangest colours lately. I've started painting it. Theo says it's weather. Theo is wrong." if peng else "I paint what I see. Lately I see a lot of people looking over their shoulders."}]
		"theo":
			return [{"who": "Theo", "text": "There's a book in the library about crystals that fall from the sky. Nobody's checked it out in forty years. Until this week." if peng else "Every town has a ledger of who owes what to whom. I keep ours. I don't keep names."}]
		"hazel":
			if hearts >= 6:
				return [{"who": "Hazel", "text": "I'll swing by your fields when I'm up early. Don't thank me, just keep the strawberries coming."}]
			return [{"who": "Hazel", "text": "Turnips forgive, strawberries don't. Come borrow my hoe if yours breaks."}]
		"bram":
			return [{"who": "Bram", "text": "Best soup in the valley, and it's free if you listen to my stories. Long stories. Come in out of the cold."}]
		"posy":
			if season == "winter":
				return [{"who": "Posy", "text": "Spiced loaf season! If you bring me honey I'll make the one my gran made."}]
			return [{"who": "Posy", "text": "Bread's out at seven, gone by nine. Flour from the mill at the lake, if you ever feel like running some over."}]
		"juniper":
			return [{"who": "Juniper", "text": "Eat before you work and you'll see me less. Which I'd prefer, no offence."}]
		"rook":
			if hearts >= 8:
				return [{"who": "Rook", "text": "You've got the eye now. If you're heading into the hills, say the word and I'll walk with you."}]
			return [{"who": "Rook", "text": "Tracks in the orchard again. Big ones. Not deer. Keep %s close after dark." % GameState.names().get("pet", "your pup")}]
		"pip", "tobin":
			return [{"who": GameState.npcs[id]["name"], "text": "Did you see the fountain change colour last night? Mabel says it's the crystals. Wren jr says it's frogs."}]
		"wren_jr", "mabel":
			return [{"who": GameState.npcs[id]["name"], "text": "We're not supposed to go past the bridge. So we only go past it a little."}]
		"sal":
			if meadow_done and not peng:
				if not r["flags"].has("sal_recruited"):
					r["flags"]["sal_recruited"] = true
					GameState.add_quest("gang", "Recruit your first crew in Hideout town: Deuce at his card table, Mama Rosa at the kitchen door.")
					return [
						{"who": "Sal", "text": "That was the President's man in the meadow. Not a good one, but one of his. You sent him running."},
						{"who": "Sal", "text": "I used to run with a crew in the river cities, before. If you're building something... I'm in. Call it rent."},
					]
				return [{"who": "Sal", "text": "Say the word, boss. I've got nothing but time and a bad knee."}]
			if peng:
				return [{"who": "Sal", "text": "Drifted in last week. Stayed for the quiet. The quiet's getting loud, in the east. You hear it?"}]
			return [{"who": "Sal", "text": "...You're not from here. Neither am I. Let's leave it there, yeah?"}]
	return Talk.line(id)


# ---- drawing -----------------------------------------------------------------

func draw_map() -> void:
	draw_grass(3)
	WorldGen.draw_ground_detail(self, 31, 0.08, _tended())  # c14_03-11: a tended village, no forest litter in the streets
	# Avenues: cobbles with grass edges. Side lanes to the districts are dirt.
	# Roads/lanes/door paths are fixed once the map is built: worked out on the first
	# full pass and reused by every clipped chunk bake (c5_16 #6).
	var rk := "town_roads:%d:%d" % [_doors.hash(), blocked.size()]
	var rm: Dictionary = _geom_memo.get(rk, {})
	if rm.is_empty():
		var r_roads := cells_of([AVENUE_X, AVENUE_Y, QUAY, FARM_EXIT.grow_individual(0, pad, 0, 0), BEACH_EXIT.grow_individual(0, 0, 0, pad), MOUNTAIN_EXIT.grow_individual(0, 0, pad, 0), COMMONS_EXIT.grow_individual(pad, 1, 0, 1)])  # cobbles run on through the band
		for c in _plaza:
			r_roads.erase(c)
		var lanes_base := cells_of(LANES + [HALL_STEPS, RecCenter.lane_rect()])
		var all_roads := r_roads.duplicate()
		all_roads.merge(lanes_base)
		_carve_door_paths(all_roads)
		var r_lanes := lanes_base.duplicate()
		r_lanes.merge(_door_paths)
		rm = {"roads": r_roads, "lanes": r_lanes}
		_geom_memo[rk] = rm
	var roads: Dictionary = rm["roads"]
	var lanes: Dictionary = rm["lanes"]
	draw_ground("cobble", roads)
	_draw_cobbles(roads)
	var steps := cells_of([HALL_STEPS])
	var dirt := lanes.duplicate()
	for c in steps:
		dirt.erase(c)
	draw_ground("dirt", dirt)
	_draw_plaza(steps)
	_draw_maze()
	# The river and the pond.
	if border_water_extra.is_empty():
		draw_water(_river, "river" if Art.has("tiles", "river_top_0") else "grass")
	draw_water(_pond, "grass")
	draw_exits()
	if not Art.has("buildings", "store"):
		draw_building(12, 20, 10, 8, Color("c9a86b"), Color("4f8fd0"), "GENERAL STORE")
		draw_building(25, 20, 10, 8, Color("5a5a66"), Color("3a3a44"), "BLACKSMITH")
		draw_building(46, 54, 8, 7, Color("7a5aa0"), Color("4a2e6b"), "POTIONS")
		draw_building(46, 30, 12, 11, Color("e8dcc2"), Color("2f6b4a"), "TOWN HALL")
	if pad == 0:
		draw_fence_border()


## C14 P2 (c14_03-06): the river meanders. Each row's channel shifts by up to a cell
## and is 4 to 6 wide, kept inside x 67-72 (the kept-clear river strip); it runs straight
## and 5 wide on both bridges and where it leaves the map (the border bands line up).
static func river_cells() -> Dictionary:
	var out := {}
	for y in RIVER_X.size.y:
		var calm := 4.0
		for b: Rect2i in BRIDGES:
			calm = minf(calm, maxf(0.0, maxf(b.position.y - y, y - (b.end.y - 1)) - 1.0))
		calm = minf(calm, minf(float(y), float(RIVER_X.size.y - 1 - y)) - 1.0)
		var k := clampf(calm / 4.0, 0.0, 1.0)
		var off := roundi(k * (1.4 * sin(y / 9.0) + 0.9 * sin(y / 4.3 + 1.7)))
		var wid := 5 + roundi(k * 1.2 * sin(y / 6.1 + 0.6))
		var x0 := clampi(RIVER_X.position.x + off, 67, 69)
		if y >= 26 and y <= 30:
			x0 = maxi(x0, 68)  # the mansion hedge ends at x 67
		var x1 := mini(x0 + clampi(wid, 4, 6), 73)
		for x in range(x0, x1):
			out[Vector2i(x, y)] = true
	return out


## The street grid's lawns get no ground litter (pinecones, acorns, branches): the
## tree bands and the far edges keep it.
func _tended() -> Dictionary:
	var k := "town_tended"
	if not _geom_memo.has(k):
		var d := {}
		for y in range(5, 120):
			for x in range(6, 66):
				if (x * 7 + y * 13) % 3 != 0:  # a third of the lawn cells keep their tufts and flowers
					d[Vector2i(x, y)] = true
		_geom_memo[k] = d
	return _geom_memo[k]


## C14 P2 (c14_03-02/-03): the plaza floor is four flagstone variants picked per 2x2 block
## by hash, a compass-star mosaic round the fountain, and a smooth brick kerb ring (a
## TriBatch annulus over the cell steps, lighter stone thresholds at the four avenue mouths).
func _draw_plaza(steps: Dictionary) -> void:
	Footsteps.mark(self, _plaza, "stone")
	Footsteps.mark(self, steps, "stone")
	if not Art.has("tiles", "c14p2_flag"):
		draw_ground("stone", _plaza)
		draw_ground("stone", steps)
		return
	for src: Dictionary in [_plaza, steps]:
		for c: Vector2i in src:
			Art.draw_tile(self, "tiles", "c14p2_flag", Vector2(c * TILE), plaza_flag_index(c))
	var ctr := PLAZA_C * TILE
	var mt := Art.tex("props", "c14p2_mosaic")
	if mt:
		var ms := 8.0 * TILE
		TriBatch.tex_rect(self, mt, Rect2(ctr - Vector2(ms, ms) / 2.0, Vector2(ms, ms)))
	var tb := TriBatch.new()
	var r_in := (PLAZA_R - 0.45) * TILE
	var r_out := (PLAZA_R + 0.78) * TILE
	var mid := (r_in + r_out) / 2.0
	var wid := r_out - r_in
	tb.arc(ctr, mid, 0.0, TAU, 72, Color("a3543e"), wid)
	tb.arc(ctr, mid + wid * 0.22, 0.0, TAU, 72, Color("bf6a50"), wid * 0.3)  # the cap's sunlit top
	for k in 4:  # paved thresholds where the avenues come in
		var a0 := k * PI / 2.0
		tb.arc(ctr, mid, a0 - 0.30, a0 + 0.30, 8, Color("d8c09a"), wid)
	for k in 96:  # mortar joints
		var a := k * TAU / 96.0
		var near_mouth := false
		for q in 4:
			if absf(angle_difference(a, q * PI / 2.0)) < 0.31:
				near_mouth = true
		if near_mouth:
			continue
		var dv := Vector2(cos(a), sin(a))
		tb.seg(ctr + dv * r_in, ctr + dv * r_out, Color(0.36, 0.17, 0.12, 0.7), 0.8)
	tb.arc(ctr, r_out, 0.0, TAU, 72, Color(0.22, 0.14, 0.09, 0.85), 1.2)
	tb.arc(ctr, r_in, 0.0, TAU, 72, Color(0.3, 0.18, 0.12, 0.6), 1.0)
	tb.flush(self)


## C14 P2 (c14_03-07): the avenues are warm rounded cobbles (3 variants per 2x2 block)
## over the old flat slabs, with a soft stone kerb where they meet the grass.
func _draw_cobbles(roads: Dictionary) -> void:
	if not Art.has("tiles", "c14p2_cobble"):
		return
	for c: Vector2i in roads:
		var h := absi(hash(Vector2i(c.x >> 1, c.y >> 1) + Vector2i(7, 3))) % 100
		var v := 0 if h < 60 else (1 if h < 82 else 2)
		Art.draw_tile(self, "tiles", "c14p2_cobble", Vector2(c * TILE), v * 2 + (c.x & 1) + (c.y & 1) * 6)
	var tb := TriBatch.new()
	var kerb := Color(0.33, 0.26, 0.2, 0.75)
	var lit := Color(0.85, 0.78, 0.66, 0.5)
	for c: Vector2i in roads:
		var p := Vector2(c * TILE)
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := c + d
			if roads.has(n) or _plaza.has(n):
				continue
			match d:
				Vector2i.LEFT:
					tb.rect(Rect2(p, Vector2(2, TILE)), kerb); tb.rect(Rect2(p + Vector2(2, 0), Vector2(1, TILE)), lit)
				Vector2i.RIGHT:
					tb.rect(Rect2(p + Vector2(TILE - 2, 0), Vector2(2, TILE)), kerb); tb.rect(Rect2(p + Vector2(TILE - 3, 0), Vector2(1, TILE)), lit)
				Vector2i.UP:
					tb.rect(Rect2(p, Vector2(TILE, 2)), kerb); tb.rect(Rect2(p + Vector2(0, 2), Vector2(TILE, 1)), lit)
				Vector2i.DOWN:
					tb.rect(Rect2(p + Vector2(0, TILE - 2), Vector2(TILE, 2)), kerb); tb.rect(Rect2(p + Vector2(0, TILE - 3), Vector2(TILE, 1)), lit)
	tb.flush(self)


## The garden maze's walls: clipped box hedge drawn as one TriBatch (continuous walls, a
## sunlit top, leaf speckles, a shadow where a wall meets the path; snow-capped in winter).
func _draw_maze() -> void:
	var wall := func(x: int, y: int) -> bool:
		return y >= 0 and y < MAZE.size() and x >= 0 and x < (MAZE[y] as String).length() and (MAZE[y] as String)[x] == "#"
	var winter := GameState.look_se() == "winter"
	var tb := TriBatch.new()
	for y in MAZE.size():
		for x in (MAZE[y] as String).length():
			if not wall.call(x, y):
				continue
			var p := Vector2((MAZE_AT + Vector2i(x, y)) * TILE)
			tb.rect(Rect2(p, Vector2(TILE, TILE)), Color("335a27"))
			tb.rect(Rect2(p, Vector2(TILE, TILE - 5)), Color("4f8236") if not winter else Color("e8eef4"))
			if not wall.call(x, y - 1):
				tb.rect(Rect2(p, Vector2(TILE, 2)), Color("7fb054") if not winter else Color("ffffff"))
			if not wall.call(x, y + 1):
				tb.rect(Rect2(p + Vector2(0, TILE), Vector2(TILE, 3)), Color(0.1, 0.18, 0.08, 0.35))
			if not wall.call(x - 1, y):
				tb.rect(Rect2(p, Vector2(1.5, TILE)), Color("2c4d22"))
			if not wall.call(x + 1, y):
				tb.rect(Rect2(p + Vector2(TILE - 1.5, 0), Vector2(1.5, TILE)), Color("2c4d22"))
			for k in 5:
				var h := absi(hash(Vector3i(x, y, k)))
				var q := p + Vector2(1 + h % 13, 1 + (h / 13) % 9)
				tb.rect(Rect2(q, Vector2(2, 2)), Color("6fa047") if not winter else Color("cfd9e2"))
	tb.flush(self)


## Flagstone cell index in tiles/c14p2_flag: variant (plain/cracked/moss/brass) per 2x2 block.
static func plaza_flag_index(c: Vector2i) -> int:
	var h := absi(hash(Vector2i(c.x >> 1, c.y >> 1))) % 100
	var v := 0 if h < 58 else (1 if h < 76 else (2 if h < 92 else 3))
	return v * 2 + (c.x & 1) + (c.y & 1) * 8


## The avenues are cobbled out through the band (draw_map); the base dirt corridor would cover them.
func draw_corridor(_cells: Dictionary) -> void:
	pass

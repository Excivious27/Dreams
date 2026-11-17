extends GameMap
## Dreamhollow: a real town. 84×96 cells, a cobbled avenue north–south from the
## farm road to the beach road, a wide east–west avenue to the mountain bridge,
## a flagstone plaza with the fountain where they cross, the river along the
## east side with two bridges, and districts: shops north of the plaza, the
## town hall and mayor's mansion north-east, cottages and the park south-west,
## inn / library / school south-east, clinic / chapel / hunter's lodge across
## the river, an orchard on the far bank. Buildings are drawn at 0.8 scale so a
## house is a house next to a 26 px hero. Villagers follow routines (npcs.json).

const FARM_EXIT := Rect2i(38, 0, 6, 2)
const BEACH_EXIT := Rect2i(38, 94, 6, 2)
const MOUNTAIN_EXIT := Rect2i(82, 46, 2, 4)
const AVENUE_X := Rect2i(38, 0, 6, 96)
const AVENUE_Y := Rect2i(0, 45, 84, 6)
const PLAZA_C := Vector2(40.5, 47.5)
const PLAZA_R := 9.5
const RIVER_X := Rect2i(68, 0, 5, 96)
const BRIDGES := [Rect2i(68, 45, 5, 6), Rect2i(68, 76, 5, 3)]
const FOUNTAIN_C := Vector2i(38, 46)

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
	"mansion_front": Vector2i(60, 26), "bridge": Vector2i(70, 52), "beach_road": Vector2i(41, 88),
	"bench_nw": Vector2i(32, 44), "bench_ne": Vector2i(48, 44), "bench_sw": Vector2i(32, 54), "bench_se": Vector2i(48, 54),
	"clock": Vector2i(29, 36), "bandstand": Vector2i(10, 38),
}

var npcs: Array = []
var _orchard_watch := false
var _plaza := {}
var _river := {}


func scene_id() -> String:
	return "town"


func default_spawn() -> Vector2:
	return Vector2(40 * TILE, 3 * TILE)


func build() -> void:
	cols = 84
	rows = 96
	pad = 7
	border = {"n": "trees", "s": "trees", "w": "trees", "e": "cliff"}
	music_track = "town"
	resources_here = false  # the town's trees, rocks and hedges are scenery
	add_exit(FARM_EXIT, "farm", Vector2(36 * TILE, 56 * TILE), "up", "▲ farm")
	add_exit(BEACH_EXIT, "beach", Vector2(32 * TILE, 3 * TILE), "down", "▼ beach")
	add_exit(MOUNTAIN_EXIT, "mountain", Vector2(2 * TILE, 39 * TILE + 8), "right", "mountain ▶")
	# Plaza and river cells (the river blocks except on the bridges).
	for y in range(36, 60):
		for x in range(29, 53):
			if Vector2(x + 0.5, y + 0.5).distance_to(PLAZA_C) <= PLAZA_R:
				_plaza[Vector2i(x, y)] = true
	for c: Vector2i in cells_of([RIVER_X]):
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
	# Rook's quest: grumps (or thugs) have crossed into the orchard.
	if GameState.has_quest("rook_tracks") and not GameState.quest_done("rook_tracks"):
		for i in 3:
			spawn_enemy("grump" if GameState.is_penguins() else "thug_speedster", cell_center(Vector2i(75 + i * 3, 10 + i * 6)))
		_orchard_watch = true
	if not GameState.run["flags"].has("town_seen"):
		GameState.run["flags"]["town_seen"] = true
		_arrival.call_deferred()
	elif GameState.festival_today() != "":
		hud.toast("%s today, on the plaza!" % GameState.festival_name(GameState.festival_today()), Color(1, 0.9, 0.5))


var _doors: Array[Vector2i] = []
var _door_paths := {}


## building() + remember the door so a lane gets carved to it.
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
	_door("store", Vector2i(10, 18), "store", "A: General Store")
	_door("smith", Vector2i(24, 18), "smith", "A: Blacksmith")
	_door("bakery", Vector2i(45, 17), "bakery", "A: Bakery", 1.35)
	_door("mansion", Vector2i(55, 13), "mansion", "A: Mayor Alder's house", 1.15)
	_door("hall", Vector2i(46, 28), "hall", "A: Town Hall")
	building("clock_tower", Vector2i(28, 32))
	# South-east: potions, inn, library, school.
	_door("potions", Vector2i(45, 53), "potions", "A: Potion Shop", 1.15)
	_door("inn", Vector2i(57, 52), "inn", "A: the Inn", 1.15)
	_door("library", Vector2i(45, 64), "library", "A: Library", 1.35)
	_door("school", Vector2i(56, 64), "school", "A: School", 1.25)
	# South-west: cottages, Hazel's farmhouse, the stable.
	_door("cottage_a", Vector2i(8, 52), "cottage_a", "A: Wren's cottage", 1.3)
	_door("cottage_b", Vector2i(19, 59), "cottage_b", "A: Finn's cottage", 1.3)
	_door("cottage_a", Vector2i(8, 66), "cottage_c", "A: Lumi & Theo's cottage", 1.3)
	_door("house", Vector2i(18, 72), "hazel_house", "A: Hazel's farmhouse")
	_door("stable", Vector2i(27, 85), "stable", "A: Stable", 1.25)
	building("bandstand", Vector2i(6, 33))
	# Across the river: clinic, chapel, Rook's lodge.
	_door("clinic", Vector2i(74, 32), "clinic", "A: Clinic", 1.35)
	_door("chapel", Vector2i(75, 53), "chapel", "A: Chapel", 1.4)
	_door("woodcutter_hut", Vector2i(72, 70), "lodge", "A: Rook's lodge", 1.25)
	# The working north end: a warehouse by the farm road, the bank by the smith.
	building("warehouse_a", Vector2i(7, 4), "", "", 1.25)
	_door("bank", Vector2i(26, 4), "bank", "A: Bank", 1.25)
	if Art.has("props", "town_gate"):
		prop("props", "gate2" if Art.has("props", "gate2") else "town_gate", Vector2i(FARM_EXIT.position.x - 4, 3), 12, 0.0, false, 0.8 if not Art.has("props", "gate2") else 0.5)
	# Bridges over the river (walk-under, drawn on the river).
	for b: Rect2i in BRIDGES:
		var nm := "bridge_stone2" if b.size.y > 3 else "bridge_wood2"
		var big := "bridge3_ew_a" if b.size.y > 3 else "foot3_ew_a"
		if Art.has("props", big):
			# One wide bridge sprite spanning the river (Prompts 09 dock sheet).
			prop("props", big, Vector2i(b.position.x - 1, b.end.y - 1), b.size.x + 1, 0.0, false)
			continue
		for y in range(b.position.y, b.end.y, 2):
			prop("props", nm if Art.has("props", nm) else "bridge", Vector2i(b.position.x, y + 1), b.size.x - 1, 0.0, false)
	# The fountain itself (animated, 4 frames) over its blocked cells.
	if Art.has("props", "fountain2"):
		anim_prop("props", "fountain2", Vector2i(FOUNTAIN_C.x, FOUNTAIN_C.y + 1), 4, 5.0)
	elif Art.has("props", "fountain"):
		prop("props", "fountain", Vector2i(FOUNTAIN_C.x, FOUNTAIN_C.y + 2), 4)


## Festival day: the plaza fills with the season's decor, the fountain is the
## stage, and a festival stall sells the day's treat. One event per festival.
func _place_festival(fest: String) -> void:
	var P := "props"
	var pf := func(name: String, c: Vector2i, w := 0, solid := true) -> void:
		if Art.has(P, name):
			prop(P, name, c, w, 0.0, solid)
	var af := func(name: String, c: Vector2i, fps := 5.0) -> void:
		if Art.has(P, name):
			anim_prop(P, name, c, 0, fps)
	match fest:
		"egg":
			pf.call("fest_ss_02", Vector2i(40, 38), 1); pf.call("fest_ss_06", Vector2i(39, 58), 2); pf.call("fest_ss_07", Vector2i(44, 36), 3)
			pf.call("fest_ss_09", Vector2i(33, 44)); pf.call("fest_ss_10", Vector2i(47, 44)); pf.call("fest_ss_11", Vector2i(33, 54))
			for c: Vector2i in [Vector2i(34, 48), Vector2i(46, 48), Vector2i(36, 56), Vector2i(44, 56)]:
				pf.call("fest_ss_18", c, 1, false)
			_fest_hunt = true
		"lantern":
			for i in 4:
				pf.call("fest_ss_%02d" % (31 + i % 3), Vector2i(32 + i * 5, 38), 2, false)
			for c: Vector2i in [Vector2i(32, 44), Vector2i(48, 44), Vector2i(32, 54), Vector2i(48, 54)]:
				pf.call("fest_ss_%02d" % (23 + (c.x + c.y) % 8), c)
			af.call("fest_ss_80", Vector2i(40, 54), 6.0)
			for c: Vector2i in [Vector2i(36, 60), Vector2i(44, 60)]:
				pf.call("fest_ss_72", c, 1)
		"harvest":
			pf.call("fest_fw_00", Vector2i(33, 42)); pf.call("fest_fw_01", Vector2i(47, 42)); pf.call("fest_fw_02", Vector2i(40, 38), 1)
			pf.call("fest_fw_05", Vector2i(34, 56)); pf.call("fest_fw_04", Vector2i(46, 56)); pf.call("fest_fw_13", Vector2i(39, 55), 2)
			pf.call("fest_fw_09", Vector2i(31, 48)); pf.call("fest_fw_10", Vector2i(49, 48)); pf.call("fest_fw_11", Vector2i(31, 56)); pf.call("fest_fw_12", Vector2i(49, 56))
			pf.call("fest_fw_15", Vector2i(44, 60)); pf.call("fest_fw_16", Vector2i(36, 60))
			for c: Vector2i in [Vector2i(34, 36), Vector2i(46, 36)]:
				pf.call("fest_fw_22", c, 1, false)
		"star":
			pf.call("fest_fw_62", Vector2i(40, 36), 1); pf.call("fest_fw_40", Vector2i(33, 44)); pf.call("fest_fw_39", Vector2i(47, 44))
			pf.call("fest_fw_41", Vector2i(32, 54)); pf.call("fest_fw_42", Vector2i(48, 54)); pf.call("fest_fw_43", Vector2i(35, 60)); pf.call("fest_fw_44", Vector2i(45, 60))
			pf.call("fest_fw_58", Vector2i(44, 58), 2); pf.call("fest_fw_57", Vector2i(36, 58), 1); pf.call("fest_fw_68", Vector2i(40, 60), 1, false)
	set_thing(40, 50, {"type": "festival", "fest": fest, "hint": "A: " + GameState.festival_name(fest)}, false)


var _fest_hunt := false



func _festival_event(fest: String) -> void:
	var key := "fest_%s_%d" % [fest, int(GameState.run["day"])]
	player.frozen = true
	if GameState.run["flags"].has(key):
		await say([{"who": "Mayor Alder", "text": "You've had your turn. Enjoy the %s!" % GameState.festival_name(fest).to_lower()}])
		player.frozen = false
		return
	match fest:
		"egg":
			var d := Dialogue.instance(get_tree())
			d.say([{"who": "Mayor Alder", "text": "The egg hunt! Twelve eggs hidden round the plaza. Find them before the kids do.", "choice": ["Go!", "Not now"], "key": ""}])
			await d.finished
			if d.last_choice == 0:
				var found := 0
				var rng := RandomNumberGenerator.new()
				rng.seed = int(GameState.run["day"])
				for i in 12:
					var c := Vector2i(rng.randi_range(30, 50), rng.randi_range(37, 59))
					if blocked.has(c) or things.has(c) or not _plaza.has(c):
						continue
					found += 1
					things[c] = {"type": "egg", "hint": "A: an egg!"}
					if Art.has("props", "fest_ss_%02d" % (12 + i % 6)):
						prop("props", "fest_ss_%02d" % (12 + i % 6), c, 0, 0.0, false)
				GameState.run["flags"]["eggs_left"] = found
				hud.toast("%d eggs hidden. Go!" % found, Color(1, 0.9, 0.4))
				GameState.run["flags"][key] = true
		"lantern":
			await say([{"who": "Lumi", "text": "Write a wish, light a lantern, let it go on the river. I won't look."}, {"text": "Your lantern drifts out under the bridge with the others. The sky fills."}])
			GameState.run["flags"][key] = true
			GameState.grow_vital("mana", 5)
			hud.toast("Max mana +5", Color(0.8, 0.9, 1.0))
			fx("sparkle", player.position + Vector2(0, -14), 14.0, 0.6)
		"harvest":
			var best := ""
			var bv := 0
			for id in GameState.run["inventory"].keys():
				var it: Dictionary = GameState.items.get(id, {})
				if str(it.get("type", "")) == "crop" and GameState.item_value(str(id)) > bv:
					bv = GameState.item_value(str(id))
					best = str(id)
			if best == "":
				await say([{"who": "Mayor Alder", "text": "Bring a crop to enter the fair! Biggest, brightest, rarest wins."}])
			else:
				GameState.add_item(best, -1)
				var place := 1 if bv >= 100 else (2 if bv >= 40 else 3)
				await say([{"who": "Mayor Alder", "text": "A %s! %s" % [GameState.item_name(best), ["First prize! The blue ribbon and three hundred crystals.", "Second prize! The red ribbon and a hundred and fifty.", "Third prize! The yellow ribbon and fifty."][place - 1]]}])
				GameState.run["crystals"] = int(GameState.run["crystals"]) + [300, 150, 50][place - 1]
				GameState.run["flags"][key] = true
				xp("farming", 40)
		"star":
			await say([{"who": "Posy", "text": "Star Festival! Everyone gives one gift. Here's yours."}, {"text": "A small box. Inside: something somebody thought you'd like."}])
			var gift: String = ["heart_fruit", "stamina_root", "mana_berry", "cake", "wine", "gold_bar"][int(GameState.run["day"]) % 6]
			give(gift)
			GameState.run["flags"][key] = true
			for id in GameState.npcs:
				GameState.run["friendship"][id] = int(GameState.run["friendship"].get(id, 0)) + 10
			hud.toast("Everyone +10 friendship", Color(1, 0.8, 0.9))
	player.frozen = false


## Tall iron lamps on the avenues (Prompts 09 plaza sheet), the old lamp otherwise.
func _lamp_name(n: int) -> String:
	var nm := "lamp2_tall_%d" % (n % 6)
	return nm if Art.has("props", nm) else "lamp"


## The community board: today's three jobs, who posted them and what they pay.
func _board() -> void:
	player.frozen = true
	var jobs := GameState.board_today()
	var d := Dialogue.instance(get_tree())
	var ch: Array = []
	for j in jobs:
		var taken := GameState.has_quest(str(j["id"]))
		ch.append("%s%s: %d %s · ◆%d" % ["✓ " if taken else "", str(GameState.npcs[str(j["npc"])]["name"]), int(j["n"]), GameState.item_name(str(j["item"])), int(j["crystals"])])
	ch.append("Close")
	d.say([{"who": "Community Board", "text": "Pinned today (%s %d). Bring the goods to whoever posted it." % [GameState.season().capitalize(), GameState.day_of_season()], "choice": ch, "key": ""}])
	await d.finished
	if d.last_choice >= 0 and d.last_choice < jobs.size():
		var j: Dictionary = jobs[d.last_choice]
		if GameState.has_quest(str(j["id"])):
			hud.toast("You already took that one.")
		else:
			GameState.board_accept(j)
			hud.toast("Job taken: %d %s for %s." % [int(j["n"]), GameState.item_name(str(j["item"])), str(GameState.npcs[str(j["npc"])]["name"])], Color(1, 0.9, 0.4))
			Music.instance(get_tree()).sfx("pickup")
	player.frozen = false


## Each home and shop gets a few props that say who lives/works there, placed
## just outside its door line (never on the lane). Names fall back if a sprite
## is missing from the manifest.
func _dress_buildings() -> void:
	var pl := func(name: String, c: Vector2i, w := 0, solid := true) -> void:
		if Art.has("props", name) and not things.has(c) and not _door_paths.has(c):
			if int(Art.info("props", name).get("frames", 1)) > 1:
				anim_prop("props", name, c, w, 4.0, solid)
			else:
				prop("props", name, c, w, 0.0, solid)
	# General store (Maple): crates of stock, a flower cart, her red mailbox.
	pl.call("crates2_a", Vector2i(9, 29)); pl.call("flower_cart", Vector2i(21, 28), 1); pl.call("mailbox2_red", Vector2i(23, 29))
	# Smithy (Gideon): anvil, tools, a fire barrel, barrels of coal.
	pl.call("forge_anvil_tools", Vector2i(35, 29), 1); pl.call("fire_barrel_0", Vector2i(24, 29)); pl.call("barrel2_b", Vector2i(36, 28))
	# Bakery (Posy): bread cart and bottle crates.
	pl.call("bread_cart", Vector2i(42, 27), 1); pl.call("bottle_crate_a", Vector2i(55, 27))
	# Mansion (Alder): iron fence posts, planters, the founder statue is on the plaza.
	pl.call("planter2_1", Vector2i(55, 25)); pl.call("planter2_2", Vector2i(68, 25)); pl.call("lamp2_short_0", Vector2i(57, 26)); pl.call("lamp2_short_1", Vector2i(66, 26))
	# Town hall: lamps and benches either side of the steps.
	pl.call("bench2_iron_a", Vector2i(44, 43), 1); pl.call("bench2_iron_b", Vector2i(60, 43), 1)
	# Potions (Wren): cauldron, herb planters, preserves.
	pl.call("cauldron2", Vector2i(44, 62)); pl.call("planter2_3", Vector2i(57, 62)); pl.call("preserves_jar", Vector2i(45, 63))
	# Inn (Bram): barrels, a card table, umbrellas for the terrace.
	pl.call("barrel2_a", Vector2i(56, 61)); pl.call("barrel_a", Vector2i(57, 62)); pl.call("umbrella_red", Vector2i(67, 61), 1); pl.call("card_table", Vector2i(68, 62), 1)
	# Library (Theo): a bench under a lamp.
	pl.call("bench2_wood_a", Vector2i(44, 73), 1); pl.call("lamp2_short_2", Vector2i(57, 73))
	# School: a bell post and a planter; the yard is for the kids.
	pl.call("horseshoe_sign", Vector2i(55, 73)); pl.call("planter2_0", Vector2i(66, 73))
	# Cottages: flower beds and mailboxes in the right colours.
	pl.call("flowerbed_blue", Vector2i(7, 60), 1); pl.call("mailbox2_blue", Vector2i(17, 60))
	pl.call("flowerbed_yellow", Vector2i(18, 67), 1); pl.call("mailbox2_green", Vector2i(28, 67)); pl.call("fish_rack", Vector2i(27, 66), 1)
	pl.call("flowerbed_pink", Vector2i(7, 74), 1); pl.call("mailbox2_red", Vector2i(17, 74))
	# Hazel's farmhouse: crates, hay, a trough, apple buckets.
	pl.call("haystack", Vector2i(17, 84), 1); pl.call("trough2", Vector2i(26, 84), 1); pl.call("apple_bucket2", Vector2i(28, 84)); pl.call("crates_c", Vector2i(16, 83))
	# Stable: hay feeder, hitching post.
	pl.call("hay_feeder", Vector2i(26, 93), 1); pl.call("hitch_post", Vector2i(36, 93))
	# Clinic (Juniper): a bench and a planter of herbs.
	pl.call("bench2_green_a", Vector2i(73, 41), 1); pl.call("planter2_3", Vector2i(80, 41))
	# Chapel: flower beds and an iron bench.
	pl.call("flowerbed_red", Vector2i(73, 66), 1); pl.call("flowerbed_red", Vector2i(82, 66), 1); pl.call("bench2_iron_a", Vector2i(72, 68), 1)
	# Rook's lodge: pelts on a tanning rack, traps, a fire barrel.
	pl.call("tanning_rack", Vector2i(71, 79), 1); pl.call("crab_pots2", Vector2i(80, 79)); pl.call("fire_barrel2", Vector2i(72, 80))
	# Bank (Ivy): two short lamps and a hedge ball.
	pl.call("lamp2_short_3", Vector2i(25, 11)); pl.call("lamp2_short_4", Vector2i(37, 11)); pl.call("hedge2_ball", Vector2i(24, 12))
	# Warehouse: crates and a covered cart.
	pl.call("crates2_b", Vector2i(7, 12)); pl.call("cart_covered", Vector2i(18, 12), 1)


func _place_props() -> void:
	_dress_buildings()
	var fest := GameState.festival_today()
	if fest != "":
		_place_festival(fest)
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
		i += 1
	prop("props", "board2" if Art.has("props", "board2") else ("notice_board" if Art.has("props", "notice_board") else "board"), Vector2i(35, 42), 1)
	for bx in [35, 36]:
		set_thing(bx, 43, {"type": "board", "hint": "A: community board"}, false)
	prop("props", "statue2_founder" if Art.has("props", "statue2_founder") else "statue", Vector2i(45, 42), 1)
	if Art.has("props", "statue2_horse"):
		prop("props", "statue2_horse", Vector2i(12, 36), 1)
	if Art.has("props", "statue2_crystal"):
		prop("props", "statue2_crystal", Vector2i(58, 60), 1)
	for c: Vector2i in [Vector2i(31, 43), Vector2i(49, 43), Vector2i(31, 53), Vector2i(49, 53)]:
		var bn: String = ["bench2_wood_a", "bench2_green_a", "bench2_iron_a"][(c.x + c.y) % 3]
		prop("props", bn if Art.has("props", bn) else ["bench_wood", "bench_green"][c.x % 2], c, 1)
	# Planters and bunting around the plaza, a hedge arch into the park.
	if Art.has("props", "planter2_0"):
		i = 0
		for c: Vector2i in [Vector2i(33, 38), Vector2i(47, 38), Vector2i(33, 58), Vector2i(47, 58)]:
			prop("props", "planter2_%d" % (i % 4), c)
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
			prop("props", "bed2_long_%d" % ((c.x + c.y) % 8), c, 1)
	var fb := ["flowerbed_red", "flowerbed_blue", "flowerbed_pink", "flowerbed_yellow"]
	i = 0
	for c: Vector2i in [Vector2i(30, 40), Vector2i(50, 40), Vector2i(30, 56), Vector2i(50, 56), Vector2i(36, 36), Vector2i(44, 36), Vector2i(36, 59), Vector2i(44, 59)]:
		prop("props", fb[i % 4], c, 1)
		i += 1
	for c: Vector2i in [Vector2i(50, 42), Vector2i(55, 42), Vector2i(60, 25), Vector2i(63, 25)]:
		prop("props", ["topiary_a", "topiary_b"][c.x % 2], c)
	# Lamps along both avenues.
	for y in range(6, 92, 8):
		if y > 40 and y < 56:
			continue
		prop("props", _lamp_name(y), Vector2i(36, y))
		prop("props", _lamp_name(y), Vector2i(45, y))
	for x in range(6, 80, 8):
		if (x > 28 and x < 54) or (x > 66 and x < 74):
			continue
		prop("props", _lamp_name(x), Vector2i(x, 43))
		prop("props", _lamp_name(x), Vector2i(x, 52))
	# Wells, carts, crates: the working edges of town.
	prop("buildings", "well", Vector2i(30, 56), 2)
	prop("props", "well_stone", Vector2i(60, 32), 1)
	prop("props", "cart_full", Vector2i(23, 31), 1)
	prop("props", "crates_a", Vector2i(36, 22))
	prop("props", "crates_b", Vector2i(36, 23))
	prop("props", "barrel_a", Vector2i(24, 29))
	prop("props", "hay", Vector2i(35, 89))
	prop("props", "farm_cart" if Art.has("props", "farm_cart") else "cart", Vector2i(26, 90), 1)
	prop("props", "signpost_cluster" if Art.has("props", "signpost_cluster") else "signpost", Vector2i(44, 4))
	for c: Vector2i in [Vector2i(8, 56), Vector2i(8, 70), Vector2i(76, 68)]:
		prop("props", "lantern_lit", c)
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
	# A tiny graveyard behind the chapel.
	_fence_rect(Rect2i(74, 65, 8, 5), Vector2i(78, 65))
	# Wild bits: tree clumps and scatter where nothing else is.
	var avoid := {}
	for r: Rect2i in [Rect2i(8, 14, 60, 30), AVENUE_X.grow(2), AVENUE_Y.grow(2), Rect2i(44, 52, 24, 24), Rect2i(6, 50, 26, 44), Rect2i(72, 30, 12, 50), Rect2i(66, 0, 8, 96), Rect2i(5, 31, 24, 12), Rect2i(72, 4, 12, 28), Rect2i(6, 3, 16, 12), Rect2i(24, 3, 14, 12)]:
		for c in cells_of([r]):
			avoid[c] = true
	for c in _plaza:
		avoid[c] = true
	WorldGen.tree_clumps(self, Rect2i(2, 2, cols - 4, rows - 4), 33, 22, avoid)
	WorldGen.scatter_props(self, Rect2i(2, 2, cols - 4, rows - 4), 34, 30, avoid)
	WorldGen.add_critters(self, Rect2i(2, 2, cols - 4, rows - 4), 35, 18, ["pigeon", "pigeon", "sparrow", "cat_orange", "cat_grey", "butterfly_blue", "butterfly_yellow", "duck"])


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


func _place_people() -> void:
	for id in GameState.npcs:
		var d: Dictionary = GameState.npcs[id]
		if id == "sal" and GameState.is_penguins() and int(GameState.run["day"]) < 4:
			continue
		if (d.get("routine", []) as Array).is_empty():
			continue  # lives out in a region (lighthouse, mill, quarry...), not in town
		var n := Npc.new()
		n.map = self
		var spot := str(d.get("spot_name", "plaza"))
		n.setup(id, d, cell_center(SPOTS.get(spot, SPOTS["plaza"])))
		n.routine = d.get("routine", [])
		n.spots = SPOTS
		add_child(n)
		npcs.append(n)


func _arrival() -> void:
	player.frozen = true
	var town: String = GameState.names()["town"]
	if GameState.is_penguins():
		await say([
			{"text": "%s. Cobbles, a river with two bridges, the smell of bread from Posy's, and a fountain everybody pretends they don't make wishes at. People look up when you pass. Not unkindly." % town},
		])
	else:
		await say([
			{"text": "%s. Big enough to get lost in, small enough that a new face is news. You keep your hood up and your hands in your pockets." % town},
			{"text": "There's a man by the fountain who doesn't look up when you pass. That's the one to watch."},
		])
	player.frozen = false


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
		"shop", "hall", "door":
			var id := str(thing.get("interior", thing.get("shop", "hall")))
			GameMap.next_interior = id
			go_to("interior", Vector2.ZERO, "up")
			return true
		"festival":
			later(_festival_event.bind(str(thing.get("fest", ""))))
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
			give("candy", 1)
			if left <= 0:
				hud.toast("All the eggs! Alder gives you ◆200.", Color(1, 0.9, 0.4))
				GameState.run["crystals"] = int(GameState.run["crystals"]) + 200
				xp("foraging", 30)
			else:
				hud.toast("%d eggs left." % left)
			return true
		"fountain":
			if int(GameState.run["crystals"]) >= 1:
				GameState.run["crystals"] = int(GameState.run["crystals"]) - 1
				hud.toast("Plink. You feel a little luckier.")
				GameState.run["flags"]["fountain"] = int(GameState.run["flags"].get("fountain", 0)) + 1
				Music.instance(get_tree()).sfx("pickup")
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
		hud.toast("Quest done: met the town.", Color(1, 0.9, 0.4))
	# Gift
	if sel != "" and GameState.count(sel) > 0 and it.get("type", "") != "tool" and it.get("type", "") != "seed":
		GameState.add_item(sel, -1)
		var gain := GameState.gift_value(id, sel)
		var before := GameState.friend_hearts(id)
		fr[id] = int(fr.get(id, 0)) + gain
		await say([{"who": name, "text": _gift_line(id, sel, gain)}])
		hud.toast("%s %s%d" % [name, "+" if gain >= 0 else "", gain], Color(1, 0.8, 0.9) if gain > 0 else Color(1, 0.7, 0.7))
		_heart_unlock(id, before)
		player.frozen = false
		return
	# Main story beats first, then side quests in their own words.
	if await Story.talk(self, id):
		player.frozen = false
		return
	if await Hearts.talk(self, id):
		player.frozen = false
		return
	if await Quests.talk(self, id, name):
		player.frozen = false
		return
	var talked: Dictionary = r["talked_today"]
	if not talked.has(id):
		talked[id] = true
		var before := GameState.friend_hearts(id)
		fr[id] = int(fr.get(id, 0)) + 5
		_heart_unlock(id, before)
	var hl := Hearts.daily(id)
	if hl != "" and (int(r["day"]) + GameState.friend_hearts(id)) % 2 == 0:
		await say([{"who": name, "text": hl}])
	else:
		await say(_lines(id, int(fr.get(id, 0))))
	player.frozen = false


## A new heart just opened: tell the player what it unlocks (npcs.json "perks").
func _heart_unlock(id: String, before: int) -> void:
	var now := GameState.friend_hearts(id)
	if now <= before:
		return
	var perk := GameState.friend_perk_at(id, now)
	if perk != "":
		hud.toast("%s ♥%d: %s" % [str(GameState.npcs[id]["name"]), now, perk], Color(1, 0.85, 0.95))
		Music.instance(get_tree()).sfx("levelup")


func _gift_line(id: String, item: String, gain: int) -> String:
	var n := GameState.item_name(item)
	if gain < 0:
		return {"gideon": "A %s. ...Why." % n, "alder": "A %s. I'll have it... filed." % n, "wren": "A %s. You can keep that, actually." % n}.get(id, "Oh. A %s. Thanks, I suppose." % n)
	if gain >= 20:
		return {"maple": "A %s! You remembered! Oh, you're going to fit right in." % n, "gideon": "...A %s. Where did you— Don't make it weird. Thank you." % n, "wren": "A %s. Do you know how rare these are? I do." % n, "finn": "A %s! Now that's a gift. Come by the hut, I'll show you the good spots." % n, "rook": "A %s. Huh. You pay attention. Good." % n, "sal": "A %s. Nobody gives me things. ...Thanks, boss." % n}.get(id, "A %s! My favourite. How did you know?" % n)
	match id:
		"maple": return "A %s! For me? That's kind." % n
		"gideon": return "Hm. A %s. ...Thank you." % n
		"wren": return "A %s. I can do something with this. Probably not what you'd expect." % n
		"alder": return "A %s, how civic-minded. It'll go in the town records." % n
		"sal": return "A %s. Huh. What do you want?" % n
	return "Thanks for the %s." % n


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
					return [{"who": "Maple", "text": "Pumpkin seeds are in. Plant them by the 10th or they'll never fill out before the frost."}]
				return [{"who": "Maple", "text": "Morning! Turnips grow fast, strawberries pay better. And bring %s by sometime, I've got a bone with their name on it." % pet}]
			if hearts >= 6:
				return [{"who": "Maple", "text": "I had a brother who ran from something once. He never said what. I never asked. He's a baker in the capital now. Just... saying."}]
			return [{"who": "Maple", "text": "New face, old plot. Seeds are in the back. Pay when you can. I mean that."}]
		"gideon":
			if GameState.tool_tier("axe") >= 2 or GameState.tool_tier("pickaxe") >= 2:
				return [{"who": "Gideon", "text": "Iron holds. Steel holds better. Bring me bars and I'll show you what a real edge is."}]
			if GameState.has_tool("iron_sword"):
				return [{"who": "Gideon", "text": "Keep the edge dry. Iron remembers rust the way people remember insults."}]
			if peng:
				return [{"who": "Gideon", "text": "Wooden sword. Hm. It'll do for whatever's bleating in that meadow. For now. Bring me copper bars and we'll talk."}]
			return [{"who": "Gideon", "text": "I don't ask what a farmer needs an iron sword for. I only ask for a hundred and twenty crystals."}]
		"wren":
			if meadow_done:
				return [{"who": "Wren", "text": "The howling stopped. You did that. The bottles on the left shelf are half price for you. Don't tell Alder, he'll want it in the records."}]
			if peng:
				return [{"who": "Wren", "text": "Something fell out of the sky three nights ago and the town's pretending it didn't. I'm not pretending. If it talks to you, tell it I said hello."}]
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
			return [{"who": "Finn", "text": "Cast with A, wait for the splash, press A again. Patience catches more than tackle. My hut's up at the lake if you want bait."}]
		"lumi":
			return [{"who": "Lumi", "text": "The sky over your farm has the strangest colours lately. I've started painting it. Don't tell Alder, he thinks it's weather." if peng else "I paint what I see. Lately I see a lot of people looking over their shoulders."}]
		"theo":
			return [{"who": "Theo", "text": "There's a book in the library about crystals that fall from the sky. Nobody's checked it out in forty years. Until this week." if peng else "Every town has a ledger of who owes what to whom. I keep ours. I don't keep names."}]
		"hazel":
			if hearts >= 6:
				return [{"who": "Hazel", "text": "I'll swing by your fields when I'm up early. Don't thank me, just keep the strawberries coming."}]
			return [{"who": "Hazel", "text": "Water before nine, harvest after six. Turnips forgive, strawberries don't. Come borrow my hoe if yours breaks."}]
		"bram":
			return [{"who": "Bram", "text": "Room's twenty crystals, and it comes with the best sleep in the valley. Soup's free if you listen to my stories."}]
		"posy":
			if season == "winter":
				return [{"who": "Posy", "text": "Spiced loaf season! If you bring me honey I'll make the one my gran made."}]
			return [{"who": "Posy", "text": "Bread's out at seven, gone by nine. Flour from the mill at the lake, if you ever feel like running some over."}]
		"juniper":
			return [{"who": "Juniper", "text": "Eat before you work and you'll see me less. Which I'd prefer, no offence."}]
		"rook":
			if hearts >= 8:
				return [{"who": "Rook", "text": "You've got the eye now. If you're heading into the hills, say the word and I'll walk with you."}]
			return [{"who": "Rook", "text": "Tracks in the orchard again. Big ones. Not deer. Keep your dog close after dark."}]
		"pip", "tobin":
			return [{"who": GameState.npcs[id]["name"], "text": "Did you see the fountain change colour last night? Mabel says it's the crystals. Wren jr says it's frogs."}]
		"wren_jr", "mabel":
			return [{"who": GameState.npcs[id]["name"], "text": "We're not supposed to go past the bridge. So we only go past it a little."}]
		"sal":
			if meadow_done and not peng:
				if not r["flags"].has("sal_recruited"):
					r["flags"]["sal_recruited"] = true
					GameState.add_quest("gang", "Recruit your first crew. (Sal is in. The rest is up to Tom.)")
					return [
						{"who": "Sal", "text": "That was the President's man in the meadow. Not a good one, but one of his. You put him down."},
						{"who": "Sal", "text": "I used to run with a crew in the river cities, before. If you're building something... I'm in. Call it rent."},
					]
				return [{"who": "Sal", "text": "Say the word, boss. I've got nothing but time and a bad knee."}]
			if peng:
				return [{"who": "Sal", "text": "Drifted in last week. Stayed for the quiet. The quiet's getting loud, in the east. You hear it?"}]
			return [{"who": "Sal", "text": "...You're not from here. Neither am I. Let's leave it there, yeah?"}]
	return [{"who": id, "text": "..."}]


# ---- drawing -----------------------------------------------------------------

func draw_map() -> void:
	draw_grass(3)
	WorldGen.draw_ground_detail(self, 31, 0.08)
	# Avenues: cobbles with grass edges. Side lanes to the districts are dirt.
	var roads := cells_of([AVENUE_X, AVENUE_Y, FARM_EXIT, BEACH_EXIT, MOUNTAIN_EXIT])
	for c in _plaza:
		roads.erase(c)
	draw_ground("cobble", roads)
	var lanes_base := cells_of([Rect2i(10, 29, 28, 2), Rect2i(44, 26, 18, 2), Rect2i(60, 23, 2, 4), Rect2i(53, 42, 2, 3), Rect2i(44, 62, 20, 2), Rect2i(62, 61, 2, 2), Rect2i(49, 72, 2, 2), Rect2i(60, 71, 2, 2), Rect2i(44, 73, 18, 2), Rect2i(13, 59, 25, 2), Rect2i(23, 66, 2, 2), Rect2i(13, 73, 2, 2), Rect2i(13, 75, 25, 2), Rect2i(24, 84, 14, 2), Rect2i(32, 92, 6, 2), Rect2i(73, 39, 6, 2), Rect2i(78, 39, 2, 25), Rect2i(73, 63, 6, 2), Rect2i(78, 63, 2, 15), Rect2i(73, 77, 6, 2), Rect2i(10, 41, 28, 2)])
	var all_roads := roads.duplicate()
	all_roads.merge(lanes_base)
	_carve_door_paths(all_roads)
	var lanes := lanes_base.duplicate()
	lanes.merge(_door_paths)
	draw_ground("dirt", lanes)
	# The plaza: flagstones in a circle, a ring of brick at the edge.
	if Art.has("tiles", "flagstone"):
		for c: Vector2i in _plaza:
			var d := Vector2(c.x + 0.5, c.y + 0.5).distance_to(PLAZA_C)
			Art.draw_tile(self, "tiles", "brick_road" if d > PLAZA_R - 1.2 and Art.has("tiles", "brick_road") else "flagstone", Vector2(c * TILE), 4)
	else:
		draw_ground("stone", _plaza)
	# The river and the pond.
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

extends GameMap
## Data-driven region map. A scene sets `region_id` and the layout comes from
## data/regions.json: size, ground, paths, props, buildings, enemies, exits, a
## landmark, an intro line, and simple interactables. This is how every new
## region (wastes, districts, sky, station, jungle, sewers...) is built without a
## script each; story hooks still live in dialogue below.

@export var region_id := "wastes"
var R: Dictionary = {}
var _anim_nodes: Array = []
var _water_cells := {}
var _forage_n := 0
var npcs: Array = []


## How tough this area's foes are. An enemy from an easier tier is brought up
## to the area's tier (never down), and one in ten comes as an elite a tier higher.
const AREA_TIER := {"orchard_hills": 1, "wastes": 1, "hideout": 1, "countryside": 1, "quarry": 2, "marsh": 2,
	"riverlands": 2, "highlands": 2, "docks": 2, "colony_coral": 2, "ruins": 3, "neon": 3, "uptown": 3, "jungle": 3,
	"colony_kelp": 3, "sky": 4, "station": 4, "underground": 4, "colony_ice": 4, "hollow_heart": 5, "colony_ember": 5}


const NO_FRUIT := ["hollow_heart", "wastes", "jungle", "quarry", "highlands", "station", "sky", "underground", "neon", "uptown", "docks", "hideout"]


func _place_secrets() -> void:
	Secrets.place(self, region_id, int(R.get("tier", AREA_TIER.get(region_id, 1))))
	_boss_markers()


## Show who's waiting at a boss spot (a dim, still figure) until they're beaten,
## so a boss isn't an invisible wall.
func _boss_markers() -> void:
	if GameState.run["flags"].has("boss_%s" % region_id):
		return
	for c: Vector2i in things.keys():
		var t: Dictionary = things[c]
		if str(t.get("type", "")) != "boss":
			continue
		var gang := not GameState.is_penguins()
		var bk := str(t.get("kind_gangsters", t.get("kind", ""))) if gang else str(t.get("kind", ""))
		var ed: Dictionary = GameState.enemy_data.get("enemies", {}).get(bk, {})
		var grp := "enemies/" + str(ed.get("art", bk))
		if ed.has("char"):
			grp = "characters/" + str(ed["char"])
		elif bk.begins_with("thug_"):
			grp = "characters/" + bk.trim_prefix("thug_")
		var tex := Art.tex(grp, "idle")
		if tex == null:
			continue
		var info := Art.info(grp, "idle")
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(0, 0, float(info.get("cell_w", tex.get_width())), tex.get_height())
		var sp := Sprite2D.new()
		sp.texture = at
		sp.scale = Vector2(0.5, 0.5)
		sp.offset = Vector2(0, -tex.get_height() / 2.0)
		sp.position = cell_center(c)
		sp.modulate = Color(0.55, 0.5, 0.65, 0.9)
		add_child(sp)
		if t.get("hint", "") == "":
			t["hint"] = "A: face it"


func _spawn_tier(kind: String) -> int:
	var at := int(R.get("tier", AREA_TIER.get(region_id, -1)))
	if at < 0:
		return -1
	var t := maxi(at, GameState.enemy_tier(kind))
	if randf() < 0.1:
		t = mini(5, t + 1)
	return t if t != GameState.enemy_tier(kind) else -1


func scene_id() -> String:
	return region_id


func default_spawn() -> Vector2:
	var s: Array = R.get("spawn", [2, 2])
	return cell_center(Vector2i(int(s[0]), int(s[1])))


func build() -> void:
	var all := GameState.load_json("res://data/regions.json")
	R = all.get(region_id, {})
	cols = int(R.get("cols", 30))
	rows = int(R.get("rows", 26))
	music_track = str(R.get("music", "meadow"))
	has_sky = bool(R.get("sky", true))
	has_pet = bool(R.get("pet", true))
	pad = int(R.get("pad", 5))
	border = R.get("border", "trees")
	for e in R.get("exits", []):
		var r: Array = e["rect"]
		add_exit(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])), str(e["scene"]), Vector2(float(e["spawn"][0]) * TILE, float(e["spawn"][1]) * TILE), str(e.get("facing", "down")), str(e.get("label", "")))
	for b in R.get("blocks", []):
		block_rect(int(b[0]), int(b[1]), int(b[2]), int(b[3]))
	# Noise-shaped water bodies: {"c": [x, y], "r": radius, "seed": n, "shore": "grass"|"sand", "fish": [...]}
	for wb in R.get("water_blobs", []):
		var cx := float(wb["c"][0])
		var cy := float(wb["c"][1])
		var rad := float(wb.get("r", 5))
		var sdv := int(wb.get("seed", 1))
		var cells := {}
		for y in range(int(cy - rad - 3), int(cy + rad + 4)):
			for x in range(int(cx - rad - 3), int(cx + rad + 4)):
				if x < 1 or y < 1 or x >= cols - 1 or y >= rows - 1:
					continue
				var n := WorldGen.fbm(float(x), float(y), sdv, 5.0)
				if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cy)) + n * rad * 0.35 <= rad:
					cells[Vector2i(x, y)] = true
		for pass_i in 2:
			var add := {}
			var drop := {}
			for c: Vector2i in cells.keys():
				pass
			for y in range(int(cy - rad - 3), int(cy + rad + 4)):
				for x in range(int(cx - rad - 3), int(cx + rad + 4)):
					var c := Vector2i(x, y)
					var wn := 0
					for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						if cells.has(c + d):
							wn += 1
					if not cells.has(c) and wn >= 3:
						add[c] = true
					elif cells.has(c) and wn <= 1:
						drop[c] = true
			for c: Vector2i in add:
				cells[c] = true
			for c: Vector2i in drop:
				cells.erase(c)
		for c: Vector2i in cells:
			set_thing(c.x, c.y, {"type": "water", "hint": "A: fish" if GameState.has_tool("rod") else "", "pool": wb.get("fish", []), "shore": str(wb.get("shore", "grass"))})
			_water_cells[c] = true
	# Islands: everything that isn't island is sea (colony maps).
	if R.has("islands"):
		var land := {}
		for bl in R["islands"]:
			var cx := float(bl["c"][0]); var cy := float(bl["c"][1]); var rad := float(bl.get("r", 8)); var sdv := int(bl.get("seed", 3))
			for y in range(int(cy - rad - 4), int(cy + rad + 5)):
				for x in range(int(cx - rad - 4), int(cx + rad + 5)):
					var n := WorldGen.fbm(float(x), float(y), sdv, 7.0)
					if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cy)) + n * rad * 0.35 <= rad:
						land[Vector2i(x, y)] = true
		for pr in R.get("paths", []):
			for y in range(int(pr[1]), int(pr[1]) + int(pr[3])):
				for x in range(int(pr[0]), int(pr[0]) + int(pr[2])):
					land[Vector2i(x, y)] = true  # sand bars along the paths
		for t in R.get("things", []):
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					land[Vector2i(int(t["cell"][0]) + dx, int(t["cell"][1]) + dy)] = true
		var sp: Array = R.get("spawn", [2, 2])
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				land[Vector2i(int(sp[0]) + dx, int(sp[1]) + dy)] = true
		for e in exits:
			for c in cells_of([e["rect"]]):
				land[c] = true
				land[c + Vector2i(0, -1)] = true
		for y in range(1, rows - 1):
			for x in range(1, cols - 1):
				var c := Vector2i(x, y)
				if not land.has(c) and not things.has(c):
					set_thing(x, y, {"type": "water", "hint": "A: fish" if GameState.has_tool("rod") else "", "pool": R.get("fish", ["minnow", "trout", "salmon"]), "shore": str(R.get("island_shore", "sand"))})
					_water_cells[c] = true
	# Painted water rects ("water": [{"rect": [x, y, w, h], "fish": [...]}]) are real
	# water too: no walking on the sea, and you can fish off the dock.
	for wr in R.get("water", []):
		var rr: Array = wr.get("rect", [])
		if rr.size() < 4:
			continue
		for y in range(int(rr[1]), int(rr[1]) + int(rr[3])):
			for x in range(int(rr[0]), int(rr[0]) + int(rr[2])):
				if x < 1 or y < 1 or x >= cols - 1 or y >= rows - 1 or things.has(Vector2i(x, y)):
					continue
				set_thing(x, y, {"type": "water", "hint": "A: fish" if GameState.has_tool("rod") else "", "pool": wr.get("fish", R.get("fish", [])), "shore": str(wr.get("shore", "sand"))})
	# Forage spots from data/forage.json (respawn every 2 days, 1 with Tracker).
	var fcount := int(R.get("forage", 0))
	if fcount > 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(region_id) % 1000 + 9 + int(GameState.run["day"]) / 7
		for i in fcount * 3:
			if _forage_n >= fcount:
				break
			var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(2, rows - 3))
			if things.has(c) or blocked.has(c):
				continue
			var key := "forage_%s_%d_%d" % [region_id, c.x, c.y]
			var item := GameState.roll_forage(region_id)
			# Respawn: common forage every 1-2 days, rare finds take most of a week.
			var tier := int(GameState.items.get(item, {}).get("tier", 1))
			var every := (1 if GameState.has_perk("foraging", "Tracker") else 2) + maxi(0, tier - 1) * 2
			if not GameState.respawned(key, every):
				continue
			things[c] = {"type": "forage", "key": key, "item": item, "hint": "A: pick %s" % GameState.item_name(item)}
			_forage_n += 1
	# Elevation: plateaus (each a set of noise blobs), drawn as cliffs with ramps.
	for pl in R.get("plateaus", []):
		var pc := {}
		for bl in pl.get("blobs", []):
			var cx := float(bl["c"][0]); var cy := float(bl["c"][1]); var rad := float(bl.get("r", 6)); var sdv := int(bl.get("seed", 7))
			for y in range(int(cy - rad - 3), int(cy + rad + 4)):
				for x in range(int(cx - rad - 3), int(cx + rad + 4)):
					if x < 2 or y < 2 or x >= cols - 2 or y >= rows - 3:
						continue
					var n := WorldGen.fbm(float(x), float(y), sdv, 6.0)
					if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cy)) + n * rad * 0.3 <= rad:
						pc[Vector2i(x, y)] = true
		# Smooth: no one-cell notches (they draw as broken cliff pieces).
		for pass_i in 2:
			var nx := pc.duplicate()
			for c: Vector2i in pc:
				var nb := 0
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if pc.has(c + d):
						nb += 1
				if nb <= 1:
					nx.erase(c)
			pc = nx
		add_plateau(pc, pl.get("ramps", []))
	if int(R.get("fruit", 0 if region_id in NO_FRUIT else 3)) > 0:
		WorldGen.fruit_trees(self, Rect2i(3, 3, cols - 6, rows - 6), hash(region_id) % 500 + 3, int(R.get("fruit", 3)))
	for t in R.get("things", []):
		var c: Array = t["cell"]
		var d := {"type": str(t["type"]), "hint": str(t.get("hint", ""))}
		for k in t:
			if not k in ["cell", "solid"]:
				d[k] = t[k]
		set_thing(int(c[0]), int(c[1]), d, bool(t.get("solid", true)))


var battle: Battle = null


func after_ready() -> void:
	WorldGen.add_backdrop(self, str(R.get("backdrop", "hills")))
	if R.has("battle"):
		battle = Battle.start(self, region_id, R["battle"])
	place_project_site()
	if R.has("colony"):
		_place_colony()
	_place_secrets.call_deferred()
	for p in R.get("props", []):
		var c := Vector2i(int(p["cell"][0]), int(p["cell"][1]))
		var g := str(p.get("group", "props"))
		var nm := str(p["name"])
		var w := int(p.get("w", 0))
		if bool(p.get("anim", false)) and Art.has(g, nm):
			var a := AnimatedSprite2D.new()
			a.sprite_frames = Art.frames(g, {"idle": nm}, {"idle": float(p.get("fps", 4.0))})
			a.animation = "idle"
			a.scale = Vector2(0.5, 0.5)
			a.position = cell_pos(c.x + (w + 1) / 2.0, c.y + 1)
			a.offset = Vector2(0, -float(Art.info(g, nm).get("cell_h", 48)) / 2.0)
			if bool(p.get("under", false)):
				a.z_index = -1
			add_child(a)
			a.play("idle")
		else:
			var sp := prop(g, nm, c, w, 0.0, false)  # footprint blocked below, sized to the art
			if sp and bool(p.get("under", false)):
				sp.z_index = -1
		if bool(p.get("solid", true)):
			var h := int(p.get("h", 1))
			# Footprint = the art's real size (declared w/h are upper bounds), so
			# a prop never blocks air beside it. Tall props block only their
			# lower part; you walk behind the roof/canopy.
			var bw := w + 1
			var bh := h
			if Art.has(g, nm):
				var info := Art.info(g, nm)
				var aw := int(floor(float(info.get("cell_w", info.get("w", bw * TILE * 2))) / (TILE * 2.0) + 0.4))
				var ah := int(floor(float(info.get("cell_h", info.get("h", bh * TILE * 2))) / (TILE * 2.0) + 0.4))
				bw = clampi(aw, 1, bw)
				bh = clampi(ah, 1, bh)
			if bh >= 3 and g != "nature":
				bh = maxi(2, int(ceil(bh * 0.62)))
			var x0 := c.x + (w + 1 - bw) / 2
			block_rect(x0, c.y - bh + 1, bw, bh)
	for k in things.keys():
		if str(things[k].get("type", "")) == "forage":
			var it := str(things[k]["item"])
			var nm := "mushrooms_fall" if it in ["mushroom", "glow_cap", "truffle"] and Art.has("nature", "mushrooms_fall") else ("wildflowers2" if Art.has("nature", "wildflowers2") else "flowers")
			prop("nature", nm, k, 0, 0.0, false)
	# Villagers who live out here (regions.json "npcs": [{"id", "cell", "lines": [...]}]).
	for n in R.get("npcs", []):
		var id := str(n["id"])
		var data: Dictionary = GameState.npcs.get(id, {"name": id.capitalize()})
		var npc := Npc.new()
		npc.map = self
		npc.setup(id, data, cell_center(Vector2i(int(n["cell"][0]), int(n["cell"][1]))))
		npc.wander = float(n.get("wander", 14.0))
		add_child(npc)
		npcs.append(npc)
	Crew.place(self)
	if Crew.perk_level("heal_hideout") >= 1 and region_id == "hideout" and int(GameState.run["flags"].get("doc_heal_day", -1)) != int(GameState.run["day"]):
		GameState.run["flags"]["doc_heal_day"] = int(GameState.run["day"])
		GameState.run["hp"] = mini(int(GameState.run["max_hp"]), int(GameState.run["hp"]) + 20)
	var gen: Dictionary = R.get("gen", {})
	var inner := Rect2i(2, 2, cols - 4, rows - 4)
	var avoid := {}
	for b in R.get("blocks", []):
		for y in range(int(b[1]) - 1, int(b[1]) + int(b[3]) + 1):
			for x in range(int(b[0]) - 1, int(b[0]) + int(b[2]) + 1):
				avoid[Vector2i(x, y)] = true
	for pr in R.get("paths", []):
		for y in range(int(pr[1]), int(pr[1]) + int(pr[3])):
			for x in range(int(pr[0]), int(pr[0]) + int(pr[2])):
				avoid[Vector2i(x, y)] = true
	for c: Vector2i in _water_cells:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				avoid[c + Vector2i(dx, dy)] = true
	if gen.has("tree_border"):
		var gaps: Array = []
		for e in exits:
			gaps.append((e["rect"] as Rect2i).grow(2))
		WorldGen.tree_border(self, Rect2i(1, 1, cols - 2, rows - 2), hash(region_id) % 1000, gaps, int(gen["tree_border"]))
	if gen.has("clumps"):
		WorldGen.tree_clumps(self, inner, hash(region_id) % 1000 + 1, int(gen["clumps"]), avoid)
	if gen.has("scatter"):
		WorldGen.scatter_props(self, inner, hash(region_id) % 1000 + 2, int(gen["scatter"]), avoid)
	if gen.has("region_props"):
		# Random scatter of named props from this region's set (non-interactive).
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(region_id) % 1000 + 3
		var names: Array = gen["region_props"]
		for i in int(gen.get("region_count", 20)):
			var c := Vector2i(rng.randi_range(inner.position.x, inner.end.x - 1), rng.randi_range(inner.position.y, inner.end.y - 1))
			if things.has(c) or blocked.has(c) or avoid.has(c):
				continue
			var nm := str(names[rng.randi_range(0, names.size() - 1)])
			var g := "nature" if Art.has("nature", nm) else "props"
			prop(g, nm, c)
	if gen.has("critters"):
		WorldGen.add_critters(self, inner, hash(region_id) % 1000 + 4, int(gen.get("critter_count", 6)), gen["critters"])
	for e in R.get("enemies", []):
		var n := GameState.enemy_count(int(e.get("count", 1)))
		for i in n:
			var at := cell_center(Vector2i(randi_range(4, cols - 5), randi_range(4, rows - 5)))
			# Never right on top of where you walked in.
			for tries in 20:
				var cc := world_to_cell(at)
				if player == null or (cc - world_to_cell(player.position)).length() >= 8.0 and not is_water_cell(cc) and not blocked.has(cc):
					break
				at = cell_center(Vector2i(randi_range(4, cols - 5), randi_range(4, rows - 5)))
			if e.has("cell"):
				at = cell_center(Vector2i(int(e["cell"][0]), int(e["cell"][1])))
			var ek := str(e["kind"])
			if ek == "grump" and not GameState.is_penguins():
				ek = "thug_lookout"
			var se := spawn_enemy(ek, at, _spawn_tier(ek))
			if se and bool(e.get("colony", false)):
				se.set_meta("colony_foe", true)
	if R.has("weather"):
		set_weather(str(R["weather"]))
	var flag := region_id + "_seen"
	if not GameState.run["flags"].has(flag) and R.has("intro"):
		GameState.run["flags"][flag] = true
		player.frozen = true
		var lines: Array = []
		var intro = R["intro"]
		if intro is Dictionary:
			intro = intro.get("penguins" if GameState.is_penguins() else "gangsters", [])
		for l in intro:
			lines.append({"text": str(l)} if l is String else l)
		await say(lines)
		player.frozen = false


func has_npc_at(c: Vector2i) -> bool:
	for n: Npc in npcs:
		if n.visible and n.cell() == c:
			return true
	return false


func interact(c: Vector2i, thing: Dictionary) -> bool:
	for n: Npc in npcs:
		if n.visible and (n.cell() == c or (thing.is_empty() and n.position.distance_to(player.position + player.facing_dir() * 14.0) < 16.0)):
			later(_talk_npc.bind(n))
			return true
	if Secrets.interact(self, c, thing):
		return true
	match str(thing.get("type", "")):
		"cpoint":
			if battle:
				later(battle.interact.bind(str(thing.get("id", ""))))
			return true
		"note":
			if thing.has("story"):
				later(func() -> void:
					if await Story.talk(self, str(thing["story"])):
						return
					tell([{"who": str(thing.get("who", "")), "text": str(thing.get("text", "...")), "mood": str(thing.get("mood", "neutral"))}]))
				return true
			tell([{"who": str(thing.get("who", "")), "text": str(thing.get("text", "...")), "mood": str(thing.get("mood", "neutral"))}])
			return true
		"water":
			if GameState.has_tool("rod"):
				var pool: Array = thing.get("pool", [])
				if pool.is_empty():
					pool = ["carp", "bass", "catfish", "salmon", "eel"]
				fish_at(c, pool)
			return true
		"shop":
			later(_shop.bind(thing))
			return true
		"loot":
			var key := "loot_%s_%d_%d" % [region_id, c.x, c.y]
			if not GameState.run["flags"].has(key) or int(GameState.run["day"]) >= int(GameState.run["flags"][key]) + int(thing.get("every", 1)):
				GameState.run["flags"][key] = int(GameState.run["day"])
				give(str(thing.get("item", "stone")), int(thing.get("n", 1)))
				if Crew.perk_level("sell_bonus") >= 3:
					GameState.run["crystals"] = int(GameState.run["crystals"]) + 25
					hud.toast("Deuce taught you where people hide coins. +◆25", Color(1, 0.9, 0.5))
			else:
				hud.toast(str(thing.get("empty", "Nothing here right now.")))
			return true
		"heal":
			if int(GameState.run["flags"].get("heal_%s" % region_id, 0)) < int(GameState.run["day"]):
				GameState.run["flags"]["heal_%s" % region_id] = int(GameState.run["day"])
				GameState.heal(int(thing.get("hp", 3)))
				GameState.restore_energy(int(thing.get("energy", 30)))
				hud.toast(str(thing.get("msg", "You feel better.")))
				fx("heal", player.position + Vector2(0, -10), 10.0, 0.6)
			else:
				hud.toast("Once a day.")
			return true
		"boss":
			later(_boss.bind(thing))
			return true
		"door":
			go_to(str(thing["scene"]), Vector2(float(thing["spawn"][0]) * TILE, float(thing["spawn"][1]) * TILE), str(thing.get("facing", "down")))
			return true
		"idoor":
			GameMap.next_interior = str(thing["interior"])
			go_to("interior", Vector2.ZERO, "up")
			return true
		"mrock":
			if GameState.held_tool() != "pickaxe":
				return GameState.has_tool("pickaxe")
			var ob := GameState.ore_block(str(thing.get("ore", "stone")))
			if ob != "":
				player.play_tool("pickaxe")
				hud.toast(ob, Color(1, 0.85, 0.6))
				return true
			if not GameState.spend_for("pickaxe"):
				hud.toast("Too tired.", Color(1, 0.7, 0.7))
				return true
			player.play_tool("pickaxe")
			Music.instance(get_tree()).sfx("chop")
			thing["hp"] = int(thing.get("hp", 2)) - 1
			if int(thing["hp"]) <= 0:
				things.erase(c)
				blocked.erase(c)
				hard.erase(c)
				if props.has(c):
					(props[c] as Node).queue_free()
					props.erase(c)
				give(str(thing.get("ore", "stone")), int(thing.get("n", 1)))
				xp("mining", 3)
			return true
	return false


func _shop(thing: Dictionary) -> void:
	var items: Array = thing.get("items", [])
	var opts: Array = []
	for it in items:
		opts.append("%s  ◆%d" % [GameState.item_name(str(it[0])), GameState.shop_price(str(it[0]), int(it[1]))])
	opts.append("Leave")
	var d := Dialogue.instance(get_tree())
	d.say([{"who": str(thing.get("who", "Shop")), "text": "%s  (◆%d)" % [str(thing.get("greet", "What'll it be?")), int(GameState.run["crystals"])], "choice": opts, "key": ""}])
	await d.finished
	var i := d.last_choice
	if i < 0 or i >= items.size():
		return
	var id := str(items[i][0])
	var price := GameState.shop_price(id, int(items[i][1]))
	if int(GameState.run["crystals"]) < price:
		hud.toast("Not enough crystals.", Color(1, 0.7, 0.7))
		return
	GameState.run["crystals"] = int(GameState.run["crystals"]) - price
	if GameState.items.get(id, {}).get("type", "") == "tool":
		GameState.add_tool(id)
		hud.toast("Got the %s." % GameState.item_name(id), Color(1, 0.9, 0.4))
	else:
		give(id)


func _boss(thing: Dictionary) -> void:
	var key := "boss_%s" % region_id
	if GameState.run["flags"].has(key):
		await say([{"text": str(thing.get("after", "Quiet now."))}])
		return
	if _boss_node != null and is_instance_valid(_boss_node) and _boss_node._alive:
		return  # already fighting it: A at the boss swings, it doesn't re-summon
	if thing.has("when") and not GameState._cond_ok(thing["when"]):
		await say([{"text": str(thing.get("locked", "Not yet. There's business to finish elsewhere first."))}])
		return
	player.frozen = true
	var gang := not GameState.is_penguins()
	var bk := str(thing.get("kind_gangsters", thing.get("kind", "commander"))) if gang else str(thing.get("kind", "commander"))
	var bw := str(thing.get("who_gangsters", thing.get("who", ""))) if gang else str(thing.get("who", ""))
	var bt := str(thing.get("text_gangsters", thing.get("text", "..."))) if gang else str(thing.get("text", "..."))
	await say([{"who": bw, "text": bt}])
	var b := spawn_enemy(bk, player.position + Vector2(40, 0))
	if b:
		b.set_meta("boss_name", bw if bw != "" else str(thing.get("title", "")))
	boss_card(bk, str(thing.get("title", bw)))
	Music.instance(get_tree()).play("boss")
	player.frozen = false
	_boss_node = b
	_boss_thing = thing


var _boss_node: Enemy
var _boss_thing: Dictionary


func on_enemy_died(e: Enemy) -> void:
	super(e)
	if _boss_node != null and e == _boss_node:
		_boss_node = null
		GameState.run["flags"]["boss_%s" % region_id] = true
		Music.instance(get_tree()).play(music_track)
		player.frozen = true
		await say([{"text": str(_boss_thing.get("win", "It's over."))}])
		var reward := str(_boss_thing.get("reward", ""))
		if reward != "":
			give(reward, int(_boss_thing.get("reward_n", 1)))
		if _boss_thing.has("max_hp"):
			# Data says hearts (old 6-heart scale); one heart is 20 health now.
			GameState.grow_vital("hp", int(_boss_thing["max_hp"]) * GameState.HEART_HP)
		GameState.save()
		player.frozen = false


## Out-of-town villagers: gifts, quests (quests.json by giver), daily hello.
func _talk_npc(n: Npc) -> void:
	player.frozen = true
	n.face(player.position)
	var id := n.id
	var name := str(GameState.npcs.get(id, {}).get("name", id.capitalize()))
	var fr: Dictionary = GameState.run["friendship"]
	var sel := str(GameState.run["selected"])
	var it: Dictionary = GameState.items.get(sel, {})
	if not GameState.run["talked_today"].has(id):
		GameState.run["talked_today"][id] = true
		GameState.add_friend(id, 5)
	if await Story.talk(self, id):
		player.frozen = false
		return
	if await Hearts.talk(self, id):
		player.frozen = false
		return
	if await Quests.talk(self, id, name):
		player.frozen = false
		return
	if await Crew.talk(self, id):
		player.frozen = false
		return
	if GameState.can_gift(id, sel) and await confirm_gift(name, sel):
		var gain := GameState.give_gift(id, sel)
		await say([{"who": name, "text": gift_reaction(name, sel, gain)}])
		hud.toast("%s %s%d" % [name, "+" if gain >= 0 else "", gain], Color(1, 0.8, 0.9) if gain > 0 else Color(1, 0.7, 0.7))
		player.frozen = false
		return
	var lines: Array = []
	var hl := Hearts.daily(id)
	if hl != "" and (int(GameState.run["day"]) + GameState.friend_hearts(id)) % 2 == 0:
		lines.append({"who": name, "text": hl})
	for nd in R.get("npcs", []):
		if str(nd["id"]) == id and lines.is_empty():
			var ls: Array = nd.get("lines", [])
			if not ls.is_empty():
				lines.append({"who": name, "text": str(ls[(int(GameState.run["day"]) + GameState.friend_hearts(id)) % ls.size()])})
	if lines.is_empty():
		lines.append({"who": name, "text": "..."})
	await say(lines)
	player.frozen = false


func draw_map() -> void:
	var ground := str(R.get("ground", "grass"))
	if ground == "grass":
		draw_grass(hash(region_id) % 100)
		WorldGen.draw_ground_detail(self, hash(region_id) % 100 + 1, float(R.get("detail", 0.1)))
		# Region ground set (Prompts-08 batch 3): the region's own fill tiles in
		# noise drifts over the grass, with its decals scattered on top.
		var ps := str(R.get("patch_set", ""))
		if ps != "" and Art.has("tiles", ps + "_top_0"):
			# Coherent ground patches (noise blobs with real edges from the region's
			# blob set) instead of a per-cell tile lottery.
			var sd := hash(region_id) % 977
			var cells := {}
			for y in range(-pad + 1, rows + pad - 1):
				for x in range(-pad + 1, cols + pad - 1):
					var n := WorldGen.fbm(float(x), float(y), sd, float(R.get("patch_scale", 10.0)))
					if n > float(R.get("ground_threshold", 0.08)):
						cells[Vector2i(x, y)] = true
			# Drop single-cell specks and fill single-cell holes so edges read cleanly.
			for pass_i in 2:
				var next := cells.duplicate()
				for y in range(-pad + 1, rows + pad - 1):
					for x in range(-pad + 1, cols + pad - 1):
						var c := Vector2i(x, y)
						var nb := 0
						for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
							if cells.has(c + off):
								nb += 1
						if cells.has(c) and nb <= 1:
							next.erase(c)
						elif not cells.has(c) and nb >= 3:
							next[c] = true
				cells = next
			for c: Vector2i in cells:
				var h := absi((c.x * 73856093) ^ (c.y * 19349663))
				var seam_ps: String = {"bog": "bog", "ruinfloor": "ruin_floor"}.get(ps, "")
				if seam_ps != "" and seam_cell(self, seam_ps, c):
					continue
				Art.draw_tile(self, "tiles", Art.fill_name(ps, h), Vector2(c * TILE), 0)
				if ps == "bog":
					draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color(0.32, 0.45, 0.22, 0.3))  # mossier, less void
				if h % 29 == 0 and _blob_interior(cells, c) and Art.has("tiles", "%s_deco_%d" % [ps, h / 29 % 36]):
					Art.draw_tile(self, "tiles", "%s_deco_%d" % [ps, h / 29 % 36], Vector2(c * TILE), 0)
			_draw_soft_rim(cells, Color(0.2, 0.13, 0.06, 0.22), Color(0.1, 0.2, 0.05, 0.18))
			var ds := str(R.get("deco_set", ""))
			var dc := int(R.get("deco_count", 0))
			if ds != "" and dc > 0:
				for y in range(0, rows):
					for x in range(0, cols):
						var h := absi((x * 73856093) ^ (y * 19349663) ^ 7)
						if h % 41 == 0 and not blocked.has(Vector2i(x, y)):
							Art.draw_tile(self, "tiles", "%s_%d" % [ds, h / 17 % dc], Vector2(x * TILE, y * TILE), 0)
	elif Art.has("tiles", ground):
		for y in range(-pad, rows + pad):
			for x in range(-pad, cols + pad):
				Art.draw_tile(self, "tiles", ground, Vector2(x * TILE, y * TILE), 4)
	else:
		draw_rect(Rect2(-pad * TILE, -pad * TILE, (cols + 2 * pad) * TILE, (rows + 2 * pad) * TILE), Color(str(R.get("ground_color", "5a9e4b"))))
	# Feature ground (Prompts 09 edge sets): noise blobs of e.g. terrace / snow / track / ruin floor.
	for fb in R.get("feature_blobs", []):
		var setn := str(fb["set"])
		if not Art.has("tiles", setn + "_top_0"):
			continue
		var cells := {}
		for bl in fb.get("blobs", []):
			var cx := float(bl["c"][0]); var cy := float(bl["c"][1]); var rad := float(bl.get("r", 5)); var sdv := int(bl.get("seed", 3))
			for y in range(int(cy - rad - 3), int(cy + rad + 4)):
				for x in range(int(cx - rad - 3), int(cx + rad + 4)):
					if x < 0 or y < 0 or x >= cols or y >= rows:
						continue
					var n := WorldGen.fbm(float(x), float(y), sdv, 5.0)
					if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cy)) + n * rad * 0.35 <= rad:
						cells[Vector2i(x, y)] = true
		for c: Vector2i in cells:
			var h := absi((c.x * 73856093) ^ (c.y * 19349663))
			Art.draw_tile(self, "tiles", Art.fill_name(setn, h), Vector2(c * TILE), 0)
			if h % 23 == 0 and _blob_interior(cells, c) and Art.has("tiles", "%s_deco_%d" % [setn, h / 23 % 36]):
				Art.draw_tile(self, "tiles", "%s_deco_%d" % [setn, h / 23 % 36], Vector2(c * TILE), 0)
		_draw_soft_rim(cells, Color(0.2, 0.13, 0.06, 0.22), Color(0.1, 0.2, 0.05, 0.18))
	draw_plateaus()
	if region_id == "marsh" and Art.has("props", "mk_fog_l") and _anim_layer:
		# Low marsh mist (Prompts 16): a few soft puffs drifting slowly, faint.
		var fogs := ["mk_fog_l", "mk_fog_m", "mk_fog_s", "mk_fog_m", "mk_fog_l", "mk_fog_s"]
		_anim_layer.jobs.append(func(ci: CanvasItem) -> void:
			var tt := Time.get_ticks_msec() / 1000.0
			for i in fogs.size():
				var ft := Art.tex("props", str(fogs[i]))
				if ft == null:
					continue
				var w := ft.get_width() * 0.35
				var span := float(cols * TILE) + w * 2.0
				var fx := fposmod(i * 211.0 + tt * (3.0 + i), span) - w
				var fy := 40.0 + fposmod(i * 157.0, float(rows * TILE) - 80.0) + sin(tt * 0.15 + i) * 10.0
				ci.draw_texture_rect(ft, Rect2(fx, fy, w, ft.get_height() * 0.35), false, Color(1, 1, 1, 0.22)))
	for layer in R.get("layers", []):
		var nm := str(layer["tile"])
		var r: Array = layer["rect"]
		draw_tileset_rect(nm, Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])), Color(str(layer.get("color", "888888"))))
	var path_kind := str(R.get("path", "dirt"))
	var pcs := {}
	for pr in R.get("paths", []):
		for y in range(int(pr[1]), int(pr[1]) + int(pr[3])):
			for x in range(int(pr[0]), int(pr[0]) + int(pr[2])):
				pcs[Vector2i(x, y)] = true
	for e in exits:
		for c in cells_of([e["rect"]]):
			pcs[c] = true
	if path_kind in ["dirt", "sand", "stone"] and ground == "grass":
		draw_ground(path_kind, pcs)
	else:
		for c: Vector2i in pcs:
			if not Art.draw_tile(self, "tiles", path_kind, Vector2(c * TILE), 4):
				draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color("8a8a90"))
	for wr in R.get("water", []):
		var r: Array = wr["rect"]
		draw_water(cells_of([Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))]), str(wr.get("shore", "grass")))
	if not _water_cells.is_empty():
		var by_shore := {}
		for c: Vector2i in _water_cells:
			var sh := str(things.get(c, {}).get("shore", "grass"))
			if not by_shore.has(sh):
				by_shore[sh] = {}
			by_shore[sh][c] = true
		for sh in by_shore:
			draw_water(by_shore[sh], str(sh))
	draw_exits()
	if bool(R.get("fence", false)) and pad == 0:
		draw_fence_border(Color(str(R.get("fence_color", "6b4a2b"))))


func _process(delta: float) -> void:
	super(delta)


## Colony maps: the elder, the shop, the star crystal and the tide beacons.
func _place_colony() -> void:
	var cid := region_id.trim_prefix("colony_")
	var done := bool(Colony.st(region_id)["done"])
	const ELDERS := {"coral": "elder_brine", "kelp": "elder_tidewhisker", "ice": "elder_icewhisker", "ember": "elder_cinderpaw"}
	for t in R.get("things", []):
		var c := Vector2i(int(t["cell"][0]), int(t["cell"][1]))
		match str(t.get("type", "")):
			"elder":
				var eid := str(ELDERS.get(cid, "mer"))
				var sp := CharacterLibrary.make_sprite(eid if CharacterLibrary.has_character(eid) else "mer")
				if sp:
					sp.position = cell_center(c)
					sp.play("happy" if done and sp.sprite_frames.has_animation("happy") else ("idle" if done else ("sad" if sp.sprite_frames.has_animation("sad") else "idle")))
					add_child(sp)
				_colony_village(cid, c, done)
			"colony_shop":
				var stn := "%s_stall_%s" % [cid, "open" if done else "closed"]
				if Art.has("props", stn):
					prop("props", stn, c, 2, 0.0, true, 0.3)
				elif Art.has("props", "stall2_blue"):
					prop("props", "stall2_blue" if done else "stall2_blue_closed", c, 1)
			"star_crystal":
				var cn := "%s_crystal_%s" % [cid, "lit" if done else "dim"]
				var nm := "ccrystal_%d" % (4 if done else 2)
				if Art.has("props", cn):
					prop("props", cn, c, 1, 0.0, true, 0.3)
				elif Art.has("props", nm):
					prop("props", nm, c)
			"beacon":
				var lit := (Colony.st(region_id)["beacons"] as Dictionary).has(str(t.get("key", "")))
				var bn := "%s_beacon_%s" % [cid, "on" if lit else "off"]
				var ln := "lantern_lit" if lit else "lantern_unlit"
				if Art.has("props", bn):
					prop("props", bn, c, 0, 0.0, true, 0.22)
				elif Art.has("props", ln):
					prop("props", ln, c)


# Houses, villagers and (until the crystal wakes) the creeping blight around the elder.
func _colony_village(cid: String, at: Vector2i, done: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(region_id)
	var spots := [Vector2i(-6, -5), Vector2i(0, -7), Vector2i(6, -5)]
	for i in 3:
		var hn := "%s_house_%d" % [cid, i + 1]
		var hc: Vector2i = at + spots[i]
		if Art.has("props", hn) and not blocked.has(hc):
			prop("props", hn, hc, 2, 0.0, true, 0.32)
	for i in 3:
		var kid := "%s_kit_%d" % [cid, i + 1]
		if not CharacterLibrary.has_character(kid):
			continue
		var sp := CharacterLibrary.make_sprite(kid)
		if sp == null:
			continue
		var kc: Vector2i = at + Vector2i(-4 + i * 4, 3 + (i % 2))
		sp.position = cell_center(kc)
		sp.play("idle")
		sp.speed_scale = 0.7 + 0.2 * i
		sp.y_sort_enabled = true
		add_child(sp)
	if done:
		return
	for i in 10:
		var bn := "%s_blight_%d" % [cid, 1 + (i % 3)]
		var bc := Vector2i(rng.randi_range(4, cols - 5), rng.randi_range(4, rows - 5))
		if Art.has("props", bn) and not blocked.has(bc) and bc.distance_to(at) > 5:
			prop("props", bn, bc, 0, 0.0, true, 0.35)

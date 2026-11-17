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
	if int(R.get("fruit", 3)) > 0:
		WorldGen.fruit_trees(self, Rect2i(3, 3, cols - 6, rows - 6), hash(region_id) % 500 + 3, int(R.get("fruit", 3)))
	for t in R.get("things", []):
		var c: Array = t["cell"]
		var d := {"type": str(t["type"]), "hint": str(t.get("hint", ""))}
		for k in t:
			if not k in ["cell", "solid"]:
				d[k] = t[k]
		set_thing(int(c[0]), int(c[1]), d, bool(t.get("solid", true)))


func after_ready() -> void:
	WorldGen.add_backdrop(self, str(R.get("backdrop", "hills")))
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
			a.position = Vector2((c.x + (w + 1) / 2.0) * TILE, (c.y + 1) * TILE)
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
			spawn_enemy(str(e["kind"]), at)
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
	match str(thing.get("type", "")):
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
	await say([{"who": str(thing.get("who", "")), "text": str(thing.get("text", "..."))}])
	var b := spawn_enemy(str(thing.get("kind", "commander")), player.position + Vector2(40, 0))
	boss_card(str(thing.get("kind", "commander")), str(thing.get("title", "")))
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
				Art.draw_tile(self, "tiles", "%s_fill_%d" % [ps, h % 42], Vector2(c * TILE), 0)
				if h % 11 == 0 and Art.has("tiles", "%s_deco_%d" % [ps, h / 11 % 36]):
					Art.draw_tile(self, "tiles", "%s_deco_%d" % [ps, h / 11 % 36], Vector2(c * TILE), 0)
			Art.draw_blob(self, cells, ps, 16.0, 0)
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
			Art.draw_tile(self, "tiles", "%s_fill_%d" % [setn, h % 42], Vector2(c * TILE), 0)
			if h % 9 == 0 and Art.has("tiles", "%s_deco_%d" % [setn, h / 9 % 36]):
				Art.draw_tile(self, "tiles", "%s_deco_%d" % [setn, h / 9 % 36], Vector2(c * TILE), 0)
		Art.draw_blob(self, cells, setn, 16.0, 0)
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

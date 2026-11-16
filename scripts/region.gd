extends GameMap
## Data-driven region map. A scene sets `region_id` and the layout comes from
## data/regions.json: size, ground, paths, props, buildings, enemies, exits, a
## landmark, an intro line, and simple interactables. This is how every new
## region (wastes, districts, sky, station, jungle, sewers...) is built without a
## script each; story hooks still live in dialogue below.

@export var region_id := "wastes"
var R: Dictionary = {}
var _anim_nodes: Array = []


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
			var sp := prop(g, nm, c, w, 0.0, bool(p.get("solid", true)))
			if sp and bool(p.get("under", false)):
				sp.z_index = -1
		if bool(p.get("solid", true)):
			var h := int(p.get("h", 1))
			block_rect(c.x, c.y - h + 1, w + 1, h)
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
		var n := int(e.get("count", 1))
		for i in n:
			var at := cell_center(Vector2i(randi_range(4, cols - 5), randi_range(4, rows - 5)))
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


func interact(c: Vector2i, thing: Dictionary) -> bool:
	match str(thing.get("type", "")):
		"note":
			await say([{"who": str(thing.get("who", "")), "text": str(thing.get("text", "...")), "mood": str(thing.get("mood", "neutral"))}])
			return true
		"shop":
			await _shop(thing)
			return true
		"loot":
			var key := "loot_%s_%d_%d" % [region_id, c.x, c.y]
			if int(GameState.run["flags"].get(key, 0)) < int(GameState.run["day"]) - int(thing.get("every", 1)):
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
			await _boss(thing)
			return true
		"door":
			go_to(str(thing["scene"]), Vector2(float(thing["spawn"][0]) * TILE, float(thing["spawn"][1]) * TILE), str(thing.get("facing", "down")))
			return true
		"mrock":
			if not GameState.has_tool("pickaxe"):
				return false
			if not GameState.spend_energy(2):
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
		opts.append("%s  ◆%d" % [GameState.item_name(str(it[0])), int(it[1])])
	opts.append("Leave")
	var d := Dialogue.instance(get_tree())
	d.say([{"who": str(thing.get("who", "Shop")), "text": "%s  (◆%d)" % [str(thing.get("greet", "What'll it be?")), int(GameState.run["crystals"])], "choice": opts, "key": ""}])
	await d.finished
	var i := d.last_choice
	if i < 0 or i >= items.size():
		return
	var id := str(items[i][0])
	var price := int(items[i][1])
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
	player.frozen = true
	await say([{"who": str(thing.get("who", "")), "text": str(thing.get("text", "..."))}])
	var b := spawn_enemy(str(thing.get("kind", "commander")), player.position + Vector2(40, 0))
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
			GameState.run["max_hp"] = int(GameState.run["max_hp"]) + int(_boss_thing["max_hp"])
			GameState.run["hp"] = int(GameState.run["max_hp"])
		GameState.save()
		player.frozen = false


func draw_map() -> void:
	var ground := str(R.get("ground", "grass"))
	if ground == "grass":
		draw_grass(hash(region_id) % 100)
		WorldGen.draw_ground_detail(self, hash(region_id) % 100 + 1, float(R.get("detail", 0.1)))
	elif Art.has("tiles", ground):
		for y in rows:
			for x in cols:
				Art.draw_tile(self, "tiles", ground, Vector2(x * TILE, y * TILE), 4)
	else:
		draw_rect(Rect2(0, 0, cols * TILE, rows * TILE), Color(str(R.get("ground_color", "5a9e4b"))))
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
	draw_exits()
	if bool(R.get("fence", false)) and pad == 0:
		draw_fence_border(Color(str(R.get("fence_color", "6b4a2b"))))


func _process(delta: float) -> void:
	super(delta)
	if not R.get("water", []).is_empty():
		queue_redraw()

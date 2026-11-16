extends GameMap
## A building interior from data/interiors.json (GameMap.next_interior picks which).
## Floor + wall kit, furniture, a counter for shops, an NPC or two, and the door back.

var I: Dictionary = {}
var interior_id := ""
var npcs: Array = []


func scene_id() -> String:
	return "interior"


func default_spawn() -> Vector2:
	var d: Array = I.get("door", [cols / 2, rows - 2])
	return cell_center(Vector2i(int(d[0]), int(d[1]) - 1))


func build() -> void:
	interior_id = GameMap.next_interior if GameMap.next_interior != "" else str(GameState.run.get("interior", "store"))
	GameState.run["interior"] = interior_id
	var all := GameState.load_json("res://data/interiors.json")
	I = all.get(interior_id, all.get("store", {}))
	cols = int(I.get("cols", 14))
	rows = int(I.get("rows", 11))
	has_sky = false
	has_pet = bool(I.get("pet", false))
	music_track = str(I.get("music", "house"))
	block_rect(1, 1, cols - 2, 1)  # back wall
	var d: Array = I.get("door", [cols / 2, rows - 2])
	set_thing(int(d[0]), int(d[1]), {"type": "exit", "hint": "A: go outside"}, false)
	for t in I.get("things", []):
		var c: Array = t["cell"]
		var dd := {}
		for k in t:
			if k != "cell":
				dd[k] = t[k]
		set_thing(int(c[0]), int(c[1]), dd, bool(t.get("solid", true)))


func after_ready() -> void:
	for p in I.get("props", []):
		var c := Vector2i(int(p["cell"][0]), int(p["cell"][1]))
		prop(str(p.get("group", "furniture")), str(p["name"]), c, int(p.get("w", 0)), 0.0, bool(p.get("solid", true)))
	for n in I.get("npcs", []):
		var id := str(n["id"])
		var data: Dictionary = GameState.npcs.get(id, {"name": id.capitalize()})
		var npc := Npc.new()
		npc.map = self
		npc.setup(id, data, cell_center(Vector2i(int(n["cell"][0]), int(n["cell"][1]))))
		npc.wander = 6.0
		add_child(npc)
		npcs.append(npc)
	if I.has("intro") and not GameState.run["flags"].has("int_" + interior_id):
		GameState.run["flags"]["int_" + interior_id] = true
		player.frozen = true
		await say([{"text": str(I["intro"])}])
		player.frozen = false


func has_npc_at(c: Vector2i) -> bool:
	for n: Npc in npcs:
		if n.cell() == c:
			return true
	return false


func interact(c: Vector2i, thing: Dictionary) -> bool:
	for n: Npc in npcs:
		if n.cell() == c or n.position.distance_to(player.position + player.facing_dir() * 14.0) < 16.0:
			_talk(n)
			return true
	match str(thing.get("type", "")):
		"exit":
			var back: Array = I.get("back", ["town", 13, 11])
			go_to(str(back[0]), Vector2(float(back[1]) * TILE + 8, float(back[2]) * TILE + 4), "down")
			return true
		"counter":
			var shop := str(thing.get("shop", ""))
			if shop == "hall":
				await Shops.hall(self)
			elif shop != "":
				await Shops.run(self, shop)
			return true
		"note":
			await say([{"who": str(thing.get("who", "")), "text": str(thing.get("text", "...")), "mood": str(thing.get("mood", "neutral"))}])
			return true
		"bed":
			hud.toast("Not your bed.")
			return true
		"heal":
			if int(GameState.run["flags"].get("heal_" + interior_id, 0)) < int(GameState.run["day"]):
				GameState.run["flags"]["heal_" + interior_id] = int(GameState.run["day"])
				GameState.heal(int(thing.get("hp", 3)))
				GameState.restore_energy(int(thing.get("energy", 30)))
				hud.toast(str(thing.get("msg", "You feel better.")))
			else:
				hud.toast("Once a day.")
			return true
	return false


func _talk(n: Npc) -> void:
	# Same lines as on the street: the town script owns the dialogue tables.
	var data: Dictionary = GameState.npcs.get(n.id, {})
	var lines: Array = data.get("inside", [])
	var name := str(data.get("name", n.id.capitalize()))
	player.frozen = true
	if lines.is_empty():
		await say([{"who": name, "text": "Come in, come in. Mind the step."}])
	else:
		await say([{"who": name, "text": str(lines[int(GameState.run["day"]) % lines.size()])}])
	player.frozen = false


func draw_map() -> void:
	var fl := str(I.get("floor", "fl_wood"))
	var wl := str(I.get("wall", "wl_plaster"))
	if Art.has("tiles", fl):
		draw_tileset_rect(fl, Rect2i(1, 2, cols - 2, rows - 3), Color("a07a4c"))
	else:
		draw_rect(Rect2(TILE, 2 * TILE, (cols - 2) * TILE, (rows - 3) * TILE), Color("a07a4c"))
	for r in I.get("rugs", []):
		draw_tileset_rect(str(r["tile"]), Rect2i(int(r["rect"][0]), int(r["rect"][1]), int(r["rect"][2]), int(r["rect"][3])), Color("b03a2e"))
	for x in range(1, cols - 1):
		var idx := 0 if x == 1 else (2 if x == cols - 2 else 1)
		var nm: String = wl + ["_l", "_m", "_r"][idx]
		var t := Art.tex("tiles", nm)
		if t:
			draw_texture_rect(t, Rect2(x * TILE, 0, TILE, TILE * 2), false)
		else:
			draw_rect(Rect2(x * TILE, 0, TILE, TILE * 2), Color("c9b08a"))
	var night := int(GameState.run["time"]) >= 19 * 60
	for wx in I.get("windows", [4, cols - 5]):
		Art.draw_prop(self, "furniture", "window_night" if night else "window_day", Vector2(int(wx) * TILE + 8, 2 * TILE))
	for p in I.get("wall_props", []):
		Art.draw_prop(self, "furniture", str(p["name"]), Vector2(int(p["x"]) * TILE + 8, 2 * TILE - 2))
	var d: Array = I.get("door", [cols / 2, rows - 2])
	draw_rect(Rect2(int(d[0]) * TILE, int(d[1]) * TILE, TILE, TILE), Color("3a2412"))
	Art.draw_prop(self, "furniture", "door_wood_open", Vector2(int(d[0]) * TILE + 8, (int(d[1]) + 1) * TILE))

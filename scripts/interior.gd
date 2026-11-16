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
		var g := str(p.get("group", "furniture"))
		var nm := str(p["name"])
		var w := int(p.get("w", 0))
		if bool(p.get("anim", false)) and Art.has(g, nm) and int(Art.info(g, nm).get("frames", 1)) > 1:
			var a := AnimatedSprite2D.new()
			a.sprite_frames = Art.frames(g, {"idle": nm}, {"idle": 5.0})
			a.animation = "idle"
			a.scale = Vector2(0.5, 0.5)
			a.position = cell_pos(c.x + (w + 1) / 2.0, c.y + 1)
			a.offset = Vector2(0, -float(Art.info(g, nm).get("cell_h", 48)) / 2.0)
			add_child(a)
			a.play("idle")
			if bool(p.get("solid", true)):
				for i in w + 1:
					blocked[Vector2i(c.x + i, c.y)] = true
			continue
		prop(g, nm, c, w, 0.0, bool(p.get("solid", true)))
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
		if n.cell() == c or (thing.is_empty() and n.position.distance_to(player.position + player.facing_dir() * 14.0) < 16.0):
			_talk(n)
			return true
	match str(thing.get("type", "")):
		"exit":
			var back: Array = I.get("back", ["town", 13, 11])
			go_to(str(back[0]), Vector2(float(back[1]) * TILE + 8, float(back[2]) * TILE + 4), "down")
			return true
		"counter":
			later(_counter.bind(str(thing.get("shop", ""))))
			return true
		"craft":
			later(Crafting.run.bind(self, str(thing.get("station", "workbench")), str(thing.get("hint", "")).trim_prefix("A: ")))
			return true
		"note":
			tell([{"who": str(thing.get("who", "")), "text": str(thing.get("text", "...")), "mood": str(thing.get("mood", "neutral"))}])
			return true
		"bed":
			hud.toast("Not your bed.")
			return true
		"loot":
			var key := "loot_%s_%d_%d" % [interior_id, c.x, c.y]
			if int(GameState.run["flags"].get(key, 0)) < int(GameState.run["day"]) - int(thing.get("every", 1)):
				GameState.run["flags"][key] = int(GameState.run["day"])
				give(str(thing.get("item", "stone")), int(thing.get("n", 1)))
			else:
				hud.toast(str(thing.get("empty", "Nothing here right now.")))
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
	emote(n, "talk", 1.0, -30.0)
	# Same lines as on the street: the town script owns the dialogue tables.
	var data: Dictionary = GameState.npcs.get(n.id, {})
	var lines: Array = data.get("inside", [])
	var name := str(data.get("name", n.id.capitalize()))
	player.frozen = true
	var offer := GameState.side_quest_for(n.id)
	if not offer.is_empty():
		var d := Dialogue.instance(get_tree())
		d.say([{"who": name, "text": str(offer["text"]) + "  Will you?", "choice": ["Sure", "Not now"], "key": ""}])
		await d.finished
		if d.last_choice == 0:
			GameState.add_quest(str(offer["id"]), str(offer["text"]))
			hud.toast("New quest from %s." % name, Color(1, 0.9, 0.4))
		player.frozen = false
		return
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
	var windows: Array = I.get("windows", [4, cols - 5])
	for x in range(1, cols - 1):
		var part: String = "_l" if x == 1 else ("_r" if x == cols - 2 else ["_m", "_m2", "_m3"][x % 3])
		if x in windows and Art.has("tiles", wl + "_window"):
			part = "_window"
		elif part != "_l" and part != "_r" and not Art.has("tiles", wl + part):
			part = "_m"
		var t := Art.tex("tiles", wl + part)
		if t:
			draw_texture_rect(t, Rect2(x * TILE, 0, TILE, TILE * 2), false)
		else:
			draw_rect(Rect2(x * TILE, 0, TILE, TILE * 2), Color("c9b08a"))
	var night := int(GameState.run["time"]) >= 19 * 60
	if not Art.has("tiles", wl + "_window"):
		for wx in windows:
			Art.draw_prop(self, "furniture", "window_night" if night else "window_day", Vector2(int(wx) * TILE + 8, 2 * TILE))
	for p in I.get("wall_props", []):
		Art.draw_prop(self, "furniture", str(p["name"]), Vector2(int(p["x"]) * TILE + 8, 2 * TILE - 2))
	var d: Array = I.get("door", [cols / 2, rows - 2])
	draw_rect(Rect2(int(d[0]) * TILE, int(d[1]) * TILE, TILE, TILE), Color("3a2412"))
	Art.draw_prop(self, "furniture", "door_wood_open", Vector2(int(d[0]) * TILE + 8, (int(d[1]) + 1) * TILE))


func _counter(shop: String) -> void:
	if shop == "hall":
		await Shops.hall(self)
	elif shop in ["smith", "potions"]:
		var d := Dialogue.instance(get_tree())
		var ch: Array = ["Buy", "Craft" if shop == "smith" else "Brew"]
		if shop == "smith":
			ch.append("Upgrade a tool")
		ch.append("Leave")
		d.say([{"who": "Gideon" if shop == "smith" else "Wren", "text": "Buying, or making something?", "choice": ch, "key": ""}])
		await d.finished
		if d.last_choice == 0:
			await Shops.run(self, shop)
		elif d.last_choice == 1:
			await Crafting.run(self, "smith" if shop == "smith" else "alchemy", "Forge" if shop == "smith" else "Cauldron")
		elif d.last_choice == 2 and shop == "smith":
			await _upgrade_tools()
	elif shop != "":
		await Shops.run(self, shop)


## Gideon's upgrade bench: every tool climbs wood → copper → iron → steel →
## silver → gold → crystal → moon. Needs bars of the next metal and crystals.
func _upgrade_tools() -> void:
	while true:
		var opts: Array = []
		var kinds: Array = []
		for k in GameState.TOOL_KINDS:
			if not GameState.has_tool(k) and not (k == "sword" and GameState.has_tool("iron_sword")):
				continue
			var t := GameState.tool_tier(k)
			if t + 1 >= GameState.TOOL_TIERS.size():
				opts.append("%s: moon (max)" % GameState.item_name(k))
			else:
				var need: Dictionary = GameState.TOOL_UPGRADE_NEED[t + 1]
				var parts: Array = []
				for id in need:
					parts.append("%d %s" % [int(need[id]), "◆" if id == "crystals" else GameState.item_name(str(id))])
				opts.append("%s%s → %s  [%s]" % ["" if GameState.can_upgrade_tool(k) else "✗ ", GameState.item_name(k), GameState.TOOL_TIERS[t + 1], ", ".join(parts)])
			kinds.append(k)
		opts.append("Leave")
		var d := Dialogue.instance(get_tree())
		d.say([{"who": "Gideon", "text": "Hand it over. Better metal, same handle.", "choice": opts, "key": ""}])
		await d.finished
		var i := d.last_choice
		if i < 0 or i >= kinds.size():
			return
		var kind: String = kinds[i]
		if GameState.upgrade_tool(kind):
			hud.toast("%s upgraded!" % GameState.item_name(kind), Color(1, 0.9, 0.4))
			Music.instance(get_tree()).sfx("levelup")
			xp("mining", 6)
			if player:
				fx("levelup", player.position + Vector2(0, -12), 12.0, 0.8)
		else:
			hud.toast("Not enough for that yet.", Color(1, 0.7, 0.7))

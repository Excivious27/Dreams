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
	GameMap.next_interior = ""
	GameState.run["interior"] = interior_id
	var all := GameState.load_json("res://data/interiors.json")
	I = all.get(interior_id, all.get("store", {}))
	cols = int(I.get("cols", 14))
	rows = int(I.get("rows", 11))
	exact_footprints = true
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
	# Keep the way in and the spot in front of every counter/thing walkable.
	var dd: Array = I.get("door", [cols / 2, rows - 2])
	blocked.erase(Vector2i(int(dd[0]), int(dd[1]) - 1))
	for t in I.get("things", []):
		var tc := Vector2i(int(t["cell"][0]), int(t["cell"][1]))
		for off in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var fc: Vector2i = tc + off
			if fc.x > 0 and fc.y > 1 and fc.x < cols - 1 and fc.y < rows - 1 and not things.has(fc):
				blocked.erase(fc)
				hard.erase(fc)
				break
	# Who is in here right now: anyone whose routine puts them in this interior
	# (their work, their home, or a named place like the inn/school/chapel). The
	# interior's own "npcs" list gives preferred standing cells; everyone else
	# takes a free floor cell.
	var listed := {}
	for n in I.get("npcs", []):
		listed[str(n["id"])] = Vector2i(int(n["cell"][0]), int(n["cell"][1]))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(interior_id) + int(GameState.run["day"])
	var used := {}
	for id in GameState.npcs:
		var data: Dictionary = GameState.npcs.get(id, {"name": str(id).capitalize()})
		var place := Npc.place_now(data.get("routine", []), str(id))
		var here := _interior_matches(place, str(id))
		if data.get("routine", []).is_empty():
			here = listed.has(id)  # region folk with no routine: where the file says
		if not here:
			continue
		var at: Vector2i = listed.get(id, Vector2i(-1, -1))
		if at == Vector2i(-1, -1) or used.has(at):
			for tries in 60:
				var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(4, rows - 3))
				if not blocked.has(c) and not things.has(c) and not used.has(c):
					at = c
					break
		if at == Vector2i(-1, -1):
			continue
		used[at] = true
		var npc := Npc.new()
		npc.map = self
		npc.setup(str(id), data, cell_center(at))
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


## Does a routine place ("work", "home", "inn", ...) mean this interior?
func _interior_matches(place: String, npc_id := "") -> bool:
	var nd: Dictionary = GameState.npcs.get(npc_id, {})
	match place:
		"work": return interior_id == str(nd.get("work", "")) or (nd.get("work", null) == null and interior_id in ["store", "smith", "potions", "hall", "bakery", "clinic", "library", "fishing_hut", "lodge", "inn"])
		"home": return interior_id == str(nd.get("home", "")) or (nd.get("home", null) == null and interior_id in ["mansion", "cottage_a", "cottage_b", "cottage_c", "hazel_house", "lodge"])
		"inn": return interior_id == "inn"
		"chapel": return interior_id == "chapel"
		"school": return interior_id == "school"
		"clinic": return interior_id == "clinic"
		"library": return interior_id == "library"
		"hall": return interior_id == "hall"
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
			later(Crafting.run.bind(self, str(thing.get("station", "workbench")), str(thing.get("hint", "")).trim_prefix("A: "), "town"))
			return true
		"stable":
			later(_stable)
			return true
		"bank":
			later(_bank)
			return true
		"note":
			tell([{"who": str(thing.get("who", "")), "text": str(thing.get("text", "...")), "mood": str(thing.get("mood", "neutral"))}])
			return true
		"bed":
			hud.toast("Not your bed.")
			return true
		"loot":
			var key := "loot_%s_%d_%d" % [interior_id, c.x, c.y]
			if int(GameState.run["flags"].get(key, 0)) <= int(GameState.run["day"]) - int(thing.get("every", 1)):
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
	if not GameState.run["talked_today"].has(n.id):
		GameState.run["talked_today"][n.id] = true
		GameState.add_friend(n.id, 5)
	if await Story.talk(self, n.id):
		player.frozen = false
		return
	if await Hearts.talk(self, n.id):
		player.frozen = false
		return
	if await Quests.talk(self, n.id, name):
		player.frozen = false
		return
	# Gifts work indoors too.
	var sel := str(GameState.run["selected"])
	var it: Dictionary = GameState.items.get(sel, {})
	if GameState.can_gift(n.id, sel) and await confirm_gift(name, sel):
		var gain := GameState.give_gift(n.id, sel)
		await say([{"who": name, "text": gift_reaction(name, sel, gain)}])
		hud.toast("%s %s%d" % [name, "+" if gain >= 0 else "", gain], Color(1, 0.8, 0.9) if gain > 0 else Color(1, 0.7, 0.7))
		player.frozen = false
		return
	if lines.is_empty():
		await say(Talk.line(n.id))
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
	var night := GameState.is_night()
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
			await Crafting.run(self, "smith" if shop == "smith" else "alchemy", "Gideon's Forge" if shop == "smith" else "Wren's Cauldron", "town")
		elif d.last_choice == 2 and shop == "smith":
			await _upgrade_tools()
	elif shop != "":
		await Shops.run(self, shop)


## Gideon's upgrade bench: every tool climbs wood → copper → iron → steel →
## silver → gold → crystal → moon. Needs bars of the next metal and crystals.
func _upgrade_tools() -> void:
	# A tool left with Gideon comes back the next morning (Sun Haven style).
	var pend: Dictionary = GameState.run.get("jobs", {}).get("smith_upgrade", {})
	if not pend.is_empty():
		if Crafting.now_abs() >= int(pend["done_at"]):
			var k0 := str(pend["kind"])
			GameState.run["jobs"].erase("smith_upgrade")
			GameState.run["flags"]["tool_away_" + k0] = false
			GameState.run["flags"].erase("tool_away_" + k0)
			hud.toast("%s upgraded!" % GameState.item_name(k0), Color(1, 0.9, 0.4))
			Music.instance(get_tree()).sfx("levelup")
			xp("mining", 6)
			if player:
				fx("levelup", player.position + Vector2(0, -12), 12.0, 0.8)
			await say([{"who": "Gideon", "text": "There. Try not to break it before lunch."}])
		else:
			await say([{"who": "Gideon", "text": "Your %s is on the bench. %s. Come back then." % [GameState.item_name(str(pend["kind"])), Crafting.fmt_minutes(int(pend["done_at"]) - Crafting.now_abs())]}])
			return
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
				var need: Dictionary = GameState.upgrade_need(k)
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
			# Paid and handed over: the tool is away until tomorrow morning.
			var t := GameState.tool_tier(kind)
			var hours := 6 + 4 * t
			GameState.run["jobs"] = GameState.run.get("jobs", {})
			GameState.run["jobs"]["smith_upgrade"] = {"kind": kind, "done_at": Crafting.now_abs() + hours * 60}
			GameState.run["flags"]["tool_away_" + kind] = true
			hud.toast("Gideon takes the %s. Ready in %dh." % [GameState.item_name(kind), hours], Color(1, 0.9, 0.4))
			Music.instance(get_tree()).sfx("plant")
			return
		else:
			hud.toast("Not enough for that yet.", Color(1, 0.7, 0.7))


## Benno's stable: buy a horse, then ride out from here whenever you like.
func _stable() -> void:
	var d := Dialogue.instance(get_tree())
	if not GameState.run["flags"].has("horse"):
		var price := 1000 if GameState.has_friend_perk("benno", 2) else 2000
		d.say([{"who": "Benno", "text": "Four in the stalls. All steady. ◆%d, saddle included.  (you have ◆%d)" % [price, int(GameState.run["crystals"])], "choice": ["The bay", "The grey", "The black", "The palomino", "Not yet"], "key": ""}])
		await d.finished
		if d.last_choice >= 0 and d.last_choice < 4:
			if int(GameState.run["crystals"]) < price:
				hud.toast("Not enough crystals.", Color(1, 0.7, 0.7))
				return
			GameState.run["crystals"] = int(GameState.run["crystals"]) - price
			GameState.run["flags"]["horse"] = true
			GameState.run["names"]["horse"] = "Clover"
			GameState.run["names"]["horse_coat"] = ["bay", "grey", "black", "palomino"][d.last_choice]
			hud.toast("Clover is yours!", Color(1, 0.9, 0.4))
			Music.instance(get_tree()).sfx("levelup")
			GameState.add_friend("benno", 10)
		return
	d.say([{"who": "Benno", "text": "Clover's saddled. Ride out?  (A/C with nothing in front of you dismounts; she waits where you leave her.)", "choice": ["Ride", "Not now"], "key": ""}])
	await d.finished
	if d.last_choice == 0:
		player.mount()
		var back: Array = I.get("back", ["town", 32, 93])
		go_to(str(back[0]), Vector2(float(back[1]) * TILE, float(back[2]) * TILE), "down")


## Ivy's bank: deposit crystals for interest (1% a day, 2% at 6 hearts), withdraw any time.
func _bank() -> void:
	var d := Dialogue.instance(get_tree())
	var bal := int(GameState.run.get("bank", 0))
	var rate := 2 if GameState.has_friend_perk("ivy", 6) else 1
	d.say([{"who": "Ivy", "text": "Balance ◆%d, %d%% a day.  You're carrying ◆%d." % [bal, rate, int(GameState.run["crystals"])], "choice": ["Deposit 100", "Deposit all", "Withdraw all", "Leave"], "key": ""}])
	await d.finished
	match d.last_choice:
		0:
			if int(GameState.run["crystals"]) >= 100:
				GameState.run["crystals"] = int(GameState.run["crystals"]) - 100
				GameState.run["bank"] = bal + 100
				hud.toast("Deposited ◆100.")
			else:
				hud.toast("Not enough on you.", Color(1, 0.7, 0.7))
		1:
			GameState.run["bank"] = bal + int(GameState.run["crystals"])
			GameState.run["crystals"] = 0
			hud.toast("Deposited everything.")
		2:
			GameState.run["crystals"] = int(GameState.run["crystals"]) + bal
			GameState.run["bank"] = 0
			hud.toast("Withdrew ◆%d." % bal)

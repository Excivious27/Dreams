extends GameMap
## Your plot of land. Farming (hoe, plant, water, harvest), sell box, pond fishing,
## berry bushes, trees for wood, the house door, exits to town (south) and the
## meadow (east). The story opening plays here on day 1.

const PLOT := Rect2i(10, 5, 8, 8)
const POND := Rect2i(12, 18, 6, 5)
const HOUSE := Rect2i(3, 3, 6, 5)
const DOOR := Vector2i(5, 7)
const SELLBOX := Vector2i(3, 10)
const CRYSTAL_SPOT := Vector2i(12, 15)
const TOWN_EXIT := Rect2i(9, 28, 2, 2)
const MEADOW_EXIT := Rect2i(18, 14, 2, 2)
const TREES := [Vector2i(3, 14), Vector2i(5, 19), Vector2i(3, 24), Vector2i(8, 25), Vector2i(16, 26), Vector2i(2, 17), Vector2i(7, 21)]
const BUSHES := [Vector2i(6, 16), Vector2i(15, 3), Vector2i(10, 24), Vector2i(17, 10)]

var _pond: Scenery.Pond
var _crystal: Node2D
var _fishing := false
var _fish_bite := false
var _crystal_t := 0.0


func scene_id() -> String:
	return "farm"


func default_spawn() -> Vector2:
	return cell_center(Vector2i(7, 12))


func build() -> void:
	cols = 20
	rows = 30
	music_track = "farm"
	block_rect(HOUSE.position.x, HOUSE.position.y, HOUSE.size.x, HOUSE.size.y)
	set_thing(DOOR.x, DOOR.y, {"type": "door", "hint": "A: go inside"})
	set_thing(HOUSE.position.x + 6, HOUSE.position.y + 4, {"type": "mailbox", "hint": "A: check mailbox"})
	set_thing(SELLBOX.x, SELLBOX.y, {"type": "sellbox", "hint": "A: sell what you're holding"})
	for y in range(POND.position.y, POND.end.y):
		for x in range(POND.position.x, POND.end.x):
			set_thing(x, y, {"type": "water", "hint": "A: fish" if GameState.has_tool("rod") else ""})
	for t: Vector2i in TREES:
		set_thing(t.x, t.y, {"type": "tree", "hp": 3, "hint": "A: chop"})
	for b: Vector2i in BUSHES:
		var key := "bush_%d_%d" % [b.x, b.y]
		var picked_day := int(GameState.run["flags"].get(key, 0))
		var has := picked_day < int(GameState.run["day"])
		set_thing(b.x, b.y, {"type": "bush", "key": key, "berries": has, "hint": "A: pick berries" if has else ""})
	for y in range(PLOT.position.y, PLOT.end.y):
		for x in range(PLOT.position.x, PLOT.end.x):
			things[Vector2i(x, y)] = {"type": "plot"}
	if GameState.is_penguins() and bool(GameState.run["intro_done"]):
		set_thing(CRYSTAL_SPOT.x, CRYSTAL_SPOT.y, {"type": "crystal", "hint": "A: talk to the Light Crystal"})


func after_ready() -> void:
	for r: Rect2i in [TOWN_EXIT, MEADOW_EXIT]:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				blocked.erase(Vector2i(x, y))
	_pond = Scenery.Pond.new()
	_pond.rect = Rect2(POND.position * TILE, POND.size * TILE)
	add_child(_pond)
	move_child(_pond, 0)
	add_child(GameMenu.new())
	if GameState.is_penguins() and bool(GameState.run["intro_done"]):
		_make_crystal()
	if not bool(GameState.run["intro_done"]):
		_intro.call_deferred()


func _make_crystal() -> void:
	_crystal = Node2D.new()
	_crystal.position = cell_center(CRYSTAL_SPOT)
	_crystal.draw.connect(func() -> void:
		var c := _crystal
		var glow := 0.5 + 0.5 * sin(_crystal_t * 2.0)
		c.draw_circle(Vector2(0, -8), 11.0 + glow * 2.0, Color(0.6, 0.85, 1.0, 0.18))
		var pts := PackedVector2Array([Vector2(0, -20), Vector2(5, -10), Vector2(0, 2), Vector2(-5, -10)])
		c.draw_colored_polygon(pts, Color(0.75, 0.9, 1.0))
		c.draw_colored_polygon(PackedVector2Array([Vector2(0, -20), Vector2(5, -10), Vector2(0, -8)]), Color(1, 1, 1, 0.8))
		c.draw_circle(Vector2(0, 1), 5.0, Color(0, 0, 0, 0.2)))
	add_child(_crystal)


func _process(delta: float) -> void:
	super(delta)
	if _crystal:
		_crystal_t += delta
		_crystal.position.y = cell_center(CRYSTAL_SPOT).y - 3.0 - sin(_crystal_t * 1.5) * 2.0
		_crystal.queue_redraw()
	if player.frozen or _changing:
		return
	var c := player.cell()
	if TOWN_EXIT.has_point(c):
		go_to("town", Vector2(10 * TILE, 2 * TILE + 8), "down")
	elif MEADOW_EXIT.has_point(c):
		go_to("meadow", Vector2(2 * TILE, 10 * TILE), "right")


# ---- interaction -------------------------------------------------------------

func interact(c: Vector2i, thing: Dictionary) -> bool:
	var sel := str(GameState.run["selected"])
	match str(thing.get("type", "")):
		"door":
			go_to("house", Vector2(5 * TILE + 8, 7 * TILE), "up")
			return true
		"mailbox":
			_mailbox()
			return true
		"sellbox":
			_sellbox(sel)
			return true
		"water":
			if GameState.has_tool("rod") and not _fishing:
				_fish()
			return true
		"tree":
			if not GameState.spend_energy(2):
				hud.toast("Too tired.", Color(1, 0.7, 0.7))
				return true
			Music.instance(get_tree()).sfx("chop")
			thing["hp"] = int(thing["hp"]) - 1
			if int(thing["hp"]) <= 0:
				thing["hp"] = 3
				give("wood", 3)
				xp("foraging", 3)
			return true
		"bush":
			if bool(thing.get("berries", false)):
				thing["berries"] = false
				thing["hint"] = ""
				GameState.run["flags"][thing["key"]] = int(GameState.run["day"])
				give("berry", 2)
				xp("foraging", 2)
				queue_redraw()
			return true
		"crystal":
			_talk_crystal()
			return true
		"plot":
			return _farm_tile(c, sel)
	# Nothing in front of you: eat/drink what you hold.
	return _use_consumable(sel)


func _use_consumable(sel: String) -> bool:
	if sel == "" or GameState.count(sel) <= 0:
		return false
	var it: Dictionary = GameState.items.get(sel, {})
	if it.has("heal") or it.has("energy"):
		GameState.add_item(sel, -1)
		GameState.heal(int(it.get("heal", 0)))
		GameState.restore_energy(int(it.get("energy", 0)) + int(it.get("heal", 0)) * 8)
		hud.toast("Ate %s." % GameState.item_name(sel))
		Music.instance(get_tree()).sfx("pickup")
		return true
	return false


func _farm_tile(c: Vector2i, sel: String) -> bool:
	var key := "%d,%d" % [c.x, c.y]
	var farm: Dictionary = GameState.run["farm"]
	var tile: Dictionary = farm.get(key, {})
	if tile.is_empty():
		if not GameState.has_tool("hoe"):
			return false
		if not GameState.spend_energy(2):
			hud.toast("Too tired.", Color(1, 0.7, 0.7))
			return true
		farm[key] = {"watered": false, "crop": "", "days": 0}
		Music.instance(get_tree()).sfx("dig")
		xp("farming", 1)
		queue_redraw()
		return true
	var crop := str(tile.get("crop", ""))
	if crop == "":
		var it: Dictionary = GameState.items.get(sel, {})
		if it.get("type", "") == "seed" and GameState.count(sel) > 0:
			tile["crop"] = str(it["crop"])
			tile["days"] = 0
			GameState.add_item(sel, -1)
			Music.instance(get_tree()).sfx("plant")
			xp("farming", 2)
			queue_redraw()
			return true
		if not bool(tile.get("watered", false)):
			return _water(tile)
		hud.toast("Hold seeds (MENU) to plant here.")
		return true
	var cd: Dictionary = GameState.crops[crop]
	if int(tile["days"]) >= int(cd["days"]):
		var n := 1 + (1 if randf() < 0.1 * GameState.skill_level("farming") else 0)
		give(str(cd["yield"]), n)
		xp("farming", 6)
		tile["crop"] = ""
		tile["days"] = 0
		_check_first_harvest()
		queue_redraw()
		return true
	if not bool(tile.get("watered", false)):
		return _water(tile)
	hud.toast("%s: %d more day%s." % [cd["name"], int(cd["days"]) - int(tile["days"]), "" if int(cd["days"]) - int(tile["days"]) == 1 else "s"])
	return true


func _water(tile: Dictionary) -> bool:
	if not GameState.has_tool("can"):
		return false
	if not GameState.spend_energy(1):
		hud.toast("Too tired.", Color(1, 0.7, 0.7))
		return true
	tile["watered"] = true
	Music.instance(get_tree()).sfx("water")
	queue_redraw()
	return true


func _check_first_harvest() -> void:
	if GameState.complete_quest("first_harvest"):
		hud.toast("Quest done: first harvest!", Color(1, 0.9, 0.4))
		GameState.run["crystals"] = int(GameState.run["crystals"]) + 25


func _sellbox(sel: String) -> void:
	var box: Dictionary = GameState.run["sellbox"]
	if sel != "" and GameState.count(sel) > 0 and GameState.items.get(sel, {}).get("type", "") != "tool":
		var n := GameState.count(sel)
		box[sel] = int(box.get(sel, 0)) + n
		GameState.add_item(sel, -n)
		hud.toast("Put %d %s in the sell box (◆%d tonight)." % [n, GameState.item_name(sel), n * GameState.item_value(sel)])
		Music.instance(get_tree()).sfx("pickup")
		return
	if box.is_empty():
		await say([{"text": "The sell box is empty. Hold an item (MENU) and press A here to sell it. You get paid in crystals overnight."}])
	else:
		var lines: Array = []
		var total := 0
		for id in box:
			total += GameState.item_value(id) * int(box[id])
		await say([{"text": "In the box: %s. Worth ◆%d, paid tonight." % [", ".join(box.keys().map(func(k: String) -> String: return "%s x%d" % [GameState.item_name(k), int(box[k])])), total]}])


func _mailbox() -> void:
	var flags: Dictionary = GameState.run["flags"]
	var day := int(GameState.run["day"])
	if GameState.is_penguins():
		if not flags.has("mail_1"):
			flags["mail_1"] = true
			await say([
				{"who": "Letter", "text": "Welcome to %s! Stop by the general store when you can. First bag of seeds is on me. - Maple" % GameState.names()["town"]},
			])
			give("strawberry_seed", 3)
			return
		if day >= 3 and not flags.has("mail_2"):
			flags["mail_2"] = true
			await say([{"who": "Letter", "text": "Dear neighbor, something has been howling from the east meadow at night. Mayor Alder says it's nothing. It is not nothing. - Wren"}])
			GameState.add_quest("clear_meadow", "Find out what's howling in the east meadow.")
			return
	else:
		if not flags.has("mail_1"):
			flags["mail_1"] = true
			await say([
				{"who": "Letter", "text": "The plot is yours under the name on the deed. Nobody here knows your real one. Keep it that way. Earn your keep and don't draw eyes. - M."},
			])
			return
		if day >= 3 and not flags.has("mail_2"):
			flags["mail_2"] = true
			await say([{"who": "Letter", "text": "A man came through town asking about a face like yours. He went east, toward the meadow. Be careful. - M."}])
			GameState.add_quest("clear_meadow", "Someone is asking about you. Check the east meadow.")
			return
	await say([{"text": "No new mail."}])


func _talk_crystal() -> void:
	var r := GameState.run
	var d: Dictionary = r["decisions"]
	if not GameState.quest_done("first_harvest"):
		await say([
			{"who": "Light Crystal", "text": "Tend the soil, %s. Every living thing you raise feeds the Meow Pow Wow a little." % GameState.names()["character"]},
			{"who": "Light Crystal", "text": "Till with A. Hold seeds from the MENU and press A to plant. Water each day. The sell box pays you in crystals overnight."},
		])
	elif not GameState.quest_done("clear_meadow"):
		await say([
			{"who": "Light Crystal", "text": "I feel Grumps gathering in the meadow to the east. They are small now. They will not stay small."},
			{"who": "Light Crystal", "text": "Your sword is wood, but your heart is not. Go when you're ready."},
		])
	else:
		await say([
			{"who": "Light Crystal", "text": "The first spark of the Meow Pow Wow is yours. The rest is scattered across this world, and beyond it."},
			{"who": "Light Crystal", "text": "Tom hasn't written the next chapter yet. (Really. That's the next guide.)"},
		])


# ---- fishing -----------------------------------------------------------------

func _fish() -> void:
	if not GameState.spend_energy(2):
		hud.toast("Too tired.", Color(1, 0.7, 0.7))
		return
	_fishing = true
	_fish_bite = false
	player.frozen = true
	hud.toast("Casting... wait for the !")
	var wait := randf_range(1.5, 4.0)
	var t := 0.0
	var caught := false
	while t < wait + 1.0:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		if not _fish_bite and t >= wait:
			_fish_bite = true
			hud.toast("!!!  Press A!", Color(1, 1, 0.4))
			Music.instance(get_tree()).sfx("bite")
		if Input.is_action_just_pressed("a") and t > 0.2:
			if _fish_bite:
				caught = true
			break
	player.frozen = false
	_fishing = false
	if caught:
		var roll := randf()
		var fish := "boot" if roll < 0.12 else ("trout" if roll < 0.12 + 0.08 * GameState.skill_level("fishing") else "minnow")
		give(fish)
		xp("fishing", 4)
	else:
		hud.toast("It got away.")


# ---- story -------------------------------------------------------------------

func _intro() -> void:
	player.frozen = true
	var n := GameState.names()
	if GameState.is_penguins():
		await _intro_penguins(n)
	else:
		await _intro_gangsters(n)
	GameState.run["intro_done"] = true
	GameState.save()
	player.frozen = false


func _intro_penguins(n: Dictionary) -> void:
	var who: String = n["character"]
	var pet_name: String = n["pet"]
	var town: String = n["town"]
	await say([
		{"text": "Far past the edge of the sky, something fell."},
		{"text": "It crossed a thousand dark skies, dimmer with every one, looking for a place that still had joy in it."},
		{"text": "It found %s. It found a little plot of land with a crooked house. It found you, %s." % [town, who]},
	])
	await hud.fade_out(0.6)
	_make_crystal()
	set_thing(CRYSTAL_SPOT.x, CRYSTAL_SPOT.y, {"type": "crystal", "hint": "A: talk to the Light Crystal"})
	player.position = cell_center(Vector2i(12, 17))
	player.facing = "up"
	if pet:
		pet.position = player.position + Vector2(-14, 4)
	await hud.fade_in(0.8)
	Music.instance(get_tree()).sfx("levelup")
	await say([
		{"who": "???", "text": "...you can hear me? Good. Good. I was starting to think I'd landed on a world of rocks."},
		{"who": "Light Crystal", "text": "I am a Light Crystal. Where I come from, we are the memory of every kind thing anyone ever did. We are... fewer than we were."},
		{"who": "Light Crystal", "text": "One of us went dark. It calls itself the Dark Crystal now. It turned others. It built an army of Grumps whose only job is to squeeze the joy out of everything, world by world."},
		{"who": "Light Crystal", "text": "I carry the last piece of something that can stop it. A power called the Meow Pow Wow. Most of it is scattered. I can only give you the first spark."},
		{"who": "Light Crystal", "text": "I need someone with their feet in the dirt and their heart in the right place. The question is whether that's you."},
		{"who": "Light Crystal", "text": "So. %s. Will you help me?" % who, "choice": ["I'll help. Where do we start?", "I just want to farm in peace.", "Who said I'd trust a talking rock?"], "key": "crystal_answer"},
	])
	var ans := int(GameState.run["decisions"].get("crystal_answer", 0))
	if ans == 0:
		await say([
			{"who": "Light Crystal", "text": "Then we start small. Here, in this soil. The Meow Pow Wow grows from living things, so grow living things."},
		])
		GameState.run["crystals"] = int(GameState.run["crystals"]) + 10
		GameState.run["flags"]["crystal_trust"] = 2
	elif ans == 1:
		await say([
			{"who": "Light Crystal", "text": "...Peace. Yes. That's exactly what the Grumps will take first. Farm, then. I'll wait. I'm very good at waiting."},
		])
		GameState.run["flags"]["crystal_trust"] = 1
	else:
		await say([
			{"who": "Light Crystal", "text": "Fair. I wouldn't either. I'll be here, glowing uselessly in your yard, until you change your mind."},
			{"who": "Light Crystal", "text": "...I am not a rock."},
		])
		GameState.run["flags"]["crystal_trust"] = 0
	await say([
		{"who": "Light Crystal", "text": "That little one by your feet - %s, is it? - has more Meow Pow Wow in one paw than this whole valley. Keep them close." % pet_name},
		{"who": "Light Crystal", "text": "Till the ground with A. Plant seeds from your MENU. Water every morning. When your first crop comes in, we'll talk again."},
	])
	GameState.add_quest("first_harvest", "Grow and harvest your first crop.")
	GameState.add_quest("meet_town", "Walk south and meet the people of %s." % town)
	hud.toast("New quests. Open MENU to see them.", Color(1, 0.9, 0.4))


func _intro_gangsters(n: Dictionary) -> void:
	var who: String = n["character"]
	var pet_name: String = n["pet"]
	var town: String = n["town"]
	Music.instance(get_tree()).play("rain")
	await say([
		{"text": "Rain. The kind that gets in under your collar and stays."},
		{"text": "You came up the south road after dark so nobody in %s would see your face. The deed in your pocket has a name on it that isn't yours." % town},
		{"text": "A crooked house. A plot of mud. A mailbox. This is what's left of your life, %s." % who},
		{"text": "Somewhere a long way from here, the man who took the rest of it is probably sleeping very well."},
	])
	await hud.fade_out(0.6)
	player.position = cell_center(Vector2i(10, 26))
	player.facing = "up"
	if pet:
		pet.position = player.position + Vector2(-14, 4)
	await hud.fade_in(0.8)
	await say([
		{"text": "There's a letter in the mailbox. You already know who it's from. M. is the only one who knows you're alive."},
		{"text": "The envelope has something written on the back, in a hand you don't recognize:"},
		{"who": "Unknown hand", "text": "\"WE KNOW WHERE YOU WENT.\""},
		{"who": who, "text": "...", "choice": ["Burn the letter. Leave no trail.", "Keep it. Evidence is evidence.", "Read it twice. Memorize the handwriting."], "key": "letter"},
	])
	var ans := int(GameState.run["decisions"].get("letter", 0))
	if ans == 0:
		await say([{"text": "You burn it in the sink. The handwriting goes with it. Whoever they are, they'll have to find you the hard way."}])
		GameState.run["flags"]["letter"] = "burned"
	elif ans == 1:
		await say([{"text": "You fold it into the deed. If this goes to court someday, or to a grave, it goes with you."}])
		GameState.run["flags"]["letter"] = "kept"
	else:
		await say([{"text": "The loops on the W. The hard press on the K. You'll know it when you see it again. You're sure you will."}])
		GameState.run["flags"]["letter"] = "memorized"
	await say([
		{"text": "%s shakes the rain off and looks up at you like all of this is normal. Maybe for a while it can be." % pet_name},
		{"text": "You'll need money to move on anyone. Money means crops. Crops mean dirt under your nails. Fine."},
		{"text": "Till with A. Hold seeds from the MENU and press A to plant. Water each morning. Sell at the box. Don't draw eyes."},
	])
	GameState.add_quest("first_harvest", "Grow and sell something. You need ◆200 before you can do anything.")
	GameState.add_quest("meet_town", "Go south. Learn who in %s can be bought, and who is watching." % town)
	hud.toast("New quests. Open MENU to see them.", Color(1, 0.9, 0.4))


# ---- drawing -----------------------------------------------------------------

func _draw() -> void:
	draw_grass()
	# House
	draw_building(HOUSE.position.x, HOUSE.position.y, HOUSE.size.x, HOUSE.size.y, Color("8b5a2b"), Color("b03a2e"), "")
	draw_rect(Rect2((HOUSE.position.x + 6) * TILE + 5, (HOUSE.position.y + 4) * TILE + 2, 6, 10), Color("5a5a66"))
	draw_rect(Rect2((HOUSE.position.x + 6) * TILE + 7, (HOUSE.position.y + 4) * TILE + 12, 2, 4), Color("333"))
	# Plot
	draw_rect(Rect2(PLOT.position * TILE, PLOT.size * TILE), Color("6f8f45"))
	var farm: Dictionary = GameState.run["farm"]
	for key in farm:
		var parts: PackedStringArray = str(key).split(",")
		var c := Vector2i(int(parts[0]), int(parts[1]))
		var tile: Dictionary = farm[key]
		var soil := Color("5c3d22") if bool(tile.get("watered", false)) else Color("8a5f38")
		draw_rect(Rect2(c * TILE + Vector2i(1, 1), Vector2i(TILE - 2, TILE - 2)), soil)
		var crop := str(tile.get("crop", ""))
		if crop != "":
			var cd: Dictionary = GameState.crops[crop]
			var frac := clampf(float(tile["days"]) / float(cd["days"]), 0.0, 1.0)
			var h := 3 + int(frac * 9)
			var cx := c.x * TILE + TILE / 2.0
			var base := (c.y + 1) * TILE - 2.0
			draw_rect(Rect2(cx - 1, base - h, 2, h), Color(cd["color"]))
			draw_rect(Rect2(cx - 3, base - h + 2, 2, 2), Color(cd["color"]))
			draw_rect(Rect2(cx + 1, base - h + 4, 2, 2), Color(cd["color"]))
			if frac >= 1.0:
				draw_circle(Vector2(cx, base - h - 1), 3.0, Color(cd["top"]))
	# Sell box
	draw_rect(Rect2(SELLBOX.x * TILE + 1, SELLBOX.y * TILE + 4, TILE - 2, TILE - 4), Color("c9a86b"))
	draw_rect(Rect2(SELLBOX.x * TILE + 1, SELLBOX.y * TILE + 2, TILE - 2, 3), Color("a8884f"))
	draw_rect(Rect2(SELLBOX.x * TILE + 5, SELLBOX.y * TILE + 3, 6, 1), Color("333"))
	# Paths
	draw_rect(Rect2(9 * TILE, 8 * TILE, 2 * TILE, 22 * TILE), Color("b8945a"))
	draw_rect(Rect2(10 * TILE, 14 * TILE, 10 * TILE, 2 * TILE), Color("b8945a"))
	# Trees and bushes
	for t: Vector2i in TREES:
		draw_tree(cell_center(t))
	for b: Vector2i in BUSHES:
		var p := cell_center(b)
		draw_circle(p + Vector2(0, -5), 6.0, Color("2f7a3a"))
		if bool(things[b].get("berries", false)):
			draw_rect(Rect2(p.x - 3, p.y - 7, 2, 2), Color("e23a3a"))
			draw_rect(Rect2(p.x + 1, p.y - 5, 2, 2), Color("e23a3a"))
			draw_rect(Rect2(p.x - 1, p.y - 3, 2, 2), Color("e23a3a"))
	# Gates
	draw_rect(Rect2(TOWN_EXIT.position * TILE, TOWN_EXIT.size * TILE), Color("b8945a"))
	draw_rect(Rect2(MEADOW_EXIT.position * TILE, MEADOW_EXIT.size * TILE), Color("b8945a"))
	draw_fence_border()
	draw_rect(Rect2(TOWN_EXIT.position * TILE, TOWN_EXIT.size * TILE), Color("b8945a"))
	draw_rect(Rect2(MEADOW_EXIT.position * TILE, MEADOW_EXIT.size * TILE), Color("b8945a"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(6 * TILE, 29 * TILE + 11), "▼ town", HORIZONTAL_ALIGNMENT_CENTER, 8 * TILE, 7, Color(1, 1, 0.85))
	draw_string(font, Vector2(14 * TILE, 13 * TILE + 11), "meadow ▶", HORIZONTAL_ALIGNMENT_RIGHT, 5 * TILE, 7, Color(1, 1, 0.85))

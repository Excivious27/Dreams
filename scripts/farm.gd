extends GameMap
## Your plot of land. Farming (hoe, plant, water, harvest), sell box, pond fishing,
## berry bushes, trees for wood, the house door, exits to town (south) and the
## meadow (east). The story opening plays here on day 1.

const PLOT := Rect2i(12, 6, 12, 10)
const POND := Rect2i(14, 22, 8, 6)
const HOUSE := Rect2i(4, 4, 6, 5)
const DOOR := Vector2i(6, 8)
const SELLBOX := Vector2i(4, 11)
const CRYSTAL_SPOT := Vector2i(12, 22)
const TOWN_EXIT := Rect2i(15, 42, 2, 2)
const MEADOW_EXIT := Rect2i(30, 18, 2, 3)
const FOREST_EXIT := Rect2i(14, 0, 3, 2)
const LAKE_EXIT := Rect2i(0, 24, 2, 3)
const TREES := [Vector2i(3, 16), Vector2i(6, 21), Vector2i(3, 28), Vector2i(9, 31), Vector2i(24, 33), Vector2i(2, 19), Vector2i(8, 25), Vector2i(26, 9), Vector2i(28, 13), Vector2i(10, 36), Vector2i(20, 37), Vector2i(27, 27)]
const BUSHES := [Vector2i(7, 18), Vector2i(26, 4), Vector2i(12, 30), Vector2i(28, 22), Vector2i(5, 34), Vector2i(22, 39)]

var _pond: Scenery.Pond
var _crystal: Node2D
var _fishing := false
var _fish_bite := false
var _crystal_t := 0.0


func scene_id() -> String:
	return "farm"


func default_spawn() -> Vector2:
	return cell_center(Vector2i(8, 14))


func build() -> void:
	cols = 32
	rows = 44
	music_track = "farm"
	add_exit(TOWN_EXIT, "town", Vector2(10 * TILE, 2 * TILE + 8), "down", "▼ town")
	add_exit(MEADOW_EXIT, "meadow", Vector2(2 * TILE, 10 * TILE), "right", "meadow ▶")
	add_exit(FOREST_EXIT, "forest", Vector2(16 * TILE, 38 * TILE), "up", "▲ forest")
	add_exit(LAKE_EXIT, "lake", Vector2(34 * TILE, 14 * TILE), "left", "◀ lake")
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
	block_rect(19, 1, 5, 2)   # barn
	block_rect(2, 36, 3, 3)   # windmill
	block_rect(25, 2, 4, 3)   # greenhouse
	block_rect(8, 38, 4, 3)   # coop
	blocked[Vector2i(12, 5)] = true  # scarecrow
	set_thing(2, 13, {"type": "workbench", "hint": "A: workbench"})
	set_thing(3, 13, {"type": "workbench", "hint": "A: workbench"})
	set_thing(6, 12, {"type": "furnace", "hint": "A: furnace (5 ore + 1 wood = bar)"})
	set_thing(7, 12, {"type": "chest", "hint": "A: storage chest"})
	set_thing(26, 30, {"type": "beehive", "hint": "A: beehive"})
	set_thing(3, 22, {"type": "keg", "hint": "A: keg"})
	set_thing(28, 6, {"type": "resonator", "hint": "A: crystal resonator"})
	set_thing(10, 23, {"type": "well", "hint": "A: well (refill energy a little)"})
	block_rect(10, 22, 1, 1)
	if GameState.is_penguins() and bool(GameState.run["intro_done"]):
		set_thing(CRYSTAL_SPOT.x, CRYSTAL_SPOT.y, {"type": "crystal", "hint": "A: talk to the Light Crystal"})


func after_ready() -> void:
	WorldGen.add_backdrop(self, "hills")
	_pond = Scenery.Pond.new()
	_pond.rect = Rect2(POND.position * TILE, POND.size * TILE)
	_pond.z_index = -1
	add_child(_pond)
	_place_props()
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
	pass


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
		"well":
			if int(GameState.run["flags"].get("well_day", 0)) < int(GameState.run["day"]):
				GameState.run["flags"]["well_day"] = int(GameState.run["day"])
				GameState.restore_energy(20)
				hud.toast("Cold water. +20 energy.")
			else:
				hud.toast("You already drank today.")
			return true
		"crystal":
			_talk_crystal()
			return true
		"workbench":
			_workbench()
			return true
		"furnace":
			_furnace()
			return true
		"chest":
			_sellbox_like_chest()
			return true
		"beehive":
			_daily_pickup("beehive", "honey", "The bees are still working.")
			return true
		"keg":
			_keg(sel)
			return true
		"resonator":
			_resonator(sel)
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
		player.play_tool("eat")
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
		player.play_tool("hoe")
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
			player.play_tool("hoe")
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
		player.play_tool("hold")
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
	player.play_tool("water")
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


# ---- crafting ----------------------------------------------------------------

func _workbench() -> void:
	var recipes := [
		{"name": "Sprinkler (4 copper bar, 1 iron bar)", "need": {"copper_bar": 4, "iron_bar": 1}, "give": "sprinkler"},
		{"name": "Chest (10 wood)", "need": {"wood": 10}, "give": "chest"},
		{"name": "Scarecrow (8 wood, 4 fiber)", "need": {"wood": 8, "fiber": 4}, "give": "scarecrow"},
		{"name": "Berry Pie (3 berry, 1 wheat)", "need": {"berry": 3, "wheat": 1}, "give": "gift_pie"},
	]
	var opts: Array = []
	for r in recipes:
		opts.append(str(r["name"]))
	opts.append("Leave")
	var d := Dialogue.instance(get_tree())
	d.say([{"who": "Workbench", "text": "Craft what? (Building skill speeds this up.)", "choice": opts, "key": ""}])
	await d.finished
	var i := d.last_choice
	if i < 0 or i >= recipes.size():
		return
	var r: Dictionary = recipes[i]
	for id in r["need"]:
		if GameState.count(id) < int(r["need"][id]):
			hud.toast("Need %d %s." % [int(r["need"][id]), GameState.item_name(id)], Color(1, 0.7, 0.7))
			return
	for id in r["need"]:
		GameState.add_item(id, -int(r["need"][id]))
	give(str(r["give"]))
	xp("building", 6)


func _furnace() -> void:
	for ore in ["copper", "iron"]:
		if GameState.count(ore) >= 5 and GameState.count("wood") >= 1:
			GameState.add_item(ore, -5)
			GameState.add_item("wood", -1)
			give(ore + "_bar")
			xp("building", 3)
			if props.has(Vector2i(5, 11)) and Art.tex("props", "furnace_on"):
				(props[Vector2i(5, 11)] as Sprite2D).texture = Art.tex("props", "furnace_on")
			return
	hud.toast("Needs 5 copper or iron ore and 1 wood.")


func _sellbox_like_chest() -> void:
	# A simple stash: moves everything that isn't a tool or seed into the chest, or takes it all back.
	var chest: Dictionary = GameState.run["flags"].get("chest", {})
	if chest.is_empty():
		var moved := 0
		for id in GameState.run["inventory"].keys():
			var t := str(GameState.items.get(id, {}).get("type", ""))
			if t in ["tool", "seed", "potion", "gift"]:
				continue
			chest[id] = GameState.count(id)
			GameState.add_item(id, -GameState.count(id))
			moved += 1
		GameState.run["flags"]["chest"] = chest
		hud.toast("Stored %d stacks in the chest." % moved if moved > 0 else "Nothing to store.")
	else:
		for id in chest:
			GameState.add_item(id, int(chest[id]))
		GameState.run["flags"]["chest"] = {}
		hud.toast("Took everything back out.")


func _daily_pickup(key: String, item: String, wait_msg: String) -> void:
	var day := int(GameState.run["day"])
	if int(GameState.run["flags"].get(key, 0)) < day - 2:
		GameState.run["flags"][key] = day
		give(item)
		xp("farming", 2)
	else:
		hud.toast(wait_msg)


func _keg(sel: String) -> void:
	var keg: Dictionary = GameState.run["flags"].get("keg", {})
	var day := int(GameState.run["day"])
	if not keg.is_empty():
		if day >= int(keg["ready"]):
			GameState.run["flags"]["keg"] = {}
			give(str(keg["out"]))
			xp("farming", 5)
		else:
			hud.toast("Fermenting... %d more day(s)." % (int(keg["ready"]) - day))
		return
	var out := {"strawberry": "strawberry_wine", "corn": "corn_ale", "berry": "berry_juice", "dreamflower": "dream_tonic"}
	if out.has(sel) and GameState.count(sel) > 0:
		GameState.add_item(sel, -1)
		GameState.run["flags"]["keg"] = {"out": out[sel], "ready": day + 3}
		hud.toast("The keg bubbles. Come back in 3 days.")
	else:
		hud.toast("Hold a fruit or crop and press A to start a brew.")


func _resonator(sel: String) -> void:
	if sel == "shard" and GameState.count("shard") >= 3:
		GameState.add_item("shard", -3)
		give("crystal_refined")
		xp("mining", 8)
		fx("pawring", cell_center(Vector2i(18, 4)) + Vector2(0, -12), 10.0, 0.6)
	else:
		hud.toast("Hold 3 Crystal Shards to refine one.")


# ---- fishing -----------------------------------------------------------------

func _fish() -> void:
	if not GameState.spend_energy(2):
		hud.toast("Too tired.", Color(1, 0.7, 0.7))
		return
	_fishing = true
	_fish_bite = false
	player.play_tool("cast")
	player.frozen = true
	hud.toast("Casting... wait for the !")
	var bob: AnimatedSprite2D = null
	if Art.has("fx", "bobber"):
		bob = AnimatedSprite2D.new()
		bob.sprite_frames = Art.frames("fx", {"bobber": "bobber", "bite": "bobber_bite"}, {"bobber": 4.0, "bite": 8.0})
		bob.animation = "bobber"
		bob.scale = Vector2(0.5, 0.5)
		bob.position = cell_center(player.facing_cell()) + Vector2(0, -6)
		bob.z_index = 1
		add_child(bob)
		bob.play("bobber")
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
			if bob:
				bob.play("bite")
		if Input.is_action_just_pressed("a") and t > 0.2:
			if _fish_bite:
				caught = true
			break
	player.frozen = false
	_fishing = false
	if bob:
		fx("splash", bob.position, 12.0, 0.5)
		bob.queue_free()
	if caught:
		var roll := randf()
		var lvl := GameState.skill_level("fishing")
		var fish := "boot"
		if roll >= 0.12:
			var pool: Array = ["sunfish", "carp", "minnow", "trout", "bass", "catfish", "salmon", "eel", "puffer", "goldfish", "starfin", "mooncarp"]
			var reach := mini(pool.size(), 3 + lvl * 2)
			fish = pool[randi() % reach]
		player.play_tool("reel")
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
	player.position = cell_center(Vector2i(12, 24))
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
	player.position = cell_center(Vector2i(16, 38))
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
	draw_grass(1)
	WorldGen.draw_ground_detail(self, 21, 0.14)
	# Paths with real grass transitions.
	var path := cells_of([Rect2i(15, 1, 2, 42), Rect2i(2, 18, 29, 3), Rect2i(6, 9, 1, 9), TOWN_EXIT, MEADOW_EXIT, FOREST_EXIT, LAKE_EXIT])
	draw_ground("dirt", path)
	draw_ground("stone", cells_of([Rect2i(9, 12, 3, 3)]))
	# Farmland feel: a hay field and wheat beyond the fence line, a stone wall by the barn.
	draw_tileset_rect("hay_field", Rect2i(25, 9, 5, 4), Color("d8b24a"))
	draw_tileset_rect("wheat_2", Rect2i(2, 30, 5, 4), Color("c9a86b"))
	draw_exits()
	# Plot: untouched soil shows as a faint patch; tilled tiles use the real tiles.
	draw_rect(Rect2(PLOT.position * TILE, PLOT.size * TILE), Color(0.45, 0.35, 0.2, 0.25))
	var farm: Dictionary = GameState.run["farm"]
	for key in farm:
		var parts: PackedStringArray = str(key).split(",")
		var c := Vector2i(int(parts[0]), int(parts[1]))
		var tile: Dictionary = farm[key]
		var wet := bool(tile.get("watered", false))
		if not Art.draw_tile(self, "tiles", "tilled_wet" if wet else "tilled_dry", Vector2(c * TILE), 4):
			draw_rect(Rect2(c * TILE + Vector2i(1, 1), Vector2i(TILE - 2, TILE - 2)), Color("5c3d22") if wet else Color("8a5f38"))
		var crop := str(tile.get("crop", ""))
		if crop != "":
			var cd: Dictionary = GameState.crops[crop]
			var frac := clampf(float(tile["days"]) / float(cd["days"]), 0.0, 1.0)
			var stage := mini(4, int(frac * 5.0))
			if frac >= 1.0:
				stage = 4
			var t := Art.tex("crops", crop)
			if t:
				var info := Art.info("crops", crop)
				var cw := int(info.get("cell_w", 32))
				var ch := int(info.get("cell_h", 32))
				var w := cw / 2.0
				var h := ch / 2.0
				draw_texture_rect_region(t, Rect2(c.x * TILE + TILE / 2.0 - w / 2.0, (c.y + 1) * TILE - h, w, h), Rect2(stage * cw, 0, cw, ch))
			else:
				var hgt := 3 + int(frac * 9)
				var cx := c.x * TILE + TILE / 2.0
				var base := (c.y + 1) * TILE - 2.0
				draw_rect(Rect2(cx - 1, base - hgt, 2, hgt), Color(cd["color"]))
				if frac >= 1.0:
					draw_circle(Vector2(cx, base - hgt - 1), 3.0, Color(cd["top"]))
	if not Art.has("buildings", "house"):
		draw_building(HOUSE.position.x, HOUSE.position.y, HOUSE.size.x, HOUSE.size.y, Color("8b5a2b"), Color("b03a2e"), "")
	draw_fence_border()


func _animal(kind: String, c: Vector2i) -> void:
	if not Art.has("props", kind):
		return
	var a := AnimatedSprite2D.new()
	a.sprite_frames = Art.frames("props", {"idle": kind}, {"idle": 2.0})
	a.animation = "idle"
	a.scale = Vector2(0.5, 0.5)
	a.position = cell_center(c)
	a.offset = Vector2(0, -float(Art.info("props", kind).get("cell_h", 48)) / 2.0)
	add_child(a)
	a.play("idle")
	blocked[c] = true


func _place_props() -> void:
	if not Art.has("buildings", "house"):
		return
	prop("buildings", "house", Vector2i(HOUSE.position.x, HOUSE.end.y - 1), HOUSE.size.x - 1)
	prop("buildings", "mailbox", Vector2i(HOUSE.end.x, HOUSE.end.y - 1))
	prop("buildings", "sellbox", SELLBOX)
	prop("props", "barn", Vector2i(19, 2), 4, -2.0)
	prop("props", "greenhouse", Vector2i(25, 4), 3)
	prop("props", "coop", Vector2i(8, 40), 3)
	prop("props", "scarecrow2" if Art.has("props", "scarecrow2") else "scarecrow", Vector2i(12, 5))
	prop("props", "windmill", Vector2i(2, 38), 2)
	prop("props", "workbench2", Vector2i(2, 13), 2)
	prop("props", "furnace_off", Vector2i(6, 12))
	prop("props", "chest_closed", Vector2i(7, 12))
	prop("props", "beehive2", Vector2i(26, 30))
	prop("props", "keg", Vector2i(3, 22))
	prop("props", "well2", Vector2i(10, 23))
	prop("props", "hay", Vector2i(23, 4))
	prop("props", "haystack", Vector2i(21, 4))
	prop("props", "trough2" if Art.has("props", "trough2") else "trough", Vector2i(20, 5))
	_animal("cow2", Vector2i(22, 7)); _animal("sheep2", Vector2i(24, 8)); _animal("chicken", Vector2i(9, 41)); _animal("chicken", Vector2i(11, 41))
	prop("props", "pig", Vector2i(27, 11))
	prop("buildings", "silo", Vector2i(30, 2), 1)
	block_rect(30, 1, 2, 3)
	prop("props", "bale_round", Vector2i(26, 13)); prop("props", "bale_square", Vector2i(28, 13))
	blocked[Vector2i(26, 13)] = true; blocked[Vector2i(28, 13)] = true
	prop("props", "tractor", Vector2i(3, 29), 1)
	block_rect(3, 28, 2, 2)
	prop("props", "farm_cart", Vector2i(12, 2), 1)
	block_rect(12, 1, 2, 2)
	prop("props", "birdbath", Vector2i(9, 14))
	prop("props", "signpost", Vector2i(13, 41))
	prop("props", "lamp", Vector2i(17, 41))
	prop("props", "stall", Vector2i(5, 27), 1)
	# Dense world detail: tree lines along the edges, clumps, scattered props, critters.
	var avoid := {}
	for y in range(PLOT.position.y - 1, PLOT.end.y + 1):
		for x in range(PLOT.position.x - 1, PLOT.end.x + 1):
			avoid[Vector2i(x, y)] = true
	for y in range(POND.position.y - 1, POND.end.y + 1):
		for x in range(POND.position.x - 1, POND.end.x + 1):
			avoid[Vector2i(x, y)] = true
	for y in range(HOUSE.position.y - 1, HOUSE.end.y + 1):
		for x in range(HOUSE.position.x - 1, HOUSE.end.x + 2):
			avoid[Vector2i(x, y)] = true
	for x in range(14, 18):
		for y in rows:
			avoid[Vector2i(x, y)] = true
	for y in range(18, 21):
		for x in range(cols):
			avoid[Vector2i(x, y)] = true
	WorldGen.tree_border(self, Rect2i(1, 1, cols - 2, rows - 2), 11, [TOWN_EXIT.grow(2), MEADOW_EXIT.grow(2), FOREST_EXIT.grow(2), LAKE_EXIT.grow(2), Rect2i(18, 0, 12, 4)], 2)
	WorldGen.tree_clumps(self, Rect2i(2, 24, 10, 14), 12, 3, avoid)
	WorldGen.tree_clumps(self, Rect2i(24, 24, 7, 16), 13, 3, avoid)
	WorldGen.scatter_props(self, Rect2i(2, 2, cols - 4, rows - 4), 14, 26, avoid)
	WorldGen.add_critters(self, Rect2i(2, 2, cols - 4, rows - 4), 15, 9, ["sparrow", "sparrow", "butterfly_orange", "butterfly_yellow", "bee", "rabbit", "squirrel", "pigeon"])
	var res := prop("props", "resonator", Vector2i(28, 6))
	if res and Art.has("props", "resonator"):
		res.queue_free()
		var a := AnimatedSprite2D.new()
		a.sprite_frames = Art.frames("props", {"idle": "resonator"}, {"idle": 4.0})
		a.animation = "idle"
		a.scale = Vector2(0.5, 0.5)
		a.position = cell_center(Vector2i(28, 6))
		a.offset = Vector2(0, -float(Art.info("props", "resonator").get("cell_h", 80)) / 2.0)
		add_child(a)
		a.play("idle")
	for t: Vector2i in TREES:
		prop("nature", GameState.tree_sprite((t.x + t.y) % 3), t)
	for b: Vector2i in BUSHES:
		var has := bool(things[b].get("berries", false))
		prop("nature", GameState.bush_sprite(has), b)
	for r: Vector2i in [Vector2i(2, 12), Vector2i(17, 25)]:
		prop("nature", "rock_snow_s" if GameState.season() == "winter" and Art.has("nature", "rock_snow_s") else "rock_s", r)

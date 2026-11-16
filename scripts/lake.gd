extends GameMap
## The west lake: a wide water body with a dock, a water-mill style stall,
## reeds, the best fishing in the valley. Exits: farm (east), forest (north).

const FARM_EXIT := Rect2i(35, 13, 1, 3)
const FOREST_EXIT := Rect2i(33, 0, 3, 1)
const LAKE := Rect2i(3, 6, 20, 18)

var _pond: Scenery.Pond


func scene_id() -> String:
	return "lake"


func default_spawn() -> Vector2:
	return Vector2(33 * TILE, 14 * TILE)


func build() -> void:
	cols = 36
	rows = 30
	music_track = "farm"
	add_exit(FARM_EXIT, "farm", Vector2(3 * TILE, 25 * TILE + 8), "right", "farm ▶")
	add_exit(FOREST_EXIT, "forest", Vector2(2 * TILE, 21 * TILE + 8), "up", "▲ forest")
	for y in range(LAKE.position.y, LAKE.end.y):
		for x in range(LAKE.position.x, LAKE.end.x):
			set_thing(x, y, {"type": "water", "hint": "A: fish" if GameState.has_tool("rod") else ""})
	# Dock walking out into the lake.
	for x in range(23, 27):
		things.erase(Vector2i(x, 14))
		blocked.erase(Vector2i(x, 14))
		things[Vector2i(x, 14)] = {"type": "dock"}
	for x in range(13, 19):
		things.erase(Vector2i(x, 14))
		blocked.erase(Vector2i(x, 14))
		things[Vector2i(x, 14)] = {"type": "dock"}
	for y in range(14, 19):
		things.erase(Vector2i(18, y))
		blocked.erase(Vector2i(18, y))
		things[Vector2i(18, y)] = {"type": "dock"}
	set_thing(27, 12, {"type": "fisher", "hint": "A: Finn's bait shop"})
	block_rect(26, 10, 4, 3)


func after_ready() -> void:
	WorldGen.add_backdrop(self, "mountains")
	_pond = Scenery.Pond.new()
	_pond.rect = Rect2(LAKE.position * TILE, LAKE.size * TILE)
	_pond.z_index = -1
	add_child(_pond)
	var dock := DockLayer.new()
	dock.map = self
	dock.z_index = -1
	add_child(dock)
	prop("props", "stall", Vector2i(26, 12), 1)
	prop("props", "signpost", Vector2i(30, 14))
	blocked[Vector2i(30, 14)] = true
	var avoid := {}
	for y in range(LAKE.position.y - 2, LAKE.end.y + 2):
		for x in range(LAKE.position.x - 2, LAKE.end.x + 2):
			avoid[Vector2i(x, y)] = true
	for y in range(10, 18):
		for x in range(23, 36):
			avoid[Vector2i(x, y)] = true
	WorldGen.tree_border(self, Rect2i(1, 1, cols - 2, rows - 2), 71, [FARM_EXIT.grow(2), FOREST_EXIT.grow(2)], 2)
	WorldGen.tree_clumps(self, Rect2i(24, 2, 10, 8), 72, 4, avoid)
	WorldGen.tree_clumps(self, Rect2i(2, 25, 32, 4), 73, 5, avoid)
	WorldGen.scatter_props(self, Rect2i(2, 2, cols - 4, rows - 4), 74, 18, avoid)
	WorldGen.add_critters(self, Rect2i(2, 2, cols - 4, rows - 4), 75, 8)
	if not GameState.run["flags"].has("lake_seen"):
		GameState.run["flags"]["lake_seen"] = true
		player.frozen = true
		await say([{"text": "The lake is bigger than the whole town. Wind combs the surface silver. Finn waves from a shack at the end of the dock."}])
		player.frozen = false


func interact(c: Vector2i, thing: Dictionary) -> bool:
	match str(thing.get("type", "")):
		"water":
			if GameState.has_tool("rod"):
				_fish(c)
			return true
		"fisher":
			_bait_shop()
			return true
	return false


func _fish(c: Vector2i) -> void:
	if not GameState.spend_energy(2):
		hud.toast("Too tired.", Color(1, 0.7, 0.7))
		return
	player.play_tool("cast")
	player.frozen = true
	var bob: AnimatedSprite2D = null
	if Art.has("fx", "bobber"):
		bob = AnimatedSprite2D.new()
		bob.sprite_frames = Art.frames("fx", {"bobber": "bobber", "bite": "bobber_bite"}, {"bobber": 4.0, "bite": 8.0})
		bob.animation = "bobber"
		bob.scale = Vector2(0.5, 0.5)
		bob.position = cell_center(c) + Vector2(0, -6)
		bob.z_index = 1
		add_child(bob)
		bob.play("bobber")
	hud.toast("Casting...")
	var wait := randf_range(1.5, 4.5)
	var t := 0.0
	var bite := false
	var caught := false
	while t < wait + 1.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		if not bite and t >= wait:
			bite = true
			hud.toast("!!!  Press A!", Color(1, 1, 0.4))
			Music.instance(get_tree()).sfx("bite")
			if bob:
				bob.play("bite")
		if Input.is_action_just_pressed("a") and t > 0.2:
			caught = bite
			break
	player.frozen = false
	if bob:
		fx("splash", bob.position, 12.0, 0.5)
		bob.queue_free()
	if caught:
		var lvl := GameState.skill_level("fishing")
		var pool: Array = ["carp", "bass", "catfish", "salmon", "eel", "puffer", "goldfish", "starfin", "mooncarp"]
		var fish: String = pool[randi() % mini(pool.size(), 2 + lvl * 2)] if randf() > 0.08 else "boot"
		player.play_tool("reel")
		give(fish)
		xp("fishing", 6)
	else:
		hud.toast("It got away.")


func _bait_shop() -> void:
	var d := Dialogue.instance(get_tree())
	d.say([{"who": "Finn", "text": "Lake fish bite deeper than pond fish. Bigger too. Want something?  (◆%d)" % int(GameState.run["crystals"]), "choice": ["Energy Tea  ◆38", "Red Potion  ◆45", "Leave"], "key": ""}])
	await d.finished
	var picks := [["energy_tea", 38], ["potion", 45]]
	if d.last_choice >= 0 and d.last_choice < picks.size():
		var id: String = picks[d.last_choice][0]
		var price: int = picks[d.last_choice][1]
		if int(GameState.run["crystals"]) < price:
			hud.toast("Not enough crystals.", Color(1, 0.7, 0.7))
			return
		GameState.run["crystals"] = int(GameState.run["crystals"]) - price
		give(id)


func _draw() -> void:
	draw_grass(7)
	WorldGen.draw_ground_detail(self, 76, 0.12)
	draw_tileset_rect("dirt", Rect2i(23, 13, 13, 3), Color("b8945a"))
	draw_tileset_rect("dirt", Rect2i(31, 1, 3, 13), Color("b8945a"))
	# Sand ring around the lake.
	draw_tileset_rect("shore_set", LAKE.grow(1), Color("c9a86b"))
	draw_exits()
	draw_fence_border()



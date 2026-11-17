extends GameMap
## The east meadow: Grumps wander here. Beat enough of them and their boss
## shows up. Mushrooms to forage. The mine entrance is at the far east end.

const FARM_EXIT := Rect2i(0, 9, 1, 3)
const EAST_EXIT := Rect2i(35, 14, 1, 3)
const MINE_DOOR := Vector2i(32, 6)
const SHROOMS := [Vector2i(5, 3), Vector2i(12, 13), Vector2i(18, 11), Vector2i(8, 8), Vector2i(24, 20), Vector2i(29, 9), Vector2i(14, 24), Vector2i(20, 4)]

var _boss: Enemy
var _spawned := 0


func scene_id() -> String:
	return "meadow"


func default_spawn() -> Vector2:
	return Vector2(2 * TILE, 10 * TILE)


func build() -> void:
	cols = 36
	rows = 28
	pad = 6
	border = {"n": "cliff", "s": "trees", "w": "trees", "e": "trees"}
	music_track = "meadow"
	add_exit(FARM_EXIT, "farm", Vector2(68 * TILE, 30 * TILE + 8), "left", "◀ farm")
	add_exit(EAST_EXIT, "crystal_meadow", Vector2(2 * TILE, 12 * TILE), "right", "east ▶")
	add_exit(Rect2i(14, 0, 4, 1), "ruins", Vector2(24 * TILE, 41 * TILE + 8), "up", "▲ ruins")
	for p: Vector2i in [Vector2i(4, 2), Vector2i(10, 2), Vector2i(16, 3), Vector2i(21, 12), Vector2i(3, 13), Vector2i(14, 8), Vector2i(9, 12), Vector2i(26, 22), Vector2i(8, 22), Vector2i(19, 25)]:
		if not is_cleared(p):
			set_thing(p.x, p.y, {"type": "tree", "hp": 3, "hint": "A: chop"})
	for p: Vector2i in [Vector2i(7, 5), Vector2i(19, 7), Vector2i(12, 10), Vector2i(27, 17), Vector2i(15, 20)]:
		if not is_cleared(p, 4):
			set_thing(p.x, p.y, {"type": "rock", "hp": 2, "hint": "A: break rock"})
	set_thing(MINE_DOOR.x, MINE_DOOR.y, {"type": "mine", "hint": "A: enter the mine"})
	things[MINE_DOOR] = {"type": "mine", "hint": "A: enter the mine"}
	for m: Vector2i in SHROOMS:
		var key := "shroom_%d_%d" % [m.x, m.y]
		var has := int(GameState.run["flags"].get(key, 0)) < int(GameState.run["day"])
		things[m] = {"type": "shroom", "key": key, "has": has, "hint": "A: pick mushroom" if has else ""}
	extend(18, 14)


func after_ready() -> void:
	WorldGen.add_backdrop(self, "mountains")
	if Art.has("props", "watchtower"):
		prop("props", "watchtower", Vector2i(cols - 8, rows - 8), 2)
		set_thing(cols - 7, rows - 7, {"type": "note", "text": "A watchtower with no watchers. From up top you could see the whole valley. The ladder's gone.", "hint": "A: the tower"}, false)
	if Art.has("props", "scarecrow_field"):
		prop("props", "scarecrow_field", Vector2i(8, rows - 6))
	_place_props()
	var avoid := {}
	for y in range(3, 9):
		for x in range(30, 35):
			avoid[Vector2i(x, y)] = true
	WorldGen.tree_clumps(self, Rect2i(2, 2, cols - 4, rows - 4), 42, 6, avoid)
	WorldGen.scatter_props(self, Rect2i(2, 2, cols - 4, rows - 4), 43, 20, avoid)
	WorldGen.add_critters(self, Rect2i(2, 2, cols - 4, rows - 4), 44, 12, ["butterfly_orange", "butterfly_blue", "butterfly_yellow", "bee", "bee", "rabbit", "sparrow", "deer"])
	var n := 4 if not GameState.quest_done("clear_meadow") else 2
	for i in n:
		_spawn_one()
	if not GameState.run["flags"].has("meadow_seen"):
		GameState.run["flags"]["meadow_seen"] = true
		_first_visit.call_deferred()


func _first_visit() -> void:
	player.frozen = true
	GameState.add_quest("clear_meadow", "Deal with whatever is in the east meadow.")
	if GameState.is_penguins():
		await say([
			{"text": "The meadow should be quiet. It isn't. Small grey shapes grumble in the grass, and the flowers near them have gone the colour of old dishwater."},
			{"text": "Grumps. The Star Crystal wasn't exaggerating. Press A to swing. Hold B to run if it goes badly."},
		])
	else:
		await say([
			{"text": "Whoever came through here brought company. Small, ugly, and organized. The President's cheapest kind of muscle."},
			{"text": "Press A to swing. Hold B to run. Nobody's watching, so there's no shame in it."},
		])
	player.frozen = false


func _spawn_one() -> void:
	_spawned += 1
	var at := Vector2(randf_range(8, 28) * TILE, randf_range(3, 24) * TILE)
	spawn_enemy(_pick_kind(), at)


## What wanders the meadow depends on the arc and how far you've gotten.
func _pick_kind() -> String:
	var cleared := GameState.quest_done("clear_meadow")
	var r := randf()
	if GameState.is_penguins():
		if not cleared:
			return "grump"
		if r < 0.45:
			return "grump"
		if r < 0.7:
			return "soldier"
		if r < 0.88:
			return "archer"
		return "wisp"
	else:
		if not cleared:
			return "grump" if r < 0.6 else "thug_speedster"
		var pool: Array = ["thug_cyber", "thug_speedster", "thug_gambler", "thug_flame"]
		return pool[randi() % pool.size()]


func _process(delta: float) -> void:
	super(delta)
	if player.frozen or _changing:
		return
	pass


func on_enemy_died(e: Enemy) -> void:
	super(e)
	if _boss != null and e == _boss:
		_boss_down()
		return
	if _boss_pending:
		return
	if GameState.quest_done("clear_meadow"):
		if enemies.size() < 2 and randf() < 0.5:
			_spawn_one()
		return
	if int(GameState.run["kills"]) >= 5 and _boss == null and not _boss_pending:
		_summon_boss()
	elif enemies.size() < 3:
		_spawn_one()


var _boss_pending := false


func _summon_boss() -> void:
	_boss_pending = true  # set before any await: one swing can kill two grumps
	player.frozen = true
	for e in enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	await hud.fade_out(0.3)
	await hud.fade_in(0.3)
	if GameState.is_penguins():
		await say([
			{"text": "The grumbling stops all at once. Something bigger pushes up out of the grass, dragging the colour out of everything around it."},
			{"who": "Big Grump", "text": "JOY. IS. INEFFICIENT."},
		])
	else:
		await say([
			{"text": "The small ones scatter. Something bigger stands up from behind the rocks. It has a face you've seen in a very bad photograph."},
			{"who": "The President's Man", "text": "He said you'd be farming. He didn't say you'd be good at it."},
		])
	_boss = spawn_enemy("big_grump" if GameState.is_penguins() else "thug_brute", Vector2(18 * TILE, 12 * TILE))
	boss_card("big_grump" if GameState.is_penguins() else "thug_brute", "Big Grump" if GameState.is_penguins() else "The President's Man")
	Music.instance(get_tree()).play("boss")
	player.frozen = false
	_boss_pending = false


func _boss_down() -> void:
	_boss = null
	player.frozen = true
	Music.instance(get_tree()).play("meadow")
	GameState.add_quest("clear_meadow", "Deal with whatever is in the east meadow.")
	GameState.complete_quest("clear_meadow")
	if GameState.is_penguins():
		GameState.grow_vital("hp", 20)
		GameState.run["hp"] = int(GameState.run["max_hp"])
		GameState.run["flags"]["spark"] = true
		await say([
			{"text": "The big Grump comes apart into grey smoke. Where it stood, the grass turns green again. Then greener than it was."},
			{"who": "Star Crystal", "text": "(from very far away) ...there it is. The first spark. It was in you the whole time, I only lit it."},
			{"text": "Your heart grows two sizes. Literally: +2 max hearts."},
		])
	else:
		GameState.run["crystals"] = int(GameState.run["crystals"]) + 60
		await say([
			{"text": "He goes down hard and stays down. In his coat: sixty crystals and a folded note. The handwriting on it has loops on the W and a hard press on the K."},
			{"text": "+60 crystals. Sal, back in town, will want to hear about this."},
		])
	GameState.save()
	player.frozen = false


func interact(_c: Vector2i, thing: Dictionary) -> bool:  # _c is used for props
	match str(thing.get("type", "")):
		"note":
			tell([{"text": str(thing.get("text", "..."))}])
			return true
		"mine":
			GameState.run["flags"]["mine_from"] = "meadow"
			GameState.run["mine_floor"] = 1  # the front door is floor 1; the lift skips floors
			go_to("mine", Vector2.ZERO)
			return true
		"shroom":
			if bool(thing.get("has", false)):
				thing["has"] = false
				thing["hint"] = ""
				GameState.run["flags"][thing["key"]] = int(GameState.run["day"])
				give("mushroom", 1)
				xp("foraging", 2)
				if props.has(_c):
					(props[_c] as Sprite2D).queue_free()
					props.erase(_c)
				queue_redraw()
			return true
	return false


func draw_map() -> void:
	draw_grass(5)
	WorldGen.draw_ground_detail(self, 51, 0.18)
	if Art.has("tiles", "g_flower"):
		for c: Vector2i in cells_of([Rect2i(4, 18, 9, 6), Rect2i(20, 3, 7, 4)]):
			if not blocked.has(c):
				Art.draw_tile(self, "tiles", "g_flower", Vector2(c * TILE), 4)
		for c: Vector2i in cells_of([Rect2i(14, 20, 8, 5)]):
			if not blocked.has(c):
				Art.draw_tile(self, "tiles", "g_tall", Vector2(c * TILE), 4)
	draw_ground("dirt", cells_of([Rect2i(1, 9, 30, 3), Rect2i(28, 9, 3, 6), Rect2i(28, 14, 7, 3), FARM_EXIT, EAST_EXIT]))
	draw_exits()
	if not Art.has("nature", "oak"):
		for k in things:
			var t: Dictionary = things[k]
			match str(t.get("type", "")):
				"tree":
					draw_tree(cell_center(k))
				"rock":
					var p := cell_center(k)
					draw_circle(p + Vector2(0, -5), 6.5, Color("7a7a86"))
				"shroom":
					if bool(t.get("has", false)):
						var p := cell_center(k)
						draw_rect(Rect2(p.x - 4, p.y - 8, 8, 3), Color("c9452f"))
	# Mine entrance in a rocky hill.
	draw_ground("stone", cells_of([Rect2i(30, 2, 5, 7)]))
	if not Art.has("props", "mine_entrance"):
		draw_rect(Rect2(MINE_DOOR.x * TILE + 2, MINE_DOOR.y * TILE, 12, 16), Color("111"))
	if pad == 0:
		draw_fence_border()


func _place_props() -> void:
	if not Art.has("nature", "oak"):
		return
	for k in things:
		var t: Dictionary = things[k]
		match str(t.get("type", "")):
			"tree":
				prop("nature", GameState.tree_sprite((k.x * 7 + k.y) % 3), k)
			"rock":
				prop("nature", "rock_m", k)
			"shroom":
				if bool(t.get("has", false)):
					prop("tiles", "deco_5", k, 0, 0.0)
	if Art.has("props", "mine_entrance"):
		prop("props", "mine_entrance", Vector2i(31, 6), 2)
	else:
		for c: Vector2i in [Vector2i(31, 7), Vector2i(33, 4)]:
			prop("nature", "rock_l", c)
	prop("nature", "log", Vector2i(6, 13), 1)

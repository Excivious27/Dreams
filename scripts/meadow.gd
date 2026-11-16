extends GameMap
## The east meadow: Grumps wander here. Beat enough of them and their boss
## shows up. Mushrooms to forage. The mine entrance is at the far east end.

const FARM_EXIT := Rect2i(0, 9, 1, 3)
const MINE_DOOR := Vector2i(22, 5)
const SHROOMS := [Vector2i(5, 3), Vector2i(12, 13), Vector2i(18, 11), Vector2i(8, 8)]

var _boss: Enemy
var _spawned := 0


func scene_id() -> String:
	return "meadow"


func default_spawn() -> Vector2:
	return Vector2(2 * TILE, 10 * TILE)


func build() -> void:
	cols = 24
	rows = 16
	music_track = "meadow"
	for p: Vector2i in [Vector2i(4, 2), Vector2i(10, 2), Vector2i(16, 3), Vector2i(21, 12), Vector2i(3, 13), Vector2i(14, 8), Vector2i(9, 12)]:
		set_thing(p.x, p.y, {"type": "tree", "hint": ""})
	for p: Vector2i in [Vector2i(7, 5), Vector2i(19, 7), Vector2i(12, 10)]:
		set_thing(p.x, p.y, {"type": "rock", "hp": 2, "hint": "A: break rock"})
	set_thing(MINE_DOOR.x, MINE_DOOR.y, {"type": "mine", "hint": "A: enter the mine"})
	block_rect(21, 3, 3, 5)
	things[MINE_DOOR] = {"type": "mine", "hint": "A: enter the mine"}
	for m: Vector2i in SHROOMS:
		var key := "shroom_%d_%d" % [m.x, m.y]
		var has := int(GameState.run["flags"].get(key, 0)) < int(GameState.run["day"])
		things[m] = {"type": "shroom", "key": key, "has": has, "hint": "A: pick mushroom" if has else ""}


func after_ready() -> void:
	for y in range(9, 12):
		blocked.erase(Vector2i(0, y))
	add_child(GameMenu.new())
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
			{"text": "Grumps. The Light Crystal wasn't exaggerating. Press A to swing. Hold B to run if it goes badly."},
		])
	else:
		await say([
			{"text": "Whoever came through here brought company. Small, ugly, and organized. The President's cheapest kind of muscle."},
			{"text": "Press A to swing. Hold B to run. Nobody's watching, so there's no shame in it."},
		])
	player.frozen = false


func _spawn_one() -> void:
	_spawned += 1
	var at := Vector2(randf_range(8, 19) * TILE, randf_range(3, 13) * TILE)
	spawn_enemy("grump", at)


func _process(delta: float) -> void:
	super(delta)
	if player.frozen or _changing:
		return
	if player.cell().x <= 0:
		go_to("farm", Vector2(17 * TILE + 8, 15 * TILE), "left")


func on_enemy_died(e: Enemy) -> void:
	super(e)
	if e.kind == "big_grump":
		_boss_down()
		return
	if GameState.quest_done("clear_meadow"):
		if enemies.size() < 2 and randf() < 0.5:
			_spawn_one()
		return
	if int(GameState.run["kills"]) >= 5 and _boss == null:
		_summon_boss()
	elif enemies.size() < 3:
		_spawn_one()


func _summon_boss() -> void:
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
	_boss = spawn_enemy("big_grump", Vector2(16 * TILE, 8 * TILE))
	Music.instance(get_tree()).play("boss")
	player.frozen = false


func _boss_down() -> void:
	_boss = null
	player.frozen = true
	Music.instance(get_tree()).play("meadow")
	GameState.add_quest("clear_meadow", "Deal with whatever is in the east meadow.")
	GameState.complete_quest("clear_meadow")
	if GameState.is_penguins():
		GameState.run["max_hp"] = int(GameState.run["max_hp"]) + 2
		GameState.run["hp"] = int(GameState.run["max_hp"])
		GameState.run["flags"]["spark"] = true
		await say([
			{"text": "The big Grump comes apart into grey smoke. Where it stood, the grass turns green again. Then greener than it was."},
			{"who": "Light Crystal", "text": "(from very far away) ...there it is. The first spark. It was in you the whole time, I only lit it."},
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


func interact(_c: Vector2i, thing: Dictionary) -> bool:
	match str(thing.get("type", "")):
		"mine":
			go_to("mine", Vector2.ZERO)
			return true
		"rock":
			if not GameState.has_tool("pickaxe"):
				return false
			if not GameState.spend_energy(2):
				hud.toast("Too tired.", Color(1, 0.7, 0.7))
				return true
			Music.instance(get_tree()).sfx("chop")
			thing["hp"] = int(thing["hp"]) - 1
			if int(thing["hp"]) <= 0:
				thing["hp"] = 2
				give("stone", 2)
				if randf() < 0.3:
					give("copper", 1)
				xp("mining", 2)
			return true
		"shroom":
			if bool(thing.get("has", false)):
				thing["has"] = false
				thing["hint"] = ""
				GameState.run["flags"][thing["key"]] = int(GameState.run["day"])
				give("mushroom", 1)
				xp("foraging", 2)
				queue_redraw()
			return true
	return false


func _draw() -> void:
	draw_grass()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 50:
		var p := Vector2(rng.randf_range(TILE, (cols - 1) * TILE), rng.randf_range(TILE, (rows - 1) * TILE))
		var col: Color = [Color("f2e05c"), Color("f5f5f5"), Color("e36d8e"), Color("8ab4ff")][i % 4]
		draw_rect(Rect2(p.floor(), Vector2(2, 2)), col)
	for k in things:
		var t: Dictionary = things[k]
		match str(t.get("type", "")):
			"tree":
				draw_tree(cell_center(k))
			"rock":
				var p := cell_center(k)
				draw_circle(p + Vector2(0, -5), 6.5, Color("7a7a86"))
				draw_circle(p + Vector2(-2, -7), 3.0, Color("9a9aa6"))
			"shroom":
				if bool(t.get("has", false)):
					var p := cell_center(k)
					draw_rect(Rect2(p.x - 1, p.y - 5, 2, 5), Color("f0e6d0"))
					draw_rect(Rect2(p.x - 4, p.y - 8, 8, 3), Color("c9452f"))
	# Mine entrance in a rocky hill.
	draw_rect(Rect2(21 * TILE, 3 * TILE, 3 * TILE, 5 * TILE), Color("6a6a76"))
	draw_rect(Rect2(MINE_DOOR.x * TILE + 2, MINE_DOOR.y * TILE, 12, 16), Color("111"))
	draw_fence_border()
	draw_rect(Rect2(0, 9 * TILE, TILE, 3 * TILE), Color("b8945a"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(1 * TILE, 9 * TILE - 2), "◀ farm", HORIZONTAL_ALIGNMENT_LEFT, 4 * TILE, 7, Color(1, 1, 0.85))
	draw_string(font, Vector2(18 * TILE, 3 * TILE - 2), "mine", HORIZONTAL_ALIGNMENT_RIGHT, 3 * TILE, 7, Color(1, 1, 0.85))

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
	return Vector2(2 * TILE, 10 * TILE) + offset()


func build() -> void:
	cols = 36
	rows = 28
	pad = 6
	border = {"n": "cliff", "s": "trees", "w": "trees", "e": "trees"}
	music_track = "meadow"
	add_exit(FARM_EXIT, "farm", Vector2(68 * TILE, 30 * TILE + 8), "left", "◀ farm")
	add_exit(EAST_EXIT, "crystal_meadow", Vector2(2 * TILE, 12 * TILE), "right", ("crystal meadow ▶" if GameState.is_penguins() else "outskirts ▶"))
	add_exit(Rect2i(14, 0, 4, 1), "ruins", Vector2(24 * TILE, 41 * TILE + 8), "up", "▲ ruins")
	for p: Vector2i in [Vector2i(4, 2), Vector2i(10, 2), Vector2i(19, 3), Vector2i(21, 13), Vector2i(3, 13), Vector2i(13, 7), Vector2i(9, 13), Vector2i(26, 22), Vector2i(8, 22), Vector2i(19, 25)]:
		if not is_cleared(p):
			set_thing(p.x, p.y, {"type": "tree", "hp": 3, "hint": "A: chop"})
	for p: Vector2i in [Vector2i(7, 5), Vector2i(19, 7), Vector2i(12, 14), Vector2i(27, 17), Vector2i(15, 20)]:
		if not is_cleared(p, 8):
			set_thing(p.x, p.y, {"type": "rock", "hp": 2, "hint": "A: break rock"})
	set_thing(MINE_DOOR.x, MINE_DOOR.y, {"type": "mine", "hint": "A: enter the mine"})
	things[MINE_DOOR] = {"type": "mine", "hint": "A: enter the mine"}
	for m: Vector2i in SHROOMS:
		var key := "shroom_%d_%d" % [m.x, m.y]
		var has := int(GameState.run["flags"].get(key, 0)) < int(GameState.run["day"])
		things[m] = {"type": "shroom", "key": key, "has": has, "hint": "A: pick mushroom" if has else ""}
	extend(18, 14)
	# A two-tier hill in the opened-up south: climb the stairs for the view over the valley.
	var hav := cells_of([Rect2i(14, 18, 9, 8)])  # the tall-grass corner stays as it is
	hav.merge(_ext_paths)
	for e in exits:
		hav.merge(cells_of([(e["rect"] as Rect2i).grow(3)]))
	hav.merge(cells_of([Rect2i(cols - 10, rows - 11, 6, 6), Rect2i(5, rows - 9, 7, 6)]))  # watchtower, scarecrow field
	WorldGen.tiered_hill(self, Vector2(27.0, 34.0), 6.5, 4.6, 5101, hav)


func after_ready() -> void:
	WorldGen.add_backdrop(self, "mountains")
	if Art.has("props", "watchtower"):
		prop("props", "watchtower", Vector2i(cols - 8, rows - 8), 2)
		set_thing(cols - 7, rows - 7, {"type": "note", "text": "A watchtower with no watchers. From up top you could see the whole valley. The ladder's gone.", "hint": "A: the tower"}, false)
	if Art.has("props", "scarecrow_field"):
		prop("props", "scarecrow_field", Vector2i(8, rows - 6))
	_place_props()
	WorldGen.clear_stairs.call_deferred(self)
	var avoid := {}
	for y in range(3, 9):
		for x in range(30, 35):
			avoid[Vector2i(x, y)] = true
	for c in cells_of([Rect2i(0, 8, 32, 5), Rect2i(27, 8, 9, 10), Rect2i(14, 0, 4, 10), Rect2i(34, 13, 20, 5)]):
		avoid[c] = true  # keep the roads clear
	WorldGen.tree_clumps(self, Rect2i(2, 2, cols - 4, rows - 4), 42, 6, avoid)
	WorldGen.scatter_props(self, Rect2i(2, 2, cols - 4, rows - 4), 43, 20, avoid)
	WorldGen.add_critters(self, Rect2i(2, 2, cols - 4, rows - 4), 44, 12, ["butterfly_orange", "butterfly_blue", "butterfly_yellow", "bee", "bee", "rabbit", "sparrow", "deer"])
	var n := 3 if not GameState.quest_done("clear_meadow") else 2
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
			{"text": "Grumps. The Star Crystal wasn't exaggerating. Tap USE to swing, ROLL to dodge. Run if it goes badly."},
		] + PupIntro.lines())
	else:
		await say([
			{"text": "Whoever came through here brought company. Small, ugly, and organized. The President's cheapest kind of muscle."},
			{"text": "Tap USE to swing, ROLL to dodge. Nobody's watching, so there's no shame in it."},
		] + PupIntro.lines())
	# Put the sword in your hand: the hoe doesn't hurt anything.
	var tb: Array = GameState.run["toolbar"]
	for i in tb.size():
		if GameState.is_sword(str(tb[i])):
			GameState.select_slot(i)
			hud.toast("%s out. Tap USE to swing." % GameState.weapon_word().capitalize(), Color(1, 0.95, 0.7))
			break
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
			return "thug_lookout"
		var pool: Array = ["thug_lookout", "thug_speedster", "thug_cyber"]
		if GameState.progress_tier() >= 2:
			pool += ["thug_gambler", "thug_flame"]
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
	if e.has_meta("minion"):
		return  # summoned helpers don't count as meadow kills
	if _boss_pending:
		return
	if GameState.quest_done("clear_meadow"):
		if enemies.size() < 2 and randf() < 0.5:
			_spawn_one()
		return
	GameState.run["meadow_kills"] = int(GameState.run.get("meadow_kills", 0)) + 1
	if int(GameState.run["meadow_kills"]) >= 5 and _boss == null and not _boss_pending:
		_summon_boss()
	elif enemies.size() < 2:
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
	# Near the player (on screen), on the side toward the middle of the map.
	var side := -1.0 if player.position.x > cols * TILE * 0.5 else 1.0
	var bat := free_spot_near(player.position + Vector2(48 * side, -32))
	_boss = spawn_enemy("big_grump" if GameState.is_penguins() else "thug_brute", bat, -1 if GameState.is_penguins() else 1)
	_boss.set_meta("boss_name", "Big Grump" if GameState.is_penguins() else "The President's Man")
	# The first boss of either arc: a new player with the starter sword and 100
	# health should lose about half of it standing toe to toe, and little if
	# they step back from the red flash. Hits for 12, 24 once it's enraged
	# (tools/early_fight_audit.gd measures this).
	_boss.damage = 1
	boss_card("big_grump" if GameState.is_penguins() else "thug_brute", "Big Grump" if GameState.is_penguins() else "The President's Man")
	Music.instance(get_tree()).play(boss_music)
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
		GameState.add_item("shard", 2)
		await say([
			{"text": "The big Grump comes apart into grey smoke. Where it stood, the grass turns green again. Then greener than it was."},
			{"who": "Star Crystal", "text": "(from very far away) ...there it is. The first spark. It was in you the whole time, I only lit it."},
			{"text": "Your heart grows two sizes. Literally: +2 max hearts. Two crystal shards glitter in the grass where it fell."},
		])
	else:
		await say([
			{"text": "He goes down hard. When he gets up, he isn't interested in you any more. He's interested in the rocks, and the road, and anywhere that isn't here."},
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
				if not Art.has("nature", "oak"):
					queue_redraw()  # only the no-art fallback paints shrooms
			return true
	return false


func draw_map() -> void:
	draw_grass(5)
	WorldGen.draw_ground_detail(self, 51, 0.18)
	if Art.has("nature", "gdeco_tuft_a") and Art.has("nature", "fdeco_0"):
		# Flower beds and the tall-grass corner as cut-out decals on the grass
		# (raw g_flower / g_tall tiles showed as hard-edged squares).
		var fl: Array = ["gdeco_dandelion", "gdeco_clover", "fdeco_0", "fdeco_1", "fdeco_2", "fdeco_3", "fdeco_4", "fdeco_5"]
		for c: Vector2i in cells_of([Rect2i(4, 18, 9, 6), Rect2i(20, 3, 7, 4)]):
			var hv := absi((c.x * 73856093) ^ (c.y * 19349663))
			if not blocked.has(c) and hv % 20 < 9:
				var nm: String = fl[hv % fl.size()]
				if Art.has("nature", nm):
					Art.draw_prop(self, "nature", nm, Vector2(c * TILE) + Vector2(8 + (hv >> 4) % 7 - 3, 14 + (hv >> 8) % 5 - 2))
		var tufts := ["gdeco_tuft_a", "gdeco_tuft_b", "gdeco_tuft_c"]
		for c: Vector2i in cells_of([Rect2i(14, 20, 8, 5)]):
			if not blocked.has(c):
				var hv := absi((c.x * 73856093) ^ (c.y * 19349663))
				Art.draw_prop(self, "nature", tufts[hv % 3], Vector2(c * TILE) + Vector2(5 + (hv >> 3) % 6, 9 + (hv >> 6) % 4))
				if hv % 3 != 0:
					Art.draw_prop(self, "nature", tufts[(hv >> 2) % 3], Vector2(c * TILE) + Vector2(10 + (hv >> 9) % 5, 15 + (hv >> 12) % 2))
	elif Art.has("tiles", "g_flower"):
		for c: Vector2i in cells_of([Rect2i(4, 18, 9, 6), Rect2i(20, 3, 7, 4)]):
			if not blocked.has(c):
				Art.draw_tile(self, "tiles", "g_flower", Vector2(c * TILE), 4)
		for c: Vector2i in cells_of([Rect2i(14, 20, 8, 5)]):
			if not blocked.has(c):
				Art.draw_tile(self, "tiles", "g_tall", Vector2(c * TILE), 4)
	draw_ground("dirt", cells_of([Rect2i(15, 0, 2, 10), Rect2i(1, 9, 30, 3), Rect2i(28, 9, 3, 6), Rect2i(28, 14, 7, 3), FARM_EXIT, EAST_EXIT]))
	draw_plateaus()
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
	if not soft_ground(cells_of([Rect2i(30, 3, 5, 6)]), "ruin_floor", Color(0.12, 0.1, 0.08, 0.3)):
		draw_ground("stone", cells_of([Rect2i(30, 3, 5, 6)]))
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
					prop("nature", "mushrooms_fall" if Art.has("nature", "mushrooms_fall") else "flowers", k, 0, 0.0, false)  # deco_5 is an opaque grass square
	# The mine mouth: a big timbered portal dressed with rocks, lanterns, rails and
	# an ore cart (falls back to the small prop when the portal art is missing).
	preload("res://scripts/mine_entrance.gd").dress(self, MINE_DOOR)
	prop("nature", "log", Vector2i(6, 13), 1)

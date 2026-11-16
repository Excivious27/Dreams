class_name GameMap
extends Node2D
## Base for every playable area. Owns the grid (size, blocked cells, things you
## can interact with), the player, the pet, camera, HUD, touch controls, sky, the
## clock, tap-to-move, and scene transitions. Subclasses draw the ground and
## place props. Children are y-sorted so the player walks behind tall things.

const TILE := 16
static var next_spawn := Vector2.ZERO
static var next_facing := "down"
static var next_interior := ""

var cols := 20
var rows := 30
var music_track := "farm"
var has_sky := true
var has_pet := true
var blocked := {}        # Vector2i -> true
var things := {}         # Vector2i -> Dictionary {type, ...}
var player: Player
var pet: Node2D
var hud: Hud
var enemies: Array = []
var sky: Scenery
var props := {}          # Vector2i -> Sprite2D (so things can change their look)
## Organic border: `pad` cells of forest/cliff/water around the content, drawn by
## draw_border(). Content coordinates stay 0..cols-1; world = (cell + pad) * TILE.
var pad := 0
## "trees" | "cliff" | "water" | "none", or a Dictionary per side {"n","s","e","w"}.
var border: Variant = "trees"
var _border_cells := {}  # Vector2i -> "tree" | "bigtree" | "rock" | "water" | "cliff"
var _border_draw: Array = []  # [[Vector2i cell, String group, String name], ...] sorted by y
var _border_rng := RandomNumberGenerator.new()
var _border_open := {}
var _ext := Rect2i()          # area added by extend()
var _ext_paths := {}          # dirt connecting moved exits
var hitstop := 0.0
var _pet_anim: AnimatedSprite2D
var _night: CanvasModulate
var _changing := false
var _time_acc := 0.0
var _pet_idle := 0.0
var _pet_busy := false
var _deco_rng := RandomNumberGenerator.new()


func _ready() -> void:
	InputSetup.ensure_actions()
	y_sort_enabled = true
	# Art is 2x detail drawn at half size; linear sampling keeps thin lines intact.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if not GameState.has_run():
		GameState.new_run("penguins", "dad", "Hero", "Dreamhollow", "Pup")
	GameState.run["scene"] = scene_id()
	build()
	# Outer ring is always solid; with a pad the organic border fills the rest.
	for x in range(-pad, cols + pad):
		blocked[Vector2i(x, -pad)] = true
		blocked[Vector2i(x, rows + pad - 1)] = true
	for y in range(-pad, rows + pad):
		blocked[Vector2i(-pad, y)] = true
		blocked[Vector2i(cols + pad - 1, y)] = true
	if pad > 0:
		_build_border()
	for e in exits:
		var r: Rect2i = e["rect"]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				blocked.erase(Vector2i(x, y))

	if has_sky:
		sky = Scenery.new()
		sky.raining = not GameState.is_penguins() and int(GameState.run["day"]) == 1
		sky.weather = GameState.weather_today()
		add_child(sky)
	_night = CanvasModulate.new()
	add_child(_night)

	player = Player.new()
	player.map = self
	player.position = (next_spawn + offset()) if next_spawn != Vector2.ZERO else default_spawn()
	player.facing = next_facing
	next_spawn = Vector2.ZERO
	add_child(player)
	player.set_character(GameState.sprite_for_playable(str(GameState.run["playable"])))

	if has_pet:
		pet = Node2D.new()
		_pet_anim = CharacterLibrary.make_sprite("dog")
		pet.add_child(_pet_anim)
		pet.position = player.position + Vector2(-14, 4)
		_pet_anim.play("idle")
		add_child(pet)

	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = maxi((cols + 2 * pad) * TILE, 270)
	cam.limit_bottom = maxi((rows + 2 * pad) * TILE, 480)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	player.add_child(cam)
	cam.make_current()

	hud = Hud.new()
	add_child(hud)
	add_child(TouchControls.new())
	add_child(GameMenu.new())
	Music.instance(get_tree()).play(music_track)
	queue_redraw()
	hud.fade_in(0.5)
	after_ready()
	_fill_extension()
	_place_signposts()
	unstick_player()
	_check_quests.call_deferred()


## Subclasses override these.
func scene_id() -> String:
	return "farm"
func build() -> void:
	pass
func after_ready() -> void:
	pass
func default_spawn() -> Vector2:
	return Vector2(cols * TILE / 2.0, rows * TILE / 2.0)
func interact(_cell: Vector2i, _thing: Dictionary) -> bool:
	return false
func hint_for(_cell: Vector2i, thing: Dictionary) -> String:
	return str(thing.get("hint", ""))


# ---- grid helpers ------------------------------------------------------------

func block_rect(x: int, y: int, w: int, h: int) -> void:
	for i in w:
		for j in h:
			blocked[Vector2i(x + i, y + j)] = true


func set_thing(x: int, y: int, thing: Dictionary, solid := true) -> void:
	things[Vector2i(x, y)] = thing
	if solid:
		blocked[Vector2i(x, y)] = true


func rect_blocked(r: Rect2) -> bool:
	var x0 := floori(r.position.x / TILE) - pad
	var y0 := floori(r.position.y / TILE) - pad
	var x1 := floori((r.end.x - 0.01) / TILE) - pad
	var y1 := floori((r.end.y - 0.01) / TILE) - pad
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			if blocked.has(Vector2i(x, y)):
				return true
	return false


func cell_center(c: Vector2i) -> Vector2:
	return Vector2((c.x + pad) * TILE + TILE / 2.0, (c.y + pad) * TILE + TILE)


## World position of a content coordinate (cells, may be fractional).
func cell_pos(x: float, y: float) -> Vector2:
	return Vector2((x + pad) * TILE, (y + pad) * TILE)


func offset() -> Vector2:
	return Vector2(pad, pad) * TILE


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE) - pad, floori(p.y / TILE) - pad)


func in_content(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows


func try_interact(c: Vector2i) -> bool:
	var thing: Dictionary = things.get(c, {})
	if interact(c, thing):
		return true
	return interact_common(c, thing)


## Interactions every outdoor map shares (trees, rocks, logs, stumps, bushes).
func interact_common(c: Vector2i, thing: Dictionary) -> bool:
	match str(thing.get("type", "")):
		"pet_animal":
			var a: Variant = thing.get("animal", null)
			if a != null and is_instance_valid(a):
				var key := "pet_%s_%d" % [str(a.kind), int(GameState.run["day"])]
				if GameState.run["flags"].has(key):
					hud.toast("Already happy today.")
				else:
					GameState.run["flags"][key] = true
					emote(a, "heart", 1.4, -18.0)
					hud.toast("%s loves that." % str(a.kind).split("_")[0].capitalize(), Color(1, 0.8, 0.9))
					xp("farming", 2)
			return true
		"weeds":
			# Weeds come out by hand (or any tool): fiber, Stardew-style.
			if not GameState.spend_energy(1):
				hud.toast("Too tired.", Color(1, 0.7, 0.7))
				return true
			var ht := GameState.held_tool()
			if ht in ["sword", "iron_sword", "scythe"]:
				player.play_tool("axe")
			else:
				player.play_tool("hold")
			Music.instance(get_tree()).sfx("chop")
			xp("foraging", 1)
			_mark_cleared(c)
			var wsp: Node2D = props.get(c, null)
			clear_cell(c)
			if wsp:
				wsp.queue_free()
			for i in 4:
				_leaf(cell_center(c) + Vector2(randf_range(-6, 6), -8))
			pop_items(cell_center(c), "fiber", 1 + (1 if randf() < 0.3 else 0))
			return true
		"tree", "log", "stump":
			if GameState.held_tool() != "axe":
				if GameState.has_tool("axe"):
					hud.toast("Use the axe for that.")
				return GameState.has_tool("axe")
			if not GameState.has_perk("foraging", "Keeper of the Woods") and not GameState.spend_energy(2):
				hud.toast("Too tired.", Color(1, 0.7, 0.7))
				return true
			player.play_tool("axe")
			Music.instance(get_tree()).sfx("chop")
			if GameState.has_perk("foraging", "Woodcutter") and int(thing.get("hp", 3)) > 1:
				thing["hp"] = int(thing.get("hp", 3)) - 1
			wobble(c, 0.08 if str(thing["type"]) == "tree" else 0.03)
			fx("wood_chips", cell_center(c) + Vector2(0, -10), 16.0, 0.5)
			thing["hp"] = int(thing.get("hp", 3)) - 1
			if int(thing["hp"]) <= 0:
				var is_tree := str(thing["type"]) == "tree"
				xp("foraging", 3)
				var bonus := 2 if GameState.has_perk("foraging", "Lumberjack") else 0
				if is_tree and not bool(thing.get("fell", false)):
					thing["hp"] = 3
					pop_items(cell_center(c), "wood", 3 + bonus)
					if GameState.has_perk("foraging", "Sap Tapper") and randf() < 0.5:
						pop_items(cell_center(c), "sap", 1)
				elif is_tree:
					_mark_cleared(c)
					fell_tree(c, 6 + bonus)
				else:
					_mark_cleared(c)
					var sp: Node2D = props.get(c, null)
					clear_cell(c)
					if sp:
						sp.queue_free()
					fx("poof", cell_center(c) + Vector2(0, -6), 16.0, 0.5)
					pop_items(cell_center(c), "wood", 2)
			return true
		"rock":
			if GameState.held_tool() != "pickaxe":
				if GameState.has_tool("pickaxe"):
					hud.toast("Use the pickaxe for that.")
				return GameState.has_tool("pickaxe")
			if not GameState.spend_energy(2):
				hud.toast("Too tired.", Color(1, 0.7, 0.7))
				return true
			player.play_tool("pickaxe")
			Music.instance(get_tree()).sfx("chop")
			wobble(c, 0.04)
			fx("stone_chips", cell_center(c) + Vector2(0, -8), 16.0, 0.5)
			thing["hp"] = int(thing.get("hp", 2)) - 1
			if int(thing["hp"]) <= 0:
				xp("mining", 2)
				_mark_cleared(c)
				var big := props.has(c) and (props[c] as Sprite2D).texture and str((props[c] as Sprite2D).texture.resource_path).contains("rock_m")
				var extra := "copper"
				var en := 1 if randf() < 0.25 else 0
				if GameState.has_perk("mining", "Gem Sense") and randf() < 0.06:
					extra = ["amethyst", "ruby", "sapphire", "emerald"][randi() % 4]
					en = 1
				break_rock(c, 2 + (1 if GameState.has_perk("mining", "Rockbreaker") else 0), extra, en, "m" if big else "")
			return true
		"bush":
			if bool(thing.get("berries", false)):
				thing["berries"] = false
				thing["hint"] = ""
				GameState.run["flags"][str(thing["key"])] = int(GameState.run["day"])
				give("berry", 2)
				xp("foraging", 2)
				if props.has(c) and Art.tex("nature", GameState.bush_sprite(false)):
					(props[c] as Sprite2D).texture = Art.tex("nature", GameState.bush_sprite(false))
			return true
		"forage":
			var item := str(thing.get("item", "mushroom"))
			GameState.run["flags"][str(thing["key"])] = int(GameState.run["day"])
			things.erase(c)
			var fsp: Node2D = props.get(c, null)
			props.erase(c)
			if fsp:
				fsp.queue_free()
			pop_items(cell_center(c), item, 1 + (1 if GameState.has_perk("foraging", "Forager") else 0))
			xp("foraging", 2 + int(GameState.items.get(item, {}).get("tier", 1)))
			return true
	return false


## Open the map up: add `dx` columns of grass to the right and `dy` rows below,
## moving exits that sat on the old right/bottom edges out to the new edges and
## laying a dirt track to them. Call at the end of build(), after add_exit().
func extend(dx: int, dy: int) -> void:
	var oc := cols
	var orow := rows
	cols += dx
	rows += dy
	_ext = Rect2i(0, 0, cols, rows)
	for e in exits:
		var r: Rect2i = e["rect"]
		if r.end.x >= oc and dx > 0:
			var nr := Rect2i(cols - r.size.x, r.position.y, r.size.x, r.size.y)
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, cols):
					_ext_paths[Vector2i(x, y)] = true
			e["rect"] = nr
		if r.end.y >= orow and dy > 0:
			var nr := Rect2i(r.position.x, rows - r.size.y, r.size.x, r.size.y)
			for x in range(r.position.x, r.end.x):
				for y in range(r.position.y, rows):
					_ext_paths[Vector2i(x, y)] = true
			e["rect"] = nr
	# Blocks the old map put on its own right/bottom ring are now in the open: clear them.
	for c: Vector2i in blocked.keys():
		if (c.x == oc - 1 or c.y == orow - 1) and not things.has(c) and not props.has(c):
			blocked.erase(c)
	for c: Vector2i in _ext_paths:
		blocked.erase(c)


## A wooden signpost beside every labelled exit (W26 travel pieces).
func _place_signposts() -> void:
	if not Art.has("props", "signpost_1"):
		return
	var i := 0
	for e in exits:
		if str(e["label"]) == "":
			continue
		var r: Rect2i = e["rect"]
		var c := Vector2i(r.end.x, r.position.y) if r.size.y >= r.size.x else Vector2i(r.position.x - 1, r.end.y - 1)
		if r.position.x <= 0:
			c = Vector2i(r.end.x, r.position.y - 1)
		elif r.end.x >= cols:
			c = Vector2i(r.position.x - 1, r.position.y - 1)
		elif r.position.y <= 0:
			c = Vector2i(r.end.x, r.end.y)
		else:
			c = Vector2i(r.end.x, r.position.y - 1)
		if not in_content(c) or blocked.has(c) or things.has(c) or props.has(c):
			continue
		prop("props", "signpost_%d" % (1 + i % 3), c)
		i += 1


## Light life for the added space: a few rocks, logs, bushes, clumps and critters.
func _fill_extension() -> void:
	if _ext.size == Vector2i.ZERO:
		return
	var avoid := _ext_paths.duplicate()
	for e in exits:
		for c in cells_of([(e["rect"] as Rect2i).grow(2)]):
			avoid[c] = true
	var seed_v := hash(scene_id()) % 1000
	WorldGen.tree_clumps(self, Rect2i(2, 2, cols - 4, rows - 4), seed_v + 5, int(cols * rows / 260.0), avoid)
	WorldGen.scatter_props(self, Rect2i(2, 2, cols - 4, rows - 4), seed_v + 6, int(cols * rows / 110.0), avoid)
	WorldGen.add_critters(self, Rect2i(2, 2, cols - 4, rows - 4), seed_v + 7, int(cols * rows / 350.0))


func _check_quests() -> void:
	if GameState.run.is_empty():
		return
	for id in GameState.tick_quests():
		hud.toast("Quest complete: %s" % id.replace("_", " "), Color(1, 0.9, 0.4))
		Music.instance(get_tree()).sfx("levelup")


## Emote bubble over a node (W36): "heart", "surprise", "confused", "sleep", "music", "angry", "talk"...
func emote(over: Node2D, name: String, secs := 1.2, dy := -22.0) -> void:
	if over == null or not Art.has("emotes", name):
		return
	var a := AnimatedSprite2D.new()
	a.sprite_frames = Art.frames("emotes", {"e": name}, {"e": 6.0})
	a.animation = "e"
	a.scale = Vector2(0.5, 0.5)
	a.position = Vector2(0, dy)
	a.z_index = 30
	over.add_child(a)
	a.play("e")
	var tw := a.create_tween()
	tw.tween_property(a, "position:y", dy - 4.0, secs)
	tw.tween_callback(a.queue_free)


# ---- action feedback (chop/mine cinematics) ----------------------------------

## Shake a prop when it's hit (trees sway, rocks jolt).
func wobble(c: Vector2i, amount := 0.08) -> void:
	if not props.has(c):
		return
	var sp := props[c] as Node2D
	var tw := sp.create_tween()
	tw.tween_property(sp, "rotation", amount, 0.05)
	tw.tween_property(sp, "rotation", -amount * 0.7, 0.08)
	tw.tween_property(sp, "rotation", amount * 0.3, 0.07)
	tw.tween_property(sp, "rotation", 0.0, 0.06)
	for i in 3:
		_leaf(cell_center(c) + Vector2(randf_range(-8, 8), randf_range(-26, -12)))


## Fell a tree: it tips over away from the player, thuds, bursts into wood.
func fell_tree(c: Vector2i, wood := 5) -> void:
	var sp: Node2D = props.get(c, null)
	things.erase(c)
	blocked.erase(c)
	props.erase(c)
	if sp == null:
		give("wood", wood)
		return
	var dir := 1.0 if player.position.x <= sp.position.x else -1.0
	var pine := sp is Sprite2D and (sp as Sprite2D).texture and str((sp as Sprite2D).texture.resource_path).contains("pine")
	var anim := ("pine_fall_r" if pine else ("oak_fall_r" if dir > 0 else "oak_fall_l"))
	if Art.has("fx", anim):
		_fell_tree_fx(sp, c, dir, anim, pine, wood)
		return
	var tw := sp.create_tween()
	tw.tween_property(sp, "rotation", dir * 0.25, 0.25).set_ease(Tween.EASE_IN)
	tw.tween_property(sp, "rotation", dir * PI / 2.0, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		shake(2.5)
		Music.instance(get_tree()).sfx("hit")
		fx("poof", sp.position + Vector2(dir * 20.0, -4), 14.0, 0.7)
		for i in 5:
			_leaf(sp.position + Vector2(dir * randf_range(6, 30), randf_range(-10, 0))))
	tw.tween_interval(0.35)
	tw.tween_property(sp, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		sp.queue_free()
		pop_items(cell_center(c) + Vector2(dir * 16.0, 0), "wood", wood))


func _fell_tree_fx(sp: Node2D, c: Vector2i, dir: float, anim: String, pine: bool, wood: int) -> void:
	# The painted fall: swap the prop for the W32 strip, then the trunk breaks into logs.
	var a := AnimatedSprite2D.new()
	a.sprite_frames = Art.frames("fx", {"fall": anim, "trunk": "trunk_break"}, {"fall": 12.0, "trunk": 10.0}, {"fall": false, "trunk": false})
	a.animation = "fall"
	a.scale = Vector2(0.5, 0.5)
	a.position = sp.position
	a.offset = Vector2(0, -float(Art.info("fx", anim).get("cell_h", 112)) / 2.0)
	a.flip_h = pine and dir < 0
	a.z_index = sp.z_index
	add_child(a)
	sp.queue_free()
	a.play("fall")
	var at := cell_center(c)
	var leaves_at := at + Vector2(dir * 18.0, -14)
	await a.animation_finished
	shake(2.5)
	Music.instance(get_tree()).sfx("hit")
	fx("leaf_burst", leaves_at, 14.0, 0.6)
	fx("dust_puff", at + Vector2(dir * 22.0, 0), 14.0, 0.5)
	await get_tree().create_timer(0.25).timeout
	if a.sprite_frames.has_animation("trunk"):
		a.animation = "trunk"
		a.offset = Vector2(0, -float(Art.info("fx", "trunk_break").get("cell_h", 56)) / 2.0)
		a.flip_h = dir < 0
		a.position = at + Vector2(dir * 10.0, 0)
		a.play("trunk")
		fx("wood_chips", at + Vector2(dir * 14.0, -8), 14.0, 0.6)
		await a.animation_finished
	a.queue_free()
	pop_items(at + Vector2(dir * 16.0, 0), "wood", wood)


## Break a rock: jolt, crumble, stone pops out.
func break_rock(c: Vector2i, stone := 2, extra := "", extra_n := 0, kind := "") -> void:
	var sp: Node2D = props.get(c, null)
	things.erase(c)
	blocked.erase(c)
	props.erase(c)
	var at := cell_center(c)
	var anim: String = {"copper": "ore_copper_break", "iron": "ore_iron_break", "shard": "ore_crystal_break", "m": "rock_m_break"}.get(kind, "rock_s_break")
	if Art.has("fx", anim):
		if sp:
			sp.queue_free()
		# Frames 0-3 are the crack (already shown on hits); play the shatter.
		var a := AnimatedSprite2D.new()
		a.sprite_frames = Art.frames("fx", {"b": anim}, {"b": 16.0}, {"b": false})
		a.animation = "b"
		a.frame = 4
		a.scale = Vector2(0.5, 0.5)
		a.position = at
		a.offset = Vector2(0, -float(Art.info("fx", anim).get("cell_h", 72)) / 2.0 + 4)
		add_child(a)
		a.play("b")
		a.animation_finished.connect(a.queue_free)
		fx("stone_chips", at + Vector2(0, -8), 14.0, 0.6)
		fx("dust_puff", at, 14.0, 0.45)
		shake(1.5)
		pop_items(at, "stone", stone)
		if extra != "" and extra_n > 0:
			pop_items(at, extra, extra_n)
		return
	if sp:
		var tw := sp.create_tween()
		tw.tween_property(sp, "scale", sp.scale * Vector2(1.25, 0.7), 0.08)
		tw.tween_property(sp, "modulate:a", 0.0, 0.1)
		tw.tween_callback(sp.queue_free)
	fx("poof", at + Vector2(0, -6), 16.0, 0.5)
	shake(1.5)
	pop_items(at, "stone", stone)
	if extra != "" and extra_n > 0:
		pop_items(at, extra, extra_n)


## Items burst out of a spot, bounce, then fly to you and land in the bag.
func pop_items(at: Vector2, id: String, n: int) -> void:
	give(id, n)
	var icon := Art.tex("items", "pop_" + id) if Art.has("items", "pop_" + id) else Art.tex("items", id)
	for i in mini(n, 6):
		var it := Sprite2D.new()
		if icon:
			it.texture = icon
			it.scale = Vector2(0.5, 0.5)
		else:
			it.texture = Art.tex("items", "wood")
		it.position = at + Vector2(0, -6)
		it.z_index = 5
		add_child(it)
		var land := at + Vector2(randf_range(-18, 18), randf_range(-4, 10))
		var tw := it.create_tween()
		tw.tween_property(it, "position", land + Vector2(0, -22), 0.18).set_ease(Tween.EASE_OUT)
		tw.tween_property(it, "position", land, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
		tw.tween_interval(0.25 + i * 0.05)
		tw.tween_method(func(f: float) -> void:
			if is_instance_valid(player):
				it.position = it.position.lerp(player.position + Vector2(0, -10), f), 0.0, 1.0, 0.3).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			it.queue_free()
			Music.instance(get_tree()).sfx("pickup"))


func _leaf(at: Vector2) -> void:
	var d := Node2D.new()
	d.position = at
	d.z_index = 4
	var age := [0.0]
	var col := Color(0.35, 0.65, 0.25) if GameState.season() != "fall" else Color(0.85, 0.5, 0.2)
	var drift := randf_range(-10, 10)
	d.draw.connect(func() -> void:
		var a: float = age[0]
		d.draw_rect(Rect2(Vector2(drift * a + sin(a * 9.0) * 3.0, a * 22.0), Vector2(2, 2)), Color(col, 1.0 - a)))
	add_child(d)
	var tw := d.create_tween()
	tw.tween_method(func(v: float) -> void: age[0] = v; d.queue_redraw(), 0.0, 1.0, 0.7)
	tw.tween_callback(d.queue_free)


## Debris that stays gone: scenes that generate rocks/logs/weeds from a seed skip
## cells recorded here (GameState.run["cleared"][scene] = ["x,y", ...]).
func _mark_cleared(c: Vector2i) -> void:
	var all: Dictionary = GameState.run.get("cleared", {})
	var lst: Array = all.get(scene_id(), [])
	var key := "%d,%d" % [c.x, c.y]
	if not key in lst:
		lst.append(key)
	all[scene_id()] = lst
	GameState.run["cleared"] = all


func is_cleared(c: Vector2i) -> bool:
	var all: Dictionary = GameState.run.get("cleared", {})
	return ("%d,%d" % [c.x, c.y]) in all.get(scene_id(), [])


## Declare an exit strip: standing in `r` sends you to `scene` at `spawn`.
var exits: Array = []
func add_exit(r: Rect2i, scene: String, spawn: Vector2, facing: String, label_text := "") -> void:
	exits.append({"rect": r, "scene": scene, "spawn": spawn, "facing": facing, "label": label_text})
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			blocked.erase(Vector2i(x, y))


func check_exits() -> void:
	if player == null or player.frozen or _changing:
		return
	var c := player.cell()
	for e in exits:
		if (e["rect"] as Rect2i).has_point(c):
			go_to(str(e["scene"]), e["spawn"], str(e["facing"]))
			return


func draw_exits() -> void:
	for e in exits:
		var r: Rect2i = e["rect"]
		if str(e["label"]) != "":
			var p := Vector2(r.position * TILE)
			label(str(e["label"]), p + Vector2(-24, -3 if r.position.y > 2 else TILE + 12), r.size.x * TILE + 48)


## Place a sprite from art/gen with its feet at the bottom-center of cell `c`
## (plus `extra_w` cells to the right for wide props). Returns null if missing.
func prop(group: String, name: String, c: Vector2i, extra_w := 0, dy := 0.0, solid := true) -> Sprite2D:
	var s := Art.sprite(group, name)
	if s == null:
		return null
	s.position = cell_pos(c.x + (extra_w + 1) / 2.0, c.y + 1) + Vector2(0, dy)
	add_child(s)
	props[c] = s
	if solid:
		# Base row always; big structures (buildings, barns, huts) also block the
		# rows their body covers so you can't walk "into" them. Trees stay 1 row.
		var tex_w := s.texture.get_width() / 2.0
		var tex_h := s.texture.get_height() / 2.0
		var rows_up := 1
		if tex_w >= 56.0 or group == "buildings":
			rows_up = clampi(int(round(tex_h / TILE)) - 1, 1, 5)
		var w_cells := maxi(extra_w + 1, int(round(tex_w / TILE)))
		var x0 := c.x + (extra_w + 1) / 2 - w_cells / 2
		for i in w_cells:
			for j in rows_up:
				var bc := Vector2i(x0 + i, c.y - j)
				if j == 0 or not things.has(bc):
					blocked[bc] = true
	return s


## Remove a prop and its thing/block at a cell.
func clear_cell(c: Vector2i) -> void:
	things.erase(c)
	blocked.erase(c)
	if props.has(c):
		(props[c] as Node).queue_free()
		props.erase(c)


## One-shot effect from art/gen/fx at a world position (bottom-center). Falls back to nothing.
func fx(name: String, at: Vector2, fps := 12.0, scale := 0.5, flip := false) -> void:
	if not Art.has("fx", name):
		return
	var sp := AnimatedSprite2D.new()
	sp.sprite_frames = Art.frames("fx", {name: name}, {name: fps}, {name: false})
	sp.animation = name
	sp.position = at
	sp.scale = Vector2(scale, scale)
	sp.flip_h = flip
	sp.z_index = 3
	sp.centered = true
	add_child(sp)
	sp.play(name)
	sp.animation_finished.connect(sp.queue_free)


## Rain/snow/leaves/fireflies overlay; set by season/weather.
func set_weather(kind: String) -> void:
	if sky:
		sky.weather = kind


func set_aurora(on: bool) -> void:
	if sky:
		sky.aurora = on


# ---- enemies -----------------------------------------------------------------

## Swing at enemies inside the rect. Subclasses can extend (rocks, etc.).
func attack_at(r: Rect2, damage: int, from := Vector2.INF) -> bool:
	Music.instance(get_tree()).sfx("swing")
	var hit := false
	if from == Vector2.INF:
		from = player.position
	for e in enemies.duplicate():
		if not is_instance_valid(e):
			continue
		# Enemies have a body ~12px wide, 14 tall above their feet.
		var body := Rect2(e.position + Vector2(-6, -14), Vector2(12, 14))
		if r.intersects(body):
			var crit := randf() < 0.03 * GameState.skill_level("combat") + (0.1 if GameState.has_perk("combat", "Critical Eye") else 0.0)
			var dmg := damage * (2 if crit else 1)
			if e.hit(dmg, from):
				hit = true
				fx("spark", e.position + Vector2(0, -8), 18.0, 0.5)
				damage_number(e.position + Vector2(0, -20), dmg, Color(1, 0.95, 0.4) if crit else Color.WHITE)
	if hit:
		Music.instance(get_tree()).sfx("hit")
	return hit


## Short freeze on a solid hit (Stardew-style weight). Counted down in _process.
func shake(amount: float) -> void:
	var cam := player.get_node_or_null("Camera2D") if player else null
	if cam == null:
		for ch in player.get_children():
			if ch is Camera2D:
				cam = ch
	if cam == null:
		return
	var c := cam as Camera2D
	var tw := c.create_tween()
	for i in 3:
		tw.tween_property(c, "offset", Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), 0.03)
	tw.tween_property(c, "offset", Vector2.ZERO, 0.04)


## Floating damage number.
func damage_number(at: Vector2, n: int, col := Color.WHITE) -> void:
	if n <= 0:
		return
	var l := Label.new()
	l.text = str(n)
	l.position = at + Vector2(-8, 0)
	l.z_index = 20
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 3)
	add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", at.y - 18.0, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)


func spawn_enemy(kind: String, at: Vector2) -> Enemy:
	var e := Enemy.new()
	e.map = self
	e.setup(kind)
	e.position = at
	add_child(e)
	enemies.append(e)
	return e


func on_enemy_died(e: Enemy) -> void:
	fx("poof", e.position + Vector2(0, -8), 14.0, 0.6)
	GameState.run["kills"] = int(GameState.run.get("kills", 0)) + 1
	GameState.run["crystals"] = int(GameState.run["crystals"]) + e.reward
	hud.toast("+%d crystals" % e.reward, Color(0.7, 0.9, 1))
	var ed: Dictionary = GameState.enemy_data.get("enemies", {}).get(e.kind, {})
	xp("combat", int(ed.get("xp", 2)))
	var table: Array = GameState.enemy_data.get("drops", {}).get(e.kind, [])
	var got := GameState.roll_drops(table)
	for id: String in got:
		pop_items(e.position, id, int(got[id]))
	var kc: Dictionary = GameState.run.get("kill_counts", {})
	kc[e.kind] = int(kc.get(e.kind, 0)) + 1
	GameState.run["kill_counts"] = kc
	Music.instance(get_tree()).sfx("die")


func nearest_enemy_to(p: Vector2, within: float) -> Enemy:
	var best: Enemy = null
	for e in enemies:
		if is_instance_valid(e) and e.position.distance_to(p) < within:
			if best == null or e.position.distance_to(p) < best.position.distance_to(p):
				best = e
	return best


func player_down() -> void:
	if _changing:
		return
	_changing = true
	player.frozen = true
	hud.toast("You collapsed...", Color(1, 0.6, 0.6))
	await hud.fade_out(1.0)
	GameState.run["crystals"] = maxi(0, int(GameState.run["crystals"]) - 15)
	GameState.sleep(true)
	hud.toast("You lost 15 crystals.")
	go_to("house", Vector2(5 * TILE + 8, 5 * TILE))


# ---- tap to move -------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or player == null or player.frozen or _changing:
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		var pos: Vector2 = (event as InputEventScreenTouch).position
		if pos.y >= TouchControls.TOP_OF_CONTROLS and TouchControls.visible_controls:
			return
		if pos.y < Hud.TOOLBAR_BOTTOM:
			return
		handle_tap(pos)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not DisplayServer.is_touchscreen_available():
		# Desktop: left click uses the tool toward the cursor, right click checks/talks.
		var mb := event as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] and mb.position.y >= Hud.TOOLBAR_BOTTOM:
			var world := get_canvas_transform().affine_inverse() * mb.position
			player.face_toward(world)
			player.do_action("tool" if mb.button_index == MOUSE_BUTTON_LEFT else "action")
			get_viewport().set_input_as_handled()


## Stardew-mobile tap: walk there, or walk up to the thing and use it.
func handle_tap(pos: Vector2) -> void:
	if get_tree().paused or player == null or player.frozen or _changing:
		return
	var world := get_canvas_transform().affine_inverse() * pos
	var c := world_to_cell(world)
	var e := nearest_enemy_to(world, 14.0)
	if true:
		if e:
			player.go_to_cell(world_to_cell(e.position - Vector2(0, 2)), true)
		elif has_npc_at(c):
			player.go_to_cell(c, true)
		elif things.has(c) and (hint_for(c, things[c]) != "" or things[c].get("type") == "plot"):
			player.go_to_cell(c, true)
		elif not blocked.has(c):
			player.go_to_cell(c, false)


func has_npc_at(_c: Vector2i) -> bool:
	return false


# ---- time --------------------------------------------------------------------

func _process(delta: float) -> void:
	if hitstop > 0.0:
		hitstop -= delta
	if get_tree().paused:
		return
	_time_acc += delta * GameState.MINUTES_PER_SECOND
	if _time_acc >= 1.0:
		var m := int(_time_acc)
		_time_acc -= m
		GameState.run["time"] = int(GameState.run["time"]) + m
	var t := int(GameState.run["time"])
	if t >= GameState.DAY_END and not _changing:
		hud.toast("It's 2am. You pass out.", Color(1, 0.7, 0.7))
		player_down()
	# Evening tint from 6pm, darkest by midnight.
	var dark := clampf((t - 18 * 60) / 360.0, 0.0, 1.0)
	_night.color = Color(1, 1, 1).lerp(Color(0.45, 0.5, 0.8), dark * 0.6)
	if player and hud:
		var fc := player.facing_cell()
		hud.set_hint(hint_for(fc, things.get(fc, {})))
	if pet:
		_follow_pet(delta)
	update_enemies(delta)
	check_exits()


func update_enemies(_delta: float) -> void:
	pass


func _follow_pet(delta: float) -> void:
	if _pet_busy:
		return
	var to := player.position - pet.position
	var dist := to.length()
	if dist > 22.0:
		var step := to.normalized() * minf(dist * 4.0, 95.0) * delta
		pet.position += step
		var running := dist > (34.0 if _pet_anim.animation.begins_with("run") else 48.0)
		var a: String
		if absf(to.x) >= absf(to.y):
			a = "run" if running else "walk"
			_pet_anim.flip_h = to.x < 0
		else:
			var vert := ("run_" if running else "walk_") + ("up" if to.y < 0 else "down")
			a = vert if _pet_anim.sprite_frames.has_animation(vert) else ("run" if running else "walk")
			_pet_anim.flip_h = false
		if _pet_anim.animation != a:
			_pet_anim.play(a)
		_pet_idle = 0.0
	else:
		_pet_idle += delta
		var want := "idle"
		if _pet_idle > 3.0 and _pet_anim.sprite_frames.has_animation("sit"):
			want = "sit"
		if _pet_anim.animation != want and _pet_anim.animation != "dig":
			_pet_anim.play(want)
		if _pet_idle > 14.0:
			_pet_idle = randf_range(-6.0, 0.0)
			_pet_dig()


func _pet_dig() -> void:
	_pet_busy = true
	_pet_anim.play("dig" if _pet_anim.sprite_frames.has_animation("dig") else "play")
	await get_tree().create_timer(1.6).timeout
	if not is_instance_valid(_pet_anim):
		return
	_pet_busy = false
	_pet_anim.play("idle")
	if randf() < 0.5:
		var found: String = ["fiber", "berry", "stone", "mushroom"][randi() % 4]
		GameState.add_item(found)
		hud.toast("%s dug up a %s!" % [GameState.names()["pet"], GameState.item_name(found)], Color(0.8, 1, 0.8))


# ---- transitions -------------------------------------------------------------

func go_to(scene: String, spawn: Vector2, facing := "down") -> void:
	if _changing and not player.frozen:
		return
	_changing = true
	player.frozen = true
	next_spawn = spawn
	next_facing = facing
	GameState.save()
	await hud.fade_out(0.35)
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % scene)


func say(lines: Array) -> void:
	var d := Dialogue.instance(get_tree())
	d.say(lines)
	await d.finished


func give(id: String, n := 1) -> void:
	_check_quests.call_deferred()
	GameState.add_item(id, n)
	hud.toast("+%d %s" % [n, GameState.item_name(id)], Color(0.85, 1, 0.85))
	Music.instance(get_tree()).sfx("pickup")
	if player:
		fx("sparkle", player.position + Vector2(0, -14), 14.0, 0.5)


func xp(skill: String, n: int) -> void:
	if GameState.add_xp(skill, n):
		hud.toast("%s level %d!" % [skill.capitalize(), GameState.skill_level(skill)], Color(1, 0.9, 0.4))
		Music.instance(get_tree()).sfx("levelup")
		if player:
			fx("levelup", player.position + Vector2(0, -4), 10.0, 0.6)


# ---- shared drawing helpers --------------------------------------------------

## Grass everywhere with scattered decoration tiles (seeded so it's stable).
func _draw() -> void:
	draw_set_transform(offset())
	draw_map()
	if not _ext_paths.is_empty():
		draw_ground("dirt", _ext_paths)
		draw_exits()
	if pad > 0:
		draw_border()
	draw_set_transform(Vector2.ZERO)


## Subclasses draw their ground here (content coordinates; the pad offset is applied).
func draw_map() -> void:
	pass


func draw_grass(seed_v := 1, r := Rect2i(0, 0, 0, 0)) -> void:
	if r.size == Vector2i.ZERO:
		r = Rect2i(-pad, -pad, cols + 2 * pad, rows + 2 * pad)
	_deco_rng.seed = seed_v
	var gname := GameState.grass_tile()
	var has_tiles := Art.has("tiles", gname)
	var season := GameState.season()
	# Natural variation: patches of tall / flowery / dry grass from low-frequency noise.
	var patchy := season in ["spring", "summer"] and Art.has("tiles", "g_tall") and Art.has("tiles", "g_dry")
	var sd := hash(scene_id()) % 1000 + seed_v
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var at := Vector2(x * TILE, y * TILE)
			if has_tiles:
				var tname := gname
				if patchy:
					var n := WorldGen.fbm(float(x), float(y), sd, 11.0)
					if n > 0.32:
						tname = "g_tall"
					elif n < -0.38:
						tname = "g_dry" if season == "summer" else "g_flower"
				Art.draw_tile(self, "tiles", tname, at, 4)
				if season == "spring" and _deco_rng.randf() < 0.07:
					Art.draw_tile(self, "tiles", "deco_%d" % _deco_rng.randi_range(0, 5), at)
			else:
				draw_rect(Rect2(at, Vector2(TILE, TILE)), Color("5a9e4b") if (x + y) % 2 == 0 else Color("67ab55"))


## Ground region with real grass transitions (W1 sets) when available.
## kind: "dirt" | "sand" | "stone". Falls back to draw_tileset_rect.
func draw_ground(kind: String, cells: Dictionary) -> void:
	var tset := "t_" + kind
	var fill: String = {"dirt": "dirt", "sand": "sand", "stone": "g_gravel"}.get(kind, "dirt")
	if Art.has("tiles", tset):
		Art.draw_autotile(self, cells, "@", tset, Art.T_GROUND_IDX)
		if kind == "dirt" and Art.has("tiles", "pdeco_pebbles"):
			for c: Vector2i in cells:
				var h := (c.x * 73856093) ^ (c.y * 19349663) ^ hash(scene_id())
				if h % 23 == 0:
					Art.draw_tile(self, "tiles", ["pdeco_pebbles", "pdeco_puddle", "pdeco_hoofprints", "pdeco_ruts", "pdeco_roots"][absi(h / 23) % 5], Vector2(c * TILE))
		return
	for c: Vector2i in cells:
		if not Art.draw_tile(self, "tiles", fill, Vector2(c * TILE), 4):
			draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color("b8945a"))


func cells_of(rects: Array) -> Dictionary:
	var d := {}
	for r: Rect2i in rects:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				d[Vector2i(x, y)] = true
	return d


## Water body with proper shore edges (grass or sand outside) and animated fill.
func draw_water(cells: Dictionary, shore := "grass") -> void:
	# Animated fill, then a procedural bank that always lines up: a dark earth
	# lip on the land side, a lighter wet rim and foam inside the water. Corners
	# are rounded with quarter discs so blobs read as real shorelines.
	var frame := int(Time.get_ticks_msec() / 250) % 4
	var fill := "water2" if Art.has("tiles", "water2") else "water"
	for c: Vector2i in cells:
		if not Art.draw_tile(self, "tiles", fill, Vector2(c * TILE), frame):
			draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color("2f6fb5"))
	var earth := Color("6b4a2b") if shore == "grass" else Color("c9a86b")
	var rim := Color("4f8fd0", 0.9)
	var foam := Color(0.85, 0.95, 1.0, 0.55 + 0.2 * sin(Time.get_ticks_msec() / 400.0))
	for c: Vector2i in cells:
		var r := Rect2(c * TILE, Vector2i(TILE, TILE))
		var n := cells.has(c + Vector2i(0, -1))
		var so := cells.has(c + Vector2i(0, 1))
		var w := cells.has(c + Vector2i(-1, 0))
		var e := cells.has(c + Vector2i(1, 0))
		if not n:
			draw_rect(Rect2(r.position, Vector2(TILE, 3)), earth)
			draw_rect(Rect2(r.position + Vector2(0, 3), Vector2(TILE, 2)), rim)
			draw_rect(Rect2(r.position + Vector2(0, 5), Vector2(TILE, 1)), foam)
		if not so:
			draw_rect(Rect2(r.position + Vector2(0, TILE - 2), Vector2(TILE, 2)), earth)
			draw_rect(Rect2(r.position + Vector2(0, TILE - 4), Vector2(TILE, 2)), rim)
			draw_rect(Rect2(r.position + Vector2(0, TILE - 5), Vector2(TILE, 1)), foam)
		if not w:
			draw_rect(Rect2(r.position, Vector2(2, TILE)), earth)
			draw_rect(Rect2(r.position + Vector2(2, 0), Vector2(2, TILE)), rim)
			draw_rect(Rect2(r.position + Vector2(4, 0), Vector2(1, TILE)), foam)
		if not e:
			draw_rect(Rect2(r.position + Vector2(TILE - 2, 0), Vector2(2, TILE)), earth)
			draw_rect(Rect2(r.position + Vector2(TILE - 4, 0), Vector2(2, TILE)), rim)
			draw_rect(Rect2(r.position + Vector2(TILE - 5, 0), Vector2(1, TILE)), foam)
		# Outer corners: round them off with a land disc.
		var land := Color(str(GameState.run.get("_land", "")), 1.0) if false else (Color("5a9e4b") if shore == "grass" else Color("e2cf96"))
		if Art.has("tiles", GameState.grass_tile()) and shore == "grass":
			land = Color("55a04a")
		for corner: Array in [[not n and not w, Vector2(0, 0)], [not n and not e, Vector2(TILE, 0)], [not so and not w, Vector2(0, TILE)], [not so and not e, Vector2(TILE, TILE)]]:
			if corner[0]:
				var cp: Vector2 = r.position + corner[1]
				draw_circle(cp, 6.0, land)
				draw_arc(cp, 5.0, 0, TAU, 12, earth, 2.5)
				draw_arc(cp, 7.5, 0, TAU, 12, rim, 1.5)
		# Inner corners: a dab of earth where two banks meet diagonally.
		for corner: Array in [[n and w and not cells.has(c + Vector2i(-1, -1)), Vector2(0, 0)], [n and e and not cells.has(c + Vector2i(1, -1)), Vector2(TILE, 0)], [so and w and not cells.has(c + Vector2i(-1, 1)), Vector2(0, TILE)], [so and e and not cells.has(c + Vector2i(1, 1)), Vector2(TILE, TILE)]]:
			if corner[0]:
				var cp: Vector2 = r.position + corner[1]
				draw_circle(cp, 3.0, earth)
				draw_circle(cp, 1.5, rim)


## A rectangle of a 3x3 tile set (dirt, stone, dock...) with proper edges.
func draw_tileset_rect(name: String, r: Rect2i, fallback: Color) -> void:
	if not Art.has("tiles", name):
		draw_rect(Rect2(r.position * TILE, r.size * TILE), fallback)
		return
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var ix := 1
			var iy := 1
			if r.size.x > 1:
				ix = 0 if x == r.position.x else (2 if x == r.end.x - 1 else 1)
			if r.size.y > 1:
				iy = 0 if y == r.position.y else (2 if y == r.end.y - 1 else 1)
			Art.draw_tile(self, "tiles", name, Vector2(x * TILE, y * TILE), iy * 3 + ix)


func draw_fence_border(col := Color("6b4a2b")) -> void:
	if Art.has("buildings", "fence_h"):
		for x in cols:
			Art.draw_prop(self, "buildings", "fence_h", Vector2(x * TILE + TILE / 2.0, TILE))
			Art.draw_prop(self, "buildings", "fence_h", Vector2(x * TILE + TILE / 2.0, rows * TILE))
		for y in range(1, rows - 1):
			Art.draw_prop(self, "buildings", "fence_v", Vector2(TILE / 2.0, (y + 1) * TILE))
			Art.draw_prop(self, "buildings", "fence_v", Vector2((cols - 0.5) * TILE, (y + 1) * TILE))
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(cols * TILE, TILE)), col)
	draw_rect(Rect2(0, (rows - 1) * TILE, cols * TILE, TILE), col)
	draw_rect(Rect2(Vector2.ZERO, Vector2(TILE, rows * TILE)), col)
	draw_rect(Rect2((cols - 1) * TILE, 0, TILE, rows * TILE), col)


func draw_tree(p: Vector2) -> void:
	draw_rect(Rect2(p.x - 2, p.y - 4, 4, 6), Color("5a3a1a"))
	draw_circle(Vector2(p.x, p.y - 10), 8.0, Color("2f7a3a"))
	draw_circle(Vector2(p.x - 3, p.y - 13), 5.0, Color("3f9a48"))


func draw_building(x: int, y: int, w: int, h: int, wall: Color, roof: Color, label_text: String) -> void:
	draw_rect(Rect2(x * TILE, (y + 1) * TILE, w * TILE, (h - 1) * TILE), wall)
	draw_rect(Rect2(x * TILE - 4, y * TILE, w * TILE + 8, TILE * 1.5), roof)
	var dx := (x + w / 2.0) * TILE - TILE / 2.0
	draw_rect(Rect2(dx, (y + h - 1) * TILE, TILE, TILE), Color("3a2412"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(x * TILE, (y + 1.3) * TILE), label_text, HORIZONTAL_ALIGNMENT_CENTER, w * TILE, 7, Color(1, 1, 0.85))


func label(text: String, at: Vector2, w := 64.0) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, w, 7, Color(1, 1, 0.85))


## Raised ground with a real cliff face under its southern edge (W28/W29 sets).
## `cells` are the walkable top cells; the row below the southern edge is the face
## (block it yourself, except `stairs` cells). prefix: "cliffg" (grass) or "cliffs" (stone).
func draw_plateau(cells: Dictionary, prefix := "cliffg", stairs: Dictionary = {}) -> void:
	var tset := "t_" + prefix
	if not Art.has("tiles", tset):
		for c: Vector2i in cells:
			draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color("6a6a74"))
		return
	# The sets are drawn as raised blocks: plain grass inside, a rock lip on the
	# side that faces open ground. Pick the tile from which neighbours are missing.
	var I := Art.T_CLIFF_IDX
	for c: Vector2i in cells:
		var n := cells.has(c + Vector2i(0, -1))
		var so := cells.has(c + Vector2i(0, 1))
		var w := cells.has(c + Vector2i(-1, 0))
		var e := cells.has(c + Vector2i(1, 0))
		var key := "mid"
		if not so:
			key = "bl" if not w else ("br" if not e else "bottom")
		elif not n:
			key = "tl" if not w else ("tr" if not e else "top")
		elif not w:
			key = "left"
		elif not e:
			key = "right"
		Art.draw_tile(self, "tiles", tset, Vector2(c * TILE), int(I[key]))
	if prefix != "cliffg":
		return
	var faces := []
	for c: Vector2i in cells:
		if not cells.has(c + Vector2i(0, 1)):
			faces.append(c)
	faces.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for c: Vector2i in faces:
		var below := c + Vector2i(0, 1)
		var has_l := cells.has(c + Vector2i(-1, 0)) and not cells.has(c + Vector2i(-1, 1))
		var has_r := cells.has(c + Vector2i(1, 0)) and not cells.has(c + Vector2i(1, 1))
		var nm := ""
		if stairs.has(below):
			var sl := stairs.has(below + Vector2i(-1, 0))
			var sr := stairs.has(below + Vector2i(1, 0))
			nm = "stairs_m" if (sl and sr) or (not sl and not sr) else ("stairs_r" if sl else "stairs_l")
		elif has_l and has_r:
			nm = ["face_a", "face_b", "face_c"][(c.x * 7 + c.y) % 3]
		elif not has_l and not has_r:
			nm = "fcorner_l"
		else:
			nm = "face_l" if not has_l else "face_r"
		var t := Art.tex("tiles", prefix + "_" + nm)
		if t:
			draw_texture_rect(t, Rect2(below.x * TILE, c.y * TILE + TILE * 0.5, TILE, TILE * 1.5), false)


## A mass of raised rock (map edges, mountain walls): stone fill with a grassy
## lip facing the open ground and painted cliff faces on the sides that face south.
func draw_rock_mass(cells: Dictionary) -> void:
	var fill := "mf_stone" if Art.has("tiles", "mf_stone") else "g_gravel"
	for c: Vector2i in cells:
		if not Art.draw_tile(self, "tiles", fill, Vector2(c * TILE), 4):
			draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color("6a6a74"))
		# subtle variation
		if (c.x * 31 + c.y * 17) % 5 == 0:
			draw_rect(Rect2(c * TILE + Vector2i(3, 4), Vector2i(6, 3)), Color(1, 1, 1, 0.08))
	var dark := Color("2e2a33")
	var grass := Color("55a04a")
	for c: Vector2i in cells:
		var r := Rect2(c * TILE, Vector2i(TILE, TILE))
		var n := cells.has(c + Vector2i(0, -1))
		var so := cells.has(c + Vector2i(0, 1))
		var w := cells.has(c + Vector2i(-1, 0))
		var e := cells.has(c + Vector2i(1, 0))
		if not so:
			# Face toward the player: painted face tile over the row below.
			var face := Art.tex("tiles", "cliffg_" + ["face_a", "face_b", "face_c"][(c.x * 7 + c.y) % 3])
			if face:
				draw_texture_rect(face, Rect2(r.position + Vector2(0, TILE * 0.4), Vector2(TILE, TILE * 1.6)), false)
			else:
				draw_rect(Rect2(r.position + Vector2(0, TILE - 4), Vector2(TILE, 4)), dark)
		if not n:
			draw_rect(Rect2(r.position, Vector2(TILE, 3)), grass)
			draw_rect(Rect2(r.position + Vector2(0, 3), Vector2(TILE, 1)), dark)
		if not w:
			draw_rect(Rect2(r.position, Vector2(3, TILE)), grass)
			draw_rect(Rect2(r.position + Vector2(3, 0), Vector2(1, TILE)), dark)
		if not e:
			draw_rect(Rect2(r.position + Vector2(TILE - 3, 0), Vector2(3, TILE)), grass)
			draw_rect(Rect2(r.position + Vector2(TILE - 4, 0), Vector2(1, TILE)), dark)
		for corner: Array in [[not n and not w, Vector2(0, 0)], [not n and not e, Vector2(TILE, 0)]]:
			if corner[0]:
				draw_circle(r.position + corner[1], 4.0, grass)
	# A few boulders on top for texture.
	for c: Vector2i in cells:
		if (c.x * 7 + c.y * 13) % 11 == 0 and cells.has(c + Vector2i(0, 1)) and cells.has(c + Vector2i(0, -1)):
			Art.draw_prop(self, "props" if Art.has("props", "boulder2_s_a") else "nature", "boulder2_s_a" if Art.has("props", "boulder2_s_a") else "rock_s", Vector2(c * TILE) + Vector2(8, 15))


# ---- organic borders ---------------------------------------------------------

func border_kind(side: String) -> String:
	if border is Dictionary:
		return str((border as Dictionary).get(side, "trees"))
	return str(border)


## Which side of the content a pad cell belongs to (nearest edge).
func _side_of(c: Vector2i) -> String:
	var dn := -c.y
	var ds := c.y - (rows - 1)
	var dw := -c.x
	var de := c.x - (cols - 1)
	var m := maxi(maxi(dn, ds), maxi(dw, de))
	if m == dn: return "n"
	if m == ds: return "s"
	if m == dw: return "w"
	return "e"


func _build_border() -> void:
	_border_rng.seed = hash(scene_id()) % 100000
	var sd := hash(scene_id()) % 10000
	# Exit corridors: cells in line with an exit stay open through the band.
	var open := {}
	for e in exits:
		var r: Rect2i = e["rect"]
		var g := r.grow(1)
		for y in range(-pad, rows + pad):
			for x in range(-pad, cols + pad):
				var c := Vector2i(x, y)
				if (r.position.y <= 0 and c.y < r.end.y and c.x >= g.position.x and c.x < g.end.x) \
				or (r.end.y >= rows and c.y >= r.position.y and c.x >= g.position.x and c.x < g.end.x) \
				or (r.position.x <= 0 and c.x < r.end.x and c.y >= g.position.y and c.y < g.end.y) \
				or (r.end.x >= cols and c.x >= r.position.x and c.y >= g.position.y and c.y < g.end.y):
					open[c] = true
	_border_open = open
	# Meandering edge: the band's inner edge is content-edge + noise, so it wanders
	# in and out by a few cells (and eats into the content where nothing stands).
	var amp := float(pad) * 0.55
	for y in range(-pad, rows + pad):
		for x in range(-pad, cols + pad):
			var c := Vector2i(x, y)
			if open.has(c):
				continue
			# Signed distance to the content rectangle, rounded at the corners.
			var dx := maxf(-c.x, c.x - (cols - 1))
			var dy := maxf(-c.y, c.y - (rows - 1))
			var depth := 0.0
			if dx > 0 and dy > 0:
				depth = sqrt(dx * dx + dy * dy)
			else:
				depth = maxf(dx, dy)
			var side := _side_of(c)
			var kind := border_kind(side)
			var n := WorldGen.fbm(float(c.x), float(c.y), sd, 9.0) * amp
			# depth > 0 is outside the content; the band starts where depth + n > 1.
			var filled := depth + n > 1.2
			if depth >= pad - 1:
				filled = true
			if kind == "none":
				filled = depth >= pad - 1
			if not filled:
				continue
			if in_content(c) and (things.has(c) or props.has(c)):
				continue
			if in_content(c) and _near_exit(c, 3):
				continue
			if in_content(c) and depth + n < 2.0 and (c.x + c.y) % 3 == 0:
				continue  # ragged inner edge
			blocked[c] = true
			match kind:
				"trees": _border_cells[c] = "tree"
				"cliff": _border_cells[c] = "cliff"
				"water": _border_cells[c] = "water"
				_: _border_cells[c] = "void"
	# Trees: sparse at the inner edge, dense and large deeper in.
	var rng := _border_rng
	for c: Vector2i in _border_cells:
		if _border_cells[c] != "tree":
			continue
		var depth := _band_depth(c)
		var chance := 0.35 if depth <= 1 else (0.6 if depth == 2 else 0.8)
		if rng.randf() > chance:
			continue
		var nm := GameState.tree_sprite(rng.randi_range(0, 2))
		if Art.has("nature", "big_oak_a"):
			var season := GameState.season()
			var mids: Array = {"spring": ["mid_oak", "mid_pine", "mid_birch", "mid_cherry", "mid_oak_b"], "summer": ["mid_oak", "mid_pine", "mid_birch", "mid_willow", "mid_oak_b"], "fall": ["mid_maple", "mid_oak", "mid_pine", "mid_maple_b", "mid_dead"], "winter": ["mid_snowpine", "mid_dead", "mid_snowpine_b", "mid_pine", "mid_dead_b"]}.get(season, ["mid_oak", "mid_pine"])
			var bigs: Array = {"spring": ["big_oak_a", "big_oak_b", "big_pine_a", "big_birch_a", "big_cherry_a", "big_oak_c"], "summer": ["big_oak_a", "big_oak_b", "big_pine_b", "big_birch_b", "big_willow", "big_oak_c"], "fall": ["big_maple_a", "big_maple_b", "big_oak_a", "big_pine_a", "big_dead_a"], "winter": ["big_snowpine_a", "big_snowpine_b", "big_dead_a", "big_dead_b", "big_pine_c"]}.get(season, ["big_oak_a"])
			nm = str(mids[rng.randi_range(0, mids.size() - 1)]) if depth <= 2 or rng.randf() < 0.4 else str(bigs[rng.randi_range(0, bigs.size() - 1)])
		if depth <= 1 and in_content(c + Vector2i(0, 1)) and not _border_cells.has(c + Vector2i(0, 1)):
			prop("nature", nm, c, 0, 0.0, false)  # inner-edge trees are props so you walk behind the canopy
		else:
			_border_draw.append([c, "nature", nm, rng.randf_range(-3.0, 3.0)])
	_border_draw.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2i).y < (b[0] as Vector2i).y)


func _near_exit(c: Vector2i, d: int) -> bool:
	for e in exits:
		if (e["rect"] as Rect2i).grow(d).has_point(c):
			return true
	var sp := world_to_cell((next_spawn + offset()) if next_spawn != Vector2.ZERO else default_spawn())
	return absi(sp.x - c.x) <= d and absi(sp.y - c.y) <= d


## If the player stands inside something solid (after a map change), slide to the nearest open cell.
func unstick_player() -> void:
	if player == null:
		return
	var feet := Rect2(player.position + Player.FEET.position, Player.FEET.size)
	if not rect_blocked(feet):
		return
	var start := world_to_cell(player.position - Vector2(0, 2))
	for rad in range(1, 8):
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				var c := start + Vector2i(dx, dy)
				if not in_content(c) or blocked.has(c):
					continue
				player.position = cell_center(c)
				return


## How deep a band cell sits (1 = touching open ground).
func _band_depth(c: Vector2i) -> int:
	for d in range(1, pad + 3):
		for off: Vector2i in [Vector2i(d, 0), Vector2i(-d, 0), Vector2i(0, d), Vector2i(0, -d)]:
			var n := c + off
			if not _border_cells.has(n) and not blocked.has(n):
				return d
	return pad + 2


func draw_border() -> void:
	var water := {}
	var cliff := {}
	var treec := {}
	for c: Vector2i in _border_cells:
		match _border_cells[c]:
			"water": water[c] = true
			"cliff": cliff[c] = true
			"tree": treec[c] = true
			"void": draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color(0.05, 0.05, 0.08))
	# Exit corridors through the band are dirt track.
	if not _border_open.is_empty():
		var corridor := {}
		for c: Vector2i in _border_open:
			if not blocked.has(c):
				corridor[c] = true
		draw_ground("dirt", corridor)
	if not water.is_empty():
		draw_water(water, "sand" if Art.has("tiles", "t_water_sand") and GameState.run["scene"] == "beach" else "grass")
	if not cliff.is_empty():
		draw_rock_mass(cliff)
	# Forest floor only under the deep part of the tree mass, with a soft edge.
	for c: Vector2i in treec:
		if _band_depth(c) >= 3 or ((c.x * 5 + c.y * 3) % 4 == 0 and _band_depth(c) == 2):
			if not Art.draw_tile(self, "tiles", "forest_floor", Vector2(c * TILE), 4):
				draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color(0.2, 0.35, 0.18, 0.6))
	for item: Array in _border_draw:
		var c: Vector2i = item[0]
		Art.draw_prop(self, str(item[1]), str(item[2]), Vector2(c * TILE) + Vector2(TILE / 2.0 + float(item[3]), TILE))

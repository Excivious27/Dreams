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
		if Art.has("animals/dog_golden", "idle"):
			_pet_anim = AnimatedSprite2D.new()
			_pet_anim.sprite_frames = Art.frames("animals/dog_golden", {"idle": "idle", "walk": "walk", "run": "run", "sit": "sit", "sleep": "sleep", "dig": "dig", "bark": "bark"}, {"idle": 4.0, "walk": 8.0, "run": 10.0, "sit": 2.0, "sleep": 1.5, "dig": 8.0, "bark": 6.0})
			_pet_anim.scale = Vector2(0.5, 0.5)
			_pet_anim.offset = Vector2(0, -float(Art.info("animals/dog_golden", "idle").get("cell_h", 32)) / 2.0 + 2.0)
			_pet_anim.animation = "idle"
		else:
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
			player.play_tool("axe" if GameState.held_tool() == "axe" else "hoe")
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
			if not GameState.has_tool("axe"):
				return false
			if not GameState.spend_energy(2):
				hud.toast("Too tired.", Color(1, 0.7, 0.7))
				return true
			player.play_tool("axe")
			Music.instance(get_tree()).sfx("chop")
			wobble(c, 0.08 if str(thing["type"]) == "tree" else 0.03)
			fx("wood_chips", cell_center(c) + Vector2(0, -10), 16.0, 0.5)
			thing["hp"] = int(thing.get("hp", 3)) - 1
			if int(thing["hp"]) <= 0:
				var is_tree := str(thing["type"]) == "tree"
				xp("foraging", 3)
				if is_tree and not bool(thing.get("fell", false)):
					thing["hp"] = 3
					pop_items(cell_center(c), "wood", 3)
				elif is_tree:
					_mark_cleared(c)
					fell_tree(c, 6)
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
			if not GameState.has_tool("pickaxe"):
				return false
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
				break_rock(c, 2, "copper", 1 if randf() < 0.25 else 0, "m" if big else "")
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
			give(item)
			xp("foraging", 2)
			if props.has(c):
				(props[c] as Sprite2D).queue_free()
				props.erase(c)
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
		draw_tileset_rect("dirt", r, Color("b8945a"))
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
		for i in extra_w + 1:
			blocked[Vector2i(c.x + i, c.y)] = true
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
			var crit := randf() < 0.05 * GameState.skill_level("combat")
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
	xp("combat", 2 if e.kind != "big_grump" else 20)
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
		var running := dist > 40.0
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
		r = Rect2i(0, 0, cols, rows)
	_deco_rng.seed = seed_v
	var gname := GameState.grass_tile()
	var has_tiles := Art.has("tiles", gname)
	var season := GameState.season()
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var at := Vector2(x * TILE, y * TILE)
			if has_tiles:
				Art.draw_tile(self, "tiles", gname, at, 4)
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
	var tset := "t_water_" + shore
	var frame := int(Time.get_ticks_msec() / 250) % 4
	var fill := "water2" if Art.has("tiles", "water2") else "water"
	if Art.has("tiles", tset):
		# fill first (animated), then edges on top
		for c: Vector2i in cells:
			Art.draw_tile(self, "tiles", fill, Vector2(c * TILE), frame)
		Art.draw_autotile(self, cells, "", tset, Art.T_WATER_IDX)
		return
	for c: Vector2i in cells:
		if not Art.draw_tile(self, "tiles", "water", Vector2(c * TILE), frame):
			draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color("2f6fb5"))


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
	var rng := _border_rng
	# Exit corridors: cells in line with an exit stay open through the pad.
	var open := {}
	for e in exits:
		var r: Rect2i = e["rect"]
		var g := r.grow(1)
		for y in range(-pad, rows + pad):
			for x in range(-pad, cols + pad):
				var c := Vector2i(x, y)
				if in_content(c):
					continue
				if (r.position.y <= 0 and c.y < 0 and c.x >= g.position.x and c.x < g.end.x) \
				or (r.end.y >= rows and c.y >= rows and c.x >= g.position.x and c.x < g.end.x) \
				or (r.position.x <= 0 and c.x < 0 and c.y >= g.position.y and c.y < g.end.y) \
				or (r.end.x >= cols and c.x >= cols and c.y >= g.position.y and c.y < g.end.y):
					open[c] = true
	_border_open = open
	# Jagged inner edge: per column/row, how far the band reaches in (0..2 cells short of full).
	var reach := {}
	for x in range(-pad, cols + pad):
		reach["n%d" % x] = rng.randi_range(0, 2)
		reach["s%d" % x] = rng.randi_range(0, 2)
	for y in range(-pad, rows + pad):
		reach["w%d" % y] = rng.randi_range(0, 2)
		reach["e%d" % y] = rng.randi_range(0, 2)
	for y in range(-pad, rows + pad):
		for x in range(-pad, cols + pad):
			var c := Vector2i(x, y)
			if in_content(c):
				continue
			var side := _side_of(c)
			var depth := 0  # distance from the content edge, 1 = touching it
			match side:
				"n": depth = -c.y
				"s": depth = c.y - (rows - 1)
				"w": depth = -c.x
				"e": depth = c.x - (cols - 1)
			var kind := border_kind(side)
			var short: int = reach.get(side + str(c.x if side in ["n", "s"] else c.y), 0)
			var filled := depth > short or depth >= pad
			if open.has(c):
				filled = false
			if kind == "none":
				filled = depth >= pad
			if not filled:
				continue
			blocked[c] = true
			match kind:
				"trees":
					_border_cells[c] = "tree"
				"cliff":
					_border_cells[c] = "cliff"
				"water":
					_border_cells[c] = "water"
				_:
					_border_cells[c] = "void"
	# Tree placement: every other cell, with jitter, bigger trees deeper in.
	for c: Vector2i in _border_cells:
		if _border_cells[c] != "tree":
			continue
		var side := _side_of(c)
		var depth := absi(c.y) if side == "n" else (c.y - rows + 1 if side == "s" else (absi(c.x) if side == "w" else c.x - cols + 1))
		if (c.x + c.y) % 2 != 0 and rng.randf() < 0.55:
			continue
		var nm := GameState.tree_sprite(rng.randi_range(0, 2))
		if Art.has("nature", "big_oak_a"):
			var season := GameState.season()
			var mids: Array = {"spring": ["mid_oak", "mid_pine", "mid_birch", "mid_cherry", "mid_oak_b"], "summer": ["mid_oak", "mid_pine", "mid_birch", "mid_willow", "mid_oak_b"], "fall": ["mid_maple", "mid_oak", "mid_pine", "mid_maple_b", "mid_dead"], "winter": ["mid_snowpine", "mid_dead", "mid_snowpine_b", "mid_pine", "mid_dead_b"]}.get(season, ["mid_oak", "mid_pine"])
			var bigs: Array = {"spring": ["big_oak_a", "big_oak_b", "big_pine_a", "big_birch_a", "big_cherry_a", "big_oak_c"], "summer": ["big_oak_a", "big_oak_b", "big_pine_b", "big_birch_b", "big_willow", "big_oak_c"], "fall": ["big_maple_a", "big_maple_b", "big_oak_a", "big_pine_a", "big_dead_a"], "winter": ["big_snowpine_a", "big_snowpine_b", "big_dead_a", "big_dead_b", "big_pine_c"]}.get(season, ["big_oak_a"])
			nm = str(mids[rng.randi_range(0, mids.size() - 1)]) if depth <= 1 or rng.randf() < 0.45 else str(bigs[rng.randi_range(0, bigs.size() - 1)])
			if nm.begins_with("big_") and (c.x + c.y) % 2 == 1:
				continue
		elif depth >= 2 and rng.randf() < 0.25 and Art.has("nature", "big_pine"):
			nm = "big_oak" if rng.randf() < 0.5 and Art.has("nature", "big_oak") else "big_pine"
		if depth == 1 and side == "s":
			# Innermost southern row as real props so canopies overlap the player.
			prop("nature", nm, c, 0, 0.0, false)
		else:
			_border_draw.append([c, "nature", nm])
	_border_draw.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2i).y < (b[0] as Vector2i).y)


func draw_border() -> void:
	# Ground under the band, then the band itself.
	var full := Rect2i(-pad, -pad, cols + 2 * pad, rows + 2 * pad)
	var kinds := {}
	for side in ["n", "s", "e", "w"]:
		kinds[border_kind(side)] = true
	if true:
		draw_grass(7, Rect2i(-pad, -pad, cols + 2 * pad, pad))
		draw_grass(8, Rect2i(-pad, rows, cols + 2 * pad, pad))
		draw_grass(9, Rect2i(-pad, 0, pad, rows))
		draw_grass(10, Rect2i(cols, 0, pad, rows))
	var water := {}
	var cliff := {}
	for c: Vector2i in _border_cells:
		match _border_cells[c]:
			"water": water[c] = true
			"cliff": cliff[c] = true
			"void": draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color(0.05, 0.05, 0.08))
	# Exit corridors through the band are dirt track.
	if not _border_open.is_empty():
		var corridor := {}
		for c: Vector2i in _border_open:
			if not blocked.has(c):
				corridor[c] = true
		draw_ground("dirt", corridor)
	if not water.is_empty():
		draw_water(water, "sand" if Art.has("tiles", "t_water_sand") and border_kind("s") == "water" and GameState.run["scene"] == "beach" else "grass")
	if not cliff.is_empty():
		if Art.has("tiles", "t_cliffs"):
			draw_plateau(cliff, "cliffs")
			# Faces toward the content along the north band's inner edge.
			for c: Vector2i in cliff:
				var below := c + Vector2i(0, 1)
				if not cliff.has(below) and in_content(below) and Art.has("tiles", "cliffs_ledge_0"):
					var t := Art.tex("tiles", "cliffs_ledge_%d" % ((c.x * 3) % 4))
					if t:
						draw_texture_rect(t, Rect2(c.x * TILE, c.y * TILE, TILE, TILE), false)
		else:
			for c: Vector2i in cliff:
				if not Art.draw_tile(self, "tiles", "pale_stone" if Art.has("tiles", "pale_stone") else "g_gravel", Vector2(c * TILE), 4):
					draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color("6a6a74"))
		for c: Vector2i in cliff:
			if (c.x * 7 + c.y * 13) % 7 == 0:
				Art.draw_prop(self, "props" if Art.has("props", "boulder2_m_a") else "nature", "boulder2_m_a" if Art.has("props", "boulder2_m_a") else "rock_m", Vector2(c * TILE) + Vector2(8, 16))
	# Dark forest floor under the tree band.
	for c: Vector2i in _border_cells:
		if _border_cells[c] == "tree":
			if not Art.draw_tile(self, "tiles", "forest_floor", Vector2(c * TILE), 4):
				draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color(0.2, 0.35, 0.18, 0.6))
	for item: Array in _border_draw:
		var c: Vector2i = item[0]
		Art.draw_prop(self, str(item[1]), str(item[2]), Vector2(c * TILE) + Vector2(TILE / 2.0, TILE))

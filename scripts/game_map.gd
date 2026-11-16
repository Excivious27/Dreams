class_name GameMap
extends Node2D
## Base for every playable area. Owns the grid (size, blocked cells, things you
## can interact with), the player, the pet, camera, HUD, touch controls, sky, the
## clock, tap-to-move, and scene transitions. Subclasses draw the ground and
## place props. Children are y-sorted so the player walks behind tall things.

const TILE := 16
static var next_spawn := Vector2.ZERO
static var next_facing := "down"

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
	# Border fence.
	for x in cols:
		blocked[Vector2i(x, 0)] = true
		blocked[Vector2i(x, rows - 1)] = true
	for y in rows:
		blocked[Vector2i(0, y)] = true
		blocked[Vector2i(cols - 1, y)] = true
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
	player.position = next_spawn if next_spawn != Vector2.ZERO else default_spawn()
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
	cam.limit_right = maxi(cols * TILE, 270)
	cam.limit_bottom = maxi(rows * TILE, 480)
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
	var x0 := floori(r.position.x / TILE)
	var y0 := floori(r.position.y / TILE)
	var x1 := floori((r.end.x - 0.01) / TILE)
	var y1 := floori((r.end.y - 0.01) / TILE)
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			if blocked.has(Vector2i(x, y)):
				return true
	return false


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE / 2.0, c.y * TILE + TILE)


func try_interact(c: Vector2i) -> bool:
	var thing: Dictionary = things.get(c, {})
	if interact(c, thing):
		return true
	return interact_common(c, thing)


## Interactions every outdoor map shares (trees, rocks, logs, stumps, bushes).
func interact_common(c: Vector2i, thing: Dictionary) -> bool:
	match str(thing.get("type", "")):
		"tree", "log", "stump":
			if not GameState.has_tool("axe"):
				return false
			if not GameState.spend_energy(2):
				hud.toast("Too tired.", Color(1, 0.7, 0.7))
				return true
			player.play_tool("axe")
			Music.instance(get_tree()).sfx("chop")
			thing["hp"] = int(thing.get("hp", 3)) - 1
			if int(thing["hp"]) <= 0:
				var is_tree := str(thing["type"]) == "tree"
				give("wood", 3 if is_tree else 2)
				xp("foraging", 3)
				if is_tree:
					thing["hp"] = 3
				else:
					things.erase(c)
					blocked.erase(c)
					if props.has(c):
						(props[c] as Sprite2D).queue_free()
						props.erase(c)
			return true
		"rock":
			if not GameState.has_tool("pickaxe"):
				return false
			if not GameState.spend_energy(2):
				hud.toast("Too tired.", Color(1, 0.7, 0.7))
				return true
			player.play_tool("pickaxe")
			Music.instance(get_tree()).sfx("chop")
			thing["hp"] = int(thing.get("hp", 2)) - 1
			if int(thing["hp"]) <= 0:
				give("stone", 2)
				if randf() < 0.25:
					give("copper", 1)
				xp("mining", 2)
				things.erase(c)
				blocked.erase(c)
				if props.has(c):
					(props[c] as Sprite2D).queue_free()
					props.erase(c)
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
func prop(group: String, name: String, c: Vector2i, extra_w := 0, dy := 0.0) -> Sprite2D:
	var s := Art.sprite(group, name)
	if s == null:
		return null
	s.position = Vector2((c.x + (extra_w + 1) / 2.0) * TILE, (c.y + 1) * TILE + dy)
	add_child(s)
	props[c] = s
	return s


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


# ---- enemies -----------------------------------------------------------------

## Swing at enemies inside the rect. Subclasses can extend (rocks, etc.).
func attack_at(r: Rect2, damage: int) -> bool:
	Music.instance(get_tree()).sfx("swing")
	var hit := false
	for e in enemies.duplicate():
		if is_instance_valid(e) and r.has_point(e.position + Vector2(0, -6)):
			if e.hit(damage, player.position):
				hit = true
				fx("spark", e.position + Vector2(0, -8), 18.0, 0.5)
	if hit:
		Music.instance(get_tree()).sfx("hit")
	return hit


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
		var world := get_canvas_transform().affine_inverse() * pos
		var c := Vector2i(floori(world.x / TILE), floori(world.y / TILE))
		var e := nearest_enemy_to(world, 14.0)
		if e:
			player.go_to_cell(Vector2i(floori(e.position.x / TILE), floori((e.position.y - 2) / TILE)), true)
		elif has_npc_at(c):
			player.go_to_cell(c, true)
		elif things.has(c) and (hint_for(c, things[c]) != "" or things[c].get("type") == "plot"):
			player.go_to_cell(c, true)
		elif not blocked.has(c):
			player.go_to_cell(c, false)
		get_viewport().set_input_as_handled()


func has_npc_at(_c: Vector2i) -> bool:
	return false


# ---- time --------------------------------------------------------------------

func _process(delta: float) -> void:
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
func draw_grass(seed_v := 1) -> void:
	_deco_rng.seed = seed_v
	var gname := GameState.grass_tile()
	var has_tiles := Art.has("tiles", gname)
	var season := GameState.season()
	for y in rows:
		for x in cols:
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
	if Art.has("tiles", tset):
		# fill first (animated), then edges on top
		for c: Vector2i in cells:
			Art.draw_tile(self, "tiles", "water", Vector2(c * TILE), frame)
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

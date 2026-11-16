class_name GameMap
extends Node2D
## Base for every playable area. Owns the grid (size, blocked cells, things you
## can interact with), the player, the pet, camera, HUD, touch controls, sky, the
## clock, and scene transitions. Subclasses draw the map and fill the grid.

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
var _pet_anim: AnimatedSprite2D
var _night: CanvasModulate
var _changing := false
var _time_acc := 0.0
var _pet_dig := 0.0


func _ready() -> void:
	InputSetup.ensure_actions()
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

	if has_sky:
		sky = Scenery.new()
		sky.raining = not GameState.is_penguins() and int(GameState.run["day"]) == 1
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
	cam.limit_right = cols * TILE
	cam.limit_bottom = rows * TILE
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	player.add_child(cam)
	cam.make_current()

	hud = Hud.new()
	add_child(hud)
	add_child(TouchControls.new())
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
	return interact(c, thing)


## Swing at enemies inside the rect. Subclasses can extend (rocks, etc.).
func attack_at(r: Rect2, damage: int) -> bool:
	Music.instance(get_tree()).sfx("swing")
	var hit := false
	for e in enemies.duplicate():
		if is_instance_valid(e) and r.has_point(e.position + Vector2(0, -6)):
			if e.hit(damage, player.position):
				hit = true
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
	GameState.run["kills"] = int(GameState.run.get("kills", 0)) + 1
	GameState.run["crystals"] = int(GameState.run["crystals"]) + e.reward
	hud.toast("+%d crystals" % e.reward, Color(0.7, 0.9, 1))
	xp("combat", 2 if e.kind != "big_grump" else 20)
	Music.instance(get_tree()).sfx("die")


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


func update_enemies(_delta: float) -> void:
	pass


func _follow_pet(delta: float) -> void:
	var to := player.position - pet.position
	var dist := to.length()
	if dist > 22.0:
		var step := to.normalized() * minf(dist * 4.0, 95.0) * delta
		pet.position += step
		_pet_anim.flip_h = to.x < 0
		var a := "run" if dist > 40.0 else "walk"
		if _pet_anim.animation != a:
			_pet_anim.play(a)
		_pet_dig = 0.0
	else:
		if _pet_anim.animation != "idle" and _pet_anim.animation != "play":
			_pet_anim.play("idle")
		_pet_dig += delta
		if _pet_dig > 14.0:
			_pet_dig = randf_range(-6.0, 0.0)
			_pet_anim.play("play")
			await get_tree().create_timer(1.4).timeout
			if is_instance_valid(_pet_anim) and _pet_anim.animation == "play":
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


func xp(skill: String, n: int) -> void:
	if GameState.add_xp(skill, n):
		hud.toast("%s level %d!" % [skill.capitalize(), GameState.skill_level(skill)], Color(1, 0.9, 0.4))
		Music.instance(get_tree()).sfx("levelup")


# ---- shared drawing helpers --------------------------------------------------

func draw_grass() -> void:
	var g1 := Color("5a9e4b")
	var g2 := Color("67ab55")
	for y in rows:
		for x in cols:
			draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), g1 if (x + y) % 2 == 0 else g2)


func draw_fence_border(col := Color("6b4a2b")) -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(cols * TILE, TILE)), col)
	draw_rect(Rect2(0, (rows - 1) * TILE, cols * TILE, TILE), col)
	draw_rect(Rect2(Vector2.ZERO, Vector2(TILE, rows * TILE)), col)
	draw_rect(Rect2((cols - 1) * TILE, 0, TILE, rows * TILE), col)


func draw_tree(p: Vector2) -> void:
	draw_rect(Rect2(p.x - 2, p.y - 4, 4, 6), Color("5a3a1a"))
	draw_circle(Vector2(p.x, p.y - 10), 8.0, Color("2f7a3a"))
	draw_circle(Vector2(p.x - 3, p.y - 13), 5.0, Color("3f9a48"))


func draw_building(x: int, y: int, w: int, h: int, wall: Color, roof: Color, label: String) -> void:
	draw_rect(Rect2(x * TILE, (y + 1) * TILE, w * TILE, (h - 1) * TILE), wall)
	draw_rect(Rect2(x * TILE - 4, y * TILE, w * TILE + 8, TILE * 1.5), roof)
	var dx := (x + w / 2.0) * TILE - TILE / 2.0
	draw_rect(Rect2(dx, (y + h - 1) * TILE, TILE, TILE), Color("3a2412"))
	draw_rect(Rect2(x * TILE + 6, (y + 1.6) * TILE, 8, 8), Color("9fd8ff"))
	draw_rect(Rect2((x + w) * TILE - 14, (y + 1.6) * TILE, 8, 8), Color("9fd8ff"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(x * TILE, (y + 1.3) * TILE), label, HORIZONTAL_ALIGNMENT_CENTER, w * TILE, 7, Color(1, 1, 0.85))

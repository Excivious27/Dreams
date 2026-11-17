class_name Player
extends Node2D
## The character you control.
## Input: D-pad/WASD/arrows move, B (X/Shift) runs (hold or tap-toggle), A (Z/Space)
## interacts with the cell in front of you or swings your sword. Tapping the
## world (or clicking with the mouse) walks there and uses what's in your hand
## on it when you arrive, Stardew-mobile style.

const WALK_SPEED := 58.0
const RUN_SPEED := 108.0
const ACCEL := 560.0
const DECEL := 760.0
const PLAY_TIME := 1.5
const FEET := Rect2(-4, -3, 8, 3)

var char_id := ""
var facing := "down"  # down, up, left, right
var anim_name := ""
var velocity := Vector2.ZERO
var map: GameMap
var frozen := false
var invuln := 0.0
## Tap-to-move target in world space; INF when none.
var auto_target := Vector2.INF
var auto_cell := Vector2i(-1, -1)

var _sprite: Node2D
var _anim: AnimatedSprite2D
var _busy := false
var _busy_t := 0.0
var _play_left := 0.0
var _bob := 0.0
var _dust_timer := 0.0
var _shadow: Node2D
var _attack_hit_done := false
var _stuck_t := 0.0
var _attack_cd := 0.0
var _buffered := ""
var _flash_mat: ShaderMaterial
var _flash := 0.0
var _combo := 0
var _wear: WearLayer
var _doll := false
## Swimming (in a water cell) and riding (on the horse) change speed, anims and what you can do.
var swimming := false
var mounted := false
var _swim_t := 0.0
var _doll_scale := 0.34
var _doll_body := "medium_slim"
var _hair: Sprite2D
var _hat: Sprite2D


func mount() -> void:
	mounted = true
	GameState.run["flags"]["mounted"] = true
	_show_idle()


func dismount() -> void:
	mounted = false
	GameState.run["flags"].erase("mounted")
	if map:
		map.hud.toast("%s waits here." % str(GameState.run.get("names", {}).get("horse", "Your horse")))
		var c: Vector2i = cell() + Vector2i(1, 0)
		if map.blocked.has(c) or map.things.has(c):
			c = cell() + Vector2i(-1, 0)
		GameState.run["flags"]["horse_at"] = [map.scene_id(), c.x, c.y]
		map._place_waiting_horse()
	_show_idle()


## Scarf + hat on the penguin (no paper doll): a soft scarf band drawn under the
## chin and a hat from the hats sheet pinned to the head. Follows the sprite's
## scale/flip each frame through `_penguin_dress`.
static func dress_penguin(parent: Node2D, anim: AnimatedSprite2D, look: Dictionary, extra_scale: float) -> void:
	for ch in parent.get_children():
		if ch.name.begins_with("PenguinDress"):
			ch.queue_free()
	var scarf := str(look.get("scarf", ""))
	var hat := str(look.get("hat", ""))
	if scarf == "" and hat == "":
		return
	var holder := Node2D.new()
	holder.name = "PenguinDress"
	holder.z_index = 1
	parent.add_child(holder)
	var sprite_h := 14.0 * extra_scale  # TARGET_H for the penguin
	var W := "characters/penguin_wear"
	if Art.has(W, "scarf_red_front") and (scarf == "" or Art.has(W, "scarf_%s_front" % scarf)):
		# Painted wearables (Prompts 10): a full penguin-sized overlay per view; the
		# body shows through where the overlay is transparent... these sheets draw
		# the whole penguin, so we show the overlay INSTEAD of the body when idle.
		var ov := Sprite2D.new()
		ov.name = "PenguinDressOverlay"
		ov.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		ov.centered = true
		holder.add_child(ov)
		var pick := func(view: String) -> Texture2D:
			var hat_name := "hat_%s_%s" % [hat, view]
			if hat != "" and Art.has(W, hat_name):
				return Art.tex(W, hat_name)
			var sc_name := "scarf_%s_%s" % [scarf, view]
			if scarf != "" and Art.has(W, sc_name):
				return Art.tex(W, sc_name)
			return null
		var upd := func() -> void:
			if not is_instance_valid(holder) or not is_instance_valid(anim):
				return
			var an := anim.animation
			var idle := an in ["idle", "view_front", "view_right", "view_left", "view_back"]
			var view := "front"
			if an in ["view_right", "view_left"]:
				view = "side"
			elif an == "view_back":
				view = "back"
			var t: Texture2D = pick.call(view) if idle else null
			ov.visible = t != null
			anim.visible = t == null
			if t:
				ov.texture = t
				ov.scale = anim.scale
				ov.position = anim.position
				ov.offset = Vector2(0, -t.get_height() / 2.0)
				ov.flip_h = an == "view_left"
				ov.modulate = anim.modulate
		anim.frame_changed.connect(upd)
		anim.animation_changed.connect(upd)
		upd.call()
		return
	if scarf != "" and PaperDoll.SCARF_COLORS.has(scarf) and str(PaperDoll.SCARF_COLORS[scarf]) != "":
		var col := Color(str(PaperDoll.SCARF_COLORS[scarf]))
		var band := Node2D.new()
		band.name = "PenguinDressScarf"
		var sh := sprite_h
		band.draw.connect(func() -> void:
			var w := sh * 0.62
			var y := -sh * 0.62
			band.draw_rect(Rect2(-w / 2.0, y, w, sh * 0.13), col)
			band.draw_rect(Rect2(-w / 2.0 + 1, y + sh * 0.13, w * 0.35, sh * 0.22), col.darkened(0.1))
			band.draw_rect(Rect2(-w / 2.0, y - 1, w, 1), col.lightened(0.25)))
		holder.add_child(band)
	if hat != "":
		var hs := Sprite2D.new()
		hs.name = "PenguinDressHat"
		hs.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		holder.add_child(hs)
		PaperDoll.place_hat_simple(hs, hat, sprite_h * 0.8, -sprite_h, false, 1.0)
	anim.frame_changed.connect(func() -> void:
		if not is_instance_valid(holder):
			return
		holder.position = anim.position
		var flip := anim.flip_h
		for ch in holder.get_children():
			if ch is Sprite2D:
				(ch as Sprite2D).flip_h = flip)


## Rebuild the doll (after equipping a costume or restyling at the dresser).
func refresh_doll() -> void:
	if _doll or PaperDoll.available():
		set_character(char_id)


## Pin hair and hat to the current body frame (paper doll only).
func _update_doll() -> void:
	if not _doll or _anim == null or _hair == null:
		return
	var look: Dictionary = GameState.run.get("look", {})
	var src := PaperDoll.frame_source(_anim.animation, _anim.frame, _doll_body)
	var body: String = src[0]
	var pose: int = src[1]
	var flip := _anim.flip_h
	PaperDoll.place_layer(_hair, "hair", str(look.get("hair", "")), body, pose, flip, _doll_scale)
	var hat_id := GameState.equipped("head")
	var hat_sprite := str(GameState.items.get(hat_id, {}).get("sprite", hat_id))
	PaperDoll.place_layer(_hat, "hats", hat_sprite if Art.has("hats", hat_sprite) else str(look.get("hat", "")), body, pose, flip, _doll_scale)
	if _hat.visible and _hair.visible:
		_hair.modulate.a = 1.0


func set_character(id: String) -> void:
	GameState.load_data()
	if _sprite:
		_sprite.queue_free()
	char_id = id
	var pid := str(GameState.run.get("playable", ""))
	var pdata: Dictionary = GameState.playables.get(pid, {})
	var look: Dictionary = GameState.run.get("look", {})
	# The paper doll is only for "build your own" heroes (or old saves that
	# dressed a drawn hero); precreated heroes are drawn as themselves.
	_doll = PaperDoll.available() and look.has("body") and bool(pdata.get("custom", false))
	if _doll:
		# Paper doll: body base + hair + hat layers (see PaperDoll).
		_anim = AnimatedSprite2D.new()
		_doll_body = PaperDoll.body_for(look)
		_anim.sprite_frames = PaperDoll.body_frames(look)
		_anim.centered = true
		_anim.offset = Vector2(0, -48)
		var h := float(PaperDoll.anchor_of("body", _doll_body, 0)[4])
		_doll_scale = CharacterLibrary.HERO_H / maxf(40.0, h)
		_anim.scale = Vector2(_doll_scale, _doll_scale)
		_anim.animation_finished.connect(_on_animation_finished)
		_sprite = _anim
		for l in [_hair, _hat]:
			if l:
				l.queue_free()
		_hair = Sprite2D.new()
		_hair.centered = true
		_hair.modulate = Color(str(PaperDoll.HAIR_COLORS.get(str(look.get("hair_color", "brown")), "ffffff")))
		_hat = Sprite2D.new()
		_hat.centered = true
		var sh := load("res://shaders/flash.gdshader")
		if sh:
			_flash_mat = ShaderMaterial.new()
			_flash_mat.shader = sh
			_anim.material = _flash_mat
	elif id == "" or not CharacterLibrary.has_character(id):
		var ph := PlaceholderSprite.new()
		ph.tint = Color(str(pdata.get("color", "2b3a67")))
		_sprite = ph
		_anim = null
	else:
		_anim = CharacterLibrary.make_sprite(id)
		_anim.animation_finished.connect(_on_animation_finished)
		if str(GameState.look_d().get("tint", "")) != "":
			_anim.modulate = Color(str(GameState.look_d().get("tint", "ffffff")))
		elif pdata.has("tint"):
			_anim.modulate = Color(str(pdata["tint"]))
		_sprite = _anim
		if id == "penguin":
			Player.dress_penguin(self, _anim, GameState.run.get("look", {}), 1.0)
		var sh := load("res://shaders/flash.gdshader")
		if sh:
			_flash_mat = ShaderMaterial.new()
			_flash_mat.shader = sh
			_anim.material = _flash_mat
	if _shadow == null:
		_shadow = Node2D.new()
		_shadow.draw.connect(func() -> void: _shadow.draw_circle(Vector2(0, -0.5), 5.0, Color(0, 0, 0, 0.22)))
		_shadow.scale = Vector2(1.0, 0.45)
		add_child(_shadow)
	add_child(_sprite)
	if _doll:
		add_child(_hair)
		add_child(_hat)
		_hair.z_index = 1
		_hat.z_index = 2
		_update_doll()
	if _wear == null:
		_wear = WearLayer.new()
		_wear.player = self
		add_child(_wear)
	_wear._body_h = float(CharacterLibrary.strip_info(id).get("cell_h", 74)) if CharacterLibrary.data().has(id) else 74.0
	_wear.refresh()
	_busy = false
	anim_name = ""
	mounted = GameState.run.get("flags", {}).has("mounted") and has_anim("ride")
	_show_idle()


func has_anim(a: String) -> bool:
	return _anim != null and _anim.sprite_frames.has_animation(a)


func facing_dir() -> Vector2:
	match facing:
		"up": return Vector2.UP
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
	return Vector2.DOWN


## The cell a tool/check goes to: the mouse-aimed neighbour when a mouse is
## pointing at one (any of the 8 around you, or your own), else the facing cell.
var aim_cell := Vector2i(-1, -1)
var _last_hit_enemy: Enemy = null
var _ability_hold := 0.0
var is_puppet := false
var mouse_held := false
var _hold_t := 0.0


func facing_cell() -> Vector2i:
	if aim_cell != Vector2i(-1, -1):
		return aim_cell
	return cell() + Vector2i(facing_dir())


func update_aim() -> void:
	if map == null or TouchControls.visible_controls or DisplayServer.is_touchscreen_available():
		aim_cell = Vector2i(-1, -1)
		return
	var mc := map.world_to_cell(get_global_mouse_position())
	var me := cell()
	var d := mc - me
	if absi(d.x) <= 1 and absi(d.y) <= 1 and d != Vector2i.ZERO:
		aim_cell = mc
	elif d == Vector2i.ZERO:
		aim_cell = me  # standing on a plot: hoe/water your own tile
	else:
		aim_cell = Vector2i(-1, -1)


func _draw() -> void:
	# Tool target highlight (Stardew's red/green cursor square).
	if map == null or frozen or map.get_tree().paused:
		return
	var held := GameState.held_tool()
	if held == "" or held in ["sword", "iron_sword"]:
		return
	var fc := facing_cell()
	var thing: Dictionary = map.things.get(fc, {})
	var usable: bool = map.hint_for(fc, thing) != "" or (held == "hoe" and map.can_till(fc)) or (held == "can" and str(thing.get("type", "")) == "plot") or (held == "scythe" and str(thing.get("type", "")) in ["grass", "weeds", "plot"])
	var col := Color(0.4, 1.0, 0.5, 0.55) if usable else Color(1.0, 0.45, 0.4, 0.4)
	var r := Rect2(map.cell_pos(fc.x, fc.y) - position, Vector2(GameMap.TILE, GameMap.TILE))
	draw_rect(r.grow(-1), col, false, 1.5)
	draw_rect(r.grow(-1), Color(col, 0.12))


func cell() -> Vector2i:
	if map:
		return map.world_to_cell(position - Vector2(0, 2))
	return Vector2i(floori(position.x / GameMap.TILE), floori((position.y - 2) / GameMap.TILE))


func face_toward(p: Vector2) -> void:
	var d := p - (position + Vector2(0, -8))
	if absf(d.x) > absf(d.y):
		facing = "left" if d.x < 0 else "right"
	else:
		facing = "up" if d.y < 0 else "down"


func go_to_cell(c: Vector2i, interact_there: bool) -> void:
	# Walk to a cell. If it's something to use, stop next to it and face it.
	auto_cell = c if interact_there else Vector2i(-1, -1)
	if interact_there:
		var target := map.cell_center(c)
		var d := target - position
		if d.length() < GameMap.TILE * 1.2:
			auto_target = Vector2.INF
			auto_cell = Vector2i(-1, -1)
			face_toward(target)
			_do_action()
			return
		# Pick the neighbouring cell nearest to us that isn't blocked.
		var best := Vector2.INF
		for off: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var n: Vector2i = c + off
			if map.blocked.has(n):
				continue
			var p := map.cell_center(n)
			if best == Vector2.INF or p.distance_to(position) < best.distance_to(position):
				best = p
		auto_target = best if best != Vector2.INF else target
	else:
		auto_target = map.cell_center(c)
	_stuck_t = 0.0


var _status_fx := {}  # status name -> AnimatedSprite2D overlay (fx/st_<name>)


func _refresh_status_fx() -> void:
	var active: Dictionary = GameState.run.get("status", {})
	for k in _status_fx.keys():
		if not active.has(k):
			(_status_fx[k] as Node).queue_free()
			_status_fx.erase(k)
	for k in active:
		if _status_fx.has(k) or not Art.has("fx", "st_" + str(k)):
			continue
		var a := AnimatedSprite2D.new()
		a.sprite_frames = Art.frames("fx", {"a": "st_" + str(k)}, {"a": 8.0})
		a.animation = "a"
		a.scale = Vector2(0.5, 0.5)
		a.position = Vector2(0, -13)
		a.z_index = 2
		a.modulate.a = 0.8
		add_child(a)
		a.play("a")
		_status_fx[k] = a


func _physics_process(delta: float) -> void:
	if not is_puppet and map and not frozen:
		_refresh_status_fx()
		var sdmg := GameState.status_tick(delta)
		if sdmg > 0:
			GameState.run["hp"] = int(GameState.run["hp"]) - sdmg
			_flash = 0.6
			map.damage_number(position + Vector2(0, -22), sdmg, Color(0.6, 0.9, 0.4))
			if int(GameState.run["hp"]) <= 0:
				map.player_down("hurt")
	if _sprite == null or is_puppet:
		return
	invuln = maxf(0.0, invuln - delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_flash = maxf(0.0, _flash - delta * 6.0)
	if _flash_mat:
		_flash_mat.set_shader_parameter("flash", _flash)
	_update_doll()
	if map and map.hitstop > 0.0:
		return
	if _anim:
		var base := Color.WHITE
		var pid := str(GameState.run.get("playable", ""))
		var pdata: Dictionary = GameState.playables.get(pid, {})
		if pdata.has("tint"):
			base = Color(str(pdata["tint"]))
		else:
			base = Color(str(GameState.look_d().get("tint", "ffffff")))
		_anim.modulate = Color(base, 0.5 if invuln > 0.0 and int(invuln * 20) % 2 == 0 else 1.0)
	if frozen:
		velocity = Vector2.ZERO
		auto_target = Vector2.INF
		_show_idle()
		return
	var dir := Input.get_vector("left", "right", "up", "down")
	if dir != Vector2.ZERO:
		auto_target = Vector2.INF
		auto_cell = Vector2i(-1, -1)
	update_aim()
	queue_redraw()
	if _busy:
		_busy_t += delta
		if _busy_t > 1.2:
			_busy = false  # watchdog: never stay stuck in an action
	else:
		_busy_t = 0.0

	if not Dialogue.input_blocked():
		# Stardew keys: C/left click = tool, X/right click = check. "a" is the generic
		# touch button (check first, tool otherwise). A press during a swing is buffered.
		var want := ""
		if Input.is_action_just_pressed("tool"):
			want = "tool"
		elif Input.is_action_just_pressed("action"):
			want = "action"
		elif Input.is_action_just_pressed("a"):
			want = "a"
		if want != "":
			if _busy:
				_buffered = want
			else:
				auto_target = Vector2.INF
				do_action(want)
				return
		elif not _busy and _buffered != "":
			var b := _buffered
			_buffered = ""
			do_action(b)
			return
		elif not _busy and (Input.is_action_pressed("tool") or mouse_held) and _hold_t > 0.25 and GameState.held_tool() in ["hoe", "can", "axe", "pickaxe", "scythe", "sword", "iron_sword"]:
			# Holding the tool button keeps swinging (Stardew-style).
			if mouse_held and map:
				face_toward(map.get_global_mouse_position())
			do_action("tool")
			return
	if Input.is_action_pressed("tool") or mouse_held:
		_hold_t += delta
	else:
		_hold_t = 0.0
	# Companion ability: hold B still for a second.
	if Input.is_action_pressed("b") and dir == Vector2.ZERO and not _busy and Companion.active_id() != "" and not Dialogue.input_blocked():
		_ability_hold += delta
		if _ability_hold >= 1.0:
			_ability_hold = -2.0  # cooldown until released
			Companion.use_ability(map, self)
	elif not Input.is_action_pressed("b"):
		_ability_hold = 0.0
	if Input.is_action_just_pressed("b") and dir == Vector2.ZERO and not _busy and has_anim("play") and not Dialogue.input_blocked():
		_busy = true
		_play_left = PLAY_TIME
		_apply("play", facing == "left")
		return
	if _busy:
		if anim_name == "play":
			_play_left -= delta
			if _play_left > 0.0 and dir == Vector2.ZERO:
				return
			_busy = false
		elif anim_name.begins_with("attack"):
			if _anim and not _attack_hit_done:
				_attack_hit()
			# A swing never locks you for long: cancel into movement after the hit.
			if _busy_t > 0.22 and dir != Vector2.ZERO:
				_busy = false
				_show_idle()
			else:
				return
		elif anim_name.begins_with("hoe_") or anim_name.begins_with("water_") or anim_name.begins_with("axe_") or anim_name.begins_with("pickaxe_") or anim_name.begins_with("cast_") or anim_name.begins_with("reel_") or anim_name.begins_with("hold_") or anim_name.begins_with("eat_"):
			if _anim and _anim.is_playing():
				return
			_busy = false
		else:
			_busy = false

	# Tap-to-move steering.
	var auto := false
	if dir == Vector2.ZERO and auto_target != Vector2.INF:
		var to := auto_target - position
		if to.length() < 3.0:
			auto_target = Vector2.INF
			if auto_cell != Vector2i(-1, -1):
				face_toward(map.cell_center(auto_cell))
				auto_cell = Vector2i(-1, -1)
				velocity = Vector2.ZERO
				_do_action()
				return
		else:
			dir = to.normalized()
			auto = true

	var running := Input.is_action_pressed("b") or TouchControls.run_toggle or (auto and auto_target.distance_to(position) > 48.0)
	var spd_mult := 1.0 + 0.08 * GameState.gear_stat("speed")
	if int(GameState.run["flags"].get("haste_until", -1)) > int(GameState.run["time"]):
		spd_mult *= 1.3
	if GameState.weather_today() in ["snow", "blizzard"] and map and map.has_sky:
		spd_mult *= 0.9
	elif int(GameState.run["energy"]) < int(GameState.run["max_energy"]) * 0.12:
		spd_mult *= 0.75  # running on empty
	if swimming:
		spd_mult *= 1.0 if Companion.has_ability("tail") else 0.55
		running = false
		_swim_t += delta
		if _swim_t > 2.0 and not Companion.has_ability("tail"):
			_swim_t = 0.0
			if not GameState.spend_energy(1):
				map.player_down("tired")
	elif mounted:
		spd_mult *= 1.8 if running else 1.5
	spd_mult *= GameState.status_speed()
	spd_mult *= 1.0 + 0.05 * mini(2, Crew.perk_level("run_speed"))
	var target := dir * (RUN_SPEED if running else WALK_SPEED) * spd_mult
	var rate := ACCEL if dir != Vector2.ZERO else DECEL
	velocity = velocity.move_toward(target, rate * delta)
	var before := position
	_move(velocity * delta)
	if auto:
		# Give up if a wall stops us.
		if position.distance_to(before) < 0.2:
			_stuck_t += delta
			if _stuck_t > 0.35:
				auto_target = Vector2.INF
				auto_cell = Vector2i(-1, -1)
		else:
			_stuck_t = 0.0

	var speed := velocity.length()
	if dir == Vector2.ZERO and speed < 4.0:
		velocity = Vector2.ZERO
		_sprite.position.y = 0
		_show_idle()
		return

	var move_dir := dir if dir != Vector2.ZERO else velocity.normalized()
	var is_run := speed > WALK_SPEED * 1.15
	var pre := ""
	if swimming and has_anim("swim"):
		pre = "swim"
	elif mounted and has_anim("ride"):
		pre = "ride"
	if pre != "":
		if absf(move_dir.x) >= absf(move_dir.y) * 0.9:
			facing = "left" if move_dir.x < 0 else "right"
			_apply("ride_run" if pre == "ride" and is_run and has_anim("ride_run") else pre, move_dir.x < 0)
		else:
			facing = "up" if move_dir.y < 0 else "down"
			_apply(pre + "_" + facing, false)
		if _anim:
			_anim.speed_scale = 1.0
		return
	if absf(move_dir.x) >= absf(move_dir.y) * 0.9:
		facing = "left" if move_dir.x < 0 else "right"
		_sprite.position.y = 0
		_apply("run" if is_run else "walk", move_dir.x < 0)
	else:
		facing = "up" if move_dir.y < 0 else "down"
		var vert := ("run_" if is_run else "walk_") + facing
		if has_anim(vert):
			_sprite.position.y = 0
			_apply(vert, false)
		else:
			# No toward/away art for this character: front/back view with a bob.
			_apply("view_back" if move_dir.y < 0 else "view_front", false)
			_bob += delta * speed * 0.16
			_sprite.position.y = -absf(sin(_bob)) * 2.0
	if _anim:
		_anim.speed_scale = clampf(speed / (RUN_SPEED if is_run else WALK_SPEED), 0.6, 1.3)

	_dust_timer -= delta
	if is_run and _dust_timer <= 0.0:
		_dust_timer = 0.14
		_puff(-move_dir)


## Play a tool-use animation (hoe/water/axe/pickaxe/cast/reel/hold/eat) in the
## facing direction if the character has it. Returns true if it played.
func play_tool(action: String, restart := true) -> bool:
	var d := "right" if facing in ["left", "right"] else facing
	var a := action + "_" + d
	if not has_anim(a) and has_anim(action + "_right"):
		a = action + "_right"
	if not has_anim(a):
		return false
	_busy = true
	_busy_t = 0.0
	velocity = Vector2.ZERO
	_sprite.position.y = 0
	_apply(a, facing == "left", restart)
	return true


func _do_action() -> void:
	do_action("a")


## mode: "a" = check then tool (touch button), "tool" = tool/sword only (C),
## "action" = check/talk/eat only (X).
func do_action(mode := "a") -> void:
	if _busy:
		return
	if swimming:
		return  # no tools in the water
	if mounted and mode != "action":
		if map and map.try_interact(facing_cell()):
			return
		dismount()
		return
	var held := GameState.held_tool()
	if mode == "tool" and held in ["sword", ""]:
		_swing()
		return
	if map and map.try_interact(facing_cell()):
		velocity = Vector2.ZERO
		if not _busy:
			_show_idle()
		return
	# Standing on a door/exit-type thing (you walked onto it): A uses it.
	if map and map.things.has(cell()) and str(map.things[cell()].get("type", "")) in ["door", "idoor", "exit", "mine", "cave", "pad"] and map.try_interact(cell()):
		velocity = Vector2.ZERO
		return
	if mode == "action":
		# Point the pup at an enemy.
		var e := map.nearest_enemy_to(position + facing_dir() * 16.0, 24.0)
		if e and map.pet is Pet and map.pet.visible:
			(map.pet as Pet)._target = e
			(map.pet as Pet).set_mode("attack")
		return
	if held in ["hoe", "can", "axe", "pickaxe", "rod", "scythe"]:
		# Swinging a farm tool at nothing: show the swing anyway, it reads as "nothing here".
		var act: String = {"hoe": "hoe", "can": "water", "axe": "axe", "pickaxe": "pickaxe", "rod": "cast", "scythe": "axe"}[held]
		if play_tool(act):
			return
		return
	if held in ["sword", "iron_sword", ""]:
		_swing()


func _swing() -> void:
	if _attack_cd > 0.0:
		return
	# Aim assist: snap to an enemy that's close and roughly in front.
	if map:
		var best: Enemy = null
		var bd := 26.0
		for e in map.enemies:
			if not is_instance_valid(e):
				continue
			var d: Vector2 = e.position - position
			if d.length() < bd and d.normalized().dot(facing_dir()) > 0.3:
				best = e
				bd = d.length()
		if best:
			face_toward(best.position)
	_busy = true
	_busy_t = 0.0
	_attack_cd = 0.3
	_attack_hit_done = false
	_combo = (_combo + 1) % 3
	velocity = Vector2.ZERO
	_sprite.position.y = 0
	# Directional attack strips when the character has them (penguin); else the side one flipped.
	var atk := "attack"
	if facing == "down" and has_anim("attack_down"):
		atk = "attack_down"
	elif facing == "up" and has_anim("attack_up"):
		atk = "attack_up"
	_apply(atk, facing == "left" and atk == "attack", true)
	if _anim:
		_anim.speed_scale = 1.6
	_attack_hit()
	if _anim == null:
		_busy = false


func _move(step: Vector2) -> void:
	if map == null:
		position += step
		return
	var nx := position + Vector2(step.x, 0)
	if not map.rect_blocked_player(Rect2(nx + FEET.position, FEET.size), self):
		position = nx
	else:
		velocity.x = 0
	var ny := position + Vector2(0, step.y)
	if not map.rect_blocked_player(Rect2(ny + FEET.position, FEET.size), self):
		position = ny
	else:
		velocity.y = 0
	var was := swimming
	swimming = map.is_water_cell(cell())
	if swimming and not was:
		map.fx("splash", position, 12.0, 0.5)
		Music.instance(get_tree()).sfx("bite")
	elif was and not swimming:
		map.fx("splash", position, 12.0, 0.4)


func _attack_hit() -> void:
	_attack_hit_done = true
	if map:
		var center := position + facing_dir() * 12.0 + Vector2(0, -6)
		var side := facing_dir().orthogonal() * 16.0
		var box := Rect2(center - Vector2(14, 14), Vector2(28, 28))
		var hit := map.attack_at(box, maxi(1, GameState.sword_damage() + (1 if _combo == 0 else 0) + GameState.status_damage_mod()), position)
		if hit:
			_last_hit_enemy = map.nearest_enemy_to(center, 22.0)
		_swing_arc(center)
		if hit:
			map.hitstop = 0.05
			map.shake(1.5)


## Stardew-style sword arc in the facing direction.
func _swing_arc(center: Vector2) -> void:
	var fx := Node2D.new()
	fx.position = center
	fx.z_index = 2
	var age := [0.0]
	var ang := facing_dir().angle()
	fx.draw.connect(func() -> void:
		var a: float = age[0]
		var col := Color(1, 1, 0.85, 0.8 * (1.0 - a))
		fx.draw_arc(Vector2.ZERO, 11.0 + a * 4.0, ang - 1.1, ang + 1.1, 12, col, 2.5))
	get_parent().add_child(fx)
	var tw := fx.create_tween()
	tw.tween_method(func(v: float) -> void: age[0] = v; fx.queue_redraw(), 0.0, 1.0, 0.18)
	tw.tween_callback(fx.queue_free)


func take_damage(n: int, from: Vector2) -> void:
	if invuln > 0.0:
		return
	if randf() < GameState.bonus("combat", "block"):
		invuln = 0.4
		if map:
			map.hud.toast("Blocked!", Color(0.8, 0.9, 1.0))
		return
	if int(GameState.run["flags"].get("shield", 0)) > 0:
		GameState.run["flags"]["shield"] = int(GameState.run["flags"]["shield"]) - 1
		invuln = 0.5
		if map:
			map.hud.toast("Shield!", Color(0.8, 0.9, 1.0))
			map.fx("sparkle", position + Vector2(0, -12), 14.0, 0.5)
		return
	n = maxi(2, n - (GameState.gear_stat("defense") + mini(2, Crew.perk_level("defence"))) * 2)
	n = int(n * (1.0 - GameState.bonus("combat", "damage_reduction")))
	# Short mercy window: enough to not get chain-hit by one enemy, not enough to
	# tank a crowd. The knockback is shorter too, so you can't bounce to safety.
	invuln = 0.35
	_flash = 1.0
	GameState.run["hp"] = int(GameState.run["hp"]) - n
	velocity = (position - from).normalized() * 120.0
	auto_target = Vector2.INF
	_busy = false
	Music.instance(get_tree()).sfx("hurt")
	if map:
		map.hitstop = 0.06
		map.shake(3.0)
		map.damage_number(position + Vector2(0, -22), n, Color(1, 0.35, 0.3))
	if int(GameState.run["hp"]) <= 0 and map:
		map.player_down()


func _puff(back: Vector2) -> void:
	var d := Node2D.new()
	d.position = position + back * 3.0
	d.z_index = -1
	var age := [0.0]
	d.draw.connect(func() -> void:
		var a: float = age[0]
		d.draw_circle(Vector2(0, -1 - a * 6.0), 1.5 + a * 2.5, Color(0.95, 0.9, 0.8, 0.5 * (1.0 - a))))
	get_parent().add_child(d)
	var tw := d.create_tween()
	tw.tween_method(func(v: float) -> void: age[0] = v; d.queue_redraw(), 0.0, 1.0, 0.4)
	tw.tween_callback(d.queue_free)


func _show_idle() -> void:
	if _anim:
		_anim.speed_scale = 1.0
	if swimming and has_anim("float"):
		_apply("float", facing == "left")
		return
	if mounted and has_anim("ride"):
		_apply({"up": "ride_up", "down": "ride_down"}.get(facing, "ride"), facing == "left")
		return
	match facing:
		"up":
			_apply("view_back", false)
		"left":
			_apply("view_left", false)
		"right":
			_apply("view_right", false)
		_:
			_apply("idle", false)


func _apply(a: String, flip: bool, restart := false) -> void:
	if _anim == null:
		anim_name = a
		_sprite.scale.x = -1.0 if flip else 1.0
		return
	if a == "view_left" and not _anim.sprite_frames.has_animation(a) and _anim.sprite_frames.has_animation("view_right"):
		a = "view_right"
		flip = true
	if not _anim.sprite_frames.has_animation(a):
		a = "idle"
	_anim.flip_h = flip
	if restart or anim_name != a:
		anim_name = a
		_anim.play(a)


func _on_animation_finished() -> void:
	if anim_name.begins_with("attack") or anim_name == "powerup" or not _anim.sprite_frames.get_animation_loop(anim_name):
		_busy = false
		_show_idle()

class_name Player
extends Node2D
## The character you control.
## Input: D-pad/WASD/arrows move, B (X/Shift) runs (hold or tap-toggle), A (Z/Space)
## interacts with the cell in front of you or swings your sword. Tapping the
## world (or clicking with the mouse) walks there and uses what's in your hand
## on it when you arrive, Stardew-mobile style.

# Round 13: ~10% slower (Tom: "moves slightly too fast"); mounts, vehicles and
# skill bonuses multiply these, so they slow by the same share.
const WALK_SPEED := 52.0
const RUN_SPEED := 96.0
const ACCEL := 560.0
const DECEL := 760.0
const PLAY_TIME := 1.5
const FEET := Rect2(-4, -3, 8, 3)

var _flash_sent := -1.0
var char_id := ""
static var last_mouse_motion_ms := -100000
var facing := "down"  # down, up, left, right
var _cur_pos := Vector2.INF  # cursor-square redraw throttle
var _cur_face := ""
var _cur_acc := 0.0
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
var _last_swing_ms := 0   # the 3-hit combo resets after a pause
var _dodge_t := 0.0
var _dodge_cd := 0.0
var _dodge_dir := Vector2.ZERO
var _wear: WearLayer
var _doll := false
## Swimming (in a water cell) and riding (on the horse) change speed, anims and what you can do.
var swimming := false
var mounted := false
var _swim_t := 0.0
var _repeat_cd := 0.0
var _doll_scale := 0.34
var _doll_body := "medium_slim"
var _hair: Sprite2D
var _hat: Sprite2D


# ---- vehicles (built at the Vehicle Workshop) -----------------------------------
var vehicle := ""
var _veh: Sprite2D
var _veh_puff := 0.0


func vehicle_def() -> Dictionary:
	return GameState.items.get(vehicle, {}) if vehicle != "" else {}


func ride(id: String) -> void:
	if mounted:
		dismount()
	vehicle = id
	GameState.run["flags"]["vehicle"] = id
	if _veh == null:
		_veh = Sprite2D.new()
		_veh.show_behind_parent = true
		_veh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_veh)
	_veh_face()


## The vehicle's picture for the way you're facing (down / up / side views).
func _veh_face() -> void:
	if _veh == null or vehicle == "":
		return
	var vd := vehicle_def()
	var base := str(vd.get("sprite", "farm_cart"))
	var view: String = {"down": "_down", "up": "_up"}.get(facing, "_side")
	var nm := base + view if Art.has("props", base + view) else (base if Art.has("props", base) else "farm_cart")
	var tex := Art.tex("props", nm)
	_veh.texture = tex
	_veh.visible = tex != null
	if tex == null:
		return
	# Sized by its side view so all three views are the same vehicle.
	var side := Art.tex("props", base + "_side") if Art.has("props", base + "_side") else tex
	var sc := float(vd.get("size", 26)) / float(maxi(1, side.get_width()))
	_veh.scale = Vector2(sc, sc)
	_veh.flip_h = facing == "left"
	_veh.position = Vector2(0, -tex.get_height() * sc * 0.5 + 4)


func unride() -> void:
	vehicle = ""
	GameState.run["flags"].erase("vehicle")
	if _veh:
		_veh.visible = false


func mount() -> void:
	if not has_anim("ride"):
		if map:
			map.hud.toast("The horse looks at you, then at your outfit. (This hero can't ride yet.)", Color(1, 0.9, 0.7))
		return
	mounted = true
	GameState.run["flags"]["mounted"] = true
	_show_idle()


func dismount() -> void:
	mounted = false
	GameState.run["flags"].erase("mounted")
	if map:
		map.hud.toast("%s waits here." % str(GameState.run.get("names", {}).get("horse", "Your horse")))
		var c: Vector2i = cell()
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var cc: Vector2i = cell() + off
			if cc.x >= 0 and cc.y >= 0 and cc.x < map.cols and cc.y < map.rows and not map.blocked.has(cc) and not map.things.has(cc):
				c = cc
				break
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
				ov.flip_h = an == "view_left" or (an == "view_right" and anim.flip_h)
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
	var follow := func() -> void:
		if not is_instance_valid(holder):
			return
		holder.position = anim.position
		var flip := anim.flip_h
		for ch in holder.get_children():
			if ch is Sprite2D:
				(ch as Sprite2D).flip_h = flip
	anim.frame_changed.connect(follow)
	anim.animation_changed.connect(follow)


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
		_hair.material = PaperDoll.hair_material(str(look.get("hair_color", "brown")))
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
	var vid := str(GameState.run.get("flags", {}).get("vehicle", ""))
	if vid != "" and GameState.count(vid) > 0 and map and map.has_sky:
		ride(vid)
	elif vehicle != "":
		unride()
	_show_idle()


func has_anim(a: String) -> bool:
	return _anim != null and _anim.sprite_frames.has_animation(a)


## A real walk cycle (2+ frames), not a one-frame stand-in alias.
func _moving_anim(a: String) -> bool:
	return has_anim(a) and _anim.sprite_frames.get_frame_count(a) > 1


## Facing rule for every walker: sideways only when the horizontal part clearly
## dominates; straight down, straight up and exact diagonals face down/up.
static func horizontal_wins(v: Vector2) -> bool:
	return absf(v.x) > absf(v.y) + 0.001


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
	if Time.get_ticks_msec() - Player.last_mouse_motion_ms > 4000:
		aim_cell = Vector2i(-1, -1)  # keyboard play: the parked cursor doesn't aim
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
	var sel := str(GameState.run["selected"])
	var seed_held: bool = held == "" and str((GameState.items.get(sel, {}) as Dictionary).get("type", "")) == "seed"
	if (held == "" and not seed_held) or GameState.is_sword(held):
		return
	var fc := facing_cell()
	var thing: Dictionary = map.things.get(fc, {})
	var fkey := "%d,%d" % [fc.x, fc.y]
	var ftile: Dictionary = (GameState.run["farm"] as Dictionary).get(fkey, {})
	var usable: bool = map.hint_for(fc, thing) != "" or (held == "hoe" and map.can_till(fc)) or (held == "can" and not ftile.is_empty() and not bool(ftile.get("watered", false)) and not GameState.sky_waters()) or (held == "scythe" and str(thing.get("type", "")) in ["grass", "weeds", "plot"]) or (seed_held and not ftile.is_empty() and str(ftile.get("crop", "")) == "") or (held == "" and sel == "fertilizer" and not ftile.is_empty() and not bool(ftile.get("fert", false)))
	var col := Color(0.4, 1.0, 0.5, 0.55) if usable else Color(1.0, 0.45, 0.4, 0.4)
	var r := Rect2(map.cell_pos(fc.x, fc.y) - position, Vector2(GameMap.TILE, GameMap.TILE))
	draw_rect(r.grow(-1), col, false, 1.5)
	draw_rect(r.grow(-1), Color(col, 0.12))


func cell() -> Vector2i:
	if map:
		return map.world_to_cell(position - Vector2(0, 2))
	return Vector2i(floori(position.x / GameMap.TILE), floori((position.y - 2) / GameMap.TILE))


func face_toward(p: Vector2) -> void:
	# Face by cells when the target is another cell (cell centres sit at feet
	# level, so a pixel offset picked the wrong side); by pixels otherwise.
	var tc := map.world_to_cell(p) if map else Vector2i(-999, -999)
	if map and tc != cell():
		var dc := tc - cell()
		if absi(dc.x) > absi(dc.y):
			facing = "left" if dc.x < 0 else "right"
		else:
			facing = "up" if dc.y < 0 else "down"
		return
	var d := p - position
	if absf(d.x) > absf(d.y):
		facing = "left" if d.x < 0 else "right"
	else:
		facing = "up" if d.y < 0 else "down"


func go_to_cell(c: Vector2i, interact_there: bool) -> void:
	# Walk to a cell. If it's something to use, stop next to it and face it.
	auto_cell = c if interact_there else Vector2i(-1, -1)
	if interact_there:
		var target := map.cell_center(c)
		var dc := c - cell()
		if dc == Vector2i.ZERO:
			# Tapped the cell you're standing on (forage, a plot): act on it directly.
			auto_target = Vector2.INF
			auto_cell = Vector2i(-1, -1)
			map.try_interact(c)
			return
		if absi(dc.x) + absi(dc.y) == 1:
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


var _status_shield := 0.0   # secs; Not Today washes statuses off for this long


func _physics_process(delta: float) -> void:
	if not is_puppet and map and not frozen:
		_refresh_status_fx()
		# Not Today's grace: the knockout hit's own poison/burn can't stick.
		if _status_shield > 0.0:
			_status_shield -= delta
			GameState.status_clear()
		var sdmg := GameState.status_tick(delta)
		if sdmg > 0:
			GameState.run["hp"] = int(GameState.run["hp"]) - sdmg
			_flash = 0.6
			map.damage_number(position + Vector2(0, -22), sdmg, Color(0.6, 0.9, 0.4))
			_last_stand()
			if int(GameState.run["hp"]) <= 0:
				map.player_down("hurt")
	if _sprite == null or is_puppet:
		return
	invuln = maxf(0.0, invuln - delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_flash = maxf(0.0, _flash - delta * 6.0)
	if _flash_mat and _flash != _flash_sent:
		_flash_sent = _flash
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
		elif char_id == "penguin":
			base = Color(str(GameState.look_d().get("tint", "ffffff")))
		_anim.modulate = Color(base, 0.5 if invuln > 0.0 and int(invuln * 20) % 2 == 0 else 1.0)
	if frozen:
		velocity = Vector2.ZERO
		auto_target = Vector2.INF
		_buffered = ""
		# Let a one-shot tool pose (cast, reel, hold) finish instead of snapping to idle.
		if not (_busy and _anim and _anim.is_playing() and not anim_name.begins_with("walk") and not anim_name.begins_with("run")):
			_show_idle()
		return
	var dir := Input.get_vector("left", "right", "up", "down")
	if dir != Vector2.ZERO:
		auto_target = Vector2.INF
		auto_cell = Vector2i(-1, -1)
	# Dodge roll (ROLL button, or Space): a quick dash with a moment of safety.
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	if TouchControls.dodge_pressed or (InputMap.has_action("dodge") and Input.is_action_just_pressed("dodge")):
		TouchControls.dodge_pressed = false
		if _dodge_cd <= 0.0 and _dodge_t <= 0.0 and not Dialogue.input_blocked() and map:
			if GameState.spend_for("dodge"):
				_dodge_dir = (dir if dir != Vector2.ZERO else facing_dir()).normalized()
				_dodge_t = 0.22
				_dodge_cd = 0.6
				_busy = false
				invuln = maxf(invuln, 0.3 if Crew.perk_level("run_speed") >= 3 else 0.2)
				map.fx("lunge_trail" if Art.has("fx", "lunge_trail") else "poof", position + Vector2(0, -4), 14.0, 0.3)
	if _dodge_t > 0.0:
		_dodge_t -= delta
		_move(_dodge_dir * 165.0 * delta)
		return
	update_aim()
	# The cursor square only moves with you/your facing; refresh it 5x a second for tool/selection changes.
	_cur_acc += delta
	if position != _cur_pos or facing != _cur_face or _cur_acc >= 0.2:
		_cur_pos = position
		_cur_face = facing
		_cur_acc = 0.0
		queue_redraw()
	if _busy:
		_busy_t += delta
		if _busy_t > 1.2:
			_busy = false  # watchdog: never stay stuck in an action
	else:
		_busy_t = 0.0

	# Hoe / can held with a direction held: work a row (Stardew / Sun Haven).
	if _work_walk(dir, delta):
		return
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
		elif not _busy and _repeat_cd <= 0.0 and (Input.is_action_pressed("tool") or mouse_held or (Input.is_action_pressed("a") and TouchControls.visible_controls)) and _hold_t > 0.25 and (GameState.held_tool() in ["hoe", "can", "axe", "pickaxe", "scythe"] or GameState.is_sword(GameState.held_tool())):
			# Holding the tool button (or USE on the phone) keeps swinging.
			if mouse_held and map:
				face_toward(map.get_global_mouse_position())
			_repeat_cd = 0.3
			do_action("tool")
			return
	_repeat_cd = maxf(0.0, _repeat_cd - delta)
	# A release missed while a menu/dialogue was up must not leave the mouse "held".
	if mouse_held and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		mouse_held = false
	if Input.is_action_pressed("tool") or mouse_held or (Input.is_action_pressed("a") and TouchControls.visible_controls):
		_hold_t += delta
	else:
		_hold_t = 0.0
	# Companion ability: hold B still for a second.
	var has_ab: bool = Companion.active_id() != "" or (GameState.is_penguins() and GameState.run["flags"].has("meow_taught"))
	if TouchControls.ability_pressed and has_ab and not _busy and not Dialogue.input_blocked() and map:
		# The phone's ♥ button: one tap, no hold.
		TouchControls.ability_pressed = false
		Companion.use_ability(map, self)
	elif Input.is_action_pressed("b") and dir == Vector2.ZERO and not _busy and has_ab and not Dialogue.input_blocked():
		_ability_hold += delta
		if _ability_hold >= 1.0:
			_ability_hold = -1000.0  # fires once per hold: release B to use it again
			Companion.use_ability(map, self)
	elif not Input.is_action_pressed("b"):
		_ability_hold = 0.0
	if Input.is_action_just_pressed("b") and dir == Vector2.ZERO and not _busy and has_anim("play") and not swimming and not mounted and not has_ab and not Dialogue.input_blocked():
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
			# Tools: the work is done on the press; the swing can be walked out of
			# after a third of a second so a row of tiles doesn't feel like treacle.
			if _anim and _anim.is_playing() and not (_busy_t > 0.3 and dir != Vector2.ZERO and not _ww_on and not anim_name.begins_with("cast_") and not anim_name.begins_with("reel_")):
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
	var spd_mult := 1.0 + 0.08 * GameState.gear_stat("speed") + 0.15 * GameState.buff("speed") + GameState.move_bonus()
	if int(GameState.run["flags"].get("haste_abs", -1)) > GameState.now_abs():
		spd_mult *= 1.3
	if GameState.weather_today() in ["snow", "blizzard"] and map and map.has_sky:
		spd_mult *= 0.9
	if GameState.exhausted():
		spd_mult *= 0.85  # exhausted (under 15%): heavy feet, the HUD bar flashes red
	var vd := vehicle_def()
	if _veh and vehicle != "":
		_veh_face()
		if dir != Vector2.ZERO:
			_veh_puff -= delta
			if _veh_puff <= 0.0 and map:
				_veh_puff = 0.28
				map.fx("veh_wake" if swimming else "veh_dust", position - dir * 8.0 + Vector2(0, -2), 12.0, 0.5, dir.x > 0)
	if swimming and float(vd.get("water", 0.0)) > 0.0:
		spd_mult *= float(vd["water"])  # rowing: quick, dry, no effort
		running = false
	elif swimming:
		if vehicle != "":
			unride()  # wheels don't float
			if map:
				map.hud.toast("You hop off at the water's edge.")
		spd_mult *= 1.0 if Companion.has_ability("tail") else 0.55
		running = false
		_swim_t += delta
		if _swim_t > 2.0 and not Companion.has_ability("tail"):
			_swim_t = 0.0
			if not GameState.spend_for("swim"):
				map.player_down("tired")
	elif mounted:
		spd_mult *= (1.8 if running else 1.5) * (1.1 if Perks.flag("ride_fast") else 1.0) * (1.1 if Builds.is_built("stable") else 1.0)
	elif vehicle != "":
		var vs := float(vd.get("speed", 1.0))
		if vd.has("snow") and (GameState.season() == "winter" or (map and map.scene_id() in ["mountain", "sky", "highlands"])):
			vs = float(vd["snow"])
		spd_mult *= vs
	spd_mult *= GameState.status_speed()
	spd_mult *= 1.0 + 0.05 * mini(2, Crew.perk_level("run_speed"))
	var target := dir * (RUN_SPEED if running else WALK_SPEED) * spd_mult
	var rate := ACCEL if dir != Vector2.ZERO else DECEL
	velocity = velocity.move_toward(target, rate * delta)
	var before := position
	_move(velocity * delta)
	if dir != Vector2.ZERO and position.distance_to(before) > 0.1:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.25 if running else 0.33  # footsteps keep pace with the slower stride
			if swimming:
				_step_t = 0.7
				Music.instance(get_tree()).sfx("splash")
			elif vehicle == "":
				Music.instance(get_tree()).step(_ground_word())
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
		_sprite.rotation = 0.0
		_show_idle()
		return

	var move_dir := dir if dir != Vector2.ZERO else velocity.normalized()
	var is_run := speed > WALK_SPEED * 1.15
	var pre := ""
	if swimming and has_anim("swim") and float(vehicle_def().get("water", 0.0)) <= 0.0:
		pre = "swim"
	elif mounted and has_anim("ride"):
		pre = "ride"
	if pre != "":
		if Player.horizontal_wins(move_dir):
			facing = "left" if move_dir.x < 0 else "right"
			_apply("ride_run" if pre == "ride" and is_run and has_anim("ride_run") else pre, move_dir.x < 0)
		else:
			facing = "up" if move_dir.y < 0 else "down"
			_apply(pre + "_" + facing if has_anim(pre + "_" + facing) else pre, false)
		if _anim:
			_anim.speed_scale = 1.0
		return
	if Player.horizontal_wins(move_dir):
		facing = "left" if move_dir.x < 0 else "right"
		_sprite.position.y = 0
		_sprite.rotation = 0.0
		_apply("run" if is_run else "walk", move_dir.x < 0)
	else:
		# Vertical wins ties: a diagonal (or a thumb that drifts a little) shows
		# the character walking toward / away from you, never sideways.
		facing = "up" if move_dir.y < 0 else "down"
		var vert := ("run_" if is_run else "walk_") + facing
		if is_run and not _moving_anim(vert):
			vert = "walk_" + facing
		if _moving_anim(vert):
			_sprite.position.y = 0
			_sprite.rotation = 0.0
			_apply(vert, false)
		else:
			# No toward/away walk strip (the penguin, some villagers): the front/back
			# view waddles and bobs instead of showing the sideways walk.
			var still := vert if has_anim(vert) else ("view_back" if move_dir.y < 0 else "view_front")
			_apply(still, false)
			_bob += delta * speed * 0.16
			_sprite.position.y = -absf(sin(_bob)) * 2.0
			_sprite.rotation = sin(_bob) * 0.07
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
	if not has_anim(a) and has_anim(action + "_down"):
		a = action + "_down"
	var drawn := has_anim(a) and not CharacterLibrary.is_alias(_anim.sprite_frames, a)
	if not has_anim(a):
		# No pose for this tool at all: swing the attack frames and draw the tool.
		if not _tool_overlay(action) or not has_anim("attack"):
			return false
		a = "attack_down" if facing == "down" and has_anim("attack_down") else ("attack_up" if facing == "up" and has_anim("attack_up") else "attack")
		_attack_hit_done = true  # a work swing, not a blow
	_busy = true
	_busy_t = 0.0
	velocity = Vector2.ZERO
	_sprite.position.y = 0
	_apply(a, facing == "left", restart)
	if _anim:
		_anim.speed_scale = 1.35
		# Work swings take the same time for every hero (frame counts differ
		# from sheet to sheet): a pickaxe blow is a pickaxe blow.
		if TOOL_TIME.has(action) and _anim.sprite_frames.has_animation(a):
			var n := _anim.sprite_frames.get_frame_count(a)
			var fps := maxf(1.0, _anim.sprite_frames.get_animation_speed(a))
			_anim.speed_scale = clampf((n / fps) / float(TOOL_TIME[action]), 0.3, 3.0)
	if not drawn and _tool_overlay(action):
		var tool := GameState.held_tool()
		if tool == "" or not (GameState.TOOL_KINDS.has(tool) or GameState.items.has(tool)):
			tool = {"water": "can"}.get(action, action)
		HeldSwing.spawn(self, tool, "pour" if action == "water" else "chop", float(TOOL_TIME.get(action, 0.4)), facing)
	return true


## How long one work swing takes (seconds), for every hero alike.
const TOOL_TIME := {"pickaxe": 0.46, "axe": 0.46, "hoe": 0.4, "water": 0.5}


static func _tool_overlay(action: String) -> bool:
	return action in ["pickaxe", "axe", "hoe", "water"]


func _do_action() -> void:
	do_action("a")


## Work-walking: hold a direction and USE (or the tool key) with the hoe or the
## watering can. Each stroke lands on the cell ahead; when the swing finishes you
## take one step along the row and swing again at the next cell. Let go of USE to
## walk normally; let go of the direction to keep working in place.
var _ww_on := false          # a work row is in progress
var _ww_dir := Vector2i.ZERO # the row's direction (one axis)
var _ww_target := Vector2.INF  # cell centre we're stepping to between strokes
var _ww_need_step := false   # the last stroke is done: step before the next one
var _ww_cd := 0.0


func _work_held() -> bool:
	return Input.is_action_pressed("tool") or Input.is_action_pressed("a") or mouse_held


func _work_walk(dir: Vector2, delta: float) -> bool:
	_ww_cd = maxf(0.0, _ww_cd - delta)
	var tool := GameState.held_tool()
	var want := dir != Vector2.ZERO and tool in ["hoe", "can"] and _work_held() and not Dialogue.input_blocked() and not swimming and not mounted and vehicle == "" and map != null and auto_target == Vector2.INF
	if not want:
		if _ww_on:
			_ww_on = false
			_ww_target = Vector2.INF
			_ww_need_step = false
		return false
	var dv := Vector2i(int(signf(dir.x)), 0) if Player.horizontal_wins(dir) else Vector2i(0, int(signf(dir.y)))
	if not _ww_on:
		_ww_on = true
		_ww_need_step = false
		_ww_target = Vector2.INF
		_ww_cd = 0.0
	if dv != _ww_dir:
		# Turned: work the new way from where you stand.
		_ww_dir = dv
		_ww_target = Vector2.INF
		_ww_need_step = false
	facing = {Vector2i(1, 0): "right", Vector2i(-1, 0): "left", Vector2i(0, -1): "up"}.get(dv, "down")
	if _busy:
		return true  # let the stroke finish (the busy block below plays it out)
	if _ww_target != Vector2.INF:
		var to := _ww_target - position
		if to.length() < 1.5:
			position = _ww_target
			_ww_target = Vector2.INF
			velocity = Vector2.ZERO
		else:
			velocity = to.normalized() * WALK_SPEED * 0.9
			var before := position
			_move(velocity * delta)
			_apply(("walk_" + facing) if facing in ["up", "down"] and has_anim("walk_" + facing) else "walk", facing == "left")
			if position.distance_to(before) < 0.05:
				_ww_target = Vector2.INF  # something in the way: work from here
			return true
	if _ww_need_step:
		_ww_need_step = false
		var nc := cell() + dv
		var fc := nc + dv
		# Step only onto open ground with something workable (or open) beyond it.
		if not map.blocked.has(nc) and map.in_content(nc) and not map.blocked.has(fc) and not map._exit_at(nc):
			_ww_target = map.cell_center(nc)
			return true
	if _ww_cd > 0.0:
		_show_idle()
		return true
	_ww_cd = 0.12
	aim_cell = Vector2i(-1, -1)
	do_action("tool")
	_ww_need_step = true
	return true


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
	if vehicle != "" and mode != "action":
		if map and map.try_interact(facing_cell()):
			return
		unride()
		if map:
			map.hud.toast("You hop off.")
		return
	var held := GameState.held_tool()
	if mode == "tool" and (held in ["sword", ""] or GameState.items.get(held, {}).has("range")):
		_swing()
		return
	# A foe right in front: the fight comes first, not the weed under its feet.
	# Any tool but the rod and the can still lands a blow on a foe right in front of you.
	if mode != "action" and (held in ["sword", ""] or (held != "rod" and held != "can" and GameState.has_tool(held))) and _enemy_in_front(26.0):
		_swing()
		return
	# Only CHECK (mode "action") may open the pup's menu: USE never does.
	if map and map.try_interact(facing_cell(), mode == "action"):
		velocity = Vector2.ZERO
		if not _busy:
			_show_idle()
		return
	# Standing on a door/exit-type thing (you walked onto it): A uses it.
	if map and map.things.has(cell()) and str(map.things[cell()].get("type", "")) in ["door", "idoor", "exit", "mine", "cave", "pad"] and map.try_interact(cell()):
		velocity = Vector2.ZERO
		return
	# A ladder / shaft down on your cell or any of the 8 around it: no need to
	# line up exactly, USE takes it (GameMap.descent_near).
	if map:
		var dc: Vector2i = map.descent_near(cell())
		if dc != Vector2i(-1, -1):
			face_toward(map.cell_center(dc))
			velocity = Vector2.ZERO
			map.try_interact(dc)
			return
	if mode == "action":
		# Point the pup at an enemy.
		var e := map.nearest_enemy_to(position + facing_dir() * 16.0, 24.0)
		if e and map.pet is Pet and map.pet.visible:
			(map.pet as Pet).set_mode("attack")
			(map.pet as Pet)._target = e
		return
	if held == "rod":
		# The rod only casts into water: say so instead of a cast at the grass.
		ToolHint.say(map, "Face water and tap USE to cast.")
		return
	if held == "" and str(GameState.items.get(str(GameState.run["selected"]), {}).get("type", "")) == "seed" and GameState.count(str(GameState.run["selected"])) > 0:
		# Seeds in hand: never a punch. Point at tilled soil instead.
		ToolHint.say(map, "Seeds go in tilled soil: till grass on your farm with the hoe first." if map and map.scene_id() == "farm" else "Seeds go in tilled soil on your farm.")
		return
	if held in ["hoe", "can", "axe", "pickaxe", "rod", "scythe"]:
		# Swinging a farm tool at nothing: show the swing anyway, it reads as "nothing here".
		var act: String = {"hoe": "hoe", "can": "water", "axe": "axe", "pickaxe": "pickaxe", "rod": "cast", "scythe": "axe"}[held]
		if play_tool(act):
			return
		return
	if held == "" or GameState.is_sword(held):
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
	GameState.spend_for("sword")  # a little energy per swing (fists and tools too)
	_busy = true
	_busy_t = 0.0
	_attack_cd = 0.3 * GameState.status_swing() * float(GameState.items.get(GameState.held_tool(), {}).get("cd", 1.0))
	_attack_hit_done = false
	_combo = 1 if Time.get_ticks_msec() - _last_swing_ms > 1200 else (_combo + 1) % 3
	_last_swing_ms = Time.get_ticks_msec()
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
	# Empty-handed attack frames (the gangster outfits): draw the blade or club.
	var hw := GameState.held_tool()
	if CharacterLibrary.unarmed_attack(char_id) and hw != "" and GameState.is_sword(hw) and not GameState.items.get(hw, {}).has("range"):
		HeldSwing.spawn(self, hw, "sweep", 0.2, facing)
	_attack_hit()
	if _anim == null:
		_busy = false


var _step_t := 0.0


## Which footstep sound fits the ground under us.
## Which report a gun makes: shotguns boom, rifles crack, the rest pop.
func _gun_sound() -> String:
	var w := GameState.equipped("weapon").to_lower()
	if "shotgun" in w or "blunder" in w or "scatter" in w:
		return "shot_shotgun"
	if "rifle" in w or "sniper" in w or "long" in w:
		return "shot_rifle"
	if "laser" in w or "ray" in w or "plasma" in w:
		return "laser"
	return "shot"


func _ground_word() -> String:
	var m := get_parent() as GameMap
	return Footsteps.word(m, m.world_to_cell(position) if m else Vector2i.ZERO, swimming)


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
	_update_wade()
	if swimming and not was:
		map.fx("splash", position, 12.0, 0.5)
		Music.instance(get_tree()).sfx("splash", "bite")
	elif was and not swimming:
		map.fx("splash", position, 12.0, 0.4)


var _wade: Node2D


## In water without a boat, the lower body sits under the surface: a band of
## water with a ripple edge is drawn over the legs.
func _update_wade() -> void:
	var on := swimming and float(vehicle_def().get("water", 0.0)) <= 0.0
	if on and _wade == null:
		_wade = Node2D.new()
		_wade.z_index = 1
		_wade.draw.connect(func() -> void:
			# Tinted to the water you stand in (navy sea, green-grey river, brown bog).
			var th: Dictionary = map.things.get(cell(), {}) if map else {}
			var sh := "sand" if str(th.get("type", "")) == "sea" else str(th.get("shore", map.border_water_shore if map else ""))
			var col: Color = {"sand": Color(0.10, 0.26, 0.48, 0.85), "quay": Color(0.10, 0.26, 0.48, 0.85), "river": Color(0.12, 0.30, 0.42, 0.85), "bog": Color(0.33, 0.30, 0.2, 0.95)}.get(sh, Color(0.13, 0.45, 0.50, 0.85))
			var t := Time.get_ticks_msec() / 300.0
			_wade.draw_rect(Rect2(-6, -9, 12, 9), col)
			_wade.draw_circle(Vector2(-6, -4.5), 4.5, col)
			_wade.draw_circle(Vector2(6, -4.5), 4.5, col)
			for i in 5:
				_wade.draw_circle(Vector2(-8 + i * 4, -9 + sin(t + i) * 0.8), 2.2, col)
			_wade.draw_arc(Vector2(0, -8), 11.0, PI * 1.05, PI * 1.95, 12, Color(1, 1, 1, 0.5), 1.0))
		add_child(_wade)
	if _wade:
		_wade.visible = on
		if on:
			_wade.queue_redraw()


func _attack_hit() -> void:
	_attack_hit_done = true
	if map:
		var center := position + facing_dir() * 12.0 + Vector2(0, -6)
		var aim := GameState.status_aim()
		if aim > 0.0:
			center += facing_dir().orthogonal() * randf_range(-aim, aim)
		var wd: Dictionary = GameState.items.get(GameState.held_tool(), {})
		if wd.has("range"):
			if GameState.count("rounds") > 0:
				_fire(wd, aim)
				return
			Music.instance(get_tree()).sfx("dry_click")
			if not _dry_told:
				_dry_told = true
				map.hud.toast("Click. Out of rounds: the Street Armory makes more.", Color(1, 0.85, 0.6))
		var box := Rect2(center - Vector2(14, 14), Vector2(28, 28))
		var dmg := GameState.sword_damage() + (1 if _combo == 0 else 0) + GameState.status_damage_mod()
		if wd.has("range"):
			dmg = int(dmg / 2)  # swung like a club
		dmg = GameState.tool_fight_damage(GameState.held_tool(), dmg)  # Tom: a pickaxe is no sword
		var hit := map.attack_at(box, maxi(1, dmg), position)
		if hit and _combo == 0 and Crew.perk_level("sword") >= 3:
			map.attack_at(box, maxi(1, dmg), position, false)  # Vic's twin strike (one whoosh)
		if hit:
			_last_hit_enemy = map.nearest_enemy_to(center, 22.0)
			if GameState.tool_fight_damage(GameState.held_tool(), 10) < 10 and not GameState.run["flags"].has("tip_tool_fight"):
				GameState.run["flags"]["tip_tool_fight"] = true
				ToolHint.say(map, "Tools only scratch foes: hold your sword to fight.")
		_swing_arc(center)
		if hit:
			map.hitstop = maxf(map.hitstop, 0.05)  # attack_at already shook the camera


var _dry_told := false


## A shot: one round, the first enemy down the line (everyone close, for a
## scattergun). A flash, a tracer and a puff of dust; nothing graphic.
func _fire(wd: Dictionary, aim: float) -> void:
	GameState.add_item("rounds", -1)
	if CharacterLibrary.unarmed_attack(char_id):
		HeldSwing.spawn(self, GameState.held_tool(), "aim", 0.16, facing)
	_dry_told = false
	var dir := facing_dir()
	var muzzle := position + dir * 10.0 + Vector2(0, -8)
	var reach := float(wd.get("range", 100.0))
	var dmg := maxi(1, GameState.sword_damage() + GameState.status_damage_mod() + int(GameState.bonus("hustle", "gun_damage")))
	var targets: Array = []
	for e in map.enemies:
		if not is_instance_valid(e):
			continue
		if not map.line_clear(muzzle, e.position + Vector2(0, -6)):
			continue  # no shooting through walls
		var to: Vector2 = e.position + Vector2(0, -6) - muzzle
		var along := to.dot(dir)
		var off := absf(to.dot(dir.orthogonal()))
		if along < -4.0 or along > reach:
			continue
		if off <= (along * 0.6 + 12.0 if bool(wd.get("spread", false)) else maxf(5.0, 13.0 - aim)):  # dazed: harder to hit, not easier
			targets.append([along, e])
	targets.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	if not bool(wd.get("spread", false)) and targets.size() > 1:
		targets = [targets[0]]
	var end := map.line_end(muzzle, muzzle + dir * reach)
	var hit := false
	for t in targets:
		var e: Node2D = t[1]
		if not bool(wd.get("spread", false)):
			end = e.position + Vector2(0, -6)
		if map.attack_at(Rect2(e.position + Vector2(-1, -8), Vector2(2, 2)), dmg, position, false):  # just this foe, not its neighbours
			hit = true
			map.fx("poof", e.position + Vector2(0, -8), 8.0, 0.3)
	var ln := Line2D.new()
	ln.width = 1.0
	ln.default_color = Color(1, 0.95, 0.6, 0.9)
	ln.points = PackedVector2Array([muzzle, end])
	ln.z_index = 4
	map.add_child(ln)
	var tw := ln.create_tween()
	tw.tween_property(ln, "modulate:a", 0.0, 0.09)
	tw.tween_callback(ln.queue_free)
	map.fx("sparkle", muzzle, 6.0, 0.15)
	Music.instance(get_tree()).sfx(_gun_sound(), "shot")
	if hit:
		map.hitstop = maxf(map.hitstop, 0.03)
	map.shake(1.0)


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
	# The third swing of a combo (+1 damage) lands with a full crescent, so the
	# rhythm USE-USE-USE reads on screen.
	if _combo == 0 and Art.has("fx", "slash"):
		var sl := AnimatedSprite2D.new()
		sl.sprite_frames = Art.frames("fx", {"slash": "slash"}, {"slash": 32.0}, {"slash": false})
		sl.animation = "slash"
		sl.position = center
		sl.rotation = ang
		sl.scale = Vector2(0.42, 0.42)
		sl.z_index = 3
		get_parent().add_child(sl)
		sl.play("slash")
		sl.animation_finished.connect(sl.queue_free)


func take_damage(n: int, from: Vector2) -> void:
	if invuln > 0.0:
		return
	if randf() < GameState.bonus("combat", "block"):
		invuln = 0.4
		if map:
			map.hud.toast("Blocked!", Color(0.8, 0.9, 1.0))
			Music.instance(get_tree()).sfx("dry_click", "thud")
		return
	if int(GameState.run["flags"].get("shield", 0)) > 0:
		GameState.run["flags"]["shield"] = int(GameState.run["flags"]["shield"]) - 1
		invuln = 0.5
		if map:
			map.hud.toast("Shield!", Color(0.8, 0.9, 1.0))
			Music.instance(get_tree()).sfx("zap", "thud")
			map.fx("sparkle", position + Vector2(0, -12), 14.0, 0.5)
		return
	# Armour scales: every point helps, none makes you untouchable.
	var defn := GameState.gear_stat("defense") + mini(2, Crew.perk_level("defence")) + int(GameState.buff("defense")) + (2 if Colony.has_ability("coral_ward") else 0)
	n = maxi(1, roundi(n * 60.0 / (60.0 + 2.5 * maxf(0.0, defn))))
	n = maxi(1, int(n * (1.0 - minf(0.45, GameState.bonus("combat", "damage_reduction") + GameState.bonus("magic", "damage_reduction")))))
	if Settings.easy():
		n = maxi(1, roundi(n * 0.6))
	if GameState.has_team():
		n = maxi(1, roundi(n * (1.0 - minf(0.4, GameState.bonus("leadership", "team_defense")))))
	# Short mercy window: enough to not get chain-hit by one enemy, not enough to
	# tank a crowd. The knockback is shorter too, so you can't bounce to safety.
	invuln = 0.35
	_flash = 1.0
	GameState.run["hp"] = int(GameState.run["hp"]) - n
	_last_stand()
	if int(GameState.run["hp"]) > 0 and int(GameState.run["hp"]) < int(GameState.run.get("max_hp", 100)) / 4:
		Music.instance(get_tree()).sfx("heartbeat")
	PupIntro.low_hp_tip(map)  # once per run: how to heal
	velocity = (position - from).normalized() * (60.0 if Crew.perk_level("defence") >= 3 else 120.0)
	auto_target = Vector2.INF
	# Doc patches you mid-fight once per map when you're in trouble.
	if Crew.perk_level("status_half") >= 3 and int(GameState.run["hp"]) > 0 and int(GameState.run["hp"]) < int(GameState.run["max_hp"]) * 0.2 and map and not map.has_meta("doc_patched"):
		map.set_meta("doc_patched", true)
		GameState.run["hp"] = int(GameState.run["hp"]) + int(int(GameState.run["max_hp"]) * 0.3)
		map.hud.toast("Doc: \"Hold still.\" Patched up mid-fight.", Color(0.7, 1, 0.8))
	_busy = false
	Music.instance(get_tree()).sfx("hurt")
	if map:
		map.hitstop = maxf(map.hitstop, 0.06)
		map.shake(3.0)
		map.damage_number(position + Vector2(0, -22), n, Color(1, 0.35, 0.3))
	if int(GameState.run["hp"]) <= 0 and map:
		map.player_down()


## Not Today (Combat): once a day a knockout (hit or status tick) leaves you on 1 HP,
## with poison/burn washed off and a moment where the hit's own status can't stick.
func _last_stand() -> void:
	if int(GameState.run["hp"]) > 0 or GameState.bonus("combat", "last_stand") <= 0 or int(GameState.run["flags"].get("last_stand_day", -1)) == int(GameState.run["day"]):
		return
	GameState.run["flags"]["last_stand_day"] = int(GameState.run["day"])
	GameState.run["hp"] = 1
	invuln = 1.0
	GameState.status_clear()
	_status_shield = 1.5
	if map:
		map.hud.toast("Not today!", Color(1, 0.85, 0.4))
		map.fx("sparkle", position + Vector2(0, -12), 14.0, 0.6)


func _puff(back: Vector2) -> void:
	var d := Node2D.new()
	d.position = position + back * 3.0
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
	if swimming and (has_anim("float") or has_anim("swim")):
		_apply("float" if has_anim("float") else "swim", facing == "left")
		return
	if mounted and has_anim("ride"):
		var ra: String = {"up": "ride_up", "down": "ride_down"}.get(facing, "ride")
		_apply(ra if has_anim(ra) else "ride", facing == "left")
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


## Is a live enemy within `dist` and roughly where you face?
func _enemy_in_front(dist: float) -> bool:
	if map == null:
		return false
	var fd := facing_dir()
	for e in map.enemies:
		if is_instance_valid(e) and e._alive:
			var to: Vector2 = e.position - position
			if to.length() <= dist and (to.length() < 6.0 or to.normalized().dot(fd) > 0.3):
				return true
	return false

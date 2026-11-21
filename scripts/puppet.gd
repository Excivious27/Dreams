class_name Puppet
extends Node2D
## A remote player in your scene: the same Player visuals, driven by Net.peers.

var peer_id := -1
var _p: Player
var _label: Label
var _target := Vector2.ZERO
var _last_look := ""
# C11b P3 (c11b_08-11): a light trailing sprite for the peer's active partner and pup (no gameplay).
var _pal: Node2D
var _pal_id := ""
var _pup: AnimatedSprite2D
var _pup_kind := "-"


func setup(id: int, m: GameMap) -> void:
	peer_id = id
	var info: Dictionary = Net.peers.get(id, {})
	_p = Player.new()
	_p.map = m
	_p.frozen = true
	_p.is_puppet = true
	add_child(_p)
	_apply_look(info)
	_label = Label.new()
	_label.text = str(info.get("name", "Player"))
	_label.add_theme_font_size_override("font_size", 7)
	_label.add_theme_color_override("font_color", Color(1, 1, 0.9))
	_label.add_theme_constant_override("outline_size", 2)
	_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.05))
	_label.position = Vector2(-30, -40)
	_label.size = Vector2(60, 10)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	y_sort_enabled = true
	if info.has("pos"):
		position = Vector2(float(info["pos"][0]), float(info["pos"][1]))
		_target = position


func _apply_look(info: Dictionary) -> void:
	var lkv: Variant = info.get("look", {})
	var lk: Dictionary = lkv if lkv is Dictionary else {}
	var key := JSON.stringify(lk)
	if key == _last_look:
		return
	_last_look = key
	# The friend's look/equip/wardrobe stand in for the run's while the Player builds and
	# re-pins the doll (Player.with_look), so they never wear your clothes (c10b_11-13).
	_p.peer_look = lk
	_p.with_look(func() -> void:
		_p.set_character(GameState.sprite_for_playable(str(GameState.run.get("playable", "")), str(lk.get("arc", "")))))


func _process(delta: float) -> void:
	var info: Dictionary = Net.peers.get(peer_id, {})
	if info.is_empty():
		queue_free()
		return
	_apply_look(info)
	if info.has("pos"):
		_target = Vector2(float(info["pos"][0]), float(info["pos"][1]))
	var to := _target - position
	if to.length() > 120.0:
		position = _target
	else:
		position = position.lerp(_target, minf(1.0, delta * 12.0))
	var an := str(info.get("anim", "idle"))
	if _p._anim and _p._anim.sprite_frames and _p._anim.sprite_frames.has_animation(an):
		if _p._anim.animation != an:
			_p._anim.play(an)
		_p._anim.flip_h = bool(info.get("flip", false))
		_p.anim_name = an
	_p._update_doll()
	_followers(info, an)


func _followers(info: Dictionary, an: String) -> void:
	var pal := str(info.get("pal", ""))
	if pal != _pal_id:
		_pal_id = pal
		if _pal:
			_pal.queue_free()
			_pal = null
		if pal != "":
			_pal = make_pal(pal)
			if _pal:
				_pal.position = Vector2(14, 6)
				add_child(_pal)
	var lkv: Variant = info.get("look", {})
	var lk: Dictionary = lkv if lkv is Dictionary else {}
	var inner: Dictionary = lk.get("look", {}) if lk.get("look", null) is Dictionary else {}
	var kind := str(inner.get("pet", "")) if bool(info.get("pup", false)) else "-"
	if kind != _pup_kind:
		_pup_kind = kind
		if _pup:
			_pup.queue_free()
			_pup = null
		if kind != "-":
			_pup = make_pup(kind)
			_pup.position = Vector2(-14, 4)
			add_child(_pup)
	var moving := an.begins_with("walk") or an.begins_with("run")
	var flip := bool(info.get("flip", false))
	for s: Variant in [_pal, _pup]:
		var sp: AnimatedSprite2D = null
		if s is AnimatedSprite2D:
			sp = s
		elif s is Node2D:
			for ch in (s as Node2D).get_children():
				if ch is AnimatedSprite2D:
					sp = ch
		if sp and sp.sprite_frames:
			var want := "walk" if moving and sp.sprite_frames.has_animation("walk") else "idle"
			if sp.sprite_frames.has_animation(want) and sp.animation != want:
				sp.play(want)
			sp.flip_h = flip


## The partner's look, as Companion.setup draws it (cat/dog strips or a character sprite).
static func make_pal(cid: String) -> Node2D:
	var d: Dictionary = Companion.defs().get(cid, {})
	var sprite := str(d.get("sprite", "man"))
	var holder := Node2D.new()
	var a: AnimatedSprite2D
	if (sprite.begins_with("cat_") or sprite.begins_with("dog_")) and Art.has("animals/" + sprite, "idle"):
		a = AnimatedSprite2D.new()
		a.sprite_frames = Art.frames("animals/" + sprite, {"idle": "idle", "walk": "walk"}, {"idle": 2.0, "walk": 8.0})
		a.scale = Vector2(0.5, 0.5)
		var tex := a.sprite_frames.get_frame_texture("idle", 0)
		if tex:
			a.offset = Vector2(0, -tex.get_height() / 2.0)
	else:
		a = CharacterLibrary.make_sprite(sprite if CharacterLibrary.has_character(sprite) else "man")
	if d.has("tint"):
		a.modulate = Color(str(d["tint"]))
	holder.add_child(a)
	a.play("idle")
	return holder


## The peer's pup or cat ("" = the classic pup), the size GameMap gives yours.
static func make_pup(kind: String) -> AnimatedSprite2D:
	if kind != "" and Art.has("animals/" + kind, "idle"):
		var a := AnimatedSprite2D.new()
		a.sprite_frames = Art.frames("animals/" + kind, {"idle": "idle", "walk": "walk"}, {"idle": 2.0, "walk": 8.0})
		var ih := float(Art.info("animals/" + kind, "idle").get("cell_h", 60))
		var ps := clampf(17.0 / maxf(20.0, ih), 0.12, 0.5)
		a.scale = Vector2(ps, ps)
		var tex := a.sprite_frames.get_frame_texture("idle", 0)
		if tex:
			a.offset = Vector2(0, -tex.get_height() / 2.0)
		a.play("idle")
		return a
	var d := CharacterLibrary.make_sprite("dog")
	d.play("idle")
	return d

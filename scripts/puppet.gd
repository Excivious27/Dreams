class_name Puppet
extends Node2D
## A remote player in your scene: the same Player visuals, driven by Net.peers.

var peer_id := -1
var _p: Player
var _label: Label
var _target := Vector2.ZERO
var _last_look := ""


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

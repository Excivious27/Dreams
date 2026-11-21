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
# C17 P5: swings, vehicles, busy cue (fields the state packet carries: act {seq,tool,kind,dur,spd}, veh, busy).
var _act_seq := -1
var _veh := ""
var _busy: Node2D
const TAG_MAX := 12
# P3's PuppetSmooth (scripts/puppet_smooth.gd: jitter buffer / seq order / teleport), loaded by
# path so this file compiles before P3's branch is merged; null = the old lerp.
var _sm: Object = null
var _step_t := 0.0
var _look_ref: Variant = null  # the look Dictionary last applied (skips the per-frame JSON compare)
const STEP_GAP := 0.34
const STEP_NEAR := 110.0  # partner footsteps heard only near you (c17_09-08)  # name tag characters before an ellipsis


## The peer's info (router peers may be keyed by String or int).
func _info() -> Dictionary:
	var pl: Dictionary = Net.peers  # the live state (pos/anim/look); the router's roster is a summary
	var v: Variant = pl.get(peer_id, pl.get(str(peer_id), {}))
	return v if v is Dictionary else {}


## Name tag text: filtered, printable letters only (no zero-width / RTL / emoji), clamped,
## the host marked (c17_09-06, c17_09-22, c17_14-10).
static func tag_text(raw: String, host := false) -> String:
	var t := ""
	for ch in raw:
		var c := ch.unicode_at(0)
		if c >= 32 and c < 0x2000:  # Latin, Greek, Cyrillic...; drops control, zero-width, RTL marks, emoji
			t += ch
	t = NameFilter.clean(t.strip_edges(), "Player")
	if t.length() > TAG_MAX:
		t = t.substr(0, TAG_MAX - 1) + "…"
	return ("Host " if host else "") + t


func setup(id: int, m: GameMap) -> void:
	peer_id = id
	add_to_group("net_puppet")
	var info: Dictionary = _info()
	_p = Player.new()
	_p.map = m
	_p.frozen = true
	_p.is_puppet = true
	add_child(_p)
	_apply_look(info)
	_label = Label.new()
	var rs: Variant = CoopPanel.peer_list().get(str(id), {})
	_label.text = tag_text(str(info.get("name", "Player")), rs is Dictionary and bool((rs as Dictionary).get("host", false)))  # s1_13-03: a peer's typed name
	_label.add_theme_font_size_override("font_size", Settings.font(7))
	_label.add_theme_color_override("font_color", Color(1, 1, 0.9))
	_label.add_theme_constant_override("outline_size", 2)
	_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.05))
	_label.position = Vector2(-40, -44)
	_label.size = Vector2(80, 10)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.z_index = 50  # above props and roofs (it was hidden behind them by y-sort)
	_label.z_as_relative = false
	add_child(_label)
	y_sort_enabled = true
	if info.has("pos"):
		position = Vector2(float(info["pos"][0]), float(info["pos"][1]))
		_target = position
	else:
		visible = false  # no position yet: wait for the first state instead of popping in at (0,0)
	if ResourceLoader.exists("res://scripts/puppet_smooth.gd"):
		var sc: Variant = load("res://scripts/puppet_smooth.gd")
		if sc is Script:
			_sm = (sc as Script).new()
			if _sm.has_method("reset"):
				_sm.call("reset", position)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)  # fade in on arrival


func _apply_look(info: Dictionary) -> void:
	var lkv: Variant = info.get("look", {})
	if lkv != null and is_same(lkv, _look_ref):
		return  # same Dictionary as last frame: nothing new arrived (c17_09-15)
	_look_ref = lkv
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
	var info: Dictionary = _info()
	if info.is_empty():
		queue_free()
		return
	_apply_look(info)
	if info.has("pos"):
		_target = Vector2(float(info["pos"][0]), float(info["pos"][1]))
		if not visible:
			visible = true
			position = _target
	var an := str(info.get("anim", "idle"))
	if _sm != null:
		position = _sm.call("step", delta, _target, int(info.get("seq", -1)), bool(info.get("tp", false)))
		if not bool(_sm.call("moving")) and (an.begins_with("walk") or an.begins_with("run")):
			an = "idle" + an.substr(an.find("_")) if an.find("_") >= 0 else "idle"
		modulate.a = 0.55 if float(_sm.call("silent_for")) > 3.0 else 1.0
	else:
		var to := _target - position
		if to.length() > 120.0:
			position = _target
		else:
			position = position.lerp(_target, minf(1.0, delta * 12.0))
	if _p._anim and _p._anim.sprite_frames and _p._anim.sprite_frames.has_animation(an):
		if _p._anim.animation != an:
			_p._anim.speed_scale = 1.0  # a swing's speed ends with the swing
			_p._anim.play(an)
		_p._anim.flip_h = bool(info.get("flip", false))
		if info.has("facing") and str(info["facing"]) != _p.facing:
			_p.facing = str(info["facing"])
			if _veh != "":
				_p._veh_face()
		_p.anim_name = an
	_p._update_doll()
	_p.set("_frozen_idle", 0.0)  # a puppet is frozen on purpose: never trip the 12 s freeze-safety (c17_09-19)
	_followers(info, an)
	_actions(info, an)
	_steps(delta, an)


func _steps(delta: float, an: String) -> void:
	if not (an.begins_with("walk") or an.begins_with("run")) or _p.map == null or _p.map.player == null:
		_step_t = 0.0
		return
	_step_t += delta
	if _step_t < STEP_GAP:
		return
	_step_t = 0.0
	if position.distance_to(_p.map.player.position) > STEP_NEAR or _veh != "":
		return
	var m := _p.map
	Music.instance(get_tree()).step(Footsteps.word(m, m.world_to_cell(position), false))


## C17 P5 (c17_09-02/03, c17_09-17): a new swing restarts the anim at the swing's speed with the
## held tool drawn; the vehicle follows `veh`; a "..." bubble while the partner is in a menu.
func _actions(info: Dictionary, an: String) -> void:
	var av: Variant = info.get("act", null)
	if av is Dictionary:
		var a: Dictionary = av
		var sq := int(a.get("seq", -1))
		if sq != _act_seq:
			_act_seq = sq
			swing(str(a.get("tool", "")), str(a.get("kind", "chop")), float(a.get("dur", 0.4)), float(a.get("spd", 1.0)), an)
	var veh := str(info.get("veh", ""))
	if veh != _veh:
		_veh = veh
		# Player.ride/unride write run.flags.vehicle: keep OUR flag (the puppet must never change it).
		var fl: Variant = GameState.run.get("flags", null)
		var had: Variant = (fl as Dictionary).get("vehicle", null) if fl is Dictionary else null
		if veh != "":
			_p.ride(veh, true)
		else:
			_p.unride(true)
		if fl is Dictionary:
			if had == null:
				(fl as Dictionary).erase("vehicle")
			else:
				(fl as Dictionary)["vehicle"] = had
	var busy := bool(info.get("busy", false))
	if busy and _busy == null and Art.has("emotes", "bubble_dots"):
		var b := AnimatedSprite2D.new()
		b.sprite_frames = Art.frames("emotes", {"e": "bubble_dots"}, {"e": 4.0})
		b.animation = "e"
		b.scale = Vector2(0.5, 0.5)
		b.position = Vector2(0, -50)
		b.z_index = 45
		add_child(b)
		b.play("e")
		_busy = b
	elif not busy and _busy:
		_busy.queue_free()
		_busy = null


## One swing (also called by tests): restart even when the anim name is the same.
func swing(tool: String, kind: String, dur: float, spd: float, an := "") -> void:
	if _p._anim == null or _p._anim.sprite_frames == null:
		return
	var nm: String = an if an != "" else _p._anim.animation
	if _p._anim.sprite_frames.has_animation(nm):
		_p._anim.speed_scale = clampf(spd, 0.5, 3.0)
		_p._anim.stop()
		_p._anim.play(nm)
		_p._anim.frame = 0
	if tool != "" and kind in ["chop", "pour", "sweep", "aim"]:
		HeldSwing.spawn(_p, tool, kind, clampf(dur, 0.1, 1.0), str(_p.facing) if "facing" in _p else "down")


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

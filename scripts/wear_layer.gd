class_name WearLayer
extends Node2D
## Paper-doll gear overlays: one AnimatedSprite2D per worn piece (art/gen/wear/<set>_<part>),
## kept in step with the player's animation, frame and facing. Layers are drawn at
## the ratio between the sheet's 64px body and the character's own height.

const PARTS := ["belt", "cape", "legs", "boots", "chest", "gloves", "helm", "shield"]
const ANIM_MAP := {"idle": "idle", "view_front": "idle", "view_back": "view_back", "view_right": "view_right", "view_left": "view_right", "walk": "walk", "run": "run", "walk_down": "walk_down", "walk_up": "walk_up", "run_down": "walk_down", "run_up": "walk_up"}

var player: Player
var _layers := {}  # part -> AnimatedSprite2D
var _sets := {}    # part -> set name
var _body_h := 74.0


## Off until on-body layer sheets exist (the current wear/* sheets are icon-style, not positioned on the body).
const ENABLED := false


func refresh() -> void:
	if not ENABLED:
		return
	# Which set each slot wears (equipment ids like "iron_chest", "leather_helm"...)
	var want := {}
	for slot in GameState.SLOTS:
		var id := GameState.equipped(slot)
		if id == "":
			continue
		for part in PARTS:
			if id.ends_with("_" + part) or id.ends_with("_" + part + "_plus"):
				var setn := id.trim_suffix("_plus").trim_suffix("_" + part)
				if Art.has("wear/%s_%s" % [setn, part], "idle"):
					want[part] = setn
	# Also map our older gear ids onto sets.
	var alias := {"iron_helm": ["helm", "iron"], "iron_mail": ["chest", "iron"], "iron_greaves": ["legs", "iron"], "leather_cap": ["helm", "leather"], "leather_vest": ["chest", "leather"], "boots": ["boots", "leather"], "crystal_crown": ["helm", "silver"], "crystal_plate": ["chest", "silver"]}
	for slot in GameState.SLOTS:
		var id := GameState.equipped(slot)
		if alias.has(id):
			var a: Array = alias[id]
			if Art.has("wear/%s_%s" % [a[1], a[0]], "idle"):
				want[str(a[0])] = str(a[1])
	for part in PARTS:
		if not want.has(part) and _layers.has(part):
			(_layers[part] as Node).queue_free()
			_layers.erase(part)
			_sets.erase(part)
		elif want.has(part) and _sets.get(part, "") != want[part]:
			if _layers.has(part):
				(_layers[part] as Node).queue_free()
			var g := "wear/%s_%s" % [want[part], part]
			var sp := AnimatedSprite2D.new()
			sp.sprite_frames = Art.frames(g, {"idle": "idle", "view_back": "view_back", "view_right": "view_right", "walk": "walk", "walk_down": "walk_down", "walk_up": "walk_up", "run": "run"}, {"idle": 1.0, "walk": 8.0, "walk_down": 8.0, "walk_up": 8.0, "run": 10.0, "view_back": 1.0, "view_right": 1.0})
			sp.animation = "idle"
			sp.centered = true
			# 64px body on a 96px cell; our character is _body_h tall at 0.5 scale
			var k := (_body_h / 64.0) * 0.5
			sp.scale = Vector2(k, k)
			sp.offset = Vector2(0, -48.0 + 4.0)
			sp.z_index = 1 if part != "cape" else -1
			add_child(sp)
			_layers[part] = sp
			_sets[part] = want[part]


func _process(_delta: float) -> void:
	if player == null or _layers.is_empty():
		return
	var pa: AnimatedSprite2D = player._anim
	if pa == null:
		return
	var base := str(ANIM_MAP.get(player.anim_name, ""))
	if base == "":
		# tool/attack animations: hold the facing pose
		base = {"up": "view_back", "left": "view_right", "right": "view_right"}.get(player.facing, "idle")
	var flip := pa.flip_h or player.facing == "left"
	for part in _layers:
		var sp: AnimatedSprite2D = _layers[part]
		if sp.animation != base and sp.sprite_frames.has_animation(base):
			sp.animation = base
		var n := sp.sprite_frames.get_frame_count(sp.animation)
		if n > 1:
			sp.frame = pa.frame % n
		sp.flip_h = flip
		sp.modulate = pa.modulate
		sp.position = player._sprite.position

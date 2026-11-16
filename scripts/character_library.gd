class_name CharacterLibrary
extends RefCounted
## Builds SpriteFrames for each character from art/characters/characters.json.
## Strips are 2x detail, so sprites are drawn at 0.5 scale.

const ROOT := "res://art/characters/"
const ORDER: Array[String] = ["man", "woman", "son", "girl", "dog"]
const DISPLAY_NAMES := {"man": "Man", "woman": "Woman", "son": "Son", "girl": "Girl", "dog": "Dog"}
const STRIP := "map_large"
const SPRITE_SCALE := 0.5
const VIEW_NAMES: Array[String] = ["view_front", "view_right", "view_back", "view_left"]
const FPS := {"idle": 4.0, "walk": 8.0, "run": 12.0, "attack": 10.0, "play": 8.0, "walk_down": 8.0, "walk_up": 8.0, "run_down": 12.0, "run_up": 12.0, "sit": 3.0, "dig": 8.0, "powerup": 8.0, "hurt": 6.0, "speak": 6.0, "charge": 6.0}
const LOOPS := {"attack": false, "powerup": false, "hurt": false}
## Tool-use actions (from Tom's tool sheets), each with _down/_right/_up strips.
const TOOL_ACTIONS := ["hoe", "water", "axe", "pickaxe", "cast", "reel", "hold", "eat"]
const TOOL_FPS := {"hoe": 10.0, "water": 8.0, "axe": 10.0, "pickaxe": 10.0, "cast": 8.0, "reel": 8.0, "hold": 8.0, "eat": 6.0}
## Characters that exist only in art/gen (no pack folder). Value = the strips to load.
const GEN_ONLY := {
	"penguin": ["idle", "walk", "run", "attack", "powerup", "view_front", "view_right", "view_back", "view_left"],
	"man_gang": ["walk", "walk_down", "attack", "hurt", "view_front", "view_right", "view_back", "view_left"],
	"son_gang": ["walk", "walk_down", "attack", "hurt", "view_front", "view_right", "view_back", "view_left"],
	"president": ["idle", "attack", "charge", "hurt", "view_front", "view_right", "view_back", "view_left"],
	"light_crystal": ["idle", "speak"],
	"barnaby": ["view_front", "walk_down"], "greta": ["view_front", "walk_down"], "wren": ["view_front", "walk_down"], "alder": ["view_front", "walk_down"],
	"finn": ["view_front", "walk_down"], "lumi": ["view_front", "walk_down"], "theo": ["view_front", "walk_down"], "hazel": ["view_front", "walk_down"],
	"riley": ["view_front", "walk_down"], "manny": ["view_front", "walk_down"], "eli": ["view_front", "walk_down"], "jax": ["view_front", "walk_down"], "vex": ["view_front", "walk_down"], "nico": ["view_front", "walk_down"],
	"cyber": ["idle", "attack", "hurt", "view_front", "view_right", "view_back", "view_left"], "brute": ["idle", "attack", "hurt", "view_front", "view_right", "view_back", "view_left"],
	"flame": ["idle", "attack", "hurt", "view_front", "view_right", "view_back", "view_left"], "speedster": ["idle", "attack", "hurt", "view_front", "view_right", "view_back", "view_left"],
	"gambler": ["idle", "attack", "hurt", "view_front", "view_right", "view_back", "view_left"], "enforcer": ["idle", "attack", "hurt", "view_front", "view_right", "view_back", "view_left"],
}

static var _data: Dictionary = {}
static var _frames_cache: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(ROOT + "characters.json", FileAccess.READ)
		if f == null:
			push_error("CharacterLibrary: can't open characters.json")
			return {}
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("CharacterLibrary: characters.json is not a dictionary")
	return _data


static func display_name(id: String) -> String:
	return str(DISPLAY_NAMES.get(id, id.capitalize()))


static func strip_info(id: String) -> Dictionary:
	return data()[id]["strips"][STRIP]


static func has_character(id: String) -> bool:
	return data().has(id) or GEN_ONLY.has(id) or Art.has("characters/" + id, "idle")


static func frames_for(id: String) -> SpriteFrames:
	if _frames_cache.has(id):
		return _frames_cache[id]
	if GEN_ONLY.has(id) or (not data().has(id) and Art.has("characters/" + id, "idle")):
		var g := "characters/" + id
		var anims := {}
		var list: Array = GEN_ONLY.get(id, ["idle", "idle_up", "idle_side", "walk", "walk_down", "walk_up", "sit", "wave", "work"])
		for a: String in list:
			if Art.has(g, a):
				anims[a] = a
		var gsf := Art.frames(g, anims, FPS, LOOPS)
		# Fallbacks so every character can idle/walk even with a partial set.
		if not gsf.has_animation("idle") and gsf.has_animation("view_front"):
			_alias(gsf, "idle", "view_front")
		if not gsf.has_animation("walk"):
			_alias(gsf, "walk", "walk_down" if gsf.has_animation("walk_down") else "idle")
		if not gsf.has_animation("run"):
			_alias(gsf, "run", "walk")
		if not gsf.has_animation("attack"):
			_alias(gsf, "attack", "idle")
		if not gsf.has_animation("view_front"):
			_alias(gsf, "view_front", "idle")
		if not gsf.has_animation("view_back"):
			_alias(gsf, "view_back", "idle_up" if gsf.has_animation("idle_up") else "idle")
		if not gsf.has_animation("view_right"):
			_alias(gsf, "view_right", "idle_side" if gsf.has_animation("idle_side") else "idle")
		for v in ["view_left"]:
			if not gsf.has_animation(v):
				_alias(gsf, v, "view_right")
		_frames_cache[id] = gsf
		return gsf
	var info := strip_info(id)
	var tex: Texture2D = load(ROOT + id + "/" + str(info["file"]))
	var w := int(info["cell_w"])
	var h := int(info["cell_h"])
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var order: Array = info["frame_order"]
	for i in order.size():
		var frame_name := str(order[i])
		var anim: String
		if frame_name.begins_with("views_"):
			anim = VIEW_NAMES[int(frame_name.get_slice("_", 1))]
		else:
			anim = frame_name.get_slice("_", 0)
		if not sf.has_animation(anim):
			sf.add_animation(anim)
			sf.set_animation_speed(anim, float(FPS.get(anim, 6.0)))
			sf.set_animation_loop(anim, bool(LOOPS.get(anim, true)))
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * w, 0, w, h)
		sf.add_frame(anim, at)
	# New frames from Tom's uploads (walking toward/away, dog sit/dig, tool use).
	var extra := {"walk_down": "walk_down", "walk_up": "walk_up", "run_down": "run_down", "run_up": "run_up", "sit": "sit", "dig": "dig"}
	var tfps := {}
	var tloops := {}
	for a: String in TOOL_ACTIONS:
		for d: String in ["down", "right", "up"]:
			extra[a + "_" + d] = a + "_" + d
			tfps[a + "_" + d] = float(TOOL_FPS[a])
			tloops[a + "_" + d] = false
	tfps.merge(FPS)
	tloops.merge(LOOPS)
	Art.add_frames(sf, "characters/" + id, extra, tfps, tloops)
	_frames_cache[id] = sf
	return sf


## Sprite anchored at its feet (bottom-center), like the strips.
static func _alias(sf: SpriteFrames, new_name: String, from: String) -> void:
	if not sf.has_animation(from):
		return
	sf.add_animation(new_name)
	sf.set_animation_speed(new_name, sf.get_animation_speed(from))
	sf.set_animation_loop(new_name, sf.get_animation_loop(from))
	for i in sf.get_frame_count(from):
		sf.add_frame(new_name, sf.get_frame_texture(from, i))


static func make_sprite(id: String) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames_for(id)
	if s.sprite_frames.has_animation("idle"):
		s.animation = "idle"
	var h := int(strip_info(id)["cell_h"]) if data().has(id) else int(Art.info("characters/" + id, "idle").get("cell_h", 64))
	s.centered = true
	s.offset = Vector2(0, -h / 2.0)
	s.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	# Frames from different strips have different cell heights; keep feet planted.
	s.frame_changed.connect(func() -> void:
		var tex := s.sprite_frames.get_frame_texture(s.animation, s.frame)
		if tex:
			s.offset = Vector2(0, -tex.get_height() / 2.0))
	return s

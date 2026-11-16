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
const FPS := {"idle": 4.0, "walk": 8.0, "run": 12.0, "attack": 10.0, "play": 8.0, "walk_down": 8.0, "walk_up": 8.0, "run_down": 12.0, "run_up": 12.0, "sit": 3.0, "dig": 8.0, "powerup": 8.0}
const LOOPS := {"attack": false, "powerup": false}
## Characters that exist only in art/gen (no pack folder).
const GEN_ONLY := {"penguin": true}

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
	return data().has(id) or GEN_ONLY.has(id)


static func frames_for(id: String) -> SpriteFrames:
	if _frames_cache.has(id):
		return _frames_cache[id]
	if GEN_ONLY.has(id):
		var g := "characters/" + id
		var gsf := Art.frames(g, {"idle": "idle", "walk": "walk", "run": "run", "attack": "attack", "powerup": "powerup",
			"view_front": "view_front", "view_right": "view_right", "view_back": "view_back", "view_left": "view_left"}, FPS, LOOPS)
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
	# New frames from Tom's uploads (walking toward/away, dog sit/dig).
	Art.add_frames(sf, "characters/" + id, {"walk_down": "walk_down", "walk_up": "walk_up", "run_down": "run_down", "run_up": "run_up", "sit": "sit", "dig": "dig"}, FPS, LOOPS)
	_frames_cache[id] = sf
	return sf


## Sprite anchored at its feet (bottom-center), like the strips.
static func make_sprite(id: String) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames_for(id)
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

class_name PaperDoll
extends RefCounted
## Builds the hero from layers: a body base (w56: skin × build, 16 poses),
## a hair style (pose-matched sets w108/110/111, tinted), a hat (w112/113)
## and, while swinging, the tier-correct tool (w100–107). Layers are pinned
## to the body frame's head anchor recorded by the slicer (manifest "anchors").
## Once the full-costume sheets (Prompts 08 batch 1) land, `body_for()` swaps
## the base for the equipped costume and everything else stays the same.

const BODIES := ["light_slim", "light_broad", "medium_slim", "medium_broad", "dark_slim", "dark_broad"]
const HAIR_COLORS := {"brown": "ffffff", "black": "6a6a7a", "blonde": "ffe4a0", "red": "ff9c7a", "silver": "e8e8f8", "pink": "ffb0d8", "blue": "9ab8ff", "green": "a8e0a0"}
## 16-pose row from w56: idle down, idle up, idle side, walk side ×4, walk down ×4, walk up ×4, run side.
const POSES := {"idle": [0], "idle_up": [1], "idle_side": [2], "walk": [3, 4, 5, 6], "walk_down": [7, 8, 9, 10], "walk_up": [11, 12, 13, 14], "run": [15, 4, 15, 6], "run_down": [7, 8, 9, 10], "run_up": [11, 12, 13, 14], "view_front": [0], "view_back": [1], "view_right": [2]}
const FPS := {"idle": 1.0, "idle_up": 1.0, "idle_side": 1.0, "walk": 8.0, "walk_down": 8.0, "walk_up": 8.0, "run": 12.0, "run_down": 12.0, "run_up": 12.0}
## Action poses from w56 row 7 used as single frames for tool/attack anims.
const ACTIONS := {"attack": ["act_attack_1", "act_attack_2", "act_attack_3"], "hurt": ["act_hurt"], "sit": ["act_sit"], "sleep": ["act_sleep"], "eat_down": ["act_eat"], "celebrate": ["act_celebrate_1", "act_celebrate_2"], "swim": ["act_swim_1", "act_swim_2"], "ride": ["act_ride_1", "act_ride_2"], "hold_down": ["act_carry_1"], "hold_up": ["act_carry_1"], "hold_right": ["act_carry_2"], "faint": ["act_faint"]}
const LIFE := {"sit": [0], "sleep": [1], "faint": [2], "carry": [3, 4], "pet": [5, 6], "wave": [7, 8], "dance": [9, 10, 11, 12], "eat_down": [13, 14], "eat_up": [13, 14], "eat_right": [13, 14], "drink": [15]}
const WATER := {"swim": [0, 1, 2, 3], "swim_down": [4, 5, 6, 7], "swim_up": [8, 9, 10, 11], "float": [12], "dive": [13], "climb_out": [14, 15]}
const RIDE := {"ride": [0, 1, 2, 3], "ride_run": [4, 5], "ride_down": [6, 7], "ride_up": [8, 9]}
const TOOL_POSES := {"hoe": "attack", "water": "hold", "axe": "attack", "pickaxe": "attack", "cast": "attack", "reel": "hold", "eat": "eat"}


static func available() -> bool:
	return Art.has("body", "medium_slim")


static func default_look() -> Dictionary:
	return {"body": "medium_slim", "hair": "shaggy", "hair_color": "brown", "hat": "", "face": 0}


static func random_look() -> Dictionary:
	var hairs := hair_styles()
	return {"body": BODIES[randi() % BODIES.size()], "hair": hairs[randi() % hairs.size()] if not hairs.is_empty() else "", "hair_color": HAIR_COLORS.keys()[randi() % HAIR_COLORS.size()], "hat": "", "face": randi() % 6}


static func hair_styles() -> Array:
	var out: Array = Art.manifest().get("hair", {}).keys()
	out.sort()
	return out


static func hat_styles() -> Array:
	var out: Array = Art.manifest().get("hats", {}).keys()
	out.sort()
	return out


## Action row (Prompts 08 batch 1 "_act" sheets): swing down 1-3, swing side
## 1-3, swing up 1-3, hold down, hold up, hold side, hurt, eat, cast, celebrate.
const ACT := {"hoe_down": [0, 1, 2], "hoe_right": [3, 4, 5], "hoe_up": [6, 7, 8], "axe_down": [0, 1, 2], "axe_right": [3, 4, 5], "axe_up": [6, 7, 8],
	"pickaxe_down": [0, 1, 2], "pickaxe_right": [3, 4, 5], "pickaxe_up": [6, 7, 8], "attack": [3, 4, 5], "attack_down": [0, 1, 2], "attack_up": [6, 7, 8],
	"water_down": [9], "water_up": [10], "water_right": [11], "hold_down": [9], "hold_up": [10], "hold_right": [11], "cast_down": [14], "cast_up": [14], "cast_right": [14],
	"reel_down": [9], "reel_up": [10], "reel_right": [11], "eat_down": [13], "eat_up": [13], "eat_right": [13], "hurt": [12], "celebrate": [15], "powerup": [15]}


## The body sheet to draw: the equipped costume (chest armor / outfit) when
## that sheet exists, else the bare base from the look.
static func body_for(look: Dictionary) -> String:
	var chest := GameState.equipped("body")
	var cs := str(GameState.items.get(chest, {}).get("costume", ""))
	if cs != "" and Art.has("body", cs):
		return cs
	var body := str(look.get("body", "medium_slim"))
	return body if Art.has("body", body) else "medium_slim"


## SpriteFrames for the body of a look (walk poses + action row).
static func body_frames(look: Dictionary) -> SpriteFrames:
	var body := body_for(look)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var tex := Art.tex("body", body)
	var info := Art.info("body", body)
	var cw := int(info.get("cell_w", 96))
	var ch := int(info.get("cell_h", 96))
	for anim: String in POSES:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, float(FPS.get(anim, 6.0)))
		sf.set_animation_loop(anim, true)
		for i in POSES[anim]:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(int(i) * cw, 0, cw, ch)
			sf.add_frame(anim, at)
	# Action row from the matching "_act" sheet (costume or base).
	var act := body + "_act"
	if Art.has("body", act):
		var atex := Art.tex("body", act)
		var ainfo := Art.info("body", act)
		var acw := int(ainfo.get("cell_w", 96))
		var ach := int(ainfo.get("cell_h", 96))
		for anim: String in ACT:
			sf.add_animation(anim)
			sf.set_animation_speed(anim, 10.0)
			sf.set_animation_loop(anim, false)
			for i in ACT[anim]:
				var at := AtlasTexture.new()
				at.atlas = atex
				at.region = Rect2(int(i) * acw, 0, acw, ach)
				sf.add_frame(anim, at)
	# Life row (Prompts 09): sit, sleep, faint, carry ×2, pet ×2, wave ×2, dance ×4, eat ×2, drink.
	var life := body + "_life"
	if Art.has("body", life):
		var ltex := Art.tex("body", life)
		var linfo := Art.info("body", life)
		var lcw := int(linfo.get("cell_w", 96))
		var lch := int(linfo.get("cell_h", 96))
		for anim: String in LIFE:
			if sf.has_animation(anim):
				sf.remove_animation(anim)
			sf.add_animation(anim)
			sf.set_animation_speed(anim, 6.0)
			sf.set_animation_loop(anim, anim in ["dance", "carry", "pet"])
			for i in LIFE[anim]:
				var at := AtlasTexture.new()
				at.atlas = ltex
				at.region = Rect2(int(i) * lcw, 0, lcw, lch)
				sf.add_frame(anim, at)
	# Water row: swim side 1-4, down 1-4, up 1-4, float, dive, climb out ×2.
	var water := body + "_water"
	if Art.has("body", water):
		var wtex := Art.tex("body", water)
		var winfo := Art.info("body", water)
		var wcw := int(winfo.get("cell_w", 128))
		var wch := int(winfo.get("cell_h", 96))
		for anim: String in WATER:
			if sf.has_animation(anim):
				sf.remove_animation(anim)
			sf.add_animation(anim)
			sf.set_animation_speed(anim, 6.0)
			sf.set_animation_loop(anim, not anim in ["dive", "climb_out"])
			for i in WATER[anim]:
				var at := AtlasTexture.new()
				at.atlas = wtex
				at.region = Rect2(int(i) * wcw, 0, wcw, wch)
				sf.add_frame(anim, at)
	# Ride row: walk side 1-4, run side 1-2, walk down 1-2, walk up 1-2.
	var ride := body + "_ride"
	if Art.has("body", ride):
		var rtex := Art.tex("body", ride)
		var rinfo := Art.info("body", ride)
		var rcw := int(rinfo.get("cell_w", 128))
		var rch := int(rinfo.get("cell_h", 128))
		for anim: String in RIDE:
			if sf.has_animation(anim):
				sf.remove_animation(anim)
			sf.add_animation(anim)
			sf.set_animation_speed(anim, 8.0 if anim != "ride_run" else 12.0)
			sf.set_animation_loop(anim, true)
			for i in RIDE[anim]:
				var at := AtlasTexture.new()
				at.atlas = rtex
				at.region = Rect2(int(i) * rcw, 0, rcw, rch)
				sf.add_frame(anim, at)
	for anim: String in ACTIONS:
		if sf.has_animation(anim):
			continue
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 8.0)
		sf.set_animation_loop(anim, anim in ["swim", "ride"])
		for nm in ACTIONS[anim]:
			var t := Art.tex("body", str(nm))
			if t:
				sf.add_frame(anim, t)
	return sf


## Pose index for a frame of any animation (walk poses or action row), with
## the sheet it came from, so layers pin to the right anchor.
static func frame_source(anim: String, frame: int, body: String) -> Array:
	if POSES.has(anim):
		var arr: Array = POSES[anim]
		return [body, int(arr[clampi(frame, 0, arr.size() - 1)])]
	if ACT.has(anim) and Art.has("body", body + "_act"):
		var arr2: Array = ACT[anim]
		return [body + "_act", int(arr2[clampi(frame, 0, arr2.size() - 1)])]
	if LIFE.has(anim) and Art.has("body", body + "_life"):
		var arr3: Array = LIFE[anim]
		return [body + "_life", int(arr3[clampi(frame, 0, arr3.size() - 1)])]
	if WATER.has(anim) and Art.has("body", body + "_water"):
		var arr4: Array = WATER[anim]
		return [body + "_water", int(arr4[clampi(frame, 0, arr4.size() - 1)])]
	if RIDE.has(anim) and Art.has("body", body + "_ride"):
		var arr5: Array = RIDE[anim]
		return [body + "_ride", int(arr5[clampi(frame, 0, arr5.size() - 1)])]
	return [body, 0]


## Head anchor of a body frame in canvas px: [cx, top, bottom, w, h].
static func anchor_of(group: String, name: String, frame: int) -> Array:
	var an: Array = Art.info(group, name).get("anchors", [])
	if an.is_empty():
		return [48.0, 20.0, 92.0, 40.0, 72.0]
	return an[clampi(frame, 0, an.size() - 1)]


## Which pose index (0-15) a body animation frame shows (for layer matching).
static func pose_index(anim: String, frame: int) -> int:
	if POSES.has(anim):
		var arr: Array = POSES[anim]
		return int(arr[clampi(frame, 0, arr.size() - 1)])
	return 0


## Hair/hat frame for a pose: these sheets are reliable for the three idle
## views, so layers follow the facing (0 down, 1 up, 2 side) until the
## pose-matched sheets are re-cut.
static func layer_frame(pose: int, act := false) -> int:
	if act:
		# Action row: 0-2 down, 3-5 side, 6-8 up, 9 down, 10 up, 11 side, 12-15 down/side.
		if pose in [6, 7, 8, 10]:
			return 1
		if pose in [3, 4, 5, 11, 14]:
			return 2
		return 0
	if pose == 1 or (pose >= 11 and pose <= 14):
		return 1
	if pose == 2 or (pose >= 3 and pose <= 6) or pose == 15:
		return 2
	return 0


## A layer sprite (hair or hat) pinned over a body frame.
static func place_layer(layer: Sprite2D, group: String, name: String, body_name: String, body_frame_pose: int, flip: bool, body_scale: float) -> void:
	if name == "" or not Art.has(group, name):
		layer.visible = false
		return
	var act := body_name.ends_with("_act")
	var life := body_name.ends_with("_life")
	var water := body_name.ends_with("_water")
	var ride := body_name.ends_with("_ride")
	var tex := Art.tex(group, name)
	var info := Art.info(group, name)
	var cw := int(info.get("cell_w", 96))
	var ch := int(info.get("cell_h", 96))
	var lf := layer_frame(body_frame_pose, act)
	if life:
		lf = 2 if body_frame_pose in [1, 2] else 0
	elif water:
		lf = 2 if body_frame_pose <= 3 or body_frame_pose == 13 else (1 if body_frame_pose >= 8 and body_frame_pose <= 11 else 0)
	elif ride:
		lf = 1 if body_frame_pose >= 8 else (0 if body_frame_pose >= 6 else 2)
	layer.texture = tex
	layer.region_enabled = true
	layer.region_rect = Rect2(lf * cw, 0, cw, ch)
	layer.visible = true
	layer.flip_h = flip
	var b := anchor_of("body", body_name, body_frame_pose)
	var l := anchor_of(group, name, lf)
	# Scale the layer so hair is a bit wider than the head. The head is about
	# 40% of the sprite height (shoulders can be wider than the head in armor).
	var head_w := minf(float(b[3]), float(b[4]) * 0.52)
	var want_w := head_w * (1.15 if group == "hair" else 1.25)
	var sc := want_w / maxf(1.0, float(l[3]))
	layer.scale = Vector2(sc, sc) * body_scale
	# Pin: layer bbox centre x over the body centre; hair bottom sits a third
	# of the way down the head; a hat's brim sits at the head top.
	var head_h := float(b[4]) * 0.42
	var target_y := float(b[1]) + (head_h * 0.72 if group == "hair" else head_h * 0.18)
	var lcx := float(l[0]) - cw / 2.0
	var lby := float(l[2]) - ch / 2.0
	# Body canvas → node space: the body sprite is centred with offset -h/2, so
	# its canvas top-left sits at (-48, -96) × scale; the layer is plain-centred.
	var off := Vector2((float(b[0]) - 48.0) - lcx * sc * (-1.0 if flip else 1.0), (target_y - 96.0) - lby * sc)
	layer.position = off * body_scale

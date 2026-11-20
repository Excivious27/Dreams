class_name PaperDoll
extends RefCounted
## Builds the hero from layers: a body base (w56: skin × build, 16 poses),
## a hair style (pose-matched sets w108/110/111, tinted), a hat (w112/113)
## and, while swinging, the tier-correct tool (w100–107). Layers are pinned
## to the body frame's head anchor recorded by the slicer (manifest "anchors").
## Once the full-costume sheets (Prompts 08 batch 1) land, `body_for()` swaps
## the base for the equipped costume and everything else stays the same.

## True while the creator / new-game preview builds a doll: show the look's outfit, not worn armour.
static var preview_bare := false
const BODIES := ["light_slim", "light_broad", "medium_slim", "medium_broad", "dark_slim", "dark_broad"]
const HAIR_COLORS := {"brown": "ffffff", "black": "3a3440", "blonde": "f2d27a", "red": "c8562e", "silver": "dcdcea", "pink": "f294c4", "blue": "5c84e0", "green": "62b266"}
## Everyday outfits the creator offers (the look's "outfit"; armor still wins in game).
const OUTFITS := ["outfit_farmer", "outfit_neon", "outfit_fisher", "outfit_forester", "outfit_miner", "outfit_merchant", "outfit_scholar"]


## The hair layer's material: recolours the brown hair art (brown = as drawn).
static func hair_material(col: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/hair_tint.gdshader")
	m.set_shader_parameter("tint", Color(str(HAIR_COLORS.get(col, "ffffff"))))
	m.set_shader_parameter("on", col != "brown" and HAIR_COLORS.has(col))
	return m
## 16-pose row from w56: idle down, idle up, idle side, walk side ×4, walk down ×4, walk up ×4, run side.
const POSES := {"idle": [0], "idle_up": [1], "idle_side": [2], "walk": [3, 4, 5, 6], "walk_down": [7, 8, 9, 10], "walk_up": [11, 12, 13, 14], "run": [15, 4, 15, 6], "run_down": [7, 8, 9, 10], "run_up": [11, 12, 13, 14], "view_front": [0], "view_back": [1], "view_right": [2]}
const FPS := {"idle": 1.0, "idle_up": 1.0, "idle_side": 1.0, "walk": 8.0, "walk_down": 8.0, "walk_up": 8.0, "run": 12.0, "run_down": 12.0, "run_up": 12.0}
## Action poses from w56 row 7 used as single frames for tool/attack anims.
const ACTIONS := {"attack": ["act_attack_1", "act_attack_2", "act_attack_3"], "hurt": ["act_hurt"], "sit": ["act_sit"], "sleep": ["act_sleep"], "eat_down": ["act_eat"], "celebrate": ["act_celebrate_1", "act_celebrate_2"], "swim": ["act_swim_1", "act_swim_2"], "ride": ["act_ride_1", "act_ride_2"], "hold_down": ["act_carry_1"], "hold_up": ["act_carry_1"], "hold_right": ["act_carry_2"], "faint": ["act_faint"]}
const LIFE := {"sit": [0], "sleep": [1], "faint": [2], "carry": [3, 4], "pet": [5, 6], "wave": [7, 8], "dance": [9, 10, 11, 12], "eat_down": [13, 14], "eat_up": [13, 14], "eat_right": [13, 14], "drink": [15]}
const WATER := {"swim": [0, 1, 2, 3], "swim_down": [4, 5, 6, 7], "swim_up": [8, 9, 10, 11], "float": [12], "dive": [13], "climb_out": [14, 15]}
const RIDE := {"ride": [0, 1, 2, 3], "ride_run": [4, 5], "ride_down": [6, 7], "ride_up": [8, 9]}
## Missing-row stand-ins for costume sheets (see body_frames); frame_source mirrors it.
const POSE_FALLBACK := {"sit": "idle", "sleep": "idle", "faint": "idle", "carry": "walk_down", "pet": "idle", "wave": "idle", "dance": "walk_down",
	"eat_up": "idle", "drink": "idle", "swim": "walk", "swim_down": "walk_down", "swim_up": "walk_up", "float": "idle", "dive": "idle", "climb_out": "idle",
	"ride": "walk", "ride_run": "run", "ride_down": "walk_down", "ride_up": "walk_up", "swim_1": "walk", "hold_up": "idle_up"}
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


## Skin tone on the painted (tan = medium) costume sheets: the look's body prefix picks
## the target mid colour; shaders/doll_body.gdshader recolours the sheet's _skin mask
## (tools/skin_masks.py). Medium (and armour sheets without a mask) stay as drawn.
const SKIN_TONES := {"light": Color(1.0, 0.86, 0.76), "dark": Color(0.55, 0.36, 0.25)}


static func skin_key(look: Dictionary) -> String:
	return str(look.get("body", "medium_slim")).get_slice("_", 0)


static func body_material(look: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/doll_body.gdshader")
	m.set_meta("skin", skin_key(look))
	return m


## Point the body material at the mask of the sheet a frame comes from.
static func apply_skin(m: ShaderMaterial, sheet: String) -> void:
	if m == null:
		return
	var tone: Variant = SKIN_TONES.get(str(m.get_meta("skin", "medium")), null)
	var mk := sheet + "_skin"
	var on := tone != null and Art.has("body", mk)
	m.set_shader_parameter("skin_on", on)
	if on:
		m.set_shader_parameter("skin_mask", Art.tex("body", mk))
		m.set_shader_parameter("tone", Vector3((tone as Color).r, (tone as Color).g, (tone as Color).b))


## Everyday outfits the creator/dresser offer for the current arc (arc jacket first):
## the wardrobe's starter outfits (data/wardrobe.json), else OUTFITS.
static func starter_outfits() -> Array:
	var first: Array = []
	var rest: Array = []
	var items: Dictionary = Wardrobe.data()["items"]
	var ids := items.keys()
	ids.sort()
	for id: String in ids:
		var e: Dictionary = items[id]
		var b := str((e.get("doll", {}) as Dictionary).get("body", ""))
		if str(e.get("slot", "")) != "outfit" or not bool(e.get("starter", false)) or not Art.has("body", b):
			continue
		var a := str(e.get("arc", ""))
		if a != "" and a != Wardrobe.arc():
			continue
		(first if a != "" else rest).append(b)
	if first.is_empty() and rest.is_empty():
		for o: String in OUTFITS:
			if Art.has("body", o):
				rest.append(o)
	if "outfit_farmer" in rest:
		rest.erase("outfit_farmer")
		rest.push_front("outfit_farmer")
	return rest.slice(0, 1) + first + rest.slice(1)


## The body sheet to draw: the equipped costume (chest armor / outfit) when
## that sheet exists, else the bare base from the look.
static func body_for(look: Dictionary) -> String:
	# Wardrobe (C10a): a worn cosmetic outfit wins over armour unless the Look
	# toggle says "show armour"; cosmetics never change stats.
	var cos := "" if preview_bare else Wardrobe.outfit_body()
	var chest := "" if preview_bare else GameState.equipped("body")
	var cs := str(GameState.items.get(chest, {}).get("costume", ""))
	if cos != "" and not (Wardrobe.show_armor() and cs != "" and Art.has("body", cs)):
		return cos
	if cs != "" and Art.has("body", cs):
		return cs
	# Nothing equipped: you still wear clothes. The look's outfit (farmer by
	# default) is the everyday costume; the bare base is only for the creator's
	# skin/build picker.
	var outfit := str(look.get("outfit", "outfit_farmer"))
	if Art.has("body", outfit):
		return outfit
	var body := str(look.get("body", "medium_slim"))
	return body if Art.has("body", body) else "medium_slim"


## Hat layers that cover the whole head: no hair drawn under them.
const FULL_HATS := ["knight", "hood", "aurora_hood", "crystal_helm", "gold_helm", "moon_helm", "silver_helm"]


## Body sheets with a helmet/hood painted in: no hair, no hat layer on top (c10_04).
static func has_headgear(body: String) -> bool:
	var b := body.trim_suffix("_act").trim_suffix("_life").trim_suffix("_water").trim_suffix("_ride")
	return b.begins_with("armor_") or b == "outfit_miner" or b == "outfit_armored"


## Any penguin hero sprite (penguin, penguin_king, penguin_wizard).
static func is_penguin(sprite: String) -> bool:
	return sprite.begins_with("penguin")


## The hat layer to draw as [group, name]: worn helm (when shown) > cosmetic hat > look hat.
static func hat_layer(look: Dictionary) -> Array:
	var helm := "" if preview_bare else GameState.equipped("head")
	var hs := str(GameState.items.get(helm, {}).get("sprite", helm))
	var helm_l: Array = []
	for g: String in ["hats", "hats_poses"]:
		if hs != "" and Art.has(g, hs):
			helm_l = [g, hs]
			break
	var cos: Array = [] if preview_bare else Wardrobe.doll_layer("hat")
	if not cos.is_empty() and not (Wardrobe.show_armor() and not helm_l.is_empty()):
		return cos
	if not helm_l.is_empty():
		return helm_l
	var lh := str(look.get("hat", ""))
	return ["hats", lh] if lh != "" and Art.has("hats", lh) else []


## Face piece (shades, goggles) as [group, name] or [].
static func face_layer(_look: Dictionary) -> Array:
	return [] if preview_bare else Wardrobe.doll_layer("face")


## Copy the body's hurt blink / tint onto a layer (keeps the layer's own alpha fade).
static func sync_layer(layer: CanvasItem, anim: CanvasItem) -> void:
	if layer == null or anim == null:
		return
	var a := layer.modulate.a
	layer.modulate = Color(anim.modulate, a * anim.modulate.a)


## Colourway of a layer (wardrobe "tint"): the luma recolour of hair_tint.gdshader
## (it also carries the hit flash); "" puts the layer's own material back.
static func _colourway(layer: Sprite2D, tint: String) -> void:
	if not layer.has_meta("base_mat"):
		layer.set_meta("base_mat", layer.material)
	if tint == "":
		if layer.material != layer.get_meta("base_mat"):
			layer.material = layer.get_meta("base_mat")
		return
	if str(layer.get_meta("tint", "")) != tint or not (layer.material is ShaderMaterial):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/hair_tint.gdshader")
		m.set_shader_parameter("tint", Color(tint))
		m.set_shader_parameter("on", true)
		layer.material = m
		layer.set_meta("tint", tint)


## Pin hair/hat/face layers for a body frame. Layers: {"hair": Sprite2D, "hat": .., "face": ..}.
static func place_all(layers: Dictionary, look: Dictionary, body: String, pose: int, flip: bool, sc: float) -> void:
	var hg := has_headgear(body)
	if layers.has("hair"):
		if hg:
			(layers["hair"] as Sprite2D).visible = false
		else:
			place_layer(layers["hair"], "hair", str(look.get("hair", "")), body, pose, flip, sc)
	if layers.has("hat"):
		var hl := hat_layer(look)
		if hl.is_empty() or hg:
			(layers["hat"] as Sprite2D).visible = false
		else:
			place_layer(layers["hat"], hl[0], hl[1], body, pose, flip, sc)
			_colourway(layers["hat"], Wardrobe.doll_tint("hat"))
			if str(hl[1]) in FULL_HATS and layers.has("hair"):
				(layers["hair"] as Sprite2D).visible = false  # helms and hoods cover the hair
	if layers.has("face"):
		var fl := face_layer(look)
		if fl.is_empty() or hg:
			(layers["face"] as Sprite2D).visible = false
		else:
			place_layer(layers["face"], fl[0], fl[1], body, pose, flip, sc, "face")


## A live paper-doll preview (body walking + layers) under `parent`, `scale` world px per
## body px multiplier (1.0 = in-game size). Returns the body sprite.
static func build_preview(parent: Node2D, look: Dictionary, mult: float, anim := "walk_down", bare := false) -> AnimatedSprite2D:
	preview_bare = bare
	var bname := body_for(look)
	var body := AnimatedSprite2D.new()
	body.sprite_frames = body_frames(look)
	body.centered = true
	var ch := float(Art.info("body", bname).get("cell_h", 96))
	body.offset = Vector2(0, -ch / 2.0)
	var h := float(anchor_of("body", bname, 0)[4])
	var sc := mult * CharacterLibrary.HERO_H / maxf(20.0, h)
	body.scale = Vector2(sc, sc)
	body.play(anim)
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var bm := body_material(look)
	bm.set_shader_parameter("crisp", false)
	body.material = bm
	parent.add_child(body)
	var layers := {}
	for k: String in ["hair", "hat", "face"]:
		var sp := Sprite2D.new()
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sp.z_index = 1
		if k == "hair":
			sp.material = hair_material(str(look.get("hair_color", "brown")))
		parent.add_child(sp)
		layers[k] = sp
	var upd := func() -> void:
		if not is_instance_valid(body):
			return
		var src := frame_source(body.animation, body.frame, bname)
		apply_skin(bm, src[0])
		preview_bare = bare
		place_all(layers, look, src[0], src[1], body.flip_h, sc)
		preview_bare = false
	body.frame_changed.connect(upd)
	body.animation_changed.connect(upd)
	upd.call()
	preview_bare = false
	return body


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
	# Costume sheets without life/water/ride rows (the six arc costumes): reuse the
	# costume's own idle/walk poses, never the bald base's act_* frames (another look,
	# drawn at a different scale).
	if not body in BODIES:
		for anim: String in POSE_FALLBACK:
			if sf.has_animation(anim):
				continue
			var from := str(POSE_FALLBACK[anim])
			sf.add_animation(anim)
			sf.set_animation_speed(anim, sf.get_animation_speed(from))
			sf.set_animation_loop(anim, not anim in ["dive", "climb_out", "faint", "sleep", "sit"])
			for i in sf.get_frame_count(from):
				sf.add_frame(anim, sf.get_frame_texture(from, i))
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
	if POSE_FALLBACK.has(anim) and not body in BODIES:
		var arr6: Array = POSES[str(POSE_FALLBACK[anim])]
		return [body, int(arr6[clampi(frame, 0, arr6.size() - 1)])]
	return [body, 0]


## Head anchor of a body frame in canvas px: [cx, top, bottom, w, h].
static func anchor_of(group: String, name: String, frame: int) -> Array:
	var an: Array = Art.info(group, name).get("anchors", [])
	if an.is_empty():
		an = _measured_anchors(group, name)
	if an.is_empty():
		return [48.0, 20.0, 92.0, 40.0, 72.0]
	return an[clampi(frame, 0, an.size() - 1)]


static var _anchor_cache: Dictionary = {}


## Sheets sliced without anchors (the six arc costumes, hats_poses): measure each
## cell's opaque box once. Bodies: [cx, bottom - h, bottom, w, h] with h scaled like
## the slicer's (figure fills ~92 of 96 px); layers: [cx, top, bottom, w, h].
static func _measured_anchors(group: String, name: String) -> Array:
	var key := group + "/" + name
	if _anchor_cache.has(key):
		return _anchor_cache[key]
	var out: Array = []
	var tex := Art.tex(group, name)
	if tex:
		var img := tex.get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			var info := Art.info(group, name)
			var cw := int(info.get("cell_w", img.get_width()))
			var ch := int(info.get("cell_h", img.get_height()))
			var n := maxi(1, int(info.get("frames", img.get_width() / maxi(1, cw))))
			for i in n:
				var r := img.get_region(Rect2i(i * cw, 0, cw, ch)).get_used_rect()
				if r.size.x <= 0:
					out.append([cw / 2.0, 0.0, float(ch), float(cw), float(ch)])
					continue
				var cx := r.position.x + r.size.x / 2.0
				if group == "body":
					var hh := r.size.y * 96.0 / 92.0
					out.append([cx, r.end.y - hh, float(r.end.y), float(r.size.x), hh])
				else:
					out.append([cx, float(r.position.y), float(r.end.y), float(r.size.x), float(r.size.y)])
	_anchor_cache[key] = out
	return out


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
## Penguin palettes (modulate over the painted sprite) and scarf colours.
const PENGUIN_TINTS := {"classic": "ffffff", "snow": "e8f4ff", "midnight": "9aa4ff", "sunset": "ffc49a", "mint": "b8ffd8", "rose": "ffb8d0", "gold": "ffe08a", "ember": "ff9a7a"}
const SCARF_COLORS := {"": "", "red": "d8403a", "blue": "3f6fd8", "green": "4aa84a", "yellow": "e8c23a", "purple": "8a5ad8", "white": "f4f4f4"}


## A hat on a non-doll hero (the penguin): the hat's front frame, scaled to the
## head width, pinned on top of the sprite. `head_w`/`top_y` are in sprite px.
static func place_hat_simple(layer: Sprite2D, name: String, head_w: float, top_y: float, flip: bool, body_scale: float) -> void:
	if name == "" or not Art.has("hats", name):
		layer.visible = false
		return
	var tex := Art.tex("hats", name)
	var info := Art.info("hats", name)
	var cw := int(info.get("cell_w", 96))
	var ch := int(info.get("cell_h", 96))
	layer.texture = tex
	layer.region_enabled = true
	layer.region_rect = Rect2(0, 0, cw, ch)
	layer.visible = true
	layer.flip_h = flip
	var l := anchor_of("hats", name, 0)
	var sc := head_w * 1.2 / maxf(1.0, float(l[3]))
	layer.scale = Vector2(sc, sc) * body_scale
	var lcx := float(l[0]) - cw / 2.0
	var lby := float(l[1]) + float(l[4]) - ch / 2.0
	layer.position = Vector2(-lcx * sc * body_scale * (-1.0 if flip else 1.0), (top_y + head_w * 0.25) - lby * sc * body_scale)


static func place_layer(layer: Sprite2D, group: String, name: String, body_name: String, body_frame_pose: int, flip: bool, body_scale: float, kind := "") -> void:
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
	if kind == "":
		kind = "hair" if group == "hair" else "hat"
	var bi := Art.info("body", body_name)
	var bcw := float(bi.get("cell_w", 96))
	var bch := float(bi.get("cell_h", 96))
	var head_w := minf(float(b[3]), float(b[4]) * 0.52)
	var want_w: float = head_w * {"hair": 1.15, "hat": 1.25, "face": 0.95}.get(kind, 1.25)
	var sc := want_w / maxf(1.0, float(l[3]))
	layer.scale = Vector2(sc, sc) * body_scale
	# Pin: layer bbox centre x over the body centre; hair bottom sits a third
	# of the way down the head; a hat's brim sits at the head top.
	var head_h := float(b[4]) * 0.42
	var target_y: float = float(b[1]) + {"hair": head_h * 0.72, "hat": head_h * 0.18, "face": head_h * 0.62}.get(kind, head_h * 0.18)
	var lcx := float(l[0]) - cw / 2.0
	var lby := float(l[2]) - ch / 2.0
	if kind == "face":
		lby = (float(l[1]) + float(l[2])) / 2.0 - ch / 2.0  # centre the lenses on the eye line
	# Body canvas → node space: the body sprite is centred with offset -h/2, so
	# its canvas top-left sits at (-48, -96) × scale; the layer is plain-centred.
	var off := Vector2((float(b[0]) - bcw / 2.0) - lcx * sc * (-1.0 if flip else 1.0), (target_y - bch) - lby * sc)
	layer.position = off * body_scale

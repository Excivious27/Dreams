class_name CharacterLibrary
extends RefCounted
## Builds SpriteFrames for each character from art/characters/characters.json.
## Strips are 2x detail, so sprites are drawn at 0.5 scale.

const ROOT := "res://art/characters/"
const ORDER: Array[String] = ["man", "woman", "son", "girl", "dog"]
const DISPLAY_NAMES := {"man": "Man", "woman": "Woman", "son": "Son", "girl": "Girl", "dog": "Dog"}
const STRIP := "map_large"
const SPRITE_SCALE := 0.5
## World height (px) of an idle sprite: villagers from art/gen are 48 px cells at 0.5.
const NPC_H := 24.0
const HERO_H := 26.0
const TARGET_H := {"penguin": 14.0, "dog": 15.0, "light_crystal": 16.0, "president": 30.0}
const VIEW_NAMES: Array[String] = ["view_front", "view_right", "view_back", "view_left"]
const FPS := {"idle": 3.0, "idle_down": 3.0, "idle_up": 3.0, "idle_side": 3.0, "walk": 8.0, "run": 12.0, "attack": 10.0, "play": 8.0, "walk_down": 8.0, "walk_up": 8.0, "run_down": 12.0, "run_up": 12.0, "sit": 3.0, "dig": 8.0, "powerup": 8.0, "power": 10.0, "hurt": 6.0, "speak": 6.0, "charge": 6.0}
const LOOPS := {"bite": false, "howl": false, "beg": false, "bark": false, "play": false, "dig": false, "fetch": false, "attack": false, "attack_down": false, "attack_up": false, "powerup": false, "power": false, "hurt": false, "faint": false, "dive": false, "cast_down": false, "cast_side": false, "cast_up": false,
	"hoe_down": false, "hoe_right": false, "hoe_up": false, "water_down": false, "water_right": false, "water_up": false, "axe_down": false, "axe_right": false, "axe_up": false,
	"pickaxe_down": false, "pickaxe_right": false, "pickaxe_up": false, "cast_right": false, "reel_right": false, "hold_down": false, "eat_down": false}
## Tool-use actions (from Tom's tool sheets), each with _down/_right/_up strips.
const TOOL_ACTIONS := ["hoe", "water", "axe", "pickaxe", "cast", "reel", "hold", "eat"]
const TOOL_FPS := {"hoe": 10.0, "water": 8.0, "axe": 10.0, "pickaxe": 10.0, "cast": 8.0, "reel": 8.0, "hold": 8.0, "eat": 6.0}
## Characters that exist only in art/gen (no pack folder). Value = the strips to load.
const HERO2_ANIMS := ["idle", "idle_down", "idle_up", "walk", "walk_down", "walk_up", "run", "run_down", "run_up", "hurt", "attack", "attack_down", "faint", "celebrate", "hoe_down", "hoe_right", "hoe_up", "axe_down", "axe_right", "axe_up", "pickaxe_down", "pickaxe_right", "pickaxe_up", "water_down", "water_right", "water_up", "hold_down", "eat_down", "cast_right", "reel_right", "sit", "sleep", "wave", "swim", "swim_down", "swim_up", "float", "ride", "ride_run", "ride_down", "ride_up", "powerup", "view_front", "view_right", "view_back", "view_left"]
const HERO3_ANIMS := ["idle", "idle_down", "idle_up", "walk", "walk_down", "walk_up", "run", "run_down", "run_up", "hurt", "attack", "attack_down", "faint", "celebrate", "powerup", "swim", "cheer", "sit", "sleep", "wave", "view_front", "view_right", "view_back", "view_left"]
const HERO12_ANIMS := ["idle", "idle_down", "idle_up", "walk", "walk_down", "walk_up", "run", "hurt", "attack", "faint", "celebrate", "cheer", "powerup", "burst", "hoe_down", "axe_down", "pickaxe_down", "water_down", "hoe_right", "hoe_up", "axe_right", "axe_up", "pickaxe_right", "pickaxe_up", "water_right", "water_up", "hold_down", "eat_down", "cast_right", "reel_right", "sit", "sleep", "sleep_bed", "wave", "swim", "float", "ride", "ability", "view_front", "view_right", "view_back", "view_left"]
const GEN_ONLY := {
	"merkitty_a": ["idle", "walk", "walk_down", "walk_up", "swim", "dive", "surface", "sing"],
	"merkitty_b": ["idle", "walk", "walk_down", "walk_up", "swim", "dive", "surface", "sing"],
	"merkitty_c": ["idle", "walk", "walk_down", "walk_up", "swim", "dive", "surface", "sing"],
	"elder_brine": ["idle", "walk", "talk", "happy", "sad"],
	"elder_tidewhisker": ["idle", "walk", "talk", "happy", "sad"],
	"elder_icewhisker": ["idle", "walk", "talk", "happy", "sad"],
	"elder_cinderpaw": ["idle", "walk", "talk", "happy", "sad"],
	"coral_kit_1": ["idle", "walk"],
	"coral_kit_2": ["idle", "walk"],
	"coral_kit_3": ["idle", "walk"],
	"kelp_kit_1": ["idle", "walk"],
	"kelp_kit_2": ["idle", "walk"],
	"kelp_kit_3": ["idle", "walk"],
	"ice_kit_1": ["idle", "walk"],
	"ice_kit_2": ["idle", "walk"],
	"ice_kit_3": ["idle", "walk"],
	"ember_kit_1": ["idle", "walk"],
	"ember_kit_2": ["idle", "walk"],
	"ember_kit_3": ["idle", "walk"],
	"penguin_king": HERO12_ANIMS,
	"penguin_wizard": HERO12_ANIMS,
	"merry": HERO12_ANIMS,
	"big_jim": HERO12_ANIMS,
	"coldy": HERO12_ANIMS,
	"mer": HERO12_ANIMS,
	"coco": HERO12_ANIMS,
	"june": HERO2_ANIMS,
	"rafe": HERO2_ANIMS,
	"nia": HERO2_ANIMS,
	"ollie": HERO2_ANIMS,
	"marisol": HERO2_ANIMS,
	"bo": HERO2_ANIMS,
	"june_gang": HERO2_ANIMS,
	"rafe_gang": HERO2_ANIMS,
	"nia_gang": HERO2_ANIMS,
	"ollie_gang": HERO2_ANIMS,
	"marisol_gang": HERO2_ANIMS,
	"bo_gang": HERO2_ANIMS,
	"penguin": ["idle", "walk", "run", "attack", "attack_down", "attack_up", "hurt", "faint", "powerup", "view_front", "view_right", "view_back", "view_left",
		"hoe_down", "hoe_right", "hoe_up", "water_down", "water_right", "water_up", "axe_down", "axe_right", "axe_up", "pickaxe_down", "pickaxe_right", "pickaxe_up",
		"cast_right", "reel_right", "hold_down", "eat_down", "sit", "sleep", "wave", "swim", "swim_down", "swim_up", "float", "dive",
		"ride", "ride_run", "ride_down", "ride_up", "carry", "pet", "dance", "laugh", "umbrella", "shiver", "cheer", "cast_down", "cast_side", "cast_up", "wings"],
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
		var list: Array = GEN_ONLY.get(id, ["idle", "idle_down", "idle_up", "idle_side", "walk", "walk_down", "walk_up", "sit", "wave", "work"])
		if id.ends_with("_gang"):
			list = (Art.manifest().get(g, {}) as Dictionary).keys()  # whatever the sheet gave us
		elif id.begins_with("mk_"):
			list = list + ["power"]  # the Marked strike their power pose when their Gift is used
		for a: String in list:
			if Art.has(g, a) and int(Art.info(g, a).get("h", 99)) >= 16:  # tiny strips are empty slots
				anims[a] = a
		var gsf := Art.frames(g, anims, FPS, LOOPS)
		# Idle strips cut through the body (c14b_14-07): rest on the clean views
		# instead (IdleLife breathes them) until they are re-cut.
		for a: String in MISCUT_IDLE.get(id, []):
			if gsf.has_animation(a):
				gsf.remove_animation(a)
		# The 12B hero sheets (Coldy, Big Jim, the penguins, the cats) drew "idle"
		# as a SIDE view: everyone resting faced right. Their front idle is
		# idle_down; the side one stays as idle_side (used for left/right rests).
		if list == HERO12_ANIMS and gsf.has_animation("idle") and gsf.has_animation("idle_down"):
			_alias(gsf, "idle_side", "idle")
			(gsf.get_meta("aliased") as Dictionary).erase("idle_side")  # drawn side idle, not a stand-in
			gsf.remove_animation("idle")
			_alias(gsf, "idle", "idle_down")
		# C14b P5 (c14b_07-06, 10-04, 14-19): the HERO2 heroes, every gangster
		# outfit and the crew sheets also drew "idle" as a side (or mixed) view,
		# so resting facing you showed them sideways or flipping poses. Their
		# front rest is idle_down; a clean side idle is kept as idle_side.
		elif list != HERO12_ANIMS and gsf.has_animation("idle") and gsf.has_animation("idle_down") and not is_alias(gsf, "idle_down"):
			if not gsf.has_animation("idle_side") and not (list == HERO2_ANIMS or id.ends_with("_gang")):
				_alias(gsf, "idle_side", "idle")
				(gsf.get_meta("aliased") as Dictionary).erase("idle_side")
			gsf.remove_animation("idle")
			_alias(gsf, "idle", "idle_down")
		if id == "penguin_wizard" and gsf.get_frame_count("idle_down") == 3:
			_drop_frame(gsf, "idle_down", 1)  # Nova's frame 1 is an off-model tilt (c14b_07-05)
			_drop_frame(gsf, "idle", 1)
		_breath_timing(gsf, g)
		# Fallbacks so every character can idle/walk even with a partial set.
		if not gsf.has_animation("idle") and gsf.has_animation("view_front"):
			_alias(gsf, "idle", "view_front")
		if not gsf.has_animation("walk"):
			_alias(gsf, "walk", "walk_down" if gsf.has_animation("walk_down") else "idle")
		if not gsf.has_animation("run"):
			_alias(gsf, "run", "walk")
		# Toward/away walks never borrow the SIDE walk (that showed the penguin
		# walking sideways while it moved down): they fall back to the front/back
		# views, which the walker bobs (Player._moving_anim tells a 1-frame stand-in).
		for pair in [["walk_down", ["view_front", "idle_down", "idle"]], ["walk_up", ["view_back", "idle_up", "walk_down"]], ["run_down", ["walk_down"]], ["run_up", ["walk_up"]], ["idle_down", ["idle"]], ["idle_up", ["view_back", "idle_down"]], ["attack_down", ["attack"]], ["attack_up", ["attack_down"]], ["hurt", ["idle"]]]:
			if gsf.has_animation(str(pair[0])):
				continue
			for src: String in pair[1]:
				if gsf.has_animation(src):
					_alias(gsf, str(pair[0]), src)
					break
		if not gsf.has_animation("attack"):
			_alias(gsf, "attack", "idle")
		if not gsf.has_animation("view_front"):
			_alias(gsf, "view_front", "idle")
		if not gsf.has_animation("view_back"):
			_alias(gsf, "view_back", "idle_up" if gsf.has_animation("idle_up") else "idle")
		if not gsf.has_animation("view_right"):
			_alias(gsf, "view_right", "idle_side" if gsf.has_animation("idle_side") else "idle")
		# No view_left alias: Player._apply mirrors view_right when view_left is
		# missing (an unflipped copy made left-facing rests look right).
		# A redrawn (underworld) hero keeps their own look for every action: tool
		# swings use their attack frames until tool poses are cut for them.
		if id.ends_with("_gang") and Art.has(g, "swim") and Art.has(g, "ride"):
			for tool: String in TOOL_ACTIONS:
				for pair in [["_right", "attack"], ["_down", "attack_down"], ["_up", "attack_up"]]:
					var an: String = tool + str(pair[0])
					if not gsf.has_animation(an):
						_alias(gsf, an, _gang_tool_src(gsf, tool, str(pair[0]), str(pair[1])))
						gsf.set_animation_loop(an, false)
		# A gangster-arc outfit with no tool poses borrows the farm hero's.
		elif id.ends_with("_gang") and has_character(id.trim_suffix("_gang")):
			var base := frames_for(id.trim_suffix("_gang"))
			for a in base.get_animation_names():
				var an := str(a)
				if gsf.has_animation(an) or not (an.split("_")[0] in TOOL_ACTIONS or an.begins_with("swim") or an.begins_with("ride")):
					continue
				gsf.add_animation(an)
				gsf.set_animation_loop(an, base.get_animation_loop(an))
				gsf.set_animation_speed(an, base.get_animation_speed(an))
				for i in base.get_frame_count(an):
					gsf.add_frame(an, base.get_frame_texture(an, i), base.get_frame_duration(an, i))
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
	var extra := {"walk_down": "walk_down", "walk_up": "walk_up", "run_down": "run_down", "run_up": "run_up", "sit": "sit", "dig": "dig", "bite": "bite", "bark": "bark2", "hurt": "hurt", "limp": "limp", "guard": "guard", "howl": "howl", "fetch": "fetch", "beg": "beg", "sleep": "sleep"}
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


## Stand-in strip for a redrawn gangster hero's missing tool pose (c5_15 #4/#5):
## fishing any way uses the drawn rod cast/reel (never an empty-handed idle),
## watering pours from a standing pose (HeldSwing draws the can), never a punch.
static func _gang_tool_src(gsf: SpriteFrames, tool: String, dir: String, attack: String) -> String:
	var pick := func(opts: Array) -> String:
		for o: String in opts:
			if gsf.has_animation(o) and not is_alias(gsf, o):
				return o
		return str(opts[-1])
	match tool:
		"hold", "eat":
			return pick.call(["hold_down", "celebrate", "idle"])
		"cast":
			return pick.call(["cast_right", "idle"])
		"reel":
			return pick.call(["reel_right", "cast_right", "idle"])
		"water":
			return pick.call({"_down": ["hold_down", "idle_down", "idle"], "_up": ["idle_up", "idle"], "_right": ["idle", "idle_down"]}[dir])
	return attack


## C14b P5 (c14b_07-02/05, 16-08, 14-19): idle strips read as a breath, not
## a tick: the rest frame is held about twice as long as the others, and a
## 3+-frame idle plays out and back (0,1,2,1) so the loop never pops.
const MISCUT_IDLE := {"bo": ["idle", "idle_down", "idle_up"], "president": ["idle"]}
const IDLE_ANIMS := ["idle", "idle_down", "idle_up", "idle_side"]


static func _breath_timing(sf: SpriteFrames, g := "") -> void:
	for a: String in IDLE_ANIMS:
		if not sf.has_animation(a) or sf.get_meta("breath_" + a, false):
			continue
		sf.set_meta("breath_" + a, true)
		var n := sf.get_frame_count(a)
		var blink := _blink_tex(g, a, sf)
		if blink != null:
			_weave_blink(sf, a, blink)
			continue
		if n < 2:
			continue
		if n >= 3 and n <= 4:
			for i in range(n - 2, 0, -1):  # ping-pong back to the rest frame
				sf.add_frame(a, sf.get_frame_texture(a, i), sf.get_frame_duration(a, i))
		sf.set_frame(a, 0, sf.get_frame_texture(a, 0), 2.2)
		sf.set_animation_speed(a, 3.0 if n >= 3 else 2.4)


## C14b P5: a blink frame (tools/slice_c14b_p5.py: the drawn idle with the eyes
## closed, everything else pixel-identical) for a front idle, else null.
static func _blink_tex(g: String, a: String, sf: SpriteFrames) -> Texture2D:
	if g == "" or not a in ["idle", "idle_down"]:
		return null
	for src: String in ["idle_down", "idle"]:
		var b := "c14bp5_blink_" + src
		if Art.has(g, b):
			var bt := Art.tex(g, b)
			var inf := Art.info(g, b)
			var n := maxi(1, int(inf.get("frames", 1)))
			# Only when the idle shows that strip's first cell (sizes match).
			var f0 := sf.get_frame_texture(a, 0)
			if f0 == null or absi(f0.get_height() - int(inf.get("cell_h", 0))) > 1:
				return null
			if n == 1:
				return bt
			var at := AtlasTexture.new()
			at.atlas = bt
			at.region = Rect2(0, 0, float(inf.get("cell_w", bt.get_width() / n)), float(inf.get("cell_h", bt.get_height())))
			return at
	return null


## The breath with a blink about every 4.6 s: rest (held), inhale, rest, a
## quick blink, rest, inhale. One-frame idles get rest + blink.
static func _weave_blink(sf: SpriteFrames, a: String, blink: Texture2D) -> void:
	var f0 := sf.get_frame_texture(a, 0)
	var f1 := sf.get_frame_texture(a, 1) if sf.get_frame_count(a) > 1 else f0
	sf.clear(a)
	sf.set_animation_speed(a, 4.0)
	sf.set_animation_loop(a, true)
	for fr: Array in [[f0, 6.0], [f1, 3.0], [f0, 4.0], [blink, 0.6], [f0, 2.0], [f1, 3.0]]:
		sf.add_frame(a, fr[0], fr[1])


static func _drop_frame(sf: SpriteFrames, a: String, i: int) -> void:
	if sf.has_animation(a) and sf.get_frame_count(a) > i + 1:
		sf.remove_frame(a, i)


## True when `anim` is a borrowed stand-in (not drawn for this action).
static func is_alias(sf: SpriteFrames, anim: String) -> bool:
	return sf != null and (sf.get_meta("aliased", {}) as Dictionary).has(anim)


## Heroes whose attack frames are empty-handed (punches, jabs, a cane): a held
## sword or club is drawn over the swing. Every gangster-arc outfit is.
static func unarmed_attack(id: String) -> bool:
	return id.ends_with("_gang")


## Sprite anchored at its feet (bottom-center), like the strips.
static func _alias(sf: SpriteFrames, new_name: String, from: String) -> void:
	if not sf.has_animation(from):
		return
	# Remember stand-ins: a tool swing drawn with someone's punch frames gets the
	# tool itself drawn over it (HeldSwing).
	var al: Dictionary = sf.get_meta("aliased", {})
	al[new_name] = from
	sf.set_meta("aliased", al)
	sf.add_animation(new_name)
	sf.set_animation_speed(new_name, sf.get_animation_speed(from))
	sf.set_animation_loop(new_name, sf.get_animation_loop(from))
	for i in sf.get_frame_count(from):
		sf.add_frame(new_name, sf.get_frame_texture(from, i), sf.get_frame_duration(from, i))


static func make_sprite(id: String) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames_for(id)
	if s.sprite_frames.has_animation("idle"):
		s.animation = "idle"
	var h := int(strip_info(id)["cell_h"]) if data().has(id) else int(Art.info("characters/" + id, "idle").get("cell_h", 64))
	s.centered = true
	s.offset = Vector2(0, -h / 2.0)
	# Everyone is drawn to the same world height as the villagers (24 px), so
	# the hero doesn't tower over the town. The penguin hero is half a villager.
	var sc := SPRITE_SCALE
	var hero := data().has(id) or (id.ends_with("_gang") and data().has(id.trim_suffix("_gang")))
	var target := float(TARGET_H.get(id, HERO_H if hero else NPC_H))
	if h > 0:
		sc = target / float(h)
	s.scale = Vector2(sc, sc)
	# Frames from different strips have different cell heights; keep feet planted.
	# animation_changed too: a swap that lands on frame 0 from frame 0 emits no
	# frame_changed, which left the feet at the old strip's height for a frame.
	var fit := func() -> void:
		var tex := s.sprite_frames.get_frame_texture(s.animation, s.frame)
		if tex:
			s.offset = Vector2(0, -tex.get_height() / 2.0)
	s.frame_changed.connect(fit)
	s.animation_changed.connect(fit)
	return s

class_name FarmAnimal
extends AnimatedSprite2D
## A farm animal from art/gen/animals/<kind>: idle, walk, eat (and baby) strips.
## Wanders slowly inside its pen, grazes, and can be petted (A) for friendship.
## C11a: roster animals come from Ranch (setup_uid: node name = uid, look/height from data/ranch.json,
## a small need bubble over the head, a fixed huddle slot at night/in bad weather, tap spots never stacked).

var kind := ""
var uid := ""  # Ranch roster id ("" = an old-style kind-only animal)
var map: GameMap
var pen := Rect2i()
var _target := Vector2.ZERO
var _wait := 1.0
var _state := "idle"
var _rng := RandomNumberGenerator.new()


var baby := false
## Babies whose own strips are unusable: [parent kind, strip, size]. (The calf
## has its own redrawn strips since round 13.)
const BABY_OF := {"chick": ["chicken2", "baby", 1.0], "kid_goat": ["goat", "idle", 0.6]}
## Kinds whose own idle strip is keyed-out scraps (c14b_14-08): always drawn from BABY_OF.
const SCRAP_ART := ["kid_goat"]
# C14b P6 idle life: held idle frames, per-animal phase, breath, sleep at night, cheer on petting.
var _ph := 0.0
var _base_sc := Vector2.ONE
var _spd_j := 1.0
var _hop := 0.0
var _at := Vector2i(-999, -999)  # the cell that holds this animal's interact thing
## True-to-life heights on screen (px, idle frame's drawn height), C5: the strips
## come from different sheets (36-px cells, big 105-px cells), so a fixed 0.5 scale
## made the Big Barn goat twice a cow. Babies are 60% of their parent.
const TARGET_H := {"chicken2": 16.0, "rooster": 17.0, "duck2": 15.0, "chick": 10.0,
	"cow_brown": 26.0, "cow_bw": 26.0, "calf": 16.0, "sheep_woolly": 20.0, "lamb": 12.0,
	"goat": 20.0, "goat2": 20.0, "goat_kid": 12.0, "llama": 30.0, "pig_a": 18.0, "horse3": 32.0,
	"llama_b": 30.0, "llama_cria": 16.0, "pig_b": 18.0, "piglet": 10.0, "rabbit_brown": 10.0, "rabbit_white": 10.0,
	"donkey": 24.0, "donkey_b": 24.0, "foal": 16.0, "foal_b": 16.0, "sheep": 18.0, "kid_goat": 12.0, "bee_swarm": 8.0}
const BABY_SHARE := 0.6
static var _art_h := {}  # kind -> px from art/gen/animals/_ranch_art.json "height" (P6), loaded once
static var _art_babies := {}  # baby kinds named in _ranch_art.json (drawn at their own height)


## True-to-life drawn height of an art kind: P6's _ranch_art.json first, then TARGET_H (0 = unknown).
static func target_h(k: String) -> float:
	if _art_h.is_empty():
		_art_h["_"] = 0.0
		var f := FileAccess.open("res://art/gen/animals/_ranch_art.json", FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text()) if f else null
		if d is Dictionary:
			for sp: String in d:
				if sp.begins_with("_") or not (d[sp] is Dictionary):
					continue
				var row: Dictionary = d[sp]
				if row.get("height", null) is Dictionary:
					for kk: String in row["height"]:
						_art_h[kk] = float(row["height"][kk])
				if str(row.get("baby", "")) != "":
					_art_babies[str(row["baby"])] = true
	if _art_h.has(k) and k != "_":
		return float(_art_h[k])
	return float(TARGET_H.get(k, 0.0))
static var _h_cache := {}  # kind -> [drawn height, drawn width] of idle frame 0 at scale 1
var _shadow: Node2D


## A roster animal (Ranch uid): its look, height and tint come from Ranch.art_for (data/ranch.json).
func setup_uid(m: GameMap, id: String, c: Vector2i, p: Rect2i) -> void:
	uid = id
	var art := Ranch.art_for(id)
	var g := str(art.get("group", "animals/chicken2"))
	var k := g.trim_prefix("animals/")
	_height = float(art.get("height_px", 0.0))
	_strip = str(art.get("strip", "idle"))
	setup(m, k, c, p, bool(art.get("baby", false)))
	name = id
	if art.get("tint", null) is Color:
		self_modulate = art["tint"]  # the body only: the need bubble and shadow keep their colours (c11b_11-02)
	var sp := Ranch.species(str(art.get("species", "")))
	if str(sp.get("glow", "")) != "":  # glow sheep, lab strains: a coloured light that walks with it
		NightGlow.add_light(m, self, float(sp.get("glow_r", 22.0)), float(art.get("height_px", 16.0)) * 0.5, Color(str(sp["glow"])))
	_refresh_thing()


var _height := 0.0  # Ranch height override (px)
## The building's door cell (P2 sets it from the farm layout): roster animals walk there and go in at
## night / in storms / in winter (Ranch.indoors), and come back out in the morning. (-999 = no door: huddle.)
var door := Vector2i(-999, -999)
var inside := false
var _strip := "idle"
var _bubble: Sprite2D
var _need := "-"
var _need_t := 0.0


## The voice for a tap (c11b_03-06): the Ranch species' voice for roster animals (lab strains included),
## else the art-kind prefix table (GameMap.animal_voice). Ranch voice words map to sfx names.
const VOICE_SFX := {"baa": "sheep", "hum": "bleat", "squeak": "thump", "chirp_bot": "beep", "hum_baa": "sheep",
	"servo_bleat": "bleat", "bunny_beep": "beep"}


static func voice_for(k: String, id := "") -> String:
	# c13_09-02: one answer for every species and its babies (RanchVoice), the old tables after it.
	var rv := RanchVoice.file_of(id if id != "" else k)
	if rv != "" and not k in ["chick"]:
		return rv
	if id != "":
		var a := Ranch.animal(id)
		var sid := str(a.get("species", ""))
		if sid != "" and Ranch.is_adult(id) or (sid != "" and not ["chicken", "duck", "cow", "sheep", "goat", "pig"].has(sid)):
			var v := str(Ranch.species(sid).get("voice", ""))
			if v != "":
				return str(VOICE_SFX.get(v, v))
	return GameMap.animal_voice(k)


## Drawn scale for an art kind at its true-to-life height (followers, menus): 0.5 when unknown.
static func scale_for(k: String, tex: Texture2D = null) -> float:
	var th := target_h(k)
	if th <= 0.0:
		return 0.5
	var h := 0.0
	if _h_cache.has(k):
		h = (_h_cache[k] as Vector2).y
	elif tex:
		var img := tex.get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			h = float(img.get_used_rect().size.y)
	return th / h if h > 4.0 else 0.5


func setup(m: GameMap, k: String, c: Vector2i, p: Rect2i, is_baby := false) -> void:
	map = m
	kind = k
	baby = is_baby
	name = "%s_%d_%d" % [k, c.x, c.y]  # stable: petting is once per animal per day
	pen = p if p.size != Vector2i.ZERO else Rect2i(c.x - 1, c.y - 1, 3, 3)
	var g := "animals/" + k
	var sc := 0.5
	var anims := {"idle": "baby" if is_baby and Art.has(g, "baby") and not Art.has(g, "idle") else "idle"}
	if _strip != "idle" and Art.has(g, _strip):
		anims["idle"] = _strip  # a hatchling drawn from its parent's baby strip (Ranch art.baby)
	var fps := {"idle": 3.0}
	if BABY_OF.has(k) and (not Art.has(g, "idle") or k in SCRAP_ART):  # P6 drew a real chick: the scrap fallback only for old art
		# The chick cut is an unusable scrap: a hatchling from the hen's baby strip.
		var b: Array = BABY_OF[k]
		g = "animals/" + str(b[0])
		sc *= float(b[2])
		anims = {"idle": str(b[1]), "walk": str(b[1]) if str(b[1]) != "idle" else "walk"}
		fps = {"idle": 3.0, "walk": 6.0}
	else:
		for a in (["walk"] if is_baby else ["walk", "eat"]):
			if Art.has(g, a):
				anims[a] = a
				fps[a] = 7.0 if a == "walk" else 3.0  # c14b_11-06: legs at 7 fps (was 6 x 0.7)
		# c14b_09-02 / 11-18: the drawn sleep / happy strips.
		for a2: String in ["sleep", "happy"]:
			if not is_baby and Art.has(g, a2):
				anims[a2] = a2
				fps[a2] = 1.2 if a2 == "sleep" else 6.0
	sprite_frames = Art.frames(g, anims, fps, {"happy": false})
	sprite_frames = idle_frames(sprite_frames, hash(k + str(c)))
	animation = "idle"
	var hw := _drawn_size(k)
	if _height > 0.0 and hw.y > 0.0:
		sc = _height / hw.y  # Ranch: species/baby height from data
	elif target_h(k) > 0.0 and hw.y > 0.0:
		sc = target_h(k) / hw.y
		if is_baby and not k in ["calf", "lamb", "goat_kid", "chick"] and not _art_babies.has(k):
			sc *= BABY_SHARE  # a young one drawn from its parent's strip
	scale = Vector2(sc, sc)
	_base_sc = scale
	_add_shadow(hw.x * sc if hw.x > 0.0 else 16.0)
	position = m.cell_center(c)
	# Feet on the ground for every strip (walk/eat cells differ from idle's).
	frame_changed.connect(_fit)
	animation_changed.connect(_fit)
	_fit()
	_rng.seed = hash(k) + c.x * 31 + c.y
	_target = position
	z_index = 0
	play("idle")
	# c14b_09-01 / 11-05: a herd never syncs: random start frame, small speed jitter, own breath phase.
	_ph = _rng.randf()
	CreatureMotion.random_start(self, _rng, 0.1)
	_spd_j = speed_scale
	var fc := _free_cell(c)
	if fc != c:
		position = m.cell_center(fc)
		_target = position
	_at = fc
	m.set_thing(fc.x, fc.y, {"type": "pet_animal", "hint": "A: pet the %s" % k.split("_")[0].rstrip("0123456789"), "animal": self, "uid": uid}, false)


## The nearest cell in the pen with no thing on it (two animals never share a tap spot, c11a_05-17).
func _free_cell(c: Vector2i) -> Vector2i:
	if not map.things.has(c):
		return c
	var best := c
	var bd := 1 << 30
	for x in range(pen.position.x, pen.end.x):
		for y in range(pen.position.y, pen.end.y):
			var q := Vector2i(x, y)
			if map.things.has(q) or map.blocked.has(q):
				continue
			var dd := (q - c).length_squared()
			if dd < bd:
				bd = dd
				best = q
	return best


## The interact thing's hint/uid kept in step with Ranch (name, hungry, goods ready).
func _refresh_thing() -> void:
	if uid == "" or map == null or not map.things.has(_at):
		return
	var t: Dictionary = map.things[_at]
	if t.get("animal", null) != self:
		return
	t["uid"] = uid
	t["hint"] = Ranch.hint(uid, GameState.held_item())


## The need bubble (goods / hungry / pet) over the head; hidden when content. Uses existing emote art.
func refresh_need() -> void:
	if uid == "":
		return
	var nd := Ranch.need(uid)
	if GameState.is_night():
		nd = ""
	_refresh_thing()
	if nd == _need:
		return
	_need = nd
	var tex: Texture2D = null
	match nd:
		"goods":
			var r := Ranch.ready(uid)
			tex = Art.tex("items", str(r.get("item", ""))) if Art.has("items", str(r.get("item", ""))) else null
		"hungry":
			tex = Art.tex("items", "hay") if Art.has("items", "hay") else null
		"pet":
			tex = Art.tex("emotes", "heart") if Art.has("emotes", "heart") else null
	if tex == null:
		if _bubble:
			_bubble.visible = false
		return
	if _bubble == null:
		_bubble = Sprite2D.new()
		_bubble.z_index = 2
		add_child(_bubble)
	_bubble.texture = tex
	var want := 9.0 if nd != "pet" else 7.0  # px on screen, phone readable but small
	var s2 := want / maxf(1.0, float(tex.get_height())) / scale.y
	_bubble.scale = Vector2(s2, s2)
	_bubble.position = Vector2(0, -(_drawn_size(kind).y + 6.0) / scale.y)
	_bubble.modulate = Color(1, 1, 1, 0.9 if nd != "pet" else 0.7)
	_bubble.visible = true


## Going in / coming out (c11a_03-05). True while the walk to the door owns this frame.
func _shelter_step() -> bool:
	var want := Ranch.indoors(uid)
	if want and not inside:
		var dp := map.cell_center(door)
		if position.distance_to(dp) < 3.0:
			inside = true
			visible = false
			if map.things.has(_at) and map.things[_at].get("animal", null) == self:
				map.things.erase(_at)  # asleep in the barn: no tap spot outside
			_at = Vector2i(-999, -999)
		else:
			_target = dp
			_state = "walk"
			_play("walk")
		return false
	if not want and inside:
		inside = false
		visible = true
		position = map.cell_center(door)
		var c := _free_cell(Vector2i(clampi(door.x, pen.position.x, pen.end.x - 1), clampi(door.y, pen.position.y, pen.end.y - 1)))
		_target = map.cell_center(c)
		_state = "walk"
		_play("walk")
		_at = c
		map.set_thing(c.x, c.y, {"type": "pet_animal", "hint": Ranch.hint(uid), "animal": self, "uid": uid}, false)
	return false


## Fixed huddle cell: the pen's animals by name fill rows back to front (no stacking, c11a_06).
func _huddle_cell() -> Vector2i:
	var mates: Array = []
	for ch in get_parent().get_children() if get_parent() else []:
		if ch is FarmAnimal and (ch as FarmAnimal).pen == pen:
			mates.append(str(ch.name))
	mates.sort()
	var i := maxi(0, mates.find(str(name)))
	var w := maxi(1, pen.size.x)
	return Vector2i(pen.position.x + i % w, pen.position.y + mini(pen.size.y - 1, i / w))


## Held idle: the rest frame long, the blink / ear frame short (shared copies per hold bucket).
static func idle_frames(sf: SpriteFrames, h: int) -> SpriteFrames:
	if sf == null or not sf.has_animation("idle") or sf.get_frame_count("idle") < 2:
		return sf
	var holds := [2.6, 3.6, 4.8, 6.0]
	return CreatureMotion.held_idle(sf, "idle", holds[absi(h) % holds.size()], 0.16 if sf.get_frame_count("idle") == 2 else 0.18)


## Petted / fed: one happy beat and a tiny hop (c14b_09-02). Called from GameMap.pet_farm_animal.
func cheer() -> void:
	if sprite_frames and sprite_frames.has_animation("happy") and _state != "walk":
		animation = "happy"
		play("happy")
		speed_scale = 1.0
		if not animation_finished.is_connected(_after_cheer):
			animation_finished.connect(_after_cheer, CONNECT_ONE_SHOT)
	if not CreatureMotion.reduced():
		_hop = 0.25


func _after_cheer() -> void:
	if animation == "happy":
		_play("idle", true)


const FLOAT_WORDS := ["jelly", "seahorse", "wisp", "sprite", "ghost", "spirit"]
var _float_k := -1


## Floating / glowing creatures (star jelly, coral seahorse, wisps): they hover, never stand.
func _floats() -> bool:
	if _float_k < 0:
		_float_k = 0
		for w: String in FLOAT_WORDS:
			if w in kind:
				_float_k = 1
	return _float_k == 1


## Asleep when it is night and the animal is resting in its huddle spot.
func _sleepy() -> bool:
	return GameState.is_night() and _state != "walk" and sprite_frames != null and sprite_frames.has_animation("sleep")


func _process(delta: float) -> void:
	if map == null or map.player == null:
		return
	# Y-sort like props: z by feet.
	z_index = 0
	# Breath (feet anchored by _fit's offset) and the cheer hop.
	var br := CreatureMotion.breath(_ph, 0.012 if animation == "sleep" else 0.02, (3.6 if animation == "sleep" else 2.6) + _ph)
	scale = _base_sc * br
	if _hop > 0.0:
		_hop = maxf(0.0, _hop - delta)
		offset.y = _fit_y - 6.0 * sin(PI * (1.0 - _hop / 0.25))
	elif _floats():
		offset.y = _fit_y + CreatureMotion.hover(_ph, 3.0, 3.0 + _ph) / maxf(0.05, scale.y)  # c14b_09-18: floaters hover
	elif animation == "idle" and _sleepy():
		_play("sleep")
	elif animation == "sleep" and not _sleepy():
		_play("idle")
	_need_t -= delta
	if _need_t <= 0.0 and uid != "":
		_need_t = 0.5
		refresh_need()
		if door.x > -999 and _shelter_step():
			return
	if inside:
		return
	_wait -= delta
	if _state == "walk":
		var d := _target - position
		if d.length() < 1.5:
			_state = "idle"
			_wait = _rng.randf_range(1.5, 4.0)
			_play("idle")
		else:
			position += d.normalized() * 10.0 * delta
			if absf(d.x) > 0.5:
				flip_h = d.x < 0
	elif _wait <= 0.0 and not (door.x > -999 and uid != "" and Ranch.indoors(uid)):
		var r := _rng.randf()
		if _sleepy() and map.world_to_cell(position) == _huddle_cell():
			_state = "idle"
			_wait = _rng.randf_range(6.0, 12.0)  # asleep in its spot: stays put till morning
			_play("sleep")
		elif r < 0.45:
			_state = "walk"
			var c := Vector2i(_rng.randi_range(pen.position.x, pen.end.x - 1), _rng.randi_range(pen.position.y, pen.end.y - 1))
			# At night, in rain and in winter they huddle at the back of the pen, by the barn.
			# Two rows (and spread along them), so a herd never stacks into one line.
			if GameState.is_night() or GameState.is_wet() or GameState.season() == "winter":
				c = _huddle_cell()
			if map.blocked.has(c):
				_wait = 0.5
				_state = "idle"
			else:
				_target = map.cell_center(c)
				_play("walk")
		elif r < 0.75 and sprite_frames.has_animation("eat"):
			_state = "eat"
			_wait = _rng.randf_range(2.0, 4.0)
			_play("eat")
		else:
			_state = "idle"
			_wait = _rng.randf_range(1.0, 3.0)
			_play("idle")
	# Keep the interact thing under the animal.
	var cell := map.world_to_cell(position - Vector2(0, 2))
	if cell == _at:
		return  # still on the same cell: nothing to move
	if map.things.has(cell) and map.things[cell].get("animal", null) != self:
		return  # never sit on (or erase) a crop, rock or another animal's spot
	if map.things.has(_at) and map.things[_at].get("animal", null) == self:
		var t: Dictionary = map.things[_at]
		map.things.erase(_at)
		map.things[cell] = t
		_at = cell
	else:
		for c: Vector2i in map.things.keys():
			var t2: Dictionary = map.things[c]
			if t2.get("animal", null) == self:
				map.things.erase(c)
				map.things[cell] = t2
				_at = cell
				break


func _play(a: String, force := false) -> void:
	if animation == "happy" and is_playing() and not force:
		return  # let the cheer finish
	if a == "idle" and _sleepy():
		a = "sleep"
	if sprite_frames.has_animation(a) and animation != a:
		animation = a
		play(a)
		speed_scale = _spd_j
		if a == "idle" or a == "sleep":
			CreatureMotion.random_start(self, _rng, 0.0)
			speed_scale = _spd_j


var _fit_y := 0.0


func _fit() -> void:
	var tex := sprite_frames.get_frame_texture(animation, frame) if sprite_frames else null
	if tex:
		offset = Vector2(0, -tex.get_height() / 2.0 + 2.0)
		_fit_y = offset.y


## The idle frame's drawn (alpha) size at scale 1, cached per kind.
func _drawn_size(k: String) -> Vector2:
	if _h_cache.has(k):
		return _h_cache[k]
	var out := Vector2.ZERO
	var tex := sprite_frames.get_frame_texture("idle", 0) if sprite_frames and sprite_frames.has_animation("idle") else null
	if tex:
		out = Vector2(tex.get_width(), tex.get_height())
		var img := tex.get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			var r := img.get_used_rect()
			if r.size.y > 4:
				out = Vector2(r.size)
	_h_cache[k] = out
	return out


## A soft ground shadow sized by the animal's width (screen px).
func _add_shadow(w: float) -> void:
	_shadow = AnimalShadow.new()
	_shadow.w = clampf(w * 0.8, 6.0, 30.0)
	_shadow.scale = Vector2(1.0 / scale.x, 1.0 / scale.y)
	_shadow.position = Vector2(0, -1.0) * (1.0 / scale.y)
	_shadow.show_behind_parent = true
	add_child(_shadow)


class AnimalShadow:
	extends Node2D
	var w := 16.0
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
		draw_circle(Vector2.ZERO, w / 2.0, Color(0, 0, 0, 0.22))
		draw_circle(Vector2.ZERO, w / 2.0 - 2.0, Color(0, 0, 0, 0.12))

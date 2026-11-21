class_name Anim
extends RefCounted
## C14b animation core (contract C14B_CONTRACT.md section 1). Static helpers every
## package uses so ambient motion is smooth, on GAME time (stops while paused),
## never in lockstep, wind-aware and reduced-motion aware.
##
## - Anim.t(): seconds of game time (PlayClock).
## - Anim.phase(node_or_cell): stable 0..1 phase from a position / cell / id.
## - Anim.wind() 0..1 (smoothed, by weather + season + map), Anim.gust(phase) 0..1.
## - Anim.reduced(): Settings.reduced_motion(); ambient loops ~30% amplitude.
## - Anim.sway_material(strength): ONE shared ShaderMaterial (shaders/sway.gdshader)
##   per strength step; per-node phase comes from world position inside the shader
##   (no material per node, so props keep batching).
## - Anim.strip_fps(id, default) / Anim.apply(sprite, id): timing from data/anim_c14b.json.
## - Anim.bob(node, amp, period) / Anim.breathe(sprite, amp, period): cheap code motion.
## - Anim.tick(): once per frame (GameMap/Scenery call it; frame-guarded) to feed
##   the shared sway materials their time and wind.

const DATA := "res://data/anim_c14b.json"
## Base wind by weather (0..1 before season/map factors).
const WEATHER_WIND := {"clear": 0.25, "sun": 0.25, "fireflies": 0.2, "petals": 0.4, "leaves": 0.45,
	"fog": 0.1, "rain": 0.6, "drizzle": 0.45, "hail": 0.7, "snow": 0.4, "wind": 0.9, "storm": 1.0,
	"blizzard": 1.0, "sandstorm": 0.9, "dust": 0.6, "ash": 0.3, "meteors": 0.2}
const REDUCED_AMP := 0.3
## Sway strength steps get one shared material each (bushes/hedges/snowy 0.5, trees/flowers 1.0, grass/crops/cloth 1.6): 3 materials max.
const STRENGTHS := [0.5, 1.0, 1.6]

static var _data: Dictionary = {}
static var _loaded := false
static var _mats: Dictionary = {}  # strength step -> ShaderMaterial
static var _frame := -1
static var _wind := -1.0  # smoothed; -1 = not yet set (snap to target first time)
static var _weather := ""  # set by Scenery each frame; "" = calendar weather
static var _map_id := ""
static var _indoor := false
static var _last_t := 0.0


static func t() -> float:
	return PlayClock.now()


static func reduced() -> bool:
	return Settings.reduced_motion()


## Amplitude factor for ambient loops: 1.0, or about 0.3 with reduced motion.
static func amp() -> float:
	return REDUCED_AMP if reduced() else 1.0


## Stable pseudo-random 0..1 from a node (its global position, else instance id),
## a Vector2/Vector2i (cell or point), an int or a String. Neighbours differ.
static func phase(v: Variant) -> float:
	var p := Vector2.ZERO
	if v is Node2D:
		p = (v as Node2D).global_position if (v as Node2D).is_inside_tree() else (v as Node2D).position
	elif v is Control:
		p = (v as Control).position
	elif v is Vector2:
		p = v
	elif v is Vector2i:
		p = Vector2(v) * 16.0
	elif v is int:
		p = Vector2(float(v) * 7.13, float(v) * 3.71)
	elif v is String:
		var h := hash(v)
		p = Vector2(float(h % 9973), float((h / 9973) % 9967))
	elif v is Object:
		var id := (v as Object).get_instance_id()
		p = Vector2(float(id % 9973), float((id / 9973) % 9967))
	var s := sin(p.x * 12.9898 + p.y * 78.233) * 43758.5453
	return s - floorf(s)


## Feed the scene's weather (Scenery calls this; empty = calendar weather).
static func set_weather(w: String, map_id := "", indoor := false) -> void:
	_weather = w
	_map_id = map_id
	_indoor = indoor


static func wind_target() -> float:
	if _indoor:
		return 0.0
	var w := _weather
	if w == "" and not GameState.run.is_empty():
		w = GameState.weather_today()
	var k := float(WEATHER_WIND.get(w, 0.25))
	var se := GameState.look_se() if not GameState.run.is_empty() else "spring"
	if se == "fall":
		k += 0.1
	if _map_id in Ambience.WINDY_MAPS:
		k *= 1.25
	k = clampf(k, 0.0, 1.0)
	if reduced():
		k = minf(k, REDUCED_AMP)
	return k


## Current wind strength 0..1, eased toward the weather's target over ~3 s.
static func wind() -> float:
	if _wind < 0.0:
		_wind = wind_target()
	return _wind


## Occasional gust 0..1 (slow noise: mostly 0, a soft swell every 8-15 s of game time).
static func gust(ph := 0.0) -> float:
	if reduced():
		return 0.0
	var x := t() * 0.09 + ph * 3.7
	var n := 0.5 + 0.3 * sin(x * TAU) + 0.2 * sin(x * TAU * 2.37 + 1.3)
	return clampf((n - 0.62) / 0.38, 0.0, 1.0)


## Once per frame: smooth the wind and push time/wind into the shared sway materials.
static func tick() -> void:
	var f := Engine.get_process_frames()
	if f == _frame:
		return
	_frame = f
	var now := t()
	var dt := clampf(now - _last_t, 0.0, 0.25)
	_last_t = now
	var tgt := wind_target()
	if _wind < 0.0:
		_wind = tgt
	else:
		_wind = lerpf(_wind, tgt, 1.0 - exp(-dt / 1.0))  # ~3 s to settle
	if _mats.is_empty():
		return
	var wv := _wind * amp()
	var gv := gust()
	for m: ShaderMaterial in _mats.values():
		m.set_shader_parameter("game_t", now)
		m.set_shader_parameter("wind", wv)
		m.set_shader_parameter("gust", gv)


static func _step(strength: float) -> float:
	var best: float = STRENGTHS[0]
	for s: float in STRENGTHS:
		if absf(s - strength) < absf(best - strength):
			best = s
	return best


## Shared sway material (one per strength step). Vertex sway pinned at the
## sprite's base, phase from world position (no lockstep, no per-node uniforms).
static func sway_material(strength := 1.0) -> ShaderMaterial:
	var k := _step(strength)
	if not _mats.has(k):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/sway.gdshader")
		m.set_shader_parameter("strength", k)
		m.set_shader_parameter("game_t", t())
		m.set_shader_parameter("wind", wind() * amp())
		m.set_shader_parameter("crisp", 1.0 if CrispArt.on() else 0.0)
		_mats[k] = m
	return _mats[k]


## Sway kind by art name: strength for nature/cloth names, or 0.0 (no sway).
## Rocks, logs, stumps, fences, buildings never sway.
const SWAY_NO := ["street", "lamp", "pot", "crate", "box", "barrel", "rock", "stone", "log", "stump", "fence", "boulder", "crystal", "ore", "statue", "sign", "well", "bench", "dead", "bare", "snag", "shake", "_cut", "chopped", "mushroom", "pumpkin", "melon"]
const SWAY_KIND := [["tgrass", 1.3], ["tall_grass", 1.3], ["grass", 1.3], ["reed", 1.3], ["cattail", 1.3], ["wheat", 1.3], ["crop", 1.3],
	["flag", 1.8], ["banner", 1.8], ["bunting", 1.8], ["laundry", 1.8], ["pennant", 1.8],
	["flower", 1.0], ["tulip", 1.0], ["daisy", 1.0], ["rose", 1.0], ["sunflower", 1.0], ["lavender", 1.0], ["fern", 1.0],
	["bush", 0.6], ["shrub", 0.6], ["hedge", 0.4], ["berry", 0.6],
	["willow", 1.0], ["palm", 1.0], ["tree", 1.0], ["oak", 1.0], ["pine", 0.6], ["birch", 1.0], ["maple", 1.0], ["ftree", 1.0], ["sapling", 1.0]]


static func sway_strength(name: String) -> float:
	var n := name.to_lower()
	for w: String in SWAY_NO:
		if w in n:
			return 0.0
	for e: Array in SWAY_KIND:
		if str(e[0]) in n:
			var s := float(e[1])
			if n.ends_with("_winter") or "snow" in n:
				s *= 0.4  # snowy/bare winter art barely moves (c14b_03-11)
			return s
	return 0.0


static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(DATA):
			var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
			if v is Dictionary:
				_data = v
	return _data


## Overrides for an art id ("name" or "group/name"): {fps, pingpong, random_start}.
static func entry(id: String) -> Dictionary:
	var d := data()
	if d.has(id):
		return d[id]
	var short := id.get_file()
	if d.has(short):
		return d[short]
	return {}


static func strip_fps(id: String, default: float) -> float:
	return float(entry(id).get("fps", default))


## Apply timing to an AnimatedSprite2D showing strip `id`: data fps, random start
## frame + small speed variance (on by default), optional ping-pong.
static func apply(sprite: AnimatedSprite2D, id: String) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var e := entry(id)
	var an := sprite.animation
	if not sprite.sprite_frames.has_animation(an):
		return
	if e.has("fps") or bool(e.get("pingpong", false)):
		var sf: SpriteFrames = sprite.sprite_frames.duplicate() if bool(e.get("pingpong", false)) else sprite.sprite_frames
		if e.has("fps"):
			if sf == sprite.sprite_frames:
				sf = sf.duplicate()
			sf.set_animation_speed(an, float(e["fps"]))
		if bool(e.get("pingpong", false)) and not sf.has_meta("pingpong"):
			var n := sf.get_frame_count(an)
			for k in range(n - 2, 0, -1):
				sf.add_frame(an, sf.get_frame_texture(an, k))
			sf.set_meta("pingpong", true)
		sprite.sprite_frames = _shared(sf, id)
	if bool(e.get("random_start", true)):
		var ph := phase(sprite)
		var n2 := sprite.sprite_frames.get_frame_count(an)
		if n2 > 1:
			sprite.frame = int(ph * n2) % n2
			sprite.frame_progress = fposmod(ph * 7.0, 1.0)
		sprite.speed_scale = 0.92 + 0.16 * fposmod(ph * 13.0, 1.0)


static var _sf_cache: Dictionary = {}


## Same id + same overrides share one SpriteFrames (batching, memory).
static func _shared(sf: SpriteFrames, id: String) -> SpriteFrames:
	var key := id + str(entry(id))
	if not _sf_cache.has(key):
		_sf_cache[key] = sf
	return _sf_cache[key]


## Snap to 0.5 px (the canvas is 270 wide; 2x art at 0.5 scale) so slow motion never shimmers.
static func snap(v: float) -> float:
	return roundf(v * 2.0) / 2.0


## Gentle vertical bob for a node (call every frame with its rest y, or let it
## keep a meta rest). Returns the offset applied.
static func bob(node: Node2D, amp_px: float, period_s: float) -> float:
	if node == null:
		return 0.0
	if not node.has_meta("anim_rest_y"):
		node.set_meta("anim_rest_y", node.position.y)
	var o := snap(sin((t() / maxf(period_s, 0.05) + phase(node)) * TAU) * amp_px * amp())
	node.position.y = float(node.get_meta("anim_rest_y")) + o
	return o


## Subtle breathing: vertical scale pulse pinned at the feet (sprite scale y).
static func breathe(sprite: Node2D, amp: float, period_s: float) -> float:
	if sprite == null:
		return 0.0
	if not sprite.has_meta("anim_rest_sy"):
		sprite.set_meta("anim_rest_sy", sprite.scale.y)
	var k := sin((t() / maxf(period_s, 0.05) + phase(sprite)) * TAU) * amp * amp()
	sprite.scale.y = float(sprite.get_meta("anim_rest_sy")) * (1.0 + k)
	return k


## Tests.
static func _reset() -> void:
	_mats.clear()
	_sf_cache.clear()
	_wind = -1.0
	_weather = ""
	_map_id = ""
	_indoor = false
	_frame = -1
	_loaded = false
	_data = {}


## C14b animation budget counters for a map (perf_probe PERF_JSON, anim_budget_test):
## anim = AnimatedSprite2D total, anim_onscreen = inside `view` (world rect),
## proc = nodes processing, mats = distinct ShaderMaterial instances (hit-flash excluded), lock = groups
## of 3+ anim_props on one strip all on the same frame and speed (lockstep).
static func budget(root: Node, view := Rect2()) -> Dictionary:
	var out := {"anim": 0, "anim_onscreen": 0, "proc": 0, "mats": 0, "lock": 0}
	var mats := {}
	var groups := {}
	for n in root.find_children("*", "", true, false):
		if n.is_processing():
			out["proc"] += 1
		if n is CanvasItem:
			var mt: Material = (n as CanvasItem).material
			if mt is ShaderMaterial and not (mt as ShaderMaterial).shader.resource_path.ends_with("flash.gdshader"):
				mats[mt.get_instance_id()] = true  # (per-character hit-flash materials are state, counted apart)
		if n is AnimatedSprite2D:
			var a := n as AnimatedSprite2D
			if not a.is_visible_in_tree():
				continue
			out["anim"] += 1
			if view.has_area() and view.has_point(a.global_position):
				out["anim_onscreen"] += 1
			if a.is_playing() and a.animation == "idle" and a.get_script() == null and a.sprite_frames and a.sprite_frames.get_frame_count(a.animation) > 1:
				var key := str(a.sprite_frames.get_instance_id())
				if not groups.has(key):
					groups[key] = {}
				groups[key][str(a.frame) + ":" + str(snappedf(a.speed_scale, 0.01))] = int(groups[key].get(str(a.frame) + ":" + str(snappedf(a.speed_scale, 0.01)), 0)) + 1
	out["mats"] = mats.size()
	for key: String in groups:
		var g: Dictionary = groups[key]
		var total := 0
		for v: int in g.values():
			total += v
		if total >= 3 and g.size() == 1:
			out["lock"] += 1
	return out

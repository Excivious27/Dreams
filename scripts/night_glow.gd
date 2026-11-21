class_name NightGlow
extends CanvasLayer
## Soft warm light around lamps, lanterns, torches and lit windows after dark.
## It sits above the map's CanvasModulate so the glow isn't darkened with it.
## Strength comes from GameMap.glow_dark(): the night outdoors, a steady level
## underground and in mines (c5_10 #3 #4).
## Windows (c5_02 #1, c5_10 #2): buildings with a `<name>_lit` mask
## (tools/make_window_glow.py, cut from their _night picture) get their panes
## added on top, faded by darkness; homes go dark late at night, shops dim after closing.

var map: GameMap
var lights: Array = []   # [Node2D, radius, lift] or [Node2D, radius, lift, Color] (a coloured light, c11b_03-07)
var windows: Array = []  # [Sprite2D building, Texture2D mask, kind "home"|"shop"|"late"]
var _tex: Texture2D
var _tex_white: Texture2D  # the same soft disc in white, tinted per light (glow sheep, lab strains)
var _canvas: Node2D

## Buildings that keep their lights on all night; homes go dark at HOME_DARK.
const LATE := ["inn", "clinic", "clock_tower", "bandstand", "warehouse_a", "karaoke", "neon_hotel", "ramen_shop", "president_tower"]  # C14 P5: the city never sleeps
const HOMES := ["cottage_a", "cottage_b", "cottage_c", "house", "house_2", "house_3", "mansion", "fishing_hut", "woodcutter_hut", "hazel_house"]
const HOME_DARK := 23.0   # homes' windows go out (back on at 5 for early risers)
const SHOP_DIM := 22.0    # shop fronts dim to a night light


func _ready() -> void:
	layer = 1
	follow_viewport_enabled = true
	_canvas = Node2D.new()
	add_child(_canvas)
	_canvas.draw.connect(_draw_glow)
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.55, 0.55))
	g.set_color(1, Color(1.0, 0.75, 0.4, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	_tex = gt
	var gw := Gradient.new()
	gw.set_color(0, Color(1, 1, 1, 0.55))
	gw.set_color(1, Color(1, 1, 1, 0.0))
	var gtw := GradientTexture2D.new()
	gtw.gradient = gw
	gtw.fill = GradientTexture2D.FILL_RADIAL
	gtw.fill_from = Vector2(0.5, 0.5)
	gtw.fill_to = Vector2(1.0, 0.5)
	gtw.width = 64
	gtw.height = 64
	_tex_white = gtw
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_canvas.material = mat
	if map != null:  # buildings placed in build(), before this layer existed
		for b: Array in map.get("_bprops"):
			add_windows(b[3] as Sprite2D, str(b[0]))


## A light that follows a node (it moves with it): colour null = the warm lamp glow. Freed nodes drop out.
## The light colour a prop casts, by its art name (c14_16-09): neon signs pink or
## cyan, crystal lamps their own crystal colour, the gangster arc's street lamps a
## cool sodium-teal; [] = the default warm amber. prop() appends this to its light row.
static func tint_of(name: String) -> Array:
	if "neon" in name:
		return [Color(1.0, 0.35, 0.85)] if name.hash() % 2 == 0 else [Color(0.3, 0.9, 1.0)]
	if "crystal" in name or "beacon_on" in name:
		if name.begins_with("ice") or "frost" in name:
			return [Color(0.55, 0.85, 1.0)]
		if name.begins_with("coral"):
			return [Color(1.0, 0.55, 0.7)]
		if name.begins_with("kelp"):
			return [Color(0.45, 1.0, 0.7)]
		return [Color(0.75, 0.6, 1.0)]
	if ("lamp" in name or "streetlight" in name) and not GameState.run.is_empty() and not GameState.is_penguins():
		return [Color(0.7, 0.9, 1.0)]
	return []


static func add_light(m: GameMap, node: Node2D, radius: float, lift: float, colour: Variant = null) -> void:
	if m == null or m.glow == null or not is_instance_valid(node):
		return
	var row: Array = [node, radius, lift]
	if colour is Color:
		row.append(colour)
	m.glow.lights.append(row)
	node.tree_exiting.connect(func() -> void:
		if is_instance_valid(m) and m.glow != null:
			m.glow.lights.erase(row), CONNECT_ONE_SHOT)


## A building sprite with a window mask: lit with the night (GameMap.building()).
func add_windows(s: Sprite2D, name: String) -> void:
	if not is_instance_valid(s) or not Art.has("buildings", name + "_lit"):
		return
	for w: Array in windows:
		if w[0] == s:
			return
	var t := Art.tex("buildings", name + "_lit")
	if t == null or s.texture == null or t.get_size() != s.texture.get_size():
		return
	var kind := "late" if name in LATE else ("home" if name in HOMES else "shop")
	windows.append([s, t, kind])


## How lit a building's windows are at this hour (0..1). Homes go out one by
## one between 22:00 and 23:15 (`ph` 0..1 per building), each fading over half
## an hour; shops dim over half an hour from 21:45 (c14b_04-19).
static func window_level(kind: String, hour: float, ph := 0.5) -> float:
	match kind:
		"late":
			return 1.0
		"home":
			if hour < 5.0:
				return 0.0
			if hour < 12.0:
				return smoothstep(5.0, 5.5, hour)
			var off_at := 22.0 + ph * 1.25
			return 1.0 - smoothstep(off_at - 0.25, off_at + 0.25, hour)
		_:
			if hour < 6.0:
				return 0.3 + 0.7 * smoothstep(5.75, 6.25, hour) if hour > 5.0 else 0.3
			return 1.0 - 0.7 * smoothstep(21.75, 22.25, hour)


var _was_on := false
var _acc := 0.0

## C14b P2 (c14b_04-01, 16-16): each light flickers like what it is, on game
## time, at its own phase: "fire" (hearths, candles, torches, braziers: a
## two-sine flame flicker in size and brightness), "electric" (lamps, street
## lights: steady), "neon" (steady with a rare short dropout every 8-20 s per
## sign), "crystal" (a slow 4 s breathe). Reduced motion: fire at 30 %, no
## neon dropouts. Kind comes from the node's meta "light_kind" or its art name.
const FIRE_WORDS := ["torch", "fire", "campfire", "bonfire", "brazier", "hearth", "fireplace", "forge", "candle", "oven", "fest_ss_80", "stove", "furnace", "kiln"]
const INDOOR_FIRE := 0.32  # fires light a room by day too (c14b_04-06)
var _kinds := {}  # instance id -> kind


## The art name a light's node shows (texture file basename), "" if unknown.
static func art_name(n: Node) -> String:
	var tex: Texture2D = null
	if n is Sprite2D:
		tex = (n as Sprite2D).texture
	elif n is AnimatedSprite2D and (n as AnimatedSprite2D).sprite_frames:
		var sf := (n as AnimatedSprite2D).sprite_frames
		var an := (n as AnimatedSprite2D).animation
		if sf.has_animation(an) and sf.get_frame_count(an) > 0:
			tex = sf.get_frame_texture(an, 0)
	if tex is AtlasTexture:
		tex = (tex as AtlasTexture).atlas
	if tex == null:
		return ""
	return tex.resource_path.get_file().get_basename()


static func kind_for(name: String) -> String:
	if name == "":
		return "electric"
	if "neon" in name:
		return "neon"
	if "crystal" in name or "beacon_on" in name:
		return "crystal"
	for w: String in FIRE_WORDS:
		if w in name:
			return "fire"
	if name.begins_with("fest_ss_"):
		return "fire"  # festival lanterns are candle-lit
	return "electric"


func kind_of(n: Node) -> String:
	var id := n.get_instance_id()
	if not _kinds.has(id):
		_kinds[id] = str(n.get_meta("light_kind")) if n.has_meta("light_kind") else kind_for(art_name(n))
	return _kinds[id]


## Size and brightness factors [radius_mul, alpha_mul] of one light at game time tm.
static func flicker(kind: String, tm: float, ph: float, reduced: bool) -> Vector2:
	match kind:
		"fire":
			var k := 0.3 if reduced else 1.0
			var nz := 0.6 * sin(tm * 7.3 + ph * 6.28) + 0.4 * sin(tm * 13.1 + ph * 10.7)
			var nz2 := 0.5 * sin(tm * 5.1 + ph * 3.9) + 0.5 * sin(tm * 11.7 + ph * 8.3)
			return Vector2(1.0 + 0.05 * k * nz, 1.0 - 0.075 * k * (1.0 + nz2))  # size +-5 %, brightness 0.85..1
		"neon":
			if reduced:
				return Vector2.ONE
			var period := 8.0 + ph * 12.0
			var u := fmod(tm + ph * 37.0, period)
			if u < 0.08 or (u > 0.16 and u < 0.22):
				return Vector2(1.0, 0.4)
			return Vector2(1.0, 0.97 + 0.03 * sin(tm * 50.0 + ph * 9.0))
		"crystal":
			var b := sin(tm * TAU * 0.25 + ph * TAU) * (0.3 if reduced else 1.0)
			return Vector2(1.0 + 0.06 * b, 0.88 + 0.12 * b)
	return Vector2(1.0 + 0.01 * sin(tm * 1.9 + ph * 6.28), 1.0)  # electric: steady


static func phase_of(p: Vector2) -> float:
	return fposmod(sin(p.x * 12.9898 + p.y * 78.233) * 43758.5453, 1.0)


func _indoor() -> bool:
	return map != null and map.scene_id() in ["house", "interior"] and not RecCenter.is_rec(map)


func _process(_d: float) -> void:
	var on := map != null and (map.glow_dark() > 0.05 or (_indoor() and not lights.is_empty()))
	# The flicker is +-4%: 15 redraws a second is plenty (it ran every frame from dusk to dawn).
	_acc += _d
	if (on and _acc >= 0.066) or on != _was_on:
		_acc = 0.0
		_canvas.queue_redraw()
	_was_on = on


## Lights farther than this from the screen centre are skipped: half the view's
## diagonal plus the largest glow, so wide desktop views never pop (c5_02 #8).
func _cutoff() -> float:
	var vs := map.get_viewport().get_visible_rect().size
	var cam := map.get_viewport().get_camera_2d()
	var z := cam.zoom.x if cam and cam.zoom.x > 0.0 else 1.0
	return maxf(320.0, (vs / z).length() * 0.5 + 120.0)


func _draw_glow() -> void:
	if map == null:
		return
	var a := map.glow_dark()
	var fire_floor := INDOOR_FIRE if _indoor() else 0.0
	if a < 0.05 and fire_floor <= 0.0:
		return
	var tm := PlayClock.now()
	var reduced := Settings.reduced_motion()
	var cam := map.get_viewport().get_camera_2d()
	var cc := cam.get_screen_center_position() if cam else Vector2.ZERO
	var cut := _cutoff()
	if not windows.is_empty():
		var hour := TownHours._hour()
		for w: Array in windows:
			if not is_instance_valid(w[0]):
				continue
			var s := w[0] as Sprite2D
			if a < 0.05 or not s.visible or (cam and s.global_position.distance_to(cc) > cut):
				continue
			var lv := window_level(str(w[2]), hour, phase_of(s.global_position)) * a * s.modulate.a
			if lv < 0.02:
				continue
			var tex := w[1] as Texture2D
			var sz := tex.get_size()
			var tl := s.offset - (sz * 0.5 if s.centered else Vector2.ZERO)
			_canvas.draw_set_transform_matrix(s.global_transform)
			_canvas.draw_texture(tex, tl, Color(1, 1, 1, minf(1.0, lv * 1.15)))
		_canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	# Indoors a lamp lights its room only: the halo is cut at the walls instead of
	# spilling into the black around a small room (c9_14).
	var room := Rect2()
	if map.scene_id() in ["house", "interior"]:
		# The outer ring of cells is the dark wall frame: light stops at the floor's
		# sides and bottom, and goes up the back wall.
		var t := float(GameMap.TILE)
		room = Rect2(map.to_global(map.offset()) + Vector2(t, 0), Vector2(map.cols, map.rows) * t - Vector2(2 * t, t))
	var tsz := _tex.get_size() if _tex else Vector2.ONE
	for l: Array in lights:
		var o: Variant = l[0]
		if not is_instance_valid(o):
			continue
		var n := o as Node2D
		if not n.visible:
			continue
		if cam and n.global_position.distance_to(cc) > cut:
			continue
		var kd := kind_of(n)
		var la := a
		if kd == "fire" and fire_floor > 0.0:
			la = maxf(a, fire_floor + 0.45 * a)
		if la < 0.05:
			continue
		var fl := flicker(kd, tm, phase_of(n.global_position), reduced)
		var lt := _tex
		var lc := Color(1, 1, 1, la * fl.y)
		if l.size() > 3 and l[3] is Color and _tex_white:
			lt = _tex_white
			lc = Color((l[3] as Color).r, (l[3] as Color).g, (l[3] as Color).b, la * fl.y)
		var r := float(l[1]) * fl.x
		var p := n.global_position + Vector2(0, -float(l[2]))
		var dst := Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0)
		if room.has_area():
			var cut_r := dst.intersection(room)
			if not cut_r.has_area():
				continue
			var src := Rect2((cut_r.position - dst.position) / dst.size * tsz, cut_r.size / dst.size * tsz)
			_canvas.draw_texture_rect_region(lt, cut_r, src, lc)
			continue
		_canvas.draw_texture_rect(lt, dst, false, lc)

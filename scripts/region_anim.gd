class_name RegionAnim
extends Node
## C14b P4: life for the props of the region maps (regions.json areas, moon, crystal
## meadow), on game time, deterministic per cell so co-op peers and tests agree.
##  * strips (c14b_06-01, c14b_13-15): any prop whose art has frames > 1 plays, unless
##    the data says "still" or it is a jumbled rotor/variant strip (STILL_STRIPS);
##  * phase (c14b_06-03, c14b_13-06): random start frame, progress and +-12% speed per
##    cell, so neighbours never move in lockstep;
##  * pop loops (c14b_05-06, c14b_16-17): glow ponds/pools, star crater, warp pads,
##    tide pools and giant flowers ping-pong (0,1,2,3,2,1) instead of snapping back;
##  * code motion, one ticking node per map: neon hum and stutter (c14b_04-08), boats
##    bob and rock (c14b_13-07), drones glide between hover spots (c14b_06-06), cloud
##    trees and sky props drift 1 px (c14b_06-08), beacons/crystals breathe (c14b_05-10).
## Settings.reduced_motion(): strips at half speed, code motion at ~30%, no stutter.

## Strips that are variants or redraw their body each frame (rotors with jumbled
## blade angles, the boiling helicopter, street lamps that are an on-switch): frame 0
## rather than a choppy loop until split art exists (c14b_16-11, c14b_13-22, c14b_04-10).
const STILL_STRIPS := ["windmill", "wind_turbine", "helicopter", "lamp2_", "airlock", "cryo_pod", "door", "gate"]  # also state strips (open/closed)
const PINGPONG := ["glow_pond", "glow_pool", "star_crater", "warp_pad", "tide_pool", "giant_flower", "aurora", "moon_spire", "crystal_tree"]
const FPS := {"fire": 8.0, "barrel": 8.0, "bonfire": 8.0, "cauldron": 5.0, "fountain": 7.0, "glow_pond": 4.0, "glow_pool": 4.0,
	"crystal_tree": 3.0, "giant_flower": 2.5, "carnivore": 2.5, "star_crater": 4.0, "warp_pad": 5.0, "console": 1.5, "arcade": 3.0}

var _items: Array = []  # [node, kind, base_pos, phase, extra]


static func of(m: Node) -> RegionAnim:
	var n := m.get_node_or_null("RegionAnim")
	if n == null:
		n = RegionAnim.new()
		n.name = "RegionAnim"
		m.add_child(n)
	return n as RegionAnim


static func hcell(c: Vector2i) -> int:
	return absi(hash(Vector2i(c.x * 7919 + 13, c.y * 104729 + 7)))


## Should this prop play as a strip? (data "anim" wins; else frames > 1 and not still).
static func wants_anim(p: Dictionary, g: String, nm: String) -> bool:
	if not Art.has(g, nm):
		return false
	if p.has("anim"):
		return bool(p["anim"])
	if bool(p.get("still", false)):
		return false
	for s: String in STILL_STRIPS:
		if nm.contains(s):
			return false
	return int(Art.info(g, nm).get("frames", 1)) > 1


static func fps_for(nm: String, given: float) -> float:
	if given > 0.0:
		return given
	for k: String in FPS:
		if nm.contains(k):
			return float(FPS[k])
	return 4.0


static func is_pingpong(nm: String) -> bool:
	for k: String in PINGPONG:
		if nm.contains(k):
			return true
	return false


## SpriteFrames for a prop strip: ping-pong where a loop would pop.
static func frames_for(g: String, nm: String, fps: float) -> SpriteFrames:
	var sf := Art.frames(g, {"idle": nm}, {"idle": fps})
	if is_pingpong(nm) and sf.has_animation("idle"):
		var n := sf.get_frame_count("idle")
		if n > 2:
			sf = sf.duplicate()  # Art may cache: never change the shared frames
			for i in range(n - 2, 0, -1):
				sf.add_frame("idle", sf.get_frame_texture("idle", i))
	return sf


## Random start frame/progress and speed per cell; reduced motion halves the speed.
static func phase(a: AnimatedSprite2D, c: Vector2i) -> void:
	if a == null or a.sprite_frames == null or not a.sprite_frames.has_animation(a.animation):
		return
	var h := hcell(c)
	var n := a.sprite_frames.get_frame_count(a.animation)
	if n > 0:
		a.set_frame_and_progress(h % n, float(h % 100) / 100.0)
	a.speed_scale = 0.88 + float(h % 25) / 100.0
	if Settings.reduced_motion():
		a.speed_scale *= 0.5


## Code motion for a placed prop node, by its art name.
func add(node: Node2D, nm: String, c: Vector2i) -> void:
	if node == null:
		return
	var kind := ""
	if nm.contains("neon"):
		kind = "neon"
	elif nm.contains("drone"):
		kind = "drone"
	elif nm.contains("boat") or nm.contains("ship") or nm.contains("ferry") or nm.contains("tug") or nm.contains("trawler") or nm.contains("canoe") or nm.contains("raft") or nm.contains("yacht"):
		kind = "boat"
	elif nm.contains("cloud_tree") or nm.contains("sky_isle") or nm.contains("float"):
		kind = "drift"
	elif nm.contains("beacon") or nm.contains("star_crystal") or nm.contains("glow_crystal") or nm.contains("lantern"):
		kind = "breathe"
	if kind == "":
		return
	var h := hcell(c)
	_items.append([node, kind, node.position, float(h % 1000) / 1000.0 * TAU, {"rot": node.rotation, "mod": node.modulate, "h": h}])


func _process(_d: float) -> void:
	if _items.is_empty():
		return
	var t := PlayClock.now()
	var rm := Settings.reduced_motion()
	var amp := 0.3 if rm else 1.0
	for it: Array in _items:
		var n: Node2D = it[0]
		if not is_instance_valid(n):
			continue
		var ph: float = it[3]
		var base: Vector2 = it[2]
		var ex: Dictionary = it[4]
		match str(it[1]):
			"neon":
				# Steady hum 0.9..1.0; every 6-15 s a short stutter; no stutter under reduced motion.
				var hum := 0.95 + 0.05 * sin(t * 7.0 + ph)
				var period := 6.0 + float(int(ex["h"]) % 90) / 10.0
				var k := fposmod(t + ph * 3.0, period)
				if not rm and k < 0.35:
					hum *= [0.45, 1.0, 0.55, 1.0, 0.7][int(k / 0.07) % 5]
				var m: Color = ex["mod"]
				n.modulate = Color(m.r * hum, m.g * hum, m.b * hum, m.a)
			"boat":
				n.position = base + Vector2(0, roundf(sin(t * 1.8 + ph) * 1.0 * amp * 2.0) / 2.0)
				n.rotation = float(ex["rot"]) + sin(t * 1.25 + ph) * deg_to_rad(0.8) * amp
			"drone":
				# Glide between three hover spots near home, eased, with a pause at each.
				var leg := 4.5
				var seg := int(floor((t + ph * 2.0) / leg))
				var u := clampf(fposmod(t + ph * 2.0, leg) / (leg - 1.5), 0.0, 1.0)
				u = u * u * (3.0 - 2.0 * u)
				var spots := [Vector2.ZERO, Vector2(14, -3), Vector2(-10, 4)]
				var a: Vector2 = spots[posmod(seg, 3)]
				var b: Vector2 = spots[posmod(seg + 1, 3)]
				n.position = base + a.lerp(b, u) * amp + Vector2(0, roundf(sin(t * 3.0 + ph) * 2.0) / 2.0)
			"drift":
				n.position = base + Vector2(0, roundf(sin(t * 0.6 + ph) * 1.0 * amp * 2.0) / 2.0)
			"breathe":
				var g := 0.88 + 0.12 * (0.5 + 0.5 * sin(t * TAU / 2.6 + ph)) * amp + 0.12 * (1.0 - amp)
				var m2: Color = ex["mod"]
				n.modulate = Color(m2.r * (0.94 + 0.08 * g), m2.g * (0.94 + 0.08 * g), m2.b * (0.94 + 0.08 * g), m2.a)


## A soft additive light on a magic prop (c14b_05-10): lit = an eased 2.5 s pulse with
## sparkles rising out of it; dim = a weak slow flicker and a dark mote now and then;
## burst = a ring of sparkles flying outward over 1.2 s (the restore moment), then gone.
class Glow extends Node2D:
	var col := Color(1, 1, 1)
	var mode := "lit"
	var ph := 0.0
	var born := 0.0
	var radius := 16.0

	func _ready() -> void:
		var cm := CanvasItemMaterial.new()
		cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = cm
		born = PlayClock.now()

	func _process(_d: float) -> void:
		if mode == "burst" and PlayClock.now() - born > 1.4:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := PlayClock.now()
		var rm := Settings.reduced_motion()
		var amp := 0.3 if rm else 1.0
		match mode:
			"lit":
				var p := 0.5 + 0.5 * sin(t * TAU / 2.5 + ph)
				p = p * p * (3.0 - 2.0 * p)
				var a := lerpf(0.75, 0.55 + 0.45 * p, amp)
				draw_circle(Vector2.ZERO, radius * 1.5, Color(col, 0.07 * a))
				draw_circle(Vector2.ZERO, radius, Color(col, 0.12 * a))
				draw_circle(Vector2.ZERO, radius * 0.5, Color(col, 0.18 * a))
				for i in 4:
					var life := 2.2
					var age := fposmod(t + ph + i * life / 4.0, life)
					var u := age / life
					var x := sin(i * 2.3 + ph) * radius * 0.6 + sin(age * 2.0 + i) * 2.0 * amp
					var y := -age * 9.0 * amp - 4.0
					var e := pow(sin(PI * u), 1.5)
					draw_circle(Vector2(x, y), 1.6, Color(col, 0.25 * e))
					draw_circle(Vector2(x, y), 0.6, Color(1, 1, 1, 0.9 * e))
			"dim":
				var f := 0.5 + 0.5 * sin(t * TAU / 4.0 + ph) * (0.6 + 0.4 * sin(t * 1.7 + ph * 2.0))
				var a2 := lerpf(0.2, 0.15 + 0.15 * f, amp)
				draw_circle(Vector2.ZERO, radius * 0.9, Color(col, 0.10 * a2))
				draw_circle(Vector2.ZERO, radius * 0.4, Color(col, 0.20 * a2))
			"burst":
				var u2 := clampf((t - born) / 1.2, 0.0, 1.0)
				var ez := 1.0 - pow(1.0 - u2, 3.0)
				var fade := 1.0 - u2
				draw_circle(Vector2.ZERO, radius * (0.5 + 1.5 * ez), Color(col, 0.18 * fade))
				for i in 12:
					var ang := i * TAU / 12.0 + ph
					var pos := Vector2(cos(ang), sin(ang) * 0.6) * radius * 2.4 * ez
					draw_circle(pos, 1.8 * fade + 0.4, Color(col, 0.5 * fade))
					draw_circle(pos, 0.7, Color(1, 1, 1, fade))


## Adds a Glow over a map position (map coordinates).
static func glow(m: GameMap, at: Vector2, col: Color, mode: String, radius := 16.0) -> Node2D:
	if m == null:
		return null
	var g := Glow.new()
	g.col = col
	g.mode = mode
	g.radius = radius
	g.ph = float(absi(hash(at)) % 1000) / 1000.0 * TAU
	g.position = at
	g.z_index = 41
	m.add_child(g)
	return g

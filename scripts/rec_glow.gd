class_name RecGlow
extends CanvasLayer
## Coloured light inside the Rec Center: screen glow spilling off the cabinets,
## the claw machine, jukebox and pinballs, neon on the walls, the pin-deck lights
## over the lanes (blacklight in the Rec Hall). It sits above the map's
## CanvasModulate (like NightGlow), so it shows more as the house lights dim
## after dark (GameMap.sky_tint asks RecGlow.tint for the rec rooms).

var map: GameMap
var lights: Array = []  # [world pos, size (ellipse), Color, phase]
var _tex: Texture2D
var _canvas: Node2D
var _acc := 0.0

const T := 16.0
## Colour of the light each prop throws (by name prefix).
const PROP_LIGHT := {
	"arcade_cab_0": "3fa9f5", "arcade_cab_5": "3fdc8c", "arcade_cab_whack": "f5c842",
	"arcade_cab_gallery": "3fd8f5", "arcade_cab": "a46cf5", "claw_machine": "f5486e",
	"jukebox": "ffb347", "vend_red": "ff5a5a", "vend_blue": "5aa0ff",
	"rec_pinball_a": "c86cff", "rec_pinball_b": "6cff8a", "rec_photo_booth": "ffd27a",
	"skee_ball": "ff9a3a", "prize_counter": "ffd27a", "ticket_booth": "ffd27a",
	"ball_return": "8ab4ff", "snack_counter": "ffd27a", "score_console": "6cd8ff",
}
const NEON_COL := ["ff4fc8", "ffd84a", "4fe8ff", "5aff7a"]


## How far the house lights are down: 0 by day, 1 deep at night.
static func dim() -> float:
	if GameState.run.is_empty():
		return 0.0
	return GameState.darkness() * Settings.night_strength()


## The rooms' tint at darkness `dark` (cooler and dimmer than a lamplit house, so the neon pops).
static func tint(dark: float) -> Color:
	var night := Color(0.84, 0.80, 0.94) if GameState.is_penguins() else Color(0.70, 0.64, 0.88)
	return Color(1, 1, 1).lerp(night, clampf(dark, 0.0, 1.0))


func _ready() -> void:
	layer = 1
	follow_viewport_enabled = true
	_canvas = Node2D.new()
	add_child(_canvas)
	_canvas.draw.connect(_draw_glow)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.add_point(0.45, Color(1, 1, 1, 0.35))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	_tex = gt
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_canvas.material = mat
	if map:
		build()


## Collect the light sources from the room's props and lanes.
func build() -> void:
	lights.clear()
	var I: Dictionary = map.get("I")
	var gang := not GameState.is_penguins()
	for p: Dictionary in I.get("props", []):
		var nm := str(p.get("name", ""))
		var col := ""
		for k: String in PROP_LIGHT:
			if nm.begins_with(k):
				col = PROP_LIGHT[k]
				break
		if col == "":
			continue
		var c: Array = p["cell"]
		var w := float(int(p.get("w", 0)) + 1)
		var base := map.cell_pos(float(c[0]) + w / 2.0, float(c[1]) + 1.0)
		# Pieces against the side walls light the room, not the wall.
		var cols := int(map.get("cols"))
		if int(c[0]) <= 1:
			base.x += 5.0
		elif int(c[0]) + int(w) >= cols - 2:
			base.x -= 5.0
		var cc := Color(col)
		# A soft pool on the floor in front, and the screen's own halo.
		_add(base + Vector2(0, 5), Vector2(11 + 5 * w, 7), cc, 0.5)
		_add(base + Vector2(0, -16), Vector2(11 + 3 * w, 11), cc, 0.16)
	if bool(I.get("lanes", false)):
		var foul := float(RecCenter.data().get("lane_foul", 11)) + 1.0
		var deck := Color("e8f0ff") if not gang else Color("b45aff")
		for ln: Dictionary in RecCenter.data().get("lanes", []):
			var cx := (float(ln["x"]) + 1.0)
			var nc := Color(NEON_COL[(int(ln["n"]) - 1) % NEON_COL.size()])
			_add(map.cell_pos(cx, 3.0), Vector2(20, 14), deck, 0.8)   # pin-deck lights
			_add(map.cell_pos(cx, 1.3), Vector2(16, 9), nc, 0.45)     # lane number
			if gang:
				_add(map.cell_pos(cx, (foul + 3.0) / 2.0), Vector2(14, 60), deck, 0.28)  # blacklight down the lane
		_add(map.cell_pos(8.0, 1.2), Vector2(14, 10), Color("ff4fc8"), 0.45)
	else:
		for i in RecDecor.WALL_NEON.size():
			var s: Array = RecDecor.WALL_NEON[i]
			var nc2 := Color(NEON_COL[i % NEON_COL.size()])
			_add(map.cell_pos(float(s[0]) + 0.5, 0.6), Vector2(16, 13), nc2, 0.6)
		var cr := RecDecor.carpet_rect()
		var mid := map.cell_pos(cr.get_center().x / T, cr.get_center().y / T)
		_add(mid, Vector2(cr.size.x * 0.55, cr.size.y * 0.6), Color("8a6cff") if not gang else Color("c04aff"), 0.22)


func _add(pos: Vector2, size: Vector2, col: Color, strength: float) -> void:
	lights.append([pos, size, Color(col, strength), randf() * TAU])


func _process(d: float) -> void:
	_acc += d
	if _acc >= 0.08:
		_acc = 0.0
		_canvas.queue_redraw()


func _draw_glow() -> void:
	if map == null or not is_instance_valid(map):
		return
	# Faint by day (sunlight through the doors), full after dark.
	var a := 0.32 + 0.68 * dim()
	if not GameState.is_penguins():
		a = 0.5 + 0.5 * dim()  # the Rec Hall keeps its blinds down
	var tm := Time.get_ticks_msec() / 1000.0
	for l: Array in lights:
		var sz: Vector2 = l[1]
		var col: Color = l[2]
		var k := a * (0.9 + 0.1 * sin(tm * 2.2 + float(l[3])))
		var p := map.to_global(l[0])
		_canvas.draw_texture_rect(_tex, Rect2(p - sz, sz * 2.0), false, Color(col.r, col.g, col.b, col.a * k))

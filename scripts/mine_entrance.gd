extends RefCounted
## The mine entrance on the meadow, dressed from existing art: the big timbered
## portal (props/mine_entrance2, its stray sheet strip trimmed off) set into a
## rocky knoll, boulders and rubble round its shoulders, lanterns on posts,
## cart rails running out over the stone apron, an ore cart, a crate and a
## sign. Every cell of the portal's front counts as the door.
##   preload("res://scripts/mine_entrance.gd").dress(self, MINE_DOOR)
## (called from meadow.gd in place of the old 26 px mine_entrance prop).

const PORTAL := "mine_entrance2"
const PORTAL_TRIM := 11        # px of a neighbouring sign board at the top of the cut
const PORTAL_SCALE := 0.62     # 96 x 66 px: six cells wide, set into the stone patch


static func dress(m: GameMap, door: Vector2i) -> void:
	# The old small prop, if the map already placed it.
	for c: Vector2i in [door + Vector2i(-1, 0), door]:
		if m.props.has(c):
			var old: Node = m.props[c]
			if old is Sprite2D and (old as Sprite2D).texture and "mine_entrance.png" in (old as Sprite2D).texture.resource_path:
				old.queue_free()
				m.props.erase(c)
	var t := Art.tex("props", PORTAL)
	if t == null:
		# No big portal art: the small one, as before.
		if Art.has("props", "mine_entrance"):
			m.prop("props", "mine_entrance", door + Vector2i(-1, 0), 2)
		return
	var s := Sprite2D.new()
	s.texture = t
	s.region_enabled = true
	s.region_rect = Rect2(0, PORTAL_TRIM, t.get_width(), t.get_height() - PORTAL_TRIM)
	s.centered = true
	s.offset = Vector2(0, -(t.get_height() - PORTAL_TRIM) / 2.0)
	s.scale = Vector2.ONE * PORTAL_SCALE
	# Bottom-centre on the door cell's bottom edge: the tunnel mouth sits on the door.
	s.position = m.cell_pos(door.x + 0.5, door.y + 1)
	m.add_child(s)
	m.props[door] = s
	# The knoll is solid; its whole front is the door (USE or tap anywhere along it).
	var half := 3
	for y in range(door.y - 3, door.y + 1):
		for x in range(door.x - half + 1, door.x + half):
			var c := Vector2i(x, y)
			m.blocked[c] = true
			m.hard[c] = true
			if y >= door.y - 1 and c != door:
				m._building_doors[c] = door
	m._building_doors[door] = door
	# Lantern light on the timbers at night.
	if m.glow:
		m.glow.lights.append([s, 30.0, 40.0])
	# Shoulders: boulders and rubble so the knoll reads as a hillside, not a box.
	_put(m, "nature", "rock_l", door + Vector2i(-3, 0), true, 0.5)
	_put(m, "nature", "rock_l", door + Vector2i(3, -1), true, 0.5)
	_put(m, "props", "rockslide", door + Vector2i(3, 0), true, 0.4, Vector2(2, 0))
	_put(m, "props", "rockslide", door + Vector2i(-3, -2), true, 0.36, Vector2(-2, 0))
	_put(m, "nature", "rock_m", door + Vector2i(2, -4), true, 0.5)
	_put(m, "nature", "rock_m", door + Vector2i(-2, -4), true, 0.5)
	for i in 4:
		var nm := "ri_mossy_%d" % [3, 7, 11, 14][i]
		_put(m, "props", nm, door + [Vector2i(-2, 1), Vector2i(2, 1), Vector2i(-4, -1), Vector2i(4, 1)][i], false, 0.4)
	# Lanterns on posts either side of the track.
	var lan := "lantern_lit" if Art.has("props", "lantern_lit") else "lamp_lit"
	_put(m, "props", lan, door + Vector2i(-1, 2), true, 0.5, Vector2(-1, 0))
	_put(m, "props", lan, door + Vector2i(1, 2), true, 0.5, Vector2(1, 0))
	# Rails out of the mouth, over the apron, ending at a buffer before the road.
	if Art.has("props", "rail_v"):
		for dy in range(1, 3):
			var r := _put(m, "props", "rail_v", door + Vector2i(0, dy), false, 0.5)
			if r:
				m.to_under(r)
		var e := _put(m, "props", "rail_end" if Art.has("props", "rail_end") else "rail_v", door + Vector2i(0, 3), false, 0.5)
		if e:
			m.to_under(e)
	# A loaded cart and an ore crate on the apron, a pick left on a rock, a sign.
	_put(m, "props", "cart_full", door + Vector2i(2, 2), true, 0.5, Vector2(2, 0))
	_put(m, "props", "cave_ore_crate", door + Vector2i(-2, 2), true, 0.28, Vector2(-2, 0))
	_put(m, "props", "pick_rock", door + Vector2i(-3, 1), true, 0.45)
	var sg := _put(m, "props", "signpost_2" if Art.has("props", "signpost_2") else "signpost", door + Vector2i(3, 2), true, 0.5, Vector2(4, 0))
	if sg:
		m.set_thing(door.x + 3, door.y + 2, {"type": "note", "text": "GRANITE'S MINE. Floor one, and down. Mind the keeper.", "hint": "A: read the sign"}, true)


static func _put(m: GameMap, group: String, nm: String, c: Vector2i, solid: bool, sc: float, nudge := Vector2.ZERO) -> Sprite2D:
	if not Art.has(group, nm) or m.things.has(c) and str(m.things[c].get("type", "")) not in ["note"]:
		return null
	var keep: Variant = m.props.get(c)
	var sp := m.prop(group, nm, c, 0, 0.0, solid, sc)
	if sp:
		sp.position += nudge
		if keep != null:
			m.props[c] = keep   # decoration doesn't take over a cell's main prop
	return sp

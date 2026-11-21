class_name PropDress
extends RefCounted
## CONDUCT 14 prop dressing (contract section 5): data/props_c14.json
## {scene: [{id, cell, layer, anim}]} (tools/gen_props_c14.py) placed through the
## map's prop()/anim_prop()/under_layer() while its static drawing is baked.
## Map owners call `PropDress.dress(self, scene_id())` once at the end of draw_map;
## the painter twin forwards to the real map and a meta flag keeps it to one pass
## (chunked bakes re-run draw_map). A planned cell is skipped when it is out of the
## content, blocked, holds a thing or a prop, is water, sits on the map's own path
## (prop/deco layers) or is the spawn, so maps can change without breaking the plan.
## id: "group/name" (group defaults to props); layer: "prop" (solid, y-sorted),
## "deco" (walk-through) or "under" (ground level, under the player); anim: fps.
## Seasonal looks: SeasonLook.pick (C15 P5) takes a <name>_<season> / table twin when the art has one.

const PATH := "res://data/props_c14.json"
static var _data := {}
static var _loaded := false


static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_data = d
	return _data


static func entries(scene_id: String) -> Array:
	return data().get(scene_id, [])


## Split "group/name" (no slash: props).
static func split_id(id: String) -> Array:
	var i := id.find("/")
	if i < 0:
		return ["props", id]
	return [id.substr(0, i), id.substr(i + 1)]


## Can a dressing piece go on cell c of this map (host = the real map)?
static func free_cell(host: GameMap, c: Vector2i, layer: String) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= host.cols or c.y >= host.rows:
		return false
	if host.blocked.has(c) or host.things.has(c) or host.is_water_cell(c):
		return false
	if layer == "under":
		return true
	if host.props.has(c):
		return false
	var pcs: Variant = host.get("_pcs")
	if pcs is Dictionary and (pcs as Dictionary).has(c):
		return false
	if host.player != null and host.world_to_cell(host.player.position).distance_squared_to(c) <= 2:
		return false
	return true


## Ground-level pieces (rails, litter) are painted straight into the map's
## drawing (baked with the ground: no nodes, perf), honouring Art.clipped.
static func draw_under(m: GameMap, host: GameMap, scene_id: String) -> void:
	for e: Dictionary in entries(scene_id):
		if str(e.get("layer", "")) != "under":
			continue
		var gn := split_id(str(e.get("id", "")))
		var name: String = gn[1]
		name = SeasonLook.pick(gn[0], name)  # C15 P5: any look season (was winter only)
		var tex := Art.tex(gn[0], name)
		if tex == null:
			continue
		var cl: Array = e.get("cell", [-1, -1])
		var c := Vector2i(int(cl[0]), int(cl[1]))
		if not free_cell(host, c, "under"):
			continue
		var sz := tex.get_size() * 0.5
		var r := Rect2(Vector2(c) * GameMap.TILE + Vector2((GameMap.TILE - sz.x) * 0.5, (GameMap.TILE - sz.y) * 0.5), sz)
		if Art.clipped(r):
			continue
		m.draw_texture_rect(tex, r, false)


## Place this scene's dressing. Returns how many pieces went down (0 on a repeat call).
static func dress(m: GameMap, scene_id: String, drawing := true) -> int:
	if m == null:
		return 0
	var host: GameMap = m._painter_of if m._painter_of != null else m
	if drawing:
		draw_under(m, host, scene_id)  # every pass: each baked chunk paints its own part
	if host.has_meta("c14_dressed"):
		return 0
	host.set_meta("c14_dressed", 0)
	var n := 0
	for e: Dictionary in entries(scene_id):
		var gn := split_id(str(e.get("id", "")))
		var group: String = gn[0]
		var name: String = gn[1]
		name = SeasonLook.pick(group, name)  # C15 P5: any look season (was winter only)
		if not Art.has(group, name):
			continue
		var cl: Array = e.get("cell", [-1, -1])
		var c := Vector2i(int(cl[0]), int(cl[1]))
		var layer := str(e.get("layer", "prop"))
		if not free_cell(host, c, layer):
			continue
		if layer == "under":
			continue  # painted into the ground bake by draw_under (no nodes)
		elif e.has("anim"):
			if host.anim_prop(group, name, c, 0, float(e["anim"]), layer == "prop") == null:
				continue
		else:
			if host.prop(group, name, c, 0, 0.0, layer == "prop") == null:
				continue
		n += 1
	host.set_meta("c14_dressed", n)  # how many went down (tools/prop_dress_test.gd)
	return n

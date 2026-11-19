extends SceneTree
## Invisible walls: blocked cells inside the map with nothing drawn on them that
## says "solid" (no sprite over the cell, no thing, no water, no ledge or cliff).
## Also checks that every open cell is reachable from the spawn (no sealed pockets
## bigger than a few cells). Run (MAPS=mountain,moon to pick maps):
##   godot --headless --path . -s res://tools/invisible_walls.gd
## Exits 1 if any map in MUST_PASS has an invisible wall or a sealed open area.
const MAPS := ["mountain", "moon", "farm", "town", "forest", "lake", "meadow", "beach", "crystal_meadow", "community_farm"]
const MUST_PASS := ["mountain", "moon"]
var fails := 0


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


var _imgs := {}


func _img(t: Texture2D) -> Image:
	var key := t.get_rid()
	if _imgs.has(key):
		return _imgs[key]
	var im: Image = null
	if t is AtlasTexture:
		var at := t as AtlasTexture
		var src := _img(at.atlas)
		if src:
			im = src.get_region(Rect2i(at.region))
	else:
		# Headless has no texture data: read the source PNG the texture came from.
		var rp := t.resource_path
		if rp.ends_with(".png") and FileAccess.file_exists(rp):
			im = Image.load_from_file(ProjectSettings.globalize_path(rp))
		if im and im.is_compressed():
			im.decompress()
	_imgs[key] = im
	return im


## Cells with opaque pixels of a solid-looking sprite over them (ground-level
## under-layer decals don't count: a wall under a puddle is still invisible).
func _covered(m: GameMap) -> Dictionary:
	var cov := {}
	var stack: Array = [m]
	var off := m.offset()
	var mx := m.get_global_transform().affine_inverse()
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.has_meta("under_rank"):
			continue
		for ch in n.get_children():
			stack.append(ch)
		if not (n is Sprite2D or n is AnimatedSprite2D) or not (n as CanvasItem).is_visible_in_tree():
			continue
		if n is Player or n.get_parent() is Npc or n.get_parent() is Enemy or n.get_parent() is Player:
			continue
		var tex: Texture2D = null
		var r := Rect2()
		if n is Sprite2D:
			var s := n as Sprite2D
			tex = s.texture
			if tex == null:
				continue
			r = s.get_rect()
		else:
			var a := n as AnimatedSprite2D
			if a.sprite_frames == null:
				continue
			tex = a.sprite_frames.get_frame_texture(a.animation, 0)
			if tex == null:
				continue
			var sz := tex.get_size()
			r = Rect2(a.offset - (sz / 2.0 if a.centered else Vector2.ZERO), sz)
		var im := _img(tex)
		var xf := mx * (n as Node2D).get_global_transform()
		var gr := xf * r
		var inv := xf.affine_inverse()
		var x0 := floori((gr.position.x - off.x) / 16.0)
		var y0 := floori((gr.position.y - off.y) / 16.0)
		var x1 := floori((gr.end.x - off.x - 0.01) / 16.0)
		var y1 := floori((gr.end.y - off.y - 0.01) / 16.0)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var c := Vector2i(x, y)
				if cov.has(c) or not m.blocked.has(c):
					continue
				if im == null:
					continue  # a render-target chunk (baked ground) or generated texture: not a solid thing
				var hit := false
				for sy in [3.0, 8.0, 13.0]:
					for sx in [3.0, 8.0, 13.0]:
						var lp: Vector2 = inv * (off + Vector2(x * 16.0 + sx, y * 16.0 + sy))
						var tp := ((lp - r.position) / r.size * Vector2(im.get_size())).floor()
						if tp.x >= 0 and tp.y >= 0 and tp.x < im.get_width() and tp.y < im.get_height() and im.get_pixel(int(tp.x), int(tp.y)).a > 0.4:
							hit = true
				if hit:
					cov[c] = true
	return cov


func _run() -> void:
	InputSetup.ensure_actions()
	var only := OS.get_environment("MAPS")
	for arc in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi", "T", "Town", "Pup")
		GameState.run["intro_done"] = true
		for s in MAPS:
			GameState.run["flags"][s + "_seen"] = true
		for f in ["cm_seen", "mine_open_1", "meow_taught", "moon_seen", "mine_seen"]:
			GameState.run["flags"][f] = true
		for s: String in MAPS:
			if only != "" and not (s in only.split(",")):
				continue
			GameMap.next_spawn = Vector2.ZERO
			GameState.run["scene"] = s
			change_scene_to_file("res://scenes/%s.tscn" % s)
			for i in 8:
				await process_frame
			var m := current_scene as GameMap
			if m == null:
				continue
			m.set_process(false)
			var cov := _covered(m)
			var plate := {}
			for pl: Dictionary in m.plateaus:
				for c in pl.get("cells", {}):
					plate[c] = true
					for o in [Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
						plate[c + o] = true
			var bad := []
			var nb := [0, 0, 0, 0, 0]
			for c: Vector2i in m.blocked:
				nb[0] += 1
				if cov.has(c):
					nb[1] += 1
				elif m.things.has(c):
					nb[2] += 1
				elif m.is_water_cell(c):
					nb[3] += 1
				elif plate.has(c):
					nb[4] += 1
			if OS.get_environment("DEBUG") != "":
				print("  blocked/cov/thing/water/plate ", nb)
			for c: Vector2i in m.blocked:
				if c.x < 1 or c.y < 1 or c.x >= m.cols - 1 or c.y >= m.rows - 1:
					continue  # the border band draws its own wall
				if cov.has(c) or m.things.has(c) or m.is_water_cell(c) or plate.has(c):
					continue
				var crater = (m.get_script() as Script).get_script_constant_map().get("CRATER")
				if crater is Rect2i and (crater as Rect2i).has_point(c):
					continue  # the crater pit is drawn on the ground (visible), not a sprite
				var ledge = m.get("_ledge")
				if ledge is Dictionary and (ledge as Dictionary).has(c):
					continue
				bad.append(c)
			# Open cells the spawn can't reach (sealed off by a wall you can't see).
			var start := m.player.cell()
			var seen := {start: true}
			var q := [start]
			while not q.is_empty():
				var a: Vector2i = q.pop_front()
				for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = a + o
					if seen.has(n) or n.x < 0 or n.y < 0 or n.x >= m.cols or n.y >= m.rows or m.blocked.has(n):
						continue
					seen[n] = true
					q.append(n)
			var sealed := 0
			for y in range(1, m.rows - 1):
				for x in range(1, m.cols - 1):
					var c := Vector2i(x, y)
					if not m.blocked.has(c) and not seen.has(c) and not m.is_water_cell(c) and not m.things.has(c):
						sealed += 1
			# Things you walk onto (landing pads, warp pads, carpets) never block.
			for pc: Vector2i in m.props:
				var sp = m.props[pc]
				if not is_instance_valid(sp) or not (sp is Sprite2D) or (sp as Sprite2D).texture == null:
					continue
				var rp := str((sp as Sprite2D).texture.resource_path)
				if (sp as Sprite2D).texture is AtlasTexture:
					rp = str(((sp as Sprite2D).texture as AtlasTexture).atlas.resource_path)
				for wn in ["landing_pad", "warp_pad", "red_carpet"]:
					if rp.get_file().begins_with(wn):
						for dx in range(-1, 3):
							var bc := pc + Vector2i(dx, 0)
							if m.blocked.has(bc) and not m.things.has(bc):
								bad.append(bc)
			bad.sort()
			print("[%s] %s: %d invisible wall cells %s ; %d open cells unreachable" % [arc, s, bad.size(), str(bad.slice(0, 40)), sealed])
			if s in MUST_PASS and (bad.size() > 0 or sealed > 12):
				fails += 1
	print("invisible_walls: %d failures" % fails)
	quit(1 if fails > 0 else 0)

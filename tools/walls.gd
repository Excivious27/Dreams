extends SceneTree
## Invisible-wall audit: for each scene, list blocked cells inside the content
## area that have no prop, thing, border or water on them.
## godot --headless -s res://tools/walls.gd -- farm town ...

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	for sc in args:
		GameState.run["flags"][sc + "_seen"] = true
		GameMap.next_spawn = Vector2.ZERO
		change_scene_to_file("res://scenes/%s.tscn" % sc)
		for k in 12:
			await process_frame
		var m := current_scene as GameMap
		var prop_cells := {}
		for c in m.props:
			prop_cells[c] = true
		# Big props block rows above their base; mark those as "explained".
		for c: Vector2i in m.props:
			var s: Node = m.props[c]
			if s is Sprite2D and (s as Sprite2D).texture:
				var sp := s as Sprite2D
				var h := int(round(sp.texture.get_height() * sp.scale.y / GameMap.TILE))
				var w := int(round(sp.texture.get_width() * sp.scale.x / GameMap.TILE))
				for i in range(-w / 2 - 1, w / 2 + 2):
					for j in range(0, h + 1):
						prop_cells[Vector2i(c.x + i, c.y - j)] = true
		var walls: Array = []
		for c: Vector2i in m.blocked:
			if not m.in_content(c):
				continue
			if m.things.has(c) or prop_cells.has(c) or m._border_cells.has(c) or m.is_water_cell(c):
				continue
			walls.append(c)
		walls.sort()
		print("%s: %d invisible blocked cells of %d blocked in content" % [sc, walls.size(), m.blocked.size()])
		var line := ""
		for c in walls.slice(0, 80):
			line += "(%d,%d) " % [c.x, c.y]
		print("   ", line)
	quit()

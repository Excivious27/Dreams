extends GameMap
## The mine: a floor of rock to break with the pickaxe (stone, copper, iron,
## crystal shards), slimes and bats, and a ladder down to a harder floor.
## The layout is generated from the floor number so it's the same each visit.

var floor_no := 1
var _grotto := false
var _ladder := Vector2i.ZERO
var mine_tier := 0           # unified tier for this floor (GameState.mine_tier)
var _guardian: Enemy = null  # the floor's gatekeeper, once it has shown up
var _summoning := false
var _way_open := false       # shaft revealed (flag mine_open_<floor>)


## How much you've "tried" this floor: rocks broken count 1, kills count 3.
## Past the threshold the guardian shows up; beat it and the way down opens.
func _tried() -> int:
	return int(GameState.run.get("mine_tried", {}).get(str(floor_no), 0))


func _try_more(n: int) -> void:
	var d: Dictionary = GameState.run.get("mine_tried", {})
	d[str(floor_no)] = int(d.get(str(floor_no), 0)) + n
	GameState.run["mine_tried"] = d
	if not _way_open and _guardian == null and not _summoning and _tried() >= _threshold():
		_summoning = true
		call_deferred("_summon_guardian")
	elif not _way_open and _guardian == null and _tried() == _threshold() / 2:
		hud.toast("Something below is listening.", Color(0.8, 0.75, 0.9))


func _threshold() -> int:
	return 8 + floor_no * 2


func scene_id() -> String:
	return "mine"


func default_spawn() -> Vector2:
	return cell_center(Vector2i(2, 2))


func build() -> void:
	cols = 18
	rows = 18
	has_sky = false
	has_pet = false
	music_track = "mine"
	floor_no = int(GameState.run.get("mine_floor", 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + floor_no
	set_thing(1, 1, {"type": "up", "hint": "A: climb out"})
	mine_tier = GameState.mine_tier(floor_no)
	_ladder = Vector2i(rng.randi_range(12, 16), rng.randi_range(12, 16))
	_way_open = GameState.run["flags"].has("mine_open_%d" % floor_no)
	if _way_open:
		things[_ladder] = {"type": "down", "hint": "A: climb down to floor %d" % (floor_no + 1)}
	# The lift: once you've opened floor 5, Granite's cart takes you straight to
	# any floor you've opened the way to (every 5th).
	if floor_no == 1 and _deepest() >= 5:
		set_thing(cols - 2, 1, {"type": "lift", "hint": "A: the mine lift"})
	# Floor 5: the flooded grotto. Half the floor is black water; crystals sit
	# under it. Mer the mercat lives here; with her you can swim and dive.
	_grotto = floor_no == 5
	if _grotto:
		for y in range(6, rows - 1):
			for x in range(1, cols - 1):
				var wc := Vector2i(x, y)
				if WorldGen.fbm(float(x), float(y), 55, 6.0) > -0.1 and wc.distance_to(_ladder) > 2:
					set_thing(x, y, {"type": "water", "hint": ""}, true)
		swim_ok = true
		set_thing(4, 4, {"type": "mer", "hint": "A: ...a cat?"}, false)
		# Mer has to be visible: she gates the grotto. Hidden while she follows you.
		if Companion.active_id() != "mer" and str(GameState.run.get("playable", "")) != "mer":
			var ms := CharacterLibrary.make_sprite("mer")
			if ms:
				ms.position = cell_center(Vector2i(4, 4))
				ms.play("idle")
				ms.flip_h = true
				add_child(ms)
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = 5555
		var placed := 0
		for i in 60:
			var c := Vector2i(rng2.randi_range(2, cols - 3), rng2.randi_range(8, rows - 2))
			if is_water_cell(c) and not things[c].has("crystal"):
				things[c] = {"type": "water", "crystal": true, "key": "grotto_%d" % placed, "hint": "A: dive for the crystal"}
				placed += 1
				if placed >= 6:
					break
	var count := 40 + floor_no * 4
	for i in count:
		if _grotto and i > count / 2:
			break
		var c := Vector2i(rng.randi_range(1, cols - 2), rng.randi_range(1, rows - 2))
		if c.distance_to(Vector2i(1, 1)) < 3 or c == _ladder or things.has(c):
			continue
		var roll := rng.randf()
		var ore := "stone"
		var pool: Array = (GameState.tier_data.get("mine", {}).get("ores", []) as Array)
		var ores: Array = pool[mini(mine_tier, pool.size() - 1)] if not pool.is_empty() else ["stone", "copper"]
		# Half stone, the rest spread over the tier's ores (rarest last, least common).
		if roll > 0.5 and ores.size() > 1:
			var r2 := (roll - 0.5) * 2.0
			var idx := 1
			var acc := 0.0
			var weights: Array = []
			for oi in range(1, ores.size()):
				weights.append(1.0 / (oi + 0.5))
			var total := 0.0
			for w in weights:
				total += float(w)
			for wi in weights.size():
				acc += float(weights[wi]) / total
				if r2 <= acc:
					idx = wi + 1
					break
			ore = str(ores[idx])
		set_thing(c.x, c.y, {"type": "rock", "ore": ore, "hp": (2 if ore == "stone" else 3) + mine_tier, "hint": "A: mine"})


func after_ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2000 + floor_no + int(GameState.run["day"])
	_place_props()
	var n := 3 + mini(floor_no, 12) / 2
	var pools: Array = GameState.tier_data.get("mine", {}).get("pools", [])
	var pool: Array = pools[mini(mine_tier, pools.size() - 1)] if not pools.is_empty() else ["slime", "bat"]
	for i in n:
		var c := Vector2i(rng.randi_range(4, cols - 2), rng.randi_range(4, rows - 2))
		if blocked.has(c) or things.has(c) or (_grotto and is_water_cell(c)):
			continue
		var kind := str(pool[rng.randi_range(0, pool.size() - 1)])
		if not GameState.is_penguins() and kind == "shard":
			kind = "thug_cyber"
		spawn_enemy(kind, cell_center(c), mine_tier)
	if not _way_open and _guardian == null and not _summoning and _tried() >= _threshold():
		_summoning = true
		call_deferred("_summon_guardian")
	if not GameState.run["flags"].has("mine_tier_seen_%d" % mine_tier) and floor_no > 1:
		GameState.run["flags"]["mine_tier_seen_%d" % mine_tier] = true
		hud.toast("%s depths. Everything down here hits harder." % GameState.tier_name(mine_tier), Color(0.9, 0.8, 1.0))
	if not GameState.run["flags"].has("mine_seen"):
		GameState.run["flags"]["mine_seen"] = true
		player.frozen = true
		await say([
			{"text": "Cold air, and the smell of wet stone. Something drips. Something else squelches."},
			{"text": "Swing your pickaxe at rocks with A: stone, copper, iron, and now and then a crystal shard."},
			{"text": "There's no ladder down. The old miners said the way opens for whoever digs long enough to wake what guards it. Down is worse, and pays better."},
		])
		player.frozen = false


func interact(c: Vector2i, thing: Dictionary) -> bool:
	match str(thing.get("type", "")):
		"up":
			GameState.run["mine_floor"] = 1
			if str(GameState.run["flags"].get("mine_from", "meadow")) == "mountain":
				go_to("mountain", Vector2(6 * TILE, 5 * TILE), "down")
			else:
				go_to("meadow", Vector2(31 * TILE, 8 * TILE + 8), "down")
			return true
		"mer":
			later(_meet_mer)
			return true
		"water":
			if bool(thing.get("crystal", false)):
				if not Companion.has_ability("tail"):
					hud.toast("Too deep. Something glints down there.", Color(0.8, 0.9, 1.0))
					return true
				if GameState.run["flags"].has(str(thing["key"])):
					hud.toast("Already took that one.")
					return true
				GameState.run["flags"][str(thing["key"])] = true
				thing.erase("crystal")
				thing["hint"] = ""
				player.play_tool("hold")
				fx("splash", player.position, 12.0, 0.6)
				pop_items(cell_center(c), "shard", 2)
				xp("mining", 8)
				var got := 0
				for k in GameState.run["flags"]:
					if str(k).begins_with("grotto_"):
						got += 1
				if got >= 6:
					GameState.run["flags"]["grotto_done"] = true
					hud.toast("That's all six. Mer hums.", Color(0.8, 0.9, 1.0))
				return true
			return false
		"lift":
			later(_use_lift)
			return true
		"down":
			if _grotto and not GameState.run["flags"].has("grotto_done"):
				hud.toast("The ladder is under the water. You'd need to swim like she does.", Color(0.8, 0.9, 1.0))
				return true
			GameState.run["mine_floor"] = floor_no + 1
			GameState.run["flags"]["mine_deepest"] = maxi(_deepest(), floor_no + 1)
			xp("mining", 4)
			go_to("mine", Vector2.ZERO)
			return true
		"skeleton":
			if not GameState.run["flags"].has("skel_%d" % floor_no):
				GameState.run["flags"]["skel_%d" % floor_no] = true
				give("gold", 2)
				tell([{"text": "Somebody didn't make it back up. Their pack still has something in it."}])
			return true
		"rock":
			if GameState.held_tool() != "pickaxe":
				if GameState.has_tool("pickaxe"):
					hud.toast("Hold the pickaxe.")
					return true
				return false
			var ob := GameState.ore_block(str(thing.get("ore", "stone")))
			if ob != "":
				player.play_tool("pickaxe")
				hud.toast(ob, Color(1, 0.85, 0.6))
				return true
			if not GameState.spend_for("pickaxe"):
				hud.toast("Too tired.", Color(1, 0.7, 0.7))
				return true
			player.play_tool("pickaxe")
			Music.instance(get_tree()).sfx("chop")
			thing["hp"] = int(thing["hp"]) - (1 + GameState.tool_tier("pickaxe") / 2)
			if int(thing["hp"]) <= 0:
				var ore := str(thing["ore"])
				things.erase(c)
				blocked.erase(c)
				if props.has(c):
					(props[c] as Sprite2D).queue_free()
					props.erase(c)
				# Ore rocks give one lump, often two with a better pickaxe or the mining tree.
				var lumps := 2 if ore == "stone" else 1 + (1 if randf() < 0.3 + 0.1 * GameState.tool_tier("pickaxe") + GameState.bonus("mining", "ore_bonus") else 0)
				# Resonance (spell): +1 ore from every rock today.
				if ore != "stone" and int(GameState.run["flags"].get("ore_bonus_day", -1)) == int(GameState.run["day"]):
					lumps += 1
				give(ore, lumps)
				xp("mining", (2 if ore == "stone" else 5) + mine_tier)
				queue_redraw()
				_try_more(1)
			return true
	return false


## Prompts-11 tiered floor set for this floor ("" = use the older variants).
func _tier_set() -> String:
	var ts: String = {2: "deep", 3: "crystal", 4: "dark", 5: "heart"}.get(mine_tier, "")
	if ts != "" and Art.has("tiles", "mine_%s_fill_0" % ts):
		return str(ts)
	return ""


func _variant() -> String:
	if floor_no >= 10:
		return "lava"
	if floor_no >= 7:
		return "ice"
	if floor_no >= 4:
		return "stone"
	return "earth"


func draw_map() -> void:
	var v := _variant()
	if _grotto:
		var wc := {}
		for c in things:
			if str(things[c].get("type", "")) == "water":
				wc[c] = true
		draw_water(wc, "grass")
	var ts := _tier_set()
	if ts != "":
		var nfill := 0
		while Art.has("tiles", "mine_%s_fill_%d" % [ts, nfill]):
			nfill += 1
		var nwall := 0
		while Art.has("tiles", "mine_%s_wall_%d" % [ts, nwall]):
			nwall += 1
		var ntop := 0
		while Art.has("tiles", "mine_%s_walltop_%d" % [ts, ntop]):
			ntop += 1
		for y in range(1, rows - 1):
			for x in range(1, cols - 1):
				var h := absi((x * 73856093) ^ (y * 19349663) ^ floor_no)
				Art.draw_tile(self, "tiles", "mine_%s_fill_%d" % [ts, h % maxi(1, nfill)], Vector2(x * TILE, y * TILE), 0)
		# Top wall: two tiles tall, standing on row 0 and rising into the pad.
		for x in range(0, cols):
			var h := absi((x * 2654435761) ^ floor_no)
			var t := Art.tex("tiles", "mine_%s_wall_%d" % [ts, h % maxi(1, nwall)])
			if t:
				draw_texture_rect(t, Rect2(x * TILE, -TILE, TILE, TILE * 2), false)
		# Sides and bottom: the cap tiles.
		for y in range(1, rows):
			for x in [0, cols - 1]:
				var h2 := absi((x * 83492791) ^ (y * 19349663))
				var t2 := Art.tex("tiles", "mine_%s_walltop_%d" % [ts, h2 % maxi(1, ntop)])
				if t2:
					draw_texture_rect(t2, Rect2(x * TILE, (y - 1) * TILE, TILE, TILE * 2), false)
		for x in range(1, cols - 1):
			var h3 := absi((x * 97) ^ (rows * 19349663))
			var t3 := Art.tex("tiles", "mine_%s_walltop_%d" % [ts, h3 % maxi(1, ntop)])
			if t3:
				draw_texture_rect(t3, Rect2(x * TILE, (rows - 2) * TILE, TILE, TILE * 2), false)
		draw_rect(Rect2(0, 0, cols * TILE, rows * TILE), Color(0.03, 0.02, 0.08, 0.1 + 0.02 * mini(floor_no, 10)))
	elif Art.has("tiles", "mf_" + v) and Art.has("tiles", "mw_" + v):
		draw_tileset_rect("mf_" + v, Rect2i(1, 1, cols - 2, rows - 2), Color("3b3542"))
		draw_rect(Rect2(0, 0, cols * TILE, rows * TILE), Color(0.05, 0.03, 0.1, 0.15 + 0.03 * mini(floor_no, 8)))
		var w := "mw_" + v
		for x in range(1, cols - 1):
			Art.draw_tile(self, "tiles", w, Vector2(x * TILE, 0), 1)
			Art.draw_tile(self, "tiles", w, Vector2(x * TILE, (rows - 1) * TILE), 7)
		for y in range(1, rows - 1):
			Art.draw_tile(self, "tiles", w, Vector2(0, y * TILE), 3)
			Art.draw_tile(self, "tiles", w, Vector2((cols - 1) * TILE, y * TILE), 5)
		Art.draw_tile(self, "tiles", w, Vector2(0, 0), 0)
		Art.draw_tile(self, "tiles", w, Vector2((cols - 1) * TILE, 0), 2)
		Art.draw_tile(self, "tiles", w, Vector2(0, (rows - 1) * TILE), 6)
		Art.draw_tile(self, "tiles", w, Vector2((cols - 1) * TILE, (rows - 1) * TILE), 8)
		if v == "lava" and Art.has("tiles", "lava"):
			_anim_layer.jobs.append(func(ci: CanvasItem) -> void:
				var frame := int(Time.get_ticks_msec() / 300) % 4
				for c: Vector2i in cells_of([Rect2i(3, 12, 4, 3), Rect2i(12, 4, 3, 2)]):
					Art.draw_tile(ci, "tiles", "lava", Vector2(c * TILE), frame))
	elif Art.has("tiles", "mine_floor"):
		draw_tileset_rect("mine_floor", Rect2i(1, 1, cols - 2, rows - 2), Color("3b3542"))
		draw_rect(Rect2(0, 0, cols * TILE, rows * TILE), Color(0.05, 0.03, 0.1, 0.3 + 0.05 * mini(floor_no, 6)))
		for x in range(1, cols - 1):
			Art.draw_tile(self, "tiles", "wall_t", Vector2(x * TILE, 0), 0)
			Art.draw_tile(self, "tiles", "wall_b", Vector2(x * TILE, (rows - 1) * TILE), 0)
		for y in range(1, rows - 1):
			Art.draw_tile(self, "tiles", "wall_l", Vector2(0, y * TILE), 0)
			Art.draw_tile(self, "tiles", "wall_r", Vector2((cols - 1) * TILE, y * TILE), 0)
		Art.draw_tile(self, "tiles", "wall_tl", Vector2(0, 0), 0)
		Art.draw_tile(self, "tiles", "wall_tr", Vector2((cols - 1) * TILE, 0), 0)
		Art.draw_tile(self, "tiles", "wall_bl", Vector2(0, (rows - 1) * TILE), 0)
		Art.draw_tile(self, "tiles", "wall_br", Vector2((cols - 1) * TILE, (rows - 1) * TILE), 0)
	elif Art.has("tiles", "stone"):
		for y in rows:
			for x in cols:
				Art.draw_tile(self, "tiles", "stone", Vector2(x * TILE, y * TILE), 4)
		draw_rect(Rect2(0, 0, cols * TILE, rows * TILE), Color(0.1, 0.05, 0.2, 0.45))
	else:
		for y in rows:
			for x in cols:
				draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), Color("3b3542") if (x + y) % 2 == 0 else Color("433c4b"))
	if not _way_open and Art.has("props", "shaft_hint_0") and not things.has(_ladder):
		Art.draw_prop(self, "props", "shaft_hint_%d" % clampi(mine_tier / 2 + (1 if mine_tier >= 3 else 0), 0, 3), cell_center(_ladder) + Vector2(0, 6))
	for k in things:
		var t: Dictionary = things[k]
		var p := cell_center(k)
		match str(t.get("type", "")):
			"rock":
				if props.has(k):
					continue
				draw_circle(p + Vector2(0, -6), 7.0, Color("7a7a86"))
			"lift":
				if not Art.draw_prop(self, "props", "mine_lift", p + Vector2(0, 2)) and not Art.draw_prop(self, "props", "cart_full", p):
					draw_rect(Rect2(p.x - 7, p.y - 12, 14, 12), Color("5a4a3a"))
			"up", "down":
				var nm := "ladder_up" if str(t["type"]) == "up" else "ladder_down"
				if Art.has("props", "ladder_a"):
					nm = "ladder_a" if str(t["type"]) == "up" else "shaft"
				if str(t["type"]) == "down" and Art.has("props", "shaft_open_0"):
					nm = "shaft_open_%d" % clampi(mine_tier / 2 + (1 if mine_tier >= 3 else 0), 0, 3)
				if not Art.draw_prop(self, "props", nm, p):
					draw_rect(Rect2(p.x - 6, p.y - 14, 12, 14), Color("1a1620"))
	if not Art.has("tiles", "mine_floor"):
		draw_rect(Rect2(0, 0, cols * TILE, TILE), Color("221d28"))
		draw_rect(Rect2(0, (rows - 1) * TILE, cols * TILE, TILE), Color("221d28"))
		draw_rect(Rect2(0, 0, TILE, rows * TILE), Color("221d28"))
		draw_rect(Rect2((cols - 1) * TILE, 0, TILE, rows * TILE), Color("221d28"))
	label("floor %d" % floor_no, Vector2(2 * TILE, TILE - 3), 6 * TILE)


func _place_props() -> void:
	var ts := _tier_set()
	if ts != "":
		var nrock := 0
		while Art.has("props", "mine_%s_rock_%d" % [ts, nrock]):
			nrock += 1
		var ore_sets := {"deep": {"iron": "a", "gold": "b"}, "crystal": {"shard": "a", "gold": "b"}, "dark": {"dark": "a", "shard": "b"}, "heart": {"shard": "a", "dark": "b"}}
		for k in things:
			var t: Dictionary = things[k]
			if str(t.get("type", "")) != "rock":
				continue
			var ore := str(t["ore"])
			var nm := ""
			var oset: Dictionary = ore_sets.get(ts, {})
			if oset.has(ore) and Art.has("props", "mine_%s_ore_%s_0" % [ts, oset[ore]]):
				nm = "mine_%s_ore_%s_0" % [ts, oset[ore]]
			elif ore != "stone" and Art.has("props", "node_" + ore):
				nm = "node_" + ore
			elif nrock > 0:
				nm = "mine_%s_rock_%d" % [ts, absi((k.x * 7 + k.y * 13)) % maxi(1, mini(nrock, 5))]
			if nm != "":
				prop("props", nm, k)
		var rng := RandomNumberGenerator.new()
		rng.seed = 4100 + floor_no
		var ndec := 0
		while Art.has("props", "mine_%s_decal_%d" % [ts, ndec]):
			ndec += 1
		for i in 8:
			var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(2, rows - 3))
			if not things.has(c) and not blocked.has(c) and ndec > 0:
				var sp := prop("props", "mine_%s_decal_%d" % [ts, rng.randi_range(0, ndec - 1)], c, 0, 0.0, false)
				if sp:
					sp.z_index = -1
		for x in [2, cols - 3]:
			var c := Vector2i(x, 1)
			if not things.has(c) and Art.has("props", "mine_%s_lamp_0" % ts):
				prop("props", "mine_%s_lamp_%d" % [ts, x % 2], c)
		for i in 2:
			var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(2, rows - 3))
			if not things.has(c) and not blocked.has(c) and Art.has("props", "mine_%s_stalag_0" % ts):
				prop("props", "mine_%s_stalag_%d" % [ts, i], c)
		if floor_no % 2 == 0 and Art.has("props", "mine_%s_cart" % ts) and not things.has(Vector2i(2, rows - 3)):
			prop("props", "mine_%s_cart" % ts, Vector2i(2, rows - 3))
			blocked[Vector2i(2, rows - 3)] = true
		if floor_no % 5 == 0 and not things.has(Vector2i(cols - 3, 2)):
			prop("props", "mine_%s_skeleton" % ts if Art.has("props", "mine_%s_skeleton" % ts) else "skeleton", Vector2i(cols - 3, 2))
			blocked[Vector2i(cols - 3, 2)] = true
			set_thing(cols - 3, 2, {"type": "skeleton", "hint": "A: an old miner"})
		if floor_no % 3 == 0 and Art.has("props", "mine_%s_crystal" % ts):
			var c := Vector2i(rng.randi_range(3, cols - 4), rng.randi_range(3, rows - 4))
			if not things.has(c) and not blocked.has(c):
				prop("props", "mine_%s_crystal" % ts, c)
		if ts == "heart" and floor_no >= 21 and Art.has("props", "heart_crystal"):
			anim_prop("props", "heart_crystal", Vector2i(cols / 2, 4), 2, 3.0, true, 0.5)
		return
	if Art.has("props", "ore_copper"):
		var v := _variant()
		var deep := Art.has("props", "node_copper")
		for k in things:
			var t: Dictionary = things[k]
			if str(t.get("type", "")) != "rock":
				continue
			var ore := str(t["ore"])
			var nm: String = {"stone": "mrock_a" if (k.x + k.y) % 3 != 0 else "mrock_b", "copper": "ore_copper", "iron": "ore_iron", "shard": "ore_crystal", "gold": "ore_gold", "dark": "ore_dark"}.get(ore, "mrock_a")
			if deep:
				nm = {"stone": "mrock_%s_%d" % [v, (k.x + k.y) % 2], "copper": "node_copper", "iron": "node_iron", "shard": "node_crystal", "gold": "node_gold", "dark": "node_dark"}.get(ore, nm)
			prop("props", nm, k)
		if deep:
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = 4000 + floor_no
			for i in 3:
				var c := Vector2i(rng2.randi_range(2, cols - 3), rng2.randi_range(2, rows - 3))
				if not things.has(c) and not blocked.has(c):
					prop("props", ["cluster_blue", "cluster_purple", "gmush_blue", "gmush_red", "stalagmite_a"][rng2.randi_range(0, 4)], c)
			for x in [3, cols - 4]:
				var sp := Art.sprite("props", "stalactite_%s" % ["a", "b", "c"][x % 3])
				if sp:
					sp.position = Vector2(x * TILE + 8, TILE + 20)
					add_child(sp)
			prop("props", "beam_lamp", Vector2i(cols / 2 - 1, 1), 1)
			if floor_no % 2 == 0 and not things.has(Vector2i(2, rows - 3)):
				prop("props", "cart_full", Vector2i(2, rows - 3))
				blocked[Vector2i(2, rows - 3)] = true
			if floor_no % 5 == 0 and not things.has(Vector2i(cols - 3, 2)):
				prop("props", "skeleton", Vector2i(cols - 3, 2))
				blocked[Vector2i(cols - 3, 2)] = true
				set_thing(cols - 3, 2, {"type": "skeleton", "hint": "A: an old miner"})
		var rng := RandomNumberGenerator.new()
		rng.seed = 3000 + floor_no
		for i in 4:
			var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(2, rows - 3))
			if not things.has(c) and not blocked.has(c):
				prop("props", "cave_mushroom" if rng.randf() < 0.5 else "cave_moss", c)
		if floor_no % 3 == 0:
			prop("props", "beam", Vector2i(cols / 2 - 1, 1), 1)
		return
	if not Art.has("nature", "rock_m"):
		return
	for k in things:
		var t: Dictionary = things[k]
		if str(t.get("type", "")) != "rock":
			continue
		prop("nature", "rock_m", k)


func _process(delta: float) -> void:
	super(delta)


func _deepest() -> int:
	return int(GameState.run["flags"].get("mine_deepest", 1))


func on_enemy_died(e: Enemy) -> void:
	super(e)
	if e == _guardian:
		_guardian = null
		_open_way()
	else:
		_try_more(3)


## The floor's gatekeeper: the tier's guardian kind, run at this floor's tier,
## one more ability per floor into the tier, and more hp the deeper you are.
func _summon_guardian() -> void:
	if _guardian != null or _way_open:
		return
	var kinds: Array = GameState.tier_data.get("mine", {}).get("guardians", ["golem"])
	var kind := str(kinds[mini(mine_tier, kinds.size() - 1)])
	var at := cell_center(_ladder)
	if _grotto:
		at = cell_center(Vector2i(cols / 2, 3))
	shake(3.0)
	fx("keeper_wake" if Art.has("fx", "keeper_wake") else "boss_shockwave", at, 12.0, 0.8)
	await get_tree().create_timer(0.9 if Art.has("fx", "keeper_wake") else 0.4).timeout
	# Never weaker than its native tier; floor 1's golem is still a golem.
	_guardian = spawn_enemy(kind, at, maxi(mine_tier, GameState.enemy_tier(kind)))
	_guardian.is_guardian = true
	var into := (floor_no - 1) % int(GameState.tier_data.get("mine", {}).get("floors_per_tier", 4))
	_guardian.max_hp = int(_guardian.max_hp * (1.5 + 0.12 * floor_no))
	_guardian.hp = _guardian.max_hp
	var extra: Array = ["lunge", "stomp", "ranged", "shield", "summon", "regen"]
	for i in into:
		for a in extra:
			if not _guardian.abilities.has(a):
				_guardian.abilities.append(a)
				break
	_guardian.reward *= 3
	if Art.has("ui", "card_keeper_%d" % mine_tier):
		boss_card("card:card_keeper_%d" % mine_tier, ["The Stone Fist", "The Quarrymaster", "The Cracked Helm", "The Crystal King", "The Dark Warden", "The Heart's Shadow"][mine_tier])
	else:
		boss_card(kind, "Keeper of floor %d" % floor_no)
	hud.toast("The keeper of floor %d wakes!" % floor_no, Color(1, 0.7, 0.7))
	Music.instance(get_tree()).sfx("levelup")


func _open_way() -> void:
	GameState.run["flags"]["mine_open_%d" % floor_no] = true
	_way_open = true
	things[_ladder] = {"type": "down", "hint": "A: climb down to floor %d" % (floor_no + 1)}
	blocked.erase(_ladder)
	if props.has(_ladder):
		(props[_ladder] as Node).queue_free()
		props.erase(_ladder)
	shake(4.0)
	fx("rock_m_break", cell_center(_ladder), 14.0, 0.8)
	queue_redraw()
	queue_redraw()
	hud.toast("The rock splits. A shaft leads down!", Color(0.8, 1.0, 0.8))
	GameState.add_hint("The way down to floor %d is open." % (floor_no + 1))
	if floor_no % 5 == 0:
		hud.toast("The lift can reach floor %d now." % floor_no, Color(0.8, 0.9, 1.0))



func _use_lift() -> void:
	var floors: Array = []
	var f := 5
	while f <= _deepest():
		floors.append(f)
		f += 5
	if floors.is_empty():
		return
	var labels: Array = []
	for n in floors:
		labels.append("Floor %d" % n)
	labels.append("Stay")
	player.frozen = true
	var d := Dialogue.instance(get_tree())
	d.say([{"who": "", "text": "Granite's lift. Rope creaks, lamp swings.", "choice": labels, "key": ""}])
	await d.finished
	player.frozen = false
	if d.last_choice >= 0 and d.last_choice < floors.size():
		GameState.run["mine_floor"] = int(floors[d.last_choice])
		go_to("mine", Vector2.ZERO)


## Mer, the mercat of the grotto. Join her and the water opens.
func _meet_mer() -> void:
	player.frozen = true
	if Companion.party()["known"].has("mer"):
		var d0 := Dialogue.instance(get_tree())
		d0.say([{"who": "Mer", "text": "Swim with me?" if Companion.active_id() != "mer" else "I'm right here. The ladder's under the deep part, past the six stones.", "choice": ["Mer joins me", "Not now"] if Companion.active_id() != "mer" else ["OK"], "key": ""}])
		await d0.finished
		if d0.last_choice == 0 and Companion.active_id() != "mer":
			Companion.recruit("mer")
			hud.toast("Mer is with you. The water is yours.", Color(0.8, 0.95, 1.0))
			_refresh_party()
		player.frozen = false
		return
	await say([
		{"who": "", "text": "On a dry rock at the water's edge: a cat. Grey, wet, entirely unbothered. Its tail is... not a cat's tail."},
		{"who": "Mer", "text": "You came down the dark stair with a lantern and no fear. That's rarer than crystal."},
		{"who": "Mer", "text": "I'm Mer. I was a cat once, before the water. Now I'm a mercat, which is better in every way but the fur."},
		{"who": "Mer", "text": "The crystals you want are under the black water. Six of them. You can't reach them; your kind sinks."},
		{"who": "Mer", "text": "But if I'm beside you, the water remembers me, and it'll let you borrow a tail. Breathe, dive, the lot. Only while I'm with you, mind."},
	])
	var d := Dialogue.instance(get_tree())
	d.say([{"who": "Mer", "text": "Come on, then. The water's warmer than it looks.", "choice": ["Swim with Mer", "Not yet"], "key": ""}])
	await d.finished
	if d.last_choice == 0:
		Companion.recruit("mer")
		GameState.add_quest("mer_crystals", "Dive with Mer for the six grotto crystals.")
		hud.toast("Mer joined you! Walk into the water.", Color(0.8, 0.95, 1.0))
		Music.instance(get_tree()).sfx("levelup")
		_refresh_party()
	else:
		Companion.refuse("mer")
		await say([{"who": "Mer", "text": "...Suit yourself. I'll be here. I'm always here."}])
	player.frozen = false

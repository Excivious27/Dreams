class_name HiddenArea
extends Node2D
## Tom's exploration rule (CONDUCT 4): every mega area hides a little pocket and
## a secret way, placed with some art rather than at random.
##
## - Pocket: a small nook dug into a wall mass (tree band, cliff, rocks), its
##   mouth closed by a vine curtain (A parts it) or a cracked wall (pickaxe).
##   Inside: an old chest (tier + 1 loot) and, in the newer areas, a journal page.
## - Secret way: a hidden pair of ends (ledge stairs up a hill, or a crack in the
##   rock) that, once found, carry you across the map: a shortcut to a hilltop or
##   a far dead end.
## Both are found by looking: the pup sniffs when you're close, and at dawn and
## dusk a faint sparkle shows where. Opened mouths/found ways stay open (flags
## hidden_open_<rid>, hidden_way_<rid>).
##
## regions.json may override: "hidden": {"pockets": 0|1, "ways": 0|1}.
## Art (P5): props/hidden_vine_curtain, props/hidden_crack_wall, props/hidden_stairs,
## props/hidden_cave_mouth_<theme>; drawn shapes when missing.

const THEMES := {"gloamwood": "gloam", "sunscorch": "desert", "frostpeak": "frost", "windward": "sky",
	"giltcity": "garden", "cities": "city", "space": "space", "colonies": "sea", "hollow": "cave", "sky": "sky"}
const VINE_THEMES := ["gloam", "sky", "sea", "garden"]
const WALL_PROPS := {"gloam": ["bush2_blue", "bush2_green"], "sky": ["bush2_green", "bush2_flower"], "sea": ["boulder2_m_a", "boulder2_m_b"],
	"desert": ["boulder2_m_a", "boulder2_m_b"], "frost": ["bush_snow", "boulder2_m_b"], "city": ["crates_a", "barrel_a", "crates_b"], "garden": ["hedge2_ball", "hedge2_tree_s"],
	"space": ["boulder2_m_b", "boulder2_s_b"], "cave": ["boulder2_m_a", "boulder2_m_b"]}

## Sealed rooms behind a guardian: open once its boss flag is set.
const SANCTUMS := {
	"desert_sunken_temple": {"need": "boss_desert_sunken_temple", "hint": "A: a sealed sun door",
		"shut": "A sun door, sealed. Sand trickles from its seams. The Colossus stands between you and it; while it stands, it won't open.",
		"page": "Page: The inner sanctum. The last spark of the old sun sleeps in a bowl of glass here, small as a firefly. The Colossus guarded it so long it forgot why. Now you know."},
}

var map: GameMap = null
var spots: Array = []  # [cell, kind] still to be found (sniff/sparkle)
var _t := 0.0
var _sniffed := false


## Mega area or explicit data: how many pockets / ways to place here.
static func wanted(m: GameMap, rid: String) -> Vector2i:
	if rid.begins_with("bf_"):
		return Vector2i.ZERO
	var R: Dictionary = m.get("R") if m.get("R") is Dictionary else {}
	var hd: Dictionary = R.get("hidden", {})
	var mega := MegaRegion.region_of(rid) != ""
	if not mega and hd.is_empty():
		return Vector2i.ZERO
	return Vector2i(int(hd.get("pockets", 1)), int(hd.get("ways", 1)))


static func theme_of(rid: String) -> String:
	return str(THEMES.get(MegaRegion.region_of(rid), "cave"))


## Places this area's pocket and secret way (deterministic per area). Returns
## the node (null if nothing was placed). Call after props/things are placed.
static func place(m: GameMap, rid: String, tier: int) -> HiddenArea:
	var want := wanted(m, rid)
	if want == Vector2i.ZERO:
		return null
	var node := HiddenArea.new()
	node.map = m
	node.name = "HiddenArea"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(rid + "_hidden")
	var theme := theme_of(rid)
	var reach := _reach(m, _start(m))
	var pocket: Dictionary = {}
	if want.x > 0:
		pocket = _place_pocket(m, rid, tier, theme, rng, reach, node)
	if SANCTUMS.has(rid):
		var sd: Dictionary = SANCTUMS[rid]
		var near := Vector2i(-1, -1)
		for c: Vector2i in m.things:
			if str(m.things[c].get("type", "")) == "boss":
				near = c
		if near.x >= 0:
			_place_pocket(m, rid, tier + 1, theme, rng, _reach(m, _start(m)), node, near, "_sanctum", sd)
	if want.y > 0:
		_place_way(m, rid, theme, rng, _reach(m, _start(m)), pocket, node)
	m.add_child(node)
	return node


static func _start(m: GameMap) -> Vector2i:
	return m.world_to_cell(m.default_spawn() - Vector2(0, 2))


## Walkable cells reachable from `from` (4-way).
static func _reach(m: GameMap, from: Vector2i) -> Dictionary:
	var seen := {}
	var st: Array = [from]
	while not st.is_empty():
		var c: Vector2i = st.pop_back()
		if seen.has(c) or not m.in_content(c) or m.blocked.has(c):
			continue
		seen[c] = true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			st.append(c + d)
	return seen


## Cells that must stay as they are: paths, exits (+2), spawn (+3), stairs, things.
static func _keep(m: GameMap) -> Dictionary:
	var keep := {}
	var R: Dictionary = m.get("R") if m.get("R") is Dictionary else {}
	for p in R.get("paths", []):
		keep.merge(m.cells_of([Rect2i(int(p[0]), int(p[1]), int(p[2]), int(p[3]))]))
	for e in m.exits:
		keep.merge(m.cells_of([(e["rect"] as Rect2i).grow(2)]))
	var s := _start(m)
	keep.merge(m.cells_of([Rect2i(s.x - 3, s.y - 3, 7, 7)]))
	for pl: Dictionary in m.plateaus:
		for stc: Vector2i in pl["stairs"]:
			keep.merge(m.cells_of([Rect2i(stc.x - 1, stc.y - 2, 3, 5)]))
	for c: Vector2i in m.things:
		keep[c] = true
	return keep


static func _place_pocket(m: GameMap, rid: String, tier: int, theme: String, rng: RandomNumberGenerator, reach: Dictionary, node: HiddenArea, near := Vector2i(-1, -1), tag := "", sanctum: Dictionary = {}) -> Dictionary:
	var keep := _keep(m)
	var best: Dictionary = {}
	var best_score := -1.0
	var dirs: Array = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]
	var cand: Array = reach.keys()
	if cand.is_empty():
		return {}
	for tries in 260:
		var e: Vector2i = cand[rng.randi() % cand.size()]  # where you stand to open it
		if keep.has(e) or (near.x >= 0 and e.distance_to(near) > 7.0):
			continue
		var d: Vector2i = dirs[rng.randi() % dirs.size()]
		var mouth := e + d
		var side := Vector2i(d.y, d.x)  # across the mouth
		var inner := {}
		for k in range(1, 3):  # 3 wide, 2 deep beyond the mouth
			for j in range(-1, 2):
				inner[mouth + d * k + side * j] = true
		var ring := {}
		for c: Vector2i in inner:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var r: Vector2i = c + Vector2i(dx, dy)
					if not inner.has(r):
						ring[r] = true
		ring.erase(e)
		var ok := true
		var walled := 0
		for c: Vector2i in inner:
			if not m.in_content(c) or c.x < 2 or c.y < 2 or c.x >= m.cols - 2 or c.y >= m.rows - 2 or keep.has(c) or m.is_water_cell(c) or m.props.has(c) or m.hard.has(c) or m._border_cells.has(c):
				ok = false
				break
		if not ok:
			continue
		for c: Vector2i in ring:
			if keep.has(c) and not m.blocked.has(c):
				ok = false
				break
			if m.blocked.has(c) or not m.in_content(c):
				walled += 1
		if not ok or m.is_water_cell(mouth):
			continue
		# The inner cells must be open ground now (we fence them off, never carve art).
		if inner.keys().any(func(c: Vector2i) -> bool: return m.blocked.has(c)):
			continue
		# Dug into a wall mass reads best; far from the start and the roads a little.
		var score := float(walled) + rng.randf() * 2.0 + minf(8.0, e.distance_to(_start(m))) * 0.2
		if score <= best_score:
			continue
		# Walling it in must not cut anything else off.
		var added: Array = []
		for c: Vector2i in ring:
			if not m.blocked.has(c) and m.in_content(c):
				added.append(c)
		added.append(mouth)
		for c: Vector2i in added:
			m.blocked[c] = true
		for c: Vector2i in inner:
			m.blocked[c] = true
		var after := _reach(m, _start(m))
		for c: Vector2i in added:
			m.blocked.erase(c)
		for c: Vector2i in inner:
			m.blocked.erase(c)
		var lost := false
		for c: Vector2i in reach:
			if not after.has(c) and not inner.has(c) and not c in added:
				lost = true
				break
		if lost or not after.has(e):
			continue
		best = {"e": e, "mouth": mouth, "inner": inner, "added": added, "d": d}
		best_score = score
	if best.is_empty():
		return {}
	var key := "hidden_open_" + rid + tag
	var open: bool = GameState.run["flags"].has(key)
	var walls: Array = WALL_PROPS.get(theme, WALL_PROPS["cave"])
	for c: Vector2i in best["added"]:
		if c == best["mouth"]:
			continue
		m.blocked[c] = true
		m.hard[c] = true
		var wn := str(walls[absi(c.x * 7 + c.y * 3) % walls.size()])
		var g := "nature" if Art.has("nature", wn) else "props"
		if Art.has(g, wn):
			m.prop(g, wn, c, 0, 0.0, false)
	var mouth: Vector2i = best["mouth"]
	var kind := "vine" if theme in VINE_THEMES else "crack"
	if not sanctum.is_empty():
		kind = "door"
	if not open:
		m.set_thing(mouth.x, mouth.y, {"type": "hidden_mouth", "key": key, "kind": kind, "need": str(sanctum.get("need", "")), "shut": str(sanctum.get("shut", "")),
			"hint": str(sanctum.get("hint", "")) if kind == "door" else ("A: the vines stir in a draft" if kind == "vine" else "A: a cracked wall (pickaxe)")}, true)
		m.hard[mouth] = true
		node._mouth_art(mouth, kind, theme)
		node.spots.append([mouth, "pocket"])
	# Inside: the chest at the back middle, the page beside it.
	var back: Vector2i = mouth + (best["d"] as Vector2i) * 2
	var ck := "hidden_chest_" + rid + tag
	var got: bool = GameState.run["flags"].has(ck)
	var loot: Dictionary = Secrets.LOOT[clampi(tier + 1, 0, Secrets.LOOT.size() - 1)]
	m.set_thing(back.x, back.y, {"type": "secret_chest", "key": ck, "give": loot, "hint": "" if got else "A: an old chest"}, true)
	m.prop("props", "chest_open" if got else "chest_closed", back)
	var page_txt := str(sanctum.get("page", Secrets.POCKET_PAGES.get(rid, "")))
	if page_txt != "":
		var side := Vector2i((best["d"] as Vector2i).y, (best["d"] as Vector2i).x)
		var pc: Vector2i = mouth + (best["d"] as Vector2i) + side
		var pk := "page_" + rid + tag
		if not GameState.run["flags"].has(pk):
			m.set_thing(pc.x, pc.y, {"type": "page", "key": pk, "text": page_txt, "hint": "A: a torn page"}, false)
			m.prop("props", "signpost" if Art.has("props", "signpost") else "chest_closed", pc, 0, 0.0, false, 0.25)
	return best


## A secret way: two hidden ends. Up a hill (stairs onto a plateau top) when the
## area has one, else a crack across to a far, quiet corner.
static func _place_way(m: GameMap, rid: String, theme: String, rng: RandomNumberGenerator, reach: Dictionary, pocket: Dictionary, node: HiddenArea) -> void:
	var keep := _keep(m)
	var near_wall := func(c: Vector2i) -> bool:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if m.blocked.has(c + d) and not m.things.has(c + d):
				return true
		return false
	var cand: Array = []
	for c: Vector2i in reach:
		if keep.has(c) or m.props.has(c) or m.is_water_cell(c) or c.x < 2 or c.y < 2 or c.x >= m.cols - 2 or c.y >= m.rows - 2:
			continue
		if not pocket.is_empty() and c.distance_to(pocket["mouth"]) < 5.0:
			continue
		if near_wall.call(c):
			cand.append(c)
	if cand.size() < 2:
		return
	cand.sort()
	var kind := "crack"
	var a := Vector2i(-1, -1)
	var b := Vector2i(-1, -1)
	# Up: a top cell of a plateau, and a foot cell below its rock face.
	for pl: Dictionary in m.plateaus:
		var tops: Array = (pl["cells"] as Dictionary).keys().filter(func(c: Vector2i) -> bool: return cand.has(c))
		if tops.is_empty():
			continue
		var top: Vector2i = tops[rng.randi() % tops.size()]
		var foots: Array = cand.filter(func(c: Vector2i) -> bool: return not (pl["cells"] as Dictionary).has(c) and c.distance_to(top) >= 4.0 and c.distance_to(top) <= 9.0)
		if foots.is_empty():
			continue
		a = foots[rng.randi() % foots.size()]
		b = top
		kind = "stairs"
		break
	if a.x < 0:
		for tries in 80:
			var p: Vector2i = cand[rng.randi() % cand.size()]
			var q: Vector2i = cand[rng.randi() % cand.size()]
			if p.distance_to(q) >= maxf(12.0, (m.cols + m.rows) * 0.3):
				a = p
				b = q
				break
	if a.x < 0:
		return
	var key := "hidden_way_" + rid
	var found: bool = GameState.run["flags"].has(key)
	for pair: Array in [[a, b], [b, a]]:
		var here: Vector2i = pair[0]
		var to: Vector2i = pair[1]
		m.set_thing(here.x, here.y, {"type": "secret_way", "key": key, "kind": kind, "to": [to.x, to.y],
			"hint": ("A: take the hidden way" if found else ("A: worn steps in the rock?" if kind == "stairs" else "A: a draught from a crack"))}, false)
		node._way_art(here, kind, theme, found)
		if not found:
			node.spots.append([here, "way"])


## ---- art (P5 names, drawn fallback) -------------------------------------------

func _mouth_art(c: Vector2i, kind: String, theme: String) -> void:
	var nm := "hidden_vine_curtain" if kind == "vine" else ("hidden_sun_door" if kind == "door" else "hidden_crack_wall")
	if Art.has("props", nm):
		map.prop("props", nm, c, 0, 0.0, false)
		return
	var d := _Drawn.new()
	d.kind = kind
	d.theme = theme
	d.position = map.cell_center(c)
	map.add_child(d)
	map.props[c] = d


func _way_art(c: Vector2i, kind: String, theme: String, found: bool) -> void:
	var nm := "hidden_stairs" if kind == "stairs" else "hidden_cave_mouth_" + theme
	var a := 1.0 if found else 0.55
	if Art.has("props", nm):
		var s := map.prop("props", nm, c, 0, 0.0, false)
		if s:
			s.modulate.a = a
			map.to_under(s)
		return
	var d := _Drawn.new()
	d.kind = "way_" + kind
	d.theme = theme
	d.modulate.a = a
	d.position = map.cell_center(c)
	map.to_under(d)
	if not map.props.has(c):
		map.props[c] = d


## Drawn fallback for the hidden-area pieces (until/unless the art exists).
class _Drawn extends Node2D:
	var kind := "crack"
	var theme := "cave"

	func _draw() -> void:
		var stone: Color = {"desert": Color(0.78, 0.62, 0.42), "frost": Color(0.7, 0.8, 0.9), "city": Color(0.5, 0.5, 0.55),
			"space": Color(0.45, 0.42, 0.55), "gloam": Color(0.32, 0.3, 0.42)}.get(theme, Color(0.48, 0.45, 0.42))
		var dark := Color(0.08, 0.06, 0.1)
		match kind:
			"vine":
				draw_rect(Rect2(-8, -18, 16, 18), stone.darkened(0.45))
				for i in 6:
					var x := -7.0 + i * 2.8
					var leaf := Color(0.25, 0.55, 0.3) if theme != "gloam" else Color(0.45, 0.35, 0.7)
					draw_line(Vector2(x, -18), Vector2(x + sin(i * 1.7) * 1.5, -1), leaf.darkened(0.2), 1.5)
					for k in 3:
						draw_circle(Vector2(x + sin(i + k) * 1.2, -15 + k * 5 + i % 2 * 2), 1.4, leaf)
			"door":
				draw_rect(Rect2(-9, -20, 18, 20), stone.darkened(0.15))
				draw_rect(Rect2(-6, -17, 12, 17), Color(0.85, 0.65, 0.25))
				draw_circle(Vector2(0, -10), 3.5, Color(1.0, 0.85, 0.4))
				draw_line(Vector2(0, -17), Vector2(0, 0), dark, 1.0)
			"crack":
				draw_rect(Rect2(-8, -16, 16, 16), stone)
				draw_rect(Rect2(-8, -16, 16, 16), stone.darkened(0.35), false, 1.0)
				var pts := PackedVector2Array([Vector2(-1, -15), Vector2(1, -11), Vector2(-2, -8), Vector2(1, -4), Vector2(0, -1)])
				draw_polyline(pts, dark, 1.5)
				draw_line(Vector2(1, -11), Vector2(5, -12), dark, 1.0)
				draw_line(Vector2(-2, -8), Vector2(-5, -6), dark, 1.0)
			"way_stairs":
				for i in 3:
					draw_rect(Rect2(-6, -4 - i * 4, 12, 3), stone.darkened(0.1 + i * 0.12))
					draw_line(Vector2(-6, -1 - i * 4), Vector2(6, -1 - i * 4), dark, 1.0)
			_:
				draw_colored_polygon(PackedVector2Array([Vector2(-6, -2), Vector2(-3, -7), Vector2(3, -8), Vector2(7, -3), Vector2(4, 0), Vector2(-4, 0)]), dark)
				draw_polyline(PackedVector2Array([Vector2(-7, -1), Vector2(-3, -8), Vector2(3, -9), Vector2(8, -3)]), stone, 1.0)


## ---- finding things ---------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	if _t < 0.5 or map == null or map.player == null or spots.is_empty():
		return
	_t = 0.0
	var pc := map.player.cell()
	var tm := int(GameState.run.get("time", 0))
	var twilight := absi(tm - GameState.sunrise()) < 90 or absi(tm - GameState.sunset()) < 90
	for s: Array in spots:
		var c: Vector2i = s[0]
		var dist := pc.distance_to(c)
		if dist <= 3.0 and not _sniffed:
			_sniffed = true
			if map.pet != null and is_instance_valid(map.pet) and map.pet.visible:
				map.hud.toast("Your pup sniffs at something nearby...", Color(0.9, 0.95, 1.0))
		if (twilight or dist <= 4.0) and randf() < 0.35:
			map.fx("sparkle" if Art.has("fx", "sparkle") else "poof", map.cell_center(c) + Vector2(randf_range(-5, 5), -8 - randf() * 6), 10.0, 0.6)


## Where you stand to open a pocket mouth (tests, hints).
func stand_of(mouth: Vector2i) -> Vector2i:
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if not map.blocked.has(mouth + d):
			return mouth + d
	return mouth


func found_spot(c: Vector2i) -> void:
	spots = spots.filter(func(s: Array) -> bool: return s[0] != c)


## Handles hidden_mouth / secret_way. Returns true if it was one.
static func interact(m: GameMap, c: Vector2i, thing: Dictionary) -> bool:
	var node := m.get_node_or_null("HiddenArea") as HiddenArea
	match str(thing.get("type", "")):
		"hidden_mouth":
			if str(thing.get("kind", "")) == "door":
				if str(thing.get("need", "")) != "" and not GameState.run["flags"].has(str(thing["need"])):
					m.tell([{"text": str(thing.get("shut", "Sealed."))}])
					return true
				Music.instance(m.get_tree()).sfx("crate_break", "thud")
				m.fx("poof", m.cell_center(c) + Vector2(0, -8), 16.0, 0.6)
			if str(thing.get("kind", "")) == "crack" and GameState.held_tool() != "pickaxe":
				return ToolHint.need(m, "pickaxe", "to break through")
			if str(thing.get("kind", "")) == "crack":
				if not GameState.spend_for("pickaxe"):
					m.hud.toast("Too tired.", Color(1, 0.7, 0.7))
					return true
				m.player.play_tool("pickaxe")
				Music.instance(m.get_tree()).sfx("crate_break", "thud")
				m.fx("stone_chips" if Art.has("fx", "stone_chips") else "poof", m.cell_center(c) + Vector2(0, -8), 16.0, 0.5)
			else:
				Music.instance(m.get_tree()).sfx("step_grass", "step")
				m.fx("leaf_burst" if Art.has("fx", "leaf_burst") else "poof", m.cell_center(c) + Vector2(0, -8), 14.0, 0.5)
			GameState.run["flags"][str(thing["key"])] = true
			m.things.erase(c)
			m.blocked.erase(c)
			m.hard.erase(c)
			if m.props.has(c):
				(m.props[c] as Node).queue_free()
				m.props.erase(c)
			m._flows.clear()
			if node:
				node.found_spot(c)
			m.hud.toast({"vine": "A hidden nook!", "door": "The sun door grinds open: the inner sanctum!"}.get(str(thing.get("kind", "")), "The wall gives way: a hidden nook!"), Color(1, 0.95, 0.6))
			Music.instance(m.get_tree()).sfx("j_secret", "j_treasure")
			return true
		"secret_way":
			var key := str(thing["key"])
			var first: bool = not GameState.run["flags"].has(key)
			GameState.run["flags"][key] = true
			var to := Vector2i(int(thing["to"][0]), int(thing["to"][1]))
			for k: Vector2i in m.things:
				if str(m.things[k].get("key", "")) == key:
					m.things[k]["hint"] = "A: take the hidden way"
					if m.props.has(k):
						(m.props[k] as CanvasItem).modulate.a = 1.0
					if node:
						node.found_spot(k)
			if first:
				m.hud.toast("A secret way!" + ("  Up you go." if str(thing.get("kind", "")) == "stairs" else "  It runs a long way."), Color(1, 0.95, 0.6))
				Music.instance(m.get_tree()).sfx("j_secret", "j_treasure")
			m.fx("poof", m.player.position + Vector2(0, -6), 12.0, 0.4)
			var dest := m.free_spot_near(m.cell_center(to))
			m.player.position = dest
			if m.pet != null and is_instance_valid(m.pet):
				m.pet.position = dest + Vector2(10, 0)
			m.fx("poof", dest + Vector2(0, -6), 12.0, 0.4)
			return true
	return false

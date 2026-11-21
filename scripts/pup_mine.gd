class_name PupMine
extends RefCounted
## The pup in the mines (Round 13). Mine floors are rebuilt on every entry and
## descent, so the pup is re-placed each time: at your heel when following, or
## by the lift when it was told to stay/guard in the mine (it keeps that
## command). While following it fights like anywhere else, and between fights it
## noses out finds from the floor's ore pool: it runs off, digs, and carries the
## find back to you (the item lands in your bag when it reaches you).

const FORAGE_EVERY := 22.0      # seconds of calm between dig runs
const FORAGE_REACH := 5         # cells from you it will wander to dig


static func active(m: GameMap) -> bool:
	return m != null and m.scene_id() == "mine"


## Run deferred from Mine.build(): put the pup on open floor for this layout.
static func settle(m: GameMap) -> void:
	if not is_instance_valid(m) or m.pet == null or not is_instance_valid(m.pet) or not (m.pet is Pet):
		return
	var pt := m.pet as Pet
	var st := Pet.state()
	var w: Array = st.get("wait", [])
	var waiting := w.size() >= 3 and str(w[0]) == "mine"
	var want: Vector2 = m.player.position + Vector2(-14, 0)
	var c := open_cell_near(m, feet_cell(m, want), feet_cell(m, m.player.position))
	pt.position = m.cell_center(c) + Vector2(0, -2)  # feet just inside the cell
	if waiting:
		# The cave it waited in has shifted: it waited by the lift instead.
		st["wait"] = ["mine", pt.position.x, pt.position.y]
		if not bool(m.get_meta("pup_told", false)):
			m.set_meta("pup_told", true)
			m.hud.toast("%s waited by the lift (%s)." % [Pet.name_of(), str(st.get("mode", "wait"))], Color(0.85, 1.0, 0.85))


## The cell under a feet position (cell_center() is a cell's bottom edge).
static func feet_cell(m: GameMap, p: Vector2) -> Vector2i:
	return m.world_to_cell(p - Vector2(0, 4))


## Nearest walkable, empty cell to `c` (never the player's own cell).
static func open_cell_near(m: GameMap, c: Vector2i, avoid: Vector2i) -> Vector2i:
	for r in 6:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := c + Vector2i(dx, dy)
				if q != avoid and m.in_content(q) and not m.blocked.has(q) and not m.things.has(q) and not m.is_water_cell(q):
					return q
	return avoid


## What the floor can give a digging pup: the tier's ores, mostly stone/coal.
static func dig_pool(m: GameMap) -> Array:
	var pool: Array = ["stone", "stone", "coal", "copper", "clay", "bone"]
	var tiers: Array = (GameState.tier_data.get("mine", {}).get("ores", []) as Array)
	var t := int(m.get("mine_tier")) if m.get("mine_tier") != null else 0
	if not tiers.is_empty():
		for o in tiers[mini(t, tiers.size() - 1)]:
			pool.append(str(o))
	if GameState.bonus("pup", "dig") >= 2:
		pool += ["shard", "fossil"]
	if GameState.bonus("pup", "dig_rare") > 0.0 and randf() < 0.25:
		pool = ["shard", "fossil", "old_coin", "amethyst", "ruby"]
	return pool.filter(func(id: String) -> bool: return GameState.items.has(id))


## Called from Pet._process every frame while following in the mine.
static func tick(pt: Pet, delta: float) -> void:
	if pt._carry_item == "" and pt._target == null:
		maybe_forage(pt, delta)
	elif pt._carry_item == "fetch" and pt._carry_find == "mine" and pt._target == null:
		# Rock in the way: after a few seconds it digs wherever it got to
		# (the clock stops while it fights: no digging with a foe on you).
		var t := float(pt.get_meta("forage_run", 0.0)) + delta
		pt.set_meta("forage_run", t)
		if t > 4.0:
			pt._carry_item = "digging"
			dig_find(pt)


static func maybe_forage(pt: Pet, delta: float) -> void:
	var m := pt.map
	var t := float(pt.get_meta("forage_t", 0.0)) + delta
	pt.set_meta("forage_t", t)
	if t < FORAGE_EVERY or m.nearest_enemy_to(m.player.position, 6.0 * GameMap.TILE) != null:
		return
	pt.set_meta("forage_t", randf_range(-6.0, 0.0))
	var pc := feet_cell(m, m.player.position)
	var best := Vector2i(-1, -1)
	for i in 12:
		var q := pc + Vector2i(randi_range(-FORAGE_REACH, FORAGE_REACH), randi_range(-FORAGE_REACH, FORAGE_REACH))
		if q.distance_to(pc) >= 2.0 and m.in_content(q) and not m.blocked.has(q) and not m.things.has(q) and not m.is_water_cell(q) and m.line_clear(m.player.position, m.cell_center(q)):
			best = q
			break
	if best == Vector2i(-1, -1):
		return
	pt._carry_from = m.cell_center(best) + Vector2(0, -2)
	pt._carry_item = "fetch"
	pt._carry_find = "mine"
	pt.set_meta("forage_run", 0.0)
	m.emote(pt, "surprise", 0.6)
	Music.instance(pt.get_tree()).sfx("bark")


## Reached the spot: dig for a moment, then carry the find back.
static func dig_find(pt: Pet) -> void:
	pt.busy = true
	pt.anim.play("dig" if pt.anim.sprite_frames.has_animation("dig") else "play")
	pt.map.fx("dust_puff", pt.position, 12.0, 0.4)
	Music.instance(pt.get_tree()).sfx("dig", "thud")
	await pt.get_tree().create_timer(1.1, false).timeout
	if not is_instance_valid(pt) or not pt.is_inside_tree():
		return
	pt.busy = false
	var pool := dig_pool(pt.map)
	pt._carry_find = str(pool[randi() % pool.size()]) if not pool.is_empty() else ""
	pt._carry_item = "bring" if pt._carry_find != "" else ""
	if pt.anim.sprite_frames.has_animation("fetch"):
		pt.anim.play("fetch")


## Back at your feet with the find.
static func deliver(pt: Pet) -> void:
	var id := pt._carry_find
	pt._carry_find = ""
	if id == "" or id == "mine":
		return
	var n := 2 if id in ["stone", "coal"] and randf() < 0.5 else 1
	pt.map.pop_items(pt.position, id, n)
	GameState.add_xp("pup", 3)
	Music.instance(pt.get_tree()).sfx("pickup")
	pt.map.hud.toast("%s brings you %s." % [Pet.name_of(), ItemWords.count_id(id, n) if n > 1 else ItemWords.with_article(GameState.item_name(id))], Color(0.8, 1, 0.8))

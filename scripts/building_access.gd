class_name BuildingAccess
## Every building you can't go into says why (round 13). For each building sprite
## on a map (GameMap._bprops: prop()/building() in "buildings", region building
## props, animated region buildings) with no way in near its front, a "locked"
## thing goes on the door cell (or the middle of the front wall when the door
## cell is taken) with a short reason, and every wall cell of the building points
## at it (GameMap._building_doors), so pressing USE anywhere along the front
## answers. tools/door_check.gd checks it on every map.

## Open structures that are not buildings you go into.
const SKIP := ["well", "bandstand", "gazebo", "mailbox", "sellbox", "fountain", "statue", "kiosk", "booth", "fence", "sign",
	"great_tree", "galleon", "crane", "dome", "windmill", "silo", "grain_elevator", "moon_spire", "tower_top"]
## Things that already are a way in (or a reason) when found by the front.
const ENTRY := ["door", "idoor", "shop", "hall", "hut", "exit", "station", "ferry", "counter", "wreck", "project", "locked",
	"house", "cave", "pad", "camp", "boss", "note"]
## First match wins: the more specific words come first. [words, reason, penguin-arc reason]
const REASONS := [
	[["noodle", "ramen", "karaoke", "arcade", "dragon", "neon_bar"], "Closed: shutters down till the district wakes up. A sign says 'back after dark, maybe'."],
	[["shop", "store", "stall", "market", "cafe", "diner", "bar", "bakery", "hotel"], "Closed: a card in the window says the keeper has moved away. The shutters are staying down."],
	[["bank"], "Locked: the vault door is shut and the teller's window is dark."],
	[["warehouse", "factory", "garage", "depot", "container", "office", "hq_"], "Locked: another crew stores its goods here, chained and guarded. Not your block, and not a fight worth picking.", "Locked: Hazel's feed store. She keeps the only key; hay and feed are sold at Maple's."],
	[["clock"], "Locked: the clock works, and Theo has the only key. He's very particular about it."],
	[["lighthouse_rust"], "Locked: the old harbour light. The door's rusted shut and the lamp's been dead for years."],
	[["tower", "lighthouse", "temple", "shrine", "ruin", "president"], "Locked: the door is barred from the inside. Nobody's gone in for years."],
	[["barn", "coop", "shed", "mill", "greenhouse", "stable", "winch"], "Locked: empty and padlocked. Nobody keeps anything in there any more."],
	[["mansion", "penthouse"], "Private home: a doorman's note says 'by appointment only'."],
	[["house", "cottage", "home", "hut", "cabin", "manor", "villa"], "Private home: nobody answers. Folks round here keep their doors shut to strangers."],
]


static func reason_for(nm: String) -> String:
	for rr in REASONS:
		for kw: String in rr[0]:
			if nm.contains(kw):
				return str(rr[2]) if rr.size() > 2 and GameState.is_penguins() else str(rr[1])
	return "Locked: it doesn't look like anyone's using it."


## [x0, base_y, w_cells, rows_up] of a _bprops entry, as drawn.
static func footprint(bp: Array) -> Array:
	var base: Vector2i = bp[1]
	var extra := int(bp[2])
	var w := extra + 1
	var rows_up := 2
	var node: Variant = bp[3] if bp.size() > 3 else null
	if node is Node2D and is_instance_valid(node):
		var sz := Vector2.ZERO
		if node is Sprite2D and (node as Sprite2D).texture:
			sz = (node as Sprite2D).texture.get_size() * (node as Sprite2D).scale
		elif node is AnimatedSprite2D and (node as AnimatedSprite2D).sprite_frames:
			var a := node as AnimatedSprite2D
			var t := a.sprite_frames.get_frame_texture(a.animation, 0)
			if t:
				sz = t.get_size() * a.scale
		if sz != Vector2.ZERO:
			w = maxi(w, int(round(sz.x / GameMap.TILE)))
			rows_up = clampi(int(round(sz.y / GameMap.TILE)) - 1, 1, 6)
	var x0 := base.x + (extra + 1) / 2 - w / 2
	return [x0, base.y, w, rows_up]


static func apply(m: GameMap) -> void:
	if m.scene_id() in ["farm", "house", "interior"]:
		return
	for bp: Array in m._bprops:
		var nm := str(bp[0])
		if SKIP.any(func(k: String) -> bool: return nm.contains(k)):
			continue
		var fp := footprint(bp)
		var x0: int = fp[0]
		var by: int = fp[1]
		var w: int = fp[2]
		var rows_up: int = fp[3]
		var door := Vector2i(x0 + w / 2, by + 1)
		if not m.in_content(door) and not m.in_content(door - Vector2i(0, 1)):
			continue
		# Already a way in (or a reason) along the front or just inside it?
		var entry := Vector2i(-1, -1)
		for dy in [1, 0, 2, -1]:
			for dx in range(0, w):
				var c := Vector2i(x0 + dx, by + dy)
				if str(m.things.get(c, {}).get("type", "")) in ENTRY:
					entry = c
					break
			if entry != Vector2i(-1, -1):
				break
		if entry == Vector2i(-1, -1):
			var at := door
			if m.things.has(at) or m.blocked.has(at) or not m.in_content(at):
				at = Vector2i(x0 + w / 2, by)  # the middle of the front wall
				if m.things.has(at):
					continue  # something of its own already answers there
			m.set_thing(at.x, at.y, {"type": "locked", "text": reason_for(nm), "hint": "A: knock"}, m.blocked.has(at))
			entry = at
		# Every wall cell of the building answers with its door or reason.
		for y in range(by - rows_up + 1, by + 1):
			for x in range(x0, x0 + w):
				var c := Vector2i(x, y)
				if c != entry and m.blocked.has(c) and not m.things.has(c) and not m._building_doors.has(c):
					m._building_doors[c] = entry

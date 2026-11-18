class_name Storage
extends RefCounted
## Chests, Sun Haven style. Every chest has its own slots:
##   run["chests"][key] = {"items": {id: n}, "q": {id: {"g","s"}}, "cap": slots}
## Keys: "chest" / "shed" (farm builds), "p:x,y" (a placed chest on the farm).
## One slot holds a stack of up to STACK of one item.

const STACK := 999
const CAPS := {"chest": 36, "shed": 72}
const PLACED_CAP := 24


static func _all() -> Dictionary:
	var r: Dictionary = GameState.run
	if not r.has("chests"):
		r["chests"] = {}
		# The old one-click stash moves into the farm chest.
		var old: Dictionary = (r.get("flags", {}) as Dictionary).get("chest", {})
		if not old.is_empty():
			box("chest")["items"] = old.duplicate()
			(r["flags"] as Dictionary).erase("chest")
	return r["chests"]


static func box(key: String) -> Dictionary:
	var a: Dictionary = GameState.run.get("chests", {}) if GameState.run.has("chests") else _all()
	if not a.has(key):
		a[key] = {"items": {}, "q": {}, "cap": int(CAPS.get(key, PLACED_CAP))}
	return a[key]


static func cap(key: String) -> int:
	return int(box(key).get("cap", PLACED_CAP))


static func slots_used(key: String) -> int:
	var t := 0
	for id in box(key)["items"]:
		t += int(ceil(float(box(key)["items"][id]) / STACK))
	return t


static func is_empty(key: String) -> bool:
	return (box(key)["items"] as Dictionary).is_empty()


static func amount(key: String, id: String) -> int:
	return int(box(key)["items"].get(id, 0))


## How many of id the chest can still take.
static func room_for(key: String, id: String) -> int:
	var have := amount(key, id)
	var part := (STACK - have % STACK) % STACK if have > 0 else 0
	return part + maxi(0, cap(key) - slots_used(key)) * STACK


## Bag → chest. Returns how many moved. Tools never go in.
static func deposit(key: String, id: String, n: int) -> int:
	if GameState.has_tool(id) and not GameState.run["inventory"].has(id):
		return 0
	n = mini(n, mini(GameState.count(id), room_for(key, id)))
	if n <= 0:
		return 0
	var b := box(key)
	# Gold/silver quality travels with the stack (best first).
	var q := GameState.quality_of(id).duplicate()
	var moved_q := {}
	var left := n
	for g in ["g", "s"]:
		var k := mini(left, int(q.get(g, 0)))
		if k > 0:
			moved_q[g] = k
			left -= k
	b["items"][id] = amount(key, id) + n
	if not moved_q.is_empty():
		var bq: Dictionary = b["q"].get(id, {})
		for g in moved_q:
			bq[g] = int(bq.get(g, 0)) + int(moved_q[g])
			GameState.add_quality(id, g, -int(moved_q[g]))
		b["q"][id] = bq
	GameState.add_item(id, -n)
	return n


## Chest → bag. Returns how many moved (stops when the bag is full).
static func withdraw(key: String, id: String, n: int) -> int:
	n = mini(n, amount(key, id))
	if n <= 0:
		return 0
	if not GameState.run["inventory"].has(id) and GameState.bag_free() <= 0:
		return 0
	var b := box(key)
	b["items"][id] = amount(key, id) - n
	GameState.add_item(id, n, true)
	var bq: Dictionary = b["q"].get(id, {})
	var left := n
	for g in ["g", "s"]:
		var k := mini(left, int(bq.get(g, 0)))
		if k > 0:
			bq[g] = int(bq[g]) - k
			left -= k
			GameState.add_quality(id, g, k)
	if int(b["items"][id]) <= 0:
		b["items"].erase(id)
		b["q"].erase(id)
	return n


static func _keep(id: String) -> bool:
	# Deposit All leaves these in the bag: tools, seeds, food you carry, and whatever's on the toolbar.
	var t := str(GameState.items.get(id, {}).get("type", ""))
	return GameState.has_tool(id) or t in ["tool", "key", "quest"] or (GameState.run["toolbar"] as Array).has(id)


static func deposit_all(key: String) -> int:
	var moved := 0
	for id: String in GameState.run["inventory"].keys():
		if not _keep(id) and deposit(key, id, GameState.count(id)) > 0:
			moved += 1
	return moved


## Quick stack: everything in the bag that this chest already holds goes in.
static func quick_stack(key: String) -> int:
	var moved := 0
	for id: String in GameState.run["inventory"].keys():
		if box(key)["items"].has(id) and not _keep(id) and deposit(key, id, GameState.count(id)) > 0:
			moved += 1
	return moved


static func take_all(key: String) -> int:
	var moved := 0
	for id: String in (box(key)["items"] as Dictionary).keys():
		if withdraw(key, id, amount(key, id)) > 0:
			moved += 1
	return moved


static func sort_box(key: String) -> void:
	var b := box(key)
	var ids: Array = (b["items"] as Dictionary).keys()
	ids.sort_custom(GameState.item_order)
	var d := {}
	for id in ids:
		d[id] = b["items"][id]
	b["items"] = d


## Chests near the player on this map (farm builds and placed chests), nearest first.
static func nearby(m: GameMap, radius := 10.0) -> Array:
	var out: Array = []
	if m == null or m.player == null:
		return out
	var pc := m.player.cell()
	for c: Vector2i in m.things:
		var t: Dictionary = m.things[c]
		var k := key_of(t, c)
		if k != "" and Vector2(c - pc).length() <= radius:
			out.append([Vector2(c - pc).length(), k])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return out.map(func(a: Array) -> String: return str(a[1]))


static func key_of(t: Dictionary, c: Vector2i) -> String:
	var ty := str(t.get("type", ""))
	if ty == "chest" and t.has("build"):
		return str(t["build"])
	if ty == "placed" and str(t.get("kind", "")) == "chest":
		return "p:%d,%d" % [c.x, c.y]
	return ""


## Quick stack into every chest in reach. Returns [stacks moved, chests used].
static func quick_stack_nearby(m: GameMap) -> Array:
	var moved := 0
	var used := 0
	for k: String in nearby(m):
		var n := quick_stack(k)
		moved += n
		used += 1 if n > 0 else 0
	return [moved, used]

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
	return int(box(key).get("cap", CAPS.get(key, PLACED_CAP)))


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
	# Keys and quest items stay in the bag: doors and quests only look there.
	if str(GameState.items.get(id, {}).get("type", "")) in ["key", "quest"]:
		return 0
	# Decor and wearables never go in a chest: Rec decor shows in the house only while
	# you hold it, and catalogue decor lives in the decor box (C10a, c10_02/c10_13).
	if is_decor_item(id):
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


## Decor/wear (items type decor/wear or a catalogue id): kept out of chests and Deposit All.
static func is_decor_item(id: String) -> bool:
	return str(GameState.items.get(id, {}).get("type", "")) in ["decor", "wear"] or Decor.is_decor(id)


static func _keep(id: String) -> bool:
	# Deposit All leaves these in the bag: tools, keys, locked items, the selected item and
	# usable things on the toolbar (seeds, food, potions...). Materials that merely landed on
	# the bar when first picked up still go in.
	var t := str(GameState.items.get(id, {}).get("type", ""))
	var usable := t in ["seed", "food", "tonic", "potion", "consumable", "placeable", "magic", "equip", "petgear"]
	if is_decor_item(id):
		return true
	return GameState.has_tool(id) or t in ["tool", "key", "quest", "vehicle"] or ((GameState.run["toolbar"] as Array).has(id) and usable) \
		or id == str(GameState.run.get("selected", "")) or GameState.is_locked(id)


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
	b["slots"] = Slots.sorted(slots(key), {}, GameState.item_order)


## The chest's slot layout (one entry per stack of up to STACK).
static func slots(key: String) -> Array:
	var b := box(key)
	if not (b.get("slots") is Array):
		b["slots"] = (b["items"] as Dictionary).keys()
	return Slots.reconcile(b["slots"], b["items"], cap(key), STACK)


static func move_slot(key: String, from: int, to: int) -> void:
	Slots.move(slots(key), from, to)


## Chests near the player on this map (farm builds and placed chests), nearest first.
static func nearby(m: GameMap, radius := 10.0) -> Array:
	var out: Array = []
	if m == null or m.player == null or GameState.visiting():
		return out  # the host's chests aren't ours
	var pc := m.player.cell()
	for c: Vector2i in m.things:
		var t: Dictionary = m.things[c]
		var k := key_of(t, c, m.scene_id())
		if k != "" and Vector2(c - pc).length() <= radius:
			out.append([Vector2(c - pc).length(), k])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return out.map(func(a: Array) -> String: return str(a[1]))


## A chest's storage key. Placed chests carry their map off the farm ("p:<scene>:x,y"),
## so an indoor chest never shares contents with the farm cell of the same number.
static func key_of(t: Dictionary, c: Vector2i, scene := "farm") -> String:
	var ty := str(t.get("type", ""))
	if ty == "chest" and t.has("build"):
		return str(t["build"])
	if ty == "placed" and str(t.get("kind", "")) == "chest":
		return "p:%d,%d" % [c.x, c.y] if scene in ["", "farm"] else "p:%s:%d,%d" % [scene, c.x, c.y]
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


## How many of id sit in all your chests.
static func total(id: String) -> int:
	if not GameState.run.has("chests"):
		return 0
	var t := 0
	for k in GameState.run["chests"]:
		t += int((GameState.run["chests"][k] as Dictionary).get("items", {}).get(id, 0))
	return t


## Use n of id straight out of the chests (for builds): removed, not moved to the bag.
static func take_from_chests(id: String, n: int) -> int:
	if not GameState.run.has("chests"):
		return 0
	var took := 0
	for k in GameState.run["chests"]:
		if took >= n:
			break
		var b: Dictionary = GameState.run["chests"][k]
		var have := int(b.get("items", {}).get(id, 0))
		var k2 := mini(have, n - took)
		if k2 > 0:
			b["items"][id] = have - k2
			if int(b["items"][id]) <= 0:
				b["items"].erase(id)
				(b.get("q", {}) as Dictionary).erase(id)
			else:
				# Plain ones are used first; stars never outnumber what's left.
				var bq: Dictionary = (b.get("q", {}) as Dictionary).get(id, {})
				var over := int(bq.get("g", 0)) + int(bq.get("s", 0)) - int(b["items"][id])
				if over > 0:
					var cs := mini(over, int(bq.get("s", 0)))
					bq["s"] = int(bq.get("s", 0)) - cs
					bq["g"] = maxi(0, int(bq.get("g", 0)) - (over - cs))
			took += k2
	return took


## C11b P3 (c11b_06-06): a placed chest's friendly name: the player's own name (box.name), else
## "Chest N (by the barn)" from the nearest Plans building, or "(in the house)" for indoor chests.
static func label(key: String) -> String:
	if key == "chest":
		return "farm chest"
	if key == "shed":
		return "shed"
	var own := str(box(key).get("name", "")) if GameState.run.get("chests", {}).has(key) else ""
	if own != "":
		return own
	if not key.begins_with("p:"):
		return key
	var placed: Array = []
	for k in GameState.run.get("chests", {}):
		if str(k).begins_with("p:"):
			placed.append(str(k))
	if not key in placed:
		placed.append(key)
	placed.sort_custom(_placed_order)
	var n := placed.find(key) + 1
	return "Chest %d (%s)" % [n, _where(key)]


static func _placed_order(a: String, b: String) -> bool:
	var ia := a.count(":") > 1
	var ib := b.count(":") > 1
	if ia != ib:
		return not ia  # farm chests first
	return a < b


static func rename(key: String, nm: String) -> void:
	box(key)["name"] = nm.strip_edges().left(16)


static func _where(key: String) -> String:
	var rest := key.substr(2)
	var parts := rest.split(":")
	if parts.size() > 1:
		var sc := parts[0]
		return "in the house" if sc in ["house", "interior", "cellar"] or sc.begins_with("house") else "in the " + sc.replace("_", " ")
	var xy := rest.split(",")
	if xy.size() != 2:
		return "on the farm"
	var c := Vector2(float(xy[0]), float(xy[1]))
	var best := ""
	var bd := 1e9
	for bid in Builds.all():
		var b: Variant = Builds.all()[bid]
		if not (b is Dictionary) or not (b as Dictionary).has("cell") or str(bid) == "_":
			continue
		if bid != "house" and not Builds.is_built(str(bid)):
			continue
		var bc: Array = (b as Dictionary)["cell"]
		var mid := Vector2(float(bc[0]) + float((b as Dictionary).get("w", 1)) / 2.0, float(bc[1]) + float((b as Dictionary).get("h", 1)) / 2.0)
		var d := mid.distance_to(c)
		if d < bd:
			bd = d
			var t := Builds.current_def(str(bid))
			best = str(t.get("name", (b as Dictionary).get("label", bid))) if bid != "house" else "house"
	if best == "" or bd > 14.0:
		return "on the farm"
	return "by the " + best.to_lower()

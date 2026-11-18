class_name Slots
extends RefCounted
## Sun Haven-style slot layout on top of an {id: count} dictionary. The dict is
## the only record of HOW MANY; a slot array only says WHERE each item shows.
## Arrays repair themselves on every read, so nothing can fall out of step.


## Fix `order` in place: every id that still needs a slot keeps its place, new
## ids take the first empty slot, gone ids leave a hole; padded/trimmed to size.
## stack 0 = one slot per id (the bag); otherwise ceil(n / stack) slots (chests).
static func reconcile(order: Array, items: Dictionary, size: int, stack: int) -> Array:
	var need := {}
	for id in items:
		var n := int(items[id])
		if n > 0:
			need[str(id)] = 1 if stack <= 0 else int(ceil(float(n) / stack))
	for i in order.size():
		var id := str(order[i])
		if id != "" and int(need.get(id, 0)) > 0:
			need[id] = int(need[id]) - 1
		else:
			order[i] = ""
	for id in need:
		for k in int(need[id]):
			var free := order.find("")
			if free >= 0:
				order[free] = id
			else:
				order.append(id)
	while order.size() < size:
		order.append("")
	while order.size() > size and str(order[order.size() - 1]) == "":
		order.pop_back()
	return order


static func move(order: Array, from: int, to: int) -> void:
	if from < 0 or to < 0 or from >= order.size() or to >= order.size() or from == to:
		return
	var t: Variant = order[to]
	order[to] = order[from]
	order[from] = t


## Locked ids keep their index; the rest are sorted by cmp into the free indices.
static func sorted(order: Array, locked: Dictionary, cmp: Callable) -> Array:
	var free_idx: Array = []
	var ids: Array = []
	for i in order.size():
		var id := str(order[i])
		if id != "" and locked.has(id):
			continue
		free_idx.append(i)
		if id != "":
			ids.append(id)
	ids.sort_custom(cmp)
	for k in free_idx.size():
		order[free_idx[k]] = ids[k] if k < ids.size() else ""
	return order

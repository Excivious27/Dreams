extends SceneTree
## Bag and chests: capacity, overflow to the farm chest, deposit/withdraw with
## quality, quick stack, sort, backpack upgrades.
##   godot --headless --path . -s res://tools/storage_test.gd
var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	var start := GameState.bag_used()
	check(GameState.bag_size() == GameState.BAG_BASE, "base bag size")
	GameState.add_item("turnip", 5)
	GameState.add_quality("turnip", "g", 2)
	Storage.deposit("chest", "turnip", 5)
	check(GameState.count("turnip") == 0 and Storage.amount("chest", "turnip") == 5, "deposit moves the stack")
	check(int(Storage.box("chest")["q"]["turnip"]["g"]) == 2, "gold quality travels into the chest")
	Storage.withdraw("chest", "turnip", 5)
	check(GameState.count("turnip") == 5 and int(GameState.quality_of("turnip").get("g", 0)) == 2, "withdraw restores count and quality")
	Storage.deposit("chest", "turnip", 3)
	GameState.add_item("stone", 7)
	Storage.deposit("chest", "stone", 1)
	# Quick stack leaves the toolbar alone (like Sun Haven's action bar): take them off it.
	var tb: Array = GameState.run["toolbar"]
	for i in tb.size():
		if str(tb[i]) in ["turnip", "stone"]:
			tb[i] = ""
	var n := Storage.quick_stack("chest")
	check(n == 2 and GameState.count("turnip") == 0 and GameState.count("stone") == 0, "quick stack moves matching items (%d)" % n)
	# Old stash first: before the chest is built, a full bag still keeps new items.
	var ids0: Array = []
	for id in GameState.items:
		if GameState.bag_free() <= 0:
			break
		var t0 := str(GameState.items[id].get("type", ""))
		if t0 in ["tool", "key", "quest", "upgrade"] or GameState.run["inventory"].has(id) or id == "copper" or id == "silver":
			continue
		GameState.add_item(id, 1)
		ids0.append(id)
	GameState.add_item("silver", 1)
	check(GameState.count("silver") == 1, "no chest built: a full bag keeps the new item")
	GameState.add_item("silver", -1)
	for id in ids0:
		GameState.add_item(id, -1)
	# Fill the bag; the next new item goes to the chest (once the chest is built).
	if not GameState.run.has("builds") or not (GameState.run["builds"] is Dictionary):
		GameState.run["builds"] = {}
	GameState.run["builds"]["chest"] = 1
	var ids: Array = []
	for id in GameState.items:
		if GameState.bag_free() <= 0:
			break
		var t := str(GameState.items[id].get("type", ""))
		if t in ["tool", "key", "quest", "upgrade"] or GameState.run["inventory"].has(id) or id == "copper":
			continue
		GameState.add_item(id, 1)
		ids.append(id)
	check(GameState.bag_free() == 0, "bag filled")
	GameState.add_item("copper", 3)
	check(GameState.count("copper") == 0 and Storage.amount("chest", "copper") == 3, "full bag sends new items to the farm chest")
	check(Storage.withdraw("chest", "copper", 3) == 0, "can't withdraw a new kind into a full bag")
	GameState.run["bag_up"] = 1
	check(GameState.bag_size() == GameState.BAG_BASE + GameState.BAG_STEP, "backpack upgrade adds slots")
	check(Storage.withdraw("chest", "copper", 3) == 3, "withdraw after upgrade")
	GameState.sort_bag()
	var keys: Array = GameState.run["inventory"].keys()
	var sorted_ok := true
	for i in range(1, keys.size()):
		if GameState.item_order(str(keys[i]), str(keys[i - 1])):
			sorted_ok = false
	check(sorted_ok, "bag sorted")
	# Old stash migrates.
	GameState.run.erase("chests")
	GameState.run["flags"]["chest"] = {"wood": 9}
	check(Storage.amount("chest", "wood") == 9, "old stash migrates into the farm chest")
	print("storage_test: %d failures" % fails)
	quit()

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
	# Slot layer (Sun Haven bag): positions stick, holes stay, sort keeps locks.
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	var bs := GameState.bag_slots()
	check(bs.size() == GameState.bag_size(), "bag slots padded to bag size")
	GameState.add_item("clay", 2)
	var ci := GameState.bag_slots().find("clay")
	check(ci >= 0, "new kind takes a slot")
	var last := GameState.bag_size() - 1
	GameState.bag_move(ci, last)
	check(GameState.bag_slots()[last] == "clay" and GameState.bag_slots()[ci] == "", "move into an empty slot leaves a hole")
	GameState.add_item("clay", 3)
	check(GameState.bag_slots().find("clay") == last, "more of a kind keeps its slot")
	GameState.add_item("clay", -5)
	check(GameState.bag_slots().find("clay") == -1 and GameState.bag_slots()[last] == "", "used-up kind leaves a hole")
	GameState.add_item("wood", 4)
	GameState.add_item("stone", 4)
	GameState.toggle_lock("wood")
	var wi := GameState.bag_slots().find("wood")
	GameState.sort_bag()
	check(GameState.bag_slots().find("wood") == wi, "locked kind keeps its slot through Sort")
	check(GameState.trash("wood", 4) == 0, "locked kind can't be trashed")
	GameState.toggle_lock("wood")
	check(GameState.trash("wood", 4) == 4 and GameState.count("wood") == 0, "trash removes it")
	check(GameState.trash("hoe", 1) == 0, "tools can't be trashed")
	GameState.run["builds"] = {"chest": 1}
	Storage.box("chest")["items"]["stone"] = 1500
	check(Storage.slots("chest").count("stone") == 2, "1500 stone takes two chest stacks")
	var j: Variant = JSON.parse_string(JSON.stringify(GameState.run, "", false))
	check(j is Dictionary and (j["bag_slots"] as Array).size() == GameState.bag_slots().size(), "slots survive a save round trip")
	# A build that uses chest items never leaves more stars than items.
	Storage.box("chest")["items"]["turnip"] = 10
	Storage.box("chest")["q"]["turnip"] = {"g": 10}
	Storage.take_from_chests("turnip", 8)
	check(int(Storage.box("chest")["q"]["turnip"].get("g", 0)) <= 2, "take_from_chests trims stars")
	# Keys and quest items stay in the bag.
	var kid := ""
	for iid: String in GameState.items:
		if str(GameState.items[iid].get("type", "")) == "key":
			kid = iid
			break
	if kid != "":
		GameState.add_item(kid, 1)
		check(Storage.deposit("chest", kid, 1) == 0 and GameState.count(kid) == 1, "keys never go into a chest")
	# A lock survives a chest round trip.
	GameState.add_item("potato", 3)
	GameState.toggle_lock("potato")
	Storage.deposit("chest", "potato", 3)
	Storage.withdraw("chest", "potato", 3)
	check(GameState.is_locked("potato"), "lock kept through deposit + withdraw")
	# Locked items are skipped by family takes.
	check(GameState.count_any("#" + GameState.family("potato")) < GameState.count("potato") or GameState.family("potato") == "", "family count skips locked")
	GameState.toggle_lock("potato")
	# Old saves: the renamed Killing Edge moves to Keen Edge.
	GameState.run["skills"]["combat"]["nodes"] = {"combat_u_killing_edge": 1}
	GameState._migrate()
	check(GameState.node_rank("combat", "combat_u_keen_edge") == 1, "Killing Edge migrates to Keen Edge")
	# A positional id that now holds a different node is refunded.
	GameState.run["skills"]["combat"]["nodes"] = {"combat_2_7": 1}
	GameState.run["skills"]["combat"]["nm"] = {"combat_2_7": "Something Else"}
	GameState._migrate()
	check(GameState.node_rank("combat", "combat_2_7") == 0, "renamed positional node is refunded")
	# Old Iron Gut (positional combat_2_8) moves to the Iron Gut unlock.
	GameState.run["skills"]["combat"]["nm"] = {}
	GameState.run["skills"]["combat"]["nodes"] = {"combat_2_8": 1}
	GameState._migrate()
	check(GameState.node_rank("combat", "combat_u_iron_gut") == 1, "Iron Gut migrates to its unlock")
	check(GameState.has_perk("combat", "Iron Gut"), "Iron Gut found by name")
	check(GameState.bonus("combat", "status_guard") > 0, "Iron Gut guards against poison")
	# Under another old name it is refunded, not moved.
	GameState.run["skills"]["combat"]["nodes"] = {"combat_2_8": 1}
	GameState.run["skills"]["combat"]["nm"] = {"combat_2_8": "Toughness"}
	GameState._migrate()
	check(GameState.node_rank("combat", "combat_u_iron_gut") == 0, "other combat_2_8 is refunded")
	# SKILL_VER: an old save's filler ranks are refunded once; a current one keeps them.
	var fid := "combat_2_7"
	GameState.run["skills"]["combat"]["nm"] = {fid: str(GameState.node("combat", fid).get("name", ""))}
	GameState.run["skills"]["combat"]["nodes"] = {fid: 1}
	GameState.run["skill_ver"] = GameState.SKILL_VER
	GameState._migrate()
	check(GameState.node_rank("combat", fid) == 1, "filler rank kept at current SKILL_VER")
	GameState.run["skill_ver"] = 0
	GameState._migrate()
	check(GameState.node_rank("combat", fid) == 0, "filler rank refunded for an old SKILL_VER")
	check(int(GameState.run.get("skill_ver", 0)) == GameState.SKILL_VER, "skill_ver stamped after the refund")
	GameState.run["skills"]["combat"]["nm"] = {}
	GameState.run["skills"]["combat"]["nodes"] = {}
	# A fresh run that ships something before any sale to Sal must still turn the day (audit c7/13).
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run.erase("sold_today")  # an old save without the key
	GameState.run["sellbox"] = {"turnip": 2}
	var d0 := int(GameState.run["day"])
	var rep := GameState.sleep()
	check(int(GameState.run["day"]) == d0 + 1 and int(rep.get("earned", 0)) > 0, "sell box pays and the day turns on a fresh run")
	# Food past the daily energy cap is kept, not eaten for nothing.
	GameState.run["fed_en"] = int(GameState.run["max_energy"])
	GameState.add_item("bread", 1)
	var fx := GameState.consume("bread")
	check(fx.has("full") and GameState.count("bread") == 1, "full: bread stays in the bag")
	check(GameState.extra_energy(20) == 0, "rest energy respects the daily cap")
	print("storage_test: %d failures" % fails)
	quit()

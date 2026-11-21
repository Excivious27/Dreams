extends SceneTree
## C16a P2: the 3-year multi-style simulator (replaces the C8 farm-only economy bot).
## Plays N days headlessly on the GameState API (no scenes, game time only, seeded) for one
## player style and arc, and writes one CSV row per day plus an unlock-stamp CSV.
##
##   godot --headless --path . -s res://tools/sim.gd -- --years 3 --style farmer|explorer|social|hustler \
##       --arc penguins|gangsters [--day-len 15|20|30|40] [--days N] [--seed n] --out /tmp/x.csv
##
## Styles: farmer (crops all day), explorer (mine floors, then fishing with what is left),
## social (small field, talk + gifts every day, decor spending), hustler (gangster arc: small field +
## the racket's daily bills from the Hideout chapter). Every style runs the same story driver (quests
## complete a few days after their `when` holds, delay per style) and the same build-sink policy
## (next building tier or permit bought when the purse holds 1.3x its price, in a per-style order).
## Rules come from the game, not copies: Farm.harvest_count / quality_odds / harvest_xp, GameState
## spend_for / energy_cost_f / hits_for / sleep (real sales, interest, overnight), Fishing.pick / xp_for,
## Racket.risk / pass_cap, Builds gates and prices. Time budget = day_len*60 / SECONDS_PER_ACTION minus
## a walk overhead per area visited, so the four day lengths differ (c16a_16-04).
## Known simplifications (reported in the workbook's Notes tab): no skill-tree node buys, no tool
## upgrades, no food eaten, ranch/crafting/casino not modelled, racket notes cost nothing to make.

const FarmS = preload("res://scripts/farm.gd")
const SECONDS_PER_ACTION := 6.0
const TRIP_ACTIONS := 15          # walking to another area and back
const REFILL_ACTIONS := 12        # walk to water and back with an empty can
const CAST_ACTIONS := 1.6         # one cast: bite wait + reel, ~10 s
const ROCKS_PER_FLOOR := 4        # rocks broken on the way (the ladder is fixed: mine.gd _farthest_open)
const WALK_PER_FLOOR := 6.0       # ~36 s walking entry -> ladder round the walls and hazards
const SWING_ACTIONS := 0.15       # one pickaxe/sword swing ~0.9 s (actions are 6 s)
const FIELD_CAP := {"farmer": 600, "explorer": 0, "social": 40, "hustler": 40}
## Days after a quest's `when` holds until the style finishes it: [main, side].
const QUEST_DELAY := {"farmer": [6, 3], "explorer": [2, 5], "social": [8, 1], "hustler": [3, 4]}
## Chapter quests (progress_tier) need real effort: earliest day per style.
const CHAPTER_DAY := {
	"farmer": {"clear_meadow": 6, "spark": 40, "wastes_gate": 40, "docks": 40, "sky_stair": 110, "neon": 110, "teleporter": 230, "uptown": 230},
	"explorer": {"clear_meadow": 3, "spark": 20, "wastes_gate": 20, "docks": 20, "sky_stair": 60, "neon": 60, "teleporter": 140, "uptown": 140},
	"social": {"clear_meadow": 7, "spark": 35, "wastes_gate": 35, "docks": 35, "sky_stair": 100, "neon": 100, "teleporter": 210, "uptown": 210},
	"hustler": {"clear_meadow": 5, "spark": 28, "wastes_gate": 28, "docks": 28, "sky_stair": 84, "neon": 84, "teleporter": 180, "uptown": 180},
}
const BUILD_ORDER := {
	"farmer": ["silo", "coop", "barn", "house", "greenhouse", "shed"],
	"explorer": ["house", "anvil", "armory", "shed", "silo", "coop"],
	"social": ["house", "coop", "shed", "silo", "barn"],
	"hustler": ["house", "shed", "silo", "coop", "barn"],
}
const SKILLS := ["farming", "fishing", "mining", "combat", "foraging", "building"]
const SKILL_MARKS := [10, 25, 50, 75, 100]

var days := 336
var arc := "penguins"
var style := "farmer"
var day_len := 15
var out_path := "/tmp/sim.csv"
var seed_n := 16
var rng := RandomNumberGenerator.new()
var avail := {}        # quest id -> first day its `when` held
var stamps := {}       # unlock key -> day
var deepest := 0
var spent := {}        # sink -> total
var made := {}         # category -> value shipped today (split of "sales")
var quests_all: Array = []
var quest_flags: Dictionary = {}  # flags a quest reward sets (modelled: a gate on one waits for that quest)


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		var k := str(a[i])
		var v := str(a[i + 1]) if i + 1 < a.size() else ""
		match k:
			"--years": days = int(v) * 112
			"--days": days = int(v)
			"--style": style = v
			"--arc": arc = v
			"--day-len": day_len = int(v)
			"--out": out_path = v
			"--seed": seed_n = int(v)
		i += 2
	if style == "hustler":
		arc = "gangsters"
	seed(seed_n)
	rng.seed = seed_n
	GameState.new_run(arc, "penguin_f" if arc == "penguins" else "dad", "Bot", "Simtown", "Dot")
	GameState.run["day_len"] = day_len
	for q in GameState.quests_data.get("main", []):
		quests_all.append([q, true])
	for q in GameState.quests_data.get("side", []):
		quests_all.append([q, false])
	for pair in quests_all:
		var rw: Variant = pair[0].get("reward", {})
		if rw is Dictionary and (rw as Dictionary).has("flag"):
			quest_flags[str(rw["flag"])] = true
	var cols := ["day", "year", "season", "style", "arc", "day_len", "purse", "earned_today", "earned_total",
		"inc_crops", "inc_fish", "inc_ore", "inc_quest", "inc_racket", "inc_other", "spent_today", "spent_total",
		"energy_start", "energy_end", "energy_max", "bound", "actions", "actions_cap"]
	for s in SKILLS:
		cols.append("lv_" + s)
	cols += ["mine_deepest", "hearts_total", "chapter", "build_tiers", "new_unlocks"]
	var lines := [",".join(cols)]
	for d in days:
		lines.append(_play_day())
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	var ul := ["style,arc,day_len,key,day"]
	for key in stamps:
		ul.append("%s,%s,%d,%s,%d" % [style, arc, day_len, key, int(stamps[key])])
	var uf := FileAccess.open(out_path.get_basename() + "_unlocks.csv", FileAccess.WRITE)
	uf.store_string("\n".join(ul) + "\n")
	uf.close()
	print("SIM %s %s len=%d days=%d purse=%d earned=%d spent=%d farming=%d fishing=%d mining=%d deepest=%d unlocks=%d" % [
		style, arc, day_len, days, int(GameState.run["crystals"]), int(GameState.run.get("earned_total", 0)),
		_sum(spent), GameState.skill_level("farming"), GameState.skill_level("fishing"), GameState.skill_level("mining"), deepest, stamps.size()])
	quit()


func _sum(d: Dictionary) -> int:
	var t := 0
	for k in d:
		t += int(d[k])
	return t


func _stamp(key: String) -> bool:
	if stamps.has(key):
		return false
	stamps[key] = int(GameState.run["day"])
	return true


func _pay(n: int, sink: String) -> bool:
	if n <= 0 or int(GameState.run["crystals"]) < n:
		return n <= 0
	GameState.run["crystals"] = int(GameState.run["crystals"]) - n
	spent[sink] = int(spent.get(sink, 0)) + n
	return true


func _ship(id: String, n: int, cat: String) -> void:
	GameState.run["sellbox"][id] = int(GameState.run["sellbox"].get(id, 0)) + n
	made[cat] = float(made.get(cat, 0.0)) + float(GameState.item_value(id) * n)


# ---- story driver -------------------------------------------------------------

func _story() -> void:
	var day := int(GameState.run["day"])
	var dl: Array = QUEST_DELAY[style]
	var chap: Dictionary = CHAPTER_DAY[style]
	for pair in quests_all:
		var q: Dictionary = pair[0]
		var id := str(q["id"])
		if str(q.get("arc", "both")) not in ["both", arc] or GameState.quest_done(id):
			continue
		var when: Dictionary = (q.get("when", {}) as Dictionary).duplicate()
		# Story-beat flags (cutscenes, bosses) are not modelled: a flag gate costs one more main-quest delay.
		var beat: bool = when.has("flag") and not GameState.run["flags"].has(str(when["flag"]))
		if beat and quest_flags.has(str(when["flag"])):
			continue  # C16a integ: a quest-set flag (mega_<id>_open) is modelled: wait for that quest
		when.erase("flag")
		if not avail.has(id):
			if not GameState._cond_ok(when):
				continue
			avail[id] = day + (int(dl[0]) if beat else 0)
		var dw: Dictionary = q.get("done_when", {})
		var need := _need_value(dw)
		# Gathering the asked items takes a day per 150 of their value; skill asks wait for the skill.
		var due := int(avail[id]) + int(dl[0] if pair[1] else dl[1]) + need / 150
		if chap.has(id):
			due = maxi(due, int(chap[id]))
		if day < due:
			continue
		if dw.has("skill") and GameState.skill_level(str(dw["skill"][0])) < int(dw["skill"][1]):
			continue
		if dw.has("rec_best") or dw.has("arcade_ms") or dw.has("donated") or dw.has("museum_wing"):
			if day < due + 14:   # minigame/museum asks: two more weeks of play
				continue
		# The items handed over are worth what they would have sold for: paid from the purse.
		if need > 0 and not _pay(need, "quest_items"):
			continue
		GameState.add_quest(id, str(q.get("text", id)))
		if GameState.complete_quest(id):
			_stamp("quest:" + id)
			if dw.has("flag"):
				GameState.run["flags"][str(dw["flag"])] = day
	_stamp("chapter:%d" % GameState.progress_tier())
	for rid in MegaRegion.ids():
		if MegaRegion.available(rid) and MegaRegion.condition_met(rid):
			if _stamp("mega:" + str(rid)):
				MegaRegion.st()["unlocked"][rid] = day


func _need_value(dw: Dictionary) -> int:
	var t := 0
	var lst: Array = []
	if dw.has("item"):
		lst.append(dw["item"])
	if dw.has("items"):
		lst += dw["items"]
	for it in lst:
		if it is Array and it.size() >= 2:
			t += GameState.item_value(str(it[0])) * int(it[1])
		elif it is String:
			t += GameState.item_value(it)
	return t


# ---- build sinks ----------------------------------------------------------------

func _builds() -> void:
	var cons: Dictionary = GameState.run.get("construction", {})
	for id in cons.keys():
		if int(GameState.run["day"]) >= int(cons[id]["done_day"]):
			Builds._finish(str(id), int(cons[id]["tier"]))
			cons.erase(id)
	for id in BUILD_ORDER[style]:
		if not Builds.data().has(id):
			continue
		var g := Builds.gate(id)
		var nd := Builds.next_def(id)
		if g == "permit":
			var pc := int(nd.get("permit", 0))
			if int(GameState.run["crystals"]) >= int(pc * 1.3) and _pay(pc, "permit"):
				GameState.run["permits"] = GameState.run.get("permits", {})
				GameState.run["permits"][id] = int(nd["tier"])
				g = Builds.gate(id)
		if g != "":
			continue
		var p := Builds.price(id)
		if p > 0 and int(GameState.run["crystals"]) >= int(p * 1.3):
			var before := int(GameState.run["crystals"])
			Builds.start(id, true)
			var paid := before - int(GameState.run["crystals"])
			if paid > 0:
				spent["build"] = int(spent.get("build", 0)) + paid
				_stamp("build:%s:%d" % [id, int(nd["tier"])])
			break   # one purchase a day


# ---- farming --------------------------------------------------------------------

func _profit_per_day(seed_id: String) -> float:
	var it: Dictionary = GameState.items.get(seed_id, {})
	var crop := str(it.get("crop", ""))
	if crop == "" or not GameState.crops.has(crop):
		return -1.0
	var cd: Dictionary = GameState.crops[crop]
	if cd.get("tree", false):
		return -1.0
	var cs := str(cd.get("season", "any"))
	if cs != "any" and cs != GameState.season():
		return -1.0
	var days_left := 28 - GameState.day_of_season()
	var grow := int(cd["days"])
	if grow > days_left:
		return -1.0
	var value := GameState.item_value(str(cd["yield"]))
	var cost := float(GameState.buy_price(seed_id))
	if cd.has("regrow"):
		var harvests := 1 + int((days_left - grow) / int(cd["regrow"]))
		return (harvests * value - cost) / float(days_left)
	return (value - cost) / float(grow)


func _pick_seed() -> String:
	var best := ""
	var best_v := 0.0
	var pool: Array = Shops.offers("store")
	for id in GameState.run["inventory"].keys():
		if GameState.count(id) > 0:
			pool.append(id)
	for sid in pool:
		if str(GameState.items.get(sid, {}).get("type", "")) != "seed":
			continue
		var v := _profit_per_day(sid)
		if v > best_v:
			best_v = v
			best = sid
	return best


func _plant(tile: Dictionary, seed_id: String) -> bool:
	if GameState.count(seed_id) <= 0:
		if not _pay(GameState.buy_price(seed_id), "seeds"):
			return false
		GameState.add_item(seed_id, 1)
	if not GameState.spend_for("plant"):
		return false
	tile["crop"] = str(GameState.items[seed_id]["crop"])
	tile["days"] = 0
	GameState.add_item(seed_id, -1)
	GameState.add_xp("farming", 2)
	return true


func _farm(st: Dictionary, field_cap: int) -> void:
	var farm: Dictionary = GameState.run["farm"]
	if field_cap <= 0:
		return
	st["actions"] += TRIP_ACTIONS / 3
	var flv := GameState.skill_level("farming")
	for key in farm.keys():
		var tile: Dictionary = farm[key]
		var crop := str(tile.get("crop", ""))
		if crop == "" or st["actions"] >= st["cap"]:
			continue
		var cd: Dictionary = GameState.crops[crop]
		if int(tile["days"]) >= int(cd["days"]):
			var n := FarmS.harvest_count(flv, GameState.bonus("farming", "extra_crop"), GameState.bonus("farming", "double_harvest"), randf(), randf())
			var yid := str(cd["yield"])
			_ship(yid, n, "crops")
			var qd := FarmS.quality_odds(flv, false, GameState.bonus("farming", "star_chance"))
			var qr := randf()
			if qr < float(qd["gold"]):
				GameState.add_quality(yid, "g", n)
			elif qr < float(qd["silver"]):
				GameState.add_quality(yid, "s", n)
			GameState.add_xp("farming", FarmS.harvest_xp(cd))
			if cd.has("regrow"):
				tile["days"] = int(cd["days"]) - int(cd["regrow"])
			else:
				tile["crop"] = ""
				tile["days"] = 0
			st["actions"] += 1
	var seed_id := _pick_seed()
	if seed_id != "":
		for key in farm.keys():
			var tile: Dictionary = farm[key]
			if str(tile.get("crop", "")) != "" or st["actions"] >= st["cap"]:
				continue
			if not _plant(tile, seed_id):
				break
			st["actions"] += 1
	var watered := 0
	if not GameState.is_wet():
		for key in farm.keys():
			var tile: Dictionary = farm[key]
			if str(tile.get("crop", "")) == "" or bool(tile.get("watered", false)) or st["actions"] >= st["cap"]:
				continue
			if not GameState.spend_for("can"):
				st["bound"] = "energy"
				break
			tile["watered"] = true
			watered += 1
			st["actions"] += 1
			if watered % maxi(1, WaterCan.cap()) == 0:
				st["actions"] += REFILL_ACTIONS
	if seed_id != "":
		var cap := mini(field_cap, int(float(GameState.run["max_energy"]) * 0.7 / maxf(0.1, GameState.energy_cost_f("can"))))
		while farm.size() < cap and st["actions"] < st["cap"] - 3 and float(GameState.run["energy"]) > 6.0:
			if int(GameState.run["crystals"]) < GameState.buy_price(seed_id) and GameState.count(seed_id) <= 0:
				break
			if not GameState.spend_for("hoe"):
				break
			var key := "%d,%d" % [10 + (farm.size() % 24), 10 + int(farm.size() / 24)]
			farm[key] = {"watered": false, "crop": "", "days": 0}
			GameState.add_xp("farming", 1)
			st["actions"] += 1
			if _plant(farm[key], seed_id):
				st["actions"] += 1
				if GameState.spend_for("can"):
					farm[key]["watered"] = true
					st["actions"] += 1


# ---- mining / fishing -------------------------------------------------------------

func _mine(st: Dictionary, keep_frac: float) -> void:
	var keep := float(GameState.run["max_energy"]) * keep_frac
	st["actions"] += TRIP_ACTIONS
	var floor_n := maxi(1, deepest - deepest % 5)   # the lift stops every 5 floors
	var pools: Array = GameState.tier_data.get("mine", {}).get("ores", [])
	# Explorers push deeper two days in three and fish the afternoon on the third.
	var stop_at := float(st["cap"]) * (0.5 if int(GameState.run["day"]) % 3 == 0 else 1.0)
	while st["actions"] < stop_at - 10 and floor_n <= 150:
		st["actions"] += WALK_PER_FLOOR
		var mtier := mini(pools.size() - 1, int(floor_n / 10))
		var ores: Array = pools[mtier] if pools.size() > 0 else ["stone"]
		var ok := true
		for r in ROCKS_PER_FLOOR:
			var ore := "stone"
			if randf() > 0.5 and ores.size() > 1:
				ore = str(ores[rng.randi_range(1, ores.size() - 1)])
			# Rock hp as mine.gd: stone STONE_HP, ore 3 + vein rank / 2, both + floor / HP_PER_FLOORS.
			var oi := ores.find(ore)
			var hp := (Mining.STONE_HP if ore == "stone" else 3 + maxi(0, oi) / 2) + floor_n / Mining.HP_PER_FLOORS
			var hits := GameState.hits_for(hp, "pickaxe")
			if float(GameState.run["energy"]) - hits * GameState.energy_cost_f("pickaxe") < keep:
				ok = false
				st["bound"] = "energy"
				break
			for h in hits:
				GameState.spend_for("pickaxe")
			st["actions"] += hits * SWING_ACTIONS
			_ship(ore, 2 if ore == "stone" else 1 + (1 if randf() < 0.3 else 0), "ore")
			GameState.add_xp("mining", (3 if ore == "stone" else 6) + mtier)
		if not ok:
			break
		# Foes on the floor: a few swings and a dodge each.
		for foe in 2 + int(floor_n / 15):
			for s in 3:
				GameState.spend_for("sword")
			GameState.spend_for("dodge")
			st["actions"] += 0.8 + floor_n / 50.0   # ~5 s a foe, longer as they toughen
			GameState.add_xp("combat", 4 + mtier)
		deepest = maxi(deepest, floor_n)
		if deepest % 10 == 0:
			_stamp("mine:%d" % deepest)
		floor_n += 1
		if st["actions"] >= stop_at:
			st["bound"] = "time"


func _fish(st: Dictionary) -> void:
	st["actions"] += TRIP_ACTIONS
	var area_tier := mini(3, GameState.progress_tier())
	var pool := Fishing.pool_for(Fishing.season_fish(GameState.season(), "fresh"), area_tier, "lake")
	while st["actions"] + CAST_ACTIONS <= st["cap"]:
		if float(GameState.run["energy"]) < GameState.energy_cost_f("rod") + 1.0:
			st["bound"] = "energy"
			return
		GameState.spend_for("rod")
		st["actions"] += CAST_ACTIONS
		var fish := Fishing.pick(pool, GameState.skill_level("fishing"), false, false, area_tier, GameState.bonus("fishing", "rare_fish"), "lake")
		if fish == "" or not GameState.items.has(fish):
			continue
		_ship(fish, 1, "fish")
		GameState.add_xp("fishing", Fishing.xp_for(fish))
	st["bound"] = "time"


# ---- social / hustle ------------------------------------------------------------

func _social(st: Dictionary) -> void:
	st["actions"] += TRIP_ACTIONS
	var npcs: Array = GameState.npcs.keys()
	npcs.sort()
	var talked := 0
	for npc in npcs:
		if talked >= 8 or st["actions"] >= st["cap"]:
			break
		GameState.add_friend(str(npc), 2)
		st["actions"] += 3
		talked += 1
	# Two liked gifts a day, bought in town (~a common item's price).
	for g in 2:
		var npc := str(npcs[(int(GameState.run["day"]) * 2 + g) % maxi(1, npcs.size())])
		if _pay(60, "gifts"):
			GameState.add_friend(npc, 8)
	# Creative: a decor piece most weeks once the purse allows.
	if int(GameState.run["day"]) % 7 == 0 and int(GameState.run["crystals"]) > 1500:
		_pay(int(GameState.run["crystals"]) / 10, "decor")


func _hustle(st: Dictionary) -> void:
	if not Racket.on() or int(GameState.run["day"]) < 8:
		return
	st["actions"] += TRIP_ACTIONS
	var notes: Array = []
	for id in GameState.items:
		if GameState.items[id].has("face"):
			notes.append(id)
	notes.sort_custom(func(x, y): return int(GameState.items[x]["face"]) < int(GameState.items[y]["face"]))
	if notes.is_empty():
		return
	var pick := str(notes[mini(notes.size() - 1, GameState.progress_tier())])
	GameState.run["passed_day"] = {"day": int(GameState.run["day"]), "n": 0}
	for k in Racket.pass_cap():
		var r := Racket.risk(pick)
		GameState.run["passed_day"]["n"] = k + 1
		st["actions"] += 4
		var face := int(GameState.items[pick]["face"])
		if randf() >= r:
			GameState.add_money(face, "racket")
			GameState.add_xp("bartering", 2 + int(GameState.items[pick].get("tier", 1)))
		else:
			GameState.run["crystals"] = int(GameState.run["crystals"]) - mini(int(GameState.run["crystals"]), face / 2)
			spent["fines"] = int(spent.get("fines", 0)) + face / 2
			break


# ---- one day --------------------------------------------------------------------

func _play_day() -> String:
	var r: Dictionary = GameState.run
	var eb0: Dictionary = (r.get("earned_by", {}) as Dictionary).duplicate()
	var earned0 := int(r.get("earned_total", 0))
	var spent0 := _sum(spent)
	var n_stamps := stamps.size()
	made = {}
	_story()
	_builds()
	var e_start := float(r["energy"])
	var cap := int(float(GameState.day_len()) * 60.0 / SECONDS_PER_ACTION)
	var st := {"actions": 0.0, "cap": cap, "bound": "time"}
	match style:
		"farmer":
			_farm(st, FIELD_CAP["farmer"])
		"explorer":
			_mine(st, 0.25)
			if st["actions"] < st["cap"] - 10:
				_fish(st)
		"social":
			_social(st)
			_farm(st, FIELD_CAP["social"])
		"hustler":
			_hustle(st)
			_farm(st, FIELD_CAP["hustler"])
	if float(r["energy"]) < 3.0:
		st["bound"] = "energy"
	var e_end := float(r["energy"])
	var day := int(r["day"])
	var year := GameState.year()
	var season := GameState.season()
	for s in SKILLS:
		var lv := GameState.skill_level(s)
		for mk in SKILL_MARKS:
			if lv >= mk:
				_stamp("skill:%s:%d" % [s, mk])
	_stamp("year:%d" % year)
	GameState.sleep()
	var eb: Dictionary = r.get("earned_by", {})
	var inc := {}
	for k in eb:
		inc[k] = int(eb[k]) - int(eb0.get(k, 0))
	var sales := int(inc.get("sales", 0))
	var mt := float(made.get("crops", 0.0)) + float(made.get("fish", 0.0)) + float(made.get("ore", 0.0))
	var split := {}
	for c in ["crops", "fish", "ore"]:
		split[c] = int(round(sales * float(made.get(c, 0.0)) / mt)) if mt > 0.0 else 0
	var quest := int(inc.get("quest", 0))
	var racket := int(inc.get("racket", 0)) + int(inc.get("wash", 0))
	var earned_today := int(r.get("earned_total", 0)) - earned0
	var other: int = earned_today - split["crops"] - split["fish"] - split["ore"] - quest - racket
	var hearts := 0
	for npc in r["friendship"]:
		hearts += GameState.friend_hearts(str(npc))
	var bt := 0
	for id in r.get("builds", {}):
		bt += int(r["builds"][id])
	var row := [day, year, season, style, arc, day_len, int(r["crystals"]), earned_today, int(r.get("earned_total", 0)),
		split["crops"], split["fish"], split["ore"], quest, racket, other, _sum(spent) - spent0, _sum(spent),
		int(e_start), int(e_end), int(r["max_energy"]), st["bound"], int(st["actions"]), cap]
	for s in SKILLS:
		row.append(GameState.skill_level(s))
	row += [deepest, hearts, GameState.progress_tier(), bt, stamps.size() - n_stamps]
	return ",".join(row.map(func(x): return str(x)))

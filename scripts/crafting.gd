class_name Crafting
extends RefCounted
## The workshop: every craft station in the game runs through here.
##
## A station is a building you made or bought (data/buildings.json, "station":
## {skill, verb, book}) with four tiers. Its tier sets what it can do:
##   recipes up to tier+1 · `tier` jobs at once · 15% faster per tier ·
##   a masterwork chance (a bonus piece) from tier 2.
## Recipes live in data/recipes.json under the station's book. A recipe also
## needs the station's skill (tier 2 at Lv3, 3 at Lv5, 4 at Lv7, 5 at Lv9), so
## the station, your skill and the story all move together.
## Town stations (Gideon's forge, Wren's cauldron...) work the same way at a
## tier set by your friendship with the keeper, for a small fee per piece.
##
## Jobs: run["jobs"][key] = [ {id, name, give, n, tier, tool, done_at}, ... ]
## Times are absolute game minutes, so jobs run while you sleep.

const ALIAS := {"smith": ["furnace", "anvil", "tannery"], "alchemy": ["cauldron"]}
const TOWN_KEEPER := {"furnace": "gideon", "anvil": "gideon", "tannery": "rook", "cauldron": "wren", "mill": "orla", "kitchen": "posy", "workbench": "hazel", "loom": "lumi", "jeweler": "ivy", "kiln": "granite"}
const SPEED := [1.0, 0.85, 0.7, 0.55]
const BONUS := [0.0, 0.05, 0.10, 0.20]
const BASE_MINUTES := {1: 20, 2: 45, 3: 90, 4: 180, 5: 360}
const STATION_SPEED := {"workbench": 1.0, "furnace": 1.2, "anvil": 1.4, "kitchen": 0.6, "cauldron": 1.2, "mill": 0.8, "loom": 1.2, "kiln": 1.5, "sawmill": 0.7, "tannery": 1.2, "press": 1.5, "jeweler": 1.6, "garage": 3.0, "launchpad": 3.0, "print_shop": 1.0, "armory": 1.6, "soda": 0.6, "resonator": 1.0, "shaper": 1.6, "litter": 0.8, "campfire": 0.5}


# ---- station facts -------------------------------------------------------------

static func meta(station: String) -> Dictionary:
	return Builds.all().get(station, {}).get("station", {})


static func is_station(station: String) -> bool:
	return not meta(station).is_empty()


static func book(station: String) -> String:
	return str(meta(station).get("book", station))


static func skill_of(station: String) -> String:
	return str(meta(station).get("skill", "building"))


static func label(station: String) -> String:
	return str(Builds.all().get(station, {}).get("label", station.capitalize()))


## Tier of the station you own (0 = not built).
static func own_tier(station: String) -> int:
	return Builds.built_tier(station)


## Tier of the town's station: grows with the keeper's friendship and the story.
static func town_tier(station: String) -> int:
	var keeper := str(TOWN_KEEPER.get(station, ""))
	var t := 1 + int(GameState.friend_hearts(keeper) / 3) if keeper != "" else 1
	return clampi(mini(t, GameState.progress_tier() + 1), 1, 3)


static func cap(tier: int) -> int:
	return mini(5, tier + 1)


static func slots(tier: int) -> int:
	return maxi(1, tier)


static func skill_tier(station: String) -> int:
	return 1 + int(GameState.skill_level(skill_of(station)) / 2)


## Kept for older callers: the recipe tier you can reach at a station you own.
static func tier_unlocked(station: String) -> int:
	return mini(cap(maxi(1, own_tier(station))), skill_tier(station))


# ---- recipes -------------------------------------------------------------------

static func _all(station: String) -> Array:
	var out: Array = []
	for rc in GameState.recipes.get(book(station), []):
		if rc.has("arc") and str(rc["arc"]) != str(GameState.run.get("arc", "")):
			continue
		out.append(rc)
	if book(station) == "keg":
		out += _keg_recipes()
	return out


## The keg takes anything you grow: one recipe per kind of produce in your pack.
static func _keg_recipes() -> Array:
	var out: Array = []
	var ids: Array = GameState.run["inventory"].keys()
	ids.sort()
	for id in ids:
		var brew := GameState.keg_brew(str(id))
		if brew == "" or GameState.count(str(id)) <= 0:
			continue
		var t := clampi(int(GameState.items.get(str(id), {}).get("tier", 1)), 1, 5)
		out.append({"id": "brew_" + str(id), "name": "%s → %s" % [GameState.item_name(str(id)), GameState.item_name(brew)], "need": {str(id): 1}, "give": brew, "tier": t, "days": 1 + mini(3, t)})
	return out


## "" if you can make it here, else what's missing ("Needs Smithy", "Needs Mining Lv 5").
static func why_locked(station: String, tier: int, rc: Dictionary) -> String:
	var rt := int(rc.get("tier", 1))
	if rt > cap(tier):
		var need := rt - 1
		var td := Builds.tier_def(station, need)
		return "needs %s" % str(td.get("name", "%s tier %d" % [label(station), need]))
	if rt > skill_tier(station):
		return "needs %s Lv %d" % [skill_of(station).capitalize(), (rt - 1) * 2 + 1]
	if rc.has("skill") and GameState.skill_level(str(rc["skill"][0])) < int(rc["skill"][1]):
		return "needs %s Lv %d" % [str(rc["skill"][0]).capitalize(), int(rc["skill"][1])]
	return ""


static func available(station: String, tier := -1) -> Array:
	if tier < 0:
		tier = maxi(1, own_tier(station))
	var out: Array = []
	for rc in _all(station):
		if why_locked(station, tier, rc) == "":
			out.append(rc)
	return out


static func can_make(rc: Dictionary, qty := 1) -> bool:
	for id in rc["need"]:
		if GameState.count_any(str(id)) < int(rc["need"][id]) * qty:
			return false
	return true


static func max_qty(rc: Dictionary) -> int:
	var n := 999
	for id in rc["need"]:
		n = mini(n, int(GameState.count_any(str(id)) / maxi(1, int(rc["need"][id]))))
	return n


static func _single(rc: Dictionary) -> bool:
	var t := str(GameState.items.get(str(rc["give"]), {}).get("type", ""))
	return bool(rc.get("tool", false)) or bool(rc.get("vehicle", false)) or t in ["tool", "vehicle", "equip"]


static func _owned(rc: Dictionary) -> bool:
	var g := str(rc["give"])
	var t := str(GameState.items.get(g, {}).get("type", ""))
	if bool(rc.get("tool", false)) or t == "tool":
		return GameState.has_tool(g)
	if t == "vehicle":
		return GameState.count(g) > 0
	return false


# ---- time ----------------------------------------------------------------------

static func minutes_for(station: String, rc: Dictionary, tier := 1, qty := 1) -> int:
	var m := float(BASE_MINUTES.get(int(rc.get("tier", 1)), 60)) * float(STATION_SPEED.get(station, 1.0))
	if rc.has("minutes"):
		m = float(rc["minutes"])
	if rc.has("days"):
		m = float(rc["days"]) * 1440.0
	m *= float(SPEED[clampi(tier, 1, 4) - 1])
	m *= 1.0 - GameState.bonus("building", "craft_speed")
	if Companion.has_ability("tinker"):
		m *= 0.7
	if bool(rc.get("tool", false)):
		m *= 1.5
	if book(station) == "keg" and Builds.built_tier("house") >= 3:
		m *= 0.5  # the manor's cellar
	m *= pow(float(maxi(1, qty)), 0.85)
	return maxi(5, int(round(m / 5.0) * 5))


static func now_abs() -> int:
	return int(GameState.run["day"]) * 1440 + int(GameState.run["time"])


static func fmt_minutes(mn: int) -> String:
	if mn >= 1440:
		return "%dd %dh" % [mn / 1440, (mn % 1440) / 60]
	if mn >= 60:
		return "%dh %02dm" % [mn / 60, mn % 60]
	return "%dm" % mn


# ---- jobs ----------------------------------------------------------------------

static func jobs(key: String) -> Array:
	var all: Dictionary = GameState.run.get("jobs", {})
	GameState.run["jobs"] = all
	var v: Variant = all.get(key, [])
	if v is Dictionary:  # saves from before stations had several slots
		v = [v] if not (v as Dictionary).is_empty() else []
		all[key] = v
	if not all.has(key):
		all[key] = v
	return v


## Older callers: the first job at a station ({} if none) and minutes left.
static func job(key: String) -> Dictionary:
	var j := jobs(key)
	return j[0] if not j.is_empty() else {}


static func job_left(key: String) -> int:
	var j := job(key)
	return 0 if j.is_empty() else maxi(0, int(j["done_at"]) - now_abs())


static func start(station: String, key: String, rc: Dictionary, tier: int, qty: int) -> Dictionary:
	for id in rc["need"]:
		GameState.take_any(str(id), int(rc["need"][id]) * qty)
	var mins := minutes_for(station, rc, tier, qty)
	if not rc.has("days"):
		# Whatever you start today is ready when you wake.
		var day_end := int(GameState.run["day"]) * 1440 + GameState.DAY_END
		mins = clampi(mins, 5, maxi(5, day_end - now_abs()))
	var j := {"id": str(rc["id"]), "name": str(rc["name"]), "give": str(rc["give"]), "n": int(rc.get("n", 1)) * qty, "batches": qty, "tier": int(rc.get("tier", 1)), "tool": bool(rc.get("tool", false)), "st": tier, "station": station, "done_at": now_abs() + mins}
	jobs(key).append(j)
	return j


## Hands over every finished job at this station. Returns how many.
static func collect(m: GameMap, station: String, key: String) -> int:
	var list := jobs(key)
	var got := 0
	for j: Dictionary in list.duplicate():
		if int(j["done_at"]) > now_abs():
			continue
		var give_id := str(j["give"])
		var it: Dictionary = GameState.items.get(give_id, {})
		var n := int(j.get("n", 1))
		if bool(j.get("tool", false)) or str(it.get("type", "")) == "tool":
			GameState.add_tool(give_id)
			m.hud.toast("Made the %s!" % GameState.item_name(give_id), Color(1, 0.9, 0.4))
		else:
			# Masterwork: a better station sometimes turns out an extra piece.
			var extra := 0
			if str(it.get("type", "")) not in ["equip", "vehicle"]:
				for i in int(j.get("batches", 1)):
					if randf() < float(BONUS[clampi(int(j.get("st", 1)), 1, 4) - 1]):
						extra += 1
			m.give(give_id, n + extra)
			if extra > 0:
				m.hud.toast("Masterwork! +%d %s" % [extra, GameState.item_name(give_id)], Color(0.8, 1, 0.9))
				m.fx("masterwork", m.player.position + Vector2(0, -22), 10.0, 0.5)
		m.xp(skill_of(station), int((4 + 3 * int(j.get("tier", 1))) * minf(4.0, 1.0 + 0.5 * (int(j.get("batches", 1)) - 1))))
		GameState.run["made"] = int(GameState.run.get("made", 0)) + n
		list.erase(j)
		got += 1
	if got > 0:
		Music.instance(m.get_tree()).sfx("levelup")
	return got


## Jobs that finished since you were last told (for a toast), across all stations.
static func newly_done() -> Array:
	var out: Array = []
	var all: Dictionary = GameState.run.get("jobs", {})
	for key in all:
		if not (all[key] is Array):
			continue
		for j: Dictionary in all[key]:
			if not j.has("give") or bool(j.get("told", false)) or int(j.get("done_at", 0)) > now_abs():
				continue
			j["told"] = true
			out.append("%s: %s ready" % [label(str(j.get("station", key))), str(j.get("name", "job"))])
	return out


## One line per station you own, for the journal.
static func summary() -> Array:
	var out: Array = []
	for id in Builds.data():
		if not is_station(id) or own_tier(id) <= 0:
			continue
		var t := own_tier(id)
		var js := jobs(id)
		var parts: Array = []
		for j: Dictionary in js:
			var left := int(j["done_at"]) - now_abs()
			parts.append("%s ×%d %s" % [str(j["name"]), int(j.get("n", 1)), "READY" if left <= 0 else fmt_minutes(left)])
		out.append({"id": id, "head": "%s (tier %d) · %d/%d busy" % [str(Builds.current_def(id).get("name", label(id))), t, js.size(), slots(t)], "jobs": parts})
	return out


# ---- the menu ------------------------------------------------------------------

static func _cat(rc: Dictionary) -> String:
	if rc.has("cat"):
		return str(rc["cat"])
	var it: Dictionary = GameState.items.get(str(rc["give"]), {})
	match str(it.get("type", "")):
		"equip":
			var nm := str(it.get("name", "Other"))
			if str(rc["give"]).begins_with("outfit_"):
				return "Outfits"
			return nm.get_slice(" ", 0) + " gear"
		"tool":
			return "Weapons & tools"
		"petgear":
			return "Pup gear"
		"vehicle":
			return "Vehicles"
	return "Materials & parts"


static func _need_text(rc: Dictionary, qty := 1) -> String:
	var need: Array = []
	for id in rc["need"]:
		need.append("%d %s" % [int(rc["need"][id]) * qty, GameState.need_name(str(id))])
	return ", ".join(need)


static func run(m: GameMap, station: String, title := "", where := "farm") -> void:
	if ALIAS.has(station):
		var subs: Array = ALIAS[station]
		if subs.size() == 1:
			await run(m, str(subs[0]), title, where)
			return
		var d0 := Dialogue.instance(m.get_tree())
		var ch: Array = []
		for s in subs:
			ch.append("%s (%s)" % [str(meta(str(s)).get("verb", "Use")), label(str(s))])
		ch.append("Leave")
		d0.say([{"who": title if title != "" else "Workshop", "text": "Which bench?", "choice": ch, "key": ""}])
		await d0.finished
		if d0.last_choice >= 0 and d0.last_choice < subs.size():
			await run(m, str(subs[d0.last_choice]), "", where)
		return
	if not is_station(station):
		m.hud.toast("Nothing to make here.")
		return
	var town := where == "town"
	var tier := town_tier(station) if town else own_tier(station)
	if tier <= 0:
		m.hud.toast("You need a %s first. Build or buy one from the Plans board on your farm." % label(station), Color(1, 0.85, 0.6))
		return
	var key := ("town_" + station) if town else station
	var head := title if title != "" else (label(station) if town else str(Builds.current_def(station).get("name", label(station))))
	# A brew started under the old one-keg rule becomes a job.
	if station == "keg" and not (GameState.run["flags"].get("keg", {}) as Dictionary).is_empty():
		var ok: Dictionary = GameState.run["flags"]["keg"]
		jobs(key).append({"id": "brew_old", "name": GameState.item_name(str(ok["out"])), "give": str(ok["out"]), "n": 1, "batches": 1, "tier": 1, "tool": false, "st": 1, "station": "keg", "done_at": int(ok["ready"]) * 1440 + GameState.DAY_START})
		GameState.run["flags"]["keg"] = {}
	var cat := ""
	while true:
		collect(m, station, key)
		var js := jobs(key)
		var list := available(station, tier)
		var cats: Array = []
		if list.size() > 9:
			for rc in list:
				if _cat(rc) not in cats:
					cats.append(_cat(rc))
		var d := Dialogue.instance(m.get_tree())
		var status := "Tier %d · %d of %d slot%s busy" % [tier, js.size(), slots(tier), "" if slots(tier) == 1 else "s"]
		if not js.is_empty():
			var soon := 999999
			for j: Dictionary in js:
				soon = mini(soon, int(j["done_at"]) - now_abs())
			status += " · next in %s" % fmt_minutes(maxi(0, soon))
		if town:
			status += " · %s's bench: ◆ fee per piece" % str(GameState.npcs.get(str(TOWN_KEEPER.get(station, "")), {}).get("name", "The keeper"))
		# Step 1 (big books only): pick a shelf.
		if cats.size() > 1 and cat == "":
			var copts: Array = cats.duplicate()
			copts.append("Leave")
			d.say([{"who": head, "text": status, "choice": copts, "key": ""}])
			await d.finished
			if d.last_choice < 0 or d.last_choice >= cats.size():
				return
			cat = str(cats[d.last_choice])
			continue
		var shown: Array = []
		var opts: Array = []
		for rc in list:
			if cat != "" and _cat(rc) != cat:
				continue
			shown.append(rc)
			var n := int(rc.get("n", 1))
			opts.append("%s%s%s  [%s]  ⏱%s" % ["✓ have · " if _owned(rc) else ("" if can_make(rc) else "✗ "), str(rc["name"]), " ×%d" % n if n > 1 else "", _need_text(rc), fmt_minutes(minutes_for(station, rc, tier))])
		# What the next upgrade or level opens, so there's always something to aim at.
		var locked: Array = []
		for rc in _all(station):
			var why := why_locked(station, tier, rc)
			if why != "" and (cat == "" or _cat(rc) == cat) and locked.size() < 3:
				locked.append("🔒 %s — %s" % [str(rc["name"]), why])
		opts += locked
		var wait_i := -1
		if not js.is_empty():
			wait_i = opts.size()
			opts.append("Wait here for the next job")
		var back_i := -1
		if cat != "":
			back_i = opts.size()
			opts.append("← Other shelves")
		opts.append("Leave")
		if shown.is_empty() and locked.is_empty() and station == "keg":
			status += "\nBring produce: fruit, vegetables, herbs, grain, mushrooms or flowers."
		d.say([{"who": head, "text": status if cat == "" else "%s\n%s" % [cat, status], "choice": opts, "key": ""}])
		await d.finished
		var i := d.last_choice
		if i == wait_i and wait_i >= 0:
			var soon2 := 999999
			for j: Dictionary in js:
				soon2 = mini(soon2, int(j["done_at"]) - now_abs())
			var day_left := GameState.DAY_END - int(GameState.run["time"]) - 10
			if soon2 > day_left:
				m.hud.toast("That won't be ready today. Sleep on it.")
			elif soon2 > 0:
				GameState.run["time"] = int(GameState.run["time"]) + soon2
				m.hud.toast("You wait. %s." % fmt_minutes(soon2))
			continue
		if i == back_i and back_i >= 0:
			cat = ""
			continue
		if i < 0 or i >= shown.size():
			if i >= shown.size() and i < shown.size() + locked.size():
				m.hud.toast(str(locked[i - shown.size()]).trim_prefix("🔒 "), Color(1, 0.85, 0.6))
				continue
			return
		var rc: Dictionary = shown[i]
		if _owned(rc):
			m.hud.toast("You already have the %s." % GameState.item_name(str(rc["give"])), Color(1, 0.8, 0.6))
			continue
		if js.size() >= slots(tier):
			m.hud.toast("Every slot is busy. A better %s runs more jobs at once." % label(station), Color(1, 0.8, 0.6))
			continue
		if not can_make(rc):
			m.hud.toast("Missing: %s." % _need_text(rc), Color(1, 0.7, 0.7))
			continue
		# How many?
		var qty := 1
		var mx := mini(max_qty(rc), 10 * tier)
		if not _single(rc) and mx > 1:
			var qs: Array = [1]
			if mx >= 5:
				qs.append(5)
			if mx not in qs:
				qs.append(mx)
			var qopts: Array = []
			for q in qs:
				qopts.append("Make %d  [%s]  ⏱%s" % [int(q) * int(rc.get("n", 1)), _need_text(rc, int(q)), fmt_minutes(minutes_for(station, rc, tier, int(q)))])
			qopts.append("Back")
			d.say([{"who": head, "text": "%s: how many?" % str(rc["name"]), "choice": qopts, "key": ""}])
			await d.finished
			if d.last_choice < 0 or d.last_choice >= qs.size():
				continue
			qty = int(qs[d.last_choice])
		if town:
			var fee := 5 * int(rc.get("tier", 1)) * qty
			if int(GameState.run["crystals"]) < fee:
				m.hud.toast("The bench fee is ◆%d." % fee, Color(1, 0.7, 0.7))
				continue
			GameState.run["crystals"] = int(GameState.run["crystals"]) - fee
		var j := start(station, key, rc, tier, qty)
		m.hud.toast("%s: ready in %s." % [str(rc["name"]), fmt_minutes(int(j["done_at"]) - now_abs())], Color(1, 0.9, 0.4))
		Music.instance(m.get_tree()).sfx("plant")

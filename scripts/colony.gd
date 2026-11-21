class_name Colony
extends RefCounted
## The merkitty colonies (penguin arc side arc, data/colonies.json + the
## colony_* regions from tools/gen_colonies.py). Four island colonies, each kept
## alive by a star crystal that the Dark Crystal is draining. Help each one:
##   1. hear the elder   2. bring what they need   3. drive off the corrupted
##   4. relight the tide beacons   5. wake the star crystal (and face what's
##   feeding on it). Each colony saved grants an ability, magic, and its shop.
##   run["colonies"][id] = {"met", "gave", "kills", "beacons": {}, "done"}

static var _d: Dictionary = {}


static func data() -> Dictionary:
	if _d.is_empty():
		_d = GameState.load_json("res://data/colonies.json")
	return _d


static func st(id: String) -> Dictionary:
	var all: Dictionary = GameState.run.get("colonies", {})
	GameState.run["colonies"] = all
	if not all.has(id):
		all[id] = {"met": false, "gave": false, "kills": 0, "beacons": {}, "done": false}
	# C7: a saved colony also sets colony_<id>_done (finale/epilogue key); old saves get it here.
	if bool(all[id].get("done", false)) and GameState.run.has("flags") and not GameState.run["flags"].has(id + "_done"):
		GameState.run["flags"][id + "_done"] = true
	return all[id]


static func saved() -> int:
	var n := 0
	for id in data():
		if bool(st(str(id)).get("done", false)):
			n += 1
	return n


static func has_ability(a: String) -> bool:
	return GameState.run.get("flags", {}).has("colony_" + a)


## The ferry at the end of the west pier on the beach.
static func ferry(m: GameMap) -> void:
	if not GameState.is_penguins():
		m.hud.toast("The ferryman shakes his head. 'Islands are closed to your sort, friend.'")
		return
	var opts: Array = []
	var ids: Array = []
	for id in data():
		var c: Dictionary = data()[id]
		var ok := GameState.progress_tier() >= int(c.get("tier", 1)) or Project.has("sky_lens")
		var held := not Campaign.region_open(str(id))  # the island's campaign comes first
		var why := ""
		if held:
			why = " (held: campaign map)"
		elif not ok:
			why = " (rough seas until story chapter %d)" % (int(c.get("tier", 1)) + 1)
		opts.append("%s%s%s" % ["✓ " if bool(st(str(id))["done"]) else "", str(c["name"]), why])
		ids.append([str(id), ok, held])
	opts.append("Stay ashore")
	var d := Dialogue.instance(m.get_tree())
	d.say([{"who": "Ferry", "text": "Skipper Barnacle, the ferry-cat, flicks an ear. 'Four colonies out there, and every one of them is going dark. Where to?'", "choice": opts, "key": ""}])
	await d.finished
	var i := d.last_choice
	if i < 0 or i >= ids.size():
		return
	if bool(ids[i][2]):
		# Same words and next step as walking into a held region (Campaign.gate_words).
		Campaign.offer(m, Campaign.gate_of(str(ids[i][0])))
		return
	if not bool(ids[i][1]):
		m.hud.toast("Skipper Barnacle: 'Not in this weather. The sea calms as the story goes on.'", Color(1, 0.85, 0.6))
		return
	var R: Dictionary = RegionData.region(str(ids[i][0]))
	var sp: Array = R.get("spawn", [10, 10])
	m.go_to(str(ids[i][0]), Vector2(float(sp[0]) * GameMap.TILE + 8, float(sp[1]) * GameMap.TILE + 8), "up")


static func interact(m: GameMap, region_id: String, thing: Dictionary) -> bool:
	var c: Dictionary = data().get(region_id, {})
	if c.is_empty():
		return false
	var s := st(region_id)
	match str(thing.get("type", "")):
		"elder":
			m.later(func() -> void: await _elder(m, region_id))
			return true
		"beacon":
			var key := str(thing.get("key", ""))
			if (s["beacons"] as Dictionary).has(key):
				m.hud.toast("This beacon burns steady.")
				return true
			if not bool(s["met"]):
				m.hud.toast("A cold stone lantern. Somebody here would know what it's for.")
				return true
			if GameState.count("crystal_refined") < 1:
				m.hud.toast("The beacon needs a Refined Crystal to catch.", Color(1, 0.85, 0.6))
				return true
			if GameState.count("crystal_refined") <= 3 and GameState.has_quest("teleporter") and not GameState.quest_done("teleporter"):
				m.hud.toast("Keep 3 Refined Crystals for the moon teleporter. Bring a fourth.", Color(1, 0.85, 0.6))
				return true
			GameState.add_item("crystal_refined", -1)
			s["beacons"][key] = true
			GameState.add_arc_xp(15)
			# The beacon's own cell (tap, mouse aim or a cell edge can face another one).
			var bc := m.player.facing_cell()
			for tc: Vector2i in m.things:
				if str(m.things[tc].get("type", "")) == "beacon" and str(m.things[tc].get("key", "")) == key:
					bc = tc
					break
			m.fx("levelup", m.cell_center(bc) + Vector2(0, -12), 10.0, 0.6)
			var lit_n := (s["beacons"] as Dictionary).size()
			m.hud.toast("Beacon lit (%d/%d)." % [lit_n, int(c.get("beacons", 3))], Color(0.7, 0.95, 1))
			var verses: Array = c.get("beacon_lines", [])
			if lit_n >= 1 and lit_n <= verses.size():
				m.tell([{"text": str(verses[lit_n - 1])}])
			sync_quest(region_id)
			# Swap the lantern for its lit picture now, not on the next visit.
			var on := "%s_beacon_on" % str(region_id).trim_prefix("colony_")
			var onn := on if Art.has("props", on) else "lantern_lit"
			if m.props.has(bc) and Art.has("props", onn):
				var sp := m.props[bc] as Sprite2D
				if sp:
					sp.texture = Art.tex("props", onn)
			return true
		"star_crystal":
			m.later(func() -> void: await _crystal(m, region_id))
			return true
		"colony_kit":
			m.later(func() -> void: await _kit(m, region_id, str(thing.get("key", "k0"))))
			return true
		"colony_shop":
			m.later(func() -> void: await _shop(m, region_id))
			return true
	return false


static func _elder(m: GameMap, id: String) -> void:
	var c: Dictionary = data()[id]
	var s := st(id)
	var who := str(c["elder"])
	if bool(s["done"]):
		await m.say(_after_lines(id))
		return
	if not bool(s["met"]):
		s["met"] = true
		GameState.add_quest("colony_" + id, _quest_text(id))
		var lines: Array = _lines(who, c["intro"])
		var mer := "intro_mer" if GameState.run["flags"].has("mermaid_gift") else "intro_nomer"
		if c.has(mer):
			lines.insert(mini(2, lines.size()), {"who": who, "text": str(c[mer])})
		await m.say(lines)
		return
	if not bool(s["gave"]):
		var need: Dictionary = c["need"]
		var ok := true
		for k in need:
			if Project.have_of(str(k)) < int(need[k]):
				ok = false
		if ok:
			for k in need:
				_take(str(k), int(need[k]))
			s["gave"] = true
			sync_quest(id)
			var ag: Array = c.get("after_gave", [str(c["need_thanks"])])
			await m.say(_lines(who, ag))
		else:
			var parts: Array = []
			for k in need:
				parts.append("%d %s (you have %d)" % [int(need[k]), Project.need_name(str(k)), Project.have_of(str(k))])
			await m.say([{"who": who, "text": "%s\nWe need: %s." % [str(c["need_text"]), ", ".join(parts)]}])
		return
	await m.say([{"who": who, "text": _status(id)}])


## Data lines: plain strings are the speaker's; {text} dicts are narration.
static func _lines(who: String, src: Array) -> Array:
	var out: Array = []
	for t in src:
		if t is Dictionary:
			out.append((t as Dictionary).duplicate())
		else:
			out.append({"who": who, "text": str(t)})
	return out


## After the save: the lore talk once (flag colony_<id>_lore), then a rotating
## line, sometimes news of another colony you've saved.
static func _after_lines(id: String) -> Array:
	var c: Dictionary = data()[id]
	var who := str(c["elder"])
	var f: Dictionary = GameState.run["flags"]
	if not f.has(id + "_lore") and c.has("lore"):
		f[id + "_lore"] = true
		return _lines(who, c["lore"])
	var pool: Array = (c.get("after", [str(c["thanks"])]) as Array).duplicate()
	for oid in data():
		if str(oid) != id and bool(st(str(oid)).get("done", false)):
			var en := str(data()[oid]["elder"])
			pool.append("Word came on the tide: %s is saved too. %s will be insufferable about it." % [str(data()[oid]["name"]), en.substr(en.rfind(" ") + 1)])
	var day := int(GameState.run.get("day", 1))
	return [{"who": who, "text": str(pool[day % pool.size()])}]


## The journal line (the step you're on shows under it: QuestTracker.progress -> progress()).
static func _quest_text(id: String) -> String:
	var c: Dictionary = data()[id]
	return "%s: help %s save the colony's star crystal." % [str(c["name"]), str(c["elder"])]


## Short progress for the Quests tab / tracker: "supplies ✗, foes 3/8, beacons 1/3".
static func progress(id: String) -> String:
	if id.begins_with("colony_side_"):
		var parts := id.trim_prefix("colony_side_").split(":")
		var kits: Array = data().get(parts[0], {}).get("kits", [])
		var i := int(parts[1].trim_prefix("k")) if parts.size() > 1 else -1
		if i < 0 or i >= kits.size() or not (kits[i] as Dictionary).has("quest"):
			return ""
		var need: Dictionary = kits[i]["quest"]["need"]
		var have := 0
		var total := 0
		for k in need:
			have += mini(Project.have_of(str(k)), int(need[k]))
			total += int(need[k])
		return "%d/%d" % [have, total]
	var key := id.trim_prefix("colony_")
	if not key.begins_with("colony_"):
		key = "colony_" + key
	if not data().has(key):
		return ""
	var c: Dictionary = data()[key]
	var s := st(key)
	if bool(s["done"]):
		return "Saved."
	if not bool(s["gave"]):
		return "Bring the supplies."
	if ready_to_wake(key):
		return "Wake the star crystal."
	return "Foes %d/%d, beacons %d/%d." % [mini(int(s["kills"]), int(c["kills"])), int(c["kills"]), (s["beacons"] as Dictionary).size(), int(c.get("beacons", 3))]


## Refresh the journal text of a colony quest.
static func sync_quest(id: String) -> void:
	for q in GameState.run.get("quests", []):
		if str(q.get("id", "")) == "colony_" + id and not bool(q.get("done", false)):
			q["text"] = _quest_text(id)


## QuestTracker compass for a colony quest (main or a kit's side quest): off the
## island, the way to the beach ferry; on it, the elder until the supplies are in,
## then the nearest unlit beacon, then the star crystal (a side quest: its kit).
static func pointer(m: GameMap, qid: String) -> Vector2:
	var rid := ""
	var kit := ""
	if qid.begins_with("colony_side_"):
		var parts := qid.trim_prefix("colony_side_").split(":")
		rid = parts[0]
		kit = parts[1] if parts.size() > 1 else ""
	else:
		rid = qid.trim_prefix("colony_")
	if not data().has(rid):
		return Vector2.ZERO
	var here := m.scene_id()
	if here != rid:
		if here == "beach":
			for c: Vector2i in m.things:
				if str((m.things[c] as Dictionary).get("type", "")) == "ferry":
					return m.cell_center(c)
		return GoalLine.exit_toward(m, "beach")
	var s := st(rid)
	var want := "elder"
	if kit != "":
		want = "colony_kit"
	elif bool(s["gave"]) and not ready_to_wake(rid):
		want = "beacon"
	elif bool(s["gave"]):
		want = "star_crystal"
	var best := Vector2.ZERO
	var bd := INF
	for c: Vector2i in m.things:
		var t: Dictionary = m.things[c]
		if str(t.get("type", "")) != want:
			continue
		if want == "beacon" and (s["beacons"] as Dictionary).has(str(t.get("key", ""))):
			continue
		if want == "colony_kit" and str(t.get("key", "")) != kit:
			continue
		var p := m.cell_center(c)
		var dd := p.distance_to(m.player.position) if m.player else 0.0
		if dd < bd:
			bd = dd
			best = p
	if best == Vector2.ZERO and want == "beacon":
		for c: Vector2i in m.things:
			if str((m.things[c] as Dictionary).get("type", "")) == "elder":
				return m.cell_center(c)  # beacons lit, foes left: the elder has the count
	return best


## A talkable kit (things "colony_kit", key k0..k2): their side quest, else chatter.
static func _kit(m: GameMap, id: String, key: String) -> void:
	var c: Dictionary = data()[id]
	var kits: Array = c.get("kits", [])
	var i := int(key.trim_prefix("k"))
	if i < 0 or i >= kits.size():
		return
	var k: Dictionary = kits[i]
	var nm := str(k["name"])
	var s := st(id)
	var day := int(GameState.run.get("day", 1))
	if not k.has("quest"):
		var ls: Array = k.get("lines", ["..."])
		await m.say([{"who": nm, "text": str(ls[(day + i) % ls.size()])}])
		return
	if not bool(s["met"]):
		await m.say([{"who": nm, "text": str(k.get("wait", "Talk to the elder first."))}])
		return
	var q: Dictionary = k["quest"]
	var qid := "colony_side_%s:%s" % [id, key]
	var sides: Dictionary = s.get("sides", {})
	s["sides"] = sides
	var state := str(sides.get(str(q["id"]), ""))
	if state == "done":
		var al: Array = k.get("after", [str(q["thanks"])])
		await m.say([{"who": nm, "text": str(al[day % al.size()])}])
		return
	var need: Dictionary = q["need"]
	if state == "":
		sides[str(q["id"])] = "open"
		GameState.add_quest(qid, "%s (%s): %s" % [str(q["title"]), str(c["name"]), _need_words(need)])
		await m.say([{"who": nm, "text": str(q["ask"])}])
		return
	var ok := true
	for it in need:
		if Project.have_of(str(it)) < int(need[it]):
			ok = false
	if not ok:
		await m.say([{"who": nm, "text": "%s\nStill need: %s." % [str(q["ask"]).split(". ")[0] + ".", _need_words(need, true)]}])
		return
	for it in need:
		_take(str(it), int(need[it]))
	sides[str(q["id"])] = "done"
	GameState.complete_quest(qid)
	await m.say([{"who": nm, "text": str(q["thanks"])}])
	var rw: Dictionary = q.get("reward", {})
	for it in rw:
		if str(it) == "crystals":
			GameState.add_money(int(rw[it]), "quests")
			m.hud.toast("+%s" % Money.amount(int(rw[it])), Color(1, 0.9, 0.5))
		elif int(rw[it]) > 0:
			m.give(str(it), int(rw[it]))
	GameState.add_arc_xp(25)
	Music.instance(m.get_tree()).sfx("quest_done", "levelup")


static func _need_words(need: Dictionary, have := false) -> String:
	var parts: Array = []
	for k in need:
		if have:
			parts.append("%d %s (you have %d)" % [int(need[k]), Project.need_name(str(k)), Project.have_of(str(k))])
		else:
			parts.append("%d %s" % [int(need[k]), Project.need_name(str(k))])
	return ", ".join(parts)


static func _status(id: String) -> String:
	var c: Dictionary = data()[id]
	var s := st(id)
	var bits: Array = []
	bits.append("%s %d/%d" % [str(c["foe_word"]), mini(int(s["kills"]), int(c["kills"])), int(c["kills"])])
	bits.append("beacons %d/%d" % [(s["beacons"] as Dictionary).size(), int(c.get("beacons", 3))])
	bits.append("supplies ✓" if bool(s["gave"]) else "supplies ✗")
	return "Still to do: " + ", ".join(bits) + ". Then come to the star crystal."


static func ready_to_wake(id: String) -> bool:
	var c: Dictionary = data()[id]
	var s := st(id)
	return bool(s["gave"]) and int(s["kills"]) >= int(c["kills"]) and (s["beacons"] as Dictionary).size() >= int(c.get("beacons", 3))


static func _crystal(m: GameMap, id: String) -> void:
	var c: Dictionary = data()[id]
	var s := st(id)
	if bool(s["done"]):
		await m.say([{"text": str(c["crystal_after"])}])
		return
	if not ready_to_wake(id):
		await m.say([{"text": str(c["crystal_dim"]) + "\n" + _status(id)}])
		return
	if m.has_meta("colony_boss"):
		if m.enemies.any(func(e: Variant) -> bool: return is_instance_valid(e) and (e as Node).has_meta("colony_boss")):
			return
		m.remove_meta("colony_boss")  # the boss left without dying: let the crystal work again
	await m.say([{"text": str(c["crystal_wake"])}])
	var spot := m.player.position + Vector2(0, -40)
	for r in [40.0, 56.0, 28.0, 72.0]:
		var found := false
		for ang in [-PI / 2, 0.0, PI, PI / 2, -PI / 4, -3 * PI / 4]:
			var cand: Vector2 = m.player.position + Vector2(cos(ang), sin(ang)) * r
			var cc := m.world_to_cell(cand)
			if not m.blocked.has(cc) and not m.is_water_cell(cc):
				spot = cand
				found = true
				break
		if found:
			break
	var b := m.spawn_enemy(str(c["boss"]), spot)
	if b:
		b.set_meta("colony_boss", id)
		b.set_meta("boss_name", str(c["boss_name"]))
		m.set_meta("colony_boss", true)
		m.boss_card(str(c["boss"]), str(c["boss_name"]))
		Music.instance(m.get_tree()).play(m.boss_music)


## From GameMap.on_enemy_died.
static func on_kill(m: GameMap, e: Enemy) -> void:
	var rid := m.scene_id()
	if not data().has(rid):
		return
	var s := st(rid)
	if e.has_meta("colony_boss"):
		m.remove_meta("colony_boss")
		await _restore(m, rid)
		return
	var kinds: Array = data()[rid].get("foe_kinds", [])
	if not e.has_meta("colony_foe") and not kinds.has(e.kind):
		return  # only the foes the elder named count
	s["kills"] = int(s["kills"]) + 1
	sync_quest(rid)
	var need := int(data()[rid]["kills"])
	if int(s["kills"]) == need:
		m.hud.toast("The %s are driven off." % str(data()[rid]["foe_word"]).to_lower(), Color(0.7, 1, 0.8))
		if data()[rid].has("kills_line"):
			m.tell([{"text": str(data()[rid]["kills_line"])}])


static func _restore(m: GameMap, id: String) -> void:
	var c: Dictionary = data()[id]
	var s := st(id)
	s["done"] = true
	GameState.add_arc_xp(120)
	GameState.complete_quest("colony_" + id)
	GameState.run["flags"]["colony_" + str(c["ability"])] = true
	GameState.run["flags"][id + "_done"] = true  # C7: finale/epilogue key per colony
	GameState.add_item("colony_light", 1)
	for sp in c.get("spells", []):
		GameState.run["skills"]["magic"] = GameState.run["skills"].get("magic", {"level": 1, "xp": 0, "nodes": {}})
		var gn: Dictionary = GameState.run.get("gift_nodes", {})
		if int(GameState.run["skills"]["magic"]["nodes"].get(str(sp), 0)) > 0 and not gn.has("magic|" + str(sp)):
			GameState.notify("You already knew %s: its Sorcery point came back." % str(GameState.node("magic", str(sp)).get("name", sp)))
		gn["magic|" + str(sp)] = 1  # always the colony's gift: a learned rank's point comes back, and a reset keeps it
		GameState.run["gift_nodes"] = gn
		GameState.run["skills"]["magic"]["nodes"][str(sp)] = maxi(1, int(GameState.run["skills"]["magic"]["nodes"].get(str(sp), 0)))
	if int(c.get("mana", 0)) > 0:
		GameState.grow_vital("mana", int(c["mana"]))
	m.fx("levelup", m.player.position + Vector2(0, -16), 12.0, 1.0)
	Music.instance(m.get_tree()).sfx("quest_done", "levelup")
	m.shake(3.0)
	Music.instance(m.get_tree()).play(m.music_track)
	var lines: Array = [{"text": str(c["crystal_restored"])}]
	lines.append_array(_lines(str(c["elder"]), c.get("reveal", [])))
	lines.append({"who": str(c["elder"]), "text": str(c["thanks"])})
	lines.append({"text": "New ability: %s. %s" % [str(c["ability_name"]), str(c["ability_desc"])]})
	var cr: Dictionary = c.get("creature", {}) if c.get("creature", null) is Dictionary else {}
	if str(cr.get("species", "")) != "":  # C11b P3: a creature comes home (waits for room; a letter says what's needed)
		lines.append({"who": str(c["elder"]), "text": str(cr.get("line", ""))})
		RanchGift.give(str(cr["species"]), "colony:" + id, {"giver": str(c["elder"])})
	var star: Array = ["One colony glowing again. I felt it from your field, like a window lighting up across the sea.",
		"Two lights out on the water now. They're humming the same tune. I think I used to know it.",
		"Three. One more, and the old song will be whole again.",
		"Four colonies, four lights. I can feel them all the way from your field. The Dark Crystal can feel them too, and it's afraid."]
	var n := saved()
	if n >= 1 and n <= 4:
		lines.append({"who": "Star Crystal", "text": star[n - 1]})
	await m.say(lines)
	GameState.save()
	# Reload the region so the lit crystal, open stall and cleared blight show now.
	if m.player:
		m.go_to(m.scene_id(), m.player.position - m.offset(), "down")


static func _shop(m: GameMap, id: String) -> void:
	var c: Dictionary = data()[id]
	if not bool(st(id)["done"]):
		await m.say([{"who": str(c["shop_who"]), "text": "Shop's shut while the crystal's dim. Help us first?"}])
		return
	await Shops.stall(m, str(c["shop_who"]), "For a friend of the colony.", c["shop"], GameState.bonus("harmony", "colony_discount"))  # C8 P6 hook


static func _take(k: String, n: int) -> void:
	if k == "#fish":
		# Cheapest first, locked fish never.
		var ids: Array = GameState.run["inventory"].keys().filter(func(x: Variant) -> bool: return not GameState.is_locked(str(x)))
		ids.sort_custom(func(a: Variant, b: Variant) -> bool: return GameState.item_value(str(a)) < GameState.item_value(str(b)))
		for id in ids:
			if n <= 0:
				return
			if str(GameState.items.get(id, {}).get("type", "")) == "fish":
				var t := mini(n, int(GameState.run["inventory"][id]))
				GameState.add_item(str(id), -t)
				n -= t
		return
	GameState.take_any(k, n)

class_name TeamAnimals
## Team animals (CONDUCT 11a P4). A raised ranch animal (Ranch roster uid) that is grown and trusts
## you (Ranch "friend" >= rules.bond_to_train) learns lessons (fetch / guard / carry / attack), one a
## day for a treat and some energy; with a lesson learned it can join the team (Ranch "team" flag):
## it musters for campaign battles (CampaignGate.team kind "animal", drawn from its own strip by
## HelperUnit.make_team) and takes farm chores (Chores, data/helpers.json).
## Data: data/team_animals.json from tools/gen_team_animals.py (edit that).
## Per-animal training state lives on the Ranch animal dict: "lessons" {id: count}, "lesson_day",
## "team" (bool, Ranch contract). Nothing here ever hurts an animal: a downed one rests till morning.

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/team_animals.json", FileAccess.READ)
		if f:
			var v: Variant = JSON.parse_string(f.get_as_text())
			if v is Dictionary:
				_data = v
		for k in ["rules", "lessons", "species", "aliases", "names"]:
			if not _data.has(k):
				_data[k] = [] if k == "names" else {}
	return _data


static func rule(key: String, dflt: Variant = 0) -> Variant:
	return (data()["rules"] as Dictionary).get(key, dflt)


static func lesson(id: String) -> Dictionary:
	return (data()["lessons"] as Dictionary).get(id, {})


## The training species key for a ranch animal (aliases cover babies/coat strips), or "".
static func species_key(uid: String) -> String:
	var a := Ranch.animal(uid)
	if a.is_empty():
		return ""
	var sp := str(a.get("species", ""))
	var tbl: Dictionary = data()["species"]
	if tbl.has(sp):
		return sp
	var al: Dictionary = data()["aliases"]
	if al.has(sp):
		return str(al[sp])
	var grp := str(Ranch.species(sp).get("group", ""))
	if tbl.has(grp):
		return grp
	return str(al.get(grp, ""))


static func spec(uid: String) -> Dictionary:
	return (data()["species"] as Dictionary).get(species_key(uid), {})


static func trainable(uid: String) -> bool:
	return not (spec(uid).get("lessons", []) as Array).is_empty()


static func name_of(uid: String) -> String:
	var a := Ranch.animal(uid)
	return str(a.get("name", "")) if str(a.get("name", "")) != "" else species_name(uid)


static func species_name(uid: String) -> String:
	var s := spec(uid)
	if s.is_empty():
		return str(Ranch.species(str(Ranch.animal(uid).get("species", ""))).get("name", "Animal"))
	return str(s.get("name_gang" if not GameState.is_penguins() else "name", s.get("name", "Animal")))


static func _day() -> int:
	return int(GameState.run.get("day", 1))


static func grown(uid: String) -> bool:
	var a := Ranch.animal(uid)
	if a.is_empty():
		return false
	if a.has("adult_day"):
		return _day() >= int(a["adult_day"])
	return _day() >= int(a.get("born_day", 1)) + int(rule("grown_days", 7))


static func bond(uid: String) -> int:
	return int(Ranch.animal(uid).get("friend", 0))


## Hearts 0..10 (100 friendship points a heart, Ranch scale).
static func hearts(uid: String) -> int:
	return clampi(bond(uid) / 100, 0, 10)


static func lessons(uid: String) -> Dictionary:
	var a := Ranch.animal(uid)
	if a.is_empty():
		return {}
	if not (a.get("lessons", null) is Dictionary):
		a["lessons"] = {}
	return a["lessons"]


## Rank 0..max_rank of one lesson (rank_at = lessons needed for each rank).
static func rank(uid: String, lid: String) -> int:
	var n := int(lessons(uid).get(lid, 0))
	var r := 0
	for need in (rule("rank_at", [3, 5, 7]) as Array):
		if n >= int(need):
			r += 1
	if n > 0:
		r = maxi(r, 1)  # the first lesson already teaches it at rank 1
	return mini(r, int(rule("max_rank", 3)))


static func learned(uid: String) -> Array:
	var out: Array = []
	for lid: String in lessons(uid):
		if rank(uid, lid) > 0:
			out.append(lid)
	out.sort()
	return out


static func can_learn(uid: String, lid: String) -> bool:
	return lid in (spec(uid).get("lessons", []) as Array)


static func treat_for(uid: String) -> String:
	for t in (spec(uid).get("treat", []) as Array):
		if GameState.count(str(t)) > 0:
			return str(t)
	return ""


## Why this animal can't take a lesson today ("" = it can).
static func why_not(uid: String, lid := "") -> String:
	if Ranch.animal(uid).is_empty():
		return "That animal isn't on your ranch."
	if GameState.visiting():
		return "Those animals belong to your host."
	if not trainable(uid):
		return "%s are happiest at home: they don't learn team lessons." % species_name(uid)
	if not grown(uid):
		return "Still little: wait until it's grown."
	var need := int(rule("bond_to_train", 200))
	if bond(uid) < need:
		return "Build its trust first: ♥%d of %d. Pet and feed it every day." % [hearts(uid), need / 100]
	if lid != "":
		if not can_learn(uid, lid):
			return "%s can't learn %s." % [species_name(uid), str(lesson(lid).get("name", lid))]
		if rank(uid, lid) >= int(rule("max_rank", 3)) and int(lessons(uid).get(lid, 0)) >= int((rule("rank_at", [7]) as Array).back()):
			return "It knows %s by heart already." % str(lesson(lid).get("name", lid))
	if int(Ranch.animal(uid).get("lesson_day", -1)) == _day():
		return "One lesson a day: it's had today's."
	if treat_for(uid) == "":
		var t: Array = spec(uid).get("treat", [])
		return "Bring a treat: %s." % " or ".join(t.map(func(x: Variant) -> String: return GameState.item_name(str(x))))
	if int(GameState.run.get("energy", 0)) < int(rule("energy", 8)):
		return "You're too tired to teach today."
	return ""


## One lesson: a treat, energy, friendship; returns the line to show.
static func teach(uid: String, lid: String) -> String:
	var why := why_not(uid, lid)
	if why != "":
		return why
	var a := Ranch.animal(uid)
	var before := rank(uid, lid)
	var t := treat_for(uid)
	GameState.add_item(t, -1)
	GameState.run["energy"] = maxi(0, int(GameState.run["energy"]) - int(rule("energy", 8)))
	lessons(uid)[lid] = int(lessons(uid).get(lid, 0)) + 1
	a["lesson_day"] = _day()
	a["friend"] = mini(1000, int(a.get("friend", 0)) + int(rule("bond_per_lesson", 20)))
	var nm := name_of(uid)
	var ln := str(lesson(lid).get("name", lid))
	var after := rank(uid, lid)
	if after > before:
		return "%s learned %s (rank %d)!" % [nm, ln, after] if before == 0 else "%s's %s is rank %d now!" % [nm, ln, after]
	var at: Array = rule("rank_at", [3, 5, 7])
	var left := 0
	for need in at:
		if int(lessons(uid)[lid]) < int(need):
			left = int(need) - int(lessons(uid)[lid])
			break
	return "%s practised %s. %d more lesson%s to the next rank." % [nm, ln, left, "" if left == 1 else "s"]


# ---- the team ----------------------------------------------------------------------

static func on_team(uid: String) -> bool:
	return bool(Ranch.animal(uid).get("team", false))


static func team() -> Array:
	var out: Array = []
	for uid: String in Ranch.animals():
		if on_team(uid):
			out.append(uid)
	out.sort()
	return out


static func why_not_team(uid: String) -> String:
	if Ranch.animal(uid).is_empty():
		return "That animal isn't on your ranch."
	if GameState.visiting():
		return "Those animals belong to your host."
	if learned(uid).is_empty():
		return "Teach it a lesson first."
	if not on_team(uid) and team().size() >= int(rule("team_max", 2)):
		return "The team has room for %d animals." % int(rule("team_max", 2))
	return ""


## Put on / take off the team. Returns "" on success, else why not.
static func set_team(uid: String, on: bool) -> String:
	if on:
		var why := why_not_team(uid)
		if why != "":
			return why
	elif Ranch.animal(uid).is_empty():
		return "That animal isn't on your ranch."
	Ranch.animal(uid)["team"] = on
	if not on:
		Chores.unassign("animal:" + uid)
	return ""


## Battle/follower numbers: species base + lesson ranks + tier, kept under the pup's at equal tier.
static func stats(uid: String) -> Dictionary:
	var s := spec(uid)
	var hp := int(s.get("hp", 14)) + int(rule("hp_per_tier", 6)) * GameState.progress_tier()
	var dmg := int(s.get("dmg", 1))
	for lid: String in learned(uid):
		var l := lesson(lid)
		hp += int(l.get("hp", 0)) * rank(uid, lid)
		dmg += int(l.get("dmg", 0)) * rank(uid, lid)
	hp += int(GameState.bonus("leadership", "pet_bond"))
	var pup_hp := Pet.max_hp() + int(rule("hp_per_tier", 6)) * GameState.progress_tier()
	hp = mini(hp, pup_hp - int(rule("pup_margin", 4)))
	return {"hp": maxi(8, hp), "dmg": maxi(1, dmg), "speed": float(s.get("speed", 1.0))}


## Battle job from its best lesson (attack > guard > carry > fetch by rank).
static func battle_job(uid: String) -> String:
	var best := ""
	var br := -1
	for lid in ["attack", "guard", "carry", "fetch"]:
		var r := rank(uid, lid)
		if r > br and r > 0:
			best = lid
			br = r
	return str(lesson(best).get("job", "striker")) if best != "" else "striker"


## Chores this animal may take (its lessons open them; WORKERS.animal is the outer limit).
static func chores_for(uid: String) -> Array:
	var out: Array = []
	for lid: String in learned(uid):
		var c := str(lesson(lid).get("chore", ""))
		if c != "" and not c in out:
			out.append(c)
	return out


## The art group of this animal ("animals/<strip>"), adult strip when grown.
static func sprite_group(uid: String) -> String:
	var a := Ranch.animal(uid)
	var sp := str(a.get("species", ""))
	var art: Dictionary = Ranch.species(sp).get("art", {})
	var cands: Array = []
	var ra := Ranch.art_for(uid)  # the roster look (variant art, baby strip): P6 team poses live on these kinds
	if not bool(ra.get("baby", false)) and str(ra.get("group", "")) != "" and Art.has(str(ra["group"]), "idle"):
		return str(ra["group"])
	var v := str(a.get("variant", ""))
	if art.has("adult"):
		if v != "":
			cands.append(str(art["adult"]) + "_" + v)
		cands.append(str(art["adult"]))
	cands.append(sp)
	cands.append(species_key(uid))
	for c in cands:
		if c != "" and Art.has("animals/" + str(c), "idle"):
			return "animals/" + str(c)
	return ""


## One view of the whole team (the API later automation targets): the pup slot, the partner slot
## (Companion.active_id), the animal slots (team()) and the battle muster (CampaignGate.team()).
static func slots() -> Dictionary:
	return {"pup": Pet.name_of(), "partner": Companion.active_id(), "animals": team(),
		"animal_max": int(rule("team_max", 2)), "muster": CampaignGate.team()}


## CampaignGate.team rows: [id, name, "animal"] for every team animal.
static func gate_rows() -> Array:
	var out: Array = []
	if GameState.run.is_empty():
		return out
	for uid: String in team():
		out.append(["animal:" + uid, name_of(uid), "animal"])
	return out


static func rename(uid: String, nm: String) -> bool:
	var t := nm.strip_edges().left(14)
	if t == "" or Ranch.animal(uid).is_empty():
		return false
	Ranch.animal(uid)["name"] = t
	return true


## A fresh default name (data names list), skipping names already on the ranch.
static func suggest_name(uid: String) -> String:
	var used := {}
	for u: String in Ranch.animals():
		used[str(Ranch.animal(u).get("name", ""))] = true
	var names: Array = data()["names"]
	if names.is_empty():
		return species_name(uid)
	var start := absi(hash(uid)) % names.size()
	for i in names.size():
		var n := str(names[(start + i) % names.size()])
		if not used.has(n):
			return n
	return str(names[start])


## Rehome (no animal is ever sold for meat): takes it off the team and its chores first.
static func rehome(uid: String) -> bool:
	if Ranch.animal(uid).is_empty() or GameState.visiting():
		return false
	Chores.unassign("animal:" + uid)
	return Ranch.rehome(uid)


# ---- Animals page (Menu > Party > Animals) -----------------------------------------

static var _rename_uid := ""
static var _rehome_arm := ""
static var _sel := ""


static func _hearts_text(n: int) -> String:
	return "♥".repeat(n) + "♡".repeat(maxi(0, 10 - n)) if n > 0 else "♡♡♡♡♡♡♡♡♡♡"


## Builds the page into the open GameMenu (menu._line/_button/_refresh/_toast).
static func build_page(menu: Variant) -> void:
	menu._line("Animals", 10, Color(1, 0.95, 0.8))
	var all: Array = Ranch.animals().keys()
	all.sort()
	if all.is_empty():
		menu._line("  No animals yet. Build a coop or barn on the farm and buy or raise one.", 8, Color(0.7, 0.7, 0.7))
		menu._button("Back to Party", func() -> void: menu._tab = "Party"; menu._refresh())
		return
	menu._line("Team: %d of %d  ·  tap an animal for lessons, name and team" % [team().size(), int(rule("team_max", 2))], 8, Color(0.85, 0.85, 0.8))
	for uid: String in all:
		var u := uid
		var tag := " ★" if on_team(u) else ""
		var b: Button = menu._button("%s%s  %s  %s" % ["▶ " if _sel == u else "", name_of(u) + tag, species_name(u), _hearts_text(hearts(u))], func() -> void:
			_sel = "" if _sel == u else u
			_rename_uid = ""
			_rehome_arm = ""
			menu._refresh())
		b.set_meta("pc_key", "animals:" + u)
		if _sel == u:
			_detail(menu, u)
	menu._button("Back to Party", func() -> void: _sel = ""; menu._tab = "Party"; menu._refresh())


static func _detail(menu: Variant, uid: String) -> void:
	var a := Ranch.animal(uid)
	var home := str(a.get("home", ""))
	var age := "grown" if grown(uid) else "little"
	menu._line("  Lives in the %s · %s · friendship %d" % [home if home != "" else "pen", age, bond(uid)], 8, Color(0.8, 0.85, 0.9))
	if trainable(uid):
		var ls: Array = []
		for lid in (spec(uid).get("lessons", []) as Array):
			ls.append("%s %s" % [str(lesson(str(lid)).get("name", lid)), ("rank %d" % rank(uid, str(lid))) if rank(uid, str(lid)) > 0 else "—"])
		menu._line("  Lessons: " + ", ".join(ls), 8, Color(0.85, 0.9, 0.8))
		var st := stats(uid)
		if not learned(uid).is_empty():
			menu._line("  Health %d · power %d · in battle: %s" % [int(st["hp"]), int(st["dmg"]), battle_job(uid)], 8, Color(0.8, 0.85, 0.9))
		for lid in (spec(uid).get("lessons", []) as Array):
			var l := str(lid)
			var why := why_not(uid, l)
			var tb: Button = menu._button("  Teach %s%s" % [str(lesson(l).get("name", l)), "" if why == "" else " (not now)"], func() -> void:
				menu._toast(teach(uid, l))
				menu._refresh())
			tb.set_meta("pc_key", "animals:%s:t:%s" % [uid, l])
			if why != "":
				tb.tooltip_text = why
		var why_today := why_not(uid)
		if why_today != "":
			menu._line("  " + why_today, 8, Color(1, 0.85, 0.6))
		var tw := why_not_team(uid)
		var label := "  Take off the team" if on_team(uid) else ("  Put on the team" + ("" if tw == "" else " (not yet)"))
		var tmb: Button = menu._button(label, func() -> void:
			var r := set_team(uid, not on_team(uid))
			menu._toast(r if r != "" else ("%s joined the team." % name_of(uid) if on_team(uid) else "%s is back to pen life." % name_of(uid)))
			menu._refresh())
		tmb.set_meta("pc_key", "animals:%s:team" % uid)
	else:
		menu._line("  A homebody: no team lessons, but it still loves a pat.", 8, Color(0.75, 0.75, 0.7))
	if _rename_uid == uid:
		var row := HBoxContainer.new()
		menu._body.add_child(row)
		var le := LineEdit.new()
		le.text = name_of(uid)
		le.max_length = 14
		le.custom_minimum_size = Vector2(150, 22)
		le.add_theme_font_size_override("font_size", Settings.font(8))
		row.add_child(le)
		var ok := Button.new()
		ok.text = "OK"
		ok.custom_minimum_size = Vector2(40, 22)
		ok.pressed.connect(func() -> void:
			if rename(uid, le.text):
				menu._toast("Say hello to %s." % name_of(uid))
			_rename_uid = ""
			menu._refresh())
		row.add_child(ok)
		le.text_submitted.connect(func(_t: String) -> void: ok.pressed.emit())
		var sug: Button = menu._button("  Pick a name for me (%s)" % suggest_name(uid), func() -> void:
			rename(uid, suggest_name(uid))
			_rename_uid = ""
			menu._refresh())
		sug.set_meta("pc_key", "animals:%s:sug" % uid)
	else:
		var rb: Button = menu._button("  Rename", func() -> void: _rename_uid = uid; menu._refresh())
		rb.set_meta("pc_key", "animals:%s:rename" % uid)
	var arm := _rehome_arm == uid
	var hb: Button = menu._button("  Sure? %s goes to a villager farm for good" % name_of(uid) if arm else "  Rehome…", func() -> void:
		if _rehome_arm != uid:
			_rehome_arm = uid
		else:
			var nm := name_of(uid)
			if rehome(uid):
				menu._toast("%s has a happy new home on a villager's farm." % nm)
			_rehome_arm = ""
			_sel = ""
		menu._refresh())
	hb.set_meta("pc_key", "animals:%s:rehome" % uid)

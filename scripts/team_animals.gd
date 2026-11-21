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
		var rs := Ranch.species(str(Ranch.animal(uid).get("species", "")))
		return str(rs.get("name_gang" if not GameState.is_penguins() else "name", rs.get("name", "Animal")))
	return str(s.get("name_gang" if not GameState.is_penguins() else "name", s.get("name", "Animal")))


## C12 (c12_14-02/04/15/17): player words for homes, where-from lines and battle jobs.
const JOB_WORDS := {"striker": "charges foes", "healer": "mends you", "warden": "shields you"}


static func job_words(job: String) -> String:
	return str(JOB_WORDS.get(job, job))


## The built tier's name of a home ("Tide Pool", "Big Barn"; gangster words via Builds), never a raw id.
static func home_word(home: String) -> String:
	if home == "":
		return "pen"
	var td := Builds.tier_def(home, maxi(1, Builds.built_tier(home)))
	var nm := str(td.get("name", ""))
	return nm if nm != "" else home.replace("_", " ").capitalize()


static func home_name(uid: String) -> String:
	var home := str(Ranch.animal(uid).get("home", ""))
	if home == "":
		home = str(Ranch.species(str(Ranch.animal(uid).get("species", ""))).get("home", ""))
	return home_word(home)


## Where the creature comes from (gen_ranch source / source_gang), "" for plain farm animals.
static func source_line(uid: String) -> String:
	var rs := Ranch.species(str(Ranch.animal(uid).get("species", "")))
	return str(rs.get("source_gang", rs.get("source", "")) if not GameState.is_penguins() else rs.get("source", ""))


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
	for need in (rule("rank_at", [1, 4, 7]) as Array):  # c11b_09-05: rank 1 on the first lesson
		if n >= int(need):
			r += 1
	return mini(r, int(rule("max_rank", 3)))


## Lessons still needed to the next rank of a lesson (0 = mastered).
static func lessons_left(uid: String, lid: String) -> int:
	var n := int(lessons(uid).get(lid, 0))
	var at: Array = rule("rank_at", [1, 4, 7])
	var r := rank(uid, lid)
	if r >= at.size() or r >= int(rule("max_rank", 3)):
		return 0
	return maxi(0, int(at[r]) - n)


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
		return "%s is a homebody: happiest in the %s, no team lessons." % [name_of(uid), home_name(uid)]
	if not grown(uid):
		return "Still little: wait until it's grown."
	var need := int(rule("bond_to_train", 200))
	if bond(uid) < need:
		return "Build its trust first: ♥%d of %d. Pet and feed it every day." % [hearts(uid), need / 100]
	if lid != "":
		if not can_learn(uid, lid):
			return "%s can't learn %s." % [name_of(uid), str(lesson(lid).get("name", lid))]
		if rank(uid, lid) >= int(rule("max_rank", 3)) and int(lessons(uid).get(lid, 0)) >= int((rule("rank_at", [7]) as Array).back()):
			return "It knows %s by heart already." % str(lesson(lid).get("name", lid))
	if int(Ranch.animal(uid).get("lesson_day", -1)) == _day():
		return "One lesson a day: it's had today's."
	if treat_for(uid) == "":
		var t: Array = spec(uid).get("treat", [])
		var tw: Array = t.map(func(x: Variant) -> String: return ItemWords.with_article(GameState.item_name(str(x))))
		return "Bring a treat: %s." % (", ".join(tw.slice(0, tw.size() - 1)) + " or " + str(tw.back()) if tw.size() > 1 else (str(tw[0]) if tw.size() == 1 else "a treat"))
	if int(GameState.run.get("energy", 0)) <= 0:  # C16a P3: spend_for("teach") works until 0
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
	if not GameState.spend_for("teach"):  # C16a P3: ENERGY_COST teach, ranching-discounted (was a flat rule 8)
		return "You're too tired to teach today."
	GameState.add_item(t, -1)
	lessons(uid)[lid] = int(lessons(uid).get(lid, 0)) + 1
	a["lesson_day"] = _day()
	a["friend"] = mini(1000, int(a.get("friend", 0)) + int(rule("bond_per_lesson", 20)))
	var nm := name_of(uid)
	var ln := str(lesson(lid).get("name", lid))
	var after := rank(uid, lid)
	if after > before:
		return "%s learned %s (rank %d)!" % [nm, ln, after] if before == 0 else "%s's %s is rank %d now!" % [nm, ln, after]
	var left := lessons_left(uid, lid)
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
	if not on_team(uid) and team().size() >= team_max():
		return "The team has room for %d animals." % team_max()
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
	# c11b_09-03: lesson growth stays under the pup's real max hp; C16a P6 (c16a_13-16): the species'
	# own base at this tier always counts, so a weak pup no longer shrinks a trained llama.
	var base_hp := int(s.get("hp", 14)) + int(rule("hp_per_tier", 6)) * GameState.progress_tier()
	hp = mini(hp, maxi(base_hp, Pet.max_hp() - int(rule("pup_margin", 4))))
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


## The variant tint of this animal (Color, or white): rare tints show on the team too (c11b_09-06).
static func tint(uid: String) -> Color:
	var t: Variant = Ranch.art_for(uid).get("tint", null)
	return t if t is Color else Color.WHITE


## One view of the whole team (the API later automation targets): the pup slot, the partner slot
## (Companion.active_id), the animal slots (team()) and the battle muster (CampaignGate.team()).
static func slots() -> Dictionary:
	return {"pup": Pet.name_of(), "partner": Companion.active_id(), "animals": team(),
		"animal_max": team_max(), "muster": CampaignGate.team()}


## CampaignGate.team rows: [id, name, "animal"] for every team animal.
static func gate_rows() -> Array:
	var out: Array = []
	if GameState.run.is_empty():
		return out
	for uid: String in team():
		out.append(["animal:" + uid, name_of(uid), "animal"])
	return out


## c11b_11-09: one rename path (Ranch.rename: cleaning, 12 letters, "named").
static func rename(uid: String, nm: String) -> bool:
	return Ranch.rename(uid, nm)


## A fresh default name from the animal's species list (Ranch), else the team list.
static func suggest_name(uid: String) -> String:
	var sid := str(Ranch.animal(uid).get("species", ""))
	if sid != "" and not (Ranch.species(sid).get("names", []) as Array).is_empty():
		var pick := Ranch._pick_name(sid)
		if pick != Ranch.display_name(sid):
			return pick
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


# ---- CHECK on a farm animal (c11b_09-13) -------------------------------------------

## CHECK (the hand) on a trainable ranch animal: Teach <lesson> / Team / Pet / Close. Returns true
## when it took the press (GameMap.try_interact). USE still pets it as before.
static func check_menu(m: GameMap, thing: Dictionary) -> bool:
	if str(thing.get("type", "")) != "pet_animal" or GameState.visiting():
		return false
	var a: Variant = thing.get("animal", null)
	if a == null or not is_instance_valid(a):
		return false
	var uid := RanchFarm.uid_of(a)
	if uid == "" or not trainable(uid):
		return false
	_check_dialog(m, a, uid)
	return true


static func _check_dialog(m: GameMap, a: Node2D, uid: String) -> void:
	var opts: Array = []
	var acts: Array = []
	for lid in (spec(uid).get("lessons", []) as Array):
		var l := str(lid)
		opts.append("Teach %s · %s" % [str(lesson(l).get("name", l)), lesson_note(uid, l)])
		acts.append(["teach", l])
	if not learned(uid).is_empty():
		opts.append("Take off the team" if on_team(uid) else "Put on the team")
		acts.append(["team", ""])
	opts.append("Pet")
	acts.append(["pet", ""])
	opts.append("Close")
	acts.append(["close", ""])
	var why := why_not(uid)
	var d := Dialogue.instance(m.get_tree())
	d.say([{"who": name_of(uid), "text": "%s · %s%s" % [species_name(uid), _hearts_text(hearts(uid)), "" if why == "" else "\n" + why], "choice": opts, "key": ""}])
	await d.finished
	var i := d.last_choice
	if i < 0 or i >= acts.size() or not is_instance_valid(a):
		return
	match str(acts[i][0]):
		"teach":
			m.hud.toast(teach(uid, str(acts[i][1])), Color(0.85, 1, 0.85))
		"team":
			var r := set_team(uid, not on_team(uid))
			m.hud.toast(r if r != "" else ("%s joined the team." % name_of(uid) if on_team(uid) else "%s is back to pen life." % name_of(uid)), Color(0.85, 1, 0.85))
		"pet":
			m.pet_farm_animal(a)


## One-time hint that training exists (the first time an animal can learn): a toast, once a save.
static func hint_once(m: GameMap, uid: String) -> void:
	var f: Dictionary = GameState.run.get("flags", {})
	if f.has("team_hint") or not trainable(uid) or why_not(uid).begins_with("Build") or not grown(uid):
		return
	f["team_hint"] = true
	if m != null and m.hud:
		m.hud.toast("%s trusts you now: CHECK it to teach a lesson." % name_of(uid), Color(0.9, 1, 0.8))


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
	all.sort_custom(func(x: String, y: String) -> bool:  # c11b_11-10: by home, then species, then number
		var ax := Ranch.animal(x)
		var ay := Ranch.animal(y)
		var hx := str(ax.get("home", ""))
		var hy := str(ay.get("home", ""))
		if hx != hy:
			return hx < hy
		var sx := str(ax.get("species", ""))
		var sy := str(ay.get("species", ""))
		if sx != sy:
			return sx < sy
		return x.substr(1).to_int() < y.substr(1).to_int())
	if all.is_empty():
		menu._line("  No animals yet. Build a coop or barn on the farm and buy or raise one.", 8, Color(0.7, 0.7, 0.7))
		menu._button("Back to Party", func() -> void: menu._tab = "Party"; menu._refresh())
		return
	menu._line("Team: %d of %d  ·  tap an animal for lessons, name and team" % [team().size(), team_max()], 8, Color(0.85, 0.85, 0.8))
	var last_home := "?"
	for uid: String in all:
		var u := uid
		var hm := str(Ranch.animal(u).get("home", ""))
		if hm != last_home:
			last_home = hm
			menu._line("%s · %d of %d" % [(hm if hm != "" else "pen").capitalize(), Ranch.roster(hm).size(), Ranch.capacity(hm)] if hm != "" else "Pen", 9, Color(0.9, 0.85, 0.7))
		var tag := " ★" if on_team(u) else ""
		var b: Button = menu._button("%s%s  %s  %s" % ["▶ " if _sel == u else "", name_of(u) + tag, Ranch.variant_name(u) + (" ✦" if Ranch.is_rare(u) else ""), _hearts_text(hearts(u))], func() -> void:
			_sel = "" if _sel == u else u
			_rename_uid = ""
			_rehome_arm = ""
			menu._refresh())
		b.set_meta("pc_key", "animals:" + u)
		if _sel == u:
			_detail(menu, u)
	menu._button("Back to Party", func() -> void: _sel = ""; menu._tab = "Party"; menu._refresh())


## The short note after a Teach button (c11b_09-16: shown, not a tooltip a phone never shows).
static func lesson_note(uid: String, lid: String) -> String:
	var r := rank(uid, lid)
	if r >= int(rule("max_rank", 3)):
		return "rank %d (mastered)" % r
	var why := why_not(uid, lid)
	var left := lessons_left(uid, lid)
	var base := ("rank %d · %d more to rank %d" % [r, left, r + 1]) if r > 0 else "new"
	if why == "":
		return base
	if why.begins_with("One lesson a day"):
		return base + " · tomorrow"
	if why.begins_with("Bring a treat"):
		return base + " · needs a treat"
	if why.contains("tired"):
		return base + " · too tired"
	if why.contains("trust"):
		return "needs more trust"
	if why.contains("little"):
		return "when grown"
	return base


## What a lesson does, in this arc's words, plus the chore it opens and its battle job (c11b_09-10).
static func lesson_desc(lid: String) -> String:
	var l := lesson(lid)
	var d := str(l.get("desc" if GameState.is_penguins() else "desc_gang", l.get("desc", "")))
	var bits: Array = []
	var c := str(l.get("chore", ""))
	if c != "":
		bits.append("chore: " + Chores.chore_name(c).to_lower())
	bits.append("in battle: " + job_words(str(l.get("job", "striker"))))
	return "%s (%s)" % [d, ", ".join(bits)]


static func _detail(menu: Variant, uid: String) -> void:
	var a := Ranch.animal(uid)
	var home := str(a.get("home", ""))
	var age := "grown" if grown(uid) else "little"
	menu._line("  Lives in the %s · %s · ♥%d" % [home_name(uid), age, hearts(uid)], 8, Color(0.8, 0.85, 0.9))
	var src := source_line(uid)
	if src != "":
		menu._line("  From: " + src, 8, Color(0.8, 0.85, 0.9))
	menu.ranch_family_lines(uid)  # C11b P2 hook: born day, gen, parents, kids, expecting, habitat
	if trainable(uid):
		var ls: Array = []
		for lid in (spec(uid).get("lessons", []) as Array):
			if rank(uid, str(lid)) > 0:
				ls.append("%s rank %d" % [str(lesson(str(lid)).get("name", lid)), rank(uid, str(lid))])
		menu._line("  Lessons: " + (", ".join(ls) if not ls.is_empty() else "none yet"), 8, Color(0.85, 0.9, 0.8))
		var st := stats(uid)
		if not learned(uid).is_empty():
			menu._line("  Health %d · power %d · in battle: %s" % [int(st["hp"]), int(st["dmg"]), job_words(battle_job(uid))], 8, Color(0.8, 0.85, 0.9))
		for lid in (spec(uid).get("lessons", []) as Array):
			var l := str(lid)
			var tb: Button = menu._button("  Teach %s · %s" % [str(lesson(l).get("name", l)), lesson_note(uid, l)], func() -> void:
				menu._toast(teach(uid, l))
				menu._refresh())
			tb.set_meta("pc_key", "animals:%s:t:%s" % [uid, l])
			menu._line("    " + lesson_desc(l), 7, Color(0.75, 0.8, 0.75))
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
		le.max_length = 12
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
		var sug: Button = menu._button("  Suggest a name: %s" % suggest_name(uid), func() -> void:
			rename(uid, suggest_name(uid))
			_rename_uid = ""
			menu._refresh())
		sug.set_meta("pc_key", "animals:%s:sug" % uid)
	else:
		var rb: Button = menu._button("  Rename", func() -> void: _rename_uid = uid; menu._refresh())
		rb.set_meta("pc_key", "animals:%s:rename" % uid)
	if bool(Ranch.animal(uid).get("keepsake", false)):
		menu._line("  %s is a keepsake: a gift that stays with you." % name_of(uid), 8, Color(0.85, 0.85, 0.75))
		return
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


## C16a P6 (c16a_13-07): team room grows: 2 at first, +1 at Leadership 25, +1 from story chapter 4
## (progress tier 3), so a bigger team is a season-2 / year-2 goal.
static func team_max() -> int:
	var n := int(rule("team_max", 2))
	if GameState.skill_level("leadership") >= 25:
		n += 1
	if GameState.progress_tier() >= 3:
		n += 1
	return n

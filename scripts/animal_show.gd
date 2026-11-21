extends RefCounted
## C11b P6: the fair ribbon tables (Animal Show, Ranch Goods, Best Egg, Fleece & Feather).
## Pure logic, called by Town (scripts/town.gd _animal_show) and tested by tools/animal_show_test.gd.
## Animals are judged on friendship (hearts), mood, product quality, variant and time grown;
## rivals are seeded by the day and get better every year (capped so a perfect rare animal still wins);
## a 4th place gets an honourable mention and no ribbon. All ages: animals go home after the show.

const YEAR_DAYS := 112
const YEAR_STEP := 10  # C16a P5 (c16a_06-13): 15 -> 10, a gold top-tier good keeps a real chance in years 1-5

## Categories per festival. Fields: kind (animal|good), title / title_gang, ask / ask_gang,
## host, goods (good tables), rivals [[who, entry (bare noun phrase), base score]], cap (best rival
## score ever), prizes [blue, red, yellow], mention (4th-place coins), beside (line verb).
const CATS := {
	"harvest": [
		{"id": "animals", "kind": "animal", "title": "Animal Show", "title_gang": "Stock Show",
			"ask": "Who are you showing? The judges look for a happy face, a fine coat and a friend who trusts you.",
			"ask_gang": "Who's going in the pen? Judges want a calm animal that trusts you and a coat that shines.",
			"rivals": [["Tam", "ram Big Dolly", 72], ["Benno", "grey mare Willow", 60], ["Hazel", "speckled hen Dot", 48], ["Mabel", "goat Pudding", 40], ["Posy", "duck Lady Waddles", 34]],
			"cap": 150, "prizes": [250, 120, 40], "mention": 10, "beside": "share the ring with"},
		{"id": "goods", "kind": "good", "title": "Ranch Goods table", "title_gang": "Goods table",
			"ask": "Which of your goods goes on the table? Freshness and a gold star count.",
			"ask_gang": "What are you putting on the table? Quality sells it.",
			"goods": ["egg", "duck_egg", "milk", "goat_milk", "sheep_wool", "rabbit_fur", "cheese", "goat_cheese", "honey", "truffle", "feather"],
			"rivals": [["Hazel", "brown eggs", 70], ["Benno", "fresh milk", 80], ["Tam", "wool bundle", 90], ["Mabel", "goat cheese", 60]],
			"family": "any", "cap": 260, "prizes": [150, 70, 25], "mention": 10, "beside": "sit on the table beside"},
	],
	"egg": [
		{"id": "eggs", "kind": "good", "title": "Best Egg table", "title_gang": "Best Egg table",
			"ask": "Which egg are you entering? Shape, shine and a gold star count.",
			"ask_gang": "Which egg goes up? Shape, shine and a gold star count.",
			"goods": ["egg", "duck_egg"],
			"rivals": [["Hazel", "brown egg", 40], ["Posy", "blue duck egg", 55], ["Mabel", "\"dinosaur\" egg", 30], ["Tam", "speckled egg", 45]],
			"family": "egg", "cap": 200, "prizes": [150, 70, 25], "mention": 10, "beside": "sit on the table beside"},
	],
	"lantern": [
		{"id": "fleece", "kind": "good", "title": "Fleece & Feather table", "title_gang": "Fleece & Feather table",
			"ask": "Wool, fur or feathers? Softness and a gold star count.",
			"ask_gang": "Wool, fur or feathers? Soft and clean wins.",
			"goods": ["sheep_wool", "rabbit_fur", "feather", "beeswax"],
			"rivals": [["Tam", "winter fleece", 85], ["Posy", "rabbit fur", 60], ["Hazel", "rooster feathers", 50]],
			"family": "fleece", "cap": 230, "prizes": [150, 70, 25], "mention": 10, "beside": "lie on the table beside"},
	],
}

## Which festivals carry a ribbon table: [cell, host]. Winter (Star Festival) has none.
const STANDS := {
	"harvest": [Vector2i(36, 40), "Benno"],
	"egg": [Vector2i(36, 36), "Posy"],
	"lantern": [Vector2i(36, 41), "Hazel"],
}

## Givers of gift animals (flag holding the uid -> [npc id, name, line]).
const GIVERS := {"tam_lamb_home": ["tam", "Tam", "Grown into the ears. Mostly. ...I'm proud of you both."]}


## Within 5 cells of today's ribbon stand (music: the animal_show tune there).
static func near_stand(fest: String, c: Vector2i) -> bool:
	var st: Array = STANDS.get(fest, [])
	return not st.is_empty() and Vector2(c - (st[0] as Vector2i)).length() <= 5.0


static func gang() -> bool:
	return not GameState.is_penguins()


static func cats(fest: String) -> Array:
	return CATS.get(fest, [])


static func cat(fest: String, cid: String) -> Dictionary:
	for c: Dictionary in cats(fest):
		if str(c["id"]) == cid:
			return c
	return {}


static func title(c: Dictionary) -> String:
	return str(c.get("title_gang" if gang() else "title", c.get("title", "")))


## Main title of a festival's stand (its first category).
static func stand_title(fest: String) -> String:
	var cs := cats(fest)
	return title(cs[0]) if not cs.is_empty() else ""


static func year() -> int:
	return (int(GameState.run.get("day", 1)) - 1) / YEAR_DAYS


static func done_key(fest: String, cid: String) -> String:
	return "fest_show_%s_%s_%d" % [fest, cid, int(GameState.run.get("day", 1))]


## Can this animal go to the show? Grown, and its species travels (bees, hives: no; species "show": false: no).
static func can_show(uid: String) -> bool:
	if not Ranch.is_adult(uid):
		return false
	var sp := Ranch.species(str(Ranch.animal(uid).get("species", "")))
	if sp.is_empty() or not bool(sp.get("show", true)):
		return false
	return str(sp.get("group", "")) != "insect"


## Judging an animal: hearts*16 (0..80) + mood/5 (0..20) + product quality (gold 25 / silver 12)
## + variant (rare 25, any non-first look 8) + days grown (max 10).
static func score_animal(uid: String) -> int:
	var a := Ranch.animal(uid)
	if a.is_empty():
		return 0
	var s := Ranch.hearts(uid) * 16 + int(a.get("mood", 0)) / 5
	var q := Ranch.quality(a)
	s += 25 if q == "g" else (12 if q == "s" else 0)
	var vr := Ranch.variant_row(uid)
	if bool(vr.get("rare", false)) or bool(vr.get("unique", false)):
		s += 25
	else:
		var vs: Array = (Ranch.species(str(a.get("species", ""))).get("art", {}) as Dictionary).get("variants", [])
		if not vs.is_empty() and vs[0] is Dictionary and str(a.get("variant", "")) != "" and str(a.get("variant", "")) != str((vs[0] as Dictionary).get("id", "")):
			s += 8
	var grown := int(GameState.run.get("day", 1)) - int(a.get("adult_day", 0))
	s += clampi(grown, 0, 10)
	return s


## Judging a good: its value plus the quality of the piece (30 iridium / 20 gold / 10 silver).
## C16a P5 (c16a_06-13): 40 + value^0.6 x 4, so exotic goods win but classics stay in the running early.
static func score_good(id: String, quality: int) -> int:
	return 40 + int(round(pow(float(maxi(0, GameState.item_value(id))), 0.6) * 4.0)) + quality * 2


## C16a P5 (c16a_06-13): a table's family takes every ranch good of that kind (exotic eggs, fleece, feathers).
static func fits_family(c: Dictionary, gid: String) -> bool:
	var fam := str(c.get("family", ""))
	if fam == "" or not Ranch.is_good(gid):
		return false
	if fam == "egg":
		return gid.ends_with("egg")
	if fam == "fleece":
		return gid.contains("wool") or gid.contains("fur") or gid.contains("feather") or gid.contains("fleece")
	return true


## This year's rivals for a category, seeded by the day (stable on reload), best first.
## Each [who, entry, score]; score = base + YEAR_STEP*year + jitter, never above cap.
static func rivals(fest: String, cid: String, day := -1) -> Array:
	var c := cat(fest, cid)
	var pool: Array = (c.get("rivals", []) as Array).duplicate(true).filter(func(r: Variant) -> bool: return not GameState.run.get("flags", {}).has(str((r as Array)[0]).to_lower() + "_gone"))  # C12 P3: nobody who left town enters
	if pool.is_empty():
		return []
	if day < 0:
		day = int(GameState.run.get("day", 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = day * 31 + cid.hash() % 997
	var yr := (day - 1) / YEAR_DAYS
	var out: Array = []
	while out.size() < 3 and not pool.is_empty():
		var r: Array = pool.pop_at(rng.randi() % pool.size())
		var sc := mini(int(r[2]) + YEAR_STEP * yr + rng.randi_range(-6, 6), int(c.get("cap", 999)))
		out.append([str(r[0]), str(r[1]), sc])
	out.sort_custom(func(x: Array, y: Array) -> bool: return int(x[2]) > int(y[2]))
	return out


## 1..3 for a ribbon, 4 = honourable mention.
static func place_for(score: int, rv: Array) -> int:
	var better := 0
	for r: Array in rv:
		if int(r[2]) > score:
			better += 1
	return better + 1


static func prize(c: Dictionary, place: int) -> int:
	if place >= 4:
		return int(c.get("mention", 10))
	return int((c.get("prizes", [0, 0, 0]) as Array)[place - 1])


## "Tam's ram Big Dolly and Benno's grey mare Willow share the ring with Bella."
static func ring_line(c: Dictionary, rv: Array, entry: String) -> String:
	if rv.size() < 2:
		return "%s takes its place." % entry
	var r0: Array = rv[0]
	var r1: Array = rv[1]
	return "%s's %s and %s's %s %s %s." % [r0[0], r0[1], r1[0], r1[1], str(c.get("beside", "stand beside")), entry]


static func result_line(place: int, entry: String, amount: int) -> String:
	if place >= 4:
		return "No ribbon this time, but an honourable mention for %s! Here's %s for the effort." % [entry, Money.amount(amount)]
	var ribbon: String = ["blue", "red", "yellow"][place - 1]
	return "The %s ribbon goes to %s! And %s with it." % [ribbon, entry, Money.amount(amount)]


## The ring and result lines with their sounds (C13 09-27): an animal entry calls in
## the ring, a ribbon gets applause, a mention a polite clap.
static func show_lines(c: Dictionary, rv: Array, entry: String, place: int, amount: int, host: String, pick: String) -> Array:
	var ring := {"text": ring_line(c, rv, entry)}
	if str(c.get("kind", "")) == "animal":
		var f := RanchVoice.file_of(str(Ranch.animal(pick).get("species", "")))
		if f != "":
			ring["sfx"] = f
	var res := {"who": host, "text": result_line(place, entry, amount), "sfx": "clap", "sfx_fallback": "j_confirm" if place >= 4 else "j_victory"}
	return [ring, res]


## One line from whoever gave you the animal, if they did. [npc id, name, line] or [].
static func giver_line(uid: String) -> Array:
	for fl: String in GIVERS:
		if str(GameState.run["flags"].get(fl, "")) == uid and uid != "":
			return GIVERS[fl]
	return []


## Animal entries: up to 3 showable grown animals, best first. [[label, uid]].
static func animal_entries() -> Array:
	var uids: Array = (Ranch.animals() as Dictionary).keys()
	uids = uids.filter(func(u: Variant) -> bool: return can_show(str(u)))
	uids.sort_custom(func(x: Variant, y: Variant) -> bool: return score_animal(str(x)) > score_animal(str(y)))
	var out: Array = []
	for u: Variant in uids.slice(0, 3):
		var a := Ranch.animal(str(u))
		var spn := Ranch.display_name(str(a.get("species", "")))
		out.append(["%s (%s)" % [str(a.get("name", spn)), spn], str(u)])
	return out


## Goods entries for a good table: what you carry, up to 4. [[label, id]].
static func good_entries(c: Dictionary) -> Array:
	var out: Array = []
	var ids: Array = (c.get("goods", []) as Array).duplicate()
	for gid: String in (Ranch.data().get("products", {}) as Dictionary).keys():
		if not ids.has(gid) and fits_family(c, gid):
			ids.append(gid)
	ids = ids.filter(func(g: Variant) -> bool: return GameState.items.has(str(g)) and GameState.count(str(g)) > 0 and not GameState.is_locked(str(g)))
	ids.sort_custom(func(x: Variant, y: Variant) -> bool: return score_good(str(x), 0) > score_good(str(y), 0))  # best first
	for gid: String in ids.slice(0, 4):
		out.append([GameState.item_name(gid), gid])
	return out


## Record a placing: show_place_<fest>_<cid>_<year> = place, show_blue/red/yellow counts, show_won_<fest>.
static func record(fest: String, cid: String, place: int) -> void:
	var fl: Dictionary = GameState.run["flags"]
	fl[done_key(fest, cid)] = place
	fl["show_place_%s_%s_%d" % [fest, cid, year()]] = place
	if place <= 3:
		var k: String = "show_" + str(["blue", "red", "yellow"][place - 1])
		fl[k] = int(fl.get(k, 0)) + 1
	if place == 1:
		fl["show_won_" + fest] = int(fl.get("show_won_" + fest, 0)) + 1


## Blue ribbons won so far (Collections reads this).
static func blue_ribbons() -> int:
	return int(GameState.run.get("flags", {}).get("show_blue", 0))

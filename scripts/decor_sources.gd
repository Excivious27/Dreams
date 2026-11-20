class_name DecorSources
extends RefCounted
## Where decor and wearables come from (CONDUCT 10a P4): one grant path for every
## source (shops, crafting, rewards, loot), the decor shelf on town counters and
## stalls, and the unique rule for sell/trash/gift/ship paths.
## Data comes from Decor (scripts/decor.gd, data/decor.json "shops"/"pools"/"grants");
## with an empty catalogue every hook here is a no-op, so the game plays as before.
## Every number lives in T.

const T := {
	"shelf_n": 6,            # pieces a decor shelf shows at once (phone list stays short)
	"rotate_days": 3,        # the shelf turns over every 3 days (same pick on reload / co-op)
	"rare_rotate_days": 7,   # rare+ pieces turn over weekly
	"rare_n": 2,             # of the shelf, at most this many rare+ pieces
	"luck_cap": 6.0,         # luck passed to Decor.roll never exceeds this (c10_07 luck curve)
	"tier_ahead": 1,         # a shelf shows pieces up to progress tier + this
	# Loot hooks: chance that a source also rolls its decor pool.
	"chest_p": 1.0,          # hidden chests / pockets are once per game: always roll
	"mine_prize_p": 1.0,     # every 10th-floor prize chest (once each)
	"mine_chest_p": 0.08,    # repeatable miner's chests: rarely, and only the common pool
	"fish_p": 0.17,          # inside a treasure catch (fishing skill/luck raise treasure itself)
}

## Shop ids (Shops.run) -> decor shelf keys in decor.json "shops". Gangster arc keys
## get "_gang" appended when that list exists (crew-flavoured stock).
const SHELF := {
	"store": "maple", "smith": "gideon", "potions": "wren", "granite": "granite",
	"sel": "sel", "tam": "tam", "orla": "orla", "marlowe": "marlowe", "lodge": "rook",
	"old_moss": "old_moss", "catkins": "catkins", "bait": "finn",
}


static func arc_word() -> String:
	return "penguins" if GameState.is_penguins() else "gangsters"


static func name_of(id: String) -> String:
	var e := Decor.entry(id)
	if e.has("name"):
		return str(e["name"])
	return GameState.item_name(id)


## Icon for any item: a catalogue entry's "icon"/"art" ("group/name", any art group)
## when that art exists, else the ordinary items icon (c10_01-02 / c10_11).
static func icon_tex(id: String) -> Texture2D:
	var e := Decor.entry(id)
	for k in ["icon", "art"]:
		var gn := str(e.get(k, ""))
		if gn.contains("/") and Art.has(gn.get_slice("/", 0), gn.get_slice("/", 1)):
			return Art.tex(gn.get_slice("/", 0), gn.get_slice("/", 1))
	return Art.tex("items", Hud.icon_for(id))


static func rarity_word(id: String) -> String:
	return Decor.rarity(id).capitalize()


static func is_wear(id: String) -> bool:
	var e := Decor.entry(id)
	return str(e.get("layer", "")) == "wear" or str(e.get("cat", "")) in Decor.WEAR_SLOTS


## Total copies the player holds anywhere (box + placed + worn).
static func held(id: String) -> int:
	var n := Decor.owned(id) + Decor.placed_count(id)
	for s in Decor.WEAR_SLOTS:
		if Decor.worn(s) == id:
			n += 1
	return n


## True when a unique piece is already the player's (never a second copy, never re-sold).
static func taken(id: String) -> bool:
	if not Decor.is_unique(id):
		return false
	return held(id) > 0 or (Decor.st()["got"] as Dictionary).has(id)


## One-of-a-kind items must never be sold, shipped, trashed or gifted (callers refuse).
## Covers catalogue uniques and Rec "once" prizes that are still bag items.
static func keeps(id: String) -> bool:
	if Decor.is_decor(id) and Decor.is_unique(id):
		return true
	if str(GameState.items.get(id, {}).get("rarity", "")) == "unique":
		return true
	return Tickets.is_once(id)


const KEEP_LINE := "One of a kind. You keep it."


## The one grant path: files decor in the decor box / wear in the wardrobe store and
## toasts with the rarity colour. m may be null (morning mail, tests). Returns true when
## something was given (a unique already owned is refused with a note).
static func grant(m: Node, id: String, n := 1, source := "") -> bool:
	if id == "" or n <= 0 or not Decor.is_decor(id):
		return false
	if taken(id):
		if m and m.get("hud"):
			m.hud.toast("You already have the %s." % name_of(id), Color(0.85, 0.85, 0.85))
		return false
	var before := Decor.owned(id)
	Decor.give(id, n, source)
	if Decor.owned(id) <= before:
		return false
	var where := "your wardrobe" if is_wear(id) else "your decor box"
	var txt := "New for your home: %s (%s). Sent to %s." % [name_of(id), rarity_word(id), where]
	if n > 1:
		txt = "New for your home: %s x%d. Sent to %s." % [name_of(id), n, where]
	if m and m.get("hud"):
		m.hud.toast(txt, Decor.rarity_color(Decor.rarity(id)))
		Music.instance(m.get_tree()).sfx("new_item", "pickup")
	else:
		GameMap.notify(txt, "new_item")
	return true


## Rolls a pool (luck capped) and grants the result: the id given, or "".
static func roll_grant(m: Node, pool: String, luck := 0.0, source := "") -> String:
	var id := Decor.roll(pool, minf(luck, float(T["luck_cap"])))
	if id == "" or taken(id):
		return ""
	return id if grant(m, id, 1, source if source != "" else pool) else ""


## Fixed grants written by gen_decor.py: decor.json "grants" {owner_key: id}
## (e.g. "secret:journal", "mine:150", "boss:<region>"). "" when none.
static func granted_for(key: String) -> String:
	var g: Variant = Decor.data().get("grants", {})
	if g is Dictionary:
		return str((g as Dictionary).get(key, ""))
	return ""


static func grant_key(m: Node, key: String) -> String:
	var id := granted_for(key)
	return id if grant(m, id, 1, key) else ""


# ---- shelves -------------------------------------------------------------------

static func _shelf_key(shop: String) -> String:
	var k := str(SHELF.get(shop, shop))
	if not GameState.is_penguins() and (Decor.data()["shops"] as Dictionary).has(k + "_gang"):
		return k + "_gang"
	return k


static func _fits(id: String) -> bool:
	var e := Decor.entry(id)
	if e.is_empty():
		return false
	var a := str(e.get("arc", ""))
	if a != "" and a != arc_word():
		return false
	if int(e.get("tier", 0)) > GameState.progress_tier() + int(T["tier_ahead"]):
		return false
	if taken(id):
		return false
	return Decor.price(id) > 0


## Deterministic window over a sorted pool: the same pick all day, on reload and for a
## co-op guest (run.day is synced). salt keeps shops from sharing a window.
static func rotate(pool: Array, n: int, period: int, salt: int) -> Array:
	var p := pool.duplicate()
	p.sort()
	if p.size() <= n:
		return p
	var out: Array = []
	var start := (int(GameState.run.get("day", 1)) / maxi(1, period) + salt) * n
	for i in n:
		out.append(p[(start + i) % p.size()])
	return out


## Today's decor shelf for a shop or stall key: commons/uncommons turn over every
## rotate_days, rare+ weekly; tier/arc filtered; owned uniques never listed.
static func today(shop: String) -> Array:
	var key := _shelf_key(shop)
	var all := Decor.stock(key).filter(func(i: Variant) -> bool: return _fits(str(i)))
	var plain: Array = []
	var rare: Array = []
	for i in all:
		if Decor.rarity_rank(Decor.rarity(str(i))) >= Decor.rarity_rank("rare"):
			rare.append(str(i))
		else:
			plain.append(str(i))
	var salt := absi(hash(key)) % 97
	var r := rotate(rare, int(T["rare_n"]), int(T["rare_rotate_days"]), salt)
	var out := rotate(plain, int(T["shelf_n"]) - r.size(), int(T["rotate_days"]), salt)
	out.append_array(r)
	return out


static func line(id: String) -> String:
	var have := held(id)
	return "%s (%s)  %s%s" % [name_of(id), rarity_word(id), Money.fmt(Decor.price(id)), ("  (have %d)" % have) if have > 0 else ""]


## Pays and grants one decor purchase; returns the toast-worthy result word.
static func buy(m: Node, id: String, qty := 1) -> String:
	if taken(id):
		return "owned"
	var cost := Decor.price(id) * qty
	if cost <= 0:
		return "none"
	if int(GameState.run["crystals"]) < cost:
		return "poor"
	GameState.run["crystals"] = int(GameState.run["crystals"]) - cost
	grant(m, id, qty, "shop")
	return "ok"


## The decor shelf menu (a counter's "Home goods" choice or a stall's extra rows).
static func shelf(m: GameMap, shop: String, who: String) -> void:
	var hello := "Home goods. New pieces every few days."
	while true:
		var ids := today(shop)
		if ids.is_empty():
			await m.say([{"who": who, "text": "Shelf's bare today. Check back in a few days."}])
			return
		var opts: Array = ids.map(func(i: Variant) -> String: return line(str(i)))
		opts.append("Back")
		var d := Dialogue.instance(m.get_tree())
		d.say([{"who": who, "text": "%s  (you have %s)" % [hello, Money.fmt(int(GameState.run["crystals"]))], "choice": opts, "key": ""}])
		await d.finished
		var i := d.last_choice
		if i < 0 or i >= ids.size():
			return
		var id := str(ids[i])
		var qty := 1
		if bool(Decor.entry(id).get("stack", false)):
			var dq := Dialogue.instance(m.get_tree())
			dq.say([{"who": who, "text": "%s, %s each. How many?" % [name_of(id), Money.fmt(Decor.price(id))], "choice": ["1", "5", "10", "Back"], "key": ""}])
			await dq.finished
			if dq.last_choice < 0 or dq.last_choice > 2:
				continue
			qty = [1, 5, 10][dq.last_choice]
		match buy(m, id, qty):
			"poor":
				m.hud.toast("Not enough crystals.", Color(1, 0.7, 0.7))
				Music.instance(m.get_tree()).sfx("nope", "thud")
			"ok":
				Music.instance(m.get_tree()).sfx("cash", "coin")
				m.xp("bartering", 1)
				hello = "Anything else for the house?"
			_:
				m.hud.toast("You already have that one.")

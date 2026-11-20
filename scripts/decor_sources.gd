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
	"reorder_fee": 1.25,     # (unused since C10b: orders cost Decor.order_price = shelf price + Decor.reorder_fee)
	"confirm_rank": 2,       # shelf buys of this rarity rank (rare) and up ask once before paying (c10b_10_20)
	"set_master_n": 6,       # claimed sets for the Little Gold Fountain (grant "set:set_master")
	"carpenter_letter_day": 3,  # Tess writes that her workshop is open
	"order_cap": 3,          # orders waiting at once
}

## Shop ids (Shops.run) -> decor shelf keys in decor.json "shops". Gangster arc keys
## get "_gang" appended when that list exists (crew-flavoured stock).
const SHELF := {
	"store": "maple", "smith": "gideon", "potions": "wren", "granite": "granite",
	"sel": "sel", "tam": "tam", "orla": "orla", "marlowe": "marlowe", "lodge": "rook",
	"old_moss": "old_moss", "catkins": "catkins", "bait": "finn",
	"carpenter": "carpenter", "lumi": "lumi",  # C10b P1: counters in Tess's workshop / cottage_c
	"crew_marlene": "crew_marlene", "crew_deuce": "crew_deuce", "crew_specs": "crew_specs", "crew_halo": "crew_halo",
}


static func arc_word() -> String:
	return "penguins" if GameState.is_penguins() else "gangsters"


static func name_of(id: String) -> String:
	if Decor.entry(id).has("name"):
		return Decor.display_name(id)  # c10b_13_05: the arc's name (name_gang) everywhere
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
	if GameState.keeps(id):
		return true  # keep-flagged items, story keys, vehicles, decor uniques (P1)
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
	if is_wear(id) and held(id) > 0:
		return false  # c10b_10_22: no second copy of clothes you already own
	return Decor.price(id) > 0


## Deterministic window over a sorted pool: the same pick all day, on reload and for a
## co-op guest (run.day is synced). salt keeps shops from sharing a window.
static func rotate(pool: Array, n: int, period: int, salt: int) -> Array:
	var p := pool.duplicate()
	p.sort()
	if p.size() <= n:
		return p
	# A fresh, deterministic mix every period (c10b_10_11: no six scarves in a row; c10b_10_21: a piece comes
	# back in days, not months). Same pick all period, on reload and for a co-op guest (run.day is synced).
	var per := int(GameState.run.get("day", 1)) / maxi(1, period)
	var keyed: Array = []
	for id in p:
		keyed.append([("%s:%d:%d" % [str(id), per, salt]).md5_text().hash(), str(id)])  # md5 first: hash() of near-equal strings keeps their order
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]) or (int(a[0]) == int(b[0]) and str(a[1]) < str(b[1])))
	var out: Array = []
	var subs := {}
	for kv in keyed:  # at most two of one kind (sub) on a shelf
		var sb := str(Decor.entry(str(kv[1])).get("sub", ""))
		if sb != "" and int(subs.get(sb, 0)) >= 2:
			continue
		subs[sb] = int(subs.get(sb, 0)) + 1
		out.append(str(kv[1]))
		if out.size() >= n:
			return out
	for kv in keyed:
		if out.size() >= n:
			break
		if not (str(kv[1]) in out):
			out.append(str(kv[1]))
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
	return "%s (%s)  %s%s" % [name_of(id), rarity_word(id), Money.fmt(Decor.buy_price(id)), ("  (have %d)" % have) if have > 0 else ""]


## Pays and grants one decor purchase; returns the toast-worthy result word.
static func buy(m: Node, id: String, qty := 1) -> String:
	if taken(id):
		return "owned"
	var cost := Decor.buy_price(id) * qty  # c10b_10_01: the shelf honours buy discounts like every shop
	if cost <= 0:
		return "none"
	if int(GameState.run["crystals"]) < cost:
		return "poor"
	GameState.run["crystals"] = int(GameState.run["crystals"]) - cost
	grant(m, id, qty, "shop")
	return "ok"


## The decor shelf menu (a counter's "Home goods" choice or a stall's extra rows).
static func shelf(m: GameMap, shop: String, who: String) -> void:
	if use_screen:
		await DecorShopScreen.open(m, shop, who)
		return
	await shelf_dialogue(m, shop, who)


## Tests and bots may prefer the dialogue list (no full-screen UI).
static var use_screen := true


static func shelf_dialogue(m: GameMap, shop: String, who: String) -> void:
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
			dq.say([{"who": who, "text": "%s, %s each. How many?" % [name_of(id), Money.fmt(Decor.buy_price(id))], "choice": ["1", "5", "10", "Back"], "key": ""}])
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


# ---- orders (catalogue re-order, made-to-order furniture) -------------------------

static func orders() -> Array:
	if not (GameState.run.get("decor_orders", null) is Array):
		GameState.run["decor_orders"] = []
	return GameState.run["decor_orders"]


static func order_price(id: String) -> int:
	return Decor.order_price(id)  # c10b_10_02: one re-order price (shelf price + Decor.reorder_fee)


## Orders a piece you have seen or owned (P3's catalogue calls this): pays now, the
## piece comes with tomorrow's post. Returns "ok", "poor", "owned", "full" or "none".
static func order(id: String) -> String:
	if Decor.is_decor(id) and taken(id):
		return "owned"  # an owned unique says so, even though uniques are never on the order list
	if not Decor.is_decor(id) or order_price(id) <= 0:
		return "none"
	if taken(id) or orders().any(func(o: Variant) -> bool: return Decor.is_unique(id) and str((o as Dictionary).get("id", "")) == id):
		return "owned"
	if orders().size() >= int(T["order_cap"]):
		return "full"
	var cost := order_price(id)
	if int(GameState.run["crystals"]) < cost:
		return "poor"
	GameState.run["crystals"] = int(GameState.run["crystals"]) - cost
	orders().append({"id": id, "day": int(GameState.run.get("day", 1))})
	return "ok"


## Morning post (Mail._morning): yesterday's orders arrive as parcels to pick up.
static func deliver_orders() -> int:
	var today := int(GameState.run.get("day", 1))
	var keep: Array = []
	var n := 0
	for o: Dictionary in orders():
		if int(o.get("day", today)) >= today:
			keep.append(o)
			continue
		Mail.send("Catalogue order", "Your order came in: %s. Take it from this parcel and it goes to your decor box." % name_of(str(o["id"])), "gift", {"item": str(o["id"]), "n": 1})
		n += 1
	GameState.run["decor_orders"] = keep
	return n


# ---- event grants (C10b P1, c10b_06_01/10/12, c10b_07) ------------------------------------------------------

## A finished main/side quest: its decor.json grant "quest:<id>" (GameState.complete_quest calls this).
static func on_quest(id: String) -> void:
	if granted_for("quest:" + id) == "":
		return
	var m := Engine.get_main_loop().get("current_scene") as Node if Engine.get_main_loop() else null
	if not (Decor.st().get("swept", null) is Dictionary):
		Decor.st()["swept"] = {}
	Decor.st()["swept"]["quest:" + id] = int(GameState.run.get("day", 1))
	grant_key(m, "quest:" + id)


## Grant keys whose event is a state, not a moment: checked every morning (GameState.sleep) and on load, so
## old saves that already passed the event get the piece too. "secret:<flag>" (run.flags), "campaign:<cid>"
## (Campaign.is_won), "quest:<id>" (done), "set:set_master" (T.set_master_n claimed sets), "heart:<npc>:<n>"
## is given by Perks itself. Returns the ids given.
static func sweep(m: Node = null) -> Array:
	var out: Array = []
	var g: Variant = Decor.data().get("grants", {})
	if not (g is Dictionary) or (g as Dictionary).is_empty():
		return out
	var fl: Dictionary = GameState.run.get("flags", {}) if GameState.run.get("flags", {}) is Dictionary else {}
	var swept: Dictionary = Decor.st().get("swept", {}) if Decor.st().get("swept", {}) is Dictionary else {}
	Decor.st()["swept"] = swept
	for key: String in g:
		if swept.has(key):
			continue
		var kind := key.get_slice(":", 0)
		var ref := key.substr(kind.length() + 1)
		var due := false
		match kind:
			"secret":
				due = fl.has(ref)
			"campaign":
				due = Campaign.is_won(ref)
			"quest":
				due = GameState.quest_done(ref)
			"set":
				due = ref == "set_master" and _claimed_sets() >= int(T["set_master_n"])
		if not due:
			continue
		var id := str(g[key])
		swept[key] = int(GameState.run.get("day", 1))
		if not Decor.in_arc(id) or held(id) > 0 or (Decor.is_unique(id) and taken(id)):
			continue
		if grant(m, id, 1, key):
			out.append(id)
	return out


static func _claimed_sets() -> int:
	var sd: Variant = Decor.st().get("sets_done", {})
	return (sd as Dictionary).size() if sd is Dictionary else 0


## Day 3+: Tess writes once to say her workshop is open (Mail._first_week hook). Both arcs, own words.
static func carpenter_letter(day: int) -> void:
	var flags: Dictionary = GameState.run.get("flags", {})
	if day < int(T.get("carpenter_letter_day", 3)) or flags.has("wmail_tess") or not Decor.data().get("shops", {}).has("carpenter"):
		return
	flags["wmail_tess"] = true
	var town := str(GameState.names().get("town", "town"))
	if GameState.is_penguins():
		Mail.send("Tess", "Hello, neighbour! I've opened a workshop in the old warehouse up by the farm road, just inside %s. Chairs, beds, shelves, rugs, and benches and lamps for your yard. Eight till six; new pieces every few days. Come and sit in a few chairs. - Tess, carpenter" % town, "news")
	else:
		Mail.send("Tess", "You're the one on the old plot. I build furniture out of the old warehouse by the farm road. Tables, beds, rugs, yard pieces, built to last whatever the street throws at them. Eight till six. - Tess", "news")

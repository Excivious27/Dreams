class_name Casino
extends RefCounted
## The Gilded Ace: the gangster arc's casino behind props/gc_casino on Gilt City's
## Casino Row (C10b P4). Real betting with purse cash (Tom 2026-11-19 20:03), all-ages.
##
## run["casino"] (per player: never in Net WORLD_KEYS, never in run.opts):
##   seed, hand_no          the outcome stream (each hand mixes in its game + bet)
##   day, today {hands, staked, won, lost}
##   loss_limit             0 = off (default from data/casino.json limits.loss_default)
##   break_until            "Take a break": the floor stays shut for you until this day
##   seen {table: true}     first-visit how-to shown
##   cold                   losses in a row (kind words only: odds never change)
##   session                net this visit (counted into earned_total on the way out if > 0)
##   visits, hands_total    lifetime counts (no money milestones)
##
## Odds: fixed tables in data/casino.json (tools/gen_casino.py computes every RTP and
## fails the build if any bet returns >= 0.99). This file NEVER reads luck, gear
## stats, buffs, perks or Difficulty: tools/casino_test.gd greps for it.

static var _data: Dictionary = {}
static var force_seed := 0      # tests: a fixed outcome stream (0 = the save's own seed)
static var skip_save := false   # tests that don't want SaveGame writes

const TABLE_SCRIPTS := {
	"slots": "res://scripts/casino_slots.gd",
	"roulette": "res://scripts/casino_roulette.gd",
	"blackjack": "res://scripts/casino_blackjack.gd",
	"dice": "res://scripts/casino_dice.gd",
	"poker": "res://scripts/casino_poker.gd",
}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/casino.json", FileAccess.READ)
		if f:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_data = d
	return _data


static func line(key: String) -> String:
	return str(data().get("lines", {}).get(key, ""))


static func lim(key: String) -> Variant:
	return data().get("limits", {}).get(key, 0)


static func _st() -> Dictionary:
	var st: Dictionary = GameState.run.get("casino", {})
	if st.is_empty():
		st = {"seed": randi() % 2000000000 + 1, "hand_no": 0, "day": -1, "today": {}, "loss_limit": int(lim("loss_default")),
			"break_until": 0, "seen": {}, "cold": 0, "session": 0, "visits": 0, "hands_total": 0}
		GameState.run["casino"] = st
	# Co-op: run.day is the host's calendar while visiting, so a visit never starts a
	# new casino day (it can't reset limits or lift a break early): own_day() stays put.
	if int(st.get("day", -1)) != int(GameState.run.get("day", 1)) and (not GameState.visiting() or int(st.get("day", -1)) < 0):
		st["day"] = int(GameState.run.get("day", 1))
		st["today"] = {"hands": 0, "staked": 0, "won": 0, "lost": 0}
	return st


## The player's own casino day (the host's day never counts while visiting).
static func own_day() -> int:
	return int(_st().get("day", GameState.run.get("day", 1)))


static func today() -> Dictionary:
	return _st()["today"]


static func purse() -> int:
	return int(GameState.run.get("crystals", 0))


static func tier() -> int:
	return clampi(GameState.progress_tier(), 0, (lim("max_bet") as Array).size() - 1)


static func min_bet() -> int:
	return int(lim("min_bet"))


static func step() -> int:
	return maxi(1, int(lim("step")))


static func max_bet() -> int:
	return int((lim("max_bet") as Array)[tier()])


static func keep() -> int:
	return int((lim("keep") as Array)[tier()])


static func stake_cap() -> int:
	return max_bet() * int(lim("daily_stake_cap_x"))


## Most this player may put down right now (0 = nothing): table max, the purse
## floor ("you keep $X for the road"), today's stake cap and loss limit.
static func max_stake() -> int:
	var st := _st()
	var td: Dictionary = st["today"]
	var m := mini(max_bet(), purse() - keep())
	m = mini(m, stake_cap() - int(td.get("staked", 0)))
	var ll := int(st.get("loss_limit", 0))
	if ll > 0:
		m = mini(m, ll - net_loss_today())
	m -= m % step()
	return maxi(0, m)


static func net_loss_today() -> int:
	var td := today()
	return maxi(0, int(td.get("lost", 0)) - int(td.get("won", 0)))


static func net_today() -> int:
	var td := today()
	return int(td.get("won", 0)) - int(td.get("lost", 0))


## "" when a bet of this size may be placed, else the dealer's reason.
static func why_no_bet(stake: int) -> String:
	var st := _st()
	var td: Dictionary = st["today"]
	if int(td.get("hands", 0)) >= int(lim("hands_cap")):
		return line("hands_cap")
	var ll := int(st.get("loss_limit", 0))
	if ll > 0 and net_loss_today() >= ll:
		return line("loss_stop")
	if int(td.get("staked", 0)) + min_bet() > stake_cap():
		return line("stake_cap")
	if purse() - keep() < min_bet():
		return line("keep_rule") % Money.amount(keep())
	if stake < min_bet() or stake > max_stake() or stake % step() != 0:
		return "Bets here are %s to %s." % [Money.amount(min_bet()), Money.amount(maxi(min_bet(), max_stake()))]
	return ""


## Takes the stake from the purse before the reveal starts (and saves), so a
## closed app mid-spin keeps the bet resolved. False (nothing taken) if refused.
static func take(stake: int, game: String, free := false) -> bool:
	if free:
		return true
	if why_no_bet(stake) != "":
		return false
	GameState.run["crystals"] = purse() - stake
	var td := today()
	td["staked"] = int(td.get("staked", 0)) + stake
	var st := _st()
	st["pending"] = {"game": game, "stake": stake}
	_save()
	return true


## Pays the settled hand: gross = what comes back (stake included). Returns the
## net (+ won, - lost, 0 push). Advances the clock a little, counts the hand,
## big days add heat, saves. Free (practice) hands touch nothing.
static func settle(game: String, stake: int, gross: int, m: Node = null, free := false) -> int:
	var net := gross - stake
	if free:
		return net
	var st := _st()
	st.erase("pending")
	GameState.run["crystals"] = purse() + gross
	var td: Dictionary = st["today"]
	td["hands"] = int(td.get("hands", 0)) + 1
	if net > 0:
		td["won"] = int(td.get("won", 0)) + net
		st["cold"] = 0
	elif net < 0:
		td["lost"] = int(td.get("lost", 0)) - net
		st["cold"] = int(st.get("cold", 0)) + 1
	st["session"] = int(st.get("session", 0)) + net
	st["hand_no"] = int(st.get("hand_no", 0)) + 1
	st["hands_total"] = int(st.get("hands_total", 0)) + 1
	var tables: Dictionary = st.get("played", {})
	tables[game] = int(tables.get(game, 0)) + 1
	st["played"] = tables
	_advance_clock()
	_keepsakes(m, game)
	# Big net day: the pit boss notices (+1 heat once a day).
	if net_today() > int(lim("big_win_x")) * max_bet() and int(st.get("heat_day", -1)) != own_day():
		st["heat_day"] = own_day()
		if Racket.on():
			Racket.add_heat(m as GameMap, 1)
			if m is GameMap:
				(m as GameMap).hud.toast(line("big_win_heat"), Color(1, 0.7, 0.5))
	_save()
	return net


## One-time keepsakes for trying each table and for hands played (data/casino.json
## "rewards"; never for the size of a win). Through DecorSources, never add_item.
static func _keepsakes(m: Node, game: String) -> void:
	var st := _st()
	var got: Dictionary = st.get("got", {})
	var played: Dictionary = st.get("played", {})
	for r: Dictionary in data().get("rewards", []):
		var key := str(r["key"])
		if got.has(key):
			continue
		var due := false
		match key.get_slice(":", 0):
			"table": due = key.get_slice(":", 1) == game
			"tables": due = played.size() >= (data().get("tables", []) as Array).size()
			"hands": due = int(st.get("hands_total", 0)) >= int(key.get_slice(":", 1))
		if not due:
			continue
		got[key] = true
		st["got"] = got
		if DecorSources.grant(m, str(r["decor"]), 1, "casino"):
			st["keepsake_line"] = str(r["text"])  # the table shows it on its banner


## Kind words after a cold run, a reality check every N hands ("" = none).
static func after_hand_note() -> String:
	var st := _st()
	var cs: Array = lim("cold_streak")
	var cold := int(st.get("cold", 0))
	if cold == int(cs[1]):
		return line("cold_2")
	if cold == int(cs[0]):
		return line("cold_1")
	var h := int(today().get("hands", 0))
	if h > 0 and h % int(lim("reality_hands")) == 0:
		var n := net_today()
		return line("reality") % [h, ("Up " + Money.amount(n)) if n > 0 else (("Down " + Money.amount(-n)) if n < 0 else "Even")]
	if closing_soon():
		return line("last_call")
	return ""


static func _advance_clock() -> void:
	if GameState.visiting():
		return  # a guest's hands never move the host's shared clock
	var t := int(GameState.run.get("time", 0)) + int(data().get("hand_min", 3))
	GameState.run["time"] = mini(t, GameState.DAY_END - 15)


static func _save() -> void:
	if not skip_save:
		GameState.save()


## The outcome stream for one hand: the save's seed, the hand number, the game and
## the bet all go in, so a reloaded save replays the same hand for the same bet but
## a different bet can't peek at it (c10b_05_04). Looks use ArcadeGame.rng instead.
static func rng_for(game: String, sig: String) -> RandomNumberGenerator:
	var st := _st()
	var r := RandomNumberGenerator.new()
	var s := force_seed if force_seed != 0 else int(st.get("seed", 1))
	r.seed = hash("%d|%d|%s|%s" % [s, int(st.get("hand_no", 0)), game, sig])
	return r


# --- hours, doors -------------------------------------------------------------

static func day_hour() -> float:
	return int(GameState.run.get("time", 0)) / 60.0


static func closing_soon() -> bool:
	var h: Array = data().get("hours", [18, 26])
	return day_hour() >= float(h[1]) - 0.5


## "" when the doors open for this player, else the doorman's words.
static func why_shut() -> String:
	if GameState.run.is_empty():
		return ""
	var st := _st()
	if int(st.get("break_until", 0)) > own_day():
		return line("doorman_break") % int(st["break_until"])
	var h: Array = data().get("hours", [18, 26])
	if day_hour() < float(h[0]) or day_hour() >= float(h[1]):
		return line("doorman_closed")
	if Racket.on() and Racket.heat() >= int(lim("refuse_heat")):
		return line("doorman_heat")
	return ""


static func odds_board() -> String:
	return str(data().get("odds_board", ""))


static func table_name(id: String) -> String:
	for t: Dictionary in data().get("tables", []):
		if str(t["id"]) == id:
			return str(t["name"])
	return id.capitalize()


# --- the floor ----------------------------------------------------------------

## The door thing on Casino Row (Region thing type "casino").
static func enter(m: GameMap) -> void:
	var why := why_shut()
	if why != "":
		await m.say([{"who": "Doorman", "text": why}])
		return
	var st := _st()
	st["session"] = 0
	st["visits"] = int(st.get("visits", 0)) + 1
	Music.instance(m.get_tree()).sfx("door", "door")
	var lines: Array = [{"who": "Host", "text": line("host_greet")}]
	if int(st["visits"]) == 1:
		lines.append({"who": "Host", "text": line("first_visit") % Money.amount(keep())})
	if GameState.count("gambler_chip") > 0 and not bool(st.get("chip_told", false)):
		st["chip_told"] = true  # Gilt Chips are collector loot: never stakes, never cashed here
		lines.append({"who": "Cashier", "text": line("gilt_chip")})
	if GameState.equipped("charm") == "golden_dice" or GameState.equipped("ring") == "golden_dice":
		lines.append({"who": "Croupier", "text": line("luck_charm")})
	await m.say(lines)
	GameMap.next_interior = "gilt_casino"
	m.go_to("interior", Vector2.ZERO, "up")


## A casino thing inside the floor room (interior thing type "casino", key "act").
static func use(m: GameMap, thing: Dictionary) -> void:
	var act := str(thing.get("act", ""))
	if act == "odds":
		await m.say([{"who": "", "text": odds_board()}])
		return
	if act == "host":
		await floor_menu(m)
		leave(m)
		return
	var why := why_shut()
	if why != "":
		await m.say([{"who": "Croupier", "text": line("closing") if why == line("doorman_closed") else why}])
		return
	var g := open_table(m, act)
	if g:
		await g.closed
		leave(m)


static func floor_menu(m: GameMap) -> void:
	var d := Dialogue.instance(m.get_tree())
	while true:
		var tables: Array = data().get("tables", [])
		var opts: Array = []
		for t: Dictionary in tables:
			opts.append(str(t["name"]))
		opts += ["Odds board", "Today", "Limits", "Leave"]
		var n := net_today()
		var head := "%s. You have %s. Today: %s, %d hands." % [str(data().get("name", "The Gilded Ace")), Money.amount(purse()),
			("up " + Money.amount(n)) if n > 0 else (("down " + Money.amount(-n)) if n < 0 else "even"), int(today().get("hands", 0))]
		d.say([{"who": "Host", "text": head, "choice": opts, "key": ""}])
		await d.finished
		var c := d.last_choice
		if c < 0 or c >= opts.size() - 1:
			return
		if c < tables.size():
			if why_shut() != "":
				await m.say([{"who": "Host", "text": line("closing")}])
				return
			var g := open_table(m, str(tables[c]["id"]))
			if g:
				await g.closed
			continue
		match str(opts[c]):
			"Odds board":
				await m.say([{"who": "", "text": odds_board()}])
			"Today":
				var td := today()
				await m.say([{"who": "Host", "text": "Today: %d hands, %s bet, %s won, %s lost. Limit: %s. Bets here: %s to %s." % [
					int(td.get("hands", 0)), Money.amount(int(td.get("staked", 0))), Money.amount(int(td.get("won", 0))), Money.amount(int(td.get("lost", 0))),
					("lose at most " + Money.amount(int(_st().get("loss_limit", 0))) + " a day") if int(_st().get("loss_limit", 0)) > 0 else "off",
					Money.amount(min_bet()), Money.amount(max_bet())]}])
			"Limits":
				await limits_menu(m)
				if why_shut() != "":
					return


static func limits_menu(m: GameMap) -> void:
	var d := Dialogue.instance(m.get_tree())
	var st := _st()
	var opts: Array = []
	var vals: Array = lim("loss_limits")
	for v in vals:
		var on := int(v) == int(st.get("loss_limit", 0))
		opts.append(("Daily loss limit: off" if int(v) == 0 else "Daily loss limit: " + Money.amount(int(v))) + ("  (now)" if on else ""))
	opts.append("Take a break (%d days off the floor)" % int(lim("break_days")))
	opts.append("Back")
	d.say([{"who": "Host", "text": "Limits are yours to set. The house never changes them for you.", "choice": opts, "key": ""}])
	await d.finished
	var c := d.last_choice
	if c < 0 or c >= opts.size() - 1:
		return
	if c < vals.size():
		st["loss_limit"] = int(vals[c])
		m.hud.toast("Daily loss limit: %s." % ("off" if int(vals[c]) == 0 else Money.amount(int(vals[c]))), Color(0.9, 0.95, 1))
		_save()
		return
	d.say([{"who": "Host", "text": "Close the floor to yourself for %d days? It can't be undone early." % int(lim("break_days")), "choice": ["Yes, take a break", "Back"], "key": ""}])
	await d.finished
	if d.last_choice == 0:
		take_break()
		await m.say([{"who": "Host", "text": line("break_set") % int(st["break_until"])}])


static func take_break() -> void:
	var st := _st()
	st["break_until"] = own_day() + int(lim("break_days"))
	_save()


## On the way out: a winning visit counts in "earned in all" once, as its net
## (wins never inflate it hand by hand; losses stay in the ledger).
static func leave(m: GameMap = null) -> void:
	var st := _st()
	var s := int(st.get("session", 0))
	if s > 0:
		GameState._count_earned(s, "casino")
	st["session"] = 0
	if m:
		var n := net_today()
		if n != 0:
			m.hud.toast("Tonight at the Ace: %s." % (("up " + Money.amount(n)) if n > 0 else ("down " + Money.amount(-n))), Color(1, 0.9, 0.6))
	_save()


static func make(id: String) -> CasinoGame:
	var path := str(TABLE_SCRIPTS.get(id, ""))
	if path == "":
		return null
	var g: CasinoGame = (load(path) as GDScript).new()
	g.game_id = "casino_" + id
	g.table = id
	for t: Dictionary in data().get("tables", []):
		if str(t["id"]) == id:
			g.title = str(t["name"])
			var a: Array = t.get("accent", [1, 0.8, 0.2])
			g.accent = Color(float(a[0]), float(a[1]), float(a[2]))
			g.howto = t.get("howto", [])
	return g


static func open_table(m: Node, id: String) -> CasinoGame:
	var g := make(id)
	if g == null:
		return null
	m.add_child(g)
	return g

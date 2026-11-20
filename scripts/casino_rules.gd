class_name CasinoRules
extends RefCounted
## Pure rule functions for The Gilded Ace (C10b P4). They mirror tools/gen_casino.py
## (which computes every RTP from the same rules), so tests can feed stacked decks.
## Nothing here reads luck, gear, perks or difficulty: the odds are the tables.

const SUITS := ["♠", "♥", "♦", "♣"]
const RANKS := ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]


static func data() -> Dictionary:
	return Casino.data()


# --- slots -------------------------------------------------------------------

## Gross payout per 1 staked for the three symbols on the payline (0 = no win).
static func slot_pay(a: String, b: String, c: String) -> int:
	var s: Dictionary = data().get("slots", {})
	if a == b and b == c:
		return int(s.get("three", {}).get(a, 0))
	if a == "cherry" and b == "cherry":
		return int(s.get("cherry2", 0))
	if a == "cherry":
		return int(s.get("cherry1", 0))
	return 0


static func strips() -> Array:
	return data().get("slots", {}).get("strips", [[], [], []])


# --- roulette ----------------------------------------------------------------

static func is_red(n: int) -> bool:
	for r in data().get("roulette", {}).get("reds", []):
		if int(r) == n:
			return true
	return false


static func roulette_wins(bet: String, pocket: int, number := 0) -> bool:
	if bet == "single":
		return pocket == number
	if pocket == 0:
		return false
	match bet:
		"red": return is_red(pocket)
		"black": return not is_red(pocket)
		"odd": return pocket % 2 == 1
		"even": return pocket % 2 == 0
		"low": return pocket <= 18
		"high": return pocket >= 19
		"dozen1": return pocket <= 12
		"dozen2": return pocket >= 13 and pocket <= 24
		"dozen3": return pocket >= 25
	return false


## Gross return per 1 staked (stake back + winnings), 0 on a loss.
static func roulette_pays(bet: String, pocket: int, number := 0) -> int:
	if not roulette_wins(bet, pocket, number):
		return 0
	return 1 + int(data().get("roulette", {}).get("bets", {}).get(bet, ["", 1])[1])


# --- dice (Big / Small) ------------------------------------------------------

static func dice_wins(bet: String, d: Array) -> bool:
	if int(d[0]) == int(d[1]) and int(d[1]) == int(d[2]):
		return false
	var s := int(d[0]) + int(d[1]) + int(d[2])
	return s <= 10 if bet == "small" else s >= 11


# --- blackjack ---------------------------------------------------------------

## Card values 1..13 (A..K). Returns [total, soft].
static func bj_total(cards: Array) -> Array:
	var t := 0
	var ace := false
	for c in cards:
		t += mini(int(c), 10)
		if int(c) == 1:
			ace = true
	if ace and t + 10 <= 21:
		return [t + 10, true]
	return [t, false]


static func bj_natural(cards: Array) -> bool:
	return cards.size() == 2 and int(bj_total(cards)[0]) == 21


## Dealer draws to 17 and stands on all 17s (soft too).
static func dealer_should_hit(cards: Array) -> bool:
	return int(bj_total(cards)[0]) < 17


## Gross return per 1 staked on the (possibly doubled) hand: player and dealer
## cards at the end, doubled = the stake was doubled (returns per ORIGINAL stake).
static func bj_settle(player: Array, dealer: Array, doubled := false) -> float:
	var pay: Array = data().get("blackjack", {}).get("bj_pay", [6, 5])
	var pn := bj_natural(player) and not doubled
	var dn := bj_natural(dealer)
	if pn and dn:
		return 1.0
	if dn:
		return 0.0
	if pn:
		return 1.0 + float(pay[0]) / float(pay[1])
	var m := 2.0 if doubled else 1.0
	var pt := int(bj_total(player)[0])
	if pt > 21:
		return 0.0
	var dt := int(bj_total(dealer)[0])
	if dt > 21 or pt > dt:
		return 2.0 * m
	if pt == dt:
		return m
	return 0.0


static func card_text(c: Variant) -> String:
	if c is Array:  # poker [rank 2..14, suit]
		var r := int(c[0])
		return (RANKS[1] if r == 14 else RANKS[r]) + SUITS[int(c[1])]
	return RANKS[clampi(int(c), 1, 13)]


# --- video poker (Jacks or Better) -------------------------------------------

## hand: 5 x [rank 2..14, suit 0..3]. Returns a paytable id or "".
static func poker_rank(hand: Array) -> String:
	var ranks: Array = []
	var suits := {}
	for c in hand:
		ranks.append(int(c[0]))
		suits[int(c[1])] = true
	ranks.sort()
	var counts := {}
	for r in ranks:
		counts[r] = int(counts.get(r, 0)) + 1
	var uniq: Array = counts.keys()
	uniq.sort()
	var flush := suits.size() == 1
	var straight := uniq.size() == 5 and (int(uniq[4]) - int(uniq[0]) == 4 or uniq == [2, 3, 4, 5, 14])
	var cs: Array = counts.values()
	cs.sort()
	cs.reverse()
	if straight and flush:
		return "royal" if int(uniq[0]) == 10 else "straight_flush"
	if int(cs[0]) == 4:
		return "four"
	if int(cs[0]) == 3 and int(cs[1]) == 2:
		return "full_house"
	if flush:
		return "flush"
	if straight:
		return "straight"
	if int(cs[0]) == 3:
		return "three"
	if int(cs[0]) == 2 and int(cs[1]) == 2:
		return "two_pair"
	if int(cs[0]) == 2:
		for r in counts:
			if int(counts[r]) == 2 and int(r) >= 11:
				return "jacks"
	return ""


## Gross return per 1 staked for a final poker hand (0 = nothing).
static func poker_pays(hand: Array) -> int:
	var id := poker_rank(hand)
	if id == "":
		return 0
	return int(data().get("poker", {}).get("pays", {}).get(id, ["", 0])[1])


## The hint hold (same simple strategy gen_casino simulates).
static func poker_hold_hint(hand: Array) -> Array:
	var rk := poker_rank(hand)
	var ranks: Array = []
	var suits: Array = []
	for c in hand:
		ranks.append(int(c[0]))
		suits.append(int(c[1]))
	if rk in ["royal", "straight_flush", "four", "full_house", "flush", "straight"]:
		return [true, true, true, true, true]
	var out: Array = []
	if rk in ["three", "two_pair", "jacks"]:
		for r in ranks:
			out.append(ranks.count(r) >= 2)
		return out
	for s in 4:
		if suits.count(s) == 4:
			for x in suits:
				out.append(x == s)
			return out
	var pair := false
	for r in ranks:
		if ranks.count(r) == 2:
			pair = true
	if pair:
		for r in ranks:
			out.append(ranks.count(r) == 2)
		return out
	var kept := 0
	for r in ranks:
		var k: bool = int(r) >= 11 and kept < 2
		if k:
			kept += 1
		out.append(k)
	return out

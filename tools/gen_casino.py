#!/usr/bin/env python3
"""The Gilded Ace: the gangster arc's casino on Gilt City's Casino Row (C10b P4).

Writes (edit this file, not the JSON):
  data/casino.json   tables, paytables, reel strips, limits, hours, house lines, odds board

Every number a game pays lives here, and every bet's return to player (RTP) is
computed here: by full enumeration (slots, roulette, dice) or by a fixed-seed
simulation of the shipped rules (blackjack basic strategy, video poker holds).
The run FAILS if any bet returns >= RTP_MAX, if any payout is fractional at the
table's bet steps, or if a casino text uses a banned word (all-ages rule).

Rules of the house (c10b_04 / c10b_05, Tom 2026-11-19 20:03: real betting, all-ages):
  * Stakes come straight from the purse (cash, $). No chip items, no credit,
    no loans, no betting items, crew or hearts. Gilt Chips stay collector loot.
  * Luck, gear, perks and difficulty never touch the odds (Casino reads none).
  * Daily limits per player (run.casino, never run.opts: co-op syncs opts).

    python3 tools/gen_casino.py          # write data/casino.json (+ checks)
    python3 tools/gen_casino.py --sim    # also print 12-week pacing for three players
"""
import itertools, json, os, random, sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
D = os.path.join(ROOT, "data")

RTP_MAX = 0.99          # no bet may return this much or more
EDGE_MAX = 0.20         # and none may keep more than this

NAME = "The Gilded Ace"
HOURS = [18, 26]        # 6pm to 2am on the day's own scale (RecCenter.day_hour style)
HAND_MIN = 3            # game minutes one settled hand/spin takes off the clock

# Table limits by progress tier (GameState.progress_tier 0-4; Gilt City opens at tier 3+).
LIMITS = {
    "min_bet": 10,
    "step": 10,                                   # every stake is a multiple of this
    "max_bet": [50, 50, 100, 100, 250, 500],      # index = progress tier (5 = High Roller later)
    "keep": [50, 100, 150, 250, 400, 600],        # the purse floor a table never bets into
    "daily_stake_cap_x": 40,                      # total staked a day <= this x the tier's max bet
    "hands_cap": 150,                             # hands a day, all tables
    "reality_hands": 30,                          # a reality check every N hands
    "loss_limits": [0, 200, 500, 1000],           # Options in the host menu (0 = off)
    "loss_default": 500,                          # on by default
    "break_days": 7,                              # "Take a break": the floor shuts for you this long
    "big_win_x": 10,                              # net winnings over this x max bet in a day = +1 heat
    "refuse_heat": 3,                             # at heat 3+ the doorman turns you away for the night
    "cold_streak": [5, 10],                       # kind words after 5 losses, a breather card after 10
}

# ------------------------------------------------------------------ slots
# 3 reels x 1 payline. Stops are drawn from the strips; the reels only show them.
SYMBOLS = ["cherry", "bell", "bar", "horseshoe", "star", "crown", "seven"]
STRIPS = [
    {"cherry": 4, "bell": 5, "bar": 4, "horseshoe": 3, "star": 2, "crown": 1, "seven": 1},
    {"cherry": 3, "bell": 5, "bar": 5, "horseshoe": 3, "star": 2, "crown": 1, "seven": 1},
    {"cherry": 2, "bell": 5, "bar": 5, "horseshoe": 4, "star": 2, "crown": 1, "seven": 1},
]
THREE = {"seven": 200, "crown": 100, "star": 40, "horseshoe": 20, "bar": 12, "bell": 10, "cherry": 8}
CHERRY2 = 4   # cherry cherry any (from the left)
CHERRY1 = 2   # cherry any any (leftmost only)


def strip_list(s):
    # Interleave so the same symbol rarely sits next to itself (looks like a real reel).
    pool = []
    for sym in SYMBOLS:
        pool += [sym] * s[sym]
    rnd = random.Random(len(pool) * 7 + s["bell"])
    best = None
    for _ in range(400):
        rnd.shuffle(pool)
        adj = sum(1 for i in range(len(pool)) if pool[i] == pool[(i + 1) % len(pool)])
        if best is None or adj < best[0]:
            best = (adj, list(pool))
    return best[1]


def slot_pay(a, b, c):
    if a == b == c:
        return THREE[a]
    if a == "cherry" and b == "cherry":
        return CHERRY2
    if a == "cherry":
        return CHERRY1
    return 0


def slots_rtp(strips):
    tot = 0.0
    hit = 0
    n = len(strips[0]) * len(strips[1]) * len(strips[2])
    for a in strips[0]:
        for b in strips[1]:
            for c in strips[2]:
                p = slot_pay(a, b, c)
                tot += p
                hit += p > 0
    return tot / n, hit / n


# ------------------------------------------------------------------ roulette
REDS = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
ROULETTE_BETS = {   # id: [label, payout x stake (net), short]
    "red": ["Red", 1, "R"], "black": ["Black", 1, "B"],
    "odd": ["Odd", 1, "Odd"], "even": ["Even", 1, "Even"],
    "low": ["1-18", 1, "1-18"], "high": ["19-36", 1, "19-36"],
    "dozen1": ["1st 12", 2, "1-12"], "dozen2": ["2nd 12", 2, "13-24"], "dozen3": ["3rd 12", 2, "25-36"],
    "single": ["One number", 35, "#"],
}


def roulette_wins(bet, pocket, number=0):
    if bet == "single":
        return pocket == number
    if pocket == 0:
        return False
    return {
        "red": pocket in REDS, "black": pocket not in REDS,
        "odd": pocket % 2 == 1, "even": pocket % 2 == 0,
        "low": pocket <= 18, "high": pocket >= 19,
        "dozen1": pocket <= 12, "dozen2": 13 <= pocket <= 24, "dozen3": pocket >= 25,
    }[bet]


def roulette_rtp(bet):
    pay = ROULETTE_BETS[bet][1]
    tot = 0
    for p in range(37):
        tot += (pay + 1) if roulette_wins(bet, p, 17) else 0
    return tot / 37.0


# ------------------------------------------------------------------ dice (sic bo Big/Small)
DICE_BETS = {"small": ["Small 4-10", 1], "big": ["Big 11-17", 1]}


def dice_wins(bet, d):
    if d[0] == d[1] == d[2]:
        return False
    s = sum(d)
    return 4 <= s <= 10 if bet == "small" else 11 <= s <= 17


def dice_rtp(bet):
    tot = 0
    for d in itertools.product(range(1, 7), repeat=3):
        tot += 2 if dice_wins(bet, d) else 0
    return tot / 216.0


# ------------------------------------------------------------------ blackjack
BJ = {"decks": 6, "bj_pay": [6, 5], "dealer_soft17": "stand", "double": "any two", "split": False,
      "insurance": False, "peek": True, "reshuffle": "every hand"}


def bj_total(cards):
    t = sum(min(c, 10) for c in cards)
    soft = False
    if 1 in cards and t + 10 <= 21:
        t += 10
        soft = True
    return t, soft


def bj_basic(cards, up):
    """Hit/stand/double basic strategy (no split): 'h', 's' or 'd'."""
    t, soft = bj_total(cards)
    two = len(cards) == 2
    up = 11 if up == 1 else min(up, 10)
    if soft:
        if t >= 19:
            return "s"
        if t == 18:
            if two and 3 <= up <= 6:
                return "d"
            return "s" if up <= 8 else "h"
        if two and ((t in (13, 14) and up in (5, 6)) or (t in (15, 16) and 4 <= up <= 6) or (t == 17 and 3 <= up <= 6)):
            return "d"
        return "h"
    if t >= 17:
        return "s"
    if t >= 13:
        return "s" if up <= 6 else "h"
    if t == 12:
        return "s" if 4 <= up <= 6 else "h"
    if t == 11 and two:
        return "d"
    if t == 10 and two and up <= 9:
        return "d"
    if t == 9 and two and 3 <= up <= 6:
        return "d"
    return "h"


def bj_round(rnd):
    shoe = [r for r in range(1, 14) for _ in range(4 * BJ["decks"])]
    def draw():
        return min(shoe.pop(rnd.randrange(len(shoe))), 10)
    p = [draw(), draw()]
    d = [draw(), draw()]
    pt, _ = bj_total(p)
    dt, _ = bj_total(d)
    if pt == 21 and dt == 21:
        return 0.0
    if dt == 21:
        return -1.0
    if pt == 21:
        return BJ["bj_pay"][0] / BJ["bj_pay"][1]
    stake = 1.0
    while True:
        a = bj_basic(p, d[0])
        if a == "d":
            stake = 2.0
            p.append(draw())
            break
        if a == "s":
            break
        p.append(draw())
        if bj_total(p)[0] > 21:
            return -stake
    pt = bj_total(p)[0]
    if pt > 21:
        return -stake
    while bj_total(d)[0] < 17:
        d.append(draw())
    dt = bj_total(d)[0]
    if dt > 21 or pt > dt:
        return stake
    if pt == dt:
        return 0.0
    return -stake


def bj_rtp(n=200000):
    rnd = random.Random(2026)
    tot = 0.0
    sq = 0.0
    for _ in range(n):
        r = bj_round(rnd)  # net per 1 initial stake
        tot += r
        sq += r * r
    mean = tot / n
    sd = (sq / n - mean * mean) ** 0.5 / n ** 0.5
    return 1.0 + mean, sd


# ------------------------------------------------------------------ video poker (Jacks or Better 8/5)
POKER = {"royal": ["Royal Flush", 250], "straight_flush": ["Straight Flush", 50], "four": ["Four of a Kind", 25],
         "full_house": ["Full House", 8], "flush": ["Flush", 5], "straight": ["Straight", 4],
         "three": ["Three of a Kind", 3], "two_pair": ["Two Pair", 2], "jacks": ["Jacks or Better", 1]}
POKER_ORDER = ["royal", "straight_flush", "four", "full_house", "flush", "straight", "three", "two_pair", "jacks"]
POKER_OPTIMAL_RTP = 0.9730   # published optimal-hold return for 8/5 Jacks or Better (royal 250 per coin, 1 coin)


def poker_rank(hand):
    """hand: list of (rank 2..14, suit 0..3). Returns a POKER id or ''."""
    ranks = sorted([c[0] for c in hand])
    suits = [c[1] for c in hand]
    flush = len(set(suits)) == 1
    uniq = sorted(set(ranks))
    straight = len(uniq) == 5 and (uniq[4] - uniq[0] == 4 or uniq == [2, 3, 4, 5, 14])
    counts = sorted([ranks.count(r) for r in uniq], reverse=True)
    if straight and flush:
        return "royal" if uniq[0] == 10 else "straight_flush"
    if counts[0] == 4:
        return "four"
    if counts[:2] == [3, 2]:
        return "full_house"
    if flush:
        return "flush"
    if straight:
        return "straight"
    if counts[0] == 3:
        return "three"
    if counts[:2] == [2, 2]:
        return "two_pair"
    if counts[0] == 2:
        pr = [r for r in uniq if ranks.count(r) == 2][0]
        return "jacks" if pr >= 11 else ""
    return ""


def poker_hold(hand):
    """A simple, readable hold strategy (the in-game 'hint' uses the same): keeps any
    paying hand's cards, four to a flush, high pairs/low pairs, two high cards."""
    rk = poker_rank(hand)
    ranks = [c[0] for c in hand]
    if rk in ("royal", "straight_flush", "four", "full_house", "flush", "straight"):
        return [True] * 5
    if rk in ("three", "two_pair", "jacks"):
        return [ranks.count(r) >= 2 for r in ranks]
    suits = [c[1] for c in hand]
    for s in range(4):
        if suits.count(s) == 4:
            return [x == s for x in suits]
    pairs = [r for r in set(ranks) if ranks.count(r) == 2]
    if pairs:
        return [r in pairs for r in ranks]
    high = [i for i, r in enumerate(ranks) if r >= 11]
    keep = high[:2]
    return [i in keep for i in range(5)]


def poker_rtp(n=120000):
    rnd = random.Random(77)
    deck = [(r, s) for r in range(2, 15) for s in range(4)]
    tot = 0
    for _ in range(n):
        d = list(deck)
        rnd.shuffle(d)
        hand = d[:5]
        rest = d[5:]
        hold = poker_hold(hand)
        k = 0
        for i in range(5):
            if not hold[i]:
                hand[i] = rest[k]
                k += 1
        rk = poker_rank(hand)
        tot += (POKER[rk][1] + 0) if rk else 0
    return tot / n


# ------------------------------------------------------------------ texts
LINES = {
    "doorman_closed": "The Gilded Ace opens at 6pm. The doorman taps his watch, politely.",
    "doorman_heat": "The doorman doesn't move. \"Pit boss says you're too hot tonight. Come back when things cool off.\"",
    "doorman_break": "You asked the house to keep you off the floor until day %d. The doorman remembers. Good for you.",
    "host_greet": "Welcome to The Gilded Ace. Tables take cash only. The odds are posted on every table, and they never change.",
    "first_visit": "House rules, first time here: you keep %s for the road, a day has a limit, and nothing you wear changes the odds. Have fun with it.",
    "keep_rule": "House rule: you keep %s for the road.",
    "loss_stop": "You've hit today's loss limit. The tables will take your bets again tomorrow.",
    "stake_cap": "That's today's betting for this table tier. Come back tomorrow.",
    "hands_cap": "You've played a lot of hands today. The house closes your tab until tomorrow.",
    "reality": "%d hands today. %s today. Keep playing, or cash out and enjoy the evening?",
    "cold_1": "Cards run cold sometimes. The table's here tomorrow.",
    "cold_2": "That's a long cold run. Take a breather?",
    "luck_charm": "Charms are lovely. The wheel doesn't care.",
    "gilt_chip": "Gilt house chips? Collectors want those, not my table. We take cash.",
    "last_call": "Last call: one more hand, then the tables close for the night.",
    "closing": "The Gilded Ace is closing for the night. Thanks for playing.",
    "big_win_heat": "The pit boss is making calls about you.",
    "break_set": "Done. The floor is closed to you until day %d. The house will hold your table.",
    "stop_early": "Stopping early never changes the result: it was drawn before the reels moved.",
}

ODDS_BOARD = "Odds board: for every $100 bet, the house keeps about"

TABLES = [   # id, name, short how-to (3 lines, button words through PadInput.words in game)
    {"id": "slots", "name": "Gilded Slots", "accent": [0.95, 0.72, 0.18],
     "howto": ["Set your bet with LEFT and RIGHT.", "A spins. One payline across the middle.", "Every win pays at least twice your bet."]},
    {"id": "roulette", "name": "Roulette", "accent": [0.9, 0.3, 0.3],
     "howto": ["UP and DOWN pick a bet, LEFT and RIGHT the stake.", "On One number, X and Y pick the number.", "A spins. Single zero: zero loses outside bets."]},
    {"id": "blackjack", "name": "Blackjack", "accent": [0.35, 0.8, 0.4],
     "howto": ["Get closer to 21 than the dealer.", "A hits, X stands, Y doubles your bet.", "Dealer stands on all 17s. Blackjack pays 6 to 5."]},
    {"id": "dice", "name": "Big or Small", "accent": [0.3, 0.55, 0.95],
     "howto": ["Three dice. Small is 4-10, Big is 11-17.", "UP and DOWN pick, A rolls.", "Any triple: the house wins."]},
    {"id": "poker", "name": "Video Poker", "accent": [0.75, 0.45, 0.95],
     "howto": ["Five cards. Tap cards (or X) to hold them.", "A draws new cards for the rest. Y shows a hint.", "Jacks or better pays. Paytable 8/5."]},
]

# One-time keepsakes for trying the tables and for hands played: never for the size
# of a win (no money milestones). Granted through DecorSources.grant(m, id, 1, "casino").
REWARDS = [
    {"key": "table:slots", "decor": "dc_casino_slot", "text": "First spin on the Gilded Slots: the house sends a little slot machine home with you."},
    {"key": "table:roulette", "decor": "dc_casino_roulette", "text": "First spin of the wheel: a small roulette wheel for your shelf, with the house's compliments."},
    {"key": "table:blackjack", "decor": "dc_casino_table", "text": "First hand of blackjack: the house sends over a felt card table."},
    {"key": "table:dice", "decor": "dc_casino_dice", "text": "First roll at Big or Small: a pair of house dice, yours to keep."},
    {"key": "table:poker", "decor": "dc_casino_cards_art", "text": "First hand of video poker: a framed royal flush for your wall."},
    {"key": "tables:all", "decor": "dc_casino_marquee", "text": "You've sat at every table in the house. The Gilded Ace sends you a marquee sign."},
    {"key": "hands:100", "decor": "dc_casino_ace_sign", "text": "A hundred hands at the Ace. The house sends you its neon ace."},
]

# The casino floor behind props/gc_casino (merged into data/interiors.json as
# "gilt_casino"). "back" is the casino door's front cell on Casino Row, read from the
# solved layout in regions.json (gen_mega_new moves structs, so never hard-coded).
def D_(n, c, w=0, solid=True, g="decor"):
    p = {"group": g, "name": n, "cell": list(c)}
    if w:
        p["w"] = w
    if not solid:
        p["solid"] = False
    return p


ROOM = {
    "cols": 16, "rows": 13, "floor": "fl_carpet_red", "wall": "wl_marble", "door": [8, 12], "music": "mega_gilt",
    "no_furnish": True, "pet": False, "casino": True, "windows": [],
    "props": [
        D_("dc_casino_marquee", (5, 1), solid=False), D_("dc_casino_ace_sign", (10, 1), solid=False),
        D_("dc_casino_slot", (1, 3)), D_("dc_casino_slot", (2, 3)), D_("dc_casino_slot", (3, 3)), D_("dc_casino_slot", (4, 3)),
        D_("dc_casino_roulette", (7, 4), 1), D_("dc_casino_slot", (12, 3)), D_("dc_casino_slot", (13, 3)), D_("dc_casino_booth", (12, 9), 1),
        D_("dc_casino_table", (3, 7), 1), D_("dc_casino_table", (11, 7), 1),
        D_("betting_booth", (6, 9), 2, g="props"),
        D_("dc_casino_stool", (3, 8), solid=False), D_("dc_casino_stool", (4, 8), solid=False),
        D_("dc_casino_rope", (6, 11), solid=False), D_("dc_casino_rope", (10, 11), solid=False),
        D_("dc_casino_lamp", (1, 11)), D_("dc_gilt_palm", (14, 11)), D_("dc_gilt_statue", (14, 5)), D_("dc_casino_lamp", (1, 6)),
    ],
    "things": [
        {"type": "casino", "act": "slots", "cell": [1, 3], "hint": "A: Gilded Slots", "solid": True},
        {"type": "casino", "act": "slots", "cell": [2, 3], "hint": "A: Gilded Slots", "solid": True},
        {"type": "casino", "act": "slots", "cell": [3, 3], "hint": "A: Gilded Slots", "solid": True},
        {"type": "casino", "act": "slots", "cell": [4, 3], "hint": "A: Gilded Slots", "solid": True},
        {"type": "casino", "act": "roulette", "cell": [7, 4], "hint": "A: Roulette", "solid": True},
        {"type": "casino", "act": "roulette", "cell": [8, 4], "hint": "A: Roulette", "solid": True},
        {"type": "casino", "act": "poker", "cell": [12, 3], "hint": "A: Video Poker", "solid": True},
        {"type": "casino", "act": "poker", "cell": [13, 3], "hint": "A: Video Poker", "solid": True},
        {"type": "casino", "act": "blackjack", "cell": [3, 7], "hint": "A: Blackjack", "solid": True},
        {"type": "casino", "act": "blackjack", "cell": [4, 7], "hint": "A: Blackjack", "solid": True},
        {"type": "casino", "act": "dice", "cell": [11, 7], "hint": "A: Big or Small", "solid": True},
        {"type": "casino", "act": "dice", "cell": [12, 7], "hint": "A: Big or Small", "solid": True},
        {"type": "casino", "act": "host", "cell": [6, 9], "hint": "A: the host stand (odds, limits)", "solid": True},
        {"type": "casino", "act": "host", "cell": [7, 9], "hint": "A: the host stand (odds, limits)", "solid": True},
        {"type": "casino", "act": "host", "cell": [8, 9], "hint": "A: the host stand (odds, limits)", "solid": True},
        {"type": "casino", "act": "odds", "cell": [14, 5], "hint": "A: read the brass plaque (house odds)", "solid": True},
    ],
}


def write_room():
    regs = json.load(open(os.path.join(D, "regions.json")))
    door = None
    for t in regs.get("gilt_casino_row", {}).get("things", []):
        if t.get("type") == "casino":
            door = t["cell"]
    if door is None:
        print("gen_casino: no casino door on Casino Row (run gen_mega_new first)")
        sys.exit(1)
    room = dict(ROOM)
    room["back"] = ["gilt_casino_row", door[0], door[1] + 1]
    path = os.path.join(D, "interiors.json")
    rooms = json.load(open(path))
    rooms["gilt_casino"] = room
    nl = open(path, "rb").read()[-1:] == b"\n"
    with open(path, "w") as f:
        json.dump(rooms, f, indent=1, ensure_ascii=False)
        if nl:
            f.write("\n")


BANNED = ["blood", "drug", "drunk", "beer", "booze", "whisk", "cigar", "smok", "kill", "dead", "debt", "loan",
          "win it back", "chase", "credit", "marker", "guaranteed", "can't lose", "hot table", "due for"]
KIDS = ["dice_kid", "the_kid", "pip", "tobin", "mabel", "wren_jr"]


def all_text(obj):
    if isinstance(obj, str):
        yield obj
    elif isinstance(obj, dict):
        for v in obj.values():
            yield from all_text(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from all_text(v)


def build():
    strips = [strip_list(s) for s in STRIPS]
    srtp, shit = slots_rtp(strips)
    rr = {b: roulette_rtp(b) for b in ROULETTE_BETS}
    dr = {b: dice_rtp(b) for b in DICE_BETS}
    brtp, bsd = bj_rtp()
    prtp = poker_rtp()
    rtp = {"slots": round(srtp, 4), "roulette": {b: round(v, 4) for b, v in rr.items()},
           "dice": {b: round(v, 4) for b, v in dr.items()},
           "blackjack": round(brtp, 4), "blackjack_sd": round(bsd, 4),
           "poker": POKER_OPTIMAL_RTP, "poker_simple_holds": round(prtp, 4)}
    worst = {"slots": srtp, "roulette": max(rr.values()), "dice": max(dr.values()), "blackjack": brtp + 2 * bsd, "poker": POKER_OPTIMAL_RTP}
    keep = {k: round((1.0 - v) * 100, 2) for k, v in [("slots", srtp), ("roulette", max(rr.values())), ("dice", max(dr.values())), ("blackjack", brtp), ("poker", POKER_OPTIMAL_RTP)]}
    board = "%s: Slots $%.2f, Roulette $%.2f, Blackjack $%.2f, Big or Small $%.2f, Video Poker $%.2f. Luck charms change nothing." % (
        ODDS_BOARD, keep["slots"], keep["roulette"], keep["blackjack"], keep["dice"], keep["poker"])
    out = {
        "_note": "Generated by tools/gen_casino.py: edit that, not this file.",
        "name": NAME, "hours": HOURS, "hand_min": HAND_MIN, "limits": LIMITS,
        "tables": TABLES,
        "slots": {"symbols": SYMBOLS, "strips": strips, "three": THREE, "cherry2": CHERRY2, "cherry1": CHERRY1, "hit_rate": round(shit, 4)},
        "roulette": {"reds": REDS, "bets": ROULETTE_BETS},
        "dice": {"bets": DICE_BETS},
        "blackjack": BJ,
        "poker": {"pays": POKER, "order": POKER_ORDER},
        "rtp": rtp, "house_keeps": keep, "odds_board": board, "lines": LINES, "rewards": REWARDS,
    }
    check(out, worst)
    return out


def check(out, worst):
    errs = []
    for g, v in worst.items():
        if v >= RTP_MAX:
            errs.append("%s RTP %.4f >= %.2f" % (g, v, RTP_MAX))
        if 1.0 - v > EDGE_MAX:
            errs.append("%s edge %.3f > %.2f" % (g, 1.0 - v, EDGE_MAX))
    # every slot line that pays pays at least 2x (no 'wins' smaller than the stake)
    for s, p in list(THREE.items()) + [("cherry2", CHERRY2), ("cherry1", CHERRY1)]:
        if p < 2:
            errs.append("slot line %s pays %d < 2x" % (s, p))
    # whole payouts at every legal stake
    st = LIMITS["step"]
    bjn, bjd = BJ["bj_pay"]
    if (st * bjn) % bjd:
        errs.append("blackjack %d:%d is fractional at step %d" % (bjn, bjd, st))
    if LIMITS["min_bet"] % st:
        errs.append("min bet not a multiple of the step")
    for m in LIMITS["max_bet"]:
        if m % st:
            errs.append("max bet %d not a multiple of the step" % m)
        if m // LIMITS["min_bet"] > 50:
            errs.append("max/min bet ratio over 50 (martingale guard)")
    # keepsakes: every decor id exists, each key once, none for money
    try:
        dec = json.load(open(os.path.join(D, "decor.json")))["items"]
        ids = set(dec.keys()) if isinstance(dec, dict) else {x["id"] for x in dec}
    except Exception:
        ids = None
    keys = set()
    for r in REWARDS:
        if r["key"] in keys:
            errs.append("reward key %s twice" % r["key"])
        keys.add(r["key"])
        if not r["key"].split(":")[0] in ("table", "tables", "hands"):
            errs.append("reward %s is not for variety or hands" % r["key"])
        if ids is not None and r["decor"] not in ids:
            errs.append("reward decor %s not in decor.json" % r["decor"])
    # words
    for s in all_text({"lines": LINES, "rewards": REWARDS, "tables": TABLES, "board": out["odds_board"], "name": NAME}):
        low = s.lower()
        for b in BANNED:
            if b in low:
                errs.append("banned word %r in %r" % (b, s[:60]))
        for k in KIDS:
            if k in low.split():
                errs.append("kid id %r in casino text" % k)
    if errs:
        for e in errs:
            print("gen_casino: " + e)
        sys.exit(1)


def sim(out):
    rnd = random.Random(5)
    print("12-week pacing (even-money roulette, 2.7% edge):")
    for who, hands, bet in [("cautious", 20, 10), ("average", 60, 30), ("high roller", 150, 100)]:
        weeks = []
        for w in range(12):
            net = 0
            for d in range(7):
                for h in range(hands):
                    net += bet if rnd.randrange(37) < 18 else -bet
            weeks.append(net)
        weeks.sort()
        print("  %-12s mean/week %+7.0f  worst week %+7.0f  best %+7.0f" % (who, sum(weeks) / 12, weeks[0], weeks[-1]))


def save(n, obj):
    path = os.path.join(D, n)
    with open(path, "w") as f:
        json.dump(obj, f, indent=1, ensure_ascii=False)
        f.write("\n")


if __name__ == "__main__":
    o = build()
    save("casino.json", o)
    write_room()
    print("gen_casino: ok  slots %.4f (hit %.1f%%)  roulette %.4f  dice %.4f  blackjack %.4f+-%.4f  poker %.4f (simple holds %.4f)" % (
        o["rtp"]["slots"], o["slots"]["hit_rate"] * 100, max(o["rtp"]["roulette"].values()), max(o["rtp"]["dice"].values()),
        o["rtp"]["blackjack"], o["rtp"]["blackjack_sd"], o["rtp"]["poker"], o["rtp"]["poker_simple_holds"]))
    if "--sim" in sys.argv:
        sim(o)

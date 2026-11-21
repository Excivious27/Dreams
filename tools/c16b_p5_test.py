#!/usr/bin/env python3
"""C16b P5: campaign content checks (long way rows, gang captains and rosters, tier-1
ramp, cache vs battle pay, reward curve, words). Data-only, reads data/*.json.
    python3 tools/c16b_p5_test.py   -> "c16b_p5_test: 0 fails"
"""
import json, os
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
B = json.load(open(D + "/data/battles.json"))
E = json.load(open(D + "/data/enemies.json"))["enemies"]
IT = json.load(open(D + "/data/items.json"))
IT = IT.get("items", IT)
CP = B["_campaigns"]
C = CP["list"]
fails = []
def check(ok, msg):
    if not ok:
        fails.append(msg)
        print("FAIL", msg)

PEOPLE = ("thug_", "gilt_", "coal_", "rust_knight", "gcap_g_")
MONSTER_WORDS = ("grump", "wolf", "golem", "hag", "serpent", "guardian", "slime", "moth", "wisp", "crab", "eel")
gang_tier_kinds = {}
for cid, c in C.items():
    arcs = ["penguins", "gangsters"] if c["arc"] == "both" else [c["arc"]]
    lw = c.get("long_way", {})
    # contract section 2 row
    for k in ("kind", "id", "cost", "steps", "text", "text_gang", "unlock_after"):
        check(k in lw, "%s long_way has %s" % (cid, k))
    check(lw.get("kind") in ("quest", "toll", "travel", "story"), cid + " long_way kind")
    check(lw.get("unlock_after") in ("loss", "skip", "always"), cid + " long_way unlock_after")
    check(int(lw.get("cost", {}).get("money", 0)) > 0 and all(k in IT for k in lw.get("cost", {}).get("items", {})), cid + " long_way cost")
    for w in ("blood", "kill", "drug", "beer", "wine", "shoot"):
        check(w not in (str(lw.get("text", "")) + str(lw.get("text_gang", ""))).lower(), "%s long_way all-ages (%s)" % (cid, w))
    battle_pay = [n["reward"]["crystals"] for n in c["nodes"] if n.get("reward") and n["type"] != "gate"]
    for n in c["nodes"]:
        if "loot" in n:
            take = sum(int(IT[k].get("value", 50)) * v for k, v in n["loot"]["items"].items())
            check(n["loot"]["crystals"] < min(battle_pay) and take < min(battle_pay), "%s %s cache out-pays a battle" % (cid, n["id"]))
        for a, cf in n.get("cfg", {}).items():
            if a == "gangsters":
                check(all(k.startswith(PEOPLE) for k in cf["enemies"]), "%s %s gang foes are people: %s" % (cid, n["id"], cf["enemies"]))
                gang_tier_kinds.setdefault(c["tier"], set()).update(cf["enemies"])
                if n["type"] in ("boss", "gate"):
                    b = cf.get("boss", "")
                    check(b.startswith("gcap_g_") and b in E, "%s %s gang captain %s" % (cid, n["id"], b))
                    nm = str(E.get(b, {}).get("name", "")).lower()
                    check(nm and not any(w in nm for w in MONSTER_WORDS) and "blink" not in E.get(b, {}).get("abilities", []), "%s captain %s named, no monster, no blink" % (cid, nm))
            if c["tier"] <= 1 and n["layer"] <= 1:
                check(all(int(E[k].get("tier", 1)) <= 1 for k in cf["enemies"]), "%s %s %s tier-1 opener foes: %s" % (cid, n["id"], a, cf["enemies"]))
    if c["arc"] == "both":
        check(all("name_gangsters" in n for n in c["nodes"] if n["type"] != "start"), cid + " gang node names")
    check(int(c["need"]["team"]) <= 4, cid + " never asks more allies than take the field")
# gang tiers each bring something new
ts = sorted(gang_tier_kinds)
for a, b in zip(ts, ts[1:]):
    check(bool(gang_tier_kinds[b] - gang_tier_kinds[a]), "gang tier %d brings a new foe kind" % b)
# gate pay grows with tier
pay = {}
for c in C.values():
    pay.setdefault(c["tier"], c["reward"]["crystals"])
check(all(pay[t] < pay[t + 1] for t in pay if t + 1 in pay), "gate pay grows by tier %s" % pay)
check(C["c_countryside"]["region_name"] == "The Highway", "countryside is The Highway")
check(CP["drill"]["enemies"]["gangsters"] == ["thug_lookout"], "gang drill foe is a lookout")
check(all(str(t) in CP.get("unlocks", {}) for t in range(1, 6)), "tier unlocks table")
for k in ("thug_speedster", "thug_brute", "thug_cyber", "thug_flame"):
    check(bool(E[k].get("name")), k + " has a display name")
for k in E:
    if k.startswith("gcap_"):
        check(os.path.exists(os.path.join(D, "art", "gen", "ui", "card_%s.png" % k)), k + " has a boss card (tools/slice_c16b_p5.py)")
print("c16b_p5_test: %d fails" % len(fails))

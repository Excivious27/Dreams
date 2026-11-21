#!/usr/bin/env python3
"""C16a P3 energy checker (econ_check style, pure Python, no imports beyond the stdlib).

Reads the live energy constants from scripts/game_state.gd (ENERGY_COST, ENERGY_SKILL,
ENERGY_FLOOR, caps, recovery multipliers, swing toughness) and the bands/personas from
data/energy_bands.json, then prints per persona x checkpoint x day length: the bar,
food cap, rest cap, what a full day spends (by task) and what is left. Fails when:
  - Tom's day-1 route (meadow fight + mine floor 1 + half of floor 2) > route.max_pct of the bar
  - the max-energy curve leaves its bands (d7, d28, y1, y2, y3, every-source ceiling)
  - a persona's day-1 full day needs more than the bar (forced pass-out on day 1)
  - from y1 on, the farmer/miner full day uses less than late_min_bar_pct of the bar (bar not binding)
  - usable energy a day (bar + food + rest) > usable_max_bar_mult x bar
Run: python3 tools/energy_check.py [-v]
"""
import json
import os
import re
import sys

R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GS = open(os.path.join(R, "scripts/game_state.gd")).read()
B = json.load(open(os.path.join(R, "data/energy_bands.json")))
VERBOSE = "-v" in sys.argv


def gd_const(name):
    m = re.search(r"^const %s := (.+?)(?:\s+#.*)?$" % name, GS, re.M)
    if not m:
        raise SystemExit("energy_check: const %s not found in game_state.gd" % name)
    v = m.group(1).strip()
    if v.startswith("{"):
        return json.loads(re.sub(r"(\d+):", r'"\1":', v))
    return float(v) if "." in v else int(v)


COST = gd_const("ENERGY_COST")
SKILL = gd_const("ENERGY_SKILL")
FLOOR = gd_const("ENERGY_FLOOR")
BASE = gd_const("ENERGY_BASE")
PER_LV = gd_const("ENERGY_PER_LEVEL")
LV_MAX = gd_const("ENERGY_LEVELS_MAX")
TREE_CAP = gd_const("TREE_EN_CAP")
GEAR_CAP = gd_const("GEAR_EN_CAP")
TONIC = gd_const("TONIC_CAP")["energy"]
FOOD_LEN = {int(k): v for k, v in gd_const("FOOD_LEN_MULT").items()}
REST_LEN = {int(k): v for k, v in gd_const("REST_LEN_MULT").items()}
T_START = gd_const("TOUGH_START")
T_TIER = gd_const("TOUGH_TIER_MULT")
T_LV = gd_const("TOUGH_LEVEL")
T_LV_FLOOR = gd_const("TOUGH_LEVEL_FLOOR")
LENS = [15, 20, 30, 40]
FIELD = ["hoe", "can", "plant", "scythe"]


def cost(task, lv, tier, perk):
    """Mirror of GameState.energy_cost_f (no weather, no stamina buff)."""
    base = COST.get(task, 1.0)
    if base <= 0:
        return 0.0
    skill_mult = 1.0
    if SKILL.get(task, "") != "":
        l = float(lv - 1)
        early = 0.15 if task in FIELD else 0.0
        skill_mult = max(0.7, 1.0 - 0.035 * l) * (1.0 + early * max(0.0, 1.0 - l / 4.0))
    t = 0 if task in ("sword", "dodge", "spar", "teach", "weed", "rod") else tier
    per = 0.12 if task in FIELD else (0.03 if task in ("axe", "pickaxe") else 0.08)
    p = perk if task in ("hoe", "can", "plant", "pickaxe") else 0.0
    return base * max(FLOOR, skill_mult * (1.0 - per * t) * (1.0 - p))


def swings(hp, tool, lv, tier):
    lvf = max(T_LV_FLOOR, 1.0 - T_LV * (min(lv, 20) - 1))
    return max(1, int(round(hp * T_START[tool] * (T_TIER ** tier) * lvf)))


def bar(cp, ceiling=False):
    lv_en = int(PER_LV * min(cp["lv_sum"], LV_MAX))
    milestones = min(gd_const("MINE_EN_CAP"), gd_const("MINE_EN_STEP") * (cp["deepest"] // 5))
    b = BASE + lv_en + min(cp["tree"], TREE_CAP) + min(cp["gear"], GEAR_CAP) + milestones + min(cp["tonic"], TONIC)
    if ceiling:
        cs = B["ceiling_sources"]
        return b + cs["friends"] + cs["misc"]
    return b + cp["friends"] + cp["misc"]


def food_cap(cp, dl):
    return round(min(200, 120 + 4 * (cp["lv"] - 1)) * FOOD_LEN[dl])


def rest_cap(b, dl):
    return round(min(max(b // 2, 60), 100) * REST_LEN[dl])


def day_spend(acts, cp, stone_share):
    lv, tier, perk = cp["lv"], cp["tier"], cp["perk"]
    out = {}
    for task, n in acts.items():
        if task == "rocks":
            sw = stone_share * swings(2, "pickaxe", lv, tier) + (1 - stone_share) * swings(4, "pickaxe", lv, tier)
            out["pickaxe"] = n * sw * cost("pickaxe", lv, tier, perk)
        elif task == "axe":
            out["axe"] = n * swings(4, "axe", lv, tier) * cost("axe", lv, tier, 0.0) / 4.0  # trees ~1 in 4 chops are stumps/branches
        else:
            out[task] = out.get(task, 0.0) + n * cost(task, lv, tier, perk)
    return out


fails = []
rt = B["route"]
cps = B["checkpoints"]
d1 = cps["d1"]
# 1. Tom's route.
per_try = (rt["stone_share"] * swings(2, "pickaxe", 1, 0) + (1 - rt["stone_share"]) * swings(4, "pickaxe", 1, 0)) * cost("pickaxe", 1, 0, 0)
fight = rt["fight"]["sword"] * cost("sword", 1, 0, 0) + rt["fight"]["dodge"] * cost("dodge", 1, 0, 0)
ft = rt["floor_tries"]
route = fight + ft[1] * per_try + 0.5 * ft[2] * per_try + rt["mine_fights"] * fight
pct = 100.0 * route / bar(d1)
print("energy_check: ROUTE (gang arc day 1, meadow + floor 1 + half floor 2): %.1f of %d (%.0f%%, max %.0f%%) [pickaxe swing %.2f, %.2f a rock, sword %.2f, dodge %.2f]"
      % (route, bar(d1), pct, rt["max_pct"], cost("pickaxe", 1, 0, 0), per_try, cost("sword", 1, 0, 0), cost("dodge", 1, 0, 0)))
if pct > rt["max_pct"]:
    fails.append("Tom's route costs %.0f%% of the day-1 bar (max %.0f%%)" % (pct, rt["max_pct"]))

# 2. Max-energy curve.
bands = B["bar"]
curve = []
for k, cp in cps.items():
    if k.startswith("_"):
        continue
    curve.append("%s %d" % (k, bar(cp)))
    if k in bands and bar(cp) > bands[k]:
        fails.append("max energy at %s is %d (band <= %d)" % (k, bar(cp), bands[k]))
ceil_ = bar(cps["y3"], True)
print("energy_check: BAR curve " + ", ".join(curve) + "; every-source ceiling %d (band <= %d)" % (ceil_, bands["ceiling"]))
if ceil_ > bands["ceiling"]:
    fails.append("every-source max energy ceiling %d > %d" % (ceil_, bands["ceiling"]))

# 3. Persona days.
db = B["day_bands"]
rows = []
for name, plan in B["personas"].items():
    if name.startswith("_"):
        continue
    for k, acts in plan.items():
        cp = cps[k]
        b = bar(cp)
        sp = day_spend(acts, cp, rt["stone_share"])
        tot = sum(sp.values())
        for dl in LENS:
            fc, rc = food_cap(cp, dl), rest_cap(b, dl)
            usable = b + fc + rc
            left = b - tot
            rows.append((name, k, dl, b, fc, rc, tot, left))
            if dl == 15 or VERBOSE:
                print("  %-8s %-4s len %2d  bar %3d food %3d rest %3d  day %6.1f (%3.0f%% of bar)  left %6.1f  %s"
                      % (name, k, dl, b, fc, rc, tot, 100 * tot / b, left, " ".join("%s %.0f" % (t, v) for t, v in sorted(sp.items()))))
            if usable > db["usable_max_bar_mult"] * b:
                fails.append("%s %s len %d: usable %d > %.1f x bar %d" % (name, k, dl, usable, db["usable_max_bar_mult"], b))
        if k == "d1" and tot > b * db["d1"]["max_bar_pct"] / 100.0:
            fails.append("%s day 1 full day needs %.0f of a %d bar (forced pass-out)" % (name, tot, b))
        if k in ("y1", "y2", "y3") and name in db["late_min_bar_pct"] and 100 * tot / b < db["late_min_bar_pct"][name]:
            fails.append("%s %s: a full day uses only %.0f%% of the bar (band >= %d%%: the bar stops binding)" % (name, k, 100 * tot / b, db["late_min_bar_pct"][name]))

for f in fails:
    print("energy_check: FAIL " + f)
print("energy_check: %s (%d persona-days x %d day lengths)" % ("ok" if not fails else "%d fails" % len(fails), len(rows) // len(LENS), len(LENS)))
sys.exit(1 if fails else 0)

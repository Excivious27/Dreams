#!/usr/bin/env python3
"""Chores (CONDUCT 11a P4 helper automation base): writes data/helpers.json. Edit this, never the JSON.

"Chores" (not "helpers": that word belongs to battle HelperUnit) are overnight farm jobs you assign
from Menu > Party > Chores. A worker is the pup ("pup"), a team animal ("animal:<ranch uid>"), a
recruited crew member ("crew:<id>", gangster arc) or a known partner ("partner:<id>").

Fields
- chores: {id: {name, verb, energy (per unit of work), base (units at level 1), per_level (extra units
           a level), xp (per unit), needs (chest: needs a deposit chest)}}
- workers: {kind: {energy (per night), chores [ids it may take]}}
  Team animals take only the chores their lessons open (team_animals.json lesson "chore") plus "pet"
  for guard; WORKERS["animal"]["chores"] is the outer limit.
- levels: xp needed for levels 2..MAX (per worker per chore).
- rules: unlock day, player xp per night cap (Leadership), forage table.
Self-check: no worker can do more than MAX_UNITS of any chore a night (helpers never out-farm you),
energy is enough for at least one unit of every chore it may take.
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CHORES = {
    "water": {"name": "Water the crops", "verb": "watered", "energy": 2, "base": 6, "per_level": 3, "xp": 1, "needs": ""},
    "harvest": {"name": "Harvest ripe crops", "verb": "harvested", "energy": 3, "base": 3, "per_level": 2, "xp": 2, "needs": "chest"},
    "feed": {"name": "Feed the animals", "verb": "fed", "energy": 1, "base": 4, "per_level": 2, "xp": 1, "needs": ""},
    "pet": {"name": "Keep the animals company", "verb": "kept company", "energy": 1, "base": 3, "per_level": 2, "xp": 1, "needs": ""},
    "forage": {"name": "Forage the edges", "verb": "foraged", "energy": 6, "base": 2, "per_level": 1, "xp": 2, "needs": "chest"},
}

WORKERS = {
    "pup": {"energy": 18, "chores": ["forage", "pet"]},
    "animal": {"energy": 14, "chores": ["forage", "pet", "harvest"]},
    "crew": {"energy": 24, "chores": ["water", "harvest", "feed", "pet", "forage"]},
    "partner": {"energy": 20, "chores": ["water", "harvest", "feed", "pet"]},
    "hand": {"energy": 16, "chores": ["feed", "pet"]},   # Ranching Farm Hand nodes (hand_slot); ranch chores only
}

LEVELS = [12, 30, 60, 100]  # xp for level 2, 3, 4, 5
MAX_LEVEL = len(LEVELS) + 1
MAX_UNITS = 20

RULES = {
    "unlock_day": 8,             # nothing in the first week (early-gating band)
    "lead_xp_cap": 4,            # Leadership xp the player gets a night for all chores together
    "forage": {"spring": ["berry", "wild_herb", "fiber"], "summer": ["berry", "wild_herb", "fiber"],
               "fall": ["mushroom", "blackberry", "fiber"], "winter": ["fiber", "wild_herb"]},
    "chests": ["chest", "shed"],  # fixed chest keys; placed chests "p:x,y" are added at runtime
}


def check(items):
    errs = []
    for kind, w in WORKERS.items():
        for c in w["chores"]:
            if c not in CHORES:
                errs.append(f"{kind}: unknown chore {c}")
            elif w["energy"] < CHORES[c]["energy"]:
                errs.append(f"{kind}: not enough energy for one {c}")
            else:
                top = CHORES[c]["base"] + CHORES[c]["per_level"] * (MAX_LEVEL - 1)
                if top > MAX_UNITS:
                    errs.append(f"{c}: {top} units at max level > {MAX_UNITS}")
    if LEVELS != sorted(LEVELS):
        errs.append("levels must rise")
    for se, ids in RULES["forage"].items():
        for i in ids:
            if items and i not in items:
                errs.append(f"forage {se}: {i} not an item")
    return errs


def main():
    items = {}
    p = os.path.join(ROOT, "data", "items.json")
    if os.path.exists(p):
        items = json.load(open(p))
    errs = check(items)
    if errs:
        print("gen_helpers: " + "; ".join(errs))
        sys.exit(1)
    out = {"chores": CHORES, "workers": WORKERS, "levels": LEVELS, "max_level": MAX_LEVEL,
           "max_units": MAX_UNITS, "rules": RULES}
    with open(os.path.join(ROOT, "data", "helpers.json"), "w") as f:
        json.dump(out, f, indent=1, sort_keys=True)
        f.write("\n")
    print(f"gen_helpers: {len(CHORES)} chores, {len(WORKERS)} worker kinds")


if __name__ == "__main__":
    main()

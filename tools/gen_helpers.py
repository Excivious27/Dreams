#!/usr/bin/env python3
"""Chores (CONDUCT 11a P4 helper automation base): writes data/helpers.json. Edit this, never the JSON.

"Chores" (not "helpers": that word belongs to battle HelperUnit) are overnight farm jobs you assign
from Menu > Party > Chores. A worker is the pup ("pup"), a team animal ("animal:<ranch uid>"), a
recruited crew member ("crew:<id>", gangster arc) or a known partner ("partner:<id>").

Fields
- chores: {id: {name, verb, energy (per unit of work), base (units at level 1), per_level (extra units
           a level), xp (per unit), needs (chest: needs a deposit chest)}}
- workers: {kind: {energy (per night), chores [ids it may take]}}
  Team animals take only the chores their lessons open (team_animals.json lesson "chore": fetch ->
  forage, guard -> guard, carry -> harvest); WORKERS["animal"]["chores"] is the outer limit.
- levels: xp needed for levels 2..MAX (per worker per chore).
- rules: unlock day, player xp per night cap (Leadership), forage table, helper spots (slots_by_tier),
  night value cap, helper pet share, chore sound gap/distance.
- level_energy / level_discount: chore levels add worker energy and cut a unit's cost (every level gains a unit).
- bond: per worker kind, extra energy per bond step (pup level, lesson rank, crew loyalty, partner hearts), capped.
- forage_regions: where a forager can go (visited regions, arc names), energy_mult per unit.
Self-check: no worker can do more than MAX_UNITS of any chore a night (helpers never out-farm you),
energy is enough for at least one unit of every chore it may take.
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CHORES = {
    "water": {"name": "Water the crops", "short": "waters", "verb": "watered", "energy": 2, "base": 6, "per_level": 3, "xp": 1, "needs": "",
              "sfx": ["water", "splash"]},
    "harvest": {"name": "Harvest ripe crops", "short": "harvests", "verb": "harvested", "energy": 3, "base": 3, "per_level": 2, "xp": 2, "needs": "chest",
                "sfx": ["harvest_pluck", "harvest"]},
    "feed": {"name": "Feed the animals", "short": "feeds", "verb": "fed", "energy": 1, "base": 4, "per_level": 2, "xp": 1, "needs": "",
             "sfx": ["hay_toss", "eat"]},   # c11b_14-06: existing files, C11a hay_toss first when it lands
    "pet": {"name": "Keep the animals company", "short": "keeps company", "verb": "kept company", "energy": 1, "base": 3, "per_level": 2, "xp": 1, "needs": "",
            "sfx": ["voice", "pickup"]},  # "voice" = the animal's own voice (RanchVoice)
    "forage": {"name": "Forage", "short": "forages", "verb": "foraged", "energy": 6, "base": 2, "per_level": 1, "xp": 2, "needs": "chest",
               "sfx": ["pick", "pickup"]},
    "guard": {"name": "Watch over the pens", "short": "guards", "verb": "watched over", "energy": 1, "base": 3, "per_level": 2, "xp": 1, "needs": "",
              "sfx": ["bark", "pickup"]},  # c11b_09-11: the Guard lesson's own chore (pens kept calm: a smaller friendship share, no lost mood)
}

WORKERS = {
    "pup": {"energy": 18, "chores": ["forage", "pet"]},
    "animal": {"energy": 16, "chores": ["forage", "pet", "harvest", "guard"]},
    "crew": {"energy": 24, "chores": ["water", "harvest", "feed", "pet", "forage"]},
    "partner": {"energy": 20, "chores": ["water", "harvest", "feed", "pet"]},
    "hand": {"energy": 16, "chores": ["feed", "pet"]},   # Ranching Farm Hand nodes (hand_slot); ranch chores only
}

LEVELS = [12, 30, 60, 100]  # xp for level 2, 3, 4, 5
MAX_LEVEL = len(LEVELS) + 1
MAX_UNITS = 20
LEVEL_ENERGY = 2          # c11b_06-13: +worker energy per chore level above 1
LEVEL_DISCOUNT = 0.1      # c11b_06-13: a unit costs chore.energy * (1 - 0.1*(lv-1)), floor 1
# c11b_06-07: worker energy grows with its bond (capped). Per kind: what counts and how much.
BOND = {"pup": {"per": 2, "cap": 10, "src": "pup skill level"},
        "animal": {"per": 2, "cap": 10, "src": "rank of the lesson that opens the chore + half its hearts"},
        "crew": {"per": 3, "cap": 9, "src": "loyalty hearts (0..3)"},
        "partner": {"per": 1, "cap": 10, "src": "friendship hearts"},
        "hand": {"per": 0, "cap": 0, "src": "none"}}
SECOND_CHORE_ENERGY = 24  # c11b_06-07: a worker with this much energy can take a second chore a night (energy split)

# c11b_06-05: forage where the worker can go: the farm edges (seasonal) plus every region you have been to.
# id: forage.json pool key; visit: scene id that must be in run.visited ("" = always); arc: "", penguins, gangsters.
FORAGE_REGIONS = [
    {"id": "edges", "pool": "", "visit": "", "arc": "", "name": "the farm edges", "name_gang": "the lot edges", "energy_mult": 1.0},
    {"id": "meadow", "pool": "meadow", "visit": "meadow", "arc": "penguins", "name": "the meadow", "name_gang": "", "energy_mult": 1.2},
    {"id": "forest", "pool": "forest", "visit": "forest", "arc": "penguins", "name": "the forest", "name_gang": "", "energy_mult": 1.3},
    {"id": "lake", "pool": "lake", "visit": "lake", "arc": "penguins", "name": "the lake shore", "name_gang": "", "energy_mult": 1.3},
    {"id": "beach", "pool": "beach", "visit": "beach", "arc": "penguins", "name": "the beach", "name_gang": "", "energy_mult": 1.4},
    {"id": "mountain", "pool": "mountain", "visit": "mountain", "arc": "penguins", "name": "the mountain path", "name_gang": "", "energy_mult": 1.5},
    {"id": "orchard_hills", "pool": "orchard_hills", "visit": "orchard_hills", "arc": "", "name": "the orchard hills", "name_gang": "the orchard hills", "energy_mult": 1.5},
    {"id": "jungle", "pool": "jungle", "visit": "jungle", "arc": "penguins", "name": "the jungle", "name_gang": "", "energy_mult": 1.7},
    {"id": "countryside", "pool": "wild", "visit": "countryside", "arc": "gangsters", "name": "", "name_gang": "the countryside", "energy_mult": 1.2},
    {"id": "docks", "pool": "beach", "visit": "docks", "arc": "gangsters", "name": "", "name_gang": "the docks", "energy_mult": 1.4},
    {"id": "underground", "pool": "mountain", "visit": "underground", "arc": "gangsters", "name": "", "name_gang": "the underground", "energy_mult": 1.5},
    {"id": "wastes", "pool": "wastes", "visit": "wastes", "arc": "", "name": "the wastes", "name_gang": "the wastes", "energy_mult": 1.7},
    {"id": "quarry", "pool": "quarry", "visit": "quarry", "arc": "", "name": "the quarry", "name_gang": "the quarry", "energy_mult": 1.6},
]

RULES = {
    "unlock_day": 8,             # nothing in the first week (early-gating band)
    "lead_xp_cap": 4,            # Leadership xp the player gets a night for all chores together
    "forage": {"spring": ["berry", "wild_herb", "fiber"], "summer": ["berry", "wild_herb", "fiber"],
               "fall": ["mushroom", "blackberry", "fiber"], "winter": ["fiber", "wild_herb"]},
    "forage_gang": {"spring": ["fiber", "wild_herb", "berry"], "summer": ["fiber", "wild_herb", "berry"],
                    "fall": ["fiber", "mushroom", "wild_herb"], "winter": ["fiber", "wild_herb"]},
    "chests": ["chest", "shed"],  # fixed chest keys; placed chests "p:x,y" are added at runtime
    # c11b_06-08: helper spots by progress tier (0..4) plus the Ranch Hand Hut tier, at most slots_max.
    # Farm Hands (Ranching skill nodes, kind "hand") are hired help and don't take a spot.
    "slots_by_tier": [3, 3, 4, 5, 5],
    "slots_hut": "hand_hut",
    "slots_max": 6,
    # c11b_12-01: the most a night of chores may put into chests (GameState.item_value), all workers together.
    "night_value_cap": [150, 300, 600, 1000, 1500],
    "helper_pet_share": 0.5,    # c11b_06-12: a helper's company counts half a pet (Ranch pet_friend)
    "guard_pet_share": 0.25,    # c11b_09-11: guarding keeps the pens calm: a quarter
    "cue_gap": 1.5,             # c11b_14-06: seconds between two chore sounds
    "cue_dist": 170.0,          # px: farther chores are silent
}


def check(items, forage=None):
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
    for kind, w in WORKERS.items():
        for c in w["chores"]:
            if c not in CHORES:
                continue
            ch = CHORES[c]
            prev = -1
            for lv in range(1, MAX_LEVEL + 1):
                by_level = ch["base"] + ch["per_level"] * (lv - 1)
                cost = max(1.0, ch["energy"] * (1 - LEVEL_DISCOUNT * (lv - 1)))
                by_energy = int((w["energy"] + LEVEL_ENERGY * (lv - 1)) // cost)
                u = min(by_level, by_energy, MAX_UNITS)
                if u <= prev:
                    errs.append(f"{kind}/{c}: level {lv} gives no extra unit ({u})")
                prev = u
    if len(RULES["slots_by_tier"]) != 5 or len(RULES["night_value_cap"]) != 5:
        errs.append("slots_by_tier / night_value_cap need 5 tiers")
    for r in FORAGE_REGIONS:
        if r["pool"] and forage and r["pool"] not in forage:
            errs.append(f"forage region {r['id']}: pool {r['pool']} not in forage.json")
    if LEVELS != sorted(LEVELS):
        errs.append("levels must rise")
    for se, ids in list(RULES["forage"].items()) + list(RULES["forage_gang"].items()):
        for i in ids:
            if items and i not in items:
                errs.append(f"forage {se}: {i} not an item")
    return errs


def main():
    items = {}
    p = os.path.join(ROOT, "data", "items.json")
    if os.path.exists(p):
        items = json.load(open(p))
    forage = {}
    fp = os.path.join(ROOT, "data", "forage.json")
    if os.path.exists(fp):
        forage = json.load(open(fp))
    errs = check(items, forage)
    if errs:
        print("gen_helpers: " + "; ".join(errs))
        sys.exit(1)
    out = {"chores": CHORES, "workers": WORKERS, "levels": LEVELS, "max_level": MAX_LEVEL,
           "max_units": MAX_UNITS, "rules": RULES, "level_energy": LEVEL_ENERGY, "level_discount": LEVEL_DISCOUNT,
           "bond": BOND, "second_chore_energy": SECOND_CHORE_ENERGY, "forage_regions": FORAGE_REGIONS}
    with open(os.path.join(ROOT, "data", "helpers.json"), "w") as f:
        json.dump(out, f, indent=1, sort_keys=True)
        f.write("\n")
    print(f"gen_helpers: {len(CHORES)} chores, {len(WORKERS)} worker kinds")


if __name__ == "__main__":
    main()

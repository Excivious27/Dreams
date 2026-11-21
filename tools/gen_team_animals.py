#!/usr/bin/env python3
"""Team animals (CONDUCT 11a P4): writes data/team_animals.json. Edit this, never the JSON.

A raised ranch animal (a Ranch roster uid, run.ranch.animals[uid]) can be trained once it is grown
and its friendship (Ranch "friend", 0..1000) reaches BOND_TO_TRAIN. Training is one lesson a day
(CHECK the animal or the Animals page): costs one treat item and energy, adds friendship, and after
RANK_AT lessons the lesson ranks up (max 3). An animal with at least one lesson can be put on the
team (Ranch "team" flag): it musters for campaign battles (CampaignGate.team kind "animal") and can
be given farm chores (data/helpers.json).

Fields
- species: {id: {name, name_gang, lessons [ids it can learn], hp, dmg, speed, carry (bool),
             treat [item ids, first one in the bag is used], voice, job_word}}
  Keys are Ranch species ids; ALIASES maps Ranch ids/strips (lamb, goat_kid, foal, llama_cria...) on.
- lessons: {id: {name, desc, desc_gang, job (battle job), chore (farm chore it opens), hp, dmg}}
  per rank bonuses.
- rules: bond/energy/rank numbers.
All ages: animals butt, kick, spit and bleat; nobody is hurt for real.
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

RULES = {
    "bond_to_train": 200,      # Ranch friend points (0..1000; 100 = one heart)
    "bond_per_lesson": 20,     # friendship a lesson adds
    "energy": 8,               # player energy per lesson
    "rank_at": [1, 4, 7],      # lessons needed for rank 1, 2, 3 (cumulative per lesson; rank 1 on the first, c11b_09-05)
    "max_rank": 3,
    "team_max": 2,             # animals on the team at once (base)
    "grown_days": 7,           # days after born_day before it can learn (matches farm young_days)
    "hp_per_tier": 6,          # + per GameState.progress_tier()
    "pup_margin": 4,           # an animal's hp stays this far under the pup's at equal tier
}

LESSONS = {
    "fetch": {"name": "Fetch", "desc": "Brings back forage it finds near you; on the farm it forages overnight.",
              "desc_gang": "Sniffs out loose goods and brings them back; on the farm it scrounges overnight.",
              "job": "healer", "chore": "forage", "hp": 2, "dmg": 0},
    "guard": {"name": "Guard", "desc": "Holds its ground beside you and shoves foes back.",
              "desc_gang": "Plants its hooves by you and shoves anybody pushy back.",
              "job": "warden", "chore": "guard", "hp": 6, "dmg": 1},  # c11b_09-11: its own chore (Chores "guard")
    "carry": {"name": "Carry", "desc": "Hauls a load: on the farm it carries the harvest to a chest.",
              "desc_gang": "Hauls the load: on the farm it carts the harvest to a chest.",
              "job": "warden", "chore": "harvest", "hp": 4, "dmg": 0},
    "attack": {"name": "Charge", "desc": "Butts, kicks or spits at foes that come for you.",
               "desc_gang": "Butts, kicks or spits at anyone who comes for you.",
               "job": "striker", "chore": "", "hp": 2, "dmg": 2},
}

SPECIES = {
    "goat": {"name": "Goat", "name_gang": "Goat", "lessons": ["attack", "guard", "fetch"],
             "hp": 18, "dmg": 2, "speed": 1.0, "carry": False, "treat": ["carrot", "apple", "hay"],
             "voice": "bleat", "job_word": "butts"},
    "llama": {"name": "Llama", "name_gang": "Llama", "lessons": ["guard", "carry", "attack"],
              "hp": 22, "dmg": 1, "speed": 0.9, "carry": True, "treat": ["apple", "carrot", "hay"],
              "voice": "bleat", "job_word": "spits"},
    "donkey": {"name": "Donkey", "name_gang": "Donkey", "lessons": ["carry", "fetch", "attack"],
               "hp": 22, "dmg": 1, "speed": 0.9, "carry": True, "treat": ["carrot", "apple", "hay"],
               "voice": "whinny", "job_word": "kicks"},
    "sheep": {"name": "Sheep", "name_gang": "Sheep", "lessons": ["fetch", "guard"],
              "hp": 16, "dmg": 1, "speed": 1.0, "carry": False, "treat": ["hay", "carrot", "apple"],
              "voice": "sheep", "job_word": "bumps"},
    "duck": {"name": "Duck", "name_gang": "Duck", "lessons": ["fetch"],
             "hp": 10, "dmg": 1, "speed": 1.1, "carry": False, "treat": ["wheat", "berry", "carrot"],
             "voice": "quack", "job_word": "pecks"},
    "hen": {"name": "Hen", "name_gang": "Hen", "lessons": ["fetch"],
            "hp": 10, "dmg": 1, "speed": 1.1, "carry": False, "treat": ["wheat", "berry", "carrot"],
            "voice": "cluck", "job_word": "pecks"},
}

# Ranch species ids / art strips that train as one of the species above.
ALIASES = {
    "goat_kid": "goat", "goat2": "goat", "kid_goat": "goat", "llama_cria": "llama", "llama_b": "llama",
    "foal": "donkey", "donkey_b": "donkey", "foal_b": "donkey", "lamb": "sheep", "sheep_woolly": "sheep",
    "chicken": "hen", "chick": "hen", "duckling": "duck",
}

NAMES = ["Biscuit", "Clover", "Pepper", "Maple", "Juniper", "Waffles", "Pebble", "Thistle", "Nutmeg", "Bramble",
         "Dumpling", "Fern", "Tansy", "Hazelnut", "Sprout", "Button"]


def check(items):
    errs = []
    for sid, sp in SPECIES.items():
        if not sp["lessons"]:
            errs.append(f"{sid}: no lessons")
        for l in sp["lessons"]:
            if l not in LESSONS:
                errs.append(f"{sid}: unknown lesson {l}")
        if "carry" in sp["lessons"] and not sp["carry"]:
            errs.append(f"{sid}: carry lesson without carry")
        for t in sp["treat"]:
            if items and t not in items:
                errs.append(f"{sid}: treat {t} not an item")
    for a, s in ALIASES.items():
        if s not in SPECIES:
            errs.append(f"alias {a} -> unknown {s}")
    if len(RULES["rank_at"]) != RULES["max_rank"]:
        errs.append("rank_at must have max_rank entries")
    bad_words = ["blood", "kill", "die", "dead", "gore"]
    for l in LESSONS.values():
        for k in ("desc", "desc_gang"):
            if any(w in l[k].lower().split() for w in bad_words):
                errs.append(f"lesson text not all-ages: {l[k]}")
    return errs


def main():
    items = {}
    p = os.path.join(ROOT, "data", "items.json")
    if os.path.exists(p):
        items = json.load(open(p))
    errs = check(items)
    if errs:
        print("gen_team_animals: " + "; ".join(errs))
        sys.exit(1)
    # c11b_14-07: one voice table: a species gen_ranch knows takes gen_ranch's voice (RanchVoice plays it).
    rp = os.path.join(ROOT, "data", "ranch.json")
    if os.path.exists(rp):
        rs = json.load(open(rp)).get("species", {})
        for sid, sp in SPECIES.items():
            key = {"hen": "chicken"}.get(sid, sid)
            if rs.get(key, {}).get("voice"):
                sp["voice"] = rs[key]["voice"]
    out = {"rules": RULES, "lessons": LESSONS, "species": SPECIES, "aliases": ALIASES, "names": NAMES}
    with open(os.path.join(ROOT, "data", "team_animals.json"), "w") as f:
        json.dump(out, f, indent=1, sort_keys=True)
        f.write("\n")
    print(f"gen_team_animals: {len(SPECIES)} species, {len(LESSONS)} lessons")


if __name__ == "__main__":
    main()

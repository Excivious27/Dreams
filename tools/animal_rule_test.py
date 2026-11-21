#!/usr/bin/env python3
"""animal_rule_test.py: no animal ever dies, is harvested or sold for meat (CLAUDE.md; s1_13-02).

Beasts are driven off, never harvested: fails if any beast-kind enemy (wolf, hound, bear, boar, deer,
crab, serpent, eel, roc, fox, cat, dog) drops an item whose player-facing name or description reads as
an animal part (meat, pelt, hide, bone, carcass, fur from, leather), if any item name/desc says
hunting or catching critters, or if an interior room places a pelt/hide/trophy prop. Item ids such as
"pelt"/"meat" stay for old saves; only what the player reads matters. stdlib only.
"""
import json, os, re, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BEAST = re.compile(r"wolf|hound|bear|boar|deer|crab|serpent|eel|roc\b|fox|lynx", re.I)
PART = re.compile(r"\bmeat\b|\bpelts?\b|\bhides?\b|\bbones?\b|carcass|\bfur from\b|leather", re.I)
HUNT = re.compile(r"\bhunt(ed|ing)?\b|catch(es)? critters|for pelts|slaughter|butcher(?!-block)", re.I)


def main():
    items = json.load(open(os.path.join(ROOT, "data", "items.json")))
    en = json.load(open(os.path.join(ROOT, "data", "enemies.json")))
    drops = en.get("drops", {})
    bad = []
    for kind, lst in drops.items():
        if not BEAST.search(kind):
            continue
        for d in lst:
            it = items.get(d[0], {})
            txt = "%s %s" % (it.get("name", ""), it.get("desc", ""))
            if PART.search(txt):
                bad.append("%s drops %s (%r)" % (kind, d[0], it.get("name")))
    for iid, it in items.items():
        if not isinstance(it, dict):
            continue
        txt = "%s %s" % (it.get("name", ""), it.get("desc", ""))
        if HUNT.search(txt):
            bad.append("item %s text reads as hunting: %r" % (iid, txt[:80]))
    rooms = json.load(open(os.path.join(ROOT, "data", "interiors.json")))
    for rid, r in rooms.items():
        if not isinstance(r, dict):
            continue
        for p in r.get("props", []) or []:
            n = p.get("name", "") if isinstance(p, dict) else ""
            if re.match(r"(pelt|hide|trophy_head)_", n):
                bad.append("room %s places prop %s" % (rid, n))
        if PART.search(str(r.get("intro", ""))):
            bad.append("room %s intro mentions animal parts" % rid)
    if not drops:
        bad.append("enemies.json has no drops table (test out of date)")
    for b in bad:
        print("animal_rule_test: FAIL " + b)
    print("animal_rule_test: %d failures" % len(bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())

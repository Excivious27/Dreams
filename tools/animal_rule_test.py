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
    # beaten beasts flee instead of the defeat puff (scripts/enemy.gd is_beast + the flee tween in _die)
    eg = open(os.path.join(ROOT, "scripts", "enemy.gd")).read()
    m = re.search(r"func is_beast\(\) -> bool:.*?for w in \[([^\]]*)\]", eg, re.S)
    words = re.findall(r'"(\w+)"', m.group(1)) if m else []
    if not m or "is_beast()" not in eg.split("func _die", 1)[-1][:1500]:
        bad.append("enemy.gd: beaten beasts must flee (is_beast check in _die)")
    for kind in en.get("enemies", {}):
        roc = kind.endswith("_roc") and 'ends_with("_roc")' in eg
        if BEAST.search(kind) and not roc and not any(w in kind for w in words):
            bad.append("beast %s is not covered by Enemy.is_beast (it would be killed, not driven off)" % kind)
    # C12 P3 (c12_06-01): villager words too (talk, first meetings, roles, indoor and region lines).
    VOICE = re.compile(r"\bhunt(ed|ing|er|s)?\b|\bmeat\b|\bi trap\b|what i trap|\bpelts?\b|for the pot", re.I)
    texts = []
    def walk(o, label):
        if isinstance(o, dict):
            for k, v in o.items():
                walk(v, label + "/" + str(k))
        elif isinstance(o, list):
            for i, v in enumerate(o):
                walk(v, label)
        elif isinstance(o, str):
            texts.append((label, o))
    walk(json.load(open(os.path.join(ROOT, "data", "talk.json"))), "talk.json")
    for nid, nd in json.load(open(os.path.join(ROOT, "data", "npcs.json"))).items():
        if isinstance(nd, dict):
            for k in ("role", "inside", "inside_gangsters"):
                walk(nd.get(k, []), "npcs.json %s/%s" % (nid, k))
    for rid, rg in json.load(open(os.path.join(ROOT, "data", "regions.json"))).items():
        for nd in (rg.get("npcs", []) if isinstance(rg, dict) else []):
            for k in ("lines", "lines_gangsters", "after", "after_gangsters", "done_lines"):
                walk(nd.get(k, []), "regions.json %s/%s/%s" % (rid, nd.get("id", ""), k))
    intros = open(os.path.join(ROOT, "scripts", "intros.gd")).read()
    for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', intros.split("const LINES", 1)[-1].split("static func", 1)[0]):
        texts.append(("intros.gd", m.group(1)))
    # C15 P6: the Egg Festival's "egg hunt" (painted eggs, a stash hunt in the gang arc) is a
    # festival game, not hunting animals; strip those phrases, everything else still fails.
    NOT_ANIMAL = re.compile(r"\b(egg|eggs|stash|scavenger|treasure)\s+hunts?\b|\bhunt(s|ing)?\s+(for\s+)?(the\s+)?(eggs?|stash|envelopes?)\b", re.I)
    for label, t in texts:
        if VOICE.search(NOT_ANIMAL.sub("", t)):
            bad.append("%s reads as hunting/meat: %r" % (label, t[:80]))
    if not drops:
        bad.append("enemies.json has no drops table (test out of date)")
    for b in bad:
        print("animal_rule_test: FAIL " + b)
    print("animal_rule_test: %d failures" % len(bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())

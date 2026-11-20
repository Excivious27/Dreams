#!/usr/bin/env python3
"""All-ages rule (C5 P6): every alcoholic drink is a trade good (type gift), never eaten or drunk:
no energy, heal, mana or buff. Fails on any item whose id/name reads as wine, ale, mead, cider, beer..."""
import json, os, re, sys
D = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
items = json.load(open(os.path.join(D, "data", "items.json")))
WORDS = re.compile(r"(^|[ _])(wine|ale|mead|cider|beer|lager|whiskey|whisky|rum|brandy|sake|champagne)($|[ _])")
SOFT = {"root_beer", "ginger_beer"}  # soft drinks
bad = []
n = 0
for k, v in items.items():
    if k in SOFT:
        continue
    text = (k + " " + str(v.get("name", ""))).lower()
    if not WORDS.search(text):
        continue
    n += 1
    if v.get("type") != "gift" or any(x in v for x in ("energy", "heal", "mana", "buff")):
        bad.append(k)
print("drink rule: %d alcoholic items checked" % n)
if bad:
    print("FAIL: drinkable alcohol:", ", ".join(bad))
    sys.exit(1)
print("ok")

#!/usr/bin/env python3
"""Minimal stand-in for the mega-region framework generator (Round 13, agent a5 owns
the real one). Writes data/mega_regions.json from the six new regions in
tools/mega_regions_new.py plus placeholders for the clusters a5 converts (Space,
Merkitty Colonies, Gangster Lieutenant Cities, Hollow Heart). When the two branches
are merged, a5's generator should simply import REGIONS from mega_regions_new.py.
Run: python3 tools/gen_mega_regions.py
"""
import json, os, sys
D = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(D, "tools"))
from mega_regions_new import REGIONS

PLACEHOLDERS = [  # a5's conversions: ids and areas only, so the list is complete
    {"id": "space", "name": "Space", "arc": "both", "theme": "space", "placeholder": True, "areas": [{"id": "moon"}, {"id": "station"}, {"id": "sky"}, {"id": "jungle"}]},
    {"id": "merkitty_colonies", "name": "Merkitty Colonies", "arc": "penguins", "theme": "sea", "placeholder": True,
     "areas": [{"id": "colony_coral"}, {"id": "colony_kelp"}, {"id": "colony_ice"}, {"id": "colony_ember"}]},
    {"id": "lieutenant_cities", "name": "Lieutenant Cities", "arc": "gangsters", "theme": "city", "placeholder": True,
     "areas": [{"id": "docks"}, {"id": "neon"}, {"id": "uptown"}, {"id": "underground"}]},
    {"id": "hollow_heart", "name": "The Hollow Heart", "arc": "both", "theme": "cave", "placeholder": True, "areas": [{"id": "hollow_heart"}]},
]

out = {"_": "Mega regions (map tabs). Written by tools/gen_mega_regions.py.", "regions": PLACEHOLDERS + REGIONS}
json.dump(out, open(f"{D}/data/mega_regions.json", "w"), indent=1, ensure_ascii=False)
print("mega_regions.json:", len(out["regions"]), "regions")

#!/usr/bin/env python3
"""C11a P3: Ranching skill-node icons. The farming icon sheet (w340) already has the animal
nodes drawn (Gentle Hands, Warm Barn, Fresh Straw, Rancher, Happy Herd, Brushed Coats, Best in
Show, Big Eggs, Full Pails); this matches them by name onto the Ranching tree as
ui/node_ranching_<id> (same matcher as slice_world.w340_352). Re-runnable; run after
gen_skill_trees.py.   python3 tools/slice_c11a_p3.py
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import slice_world as W
S = W.S
mpath = os.path.join(S.OUT, "manifest.json")
S.manifest.update(json.load(open(mpath)))
W.SKILL_SHEETS = {"w340_skill_icons_farming.png": "ranching"}
for f in os.listdir(os.path.join(S.OUT, "ui")):  # rm before write: art files are hardlinked
    if f.startswith("node_ranching_") and f.endswith(".png"):
        os.remove(os.path.join(S.OUT, "ui", f))
W.w340_352()
with open(mpath, "w") as fh:
    json.dump(S.manifest, fh, indent=1, sort_keys=True)

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

# The rest of the tree + the Ranching emblem: two 4x3 icon sheets rendered for C11a P3
# (art/incoming/c11a/p3_ranch_icons_a/b.png). Sheet a cell 0 = ui/skill3_ranching; the other
# 23 cells go to the filler nodes that had no drawn icon, by name.
import numpy as np
from PIL import Image
def _runs(v):
    out, st = [], None
    for i, x in enumerate(list(v) + [False]):
        if x and st is None: st = i
        if not x and st is not None:
            if i - st > 60: out.append((st, i))
            st = None
    return out
ORDER = ["@emblem", "Soft Brush", "Clean Stalls", "Shiny Coats", "Proud Hens", "Blue Ribbon", "Fine Fleece", "Cream Top",
         "Nest Box", "Warm Lamp", "Little Ones", "Spring Lambs",
         "Quick Chicks", "Growing Up", "Strong Kids", "Proud Parents", "Kind Voice", "Known Face", "Treat Pocket", "Follow Me",
         "Trusted", "Barn Buddy", "Best Pals", "Whistle Call"]
cells = []
for f in ("a", "b"):
    path = os.path.join(S.INC, "c11a", "p3_ranch_icons_%s.png" % f)
    if not os.path.exists(path):
        continue
    rgba = np.array(Image.open(path).convert("RGBA"))
    m = rgba[..., 3] > 40
    for y0, y1 in _runs(m.sum(axis=1) > 20)[:3]:
        for x0, x1 in _runs(m[y0:y1].sum(axis=0) > 20)[:4]:
            cells.append(Image.fromarray(rgba[y0:y1, x0:x1].copy()))
nodes = json.load(open(os.path.join(S.OUT, "..", "..", "data", "skills.json")))["skills"]["ranching"]["nodes"]
by_name = {str(n["name"]): n for n in nodes if not n.get("unlock")}
done = 0
for nm, im in zip(ORDER, cells):
    if nm == "@emblem":
        name = "skill3_ranching"
    elif nm in by_name:
        name = "node_ranching_%s" % by_name[nm]["id"]
    else:
        continue
    fp = os.path.join(S.OUT, "ui", name + ".png")
    if os.path.exists(fp):
        os.remove(fp)
    S.save(S.scale_to(im, 48, 48), "ui", name); done += 1
print("   ranching sheets: %d cells, %d saved" % (len(cells), done))
with open(mpath, "w") as fh:
    json.dump(S.manifest, fh, indent=1, sort_keys=True)

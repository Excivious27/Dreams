#!/usr/bin/env python3
"""Weather overlay strips (fx/ov_*, fx/ov2_*): wipe solid columns/rows that are
sheet borders caught during slicing (they flash as bars every few frames).
Weather art is sparse, so any column or row that is mostly opaque is a border.
Run after the slicers."""
import json, os
import numpy as np
from PIL import Image
GEN = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "gen")
man = json.load(open(os.path.join(GEN, "manifest.json")))
fixed = 0
for name, info in man.get("fx", {}).items():
    if not (name.startswith("ov_") or name.startswith("ov2_")) or name.endswith("fog") or "sandstorm" in name or "glare" in name or "godrays" in name or "moonglow" in name:
        continue
    p = os.path.join(GEN, info["file"])
    a = np.array(Image.open(p).convert("RGBA"))
    al = a[..., 3] > 160
    cols = al.mean(0) > 0.6
    rows = al.mean(1) > 0.6
    if cols.any() or rows.any():
        a[:, cols, 3] = 0
        a[rows, :, 3] = 0
        Image.fromarray(a).save(p)
        fixed += 1
        print(name, int(cols.sum()), "cols", int(rows.sum()), "rows")
print("fixed", fixed)

#!/usr/bin/env python3
"""Paint over the thin white seam lines that slicing left inside ground tiles
(they show as stripes across big areas). Re-runnable; run after slicing.
    python3 tools/tile_seams.py
"""
import os, json
import numpy as np
from PIL import Image
G = os.path.join(os.path.dirname(__file__), "..", "art", "gen")
m = json.load(open(os.path.join(G, "manifest.json")))["tiles"]
fixed = 0
for k, v in m.items():
    p = os.path.join(G, v["file"])
    im = Image.open(p).convert("RGBA")
    a = np.asarray(im).copy()
    if a.shape[0] < 8 or a.shape[1] < 8:
        continue
    bright = (a[..., :3].min(axis=2) > 205) & (a[..., 3] > 0)
    changed = False
    for axis in (0, 1):
        frac = bright.mean(axis=axis)            # per column (axis 0) or row (axis 1)
        bad = np.where(frac > 0.45)[0]
        n = len(frac)
        if len(bad) == 0 or len(bad) > n // 4:
            continue                             # nothing, or the tile is just pale
        good = [i for i in range(n) if i not in set(bad)]
        for b in bad:
            src = min(good, key=lambda g: abs(g - b))
            if axis == 0:
                a[:, b] = a[:, src]
            else:
                a[b, :] = a[src, :]
        changed = True
    if changed:
        Image.fromarray(a).save(p)
        fixed += 1
print("tiles repaired:", fixed)

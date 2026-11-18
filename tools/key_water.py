#!/usr/bin/env python3
"""Cut the painted water out of props/buildings that sit in real water, so the
map's own (animated) water shows through instead of a hard blue rectangle.
Re-run after slicing.   python3 tools/key_water.py
"""
import os
import numpy as np
from PIL import Image
G = os.path.join(os.path.dirname(__file__), "..", "art", "gen")
TARGETS = [("buildings/water_mill.png", 0.55), ("props/crab_pot_water.png", 0.0),
           ("buildings/fishing_hut.png", 0.6), ("buildings/lighthouse.png", 0.8),
           ("props/bridge3_ew_a.png", 0.5), ("props/foot3_ew_a.png", 0.5),
           ("props/bridge_wood2.png", 0.4), ("props/r_riverlands_34.png", 0.6),
           ("props/beaver_dam.png", 0.5)]
for f, top in TARGETS:
    p = os.path.join(G, f)
    if not os.path.exists(p):
        continue
    a = np.asarray(Image.open(p).convert("RGBA")).astype(int)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    water = (b > r + 25) & (b > g - 5) & (b > 90) & (al > 0)
    water[: int(a.shape[0] * top)] = False
    a[water, 3] = 0
    Image.fromarray(a.astype("uint8")).save(p)
    print("keyed", f, round(float(water.mean()), 3))

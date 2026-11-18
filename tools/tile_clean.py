#!/usr/bin/env python3
"""Pick the clean fill tiles of each ground/water set (no slicing seams, no
stray edge pieces, low contrast) so big areas read as one surface instead of a
patchwork. Writes data/tile_clean.json {set: [indices]}.
    python3 tools/tile_clean.py
"""
import json, os, re
import numpy as np
from PIL import Image
G = os.path.join(os.path.dirname(__file__), "..", "art", "gen")
m = json.load(open(os.path.join(G, "manifest.json")))["tiles"]
sets = {}
for k in m:
    mm = re.match(r"(.+)_fill_(\d+)$", k)
    if mm:
        sets.setdefault(mm.group(1), []).append(int(mm.group(2)))
out = {}
for s, idx in sorted(sets.items()):
    scores = []
    for i in idx:
        a = np.asarray(Image.open(os.path.join(G, m["%s_fill_%d" % (s, i)]["file"])).convert("RGBA")).astype(float)
        rgb, al = a[..., :3], a[..., 3]
        if (al < 200).mean() > 0.02:
            continue                       # holes: an edge piece, not a fill
        bright = (rgb.min(axis=2) > 205)
        if bright.mean(axis=0).max() > 0.35 or bright.mean(axis=1).max() > 0.35:
            continue                       # a slicing seam (white line)
        lum = rgb.mean(axis=2)
        h, w = lum.shape
        sat = rgb.max(axis=2) - rgb.min(axis=2)
        if s not in ("bog",) and ((sat < 18) & (lum > 90)).mean() > 0.03:
            continue                       # grey stones / smudges stamped in
        # Big tile-to-tile colour casts make a grid; judge against the set later.
        # Edge pieces differ strongly between halves; fills don't.
        halves = max(abs(lum[: h // 2].mean() - lum[h // 2:].mean()), abs(lum[:, : w // 2].mean() - lum[:, w // 2:].mean()))
        scores.append((lum.std() + 2.0 * halves, i, lum.mean()))
    if not scores:
        continue
    scores.sort()
    med = np.median([x[2] for x in scores])
    keep = [i for sc, i, mean in scores if abs(mean - med) < 7][:6]
    out[s] = keep or [scores[0][1]]
json.dump(out, open(os.path.join(os.path.dirname(__file__), "..", "data", "tile_clean.json"), "w"), indent=1)
print({k: len(v) for k, v in out.items()})

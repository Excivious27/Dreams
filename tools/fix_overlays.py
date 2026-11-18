#!/usr/bin/env python3
"""Weather overlay strips (fx/ov_*, fx/ov2_*): wipe solid columns/rows that are
sheet borders caught during slicing (they flash as bars every few frames).
Weather art is sparse, so any column or row that is mostly opaque is a border.
Run after the slicers."""
import json, os
import numpy as np
from PIL import Image
GEN = os.environ.get("ART_GEN") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "gen")
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

# Cloud shadows: the sheet gives them binary alpha, so on snow and pale ground they drift as
# pixel-edged grey blocks. Blur the alpha once (skipped when it already has soft edges).
cs = man.get("fx", {}).get("cloud_shadow")
if cs:
    from PIL import ImageFilter
    p = os.path.join(GEN, cs["file"])
    im = Image.open(p).convert("RGBA")
    al = np.array(im)[..., 3]
    if ((al > 20) & (al < 235)).mean() < 0.05:  # not softened yet
        arr = np.array(im)
        solid = al > 200
        if solid.any():
            arr[~solid, :3] = arr[solid, :3].mean(0).astype(np.uint8)  # no dark halo where the blur reaches keyed pixels
        im = Image.fromarray(arr)
        im.putalpha(im.getchannel("A").filter(ImageFilter.GaussianBlur(5)))
        im.save(p)
        print("cloud_shadow softened")

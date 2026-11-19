#!/usr/bin/env python3
"""CONDUCT 2 (c2_09) art: the community farm's overnight build sites.

art/incoming/r13/c2_09_build_sites.png (image tool edit of cf_crates/wood_fence_pile):
four pieces left to right -> art/gen/props/cf_site_lumber (planks on sawhorses),
cf_site_stone (cut stone + mortar bucket), cf_site_saplings (wheelbarrow of saplings),
cf_site_glass (crate of panes under a tarp). The render's magenta-tinted ground
shadows become soft dark shadows. Community farm shows them while the crew builds
a stage overnight (Commons.pending).
Run after the other slicers:  python3 tools/slice_r13_c2_09.py
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
from slice_comp import blobs, rows_of
import numpy as np
from PIL import Image

NAMES = ["cf_site_lumber", "cf_site_stone", "cf_site_saplings", "cf_site_glass"]
WIDTH = 64  # 2x-detail pixels (cf_crates is 76 at prop scale 0.45)


def build_sites():
    f = "r13/c2_09_build_sites.png"
    p = os.path.join(S.INC, f)
    if not os.path.exists(p):
        return
    a = np.asarray(Image.open(p).convert("RGBA")).astype(np.int32)
    shadow = (a[..., 3] > 40) & (a[..., 0] > a[..., 1] + 40) & (a[..., 2] > a[..., 1] + 40)
    a[shadow] = [12, 8, 16, 80]
    a[a[..., 3] <= 40] = [0, 0, 0, 0]
    rgba = a.astype(np.uint8)
    rows = rows_of(blobs(rgba, merge=14, min_area=3000))
    pieces = max(rows, key=len)
    assert len(pieces) == 4, [len(r) for r in rows]
    for name, b in zip(NAMES, pieces):
        im = Image.fromarray(rgba[b[1]:b[3], b[0]:b[2]])
        h = max(1, round(im.height * WIDTH / im.width))
        im = im.resize((WIDTH, h), Image.LANCZOS)
        q = np.asarray(im).copy()
        solid = q[..., 3] > 150
        q[..., 3] = np.where(solid, 255, np.where(q[..., 3] > 30, 80, 0))
        out = os.path.join(S.OUT, "props", name + ".png")
        if os.path.exists(out):
            os.remove(out)  # never write a (possibly hardlinked) art file in place
        S.save(Image.fromarray(q), "props", name)


STEPS = [build_sites]

if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    for fn in STEPS:
        fn(); print("ok", fn.__name__)
    tmp = mpath + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(S.manifest, fh, indent=1, sort_keys=True)
    os.replace(tmp, mpath)

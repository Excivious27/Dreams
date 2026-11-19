#!/usr/bin/env python3
"""Round 13 (a9) art: the lake lighthouse as it stands before Marlowe relights it.

art/incoming/r13_a9/lighthouse_broken.png (image tool edit of the lit strip):
one derelict lighthouse on its rock -> art/gen/buildings/lighthouse_broken.png,
the same frame size and bottom-centre anchor as one frame of `lighthouse`, so it
drops into the lit lighthouse's spot. Run after the other slicers:
    python3 tools/slice_r13_a9.py
"""
import json, os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
from slice_art import load, crop, scale_to
from slice_comp import blobs
from PIL import Image


def lighthouse_broken():
    f = "r13_a9/lighthouse_broken.png"
    if not os.path.exists(os.path.join(S.INC, f)):
        return
    rgba = load(f)
    bs = blobs(rgba, merge=12, min_area=2000)
    x0 = min(b[0] for b in bs); y0 = min(b[1] for b in bs)
    x1 = max(b[2] for b in bs); y1 = max(b[3] for b in bs)
    lit = S.manifest.get("buildings", {}).get("lighthouse", {})
    cw, ch = int(lit.get("cell_w", 148)), int(lit.get("cell_h", 224))
    img = scale_to(crop(rgba, (x0, y0, x1, y1)), width=cw - 6, height=ch)
    out = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    out.alpha_composite(img, ((cw - img.width) // 2, ch - img.height))
    S.save(out, "buildings", "lighthouse_broken")


STEPS = [lighthouse_broken]

if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    for fn in STEPS:
        fn(); print("ok", fn.__name__)
    tmp = mpath + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(S.manifest, fh, indent=1, sort_keys=True)
    os.replace(tmp, mpath)  # a new file: never write the (hardlinked) manifest in place

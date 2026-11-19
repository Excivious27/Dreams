#!/usr/bin/env python3
"""CONDUCT 1 (c1_12) art: the melee wind-up telegraph icon.

art/incoming/r13/c1_12_tele_strike.png (image tool edit of tele_lunge/tele_stomp):
one framed claw-slash icon -> art/gen/ui/tele_strike.png, the same 17x16 size as
the other tele_* icons (Enemy._draw shows it while a foe winds up a hit).
Run after the other slicers:  python3 tools/slice_r13_c1_12.py
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
from slice_art import load, crop
from slice_comp import blobs
import numpy as np
from PIL import Image


def tele_strike():
    f = "r13/c1_12_tele_strike.png"
    if not os.path.exists(os.path.join(S.INC, f)):
        return
    rgba = load(f)
    bs = blobs(rgba, merge=12, min_area=2000)
    x0 = min(b[0] for b in bs); y0 = min(b[1] for b in bs)
    x1 = max(b[2] for b in bs); y1 = max(b[3] for b in bs)
    ref = S.manifest.get("ui", {}).get("tele_lunge", {})
    w, h = int(ref.get("w", 17)), int(ref.get("h", 16))
    img = crop(rgba, (x0, y0, x1, y1)).resize((w, h), Image.BOX)
    a = np.asarray(img).copy()
    a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
    out = os.path.join(S.OUT, "ui", "tele_strike.png")
    if os.path.exists(out):
        os.remove(out)  # never write a (possibly hardlinked) art file in place
    S.save(Image.fromarray(a), "ui", "tele_strike")


STEPS = [tele_strike]

if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    for fn in STEPS:
        fn(); print("ok", fn.__name__)
    tmp = mpath + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(S.manifest, fh, indent=1, sort_keys=True)
    os.replace(tmp, mpath)

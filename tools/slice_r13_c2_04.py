#!/usr/bin/env python3
"""CONDUCT 2 (c2_04) art: Skee-Ball stage + snack-bar icons.

art/incoming/r13_arcade/c2_skee_stage.png (image tool, 1024x1536, full bleed)
    -> art/gen/arcade/stage_skee.png (540 wide; ArcadeSkee maps its hit zones
       in the 1024-wide source coordinates, so keep the crop at x 0..1024)
art/incoming/r13_arcade/c2_snacks.png (4 icons on magenta, one row)
    -> art/gen/items/snack_cotton_candy, snack_popcorn, snack_pretzel (32px, manifest)
    -> art/gen/arcade/skee_ball_ball.png (the rolled ball)
Never writes a file in place (art is hardlinked): each output is removed first.
    python3 tools/slice_r13_c2_04.py
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
from slice_art import load, crop
from slice_comp import blobs, rows_of
import numpy as np
from PIL import Image


def _rm(p):
    if os.path.exists(p):
        os.remove(p)


def stage():
    f = os.path.join(S.INC, "r13_arcade/c2_skee_stage.png")
    if not os.path.exists(f):
        return
    im = Image.open(f).convert("RGBA")
    assert im.size == (1024, 1536), im.size
    out = os.path.join(S.OUT, "arcade", "stage_skee.png")
    _rm(out)
    im.resize((540, 810), Image.LANCZOS).save(out)


def _icon(img, h=32):
    # Fit into 32x32 (BOX keeps the pixel look), hard alpha edge.
    k = min(32.0 / img.width, float(h) / img.height)
    img = img.resize((max(1, round(img.width * k)), max(1, round(img.height * k))), Image.BOX)
    a = np.asarray(img).copy()
    a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
    return Image.fromarray(a)


def snacks():
    f = "r13_arcade/c2_snacks.png"
    if not os.path.exists(os.path.join(S.INC, f)):
        return
    rgba = load(f)
    rs = rows_of(blobs(rgba, merge=14, min_area=3000))
    row = max(rs, key=len)
    assert len(row) == 4, [len(r) for r in rs]
    row = sorted(row, key=lambda b: b[0])
    for b, name in zip(row[:3], ["snack_cotton_candy", "snack_popcorn", "snack_pretzel"]):
        _rm(os.path.join(S.OUT, "items", name + ".png"))
        S.save(_icon(crop(rgba, b)), "items", name)
    ball = crop(rgba, row[3])
    k = 48.0 / max(ball.width, ball.height)
    ball = ball.resize((round(ball.width * k), round(ball.height * k)), Image.LANCZOS)
    out = os.path.join(S.OUT, "arcade", "skee_ball_ball.png")
    _rm(out)
    ball.save(out)


STEPS = [stage, snacks]

if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    for fn in STEPS:
        fn(); print("ok", fn.__name__)
    tmp = mpath + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(S.manifest, fh, indent=1, sort_keys=True)
    os.replace(tmp, mpath)

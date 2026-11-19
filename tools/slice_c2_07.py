#!/usr/bin/env python3
"""CONDUCT 2 (c2_07): Rec Center decor renders (art/incoming/c2_07/).

  rec_arcade_props.png -> props/rec_air_hockey, rec_pinball_a, rec_pinball_b,
                          rec_capsule, rec_photo_booth, rec_stool_table
  rec_wall_decor.png   -> furniture/rec_poster_0..3 (wall_props), props/rec_neon_0..3
  rec_carpets.png      -> tiles/rec_carpet, tiles/rec_carpet_gang (96 px seamless squares)

    python3 tools/slice_c2_07.py   (merges into the manifest)
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
import slice_art as S
from slice_art import load, crop, scale_to, save
from slice_comp import blobs, rows_of
from PIL import Image

D = "c2_07/"


def props():
    rgba = load(D + "rec_arcade_props.png")
    rows = rows_of(blobs(rgba, merge=14, min_area=3000))
    assert [len(r) for r in rows[:2]] == [3, 3], [len(r) for r in rows]
    spec = [[("rec_air_hockey", "w", 64), ("rec_pinball_a", "h", 66), ("rec_pinball_b", "h", 66)],
            [("rec_capsule", "h", 54), ("rec_photo_booth", "h", 78), ("rec_stool_table", "h", 42)]]
    for r in range(2):
        for (name, k, v), b in zip(spec[r], rows[r]):
            im = crop(rgba, b)
            save(scale_to(im, width=v) if k == "w" else scale_to(im, height=v), "props", name)


def wall():
    rgba = load(D + "rec_wall_decor.png")
    rows = rows_of(blobs(rgba, merge=6, min_area=3000))
    assert [len(r) for r in rows[:2]] == [4, 4], [len(r) for r in rows]
    for i, b in enumerate(rows[0]):
        save(scale_to(crop(rgba, b), height=52), "furniture", "rec_poster_%d" % i)
    for i, b in enumerate(rows[1]):
        save(scale_to(crop(rgba, b), height=40), "props", "rec_neon_%d" % i)


def seamless(a):
    n, m = a.shape[:2]
    band = 5
    r = np.roll(a, (n // 2, m // 2), (0, 1))
    dy = np.minimum(np.arange(n), n - 1 - np.arange(n)).astype(float)
    dx = np.minimum(np.arange(m), m - 1 - np.arange(m)).astype(float)
    wy = np.clip(dy / band, 0, 1); wy = wy * wy * (3 - 2 * wy)
    wx = np.clip(dx / band, 0, 1); wx = wx * wx * (3 - 2 * wx)
    w = np.minimum.outer(wy, wx)[..., None]
    return a * w + r * (1 - w)


def carpets():
    rgba = load(D + "rec_carpets.png")
    bs = sorted(blobs(rgba, merge=2, min_area=100000), key=lambda b: b[0])
    assert len(bs) == 2, bs
    for b, name in zip(bs, ["rec_carpet", "rec_carpet_gang"]):
        x0, y0, x1, y1 = b
        s = min(x1 - x0, y1 - y0) - 16
        im = Image.fromarray(rgba[y0 + 8:y0 + 8 + s, x0 + 8:x0 + 8 + s]).convert("RGB")
        im = im.resize((96, 96), Image.LANCZOS)
        a = seamless(np.asarray(im).astype(float))
        out = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).convert("RGBA")
        save(out, "tiles", name)


STEPS = [props, wall, carpets]

if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    for fn in STEPS:
        if sys.argv[1:] and fn.__name__ not in sys.argv[1:]:
            continue
        fn()
        print("ok", fn.__name__)
    with open(mpath + ".tmp", "w") as f:
        json.dump(S.manifest, f, indent=1, sort_keys=True)
    os.remove(mpath)
    os.rename(mpath + ".tmp", mpath)

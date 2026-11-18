#!/usr/bin/env python3
"""Make every art/gen/seamless/*.png truly wrap.

The slicer trims and resizes the generator's squares, which breaks their wrap,
so a faint line shows every 8 cells (the "grass grid"). This blends each
texture with itself shifted by half its size, with a smooth weight that is 1 in
the middle and 0 at the edges, so opposite edges match exactly.

    python3 tools/make_seamless.py          (after slicing; idempotent enough to re-run)
    python3 tools/make_seamless.py --check  (prints the wrap jump vs a normal step)
"""
import os, sys, glob
import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
BAND = 48


def seamless(a):
    n, m = a.shape[:2]
    r = np.roll(a, (n // 2, m // 2), (0, 1))
    dy = np.minimum(np.arange(n), n - 1 - np.arange(n)).astype(float)
    dx = np.minimum(np.arange(m), m - 1 - np.arange(m)).astype(float)
    wy = np.clip(dy / BAND, 0, 1); wy = wy * wy * (3 - 2 * wy)
    wx = np.clip(dx / BAND, 0, 1); wx = wx * wx * (3 - 2 * wx)
    w = np.minimum.outer(wy, wx)[..., None]
    return a * w + r * (1 - w)


def stats(a):
    l = a[..., :3].mean(2)
    step = np.abs(np.diff(l, axis=1)).mean()
    wrap = max(np.abs(l[:, 0] - l[:, -1]).mean(), np.abs(l[0] - l[-1]).mean())
    return step, wrap


check = "--check" in sys.argv
bad = 0
for f in sorted(glob.glob(os.path.join(ROOT, "art/gen/seamless/*.png"))):
    im = Image.open(f).convert("RGBA")
    a = np.asarray(im).astype(float)
    step, wrap = stats(a)
    if check:
        flag = wrap > 1.3 * step + 1
        bad += flag
        print("%-28s step %5.1f wrap %5.1f %s" % (os.path.basename(f), step, wrap, "SEAM" if flag else ""))
        continue
    if wrap <= 1.3 * step + 1:
        continue  # already wraps
    o = seamless(a)
    o[..., 3] = a[..., 3]  # keep the alpha as it was (water edges etc.)
    Image.fromarray(o.clip(0, 255).astype(np.uint8)).save(f)
    print("fixed", os.path.basename(f), round(wrap, 1), "->", round(stats(o)[1], 1))
if check:
    print("seams:", bad)

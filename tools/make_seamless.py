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


# Patterned floors (checker squares, brick bond) can't be cross-faded: the blend
# ghosts the pattern at the joins (c5_12 #2). Right after a fresh slice, rebuild them
# from a clean crop of whole periods (box in the sliced 256 texture, repeats x/y):
#   python3 tools/make_seamless.py --periodic   (--periodic-auto: only PERIODIC_AUTO, any time)
PERIODIC = {"floor_checker": ((59, 58, 195, 196), (2, 2)), "city_pavement": ((81, 61, 169, 207), (3, 2))}
# Plank floors whose period is found in the clean centre (the cross-fade only touches the edges):
# one or more whole periods are cut from the middle and tiled (c10b_08-22). Safe to re-run.
PERIODIC_AUTO = ["floor_light", "floor_dark"]


def _period(l, axis, lo=12, hi=128):
    x = l - l.mean()
    best, bk = -1, 0
    for k in range(lo, hi):
        a = x[:, :-k] if axis == 1 else x[:-k]
        b = x[:, k:] if axis == 1 else x[k:]
        d = np.sqrt((a * a).sum() * (b * b).sum())
        c = (a * b).sum() / d if d else 0
        if c > best:
            best, bk = c, k
    return bk if best > 0.6 else 0


def auto_box(f):
    """Box of whole periods inside the centre 128 px (axes without a period keep the centre 128)."""
    a = np.asarray(Image.open(f).convert("RGBA")).astype(float)
    c = a[64:192, 64:192, :3].mean(2)
    px, py = _period(c, 1), _period(c, 0)
    w = (128 // px) * px if px else 128
    h = (128 // py) * py if py else 128
    return (64, 64, 64 + w, 64 + h), (max(1, round(256 / w)), max(1, round(256 / h)))


def periodic(f, box, reps):
    a = np.asarray(Image.open(f).convert("RGBA"))
    x0, y0, x1, y1 = box
    mos = np.tile(a[y0:y1, x0:x1], (reps[1], reps[0], 1))
    pad = 12
    big = np.pad(mos, ((pad, pad), (pad, pad), (0, 0)), mode="wrap")
    H, W = mos.shape[:2]
    sy, sx = 256 / H, 256 / W
    im = Image.fromarray(big).resize((round(big.shape[1] * sx), round(big.shape[0] * sy)), Image.LANCZOS)
    oy, ox = round(pad * sy), round(pad * sx)
    o = np.asarray(im.crop((ox, oy, ox + 256, oy + 256))).copy()
    o[..., 3] = 255
    os.remove(f)  # hardlinked art: never write in place
    Image.fromarray(o).save(f)
    print("periodic", os.path.basename(f))


if "--periodic" in sys.argv:
    for nm, (box, reps) in PERIODIC.items():
        periodic(os.path.join(ROOT, "art/gen/seamless/%s.png" % nm), box, reps)
if "--periodic" in sys.argv or "--periodic-auto" in sys.argv:
    for nm in PERIODIC_AUTO:
        f = os.path.join(ROOT, "art/gen/seamless/%s.png" % nm)
        if os.path.exists(f):
            periodic(f, *auto_box(f))
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
    if wrap <= 1.3 * step + 1 or os.path.basename(f)[:-4] in PERIODIC or os.path.basename(f)[:-4] in PERIODIC_AUTO:
        continue  # already wraps (patterned floors: --periodic)
    o = seamless(a)
    o[..., 3] = a[..., 3]  # keep the alpha as it was (water edges etc.)
    os.remove(f)  # hardlinked art: never write in place
    Image.fromarray(o.clip(0, 255).astype(np.uint8)).save(f)
    print("fixed", os.path.basename(f), round(wrap, 1), "->", round(stats(o)[1], 1))
if check:
    print("seams:", bad)

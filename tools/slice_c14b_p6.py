#!/usr/bin/env python3
"""C14b P6 slicer: creature/enemy idle strips from art/incoming/c14bp6/ (magenta key).

Each sheet is one row of N frames on flat magenta. Frames are found as connected
components (after a small dilation), keyed, scaled by ONE factor (from the tallest
frame to the target cell height) and bottom-aligned on a shared cell so feet stay on
one baseline. Writes art/gen/<group>/<anim>.png and updates manifest.json.
Never edits an existing file in place: removes it first, then writes.
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INC = os.path.join(ROOT, "art", "incoming", "c14bp6")
GEN = os.path.join(ROOT, "art", "gen")

# (sheet, group, anim, frames, cell height, extra manifest fields)
JOBS = [
    ("c14bp6_president_idle.png", "characters/president", "idle", 4, 83, {"fps": 3.0, "pingpong": False}),
    ("c14bp6_rabbit_idle.png", "wildlife/rabbit", "idle", 4, 37, {}),
    ("c14bp6_squirrel_idle.png", "wildlife/squirrel", "idle", 4, 32, {}),
    ("c14bp6_sparrow_idle.png", "wildlife/sparrow", "idle", 4, 26, {"_trim": 0.08}),
    ("c14bp6_duck_idle.png", "wildlife/duck", "idle", 4, 46, {"_nogreen": 0.2}),
    ("c14bp6_frog_idle.png", "wildlife/frog", "idle", 4, 26, {}),
    ("c14bp6_fox_idle.png", "wildlife/fox", "idle", 4, 32, {}),
]


def key(im):
    rgba = np.asarray(im.convert("RGBA"))
    if (rgba[..., 3] < 10).mean() > 0.5:
        return rgba.copy()  # a real-alpha render: use it as is
    a = np.asarray(im.convert("RGB")).astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mag = (r > 150) & (b > 150) & (g < 110) & (np.abs(r - b) < 90)
    soft = (r > 120) & (b > 120) & (g < 140) & ~mag
    alpha = np.where(mag, 0, 255).astype(np.uint8)
    alpha[soft] = 110
    rgb = a.astype(np.uint8)
    # de-fringe: pull magenta out of soft edge pixels
    rgb[soft, 0] = np.minimum(rgb[soft, 0], rgb[soft, 1] + 40)
    rgb[soft, 2] = np.minimum(rgb[soft, 2], rgb[soft, 1] + 40)
    return np.dstack([rgb, alpha])


def strip_ground(crop, trim=0.0, nogreen=0.0):
    h = crop.shape[0]
    if nogreen > 0:
        y0 = int(h * (1 - nogreen))
        c = crop[y0:].astype(np.int16)
        green = (c[..., 1] > c[..., 0] + 25) & (c[..., 1] > c[..., 2] + 25)
        crop[y0:, :, 3] = np.where(green, 0, crop[y0:, :, 3])
    if trim > 0:
        crop[h - max(1, int(h * trim)):, :, 3] = 0
    return crop


def frames_of(rgba, n, trim=0.0, nogreen=0.0):
    solid = rgba[..., 3] > 200
    lab, cnt = ndimage.label(ndimage.binary_dilation(solid, iterations=6))
    boxes = ndimage.find_objects(lab)
    big = []
    for i, sl in enumerate(boxes):
        area = int((lab[sl] == i + 1).sum())
        big.append((area, sl))
    big.sort(key=lambda t: -t[0])
    picked = sorted([sl for _a, sl in big[:n]], key=lambda sl: sl[1].start)
    if len(picked) != n:
        raise SystemExit("expected %d frames, found %d" % (n, len(picked)))
    out = []
    for sl in picked:
        ys, xs = sl
        crop = rgba[ys.start:ys.stop, xs.start:xs.stop].copy()
        m = ndimage.binary_dilation(solid[ys, xs], iterations=1)
        crop[..., 3] = np.where(m, crop[..., 3], 0)
        out.append(clean(strip_ground(clean(crop), trim, nogreen)))
    return out


def clean(crop):
    """Drop the painted ground strip beside the feet and stray motion marks."""
    al = crop[..., 3] > 128
    rows = np.where(al.any(1))[0]
    if len(rows) == 0:
        return crop
    top, bot = rows[0], rows[-1]
    band = max(2, int((bot - top) * 0.10))
    y0 = bot - band
    feet = al[max(top, y0 - 4):y0].any(0)
    feet = ndimage.binary_dilation(feet, iterations=3)
    crop[y0:bot + 1, :, 3] = np.where(feet[None, :], crop[y0:bot + 1, :, 3], 0)
    al = crop[..., 3] > 128
    lab, n = ndimage.label(al, structure=np.ones((3, 3)))
    if n > 1:
        sizes = ndimage.sum(al, lab, range(1, n + 1))
        keep = np.isin(lab, [i + 1 for i, v in enumerate(sizes) if v >= sizes.max() * 0.06])
        crop[..., 3] = np.where(keep | (crop[..., 3] < 129) & ndimage.binary_dilation(keep, iterations=1), crop[..., 3], 0)
    al = crop[..., 3] > 0
    ys, xs = np.where(al)
    return crop[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def resize(arr, w, h):
    a = arr.astype(np.float32) / 255.0
    pm = a.copy()
    pm[..., :3] *= pm[..., 3:4]
    im = Image.fromarray((pm * 255).astype(np.uint8), "RGBA").resize((w, h), Image.LANCZOS)
    r = np.asarray(im).astype(np.float32) / 255.0
    al = r[..., 3:4]
    rgb = np.where(al > 0.01, r[..., :3] / np.maximum(al, 1e-3), 0)
    alpha = np.where(al[..., 0] < 0.25, 0, np.clip((al[..., 0] - 0.25) / 0.5, 0, 1))
    return (np.dstack([np.clip(rgb, 0, 1), alpha]) * 255).astype(np.uint8)


def build(sheet, group, anim, n, cell_h, extra, man):
    extra = dict(extra)
    rgba = key(Image.open(os.path.join(INC, sheet)))
    fr = frames_of(rgba, n, float(extra.pop("_trim", 0.0)), float(extra.pop("_nogreen", 0.0)))
    tall = max(f.shape[0] for f in fr)
    k = cell_h / float(tall)
    scaled = [resize(f, max(1, round(f.shape[1] * k)), max(1, round(f.shape[0] * k))) for f in fr]
    cw = max(s.shape[1] for s in scaled) + 2
    strip = np.zeros((cell_h, cw * n, 4), np.uint8)
    for i, s in enumerate(scaled):
        x = i * cw + (cw - s.shape[1]) // 2
        y = cell_h - s.shape[0]
        strip[y:y + s.shape[0], x:x + s.shape[1]] = s
    rel = "%s/%s.png" % (group, anim)
    path = os.path.join(GEN, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path):
        os.remove(path)
    Image.fromarray(strip, "RGBA").save(path)
    ent = {"cell_h": cell_h, "cell_w": cw, "file": rel, "frames": n, "h": cell_h, "w": cw * n}
    ent.update(extra)
    man.setdefault(group, {})[anim] = ent
    print("wrote", rel, ent["w"], "x", cell_h)


def main():
    only = set(sys.argv[1:])
    mp = os.path.join(GEN, "manifest.json")
    man = json.load(open(mp))
    for job in JOBS:
        if only and job[0] not in only and job[1] not in only:
            continue
        if not os.path.exists(os.path.join(INC, job[0])):
            print("skip (missing)", job[0])
            continue
        build(*job, man=man)
    tmp = mp + ".tmp"
    with open(tmp, "w") as f:
        json.dump(man, f, indent=1)
        f.write("\n")
    os.replace(tmp, mp)


if __name__ == "__main__":
    main()

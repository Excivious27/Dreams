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
]


def key(im):
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


def frames_of(rgba, n):
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
        out.append(crop)
    return out


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
    rgba = key(Image.open(os.path.join(INC, sheet)))
    fr = frames_of(rgba, n)
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

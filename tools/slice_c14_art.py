#!/usr/bin/env python3
"""CONDUCT 14 P6 art slicer: redraws of broken existing art ids (rm first, then write).

Sources (dreams-image renders, art/incoming/c14p6/):
  flame_core.png  -> items/flame_core (c14_17-01: the old icon was a broken fragment)
  dunes.png, dunes-2.png (5 isolated props each, one row) -> nature/dune_0..9
                      (c14_17-04 / c14_15-01: the old set were square sand crops)

Colour key: the C11b violet-safe key (cut magenta only in regions touching near-pure
#FF00FF); renders that already carry alpha keep it. Pieces are found as alpha blobs
(sparks within a few px merge into their piece), cropped, and scaled down to the
target box with a hard alpha edge. Usage: python3 tools/slice_c14_art.py [--check]
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INC = os.path.join(ROOT, "art", "incoming", "c14p6")
GEN = os.path.join(ROOT, "art", "gen")
MAN = os.path.join(GEN, "manifest.json")

# sheet -> (group, [ids left to right], (max_w, max_h))
JOBS = [
    ("flame_core.png", "items", ["flame_core"], (32, 32)),
    ("dunes.png", "nature", ["dune_0", "dune_1", "dune_2", "dune_3", "dune_4"], (40, 30)),
    ("dunes-2.png", "nature", ["dune_5", "dune_6", "dune_7", "dune_8", "dune_9"], (40, 30)),
]


def load(path):
    a = np.array(Image.open(path).convert("RGBA"))
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    loose = (r > 150) & (g < 110) & (b > 150) & (r - g > 80) & (b - g > 80)
    strict = (r > 215) & (b > 215) & (g < 60)
    lab, _ = ndimage.label(loose)
    hit = np.unique(lab[strict & loose])
    a[np.isin(lab, hit[hit > 0]), 3] = 0
    return a


def pieces(a, n):
    """The n biggest alpha blobs (specks within 24 px join), left to right."""
    solid = a[..., 3] > 40
    lab, k = ndimage.label(ndimage.binary_dilation(solid, iterations=24))
    sizes = ndimage.sum(solid, lab, range(1, k + 1))
    keep = list(np.argsort(sizes)[::-1][:n] + 1)
    boxes = []
    for i in keep:
        ys, xs = np.where((lab == i) & solid)
        boxes.append((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1, i))
    boxes.sort(key=lambda b: b[0])
    out = []
    for x0, y0, x1, y1, i in boxes:
        crop = a[y0:y1, x0:x1].copy()
        crop[~(lab[y0:y1, x0:x1] == i), 3] = 0
        out.append(crop)
    return out


def shrink(crop, box):
    h, w = crop.shape[:2]
    s = min(box[0] / w, box[1] / h)
    tw, th = max(1, round(w * s)), max(1, round(h * s))
    im = Image.fromarray(crop)
    # premultiplied box filter so the key colour never bleeds into the edge
    arr = np.array(im).astype(float)
    arr[..., :3] *= arr[..., 3:4] / 255.0
    pm = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA").resize((tw, th), Image.BOX)
    p = np.array(pm).astype(float)
    al = p[..., 3:4]
    rgb = np.where(al > 0, p[..., :3] * 255.0 / np.maximum(al, 1), 0)
    out = np.dstack([rgb, np.where(al[..., 0] >= 110, 255, 0)]).clip(0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def main():
    check = "--check" in sys.argv
    man = json.load(open(MAN))
    made = []
    for sheet, group, ids, box in JOBS:
        src = os.path.join(INC, sheet)
        if not os.path.exists(src):
            print("missing", src)
            continue
        ps = pieces(load(src), len(ids))
        assert len(ps) == len(ids), (sheet, len(ps))
        for name, crop in zip(ids, ps):
            im = shrink(crop, box)
            rel = f"{group}/{name}.png"
            if not check:
                dst = os.path.join(GEN, rel)
                if os.path.exists(dst):
                    os.remove(dst)  # art is hardlinked across worktrees: never write in place
                im.save(dst)
                man.setdefault(group, {})[name] = {"file": rel, "w": im.width, "h": im.height}
            made.append(f"{group}/{name} {im.width}x{im.height}")
    if not check:
        with open(MAN, "w") as f:
            json.dump(man, f, indent=1, sort_keys=True)
    print("\n".join(made))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Slice the achievement badge sheets (S1 P2).

Input:  art/incoming/s1p2/ach_sheet_1..5.png (dreams-image, 4x3 badges each, magenta key),
        badges in data/achievements.json "list" order, 12 per sheet.
Output: art/gen/ach/<icon>.png         64x64 in-game icon (title list)
        art/gen/ach/<icon>_locked.png  64x64 greyed twin
        docs/steam/achievements/<API>_ACHIEVED.png / <API>_UNACHIEVED.png  256x256 Steam
        masters (docs/ has .gdignore, so they never ship in a build; bulk-upload names).
Files are removed before writing (art is hardlinked across worktrees).

    python3 tools/slice_achievements.py
"""
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art", "incoming", "s1p2")
OUT = os.path.join(ROOT, "art", "gen", "ach")
STEAM = os.path.join(ROOT, "docs", "steam", "achievements")


def key_mask(a):
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    return (r > 170) & (b > 170) & (g < 110) & (abs(r - b) < 90)


def badges(path):
    im = Image.open(path).convert("RGB")
    a = np.asarray(im)
    bg = key_mask(a)
    h, w = bg.shape
    fg = ~bg
    cols = fg.sum(axis=0) > h * 0.04
    rows = fg.sum(axis=1) > w * 0.04

    def runs(v):
        out, start = [], None
        for i, x in enumerate(list(v) + [False]):
            if x and start is None:
                start = i
            elif not x and start is not None:
                if i - start > 40:
                    out.append((start, i))
                start = None
        return out
    cr, rr = runs(cols), runs(rows)
    if len(cr) != 4 or len(rr) != 3:
        raise SystemExit("%s: found %d cols x %d rows, want 4x3" % (path, len(cr), len(rr)))
    rgba = np.dstack([a, np.where(bg, 0, 255).astype(np.uint8)])
    out = []
    for (y0, y1) in rr:
        for (x0, x1) in cr:
            cell = rgba[y0:y1, x0:x1]
            ys, xs = np.nonzero(cell[..., 3])
            cell = cell[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
            s = max(cell.shape[0], cell.shape[1])
            sq = np.zeros((s, s, 4), np.uint8)
            oy, ox = (s - cell.shape[0]) // 2, (s - cell.shape[1]) // 2
            sq[oy:oy + cell.shape[0], ox:ox + cell.shape[1]] = cell
            out.append(Image.fromarray(sq, "RGBA"))
    return out


def grey(im):
    g = im.convert("LA").convert("RGBA")
    a = np.asarray(g).astype(float)
    a[..., :3] = a[..., :3] * 0.55 + 40
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


def save(im, path):
    if os.path.exists(path):
        os.remove(path)
    im.save(path)


def main():
    lst = json.load(open(os.path.join(ROOT, "data", "achievements.json"), encoding="utf-8"))["list"]
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(STEAM, exist_ok=True)
    icons = []
    n = 1
    while os.path.exists(os.path.join(SRC, "ach_sheet_%d.png" % n)):
        icons += badges(os.path.join(SRC, "ach_sheet_%d.png" % n))
        n += 1
    if len(icons) < len(lst):
        raise SystemExit("only %d badges for %d achievements" % (len(icons), len(lst)))
    for a, im in zip(lst, icons):
        big = im.resize((256, 256), Image.LANCZOS)
        save(big.convert("RGB") if False else big, os.path.join(STEAM, a["api"] + "_ACHIEVED.png"))
        save(grey(big), os.path.join(STEAM, a["api"] + "_UNACHIEVED.png"))
        small = im.resize((64, 64), Image.LANCZOS)
        save(small, os.path.join(OUT, a["icon"] + ".png"))
        save(grey(small), os.path.join(OUT, a["icon"] + "_locked.png"))
    print("slice_achievements: %d icons (+ locked twins, 256 px Steam masters)" % len(lst))


if __name__ == "__main__":
    main()

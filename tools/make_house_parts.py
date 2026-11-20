#!/usr/bin/env python3
"""Farmhouse part masks for exterior styles (C10b P3).

Writes art/gen/house_parts/<house>_parts.png for house, house_2, house_3: the same
size as the day picture, R channel = part id * 32 (nearest-sampled by
shaders/house_palette.gdshader in UV space, so it also fits the slightly scaled
_night/_snow pictures):
  1 roof tiles   2 siding / wood (walls, trim, posts, steps)   3 window glass
  4 stonework (base, chimneys)   0 anything else (flowers, bushes, lamps, outline)
Roof = the saturated red tile core, closed morphologically and hole-filled so tile
highlights and inner outlines inside the roof get the ramp too (c10b_01-15).
A coloured preview goes to /tmp/house_parts_preview.png. `--check` only verifies
that every mask exists and matches its picture's size (check.sh friendly).
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art/gen/buildings")
OUT = os.path.join(ROOT, "art/gen/house_parts")
HOUSES = ["house", "house_2", "house_3"]
STEP = 32
PREVIEW = {1: (40, 90, 230), 2: (240, 200, 40), 3: (40, 230, 230), 4: (200, 60, 200)}


# Door boxes (day-picture px, x0, y0, x1, y1): the painted door is never roof (its
# dark red planks pass the tile test) and door overlays cover exactly this box.
DOORS = {"house": (80, 119, 111, 157), "house_2": (85, 97, 116, 140), "house_3": (179, 118, 213, 166)}


def parts(img, door=None):
    a = np.asarray(img.convert("RGBA")).astype(np.float32)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    op = al > 40
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    sat = (mx - mn) / np.maximum(mx, 1)
    lum = 0.3 * r + 0.59 * g + 0.11 * b
    warm = op & (r >= g) & (g >= b * 0.8) & (sat > 0.25)
    gr = g / np.maximum(r, 1)
    core = warm & (r > 110) & (gr < 0.42)
    core = ndimage.binary_opening(core, iterations=1)
    lab, n = ndimage.label(core)
    if n:
        sizes = ndimage.sum(core, lab, range(1, n + 1))
        core = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= 40])
    if door:
        core[door[1]:door[3], door[0]:door[2]] = False
    roof = ndimage.binary_closing(core, iterations=3)
    holes = ndimage.binary_fill_holes(roof) & ~roof
    hl, hn = ndimage.label(holes)
    for i, sl in enumerate(ndimage.find_objects(hl)):
        if sl is not None and (hl[sl] == i + 1).sum() <= 120:  # tile seams, not the dormer gable
            roof[sl] |= hl[sl] == i + 1
    roof &= op
    # tile-edge highlights / ridge caps: grow 2 px into light-orange warm pixels
    edge = warm & (gr < 0.6) & (b < r * 0.3)
    for _ in range(2):
        roof |= ndimage.binary_dilation(roof) & edge
    # keep roof to warm pixels and dark outline/shade inside it (not windows/chimney stone)
    roof &= (warm | (lum < 70)) & ~((b > r + 15) & (b > 80))
    if door:
        roof[door[1]:door[3], door[0]:door[2]] = False
    out = np.zeros(a.shape[:2], np.uint8)
    out[roof] = 1
    glass = op & (b > r + 20) & (b > 90) & ~roof
    br0 = b / np.maximum(r, 1)
    wood = warm & ~roof & (gr >= 0.38) & (gr < 0.9) & ~((br0 > 0.5) & (gr > 0.6))
    out[wood] = 2
    out[glass] = 3
    br = b / np.maximum(r, 1)
    stone = op & (br > 0.5) & (gr > 0.6) & (r >= g) & (sat < 0.45) & (lum > 60) & ~glass & ~roof
    out[stone] = 4
    return out


def main():
    check = "--check" in sys.argv
    bad = 0
    os.makedirs(OUT, exist_ok=True)
    tiles = []
    meta = {"doors": DOORS, "lum": {}}
    for h in HOUSES:
        src = Image.open(os.path.join(SRC, h + ".png"))
        dst = os.path.join(OUT, h + "_parts.png")
        if check:
            if not os.path.exists(dst) or Image.open(dst).size != src.size:
                print("house parts: %s missing or wrong size" % dst)
                bad += 1
            continue
        p = parts(src, DOORS.get(h))
        im = np.zeros(p.shape + (4,), np.uint8)
        im[..., 0] = p * STEP
        im[..., 3] = 255
        if os.path.exists(dst):
            os.remove(dst)  # hardlinked art: never write in place
        Image.fromarray(im, "RGBA").save(dst)
        pv = np.asarray(src.convert("RGBA")).copy()
        for k, c in PREVIEW.items():
            pv[p == k, :3] = (pv[p == k, :3] * 0.35 + np.array(c) * 0.65).astype(np.uint8)
        tiles.append(Image.fromarray(pv, "RGBA"))
        arr = np.asarray(src.convert("RGB")).astype(np.float32) / 255.0
        lum = arr[..., 0] * 0.3 + arr[..., 1] * 0.59 + arr[..., 2] * 0.11
        meta["lum"][h] = {str(k): [round(float(np.percentile(lum[p == k], 3)), 3), round(float(np.percentile(lum[p == k], 97)), 3)] for k in PREVIEW if (p == k).any()}
        counts = {k: int((p == k).sum()) for k in PREVIEW}
        print(h, src.size, counts)
    if check:
        if not os.path.exists(os.path.join(OUT, "parts.json")):
            print("house parts: parts.json missing")
            bad += 1
        sys.exit(1 if bad else 0)
    import json
    mp = os.path.join(OUT, "parts.json")
    if os.path.exists(mp):
        os.remove(mp)
    with open(mp, "w") as f:
        json.dump(meta, f, indent=1)
    w = sum(t.size[0] for t in tiles) + 10 * len(tiles)
    sheet = Image.new("RGBA", (w, max(t.size[1] for t in tiles)), (30, 60, 30, 255))
    x = 0
    for t in tiles:
        sheet.alpha_composite(t, (x, 0))
        x += t.size[0] + 10
    sheet.resize((sheet.size[0] * 2, sheet.size[1] * 2), Image.NEAREST).save("/tmp/house_parts_preview.png")


if __name__ == "__main__":
    main()

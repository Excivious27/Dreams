#!/usr/bin/env python3
"""C16a P4 slicer: bug net + Critter log icons from art/incoming/c16ap4/c16ap4_critters_sheet.png
(5 x 4 grid, alpha or flat magenta). Each cell: keyed, cropped to its largest blob (glow sparkles kept
when they touch it after dilation), fitted into 32 px keeping aspect, written as art/gen/items/c16ap4_<name>.png
(rm first, never edited in place) + manifest items entries. Names in reading order: NAMES."""
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEET = os.path.join(ROOT, "art", "incoming", "c16ap4", "c16ap4_critters_sheet.png")
GEN = os.path.join(ROOT, "art", "gen")
COLS, ROWS = 5, 4
NAMES = ["ladybug", "lemon_wing", "orange_flutter", "sky_wing", "bumble_bee",
         "meadow_hopper", "garden_snail", "violet_duchess", "pond_dragonfly", "green_frog",
         "shore_crab", "firefly", "sky_jelly", "petal_emperor", "sunwing",
         "ember_moth", "snow_sylph", "bug_net", "silk_net", "star_net"]


def key(im):
    rgba = np.asarray(im.convert("RGBA")).copy()
    if (rgba[..., 3] < 10).mean() > 0.3:
        return rgba
    a = rgba[..., :3].astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mag = (r > 150) & (b > 150) & (g < 110) & (np.abs(r - b) < 90)
    rgba[mag, 3] = 0
    return rgba


def crop_main(rgba):
    solid = rgba[..., 3] > 60
    lab, n = ndimage.label(ndimage.binary_dilation(solid, iterations=6))
    if n == 0:
        raise SystemExit("empty cell")
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    mask = lab == int(np.argmax(sizes)) + 1
    out = rgba.copy()
    out[~mask, 3] = 0
    ys, xs = np.where(out[..., 3] > 20)
    return out[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def main():
    sheet = key(Image.open(SHEET))
    H, W = sheet.shape[:2]
    man_p = os.path.join(GEN, "manifest.json")
    man = json.load(open(man_p))
    for i, name in enumerate(NAMES):
        cx, cy = i % COLS, i // COLS
        cell = sheet[cy * H // ROWS:(cy + 1) * H // ROWS, cx * W // COLS:(cx + 1) * W // COLS]
        crop = crop_main(cell)
        h, w = crop.shape[:2]
        s = 32.0 / max(w, h)
        nw, nh = max(1, round(w * s)), max(1, round(h * s))
        im = Image.fromarray(crop).resize((nw, nh), Image.LANCZOS)
        out = os.path.join(GEN, "items", "c16ap4_%s.png" % name)
        if os.path.exists(out):
            os.remove(out)
        im.save(out)
        man["items"]["c16ap4_" + name] = {"file": "items/c16ap4_%s.png" % name, "h": nh, "w": nw}
    with open(man_p + ".tmp", "w") as fh:
        json.dump(man, fh, indent=1)
        fh.write("\n")
    os.replace(man_p + ".tmp", man_p)
    print("slice_c16a_p4: %d icons" % len(NAMES))


if __name__ == "__main__":
    main()

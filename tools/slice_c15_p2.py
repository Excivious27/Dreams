#!/usr/bin/env python3
"""C15 P2 seasonal forage icons (art/incoming/c15p2/forage_*.png, one row of 3 on magenta)
-> art/gen/items/c15p2_<item>.png (32 px tall, like the other item icons). Items point at them
through items.json "icon" (tools/gen_seasons.py). Also gives moon_melon_seed an item icon
(copy of crops/moon_melon_seed). rm-then-write (art files are hardlinked).
    python3 tools/slice_c15_p2.py [check]
"""
import json, os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INC = os.path.join(ROOT, "art", "incoming", "c15p2")
MAN = os.path.join(ROOT, "art", "gen", "manifest.json")
SHEETS = {
    "forage_spring.png": ["fiddlehead", "salmonberry", "crocus"],
    "forage_summer_a.png": ["sand_dollar", "sea_glass", "summer_kelp"],
    "forage_summer_b.png": ["cattail", "water_lily", "honeysuckle"],
    "forage_fall_a.png": ["chanterelle", "hazelnut", "rosehip"],
    "forage_fall_b.png": ["wild_plum", "chestnut", "leaf_bundle"],
    "forage_winter.png": ["holly_sprig", "snow_yam", "crystal_icicle"],
    "winter_crops.png": ["snow_radish", "winter_leek", "winter_honeycomb"],
}
EXTRA = {"c15p2_moon_melon_seed": ("crops", "moon_melon_seed")}
IDS = ["c15p2_" + n for names in SHEETS.values() for n in names] + list(EXTRA)


def _rm(nid):
    p = os.path.join(ROOT, "art", "gen", "items", nid + ".png")
    if os.path.exists(p):
        os.remove(p)


def bbox(rgba):
    ys, xs = np.nonzero(rgba[..., 3] > 40)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def slice_sheet(src, names):
    rgba = S.key_magenta(Image.open(os.path.join(INC, src)))
    h, w = rgba.shape[:2]
    for i, n in enumerate(names):
        cell = rgba[:, i * w // 3:(i + 1) * w // 3].copy()
        x0, y0, x1, y1 = bbox(cell)
        piece = Image.fromarray(cell[y0:y1, x0:x1].astype(np.uint8))
        img = S.scale_to(piece, 32, 32)
        a = np.asarray(img).copy()
        a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
        nid = "c15p2_" + n
        _rm(nid)
        S.save(Image.fromarray(a), "items", nid)


def main():
    man = json.load(open(MAN))
    if sys.argv[1:] == ["check"]:
        miss = [i for i in IDS if i not in man.get("items", {}) or not os.path.exists(os.path.join(ROOT, "art", "gen", "items", i + ".png"))]
        if miss:
            print("slice_c15_p2: missing", miss)
        sys.exit(1 if miss else 0)
    for src, names in SHEETS.items():
        slice_sheet(src, names)
    for nid, (grp, name) in EXTRA.items():
        img = Image.open(os.path.join(ROOT, "art", "gen", grp, name + ".png")).convert("RGBA")
        _rm(nid)
        S.save(S.scale_to(img, 32, 32), "items", nid)
    for i in IDS:
        man.setdefault("items", {})[i] = S.manifest["items"][i]
    os.remove(MAN)
    with open(MAN, "w") as fh:
        json.dump(man, fh, indent=1, sort_keys=True)
    print("slice_c15_p2: %d icons" % len(IDS))


if __name__ == "__main__":
    main()

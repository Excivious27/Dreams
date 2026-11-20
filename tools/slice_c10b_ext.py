#!/usr/bin/env python3
"""Farmhouse exterior overlay art (C10b P3): renders in art/incoming/c10b/ext_*.png
-> art/gen/house_parts/<kind>_<style>.png (no manifest; HouseExterior loads them
by path). Run after the other slicers, then tools/make_house_parts.py.

SHEETS is the one render list: file, the piece names in reading order (rows top to
bottom, left to right), and the height each piece is stored at (doors are fitted to
each tier's door box in game; porch dressings are drawn at that height / 2).
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from slice_comp import blobs, rows_of  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INC = os.path.join(ROOT, "art/incoming/c10b")
OUT = os.path.join(ROOT, "art/gen/house_parts")

SHEETS = [
    {"file": "ext_doors.png", "kind": "door", "h": 72,
     "names": ["oak", "dutch_blue", "round_green", "glass_white", "barn_red", "studded", "ice", "steel"],
     "prompt": "8 arched front doors in their own frames, 2 rows of 4, straight-on, matching buildings/house.png (edit_image source)"},
    {"file": "ext_porch.png", "kind": "porch", "h": 48,
     "names": ["fern", "bench", "mat", "lamp_post", "sunflowers", "penguin_lamp", "crates", "birdbath"],
     "prompt": "8 small porch decorations, 2 rows of 4, top-down 3/4, matching buildings/house.png (edit_image source)"},
    {"file": "ext_mailboxes.png", "kind": "mailbox", "h": 40,
     "names": ["white", "green", "birdhouse", "copper", "barn", "iron", "ice", "steel"],
     "prompt": "8 mailboxes on posts, flag down, no mail, 2 rows of 4, matching buildings/mailbox.png + house.png (edit_image sources)"},
]


def key(rgba):
    a = rgba.copy()
    m = (a[..., 0] > 200) & (a[..., 1] < 70) & (a[..., 2] > 200)
    a[m, 3] = 0
    return a


# Seamless straight-on wall textures for the siding "material" styles (c10b_01-22):
# the shader tiles them over the walls, shaded by the painted planks' light.
WALLS = {"file": "ext_walls.png", "names": ["brick", "fieldstone", "logs"], "px": 64,
         "prompt": "3 square seamless wall swatches: red brick, grey fieldstone, horizontal log cabin (generate_image)"}


def tileable(im):
    """Cross-fade a half-offset copy across the seams so the swatch wraps."""
    a = np.asarray(im).astype(np.float32)
    h, w = a.shape[:2]
    sh = np.roll(np.roll(a, h // 2, 0), w // 2, 1)
    yy = np.abs(np.arange(h) - h / 2) / (h / 2)
    xx = np.abs(np.arange(w) - w / 2) / (w / 2)
    m = np.clip((np.maximum(yy[:, None], xx[None, :]) - 0.7) / 0.3, 0, 1)[..., None]
    return Image.fromarray((a * (1 - m) + sh * m).astype(np.uint8), im.mode)


def walls():
    src = os.path.join(INC, WALLS["file"])
    rgba = key(np.asarray(Image.open(src).convert("RGBA")))
    boxes = sorted(blobs(rgba, merge=2, min_area=5000), key=lambda b: b[0])
    if len(boxes) != len(WALLS["names"]):
        print("walls: found", len(boxes))
        sys.exit(1)
    for name, b in zip(WALLS["names"], boxes):
        x0, y0, x1, y1 = b
        side = min(x1 - x0, y1 - y0) - 12
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
        im = Image.fromarray(rgba[cy - side // 2:cy + side // 2, cx - side // 2:cx + side // 2], "RGBA").convert("RGB")
        im = tileable(im.resize((WALLS["px"] * 2, WALLS["px"] * 2), Image.LANCZOS))
        im = tileable(im).resize((WALLS["px"], WALLS["px"]), Image.LANCZOS)
        dst = os.path.join(OUT, "wall_%s.png" % name)
        if os.path.exists(dst):
            os.remove(dst)
        im.save(dst)


def main():
    os.makedirs(OUT, exist_ok=True)
    made = 0
    for sh in SHEETS:
        src = os.path.join(INC, sh["file"])
        if not os.path.exists(src):
            print("missing render", src)
            sys.exit(1)
        rgba = key(np.asarray(Image.open(src).convert("RGBA")))
        boxes = [b for b in blobs(rgba, merge=6, min_area=800)]
        order = [b for row in rows_of(boxes) for b in sorted(row, key=lambda b: b[0])]
        if len(order) != len(sh["names"]):
            print(sh["file"], "found", len(order), "pieces, want", len(sh["names"]))
            sys.exit(1)
        for name, b in zip(sh["names"], order):
            im = Image.fromarray(rgba[b[1]:b[3], b[0]:b[2]], "RGBA")
            h = sh["h"]
            w = max(1, round(im.size[0] * h / im.size[1]))
            im = im.resize((w, h), Image.LANCZOS)
            arr = np.asarray(im).copy()
            arr[..., 3] = np.where(arr[..., 3] > 110, 255, 0)  # hard alpha (crisp edge)
            dst = os.path.join(OUT, "%s_%s.png" % (sh["kind"], name))
            if os.path.exists(dst):
                os.remove(dst)  # hardlinked art: never write in place
            Image.fromarray(arr, "RGBA").save(dst)
            made += 1
    walls()
    print("house parts overlays:", made, "+ walls", len(WALLS["names"]))


if __name__ == "__main__":
    main()

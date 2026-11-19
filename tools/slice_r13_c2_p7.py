#!/usr/bin/env python3
"""CONDUCT 2 fix P7 (art quality).

Steps (run after the other slicers):  python3 tools/slice_r13_c2_p7.py [step ...]
  card_big_grump  art/incoming/c2_p7/card_big_grump.png (image-tool edit of the old
                  card): the Big Grump storm cloud in the gold boss frame. The old card
                  showed a bald man in a fur coat that matched nothing in the game.
  mine_rocks      crispens every mine stone/ore prop (tools/crispen.py): hard alpha,
                  magenta fringe removed, small palette, 1px dark outline, light unsharp.
  buildings       crispens the worst-scoring buildings from tools/fuzz_audit.py
                  (CRISP_BUILDINGS below; footprint and canvas size unchanged).
Every output file is removed before it is written (art/gen files are hardlinked).
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
from slice_comp import blobs
import numpy as np
from PIL import Image
import crispen as C


def _replace(img, group, name):
    out = os.path.join(S.OUT, group, name + ".png")
    if os.path.exists(out):
        os.remove(out)
    S.save(img, group, name)


def card_big_grump():
    p = os.path.join(S.INC, "c2_p7/card_big_grump.png")
    if not os.path.exists(p):
        return
    rgba = np.asarray(S.load("c2_p7/card_big_grump.png"))
    b = max(blobs(rgba, merge=3, min_area=5000), key=lambda b: (b[2] - b[0]) * (b[3] - b[1]))
    im = Image.fromarray(rgba[b[1]:b[3], b[0]:b[2]])
    # Same size as the other boss cards (764x322, a banner): boss_card draws it
    # keep-aspect in 250x84 with the title on the right half (a taller card would be
    # read as a portrait card). The render's frame is a little taller: squash ~15%.
    im = im.resize((764, 322), Image.LANCZOS)
    a = np.asarray(im).copy()
    a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
    _replace(Image.fromarray(a), "ui", "card_big_grump")


MINE_PREFIXES = ("mine_deep_rock_", "mine_dark_rock_", "mine_heart_rock_", "mine_crystal_rock_",
                 "mine_deep_bigrock_", "mine_dark_bigrock_", "mine_heart_bigrock_", "mine_crystal_bigrock_",
                 "mine_deep_ore_", "mine_dark_ore_", "mine_heart_ore_", "mine_crystal_ore_", "node_")


def mine_rocks():
    for name in sorted(S.manifest.get("props", {})):
        if not name.startswith(MINE_PREFIXES):
            continue
        p = os.path.join(S.OUT, "props", name + ".png")
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGBA")
        if C.is_crisp(im):
            continue  # already done (idempotent)
        _replace(C.crispen(im), "props", name)


# Worst buildings by tools/fuzz_audit.py (docs/FUZZY-ART.md), crispened in place.
CRISP_BUILDINGS = []


def buildings():
    for name in CRISP_BUILDINGS:
        p = os.path.join(S.OUT, "buildings", name + ".png")
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGBA")
        if C.is_crisp(im):
            continue
        _replace(C.crispen(im, colors=48, outline=False), "buildings", name)


STEPS = [card_big_grump, mine_rocks, buildings]

if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    only = sys.argv[1:]
    for fn in STEPS:
        if only and fn.__name__ not in only:
            continue
        fn(); print("ok", fn.__name__)
    tmp = mpath + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(S.manifest, fh, indent=1, sort_keys=True)
    os.replace(tmp, mpath)

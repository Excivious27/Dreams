#!/usr/bin/env python3
"""C15 P6 festival props (art/incoming/c15p6/*.png, real-alpha renders or magenta key):
  c15p6_hunt_parade    -> props/c15p6_golden_egg, c15p6_envelope_0..2 (gang stash hunt), c15p6_parade_float
  c15p6_pumpkins_feast -> props/c15p6_pumpkin_lantern_0..2 (Hollow Night), c15p6_feast_table (Gift Swap)
  c15p6_gang_fest      -> props/c15p6_food_truck, c15p6_neon_string, c15p6_crate_stack (gang festival dressing)
Pieces are taken left to right; each scaled to its target height in art px (2x detail).
rm-then-write (art files are hardlinked).   python3 tools/slice_c15_p6.py [check]
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
import slice_comp as C
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAN = os.path.join(ROOT, "art", "gen", "manifest.json")
INC = os.path.join(ROOT, "art", "incoming", "c15p6")
SHEETS = [
    ("c15p6_hunt_parade.png", [("c15p6_golden_egg", 56), ("c15p6_envelope_0", 48), ("c15p6_envelope_1", 48), ("c15p6_envelope_2", 48), ("c15p6_parade_float", 190)]),
    ("c15p6_pumpkins_feast.png", [("c15p6_pumpkin_lantern_0", 78), ("c15p6_pumpkin_lantern_1", 78), ("c15p6_pumpkin_lantern_2", 82), ("c15p6_feast_table", 230)]),
    ("c15p6_gang_fest.png", [("c15p6_food_truck", 230), ("c15p6_neon_string", 170), ("c15p6_crate_stack", 150)]),
]
IDS = [i for _, ps in SHEETS for i, _ in ps]


def load(name):
    im = Image.open(os.path.join(INC, name)).convert("RGBA")
    a = np.asarray(im)
    if (a[..., 3] < 10).mean() > 0.3:
        return a.copy()  # real alpha render
    return np.asarray(S.key_magenta(im))


def main():
    man = json.load(open(MAN))
    if sys.argv[1:] == ["check"]:
        miss = [i for i in IDS if i not in man.get("props", {}) or not os.path.exists(os.path.join(ROOT, "art", "gen", "props", i + ".png"))]
        print("slice_c15_p6: missing", miss) if miss else None
        sys.exit(1 if miss else 0)
    for src, pieces in SHEETS:
        rgba = load(src)
        _, rows = C.sheet_rows(src, merge=12, min_area=3000, rgba=rgba)
        boxes = sorted([b for row in rows for b in row], key=lambda b: -(b[2] - b[0]) * (b[3] - b[1]))[:len(pieces)]
        boxes.sort(key=lambda b: b[0])
        if len(boxes) != len(pieces):
            sys.exit("slice_c15_p6: %s: %d pieces, want %d" % (src, len(boxes), len(pieces)))
        for (nid, h), b in zip(pieces, boxes):
            p = os.path.join(ROOT, "art", "gen", "props", nid + ".png")
            if os.path.exists(p):
                os.remove(p)
            S.save(C.piece(rgba, b, factor=h / float(b[3] - b[1])), "props", nid)
    for i in IDS:
        man.setdefault("props", {})[i] = S.manifest["props"][i]
    os.remove(MAN)
    with open(MAN, "w") as f:
        json.dump(man, f, indent=1)
    print("slice_c15_p6: %d props" % len(IDS))


if __name__ == "__main__":
    main()

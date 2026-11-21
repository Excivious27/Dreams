#!/usr/bin/env python3
"""C16b P3: the long way story panels (dreams-image renders in art/incoming/c16bp3/),
one per main-story long way, 500x333 like the other Dialogue "pic" panels.
    python3 tools/slice_c16bp3.py
Merges into art/gen/manifest.json (group "ui").
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
from slice_art import save
from PIL import Image

REGS = ["wastes", "sky", "countryside", "docks", "neon", "underground", "uptown"]


def panels():
    for r in REGS:
        name = "c16bp3_long_" + r
        im = Image.open(os.path.join(S.INC, "c16bp3", name + ".png")).convert("RGBA")
        save(im.resize((500, 333), Image.LANCZOS), "ui", name)


if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    panels()
    os.remove(mpath)  # the manifest may be hardlinked to other checkouts: never write it in place
    with open(mpath, "w") as f:
        json.dump(S.manifest, f, indent=1, sort_keys=True)
    print("ok c16bp3 panels")

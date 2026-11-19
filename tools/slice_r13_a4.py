#!/usr/bin/env python3
"""Round 13 (a4) campaign art: training/briefing story panels and battle UI icons
(image-tool renders in art/incoming/r13_a4/). Run after the other slicers:
    python3 tools/slice_r13_a4.py
Merges into art/gen/manifest.json (group "ui").
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
from slice_art import load, save
from slice_comp import blobs, piece
from PIL import Image

INC = "r13_a4/"
PANELS = {"cut_drill_catkins": "cut_drill_catkins.png", "cut_drill_sal": "cut_drill_sal.png", "cut_war_table": "cut_war_table.png"}
MODES = [["mode_skirmish", "mode_siege", "mode_escort"], ["mode_defend", "mode_boss", "mode_gate"]]
RALLY = [["rally_guard", "rally_follow", "rally_send"], ["icon_objective", "icon_whistle", "icon_supply"]]


def panels():
    """Full-bleed story panels, 500x333 (Dialogue "pic" and the briefing cards)."""
    for name, f in PANELS.items():
        im = Image.open(os.path.join(S.INC, INC + f)).convert("RGBA")
        im = im.resize((500, 333), Image.LANCZOS)
        save(im, "ui", name)


def _icons(f, names, h):
    """A 3x2 sheet: each icon is everything in its grid cell (footprints etc. are several blobs)."""
    rgba = load(INC + f)
    H, W = rgba.shape[:2]
    nr, nc = len(names), len(names[0])
    for r in range(nr):
        for c in range(nc):
            cell = (c * W // nc, r * H // nr, (c + 1) * W // nc, (r + 1) * H // nr)
            bs = blobs(rgba, cell, merge=4, min_area=300)
            assert bs, (f, r, c)
            b = (min(x[0] for x in bs), min(x[1] for x in bs), max(x[2] for x in bs), max(x[3] for x in bs))
            save(piece(rgba, b, h=h), "ui", names[r][c])


def icons():
    _icons("battle_mode_icons.png", MODES, 48)
    _icons("battle_rally_icons.png", RALLY, 40)


STEPS = [panels, icons]

if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    for fn in STEPS:
        fn()
        print("ok", fn.__name__)
    os.remove(mpath)  # the manifest may be hardlinked to other checkouts: never write it in place
    with open(mpath, "w") as f:
        json.dump(S.manifest, f, indent=1, sort_keys=True)

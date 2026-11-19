#!/usr/bin/env python3
"""Round 13 (a8) redraws: animal and penguin strips that were bad at the source.

  r13/a8_deer_walk.png            deer: 6-frame walk, 4-frame graze idle
  r13/a8_calf.png                 calf: idle 4, walk 4, eat 2 (its own art, was scraps)
  r13/a8_fox_squirrel_turtle.png  fox / squirrel / turtle: idle + walk with whole tails
  r13/a8_penguin_king_walks.png   Pip-Pip: walk_down 4, walk_up 4, walk (side) 6
  r13/a8_penguin_wizard_walks.png Nova: the same

Every sheet uses one scale for all its frames; frames are bottom-anchored and
centred on the body (animals: the trunk; penguins: the torso), so cycles
neither pulse nor slide. Files are removed before they are written.

    python3 tools/slice_r13_a8.py   (after slice_world5.py and reslice_*.py)"""
import json, os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S  # noqa: E402
from slice_comp import sheet_rows  # noqa: E402
from reslice_hero12 import write, scaled, torso_x, OUT  # noqa: E402
from align_strips import body_x  # noqa: E402


def figs(rgba, row):
    out = []
    for b in row:
        im = Image.fromarray(rgba[b[1]:b[3], b[0]:b[2]].astype(np.uint8))
        out.append(im.crop(im.getbbox()))
    return out


def strip_by(frames, anchor):
    xs = [anchor(f) for f in frames]
    xs = [x if x is not None else f.width / 2.0 for f, x in zip(frames, xs)]
    half = max(max(x, f.width - x) for f, x in zip(frames, xs))
    cw = int(np.ceil(half)) * 2 + 4
    ch = max(f.height for f in frames)
    out = Image.new("RGBA", (cw * len(frames), ch), (0, 0, 0, 0))
    for i, (f, x) in enumerate(zip(frames, xs)):
        out.alpha_composite(f, (i * cw + int(round(cw / 2.0 - x)), ch - f.height))
    return out, cw, ch


def put(m, group, name, frames, anchor):
    img, cw, ch = strip_by(frames, anchor)
    write(m, group, name, img, cw, ch, len(frames))


def rows_for(file, want):
    rgba, rows = sheet_rows(file, merge=4, min_area=400)
    rows = [r for r in rows if len(r) >= 2]
    got = [len(r) for r in rows]
    if got[:len(want)] != want:
        raise SystemExit("%s: rows %s, expected %s" % (file, got, want))
    return rgba, rows


def animals(m):
    # Deer: 6 walk, 4 idle (stand, graze down, graze, up). Strip height ~60 (2x units).
    rgba, rows = rows_for("r13/a8_deer_walk.png", [6, 4])
    walk, idle = figs(rgba, rows[0]), figs(rgba, rows[1])
    s = 60.0 / float(np.median([f.height for f in walk]))
    put(m, "wildlife/deer", "walk", [scaled(f, s) for f in walk], body_x)
    put(m, "wildlife/deer", "idle", [scaled(f, s) for f in idle], body_x)
    # Calf: a calf next to the cows (cow strips are 48 tall): ~34.
    rgba, rows = rows_for("r13/a8_calf.png", [4, 4, 2])
    idle, walk, eat = (figs(rgba, r) for r in rows[:3])
    s = 34.0 / float(np.median([f.height for f in idle]))
    for nm, fr in (("idle", idle), ("walk", walk), ("eat", eat)):
        put(m, "animals/calf", nm, [scaled(f, s) for f in fr], body_x)
    # Fox 1+4, squirrel 1+4, turtle 1+3 (heights as the old strips).
    rgba, rows = rows_for("r13/a8_fox_squirrel_turtle.png", [5, 5, 4])
    for row, name, h in ((rows[0], "fox", 32.0), (rows[1], "squirrel", 34.0), (rows[2], "turtle", 26.0)):
        fr = figs(rgba, row)
        s = h / float(max(f.height for f in fr))
        fr = [scaled(f, s) for f in fr]
        put(m, "wildlife/" + name, "idle", fr[:1], body_x)
        put(m, "wildlife/" + name, "walk", fr[1:], body_x)


def penguins(m):
    for cid, file in (("penguin_king", "r13/a8_penguin_king_walks.png"), ("penguin_wizard", "r13/a8_penguin_wizard_walks.png")):
        rgba, rows = rows_for(file, [4, 4, 6])
        down, up, side = (figs(rgba, r) for r in rows[:3])
        # Same size as their idle_down (96 px tall in the strips).
        s = 96.0 / float(max(f.height for f in down))
        G = "characters/" + cid
        put(m, G, "walk_down", [scaled(f, s) for f in down], torso_x)
        put(m, G, "walk_up", [scaled(f, s) for f in up], torso_x)
        put(m, G, "walk", [scaled(f, s) for f in side], torso_x)
        print("  %s: walk_down 4, walk_up 4, walk 6" % cid)


if __name__ == "__main__":
    mpath = os.path.join(OUT, "manifest.json")
    m = json.load(open(mpath))
    animals(m)
    penguins(m)
    os.remove(mpath)
    with open(mpath, "w") as f:
        json.dump(m, f, indent=1, sort_keys=True)
    print("ok slice_r13_a8")

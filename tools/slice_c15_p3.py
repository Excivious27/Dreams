#!/usr/bin/env python3
"""C15 P3: seasonal villager walker sheets (dreams-image, same 8-row x 16-column
layout as w159/w160: idle down, idle up, idle side, walk side x4, walk down x4,
walk up x4, spare). Writes art/gen/characters/npc_<id>_<season>/ (idle, idle_up,
idle_side, walk, walk_down, walk_up), the same strips Npc.setup already prefers
for the season. New groups only (rm-then-write is moot: no file existed).

  python3 tools/slice_c15_p3.py [sheet-name-part ...]   (default: every sheet)
Writes remove the old file first (art files are hardlinked across worktrees).
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import slice_art as S  # noqa: E402
_save = S.save


def _save_rm(img, group, name):  # rm-then-write: never modify a hardlinked art file in place
    p = os.path.join(S.OUT, group, name + ".png")
    if os.path.exists(p):
        os.remove(p)
    return _save(img, group, name)


S.save = _save_rm
from slice_art import crop, strip  # noqa: E402
from slice_art2 import region_bbox  # noqa: E402
from slice_world import _grid_runs, _equal_cells  # noqa: E402
from PIL import Image  # noqa: E402
import numpy as np  # noqa: E402

# render (under art/incoming/) -> rows top to bottom
SHEETS = {
    "c15p3/c15p3_winter_walkers_a.png": [("gideon", "winter"), ("wren", "winter"), ("alder", "winter"), ("hazel", "winter"), ("theo", "winter"), ("bram", "winter"), ("tobin", "winter")],
    "c15p3/c15p3_walkers_b.png": [("ivy", "winter"), ("benno", "winter"), ("tess", "winter"), ("wren_jr", "winter"), ("maple", "spring"), ("finn", "spring"), ("posy", "spring")],
    "c15p3/c15p3_festival_walkers.png": [("alder", "festival_star"), ("posy", "festival_star"), ("maple", "festival_star"), ("pip", "festival_star"), ("tobin", "festival_star"), ("wren_jr", "festival_star"), ("alder", "festival_lantern"), ("posy", "festival_lantern")],
}


def sheet(file, pairs):
    if not os.path.exists(os.path.join(S.INC, file)):
        print("slice_c15_p3: missing", file)
        return []
    src = Image.open(os.path.join(S.INC, file)).convert("RGBA")
    rgba = np.array(S.key_magenta(src))  # magenta key, and keep the render's own transparency
    rgba[..., 3] = np.minimum(rgba[..., 3], np.asarray(src)[..., 3])
    a = rgba[..., 3] > 40
    rows = [r for r in _grid_runs(a.mean(1), 0.01, 30) if r[1] - r[0] >= 30][:8]
    done = []
    for (v, season), (y0, y1) in zip(pairs, rows):
        bs = _equal_cells(rgba, (4, max(0, y0 - 4), rgba.shape[1] - 4, min(rgba.shape[0], y1 + 4)), 16)
        fr = []
        for b in bs:
            bb = region_bbox(rgba, b)
            fr.append(crop(rgba, bb) if bb else Image.new("RGBA", (8, 8)))
        g = "characters/npc_%s_%s" % (v, season)
        strip([fr[0]], g, "idle"); strip([fr[2]], g, "idle_side"); strip([fr[1]], g, "idle_up")
        strip(fr[3:7], g, "walk"); strip(fr[7:11], g, "walk_down"); strip(fr[11:15], g, "walk_up")
        done.append(g)
    return done


def main():
    groups = []
    want = [a for a in sys.argv[1:] if not a.startswith("-")]  # sheet basenames (default: all)
    for f, pairs in SHEETS.items():
        if want and not any(w in f for w in want):
            continue
        groups += sheet(f, pairs)
    mpath = os.path.join(S.OUT, "manifest.json")
    man = json.load(open(mpath))
    for g in groups:
        man[g] = S.manifest[g]
    tmp = mpath + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(man, fh, indent=1, sort_keys=True)
    os.remove(mpath)
    os.rename(tmp, mpath)
    print("slice_c15_p3:", ", ".join(g.split("/")[1] for g in groups))


if __name__ == "__main__":
    main()

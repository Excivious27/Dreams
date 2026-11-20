#!/usr/bin/env python3
"""CONDUCT 10a P5 art: penguin-hero accessories (scarf, bowtie, goggles) as small 3-view
pieces pinned on Pip-Pip / Nova by Wardrobe (recoloured at runtime by the entry tint).
Source art/incoming/c10/p5_penguin_acc.png: row 1 scarf front/side/back, row 2 bowtie
front/side, row 3 goggles front/side/back. Writes art/gen/decor/pg_<piece>_<view>.png at
one shared scale (scarf 48 px wide). Run after the other slicers (and P6's slice_c10a.py)."""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
import slice_comp as C

ROWS = [("pg_scarf", ["front", "side", "back"]), ("pg_bowtie", ["front", "side"]), ("pg_goggles", ["front", "side", "back"])]


def _rm(p):
    if os.path.exists(p):
        os.remove(p)


def acc():
    import numpy as np
    rgba = np.asarray(S.load("c10/p5_penguin_acc.png")).copy()
    rgba[rgba[..., 3] < 110] = 0
    rows = [r for r in C.rows_of(C.blobs(rgba, merge=10, min_area=1500)) if r]
    assert [len(r) for r in rows] == [3, 2, 3], [len(r) for r in rows]
    f = 48.0 / (rows[0][0][2] - rows[0][0][0])
    for (base, views), row in zip(ROWS, rows):
        for v, b in zip(views, row):
            _rm(os.path.join(S.OUT, "decor", "%s_%s.png" % (base, v)))
            S.save(C.piece(rgba, b, factor=f), "decor", "%s_%s" % (base, v))


if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    acc()
    data = json.dumps(S.manifest, indent=1, sort_keys=True)
    _rm(mpath)
    with open(mpath, "w") as f:
        f.write(data)
    print("ok c10 wardrobe accessories")

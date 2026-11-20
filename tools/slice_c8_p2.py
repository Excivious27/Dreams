#!/usr/bin/env python3
"""CONDUCT 8 P2 art: icons for the new economy goods (premium keg goods, goat cheese, duck egg).
Source: art/incoming/c8/p2_goods.png (a row of 4 over a row of 3; real alpha or magenta key).
Files are removed before writing (art/gen is hardlinked across worktrees)."""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
import slice_comp as C

NAMES = [["reserve_ale", "royal_mead", "gourmet_pickles", "herbal_cordial"], ["truffle_broth", "goat_cheese", "duck_egg"]]


def _rm(path):
    if os.path.exists(path):
        os.remove(path)


def _largest(im):
    import numpy as np
    from scipy import ndimage
    from PIL import Image
    a = np.asarray(im).copy()
    lab, n = ndimage.label(a[..., 3] > 0)
    if n > 1:
        sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
        keep = [i + 1 for i, s in enumerate(sizes) if s >= 0.04 * sizes.max()]  # keep steam/straw bits, drop specks
        a[~np.isin(lab, keep)] = 0
    return Image.fromarray(a)


def goods():
    import numpy as np
    from PIL import Image
    raw = np.asarray(Image.open(os.path.join(S.INC, "c8/p2_goods.png")).convert("RGBA")).copy()
    rgba = S.load("c8/p2_goods.png") if (raw[..., 3] > 0).all() else raw
    rgba = np.asarray(rgba).copy()
    rgba[rgba[..., 3] < 110] = 0
    rows = [r for r in C.rows_of(C.blobs(rgba, merge=24, min_area=2000)) if r]
    assert [len(r) for r in rows] == [4, 3], [len(r) for r in rows]
    for names, row in zip(NAMES, rows):
        for nm, b in zip(names, row):
            _rm(os.path.join(S.OUT, "items", nm + ".png"))
            im = C.piece(rgba, b, h=32)
            if im.width > 32:
                im = C.piece(rgba, b, w=32)  # fit the 32 px icon box like the rest
            S.save(_largest(im), "items", nm)


if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    goods()
    data = json.dumps(S.manifest, indent=1, sort_keys=True)
    _rm(mpath)
    with open(mpath, "w") as f:
        f.write(data)
    print("ok c8 p2 goods")

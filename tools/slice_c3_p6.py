#!/usr/bin/env python3
"""CONDUCT 3 P6 art: the gangster arc's starting weapon, the Street Bat, at all
eight tool tiers (items/bat_<tier>, matched to the sword_<tier> icons: 32 px tall).
Source: art/incoming/c3/p6_street_bats.png (one row of eight bats).
Files are removed before writing (art/gen is hardlinked across worktrees)."""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
import slice_comp as C

TIERS = ["wood", "copper", "iron", "steel", "silver", "gold", "crystal", "moon"]


def _rm(path):
    if os.path.exists(path):
        os.remove(path)


def _largest(im):
    """Keep only the bat itself (stray key specks around it go)."""
    import numpy as np
    from scipy import ndimage
    from PIL import Image
    a = np.asarray(im).copy()
    lab, n = ndimage.label(a[..., 3] > 0)
    if n > 1:
        sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
        keep = 1 + int(np.argmax(sizes))
        a[lab != keep] = 0
    return Image.fromarray(a)


def bats():
    rgba = S.load("c3/p6_street_bats.png")
    rows = C.rows_of(C.blobs(rgba, merge=4, min_area=400))
    row = max(rows, key=len)
    assert len(row) == 8, "expected 8 bats, found %d" % len(row)
    for tier, b in zip(TIERS, row):
        _rm(os.path.join(S.OUT, "items", "bat_%s.png" % tier))
        S.save(_largest(C.piece(rgba, b, h=32)), "items", "bat_" + tier)


if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    bats()
    data = json.dumps(S.manifest, indent=1, sort_keys=True)
    _rm(mpath)
    with open(mpath, "w") as f:
        f.write(data)
    print("ok bats")

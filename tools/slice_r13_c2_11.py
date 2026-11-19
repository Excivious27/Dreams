#!/usr/bin/env python3
"""CONDUCT 2 (c2_11): community farm art. art/incoming/r13/c2_11_*.png ->
  nature/ftree_<apple|orange|plum>_green (leafy, no fruit: the growing season
  between blossom and fruit), props/cf_junk_* (the lot's stage-0 debris).
python3 tools/slice_r13_c2_11.py; then art_audit --fix, godot --import."""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
import numpy as np
from PIL import Image
from slice_comp import load, rows_of, blobs, save_piece


def kit(file, group, names, merge=10):
    raw = Image.open(os.path.join(S.INC, file)).convert("RGBA")
    a = np.asarray(raw)
    # Some renders come back already cut out (transparent background): keep their alpha.
    rgba = a.copy() if (a[..., 3] < 40).mean() > 0.3 else load(file)
    rows = rows_of(blobs(rgba, merge=merge, min_area=2000))
    got = [b for r in rows for b in r]
    assert len(got) == len(names), (file, len(got), rows)
    for b, (name, kw) in zip(got, names):
        p = os.path.join(S.OUT, group, name + ".png")
        if os.path.exists(p):
            os.remove(p)  # art/gen files may be hardlinked: never write in place
        save_piece(rgba, b, group, name, **kw)
        print(group, name, b, S.manifest[group][name]["w"], S.manifest[group][name]["h"])


def run():
    kit("r13/c2_11_ftree_green.png", "nature", [("ftree_apple_green", {"h": 128}), ("ftree_orange_green", {"h": 128}), ("ftree_plum_green", {"h": 128})])
    kit("r13/c2_11_debris_wild.png", "props", [("cf_junk_bramble", {"h": 60}), ("cf_junk_weeds", {"h": 56}), ("cf_junk_branches", {"h": 54}),
                                               ("cf_junk_stones", {"h": 54}), ("cf_junk_stump", {"h": 64})], merge=3)
    kit("r13/c2_11_debris_lot.png", "props", [("cf_junk_slab", {"h": 64}), ("cf_junk_rubble", {"h": 56}), ("cf_junk_scrap", {"h": 56}), ("cf_junk_tyres", {"h": 60})])


if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    run()
    os.remove(mpath)  # hardlinked to the main repo: replace, never write through
    with open(mpath, "w") as f:
        json.dump(S.manifest, f, indent=1, sort_keys=True)

#!/usr/bin/env python3
"""Round 13 (a3): the community farm kit (art/incoming/r13_a3/commons_kit_a/b.png)
into art/gen/props/cf_*.  python3 tools/slice_r13_a3.py
Then: python3 tools/art_audit.py --fix; godot --headless --path . --import"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
from slice_comp import load, rows_of, blobs, save_piece


def kit(file, names, merge=8):
    rgba = load(file)
    rows = rows_of(blobs(rgba, merge=merge, min_area=400))
    got = [b for r in rows for b in r]
    assert len(got) == len(names), (file, len(got), [r for r in rows])
    for b, (name, kw) in zip(got, names):
        save_piece(rgba, b, "props", name, **kw)
        print(name, b, S.manifest["props"][name]["w"], S.manifest["props"][name]["h"])


def icons():
    rgba = load("r13_a3/commons_icons.png")
    bx = sorted(blobs(rgba, merge=12, min_area=2000), key=lambda b: -(b[2] - b[0]) * (b[3] - b[1]))[:4]
    bx.sort(key=lambda b: b[0])
    for b, name in zip(bx, ["commons_stew", "harvest_cobbler", "harvest_basket", "green_thumb_charm"]):
        save_piece(rgba, b, "items", name, w=32, h=32)
        print(name, b)


def run():
    kit("r13_a3/commons_kit_a.png", [("cf_bed_frame", {"w": 232}), ("cf_cold_frame", {"w": 136}),
                                      ("cf_shed_ruin", {"w": 92}), ("cf_well_broken", {"w": 52}), ("cf_compost", {"w": 72})])
    kit("r13_a3/commons_kit_b.png", [("cf_hole", {"w": 34}), ("cf_sapling", {"h": 60}), ("cf_picnic_table", {"w": 104}),
                                      ("cf_mural_wall", {"w": 210}), ("cf_crates", {"w": 76}), ("cf_donation_box", {"h": 60})])


if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    run()
    icons()
    with open(mpath, "w") as f:
        json.dump(S.manifest, f, indent=1, sort_keys=True)

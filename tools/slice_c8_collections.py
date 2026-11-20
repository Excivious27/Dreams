#!/usr/bin/env python3
"""CONDUCT 8 P3 art: museum furniture, collection reward decor, Book tab icon, Curator's Loupe.

Renders: art/incoming/c8/museum_furniture.png (2 rows x 3), art/incoming/c8/collection_rewards.png
(2 rows x 4). Run after the other slicers; then tools/art_audit.py --fix <ids>, set_import_lossy,
godot --import. Hardlinked art: every file is removed before it is written.
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
from slice_comp import blobs, rows_of, tight, piece
import numpy as np
from PIL import Image

SRC = "c8/"


def _rm(group, name):
    p = os.path.join(S.OUT, group, name + ".png")
    if os.path.exists(p):
        os.remove(p)


def save(img, group, name):
    _rm(group, name)
    return S.save(img, group, name)


def rgba_of(file):
    src = Image.open(os.path.join(S.INC, SRC + file)).convert("RGBA")
    a = S.key_magenta(src)
    a = np.asarray(a).copy() if not isinstance(a, np.ndarray) else a
    sa = np.asarray(src)[..., 3]
    a[..., 3] = np.minimum(a[..., 3], sa)
    return a


def grid(rgba, n_rows, n_per):
    bx = blobs(rgba, merge=12, min_area=1500)
    rows = sorted(rows_of(bx), key=lambda r: -sum((b[2] - b[0]) * (b[3] - b[1]) for b in r))[:n_rows]
    rows.sort(key=lambda r: r[0][1])
    out = []
    for r in rows:
        r = sorted(sorted(r, key=lambda b: -(b[2] - b[0]) * (b[3] - b[1]))[:n_per], key=lambda b: b[0])
        assert len(r) == n_per, (len(r), n_per)
        out.append([tight(rgba, b) for b in r])
    assert len(out) == n_rows
    return out


# name, group, target width in art px (2x detail: 32 = one 16-px cell)
FURNITURE = [[("museum_case", "furniture", 32), ("museum_pedestal", "furniture", 26), ("museum_tank", "furniture", 64)],
             [("museum_counter", "furniture", 62), ("museum_sign_wing", "furniture", 26), ("museum_rope", "furniture", 18)]]
REWARDS = [[("mineral_display", "props", 30), ("fish_trophy", "props", 30), ("relic_shelf", "props", 30), ("curio_jar", "props", 22)],
           [("shipper_ribbon", "props", 20), ("museum_trophy", "props", 22), ("tab_book", "ui", 0), ("curators_loupe", "items", 28)]]


def furniture():
    a = rgba_of("museum_furniture.png")
    for row, boxes in zip(FURNITURE, grid(a, 2, 3)):
        for (name, group, w), b in zip(row, boxes):
            save(piece(a, b, w=w), group, name)


def rewards():
    a = rgba_of("collection_rewards.png")
    for row, boxes in zip(REWARDS, grid(a, 2, 4)):
        for (name, group, w), b in zip(row, boxes):
            if name == "tab_book":
                icon = piece(a, b, h=40)
                for sel, base in (("", "tab_items"), ("_sel", "tab_items_sel")):
                    # tab icons sit on the same frame size as tab_items (icon centred)
                    ref = Image.open(os.path.join(S.OUT, "ui", base + ".png"))
                    out = Image.new("RGBA", ref.size, (0, 0, 0, 0))
                    ic = icon if sel else icon.point(lambda v: v)  # same art; menu tints the idle one
                    out.alpha_composite(ic, ((ref.width - ic.width) // 2, (ref.height - ic.height) // 2))
                    save(out, "ui", "tab_book" + sel)
            else:
                save(piece(a, b, w=w), group, name)


STEPS = [furniture, rewards]

if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    only = sys.argv[1:]
    for fn in STEPS:
        if only and fn.__name__ not in only:
            continue
        fn(); print("ok", fn.__name__)
    data = json.dumps(S.manifest, indent=1, sort_keys=True)
    os.remove(mpath)
    with open(mpath, "w") as fh:
        fh.write(data)

#!/usr/bin/env python3
"""C14 P2 town art: plaza flagstone variants, the plaza mosaic, plaza props.

python3 tools/slice_c14_town.py [step ...]   (renders in art/incoming/c14p2/)
Ids are all c14p2_*. Art is hardlinked across worktrees: files are removed
before they are written (never modified in place).
"""
import os, sys, json
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
import slice_comp as C

INC = "c14p2"


def _rm_save(img, group, name):
    p = os.path.join(S.OUT, group, name + ".png")
    if os.path.exists(p):
        os.remove(p)
    return S.save(img, group, name)


def _blocks(file, n, name):
    """n square variants -> tiles/<name>: 2n cols x 2 rows of 32px cells; each variant
    is a 2x2-cell block (64x64), cell index = v*2 + qx + qy*2n."""
    rgba = S.load(INC + "/" + file)
    boxes = sorted(C.blobs(rgba, merge=3, min_area=5000), key=lambda b: b[0])
    boxes = [b for b in boxes if b[2] - b[0] > 100][:n]
    assert len(boxes) == n, boxes
    out = Image.new("RGBA", (64 * n, 64), (0, 0, 0, 0))
    for v, b in enumerate(boxes):
        b = C.tight(rgba, b)
        im = S.crop(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2)).resize((64, 64), Image.LANCZOS)
        a = np.asarray(im).copy()
        a[..., 3] = 255
        out.paste(Image.fromarray(a), (v * 64, 0))
    _rm_save(out, "tiles", name)
    S.manifest["tiles"][name].update({"cell_w": 32, "cell_h": 32, "cols": 2 * n})


def flagstones():
    _blocks("flagstones.png", 4, "c14p2_flag")


def cobbles():
    _blocks("cobbles.png", 3, "c14p2_cobble")


def mosaic():
    """Round compass-star inlay, 256x256 (8x8 cells drawn at 0.5), feathered edge."""
    im = Image.open(os.path.join(S.INC, INC, "plaza_mosaic.png")).convert("RGBA")
    w, h = im.size
    m = int(min(w, h) * 0.035)
    im = im.crop((m, m, w - m, h - m)).resize((256, 256), Image.LANCZOS)
    a = np.asarray(im).copy()
    yy, xx = np.mgrid[0:256, 0:256]
    d = np.hypot(xx - 127.5, yy - 127.5)
    a[..., 3] = np.clip((126 - d) * 255 / 14, 0, 255).astype(np.uint8)
    _rm_save(Image.fromarray(a), "props", "c14p2_mosaic")


PROPS = [  # (name, 2x width) row by row, left to right
    ("c14p2_tree_planter", 92), ("c14p2_flower_kiosk", 104), ("c14p2_cafe_table", 84), ("c14p2_cafe_umbrella", 92),
    ("c14p2_bench_curved", 84), ("c14p2_bench_iron", 70), ("c14p2_drink_fountain", 40), ("c14p2_signpost", 52),
]


def props():
    rgba, rows = C.sheet_rows(INC + "/plaza_props.png", merge=6, min_area=800)
    pieces = [b for r in rows for b in r]
    assert len(pieces) == 8, [len(r) for r in rows]
    for (name, w), b in zip(PROPS, pieces):
        _rm_save(C.piece(rgba, C.tight(rgba, b), w=w), "props", name)


SNOW = ["store", "smith", "bakery", "mansion", "hall", "clock_tower", "potions", "inn", "library", "school",
        "cottage_a", "cottage_b", "cottage_c", "stable", "bandstand", "clinic", "chapel", "warehouse_a", "bank"]


def snow():
    """buildings/<id>_snow: the edit render keyed, its content box scaled onto the original
    content box of the same canvas (so the _lit window mask still lines up)."""
    for b in SNOW:
        f = os.path.join(S.INC, INC, "snow_%s.png" % b)
        if not os.path.exists(f):
            print("   snow: no render for", b); continue
        orig = Image.open(os.path.join(S.OUT, "buildings", b + ".png")).convert("RGBA")
        oa = np.asarray(orig)
        ob = C.content_box(oa)
        rgba = S.load(INC + "/snow_%s.png" % b)
        box = C.content_box(rgba)
        im = S.crop(rgba, box).resize((ob[2] - ob[0], ob[3] - ob[1]), Image.LANCZOS)
        a = np.asarray(im).copy()
        a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
        out = Image.new("RGBA", orig.size, (0, 0, 0, 0))
        out.alpha_composite(Image.fromarray(a), (ob[0], ob[1]))
        _rm_save(out, "buildings", b + "_snow")


def garden():
    """NE gardens: buildings/c14p2_greenhouse (1x like the town buildings, 96 wide) and
    props/c14p2_rose_arbour (2x detail, drawn at 0.5)."""
    rgba, rows = C.sheet_rows(INC + "/garden.png", merge=6, min_area=3000)
    pieces = sorted([b for r in rows for b in r], key=lambda b: (b[2] - b[0]) * (b[3] - b[1]), reverse=True)[:2]
    pieces.sort(key=lambda b: b[0])
    assert len(pieces) == 2, pieces
    _rm_save(C.piece(rgba, C.tight(rgba, pieces[0]), w=96), "buildings", "c14p2_greenhouse")
    _rm_save(C.piece(rgba, C.tight(rgba, pieces[1]), w=76), "props", "c14p2_rose_arbour")


def harbour():
    """Harbour Row buildings (1x, like the town's): fish market, chandlery, ticket office."""
    rgba, rows = C.sheet_rows(INC + "/harbour.png", merge=6, min_area=3000)
    pieces = sorted([b for r in rows for b in r], key=lambda b: (b[2] - b[0]) * (b[3] - b[1]), reverse=True)[:3]
    pieces.sort(key=lambda b: b[0])
    assert len(pieces) == 3, pieces
    for nm, b in zip(["c14p2_fish_market", "c14p2_chandlery", "c14p2_ticket_office"], pieces):
        _rm_save(C.piece(rgba, C.tight(rgba, b), w=112), "buildings", nm)


STEPS = [flagstones, cobbles, mosaic, props, snow, garden, harbour]

if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    only = sys.argv[1:]
    for fn in STEPS:
        if only and fn.__name__ not in only:
            continue
        fn(); print("ok", fn.__name__)
    with open(mpath, "w") as f:
        json.dump(S.manifest, f, indent=1, sort_keys=True)

#!/usr/bin/env python3
"""CONDUCT 3 P4 art: grump variants, Crystal Kin helper, crystal pylon, battlefield
landmarks. Sources: art/incoming/c3p4/*.png (image tool renders, even grids).

    python3 tools/slice_c3_p4.py [step ...]

Writes (rm before write; never in place):
  enemies/grump_<variant>/{idle,walk,attack,hurt}.png   (strips, 2x detail)
  helpers/crystal_kin_crystal_{idle,walk,act}_N.png, _hurt_0/1, helpers/crystal_kin
  props/crystal_pylon (+ _0.._3 frames: 0-1 idle glow, 2-3 zap)
  props/bf_cairn, bf_ruin_pillar, bf_ruin_wall, bf_weir_gate, bf_sky_pillar, bf_sewer_mouth
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image
import slice_art as S
from slice_comp import content_box, even_grid, tight, blobs, rows_of, piece

SRC = "c3p4/"
VARIANTS = {  # name: target idle height (2x px). Base grump idle is 40.
    "crystal": 46, "storm": 44, "frost": 44, "coral": 44, "ember": 44,
    "moss": 40, "brute": 66, "wisp": 46,
}


def _load(name):
    """Renders come with real alpha; key magenta too, but keep the render's alpha."""
    im = Image.open(os.path.join(S.INC, name)).convert("RGBA")
    a = S.key_magenta(im)
    a[..., 3] = np.minimum(a[..., 3], np.asarray(im)[..., 3])
    return a


def _rm(group, name):
    p = os.path.join(S.OUT, group, name + ".png")
    if os.path.exists(p):
        os.remove(p)


def _grid(rgba, cols, rows):
    box = (0, 0, rgba.shape[1], rgba.shape[0])
    return even_grid(rgba, box, cols, rows)


def _clean(rgba, b, keep=0.8):
    """Drop bits that crept in from the row below (blobs starting low in the cell)."""
    parts = [q for q in blobs(rgba, b, merge=4, min_area=30) if q[1] < b[1] + keep * (b[3] - b[1])]
    if not parts:
        return b
    return (min(q[0] for q in parts), min(q[1] for q in parts), max(q[2] for q in parts), max(q[3] for q in parts))


def _frames(rgba, boxes, f):
    return [piece(rgba, b, factor=f) for b in boxes]


def _strip(frames, group, name):
    _rm(group, name)
    S.strip(frames, group, name)


def grumps():
    for v, th in VARIANTS.items():
        rgba = _load(SRC + "grump_%s.png" % v)
        g = _grid(rgba, 4, 3)
        hs = [b[3] - b[1] for b in g[0]]
        f = th / float(np.median(hs))
        grp = "enemies/grump_" + v
        idle = _frames(rgba, g[0], f)
        _strip(idle, grp, "idle")
        _strip(_frames(rgba, g[1], f), grp, "walk")
        _strip(_frames(rgba, g[2], f), grp, "attack")
        # hurt: the idle pose knocked back a little (flash shader does the white)
        hurt = []
        for i, im in enumerate(idle[:2]):
            r = im.rotate(8 if i == 0 else -5, resample=Image.NEAREST, expand=True)
            hurt.append(r)
        _strip(hurt, grp, "hurt")


def _pad(frames, align="center"):
    """One canvas for every frame (drawers scale by frame size), feet on the bottom."""
    cw = max(f.width for f in frames); ch = max(f.height for f in frames)
    out = []
    for f in frames:
        c = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        x = 0 if align == "left" else (cw - f.width) // 2
        c.alpha_composite(f, (x, ch - f.height))
        out.append(c)
    return out


def kin_pylon():
    rgba = _load(SRC + "kin_pylon.png")
    g = _grid(rgba, 4, 4)
    f = 60.0 / float(np.median([b[3] - b[1] for b in g[0]]))
    idle = [piece(rgba, b, factor=f) for b in g[0]]
    hurt = [im.rotate(7 if i == 0 else -7, resample=Image.NEAREST, expand=True) for i, im in enumerate(idle[:2])]
    allf = {"idle": idle, "walk": [piece(rgba, b, factor=f) for b in g[1]],
            "act": [piece(rgba, _clean(rgba, b), factor=f) for b in g[2]], "hurt": hurt}
    flat = _pad([im for v in allf.values() for im in v])
    k = 0
    for anim, fr in allf.items():
        for i in range(len(fr)):
            nm = "crystal_kin_crystal_%s_%d" % (anim, i)
            _rm("helpers", nm)
            S.save(flat[k], "helpers", nm); k += 1
    _rm("helpers", "crystal_kin")
    S.save(flat[0], "helpers", "crystal_kin")
    # pylon: frames 0-1 idle glow, 2-3 zap beam to the right (body left-aligned)
    fp = 84.0 / float(np.median([b[3] - b[1] for b in g[3]]))
    pf = _pad([piece(rgba, b, factor=fp) for b in g[3]], align="left")
    for i, im in enumerate(pf):
        nm = "crystal_pylon_%d" % i
        _rm("props", nm)
        S.save(im, "props", nm)
    _rm("props", "crystal_pylon")
    S.save(piece(rgba, g[3][0], factor=fp), "props", "crystal_pylon")


LANDMARKS = [("bf_cairn", 96), ("bf_ruin_pillar", 120), ("bf_ruin_wall", 96),
             ("bf_weir_gate", 100), ("bf_sky_pillar", 120), ("bf_sewer_mouth", 100)]


def landmarks():
    rgba = _load(SRC + "bf_landmarks.png")
    g = _grid(rgba, 3, 2)
    cells = g[0] + g[1]
    for (nm, h), b in zip(LANDMARKS, cells):
        # largest blob in the cell (drops stray pebbles from neighbours)
        parts = blobs(rgba, b, merge=6, min_area=200)
        if parts:
            x0 = min(p[0] for p in parts); y0 = min(p[1] for p in parts)
            x1 = max(p[2] for p in parts); y1 = max(p[3] for p in parts)
            b = (x0, y0, x1, y1)
        _rm("props", nm)
        S.save(piece(rgba, b, h=h), "props", nm)


STEPS = [grumps, kin_pylon, landmarks]

if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    only = sys.argv[1:]
    for fn in STEPS:
        if only and fn.__name__ not in only:
            continue
        fn(); print("ok", fn.__name__)
    tmp = mpath + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(S.manifest, fh, indent=1, sort_keys=True)
    os.remove(mpath); os.rename(tmp, mpath)

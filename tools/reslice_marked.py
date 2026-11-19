#!/usr/bin/env python3
"""Re-slice the ten Marked (Prompt 15 batch 7, w304-w308) with hand-checked cells.

The first slicer (slice_world._mk_sheet) cut each band at empty columns and
mapped cells by their position out of 16. Flame trails, rings and wind streaks
join neighbouring figures, so cells merged and every later name slid: Ember's
power strip had half-figures cut at the seams, Rio's attack strip showed his
back, his sit/sleep were ring pulses, several views were tool poses, and side
strips drawn facing left played backwards against the walk.

Here each band is cut on the sheet's own grid (16 cells, pitch measured from
the band), every cell keeps only the pieces whose centre lies in it, each
character gets ONE scale, and frames are centred on the torso with feet on
the bottom line (reslice_hero12.steady_strip). SPEC lists, per character, the
cells of every animation as (row, cell) pairs; "f" flips a strip drawn facing
left so every side strip faces right like the walk. Files are removed before
they are written (art/ is hardlinked).

    python3 tools/reslice_marked.py [mk_ember mk_rio ...]
    python3 tools/reslice_marked.py --cells OUTDIR   # indexed cell sheets to check SPEC
Run after slice_world.py (it replaces those strips) and before art_audit.py."""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
import slice_world as W  # noqa: E402
from reslice_hero12 import steady_strip, write, scaled  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "gen")

SHEETS = {"w304_marked_kit_ember.png": ("mk_kit", "mk_ember"), "w305_marked_dahlia_juno.png": ("mk_dahlia", "mk_juno"),
          "w306_marked_rio_mei.png": ("mk_rio", "mk_mei"), "w307_marked_bruno_tomas.png": ("mk_bruno", "mk_tomas"),
          "w308_marked_sable_atlas.png": ("mk_sable", "mk_atlas")}
# One scale for every cell (the old slicer kept ~0.96 of source size per
# frame); drawn sizes stay as drawn, so big Atlas stays big.
SCALE = 0.96


def R(row, a, b, step=1):
    return [(row, c) for c in range(a, b, step)]


# Default layout (the prompt): row A idle d/u/s x2, walk down x4, up x4, side x2;
# row B walk side x2, attack down/up/side x3, hurt x2, yield x2, join x1;
# row C power x6, guard x2, tired x2, sit, sleep, cheer x2, laugh x2.
def default():
    return {"idle": R(0, 0, 2), "idle_up": R(0, 2, 4), "idle_side": R(0, 4, 6), "walk_down": R(0, 6, 10),
            "walk_up": R(0, 10, 14), "walk": R(0, 14, 16) + R(1, 0, 2), "attack_down": R(1, 2, 5),
            "attack_up": R(1, 5, 8), "attack": R(1, 8, 11), "hurt": R(1, 11, 13), "yield": R(1, 13, 15),
            "wave": R(1, 15, 16), "power": R(2, 0, 6), "guard": R(2, 6, 8), "tired": R(2, 8, 10),
            "sit": R(2, 10, 11), "sleep": R(2, 11, 12), "cheer": R(2, 12, 14), "laugh": R(2, 14, 16)}


SPEC = {}  # filled below, after the cells were checked by eye
FLIP = {}  # character -> set of animations drawn facing left
NCELLS = {}  # character -> {row: cells} where a row holds 17 figures
VIEW_CELLS = {}  # character -> {view: (row, cell, flip)} when the sheet has no view row
SOLO = {}  # character -> animations that keep only their largest piece (a stray "Z")


def bands(rgba):
    on = (rgba[:, :, 3] > 40).sum(axis=1) > 3
    runs, st = [], None
    for y in range(len(on) + 1):
        v = y < len(on) and on[y]
        if v and st is None:
            st = y
        if not v and st is not None:
            if y - st > 10:
                runs.append([st, y])
            st = None
    return runs


def grid_x(rgba, y0, y1, n=16):
    """Cell boundaries of a band: n equal cells between the first and last
    sprite columns (a few rows squeeze in a 17th figure)."""
    col = (rgba[y0:y1, :, 3] > 40).sum(axis=0) > 1
    xs = np.nonzero(col)[0]
    a, b = int(xs.min()), int(xs.max()) + 1
    pitch = (b - a) / float(n)
    return [int(round(a + i * pitch)) for i in range(n + 1)]


def cell_figs(rgba, y0, y1, edges):
    """Each grid cell's own pieces: components (alpha) assigned to the cell
    holding their centre; a component wider than 1.6 cells (two figures joined
    by a streak) is cut at the cell lines instead."""
    win = rgba[y0:y1]
    a = win[..., 3] > 40
    lab, n = ndimage.label(a, structure=np.ones((3, 3)))
    figs = []
    nc = len(edges) - 1
    masks = [np.zeros_like(a) for _ in range(nc)]
    pitch = (edges[-1] - edges[0]) / float(nc)
    objs = ndimage.find_objects(lab)
    for i, sl in enumerate(objs, 1):
        if sl is None:
            continue
        m = lab[sl] == i
        if m.sum() < 6:
            continue
        x0, x1 = sl[1].start, sl[1].stop
        if x1 - x0 > 1.6 * pitch:
            for c in range(nc):
                lo, hi = max(x0, edges[c]), min(x1, edges[c + 1])
                if lo < hi:
                    sub = masks[c][sl[0], lo:hi]
                    masks[c][sl[0], lo:hi] = sub | m[:, lo - x0:hi - x0]
            continue
        ys, xs = np.nonzero(m)
        cx = x0 + xs.mean()
        c = int(np.clip(np.searchsorted(edges, cx) - 1, 0, nc - 1))
        masks[c][sl] |= m
    for c in range(nc):
        m = masks[c]
        if m.sum() < 30:
            figs.append(None)
            continue
        out = win.copy()
        out[..., 3] = np.where(m, win[..., 3], 0)
        ys, xs = np.nonzero(m)
        figs.append(Image.fromarray(out[ys.min():ys.max() + 1, xs.min():xs.max() + 1].astype(np.uint8)))
    return figs


def blob_figs(rgba, y0, y1):
    """Figures of the views row, left to right (column runs); portraits and
    icons come after."""
    a = rgba[y0:y1, :, 3] > 40
    col = a.sum(axis=0) > 1
    runs, st = [], None
    for x in range(len(col) + 1):
        v = x < len(col) and col[x]
        if v and st is None:
            st = x
        if not v and st is not None:
            if x - st >= 8:
                runs.append([st, x])
            st = None
    if not runs:
        return []
    cut = runs  # on every sheet the views stand apart
    out = []
    for a0, b in cut:
        sub = rgba[y0:y1, a0:b]
        ys, xs = np.nonzero(sub[..., 3] > 40)
        out.append(Image.fromarray(sub[ys.min():ys.max() + 1, xs.min():xs.max() + 1].copy()) if len(ys) else None)
    return out


def char_rows(file):
    """{cid: [row figs...]} for the two characters on a sheet."""
    rgba = W.load_hue(file)
    bs = bands(rgba)
    half = rgba.shape[0] / 2.0
    out = {}
    for cid, sel in zip(SHEETS[file], [[b for b in bs if (b[0] + b[1]) / 2 < half], [b for b in bs if (b[0] + b[1]) / 2 >= half]]):
        rows = []
        for r, (y0, y1) in enumerate(sel):
            y0, y1 = max(0, y0 - 2), min(rgba.shape[0], y1 + 2)
            if r == len(sel) - 1:
                rows.append(blob_figs(rgba, y0, y1))  # views + portraits: not on the grid
            else:
                rows.append(cell_figs(rgba, y0, y1, grid_x(rgba, y0, y1, NCELLS.get(cid, {}).get(r, 16))))
        out[cid] = rows
    return out


def cells_sheet(cid, rows, path):
    """Every cell with its (row, cell) label, to check SPEC by eye."""
    cw, chh = 100, 130
    img = Image.new("RGB", (max(len(r) for r in rows) * cw, len(rows) * chh), (60, 120, 70))
    d = ImageDraw.Draw(img)
    for r, figs in enumerate(rows):
        for c, f in enumerate(figs):
            x, y = c * cw, r * chh
            d.rectangle([x, y, x + cw - 1, y + chh - 1], outline=(20, 20, 20))
            if f is not None:
                ff = f if f.height <= chh - 14 else scaled(f, (chh - 14) / float(f.height))
                ff = ff if ff.width <= cw - 2 else scaled(ff, (cw - 2) / float(ff.width))
                img.paste(ff, (x + (cw - ff.width) // 2, y + chh - ff.height), ff)
            d.text((x + 3, y + 2), "%d,%d" % (r, c), fill=(255, 255, 255))
    img.save(path)


def largest(img):
    a = np.array(img)
    lab, n = ndimage.label(a[..., 3] > 40, structure=np.ones((3, 3)))
    if n < 2:
        return img
    k = 1 + int(np.argmax(ndimage.sum(np.ones_like(lab), lab, np.arange(1, n + 1))))
    a[..., 3] = np.where(lab == k, a[..., 3], 0)
    ys, xs = np.nonzero(a[..., 3])
    return Image.fromarray(a[ys.min():ys.max() + 1, xs.min():xs.max() + 1])


def reslice(cid, rows, manifest):
    spec = dict(default())
    spec.update(SPEC.get(cid, {}))
    for k in [k for k, v in spec.items() if not v]:
        # Nothing on the sheet for it: drop the old wrong strip so the
        # CharacterLibrary fallback (e.g. attack_up -> attack_down) is used.
        path = os.path.join(OUT, "characters", cid, k + ".png")
        for f in (path, path + ".import"):
            if os.path.exists(f):
                os.remove(f)
        manifest.get("characters/" + cid, {}).pop(k, None)
    spec = {k: v for k, v in spec.items() if v}
    s = SCALE
    G = "characters/" + cid
    for name, cells in spec.items():
        part = [rows[r][c] for r, c in cells if r < len(rows) and rows[r][c] is not None]
        if not part:
            print("   %s %s: no cells" % (cid, name))
            continue
        if name in SOLO.get(cid, ()):
            part = [largest(f) for f in part]
        img, cw, ch = steady_strip([scaled(f, s) for f in part], flip=name in FLIP.get(cid, ()))
        write(manifest, G, name, img, cw, ch, len(part))
    views = VIEW_CELLS.get(cid) or {nm: (len(rows) - 1, i, False) for i, nm in
                                      enumerate(["view_front", "view_right", "view_back", "view_left"])}
    for nm, (r, c, fl) in views.items():
        f = rows[r][c] if c < len(rows[r]) else None
        if f is None:
            continue
        img, cw, ch = steady_strip([scaled(f, s)], flip=fl)
        write(manifest, G, nm, img, cw, ch, 1)
    print("  %s: %d rows, scale %.3f" % (cid, len(rows), s))


# ---------------------------------------------------------------- the cells
# Checked against `--cells` sheets. Only the differences from default().
C = lambda *pairs: [tuple(p) for p in pairs]  # noqa: E731
# Most sheets drew row B in the HERO layout (walk x2, run down/up/side x4,
# hurt/yield) instead of attacks, so attacks come from wherever the artist put
# them; a back-view attack exists on none of them (attack_up is dropped and
# falls back to attack_down). Every side strip here faces right like the walk.
SPEC.update({
    "mk_ember": {"attack_down": R(1, 2, 5), "attack": R(1, 6, 9), "attack_up": [], "hurt": C((1, 15)),
                 "yield": C((1, 14)), "wave": C((2, 14)), "guard": R(2, 7, 9), "tired": R(2, 9, 11),
                 "sit": C((2, 11)), "sleep": C((2, 12)), "cheer": R(2, 13, 15), "laugh": C((2, 15))},
    "mk_rio": {"attack_down": R(2, 1, 4), "attack_up": [], "attack": R(3, 3, 6), "hurt": C((1, 14)),
               "yield": R(2, 12, 14), "wave": C((3, 15)),
               "power": C((2, 2), (2, 7), (2, 8), (2, 9), (2, 10), (2, 11)),
               "guard": C((3, 8), (3, 9)), "tired": R(3, 11, 13), "sit": C((3, 6)), "sleep": C((3, 7)),
               "cheer": C((3, 10), (3, 13)), "laugh": C((3, 14))},
    "mk_kit": {"attack": R(1, 3, 6), "attack_down": [], "attack_up": [], "hurt": C((1, 14)), "yield": C((1, 15)),
               "wave": C((2, 14)), "guard": R(2, 7, 9), "tired": R(2, 9, 11), "sit": C((2, 11)),
               "sleep": C((2, 12)), "cheer": C((2, 13)), "laugh": C((2, 14), (2, 15))},
    "mk_mei": {"attack": R(1, 3, 6), "attack_down": [], "attack_up": [], "hurt": C((1, 14)), "wave": C((1, 15)),
               "yield": C((2, 12)), "power": C((2, 0), (2, 2), (2, 4), (2, 5), (2, 6), (2, 7)),
               "guard": R(2, 9, 11), "tired": R(2, 11, 13), "sit": C((2, 11)), "sleep": C((2, 13)),
               "cheer": C((2, 14)), "laugh": C((2, 15))},
    "mk_bruno": {"attack": R(1, 2, 5), "attack_down": R(1, 5, 8), "attack_up": [], "hurt": R(1, 10, 12),
                 "yield": R(1, 12, 14), "wave": C((1, 15)), "guard": R(2, 14, 16), "tired": R(2, 7, 9),
                 "sit": C((2, 9)), "sleep": C((2, 10)), "cheer": R(2, 11, 13), "laugh": C((2, 13))},
    "mk_tomas": {"attack": R(1, 3, 6), "attack_down": R(1, 6, 8), "attack_up": [], "hurt": R(1, 10, 12),
                 "yield": R(1, 12, 14), "wave": C((1, 15)), "power": C((2, 0), (2, 1), (2, 2), (2, 3), (2, 3), (2, 5)),
                 "guard": R(2, 6, 8), "tired": C((2, 8)), "sit": C((2, 9)), "sleep": C((2, 10)),
                 "cheer": C((2, 12), (1, 14)), "laugh": C((2, 11))},
    "mk_sable": {"attack": R(2, 5, 8), "attack_down": [], "attack_up": [], "hurt": C((1, 14)), "yield": C((1, 15)),
                 "wave": C((2, 15)), "power": C((2, 0), (2, 1), (2, 2), (2, 3), (2, 4), (2, 0)),
                 "guard": R(2, 8, 10), "tired": C((2, 10)), "sit": C((2, 11)), "sleep": C((2, 12)),
                 "cheer": C((2, 13)), "laugh": R(2, 14, 16)},
    "mk_atlas": {"walk_up": R(0, 2, 4), "attack": R(1, 2, 5), "attack_down": R(1, 7, 10), "attack_up": [], "hurt": R(1, 10, 12),
                 "yield": C((1, 13)), "wave": C((1, 15)), "power": C((2, 0), (2, 2), (2, 3), (2, 5), (2, 6), (2, 7)),
                 "guard": C((2, 8)), "tired": R(2, 10, 12), "sit": C((2, 10)), "sleep": C((2, 12)),
                 "cheer": C((2, 13), (1, 14)), "laugh": R(2, 14, 16)},
    "mk_dahlia": {"walk": R(0, 13, 17), "walk_up": R(0, 10, 12), "attack": R(1, 3, 6), "attack_down": [], "attack_up": [], "hurt": C((1, 11)),
                  "yield": C((1, 12)), "wave": C((1, 15)), "guard": R(2, 7, 9), "tired": R(2, 10, 12),
                  "sit": C((2, 12)), "sleep": C((2, 13)), "cheer": R(2, 14, 16), "laugh": C((2, 15))},
    "mk_juno": {"walk": R(0, 13, 17), "walk_up": R(0, 10, 12), "attack": R(1, 3, 6), "attack_down": [], "attack_up": [], "hurt": C((1, 11)),
                "yield": C((1, 12)), "wave": C((1, 15)), "power": C((2, 0), (2, 1), (2, 2), (2, 3), (1, 4), (1, 5)),  # the beam cells 2,4-2,7 run into each other
                "guard": R(2, 8, 10), "tired": R(2, 10, 12), "sit": C((2, 12)), "sleep": C((2, 13)),
                "cheer": R(2, 14, 16), "laugh": C((2, 15))},
})
FLIP.update({"mk_rio": {"idle_side"}, "mk_bruno": {"idle_side"}, "mk_atlas": {"idle_side"}})
SOLO.update({"mk_sable": {"cheer"}})
# Bruno's fourth row is tool poses (pickaxe, forge): views come from row A.
VIEW_CELLS.update({"mk_bruno": {"view_front": (0, 0, False), "view_back": (0, 2, False),
                                "view_right": (0, 4, True), "view_left": (0, 4, False)},
                  # Dahlia and Juno open their last row with tool poses; views are figures 4-7.
                  "mk_dahlia": {"view_front": (3, 4, False), "view_right": (3, 5, False), "view_back": (3, 6, False), "view_left": (3, 7, False)},
                  "mk_juno": {"view_front": (3, 4, False), "view_right": (3, 5, False), "view_back": (3, 6, False), "view_left": (3, 7, False)}})
NCELLS.update({"mk_dahlia": {0: 17}, "mk_juno": {0: 17}})


if __name__ == "__main__":
    args = sys.argv[1:]
    if args[:1] == ["--cells"]:
        od = args[1]
        os.makedirs(od, exist_ok=True)
        for file in SHEETS:
            for cid, rows in char_rows(file).items():
                cells_sheet(cid, rows, os.path.join(od, cid + ".png"))
        sys.exit(0)
    mpath = os.path.join(OUT, "manifest.json")
    manifest = json.load(open(mpath))
    for file, cids in SHEETS.items():
        if args and not set(cids) & set(args):
            continue
        for cid, rows in char_rows(file).items():
            if args and cid not in args:
                continue
            reslice(cid, rows, manifest)
    os.remove(mpath)
    with open(mpath, "w") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)

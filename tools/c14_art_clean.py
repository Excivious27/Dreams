#!/usr/bin/env python3
"""C14 P6 art cleanup passes over existing sliced art (rm first, then write; never in place).

  badges   (c14_17-22) item icons: a cut-off sheet badge (diamond/crescent from the
           source sheet) in the top-left 12x12 corner, a separate blob or one joined by
           a neck of <= 2 px, is cleared. Pinholes (enclosed transparent runs <= 4 px)
           in icons are filled with the neighbour mean.
  shadows  (c14_17-02, c14_17-12) helpers / enemies / animals: magenta key residue in the
           lower 45% of each frame (hue near #FF00FF, r ~ b, g low) becomes the shared
           translucent black ground shadow.
Usage: python3 tools/c14_art_clean.py badges|shadows [--dry] [--sheet out.png]
Prints every file it changed; --dry changes nothing; --sheet writes a before/after sheet.
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEN = os.path.join(ROOT, "art", "gen")
MAN = json.load(open(os.path.join(GEN, "manifest.json")))
CORNER = 12
SHADOW_EXTRA = ("cloud_sheep_shorn", "rock_crab")  # c14_17-12 named outside helpers/


def write(rel, arr):
    dst = os.path.join(GEN, rel)
    os.remove(dst)  # art is hardlinked across worktrees
    Image.fromarray(arr, "RGBA").save(dst)


def clean_badge(a):
    al = a[..., 3] > 30
    h, w = al.shape
    if h < 20 or w < 20:
        return None
    out = a.copy()
    changed = False
    # 1) whole small blobs in the corner
    lab, k = ndimage.label(al)
    if k > 1:
        sizes = ndimage.sum(al, lab, range(1, k + 1))
        main = int(np.argmax(sizes)) + 1
        for i in range(1, k + 1):
            if i == main:
                continue
            ys, xs = np.where(lab == i)
            if ys.max() < CORNER and xs.max() < CORNER and sizes[i - 1] < 60:
                out[lab == i, 3] = 0
                changed = True
    # 2) a corner blob joined by a thin neck: split with an opening, drop the corner part
    al2 = out[..., 3] > 30
    op = ndimage.binary_erosion(al2, iterations=2)
    lab, k = ndimage.label(op)
    if k > 1:
        sizes = ndimage.sum(op, lab, range(1, k + 1))
        main = int(np.argmax(sizes)) + 1
        for i in range(1, k + 1):
            if i == main:
                continue
            ys, xs = np.where(lab == i)
            if ys.max() < CORNER - 2 and xs.max() < CORNER - 2 and sizes[i - 1] < 25:
                # the blob's own pixels: grow it back inside the corner box only
                grow = ndimage.binary_dilation(lab == i, iterations=3) & al2
                grow[CORNER:, :] = False
                grow[:, CORNER:] = False
                # never cut into the main body's eroded core
                grow &= ~ndimage.binary_dilation(lab == main, iterations=2)
                if grow.sum() >= 3:
                    out[grow, 3] = 0
                    changed = True
    # 3) pinholes: enclosed transparent runs of <= 4 px
    al3 = out[..., 3] > 30
    holes = ndimage.binary_fill_holes(al3) & ~al3
    hl, hk = ndimage.label(holes)
    for i in range(1, hk + 1):
        m = hl == i
        if m.sum() <= 3:
            ring = ndimage.binary_dilation(m) & al3
            if ring.any():
                out[m, :3] = out[ring, :3].mean(axis=0).astype(np.uint8)
                out[m, 3] = 255
                changed = True
    return out if changed else None


def clean_shadow(a, cell_w):
    r, g, b = (a[..., i].astype(int) for i in range(3))
    al = a[..., 3]
    mag = (al > 0) & (np.minimum(r, b) > 100) & (np.abs(r - b) < 60) & (g < 0.5 * np.minimum(r, b))
    h = a.shape[0]
    band = np.zeros_like(mag)
    band[int(h * 0.55):, :] = True
    hit = mag & band
    if hit.sum() < 6:
        return None
    out = a.copy()
    out[hit, 0:3] = 0
    out[hit, 3] = 64
    return out


# holes (c14_17-21, -03, -17, -19, -10, -20): enclosed see-through specks left by the key are
# filled with the mean of their ring. Folder entries cover every strip inside.
HOLES = {"nature/mid_cherry.png": 8, "nature/mid_cherry_b.png": 8, "nature/big_cherry_a.png": 8, "nature/big_cherry_b.png": 8,
         "hats/witch.png": 6, "stations/cauldron_4.png": 10, "enemies/dark_crystal": 400, "enemies/finargle": 6,
         "enemies/cboss_coral": 6, "helpers/shade_drone_act_2.png": 8, "helpers/shade_drone_act_3.png": 8,
         "helpers/shade_crystal_act_2.png": 8}
for _k in ("elder_brine", "elder_cinderpaw", "elder_icewhisker", "elder_tidewhisker") + tuple(
        "%s_kit_%d" % (c, i) for c in ("coral", "ice", "ember", "kelp") for i in (1, 2, 3)):
    HOLES["characters/" + _k] = 6


def fill_holes(a, most):
    al = a[..., 3] > 30
    holes = ndimage.binary_fill_holes(al) & ~al
    hl, hk = ndimage.label(holes)
    if hk == 0:
        return None
    out = a.copy()
    n = 0
    for i in range(1, hk + 1):
        m = hl == i
        if m.sum() > most:
            continue
        ring = ndimage.binary_dilation(m, iterations=1) & al
        if ring.any():
            out[m, :3] = np.median(out[ring, :3], axis=0).astype(np.uint8)
            out[m, 3] = 255
            n += 1
    return out if n else None


def hole_files():
    for k, most in HOLES.items():
        p = os.path.join(GEN, k)
        if os.path.isdir(p):
            for f in sorted(os.listdir(p)):
                if f.endswith(".png"):
                    yield k + "/" + f, most
        elif os.path.exists(p):
            yield k, most


def files(kind):
    for group, items in MAN.items():
        if not isinstance(items, dict):
            continue
        for name, info in items.items():
            if not isinstance(info, dict) or "file" not in info:
                continue
            f = info["file"]
            if kind == "badges" and f.startswith("items/"):
                yield f, info
            if kind == "shadows" and (f.startswith("helpers/") or f.split("/")[1] in SHADOW_EXTRA):
                yield f, info


def main():
    kind = sys.argv[1]
    dry = "--dry" in sys.argv
    sheet = sys.argv[sys.argv.index("--sheet") + 1] if "--sheet" in sys.argv else ""
    pairs = []
    seen = set()
    if kind == "holes":
        for rel, most in hole_files():
            a = np.array(Image.open(os.path.join(GEN, rel)).convert("RGBA"))
            out = fill_holes(a, most)
            if out is None:
                continue
            print(rel)
            pairs.append((a, out))
            if not dry:
                write(rel, out)
    for rel, info in ([] if kind == "holes" else files(kind)):
        if rel in seen or not os.path.exists(os.path.join(GEN, rel)):
            continue
        seen.add(rel)
        a = np.array(Image.open(os.path.join(GEN, rel)).convert("RGBA"))
        out = clean_badge(a) if kind == "badges" else clean_shadow(a, int(info.get("cell_w", a.shape[1])))
        if out is None:
            continue
        print(rel)
        pairs.append((a, out))
        if not dry:
            write(rel, out)
    print(f"{kind}: {len(pairs)} files", file=sys.stderr)
    if sheet and pairs:
        cells = pairs[:120]
        cw = max(p[0].shape[1] for p in cells) * 2 + 6
        ch = max(p[0].shape[0] for p in cells) + 4
        cols = 6
        img = Image.new("RGBA", (cw * cols, ch * ((len(cells) + cols - 1) // cols)), (70, 100, 70, 255))
        for i, (a, o) in enumerate(cells):
            x, y = (i % cols) * cw, (i // cols) * ch
            img.alpha_composite(Image.fromarray(a, "RGBA"), (x, y))
            img.alpha_composite(Image.fromarray(o, "RGBA"), (x + a.shape[1] + 2, y))
        img.save(sheet)


if __name__ == "__main__":
    main()

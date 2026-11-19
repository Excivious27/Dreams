#!/usr/bin/env python3
"""Re-cut the ground and medium wildlife rows of w64_wildlife_scaled.png
(rabbit, squirrel, hedgehog, frog, turtle, mouse, rat, snake; deer, fox,
boar, goat, raccoon, badger, otter, beaver).

slice_world.w64 asked for exactly 24 sprites per row, but animals of one
group touch (the deer's legs, the fox trio, the goats), so whole animals were
cut in half and neighbours' slivers sat in the frames: the deer's walk showed
half a deer and a stray strip. Here each group is split at the emptiest
column between its figures, every figure keeps only its own pixels, the sheet
scale stays uniform (hero = 64 px), and frames are centred on the torso and
bottom-anchored. Files are removed before they are written.

    python3 tools/reslice_wildlife.py"""
import json, os, sys
import numpy as np
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
import slice_world as W  # noqa: E402
from reslice_hero12 import _figure, steady_strip, write, scaled, OUT  # noqa: E402

# Row -> per group (in x order): (name or None, splits per component).
ROWS = {
    3: [("rabbit", None), ("squirrel", [1, 2]), ("hedgehog", None), ("frog", None), ("turtle", None),
        ("mouse", None), ("rat", [1, 2]), (None, None), ("snake", None)],
    5: [("deer", None), ("fox", [3]), ("boar", None), ("goat", [3]), ("raccoon", None),
        ("badger", [1, 2]), ("otter", [1, 2]), ("beaver", None)],
}


def comps(a, y0, y1, x0=10, x1=1526):
    sub = a[y0:y1, x0:x1]
    lab, n = ndimage.label(ndimage.binary_dilation(sub, iterations=2))
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        if (lab[sl] == i + 1).sum() < 80:
            continue
        out.append((sl[1].start + x0, y0, sl[1].stop + x0, y1))
    out.sort()
    groups = [[out[0]]]
    for b in out[1:]:
        if b[0] - groups[-1][-1][2] >= 15:
            groups.append([b])
        else:
            groups[-1].append(b)
    return groups


def split_valley(a, box, k):
    """Split a box into k figures at the emptiest columns near the even cuts."""
    if k <= 1:
        return [box]
    x0, y0, x1, y1 = box
    col = a[y0:y1, x0:x1].sum(0)
    w = x1 - x0
    cuts = [x0]
    for j in range(1, k):
        c = int(w * j / k)
        r = max(2, int(w / (2.0 * k) * 0.6))
        lo, hi = max(1, c - r), min(w - 1, c + r)
        cuts.append(x0 + lo + int(np.argmin(col[lo:hi])))
    cuts.append(x1)
    return [(cuts[i], y0, cuts[i + 1], y1) for i in range(k)]


def figure_cut(rgba, box):
    """A figure cut out of a touching group: the box's own pixels, minus the
    bits of the neighbours that the cut left at its sides."""
    from PIL import Image
    x0, y0, x1, y1 = box
    win = rgba[y0:y1, x0:x1].copy()
    a = win[..., 3] > 0
    lab, n = ndimage.label(a, structure=np.ones((3, 3)))
    if n == 0:
        return None
    sizes = ndimage.sum(a, lab, np.arange(1, n + 1))
    big = float(max(sizes))
    keep = np.zeros_like(a)
    for i in range(1, n + 1):
        m = lab == i
        cols = np.nonzero(m.any(0))[0]
        edge = cols.min() <= 1 or cols.max() >= m.shape[1] - 2
        if sizes[i - 1] >= 0.999 * big or (sizes[i - 1] >= 0.2 * big and not edge) or sizes[i - 1] >= 0.45 * big:
            keep |= m
    win[..., 3] = np.where(keep, win[..., 3], 0)
    ys, xs = np.nonzero(win[..., 3] > 0)
    return Image.fromarray(win[ys.min():ys.max() + 1, xs.min():xs.max() + 1].astype(np.uint8))


def main():
    rgba = W.load_hue("w64_wildlife_scaled.png")
    a = rgba[..., 3] > 40
    rows = [r for r in W._grid_runs(a.mean(1), 0.02, 30) if r[1] - r[0] >= 40]
    # Scale: the hero in row 0 is 64 px in our 2x units (as slice_world.w64).
    hero = W.region_bbox(rgba, (10, rows[0][0], 120, rows[0][1]))
    sc = 64.0 / (hero[3] - hero[1])
    mpath = os.path.join(OUT, "manifest.json")
    manifest = json.load(open(mpath))
    for ri, spec in ROWS.items():
        y0, y1 = rows[ri]
        groups = comps(a, y0, y1)
        if len(groups) != len(spec):
            print("  row %d: %d groups, expected %d: skipped" % (ri, len(groups), len(spec)))
            continue
        for (name, splits), grp in zip(spec, groups):
            if name is None:
                continue
            figs = []
            for i, b in enumerate(grp):
                k = 1 if splits is None else splits[i]
                if k == 1:
                    figs.append(_figure(rgba, b))
                else:
                    figs.extend(figure_cut(rgba, c) for c in split_valley(a, b, k))
            figs = [scaled(f, sc) for f in figs if f is not None]
            G = "wildlife/" + name
            idle, walk = figs[:1], (figs[1:] if len(figs) >= 3 else figs[:2])
            if name == "turtle":
                walk = figs[:1]  # the second turtle overlaps a third on the sheet
            for anim, fr in (("idle", idle), ("walk", walk)):
                img, cw, ch = steady_strip(fr)
                write(manifest, G, anim, img, cw, ch, len(fr))
            print("  %s: %d figures" % (name, len(figs)))
    cats(manifest)
    os.remove(mpath)
    with open(mpath, "w") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)


def cats(manifest):
    """Town/forest cats (w23 row 11: grey, orange, black x 4 poses). The first
    cut was off by one, so the grey cat's idle blinked into an orange cat and
    the orange one into a black cat (the "flashing cat" in town)."""
    rgba = W.load_hue("w23_wildlife.png")
    y0, y1, x0, x1 = 812, 908, 10, 905
    cw = (x1 - x0) / 12.0
    figs = [_figure(rgba, (int(x0 + i * cw) + 2, y0, int(x0 + (i + 1) * cw) - 2, y1)) for i in range(12)]
    if any(f is None for f in figs):
        print("  cats: empty cell, skipped")
        return
    s = 36.0 / max(f.height for f in figs)
    for k, col in enumerate(["grey", "orange", "black"]):
        fr = [scaled(f, s) for f in figs[k * 4:(k + 1) * 4]]
        img, w, h = steady_strip(fr)
        write(manifest, "wildlife/cat_" + col, "idle", img, w, h, len(fr))
    print("  cats: 3 x 4 poses")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Re-slice the Prompts 12B hero sheets (Coldy, Big Jim, Pip-Pip the penguin
king, Nova the penguin wizard) with steady frames.

The first slicer (slice_world._grid12) scaled every cell to 96 px on its own
and centred it on its bounding box, so a flapping scarf or a raised wand
shrank the body and slid it sideways: walk/run cycles pulsed and jittered.
It also gave the penguins a "walk" that mixed four side steps with front
views (the penguin turned to face you mid-stride).

Here every cell of a sheet uses ONE scale (idle_down's tallest frame = 96 px,
as before), cells keep only their own figure (no neighbour slivers), and each
frame is centred on its torso (the columns where the figure is tallest), so
the body stays put while scarves and wands move around it. Feet stay on the
bottom line. Files are removed before they are written (art/ is hardlinked).

    python3 tools/reslice_hero12.py [coldy big_jim penguin_king penguin_wizard]
Run after slice_world.py (it replaces those strips) and before art_audit.py."""
import json, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
import slice_world as W  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "gen")

# Per-character fixes on top of slice_world.GRID12 (cell ranges in row 0).
OVERRIDES = {
    # Cells 7-10 are the four side steps; 11-14 are front/three-quarter steps.
    "penguin_king": {0: [("idle", 7, 9), ("walk", 7, 11)]},
    "penguin_wizard": {0: [("idle", 7, 9), ("walk", 7, 11), ("walk_down", 12, 15)]},
}
# Single-frame views cut from the grid when the sheet's own view row is missing.
VIEWS_FROM_CELLS = {"penguin_king": {"view_front": 0, "view_back": 3, "view_right": 7},
                    # The wizard's own view row is the older w242 design (green hat).
                    "penguin_wizard": {"view_front": 0, "view_back": 3, "view_right": 7}}
# Only the movement strips are re-cut: the action rows (attack, tools, ride,
# swim) overlap their neighbours too much for per-figure cuts and keep the
# first slicer's cells.
MOVE = {"idle", "idle_down", "idle_up", "walk", "walk_down", "walk_up", "run"}


def _figure(rgba, box):
    """The cell's own figure: the components that mostly sit inside the box,
    searched in a widened window so a scarf cut by an even split comes back."""
    H, Wd = rgba.shape[:2]
    x0, y0, x1, y1 = box
    pad = int((x1 - x0) * 0.35)
    wx0, wx1 = max(0, x0 - pad), min(Wd, x1 + pad)
    win = rgba[y0:y1, wx0:wx1]
    a = win[..., 3] > 0
    lab, n = ndimage.label(ndimage.binary_dilation(a, iterations=1))
    lab = lab * a
    keep = np.zeros_like(a)
    if n:
        bx0, bx1 = x0 - wx0, x1 - wx0
        sizes = ndimage.sum(a, lab, np.arange(1, n + 1))
        big = float(max(sizes)) if len(sizes) else 1.0
        for i in range(1, n + 1):
            m = lab == i
            tot = m.sum()
            if tot < 12:
                continue
            # Shadows / crowns of the rows above and below poke into the band
            # at its top or bottom edge: small pieces touching an edge go.
            rows = np.nonzero(m.any(1))[0]
            if (rows.min() <= 1 or rows.max() >= m.shape[0] - 2) and tot < 0.15 * big:
                continue
            inside = m[:, bx0:bx1].sum()
            if inside / float(tot) >= 0.6:
                keep |= m
        # A component that also grabbed the neighbour: fall back to the box.
        cols = np.nonzero(keep.any(0))[0]
        if len(cols) and (cols.max() - cols.min()) > 1.5 * (x1 - x0):
            keep = np.zeros_like(a)
            keep[:, bx0:bx1] = a[:, bx0:bx1]
    if not keep.any():
        keep = np.zeros_like(a)
        keep[:, x0 - wx0:x1 - wx0] = a[:, x0 - wx0:x1 - wx0]
    out = win.copy()
    out[..., 3] = np.where(keep, win[..., 3], 0)
    ys, xs = np.nonzero(out[..., 3] > 0)
    if len(ys) == 0:
        return None
    return Image.fromarray(out[ys.min():ys.max() + 1, xs.min():xs.max() + 1].astype(np.uint8))


def torso_x(img):
    a = np.array(img)[..., 3] > 40
    col = a.sum(0)
    if col.max() == 0:
        return img.width / 2.0
    cols = np.nonzero(col >= col.max() * 0.6)[0]
    return (cols.min() + cols.max() + 1) / 2.0


def steady_strip(frames, flip=False):
    """Bottom-anchored strip, every frame centred on its torso."""
    if flip:
        frames = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in frames]
    anchors = [torso_x(f) for f in frames]
    half = max(max(ax, f.width - ax) for f, ax in zip(frames, anchors))
    cw = int(np.ceil(half)) * 2
    ch = max(f.height for f in frames)
    out = Image.new("RGBA", (cw * len(frames), ch), (0, 0, 0, 0))
    for i, (f, ax) in enumerate(zip(frames, anchors)):
        out.alpha_composite(f, (i * cw + int(round(cw / 2.0 - ax)), ch - f.height))
    return out, cw, ch


def write(manifest, group, name, img, cw, ch, n):
    d = os.path.join(OUT, group)
    os.makedirs(d, exist_ok=True)
    path = os.path.join(d, name + ".png")
    if os.path.exists(path):
        os.remove(path)  # hardlinked art: never write in place
    img.save(path)
    manifest.setdefault(group, {})[name] = {"file": "%s/%s.png" % (group, name), "w": img.width, "h": img.height,
                                            "cell_w": cw, "cell_h": ch, "frames": n}


def scaled(img, s):
    return img.resize((max(1, int(round(img.width * s))), max(1, int(round(img.height * s)))), Image.LANCZOS)


def reslice(file, manifest):
    cid, spec = W.GRID12[file]
    spec = {r: list(v) for r, v in spec.items()}
    for r, names in OVERRIDES.get(cid, {}).items():
        over = {n for n, _, _ in names}
        spec[r] = [x for x in spec[r] if x[0] not in over] + names
    rgba = W.load_hue(file)
    H, Wd = rgba.shape[:2]
    ch = H / 7.0
    r0 = W._band_blobs(rgba, 2, int(ch) - 2)
    pitch = (r0[-1][0] - r0[0][0]) / float(max(1, len(r0) - 1)) if len(r0) > 1 else 96.0
    rows = {}
    spec = {r: [x for x in names if x[0] in MOVE] for r, names in spec.items()}
    spec = {r: names for r, names in spec.items() if names}
    for r in spec:
        by0, by1 = int(r * ch) + 2, int((r + 1) * ch) - (42 if r == 5 else 2)
        cells = []
        for b in W._band_blobs(rgba, by0, by1):
            b = (b[0], max(b[1], by0), b[2], min(b[3], by1))
            cells.extend(W._split_blob(b, max(1, int(round((b[2] - b[0]) / pitch)))))
        rows[r] = cells
    figs = {r: [_figure(rgba, b) for b in cells] for r, cells in rows.items()}
    ref = [f.height for f in figs[0][0:3] if f is not None]
    s = 96.0 / max(ref)
    G = "characters/" + cid
    for r, names in spec.items():
        for name, c0, c1 in names:
            part = [f for f in figs[r][c0:c1] if f is not None]
            if not part:
                continue
            img, cw, chh = steady_strip([scaled(f, s) for f in part])
            write(manifest, G, name, img, cw, chh, len(part))
    for view, c in VIEWS_FROM_CELLS.get(cid, {}).items():
        f = figs[0][c]
        if f is None:
            continue
        img, cw, chh = steady_strip([scaled(f, s)])
        write(manifest, G, view, img, cw, chh, 1)
        if view == "view_right":
            img, cw, chh = steady_strip([scaled(f, s)], flip=True)
            write(manifest, G, "view_left", img, cw, chh, 1)
    print("  %s: scale %.3f" % (cid, s))


if __name__ == "__main__":
    want = sys.argv[1:]
    mpath = os.path.join(OUT, "manifest.json")
    manifest = json.load(open(mpath))
    for file, (cid, _) in W.GRID12.items():
        if want and cid not in want:
            continue
        reslice(file, manifest)
    os.remove(mpath)
    with open(mpath, "w") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)

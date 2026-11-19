#!/usr/bin/env python3
"""Steady animal strips: re-centre every frame of a strip on the animal's body
so walk/idle/eat cycles stop sliding sideways (the slicers centred frames on
their bounding boxes, so a swinging tail or a lowered head shifted the body).

The anchor is the middle of the body barrel: the columns that are most filled
in the band between 35% and 75% of the frame's height (the trunk, not the
head, tail or legs). Frames keep their feet line; the cell grows if a frame
needs more room. Only strips whose body drifts more than 2 px are rewritten,
and files are removed before they are written (art/ is hardlinked).

    python3 tools/align_strips.py [--dry] [group ...]
Default groups: every animals/* and wildlife/* entry (idle, walk, run, eat, baby)."""
import json, os, sys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "gen")
ANIMS = {"idle", "walk", "run", "eat", "baby", "sit", "sleep"}
# Strips whose motion is the point (a leaping fish, a soaring eagle, wings,
# a drifting jelly) or that are unusable cuts (replaced in code by FarmAnimal.BABY_OF).
SKIP = {"wildlife/fish_jump", "wildlife/eagle", "wildlife/butterfly", "wildlife/jelly", "wildlife/hawk",
        "animals/chick", "animals/kid_goat", "animals/piglet", "animals/duck_water", "animals/bee_swarm"}


def body_x(fr):
    a = np.array(fr)[..., 3] > 40
    ys = np.nonzero(a.any(1))[0]
    if len(ys) == 0:
        return None
    top, bot = ys.min(), ys.max() + 1
    h = bot - top
    band = a[top + int(h * 0.35):top + max(int(h * 0.75), int(h * 0.35) + 1)]
    col = band.sum(0)
    if col.max() == 0:
        return None
    cols = np.nonzero(col >= col.max() * 0.5)[0]
    return (cols.min() + cols.max() + 1) / 2.0


def frames_of(img, n, cw):
    return [img.crop((i * cw, 0, (i + 1) * cw, img.height)) for i in range(n)]


def mean_rgb(fr):
    arr = np.array(fr).astype(np.float32)
    a = arr[..., 3] > 128
    return arr[..., :3][a].mean(0) if a.any() else np.zeros(3)


def clean(fr):
    """Drop neighbour slivers: small pieces touching the cell's left/right edge."""
    from scipy import ndimage
    arr = np.array(fr)
    a = arr[..., 3] > 0
    lab, n = ndimage.label(a, structure=np.ones((3, 3)))
    if n < 2:
        return fr, int(a.sum()), False
    sizes = ndimage.sum(a, lab, np.arange(1, n + 1))
    big = float(max(sizes))
    hit = False
    main = lab == (int(np.argmax(sizes)) + 1)
    mc = np.nonzero(main.any(0))[0]
    for i in range(1, n + 1):
        m = lab == i
        cols = np.nonzero(m.any(0))[0]
        edge = cols.min() <= 1 or cols.max() >= a.shape[1] - 2
        beside = cols.min() > mc.max() or cols.max() < mc.min()  # wholly left/right of the body
        if (edge and sizes[i - 1] < 0.1 * big) or (beside and sizes[i - 1] < 0.03 * big):
            arr[..., 3][m] = 0
            hit = True
    return Image.fromarray(arr), int((arr[..., 3] > 0).sum()), hit


def align(entry, dry):
    path = os.path.join(OUT, entry["file"])
    img = Image.open(path).convert("RGBA")
    n, cw, ch = int(entry["frames"]), int(entry["cell_w"]), int(entry["cell_h"])
    frs, areas, hits = [], [], False
    for f in frames_of(img, n, cw):
        f2, ar, hit = clean(f)
        frs.append(f2); areas.append(ar); hits = hits or hit
    # A frame that is only a scrap of the next animal on the sheet, or that
    # holds a different animal (another coat colour), goes.
    med = float(np.median(areas))
    cols = [mean_rgb(f) for f in frs]
    mcol = np.median(np.array(cols), axis=0)
    keep = [i for i, ar in enumerate(areas) if ar >= 0.4 * med and np.abs(cols[i] - mcol).sum() < 90]
    dropped = len(keep) < len(frs)
    frs = [frs[i] for i in keep]
    n = len(frs)
    xs = [body_x(f) for f in frs]
    if any(x is None for x in xs):
        return None
    drift = max(xs) - min(xs)
    if drift <= 2.0 and not hits and not dropped:
        return None
    # Tight crops, then place each so its body sits on the cell's centre line.
    tight = []
    for f, x in zip(frs, xs):
        bb = f.getbbox()
        tight.append((f.crop(bb), x - bb[0], bb[3]))
    half = max(max(ax, t.width - ax) for t, ax, _ in tight)
    ncw = max(cw, int(np.ceil(half)) * 2 + 4)  # 2 px air: re-runs never mistake a tail tip for a sliver
    out = Image.new("RGBA", (ncw * n, ch), (0, 0, 0, 0))
    for i, (t, ax, b) in enumerate(tight):
        out.alpha_composite(t, (i * ncw + int(round(ncw / 2.0 - ax)), b - t.height))
    if not dry:
        os.remove(path)
        out.save(path)
        entry.update({"w": out.width, "h": out.height, "cell_w": ncw, "frames": n})
    return drift


def main():
    dry = "--dry" in sys.argv
    groups = [a for a in sys.argv[1:] if not a.startswith("--")]
    mpath = os.path.join(OUT, "manifest.json")
    m = json.load(open(mpath))
    changed = 0
    for g in sorted(m):
        if groups and g not in groups:
            continue
        if not groups and g in SKIP:
            continue
        if not groups and not (g.startswith("animals/") or g.startswith("wildlife/")):
            continue
        for name, e in sorted(m[g].items()):
            if name not in ANIMS or not isinstance(e, dict) or int(e.get("frames", 1)) < 2:
                continue
            d = align(e, dry)
            if d is not None:
                changed += 1
                print("  %s/%s: body drift %.0f px %s" % (g, name, d, "(dry)" if dry else "-> 0"))
    if not dry and changed:
        os.remove(mpath)
        with open(mpath, "w") as f:
            json.dump(m, f, indent=1, sort_keys=True)
    print("aligned %d strips" % changed)


if __name__ == "__main__":
    main()

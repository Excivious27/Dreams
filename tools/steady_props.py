#!/usr/bin/env python3
"""Stop animated props from "breathing": the slicer fitted every frame of a
prop strip into the same cell on its own, so a frame with a tall steam puff,
glow beam or spark shrank the whole object (warp pads, teleporters, the coffee
pot, cauldrons...). Here each frame is rescaled so the object's base (the
widest row in the bottom 30% of the frame) matches the widest base in the
strip, then the strip is rebuilt bottom-anchored and centred on that base.

Effects that are meant to grow (fires, sprays, pops, the lift) are left
alone. Files are removed before they are written (art/ is hardlinked).

    python3 tools/steady_props.py [--dry] [group/name ...]"""
import json, os, sys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "gen")
STRIPS = ["props/warp_pad", "props/teleporter2", "props/holo_table", "props/hot_spring", "props/enchant_table",
          "props/sewer_rat", "furniture/coffee_pot", "furniture/kettle", "furniture/anvil2", "furniture/crystal_ball",
          "stations/cauldron_1", "stations/cauldron_2", "stations/stove_1", "stations/stove_2"]


def base(fr, band=None):
    """(width, x0, x1) of the object's foot: the median row span over the
    bottom 25% of the frame, ignoring specks and slivers beside the object."""
    from scipy import ndimage
    a = np.array(fr)[..., 3] > 40
    lab, n = ndimage.label(a, structure=np.ones((3, 3)))
    if n == 0:
        return None
    sizes = ndimage.sum(a, lab, np.arange(1, n + 1))
    a = np.isin(lab, [i + 1 for i in range(n) if sizes[i] >= 0.03 * max(sizes)])
    ys = np.nonzero(a.any(1))[0]
    top, bot = ys.min(), ys.max() + 1
    spans = []
    for y in range(bot - (band or max(1, int((bot - top) * 0.25))), bot):
        xs = np.nonzero(a[y])[0]
        if len(xs):
            spans.append((xs.max() - xs.min() + 1, xs.min(), xs.max() + 1))
    if not spans:
        return None
    w = float(np.median([sp[0] for sp in spans]))
    c = float(np.median([(sp[1] + sp[2]) / 2.0 for sp in spans]))
    return (w, c - w / 2.0, c + w / 2.0)


def steady(group, name, m, dry):
    e = m.get(group, {}).get(name)
    if not isinstance(e, dict) or int(e.get("frames", 1)) < 2:
        return None
    path = os.path.join(OUT, e["file"])
    img = Image.open(path).convert("RGBA")
    n, cw, ch = int(e["frames"]), int(e["cell_w"]), int(e["cell_h"])
    frs = [img.crop((i * cw, 0, (i + 1) * cw, ch)) for i in range(n)]
    bs = [base(f) for f in frs]
    if any(b is None or b[0] == 0 for b in bs):
        return None
    ref = max(b[0] for b in bs)
    spread = (ref - min(b[0] for b in bs)) / float(ref)
    if spread < 0.06:
        return None
    placed = []
    for f, b in zip(frs, bs):
        k = ref / float(b[0])
        bb = f.getbbox()
        t = f.crop(bb)
        cx = ((b[1] + b[2]) / 2.0 - bb[0]) * k
        if abs(k - 1.0) > 0.01:
            t = t.resize((max(1, int(round(t.width * k))), max(1, int(round(t.height * k)))), Image.LANCZOS)
        placed.append((t, cx))
    half = max(max(cx, t.width - cx) for t, cx in placed)
    ncw = int(np.ceil(half)) * 2 + 2
    nch = max(t.height for t, _ in placed)
    out = Image.new("RGBA", (ncw * n, nch), (0, 0, 0, 0))
    for i, (t, cx) in enumerate(placed):
        out.alpha_composite(t, (i * ncw + int(round(ncw / 2.0 - cx)), nch - t.height))
    if not dry:
        os.remove(path)
        out.save(path)
        e.update({"w": out.width, "h": out.height, "cell_w": ncw, "cell_h": nch})
    return spread


def main():
    dry = "--dry" in sys.argv
    want = [a for a in sys.argv[1:] if not a.startswith("--")] or STRIPS
    mpath = os.path.join(OUT, "manifest.json")
    m = json.load(open(mpath))
    done = 0
    for gn in want:
        g, n = gn.rsplit("/", 1)
        s = steady(g, n, m, dry)
        if s is not None:
            done += 1
            print("  %s: base size swung %.0f%% -> steady%s" % (gn, s * 100, " (dry)" if dry else ""))
    if done and not dry:
        os.remove(mpath)
        with open(mpath, "w") as f:
            json.dump(m, f, indent=1, sort_keys=True)
    print("steadied %d strips" % done)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Art consistency audit: for every character strip, per-frame bounding boxes.
Flags frames whose height, width or feet line differ a lot from the strip's
median (a cell that caught a neighbour, an effect, or a wrong split), strips
with a single frame where the name implies motion, and characters whose idle
and walk heights disagree (scale mismatch). Edge-blob scan (C5): a figure
touching the top of its cell (cut off by the slice) and detached bits on a
cell's left/right edge (a neighbour bleeding in) are reported. Prints a report;
--fix normalises the feet line of every frame to the strip's median (shifts
frames vertically); with --bleed too it also clears the bleeding edge bits
(review first: a detached tool head can touch a cell edge)."""
import json, os, sys, glob
import numpy as np
from PIL import Image
from scipy import ndimage


def edge_blobs(cell):
    """(cut_top, bleed_mask) for one cell's alpha mask: cut_top when the main
    figure runs along the top row (a slice that cut the head off); bleed_mask
    marks detached islands under 15% of the main piece that touch the cell's
    left or right edge (the next figure's sliver)."""
    lab, n = ndimage.label(cell, structure=np.ones((3, 3)))
    bleed = np.zeros_like(cell)
    if n == 0:
        return False, bleed
    sz = ndimage.sum(cell, lab, range(1, n + 1))
    big = int(np.argmax(sz)) + 1
    # Every strip is cropped to its tallest frame, so a head touching the top
    # row is normal; a slice cut leaves a flat, wide edge (row 0 about as wide
    # as row 2 and a good share of the figure's width).
    fig = lab == big
    xs = np.nonzero(fig.any(axis=0))[0]
    fw = (xs.max() - xs.min() + 1) if len(xs) else 1
    r0, r2 = fig[0].sum(), fig[min(2, fig.shape[0] - 1)].sum()
    cut = r0 >= max(6, 0.4 * fw) and r0 >= 0.75 * r2
    w = cell.shape[1]
    for i, sl in enumerate(ndimage.find_objects(lab)):
        if i + 1 == big or sl is None:
            continue
        # A neighbour's sliver: a narrow, tall-ish piece standing on the side
        # edge (sparkles, rain, notes and shiver lines are small or not on the edge).
        bw, bh = sl[1].stop - sl[1].start, sl[0].stop - sl[0].start
        if sz[i] < 0.15 * sz[big - 1] and (sl[1].start <= 1 or sl[1].stop >= w - 1) and bw <= 0.25 * w and bh >= 0.2 * cell.shape[0]:
            bleed |= lab == i + 1
    return bool(cut), bleed

MOTION = {"walk", "run", "swim", "ride", "attack", "powerup", "hoe_down", "axe_down", "pickaxe_down", "water_down", "cast_right", "walk_up", "walk_down", "dive", "surface", "swim_fast"}
m = json.load(open("art/gen/manifest.json"))
fix = "--fix" in sys.argv
clear_bleed = "--bleed" in sys.argv
only = [a for a in sys.argv[1:] if not a.startswith("--")]
issues = []
changed = False
# Frames known to be wrong on the source sheets (a portrait, a fishing line, a
# neighbour) — dropped by --fix after every re-slice.
KNOWN_DROPS = {("bo", "celebrate"): [0], ("marisol", "axe_down"): [0], ("nia", "reel_right"): [0, 1], ("ollie", "hoe_up"): [2],
               ("nia", "pickaxe_up"): [0]}

def frames_of(key, name):
    info = m.get(key, {}).get(name)
    f = "art/gen/%s/%s.png" % (key, name)
    if not isinstance(info, dict) or "frames" not in info or not os.path.exists(f):
        return None, None, None
    im = Image.open(f).convert("RGBA")
    n = int(info["frames"]); cw = int(info["cell_w"]); ch = int(info["cell_h"])
    return im, n, (cw, ch)

for key in sorted(k for k in m if k.startswith("characters/")):
    cid = key.split("/", 1)[1]
    if only and cid not in only:
        continue
    heights = {}
    for name in sorted(m[key]):
        im, n, dims = frames_of(key, name)
        if im is None:
            continue
        cw, ch = dims
        a = np.array(im)[..., 3] > 30
        boxes = []
        bleeds = {}
        for i in range(n):
            cut, bl = edge_blobs(a[:, i * cw:(i + 1) * cw])
            if cut and name not in ("umbrella", "fish"):  # umbrella tops / rods may reach the edge
                issues.append((cid, name, "frame %d cut off at the top" % i))
            if bl.any():
                issues.append((cid, name, "frame %d neighbour bleed (%d px)" % (i, int(bl.sum()))))
                if clear_bleed:
                    bleeds[i] = bl
                    a[:, i * cw:(i + 1) * cw] &= ~bl
        for i in range(n):
            cell = a[:, i * cw:(i + 1) * cw]
            ys, xs = np.where(cell)
            if len(ys) == 0:
                boxes.append(None); continue
            boxes.append((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
        good = [b for b in boxes if b]
        if not good:
            issues.append((cid, name, "empty strip")); continue
        hs = np.array([b[3] - b[1] for b in good]); ws = np.array([b[2] - b[0] for b in good]); feet = np.array([b[3] for b in good])
        mh, mw, mf = np.median(hs), np.median(ws), np.median(feet)
        heights[name] = mh
        for i, b in enumerate(boxes):
            if b is None:
                issues.append((cid, name, "frame %d empty" % i)); continue
            h, w, ft = b[3] - b[1], b[2] - b[0], b[3]
            if abs(h - mh) > 0.35 * mh or abs(w - mw) > 0.6 * mw:
                issues.append((cid, name, "frame %d size %dx%d vs median %dx%d" % (i, w, h, mw, mh)))
            if abs(ft - mf) > 0.15 * ch:
                issues.append((cid, name, "frame %d feet y %d vs median %d" % (i, ft, mf)))
        if n == 1 and name in MOTION:
            issues.append((cid, name, "single frame"))
        if fix:
            # Drop empty frames and tiny fragments (a stray sparkle caught as a
            # frame), then shift each frame so its feet sit on the strip's median.
            drop = KNOWN_DROPS.get((cid, name), [])
            keep = [i for i, b in enumerate(boxes) if i not in drop and b and (b[3] - b[1]) >= 0.3 * mh and (b[2] - b[0]) >= 0.2 * mw]
            if not keep:
                continue
            out = Image.new("RGBA", (cw * len(keep), ch), (0, 0, 0, 0))
            for j, i in enumerate(keep):
                b = boxes[i]
                cell = im.crop((i * cw, 0, (i + 1) * cw, ch))
                if i in bleeds:
                    ca = np.array(cell)
                    ca[bleeds[i]] = 0
                    cell = Image.fromarray(ca)
                dy = max(-b[1], int(mf - b[3]))
                out.paste(cell, (j * cw, dy), cell)
            _p = "art/gen/%s/%s.png" % (key, name)
            os.remove(_p)  # art/ is hardlinked across worktrees: never save in place
            out.save(_p)
            if len(keep) != n:
                m[key][name]["frames"] = len(keep); m[key][name]["w"] = cw * len(keep)
                changed = True
    if "idle" in heights and "walk" in heights and abs(heights["idle"] - heights["walk"]) > 0.2 * heights["idle"]:
        issues.append((cid, "idle/walk", "height mismatch %d vs %d" % (heights["idle"], heights["walk"])))
by = {}
for cid, name, what in issues:
    by.setdefault(cid, []).append((name, what))
for cid in sorted(by):
    print(cid, len(by[cid]))
    for name, what in by[cid][:12]:
        print("   ", name, "-", what)
print("TOTAL", len(issues), "issues in", len(by), "characters")
# Item icons: clear small detached bits (< 8% of the main piece) touching the icon's edge (a neighbour's sliver,
# the cut-off rest of a rarity gem). KEEP_BITS: icons where such a bit is part of the picture (kept in step with slice_world.KEEP_BITS).
KEEP_BITS = {"coffee", "cream_soda", "golden_float", "echo_leek", "singing_pear", "light_mote2", "star_dust2", "wishfruit_cake",
             "dream_orchid", "dreamflower", "ethereal_corn", "hush_carrot", "halo", "flameberry", "star_dust"}
if fix and not only:
    from scipy import ndimage
    n_bits = 0
    for p in sorted(glob.glob("art/gen/items/*.png")):
        nm = os.path.basename(p)[:-4]
        if nm in KEEP_BITS or m.get("items", {}).get(nm, {}).get("frames"):
            continue
        im = np.array(Image.open(p).convert("RGBA"))
        a = im[..., 3] > 40
        lab, n = ndimage.label(a, structure=np.ones((3, 3)))
        if n < 2:
            continue
        sz = ndimage.sum(a, lab, range(1, n + 1))
        h, w = a.shape
        drop = [i + 1 for i, sl in enumerate(ndimage.find_objects(lab)) if (sz[i] < 0.08 * sz.max() and (sl[1].start <= 2 or sl[0].start <= 2 or sl[1].stop >= w - 2))
                or (sz[i] < 0.35 * sz.max() and (sl[1].start <= 1 or sl[1].stop >= w - 1) and (sl[1].stop - sl[1].start) <= 0.35 * w)]  # a narrow piece on the left/right edge = the next icon's sliver
        if drop:
            im[np.isin(lab, drop), 3] = 0
            os.remove(p)  # hardlinked: never save in place
            Image.fromarray(im).save(p)
            n_bits += 1
    print("item icons: stray edge bits cleared on", n_bits)
if fix and changed:
    _d = json.dumps(m, indent=1, sort_keys=True)
    os.remove("art/gen/manifest.json")  # hardlinked: never write in place
    open("art/gen/manifest.json", "w").write(_d)
    print("manifest updated")

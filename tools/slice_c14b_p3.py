#!/usr/bin/env python3
"""C14b P3 animation-life art (art/incoming/c14b/c14bp3_*.png, magenta key):
  water_mill_parts -> buildings/c14bp3_water_mill_base (+ "hub": wheel axle in art px)
                      buildings/c14bp3_water_mill_wheel (spun in code by lake.gd)
  windmill_parts   -> props/c14bp3_windmill_body (+ "hub") and props/c14bp3_windmill_sails
                      (spun in code by farm.gd's Mill build)
  bonfire_strip    -> props/c14bp3_bonfire (6-frame loop, frames aligned on the stone ring)
rm-then-write (art files are hardlinked).   python3 tools/slice_c14b_p3.py [check]
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
import slice_comp as C
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAN = os.path.join(ROOT, "art", "gen", "manifest.json")
# (sheet, [(group, id)], base height in art px for the first piece; the second piece keeps the same factor)
PAIRS = [("c14b/c14bp3_water_mill_parts.png", [("buildings", "c14bp3_water_mill_base"), ("buildings", "c14bp3_water_mill_wheel")], 176),
         ("c14b/c14bp3_windmill_parts.png", [("props", "c14bp3_windmill_body"), ("props", "c14bp3_windmill_sails")], 92)]
BONFIRE = ("c14b/c14bp3_bonfire_strip.png", "props", "c14bp3_bonfire", 140)
IDS = [(g, i) for _, pr, _ in PAIRS for g, i in pr] + [(BONFIRE[1], BONFIRE[2])]


def _rm(group, nid):
    p = os.path.join(ROOT, "art", "gen", group, nid + ".png")
    if os.path.exists(p):
        os.remove(p)


def _hub(rgba, box):
    """The axle hub on a base piece: the centroid of the round metal/gold boss, found as the
    darkest-ringed blob nearest the piece's middle third (fallback: measured ratio)."""
    x0, y0, x1, y1 = box
    a = rgba[y0:y1, x0:x1].astype(np.int32)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    gold = (al > 200) & (r > 170) & (g > 120) & (g < 200) & (b < 90)
    h, w = gold.shape
    ys, xs = np.nonzero(gold[h // 4: h * 9 // 10, w // 4: w * 3 // 4])
    return xs, ys, (w, h)


def pair(src, ids, base_h, man):
    rgba, rows = C.sheet_rows(src, merge=10, min_area=4000)
    pieces = sorted([b for row in rows for b in row], key=lambda b: -(b[2] - b[0]) * (b[3] - b[1]))[:2]
    pieces.sort(key=lambda b: b[0])
    if len(pieces) != 2:
        sys.exit(f"slice_c14b_p3: {src}: found {len(pieces)} pieces")
    base, part = pieces
    f = base_h / float(base[3] - base[1])
    out = {}
    for (g, nid), bx in zip(ids, pieces):
        _rm(g, nid)
        S.save(C.piece(rgba, bx, factor=f), g, nid)
    return rgba, base, f


def main():
    man = json.load(open(MAN))
    if sys.argv[1:] == ["check"]:
        miss = [i for g, i in IDS if i not in man.get(g, {}) or not os.path.exists(os.path.join(ROOT, "art", "gen", g, i + ".png"))]
        print("slice_c14b_p3: missing", miss) if miss else None
        sys.exit(1 if miss else 0)
    hubs = {}
    # Hub positions measured on the renders (fraction of the base piece's box): the wheel
    # axle on the mill wall, the sail boss on the windmill cap.
    HUB_FRAC = {"c14bp3_water_mill_base": (0.5505, 0.655), "c14bp3_windmill_body": (0.526, 0.282)}
    for src, ids, bh in PAIRS:
        rgba, base, f = pair(src, ids, bh, man)
        nid = ids[0][1]
        w = round((base[2] - base[0]) * f)
        h = round((base[3] - base[1]) * f)
        fx, fy = HUB_FRAC[nid]
        hubs[(ids[0][0], nid)] = [round(w * fx), round(h * fy)]
    # Bonfire: 6 frames, aligned on the stone ring (bottom 40% of each frame) so logs never jump.
    src, g, nid, fh = BONFIRE
    rgba, rows = C.sheet_rows(src, merge=6, min_area=3000)
    row = max(rows, key=len)
    if len(row) != 6:
        sys.exit(f"slice_c14b_p3: bonfire: {len(row)} frames")
    hmax = max(b[3] - b[1] for b in row)
    f = fh / float(hmax)
    frames, centres = [], []
    for b in row:
        a = rgba[b[1]:b[3], b[0]:b[2]]
        hh = a.shape[0]
        ring = a[int(hh * 0.6):, :, 3] > 100
        xs = np.nonzero(ring.any(axis=0))[0]
        centres.append((xs[0] + xs[-1]) / 2.0 * f)
        frames.append(C.piece(rgba, b, factor=f))
    cw = int(max(fr.width for fr in frames) + 8)
    ch = max(fr.height for fr in frames)
    strip = Image.new("RGBA", (cw * 6, ch), (0, 0, 0, 0))
    for i, (fr, cx) in enumerate(zip(frames, centres)):
        strip.alpha_composite(fr, (int(round(i * cw + cw / 2.0 - cx)), ch - fr.height))
    _rm(g, nid)
    S.save(strip, g, nid)
    S.manifest[g][nid].update({"cell_w": cw, "cell_h": ch, "frames": 6})
    for gg, ii in IDS:
        man.setdefault(gg, {})[ii] = S.manifest[gg][ii]
    for (gg, ii), hp in hubs.items():
        man[gg][ii]["hub"] = hp
    os.remove(MAN)
    with open(MAN, "w") as fh_:
        json.dump(man, fh_, indent=1, sort_keys=True)
    print("slice_c14b_p3: %d pieces, hubs %s" % (len(IDS), hubs))


if __name__ == "__main__":
    main()

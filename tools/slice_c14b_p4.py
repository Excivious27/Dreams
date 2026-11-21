#!/usr/bin/env python3
"""C14b P4 art: `python3 tools/slice_c14b_p4.py` -> props/c14bp4_windmill_body + props/c14bp4_windmill_sails.

art/incoming/c14b/c14bp4_windmill_parts.png: a sail-less windmill tower (left) and a symmetric
sail cross (right) on magenta. The body is scaled to windmill3's height (104 px, 2x detail) and the
sails by the same factor; the manifest entry of the body carries "hub": [x, y] (pixels in the body
cell) where scripts/region_anim.gd pins the code-rotated sails (c14b_13-04, c14b_16-11).
Magenta key: only pixels close to #FF00FF are cut. Never writes an existing file in place (rm first).
"""
import json, os
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art", "incoming", "c14b", "c14bp4_windmill_parts.png")
GEN = os.path.join(ROOT, "art", "gen")
MAN = os.path.join(GEN, "manifest.json")
BODY_H = 104


def key(im):
    a = np.array(im.convert("RGBA")).astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mag = (r > 200) & (b > 200) & (g < 90) & (np.abs(r - b) < 60)
    a[..., 3] = np.where(mag, 0, 255)
    return a.astype(np.uint8)


def _manifest_insert(ent):
    """Text insert into the "props" group (the manifest is not round-trip safe through json.dump:
    a re-dump reorders other packages' entries). Our own old entries are dropped first."""
    src = open(MAN).read().split("\n")
    keep, skip = [], False
    for ln in src:
        if any(ln.startswith('  "%s": {' % k) for k in ent):
            skip = True
            continue
        if skip:
            if ln.startswith("  }"):
                skip = False
            continue
        keep.append(ln)
    i = keep.index(' "props": {')
    lines = []
    for k, v in ent.items():
        body = json.dumps(v, indent=1, sort_keys=True).split("\n")
        lines.append('  "%s": %s' % (k, body[0]))
        lines += ["  " + l for l in body[1:-1]]
        lines.append("  },")
    out = keep[: i + 1] + lines + keep[i + 1:]
    os.remove(MAN)  # never write in place
    with open(MAN, "w") as f:
        f.write("\n".join(out))
    json.load(open(MAN))


def main():
    a = key(Image.open(SRC))
    lab, n = ndimage.label(a[..., 3] > 0)
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    big = sorted(range(1, n + 1), key=lambda i: -sizes[i - 1])[:2]
    boxes = sorted([ndimage.find_objects((lab == i).astype(int))[0] for i in big], key=lambda s: s[1].start)
    body_sl, sail_sl = boxes
    # Keep everything inside each box (ivy specks are separate blobs but belong to the art).
    body = a[body_sl].copy()
    sails = a[sail_sl].copy()
    # Hub on the body: the round wooden cap = the brownest disc in the upper half.
    bh, bw = body.shape[:2]
    up = body[: bh // 2].astype(int)
    brown = (up[..., 0] > 120) & (up[..., 0] < 200) & (up[..., 1] > 70) & (up[..., 1] < 140) & (up[..., 2] < 90) & (up[..., 3] > 0)
    ys, xs = np.nonzero(brown)
    hub = (float(np.median(xs)), float(np.median(ys))) if len(xs) else (bw / 2.0, bh * 0.3)
    s = BODY_H / bh
    bimg = Image.fromarray(body).resize((max(1, round(bw * s)), BODY_H), Image.LANCZOS)
    simg = Image.fromarray(sails)
    side = max(simg.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(simg, ((side - simg.width) // 2, (side - simg.height) // 2))
    ss = max(2, round(side * s * 0.9)) // 2 * 2
    simg = sq.resize((ss, ss), Image.LANCZOS)
    out = {}
    for nm, im, extra in [("c14bp4_windmill_body", bimg, {"hub": [round(hub[0] * s, 1), round(hub[1] * s, 1)]}),
                          ("c14bp4_windmill_sails", simg, {})]:
        p = os.path.join(GEN, "props", nm + ".png")
        if os.path.exists(p):
            os.remove(p)  # hardlinked across worktrees: never write in place
        im.save(p)
        e = {"file": "props/%s.png" % nm, "w": im.width, "h": im.height, "cell_w": im.width, "cell_h": im.height, "frames": 1}
        e.update(extra)
        out[nm] = e
    _manifest_insert(out)
    print(json.dumps(out))


if __name__ == "__main__":
    main()

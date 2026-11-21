#!/usr/bin/env python3
"""C15 P4 slicer: winter (snow) twins of the gang city props from art/incoming/c15p4/.

Each render is one prop on flat magenta (or real alpha). The prop is keyed, cropped
to its largest blob (after a small dilation), scaled to fit the ORIGINAL prop's
canvas (art/gen/props/<name>.png) keeping its aspect, bottom-centred on that same
canvas, and written as art/gen/props/<name>_winter.png, so WorldGen.winter_look
picks it up in winter. Never edits an existing file in place: removes it first.
Appends manifest.json entries (props/<name>_winter)."""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INC = os.path.join(ROOT, "art", "incoming", "c15p4")
GEN = os.path.join(ROOT, "art", "gen")


def key(im):
    rgba = np.asarray(im.convert("RGBA"))
    if (rgba[..., 3] < 10).mean() > 0.3:
        return rgba.copy()
    a = np.asarray(im.convert("RGB")).astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mag = (r > 150) & (b > 150) & (g < 110) & (np.abs(r - b) < 90)
    soft = (r > 120) & (b > 120) & (g < 140) & ~mag
    alpha = np.where(mag, 0, 255).astype(np.uint8)
    alpha[soft] = 110
    rgb = a.astype(np.uint8)
    rgb[soft, 0] = np.minimum(rgb[soft, 0], rgb[soft, 1] + 40)
    rgb[soft, 2] = np.minimum(rgb[soft, 2], rgb[soft, 1] + 40)
    return np.dstack([rgb, alpha])


def crop_main(rgba):
    solid = rgba[..., 3] > 200
    lab, n = ndimage.label(ndimage.binary_dilation(solid, iterations=8))
    if n == 0:
        raise SystemExit("empty render")
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    keep = int(np.argmax(sizes)) + 1
    mask = lab == keep
    out = rgba.copy()
    out[~mask, 3] = 0
    ys, xs = np.where(out[..., 3] > 0)
    return out[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def main():
    man_p = os.path.join(GEN, "manifest.json")
    man = json.load(open(man_p))
    done = []
    only = set(sys.argv[1:])
    for f in sorted(os.listdir(INC)):
        if not f.endswith("_winter.png") or not f.startswith("c15p4_"):
            continue
        name = f[len("c15p4_"):-len("_winter.png")]
        if only and name not in only:
            continue
        src = os.path.join(GEN, "props", name + ".png")
        if not os.path.exists(src):
            print("skip (no original)", name)
            continue
        W, H = Image.open(src).size
        crop = crop_main(key(Image.open(os.path.join(INC, f))))
        h, w = crop.shape[:2]
        s = min(W / w, H / h)
        nw, nh = max(1, round(w * s)), max(1, round(h * s))
        im = Image.fromarray(crop).resize((nw, nh), Image.LANCZOS)
        canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        canvas.paste(im, ((W - nw) // 2, H - nh), im)
        out = os.path.join(GEN, "props", name + "_winter.png")
        if os.path.exists(out):
            os.remove(out)
        canvas.save(out)
        man.setdefault("props", {})[name + "_winter"] = {"file": "props/%s_winter.png" % name, "w": W, "h": H}
        done.append(name + "_winter")
    tmp = man_p + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(man, fh, indent=1)
        fh.write("\n")
    os.replace(tmp, man_p)
    print("c15p4 sliced %d: %s" % (len(done), " ".join(done)))


if __name__ == "__main__":
    main()

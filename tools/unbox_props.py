#!/usr/bin/env python3
"""Cut props out of the square backgrounds the slicer left them on.

  - BACKDROP: a flat backing (the sunflowers' grass tile, the bulbs' brown
    square) is flood-filled away from the frame's border wherever the colour
    stays close to the border's own colour; the new edge gets a 1 px feather.
  - SLIVERS: thin bars of sheet magenta at a frame's left/right edge (the
    neon signs) are cleared.
Works per frame on strips. Files are removed before they are written.

    python3 tools/unbox_props.py"""
import json, os
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "gen")
BACKDROP = {"nature/sunflowers": 46, "props/bulb_off": 30, "props/bulb_on": 30}
# Textured backings (a grass tile, a wall patch) that a colour flood can't
# separate: their square corners fade out in a soft oval instead.
VIGNETTE = ["nature/sunflowers", "props/bulb_off", "props/bulb_on"]
SLIVERS = ["props/neon_sign_%d" % i for i in range(8)]


def unbackdrop(fr, tol):
    arr = np.array(fr).astype(np.int32)
    a = arr[..., 3] > 0
    h, w = a.shape
    edge = np.zeros_like(a)
    edge[0, :] = edge[-1, :] = edge[:, 0] = edge[:, -1] = True
    ref = np.median(arr[..., :3][edge & a], axis=0) if (edge & a).any() else None
    if ref is None:
        return fr
    near = a & (np.abs(arr[..., :3] - ref).sum(-1) <= tol)
    lab, n = ndimage.label(near)
    touch = np.unique(lab[edge & near])
    bg = np.isin(lab, touch[touch > 0])
    out = arr.copy()
    out[..., 3][bg] = 0
    # Feather: pixels next to the cut get half alpha (no stair-stepped box edge).
    rim = ndimage.binary_dilation(bg) & ~bg & (out[..., 3] > 0)
    out[..., 3][rim] = (out[..., 3][rim] * 0.55).astype(np.int32)
    return Image.fromarray(out.astype(np.uint8))


def vignette(fr):
    arr = np.array(fr).astype(np.float32)
    h, w = arr.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt(((xx + 0.5 - w / 2.0) / (w / 2.0)) ** 2 + ((yy + 0.5 - h / 2.0) / (h / 2.0)) ** 2)
    t = np.clip((1.0 - d) / 0.28, 0.0, 1.0)
    k = t * t * (3 - 2 * t)  # smoothstep: full inside, soft to nothing at the rim
    arr[..., 3] *= k
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8))


def unsliver(fr):
    arr = np.array(fr).astype(np.int32)
    r, g, b, a = arr[..., 0], arr[..., 1], arr[..., 2], arr[..., 3]
    mag = (r > 170) & (b > 150) & (g < 90) & (a > 0)
    h, w = mag.shape
    for x in list(range(0, min(6, w))) + list(range(max(0, w - 6), w)):
        if mag[:, x].mean() > 0.5:
            arr[:, x, 3] = 0
    return Image.fromarray(arr.astype(np.uint8))


def rework(m, gname, fn):
    g, n = gname.rsplit("/", 1)
    e = m.get(g, {}).get(n)
    if not isinstance(e, dict):
        return False
    path = os.path.join(OUT, e["file"])
    img = Image.open(path).convert("RGBA")
    k = int(e.get("frames", 1))
    cw = int(e.get("cell_w", img.width))
    ch = int(e.get("cell_h", img.height))
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    for i in range(k):
        out.paste(fn(img.crop((i * cw, 0, (i + 1) * cw, ch))), (i * cw, 0))
    os.remove(path)
    out.save(path)
    return True


def main():
    m = json.load(open(os.path.join(OUT, "manifest.json")))
    for gname, tol in BACKDROP.items():
        if rework(m, gname, lambda f, t=tol: unbackdrop(f, t)):
            print("  %s: backdrop cut away" % gname)
    for gname in VIGNETTE:
        if rework(m, gname, vignette):
            print("  %s: square corners faded" % gname)
    for gname in SLIVERS:
        if rework(m, gname, unsliver):
            print("  %s: edge slivers cleared" % gname)


if __name__ == "__main__":
    main()

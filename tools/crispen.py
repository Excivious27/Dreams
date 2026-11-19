#!/usr/bin/env python3
"""Crispen a soft (LANCZOS-downscaled) sprite into clean pixel art, same size.

crispen(img): hard alpha (no half-transparent fringe), magenta spill on the rim
turned into the dark outline colour, a light unsharp mask, a small palette
(k-means-ish via PIL median cut on the opaque pixels) and an optional 1px dark
outline on the silhouette rim. The canvas size and footprint never change.
Used by tools/slice_r13_c2_p7.py; scored by tools/fuzz_audit.py.
"""
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage


def is_crisp(img, colors=48):
    a = np.asarray(img.convert("RGBA"))
    al = a[..., 3]
    if ((al > 0) & (al < 255)).any():
        return False
    op = a[al == 255][:, :3]
    return len(op) == 0 or len(np.unique(op.view(np.dtype((np.void, 3))))) <= colors * 2 + 2


def crispen(img, colors=24, outline=True, sharpen=80, alpha_cut=110):
    img = img.convert("RGBA")
    a = np.asarray(img).astype(np.int32)
    m = a[..., 3] >= alpha_cut
    m = ndimage.binary_opening(m, iterations=1) | (m & ndimage.binary_erosion(m, iterations=0 or 1))
    rgb = Image.fromarray(a[..., :3].astype(np.uint8))
    if sharpen:
        rgb = rgb.filter(ImageFilter.UnsharpMask(radius=1.0, percent=sharpen, threshold=2))
    c = np.asarray(rgb).astype(np.int32)
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    rim = m & ~ndimage.binary_erosion(m, iterations=1, border_value=0)
    spill = (np.minimum(r, b) - g > 35)
    # magenta-ish spill anywhere near the rim: neutralise it
    near = m & ~ndimage.binary_erosion(m, iterations=2, border_value=0)
    fix = near & spill
    c[..., 0] = np.where(fix, np.minimum(r, g + 25), r)
    c[..., 2] = np.where(fix, np.minimum(b, g + 25), b)
    # palette from the opaque pixels
    if m.any():
        op = c[m].astype(np.uint8)
        n = len(op)
        w = int(np.ceil(np.sqrt(n)))
        tile = np.zeros((w * w, 3), np.uint8)
        tile[:n] = op
        tile[n:] = op[0]
        pal_img = Image.fromarray(tile.reshape(w, w, 3)).quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        q = np.asarray(Image.fromarray(c.astype(np.uint8)).quantize(palette=pal_img, dither=Image.Dither.NONE).convert("RGB")).astype(np.int32)
        c = np.where(m[..., None], q, c)
    if outline:
        # darken the rim toward a deep version of its own colour (a clean 1px outline)
        dark = (c * 0.32 + np.array([10, 6, 16]) * 0.68 * 0.5).astype(np.int32)
        lum = c.sum(-1)
        c = np.where((rim & (lum > 150))[..., None], dark, c)
    out = np.zeros_like(a)
    out[..., :3] = np.clip(c, 0, 255)
    out[..., 3] = np.where(m, 255, 0)
    out[~m] = 0
    return Image.fromarray(out.astype(np.uint8))

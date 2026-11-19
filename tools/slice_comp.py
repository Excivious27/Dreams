#!/usr/bin/env python3
"""Component helpers for sheets made by the image tool (Prompts 17-30 renders).

The renders put pieces roughly, not exactly, where the prompt asked, so every
slicer here finds pieces as magenta-separated blobs and reads them as rows.
"""
import os, sys
import numpy as np
from scipy import ndimage
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
from slice_art import load, crop, scale_to, save, strip
from PIL import Image


def blobs(rgba, reg=None, merge=5, min_area=60, alpha=40):
    """Boxes (x0,y0,x1,y1) of pieces. Pixels closer than `merge` join one piece."""
    x0, y0 = (reg[0], reg[1]) if reg else (0, 0)
    a = rgba[reg[1]:reg[3], reg[0]:reg[2]] if reg else rgba
    m = a[..., 3] > alpha
    lab, n = ndimage.label(ndimage.binary_dilation(m, iterations=merge) if merge else m)
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        if sl is None:
            continue
        sub = m[sl] & (lab[sl] == i + 1)
        if sub.sum() < min_area:
            continue
        ys, xs = np.nonzero(sub)
        out.append((x0 + sl[1].start + xs.min(), y0 + sl[0].start + ys.min(),
                    x0 + sl[1].start + xs.max() + 1, y0 + sl[0].start + ys.max() + 1))
    return out


def rows_of(boxes, overlap=0.35):
    """Group boxes into rows (top to bottom), each sorted left to right."""
    rows = []
    for b in sorted(boxes, key=lambda b: (b[1] + b[3]) / 2):
        cy, h = (b[1] + b[3]) / 2, b[3] - b[1]
        for r in rows:
            ry0, ry1 = r["y0"], r["y1"]
            ov = min(b[3], ry1) - max(b[1], ry0)
            if ov > overlap * min(h, ry1 - ry0) or ry0 <= cy <= ry1 and h < 1.5 * (ry1 - ry0):
                r["b"].append(b); r["y0"] = min(ry0, b[1]); r["y1"] = max(ry1, b[3]); break
        else:
            rows.append({"b": [b], "y0": b[1], "y1": b[3]})
    rows.sort(key=lambda r: r["y0"])
    return [sorted(r["b"], key=lambda b: b[0]) for r in rows]


def sheet_rows(file, reg=None, merge=5, min_area=60, rgba=None):
    rgba = load(file) if rgba is None else rgba
    return rgba, rows_of(blobs(rgba, reg, merge, min_area))


def piece(rgba, b, factor=None, w=None, h=None, cover=False):
    im = crop(rgba, b)
    if factor:
        return scale_to(im, width=max(1, round(im.width * factor)), height=max(1, round(im.height * factor)))
    return scale_to(im, width=w, height=h, cover=cover)


def save_piece(rgba, b, group, name, **kw):
    return save(piece(rgba, b, **kw), group, name)


def save_strip(rgba, boxes, group, name, factor):
    if len(boxes) >= 3:
        mw = float(np.median([b[2] - b[0] for b in boxes]))
        fixed = []
        for b in boxes:
            if b[2] - b[0] > 1.6 * mw:  # two figures caught in one frame: keep the biggest
                parts = blobs(rgba, b, merge=1, min_area=50)
                if len(parts) > 1:
                    b = max(parts, key=lambda q: (q[2] - q[0]) * (q[3] - q[1]))
            fixed.append(b)
        boxes = fixed
    frames = [piece(rgba, b, factor=factor) for b in boxes]
    if frames:
        strip(frames, group, name)


def med_h(boxes):
    return float(np.median([b[3] - b[1] for b in boxes])) if boxes else 1.0


def split_wide(boxes, n):
    """When a row came out with fewer pieces than expected (touching frames),
    split the widest boxes evenly until there are n."""
    boxes = list(boxes)
    while len(boxes) < n and boxes:
        i = max(range(len(boxes)), key=lambda k: boxes[k][2] - boxes[k][0])
        b = boxes[i]
        w = b[2] - b[0]
        k = max(2, round(w / max(1, np.median([x[2] - x[0] for x in boxes]))))
        k = min(k, n - len(boxes) + 1)
        parts = [(b[0] + w * j // k, b[1], b[0] + w * (j + 1) // k, b[3]) for j in range(k)]
        boxes[i:i + 1] = parts
    return sorted(boxes, key=lambda b: b[0])


def tight(rgba, b):
    """Shrink a box to its opaque pixels."""
    a = rgba[b[1]:b[3], b[0]:b[2], 3] > 40
    if not a.any():
        return b
    ys, xs = np.nonzero(a)
    return (b[0] + xs.min(), b[1] + ys.min(), b[0] + xs.max() + 1, b[1] + ys.max() + 1)


def report(file, **kw):
    rgba, rows = sheet_rows(file, **kw)
    return [len(r) for r in rows], rows


def col_segments(rgba, box, min_gap=2, alpha=40):
    """Split a box at fully-empty columns."""
    a = rgba[box[1]:box[3], box[0]:box[2], 3] > alpha
    filled = a.any(axis=0)
    segs, start = [], None
    gap = 0
    for x, f in enumerate(filled):
        if f:
            if start is None: start = x
            gap = 0; end = x
        elif start is not None:
            gap += 1
            if gap >= min_gap:
                segs.append((start, end + 1)); start = None
    if start is not None:
        segs.append((start, end + 1))
    return [tight(rgba, (box[0] + s, box[1], box[0] + e, box[3])) for s, e in segs]


def row_n(rgba, row, n, min_gap=2):
    """Exactly n pieces from a row (list of boxes): split at empty columns, merge
    slivers, then even-split the widest if still short; drop the smallest extras."""
    x0 = min(b[0] for b in row); y0 = min(b[1] for b in row)
    x1 = max(b[2] for b in row); y1 = max(b[3] for b in row)
    segs = col_segments(rgba, (x0, y0, x1, y1), min_gap)
    medw = np.median([s[2] - s[0] for s in segs]) if segs else 1
    segs = [s for s in segs if (s[2] - s[0]) > 0.15 * medw or len(segs) <= n]
    if len(segs) < n:
        if len(segs) <= 1:
            w = (x1 - x0) / n
            segs = [tight(rgba, (int(x0 + i * w), y0, int(x0 + (i + 1) * w), y1)) for i in range(n)]
        else:
            segs = split_wide(segs, n)
    pitch = (x1 - x0) / n
    def even():
        return [tight(rgba, (int(x0 + i * pitch), y0, int(x0 + (i + 1) * pitch), y1)) for i in range(n)]
    while len(segs) > n:
        # merge the narrowest piece into its nearest neighbour
        i = min(range(len(segs)), key=lambda k: segs[k][2] - segs[k][0])
        j = i - 1 if i > 0 and (i == len(segs) - 1 or segs[i][0] - segs[i - 1][2] < segs[i + 1][0] - segs[i][2]) else i + 1
        a, b = segs[min(i, j)], segs[max(i, j)]
        segs[min(i, j):max(i, j) + 1] = [(a[0], min(a[1], b[1]), b[2], max(a[3], b[3]))]
    ws = [s_[2] - s_[0] for s_ in segs]
    if ws and (min(ws) < 0.4 * pitch or max(ws) > 1.7 * pitch):
        return even()
    return segs


def even_grid(rgba, box, cols, rows):
    """Cells of an even grid laid over box, each tightened."""
    x0, y0, x1, y1 = box
    w = (x1 - x0) / cols; h = (y1 - y0) / rows
    return [[tight(rgba, (int(x0 + c * w), int(y0 + r * h), int(x0 + (c + 1) * w), int(y0 + (r + 1) * h))) for c in range(cols)] for r in range(rows)]


def content_box(rgba, alpha=40):
    a = rgba[..., 3] > alpha
    ys, xs = np.nonzero(a)
    return (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)


def bands(rgba, n, alpha=40):
    """n horizontal bands of content, split at the n-1 widest empty gaps."""
    m = (rgba[..., 3] > alpha).any(axis=1)
    ys = np.where(m)[0]
    gaps = []
    for a, b in zip(ys[:-1], ys[1:]):
        if b - a > 1:
            gaps.append((b - a, a, b))
    cut = sorted(sorted(gaps, reverse=True)[:n - 1], key=lambda g: g[1])
    edges = [ys[0]] + [y for g in cut for y in (g[1] + 1, g[2])] + [ys[-1] + 1]
    out = []
    for i in range(0, len(edges), 2):
        y0, y1 = edges[i], edges[i + 1]
        xs = np.where((rgba[y0:y1, :, 3] > alpha).any(axis=0))[0]
        out.append([(xs.min(), y0, xs.max() + 1, y1)])
    return out

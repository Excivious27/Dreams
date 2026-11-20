#!/usr/bin/env python3
"""CONDUCT 3 (P5) art: the community farm's multi-day build progress pieces, and the
gangster-arc Whack-a-Snitch critters (whack_snitch step, art/gen/arcade, no manifest).

art/incoming/r13/c3_p5_build_progress.png (image tool edit of cf_site_lumber/stone):
four pieces left to right -> art/gen/props/cf_build_frame (half-built timber shed),
cf_build_well (half-stacked well + rope tripod), cf_build_greenhouse (iron frame,
a few panes), cf_build_sawhorse (sawhorse, toolbox, saw). Community farm shows them
from the second build day on (Commons.build_progress).
Run after the other slicers:  python3 tools/slice_r13_c3_p5.py
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
from slice_comp import blobs, rows_of
import numpy as np
from PIL import Image

NAMES = [("cf_build_frame", 96), ("cf_build_well", 80), ("cf_build_greenhouse", 96), ("cf_build_sawhorse", 64)]


def build_progress():
    p = os.path.join(S.INC, "r13/c3_p5_build_progress.png")
    if not os.path.exists(p):
        return
    a = np.asarray(Image.open(p).convert("RGBA")).astype(np.int32)
    a[a[..., 3] <= 40] = [0, 0, 0, 0]
    rgba = a.astype(np.uint8)
    rows = rows_of(blobs(rgba, merge=14, min_area=3000))
    pieces = max(rows, key=len)
    assert len(pieces) == 4, [len(r) for r in rows]
    for (name, width), b in zip(NAMES, pieces):
        im = Image.fromarray(rgba[b[1]:b[3], b[0]:b[2]])
        h = max(1, round(im.height * width / im.width))
        im = im.resize((width, h), Image.LANCZOS)
        q = np.asarray(im).copy()
        q[..., 3] = np.where(q[..., 3] > 150, 255, np.where(q[..., 3] > 30, 80, 0))
        out = os.path.join(S.OUT, "props", name + ".png")
        if os.path.exists(out):
            os.remove(out)
        S.save(Image.fromarray(q), "props", name)


def whack_snitch():
    """art/incoming/r13/c3_p5_whack_snitch.png -> art/gen/arcade/whack_snitch{,_gold,_helmet,_dizzy}
    (gangster-arc Whack-a-Snitch critters, same 120-wide hole framing as whack_grump)."""
    p = os.path.join(S.INC, "r13/c3_p5_whack_snitch.png")
    if not os.path.exists(p):
        return
    a = np.asarray(Image.open(p).convert("RGBA")).copy()
    mag = (a[..., 3] > 40) & (a[..., 0] > 200) & (a[..., 2] > 200) & (a[..., 1] < 80)
    a[mag] = 0
    a[a[..., 3] <= 40] = 0
    cols = (a[..., 3] > 40).sum(axis=0) > 0
    spans, x = [], 0
    while x < len(cols):
        if cols[x]:
            x0 = x
            while x < len(cols) and (cols[x:x + 12].any()):
                x += 1
            spans.append((x0, x))
        x += 1
    spans = [sp for sp in spans if sp[1] - sp[0] > 60]
    assert len(spans) == 4, spans
    for name, (x0, x1) in zip(["whack_snitch", "whack_snitch_gold", "whack_snitch_helmet", "whack_snitch_dizzy"], spans):
        sub = a[:, x0:x1]
        rows = np.where((sub[..., 3] > 40).any(axis=1))[0]
        im = Image.fromarray(sub[rows[0]:rows[-1] + 1])
        im = im.resize((120, max(1, round(im.height * 120 / im.width))), Image.LANCZOS)
        q = np.asarray(im).copy()
        q[..., 3] = np.where(q[..., 3] > 128, 255, 0)
        out = os.path.join(S.OUT, "arcade", name + ".png")
        if os.path.exists(out):
            os.remove(out)
        Image.fromarray(q).save(out)


STEPS = [build_progress, whack_snitch]

if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    for fn in STEPS:
        fn(); print("ok", fn.__name__)
    tmp = mpath + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(S.manifest, fh, indent=1, sort_keys=True)
    os.replace(tmp, mpath)

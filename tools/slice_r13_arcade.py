#!/usr/bin/env python3
"""Round 13 arcade art (art/incoming/r13_arcade/*) -> art/gen/arcade/.

Pieces are found as magenta-separated blobs and read as rows (slice_comp).
Saves plain PNGs only (no manifest entries: the arcade loads them with
Art.tex("arcade", name)). Never rewrites a file in place (art is hardlinked):
each output is removed first.
    python3 tools/slice_r13_arcade.py
"""
import os, sys
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
from slice_comp import blobs, rows_of, piece

SRC = "r13_arcade/"
OUT = os.path.join(S.OUT, "arcade")


def out(img, name):
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, name + ".png")
    if os.path.exists(p):
        os.remove(p)
    img.save(p)
    return p


def rows(file, n_expect=None, merge=6, min_area=400):
    rgba = S.load(SRC + file)
    rs = rows_of(blobs(rgba, merge=merge, min_area=min_area))
    rs = [r for r in rs if max(b[3] - b[1] for b in r) > 30]
    print(file, [len(r) for r in rs])
    if n_expect:
        assert [len(r) for r in rs] == n_expect, (file, [len(r) for r in rs])
    return rgba, rs


def bands(file):
    """Opaque panorama strips separated by magenta bars."""
    im = np.asarray(Image.open(os.path.join(S.INC, SRC + file)).convert("RGB")).astype(int)
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    mag = (np.minimum(r, b) - g > 120)
    rowmag = mag.mean(axis=1) > 0.6
    out_b, y = [], 0
    while y < len(rowmag):
        if not rowmag[y]:
            y0 = y
            while y < len(rowmag) and not rowmag[y]:
                y += 1
            if y - y0 > 60:
                out_b.append((y0, y))
        y += 1
    return im, mag, out_b


def band_imgs(file):
    im, mag, bs = bands(file)
    res = []
    for y0, y1 in bs:
        sub = mag[y0:y1]
        colmag = sub.mean(axis=0) > 0.6
        xs = np.nonzero(~colmag)[0]
        x0, x1 = xs.min(), xs.max() + 1
        # trim a few px so no magenta fringe survives
        crop = im[y0 + 3:y1 - 3, x0 + 3:x1 - 3].astype(np.uint8)
        res.append(Image.fromarray(crop, "RGB").convert("RGBA"))
    print(file, "bands", [(b.width, b.height) for b in res])
    return res


def seamless_x(img, blend=48):
    """Cross-fade the right edge into the left so the strip wraps."""
    a = np.asarray(img).astype(float)
    w = a.shape[1]
    out = a[:, :w - blend].copy()
    for i in range(blend):
        t = i / blend
        out[:, i] = a[:, i] * t + a[:, w - blend + i] * (1 - t)
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def backdrops():
    names = ["meadow", "canyon", "forest", "clouds", "gears", "garden", "night", "space", "cave"]
    imgs = band_imgs("jumper_bg_a.png") + band_imgs("jumper_bg_b.png") + band_imgs("jumper_bg_c.png")
    assert len(imgs) == 9, len(imgs)
    for n, im in zip(names, imgs):
        im = seamless_x(im)
        im = im.resize((round(im.width * 336 / im.height), 336), Image.LANCZOS)
        out(im, "bg_" + n)


def jumper_sprites():
    rgba, rs = rows("jumper_sprites.png", [5, 7, 4])
    for i, b in enumerate(rs[0]):
        out(piece(rgba, b, h=40), "hero_%d" % i)
    for i, b in enumerate(rs[1][:4]):
        out(piece(rgba, b, h=24), "coin_%d" % i)
    out(piece(rgba, rs[1][4], w=96), "spikes")
    out(piece(rgba, rs[1][5], h=64), "flag_red")
    out(piece(rgba, rs[1][6], h=64), "flag_green")
    out(piece(rgba, rs[2][0], h=128), "goal")
    out(piece(rgba, rs[2][1], h=24), "plank")
    out(piece(rgba, rs[2][2], h=24), "mover")
    out(piece(rgba, rs[2][3], h=48), "ceiling")


def ground():
    rgba, rs = rows("jumper_ground.png", [4, 4])
    k = 0
    for r in rs:
        for b in r:
            im = piece(rgba, b, w=64, h=64, cover=True)
            out(im, "ground_%d" % k)
            body = im.crop((0, 32, 64, 64))
            out(body, "ground_body_%d" % k)
            k += 1


def whack():
    rgba, rs = rows("whack_sprites.png", [4, 4], merge=14, min_area=3000)
    names = ["grump", "gold", "helmet", "bunny", "dizzy", "mallet", "hole", "bush"]
    for b, n in zip(rs[0] + rs[1], names):
        out(piece(rgba, b, w=120) if n != "mallet" else piece(rgba, b, h=90), "whack_" + n)


def claw_gallery():
    rgba, rs = rows("claw_gallery_sprites.png", [6, 4, 4], merge=6)
    looks = ["bear", "penguin", "star", "duck", "blob", "bunny"]
    for n, b in zip(looks, rs[0]):
        out(piece(rgba, b, h=56), "plush_" + n)
    out(piece(rgba, rs[1][0], h=84), "claw_open")
    out(piece(rgba, rs[1][1], h=84), "claw_closed")
    out(piece(rgba, rs[1][2], h=56), "capsule")
    out(piece(rgba, rs[1][3], w=96), "ticket_strip")
    for n, b in zip(["duck", "duck_gold", "frog", "popper"], rs[2]):
        out(piece(rgba, b, h=64) if n != "popper" else piece(rgba, b, w=110), "gallery_" + n)


def cabinets():
    rgba, rs = rows("cabinets.png", [5], merge=6)
    for n, b in zip(["jumper", "stack", "whack", "claw", "gallery"], rs[0]):
        out(piece(rgba, b, h=160), "cabinet_" + n)


def stages():
    im = np.asarray(Image.open(os.path.join(S.INC, SRC + "stage_backdrops.png")).convert("RGB")).astype(int)
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    mag = (np.minimum(r, b) - g > 120)
    colmag = mag.mean(axis=0) > 0.6
    rowmag = mag.mean(axis=1) > 0.6
    ys = np.nonzero(~rowmag)[0]
    panels, x = [], 0
    while x < len(colmag):
        if not colmag[x]:
            x0 = x
            while x < len(colmag) and not colmag[x]:
                x += 1
            if x - x0 > 100:
                panels.append((x0, x))
        x += 1
    assert len(panels) == 3, panels
    for n, (x0, x1) in zip(["lawn", "booth", "clawbox"], panels):
        sub = mag[:, x0:x1]
        yy = np.nonzero(sub.mean(axis=1) < 0.4)[0]
        crop = Image.fromarray(im[yy.min() + 3:yy.max() - 3, x0 + 3:x1 - 3].astype(np.uint8), "RGB").convert("RGBA")
        if n == "clawbox":
            crop = patch_claw(crop)
        out(crop.resize((540, round(540 * crop.height / crop.width)), Image.LANCZOS), "stage_" + n)


def patch_claw(img):
    """The render painted a claw on the back wall: rebuild that part of the padded
    wall from clean rows two tiles further down (same columns, so the grid lines up)."""
    a = np.asarray(img).copy()
    h, w = a.shape[:2]
    # Tile pitch from the wall's own rows (autocorrelation of a clean column band).
    band = a[int(h * 0.40):int(h * 0.64), int(w * 0.15):int(w * 0.40), :3].mean(axis=(1, 2))
    band = band - band.mean()
    best, pitch = -1e18, 0
    for lag in range(int(h * 0.08), int(h * 0.15)):
        v = float((band[:-lag] * band[lag:]).sum())
        if v > best:
            best, pitch = v, lag
    x0, x1 = int(w * 0.338), int(w * 0.905)
    d = 2 * pitch
    y0, ym, y1 = int(h * 0.082), int(h * 0.082) + d, int(h * 0.42)
    a[ym:y1, x0:x1] = a[ym + d:y1 + d, x0:x1]
    a[y0:ym, x0:x1] = a[y0 + d:ym + d, x0:x1]
    return Image.fromarray(a)


def cab_props():
    """Rec Center props for the cabinets a1's cabinet row didn't have (31x64 like
    props/arcade_cab_*). These two do go in the manifest (props are placed by name);
    the manifest is hardlinked, so it is rewritten as a new file."""
    import json
    mpath = os.path.join(S.OUT, "manifest.json")
    man = json.load(open(mpath))
    for n in ["whack", "gallery"]:
        im = Image.open(os.path.join(OUT, "cabinet_%s.png" % n)).convert("RGBA")
        im = S.scale_to(im, height=64)
        p = os.path.join(S.OUT, "props", "arcade_cab_%s.png" % n)
        if os.path.exists(p):
            os.remove(p)
        im.save(p)
        man.setdefault("props", {})["arcade_cab_" + n] = {"file": "props/arcade_cab_%s.png" % n, "w": im.width, "h": im.height}
    tmp = mpath + ".tmp"
    with open(tmp, "w") as f:
        json.dump(man, f, indent=1, sort_keys=True)
    os.remove(mpath)
    os.rename(tmp, mpath)


STEPS = [backdrops, jumper_sprites, ground, whack, claw_gallery, cabinets, stages, cab_props]

if __name__ == "__main__":
    only = sys.argv[1:]
    for fn in STEPS:
        if only and fn.__name__ not in only:
            continue
        fn()
        print("ok", fn.__name__)

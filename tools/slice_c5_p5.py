#!/usr/bin/env python3
"""CONDUCT 5 fix package P5 art steps (villagers, animals, fuzzy art).

    python3 tools/slice_c5_p5.py [step ...]

Steps:
  wren_jr   art/incoming/c5/p5_wren_jr_walk_b.png -> characters/npc_wren_jr_base
            (her new-design walker: idle/idle_side/idle_up + 3 walks x4)
  rekey     magenta key residue post-pass on wildlife walks and pet anims
            (drops r>150, g<110, b>120 pixels) -- c5_09 #4
  blobs     ward_*/hq_* buildings: keep the main blob, drop stray specks/beams,
            then hard alpha + outline (tools/crispen.py) -- c5_05 #1 #2
Every write removes the old file first (art/gen is hardlinked to the main repo).
"""
import os, sys, json, glob
import numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
import slice_comp as C


def _rm(group, name):
    p = os.path.join(S.OUT, group, name + ".png")
    if os.path.exists(p):
        os.remove(p)


def _write(img, path):
    """Replace a (possibly hardlinked) file: write a temp file, rm, move."""
    tmp = path + ".tmp.png"
    img.save(tmp)
    if os.path.exists(path):
        os.remove(path)
    os.replace(tmp, path)


def _load_keep_alpha(name):
    """A render with its own alpha (transparent background): keep it, and key
    any magenta too."""
    src = Image.open(os.path.join(S.INC, name)).convert("RGBA")
    k = np.asarray(S.key_magenta(src)).copy()
    k[..., 3] = np.minimum(k[..., 3], np.asarray(src)[..., 3])
    k[k[..., 3] <= 40] = 0
    return k


def wren_jr():
    rgba = _load_keep_alpha("c5/p5_wren_jr_walk_b.png")
    rgba, rows = C.sheet_rows(None, merge=4, min_area=400, rgba=rgba)
    rows = [r for r in rows if len(r) >= 3]
    assert len(rows) == 4 and len(rows[0]) == 3 and all(len(r) == 4 for r in rows[1:]), [len(r) for r in rows]
    # Target: the other kid walkers (pip_winter, tobin_summer) are ~68-70 px.
    allb = [b for r in rows for b in r]
    f = 68.0 / C.med_h(allb)
    g = "characters/npc_wren_jr_base"
    flip = lambda im: im.transpose(Image.FLIP_LEFT_RIGHT)
    # (p5_wren_jr_walk.png, the first render, drew someone else: unused.)
    # Side poses face right like every walker (flip_h = left).
    def side(b):
        return C.piece(rgba, b, factor=f)
    for nm, b, fl in [("idle", rows[0][0], False), ("idle_side", rows[0][1], True), ("idle_up", rows[0][2], False)]:
        _rm(g, nm)
        im = side(b) if fl else C.piece(rgba, b, factor=f)
        S.save(im, g, nm)
        S.manifest[g][nm].update({"cell_w": im.width, "cell_h": im.height, "frames": 1})
    for nm, r, fl in [("walk", rows[1], True), ("walk_down", rows[2], False), ("walk_up", rows[3], False)]:
        _rm(g, nm)
        frames = [side(b) if fl else C.piece(rgba, b, factor=f) for b in r]
        S.strip(frames, g, nm)


def _rekey_arr(a):
    """Leftover magenta key under the feet: pixels in the bottom band of a
    frame whose hue sits near magenta (red and blue well above green, blue
    not far under red). Hot-pink bows (mid-frame) and pink noses stay."""
    r, gg, b, al = [a[..., i].astype(int) for i in range(4)]
    bad = (al > 0) & (r - gg > 35) & (b - gg > 25) & (b > 0.55 * r)
    h = a.shape[0]
    bad[: int(h * 0.78)] = False
    return bad


def _rekey_fix(a, bad):
    """Recolour key residue as a soft brown ground shadow (keeps the shape the
    artist meant as the shadow; no pink)."""
    a = a.copy()
    lum = (0.3 * a[..., 0] + 0.45 * a[..., 1] + 0.25 * a[..., 2]).astype(int)
    lum = np.clip(lum, 20, 120)
    a[..., 0] = np.where(bad, lum * 0.95, a[..., 0])
    a[..., 1] = np.where(bad, lum * 0.78, a[..., 1])
    a[..., 2] = np.where(bad, lum * 0.62, a[..., 2])
    return a


REKEY = {
    "wildlife": ["boar", "otter", "rabbit", "mouse", "crab", "raccoon", "badger", "beaver", "hedgehog", "snake", "goat"],
    "animals": ["cat_grey", "dog_corgi", "dog_white", "pup", "goat", "goat2", "goat_kid", "kid_goat", "sheep_woolly"],
}


def rekey(report=False):
    total = 0
    for group, names in REKEY.items():
        for nm in names:
            for path in sorted(glob.glob(os.path.join(S.OUT, group, nm, "*.png"))):
                im = Image.open(path).convert("RGBA")
                a = np.asarray(im).copy()
                bad = _rekey_arr(a)
                n = int(bad.sum())
                if not n:
                    continue
                total += n
                print(f"  {group}/{nm}/{os.path.basename(path)}: {n}")
                if not report:
                    _write(Image.fromarray(_rekey_fix(a, bad).astype(np.uint8)), path)
    print("rekey pixels", total)


def _keep_main(a, frac=0.04):
    """Drop opaque islands smaller than `frac` of the largest one (stray specks,
    a beam that floated off the art), then trim to what's left."""
    m = a[..., 3] > 40
    lab, n = ndimage.label(ndimage.binary_dilation(m, iterations=2))
    if n <= 1:
        return a, 0
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    big = sizes.max()
    keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= frac * big])
    dropped = int((m & ~keep).sum())
    a = a.copy()
    a[~keep] = 0
    return a, dropped


def blobs(names=None):
    import crispen
    names = names or [f"{p}_{i}" for p in ("ward", "hq") for i in range(1, 7)]
    for nm in names:
        for group in ("buildings", "props"):
            info = S.manifest.get(group, {}).get(nm)
            if not info:
                continue
            path = os.path.join(S.OUT, info["file"])
            a = np.asarray(Image.open(path).convert("RGBA"))
            a2, dropped = _keep_main(a)
            im = crispen.crispen(Image.fromarray(a2))
            # Keep the canvas (footprint and anchor unchanged).
            _write(im, path)
            print(group, nm, "dropped", dropped)


STEPS = [wren_jr, rekey, blobs]

if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    only = sys.argv[1:]
    for fn in STEPS:
        if only and fn.__name__ not in only:
            continue
        fn(); print("ok", fn.__name__)
    tmp = mpath + ".tmp"
    with open(tmp, "w") as f:
        json.dump(S.manifest, f, indent=1, sort_keys=True)
    if os.path.exists(mpath):
        os.remove(mpath)
    os.replace(tmp, mpath)

#!/usr/bin/env python3
"""CONDUCT 5 fix P4: gangster crew readability + strip repairs.

  python3 tools/slice_c5_p4.py [step ...]      (default: every step)

Steps (run after the other slicers; every write removes the file first, art is
hardlinked to the main repo):
  vicval   every crew walk_down had frames 0/1 as two halves of one figure and
           frame 3 a back view -> rebuilt from the drawn front frames (idle,
           whole step, idle, mirrored step); Vic/Val view_front showed the
           back -> their front idle.
  crew     c5_06 #2 "one colour pair" rule: the 12 crew were one near-black
           silhouette. Below the head, each member's dark clothing is re-shaded
           into their own main colour and the neon trim into their accent, on
           every strip and on the lower part of every portrait (sprite and
           portrait stay matched). Outlines, faces and hair are kept.
           Idempotent: the originals are kept in art/gen/kits/c5_p4_orig/.
"""
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEN = os.path.join(ROOT, "art", "gen")
ORIG = os.path.join(GEN, "kits", "c5_p4_orig")
MAN = os.path.join(GEN, "manifest.json")

# id: (main dark, main light, accent)  -- c5_06 #2 colour pairs
CREW = {
    "deuce": ("#a9abbb", "#f6f6fb", "#e0303e"),      # white tux, red cards
    "mama_rosa": ("#94401a", "#f08a3a", "#f6e2b8"),  # orange chef, cream
    "specs": ("#145462", "#3cc4cc", "#a6faff"),      # teal, screens
    "ladder": ("#24521f", "#5cb04a", "#cff060"),     # green
    "vic": ("#1a347e", "#4a7ee6", "#8fd2ff"),        # blue twin
    "val": ("#7e1a26", "#e44a52", "#ffb080"),        # red twin
    "halo": ("#8e6a1c", "#ecc650", "#fffbe8"),       # gold / white
    "dice": ("#432672", "#8e5ad6", "#ffe23e"),       # purple / yellow
    "the_kid": ("#386a10", "#90d634", "#eaff74"),    # lime
    "doc": ("#a6b8b2", "#eef8f3", "#56e0ac"),        # white coat, mint
    "marlene": ("#744610", "#d68c28", "#ffd648"),    # amber / gold
    "sasha": ("#465060", "#9ca8b8", "#d42a3a"),      # steel / crimson
}
HEAD = 0.30       # sprites: top share of the figure left alone (hair, face, hats)
PORTRAIT_HEAD = 0.62


def _hex(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


def _save(img, path):
    if os.path.exists(path):
        os.remove(path)
    img.save(path)


def _orig(rel):
    """The untouched source of art/gen/<rel> (copied aside on the first run)."""
    src = os.path.join(GEN, rel)
    keep = os.path.join(ORIG, rel)
    if not os.path.exists(keep):
        os.makedirs(os.path.dirname(keep), exist_ok=True)
        shutil.copyfile(src, keep)
    return Image.open(keep).convert("RGBA")


def _hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    d = mx - mn
    s = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    h = np.zeros_like(mx)
    m = d > 1e-6
    rc = np.where(m, (mx - r) / np.maximum(d, 1e-6), 0)
    gc = np.where(m, (mx - g) / np.maximum(d, 1e-6), 0)
    bc = np.where(m, (mx - b) / np.maximum(d, 1e-6), 0)
    h = np.where(r == mx, bc - gc, np.where(g == mx, 2.0 + rc - bc, 4.0 + gc - rc))
    h = (h / 6.0) % 1.0
    return h, s, mx


def recolour(a, dark, light, acc, head, cells=1, ramp=0.0, accent=True):
    """a: HxWx4 uint8. Returns a recoloured copy (per cell bbox head cut)."""
    out = a.astype(np.float32)
    H, W = a.shape[:2]
    cw = W // max(1, cells)
    alpha = a[..., 3] > 128
    # Outline = opaque pixel touching transparency.
    edge = np.zeros_like(alpha)
    p = np.pad(alpha, 1)
    edge = alpha & ~(p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:])
    rgb = out[..., :3] / 255.0
    h, s, v = _hsv(rgb)
    body = np.zeros_like(alpha)
    wgt = np.ones((H, W), dtype=np.float32)
    for c in range(max(1, cells)):
        x0, x1 = c * cw, (c + 1) * cw if c < cells - 1 else W
        ys = np.where(alpha[:, x0:x1].any(1))[0]
        if ys.size == 0:
            continue
        top, bot = ys[0], ys[-1]
        cut = int(top + (bot - top) * head)
        body[cut:, x0:x1] = True
        if ramp > 0:
            rr = max(1, int((bot - top) * ramp))
            for y in range(cut, min(H, cut + rr)):
                wgt[y, x0:x1] = (y - cut + 1) / float(rr + 1)
    skin = (h > 0.02) & (h < 0.13) & (s > 0.2) & (s < 0.75) & (v > 0.35)
    darkpx = body & alpha & ~edge & (v >= 0.07) & (v < 0.40) & (s < 0.55)
    neon = body & alpha & ~edge & (s > 0.45) & (v > 0.42) & ~skin
    t = np.clip((v - 0.07) / 0.33, 0, 1)[..., None]
    shade = dark[None, None, :] * (1 - t) + light[None, None, :] * t
    src = out[..., :3].copy()
    w3 = wgt[..., None]
    out[..., :3] = np.where(darkpx[..., None], shade * w3 + src * (1 - w3), out[..., :3])
    if not accent:
        return np.clip(out, 0, 255).astype(np.uint8)
    # Accent keeps the trim's own brightness pattern.
    k = np.clip(v / 0.95, 0.45, 1.0)[..., None]
    out[..., :3] = np.where(neon[..., None], acc[None, None, :] * k, out[..., :3])
    return np.clip(out, 0, 255).astype(np.uint8)


def crew():
    man = json.load(open(MAN))
    n = 0
    for cid, (d, l, ac) in CREW.items():
        dark, light, acc = _hex(d), _hex(l), _hex(ac)
        for anim, info in man.get("characters/" + cid, {}).items():
            rel = info.get("file")
            if not rel or not os.path.exists(os.path.join(GEN, rel)):
                continue
            a = np.array(_orig(rel))
            cells = int(info.get("frames", 1) or 1)
            _save(Image.fromarray(recolour(a, dark, light, acc, HEAD, cells)), os.path.join(GEN, rel))
            n += 1
        pdir = os.path.join(GEN, "portraits", cid)
        if os.path.isdir(pdir):
            for f in sorted(os.listdir(pdir)):
                if f.endswith(".png"):
                    rel = "portraits/%s/%s" % (cid, f)
                    a = np.array(_orig(rel))
                    _save(Image.fromarray(recolour(a, dark, light, acc, PORTRAIT_HEAD, ramp=0.14, accent=False)), os.path.join(GEN, rel))
                    n += 1
    print("crew: recoloured %d files" % n)


def _cells(path, n):
    im = Image.open(path).convert("RGBA")
    cw = im.width // n
    return [im.crop((i * cw, 0, (i + 1) * cw, im.height)) for i in range(n)]


def _strip(frames):
    w = max(f.width for f in frames)
    h = max(f.height for f in frames)
    out = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.alpha_composite(f, (i * w + (w - f.width) // 2, h - f.height))
    return out, w, h


def vicval():
    man = json.load(open(MAN))
    for cid in CREW:
        g = man["characters/" + cid]
        base = os.path.join(GEN, "characters", cid)
        idle = _cells(os.path.join(ORIG if os.path.exists(os.path.join(ORIG, "characters", cid, "idle_down.png")) else GEN, "characters", cid, "idle_down.png"), int(g["idle_down"]["frames"]))
        vv = os.path.join(ORIG, "characters", cid, "walk_down_vv.png")  # the broken original strip
        if not os.path.exists(vv):
            os.makedirs(os.path.dirname(vv), exist_ok=True)
            o = os.path.join(ORIG, "characters", cid, "walk_down.png")
            shutil.copyfile(o if os.path.exists(o) else os.path.join(base, "walk_down.png"), vv)
        walk = _cells(vv, 4)
        front = walk[2]  # the one whole front step
        frames = [idle[0], front, idle[-1], front.transpose(Image.FLIP_LEFT_RIGHT)]
        im, w, h = _strip(frames)
        _save(im, os.path.join(base, "walk_down.png"))
        g["walk_down"].update({"frames": 4, "cell_w": w, "cell_h": h, "w": im.width, "h": h})
        vf = idle[0]
        if cid not in ("vic", "val"):  # only the twins' view_front showed the back
            vf = None
        if vf is not None:
            _save(vf, os.path.join(base, "view_front.png"))
            g["view_front"].update({"frames": 1, "cell_w": vf.width, "cell_h": vf.height, "w": vf.width, "h": vf.height})
        # The crew strips are recoloured from ORIG: refresh those copies too.
        for name in ("walk_down.png",) + (("view_front.png",) if vf is not None else ()):
            keep = os.path.join(ORIG, "characters", cid, name)
            if os.path.exists(keep):
                os.remove(keep)
            os.makedirs(os.path.dirname(keep), exist_ok=True)
            shutil.copyfile(os.path.join(base, name), keep)
    tmp = MAN + ".tmp"
    json.dump(man, open(tmp, "w"), indent=1, sort_keys=True)
    os.remove(MAN)
    os.rename(tmp, MAN)
    print("vicval: crew walk_down rebuilt (+ twins view_front)")


STEPS = {"vicval": vicval, "crew": crew}

if __name__ == "__main__":
    for s in (sys.argv[1:] or list(STEPS)):
        STEPS[s]()

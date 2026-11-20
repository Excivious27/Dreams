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
           Idempotent: the originals are kept in art/gen/kits/c5_p4_orig/
           (rm -rf that folder after re-slicing the source sheets).
  slivers  c5_07 #1: neighbour-row/column slivers in the 12B heroes' strips
           (Pip-Pip, Nova, Coldy, Big Jim): small pieces touching a cell's top,
           bottom or side edge away from the figure are dropped.
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


HERO12_SLIVER = ["penguin_king", "penguin_wizard", "coldy", "big_jim"]


def _clean_cell(a):
    """Drop neighbour-row/column slivers from one cell (HxWx4 uint8)."""
    from scipy import ndimage
    a = a.copy()
    rows = (a[..., 3] > 40).any(1)
    H = rows.size
    # A band at the top/bottom edge cut off from the figure by empty rows is
    # the next row's figure: clear it.
    if rows[:10].any():
        t = int(np.argmax(rows))
        k = t + int(np.argmin(rows[t:]))  # first empty row below the band
        if t < k < H * 0.25 and rows[k:].any():
            a[:k] = 0
    if rows[-3:].any():
        t = H - 1 - int(np.argmax(rows[::-1]))
        k = t - int(np.argmin(rows[t::-1]))  # last empty row above the band
        if H * 0.8 < k < t and rows[:k].any():
            a[k + 1:] = 0
    alpha = a[..., 3] > 40
    lab, n = ndimage.label(alpha, structure=np.ones((3, 3)))
    if n <= 1:
        return a
    sizes = ndimage.sum(alpha, lab, range(1, n + 1))
    main = int(np.argmax(sizes)) + 1
    msl = ndimage.find_objects(lab)[main - 1]
    m_top, m_bot = msl[0].start, msl[0].stop
    H, W = alpha.shape
    out = a.copy()
    for i, sl in enumerate(ndimage.find_objects(lab), start=1):
        if i == main or sl is None:
            continue
        y0, y1, x0, x1 = sl[0].start, sl[0].stop, sl[1].start, sl[1].stop
        small = sizes[i - 1] < 0.12 * sizes[main - 1]
        top = y0 == 0 and y1 <= m_top + (m_bot - m_top) * 0.2
        bottom = y1 >= H and y0 >= m_bot - 3
        side = (x0 == 0 or x1 >= W) and (x1 - x0) <= 5
        if small and (top or bottom or side):
            out[lab == i] = 0
    return out


def slivers():
    man = json.load(open(MAN))
    n = 0
    for cid in HERO12_SLIVER:
        for anim, info in man.get("characters/" + cid, {}).items():
            rel = info.get("file")
            if not rel or not os.path.exists(os.path.join(GEN, rel)):
                continue
            a = np.array(_orig(rel))
            cells = int(info.get("frames", 1) or 1)
            cw = a.shape[1] // cells
            b = a.copy()
            for c in range(cells):
                b[:, c * cw:(c + 1) * cw] = _clean_cell(a[:, c * cw:(c + 1) * cw])
            if not np.array_equal(a, b):
                _save(Image.fromarray(b), os.path.join(GEN, rel))
                n += 1
    print("slivers: cleaned %d strips" % n)


# ---- c5_07 #2 / c5_15 #3: tool poses right/up for Pip-Pip and Nova, pickaxe_down
# for Coldy and Big Jim (renders art/incoming/c5/p4_*; edit_image from their strips).
TOOL_SHEETS = [
    ("c5/p4_pk_tools_right.png", "penguin_king", "right"),
    ("c5/p4_pk_tools_up.png", "penguin_king", "up"),
    ("c5/p4_pw_tools_right.png", "penguin_wizard", "right"),
    ("c5/p4_pw_tools_up.png", "penguin_wizard", "up"),
]
TOOL_ROWS = ["hoe", "axe", "pickaxe", "water"]
INC = os.path.join(ROOT, "art", "incoming")


def _load_sheet(rel):
    im = Image.open(os.path.join(INC, rel)).convert("RGBA")
    a = np.array(im)
    if (a[..., 3] < 10).mean() < 0.2:  # an opaque magenta render: key pure magenta only
        rgb = a[..., :3].astype(np.int32)  # (the shared keyer eats Big Jim's purple)
        d = np.abs(rgb - np.array([255, 0, 255])).sum(-1)
        a[d < 80] = 0
        mag = (rgb[..., 0] > 215) & (rgb[..., 2] > 215) & (rgb[..., 1] < 70)
        a[mag] = 0
    else:
        a[a[..., 3] < 40] = 0
    return a


def _figs(a, n_rows):
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import slice_comp as C
    rows = C.rows_of(C.blobs(a, merge=10, min_area=1500))
    rows = sorted(rows, key=lambda r: min(b[1] for b in r))[:n_rows]
    return [sorted(r, key=lambda b: b[0]) for r in rows]


def _body_h(rel_png, frame=0):
    info_im = Image.open(os.path.join(GEN, rel_png)).convert("RGBA")
    return info_im


def _used_h(img):
    bb = img.getbbox()
    return (bb[3] - bb[1]) if bb else img.height


def _save_strip(frames, group, name, man):
    out, w, h = _strip(frames)
    path = os.path.join(GEN, group, name + ".png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    _save(out, path)
    man.setdefault(group, {})[name] = {"file": "%s/%s.png" % (group, name), "w": out.width, "h": h, "cell_w": w, "cell_h": h, "frames": len(frames)}


def _ref_h(cid, anim):
    man = json.load(open(MAN))
    info = man["characters/" + cid][anim]
    im = Image.open(os.path.join(GEN, info["file"])).convert("RGBA")
    cw = info["cell_w"]
    return int(np.median([_used_h(im.crop((i * cw, 0, (i + 1) * cw, im.height))) for i in range(info["frames"])])), info["cell_h"]


def _ref_w(cid, anim):
    man = json.load(open(MAN))
    info = man["characters/" + cid][anim]
    im = Image.open(os.path.join(GEN, info["file"])).convert("RGBA")
    cw = info["cell_w"]
    ws = []
    for i in range(info["frames"]):
        bb = im.crop((i * cw, 0, (i + 1) * cw, im.height)).getbbox()
        ws.append(bb[2] - bb[0] if bb else cw)
    return int(np.median(ws))


def _write_dump(man):
    tmp = MAN + ".tmp"
    json.dump(man, open(tmp, "w"), indent=1, sort_keys=True)
    os.remove(MAN)
    os.rename(tmp, MAN)


def tools():
    man = json.load(open(MAN))
    for rel, cid, d in TOOL_SHEETS:
        if not os.path.exists(os.path.join(INC, rel)):
            continue
        a = _load_sheet(rel)
        rows = _figs(a, 4)
        # Scale: the watering row (no tool raised) matches their drawn water_down body.
        ref, cell_h = _ref_h(cid, "idle_down")
        wat = [b[3] - b[1] for b in rows[3]]
        f = ref / float(np.median(wat))
        for name, row in zip(TOOL_ROWS, rows):
            frames = []
            for b in row[:3]:
                im = Image.fromarray(a[b[1]:b[3], b[0]:b[2]])
                frames.append(im.resize((max(1, round(im.width * f)), max(1, round(im.height * f))), Image.LANCZOS))
            _save_strip(frames, "characters/" + cid, "%s_%s" % (name, d), man)
    rel = "c5/p4_pickaxe_down_coldy_jim.png"
    if os.path.exists(os.path.join(INC, rel)):
        a = _load_sheet(rel)
        rows = _figs(a, 2)
        for cid, row in zip(["coldy", "big_jim"], rows):
            row = [b for b in row if b[3] - b[1] > 100][:3]
            if cid == "coldy":
                f = _ref_w(cid, "idle_down") / float(row[0][2] - row[0][0])  # arms up: body width
            else:  # Big Jim's arms stick out at rest: match the mid swing to his height
                f = 0.97 * _ref_h(cid, "idle_down")[0] / float(row[1][3] - row[1][1])
            frames = []
            for b in row:
                im = Image.fromarray(a[b[1]:b[3], b[0]:b[2]])
                frames.append(im.resize((max(1, round(im.width * f)), max(1, round(im.height * f))), Image.LANCZOS))
            _save_strip(frames, "characters/" + cid, "pickaxe_down", man)
    _write_dump(man)
    print("tools: tool strips written")


STEPS = {"vicval": vicval, "crew": crew, "slivers": slivers, "tools": tools}

if __name__ == "__main__":
    for s in (sys.argv[1:] or list(STEPS)):
        STEPS[s]()

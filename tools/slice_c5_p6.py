#!/usr/bin/env python3
"""CONDUCT 5 fix package P6 art: the four missing mega boss cards.

  ui/card_rime_wyrm, ui/card_storm_roc       from their enemies/<kind>/idle frame 0
  ui/card_madame_aurum, ui/card_baron_coalbrook  from art/incoming/c5/p6_gang_boss_portraits.png
                                              (image tool render, transparent; left Aurum, right Coalbrook)
  ui/card_garden_boss, _smuggler_king, _ice_hauler   copies of ui/card_gang_boss_gloam/_desert/_frost

Cards use the same composition as tools/slice_c4_p5.py cards(): the shared ornate frame
(ui/card_big_grump), its inner panel repainted, the boss on the left with a soft glow.
Run after the other slicers:  python3 tools/slice_c5_p6.py
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
from slice_comp import blobs
import numpy as np
from PIL import Image, ImageFilter


def _rm(group, name):
    p = os.path.join(S.OUT, group, name + ".png")
    if os.path.exists(p):
        os.remove(p)  # hardlinked art: never write in place


def first_frame(kind):
    info = S.manifest["enemies/" + kind]["idle"]
    im = Image.open(os.path.join(S.OUT, info["file"])).convert("RGBA")
    return im.crop((0, 0, info["cell_w"], info["cell_h"]))


def tight(im):
    bb = im.getbbox()
    return im.crop(bb) if bb else im


def portraits():
    """Left and right figure of the render, scaled to sprite size (~120 px tall) like a boss frame."""
    src = Image.open(os.path.join(S.INC, "c5", "p6_gang_boss_portraits.png")).convert("RGBA")
    a = np.asarray(src).copy()
    keyed = np.asarray(S.key_magenta(src))
    a[..., 3] = np.minimum(a[..., 3], keyed[..., 3])
    rgba = Image.fromarray(a)
    W = rgba.width
    out = []
    for x0, x1 in ((0, W // 2), (W // 2, W)):
        p = tight(rgba.crop((x0, 0, x1, rgba.height)))
        f = 120.0 / p.height
        p = p.resize((max(1, round(p.width * f)), 120), Image.LANCZOS)
        q = np.asarray(p).copy()
        q[..., 3] = np.where(q[..., 3] > 140, 255, np.where(q[..., 3] > 60, q[..., 3], 0))
        out.append(Image.fromarray(q))
    return out


def card(kind, spr):
    base = Image.open(os.path.join(S.OUT, "ui", "card_big_grump.png")).convert("RGBA")
    a = np.asarray(base).astype(np.int32)
    W, H = base.size
    x0, y0, x1, y1 = (24, 30, W - 24, H - 22)
    panel = np.zeros((y1 - y0, x1 - x0, 4), np.int32)
    xs = np.linspace(0, 1, x1 - x0)[None, :]
    ys = np.linspace(0, 1, y1 - y0)[:, None]
    shade = 0.55 + 0.45 * (1 - np.abs(ys - 0.5) * 1.6) * (1 - 0.6 * xs)
    panel[..., 0] = (92 * shade).astype(int)
    panel[..., 1] = (14 * shade).astype(int)
    panel[..., 2] = (22 * shade).astype(int)
    panel[..., 3] = 255
    c = a.copy()
    reg = c[y0:y1, x0:x1]
    rr, gg, bb = reg[..., 0], reg[..., 1], reg[..., 2]
    gold = (rr > 120) & (gg > 70) & (bb < gg) & (rr > bb + 40)
    m = (~gold) & (reg[..., 3] > 0)
    m[12:-6, 14:-14] = True
    reg[m] = panel[m]
    img = Image.fromarray(c.astype(np.uint8))
    spr = tight(spr)
    ph = (y1 - y0) - 16
    f = ph / float(spr.height)
    sw = round(spr.width * f)
    if sw > (x1 - x0) * 0.45:
        f = (x1 - x0) * 0.45 / spr.width
        sw = round(spr.width * f)
    big = spr.resize((sw, max(1, round(spr.height * f))), Image.NEAREST)
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gl = Image.new("RGBA", big.size, (255, 200, 140, 0))
    al = np.asarray(big)[..., 3]
    gl.putalpha(Image.fromarray((al > 0).astype(np.uint8) * 90))
    px = x0 + 40
    py = y1 - 8 - big.height
    glow.alpha_composite(gl, (px, py))
    glow = glow.filter(ImageFilter.GaussianBlur(10))
    img.alpha_composite(glow)
    img.alpha_composite(big, (px, py))
    _rm("ui", "card_" + kind)
    S.save(img, "ui", "card_" + kind)


def cards():
    card("rime_wyrm", first_frame("rime_wyrm"))
    card("storm_roc", first_frame("storm_roc"))
    aurum, coal = portraits()
    card("madame_aurum", aurum)
    card("baron_coalbrook", coal)
    # gangster mega bosses: boss_card looks up ui/card_<kind>; their cards were sliced as card_gang_boss_*
    for kind, src in (("garden_boss", "gloam"), ("smuggler_king", "desert"), ("ice_hauler", "frost")):
        im = Image.open(os.path.join(S.OUT, "ui", "card_gang_boss_%s.png" % src)).convert("RGBA")
        _rm("ui", "card_" + kind)
        S.save(im, "ui", "card_" + kind)


if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    cards()
    print("ok cards")
    data = json.dumps(S.manifest, indent=1, sort_keys=True)
    os.remove(mpath)  # hardlinked across worktrees: never write it in place
    with open(mpath, "w") as fh:
        fh.write(data)

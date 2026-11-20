#!/usr/bin/env python3
"""C10b P4: slice the casino renders (art/incoming/c10b/casino_*.png) into art/gen/casino/.

    python3 tools/slice_c10b_casino.py

casino_symbols.png: 2 rows x 4 cells -> sym_cherry, sym_bell, sym_bar, sym_horseshoe,
sym_star, sym_crown, sym_seven (64x64, 2x detail for 32-px drawing) and card_back
(60x84). The render has its own alpha; magenta is keyed too in case a re-render has none.
No manifest: CasinoGame loads them with Art.tex("casino", name). rm before write
(art files are hardlinked across worktrees).
"""
import os
import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "art/incoming/c10b/casino_symbols.png")
OUT = os.path.join(ROOT, "art/gen/casino")
NAMES = ["sym_cherry", "sym_bell", "sym_bar", "sym_horseshoe", "sym_star", "sym_crown", "sym_seven", "card_back"]


def key(im):
    a = np.array(im.convert("RGBA"))
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    mag = (r > 200) & (b > 200) & (g < 80)
    a[..., 3][mag] = 0
    return Image.fromarray(a)


def fit(piece, w, h):
    pw, ph = piece.size
    s = min(w / pw, h / ph)
    p = piece.resize((max(1, round(pw * s)), max(1, round(ph * s))), Image.LANCZOS)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(p, ((w - p.width) // 2, (h - p.height) // 2), p)
    a = np.array(out)
    a[..., 3] = np.where(a[..., 3] > 110, 255, 0)  # hard edge: crisp at 1:1 and magnified
    return Image.fromarray(a)


def main():
    im = key(Image.open(SRC))
    W, H = im.size
    os.makedirs(OUT, exist_ok=True)
    for i, nm in enumerate(NAMES):
        cx, cy = i % 4, i // 4
        cell = im.crop((cx * W // 4, cy * H // 2, (cx + 1) * W // 4, (cy + 1) * H // 2))
        bb = cell.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
        if not bb:
            raise SystemExit("empty cell %s" % nm)
        piece = cell.crop(bb)
        out = fit(piece, 60, 84) if nm == "card_back" else fit(piece, 64, 64)
        path = os.path.join(OUT, nm + ".png")
        if os.path.exists(path):
            os.remove(path)
        out.save(path)
        print("  ", nm, piece.size)


if __name__ == "__main__":
    main()
